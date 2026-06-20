"""Prevent macOS idle sleep during long WiFi transfers (display may still dim/off)."""

from __future__ import annotations

import os
import platform
import subprocess
from contextlib import contextmanager
from typing import Iterator, Optional

_caffeinate_proc: Optional[subprocess.Popen] = None


@contextmanager
def keep_system_awake(reason: str = "insta360-go3s-wifi transfer") -> Iterator[None]:
    """Block system idle sleep on macOS; does not require the display to stay on."""
    global _caffeinate_proc
    if platform.system() != "Darwin":
        yield
        return

    proc: Optional[subprocess.Popen] = None
    try:
        # -i: idle sleep only (screen can turn off)
        # -w: watch our PID and exit when import process ends
        proc = subprocess.Popen(
            ["caffeinate", "-i", "-w", str(os.getpid())],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        _caffeinate_proc = proc
        yield
    finally:
        if proc is not None and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        if _caffeinate_proc is proc:
            _caffeinate_proc = None


def keep_system_awake_enabled() -> bool:
    """Return False when user opts out via env var."""
    value = os.environ.get("INSTA360_KEEP_AWAKE", "1").strip().lower()
    return value not in {"0", "false", "no", "off"}
