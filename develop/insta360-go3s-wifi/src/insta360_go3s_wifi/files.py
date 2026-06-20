"""Remote file path helpers."""

from __future__ import annotations

import os
from typing import Iterable, List, Optional, Sequence, Tuple


def is_mp4(path: str) -> bool:
    return path.lower().endswith(".mp4")


def is_lrv(path: str) -> bool:
    return path.lower().endswith(".lrv")


def sibling_lrv(mp4_path: str) -> str:
    base, _ = os.path.splitext(mp4_path)
    return f"{base}.lrv"


def pick_smallest_mp4(paths: Sequence[str]) -> Optional[str]:
    mp4s = [p for p in paths if is_mp4(p)]
    if not mp4s:
        return None
    return min(mp4s, key=len)


def group_mp4_with_lrv(mp4_path: str, remote_paths: Iterable[str]) -> List[str]:
    """Return download list: MP4 plus matching LRV if present on camera."""
    remote_set = set(remote_paths)
    group = [mp4_path]
    lrv = sibling_lrv(mp4_path)
    if lrv in remote_set:
        group.append(lrv)
    return group


def iter_mp4_groups(remote_paths: Sequence[str]) -> List[List[str]]:
    """Build [mp4, lrv?] download groups for every MP4 on the camera."""
    remote_list = list(remote_paths)
    groups: List[List[str]] = []
    for path in remote_list:
        if is_mp4(path):
            groups.append(group_mp4_with_lrv(path, remote_list))
    return groups


def local_name(remote_path: str) -> str:
    return os.path.basename(remote_path.strip("/"))


def remote_to_http_url(remote_path: str, host: str = "192.168.42.1") -> str:
    if not remote_path.startswith("/"):
        remote_path = f"/{remote_path}"
    return f"http://{host}{remote_path}"
