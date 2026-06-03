# Lucky5 v7

A clean-room recreation of a Lebanese amusement video poker machine (1990-2010 era).

**Godot 4.6 portrait cabinet** + **.NET 9 API server**

Features authentic Lebanese arcade aesthetics, machine-credit vs wallet-credit economy, progressive jackpots, inline double-up Hi-Lo mechanic, switch-only Lucky 5 protection, admin telemetry, agent lobby, daily reward bonuses, agent-based user tracking, and deterministic policy logic targeting ~85% RTP.

## Prerequisites

- **.NET 9 SDK** (or later) — https://dotnet.microsoft.com
- **Godot 4.6** (or later) — https://godotengine.org
- PowerShell 7+ (Windows) or bash (Linux/macOS)

## 1-Click Quick Start

```powershell
# Starts server + Godot cabinet
.\dev.ps1

# Server + legacy web cabinet fallback
.\dev.ps1 -Web

# API only (headless, for testing/debugging)
.\dev.ps1 -Headless -Port 8080
```

The API starts on `http://localhost:5051`. The Godot cabinet connects to the API automatically.

## Credentials

| Username | Password | Role |
|----------|----------|------|
| `admin` | `admin123` | Admin (full access) |
| `tester` | `password` | Player (test account, 50M balance) |

## Running Tests

```powershell
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj

# Optional Godot smoke test when GODOT_BIN or Godot on PATH is available
.\scripts\godot\Test-GodotCabinet.ps1
```

## Building for Production

```powershell
# Publish .NET API as self-contained executable
dotnet publish server/src/Lucky5.Api/Lucky5.Api.csproj -c Release -o publish

# Run the published server
cd publish && dotnet Lucky5.Api.dll
```

## Repository Structure

```
server/
├── src/Lucky5.Api/            ASP.NET Core 9 host, controllers, auth middleware
├── src/Lucky5.Application/    Service contracts, DTOs, request models
├── src/Lucky5.Domain/         Core engine, entities, CleanRoom game logic
│   └── Game/CleanRoom/        Authoritative RTP/variance/deterministic logic
├── src/Lucky5.Infrastructure/ Service implementations, in-memory data store
├── src/Lucky5.Realtime/       SignalR hub for cabinet communication
└── src/Lucky5.Simulation/     RTP simulation runner

godot/cabinet/                 Godot 4.6 portrait cabinet client
├── scenes/                    Game scenes (CabinetRoot.tscn)
├── scripts/                   GDScript game logic (cabinet_root.gd, etc.)
├── skins/lucky5/cards/        52-card deck + back sides (high-res PNG)
└── addons/                    Card framework, state machine, shader library

docs/                          Developer documentation
scripts/                       Build, test, and utility scripts
```

## Feature Highlights (v7)

- **Dual wallet**: `Credit` (bonus/agent-funded) + `WalletBalance` (cash), credit consumed first
- **Daily reward**: spin-based bonus, idempotent daily gate
- **Agent system**: agent entities, credit pool, user assignment — full admin API
- **Session hardening**: active-round hydration, safe back-to-lobby, idempotent cash-out
- **In-memory store**: zero external dependencies for local dev and testing
- **Optional persistence**: file-backed snapshots via `Persistence:FileStore:RootPath`

## Documentation

| Document | Purpose |
|---|---|
| [docs/README.md](docs/README.md) | Full game rules, paytable, API reference |
| [docs/CONTINUATION_GUIDE.md](docs/CONTINUATION_GUIDE.md) | Developer handoff — economy, architecture |
| [docs/GAME_FEEL_REFERENCE.md](docs/GAME_FEEL_REFERENCE.md) | Visual/UX reference from original cabinet |
| [docs/LUCKY5_AUTHORITATIVE_GAMEPLAY_REFERENCE.md](docs/LUCKY5_AUTHORITATIVE_GAMEPLAY_REFERENCE.md) | Gameplay rules and mechanics |
| [docs/GODOT_KIOSK_RELEASE.md](docs/GODOT_KIOSK_RELEASE.md) | Kiosk release instructions |
| [docs/forensics/](docs/forensics/) | APK reverse-engineering findings |
