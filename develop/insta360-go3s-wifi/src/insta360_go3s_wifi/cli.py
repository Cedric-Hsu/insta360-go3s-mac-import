"""CLI entry point."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.progress import BarColumn, DownloadColumn, Progress, TextColumn, TransferSpeedColumn
from rich.table import Table

from insta360_go3s_wifi.client import CameraConnectionError, connected_camera
from insta360_go3s_wifi.diagnose import run_diagnose
from insta360_go3s_wifi.go3s_protocol import probe_tcp_handshake
from insta360_go3s_wifi.importer import reveal_in_finder, run_import
from insta360_go3s_wifi.index import ImportIndex
from insta360_go3s_wifi.network import DEFAULT_CAMERA_HOST, check_wifi_for_go3s
from insta360_go3s_wifi.progress_ui import RichImportProgress
from insta360_go3s_wifi.verify import run_probe, run_verify
from insta360_go3s_wifi.ui_cli import ui_app

app = typer.Typer(
    help="Unofficial GO 3S WiFi import tool for macOS.",
    no_args_is_help=True,
)
app.add_typer(ui_app, name="ui")
console = Console()


def _print_report(report) -> None:
    table = Table(title="Results")
    table.add_column("Step")
    table.add_column("Status")
    table.add_column("Detail")
    for step in report.steps:
        table.add_row(step.name, "PASS" if step.ok else "FAIL", step.detail)
    console.print(table)
    if report.downloaded_files:
        console.print("\nDownloaded:")
        for path in report.downloaded_files:
            console.print(f"  - {path}")


@app.command(name="import")
def import_files(
    dest: Path = typer.Argument(..., help="Local folder for imported media"),
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
    new_only: bool = typer.Option(
        True,
        "--new-only/--all",
        help="Only download clips not yet in the local index",
    ),
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        help="Show pending downloads without transferring files",
    ),
    open_finder: bool = typer.Option(
        False,
        "--open-finder",
        help="Reveal destination in Finder when finished",
    ),
) -> None:
    """Import MP4 (+ LRV) from the camera over WiFi."""
    dest = dest.expanduser()
    mode = "new clips only" if new_only else "all clips"
    console.print(f"[bold]Import[/bold] → {dest.resolve()} ({mode})")
    console.print(
        "Ensure Mac is on GO 3S WiFi and Action Pod Quick File Transfer is active.\n"
    )

    try:
        if dry_run:
            result = run_import(
                dest=dest,
                host=host,
                new_only=new_only,
                dry_run=True,
            )
        else:
            with Progress(
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                DownloadColumn(),
                TransferSpeedColumn(),
                console=console,
            ) as progress:
                result = run_import(
                    dest=dest,
                    host=host,
                    new_only=new_only,
                    progress=RichImportProgress(progress),
                )
    except CameraConnectionError as exc:
        console.print(f"[red]Error:[/red] {exc}")
        raise typer.Exit(code=1) from exc

    stats = result.stats
    console.print(
        f"\nRemote files: {stats.remote_total} | "
        f"MP4 groups: {stats.mp4_groups_total} | "
        f"Skipped: {stats.skipped} | "
        f"Downloaded: {stats.downloaded_files} file(s)"
    )
    if stats.downloaded_bytes:
        mb = stats.downloaded_bytes / (1024 * 1024)
        console.print(f"Transferred: {mb:.1f} MB")

    if dry_run:
        console.print(f"\n[dim]Dry run — would download {len(result.imported_paths)} file(s):[/dim]")
        for path in result.imported_paths[:20]:
            console.print(f"  - {path}")
        if len(result.imported_paths) > 20:
            console.print(f"  ... and {len(result.imported_paths) - 20} more")
    elif result.imported_paths:
        console.print("\nImported:")
        for path in result.imported_paths:
            console.print(f"  - {path}")

    if stats.failed:
        console.print("\n[red]Failures:[/red]")
        for item in stats.failed:
            console.print(f"  - {item}")

    if open_finder and not dry_run:
        reveal_in_finder(result.dest)
        console.print(f"\n[green]Opened[/green] {result.dest}")

    raise typer.Exit(code=0 if result.ok else 1)


@app.command()
def status(
    dest: Path = typer.Argument(..., help="Import destination folder"),
) -> None:
    """Show local import index summary."""
    dest = dest.expanduser().resolve()
    index = ImportIndex.load(dest)
    table = Table(title=f"Import index ({index.path})")
    table.add_column("Remote path")
    table.add_column("Local file")
    table.add_column("Size")
    for entry in index.files.values():
        size_mb = entry.size / (1024 * 1024)
        table.add_row(entry.remote_path, entry.local_name, f"{size_mb:.1f} MB")
    console.print(table)
    console.print(f"\nIndexed: {len(index.files)} file(s)")
    if index.updated_at:
        console.print(f"Updated: {index.updated_at}")


@app.command()
def diagnose(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Port and HTTP checks (TCP 6666, 80, osc/info)."""
    report = run_diagnose(host=host)
    table = Table(title="Diagnose")
    table.add_column("Status")
    table.add_column("Detail")
    for step in report.steps:
        table.add_row("PASS" if step.ok else "FAIL", step.message)
    console.print(table)
    raise typer.Exit(code=0 if report.passed else 1)


