from pathlib import Path
from unittest.mock import MagicMock, patch

from insta360_go3s_wifi.client import CameraClient
from insta360_go3s_wifi.importer import run_import, select_download_groups
from insta360_go3s_wifi.index import ImportIndex


def test_run_import_dry_run(tmp_path: Path):
    dest = tmp_path / "imports"
    remote = [
        "/DCIM/Camera01/VID_a.mp4",
        "/DCIM/Camera01/VID_a.lrv",
        "/DCIM/Camera01/VID_b.mp4",
    ]

    camera = MagicMock(spec=CameraClient)
    camera.list_files.return_value = remote
    camera.download.return_value = True

    result = run_import(
        dest=dest,
        new_only=True,
        dry_run=True,
        camera_factory=lambda: camera,
    )

    assert result.ok
    assert result.stats.remote_total == 3
    assert result.stats.mp4_groups_total == 2
    assert len(result.imported_paths) == 3
    camera.download.assert_not_called()


def test_run_import_downloads_and_indexes(tmp_path: Path):
    dest = tmp_path / "imports"
    mp4 = "/DCIM/Camera01/VID_a.mp4"
    lrv = "/DCIM/Camera01/VID_a.lrv"

    camera = MagicMock(spec=CameraClient)
    camera.list_files.return_value = [mp4, lrv]

    def _download(
        remote_path: str,
        local_path: str,
        progress_callback=None,
        should_cancel=None,
    ) -> bool:
        Path(local_path).write_bytes(b"data")
        return True

    camera.download.side_effect = _download

    result = run_import(
        dest=dest,
        new_only=True,
        dry_run=False,
        camera_factory=lambda: camera,
    )

    assert result.ok
    assert result.stats.downloaded_files == 2
    assert (dest / "VID_a.mp4").is_file()
    assert (dest / "VID_a.lrv").is_file()
    assert (dest / ".insta360-go3s-wifi" / "index.json").is_file()


def test_lrv_failure_does_not_mark_mp4_imported(tmp_path: Path):
    dest = tmp_path / "imports"
    mp4 = "/DCIM/Camera01/VID_a.mp4"
    lrv = "/DCIM/Camera01/VID_a.lrv"

    camera = MagicMock(spec=CameraClient)
    camera.list_files.return_value = [mp4, lrv]

    def _download(remote_path, local_path, progress_callback=None, should_cancel=None):
        if remote_path.endswith(".mp4"):
            Path(local_path).write_bytes(b"mp4-data")
            return True
        return False

    camera.download.side_effect = _download

    result = run_import(
        dest=dest,
        new_only=True,
        dry_run=False,
        camera_factory=lambda: camera,
    )

    assert not result.ok
    index = ImportIndex.load(dest)
    assert not index.is_imported(mp4)
    assert (dest / "VID_a.mp4").is_file()


def test_remote_filter_skipped_count(tmp_path: Path):
    dest = tmp_path / "imports"
    remote = [
        "/DCIM/Camera01/VID_a.mp4",
        "/DCIM/Camera01/VID_b.mp4",
        "/DCIM/Camera01/VID_c.mp4",
    ]

    camera = MagicMock(spec=CameraClient)
    camera.list_files.return_value = remote

    result = run_import(
        dest=dest,
        new_only=True,
        dry_run=True,
        camera_factory=lambda: camera,
        remote_filter={remote[0]},
    )

    assert result.ok
    assert result.stats.mp4_groups_total == 3
    assert result.stats.skipped == 0
    assert len(result.imported_paths) == 1


def test_select_download_groups_respects_index(tmp_path: Path):
    dest = tmp_path / "imports"
    dest.mkdir()
    index = ImportIndex.load(dest)
    index.mark_imported("/DCIM/a.mp4", "a.mp4", 10)
    (dest / "a.mp4").write_bytes(b"x" * 10)

    remote = ["/DCIM/a.mp4", "/DCIM/b.mp4"]
    pending = select_download_groups(remote, index, new_only=True)
    assert pending == [["/DCIM/b.mp4"]]
