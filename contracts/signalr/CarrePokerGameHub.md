# CarrePokerGameHub Contract (v2)

Hub route: `/CarrePokerGameHub`

**Status.** v2 is the live-protocol target, derived from the reference cabinet
session captured in `docs/forensics/live_protocol_2026-05-02.md`. The current
Lucky5 server still implements the v1 shape (separate `Deal` + `Draw`, event
names `CardRevealed / RewardStatus / WalletUpdated / MachineStateUpdated`);
those are retained as **legacy aliases** until the migration slices A5 and D1
land, at which point v1 clients keep working via server-side dual emission.

## Connection and auth

- Transport: SignalR JSON, protocol v1, WebSockets preferred, long-polling fallback.
- Framing: `\x1e`-delimited JSON per SignalR spec. Handshake send:
  `{"protocol":"json","version":1}`.
- Auth: bearer JWT via `access_token` query parameter on negotiate and hub URLs, or
  `Authorization: Bearer <jwt>` header. Claims: `ID` = member id, `jti`, `exp`.
- Reconnect backoff: `1s, 2s, 5s, 10s`.
- Keepalive: SignalR ping (`type: 6`) every `20s` target.
- Server stale threshold: `(2 x keepalive) + 5s`.

## Card wire shapes

Two card representations coexist on the wire:

- **Short card** (inside client `Deal` arguments): `{ cardID, suit, rank }` where
  `suit` is the ASCII code of `H/D/C/S` (72/68/67/83) and `rank` is `2..14`.
- **Long card** (inside server events): `{ cardID, title, suit, rank }` where
  `suit` is the word `"Hearts" | "Diamonds" | "Clubs" | "Spades"` and `rank` is the
  word `"Two" | ... | "Ace"`. `title` is short code like `"AH"`, `"10D"`.

`cardID` dictionary: `1..13 = H 2..A`, `14..26 = D 2..A`, `27..39 = C 2..A`,
`40..52 = S 2..A`. See `GET /api/Game/cards`.

## Client -> server methods

### `Deal(machineId, cards, holds)` (v2, unified deal+draw)

- `machineId: int` — target machine.
- `cards: Card[]` — current 5-card hand in short form. Empty array `[]` means
  "fresh deal, no prior state".
- `holds: bool[5]` — per-position hold flags. All-`false` + empty `cards[]` means
  fresh deal; any `true` with a non-empty `cards[]` means draw phase.

Server decides phase via `dealCount` in the response: `0 = initial`, `1 = post-draw`.

### `Deal(machineId, betAmount)` (v1 legacy, deprecated)

Retained for current Lucky5 clients. Treated as fresh deal with server-side roundId
tracking; `betAmount` becomes `currentStake`. Will be removed after slice D1.

### `Draw(roundId, holdIndexes)` (v1 legacy, deprecated)

Retained. Will be removed after slice D1. v2 clients fold this into `Deal`.

### `DoubleUp(machineId, pickedBig)` (v2)

- `machineId: int`
- `pickedBig: bool` — `true` = big, `false` = small.

Server emits `SwapDoubleUpCard` (0..N times) then `DoubleUpWin`.

### `DoubleUp(roundId, guess)` (v1 legacy, deprecated)

Retained with `guess: "big" | "small"`.

### `GetAvailableMachines(gameId)` (v2, new)

- `gameId: int`

Returns `MachineListing[]` for the given game. Used to populate the lobby.

### `JoinMachine(machineId)` / `LeaveMachine(machineId)` (v1 legacy)

Retained for explicit room membership. v2 clients can skip these; server auto-joins
on first `Deal`.

### `Heartbeat()` / `ReconnectSync(machineId)` (both versions)

Unchanged.

## Server -> client events

All events are delivered as SignalR invocations (`type: 1`) where the first argument
is the payload below.

### `CardsDealt` (v2) — full round snapshot

Fired after every `Deal` (initial or draw). Replaces v1 `CardsDealt` + `CardRevealed`
and includes the entire machine/round state.

```ts
interface CardsDealtPayload {
  memberId: number;
  cards: LongCard[];
  result: {
    handRank: number;          // 0 = No Win, 1 = 2 Pair, 2 = 3 of a Kind, ...
    description: string;
    winAmount: number;
    isWin: boolean;
    canWin: boolean;
  };
  dealCount: number;           // 0 = initial, 1 = post-draw
  inDoubleUp: boolean;
  doubleUpCard: { cardID: number; title: string } | null;
  shouldReset: boolean;        // clear visuals before render
  shouldDetuctStake: boolean;  // [sic] cabinet-side credit decrement hint
  currentStake: number;
  credit: number;              // wallet balance after this event
  kentRounds: number;
  fullHouseBonus: boolean;
  carreIndex: 1 | 2;           // which 4-of-a-kind slot is active
  currentCarre1: number;
  currentCarre2: number;
  currentFullHouse: number;
  currentKent: number;
  currentStraightFlush: number;
  offerOccurred: boolean;
  offerAmount: number;
  currentBonusAmount: number | null;
  freeGameCount: number;
  wasFreeGameRound: boolean;
  swap10: null | { position: number; remaining: number };
  aceCard: boolean;
  aceMultiplier: number;
  gameId: number;
}
```

