# AI9Poker Cabinet Reference Capture - 2026-06-04

Status: presentation reference for Lucky5 Godot and web cabinet parity. This note
does not authorize changes to payout math, RNG, double-up odds, jackpot math,
wallet settlement, or server authority.

## Source Inputs

- In-app browser: `https://ai9poker.com/install#/minified:z8`, title `Ai9Poker`.
- Local source bundle: `temp/main.dart.js`, size 4,754,564 bytes, last write
  2026-05-17 in this workspace.
- Existing Lucky5 references:
  `docs/LUCKY5_AUTHORITATIVE_GAMEPLAY_REFERENCE.md`,
  `docs/GAME_FEEL_REFERENCE.md`, and
  `docs/contracts/godot-cabinet/ai9poker-comparison-event-matrix.md`.

## Observed Cabinet Frame

- Portrait black CRT playfield with rainbow paytable in the upper left.
- Top-right credit/stake block reads `CREDIT` above the amount and `STAKE`
  above the wager.
- The idle field shows one large full-house-rank card in the center area.
- Machine identity/counter block sits below the cards:
  `SERIE`, `KENT /3`, side four-of-a-kind counters, center straight-flush
  counter, serial number, and the `4 OF A KIND   WINS BONUS` banner.
- Brown wood-grain control deck has a five-button HOLD row, then
  `BIG`, `SMALL`, `CANCEL HOLD`, `DEAL DRAW`, `BET`, then
  `TAKE HALF`, circular `MENU`, and `TAKE SCORE`.

## Source Bundle Evidence

The compiled Flutter bundle confirms the presentation vocabulary and event
surfaces Lucky5 should mirror at the client boundary:

- SignalR-style event names include `CardsDealt`, `BetPlaced`,
  `DoubleUpWin`, `SwapDoubleUpCard`, `HoldCardChanged`, and
  `CancelHoldChanged`.
- Hub/action names include `HoldCard`, `CancelHold`, and `SwapDoubleUp`.
- Double-up labels include `HI LO GAMBLE`, `ACE COUNTS`, `HI OR LO`,
  `5 [spade] NEVER LOSE`, and `WHEN BUYING`.
- Machine info labels include `SERIE`, `KENT /3`, `4 OF A KIND`, and
  `WINS BONUS`.
- Button labels include `BIG`, `SMALL`, `CANCEL HOLD`, `DEAL DRAW`, `BET`,
  `TAKE HALF`, and `TAKE SCORE`.

## Double-Up Presentation Target

Lucky5 already owns double-up state server-side. The client target is a fixed
five-slot progressive board:

- Render recent trail cards, the current dealer card, and the active
  reveal/challenger slot in the same five-card cabinet rhythm instead of a
  two-card duel.
- Avoid duplicating the current dealer card when it is also the last
  `card_trail` entry from the backend.
- Keep the active reveal slot visually alive with the existing fast shuffle
  cadence. The AI9Poker-like cadence in Lucky5 docs is about 50-80 ms; Godot
  currently uses 80 ms.
- Keep `BIG` and `SMALL` as physical-choice controls. Do not infer game
  acceptance from local animation; backend response/snapshot remains
  authoritative.

## Current Implementation Slice

For this pass, parity work is presentation-only:

- Web cabinet: five-slot double-up board, source labels, jackpot-rank label
  cleanup, and paytable amounts based on the active stake instead of a fixed
  5,000 wager.
- Godot cabinet: five-slot double-up board fed by normalized
  `double_up.card_trail`, `dealer_card`, `challenger_card`, switch count, and
  Lucky 5/no-lose flags.
- Shared behavior: keep existing backend contracts and command names. Do not
  rename actions to AI9Poker hub names.
