.ONESHELL:
.PHONY: help init up down logs build rebuild reload \
        src-sync src-push grafana-up grafana-down \
        start-hot-reload stop-hot-reload

HERMES_AGENT_DIR := ../hermes_configs

help:
	@echo 'Usage:'
	@echo '  make <command>  (run from hermes_container/)'
	@echo ''
	@echo 'Container commands:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-23s %s\n", $$1, $$2}'

init:  ## Interactive setup of ~/.hermes/.env with API keys
	bash $(HERMES_AGENT_DIR)/init.sh

up:  ## Start hermes-suite (set up systemd service)
	bash up.sh

down:  ## Stop hermes-suite container
	bash down.sh

logs:  ## Show last 50 lines of hermes-suite logs
	bash logs.sh

build:  ## Build hermes-suite image
	bash build.sh

rebuild:  ## Rebuild and restart hermes-suite
	bash build.sh && bash up.sh

reload:  ## Hot-reload gateway services (no container restart)
	podman exec hermes-suite supervisorctl restart hermes-gateway

start-hot-reload:  ## Start in-container config file watcher
	@# Push scripts into container
	podman cp $(HERMES_AGENT_DIR)/hermes_hot_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null; \
	podman cp $(HERMES_AGENT_DIR)/hermes_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null; \
	-podman exec hermes-suite pkill -f "hermes_hot_reload.py" 2>/dev/null; \
	sleep 1; \
	podman exec -d hermes-suite /opt/hermes/.venv/bin/python3 /opt/hermes/scripts/hermes_hot_reload.py; \
	echo "[hot-reload] Started inside container"

stop-hot-reload:  ## Stop the in-container config file watcher
	@-podman exec hermes-suite pkill -f "hermes_hot_reload.py" 2>/dev/null && \
		echo "[hot-reload] Stopped" || echo "[hot-reload] Not running"

logs-hot-reload:  ## Show hot-reload watcher log (tail -20)
	@podman exec hermes-suite tail -20 /opt/data/logs/hot-reload.log 2>/dev/null || \
		echo "[hot-reload] No log file found"

src-sync:  ## Extract /opt/hermes to host (~/hermes-agent-src/) for editing
	mkdir -p ~/hermes-agent-src; \
	podman cp hermes-suite:/opt/hermes/. ~/hermes-agent-src/
	@echo "Source extracted to ~/hermes-agent-src/ — edit files there, then run 'make src-push'"

src-push:  ## Push edited host files (~/hermes-agent-src/) back into the container
	podman cp ~/hermes-agent-src/. hermes-suite:/opt/hermes/
	podman cp $(HERMES_AGENT_DIR)/hermes_hot_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null || true
	podman cp $(HERMES_AGENT_DIR)/hermes_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null || true
	@echo "Files pushed — run 'make reload' to hot-reload the gateway"

grafana-up:  ## Start Grafana + Prometheus monitoring stack
	cd grafana_prometheus && docker compose up -d
	@echo "Grafana: http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"

grafana-down:  ## Stop Grafana + Prometheus monitoring stack
	cd grafana_prometheus && docker compose down
