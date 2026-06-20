from insta360_go3s_wifi.go3s_protocol import (
    CAMERA_PAGE_SIZE,
    Go3sSession,
    PKT_SYNC,
    SYNC_MAGIC,
    _payload_has_sync,
)


def test_payload_has_sync_exact():
    assert _payload_has_sync(PKT_SYNC)


def test_payload_has_sync_substring():
    assert _payload_has_sync(b"\x06\x00\x00syNceNdinSextra")


def test_list_files_range_follows_total(monkeypatch):
    session = Go3sSession(host="192.168.42.1")
    calls = []

    def fake_page(limit, start):
        calls.append((limit, start))
        if start == 0:
            return [f"/DCIM/f{i}.mp4" for i in range(100)], 275
        if start == 100:
            return [f"/DCIM/f{i}.mp4" for i in range(100, 200)], 275
        if start == 200:
            return [f"/DCIM/f{i}.mp4" for i in range(200, 275)], 275
        return [], 275

    monkeypatch.setattr(session, "list_files_page", fake_page)

    paths, total, has_more, next_start = session.list_files_range(
        start=0,
        page_size=CAMERA_PAGE_SIZE,
        max_pages=None,
    )

    assert total == 275
    assert len(paths) == 275
    assert has_more is False
    assert next_start == 275
    assert calls == [(CAMERA_PAGE_SIZE, 0), (CAMERA_PAGE_SIZE, 100), (CAMERA_PAGE_SIZE, 200)]


def test_list_files_range_first_page_has_more(monkeypatch):
    session = Go3sSession(host="192.168.42.1")

    def fake_page(limit, start):
        if start == 0:
            return [f"/DCIM/f{i}.mp4" for i in range(100)], 275
        return [], 275

    monkeypatch.setattr(session, "list_files_page", fake_page)

    paths, total, has_more, next_start = session.list_files_range(
        start=0,
        page_size=CAMERA_PAGE_SIZE,
        max_pages=1,
    )

    assert len(paths) == 100
    assert total == 275
    assert has_more is True
    assert next_start == 100
