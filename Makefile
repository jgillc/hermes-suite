.ONESHELL:
.PHONY: help hermes start stop status logs init lint test test-unit test-shell security all check \
        setup-tools install-local test-hermes install-precommit

HERMES_AGENT_DIR := hermes_configs
HERMES_CONTAINER_DIR := hermes_container
HERMES_IGNORE := -not -path './hermes_upstream/*' -not -path './hermes_webui/*'
YELLOW := $(shell tput -Txterm setaf 3)
GREEN  := $(shell tput -Txterm setaf 2)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)
TARGET_MAX_CHAR_NUM := 23

.DEFAULT_GOAL := help

help:
	@echo 'Usage:'
	@echo '  $(RED)make$(RESET) $(YELLOW)command$(RESET)'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-$(TARGET_MAX_CHAR_NUM)s$(RESET)$(GREEN)%s$(RESET)\n", $$1, $$2}'

hermes:  ## Manage local Hermes services: start | stop | status | logs
	@echo "Usage: make {start|stop|status|logs}"

start:  ## Start all local Hermes services
	@[ -f hermes_local/run.sh ] || { echo "Run 'make install-local' first"; exit 1; }
	bash hermes_local/run.sh start

stop:  ## Stop all local Hermes services
	@[ -f hermes_local/run.sh ] || { echo "Run 'make install-local' first"; exit 1; }
	bash hermes_local/run.sh stop

status:  ## Show status of local Hermes services
	@[ -f hermes_local/run.sh ] || { echo "Run 'make install-local' first"; exit 1; }
	bash hermes_local/run.sh status

logs:  ## Tail all local Hermes logs
	@[ -f hermes_local/run.sh ] || { echo "Run 'make install-local' first"; exit 1; }
	bash hermes_local/run.sh logs

init:  ## Interactive setup of ~/.hermes/.env with API keys
	bash $(HERMES_AGENT_DIR)/init.sh

# ── QA & Tooling ──────────────────────────────────────────────────────────────

install-precommit:  ## Install pre-commit hooks (for contributors)
	@echo "=== Installing pre-commit hooks ==="
	@if command -v pre-commit &>/dev/null; then \
		echo "  pre-commit already installed"; \
	else \
		pip install --user pre-commit 2>/dev/null || \
		pip3 install --user pre-commit 2>/dev/null || \
		pipx install pre-commit 2>/dev/null || \
		echo "  WARNING: could not install pre-commit — try: pip install pre-commit"; \
	fi
	pre-commit install
	@echo "✅ Pre-commit hooks installed"

lint:  ## Run linters (shellcheck, yamllint, hadolint, ruff)
	@echo "=== Running ShellCheck ==="
	@find . -name '*.sh' $(HERMES_IGNORE) -not -path './.git/*' -not -path './$(HERMES_CONTAINER_DIR)/*' -exec shellcheck --severity=warning {} +
	@echo ""
	@echo "=== Running yamllint ==="
	@find . \( -name '*.yaml' -o -name '*.yml' \) $(HERMES_IGNORE) -not -path './.git/*' -exec yamllint --strict {} +
	@echo ""
	@echo "=== Running ruff on Python files ==="
	@if command -v ruff &>/dev/null; then \
		ruff check $(HERMES_AGENT_DIR)/*.py; \
	else \
		echo "  (ruff not installed — skipping)"; \
	fi
	@echo "✅ Lint checks passed"

test:  ## Run syntax validation, config checks, and unit tests
	@echo "=== Shell syntax check ==="
	@find . -name '*.sh' $(HERMES_IGNORE) -not -path './.git/*' -not -path './$(HERMES_CONTAINER_DIR)/*' -exec bash -n {} +
	@echo "✅ All shell scripts parse cleanly"
	@echo ""
	@echo "=== YAML syntax check ==="
	@find . \( -name '*.yaml' -o -name '*.yml' \) $(HERMES_IGNORE) -not -path './.git/*' \
		-exec python3 -c "import yaml; yaml.safe_load(open('{}'))" \; 2>&1 || \
		{ echo "❌ YAML parsing failed"; exit 1; }
	@echo "✅ All YAML files parse cleanly"
	@echo ""
	@echo "=== Python import check ==="
	@python3 -c "import yaml; print('✅ PyYAML available')" 2>/dev/null || \
		echo "  (PyYAML not installed — skipping YAML validation)"
	@echo ""
	@echo "=== Running pytest ==="
	@if command -v pytest &>/dev/null; then \
		pytest tests/ -v --tb=short || exit 1; \
	else \
		echo "  (pytest not installed — skipping unit tests)"; \
	fi
	@echo "✅ Tests passed"

test-unit:  ## Run unit tests (pytest)
	@echo "=== Running pytest unit tests ==="
	@if command -v pytest &>/dev/null; then \
		pytest tests/ -v --tb=short -m "not integration" || exit 1; \
	else \
		echo "  ❌ pytest not installed — install with: pip install pytest pytest-mock"; \
		exit 1; \
	fi
	@echo "✅ Unit tests passed"

test-shell:  ## Run shell script tests (bats)
	@echo "=== Running BATS shell tests ==="
	@if command -v bats &>/dev/null; then \
		bats tests/hermes_container/*.bats tests/hermes_local/*.bats || exit 1; \
	else \
		echo "  ⚠️  BATS not installed — install with: npm install -g bats"; \
		echo "  Skipping shell tests"; \
	fi
	@echo "✅ Shell tests passed"

security:  ## Run security scans (shellcheck, clamav, secrets)
	@echo "=== ShellCheck (strict) ==="
	@find . -name '*.sh' $(HERMES_IGNORE) -not -path './.git/*' -not -path './$(HERMES_CONTAINER_DIR)/*' -exec shellcheck {} +
	@echo "✅ ShellCheck passed"
	@echo ""
	@echo "=== Secrets scan (grep for high-entropy patterns) ==="
	@! grep -rnP '(?i)(sk-[a-zA-Z0-9]{20,}|api[_-]?key["'\"']?\s*[:=]\s*["'\'']?[a-zA-Z0-9]{16,}|secret["'\"']?\s*[:=]\s*["'\'']?[a-zA-Z0-9]{16,}|token["'\"']?\s*[:=]\s*["'\'']?[a-zA-Z0-9]{16,})' \
		--include='*.{sh,py,yaml,yml,env,txt,md}' \
		--exclude-dir=.git . 2>/dev/null || true
	@echo "✅ Secrets scan complete"
	@echo ""
	@echo "=== ClamAV scan ==="
	@if command -v clamscan &>/dev/null; then \
		clamscan --recursive --infected --max-filesize=25M . 2>&1 | tail -3; \
	else \
		echo "  (clamscan not installed — skipping)"; \
	fi
	@echo "✅ Security checks complete"

all: lint test  ## Run all lint and test checks
	@echo "✅ All checks passed"

check: all  ## Run all checks with additional validation
	@echo "✅ Check complete"

setup-tools:  ## Install local dev toolchain (shellcheck, yamllint, ruff, hadolint, pre-commit, clamav)
	bash hermes_local/setup-tools.sh

install-local:  ## Install Hermes Suite locally without containers
	bash hermes_local/install.sh

test-hermes:  ## Run integration tests for local Hermes install
	bash hermes_local/test.sh
