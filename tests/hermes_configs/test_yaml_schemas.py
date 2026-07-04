import yaml
from pathlib import Path

import pytest


CONFIGS_DIR = Path(__file__).parent.parent.parent / "hermes_configs"


@pytest.fixture
def config_files():
    return {
        "free": CONFIGS_DIR / "config-free.yaml",
        "cheap": CONFIGS_DIR / "config-cheap.yaml",
        "normal": CONFIGS_DIR / "config-normal.yaml",
    }


@pytest.fixture
def load_config(config_files):
    def _load(name):
        with open(config_files[name]) as f:
            return yaml.safe_load(f)

    return _load


class TestConfigValidation:
    def test_all_configs_are_valid_yaml(self, config_files):
        for name, path in config_files.items():
            with open(path) as f:
                config = yaml.safe_load(f)
                assert config is not None, f"{name} config is empty"

    def test_config_has_required_sections(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            required_sections = [
                "model",
                "agent",
                "terminal",
                "compression",
                "display",
                "memory",
            ]
            for section in required_sections:
                assert section in config, f"{config_name} missing {section}"

    def test_model_section_is_valid(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            model = config.get("model", {})
            assert "provider" in model, f"{config_name} model missing provider"
            assert "context_length" in model or "max_tokens" in model

    def test_provider_references_are_valid(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            provider = config.get("model", {}).get("provider", "")

            if provider.startswith("custom:"):
                provider_name = provider.replace("custom:", "")
                custom_providers = config.get("custom_providers", [])
                provider_names = [p.get("name") for p in custom_providers]
                assert provider_name in provider_names, (
                    f"{config_name} references undefined custom provider {provider_name}"
                )

    def test_custom_providers_have_required_fields(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            custom_providers = config.get("custom_providers", [])
            for provider in custom_providers:
                assert "name" in provider
                assert "base_url" in provider
                assert "key_env" in provider
                assert "api_mode" in provider

    def test_agent_section_is_valid(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            agent = config.get("agent", {})
            assert isinstance(agent.get("max_turns"), int)
            assert agent.get("max_turns", 0) >= 1

    def test_terminal_backend_is_valid(self, load_config):
        valid_backends = ["local", "docker", "ssh", "kubernetes"]
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            terminal = config.get("terminal", {})
            backend = terminal.get("backend")
            assert backend in valid_backends, (
                f"{config_name} has invalid backend {backend}"
            )

    def test_compression_threshold_is_valid(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            compression = config.get("compression", {})
            if compression.get("enabled"):
                threshold = compression.get("threshold")
                assert (
                    isinstance(threshold, (int, float)) and 0.0 <= threshold <= 1.0
                ), f"{config_name} has invalid compression threshold {threshold}"

    def test_memory_settings_are_valid(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            memory = config.get("memory", {})
            assert isinstance(memory.get("memory_enabled"), bool)
            assert isinstance(memory.get("user_profile_enabled"), bool)

    def test_disabled_toolsets_are_list(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            agent = config.get("agent", {})
            disabled = agent.get("disabled_toolsets")
            if disabled is not None:
                assert isinstance(disabled, list)

    def test_display_skin_is_valid(self, load_config):
        valid_skins = ["mono", "color", "dark", "light", "slate", "default"]
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            display = config.get("display", {})
            skin = display.get("skin")
            if skin:
                assert skin in valid_skins, f"{config_name} has invalid skin {skin}"

    def test_stt_provider_is_valid(self, load_config):
        valid_providers = ["local", "openai", "google", "deepgram"]
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            stt = config.get("stt", {})
            provider = stt.get("provider")
            if provider:
                assert provider in valid_providers, (
                    f"{config_name} has invalid STT provider {provider}"
                )

    def test_fallback_providers_is_list(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            fallback = config.get("fallback_providers")
            if fallback is not None:
                assert isinstance(fallback, list)
                for provider in fallback:
                    assert "provider" in provider
                    assert "model" in provider

    def test_auxiliary_section_structure(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            auxiliary = config.get("auxiliary", {})
            if auxiliary:
                for key, value in auxiliary.items():
                    if isinstance(value, dict) and key != "curator":
                        if "provider" in value:
                            assert "model" in value

    def test_free_config_specific_validations(self, load_config):
        config = load_config("free")
        model = config.get("model", {})
        provider = model.get("provider", "")
        assert "opencode-zen" in provider or "openrouter" in provider, (
            "free config should use free providers"
        )

    def test_config_no_hardcoded_api_keys(self, config_files):
        for name, path in config_files.items():
            with open(path) as f:
                content = f.read()
                assert "sk-" not in content.lower()
                assert "sk_" not in content.lower()
                assert "api_key:" not in content.lower()
                assert "apikey:" not in content.lower()

    def test_config_terminal_cwd_is_valid_path(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)
            terminal = config.get("terminal", {})
            cwd = terminal.get("cwd")
            if cwd:
                assert isinstance(cwd, str)
                assert cwd.startswith("/") or cwd.startswith("~")

    def test_config_timeouts_are_positive(self, load_config):
        for config_name in ["free", "cheap", "normal"]:
            config = load_config(config_name)

            if "terminal" in config:
                timeout = config["terminal"].get("timeout")
                if timeout:
                    assert isinstance(timeout, int) and timeout > 0

            if "auxiliary" in config:
                for key, value in config["auxiliary"].items():
                    if isinstance(value, dict):
                        timeout = value.get("timeout")
                        if timeout:
                            assert isinstance(timeout, int) and timeout > 0
