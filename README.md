# MCP Gateway for Unraid

A Docker-based [Model Context Protocol (MCP)](https://spec.modelcontextprotocol.io/) Gateway for Unraid.
Lets your AI agents (Claude, VS Code, Cursor, etc.) access MCP tools running in Docker containers —
all within your local network.

```
AI Client → MCP Gateway (container) → MCP Servers (containers)
```

## Quick Start

```bash
# 1. Create .env from template
cp .env.example .env

# 2. Start the gateway
docker compose up -d

# 3. Check it's running
curl http://localhost:8811/health
```

Your AI clients connect to `http://<unraid-ip>:8811/mcp`.

## Features

- **LAN-only by default** — all traffic stays on your network, no data leaves your LAN
- **Multiple transport modes** — `streaming` (recommended), `sse`, or `stdio`
- **Isolated servers** — each MCP tool runs in its own container with resource limits
- **Secrets management** — API keys stored in a mounted `.env` file, never in env vars
- **Works with any MCP client** — Claude Desktop, VS Code Agent, Cursor, and more
- **Docker Desktop compatible** — test locally before deploying to Unraid

## Configuration

### Environment Variables (`.env`)

| Variable | Default | Description |
|---|---|---|
| `GATEWAY_TRANSPORT` | `streaming` | Transport: `stdio`, `sse`, or `streaming` |
| `GATEWAY_PORT` | `8811` | Port the gateway listens on |
| `GATEWAY_SERVERS` | `fetch,duckduckgo` | Comma-separated MCP servers to enable |
| `GATEWAY_MEMORY` | `2Gb` | Memory per MCP server container |
| `GATEWAY_CPUS` | `1` | CPUs per MCP server container |
| `GATEWAY_LOG_CALLS` | `true` | Log tool calls |
| `GATEWAY_VERBOSE` | `false` | Verbose logging |
| `GATEWAY_VERIFY_SIGNATURES` | `false` | Verify MCP image signatures |
| `GATEWAY_BLOCK_NETWORK` | `false` | Block tool network access |

### Available MCP Servers

The gateway uses the [Docker MCP Catalog](https://hub.docker.com/mcp) which includes:

| Server | Description |
|---|---|
| `fetch` | HTTP requests to fetch URLs |
| `duckduckgo` | Web search |
| `filesystem` | Read/write access to mounted paths |
| `github-official` | GitHub API (issues, PRs, repos) |
| `slack` | Slack workspace access |
| `postgres` | PostgreSQL database queries |
| `notion` | Notion workspace tools |

Set them via `GATEWAY_SERVERS=fetch,duckduckgo,filesystem,github-official`.

## Connecting AI Clients

### Claude Desktop

In your `claude_desktop_config.json`:

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

Or connect via URL to your Unraid server:

```json
{
  "mcpServers": {
    "Unraid_Gateway": {
      "url": "http://192.168.1.100:8811/mcp"
    }
  }
}
```

### VS Code

In `.vscode/mcp.json`:

```json
{
  "servers": {
    "MCP_GATEWAY": {
      "command": "docker",
      "args": [
        "mcp",
        "gateway",
        "run",
        "--transport",
        "streaming",
        "--port",
        "8811"
      ],
      "type": "stdio"
    }
  }
}
```

### Cursor

Settings → MCP → Add new MCP server:
- **Name**: Unraid Gateway
- **Type**: `command`
- **Command**: `docker mcp gateway run --transport streaming --port 8811`

## Testing with Docker Desktop

```bash
# Clone and start
docker compose up -d

# Verify
curl http://localhost:8811/health

# Test with the Python example client
cd examples/python-client
pip install httpx
python client.py http://localhost:8811/mcp
```

## Installing on Unraid

### Method 1: Docker Compose (recommended)

```bash
# On the Unraid server via SSH
git clone https://github.com/yourusername/mcp-gateway-unraid.git
cd mcp-gateway-unraid
cp .env.example .env
nano .env           # configure your servers
docker compose up -d
```

### Method 2: Unraid Community Apps

1. Add the template URL in Community Apps
2. Find "MCPGateway" in the Apps list
3. Click Install
4. Configure the template parameters

### Method 3: Manual Docker Run

```bash
docker run -d \
  --name unraid-mcp-gateway \
  --restart unless-stopped \
  -e DOCKER_MCP_IN_CONTAINER=1 \
  -p 8811:8811 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/user/appdata/mcp-gateway/secrets:/secrets:ro \
  docker/mcp-gateway:latest \
  /docker-mcp gateway run \
    --transport=streaming \
    --port=8811 \
    --servers=fetch,duckduckgo \
    --secrets=/secrets/.env
```

## Networking: LAN Access

The gateway is **bound to your Unraid host IP** via Docker port mapping.
Only machines on your local network can reach it:

```
AI Client (192.168.1.50) ──→ Unraid (192.168.1.100:8811) ──→ Gateway Container
```

The gateway does **not** expose itself to the internet unless you explicitly
configure port forwarding on your router (not recommended).

### Firewall Note

Unraid's default firewall (`iptables`) allows LAN traffic.
No additional firewall configuration is needed.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Unraid Server                                           │
│                                                          │
│  ┌────────────────────┐   ┌──────────────────────────┐  │
│  │  AI Client          │   │  MCP Gateway Container   │  │
│  │  (Claude / VSCode)  │──▶│  port 8811              │  │
│  └────────────────────┘   │  docker/mcp-gateway       │  │
│                           └─────────┬────────────────┘  │
│                                     │                    │
│                           ┌─────────▼────────────────┐  │
│                           │  MCP Server Containers   │  │
│                           │  (fetch, duckduckgo,     │  │
│                           │   filesystem, etc.)      │  │
│                           └──────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Security

- **No internet exposure** — gateway listens on LAN only
- **Container isolation** — each MCP server runs in its own container
- **Resource limits** — CPU and memory caps per server
- **Secrets isolation** — credentials in `.env` file, never in environment
- **No root in containers** — MCP servers run with limited privileges
- **Image verification** — signed Docker images (optional)

## Troubleshooting

| Problem | Fix |
|---|---|
| `Docker Desktop is not running` | Set `DOCKER_MCP_IN_CONTAINER=1` |
| Gateway starts but tools fail | Check `/var/run/docker.sock` is mounted |
| Can't connect from another machine | Verify firewall allows port 8811 |
| Secrets not loading | Check `.env` file exists and is readable |
| Image not found | Use `docker compose build` to build locally |

## License

MIT — see [LICENSE](LICENSE).

## References

- [Docker MCP Gateway](https://github.com/docker/mcp-gateway)
- [Docker MCP Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)
- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [Unraid](https://unraid.net)
