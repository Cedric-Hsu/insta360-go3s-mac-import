from pathlib import Path

from insta360_go3s_wifi.index import ImportIndex, index_path_for


def test_index_roundtrip(tmp_path: Path):
    dest = tmp_path / "Movies" / "GO3S"
    dest.mkdir(parents=True)
    index = ImportIndex.load(dest)
    index.mark_imported(
        "/DCIM/Camera01/VID_test.mp4",
        "VID_test.mp4",
        12345,
    )
    index.save()

    loaded = ImportIndex.load(dest)
    assert index_path_for(dest) == loaded.path
    assert loaded.is_imported("/DCIM/Camera01/VID_test.mp4") is False

    (dest / "VID_test.mp4").write_bytes(b"x" * 12345)
    assert loaded.is_imported("/DCIM/Camera01/VID_test.mp4") is True


def test_is_imported_requires_local_file(tmp_path: Path):
    dest = tmp_path / "dest"
    dest.mkdir()
    index = ImportIndex.load(dest)
    index.mark_imported("/DCIM/Camera01/a.mp4", "a.mp4", 100)
    assert index.is_imported("/DCIM/Camera01/a.mp4") is False

    (dest / "a.mp4").write_bytes(b"x" * 100)
    assert index.is_imported("/DCIM/Camera01/a.mp4") is True

    (dest / "a.mp4").unlink()
    assert index.is_imported("/DCIM/Camera01/a.mp4") is False


def test_is_imported_rejects_truncated_file(tmp_path: Path):
    dest = tmp_path / "dest"
    dest.mkdir()
    index = ImportIndex.load(dest)
    index.mark_imported("/DCIM/Camera01/a.mp4", "a.mp4", 100)
    (dest / "a.mp4").write_bytes(b"x" * 50)
    assert index.is_imported("/DCIM/Camera01/a.mp4") is False


def test_is_imported_remote_by_local_file_without_index(tmp_path: Path):
    dest = tmp_path / "dest"
    dest.mkdir()
    (dest / "VID_manual.mp4").write_bytes(b"x" * 500)
    index = ImportIndex.load(dest)
    remote = "/DCIM/Camera01/VID_manual.mp4"
    assert index.is_imported(remote) is False
    assert index.is_imported_remote(remote) is True
    assert remote in index.imported_mp4_paths([remote, "/DCIM/Camera01/VID_new.mp4"])


def test_load_corrupt_index_returns_empty(tmp_path: Path):
    dest = tmp_path / "dest"
    dest.mkdir()
    bad = dest / ".insta360-go3s-wifi" / "index.json"
    bad.parent.mkdir(parents=True)
    bad.write_text("{not json", encoding="utf-8")

    index = ImportIndex.load(dest)
    assert index.files == {}
