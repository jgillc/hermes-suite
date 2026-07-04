#!/usr/bin/env python3
"""
In-container hot-reload watcher for Hermes config files.

Monitors config.yaml and .env for changes by polling mtime.
When a change is detected, clears the config cache and reloads
environment variables — no gateway restart needed.

Runs as a background process inside the container via `podman exec -d`.
Managed from the host via `make start-hot-reload` / `make stop-hot-reload`.
"""

import os
import sys
import time
import logging

HERMES_HOME = os.environ.get('HERMES_HOME', '/opt/data')
POLL_INTERVAL = int(os.environ.get('HERMES_HOT_RELOAD_INTERVAL', '5'))
CONFIG_FILE = os.path.join(HERMES_HOME, 'config.yaml')
ENV_FILE = os.path.join(HERMES_HOME, '.env')

LOG_FILE = os.path.join(HERMES_HOME, 'logs', 'hot-reload.log')
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='[hot-reload] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),
    ],
)
log = logging.getLogger(__name__)


def get_sig(path: str) -> tuple | None:
    try:
        st = os.stat(path)
        return (st.st_mtime_ns, st.st_size)
    except OSError:
        return None


def do_reload() -> None:
    try:
        sys.path.insert(0, '/opt/hermes')
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
        log.info("Reloaded: %d env var(s) updated", env_count)
    except Exception as e:
        log.error("Reload failed: %s", e)


def main() -> None:
    files = {
        CONFIG_FILE: get_sig(CONFIG_FILE),
        ENV_FILE: get_sig(ENV_FILE),
    }
    for f in files:
        if files[f] is not None:
            log.info("Watching: %s", f)
        else:
            log.warning("Not found: %s", f)

    if not any(files.values()):
        log.error("No files to watch — exiting")
        sys.exit(1)

    while True:
        time.sleep(POLL_INTERVAL)
        for path, last_sig in files.items():
            sig = get_sig(path)
            if sig is not None and sig != last_sig:
                files[path] = sig
                log.info("Change detected in %s", path)
                do_reload()
                break


if __name__ == '__main__':
    main()
