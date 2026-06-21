#!/bin/sh
# ─── MCP Gateway Entrypoint ──────────────────────────────────────────
# Pulls the default catalog on first start, then launches the gateway
# with args derived from GATEWAY_* environment variables.

# Source secrets if mounted (provides template values and MCP_GATEWAY_AUTH_TOKEN)
if [ -f /secrets/.env ]; then
  set -a
  . /secrets/.env
  set +a
fi

/docker-mcp catalog pull mcp/docker-mcp-catalog:latest 2>/dev/null || \
  echo "[entrypoint] Catalog pull skipped (will retry on restart)"

# Build gateway args from environment variables
set -- gateway run \
  --port "${GATEWAY_PORT:-8811}" \
  --transport "${GATEWAY_TRANSPORT:-streaming}"

if [ -n "$GATEWAY_SERVERS" ]; then
  OLD_IFS="$IFS"
  IFS=','
  for server in $GATEWAY_SERVERS; do
    set -- "$@" --servers "$server"
  done
  IFS="$OLD_IFS"
fi

[ -n "$GATEWAY_MEMORY" ] && set -- "$@" --memory "$GATEWAY_MEMORY"
[ -n "$GATEWAY_CPUS" ] && set -- "$@" --cpus "$GATEWAY_CPUS"
[ "$GATEWAY_LOG_CALLS" = "true" ] && set -- "$@" --log-calls
[ "$GATEWAY_VERBOSE" = "true" ] && set -- "$@" --verbose
[ "$GATEWAY_VERIFY_SIGNATURES" = "true" ] && set -- "$@" --verify-signatures
[ "$GATEWAY_BLOCK_NETWORK" = "true" ] && set -- "$@" --block-network

# Support custom catalogs — comma-separated paths each get their own --catalog flag.
# Docker MCP requires local file paths to be inside the catalogs directory,
# so we copy local files there and reference them by basename.
CATALOGS_DIR="${XDG_CONFIG_HOME:-$HOME/.docker}/mcp/catalogs"
if [ -n "$GATEWAY_CATALOG" ]; then
  OLD_IFS="$IFS"
  IFS=','
  for catalog in $GATEWAY_CATALOG; do
    if [ -f "$catalog" ]; then
      mkdir -p "$CATALOGS_DIR"
      cp "$catalog" "$CATALOGS_DIR/"
      set -- "$@" --catalog "$(basename "$catalog")"
    else
      set -- "$@" --catalog "$catalog"
    fi
  done
  IFS="$OLD_IFS"
fi

exec /docker-mcp "$@"
