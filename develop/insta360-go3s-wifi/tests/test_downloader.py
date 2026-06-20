import io
from pathlib import Path
from unittest.mock import MagicMock, patch

import http.client

from insta360_go3s_wifi.downloader import download_remote_file


class _FakeResponse:
    def __init__(self, status, headers, body: bytes):
        self.status = status
        self.headers = headers
        self._body = io.BytesIO(body)

    def read(self, size=-1):
        return self._body.read(size)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


def test_download_restarts_when_range_not_honored(tmp_path: Path):
    local_path = tmp_path / "clip.mp4"
    local_path.write_bytes(b"partial")

    body = b"full-file-content"
    response = _FakeResponse(
        http.client.OK,
        {"Content-Length": str(len(body))},
        body,
    )

    with patch("insta360_go3s_wifi.downloader.urlopen", return_value=response):
        ok = download_remote_file("/DCIM/VID_a.mp4", str(local_path))

    assert ok
    assert local_path.read_bytes() == body


def test_download_partial_content_appends(tmp_path: Path):
    local_path = tmp_path / "clip.mp4"
    local_path.write_bytes(b"part")

    body = b"-rest"
    total = len(b"part") + len(body)
    response = _FakeResponse(
        http.client.PARTIAL_CONTENT,
        {
            "Content-Range": f"bytes 4-{total - 1}/{total}",
            "Content-Length": str(len(body)),
        },
        body,
    )

    with patch("insta360_go3s_wifi.downloader.urlopen", return_value=response):
        ok = download_remote_file("/DCIM/VID_a.mp4", str(local_path))

    assert ok
    assert local_path.read_bytes() == b"part-rest"
