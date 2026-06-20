"""Mac network helpers for GO 3S WiFi validation."""

from __future__ import annotations

import platform
import socket
import subprocess
import time
from dataclasses import dataclass
from typing import Optional, Set, Tuple
from urllib.error import URLError
from urllib.request import Request, urlopen


DEFAULT_CAMERA_HOST = "192.168.42.1"
DEFAULT_CAMERA_PORT = 6666
GO3S_SSID_PREFIX = "GO 3S"

_NETWORK_INFO_PROPERTY_KEYS: Set[str] = {
    "PHY Mode",
    "Channel",
    "Country Code",
    "Network Type",
    "Security",
    "Signal / Noise",
    "Transmit Rate",
    "MCS Index",
}

_SSID_CACHE: Optional[Tuple[float, Optional[str]]] = None
_SSID_CACHE_TTL_SEC = 5.0
_NETWORKSETUP_TIMEOUT_SEC = 2.0
_SYSTEM_PROFILER_TIMEOUT_SEC = 5.0


@dataclass
class ProbeResult:
    ok: bool
    message: str


@dataclass
class WifiStatus:
    connected: bool
    ssid: Optional[str]
    looks_like_go3s: bool


def _ssid_from_networksetup() -> Optional[str]:
    for device in ("en0", "en1"):
        try:
            output = subprocess.run(
                ["networksetup", "-getairportnetwork", device],
                capture_output=True,
                text=True,
                timeout=_NETWORKSETUP_TIMEOUT_SEC,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        text = (output.stdout or "").strip()
        if not text or "not associated" in text.lower():
            continue
        prefix = "Current Wi-Fi Network:"
        if prefix in text:
            ssid = text.split(prefix, 1)[1].strip()
            return ssid or None
    return None


def _resolve_wifi_ssid() -> Optional[str]:
    if platform.system() != "Darwin":
        return None

    ssid = _ssid_from_networksetup()
    if ssid:
        return ssid

    try:
        output = subprocess.run(
            ["system_profiler", "SPAirPortDataType"],
            capture_output=True,
            text=True,
            timeout=_SYSTEM_PROFILER_TIMEOUT_SEC,
            check=False,
        )
        if output.returncode == 0 and output.stdout:
            return _ssid_from_system_profiler(output.stdout)
    except (OSError, subprocess.TimeoutExpired):
        return None

    return None


def _ssid_from_system_profiler(text: str) -> Optional[str]:
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if "Current Network Information:" not in line:
            continue
        for follow in lines[index + 1 : index + 12]:
            stripped = follow.strip()
            if not stripped:
                continue
            if stripped.startswith("Other Local") or stripped.startswith("awdl0:"):
                break
            if not stripped.endswith(":"):
                continue
            key = stripped[:-1].strip()
            if key in _NETWORK_INFO_PROPERTY_KEYS or key.endswith("Information"):
                continue
            return key
    return None


def get_current_wifi_ssid() -> Optional[str]:
    """Return current Wi-Fi SSID on macOS, or None if unavailable."""
    global _SSID_CACHE
    now = time.monotonic()
    if _SSID_CACHE is not None and now - _SSID_CACHE[0] < _SSID_CACHE_TTL_SEC:
        return _SSID_CACHE[1]

    ssid = _resolve_wifi_ssid()
    _SSID_CACHE = (now, ssid)
    return ssid


def clear_wifi_ssid_cache() -> None:
    """Invalidate cached SSID (for tests)."""
    global _SSID_CACHE
    _SSID_CACHE = None


def check_wifi_for_go3s() -> WifiStatus:
    """SSID-only WiFi probe; reachability is checked separately via ping/TCP."""
    ssid = get_current_wifi_ssid()
    if not ssid:
        return WifiStatus(connected=False, ssid=None, looks_like_go3s=False)
    if ssid == "<redacted>":
        # macOS often hides the SSID; treat as likely GO 3S AP when associated.
        return WifiStatus(connected=True, ssid=ssid, looks_like_go3s=True)
    return WifiStatus(
        connected=True,
        ssid=ssid,
        looks_like_go3s=ssid.upper().startswith(GO3S_SSID_PREFIX.upper()),
    )


def ping_host(host: str = DEFAULT_CAMERA_HOST, count: int = 3) -> ProbeResult:
    try:
        result = subprocess.run(
            ["ping", "-c", str(count), host],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        if result.returncode == 0:
            return ProbeResult(ok=True, message=f"ping {host} OK")
        tail = (result.stdout or result.stderr or "").strip().splitlines()
        detail = tail[-1] if tail else "no reply"
        return ProbeResult(ok=False, message=f"ping {host} failed: {detail}")
    except (OSError, subprocess.TimeoutExpired) as exc:
        return ProbeResult(ok=False, message=f"ping {host} error: {exc}")


def tcp_reachable(
    host: str = DEFAULT_CAMERA_HOST,
    port: int = DEFAULT_CAMERA_PORT,
    timeout: float = 1.5,
) -> ProbeResult:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return ProbeResult(ok=True, message=f"TCP {host}:{port} reachable")
    except OSError as exc:
        return ProbeResult(ok=False, message=f"TCP {host}:{port} failed: {exc}")


def http_head(url: str, timeout: float = 5.0) -> ProbeResult:
    try:
        request = Request(url, method="HEAD")
        with urlopen(request, timeout=timeout) as response:
            code = response.status
            if code < 400:
                return ProbeResult(ok=True, message=f"HTTP {code} {url}")
            return ProbeResult(ok=False, message=f"HTTP {code} {url}")
    except URLError as exc:
        return ProbeResult(ok=False, message=f"HTTP HEAD failed {url}: {exc.reason}")
    except OSError as exc:
        return ProbeResult(ok=False, message=f"HTTP HEAD error {url}: {exc}")
