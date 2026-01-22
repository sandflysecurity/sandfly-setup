.PHONY: help init start stop logs clean node dev

SANDFLY_VERSION ?= 5.5.1
SANDFLY_IMAGE_BASE ?= quay.io/sandfly
SANDFLY_HOSTNAME ?= localhost

help: ## Show this help message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Sandfly (first time setup)
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Copy env.example to .env first"; \
		exit 1; \
	fi
	@mkdir -p sandfly-data/postgres sandfly-data/ssl
	@if [ ! -f sandfly-data/postgres.admin.password.txt ]; then \
		grep '^POSTGRES_PASSWORD=' .env | cut -d'=' -f2 > sandfly-data/postgres.admin.password.txt; \
	fi
	@docker compose up -d sandfly-postgres
	@docker compose --profile setup up sandfly-init
	@docker rm sandfly-init 2>/dev/null || true
	@echo "Initialization complete! Run 'make start' to start services."
	@echo "################################################################################"
	@printf 'Admin username: %s\n' "admin"
	@printf 'Admin password: %s\n' "$$(tr -d '\n' < sandfly-data/admin.password.txt)"
	@echo "################################################################################"

start: ## Start Sandfly services
	@if [ ! -f sandfly-data/config.server.json ]; then \
		echo "Error: Sandfly not initialized. Run 'make init' first"; \
		exit 1; \
	fi
	@docker compose up -d

logs: ## Show logs
	@docker compose logs -f

stop: ## Stop all services
	@docker compose down

clean: ## Remove all data and containers
	@read -p "Remove all data? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@docker compose down
	@sudo rm -rf sandfly-data

dev: ## Start development environment
	@$(MAKE) start
	@$(MAKE) node
