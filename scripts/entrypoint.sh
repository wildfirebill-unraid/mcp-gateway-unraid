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
      echo "[entrypoint] WARNING: Catalog file '$catalog' not found — check mount paths"
    fi
  done
  IFS="$OLD_IFS"
fi

# Generate Docker MCP config file from known env vars for template resolution.
# This allows {{server-name.key_name}} templates in the catalog to resolve
# without requiring the Docker MCP secrets engine plugin.
# Mapping: env var → (server-name, key-name)
CONFIG_FILE="${CATALOGS_DIR}/config.yaml"
CONFIG_SERVERS=""
resolve_config() {
  local server="$1" key="$2" value="$3"
  [ -z "$value" ] && return
  CONFIG_SERVERS="${CONFIG_SERVERS} ${server}"
}
write_config() {
  mkdir -p "$CATALOGS_DIR"
  local servers_sorted
  servers_sorted=$(echo "${CONFIG_SERVERS}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  if [ -n "$servers_sorted" ]; then
    echo "servers:" > "$CONFIG_FILE"
    for srv in $servers_sorted; do
      echo "  $srv:" >> "$CONFIG_FILE"
      # Write all keys for this server
      case "$srv" in
        github-mcp)
          [ -n "${GITHUB_TOKEN:-}" ] && echo "    github_token: \"${GITHUB_TOKEN}\"" >> "$CONFIG_FILE"
          [ -n "${GITHUB_API_URL:-}" ] && echo "    github_api_url: \"${GITHUB_API_URL}\"" >> "$CONFIG_FILE"
          ;;
        email-mcp)
          [ -n "${SMTP_HOST:-}" ] && echo "    smtp_host: \"${SMTP_HOST}\"" >> "$CONFIG_FILE"
          [ -n "${SMTP_PORT:-}" ] && echo "    smtp_port: \"${SMTP_PORT}\"" >> "$CONFIG_FILE"
          [ -n "${SMTP_USER:-}" ] && echo "    smtp_user: \"${SMTP_USER}\"" >> "$CONFIG_FILE"
          [ -n "${SMTP_PASSWORD:-}" ] && echo "    smtp_password: \"${SMTP_PASSWORD}\"" >> "$CONFIG_FILE"
          [ -n "${SMTP_USE_TLS:-}" ] && echo "    smtp_use_tls: \"${SMTP_USE_TLS}\"" >> "$CONFIG_FILE"
          [ -n "${SMTP_FROM:-}" ] && echo "    smtp_from: \"${SMTP_FROM}\"" >> "$CONFIG_FILE"
          [ -n "${EMAIL_PATH:-}" ] && echo "    email_path: \"${EMAIL_PATH}\"" >> "$CONFIG_FILE"
          ;;
        influxdb-mcp)
          [ -n "${INFLUXDB_URL:-}" ] && echo "    influxdb_url: \"${INFLUXDB_URL}\"" >> "$CONFIG_FILE"
          [ -n "${INFLUXDB_TOKEN:-}" ] && echo "    influxdb_token: \"${INFLUXDB_TOKEN}\"" >> "$CONFIG_FILE"
          [ -n "${INFLUXDB_ORG:-}" ] && echo "    influxdb_org: \"${INFLUXDB_ORG}\"" >> "$CONFIG_FILE"
          ;;
        elasticsearch-mcp)
          [ -n "${ES_HOST:-}" ] && echo "    es_host: \"${ES_HOST}\"" >> "$CONFIG_FILE"
          [ -n "${ES_PORT:-}" ] && echo "    es_port: \"${ES_PORT}\"" >> "$CONFIG_FILE"
          ;;
        mongodb-mcp)
          [ -n "${MONGODB_URI:-}" ] && echo "    mongodb_uri: \"${MONGODB_URI}\"" >> "$CONFIG_FILE"
          [ -n "${MONGODB_DATABASE:-}" ] && echo "    mongodb_database: \"${MONGODB_DATABASE}\"" >> "$CONFIG_FILE"
          ;;
        mysql-mcp)
          [ -n "${MYSQL_HOST:-}" ] && echo "    mysql_host: \"${MYSQL_HOST}\"" >> "$CONFIG_FILE"
          [ -n "${MYSQL_PORT:-}" ] && echo "    mysql_port: \"${MYSQL_PORT}\"" >> "$CONFIG_FILE"
          [ -n "${MYSQL_USER:-}" ] && echo "    mysql_user: \"${MYSQL_USER}\"" >> "$CONFIG_FILE"
          [ -n "${MYSQL_PASSWORD:-}" ] && echo "    mysql_password: \"${MYSQL_PASSWORD}\"" >> "$CONFIG_FILE"
          [ -n "${MYSQL_DATABASE:-}" ] && echo "    mysql_database: \"${MYSQL_DATABASE}\"" >> "$CONFIG_FILE"
          ;;
        postgresql-mcp)
          [ -n "${PGHOST:-}" ] && echo "    pghost: \"${PGHOST}\"" >> "$CONFIG_FILE"
          [ -n "${PGPORT:-}" ] && echo "    pgport: \"${PGPORT}\"" >> "$CONFIG_FILE"
          [ -n "${PGUSER:-}" ] && echo "    pguser: \"${PGUSER}\"" >> "$CONFIG_FILE"
          [ -n "${PGPASSWORD:-}" ] && echo "    pgpassword: \"${PGPASSWORD}\"" >> "$CONFIG_FILE"
          [ -n "${PGDATABASE:-}" ] && echo "    pgdatabase: \"${PGDATABASE}\"" >> "$CONFIG_FILE"
          ;;
        redis-mcp)
          [ -n "${REDIS_HOST:-}" ] && echo "    redis_host: \"${REDIS_HOST}\"" >> "$CONFIG_FILE"
          [ -n "${REDIS_PORT:-}" ] && echo "    redis_port: \"${REDIS_PORT}\"" >> "$CONFIG_FILE"
          [ -n "${REDIS_PASSWORD:-}" ] && echo "    redis_password: \"${REDIS_PASSWORD}\"" >> "$CONFIG_FILE"
          [ -n "${REDIS_DB:-}" ] && echo "    redis_db: \"${REDIS_DB}\"" >> "$CONFIG_FILE"
          ;;
        memcached-mcp)
          [ -n "${MEMCACHED_HOST:-}" ] && echo "    memcached_host: \"${MEMCACHED_HOST}\"" >> "$CONFIG_FILE"
          [ -n "${MEMCACHED_PORT:-}" ] && echo "    memcached_port: \"${MEMCACHED_PORT}\"" >> "$CONFIG_FILE"
          ;;
      esac
    done
    set -- "$@" --config "$(basename "$CONFIG_FILE")"
  fi
}

