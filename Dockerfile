# ─── MCP Gateway for Unraid - Build from source ──────────────────────
# Use this Dockerfile if docker/mcp-gateway is unavailable on Docker Hub.
# Based on the official docker/mcp-gateway build.
# =========================================================================

# Stage 1: Build the gateway binary
FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY . .
RUN go build -trimpath -ldflags "-s -w" -o /docker-mcp ./cmd/docker-mcp/

# Stage 2: Build the bridge tool
FROM golang:1.25-alpine AS bridge-builder
WORKDIR /app
COPY . .
RUN go build -trimpath -ldflags "-s -w" -o /docker-mcp-bridge ./tools/docker-mcp-bridge/

# Stage 3: Minimal runtime image
FROM alpine:3.23
RUN apk update && apk upgrade --no-cache && apk add --no-cache docker-cli socat jq curl wget
RUN mkdir -p /misc /config /secrets
COPY --from=builder /docker-mcp /
COPY --from=bridge-builder /docker-mcp-bridge /misc/
ENV DOCKER_MCP_IN_CONTAINER=1
ENTRYPOINT ["/docker-mcp", "gateway", "run"]
