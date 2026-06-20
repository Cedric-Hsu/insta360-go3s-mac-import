"""Import workflow: list remote files, dedupe, download MP4/LRV groups."""

from __future__ import annotations

import subprocess
from contextlib import nullcontext
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, List, Optional, Protocol, Tuple

from insta360_go3s_wifi.cancel import ImportCancelled, make_cancel_checker, raise_if_cancelled
from insta360_go3s_wifi.client import CameraClient, CameraConnectionError
from insta360_go3s_wifi.files import iter_mp4_groups, local_name
from insta360_go3s_wifi.index import ImportIndex
from insta360_go3s_wifi.network import DEFAULT_CAMERA_HOST, check_wifi_for_go3s, ping_host
from insta360_go3s_wifi.power import keep_system_awake, keep_system_awake_enabled


class DownloadProgress(Protocol):
    def on_file_start(self, remote_path: str, local_path: Path) -> None: ...

    def on_file_progress(self, written: int, total: Optional[int]) -> None: ...

    def on_file_done(self, remote_path: str, local_path: Path, size: int) -> None: ...


@dataclass
class ImportStats:
    remote_total: int = 0
    mp4_groups_total: int = 0
    skipped: int = 0
    downloaded_files: int = 0
    downloaded_bytes: int = 0
    failed: List[str] = field(default_factory=list)


@dataclass
class ImportResult:
    dest: Path
    stats: ImportStats
    imported_paths: List[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.stats.failed


class _NullProgress:
    def on_file_start(self, remote_path: str, local_path: Path) -> None:
        pass

    def on_file_progress(self, written: int, total: Optional[int]) -> None:
        pass

    def on_file_done(self, remote_path: str, local_path: Path, size: int) -> None:
        pass


def select_download_groups(
    remote_paths: List[str],
    index: ImportIndex,
    new_only: bool,
    remote_filter: Optional[set] = None,
) -> List[List[str]]:
    """Return MP4 groups that still need downloading."""
    groups = iter_mp4_groups(remote_paths)
    if remote_filter is not None:
        groups = [group for group in groups if group[0] in remote_filter]
    if not new_only:
        return groups

    pending: List[List[str]] = []
    for group in groups:
        mp4_remote = group[0]
        if index.is_imported_remote(mp4_remote):
            continue
        pending.append(group)
    return pending


def _scoped_groups(
    remote_paths: List[str],
    remote_filter: Optional[set],
) -> List[List[str]]:
    groups = iter_mp4_groups(remote_paths)
    if remote_filter is None:
        return groups
    return [group for group in groups if group[0] in remote_filter]


def ensure_wifi_ready(host: str = DEFAULT_CAMERA_HOST) -> None:
    ping = ping_host(host, count=1)
    if ping.ok:
        return

    wifi = check_wifi_for_go3s()
    detail = wifi.ssid or "unknown SSID"
    raise CameraConnectionError(
        f"Cannot reach camera at {host} ({ping.message}). "
        f"Connect Mac to GO 3S WiFi first (current: {detail})."
    )


def run_import(
    dest: Path,
    host: str = DEFAULT_CAMERA_HOST,
    new_only: bool = True,
    dry_run: bool = False,
    progress: Optional[DownloadProgress] = None,
    camera_factory: Optional[Callable[[], CameraClient]] = None,
    should_cancel: Optional[Callable[[], bool]] = None,
    remote_filter: Optional[set] = None,
) -> ImportResult:
    dest = dest.expanduser().resolve()
    dest.mkdir(parents=True, exist_ok=True)
    cancel = make_cancel_checker(should_cancel)

    if camera_factory is None:
        ensure_wifi_ready(host)

    index = ImportIndex.load(dest)
    stats = ImportStats()
    imported_paths: List[str] = []
    reporter = progress or _NullProgress()
    cancelled = False

    def _open_camera() -> CameraClient:
        camera = CameraClient(host=host)
        camera.open()
        return camera

    open_camera = camera_factory or _open_camera
    awake_ctx = keep_system_awake() if keep_system_awake_enabled() else nullcontext()
    with awake_ctx:
        camera = open_camera()
        try:
            raise_if_cancelled(cancel)
            remote_paths = camera.list_files()
            stats.remote_total = len(remote_paths)
            all_groups = iter_mp4_groups(remote_paths)
            stats.mp4_groups_total = len(all_groups)
            scoped = _scoped_groups(remote_paths, remote_filter)
            groups = select_download_groups(
                remote_paths,
                index,
                new_only=new_only,
                remote_filter=remote_filter,
            )
            if new_only:
                stats.skipped = len(scoped) - len(groups)
            else:
                stats.skipped = 0
            pending_file_count = sum(len(group) for group in groups)

            on_begin = getattr(reporter, "on_import_begin", None)
            if callable(on_begin):
                on_begin(pending_file_count, stats.mp4_groups_total)

            for group in groups:
                raise_if_cancelled(cancel)
                completed_in_group: List[Tuple[str, str, int, Path]] = []
                group_ok = True

                for remote_path in group:
                    raise_if_cancelled(cancel)
                    name = local_name(remote_path)
                    local_path = dest / name

                    if dry_run:
                        imported_paths.append(str(local_path))
                        continue

                    reporter.on_file_start(remote_path, local_path)
                    try:
                        ok = camera.download(
                            remote_path,
                            str(local_path),
                            progress_callback=reporter.on_file_progress,
                            should_cancel=cancel,
                        )
                    except CameraConnectionError as exc:
                        stats.failed.append(f"{remote_path}: {exc}")
                        group_ok = False
                        break

                    if not ok or not local_path.is_file():
                        if cancel():
                            cancelled = True
                            stats.failed.append("cancelled by user")
                        else:
                            stats.failed.append(f"{remote_path}: download incomplete")
                        group_ok = False
                        break

                    size = local_path.stat().st_size
                    completed_in_group.append((remote_path, name, size, local_path))
                    stats.downloaded_files += 1
                    stats.downloaded_bytes += size
                    reporter.on_file_done(remote_path, local_path, size)

                if dry_run:
                    continue

                if not group_ok:
                    break

                for remote_path, name, size, local_path in completed_in_group:
                    index.mark_imported(remote_path, name, size)
                    imported_paths.append(str(local_path))

                if stats.failed:
                    break
        except ImportCancelled:
            cancelled = True
            stats.failed.append("cancelled by user")
        finally:
            camera.close()

    if not dry_run and stats.downloaded_files:
        index.save()

    on_end = getattr(reporter, "on_cancelled", None) if cancelled else None
    if callable(on_end):
        on_end(stats)

    return ImportResult(dest=dest, stats=stats, imported_paths=imported_paths)


def reveal_in_finder(path: Path) -> None:
    """Reveal a file or folder in Finder (macOS)."""
    resolved = path.expanduser().resolve()
    subprocess.run(["open", "-R", str(resolved)], check=False)
