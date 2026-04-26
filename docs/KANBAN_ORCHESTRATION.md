# Lucky5 Development and Kanban Orchestration Playbook

This playbook turns the working Lucky5 Kanban pattern into a reusable process for this repo and similar projects. It is intentionally procedural: use it to set up boards, shape tasks, run steward sessions, recover stuck work, and hand off completed work without rediscovering the same practices.

The current lessons come from the Godot cabinet setup flow, task `edddb` completion hardening, interrupted worker final reports, dependency tightening, and Windows Kanban CLI behavior.

## Scope

- Applies to Lucky5 Kanban tasks, steward sessions, worker prompts, review handoffs, and project/tool onboarding tasks.
- Does not authorize product work by itself. Process cards must not implement backend, game, finance, auth, or cabinet feature changes.
- Keeps Lucky5 invariants in force: backend authority, deterministic CleanRoom logic, no payout/RNG/hand-evaluation/double-up/RTP/game-rule changes unless the task explicitly assigns governed variant work.

## Board Setup

1. Confirm the canonical repo path before reading or mutating the board. In this workspace, Kanban reads are tied to:

   ```powershell
   kanban task list --project-path "C:\Users\Gabi.WIN-CD45QMUUPFF\Documents\GitHub\Lucky5-v7"
   ```

2. Treat detached task worktrees as implementation workspaces, not necessarily Kanban project roots. If `kanban task list` says the Cline worktree is not added to Kanban, retry against the canonical repo path before declaring Kanban unavailable.
3. Start with a read-only board list, dependency list, and `git status -sb` for the target worktree.
4. Keep board columns simple: `backlog`, `in_progress`, `review`, `trash`.
5. Disable auto-review by default for high-risk tasks touching finance, wallets, ledgers, persistence, auth, RTP, payout, RNG, hand evaluation, double-up, jackpots, settlement, or game rules.
6. On Windows, serialize Kanban CLI mutations. Do not run create/start/update/link/unlink/trash/delete operations concurrently. Read-only `task list` calls can run freely.

## Task Decomposition

Create tasks around ownership and verification boundaries, not around vague milestones.

- Good task boundaries: one backend authority area, one contract layer, one client presentation slice, one docs/process deliverable, one verification gate.
- Avoid parallel tasks that edit the same authority files such as `GameService`, `IGameService`, `CabinetContractsDto`, CleanRoom engine files, wallet/ledger/session persistence, or shared contract schemas unless the steward has explicitly planned ownership and integration order.
- Put dependencies on the board whenever one task consumes another task's contract, durable state model, auth flow, or verification evidence.
- Keep process/steward cards orchestration-only. If code or product work is discovered, create a dedicated implementation task.

Recommended Lucky5 ordering for Godot migration work:

1. Process/playbook and board hygiene.
2. Durable backend authority and persistence/recovery foundations.
3. Idempotency, ledger integrity, audit, and auth.
4. WebSocket/cabinet projection contracts.
5. Presentation-only Godot vertical slice.
6. Admin operations console and audit visibility.
7. Scene parity, polish, and regression evidence.
8. Deployment pipeline and signed assets.
9. Legacy client decommission only after explicit burn-in approval.

## Dependency Linking

Use links to block consumers on prerequisites. Link when:

- A client task depends on backend contracts, auth, idempotency, or event sequencing.
- Admin UI depends on audit records, device revocation, or session recovery APIs.
- Deployment depends on parity, verification gates, and admin readiness.
- Decommission depends on production burn-in and fallback readiness.

Do not link merely because tasks are thematically related. A link should mean "starting this before the prerequisite completes creates likely rework or unsafe behavior."

## Worker Prompt Shape

Every worker task should be self-contained and should not rely on chat history for critical constraints.

Use this template:

```markdown
Objective: <single outcome, with the owner area named>

Context:
- <current repo/board facts the worker needs>
- <known prior work or dependency outcome>
- <what this card must not do>

Acceptance criteria:
1. Inspect <specific instruction files, docs, code paths, board state, or dependency outcomes> before editing.
2. Implement or document <smallest concrete deliverable>.
3. Preserve <domain invariants and ownership boundaries>.
4. Add/update <tests, docs, templates, or verification artifacts>.
5. Verify with <exact tightest relevant commands>.
6. If verification is blocked, report the exact command, blocker, and expected success signal.
7. Write `tmp/summary-<timestamp>.json` and update the canonical Codex memory file for meaningful work when available. See [Summary and Memory Artifacts](#summary-and-memory-artifacts).
8. Finish with a final report listing changed files, verification, residual risks, and follow-ups.

Safety constraints:
- Do not revert unrelated user changes.
- Do not run destructive git, cleanup, trash, delete, reset, or force-push actions without explicit user approval.
- Do not expose secrets or commit machine-specific credentials.
- Do not change payout tables, RNG, hand evaluation, double-up math, RTP, jackpots, wallet settlement, or game rules unless explicitly assigned through governed variant work.

Verification expectations:
- <command 1>
- <command 2>
- `git status -sb`

Final report requirements:
- Changed files grouped by purpose.
- Verification run with pass/fail/blocker.
- Assumptions and remaining risks.
- Follow-up tasks needed, if any.
- Clear "ready for review" or clear blocker.
```

