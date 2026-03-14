# Continuation Guide

This document is the fastest way for another developer to catch up on the current Lucky5 codebase.

## Live frontend

The production frontend is the vanilla app served from:

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`

Do **not** start from the prototype folders for feature work unless you are intentionally rebuilding the frontend.

## Core backend files

- `server/src/Lucky5.Api/Controllers/GameController.cs` — gameplay, machine session cash-in/out, jackpot rank, machine state
- `server/src/Lucky5.Api/Controllers/AuthController.cs` — signup/login/OTP/profile/history
- `server/src/Lucky5.Api/Controllers/AdminController.cs` — admin-only user/machine tools
- `server/src/Lucky5.Infrastructure/Services/GameService.cs` — authoritative game flow
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs` — admin balance adjustments and machine inspection/reset
- `server/src/Lucky5.Infrastructure/Services/AuthService.cs` — auth and wallet profile operations
- `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs` — all in-memory state
- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs` — RTP / variance shaping / double-up deck pressure

## Economy model

There are now two balances:

1. **Lobby wallet balance**
   - shown in the lobby / wallet screens
   - stored on `MemberProfile.WalletBalance`
2. **Machine credit balance**
   - shown on the game CREDIT display
   - stored per player + machine in `MachineSessionState.MachineCredits`

### Machine session rules

- players cash in to the machine in **200,000** increments
- total cash-in per machine session is capped at **1,000,000**
- cash-out to wallet is allowed when either:
  - the machine session is marked closed, or
  - machine credits reach at least **2x** total cash-in

## Jackpot / double-up rules

- jackpot values can start at max
- jackpot wins reset to 20% baseline values
- jackpot values never grow above their max caps
- jackpot win value goes straight to **machine credits**
- only the **base paytable win** enters double-up
- the Lucky 5 no-lose state only arms when 5♠ is reached through **SWITCH**; opening dealer 5♠ and BIG/SMALL reveal 5♠ are visual only
- the paytable row for the active hand is reused as the live score row during win/double-up

## Machine closed

Machine closed is a gameplay event, not a hard reset.

- machine ledgers continue accumulating history
- machine session is flagged closed for the current player
- player is expected to cash out machine credits back to the wallet
- machine RTP memory should keep running across closes

## RTP / fun policy

`MachinePolicy.cs` now uses:

- target RTP
- jackpot RTP pressure (not just base paytable RTP)
- net since last close
- Lucky 5 drought
- loss streak pressure
- counterplay / counterintuitive-hold pressure

This is meant to soften very long online dry spells while still letting the machine breathe with ups/downs and close misses.

The latest tuning pass also tightened the negative correction when the observed RTP is already above target, so jackpot-heavy periods push the normal paytable scale down faster instead of compounding the overshoot.

## Strange player behavior handling

`GameService.DrawAsync()` compares actual holds against advised holds and updates `MachineSessionState.CounterplayScore`.

This is then fed back into:

- deal-time policy mode selection
- draw-time payout scale pressure

So if a player repeatedly destroys strong hands or plays in an obviously counterintuitive way, the machine can compensate and keep the experience from becoming dead or overly punishing.

## Admin tools

Current admin features:

- search/list users
- credit or debit wallet balances with reasons
- inspect machine RTP and jackpot state
- inspect per-player machine sessions on each machine
- reset machine state separately from wallet adjustments

## Adding a new lobby game

1. Add a new entry to `AVAILABLE_GAMES` in `wwwroot/js/game.js`
2. Add any new route/screen handling in `showLobby()` / `openGame()`
3. Add the new backend controller/service if the game needs its own logic
4. Keep the existing Lucky5 frontend isolated so variants do not break the live cabinet

## Known limitation / next important step

Machine ledgers and machine sessions still live in memory. That means they can survive for long-running single-instance deployments, but **not** across process restarts or redeploys.

Also note that `DealAsync()` now requires enough machine credits for **both** deal and draw up front. That is deliberate: it avoids dead-end rounds where a player can start a hand but cannot afford the mandatory draw cost.

For true month-scale durability, the next big engineering step is persistent storage for:

- `MachineLedgerState`
- `MachineSessionState`
- optionally audit/history rows
