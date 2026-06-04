# AI9Poker Cabinet Reference Capture - 2026-06-04

Status: presentation reference for Lucky5 Godot and web cabinet parity. This note
does not authorize changes to payout math, RNG, double-up odds, jackpot math,
wallet settlement, or server authority.

## Source Inputs

- In-app browser: `https://ai9poker.com/install#/minified:z8`, title `Ai9Poker`.
- Fresh in-app browser capture: `https://ai9poker.com/install#/minified:Cu`,
  title `Ai9Poker`, 552x912 viewport, saved at
  `docs/assets/ai9poker-reference-current-2026-06-04.jpg`.
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
- The current 552x912 browser capture shows the same cabinet at STAKE 40,000:
  eight paytable rows on the left, `CREDIT`/`STAKE` on the right, five large
  cards across the middle, HOLD badges under held cards, a jackpot/bonus strip
  below the cards, and a brown wood-grain control deck in the bottom third.
- Machine identity/counter block sits below the cards:
  `SERIE`, `KENT /3`, side four-of-a-kind counters, center straight-flush
  counter, serial number, and the `4 OF A KIND   WINS BONUS` banner.
- The current browser capture shows a cabinet variation with `FREE GAMES BONUS`
  in the lower strip; the bundle also contains the `4 OF A KIND` / `WINS BONUS`
  text pair used by the Lucky5 reference docs.
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
- The physical button string block is exactly:
  `["BIG","SMALL","CANCEL\nHOLD","DEAL\nDRAW","BET","TAKE\nHALF","TAKE\nSCORE"]`.
- The bundle contains `DOUBLE UP` as an in-screen cue, but does not expose
  visible physical deck labels named `DOUBLE UP`, `SWITCH DEALER`, or
  `SWITCH\nDEALER`. Lucky5 should keep double-up entry and dealer switching on
  the physical controls instead of adding extra standalone deck buttons.

## Physical Control Contract

- `BIG` and `SMALL` are the primary double-up guess buttons. After a paying
  draw, pressing either one may enter double-up directly if the backend has not
  already started the session.
- `BET` is stake-cycle during normal idle/deal setup. During an active
  double-up session with switches remaining, `BET` maps to the dealer switch
  action. Do not add a separate visible `SWITCH DEALER` deck button.
- `DEAL DRAW` is the single red deal/draw command and stays in the same deck
  position through idle, deal, and draw.
- `CANCEL HOLD` clears held cards in the draw phase.
- `TAKE HALF` and `TAKE SCORE` stay visible during win and double-up states.
  They are not modal actions.
- `MENU` is the center circular overlay entry. Admin/agent tooling may live
  behind a cabinet side panel, but it must not replace the physical deck.

## Gameplay Flow Notes

- Base flow: login/join machine, cash in, cycle stake with `BET`, press
  `DEAL DRAW`, toggle HOLD buttons, press `DEAL DRAW` again, evaluate, then
  take score, take half, or enter double-up through `BIG`/`SMALL`.
- Deal and draw presentation remains one-card-at-a-time, left-to-right. Held
  cards keep their HOLD badge and do not animate as replaced cards.
- Paytable, credit/stake, jackpot counters, `SERIE`, and `KENT /3` remain
  visible during normal play and double-up. Lucky5 should not move these into a
  lobby-style HUD.
- Full House rank switching is a pre-deal jackpot-rank action and remains
  separate from double-up dealer switching. The AI9 bundle exposes
  `SwapFullHouseCard` and `SwapDoubleUpCard`; Lucky5 keeps the corresponding
  backend authority in its own route names.

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
- Keep the printed rule text visible near the double-up board:
  `HI LO GAMBLE`, `ACE COUNTS`, `HI OR LO`, `5 [spade] NEVER LOSE`, and
  `WHEN BUYING`. Brighten or pulse the Lucky 5 line only when the backend says
  the no-lose/buy state is active.
- `SwapDoubleUpCard`/dealer-switch presentation should feel like a quick
  cabinet card swap, then settle back into the same five-slot board. It is a
  `BET`-button action in the Lucky5 UI, not an independent game mode.

## Current Implementation Slice

For this pass, parity work is presentation-only:

- Web cabinet: five-slot double-up board, source labels, jackpot-rank label
  cleanup, paytable amounts based on the active stake instead of a fixed 5,000
  wager, sequential card animation classes, and double-up shuffle/reveal
  classes.
- Web physical controls: `BIG`/`SMALL` enter or continue double-up;
  `BET` switches dealer during active double-up when switches remain; no
  visible standalone `DOUBLE UP` or `SWITCH DEALER` buttons are introduced.
- Web admin/agent upgrade: an admin-only cabinet side panel exposes agents,
  users, and machines; admins can create agents, load agent credit, search
  users, and assign a user to an agent without leaving the cabinet.
- Web install shell: the fallback cabinet links `/manifest.webmanifest`, locks
  the app shell to a portrait standalone/fullscreen install target, and emits
  mobile web app metadata for browser and Android-compatible testing.
- Godot cabinet: five-slot double-up board fed by normalized
  `double_up.card_trail`, `dealer_card`, `challenger_card`, switch count, and
  Lucky 5/no-lose flags.
- Godot physical controls: the main deck keeps the AI9Poker button vocabulary
  and routes double-up dealer switching through the `BET` control when the
  backend exposes remaining switches.
- Godot admin/agent upgrade: the admin overlay has an `AGENTS` section with
  create/load/select behavior and `ASSIGN` actions on user rows, backed by
  `/api/Agent` endpoints.
- Shared behavior: keep existing backend contracts and command names. Do not
  rename actions to AI9Poker hub names.
- Backend authority: `GameService.GuessDoubleUpAsync` starts double-up when a
  guess arrives before a session exists, and all double-up, take-half,
  jackpot-rank, balance, machine, and agent mutations remain server-owned.

## Verification Evidence

- `git diff --check -- ':!src/web/.next'` passed after this note update; it
  only reported the repo's normal LF-to-CRLF warnings on touched files.
- `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj` passed
  after this note update with `Lucky5 regression suite passed.`
- `./scripts/godot/Test-GodotCabinet.ps1` passed after this note update with
  `status: "passed"` on Godot `4.6.3.stable.official.7d41c59c4`.
- Web TypeScript passed after this note update with `tsc --noEmit
  --incremental false --pretty false`.
- `next build` passed after the web install-shell update; the build exposes
  `/manifest.webmanifest` as a static app route and no longer emits the
  unsupported Next `themeColor` metadata warning.
- Production web smoke on `http://127.0.0.1:3011/` returned the cabinet shell,
  linked `/manifest.webmanifest`, emitted `mobile-web-app-capable=yes` and
  `apple-mobile-web-app-capable=yes`, and served a portrait standalone manifest
  with fullscreen override and any/maskable icons.
- Local HTTP smoke after this note update: `http://127.0.0.1:3000/` returned
  200 and served the cabinet bundle; `http://127.0.0.1:5051/health/live`
  returned `Healthy`; `http://127.0.0.1:5051/api/Game/machines` returned 3
  machines.
- Earlier browser smoke during this implementation pass verified the admin/agent
  panel: admin login, agents/users/machines tabs, agent creation, agent credit
  load, and assigning `tester` to the created agent.
- Current AI9Poker visual reference was captured from the open in-app browser
  tab on 2026-06-04 and saved as
  `docs/assets/ai9poker-reference-current-2026-06-04.jpg`.