## Steward Cadence

Use a steward card when the board has multiple workers, dependencies, or stale-session risk. The steward should not edit repo files unless the card explicitly assigns docs/process work.

Steward card setup:

- Create a dedicated steward card as soon as a repo has two or more active workers, a dependency graph that affects start order, or stale-session/recovery risk.
- The card owns orchestration only: board reads, dependency checks, stale-session triage, review handoffs, and follow-up task creation. Product/code changes require separate implementation cards.
- Include the canonical project path, active worker IDs, dependency links, high-risk ownership boundaries, poll cadence, stale thresholds, cleanup approval rule, and final-report requirements in the steward prompt.
- If no steward card exists while multiple workers are active, create or request one before starting more implementation work.

Polling cadence:

- Poll every 10 to 15 minutes while the steward session is active.
- Use read-only Kanban list first.
- Check `in_progress`, `review`, `trash`, and dependency links.
- For suspicious tasks, inspect the task worktree with `git status -sb` and only then decide whether to ask for action.

Stale thresholds:

- No session output for 15 minutes: watchlist the task and capture task ID, prompt objective, session state, last output time, and worktree path.
- Dirty worktree with no output for 20 minutes: mark stale-dirty, capture `git status -sb` and `git diff --stat`, and do not trash or overwrite it.
- Clean worktree with acceptance criteria apparently satisfied: mark review-ready or final-report-blocked.
- Task blocked only on summary, memory, or final-report polish: require the final report now and create a follow-up if the artifact truly matters.

Start/stop/link rules:

- Start only dependency-ready tasks.
- Do not start two tasks that plan to edit the same backend authority files unless ownership is explicit.
- Link tasks when a real prerequisite exists; unlink only after verifying the prerequisite is no longer required or has moved to an accepted state.
- Move a task to review only after its final report names changed files, verification, blockers or residual risks, summary artifact status, memory update status, and follow-up needs.
- Trash, delete, reset, discard, or remove worktrees only after capturing status and receiving explicit user approval.
- Stop starting new work when review or recovery load is the bottleneck.
- Create follow-up tasks for discovered issues instead of expanding an active worker's scope.

Dirty-worktree handling:

- Never trash active dirty work.
- Never discard uncommitted changes from another worker.
- Capture status first, then ask the user before cleanup, deletion, reset, or worktree removal.
- If the main worktree has user edits, document them and avoid touching those files unless the task requires it.

## Worker Completion Contract

A worker must produce its final report as soon as either condition is true:

- Acceptance criteria are met and the tightest relevant verification has run or has a clear blocker.
- Only trivial, non-blocking cleanup remains, such as summary artifacts, handoff notes, optional broader verification, or follow-up task creation.

Do not leave a task in `in_progress` only to perfect a final report, write optional memory, or wait on non-blocking handoff polish.

Every final report must include:

- Changed files, grouped by purpose.
- Verification run, with pass/fail/blocker and exact command names.
- Residual risks and assumptions.
- Explicit remaining follow-up items.
- A clear statement that the task is ready for review, or a clear blocker if it is not.

If memory or `tmp/summary-<timestamp>.json` is blocked, record that blocker in the final report and move the task forward instead of staying active silently.

## Review Gates

Use review for evidence, not ceremony.

For docs/process tasks:

- Read-only board list succeeds or the Kanban blocker is reported.
- `git status -sb` reviewed.
- `git diff --check` passes or only known line-ending warnings remain.
- Links from AGENTS/docs indexes are compact and point to durable docs.

For backend authority tasks:

- Run `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`.
- If local .NET runtime is missing, record the exact failure and try the known roll-forward command only when appropriate:

  ```powershell
  $env:DOTNET_ROLL_FORWARD='Major'; dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
  ```

- Add focused tests for the changed authority path.
- Confirm no unassigned game-rule, payout, RNG, RTP, settlement, or ledger behavior changed.

For Godot/client tasks:

- Verify the local tool path and signature before trusting downloaded executables.
- Prefer non-Mono Godot for GDScript-only work unless C# is explicitly introduced.
- Run a headless project load or document the exact manual editor command and expected success signal.
- Confirm the client remains presentation-only and does not compute game truth.

## Stuck-Task Recovery

Use recovery to preserve evidence and worker output.

