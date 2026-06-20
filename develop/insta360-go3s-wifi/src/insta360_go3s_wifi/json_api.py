"""Machine-readable JSON / NDJSON output for the macOS UI."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from insta360_go3s_wifi.files import is_mp4, local_name
from insta360_go3s_wifi.importer import ImportResult, ImportStats


def emit_json(payload: Dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def emit_event(event_type: str, **fields: Any) -> None:
    payload = {"type": event_type, **fields}
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def stats_to_dict(stats: ImportStats) -> Dict[str, Any]:
    return {
        "remote_total": stats.remote_total,
        "mp4_groups_total": stats.mp4_groups_total,
        "skipped": stats.skipped,
        "downloaded_files": stats.downloaded_files,
        "downloaded_bytes": stats.downloaded_bytes,
        "failed": list(stats.failed),
    }


def import_result_to_dict(result: ImportResult) -> Dict[str, Any]:
    return {
        "ok": result.ok,
        "dest": str(result.dest),
        "stats": stats_to_dict(result.stats),
        "imported_paths": list(result.imported_paths),
    }


class JsonImportProgress:
    """Emit NDJSON progress events for UI consumers."""

    def on_import_begin(self, pending_files: int, mp4_groups: int) -> None:
        emit_event(
            "import_begin",
            pending_files=pending_files,
            mp4_groups=mp4_groups,
        )

    def on_file_start(self, remote_path: str, local_path: Path) -> None:
        emit_event(
            "file_start",
            remote=remote_path,
            local=str(local_path),
            name=local_name(remote_path),
        )

    def on_file_progress(self, written: int, total: Optional[int]) -> None:
        emit_event(
            "file_progress",
            written=written,
            total=total,
        )

    def on_file_done(self, remote_path: str, local_path: Path, size: int) -> None:
        emit_event(
            "file_done",
            remote=remote_path,
            local=str(local_path),
            name=local_name(remote_path),
            size=size,
        )

    def on_complete(self, result: ImportResult) -> None:
        if any("cancelled" in item for item in result.stats.failed):
            self.on_cancelled(result.stats)
            return
        if not result.ok:
            emit_event(
                "error",
                message="; ".join(result.stats.failed) or "import failed",
                **import_result_to_dict(result),
            )
            return
        emit_event("complete", **import_result_to_dict(result))

    def on_cancelled(self, stats: ImportStats) -> None:
        emit_event(
            "cancelled",
            downloaded_files=stats.downloaded_files,
            downloaded_bytes=stats.downloaded_bytes,
            stats=stats_to_dict(stats),
        )


def files_payload(files: List[str]) -> Dict[str, Any]:
    mp4_files = [path for path in files if is_mp4(path)]
    return {
        "ok": True,
        "count": len(files),
        "mp4_count": len(mp4_files),
        "files": files,
        "mp4_files": mp4_files,
    }
