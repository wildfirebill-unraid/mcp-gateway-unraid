.PHONY: up down restart logs ps build test-env clean

# ─── Environment ──────────────────────────────────────────────────────
# Load .env if present
ifneq (,$(wildcard .env))
    include .env
    export
endif

# ─── Targets ──────────────────────────────────────────────────────────

## Start the MCP Gateway
up:
	docker compose up -d

## Stop the MCP Gateway
down:
	docker compose down

## Restart the MCP Gateway
restart: down up

## View gateway logs
logs:
	docker compose logs -f gateway

## Show container status
ps:
	docker compose ps

## Build the gateway image from source (if Docker Hub image unavailable)
build:
	docker compose build

## Quick test: call the health endpoint
test-env:
	@echo "=== MCP Gateway Health Check ==="
	@curl -s http://localhost:${GATEWAY_PORT:-8811}/health || echo "Gateway not running on port ${GATEWAY_PORT:-8811}"

## List available MCP tools via the gateway
test-tools:
	@echo "=== Listing MCP Tools ==="
	@docker exec unraid-mcp-gateway /docker-mcp tools ls

## Clean up stopped containers and volumes
clean:
	docker compose down -v
	docker system prune -f --filter label=app=mcp-gateway

## Copy .env.example if .env doesn't exist
setup:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env from .env.example. Edit it to configure your gateway."; \
	else \
		echo ".env already exists."; \
	fi
	@mkdir -p secrets config
	@echo "Directory structure ready."

## Edit configuration
edit:
	@${EDITOR:-vim} .env
