"""Extended connectivity diagnostics for GO 3S."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List
from urllib.error import URLError
from urllib.request import Request, urlopen

from insta360_go3s_wifi.go3s_protocol import probe_tcp_handshake
from insta360_go3s_wifi.network import (
    DEFAULT_CAMERA_HOST,
    ProbeResult,
    check_wifi_for_go3s,
    http_head,
    ping_host,
    tcp_reachable,
)


@dataclass
class DiagnoseReport:
    steps: List[ProbeResult]

    @property
    def passed(self) -> bool:
        return all(step.ok for step in self.steps)


def _http_get(url: str, timeout: float = 5.0) -> ProbeResult:
    try:
        with urlopen(url, timeout=timeout) as response:
            return ProbeResult(ok=True, message=f"HTTP GET {url} -> {response.status}")
    except URLError as exc:
        return ProbeResult(ok=False, message=f"HTTP GET {url} failed: {exc.reason}")
    except OSError as exc:
        return ProbeResult(ok=False, message=f"HTTP GET {url} error: {exc}")


def run_diagnose(host: str = DEFAULT_CAMERA_HOST) -> DiagnoseReport:
    steps: List[ProbeResult] = []

    wifi = check_wifi_for_go3s()
    if wifi.ssid:
        if wifi.ssid == "<redacted>":
            steps.append(
                ProbeResult(
                    ok=True,
                    message="SSID hidden by macOS; use ping to 192.168.42.1 as proxy check",
                )
            )
        else:
            steps.append(
                ProbeResult(
                    ok=wifi.looks_like_go3s or True,
                    message=f"WiFi SSID `{wifi.ssid}` (GO 3S name={wifi.looks_like_go3s})",
                )
            )
    else:
        steps.append(ProbeResult(ok=False, message="Could not read current WiFi SSID"))

    ping = ping_host(host)
    steps.append(ping)
    steps.append(tcp_reachable(host, 6666, timeout=3.0))
    steps.append(tcp_reachable(host, 80, timeout=3.0))

    sync_ok, sync_detail, _, banner_seen = probe_tcp_handshake(host)
    probe_msg = f"TCP probe: {sync_detail}"
    if banner_seen and not sync_ok:
        probe_msg += " (GO 3S banner only; SYNC echo missing)"
    steps.append(
        ProbeResult(
            ok=sync_ok or banner_seen,
            message=probe_msg,
        )
    )

    steps.append(http_head(f"http://{host}/osc/info"))
    steps.append(http_head(f"http://{host}/DCIM/Camera01/"))
    steps.append(_http_get(f"http://{host}/osc/info"))

    return DiagnoseReport(steps=steps)
