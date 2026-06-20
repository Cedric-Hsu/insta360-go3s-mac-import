"""Performance / diagnostic logging for GO 3S WiFi tooling."""

from __future__ import annotations

import json
import os
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterator, Optional

_LOG_LOCK = threading.Lock()
_LOG_PATH: Optional[Path] = None


def default_log_path() -> Path:
    return Path.home() / "Library/Logs/Insta360GO3SImport/perf.log"


def perf_log_path() -> Path:
    global _LOG_PATH
    if _LOG_PATH is None:
        custom = os.environ.get("INSTA360_PERF_LOG_PATH", "").strip()
        _LOG_PATH = Path(custom).expanduser() if custom else default_log_path()
    return _LOG_PATH


def perf_enabled() -> bool:
    value = os.environ.get("INSTA360_PERF_LOG", "1").strip().lower()
    return value not in {"", "0", "false", "no", "off"}


def _format_extra(extra: Optional[Dict[str, Any]]) -> str:
    if not extra:
        return ""
    try:
        payload = json.dumps(extra, ensure_ascii=False, sort_keys=True)
    except TypeError:
        payload = json.dumps({k: str(v) for k, v in extra.items()}, ensure_ascii=False, sort_keys=True)
    return f" {payload}"


def log_event(
    component: str,
    message: str,
    *,
    duration_ms: Optional[float] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    if not perf_enabled():
        return

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    duration = ""
    if duration_ms is not None:
        duration = f" duration_ms={duration_ms:.1f}"
    line = f"{timestamp} [{component}] {message}{duration}{_format_extra(extra)}\n"

    path = perf_log_path()
    with _LOG_LOCK:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(line)


@contextmanager
def timed_step(
    component: str,
    step: str,
    **fields: Any,
) -> Iterator[None]:
    start = time.perf_counter()
    log_event(component, f"{step} start", extra=fields or None)
    try:
        yield
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - start) * 1000.0
        error_fields = dict(fields)
        error_fields["error"] = str(exc)
        log_event(component, f"{step} error", duration_ms=elapsed_ms, extra=error_fields)
        raise
    else:
        elapsed_ms = (time.perf_counter() - start) * 1000.0
        log_event(component, f"{step} done", duration_ms=elapsed_ms, extra=fields or None)
