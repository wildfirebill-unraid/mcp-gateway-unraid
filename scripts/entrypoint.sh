#!/bin/sh
# ─── MCP Gateway Entrypoint ──────────────────────────────────────────
# Pulls the default catalog on first start, then launches the gateway
# with args derived from GATEWAY_* environment variables.

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
[ "$GATEWAY_VERIFY_SIGNATURES" = "true" ] && set -- "$@" --verify-signatures

exec /docker-mcp "$@"
