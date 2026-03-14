# Debug Mode Rules (Non-Obvious Only)

## Test Runner Outputs to Console
Tests are a console app — failures print to stdout as plain text, not structured test results. Look for lines starting with `[FAIL]` in the console output. The runner exits 0 even on failures (check stdout).

## No Database to Inspect
All state lives in `InMemoryDataStore` dictionaries. There is no SQL, no migrations, no database logs. To inspect game state during debugging, add temporary logging in `GameService.cs` or the relevant controller.

## SignalR Hub Logs
The hub is `CarrePokerGameHub` in `Lucky5.Realtime/CarrePokerGameHub.cs`. Connection issues often stem from missing `access_token` query parameter on WebSocket upgrade, not Authorization header problems.

## Deterministic RNG Aids Debugging
Game outcomes are fully reproducible. If you know the seed (from `DeterministicSeed.Derive()`) and stream name, you can replay the exact same shuffle/deal/draw sequence. Use this for repro cases.

## Machine Policy Silent Deck Alteration
In Cold/Hot distribution modes, `MachinePolicy.AlterDeck()` silently reorders the deck to influence outcomes. If a hand result seems wrong, check `MachinePolicyState.DistributionMode` — the deck may have been altered before dealing.

## Two Separate Game Directories
If debugging hand evaluation or game logic, check which namespace you are in:
- `Lucky5.Domain.Game.CleanRoom` — authoritative engine (deterministic)
- `Lucky5.Domain.Game` — legacy helpers for presentation/UI noise (non-deterministic, uses `RoundNoiseRng`)

## API Port Configuration
API listens on `PORT` env var (default 5000). Docker Compose maps container 8080 → host 5051. Nginx reverse-proxies from host 8080 → api:8080. If you cannot reach the API, check which port/layer you are targeting.

## Heartbeat Monitor
`HeartbeatMonitorService` runs as a background service checking SignalR connections. Disconnected clients are auto-cleaned after the heartbeat interval (default 20s from AppSettings).