@app.command()
def probe(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Check WiFi, ping, and HTTP reachability (no TCP 6666)."""
    report = run_probe(host=host)
    _print_report(report)
    raise typer.Exit(code=0 if report.passed else 1)


@app.command("raw-tcp")
def raw_tcp(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
) -> None:
    """Send SYNC to TCP 6666 and print raw bytes returned (debug)."""
    sync_ok, summary, raw, banner_seen = probe_tcp_handshake(host)
    console.print(f"SYNC echo: {'yes' if sync_ok else 'no'}")
    if banner_seen:
        console.print("Banner seen: yes (GO 3S idle greeting; not a SYNC echo)")
    console.print(summary)
    if raw:
        console.print(f"Raw hex: {raw.hex(' ')}")
    raise typer.Exit(code=0 if sync_ok else 1)

@app.command("list")
def list_files(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
    limit: int = typer.Option(20, help="Max paths to print"),
) -> None:
    """List remote files via GET_FILE_LIST."""
    wifi = check_wifi_for_go3s()
    if wifi.ssid:
        console.print(f"WiFi: {wifi.ssid}")
    try:
        with connected_camera(host=host) as camera:
            files = camera.list_files()
    except CameraConnectionError as exc:
        console.print(f"[red]Error:[/red] {exc}")
        raise typer.Exit(code=1) from exc

    console.print(f"Total: {len(files)}")
    for path in files[:limit]:
        console.print(path)
    if len(files) > limit:
        console.print(f"... and {len(files) - limit} more")


@app.command()
def verify(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
    dest: Path = typer.Option(
        Path("./test-download"),
        help="Download directory for smallest MP4 test",
    ),
    skip_download: bool = typer.Option(
        False,
        "--skip-download",
        help="Only test network + file list",
    ),
    save_report: Optional[Path] = typer.Option(
        None,
        "--save-report",
        help="Append markdown summary to a file (e.g. ../../tests/GO3S_COMPAT.md)",
    ),
) -> None:
    """Run Phase 1 checklist: probe, TCP, list, optional download."""
    console.print("[bold]Phase 1 verification[/bold]")
    console.print("Ensure Mac is connected to GO 3S WiFi before continuing.\n")

    report = run_verify(
        host=host,
        download_dir=str(dest),
        skip_download=skip_download,
    )
    _print_report(report)

    markdown = report.to_markdown()
    console.print("\n[dim]Markdown summary:[/dim]\n")
    console.print(markdown)

    if save_report is not None:
        save_report.parent.mkdir(parents=True, exist_ok=True)
        with open(save_report, "a", encoding="utf-8") as handle:
            handle.write("\n")
            handle.write(markdown)
        console.print(f"[green]Appended report to[/green] {save_report}")

    raise typer.Exit(code=0 if report.passed else 1)


@app.command()
def download_test(
    host: str = typer.Option(DEFAULT_CAMERA_HOST, help="Camera IP"),
    dest: Path = typer.Option(Path("./test-download"), help="Output directory"),
) -> None:
    """Download smallest MP4 (+ LRV if present). Alias for verify without probe-only."""
    report = run_verify(host=host, download_dir=str(dest), skip_download=False)
    _print_report(report)
    raise typer.Exit(code=0 if report.passed else 1)


def main() -> None:
    app()


if __name__ == "__main__":
    main()