# Register config sources from known env vars
resolve_config github-mcp github_token "${GITHUB_TOKEN:-}"
resolve_config github-mcp github_api_url "${GITHUB_API_URL:-}"
resolve_config email-mcp smtp_host "${SMTP_HOST:-}"
resolve_config email-mcp smtp_port "${SMTP_PORT:-}"
resolve_config email-mcp smtp_user "${SMTP_USER:-}"
resolve_config email-mcp smtp_password "${SMTP_PASSWORD:-}"
resolve_config email-mcp smtp_use_tls "${SMTP_USE_TLS:-}"
resolve_config email-mcp smtp_from "${SMTP_FROM:-}"
resolve_config email-mcp email_path "${EMAIL_PATH:-}"
resolve_config influxdb-mcp influxdb_url "${INFLUXDB_URL:-}"
resolve_config influxdb-mcp influxdb_token "${INFLUXDB_TOKEN:-}"
resolve_config influxdb-mcp influxdb_org "${INFLUXDB_ORG:-}"
resolve_config elasticsearch-mcp es_host "${ES_HOST:-}"
resolve_config elasticsearch-mcp es_port "${ES_PORT:-}"
resolve_config mongodb-mcp mongodb_uri "${MONGODB_URI:-}"
resolve_config mongodb-mcp mongodb_database "${MONGODB_DATABASE:-}"
resolve_config mysql-mcp mysql_host "${MYSQL_HOST:-}"
resolve_config mysql-mcp mysql_port "${MYSQL_PORT:-}"
resolve_config mysql-mcp mysql_user "${MYSQL_USER:-}"
resolve_config mysql-mcp mysql_password "${MYSQL_PASSWORD:-}"
resolve_config mysql-mcp mysql_database "${MYSQL_DATABASE:-}"
resolve_config postgresql-mcp pghost "${PGHOST:-}"
resolve_config postgresql-mcp pgport "${PGPORT:-}"
resolve_config postgresql-mcp pguser "${PGUSER:-}"
resolve_config postgresql-mcp pgpassword "${PGPASSWORD:-}"
resolve_config postgresql-mcp pgdatabase "${PGDATABASE:-}"
resolve_config redis-mcp redis_host "${REDIS_HOST:-}"
resolve_config redis-mcp redis_port "${REDIS_PORT:-}"
resolve_config redis-mcp redis_password "${REDIS_PASSWORD:-}"
resolve_config redis-mcp redis_db "${REDIS_DB:-}"
resolve_config memcached-mcp memcached_host "${MEMCACHED_HOST:-}"
resolve_config memcached-mcp memcached_port "${MEMCACHED_PORT:-}"

write_config

exec /docker-mcp "$@"
