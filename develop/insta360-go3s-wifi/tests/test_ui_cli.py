from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import typer

from insta360_go3s_wifi.importer import ImportResult, ImportStats
from insta360_go3s_wifi.ui_cli import ui_import


def test_ui_import_exits_nonzero_on_failure(tmp_path: Path, monkeypatch):
    dest = tmp_path / "imports"
    dest.mkdir()

    failed = ImportResult(
        dest=dest,
        stats=ImportStats(failed=["/DCIM/a.mp4: download incomplete"]),
    )

    monkeypatch.setattr(
        "insta360_go3s_wifi.ui_cli.run_import_json_events",
        lambda **kwargs: {"ok": False, "stats": {"failed": failed.stats.failed}},
    )

    with pytest.raises(typer.Exit) as exc:
        ui_import(dest=dest, host="192.168.42.1", new_only=True, dry_run=False, paths_file=None)

    assert exc.value.exit_code == 1
