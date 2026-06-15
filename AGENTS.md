You are an AI coding agent working in Lucky5 v7. Optimize for correctness, safety, reversibility, and small verified changes.

<context>
Ground factual claims in this repository's source files, linked docs, and command output from the current workspace.
</context>

## Operating Loop
- Inspect before editing. Read only the files needed for the task.
- Preserve existing conventions and user changes. Never revert unrelated work.
- Plan briefly for non-trivial work, then implement the smallest useful change.
- Verify with the tightest relevant check. Never claim completion without evidence.
- Report in concise markdown: what changed, what ran, assumptions, and remaining risk.

## Safety
- Do not invent file contents, command output, runtime state, or tool capabilities.
- Confirm before destructive or high-risk actions: data deletion, history rewrite, force push, registry edits, production deploys, or cloud deletes.
- Keep secrets, tokens, private keys, session data, and personal data out of chat, logs, and commits.
- Prefer dry runs, previews, and read-only inspection before mutation.

## Lucky5 Invariants
- `docs/` is the source of truth for product and engineering behavior.
- This repo is a Godot 4.6 portrait cabinet client plus a .NET 9 API server.
- `godot/cabinet/` is the primary playable client; `server/src/Lucky5.Api/` is the sole backend.
- `server/src/Lucky5.Domain/Game/CleanRoom/` owns deterministic authoritative game logic.
- The backend owns balance, machine state, session state, and realtime behavior.
- Preserve the retro cabinet feel. Do not turn the product into a generic casino UI.
- Persistence is in-memory unless `Persistence:FileStore:RootPath` configures file snapshots.

## Commands
- Launch: `./dev.ps1` for API plus Godot, `./dev.ps1 -Headless` for API only.
- Tests: `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`. Do not default to `dotnet test`.
- Build API: `dotnet build server/Lucky5.sln` or publish `server/src/Lucky5.Api/Lucky5.Api.csproj`.
- Optional Godot smoke: `./scripts/godot/Test-GodotCabinet.ps1` when Godot is on PATH or `GODOT_BIN` is set.

## Grounding Links
- Start with [README.md](README.md) for setup, commands, credentials, and repo structure.
- Use [docs/README.md](docs/README.md) and [docs/LUCKY5_AUTHORITATIVE_GAMEPLAY_REFERENCE.md](docs/LUCKY5_AUTHORITATIVE_GAMEPLAY_REFERENCE.md) for product and gameplay behavior.
- Use [docs/GAME_FEEL_REFERENCE.md](docs/GAME_FEEL_REFERENCE.md), [docs/GODOT_CABINET_MIGRATION.md](docs/GODOT_CABINET_MIGRATION.md), and [docs/GODOT_KIOSK_RELEASE.md](docs/GODOT_KIOSK_RELEASE.md) for cabinet work.
- Use [docs/KANBAN_ORCHESTRATION.md](docs/KANBAN_ORCHESTRATION.md) for Kanban worker, steward, review, recovery, and summary artifact rules.
- No `CLAUDE.md` files are currently present; prefer live source and these docs over stale local instruction-file names.

## Chat Customizations
- Workspace custom agents live in `.github/agents/` and currently cover Playwright planning, generation, and healing.
- Workspace skills live in `.github/skills/`. Load the most specific skill before specialized work such as ASP.NET Core, frontend design, deployment, codebase mapping, spreadsheet/doc generation, or skill creation.
- Keep customization files compact. Link to existing docs instead of embedding them.

## vexp <!-- vexp v2.0.27 -->

**MANDATORY: use `run_pipeline` - do NOT grep or glob the codebase.**
vexp returns pre-indexed, graph-ranked context in a single call.

### Workflow
1. `run_pipeline` with your task description - ALWAYS FIRST (replaces all other tools)
2. Make targeted changes based on the context returned
3. `run_pipeline` again only if you need more context

### Available MCP tools
- `run_pipeline` - **PRIMARY TOOL**. Runs capsule + impact + memory in 1 call.
  Auto-detects intent. Includes file content. Example: `run_pipeline({ "task": "fix auth bug" })`
- `get_skeleton` - compact file structure
- `index_status` - indexing status
- `expand_vexp_ref` - expand V-REF placeholders in v2 output

### Agentic search
- Do NOT use built-in file search, grep, or codebase indexing - always call `run_pipeline` first
- If you spawn sub-agents or background tasks, pass them the context from `run_pipeline`
  rather than letting them search the codebase independently

### Smart Features
Intent auto-detection, hybrid ranking, session memory, auto-expanding budget.

### Multi-Repo
`run_pipeline` auto-queries all indexed repos. Use `repos: ["alias"]` to scope. Run `index_status` to see aliases.
<!-- /vexp -->