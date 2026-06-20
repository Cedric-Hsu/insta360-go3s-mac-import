"""JSON commands consumed by the macOS SwiftUI app."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import typer

from insta360_go3s_wifi.client import CameraConnectionError
from insta360_go3s_wifi.json_api import emit_json
from insta360_go3s_wifi.network import DEFAULT_CAMERA_HOST
from insta360_go3s_wifi.perf_log import default_log_path, timed_step
from insta360_go3s_wifi.ui_bridge import (
    camera_summary,
    connection_diagnose,
    connection_status,
    index_status,
    list_remote_files,
    local_library,
    pending_import,
    run_import_json_events,
)

ui_app = typer.Typer(help="JSON API for the macOS UI (stdout only).")


@ui_app.command("perf-log-path")
def ui_perf_log_path() -> None:
    """Return the performance log file path."""
    emit_json({"ok": True, "path": str(default_log_path())})


@ui_app.command("connection")
def ui_connection(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Return WiFi / ping status as one JSON object."""
    with timed_step("ui_cli", "connection", host=host):
        emit_json(connection_status(host=host))


@ui_app.command("diagnose")
def ui_diagnose(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Run full connectivity checklist (WiFi, ping, TCP, HTTP)."""
    with timed_step("ui_cli", "diagnose", host=host):
        emit_json(connection_diagnose(host=host))


@ui_app.command("list-remote")
def ui_list_remote(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Return remote file list as JSON."""
    try:
        with timed_step("ui_cli", "list-remote", host=host):
            emit_json(list_remote_files(host=host))
    except CameraConnectionError as exc:
        emit_json({"ok": False, "error": str(exc)})
        raise typer.Exit(code=1) from exc


@ui_app.command("pending")
def ui_pending(
    dest: Path = typer.Argument(..., help="Import destination folder"),
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Return files that would be imported (--new-only dry run)."""
    try:
        with timed_step("ui_cli", "pending", host=host, dest=str(dest)):
            emit_json(pending_import(dest=dest, host=host))
    except CameraConnectionError as exc:
        emit_json({"ok": False, "error": str(exc)})
        raise typer.Exit(code=1) from exc


@ui_app.command("summary")
def ui_summary(
    dest: Path = typer.Argument(..., help="Import destination folder"),
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
    start: int = typer.Option(0, help="Remote file list offset"),
    page_size: int = typer.Option(100, help="Camera page size (max ~100)"),
    max_pages: Optional[int] = typer.Option(
        None,
        "--max-pages",
        help="Limit pages fetched; 1 = first page only for progressive UI load",
    ),
) -> None:
    """List remote MP4s and imported/pending split in one TCP session."""
    try:
        with timed_step(
            "ui_cli",
            "summary",
            host=host,
            dest=str(dest),
            start=start,
            page_size=page_size,
            max_pages=max_pages,
        ):
            emit_json(
                camera_summary(
                    dest=dest,
                    host=host,
                    start=start,
                    page_size=page_size,
                    max_pages=max_pages,
                )
            )
    except CameraConnectionError as exc:
        emit_json({"ok": False, "error": str(exc)})
        raise typer.Exit(code=1) from exc


@ui_app.command("import")
def ui_import(
    dest: Path = typer.Argument(..., help="Import destination folder"),
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
    new_only: bool = typer.Option(True, "--new-only/--all"),
    dry_run: bool = typer.Option(False, "--dry-run"),
    paths_file: Optional[Path] = typer.Option(
        None,
        "--paths-file",
        help="Text file with remote MP4 paths to import (one per line)",
    ),
) -> None:
    """Run import and stream NDJSON progress events, then a complete event."""
    remote_filter = None
    if paths_file is not None:
        lines = paths_file.read_text(encoding="utf-8").splitlines()
        remote_filter = {line.strip() for line in lines if line.strip()}
    try:
        with timed_step(
            "ui_cli",
            "import",
            host=host,
            dest=str(dest),
            new_only=new_only,
            dry_run=dry_run,
            paths_count=len(remote_filter) if remote_filter else 0,
        ):
            result = run_import_json_events(
                dest=dest,
                host=host,
                new_only=new_only,
                dry_run=dry_run,
                remote_filter=remote_filter,
            )
    except CameraConnectionError as exc:
        emit_json({"type": "error", "message": str(exc)})
        raise typer.Exit(code=1) from exc

    if not result.get("ok", False):
        raise typer.Exit(code=1)
    raise typer.Exit(code=0)


@ui_app.command("index")
def ui_index(
    dest: Path = typer.Argument(..., help="Import destination folder"),
) -> None:
    """Return local import index as JSON."""
    with timed_step("ui_cli", "index", dest=str(dest)):
        emit_json(index_status(dest=dest))


@ui_app.command("library")
def ui_library(
    dest: Path = typer.Argument(..., help="Import destination folder"),
) -> None:
    """Return local media files in the destination folder."""
    with timed_step("ui_cli", "library", dest=str(dest)):
        emit_json(local_library(dest=dest))
