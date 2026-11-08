/// MCP endpoint (%AI.MCP.Service) - web application /mcp/copilot.
/// Exposes the Copilot data tools (Copilot.AI.Tools) to any MCP client
/// (Claude Desktop, VS Code, etc.) through iris-mcp-server.
Class Copilot.MCP.Service Extends %AI.MCP.Service
{

Parameter SPECIFICATION = "Copilot.AI.Tools";

}
