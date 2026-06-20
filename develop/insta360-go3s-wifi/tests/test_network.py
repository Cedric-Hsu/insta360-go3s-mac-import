"""Tests for WiFi SSID helpers."""

from __future__ import annotations

from insta360_go3s_wifi.network import (
    check_wifi_for_go3s,
    clear_wifi_ssid_cache,
    get_current_wifi_ssid,
)


def test_check_wifi_redacted_ssid(monkeypatch):
    monkeypatch.setattr(
        "insta360_go3s_wifi.network.get_current_wifi_ssid",
        lambda: "<redacted>",
    )
    status = check_wifi_for_go3s()
    assert status.looks_like_go3s is True
    assert status.ssid == "<redacted>"


def test_ssid_cache_reuses_value(monkeypatch):
    clear_wifi_ssid_cache()
    calls = {"count": 0}

    def fake_resolve():
        calls["count"] += 1
        return "GO 3S TEST.OSC"

    monkeypatch.setattr("insta360_go3s_wifi.network._resolve_wifi_ssid", fake_resolve)
    assert get_current_wifi_ssid() == "GO 3S TEST.OSC"
    assert get_current_wifi_ssid() == "GO 3S TEST.OSC"
    assert calls["count"] == 1
