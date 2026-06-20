"""Rich progress adapter for import downloads."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from rich.progress import Progress, TaskID

from insta360_go3s_wifi.files import local_name


class RichImportProgress:
    def __init__(self, progress: Progress) -> None:
        self._progress = progress
        self._task: Optional[TaskID] = None

    def on_file_start(self, remote_path: str, local_path: Path) -> None:
        if self._task is not None:
            self._progress.remove_task(self._task)
        label = local_name(remote_path)
        self._task = self._progress.add_task(label, total=None)

    def on_file_progress(self, written: int, total: Optional[int]) -> None:
        if self._task is None:
            return
        self._progress.update(self._task, completed=written, total=total)

    def on_file_done(self, remote_path: str, local_path: Path, size: int) -> None:
        if self._task is None:
            return
        self._progress.update(self._task, completed=size, total=size)
