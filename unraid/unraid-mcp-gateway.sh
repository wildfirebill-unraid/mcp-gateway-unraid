#!/bin/bash
# ─── MCP Gateway for Unraid - Manual Startup Script ─────────────────────
# Usage:
#   ./unraid-mcp-gateway.sh start   - Start the gateway container
#   ./unraid-mcp-gateway.sh stop    - Stop the gateway container
#   ./unraid-mcp-gateway.sh restart - Restart the gateway container
#   ./unraid-mcp-gateway.sh logs    - Follow gateway logs
#   ./unraid-mcp-gateway.sh status  - Check gateway status
#   ./unraid-mcp-gateway.sh tools   - List available MCP tools
# =========================================================================

CONTAINER_NAME="unraid-mcp-gateway"
IMAGE="docker/mcp-gateway:latest"
MCP_PORT="${MCP_PORT:-8811}"
MCP_TRANSPORT="${MCP_TRANSPORT:-streaming}"
MCP_SERVERS="${MCP_SERVERS:-fetch,duckduckgo}"
MCP_MEMORY="${MCP_MEMORY:-2Gb}"
MCP_CPUS="${MCP_CPUS:-1}"
MCP_SECRETS_DIR="${MCP_SECRETS_DIR:-/mnt/user/appdata/mcp-gateway/secrets}"
MCP_CONFIG_DIR="${MCP_CONFIG_DIR:-/mnt/user/appdata/mcp-gateway/config}"

ensure_dirs() {
    mkdir -p "$MCP_SECRETS_DIR" "$MCP_CONFIG_DIR"
}

cmd_start() {
    ensure_dirs
    echo "Starting MCP Gateway on port $MCP_PORT (transport: $MCP_TRANSPORT)..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -e DOCKER_MCP_IN_CONTAINER=1 \
        -p ${MCP_PORT}:${MCP_PORT} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$MCP_SECRETS_DIR":/secrets:ro \
        -v "$MCP_CONFIG_DIR":/config:ro \
        "$IMAGE" \
        /docker-mcp gateway run \
            --transport=$MCP_TRANSPORT \
            --port=$MCP_PORT \
            --servers=$MCP_SERVERS \
            --memory=$MCP_MEMORY \
            --cpus=$MCP_CPUS \
            --secrets=/secrets/.env \
            --log-calls=true \
            --verbose=false \
            --verify-signatures=false
    echo "Gateway started. AI clients can connect to http://$(hostname -I | awk '{print $1}'):$MCP_PORT/mcp"
}

cmd_stop() {
    echo "Stopping MCP Gateway..."
    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null
    echo "Gateway stopped."
}

cmd_logs() {
    docker logs -f "$CONTAINER_NAME"
}

cmd_status() {
    if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        echo "MCP Gateway is RUNNING"
        docker ps --filter name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "Connect your AI client to: http://<unraid-ip>:$MCP_PORT/mcp"
    else
        echo "MCP Gateway is NOT running"
    fi
}

cmd_tools() {
    docker exec "$CONTAINER_NAME" /docker-mcp tools ls 2>/dev/null || echo "Gateway not running."
}

case "${1:-status}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_stop; sleep 1; cmd_start ;;
    logs)    cmd_logs ;;
    status)  cmd_status ;;
    tools)   cmd_tools ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|tools}"
        exit 1
        ;;
esac
