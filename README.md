# MCP Gateway for Unraid

[![Docker build & publish](https://github.com/wildfirebill-unraid/mcp-gateway-unraid/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/wildfirebill-unraid/mcp-gateway-unraid/actions/workflows/docker-publish.yml)
[![GitHub release](https://img.shields.io/github/v/tag/wildfirebill-unraid/mcp-gateway-unraid?label=release&sort=semver)](https://github.com/wildfirebill-unraid/mcp-gateway-unraid/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/wildfirebill-unraid/mcp-gateway-unraid?style=social)](https://github.com/wildfirebill-unraid/mcp-gateway-unraid/stargazers)
[![GitHub contributors](https://img.shields.io/github/contributors/wildfirebill-unraid/mcp-gateway-unraid)](https://github.com/wildfirebill-unraid/mcp-gateway-unraid/graphs/contributors)

Run a [Model Context Protocol (MCP)](https://spec.modelcontextprotocol.io/) Gateway on **Unraid** to let AI agents — Claude Desktop, VS Code, Cursor, and any MCP-compatible client — securely access Docker-hosted MCP tools across your LAN. Built from the official [docker/mcp-gateway](https://github.com/docker/mcp-gateway) source.

### Who Is This For

- **Unraid users** who want AI agent capabilities on their home server
- **Self-hosters** looking for a local, private MCP gateway instead of cloud-based AI tool access
- **Developers** running Claude Desktop, VS Code, or Cursor who need Docker-hosted MCP tools on their LAN
- **Docker users** deploying MCP servers in isolated containers managed by a lightweight gateway

```
AI Client ──→ MCP Gateway (Unraid container, port 8811) ──→ MCP Servers (isolated containers)
```

---

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Installation](#installation)
  - [Download Template](#method-1-download-template-recommended-for-unraid)
  - [Docker Compose](#method-2-docker-compose)
  - [Manual Docker Run](#method-3-manual-docker-run)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Authentication](#authentication)
  - [Available MCP Servers](#available-mcp-servers)
- [Adding Custom MCP Servers](#adding-custom-mcp-servers)
  - [Custom catalog.yaml](#option-1-custom-catalogyaml-recommended)
  - [file:// Server Definition](#option-2-file-server-definition)
  - [Companion Container](#option-3-companion-container)
- [Connecting AI Clients](#connecting-ai-clients)
  - [Claude Desktop](#claude-desktop)
  - [VS Code](#vs-code)
  - [Cursor](#cursor)
- [Architecture](#architecture)
- [Security](#security)
- [Build from Source](#build-from-source)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Quick Start

```bash
# 1. Clone and configure
git clone https://github.com/wildfirebill-unraid/mcp-gateway-unraid.git
cd mcp-gateway-unraid
cp .env.example .env

# 2. Set your MCP_GATEWAY_AUTH_TOKEN in .env
echo "MCP_GATEWAY_AUTH_TOKEN=mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0" >> .env

# 3. Start the gateway
docker compose up -d

# 4. Verify
curl http://localhost:8811/health

# 5. Connect your AI agent
curl -H "Authorization: Bearer mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0" http://localhost:8811/mcp
```

> Your AI clients connect to `http://<unraid-ip>:8811/mcp` with the `Authorization: Bearer <token>` header.

---

## Features

- **🔒 LAN-only by default** — all traffic stays on your local network
- **🔐 Bearer authentication** — every MCP request requires a token (`MCP_GATEWAY_AUTH_TOKEN`)
- **📦 Isolated containers** — each MCP server runs in its own Docker container with resource limits
- **🔌 Multiple transport modes** — `streaming` (recommended for LAN), `sse`, or `stdio`
- **🛡️ Secrets isolation** — API keys stored in a mounted `.env` file, never in environment variables
- **🧩 Dynamic catalog** — auto-pulls the Docker MCP catalog on start for discoverable tools
- **🖥️ Unraid ready** — download the XML template for one-click install (Community Apps listing coming soon)
- **🏗️ Builds from source** — no dependency on Docker Hub availability

---

## Installation

### Method 1: Download Template (recommended for Unraid)

> **Community Apps listing coming soon.** For now, install via the XML template in this repo.

1. Download the template: [`unraid/mcp-gateway-unraid.xml`](unraid/mcp-gateway-unraid.xml)
2. In Unraid, go to **Docker → Add Container → Template → Add Template**
3. Select the downloaded XML file
4. Set your **Auth Token** (`MCP_GATEWAY_AUTH_TOKEN` — required)
5. Click **Apply**

### Method 2: Docker Compose

```bash
git clone https://github.com/wildfirebill-unraid/mcp-gateway-unraid.git
cd mcp-gateway-unraid
cp .env.example .env
# Edit .env to set MCP_GATEWAY_AUTH_TOKEN and GATEWAY_SERVERS
docker compose up -d
```

### Method 3: Manual Docker Run

```bash
docker run -d \
  --name unraid-mcp-gateway \
  --restart unless-stopped \
  -e DOCKER_MCP_IN_CONTAINER=1 \
  -e MCP_GATEWAY_AUTH_TOKEN=mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0 \
  -e GATEWAY_SERVERS=fetch,duckduckgo \
  -p 8811:8811 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/user/appdata/mcp-gateway/secrets:/secrets:ro \
  ghcr.io/wildfirebill-unraid/mcp-gateway-unraid:latest
```

> The image is hosted on **GitHub Container Registry (ghcr.io)** — no Docker Hub account needed.

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `MCP_GATEWAY_AUTH_TOKEN` | *(auto-generated)* | Bearer token for endpoint authentication. **Required** for persistent client access. |
| `GATEWAY_TRANSPORT` | `streaming` | Transport protocol: `stdio`, `sse`, or `streaming` |
| `GATEWAY_PORT` | `8811` | Port the gateway listens on |
| `GATEWAY_SERVERS` | `fetch,duckduckgo` | Comma-separated list of MCP servers to enable |
| `GATEWAY_MEMORY` | `2Gb` | Memory limit per MCP server container |
| `GATEWAY_CPUS` | `1` | CPU cores per MCP server container |
| `GATEWAY_LOG_CALLS` | `true` | Log MCP tool calls to stdout |
| `GATEWAY_VERIFY_SIGNATURES` | `false` | Verify Docker MCP image signatures |
| `DOCKER_MCP_IN_CONTAINER` | `1` | **Must be set to 1** for Unraid / non-Docker-Desktop environments |

### Authentication

The gateway enforces Bearer token authentication on all endpoints except `/health`.

- Set `MCP_GATEWAY_AUTH_TOKEN` as an environment variable on the container
- If unset, a **random 50-character token** is generated on every container start (token changes on restart)
- Clients send the token in the `Authorization` header:

```
Authorization: Bearer mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

To persist the same token across restarts, set `MCP_GATEWAY_AUTH_TOKEN` in your Unraid template or `.env` file.

### Available MCP Servers

The gateway uses the [Docker MCP Catalog](https://hub.docker.com/mcp) which includes:

| Server | Description | Image |
|---|---|---|
| `fetch` | HTTP requests to fetch URLs | `docker/mcp-fetch` |
| `duckduckgo` | Web search | `docker/mcp-duckduckgo` |
| `filesystem` | Read/write access to mounted paths | `docker/mcp-filesystem` |
| `github-official` | GitHub API (issues, PRs, repos) | `docker/mcp-github` |
| `slack` | Slack workspace access | `docker/mcp-slack` |
| `postgres` | PostgreSQL database queries | `docker/mcp-postgres` |
| `notion` | Notion workspace tools | `docker/mcp-notion` |

Set via `GATEWAY_SERVERS=fetch,duckduckgo,filesystem,github-official`.

---

## Adding Custom MCP Servers

Beyond the catalog, the gateway supports three approaches for adding your own MCP servers.

### Option 1: Custom `catalog.yaml` (recommended)

Create a full catalog file that mixes Docker catalog servers with your own, then mount it into the container.

**1. Create `catalog.yaml`:**

For a **container-based** server (Docker image the gateway spawns):

```yaml
version: 3
name: docker-mcp
displayName: Docker MCP Catalog
servers:
  my-custom-server:
    description: "My custom MCP tool"
    title: "Custom Server"
    type: "server"
    image: "my-org/custom-mcp-server:v1"
    env:
      - name: "API_KEY"
        value: "{{my-custom-server.api_key}}"
    command:
      - "--transport=stdio"
    config:
      - name: "my-custom-server"
        description: "Server configuration"
        type: "object"
        properties:
          api_key:
            type: "string"
            description: "API key for the server"
        required: ["api_key"]
```

For an **HTTP-based** server (already running elsewhere on your network):

```yaml
  my-http-server:
    type: http
    url: "http://host.docker.internal:3000/mcp"
```

**2. Mount the catalog and update `docker-compose.yml`:**

```yaml
services:
  gateway:
    image: ghcr.io/wildfirebill-unraid/mcp-gateway-unraid:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./catalog.yaml:/mcp/catalog.yaml:ro     # <-- mount custom catalog
    command:
      - --catalog=/mcp/catalog.yaml              # <-- use it
      - --servers=fetch,duckduckgo,my-custom-server
      - --transport=streaming
      - --port=8811
```

The gateway spawns `my-custom-server` as a sibling container just like catalog servers — same resource limits, secrets injection, and lifecycle management.

### Option 2: `file://` Server Definition

Define a single server in a YAML file and reference it directly with `--server file://`.

**1. Create `my-server.yaml`:**

```yaml
registry:
  my-dev-server:
    description: "Development server"
    title: "Dev Server"
    type: "server"
    image: "myorg/dev-server:latest"
    tools:
      - name: "dev_tool"
    env:
      - name: "MY_KEY"
        value: "{{my-dev-server.my_key}}"
    config:
      - name: "my-dev-server"
        description: "Config"
        type: "object"
        properties:
          my_key:
            type: "string"
        required: ["my_key"]
```

**2. Mount and reference in `docker-compose.yml`:**

```yaml
services:
  gateway:
    image: ghcr.io/wildfirebill-unraid/mcp-gateway-unraid:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./my-server.yaml:/servers/my-server.yaml:ro
    command:
      - --server=file:///servers/my-server.yaml
      - --servers=fetch,duckduckgo,my-dev-server
      - --transport=streaming
      - --port=8811
```

The `--server file://` flag can be repeated and mixed with catalog servers.

### Option 3: Companion Container

Run your MCP server as its own container alongside the gateway. Connect clients directly to it (bypassing the gateway).

**Add to `docker-compose.yml`:**

```yaml
services:
  gateway:
    image: ghcr.io/wildfirebill-unraid/mcp-gateway-unraid:latest
    # ... existing gateway config ...

  my-local-server:
    image: my-org/custom-mcp-server:v1
    container_name: unraid-mcp-local
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - API_KEY=sk-custom-server-key-abc123
```

**Connect your AI client to the companion directly:**

```json
{
  "mcpServers": {
    "Local_Server": {
      "url": "http://192.168.1.100:3000/mcp"
    }
  }
}
```

**Trade-offs:**

| Approach | Lifecycle managed by gateway | Secrets injection | Resource limits | Best for |
|---|---|---|---|---|
| Custom catalog | ✅ | ✅ | ✅ | Servers you want fully managed |
| `file://` definition | ✅ | ✅ | ✅ | Adding one-off servers to an existing setup |
| Companion container | ❌ | ❌ (manual) | ❌ (manual) | Quick testing, HTTP-only servers, or when you can't containerize |

---

## Connecting AI Clients

All clients connect to `http://<unraid-ip>:8811/mcp` with the `Authorization: Bearer <token>` header.

### Claude Desktop

**Option A — URL connection (streaming):**

In `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "Unraid_Gateway": {
      "url": "http://192.168.1.100:8811/mcp",
      "headers": {
        "Authorization": "Bearer mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
      }
    }
  }
}
```

**Option B — Local Docker Desktop (for testing):**

```json
{
  "mcpServers": {
    "MCP_DOCKER": {
      "command": "docker",
      "args": ["mcp", "gateway", "run", "--transport", "streaming", "--port", "8811"]
    }
  }
}
```

### VS Code

In `.vscode/mcp.json`:

```json
{
  "servers": {
    "Unraid_Gateway": {
      "url": "http://192.168.1.100:8811/mcp",
      "headers": {
        "Authorization": "Bearer mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
      },
      "type": "sse"
    }
  }
}
```

### Cursor

**Settings → MCP → Add new MCP server:**

- **Name**: Unraid Gateway
- **Type**: `url`
- **URL**: `http://192.168.1.100:8811/mcp`
- **Headers**: `{"Authorization": "Bearer mcp_gateway_token_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"}`

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Unraid Server                                                    │
│                                                                   │
│  ┌─────────────────────┐      ┌────────────────────────────────┐ │
│  │  AI Client           │      │  MCP Gateway Container         │ │
│  │  (Claude / VS Code   │─────▶│  ghcr.io/.../mcp-gateway-unraid│ │
│  │   / Cursor)          │      │  Port 8811                     │ │
│  └─────────────────────┘      │  Auth: Bearer token             │ │
│                               │  Entrypoint: env-var to CLI     │ │
│                               └──────────┬─────────────────────┘ │
│                                          │                        │
│                               ┌──────────▼─────────────────────┐ │
│                               │  MCP Server Containers          │ │
│                               │  (fetch, duckduckgo,            │ │
│                               │   filesystem, github, etc.)     │ │
│                               │  Each gets: CPU/MEM limits,     │ │
│                               │  isolated networking            │ │
│                               └────────────────────────────────┘ │
│                                                                   │
│  /var/run/docker.sock ◄── gateway creates sibling containers      │
│  ./secrets/.env       ◄── API keys mounted read-only              │
└──────────────────────────────────────────────────────────────────┘
```

---

## Security

- **🔐 Bearer auth** — all MCP endpoints require a valid token
- **🏠 LAN-only** — gateway listens on your LAN, not exposed to the internet
- **📦 Container isolation** — each MCP server runs in its own container with resource limits
- **🔑 Secrets isolation** — credentials in a mounted `.env` file, never in process environment
- **🖼️ Image signatures** — optional image signature verification
- **🚫 No root** — MCP servers run with limited privileges
- **🔄 Auto-generated tokens** — if `MCP_GATEWAY_AUTH_TOKEN` is unset, a new random token is generated on each start

---

## Build from Source

The Dockerfile builds the gateway from the [official docker/mcp-gateway repository](https://github.com/docker/mcp-gateway):

```bash
docker build -t mcp-gateway-unraid:local .
```

This produces the same multi-stage build used in CI/CD and published to ghcr.io.

---

## Contributing

Contributions are welcome! Here's how to help:

1. **Report issues** — open a GitHub issue for bugs or feature requests
2. **Submit PRs** — fork the repo, make changes, and open a pull request
3. **Improve docs** — README updates, better examples, and troubleshooting tips are always appreciated

See the [open issues](https://github.com/wildfirebill-unraid/mcp-gateway-unraid/issues) for current tasks.

---

## FAQ / Troubleshooting

### Why do I get a `401 Unauthorized` error?

Your `MCP_GATEWAY_AUTH_TOKEN` is missing or doesn't match the client's `Authorization` header. Set a fixed token in the Unraid template and pass it as `Authorization: Bearer <token>` in every client request.

### Why does the gateway say "Docker Desktop is not running"?

This environment variable is missing. Set `DOCKER_MCP_IN_CONTAINER=1` on the container to tell the gateway it's running inside a Docker container on a Linux host (Unraid) rather than Docker Desktop.

### The gateway starts but tools fail to run. Why?

The Docker socket is not mounted. Mount `/var/run/docker.sock` so the gateway can create sibling MCP server containers.

### I can't connect to the gateway from another machine on my network. What's wrong?

Port 8811 is likely blocked by the Unraid firewall. Navigate to **Settings → Firewall** in Unraid and allow inbound TCP traffic on port 8811.

### My secrets/API keys aren't being loaded. How do I fix this?

Check that `./secrets/.env` exists, is readable, and follows the correct format (`KEY=VALUE` on each line). The file must be mounted into the container at `/secrets/.env`.

### Why did the catalog pull fail at startup?

The container started before your network interface was ready. Restart the container — the catalog pull is retried on each start.

### Why did my auth token change after restarting the container?

No `MCP_GATEWAY_AUTH_TOKEN` was set, so the gateway generated a random one. Set a fixed token in the Unraid template or `.env` file to keep it stable.

### How do I add a custom MCP server that isn't in the Docker MCP catalog?

See the [Adding Custom MCP Servers](#adding-custom-mcp-servers) section above for three approaches: custom `catalog.yaml`, `file://` definitions, or companion containers.

### Can I run this without Docker Desktop?

Yes — that's the point. Set `DOCKER_MCP_IN_CONTAINER=1` for Unraid and other non-Docker-Desktop Docker hosts.

### Is the gateway exposed to the internet by default?

No. It listens on the Unraid LAN interface (port 8811) by default. Do not port-forward this port unless you have additional security measures in place.

---

## Related Projects

- [docker/mcp-gateway](https://github.com/docker/mcp-gateway) — the official upstream gateway this image builds from
- [Docker MCP Toolkit & Catalog](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/) — official Docker MCP catalog documentation
- [Model Context Protocol](https://spec.modelcontextprotocol.io/) — the open standard this gateway implements
- [Claude Desktop](https://claude.ai/download) — AI desktop client with MCP support
- [VS Code MCP](https://code.visualstudio.com/docs/copilot/ai/mcp-servers) — using MCP servers in VS Code Copilot
- [Unraid Community Apps](https://unraid.net/community/apps) — one-click install templates for Unraid

---

## License

MIT — see [LICENSE](LICENSE).


