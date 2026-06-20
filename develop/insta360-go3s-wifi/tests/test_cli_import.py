def test_cli_module_imports():
    import insta360_go3s_wifi.cli as cli

    assert cli.app is not None
