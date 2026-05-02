# Live Protocol Forensics — 2026-05-02

Source-of-truth artifact captured from a **live production session** of the reference game
at `https://ai9poker.com/install/` (same vendor `www.nascode.com`, same hub
`CarrePokerGameHub` that Lucky5 is a clean-room of).

This document **supersedes** the string-inferred catalog in
`docs/forensics/gameplay_event_catalog.md` and the assumed contract in
`contracts/signalr/CarrePokerGameHub.md` for every item listed below.

- Raw hub capture: `tmp/ai9poker-hub-capture-2026-05-02.json` (321 messages, 148KB).
- Capture method: injected `fetch` / `XMLHttpRequest` / `WebSocket` hooks, decoded the
  `0x1E`-delimited SignalR JSON frames from long-polling traffic.

## 1. Transport

- **SignalR JSON, protocol v1**, transported over HTTP long-polling (not WebSocket in
  this run, though the server supports it).
- Record separator: `\x1e` between framed JSON objects.
- Handshake send: `{"protocol":"json","version":1}`.
- Negotiate endpoint: `POST /CarrePokerGameHub/negotiate?access_token=<jwt>&negotiateVersion=1`.
- Hub URL pattern: `/CarrePokerGameHub?access_token=<jwt>&id=<connectionToken>`.
- Auth: JWT bearer via `access_token` query param. Token header is HMAC-SHA256 with
  issuer/audience `www.nascode.com`; payload carries `{ID: string memberId, jti, exp}`.
- Ping/keepalive: message `type: 6` periodically in each direction.

## 2. Hub methods (client -> server)

Method signatures as observed on the wire (`type: 1` invocations):

| Method | Arguments | Notes |
|---|---|---|
| `Deal` | `(machineId: int, cards: Card[], holds: bool[5])` | **Single method for both initial deal and draw.** Client passes current 5 cards + which to hold; empty `cards[]` + all-false `holds[]` means "fresh deal". Server responds with `CardsDealt` and distinguishes phases via `dealCount` (0 = initial, 1 = post-draw). |
| `DoubleUp` | `(machineId: int, pickedBig: bool)` | Boolean big/small, machine-scoped not round-scoped. |
| `GetAvailableMachines` | `(gameId: int)` | Returns the lobby's machines for that game. |

Card wire shape inside the `Deal` arguments array:

```json
{ "cardID": 8, "suit": 72, "rank": 9 }
```

Suits are ASCII letter codes: `72='H' Hearts, 68='D' Diamonds, 67='C' Clubs, 83='S' Spades`.
Ranks are `2..14` where `11=J, 12=Q, 13=K, 14=A`.

`cardID` is a stable card dictionary id (see `GET /api/Game/cards`):
`1..13 = H 2..A`, `14..26 = D 2..A`, `27..39 = C 2..A`, `40..52 = S 2..A`.

## 3. Hub events (server -> client)

All payloads are `type: 1` invocation frames; the first argument is the shape below.

### `CardsDealt` — full snapshot, emitted after every Deal / Draw

```json
{
  "memberId": 6,
  "cards": [ { "cardID": 39, "title": "AC", "suit": "Clubs", "rank": "Ace" }, ... ],
  "result": { "handRank": 2, "description": "3 of a Kind", "winAmount": 30000, "isWin": true, "canWin": true },
  "kentRounds": 1,
  "inDoubleUp": true,
  "doubleUpCard": { "cardID": 12, "title": "KH" },
  "shouldReset": false,
  "dealCount": 0,
  "fullHouseBonus": false,
  "currentCarre1": 2000000,
  "currentCarre2": 395265,
  "currentFullHouse": 20000000,
  "currentKent": 5000000,
  "currentStraightFlush": 10000000,
  "carreIndex": 1,
  "currentStake": 5000,
  "shouldDetuctStake": true,
  "offerOccurred": false,
  "offerAmount": 0,
  "credit": 4445000,
  "gameId": 0,
  "currentBonusAmount": null,
  "freeGameCount": 0,
  "wasFreeGameRound": false,
  "swap10": null,
  "aceCard": false,
  "aceMultiplier": 0
}
```

