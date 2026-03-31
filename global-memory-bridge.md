Last verified: 2026-03-15

This workspace uses disk-backed VS Code Agent Memory.

Shared agent MCP memory is routed through:

- C:\Users\Gabi\.agent-runtime\scripts\memory-mcp.cmd
- C:\Users\Gabi\.agent-runtime\data\memory\global-memory.jsonl

Notes: - The VS Code Explorer Memory tab is workspace-scoped and reads `.vscode/memory`. - Roo, Codex, and other MCP-aware agents should use the shared `memory` MCP server above. - `AGENTS.md` can be auto-synced by the Agent Memory extension when it writes memory entries. - For current Lucky5 RTP / fun / tension work, bootstrap from `.memory/rtp-80-rebalancing-handoff-2026-03-31.md` first, then `.memory/decisions.md`, `.memory/patterns.md`, `.memory/inbox.md`, and `.memory/audit-log.md`.
