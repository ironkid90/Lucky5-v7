# Architect Mode Rules (Non-Obvious Only)

## CleanRoom is the Only Authoritative Game Engine
All architectural decisions about game logic MUST route through `Lucky5.Domain.Game.CleanRoom/`. The non-CleanRoom `Game/` directory exists for historical/presentation reasons only. Never propose new game rules or evaluation logic outside CleanRoom.

## Stateless Engine, Stateful Service Layer
`FiveCardDrawEngine` and `Lucky5DoubleUpEngine` are pure static classes with no state. All mutable state lives in `GameService` (Infrastructure layer) which orchestrates `InMemoryDataStore` dictionaries. This separation is intentional — the engine can be tested without any infrastructure.

## Machine Policy is a Hidden RTP Controller
`MachinePolicy` silently alters deck composition based on `CreditsIn/CreditsOut` ratio vs `TargetRTP`. It operates in Cold (house-favorable), Neutral, or Hot (player-favorable) modes. Any architecture change must preserve this RTP control loop. Streak tracking, cooldowns (post-big-win suppression), and payout scaling (0.5x–4.0x) are all part of this system.

## No Real Persistence Layer Yet
`InMemoryDataStore` is the only persistence. When designing database architecture, note that:
- Machine sessions keyed by `"{userId}:{machineId}"` string
- Machine ledgers track cumulative CreditsIn/CreditsOut for RTP calculation
- Active rounds stored by `Guid` round ID
- All data lost on restart

## SignalR is the Real-Time Transport
`CarrePokerGameHub` handles real-time game events. `ConnectionRegistry` maps userId→connectionId. `HeartbeatMonitorService` runs as a hosted background service. Auth uses query parameter `access_token` on WebSocket upgrade.

## Cabinet Design is Sacrosanct
The retro Lebanese poker machine aesthetic defined in `docs/GAME_FEEL_REFERENCE.md` must be preserved. Do not propose modernizing into a standard online casino UI. The amber/gold on dark theme with grid overlay (`src/web/app/globals.css`) is intentional.

## Web-First Development Priority
Architecture decisions should prioritize the web cabinet (`src/web/`) over Flutter (`client/`) or mobile Capacitor wrapper (`mobile/`). The Flutter client exists but is secondary.

## Presentation Noise is Separate from Game Logic
`PresentationNoiseGenerator` creates fake "near miss" card sequences and tension delays for the UI. This is purely cosmetic — it does NOT affect actual game outcomes. Keep this boundary clear in any architectural proposals.

## Infrastructure Docker Stack
Local development uses: Postgres 16, Redis 7, Nginx reverse proxy, Seq for structured logging. The API itself does not yet use Postgres/Redis — they are provisioned for future migration from InMemoryDataStore.
