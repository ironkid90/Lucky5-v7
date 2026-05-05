# Godot Migration Reset And Dependency Map - 2026-05-05

This document resets the Lucky5 Godot migration work plan after the migration
verification review. It is a planning artifact only. It does not authorize or
implement backend, frontend, Godot, payout, RNG, RTP, wallet, jackpot, double-up,
hand-evaluation, or game-rule changes.

## Reset Decision

Use current `main` as the implementation baseline. Trashed task patches, final
report snippets, and dirty Cline worktrees are reference evidence only. Do not
apply those patches directly into product code, and do not revive dirty worktrees
as authoritative source.

The root verification report at `MIGRATION_VERIFICATION_REPORT.md` is not an
acceptance gate for Godot migration product work. It records broad implementation
claims and expected verification commands, but the reset evidence shows the safe
state is: contract/discovery artifacts landed on `main`; downstream production
Godot migration implementation must be re-created from current `main` in small,
dependency-ordered tasks.

## Evidence Reviewed

- Current repo/worktree status: clean before this docs-only reset change.
- Canonical `main`: `8b65ec1 docs: complete godot cabinet phase 0 discovery`.
- Current landed Godot contract package:
  - `docs/contracts/godot-cabinet/README.md`
  - `docs/contracts/godot-cabinet/phase-0-discovery.md`
  - `docs/contracts/godot-cabinet/cabinet-contract-v1.schema.json`
  - `docs/contracts/godot-cabinet/variant-definition-v1.schema.json`
  - `docs/contracts/godot-cabinet/lucky5-classic.variant.v1.json`
  - `docs/contracts/godot-cabinet/ai9poker-comparison-event-matrix.md`
- Current starter Godot project under `godot/cabinet/`, including
  `project.godot`, `scenes/CabinetRoot.tscn`, `fixtures/classic_snapshot.json`,
  and existing scripts. Treat it as a static/presentation starter until backend
  contracts are implemented.
- Transitional backend DTOs in
  `server/src/Lucky5.Application/Dtos/CabinetContractsDto.cs`; these do not by
  themselves prove the live backend is schema-complete.
- Trashed patch archive at
  `C:\Users\Gabi.WIN-CD45QMUUPFF\.cline\kanban\trashed-task-patches`.
- Captured board JSON under `tmp/kanban-*.json`. Live Kanban CLI reads timed out
  during this reset, so verify live board state before mutating links.
- Registered/on-disk Cline worktrees under
  `C:\Users\Gabi.WIN-CD45QMUUPFF\.cline\worktrees`. Several are corrupt, missing,
  or stale, so none are authoritative.

## Salvage Versus Reimplement

### Salvage as authoritative from current `main`

| Area | Salvage | Why |
| --- | --- | --- |
| Phase 0 discovery and contracts | Keep `docs/contracts/godot-cabinet/` as the source-of-truth planning package. | It is committed on current `main` and explicitly preserves backend authority. |
| Presentation backlog guidance | Keep the AI9Poker comparison/event matrix as a planning reference only. | It identifies presentation and adapter gaps without authorizing game-rule changes. |
| Starter Godot project | Keep the current `godot/cabinet/` project as a static fixture/editor baseline. | It is on `main`, but it is not a live backend-driven cabinet yet. |
| Transitional cabinet DTOs | Keep as implementation evidence to inspect during backend contract work. | They are useful seed types, but the Phase 0 docs still identify schema mismatch and missing command/replay surfaces. |
| Orchestration playbook | Keep `docs/KANBAN_ORCHESTRATION.md` as process policy. | It contains durable recovery, dependency, and dirty-worktree safety rules. |

### Salvage as reference only, not code

| Evidence | Use | Do not do |
| --- | --- | --- |
| Trashed backend/product patches | Mine for tests, naming ideas, edge cases, and conflict notes. | Do not apply directly to `main` or cherry-pick as a bundle. |
| Dirty/corrupt Cline worktrees | Use status/diff summaries only when they are readable. | Do not copy files wholesale; do not delete/reset without explicit approval. |
| `MIGRATION_VERIFICATION_REPORT.md` | Treat as a historical claim to verify or supersede. | Do not use it as proof that Redis, RTP, CI gates, or Godot readiness are complete. |
| Old final report snippets in trash | Use to identify intended acceptance criteria. | Do not treat `awaiting_review`, `interrupted`, or `trash` state as merged completion evidence. |

### Reimplement from current `main`

Reimplement these areas in fresh, narrow branches/worktrees from current `main`:

| Prior task/patch evidence | Reset disposition |
| --- | --- |
| `e8e2d` durable/PostgreSQL state patch | Reimplement after revalidating the current in-memory persistence boundary and Data Connect target schema. |
| `96173` ledger/reconciliation patch | Reimplement after durable state design is accepted; do not import broad service rewrites. |
| `8a369` idempotent cabinet command patch | Reimplement after ledger/state ownership is clear; keep duplicate-command and stale-version tests as reference. |
| `bb0e7` admin audit patch | Reimplement as a small audit foundation; avoid overlapping Auth/Admin/GameService edits. |
| `9baa7` cabinet auth/revocation patch | Reimplement after audit and token boundaries are designed; keep secret redaction constraints. |
| `132bc` WebSocket projection/replay patch | Reimplement after auth, idempotency, and backend state sequencing exist. |
| `35af6` mega integration patch | Do not revive. Split into the narrower tasks below. |
| `8e49a` VariantDefinition backend code patch | Reimplement only after contract/schema acceptance; no game-rule changes. |
| `c13ba` Godot live vertical slice work | Reimplement after backend contract/projection API is complete. |
| `cb413` admin console work | Reimplement after audit/auth/realtime foundations exist. |
| `a70d8`, `97600`, `caef2`, `12568` parity/readiness/deploy/decommission work | Reimplement only after their upstream gates pass. |

