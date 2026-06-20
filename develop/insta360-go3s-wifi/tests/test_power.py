from unittest.mock import MagicMock, patch

from insta360_go3s_wifi.power import keep_system_awake, keep_system_awake_enabled


def test_keep_system_awake_enabled_default():
    with patch.dict("os.environ", {}, clear=True):
        assert keep_system_awake_enabled() is True


def test_keep_system_awake_disabled_by_env():
    with patch.dict("os.environ", {"INSTA360_KEEP_AWAKE": "0"}):
        assert keep_system_awake_enabled() is False


def test_keep_system_awake_spawns_caffeinate_on_darwin():
    proc = MagicMock()
    proc.poll.return_value = None
    with patch("insta360_go3s_wifi.power.platform.system", return_value="Darwin"):
        with patch("insta360_go3s_wifi.power.subprocess.Popen", return_value=proc) as popen:
            with keep_system_awake():
                popen.assert_called_once()
                args = popen.call_args[0][0]
                assert args[:2] == ["caffeinate", "-i"]
            proc.terminate.assert_called_once()