Key semantics:

- `handRank` is an int enum; `description` is human readable. Observed values:
  `0: "No Win"`, `1: "2 Pair"`, `2: "3 of a Kind"`. Full ladder matches the base paytable.
- `inDoubleUp: true` + `doubleUpCard` present = a Hi-Lo round is armed after the draw.
- `dealCount` is the server's round phase counter: `0 = fresh deal` (or post-resolution
  reset), `1 = post-draw`.
- `shouldReset: true` means the cabinet should clear visuals before rendering.
- `shouldDetuctStake: true` tells the client to decrement credit by `currentStake`
  locally (stake debit is reflected in `credit` too).
- All five progressive pool values are snapshotted every event; no diff updates.

### `DoubleUpWin` — double-up resolution

```json
{
  "memberId": 6,
  "previousCard": { "cardID": 12, "suit": 72, "rank": 13, "title": "KH" },
  "nextCard":     { "cardID": 51, "suit": 83, "rank": 13, "title": "KS" },
  "pickedBig": false,
  "newWinAmount": 0,
  "lostAmount": 30000,
  "doubleUpCount": 0,
  "canContinue": false,
  "isWin": false,
  "isEquality": false,
  "lucky5": false,
  "winLucky5": false,
  "bonus": false,
  "bonusAmount": 0,
  "opened": 0,
  "credit": 4445000,
  "freeGame": false,
  "freeGameCount": 0,
  "bonusCard": false,
  "bonusCardAmount": 0,
  "currentBonusAmount": null,
  "aceCard": false,
  "aceMultiplier": 0,
  "aceMultiplierFired": false,
  "swapActivePosition": null,
  "swapActiveRemaining": 0,
  "gameId": 1
}
```

Key semantics:

- `opened` is the **cabinet door state** (`0 = closed`, `1 = opened`). The server
  applies `ClosedDoubleUpPercentage` vs `OpenedDoubleUpPercentage` to compute the
  result, then exposes which regime was used.
- `isEquality` means the two cards tied on rank; not a win, not a loss (push).
- `lucky5` fires when the next card is 5 of Spades (the cabinet's
  **"5 NEVER LOSE WHEN BUYING"** mechanic). `winLucky5` indicates it resolved to a win.
- `canContinue: true` means the player may double up again; `doubleUpCount` increments.
- `bonusCard` / `bonusCardAmount` — random bonus card injection during the double-up.
- `aceMultiplierFired` — whether the ace-multiplier condition triggered on this step.
- `swapActivePosition` / `swapActiveRemaining` — swap mechanic state (see SwapDoubleUpCard).

### `SwapDoubleUpCard` — swap animation frame

```json
{
  "nextCard": { "cardID": 51, "suit": 83, "rank": 13, "title": "KS" },
  "lucky5": false,
  "winLucky5": false,
  "gameId": 1,
  "isFreeGame": false,
  "isBonus": false,
  "freeGameCount": 0,
  "aceCard": false,
  "aceMultiplier": 1
}
```

Emitted in rapid bursts (avg 542 ms between consecutive `SwapDoubleUpCard` events)
when the player triggers swap. Represents the animated cycling of candidate cards
before `DoubleUpWin` finalizes.

### `BetPlaced`, `HoldCardUpdated` — presentation sync

Observed but low frequency (`BetPlaced` fires once per bet change; `HoldCardUpdated`
fires on hold toggles). Payload shape not yet fully captured; assume simple
`{ machineId, memberId, value }` style. Used to keep spectators in sync and to
broadcast UI changes to other connections of the same user.

### `MachineStatusChanged` — lobby presence

```json
{ "machineId": 117, "isOccupied": false, "playerId": null, "gameId": 2 }
```

Server broadcasts whenever a seat is claimed/released anywhere in the lobby — lets
the client show a live "machines available" board.

### `UserStatusChanged` — user presence

Arguments tuple: `[userId: int, state: "Active" | "Reconnecting"]`. Broadcast when
other players connect, disconnect, or enter reconnection backoff.

