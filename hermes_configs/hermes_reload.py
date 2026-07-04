#!/usr/bin/env python3
"""Reload Hermes config and env from within the container.
Called by the host-side watch_config.sh poller via `podman exec`.
Clears the mtime-based config cache and re-reads .env so changes
take effect on the next agent turn without restarting the gateway.
"""

import sys

sys.path.insert(0, "/opt/hermes")

from hermes_cli.config import (
    reload_env,
    _LOAD_CONFIG_CACHE,
    _RAW_CONFIG_CACHE,
    get_config_path,
    _CONFIG_LOCK,
)

path_key = str(get_config_path())
with _CONFIG_LOCK:
    _LOAD_CONFIG_CACHE.pop(path_key, None)
    _RAW_CONFIG_CACHE.pop(path_key, None)

env_count = reload_env()
print(f"Config cache cleared, {env_count} env var(s) updated")
