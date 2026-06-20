"""HTTP download from camera file server."""

from __future__ import annotations

import http.client
import os
from typing import Callable, Optional
from urllib.request import Request, urlopen

from insta360_go3s_wifi.files import remote_to_http_url

ProgressCallback = Callable[[int, Optional[int]], None]


def download_remote_file(
    remote_path: str,
    local_path: str,
    host: str = "192.168.42.1",
    progress_callback: Optional[ProgressCallback] = None,
    should_cancel: Optional[Callable[[], bool]] = None,
) -> bool:
    os.makedirs(os.path.dirname(os.path.abspath(local_path)), exist_ok=True)
    url = remote_to_http_url(remote_path, host=host)

    resume_from = 0
    if os.path.exists(local_path):
        resume_from = os.path.getsize(local_path)

    headers = {}
    if resume_from > 0:
        headers["Range"] = f"bytes={resume_from}-"

    request = Request(url, headers=headers, method="GET")
    with urlopen(request, timeout=120) as response:
        status = getattr(response, "status", http.client.OK)
        if resume_from > 0 and status != http.client.PARTIAL_CONTENT:
            resume_from = 0

        total_header = response.headers.get("Content-Range")
        total_size: Optional[int] = None
        if total_header and "/" in total_header:
            total_size = int(total_header.split("/")[-1])
        elif response.headers.get("Content-Length"):
            total_size = int(response.headers["Content-Length"]) + resume_from

        mode = "ab" if resume_from else "wb"
        written = resume_from
        with open(local_path, mode) as handle:
            while True:
                if should_cancel and should_cancel():
                    return False
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                handle.write(chunk)
                written += len(chunk)
                if progress_callback:
                    progress_callback(written, total_size)

    if not os.path.isfile(local_path):
        return False
    final_size = os.path.getsize(local_path)
    if final_size <= 0:
        return False
    if total_size is not None and final_size != total_size:
        return False
    return True
