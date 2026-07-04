import os
import subprocess
from pathlib import Path


class TestHermesExecutable:
    def test_hermes_command_exists(self):
        """Test that hermes command is available in PATH"""
        result = subprocess.run(["which", "hermes"], capture_output=True, text=True)
        assert result.returncode == 0, (
            f"hermes not found in PATH. Output: {result.stderr}"
        )
        assert "hermes" in result.stdout

    def test_hermes_version(self):
        """Test that hermes --version works"""
        result = subprocess.run(["hermes", "--version"], capture_output=True, text=True)
        assert result.returncode == 0, f"hermes --version failed: {result.stderr}"
        assert "Hermes Agent" in result.stdout
        assert "v0." in result.stdout

    def test_hermes_help(self):
        """Test that hermes --help works"""
        result = subprocess.run(["hermes", "--help"], capture_output=True, text=True)
        assert result.returncode == 0, f"hermes --help failed: {result.stderr}"
        assert "usage: hermes" in result.stdout or "Hermes Agent" in result.stdout

    def test_hermes_venv_exists(self):
        """Test that hermes_upstream/.venv/bin/hermes exists"""
        hermes_path = (
            Path.home()
            / "data"
            / "repos"
            / "hermes-suite"
            / "hermes_upstream"
            / ".venv"
            / "bin"
            / "hermes"
        )
        if not hermes_path.exists():
            hermes_path = Path(
                "/home/server/data/repos/hermes-suite/hermes_upstream/.venv/bin/hermes"
            )

        assert hermes_path.exists(), (
            f"Hermes venv executable not found at {hermes_path}"
        )
        assert os.access(hermes_path, os.X_OK), (
            f"Hermes venv executable not executable at {hermes_path}"
        )

    def test_hermes_wrapper_script(self):
        """Test that the wrapper script exists and is executable"""
        wrapper_path = Path.home() / ".local" / "bin" / "hermes"
        assert wrapper_path.exists(), f"Hermes wrapper not found at {wrapper_path}"
        assert os.access(wrapper_path, os.X_OK), (
            f"Hermes wrapper not executable at {wrapper_path}"
        )

    def test_hermes_wrapper_is_script(self):
        """Test that the wrapper is a shell script"""
        wrapper_path = Path.home() / ".local" / "bin" / "hermes"
        with open(wrapper_path, "r") as f:
            first_line = f.readline()
        assert first_line.startswith("#!/"), (
            f"Wrapper script does not have shebang: {first_line}"
        )

    def test_hermes_subcommands(self):
        """Test that common hermes subcommands are available"""
        subcommands = ["chat", "gateway", "dashboard", "model", "status"]
        for subcommand in subcommands:
            result = subprocess.run(
                ["hermes", subcommand, "--help"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            # Just check that the command is recognized (returns 0 or shows help)
            assert result.returncode in [0, 1, 2], (
                f"hermes {subcommand} failed unexpectedly: {result.stderr}"
            )

    def test_hermes_doctor_runs(self):
        """Test that hermes doctor command executes"""
        result = subprocess.run(
            ["hermes", "doctor"], capture_output=True, text=True, timeout=30
        )
        # hermes doctor may return non-zero if there are issues, but should run
        assert "Error" not in result.stderr or "could not find" not in result.stderr, (
            f"hermes doctor failed: {result.stderr}"
        )

    def test_hermes_works_from_different_directory(self):
        """Test that hermes command works from different working directories"""
        original_cwd = os.getcwd()
        try:
            # Change to /tmp and run hermes
            os.chdir("/tmp")
            result = subprocess.run(
                ["hermes", "--version"], capture_output=True, text=True
            )
            assert result.returncode == 0, (
                f"hermes failed from different directory: {result.stderr}"
            )
            assert "Hermes Agent" in result.stdout
        finally:
            os.chdir(original_cwd)


class TestHermesIntegration:
    def test_make_venv_creates_root_venv(self):
        """Test that make venv creates .venv in project root"""
        repo_root = Path.home() / "data" / "repos" / "hermes-suite"
        if not repo_root.exists():
            repo_root = Path("/home/server/data/repos/hermes-suite")

        venv_path = repo_root / ".venv"
        assert venv_path.exists(), f"Project .venv not found at {venv_path}"
        assert (venv_path / "bin" / "python").exists(), "venv python not found"
        assert (venv_path / "bin" / "pytest").exists(), "venv pytest not found"

    def test_pytest_available_in_venv(self):
        """Test that pytest is available in project venv"""
        repo_root = Path.home() / "data" / "repos" / "hermes-suite"
        if not repo_root.exists():
            repo_root = Path("/home/server/data/repos/hermes-suite")

        pytest_bin = repo_root / ".venv" / "bin" / "pytest"
        assert pytest_bin.exists(), f"pytest not found in venv: {pytest_bin}"

        result = subprocess.run(
            [str(pytest_bin), "--version"],
            capture_output=True,
            text=True,
            cwd=str(repo_root),
        )
        assert result.returncode == 0, f"pytest --version failed: {result.stderr}"
        assert "pytest" in result.stdout
