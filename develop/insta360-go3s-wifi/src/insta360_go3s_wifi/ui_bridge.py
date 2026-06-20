"""High-level operations returning dicts for JSON CLI / UI."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from insta360_go3s_wifi.client import CameraConnectionError, connected_camera
from insta360_go3s_wifi.diagnose import run_diagnose
from insta360_go3s_wifi.files import is_mp4
from insta360_go3s_wifi.importer import run_import, select_download_groups
from insta360_go3s_wifi.index import ImportIndex
from insta360_go3s_wifi.json_api import (
    JsonImportProgress,
    files_payload,
    import_result_to_dict,
)
from insta360_go3s_wifi.go3s_protocol import probe_tcp_handshake
from insta360_go3s_wifi.network import (
    DEFAULT_CAMERA_HOST,
    check_wifi_for_go3s,
    ping_host,
    ProbeResult,
    tcp_reachable,
)
from insta360_go3s_wifi.perf_log import log_event, timed_step


def _import_ready_from_steps(steps: List[ProbeResult]) -> bool:
    """Import-ready when link + TCP probe pass; HTTP extras are informational."""
    ping = next((step for step in steps if step.message.startswith("ping ")), None)
    tcp6666 = next(
        (step for step in steps if "TCP" in step.message and ":6666" in step.message),
        None,
    )
    probe = next((step for step in steps if step.message.startswith("TCP probe:")), None)
    link_ok = bool((ping and ping.ok) or (tcp6666 and tcp6666.ok))
    service_ok = bool(probe and probe.ok)
    return link_ok and service_ok


def connection_status(host: str = DEFAULT_CAMERA_HOST) -> Dict[str, Any]:
    with timed_step("connection_status", "total", host=host):
        with timed_step("connection_status", "wifi"):
            wifi = check_wifi_for_go3s()
        with timed_step("connection_status", "ping", host=host):
            ping = ping_host(host, count=1)
        tcp6666 = ProbeResult(ok=False, message="")
        tcp80 = ProbeResult(ok=False, message="")
        if not ping.ok and wifi.looks_like_go3s:
            with timed_step("connection_status", "tcp6666", host=host):
                tcp6666 = tcp_reachable(host, 6666)
            if not tcp6666.ok:
                with timed_step("connection_status", "tcp80", host=host):
                    tcp80 = tcp_reachable(host, 80)
        sync_ok = False
        sync_detail = ""
        if wifi.looks_like_go3s or ping.ok or tcp6666.ok:
            with timed_step("connection_status", "tcp_probe", host=host):
                sync_ok, sync_detail, _, _banner_seen = probe_tcp_handshake(host)
        link_ok = ping.ok or tcp6666.ok
        ok = link_ok and sync_ok
        looks_like_go3s = wifi.looks_like_go3s or ping.ok
        wifi_only = looks_like_go3s and not ok
        log_event(
            "connection_status",
            "result",
            extra={
                "ok": ok,
                "link_ok": link_ok,
                "sync_ok": sync_ok,
                "ping_ok": ping.ok,
                "tcp6666_ok": tcp6666.ok,
                "tcp80_ok": tcp80.ok,
                "wifi_only": wifi_only,
                "looks_like_go3s": looks_like_go3s,
                "ssid": wifi.ssid or "",
            },
        )
    return {
        "ok": ok,
        "host": host,
        "ping_ok": ping.ok,
        "ping_message": ping.message,
        "tcp6666_ok": tcp6666.ok,
        "tcp80_ok": tcp80.ok,
        "sync_ok": sync_ok,
        "sync_detail": sync_detail,
        "link_ok": link_ok,
        "wifi_only": wifi_only,
        "ssid": wifi.ssid,
        "looks_like_go3s": looks_like_go3s,
    }


def _ui_lang() -> str:
    raw = (os.environ.get("INSTA360_UI_LANG") or "zh").strip().lower()
    return "en" if raw.startswith("en") else "zh"


def _diagnose_hint(steps: List[ProbeResult]) -> str:
    lang = _ui_lang()
    for step in steps:
        if step.ok:
            continue
        msg = step.message.lower()
        if "ssid" in msg or "wifi" in msg:
            if lang == "en":
                return (
                    "On Mac, join Wi‑Fi GO 3S xxxxxx.OSC. "
                    "Find the password on Action Pod: Settings → Wi‑Fi info (not always 88888888)."
                )
            return (
                "请在 Mac 上连接 GO 3S xxxxxx.OSC Wi‑Fi。"
                "密码在 Action Pod：设置 → Wi‑Fi 信息 中查看（非固定 88888888）。"
            )
        if "ping" in msg:
            if lang == "en":
                return "Confirm GO 3S is powered on inside the Action Pod."
            return "确认 GO 3S 已开机，并放在 Action Pod 内。"
        if "6666" in step.message or "sync" in msg or "banner" in msg:
            if lang == "en":
                return (
                    "Pair GO 3S with the Insta360 app on your phone first, then on Action Pod: "
                    "Album → pick a clip → enable Quick File Transfer."
                )
            return (
                "请先用手机 Insta360 App 蓝牙连接 GO 3S，再在 Action Pod："
                "相册 → 任选片段 → 开启 Quick File Transfer。"
            )
        if "http" in msg:
            if lang == "en":
                return (
                    "Quick File Transfer may be off. Confirm the phone app is connected "
                    "and the Pod stays on the transfer screen."
                )
            return "Quick File Transfer 可能未开启；请确认手机 App 已连接相机并保持 Pod 传输界面。"
    if steps and all(step.ok for step in steps):
        if lang == "en":
            return "Hardware checks passed. If the list is still empty, click Refresh."
        return "硬件连接正常。若列表仍为空，请点击刷新加载文件。"
    if lang == "en":
        return "Follow the steps below, then try again."
    return "请按下方步骤检查连接后重试。"


def connection_diagnose(host: str = DEFAULT_CAMERA_HOST) -> Dict[str, Any]:
    """Full connectivity checklist for the macOS UI."""
    with timed_step("connection_diagnose", "total", host=host):
        report = run_diagnose(host=host)
    steps = [{"ok": step.ok, "message": step.message} for step in report.steps]
    core_ok = _import_ready_from_steps(report.steps)
    return {
        "ok": core_ok,
        "host": host,
        "steps": steps,
        "hint": _diagnose_hint(report.steps),
    }


def list_remote_files(host: str = DEFAULT_CAMERA_HOST) -> Dict[str, Any]:
    with timed_step("list_remote_files", "total", host=host):
        with connected_camera(host=host) as camera:
            with timed_step("list_remote_files", "list_files", host=host):
                files = camera.list_files()
        log_event("list_remote_files", "result", extra={"count": len(files)})
    return files_payload(files)


def index_status(dest: Path) -> Dict[str, Any]:
    dest = dest.expanduser().resolve()
    index = ImportIndex.load(dest)
    entries = [
        {
            "remote_path": entry.remote_path,
            "local_name": entry.local_name,
            "size": entry.size,
            "imported_at": entry.imported_at,
            "imported": index.is_imported(entry.remote_path),
        }
        for entry in index.files.values()
    ]
    mp4_entries = [entry for entry in entries if entry["local_name"].lower().endswith(".mp4")]
    return {
        "ok": True,
        "dest": str(dest),
        "count": len(entries),
        "mp4_count": len(mp4_entries),
        "updated_at": index.updated_at,
        "entries": entries,
    }


def local_library(dest: Path) -> Dict[str, Any]:
    dest = dest.expanduser().resolve()
    if not dest.is_dir():
        return {"ok": True, "dest": str(dest), "files": [], "count": 0}

    files = sorted(
        str(path)
        for path in dest.iterdir()
        if path.is_file() and path.suffix.lower() in {".mp4", ".lrv", ".jpg"}
    )
    return {
        "ok": True,
        "dest": str(dest),
        "count": len(files),
        "files": files,
    }


def camera_summary(
    dest: Path,
    host: str = DEFAULT_CAMERA_HOST,
    *,
    start: int = 0,
    page_size: int = 100,
    max_pages: Optional[int] = None,
) -> Dict[str, Any]:
    """List remote MP4s and imported/pending split in one TCP session."""
    with timed_step(
        "camera_summary",
        "total",
        host=host,
        dest=str(dest),
        start=start,
        page_size=page_size,
        max_pages=max_pages,
    ):
        dest = dest.expanduser().resolve()
        with timed_step("camera_summary", "index_load", dest=str(dest)):
            index = ImportIndex.load(dest)
        with connected_camera(host=host) as camera:
            with timed_step("camera_summary", "list_files", host=host):
                if max_pages is None and start == 0:
                    remote_paths = camera.list_files()
                    remote_total = len(remote_paths)
                    has_more = False
                    next_start = len(remote_paths)
                else:
                    remote_paths, remote_total, has_more, next_start = camera.list_files_range(
                        start=start,
                        page_size=page_size,
                        max_pages=max_pages or 1,
                    )
        with timed_step("camera_summary", "split_imported"):
            mp4_files = [path for path in remote_paths if is_mp4(path)]
            imported_set = index.imported_mp4_paths(mp4_files)
            pending_mp4 = [path for path in mp4_files if path not in imported_set]
        log_event(
            "camera_summary",
            "result",
            extra={
                "remote_count": len(remote_paths),
                "remote_total": remote_total,
                "has_more": has_more,
                "next_start": next_start,
                "mp4_count": len(mp4_files),
                "imported_count": len(imported_set),
                "pending_count": len(pending_mp4),
            },
        )
    return {
        "ok": True,
        "dest": str(dest),
        "count": len(remote_paths),
        "remote_total": remote_total,
        "remote_loaded": next_start if remote_total is not None else len(remote_paths),
        "list_start": start,
        "list_next_start": next_start,
        "has_more": has_more,
        "mp4_count": len(mp4_files),
        "imported_count": len(imported_set),
        "pending_count": len(pending_mp4),
        "mp4_files": mp4_files,
        "imported_mp4": sorted(imported_set),
        "pending_mp4": pending_mp4,
    }


def pending_from_summary(summary: Dict[str, Any]) -> Dict[str, Any]:
    pending_mp4 = summary.get("pending_mp4", [])
    dest = summary.get("dest", "")
    pending_local = [
        str(Path(dest).expanduser().resolve() / Path(path).name) for path in pending_mp4
    ]
    return {
        "ok": True,
        "dest": dest,
        "pending_mp4_remote": pending_mp4,
        "pending_mp4": pending_local,
        "pending_count": len(pending_mp4),
    }


def run_import_json_events(
    dest: Path,
    host: str = DEFAULT_CAMERA_HOST,
    new_only: bool = True,
    dry_run: bool = False,
    remote_filter: Optional[set] = None,
) -> Dict[str, Any]:
    progress = JsonImportProgress()
    result = run_import(
        dest=dest,
        host=host,
        new_only=new_only,
        dry_run=dry_run,
        progress=progress,
        remote_filter=remote_filter,
    )
    if not any("cancelled" in item for item in result.stats.failed):
        progress.on_complete(result)
    return import_result_to_dict(result)


def pending_import(dest: Path, host: str = DEFAULT_CAMERA_HOST) -> Dict[str, Any]:
    summary = camera_summary(dest=dest, host=host)
    payload = pending_from_summary(summary)
    payload["stats"] = {
        "remote_total": summary.get("count", 0),
        "mp4_groups_total": summary.get("mp4_count", 0),
        "skipped": summary.get("imported_count", 0),
    }
    return payload
