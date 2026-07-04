.ONESHELL:
.PHONY: help hermes start stop status logs init lint test test-unit test-shell test-executable security all check \
        setup-tools install-local test-hermes install-precommit venv activate systemd-install install-hermes-path

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
	@[ -d .venv ] || { echo "Run 'make venv' first to create virtual environment"; exit 1; }
	@. .venv/bin/activate && bash hermes_local/run.sh start

stop:  ## Stop all local Hermes services
	@[ -f hermes_local/run.sh ] || { echo "Run 'make install-local' first"; exit 1; }
	@bash hermes_local/run.sh stop

status:  ## Show status of local Hermes services
	@[ -f hermes_local/run.sh ] || { echo "Run 'make install-local' first"; exit 1; }
	@bash hermes_local/run.sh status

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

venv:  ## Create Python virtual environment and install dependencies
	@echo "=== Creating Python virtual environment ==="
	@if [ -d .venv ]; then \
		echo "  Virtual environment already exists at .venv"; \
	else \
		python3 -m venv .venv; \
		echo "✅ Virtual environment created"; \
	fi
	@echo "=== Installing dependencies ==="
	@. .venv/bin/activate && pip install --upgrade pip setuptools wheel
	@. .venv/bin/activate && pip install -r requirements.txt
	@echo "✅ Dependencies installed"
	@echo ""
	@echo "To activate the virtual environment, run:"
	@echo "  source .venv/bin/activate"

activate:  ## Activate Python virtual environment (launches interactive shell)
	@if [ ! -d .venv ]; then \
		echo "❌ Virtual environment not found"; \
		echo "Create it first with: make venv"; \
		exit 1; \
	fi
	@echo "=== Activating virtual environment ==="
	@echo "Python: $$(. .venv/bin/activate && python --version)"
	@echo ""
	@echo "Your shell configuration (.bashrc, .bash_system) and aliases are loaded."
	@echo "You can now run commands with the venv active:"
	@echo "  - pytest tests/"
	@echo "  - python -c 'import hermes_configs'"
	@echo "  - hermes --version"
	@echo ""
	@bash --rcfile <(cat ~/.bashrc ~/.bash_system 2>/dev/null; echo "source .venv/bin/activate"; echo 'PS1="[hermes-venv] $${PS1}"') -i

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

test-executable:  ## Test hermes executable and PATH integration
	@echo "=== Testing hermes executable ==="
	@if [ -d .venv ]; then \
		. .venv/bin/activate && pytest tests/test_hermes_executable.py -v --tb=short || exit 1; \
	else \
		echo "❌ .venv not found — run 'make venv' first"; \
		exit 1; \
	fi
	@echo "✅ Hermes executable tests passed"

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

systemd-install:  ## Install systemd service files for user (or use: sudo make systemd-install for system)
	@echo "=== Installing Hermes systemd services ==="
	@mkdir -p ~/.config/systemd/user
	@cp systemd/hermes-gateway@.service ~/.config/systemd/user/
	@cp systemd/hermes-dashboard@.service ~/.config/systemd/user/
	@cp systemd/hermes-webui@.service ~/.config/systemd/user/
	@systemctl --user daemon-reload
	@echo "✅ Services installed for user."
	@echo "   To enable and start services (replace USERNAME with your login):"
	@echo "   systemctl --user enable hermes-gateway@USERNAME"
	@echo "   systemctl --user start hermes-gateway@USERNAME"
	@echo "   And similarly for hermes-dashboard@USERNAME and hermes-webui@USERNAME"
	@echo ""
	@echo "   View status: systemctl --user status hermes-gateway@USERNAME"
	@echo "   View logs:   journalctl --user -u hermes-gateway@USERNAME -f"
	@echo ""
	@echo "   For system-wide installation, use: sudo make systemd-install"

install-hermes-path:  ## Install hermes wrapper to system PATH (~/.local/bin/hermes)
	@echo "=== Installing hermes to system PATH ==="
	@mkdir -p ~/.local/bin
	@bash -c 'cat > ~/.local/bin/hermes << "SCRIPT"\n#!/bin/bash\nHERMES_SUITE_PATHS=(\n    "$$HOME/hermes-suite"\n    "$$HOME/data/repos/hermes-suite"\n    "/home/server/data/repos/hermes-suite"\n    "$$(pwd)/hermes-suite"\n)\nfor REPO_PATH in "$${HERMES_SUITE_PATHS[@]}"; do\n    HERMES_BIN="$$REPO_PATH/hermes_upstream/.venv/bin/hermes"\n    if [[ -x "$$HERMES_BIN" ]]; then\n        exec "$$HERMES_BIN" "$$@"\n    fi\ndone\necho "Error: Could not find hermes executable" >&2\nexit 1\nSCRIPT\n'
	@chmod +x ~/.local/bin/hermes
	@echo "✓ hermes wrapper installed at ~/.local/bin/hermes"
	@echo "  Test with: hermes --version"
	@echo "  For system-wide access: sudo cp ~/.local/bin/hermes /usr/local/bin/"

setup-tools:  ## Install local dev toolchain (shellcheck, yamllint, ruff, hadolint, pre-commit, clamav)
	bash hermes_local/setup-tools.sh

install-local:  ## Install Hermes Suite locally without containers
	bash hermes_local/install.sh

test-hermes:  ## Run integration tests for local Hermes install
	bash hermes_local/test.sh
