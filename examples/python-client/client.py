#!/usr/bin/env python3
"""MCP Gateway Python Client Example.

Connects to the MCP Gateway via streaming transport and lists/calls tools.

Usage:
    python client.py http://unraid-ip:8811/mcp

Requirements:
    pip install httpx
"""

import sys
import json
import httpx


class MCPClient:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.client = httpx.Client(timeout=30.0)

    def list_tools(self):
        """List all available MCP tools from the gateway."""
        response = self.client.post(
            f"{self.base_url}/",
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list",
                "params": {},
            },
        )
        response.raise_for_status()
        return response.json()

    def call_tool(self, name: str, arguments: dict = None):
        """Call a specific MCP tool."""
        response = self.client.post(
            f"{self.base_url}/",
            json={
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": name,
                    "arguments": arguments or {},
                },
            },
        )
        response.raise_for_status()
        return response.json()


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <gateway_url>")
        print(f"  e.g. {sys.argv[0]} http://192.168.1.100:8811/mcp")
        sys.exit(1)

    url = sys.argv[1]
    client = MCPClient(url)

    print(f"\n🔌 Connected to MCP Gateway at {url}\n")

    # List tools
    print("📋 Listing available tools...")
    try:
        tools_response = client.list_tools()
        tools = tools_response.get("result", {}).get("tools", [])
        if not tools:
            print("  No tools available (gateway is running but no servers configured)")
        else:
            for tool in tools:
                print(f"  • {tool['name']}: {tool.get('description', 'No description')}")
    except Exception as e:
        print(f"  ❌ Failed to list tools: {e}")
        print("\n  Make sure the gateway is running and accessible.")
        sys.exit(1)


if __name__ == "__main__":
    main()
