from pathlib import Path

from insta360_go3s_wifi.files import group_mp4_with_lrv, iter_mp4_groups, local_name
from insta360_go3s_wifi.importer import select_download_groups
from insta360_go3s_wifi.index import ImportIndex


def test_local_name():
    assert local_name("/DCIM/Camera01/VID_test.mp4") == "VID_test.mp4"


def test_group_mp4_with_lrv():
    remote = [
        "/DCIM/Camera01/VID_a.mp4",
        "/DCIM/Camera01/VID_a.lrv",
        "/DCIM/Camera01/VID_b.mp4",
    ]
    assert group_mp4_with_lrv(remote[0], remote) == [remote[0], remote[1]]
    assert group_mp4_with_lrv(remote[2], remote) == [remote[2]]


def test_iter_mp4_groups():
    remote = [
        "/DCIM/Camera01/VID_a.mp4",
        "/DCIM/Camera01/VID_a.lrv",
        "/DCIM/Camera01/VID_b.mp4",
    ]
    groups = iter_mp4_groups(remote)
    assert len(groups) == 2
    assert groups[0] == [remote[0], remote[1]]


def test_select_download_groups_new_only(tmp_path: Path):
    dest = tmp_path / "imports"
    dest.mkdir()
    index = ImportIndex.load(dest)
    mp4 = "/DCIM/Camera01/VID_old.mp4"
    lrv = "/DCIM/Camera01/VID_old.lrv"
    new_mp4 = "/DCIM/Camera01/VID_new.mp4"

    (dest / "VID_old.mp4").write_bytes(b"x" * 10)
    index.mark_imported(mp4, "VID_old.mp4", 10)
    index.save()

    remote = [mp4, lrv, new_mp4]
    pending = select_download_groups(remote, index, new_only=True)
    assert pending == [[new_mp4]]


def test_select_download_groups_all(tmp_path: Path):
    dest = tmp_path / "imports"
    dest.mkdir()
    index = ImportIndex.load(dest)
    mp4 = "/DCIM/Camera01/VID_old.mp4"
    (dest / "VID_old.mp4").write_bytes(b"x" * 10)
    index.mark_imported(mp4, "VID_old.mp4", 10)

    remote = [mp4, "/DCIM/Camera01/VID_new.mp4"]
    pending = select_download_groups(remote, index, new_only=False)
    assert len(pending) == 2