## 4. REST endpoints observed live

| Method | Path | Purpose | Lucky5 parity |
|---|---|---|---|
| POST | `/api/Auth/login` | `{PhoneNumber, Password, platform, appVersion}` -> `{AccessToken, RefreshToken, User}` | **different**: Lucky5 uses username/password |
| POST | `/api/Auth/logout` | session end | present |
| GET  | `/api/Auth/GetUserById?memberId=<id>` | profile | present (but by claim, not query) |
| GET  | `/api/Game/games` | game catalogue (GameID list) | **missing** |
| GET  | `/api/Game/games/machines/{machineId}` | **full machine config snapshot** (see §5) | **missing** |
| GET  | `/api/Game/defaultRules` | `[{RuleID, Amount, RuleName}]` base multipliers | present (different shape) |
| GET  | `/api/Game/cards` | card dictionary | present-ish |
| GET  | `/api/General/app-settings` | app-wide config (theming, limits, flags) | **missing** |

Observed `defaultRules` (multipliers of stake):

```json
[
  { "RuleID": 1, "Amount": 1000, "RuleName": "ROYAL FLUSH" },
  { "RuleID": 2, "Amount": 300,  "RuleName": "STRAIGHT FLUSH" },
  { "RuleID": 3, "Amount": 120,  "RuleName": "4 OF A KIND" },
  { "RuleID": 4, "Amount": 20,   "RuleName": "FULL HOUSE" },
  { "RuleID": 5, "Amount": 14,   "RuleName": "FLUSH" },
  { "RuleID": 6, "Amount": 10,   "RuleName": "STRAIGHT" },
  { "RuleID": 7, "Amount": 6,    "RuleName": "3 OF A KIND" },
  { "RuleID": 8, "Amount": 4,    "RuleName": "2 PAIR" }
]
```

## 5. Machine configuration — `GET /api/Game/games/machines/{id}`

Full payload observed for machine 59 ("Machine 18"):

```json
{
  "MachineID": 59, "GameID": 1, "MachineName": "Machine 18",
  "MinBetAmount": 5000, "MaxBetAmount": 10000,
  "MachineAmount": 1507000, "CurrentUserAmount": 0,
  "OpenAmount": 36000000, "CounterStatus": false,
  "Active": true, "Ready": false,
  "OpenedDoubleUpPercentage": 100, "ClosedDoubleUpPercentage": 1,
  "AutoOpenClosePercentage": false,
  "CarreIndex": 1, "CurrentMemberID": 6,
  "Profit": 8771098,
  "WinBonusDefaultPokerRulesID": 0, "WinBonusAmount": 0,
  "MaxStraightFlush": 10000000, "MaxCarre1": 2000000, "MaxCarre2": 2000000,
  "MaxFullHouse": 20000000, "MaxKent": 5000000,
  "MinStraightFlush": 5000000, "MinCarre1": 287645, "MinCarre2": 301265,
  "MinFullHouse": 12547667, "MinKent": 1287345,
  "CurrentStraightFlush": 10000000, "CurrentCarre1": 2000000,
  "CurrentCarre2": 369265, "CurrentFullHouse": 20000000, "CurrentKent": 5000000,
  "KentRounds": 1, "DoubleUpLimit": 10000, "FullHouseCardID": 13,
  "FirstRechargeCredit": 200000, "FirstRechargeBonus": 15000,
  "SecondRechargeCredit": 400000, "SecondRechargeBonus": 30000
}
```

### Fields we already model in Lucky5

- Pools: `JackpotFullHouse`, `JackpotFourOfAKindA`, `JackpotFourOfAKindB`,
  `JackpotStraightFlush` in `MachineLedgerState`. Equivalents exist for `currentFullHouse`,
  `currentCarre1`, `currentCarre2`, `currentStraightFlush`.
- Rotating rank: `JackpotFullHouseRank` — equivalent to `FullHouseCardID`.
- Carre rotation: `ActiveFourOfAKindSlot` — equivalent to `CarreIndex`.

### Fields missing from Lucky5 (`Machine.cs` + `MachineLedgerState.cs`)

