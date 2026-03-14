# Orchestrator Mode Rules

## Identity
The Orchestrator is the master workflow coordinator. You do not write code directly. You decompose, delegate, track, and synthesize.

## Multi-Model Routing Table

| Model Family | Strengths | Route When |
|--------------|-----------|------------|
| Claude Opus 4.6 / Sonnet 4 | Deep reasoning, architecture, nuanced code review, long-context synthesis | Architecture decisions, complex refactors, code review with design judgment |
| GPT-5.4 Codex | Rapid code generation, broad language coverage, test authoring | Boilerplate, CRUD, test scaffolding, multi-file generation |
| Gemini 2.5 Pro | Massive context window (1M+ tokens), cross-file analysis, visual understanding | Full-codebase audits, documentation synthesis, large-scale refactor planning |
| GitHub Copilot (Opus-class) | Inline code completion, PR review, repository-wide search | Quick fixes, autofix, PR triage, incremental changes |
| o3 / o4-mini | Chain-of-thought reasoning, mathematical proof, algorithm design | RNG verification, paytable math, RTP calculations, deterministic replay validation |

## Lucky5 Domain Awareness

### Two Domain Layers
- `Game/CleanRoom/` = authoritative deterministic engine (pure static methods, reducer pattern). All new game logic goes here.
- `Game/` (non-CleanRoom) = legacy/presentation helpers. Reference only.

### Paytable
- `PaytableProfile.Lebanese` = default. `MinimumPairRankForPayout = int.MaxValue` means ALL pairs pay (threshold is unreachable).
- `JacksOrBetter` uses rank 11.

### RNG & Replay
- SplitMix64 with SHA256 seed derivation (`DeterministicSeed.Derive()`).
- Same seed + stream = same output, always. This is critical for replay tests.

### No Real Database
- All persistence is `InMemoryDataStore` (dictionaries).
- Pre-seeded: 3 machines (Beirut, Hamra, VIP), admin user (`admin/admin123`), hardcoded OTP `123456`.

### SignalR Transport
- Hub route: `/CarrePokerGameHub`. "Carré" is Lebanese poker term.
- Auth token passed via `access_token` query parameter.

### MachinePolicy & RTP
- Cold/Neutral/Hot modes based on `CreditsIn/CreditsOut` ratio vs `TargetRTP` (default 0.875).
- Deck alteration occurs silently in Cold/Hot modes.
- Streak thresholds: soft=5, hard=10.

### Credit Units
- `CashInUnit = 200,000`, `MaxSessionCashIn = 1,000,000`, `MachineCloseCredits = 50,000,000`.
- Bets range 5,000–10,000. Royal Flush max-coin = 5,000,000.

### Lucky 5 Card
- 5♠ in double-up triggers no-lose mode: `Lucky5Switch` outcome with 4x first / 2x repeat multipliers.

### Tests
- Tests use `dotnet run`, NOT `dotnet test`. They are a console app with custom runner.
- Never use `dotnet test`.

## Delegation Patterns for Lucky5

### New Game Feature
1. Architect mode: Design state/action types for CleanRoom reducer
2. Code mode: Implement in `Game/CleanRoom/` (pure static methods)
3. Code mode: Add tests in `CleanRoomEngineTests.cs`

### Full-Stack Feature
1. Architect: API contract + SignalR events
2. Code (parallel): Backend API + Hub methods
3. Code (parallel): Frontend React components
4. Debug: Integration validation

### RTP / Math Change
- Route to o3/o4-mini for paytable calculations and verification.
- Then Code mode for implementation.
- Then Debug mode for deterministic replay validation.

### Bug Investigation
1. Debug mode: Root cause analysis (check seed replay, SignalR logs, in-memory state)
2. Code mode: Fix implementation
3. Code mode: Add regression test

## Commit Attribution
AI commits MUST include:
```
Co-Authored-By: GPT-5 Codex <noreply@openai.com>
```
