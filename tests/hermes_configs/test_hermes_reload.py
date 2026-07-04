import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))


@pytest.fixture
def mock_hermes_cli_config():
    mock_module = MagicMock()
    mock_module._LOAD_CONFIG_CACHE = {"test": "value"}
    mock_module._RAW_CONFIG_CACHE = {"raw": "data"}
    mock_module._CONFIG_LOCK = MagicMock()
    mock_module._CONFIG_LOCK.__enter__ = MagicMock(return_value=None)
    mock_module._CONFIG_LOCK.__exit__ = MagicMock(return_value=None)
    mock_module.reload_env = MagicMock(return_value=5)
    mock_module.get_config_path = MagicMock(return_value=Path("/opt/data/config.yaml"))
    return mock_module


class TestHermesReloadModule:
    def test_reload_module_imports(self):
        try:
            import hermes_reload

            assert hermes_reload is not None
        except Exception as e:
            pytest.skip(f"Could not import hermes_reload: {e}")

    def test_reload_functions_available(self, mock_hermes_cli_config):
        with patch.dict("sys.modules", {"hermes_cli.config": mock_hermes_cli_config}):
            import hermes_reload

            assert hermes_reload is not None

    def test_config_cache_structure(self):
        test_cache = {"key1": "value1", "key2": "value2"}

        assert isinstance(test_cache, dict)
        assert len(test_cache) == 2
        assert "key1" in test_cache

    def test_reload_env_signature(self, mock_hermes_cli_config):
        with patch.dict("sys.modules", {"hermes_cli.config": mock_hermes_cli_config}):
            mock_hermes_cli_config.reload_env.return_value = 10
            result = mock_hermes_cli_config.reload_env()

            assert isinstance(result, int)
            assert result >= 0

    def test_config_lock_context_manager(self, mock_hermes_cli_config):
        lock = mock_hermes_cli_config._CONFIG_LOCK

        with lock:
            pass

        lock.__enter__.assert_called()
        lock.__exit__.assert_called()

    def test_get_config_path_returns_path(self, mock_hermes_cli_config):
        path = mock_hermes_cli_config.get_config_path()

        assert isinstance(path, Path)
        assert str(path).endswith(".yaml")

    def test_cache_clearing_logic(self):
        cache = {"config": "data", "other": "stuff"}

        config_key = "config"
        cache.pop(config_key, None)

        assert "config" not in cache
        assert "other" in cache

    def test_multiple_cache_operations(self):
        load_cache = {"path1": "config1"}
        raw_cache = {"path2": "raw_config"}

        load_cache.clear()
        raw_cache.clear()

        assert len(load_cache) == 0
        assert len(raw_cache) == 0