1. Capture read-only board state:

   ```powershell
   kanban task list --project-path "C:\Users\Gabi.WIN-CD45QMUUPFF\Documents\GitHub\Lucky5-v7" --column in_progress
   ```

2. Capture worktree status:

   ```powershell
   git -C "<task-worktree>" status -sb
   ```

3. If dirty, capture a diff summary and untracked files:

   ```powershell
   git -C "<task-worktree>" diff --stat
   git -C "<task-worktree>" ls-files --others --exclude-standard
   ```

4. If clean and complete, request final reporting or move to review according to the active Kanban workflow.
5. If incomplete, create a follow-up with the captured status and exact remaining work.
6. Before cleanup, show the captured status and ask the user for explicit approval for trashing, discarding, deleting, resetting, or removing worktrees.

A `pid` of `0` in Kanban output is not enough by itself to declare a session dead. Use last output age, worktree status, and task content together.

## Project Onboarding for Tool-Specific Setup

Use this pattern for Godot, mobile SDKs, desktop tools, and other local tool setup tasks.

- Verify local tool paths before writing docs around them.
- Verify executable signatures or checksums where feasible. For Godot on Windows, use `Get-AuthenticodeSignature` for downloaded executables.
- Prefer repo-local project files and launch helpers that accept path overrides through parameters or environment variables.
- Do not commit machine-specific secrets, absolute credential paths, API keys, service-account JSON, tokens, or local cache folders.
- Document beginner workflow: which executable to use, how to open/import the project, how to run the main scene, how to run the current scene, how to edit scenes/scripts, how to use the remote inspector/debugger, where assets/scripts/scenes live, and what generated folders are ignored.
- Keep authority boundaries explicit. Godot and other clients may render, animate, and collect input; the backend decides wallet, ledger, jackpot, session, RNG, payout, double-up, and state transitions.
- For local helper scripts, keep defaults safe and overridable. Avoid hard-coded personal paths unless the script also supports `-ToolPath` or an environment variable override.

## Summary and Memory Artifacts

Use memory and summary artifacts to preserve durable handoff context without storing secrets, raw logs, transcripts, or vendor/tool catalogs.

Canonical memory path:

- Treat `~/.codex/memory.json` as the logical memory path.
- On Windows workstations with profile aliases, prefer `C:/Users/Gabi/.codex/memory.json` when it exists as the cross-client canonical path. Also read `$env:USERPROFILE/.codex/memory.json` when it differs, because task worktrees may run under aliases such as `C:/Users/Gabi.WIN-CD45QMUUPFF`.
- Write the canonical path first. If the current profile memory path differs and already exists, keep it in the same schema when feasible. If either write is blocked, record the blocker in the final report and in the summary artifact if available.
- Do not create new home-directory aliases based on guesswork. Do not copy secrets, tokens, private keys, cookies, service-account JSON, or machine credentials between memory files.

Use this memory schema, with snake_case keys:

```json
{
  "schema_version": "agent-memory/v1",
  "last_updated": "YYYY-MM-DDTHH:mm:ssZ",
  "current_objective": "",
  "environment_facts": {},
  "constraints_and_safety_notes": [],
  "key_decisions": [],
  "open_questions": [],
  "next_steps": [],
  "verification": [],
  "summary_artifact": ""
}
```

Create `tmp/summary-<timestamp>.json` after meaningful tasks: code changes, docs/process changes, board stewardship, review/recovery sessions, or verification work whose result should be reusable. Trivial read-only checks can skip the artifact unless the task asks for one.

Required summary JSON shape:

```json
{
  "schema_version": "task-summary/v1",
  "timestamp": "YYYYMMDD-HHMMSS",
  "objective": "",
  "changed_files": [],
  "commands": [],
  "verification": [],
  "outcome": "",
  "assumptions": [],
  "follow_ups": [],
  "memory_paths": [],
  "redactions": []
}
```

Summary rules:

- Create `tmp/` if it is missing. The directory is ignored by git in this repo.
- Summarize command output instead of pasting raw logs. Include exact command names, pass/fail/blocker state, and the smallest useful evidence.
- Redact secrets before writing. If a needed fact is sensitive, write a placeholder such as `<redacted: token>` and note the redaction in `redactions`.
- If `tmp/` or memory writes are blocked, do not leave the worker active only for artifact polish. Record the blocker, the exact command that failed, and the next manual command in the final report.

## Reuse on the Next Project

1. Copy this playbook to the new repo's `docs/` or equivalent process folder.
2. Replace canonical paths, test commands, invariants, and high-risk file lists with project-specific equivalents.
3. Add a one-line pointer from the repo instruction file, keeping that file compact.
4. Create the first steward card with the canonical project path, polling cadence, stale thresholds, dependency order, and cleanup approval rule.
5. Create worker tasks from the template above and keep each one independently verifiable.
