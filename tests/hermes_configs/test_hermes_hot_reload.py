import sys
import time
import tempfile
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def mock_hermes_home(monkeypatch):
    with tempfile.TemporaryDirectory() as tmpdir:
        monkeypatch.setenv("HERMES_HOME", tmpdir)
        monkeypatch.setenv("HERMES_HOT_RELOAD_INTERVAL", "1")
        yield tmpdir


@pytest.fixture
def temp_files():
    with tempfile.TemporaryDirectory() as tmpdir:
        config_file = Path(tmpdir) / "config.yaml"
        env_file = Path(tmpdir) / ".env"
        config_file.write_text("test: config")
        env_file.write_text("TEST=value")
        yield {"config": config_file, "env": env_file, "dir": tmpdir}


class TestGetSig:
    def test_get_sig_returns_mtime_and_size(self, temp_files):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        sig = get_sig(str(temp_files["config"]))

        assert sig is not None
        assert isinstance(sig, tuple)
        assert len(sig) == 2
        assert isinstance(sig[0], int)
        assert isinstance(sig[1], int)

    def test_get_sig_handles_missing_file(self, mock_hermes_home):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        sig = get_sig("/nonexistent/path/file.txt")
        assert sig is None

    def test_get_sig_detects_file_changes(self, temp_files):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        sig1 = get_sig(str(temp_files["config"]))
        time.sleep(0.01)
        temp_files["config"].write_text("test: config\nmore: data")
        sig2 = get_sig(str(temp_files["config"]))

        assert sig1 != sig2

    def test_get_sig_file_info_consistency(self, temp_files):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        sig = get_sig(str(temp_files["config"]))
        stat = temp_files["config"].stat()

        mtime_ns, size = sig
        assert mtime_ns == stat.st_mtime_ns
        assert size == stat.st_size


class TestFileMonitoring:
    def test_multiple_file_signatures(self, temp_files):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        config_sig = get_sig(str(temp_files["config"]))
        env_sig = get_sig(str(temp_files["env"]))

        assert config_sig is not None
        assert env_sig is not None
        assert config_sig != env_sig

    def test_nonexistent_files_return_none(self, mock_hermes_home):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        sig1 = get_sig("/nonexistent/file1")
        sig2 = get_sig("/nonexistent/file2")

        assert sig1 is None
        assert sig2 is None


class TestEnvironmentIntegration:
    def test_get_sig_with_custom_hermes_home(self, temp_files):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        test_file = Path(temp_files["dir"]) / "test.env"
        test_file.write_text("KEY=value")

        sig = get_sig(str(test_file))

        assert sig is not None
        assert sig[1] == test_file.stat().st_size

    def test_file_modification_detection(self, temp_files):
        sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hermes_configs"))
        from hermes_hot_reload import get_sig

        original_sig = get_sig(str(temp_files["config"]))
        assert original_sig is not None

        time.sleep(0.01)
        temp_files["config"].write_text("modified content")

        new_sig = get_sig(str(temp_files["config"]))
        assert new_sig is not None
        assert original_sig != new_sig
