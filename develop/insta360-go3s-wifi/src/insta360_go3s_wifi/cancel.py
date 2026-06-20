"""Cooperative import cancellation via flag file."""

from __future__ import annotations

import os
from typing import Callable, Optional


def cancel_flag_path() -> Optional[str]:
    return os.environ.get("INSTA360_CANCEL_FILE") or None


def is_cancel_requested() -> bool:
    path = cancel_flag_path()
    if not path:
        return False
    return os.path.exists(path)


def make_cancel_checker(
    override: Optional[Callable[[], bool]] = None,
) -> Callable[[], bool]:
    if override is not None:
        return override
    return is_cancel_requested


class ImportCancelled(RuntimeError):
    pass


def raise_if_cancelled(checker: Callable[[], bool]) -> None:
    if checker():
        raise ImportCancelled("Import cancelled by user")