Patch apply-check evidence supports this reset: process-only patches such as
`0da59`, `273a0`, `42b5b`, and `e7f57` can apply cleanly but are orchestration
work, while the large Godot/backend product patches generally fail
`git apply --check` on current `main` or overlap already-landed files. Treat
even clean process patches as separate process work, not as Godot product work.

## Clean Dependency Map

The dependency direction below is `consumer -> prerequisite`.

```text
Decommission legacy clients
  -> Kiosk build, signing, deployment, rollback
    -> Production readiness gate
      -> Godot scene parity and polish
        -> Live Godot deal/draw vertical slice
          -> Backend cabinet projection API and recovery feed
            -> Admin audit + cabinet auth/revocation foundation
              -> Ledger integrity + idempotent command foundation
                -> Durable backend state and crash recovery foundation
                  -> Reset accepted + Phase 0 contracts/discovery accepted

Production readiness gate
  -> Admin console v1
    -> Backend cabinet projection API and recovery feed
    -> Admin audit + cabinet auth/revocation foundation
```

### Board-ID map from captured state

Captured `tmp/kanban-backlog-latest.json` contained these links. Verify live
Kanban before mutating because live CLI reads timed out during this reset.

| Task ID | Work item | Depends on |
| --- | --- | --- |
| `d07e0` | Reset/salvage decision and dependency map | `e4e49` Phase 0 |
| `0ec9b` | Durable backend state foundation | `d07e0` |
| `01d09` | Ledger integrity + idempotent command foundation | `0ec9b` |
| `2520f` | Admin audit + cabinet auth/revocation foundation | `01d09` |
| `593be` | Backend cabinet projection API/recovery feed | `2520f` |
| `2bfc1` | Live Godot vertical slice | `593be` |
| `6bca8` | Admin console v1 | `593be` plus audit/auth readiness from `2520f` |
| `99d03` | Godot scene parity and polish | `2bfc1` |
| `055a4` | Migration testing and production readiness gate | `99d03` and `6bca8` |
| `9244d` | Kiosk build, signing, deployment, rollback | `055a4` |
| `e9d59` | Legacy decommission plan | `9244d` plus explicit burn-in approval |

Captured board state also linked `e4e49` to orchestration/recovery task `42b5b`.
That is a process prerequisite, not a product dependency. If `42b5b` is already
closed or superseded, remove or replace that link before starting product work.

## Task Boundaries For Reimplementation

1. **Accept/reset gate**: this document reviewed; board links repaired; no dirty
   worktree is treated as source-of-truth.
2. **Phase 0 acceptance**: schemas and discovery docs remain valid; repair only
   documentation gaps or route catalogs. No product code.
3. **Durable backend state**: define crash recovery for gameplay, finance,
   sessions, audit, and machine state without assuming Data Connect is active.
4. **Ledger + idempotency**: add replay-safe `CabinetCommand` handling,
   `expected_state_version`, duplicate-command behavior, and reconciliation tests.
5. **Audit + cabinet auth**: append-only admin audit and device auth/revocation;
   no player JWT/OTP conflation or secret leakage.
6. **Cabinet projection API**: schema-aligned snapshot, command result, monotonic
   sequence, and replay-or-full-snapshot recovery. Keep SignalR compatibility
   unless explicitly retired later.
7. **Godot vertical slice**: presentation-only HTTP/realtime adapter, state store,
   action locks, and deal/hold/draw loop against server-confirmed outcomes.
8. **Admin console**: visibility and safe operations over already-audited backend
   surfaces.
9. **Scene parity/polish**: visual/audio/layout parity after live slice is stable.
10. **Readiness gate**: contract/replay/idempotency/auth/parity checks, Godot
    headless load, manual QA checklist, and burn-in criteria.
11. **Deploy/build**: kiosk exports, signed asset manifest, rollback plan, and
    update mode only after readiness passes.
12. **Decommission**: planning only until burn-in and explicit approval; keep the
    web cabinet as internal fallback.

## Worktree Safety Notes

- Do not delete, reset, or clean abandoned worktrees without explicit approval.
- Worktrees observed as corrupt or unsafe reference sources include `6bca8`,
  `99d03`, `9da03`, and `e9d59` under
  `C:\Users\Gabi.WIN-CD45QMUUPFF\.cline\worktrees`.
- If a prior diff is needed, inspect the archived `.patch` file in a fresh
  throwaway branch/worktree and port only the minimal test or design idea.
- Always verify with the tightest relevant check for the newly reimplemented
  slice; for backend authority work use:

```powershell
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

## Immediate Next Steps

1. Review and accept this reset map.
2. Verify live Kanban state, then repair links so only the dependency map above
   blocks product work.
3. Start `0ec9b` only after reset acceptance and Phase 0 are accepted.
4. Keep all later product cards blocked until their prerequisites complete with
   explicit verification evidence.