# Code Mode Rules (Non-Obvious Only)

## Test Runner is a Console App
Tests use `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`, NOT `dotnet test`. The test project is `OutputType=Exe` with a custom `Program.cs` runner that collects failures into `List<string> failures`.

## New Game Logic → CleanRoom Only
All new game logic MUST go in `server/src/Lucky5.Domain/Game/CleanRoom/`. The non-CleanRoom `Game/` directory (`DeckBuilder`, `HandTensionAnalyzer`, `PokerHandEvaluator`, `RoundNoiseRng`) is legacy/presentation — do not add game rules there.

## Card Code "10" Normalizes to "T"
`CleanRoomCard.FromCode()` converts "10" to rank char 'T' internally. Always use single-char rank codes (2-9, T, J, Q, K, A) when constructing cards in tests or engine code.

## Reducer Pattern for Game State
`FiveCardDrawEngine.Reduce(state, action)` is the only way to advance game state. Do not mutate `FiveCardDrawState` directly. Actions: `ToggleHold`, `SetHoldMask`, `Draw`.

## InMemoryDataStore — All State is Volatile
No real database. `InMemoryDataStore` has plain `Dictionary<>` collections. Server restarts wipe everything. Pre-seeded data: 3 machines, admin user, 2 offers, 3 contact types.

## Auth Token via Query Parameter for SignalR
WebSocket connections pass `access_token` as a query parameter (not just Authorization header). `BearerTokenMiddleware` checks both.

## Credit Constants (Easy to Get Wrong)
- `CashInUnit = 200,000` (per cash-in)
- `MaxSessionCashIn = 1,000,000`
- `MachineCloseCredits = 50,000,000`
- Bets: 5,000–10,000
- Royal Flush max-coin: 5,000,000

## Hardcoded Bootstrap OTP
OTP verification accepts `123456` for all users during development.

## Admin Password Stored as Plaintext
`InMemoryDataStore` stores `PasswordHash` field as the raw password string (no hashing). This is intentional for the in-memory dev store.

## Commit Attribution Required
```
Co-Authored-By: GPT-5 Codex <noreply@openai.com>
```
