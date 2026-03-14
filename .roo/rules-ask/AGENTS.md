# Ask Mode Rules (Non-Obvious Only)

## Misleading Directory Names
- `sources/` contains decompiled Java from the original Android APK — reference only, never edit. File names (`b2/f.java`, `C0/a.java`) are obfuscated.
- `server/src/Lucky5.Api/wwwroot/` is the original vanilla JS cabinet — NOT the active frontend.
- `src/web/` is the active React/Next.js cabinet despite being outside `server/`.
- `Game/` (non-CleanRoom) in Domain is legacy presentation code, NOT the game engine.

## "Carré" = Lebanese Poker Term
The SignalR hub is named `CarrePokerGameHub` because "Carré" means four-of-a-kind in Lebanese poker parlance. This is not a typo or French word — it is the local term used in the target market (Lebanon).

## Documentation Lives in `docs/`
- `docs/GAME_FEEL_REFERENCE.md` — canonical cabinet feel reference (retro aesthetic, not modern casino)
- `docs/forensics/` — deep dives into endpoint catalog, gameplay events, and module map
- `docs/CONTINUATION_GUIDE.md` — next steps and roadmap
- `contracts/` — OpenAPI spec (`lucky5-v1.yaml`) and SignalR hub documentation

## Lebanese Paytable is Counterintuitive
`MinimumPairRankForPayout = int.MaxValue` means ALL pairs pay (the threshold is unreachable). `JacksOrBetter` uses rank 11 (jacks). This naming is backwards from what you might expect.

## Two Frontends Exist
1. Vanilla JS in `server/src/Lucky5.Api/wwwroot/` — original, served by the .NET API directly
2. React/Next.js in `src/web/` — active development target, single component `lucky5-cabinet.tsx`

## Mobile is a Capacitor Wrapper
`mobile/` wraps the web cabinet into an Android app via Capacitor. `scripts/sync-web.mjs` copies web build into `mobile/www/`. There is no native mobile code.

## Flutter Client is Separate
`client/` is a standalone Flutter app connecting via SignalR (`signalr_netcore` package). It is NOT the primary development target — web-first is the current priority.