### `DoubleUpWin` (v2) — double-up resolution

Fired after `DoubleUp`. Replaces v1 `RewardStatus` + `DoubleUpCard`.

```ts
interface DoubleUpWinPayload {
  memberId: number;
  previousCard: ShortCard & { title: string };
  nextCard: ShortCard & { title: string };
  pickedBig: boolean;
  isWin: boolean;
  isEquality: boolean;         // tie on rank - neither win nor loss
  canContinue: boolean;
  doubleUpCount: number;
  newWinAmount: number;
  lostAmount: number;
  opened: 0 | 1;               // 0 = door closed (live RTP), 1 = open (test mode)
  credit: number;
  lucky5: boolean;
  winLucky5: boolean;          // 5 of Spades "never lose" fired to a win
  bonus: boolean;
  bonusAmount: number;
  bonusCard: boolean;
  bonusCardAmount: number;
  currentBonusAmount: number | null;
  freeGame: boolean;
  freeGameCount: number;
  aceCard: boolean;
  aceMultiplier: number;
  aceMultiplierFired: boolean;
  swapActivePosition: number | null;
  swapActiveRemaining: number;
  gameId: number;
}
```

### `SwapDoubleUpCard` (v2) — swap animation frame

Fired 0..N times rapidly (~540ms cadence) when swap is triggered during double-up.

```ts
interface SwapDoubleUpCardPayload {
  nextCard: ShortCard & { title: string };
  lucky5: boolean;
  winLucky5: boolean;
  isFreeGame: boolean;
  isBonus: boolean;
  freeGameCount: number;
  aceCard: boolean;
  aceMultiplier: number;
  gameId: number;
}
```

### `BetPlaced` (v2) — bet notification

```ts
interface BetPlacedPayload { machineId: number; memberId: number; stake: number; }
```

### `HoldCardUpdated` (v2) — hold state sync

```ts
interface HoldCardUpdatedPayload { machineId: number; memberId: number; holds: boolean[]; }
```

### `MachineStatusChanged` (v2) — lobby seat presence

Server broadcasts to ALL connections whenever any machine's seat changes.

```ts
interface MachineStatusChangedPayload {
  machineId: number;
  isOccupied: boolean;
  playerId: number | null;
  gameId: number;
}
```

### `UserStatusChanged` (v2) — user presence

Tuple args: `[userId: number, state: "Active" | "Reconnecting"]`.

### `Error` (both versions)

```ts
interface ErrorPayload { code: string; message: string; }
```

### Legacy v1 events (deprecated, emitted in parallel during migration)

- `MachineStateUpdated` — superseded by `MachineStatusChanged` (seat only) and by the
  state fields embedded in `CardsDealt`.
- `CardRevealed` — superseded by `CardsDealt` with `dealCount: 1`.
- `DoubleUpCard` — superseded by `DoubleUpWin`.
- `RewardStatus` — superseded by `DoubleUpWin`.
- `WalletUpdated` — superseded by `credit` field in `CardsDealt` and `DoubleUpWin`.

## State machine

```
Lobby -- GetAvailableMachines --> Lobby
Lobby -- Deal(machineId, [], all-false) --> Dealt(dealCount=0)
Dealt -- Deal(machineId, cards, holds) --> Dealt(dealCount=1)
Dealt -- (if isWin && canWin) --> DoubleUp(machineId, pickedBig)
DoubleUp -- SwapDoubleUpCard xN --> DoubleUp
DoubleUp -- DoubleUpWin --> Dealt(dealCount=0) | Lobby
```

`DoubleUp` is always machine-scoped; the server resolves against the open round of
the current seat.

## Ordering and idempotency

- Server MUST deliver `CardsDealt` before any subsequent `DoubleUpWin` for the same
  round.
- `SwapDoubleUpCard` MUST NOT follow a `DoubleUpWin` for the same round.
- Server SHOULD tolerate duplicate `Deal` invocations from retried clients by
  returning the last `CardsDealt` snapshot (idempotency by `(connectionId, seat)`).
- Clients SHOULD de-duplicate using the `(machineId, dealCount, serverTimestamp)`
  tuple after reconnect.
