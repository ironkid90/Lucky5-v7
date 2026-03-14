# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Package Manager
- .NET 9.0 (`dotnet`) for server. Flutter (`dart`/`flutter`) for client. Node/npm for mobile (Capacitor). No canonical JS package manager for web.
- Git: `& 'C:\Program Files\Git\cmd\git.exe' ...`

## Commands
| Task | Command |
|------|---------|
| Build server | `dotnet build server/Lucky5.sln -v minimal` |
| Run tests | `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj` |
| Run API locally | `dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj` |
| Full bootstrap | `pwsh scripts/bootstrap.ps1` |
| Smoke test API | `pwsh scripts/smoke-api.ps1` |
| Local stack | `docker compose -f infra/docker-compose.yml up` |
| Lint | `trunk check` (hadolint, markdownlint, shellcheck, yamllint, prettier, checkov, trufflehog, dart, osv-scanner) |
| Flutter client | `cd client && flutter pub get && flutter run` |
| Mobile build | `cd mobile && npm run build` (Capacitor sync → Android) |

## Critical Non-Obvious Facts

### Tests use `dotnet run`, NOT `dotnet test`
Tests are a console app (`OutputType=Exe`), not xunit/nunit. They use a custom runner with `List<string> failures` and manual assertions. Never use `dotnet test`.

### Game engine is stateless and deterministic
All game logic lives in [`Lucky5.Domain.Game.CleanRoom/`](server/src/Lucky5.Domain/Game/CleanRoom/) as pure static methods. `FiveCardDrawEngine` uses a reducer pattern (`Reduce(state, action)`). RNG is SplitMix64 with SHA256 seed derivation (`DeterministicSeed.Derive()`). Same seed + stream = same output, always.

### Lebanese paytable is the default — pays ALL pairs
`PaytableProfile.Lebanese` sets `MinimumPairRankForPayout = int.MaxValue` which means **every pair pays**. This is counterintuitive — `int.MaxValue` means the rank threshold is unreachable, so no pair is excluded. `JacksOrBetter` uses rank 11.

### Lucky 5 = 5 of Spades — special double-up card
In double-up, drawing the 5♠ triggers "no-lose mode": player gets `Lucky5Switch` outcome with 4x first / 2x repeat multipliers. The dealer card is then replaced.

### InMemoryDataStore — no real database yet
All persistence is in-memory dictionaries. Server pre-seeds 3 machines (Beirut, Hamra, VIP), an admin user (`admin/admin123`), and hardcoded OTP `123456`.

### Credit units are large numbers
`CashInUnit = 200,000`, `MaxSessionCashIn = 1,000,000`, `MachineCloseCredits = 50,000,000`. Bets range 5,000–10,000. Royal Flush max-coin = 5,000,000.

### SignalR hub is "CarrePokerGameHub"
Hub route: `/CarrePokerGameHub`. "Carré" is the Lebanese poker term. Auth token passed via `access_token` query parameter for WebSocket connections.

### Machine policy controls RTP with distribution modes
`MachinePolicy` manages Cold/Neutral/Hot modes based on `CreditsIn/CreditsOut` ratio vs `TargetRTP` (default 0.875). Deck alteration occurs in Cold/Hot modes. Streak thresholds: soft=5, hard=10. Cooldown system prevents consecutive big wins.

### Two domain layers in Lucky5.Domain
`Game/CleanRoom/` = authoritative deterministic engine. `Game/` (non-CleanRoom) = legacy/presentation helpers (`DeckBuilder`, `HandTensionAnalyzer`, `PokerHandEvaluator`, `RoundNoiseRng`). New game logic goes in CleanRoom only.

### Web frontend serves from API's wwwroot
`server/src/Lucky5.Api/wwwroot/` has a vanilla JS/CSS cabinet (the original). `src/web/` has the React/Next.js cabinet. The React cabinet is the active development target.

### Admin env vars
`LUCKY5_ADMIN_USERNAME`, `LUCKY5_ADMIN_PASSWORD`, `LUCKY5_ADMIN_PHONE` — default to `admin`/`admin123`/`+96100000000`.

## Key Conventions
- Keep game logic deterministic and separated from presentation noise, cabinet feel, and RTP tuning.
- Backend state is authoritative for machine join/leave, balance, credit, and realtime updates.
- Preserve the cabinet layout and retro feel from `docs/GAME_FEEL_REFERENCE.md`; do not modernize into a generic casino UI.
- Prefer web-first playable slice before Flutter or native mobile work.
- Use `docs/` as the active source of truth.
- `sources/` contains decompiled Java from the original APK — reference only, do not edit.

## Commit Attribution
AI commits MUST include:
```
Co-Authored-By: GPT-5 Codex <noreply@openai.com>
```
