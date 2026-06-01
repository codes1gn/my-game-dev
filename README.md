# my-game-dev

AI Agent-assisted game development project on Windows.

## Tech Stack

- **Engine**: Godot 4.6.3
- **AI Bridge**: Godot Runtime Bridge (GRB) via MCP
- **AI Agent**: Cursor IDE
- **Language**: GDScript

## Setup

1. Install Godot 4.5+ (`winget install GodotEngine.GodotEngine`)
2. Clone this repo
3. Run `npm install` in `godot-runtime-bridge/mcp/`
4. Open in Cursor — MCP is configured in `.cursor/mcp.json`
5. In Cursor Settings > Tools & MCP, enable `godot-runtime-bridge`

## Project Structure

```
my-game-dev/
├── .cursor/mcp.json          # Cursor MCP config for GRB
├── addons/godot-runtime-bridge/  # GRB addon
├── main.tscn                 # Main scene
├── main.gd                   # Main script
└── project.godot             # Godot project config
```

## Usage

With GRB connected, tell Cursor things like:
- "Launch my game and take a screenshot"
- "Add a pause menu"
- "Run a smoke test and fix bugs"
