-+# Global Instructions for All Modes

These instructions apply to every mode (code, architect, debug, ask, orchestrator).

## 1. Project Identity
- **Name**: Lucky5 v4 — a Lebanese-style video poker cabinet game.
- **Stack**: .NET 9 backend, React/Next.js web frontend, Flutter client, Capacitor mobile wrapper.
- **Monorepo**: `server/`, `src/web/`, `client/`, `mobile/`, `contracts/`, `docs/`, `infra/`.

## 2. Game Engine Rules (Critical)
- Authoritative game logic lives ONLY in `server/src/Lucky5.Domain/Game/CleanRoom/`.
- CleanRoom code is pure static methods with a reducer pattern: `Reduce(state, action)`.
- Never add side effects, network calls, or randomness outside of SplitMix64 to CleanRoom code.
- `Game/` (non-CleanRoom) is legacy/presentation. Reference only, do not add new logic there.

## 3. Testing
- Run tests with `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`.
- **Never** use `dotnet test`. Tests are a console app with a custom runner.
- Test output is plaintext pass/fail with `List<string> failures`.

## 4. Persistence
- No real database yet. All state is in `InMemoryDataStore` (dictionaries).
- Pre-seeded: 3 machines (Beirut, Hamra, VIP), admin (`admin/admin123`), OTP `123456`.

## 5. Realtime
- SignalR hub route: `/CarrePokerGameHub`.
- Auth token via `access_token` query parameter for WebSocket connections.

## 6. Design Philosophy
- Preserve the cabinet layout and retro feel from `docs/GAME_FEEL_REFERENCE.md`.
- Do not modernize into a generic casino UI.
- Web-first playable slice before Flutter or native mobile work.

## 7. Code Quality
- Keep game logic deterministic and separated from presentation noise, cabinet feel, and RTP tuning.
- Backend state is authoritative for machine join/leave, balance, credit, and realtime updates.
- Use `docs/` as the active source of truth.
- `sources/` contains decompiled Java from the original APK — reference only, never edit.

## 8. Commit Attribution
Automated/AI commits MUST include:
```
Co-Authored-By: GPT-5 Codex <noreply@openai.com>
```

## 9. Platform Commands
| Task | Command |
|------|---------|
| Build server | `dotnet build server/Lucky5.sln -v minimal` |
| Run tests | `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj` |
| Run API | `dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj` |
| Local stack | `docker compose -f infra/docker-compose.yml up` |
| Lint | `trunk check` |
| Flutter client | `cd client && flutter pub get && flutter run` |
| Git | `& 'C:\Program Files\Git\cmd\git.exe' ...` |

## 10. Key Domain Facts
- `PaytableProfile.Lebanese` = default. All pairs pay (`MinimumPairRankForPayout = int.MaxValue` -> threshold unreachable).
- 5 of spades in double-up = Lucky5 no-lose mode (4x first / 2x repeat).
- Credit units are large: `CashInUnit = 200,000`, bets 5,000–10,000.
- RNG is SplitMix64 + SHA256 seed derivation. Deterministic for replay.
- MachinePolicy: Cold/Neutral/Hot modes, TargetRTP 0.875, silent deck alteration.
- Admin env: `LUCKY5_ADMIN_USERNAME`, `LUCKY5_ADMIN_PASSWORD`, `LUCKY5_ADMIN_PHONE`.
