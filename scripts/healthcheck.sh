#!/bin/bash
# Health check for MCP Gateway
# Returns 0 if gateway is healthy, 1 otherwise
HOST="${1:-localhost}"
PORT="${2:-8811}"
URL="http://${HOST}:${PORT}/health"

if command -v curl &>/dev/null; then
    status=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
elif command -v wget &>/dev/null; then
    status=$(wget -q -O /dev/null --server-response "$URL" 2>&1 | awk '/HTTP/{print $2}' | tail -1)
else
    echo "Neither curl nor wget found"
    exit 1
fi

if [ "$status" = "200" ]; then
    echo "MCP Gateway is healthy (HTTP $status)"
    exit 0
else
    echo "MCP Gateway is unhealthy (HTTP $status)"
    exit 1
fi
