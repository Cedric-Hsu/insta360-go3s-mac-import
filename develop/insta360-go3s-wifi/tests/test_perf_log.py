"""Tests for performance logging."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from insta360_go3s_wifi import perf_log


@pytest.fixture
def perf_log_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    path = tmp_path / "perf.log"
    monkeypatch.setenv("INSTA360_PERF_LOG", "1")
    monkeypatch.setenv("INSTA360_PERF_LOG_PATH", str(path))
    perf_log._LOG_PATH = None
    return path


def test_log_event_writes_line(perf_log_file: Path) -> None:
    perf_log.log_event("test", "hello", extra={"n": 1})
    text = perf_log_file.read_text(encoding="utf-8")
    assert "[test] hello" in text
    assert '"n": 1' in text


def test_timed_step_records_duration(perf_log_file: Path) -> None:
    with perf_log.timed_step("test", "work", tag="a"):
        pass
    text = perf_log_file.read_text(encoding="utf-8")
    assert "work start" in text
    assert "work done" in text
    assert "duration_ms=" in text


def test_perf_disabled_skips_write(perf_log_file: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("INSTA360_PERF_LOG", "0")
    perf_log.log_event("test", "skipped")
    assert not perf_log_file.exists() or perf_log_file.read_text(encoding="utf-8") == ""


def test_default_log_path_under_library_logs() -> None:
    path = perf_log.default_log_path()
    assert path.name == "perf.log"
    assert "Insta360GO3SImport" in str(path)
