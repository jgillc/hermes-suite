# Hermes Suite — Container to Local Migration

## Before: Containerized (Podman)

| Aspect | Detail |
|--------|--------|
| **Runtime** | Podman containers via `docker-compose.yaml` |
| **Agent** | `nousresearch/hermes-agent:v2026.6.19` — prebuilt image from Docker Hub |
| **WebUI** | Cloned inside the Dockerfile at build time |
| **Network** | Custom `agent_net` bridge (10.99.0.x) for multi-container comms |
| **Playwright** | Separate `mcr.microsoft.com/playwright` container at 10.99.0.20:9223 |
| **Config** | Host `~/.hermes/` bind-mounted into container at `/opt/data` |
| **Startup** | `make up` → `up.sh` → `podman-compose up -d` |
| **Teardown** | `make down` → `down.sh` → `podman-compose down` |
| **CDP URL** | `http://10.99.0.20:9223` (pointed at Playwright container) |
| **Env file** | `/home/server/.env_hermes` mounted into container |
| **Data dir** | `~/.hermes/` mounted as `/opt/data` inside container |
| **Services** | supervisord managed 3 processes inside single container |
| **Dev tools** | None — linting/testing only on host |
| **Ports** | Podman mapped 8642, 8787, 9119 to host |

## After: Local (Containerless)

| Aspect | Detail |
|--------|--------|
| **Runtime** | Native Python processes on host |
| **Agent** | Git clone `NousResearch/hermes-agent@v2026.6.19` → `uv venv` + `pip install -e .[all,...]` |
| **WebUI** | Git clone `nesquena/hermes-webui@v0.51.742` → separate venv |
| **Network** | Host networking — no bridge, no container orchestration |
| **Playwright** | Not running (CDP URL cleared to `''`) |
| **Config** | Direct `~/.hermes/` access (no bind mount) |
| **Startup** | `./hermes_local/run.sh start` → background processes via `nohup` |
| **Teardown** | `./hermes_local/run.sh stop` → `kill` |
| **CDP URL** | `''` (empty — browser tool disabled) |
| **Env file** | Copied from `/home/server/.env_hermes` → `~/.hermes/.env` |
| **Data dir** | `~/.hermes/` directly (no indirection) |
| **Services** | 3 independent background PIDs managed by `hermes_local/run.sh` |
| **Dev tools** | shellcheck, yamllint, ruff, pre-commit — fully installed via `hermes_local/setup-tools.sh` |
| **Ports** | Direct bind to host — WebUI 8787, Dashboard 9119 (no port mapping) |
| **Systemd** | User service installed at `~/.config/systemd/user/hermes-suite.service` |
| **Testing** | `hermes_local/test.sh` — 19 integration tests covering CLI, API, config, chat |

## Key Differences

1. **No container overhead** — faster startup, no image pulls, no compose orchestration
2. **Direct filesystem** — no bind mount permissions issues, no UID/GID remapping
3. **Dev toolchain** — linting, testing, pre-commit all work natively
4. **Playwright removed** — CDP URL cleared to avoid 10s timeout on tool init
5. **Config migrated** — v0 → v30, using new `providers:` section format
6. **Gateway auth locked down** — `GATEWAY_ALLOW_ALL_USERS=false`
7. **Process management** — simpler (nohup/PID files) vs supervisord in container

## Quick Commands Reference

```
# Container mode (old) — now at hermes_container/
cd hermes_container/
make up              # podman-compose up -d
make down            # podman-compose down
make logs            # podman logs
make rebuild         # rebuild image + restart

# Local mode (new) — at repo root
./hermes_local/run.sh start   # start gateway + dashboard + webui
./hermes_local/run.sh stop    # stop all services
./hermes_local/run.sh status  # check running PIDs
./hermes_local/run.sh logs    # tail all logs
make lint              # run linters
make test              # run syntax checks
./hermes_local/test.sh       # run 19 integration tests
```
