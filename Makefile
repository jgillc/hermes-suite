.ONESHELL:
.PHONY: help init-hermes up-hermes down-hermes logs-hermes build-hermes rebuild-hermes reload-hermes \
        src-sync-hermes src-push-hermes cheap-hermes normal-hermes grafana-up grafana-down

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

init-hermes:  ## Interactive setup of ~/.hermes/.env with API keys
	bash $(HERMES_AGENT_DIR)/init.sh

up-hermes: $(HERMES_AGENT_DIR)/config-free.yaml  ## Start hermes-suite (free-tier config, set up systemd service)
	mkdir -p ~/.hermes
	cp $(HERMES_AGENT_DIR)/config-free.yaml ~/.hermes/config.yaml
	printf '%s\n' "$(abspath $(HERMES_AGENT_DIR)/config-free.yaml)" > ~/.hermes/.last_config
	bash up.sh
	# Fix ownership so hermes user (container UID 1000) can access /opt/data
	@echo "Waiting for container..."
	@for i in 1 2 3 4 5; do podman exec hermes-suite test -d /opt/data 2>/dev/null && break; sleep 2; done
	podman exec -u 0 hermes-suite chown hermes:hermes /opt/data
	podman exec -u 0 hermes-suite chown -R hermes:hermes /opt/data
	bash $(HERMES_AGENT_DIR)/setup-hermes-service.sh

down-hermes:  ## Stop hermes-suite container
	bash down.sh

logs-hermes:  ## Show last 50 lines of hermes-suite logs
	podman logs hermes-suite --tail 50

build-hermes:  ## Build hermes-suite image
	bash build.sh

rebuild-hermes:  ## Rebuild and restart hermes-suite
	bash build.sh && bash up.sh

reload-hermes:  ## Reload .env and restart hermes-suite (no rebuild)
	podman restart hermes-suite

src-sync-hermes:  ## Extract /opt/hermes to host (~/hermes-agent-src/) for editing
	mkdir -p ~/hermes-agent-src; \
	podman cp hermes-suite:/opt/hermes/. ~/hermes-agent-src/
	@echo "Source extracted to ~/hermes-agent-src/ — edit files there, then run 'make src-push-hermes'"

src-push-hermes:  ## Push edited host files (~/hermes-agent-src/) back into the container
	podman cp ~/hermes-agent-src/. hermes-suite:/opt/hermes/
	@echo "Files pushed — run 'make reload-hermes' to restart the container"

cheap-hermes: $(HERMES_AGENT_DIR)/config-cheap.yaml  ## Apply cheap-tier config (~/.hermes/config.yaml) and restart
	mkdir -p ~/.hermes
	cp $(HERMES_AGENT_DIR)/config-cheap.yaml ~/.hermes/config.yaml
	printf '%s\n' "$(abspath $(HERMES_AGENT_DIR)/config-cheap.yaml)" > ~/.hermes/.last_config
	bash up.sh
	@echo "Waiting for container..."
	@for i in 1 2 3 4 5; do podman exec hermes-suite test -d /opt/data 2>/dev/null && break; sleep 2; done
	podman exec -u 0 hermes-suite chown hermes:hermes /opt/data
	podman exec -u 0 hermes-suite chown -R hermes:hermes /opt/data
	podman restart hermes-suite

normal-hermes: $(HERMES_AGENT_DIR)/config-normal.yaml  ## Apply normal/production config (~/.hermes/config.yaml) and restart
	mkdir -p ~/.hermes
	cp $(HERMES_AGENT_DIR)/config-normal.yaml ~/.hermes/config.yaml
	printf '%s\n' "$(abspath $(HERMES_AGENT_DIR)/config-normal.yaml)" > ~/.hermes/.last_config
	bash up.sh
	@echo "Waiting for container..."
	@for i in 1 2 3 4 5; do podman exec hermes-suite test -d /opt/data 2>/dev/null && break; sleep 2; done
	podman exec -u 0 hermes-suite chown hermes:hermes /opt/data
	podman exec -u 0 hermes-suite chown -R hermes:hermes /opt/data
	podman restart hermes-suite

grafana-up:  ## Start Grafana + Prometheus monitoring stack
	cd grafana_prometheus && docker compose up -d
	@echo "Grafana: http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"

grafana-down:  ## Stop Grafana + Prometheus monitoring stack
	cd grafana_prometheus && docker compose down
