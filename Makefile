.ONESHELL:
.PHONY: help init up down logs build rebuild reload \
        src-sync src-push grafana-up grafana-down \
        start-hot-reload stop-hot-reload

HERMES_AGENT_DIR := hermes_agent
YELLOW := $(shell tput -Txterm setaf 3)
GREEN  := $(shell tput -Txterm setaf 2)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)
TARGET_MAX_CHAR_NUM := 23

.DEFAULT_GOAL := help

help:
	@echo 'Usage:'
	@echo '  $(RED)make$(RESET) $(YELLOW)command$(RESET)'
	@echo 'Commands:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-$(TARGET_MAX_CHAR_NUM)s$(RESET)$(GREEN)%s$(RESET)\n", $$1, $$2}'

init:  ## Interactive setup of ~/.hermes/.env with API keys
	bash $(HERMES_AGENT_DIR)/init.sh

up:  ## Start hermes-suite (set up systemd service)
	mkdir -p ~/.hermes
	# Only seed config.yaml if it doesn't already exist — never overwrite dashboard edits
	test -f ~/.hermes/config.yaml || cp $(HERMES_AGENT_DIR)/config-free.yaml ~/.hermes/config.yaml
	bash up.sh
	# Fix ownership so hermes user (container UID 1000) can access /opt/data
	@echo "Waiting for container..."
	@for i in 1 2 3 4 5; do podman exec hermes-suite test -d /opt/data 2>/dev/null && break; sleep 2; done
	podman exec -u 0 hermes-suite chown hermes:hermes /opt/data
	podman exec -u 0 hermes-suite chown -R hermes:hermes /opt/data
	# Deploy hot-reload helper scripts into the container
	podman cp $(HERMES_AGENT_DIR)/hermes_hot_reload.py hermes-suite:/opt/hermes/scripts/
	podman cp $(HERMES_AGENT_DIR)/hermes_reload.py hermes-suite:/opt/hermes/scripts/
	bash $(HERMES_AGENT_DIR)/setup-hermes-service.sh

down:  ## Stop hermes-suite container
	bash down.sh

logs:  ## Show last 50 lines of hermes-suite logs
	podman logs hermes-suite --tail 50

build:  ## Build hermes-suite image
	bash build.sh

rebuild:  ## Rebuild and restart hermes-suite
	bash build.sh && bash up.sh

reload:  ## Hot-reload gateway services (no container restart)
	podman exec hermes-suite supervisorctl restart hermes-gateway

start-hot-reload:  ## Start in-container config file watcher (polls config.yaml / .env)
	@# Push scripts into container
	podman cp $(HERMES_AGENT_DIR)/hermes_hot_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null; \
	podman cp $(HERMES_AGENT_DIR)/hermes_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null; \
	# Kill any existing watcher first
	-podman exec hermes-suite pkill -f "hermes_hot_reload.py" 2>/dev/null; \
	sleep 1; \
	# Start watcher in background inside the container
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
	# Also push hot-reload helpers
	podman cp $(HERMES_AGENT_DIR)/hermes_hot_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null || true
	podman cp $(HERMES_AGENT_DIR)/hermes_reload.py hermes-suite:/opt/hermes/scripts/ 2>/dev/null || true
	@echo "Files pushed — run 'make reload' to hot-reload the gateway"

# Backward-compat aliases
init-hermes: init
up-hermes: up
down-hermes: down
logs-hermes: logs
build-hermes: build
rebuild-hermes: rebuild
reload-hermes: reload
src-sync-hermes: src-sync
src-push-hermes: src-push

grafana-up:  ## Start Grafana + Prometheus monitoring stack
	cd grafana_prometheus && docker compose up -d
	@echo "Grafana: http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"

grafana-down:  ## Stop Grafana + Prometheus monitoring stack
	cd grafana_prometheus && docker compose down
