Durable agent contract for this repository. Keep this file compact, reusable, and focused on behavior that improves long-run agent quality. 

## Mission 
- Optimize for correctness, safety, reversibility, context efficiency, and maintainability. 
- Prefer durable workflow rules over tool dumps, copied docs, or temporary task notes. 
- Treat AGENTS.md as policy, not as a scratchpad or knowledge base. 

## Default Operating Loop 
1. Restate the objective and success criteria briefly. 
2. Inspect the repo and runtime before editing anything. 
3. Read only the files needed for the task. 
4. Make a short plan when the work is non-trivial. 
5. Implement the smallest change that solves the problem. 
6. Verify with the tightest relevant checks. 
7. Report what changed, what was verified, assumptions, and remaining risk. 

## Core Behavior Rules 
- Never invent file contents, command results, tests, runtime state, or tool capabilities. 
- Inspect before editing. Verify after editing. 
- Prefer reversible actions and previews before risky operations. 
- Preserve existing project conventions unless the task explicitly changes them. 
- Make local, minimal edits instead of broad rewrites unless a rewrite is the task. 
- Do not revert unrelated user changes. 
- Ask only when blocked on a truly risky unknown; otherwise make a reasonable assumption and state it. 

## Context And Memory Discipline 
- Keep active context lean. Search first, then open only the relevant files and line ranges. 
- Prefer local source-of-truth docs over memory or guesswork. 
- Do not paste large logs, generated files, external docs, or tool schemas into AGENTS.md or chat unless they are necessary. 
- Summarize bulky output instead of carrying it forward verbatim. 
- Offload large transient output to task artifacts under `tmp/` when useful instead of keeping it in live context. 
- After meaningful tasks, update the canonical Codex memory file defined in `docs/KANBAN_ORCHESTRATION.md` with current objective, environment facts, decisions, open questions, and next steps.
- After meaningful tasks, write `tmp/summary-<timestamp>.json` using the required summary schema in `docs/KANBAN_ORCHESTRATION.md`.

## Tool Strategy 
- Use the smallest toolset that can complete the task well. 
- Prefer fast targeted search tools such as `rg` or equivalent. 
- Use explicit working directories for shell commands. 
- Prefer shared local MCP wrappers and existing repo scripts when they help. 
- For third-party libraries, prefer current official docs rather than stale recollection. 
- Do not serialize raw tool catalogs or copied vendor docs into repo instruction files. 

## Editing And Verification 
- Keep changes ASCII unless the file already requires Unicode. 
- Add comments only when they clarify non-obvious logic. 
- Validate with the smallest relevant check: build, test, lint, typecheck, smoke test, or targeted script. 
- If verification cannot run, say so and provide the exact command that should be run next. 
- Never claim a fix is complete without evidence from inspection or verification. 

## Safety Rules 
- Confirm before destructive or high-risk actions such as deleting data, rewriting git history, force-pushing, registry edits, production deploys, or cloud deletions. 
- Prefer dry runs such as `-WhatIf`, preview modes, or read-only inspection before mutation. 

## Lucky5 Repo Invariants 
- `docs/` is the active source of truth for product and engineering behavior. 
- Tests run with `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`, not `dotnet test`. 
- Authoritative game logic belongs in `server/src/Lucky5.Domain/Game/CleanRoom/` and must stay deterministic. 
- The backend is authoritative for balance, machine state, session state, and realtime behavior. 
- The current persistence model is in-memory; data is lost on restart unless file snapshot persistence is configured. 
- Preserve the retro cabinet feel; do not modernize the product into a generic casino UI. 
- The Godot cabinet (`godot/cabinet/`) is the primary playable client. Godot 4.6 required. 
- The .NET 9 API (`server/src/Lucky5.Api/`) is the sole backend. 

## Lucky5 v7 Current State (June 2026) 
- Single consolidated repo: Godot cabinet client + .NET 9 API server. 
- Flutter, Web (Next.js), and Mobile (Capacitor) clients removed. 
- Firebase, Azure, Docker, and cloud infra removed. 
- Launch: `.\dev.ps1` starts API + Godot cabinet. `.\dev.ps1 -Headless` for API only. 
- Admin access: username `admin`, password `admin123`. Test user: `tester` / `password`. 
- In-memory data store with optional file persistence via `Persistence:FileStore:RootPath`. 

## Repo Routing 
- Root AGENTS.md provides the default contract for the whole repo. 
- For subsystem detail, read the nearest local `CLAUDE.md` or nested instruction file before making deeper changes. 
- Key local context files: `server/src/Lucky5.Api/CLAUDE.md`, `server/src/Lucky5.Domain/Game/CleanRoom/CLAUDE.md`, `server/tests/CLAUDE.md`. 

## Smart General Defaults 
- Favor search-driven discovery over loading entire files or directories. 
- Prefer narrow diffs, stable interfaces, and changes that make future agent work easier. 
- When touching workflows or tooling, improve reproducibility, naming, logging, and failure clarity. 
- When touching docs, keep them actionable and aligned with the current repo reality. 

## Anti-Bloat Maintenance Rule 
Never let this file grow into a prompt dump. Do not paste external documentation, API references, vendor tool catalogs, raw prompts, giant command outputs, or generated content into AGENTS.md. 

## Reinforcements 
- Keep the summary artifact step explicit after meaningful tasks. 
- For Kanban worker, steward, review, and recovery sessions, follow `docs/KANBAN_ORCHESTRATION.md`.
- Never expose secrets, tokens, private keys, session data, or sensitive personal information.