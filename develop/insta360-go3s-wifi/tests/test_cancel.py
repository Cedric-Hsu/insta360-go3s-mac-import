from unittest.mock import MagicMock

from insta360_go3s_wifi.client import CameraClient
from insta360_go3s_wifi.importer import run_import


def test_run_import_respects_cancel(tmp_path):
    dest = tmp_path / "imports"
    mp4 = "/DCIM/Camera01/VID_a.mp4"
    mp4_b = "/DCIM/Camera01/VID_b.mp4"
    finished: list[str] = []

    camera = MagicMock(spec=CameraClient)
    camera.list_files.return_value = [mp4, mp4_b]

    def _download(remote_path, local_path, progress_callback=None, should_cancel=None):
        from pathlib import Path

        Path(local_path).write_bytes(b"done")
        finished.append(remote_path)
        return True

    camera.download.side_effect = _download

    def cancel_before_second() -> bool:
        return len(finished) >= 1

    result = run_import(
        dest=dest,
        new_only=True,
        dry_run=False,
        camera_factory=lambda: camera,
        should_cancel=cancel_before_second,
    )

    assert len(finished) == 1
    assert any("cancelled" in item for item in result.stats.failed)
    assert result.stats.downloaded_files == 1
