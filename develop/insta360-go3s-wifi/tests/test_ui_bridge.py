from insta360_go3s_wifi.ui_bridge import (
    _diagnose_hint,
    _import_ready_from_steps,
    connection_diagnose,
    connection_status,
)
from insta360_go3s_wifi.network import ProbeResult


def test_connection_status_shape():
    payload = connection_status(host="127.0.0.1")
    assert "ok" in payload
    assert "ping_ok" in payload
    assert "tcp6666_ok" in payload


def test_import_ready_requires_link_and_probe():
    steps = [
        ProbeResult(ok=True, message="ping 192.168.42.1 OK"),
        ProbeResult(ok=True, message="TCP 192.168.42.1:6666 reachable"),
        ProbeResult(ok=True, message="TCP probe: bytes=12 sync=yes reset=no preview=..."),
        ProbeResult(ok=False, message="HTTP HEAD failed http://192.168.42.1/osc/info: timeout"),
    ]
    assert _import_ready_from_steps(steps) is True


def test_import_ready_false_without_probe():
    steps = [
        ProbeResult(ok=True, message="ping 192.168.42.1 OK"),
        ProbeResult(ok=False, message="TCP probe: connect failed"),
    ]
    assert _import_ready_from_steps(steps) is False


def test_diagnose_hint_for_ping_failure():
    steps = [ProbeResult(ok=False, message="ping 192.168.42.1 failed: timeout")]
    hint = _diagnose_hint(steps)
    assert "Action Pod" in hint or "开机" in hint


def test_diagnose_hint_when_all_pass():
    steps = [ProbeResult(ok=True, message="ping OK")]
    hint = _diagnose_hint(steps)
    assert "刷新" in hint


def test_connection_diagnose_shape():
    payload = connection_diagnose(host="127.0.0.1")
    assert "ok" in payload
    assert "steps" in payload
    assert "hint" in payload
    assert isinstance(payload["steps"], list)
