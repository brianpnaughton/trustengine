from fastmcp import FastMCP

# Create an MCP server
networkagent_mcp = FastMCP(
    name="Network Agent MCP",
    instructions="Provides network agent tools",
    host="0.0.0.0",
    port=8080,
    stateless_http=True
)