- **Kent pool:** `CurrentKent / MinKent / MaxKent` (Lucky5 has Kent as an identifier
  string, not a progressive pool). `KentRounds` for streak tracking.
- **Operational money:** `MachineAmount`, `OpenAmount`, `CurrentUserAmount`, `Profit`.
- **Seat lock:** `CurrentMemberID` (the member currently seated; blocks other joiners).
- **Door / tamper:** `Ready`, `CounterStatus`, `OpenedDoubleUpPercentage`,
  `ClosedDoubleUpPercentage`, `AutoOpenClosePercentage`.
- **Double-up cap:** `DoubleUpLimit`.
- **Recharge bonus tiers:** `FirstRechargeCredit/Bonus`, `SecondRechargeCredit/Bonus`.
- **Operator override:** `WinBonusDefaultPokerRulesID`, `WinBonusAmount`.

## 6. Cabinet UI and feel

### Dimensions and stack

- Viewport in production: **486 x 886** CSS px (portrait, ~9:16).
- Rendered by **Flutter Web (canvaskit)** — a single canvas, no DOM hierarchy. Our
  existing DOM cabinet in `src/web/components/lucky5-cabinet.tsx` is an acceptable
  visual twin if we match the layout and palette.
- Assets bundle: `InterRegular/Medium/SemiBold/Bold/ExtraBold`, `Impact`, `ARCADE`,
  LineAwesome icons, card PNGs at `assets/images/cards/{RankSuit}.png` (e.g. `AH.png`),
  button PNGs with on/off states (`deal_draw.png` + `deal_draw_on.png`).

### Layout (top to bottom)

1. **Paytable strip** — 8 rows: ROYAL/STRAIGHT FLUSH, 4 OF A KIND, FULL HOUSE, FLUSH,
   STRAIGHT, 3 OF A KIND, 2 PAIR. Hand labels on left, amount on right. Each row has
   a dedicated color: red, orange, cyan/teal, yellow, red-pink, green, cyan, pale.
   FULL HOUSE row shows the current progressive pot (not the multiplier).
2. **Credit / Stake strip** on the right (green CREDIT label, yellow STAKE).
3. **Card row** — 5 cards. Card back: pink twill pattern with a crown diamond motif.
   "10CAR" label appears above leftmost card when a 10 is live (swap indicator).
4. **DOUBLE UP / SERIE / KENT counters** row — small CRT-green text. Shows the
   rolling pool value (e.g. `5000000`) and the serie counter `1x`, and Kent counter
   (`KENT /3 . 1`).
5. **FREE GAMES 000 / BONUS CARD 3000000** status band (only when active).
6. **Side-by-side progressive pools display:** `CarreA | StraightFlush x CarreB` with
   dedicated colors (green, red, green).
7. **4 OF A KIND WINS BONUS** banner when rotation is active.
8. **Control deck** (wood-textured panel, ~320px tall):
   - Row 1: HOLD x5 (yellow glossy, curved tops).
   - Row 2: BIG (orange), SMALL (orange), CANCEL HOLD (cream/white), DEAL DRAW (red), BET (green).
   - Row 3: TAKE HALF (red), MENU (black round burger icon), TAKE SCORE (orange).

### Pacing (measured from 321 live events)

These are the **target animation / state-hold timings** our cabinet should match:

| Transition | Count | Avg ms | Min ms | Max ms |
|---|---|---|---|---|
| `CardsDealt -> CardsDealt` (round-to-round) | 93 | 1768 | 1172 | 9625 |
| `SwapDoubleUpCard -> SwapDoubleUpCard` | 12 | 542 | 444 | 1071 |
| `SwapDoubleUpCard -> DoubleUpWin` | 7 | 886 | 600 | 1354 |
| `CardsDealt -> DoubleUpWin` | 5 | 2670 | 1972 | 4557 |
| `CardsDealt -> SwapDoubleUpCard` | 3 | 1829 | 1045 | 2464 |
| `DoubleUpWin -> CardsDealt` | 10 | 1997 | 1534 | 2956 |
| `BetPlaced -> CardsDealt` | 2 | 758 | 753 | 763 |

