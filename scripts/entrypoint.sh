#!/bin/sh
# ─── MCP Gateway Entrypoint ──────────────────────────────────────────
# Pulls the default catalog on first start, then launches the gateway.

/docker-mcp catalog pull mcp/docker-mcp-catalog:latest 2>/dev/null || \
  echo "[entrypoint] Catalog pull skipped (will retry on restart)"

exec /docker-mcp gateway run "$@"