Design constants derived:

- **DEAL_ANIM_MS = 1700** — deal reveal + think time before next deal.
- **SWAP_FRAME_MS = 540** — swap cycle frame duration.
- **DU_REVEAL_MS = 2700** — draw-to-doubleup dealer reveal window.
- **DU_RESOLUTION_MS = 2000** — post-double-up settle back to idle.
- **BET_TO_DEAL_MS = 760** — bet press to first card reveal.

## 7. Persistence model

### Client side (ai9poker observed)

- **localStorage**, single key `GetStorage` (Flutter `get_storage` package convention):

```json
{
  "userData": {
    "AccessToken": "<jwt>",
    "RefreshToken": "<base64>",
    "User": { "UserID": 6, "Username": "Riro", "PhoneNumber": "70202320", ... }
  }
}
```

- No sessionStorage. No cookies. No IndexedDB. Everything lives under one JSON blob.
- Refresh token is present (opaque base64), so silent JWT refresh is supported.

### Lucky5 current state

- `src/web/components/lucky5-cabinet.tsx` holds auth state in React state only
  (`accessToken`, `profile`) and does not persist across reloads. Tokens are lost on
  F5. There is no refresh-token flow on the client.
- There is no `useCarrePokerHub` — the cabinet polls `/api/Game/machine/{id}/state`
  every 5 seconds. We are paying latency for state we could subscribe to.
- Server persistence is in-memory only (confirmed in AGENTS.md). `dataconnect/schema/schema.gql`
  exists as the eventual PostgreSQL schema.

## 8. Delta summary vs existing Lucky5 contracts

### `contracts/signalr/CarrePokerGameHub.md` — wrong on

- Method signatures: `Deal(machineId, betAmount)` + separate `Draw(roundId, holds)`
  -> **should be** single `Deal(machineId, cards[], holds[])`.
- `DoubleUp(roundId, guess: "big"|"small")` -> **should be**
  `DoubleUp(machineId, pickedBig: bool)`.
- `JoinMachine / LeaveMachine` -> **not used** in live protocol; replaced implicitly
  via `Deal` and explicitly via `GetAvailableMachines(gameId)`.
- Event names: `CardRevealed / RewardStatus / WalletUpdated / MachineStateUpdated`
  -> **should be** `CardsDealt / DoubleUpWin / SwapDoubleUpCard / MachineStatusChanged
  / UserStatusChanged / BetPlaced / HoldCardUpdated`.

### `docs/forensics/gameplay_event_catalog.md` — inherited the same errors from AOT string inference.

### `docs/forensics/endpoint_catalog.md` — add

- `GET /api/Game/games/machines/{machineId}` (was normalized to `/games/machines`).
- `GET /api/Game/games` (game catalogue, distinct from machines).

### `src/web/lib/types.ts` and `lucky5-cabinet.tsx` — gaps

- `DealResult` is missing: `dealCount`, `inDoubleUp`, `doubleUpCard`, `carreIndex`,
  `fullHouseBonus`, `shouldReset`, `kentRounds`, per-pool currents, `offerOccurred`,
  `offerAmount`, `freeGameCount`, `wasFreeGameRound`, `swap10`, `aceCard`, `aceMultiplier`,
  `credit`.
- `DoubleUpResult` is missing: `opened`, `isEquality`, `bonusCard / bonusCardAmount`,
  `freeGame / freeGameCount`, `aceMultiplierFired`, `swapActivePosition / swapActiveRemaining`.
  (`isLucky5Active`, `luckyMultiplier`, `switchesRemaining` already exist.)
- Cabinet has no live Kent counter, no pool row, no rotating full-house target,
  no presence indicators, no SignalR connection.

## 9. Next steps

Execution plan lives in the session todo list (slices A1..A7, C1..C4, B1..B6,
D1..D4, E1..E4). Slice A1 closes with the commit of this document and the raw
capture at `tmp/ai9poker-hub-capture-2026-05-02.json`. Slices A2..A5 and E1 are
the highest leverage for the next session.
