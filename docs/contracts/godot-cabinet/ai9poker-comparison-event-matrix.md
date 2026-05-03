# AI9Poker Comparison And Lucky5 Event Matrix

Status: planning artifact for presentation-only Lucky5 upgrades.

Scope: compare the AI9Poker browser-export map against the current Lucky5 backend
contracts and Godot cabinet scripts, then define the Lucky5-specific event matrix
and presentation-only backlog. This document does not authorize changes to payout
tables, RNG, hand evaluation, double-up math, RTP, jackpot math, wallet settlement
rules, or game rules.

## Source Evidence

AI9Poker export evidence:

- `AI9POKER_CODE_MAP.md` in the browser-export folder maps the compiled Flutter
  app, REST calls, SignalR hub calls, controllers, and presentation patterns.
- The relevant AI9Poker patterns are presentation-side only: reconnect/rejoin,
  action locks, machine selection, update/notification surfaces, and asset
  preload/disabled-state handling.

Lucky5 repo evidence:

- `docs/contracts/godot-cabinet/README.md`
- `docs/contracts/godot-cabinet/phase-0-discovery.md`
- `docs/contracts/godot-cabinet/cabinet-contract-v1.schema.json`
- `server/src/Lucky5.Application/Dtos/CabinetContractsDto.cs`
- `server/src/Lucky5.Api/Controllers/GameController.cs`
- `server/src/Lucky5.Realtime/CarrePokerGameHub.cs`
- `godot/cabinet/scripts/cabinet_api_client.gd`
- `godot/cabinet/scripts/cabinet_state_store.gd`
- `godot/cabinet/scripts/cabinet_controls.gd`
- `godot/cabinet/scripts/cabinet_root.gd`
- `godot/cabinet/fixtures/classic_snapshot.json`

## Comparison Summary

| Area | AI9Poker export | Current Lucky5 | Migration decision |
| --- | --- | --- | --- |
| Game commands | Mostly SignalR hub invocations such as `Bet`, `Deal`, `HoldCard`, `DoubleUp`, `TakeScore`, `JoinMachine`, and `GetAvailableMachines`. | Gameplay commands are mostly REST today. SignalR exists for presence, machine state, and some legacy live events. The schema already defines `CabinetCommand`. | Do not copy the AI9Poker hub command names directly. Use Lucky5 `CabinetCommand` names and preserve backend authority. |
| Reconnect | Hub reconnect re-subscribes handlers and rejoins the active machine. | Contract docs require `reconnect_sync`, `last_state_version`, and `last_sequence_number`, but current live backend has no replay buffer and `ReconnectSync(int machineId)` only emits current machine state. | Presentation backlog should implement a blocking reconnect state machine that falls back to full snapshot until replay exists. |
| Snapshot | AI9Poker uses event payloads and model parsers from a compiled Flutter bundle. | Lucky5 schema defines a full `CabinetSnapshot`, but live backend/Godot fixture still use a legacy seed shape. | Add a client adapter now; backlog backend contract alignment separately. |
| Event ordering | AI9Poker stream objects include method/type/data/timestamp, but no verified schema-level monotonic contract from the export. | Lucky5 schema defines `sequence_number` and `state_version`; current backend sets `sequence_number = state_version` in the legacy snapshot. | Godot should track both fields but enter full-snapshot recovery when ordering is not guaranteed. |
| Button gating | AI9Poker has action-in-progress locks, cooldowns, animation guards, and server-driven state. | Godot currently enables buttons from `ui_hints.enabled_buttons`, but commands only update the local message label. | Add a presentation-side action-lock component; backend remains final authority. |
| Machine selection | AI9Poker has game list, available machines, occupancy/status, selected machine, and cashier routing. | Lucky5 has REST machine list and SignalR `AvailableMachines`/`MachineStatusChanged`, but no Godot machine-selection screen yet. | Define a JSON screen contract and machine selection store before building the screen. |
| Notifications/update | AI9Poker has `ForceUpdate`, reward status, server errors, notification/message events. | Lucky5 has hub `Error`, reward REST, and web notification surfaces, but no Godot forced-update/notification contract. | Add visible recovery/update/notice overlay contract, without wallet/game mutations. |
| Assets | AI9Poker preloads cards, buttons, board art, and loading states. | Lucky5 contract docs identify assets and known asset risks. Godot vertical slice currently draws cards/buttons procedurally. | Add a preload manifest and disabled/missing-asset states before replacing procedural placeholders. |

## Current Alignment Gaps

These are contract/presentation gaps, not gameplay gaps.

| Gap | Current evidence | Risk | Presentation decision |
| --- | --- | --- | --- |
| Schema version mismatch | JSON schema requires `schema_version: "cabinet.v1"`; backend DTO and fixture use `"v1"`. | Godot cannot validate live snapshots against the contract without adapter logic. | Add a Godot compatibility adapter or align backend output before strict validation. |
| Snapshot shape mismatch | Schema requires `message_type`, `server_time_utc`, `session`, `machine`, `variant`, `buttons`, `presentation`, and `recovery`; backend/Godot fixture use flat `session_id`, `machine_id`, `variant_id`, `ui_hints`, `timestamp`. | Godot code may bind to legacy seed fields and miss the real contract. | Document both shapes and make the store accept legacy only through a named compatibility path. |
| Button ID mismatch | Schema button IDs include `deal_draw` and `cancel_hold`; backend/Godot fixture currently emit/use `deal` and `cancel`. | Controls may stay disabled or emit command names the backend does not understand. | Normalize IDs at the Godot adapter boundary or align backend/Godot to the schema. |
| Command envelope mismatch | Schema command includes `message_type`, `client_sequence_number`, and `sent_at_utc`; Godot `emit_command` emits no `message_type`, no `client_sequence_number`, and uses `timestamp`. | Retries and telemetry become inconsistent. | Backlog should add a presentation command builder that emits the schema shape while preserving legacy fallbacks. |
| Command transport gap | Current API has no `/api/Game/cabinet-command` endpoint in this checkout; hub has method-specific commands. | Godot cannot submit a single schema command envelope yet. | Keep Godot commands presentation-only until backend command adapter is implemented. |
| Realtime client gap | Current `godot/cabinet/scripts` has no WebSocket/SignalR client script. | Godot cannot receive live backend events or heartbeat timeouts. | Presentation backlog starts with a connection state machine and fakeable event adapter. |
| Replay gap | Contract expects replay-or-snapshot behavior; current backend lacks a replay buffer. | Missed events cannot be safely applied incrementally. | Always request/apply full snapshot after reconnect until replay exists. |
| Hub error visibility gap | Backend sends hub `Error`; current Godot has no handler or overlay. | Transport/heartbeat errors can silently strand the cabinet. | Add visible recovery/error overlay and disable gameplay commands while recovering. |

## Lucky5 Event Matrix

The `Backend event name` column uses the Lucky5 target contract name first. When
the live backend currently emits a legacy SignalR event, that event appears in
parentheses.

| Backend event name | Godot handler | Authoritative payload fields | Retry/reconnect behavior |
| --- | --- | --- | --- |
| `cabinet_snapshot` (`GET /api/Game/machine/{machineId}/cabinet-snapshot`) | Current: `CabinetStateStore.apply_snapshot`, then `CabinetRoot._render_snapshot`. Target: `CabinetConnection._apply_snapshot(snapshot)` delegates to the store. | Target schema: `schema_version`, `state_version`, `sequence_number`, `server_time_utc`, `session`, `machine`, `variant`, `game_state`, `credits`, `hand`, `evaluation`, `double_up`, `jackpot`, `buttons`, `presentation`, `recovery`. Legacy seed: `session_id`, `machine_id`, `variant_id`, `ui_hints`, `timestamp`. | Fetch on first machine join, app resume, stale command rejection, transport reconnect, event gap, and explicit `recovery_required`. Disable gameplay commands until applied. |
| `state_changed` (`MachineStateUpdated`) | Target: `CabinetStateStore.apply_event(event)` followed by snapshot refresh if payload is legacy/unversioned. | Machine/session state, jackpot counters, active round/session counts, `state_version`, `sequence_number` when available. Current legacy hub payload has no guaranteed sequence. | If unsequenced, treat as a refresh hint and fetch snapshot. If sequenced, apply only when `sequence_number == last + 1`; otherwise enter recovery. |
| `jackpot_updated` (`MachineStateUpdated`, `ChangeJackpotRank` response) | Target: `CabinetStateStore.apply_jackpot(payload)` and `CabinetRoot._render_snapshot`. | `full_house`, `full_house_rank`, `four_of_a_kind_a`, `four_of_a_kind_b`, `active_four_of_a_kind_slot`, `straight_flush`, `machine_serial`, `machine_serie`, `machine_kent`. | Local jackpot rank selection must stay pending until backend confirms. On reconnect, ignore local rank memory and use snapshot. |
| `session_visibility_changed` (`JoinMachine`, `LeaveMachine`, `UserStatusChanged`) | Target: `MachineSelectionStore.apply_visibility(payload)` and `CabinetConnection._on_presence_event(payload)`. | `machine_id`, `session_id`, `authenticated_user_id`, `visibility`, `is_machine_closed`, `can_cash_out`, legacy `userId`, `state`, `isOccupied`, `playerId`. | On reconnect, re-authenticate, rejoin active machine, then fetch snapshot. Do not show machine as available until current occupancy/status refresh arrives. |
| `available_machines` (`AvailableMachines`, `GET /api/Game/machines`) | Target: `MachineSelectionStore.apply_available_machines(payload)`. | `id`, `name`, `is_open`, `min_bet`, `max_bet`; legacy DTO currently uses `Id`, `Name`, `IsOpen`, `MinBet`, `MaxBet` through JSON casing. | Refresh on lobby open, reconnect, and `MachineStatusChanged`. Use stale marker if refresh fails; do not allow entry into a stale occupied machine. |
| `machine_status_changed` (`MachineStatusChanged`) | Target: `MachineSelectionStore.apply_machine_status(payload)`. | `machine_id`, `is_open`, `is_occupied`, `player_id`, `game_id`, optional `last_seen_utc`. Legacy hub payload has `machineId`, `isOccupied`, `playerId`, `gameId`. | Apply as lobby presentation state only. If the selected machine changes while connected, request a full snapshot before enabling cabinet commands. |
| `credits_updated` (`WalletUpdated`, cash-in/cash-out command result, profile/session fetch) | Target: `CabinetStateStore.apply_credits(payload)`; current renderer already reads `snapshot.credits`. | `machine_credits`, `wallet_balance`, `credit_balance`, `stake`, `total_cash_in`, `cash_out_threshold`, `pending_win_amount`; legacy DTOs expose `machineCredits`, `walletBalance`, `balance`, `bet`, `total_won`. | Never mutate credits optimistically. Keep the action lock pending until command result or snapshot arrives. On retry, reuse the same command/idempotency key once backend supports it. |
| `round_updated` (`CardsDealt`, `CardRevealed`) | Target: `CabinetStateStore.apply_round_update(payload)`. Current renderer reads `hand.result_cards`, `evaluation`, `ui_hints.enabled_buttons`. | `round_id`, `game_state`, `cards`, `result_cards`, `held_indexes`, `advised_holds`, `hand_rank`, `win_amount`, `jackpot_won`, `double_up_available`, `buttons`, `presentation.message`. | If command response is lost, do not reissue deal/draw with a new id. Enter reconnect recovery and fetch snapshot. Ignore duplicate event sequence. |
| `double_up_updated` (`DoubleUpWin`, `DoubleUpCard`, `SwapDoubleUpCard`) | Target: `CabinetStateStore.apply_double_up(payload)` and a future `DoubleUpPresenter.play(payload.presentation)`. | `active`, `round_id`, `status`, `dealer_card`, `challenger_card`, `card_trail`, `current_amount`, `switches_remaining`, `is_no_lose_active`, `is_lucky5_active`, `lucky_multiplier`, optional presentation noise/effects. | Lock Big/Small/Switch/Take buttons per physical action. If transport drops during double-up, show recovery overlay and fetch snapshot before re-enabling. |
| `command_accepted` | Target: `ActionLock.resolve(command_id)`, then store applies included `event` or `snapshot`. | `command_id`, `idempotency_key`, `status`, `state_version`, `sequence_number`, `event`, optional `snapshot`. | Mark retry as complete only when `command_id` and `idempotency_key` match the pending command. Do not infer success from button press or local animation. |
| `command_rejected` (`Error`, HTTP 400/401/403/409-style failures) | Target: `ActionLock.reject(command_id)`, `CabinetRecoveryOverlay.show(error)`, optional store snapshot apply. | `code`, `message`, `retryable`, `state_version`, `sequence_number`, optional `snapshot`. Legacy hub `Error` has `code`, `message`. | If `status=stale_state` or `requires_snapshot`, fetch/apply snapshot and clear lock. If unauthorized, return to auth/session recovery. |
| `heartbeat_ack` | Target: `CabinetConnection._on_heartbeat_ack(payload)`. | `connection_id`, `server_time_utc`, optional `state_version`, `sequence_number`. Not emitted by current backend. | Send heartbeat on interval only while connected and foreground. Missing ack past threshold moves to `reconnecting` and disables gameplay commands. |
| `heartbeat_timeout` (`Error` with `code=HEARTBEAT_TIMEOUT`) | Target: `CabinetConnection._on_heartbeat_timeout(payload)` and `CabinetRecoveryOverlay.show("Heartbeat timeout")`. | `code`, `message`, optional `connection_id`, `server_time_utc`. | Treat as authoritative recovery-required. Stop sending gameplay commands, reconnect transport, rejoin machine, and fetch snapshot. |
| `replay_gap` | Target: `CabinetConnection._on_replay_gap(payload)`. | `expected_sequence_number`, `actual_sequence_number`, `machine_id`, `session_id`, optional `snapshot_url` or inline `snapshot`. Not implemented today. | Immediately request full snapshot. Do not apply later incremental events until snapshot resets `last_sequence_number`. |
| `recovery_required` | Target: `CabinetConnection.enter_recovery(reason)` and `CabinetRecoveryOverlay.show(reason)`. | `reason`, `machine_id`, `session_id`, `last_known_state_version`, `last_known_sequence_number`, optional `snapshot`. | Blocking overlay. Commands disabled until snapshot or replay succeeds. |
| `notification` / `forced_update` | Target: `CabinetNoticeOverlay.show(payload)` and optional `UpdateGate.block_gameplay(payload)`. | `notice_id`, `severity`, `title`, `message`, `requires_ack`, `minimum_client_schema`, `download_url` if update is required. Lucky5 does not currently emit this as a cabinet event. | Non-critical notices can survive reconnect. Forced update blocks gameplay entry after current safe state and should never mutate credits/game state. |

## Command Mapping For Godot Controls

This table maps the current Godot button IDs to target `CabinetCommand` types.
It also records the live Lucky5 backend route or hub method that exists today.

| Godot control | Current emitted ID | Target command type | Current backend surface | Notes |
| --- | --- | --- | --- | --- |
| Machine card/select | none yet | `join_machine` | Hub `JoinMachine(machineId)`, REST snapshot fetch | Rejoin then snapshot on reconnect. |
| Back to lobby | none yet | `leave_machine` | Hub `LeaveMachine(machineId)` | Must release occupancy and refresh machine list. |
| Cash in | none yet | `cash_in` | `POST /api/Game/machine/{machineId}/cash-in` | Amount is structured payload, no prompt. |
| Cash out | none yet | `cash_out` | `POST /api/Game/machine/{machineId}/cash-out` | Backend blocks unresolved rounds. |
| Bet | `bet` | `bet_change` or `deal` depending state | No dedicated live `bet_change` endpoint; hub `Deal(machineId, betAmount)` and REST deal exist. | Keep presentation-only cycling local until backend contract exists, but snapshot must decide final stake. |
| Deal/Draw | `deal` | `deal` or `draw` | REST `POST /api/Game/deal`, `POST /api/Game/draw`; hub `Deal`, `Draw` | Requires adapter because schema button is `deal_draw`, current ID is `deal`. |
| Hold buttons | `hold_0` to `hold_4` | `hold` | No dedicated REST hold endpoint; hub emits hold sync during `Draw`. | Can be local preview, but reconnect needs snapshot/server-visible holds before strict mode. |
| Cancel hold | `cancel` | `clear_holds` | No dedicated endpoint | Requires ID normalization from `cancel` to schema `cancel_hold` or schema update. |
| Big | `big` | `double_up_guess` with `guess=big` | REST `POST /api/Game/double-up/guess`; hub `DoubleUp(roundId, guess)` | Lock until response/snapshot. |
| Small | `small` | `double_up_guess` with `guess=small` | Same as Big | Same. |
| Take half | `take_half` | `take_half` | `POST /api/Game/double-up/take-half` | Backend authority only. |
| Take score | `take_score` | `take_score` | `POST /api/Game/double-up/cashout`; cash-out also uses a separate machine endpoint | Distinguish game win collection from machine cash out in UI copy and payload. |
| Menu | `menu` | no gameplay command | Godot local overlay | Menu can open while recovering but mutating entries stay disabled. |
| Jackpot rank selector | none yet | `jackpot_rank_change` | `POST /api/Game/jackpot/rank` | Must be explicit; do not hide it behind Bet/Hold side effects. |
| Heartbeat | none yet | `heartbeat` | Hub `Heartbeat()` | Presentation connection health only. |
| Reconnect | none yet | `reconnect_sync` | Hub `ReconnectSync(machineId)` | Use full snapshot fallback until replay exists. |

## Presentation-Only Backlog

Backlog items below are ordered so the Godot client can become safer without
changing backend game authority. Each item is intentionally scoped to client
state, contracts, overlays, and adapters.

### P0. Snapshot Compatibility Adapter

Goal: make Godot explicitly distinguish legacy Lucky5 seed snapshots from the
schema-defined `cabinet.v1` contract.

Files likely touched:

- `godot/cabinet/scripts/cabinet_state_store.gd`
- `godot/cabinet/scripts/cabinet_api_client.gd`
- `godot/cabinet/scripts/cabinet_root.gd`
- `godot/cabinet/fixtures/classic_snapshot.json`
- contract docs in `docs/contracts/godot-cabinet/`

Acceptance:

- Godot accepts legacy `"v1"` snapshots through a named adapter path.
- Godot stores normalized fields with schema-style names internally.
- Button IDs are normalized between `deal`/`cancel` and `deal_draw`/`cancel_hold`.
- No gameplay math, payout, RNG, double-up, jackpot, or wallet settlement logic is added to Godot.

### P1. Reconnect State Machine

Goal: implement a presentation-side connection state machine that prevents unsafe
commands during disconnect/reconnect.

Target states:

- `offline`
- `authenticating`
- `connecting`
- `joining_machine`
- `syncing_snapshot`
- `live`
- `reconnecting`
- `recovery_required`
- `blocked_update`
- `fatal_error`

Acceptance:

- Any disconnect moves the cabinet to `reconnecting` or `recovery_required`.
- Gameplay controls are disabled while not `live`.
- Reconnect flow performs: authenticate, rejoin machine, `reconnect_sync`, full snapshot fetch.
- Full snapshot is mandatory after reconnect until backend replay is implemented.
- Last known `state_version`, `sequence_number`, `session_id`, and `machine_id` are tracked.
- UI shows a blocking recovery overlay with a clear message.

Backend dependency:

- Existing hub `ReconnectSync(machineId)` can be used as a compatibility hint.
- Replay buffer is not required for this presentation slice; snapshot fallback is required.

### P2. Action-Lock Component

Goal: add AI9Poker-style duplicate-action protection on the Godot presentation
side while preserving server authority.

Rules:

- One gameplay command may be pending at a time.
- Each command has a generated `command_id` and stable `idempotency_key`.
- Repeated button presses during the lock are ignored or produce a soft disabled press state.
- Lock releases only on matching command result, snapshot recovery, explicit rejection, or timeout into recovery.
- Animation guards can delay input locally but must not imply server acceptance.

Acceptance:

- Pressing Deal/Draw/Big/Small/Take Half/Take Score twice does not emit two new command intents.
- Timeout does not retry with a new command ID; it enters recovery.
- Menu remains available, but mutating menu entries follow the same lock.

### P3. Machine-Selection Screen Contract

Goal: define and implement the Godot lobby/machine-selection data shape before
building the full screen.

Contract fields:

- `machine_id`
- `display_name`
- `variant_id`
- `is_open`
- `is_occupied`
- `player_id`
- `min_bet`
- `max_bet`
- `current_state`
- `last_seen_utc`
- `presentation_skin_id`

Acceptance:

- Initial list loads from `GET /api/Game/machines`.
- Live status updates apply from `MachineStatusChanged` and `AvailableMachines`.
- Selecting a machine triggers join plus snapshot fetch.
- Occupied/stale machines are visibly disabled.
- Reconnect from lobby refreshes the list before allowing entry.

### P4. Forced Update And Notification Surface

Goal: add a Godot-native notice/update overlay equivalent to AI9Poker's forced
update and notification handling, without tying it to gameplay settlement.

Notice fields:

- `notice_id`
- `severity`
- `title`
- `message`
- `requires_ack`
- `blocks_gameplay`
- `minimum_client_schema`
- `download_url`
- `created_utc`

Acceptance:

- Non-blocking notices can be acknowledged and stored for the current session.
- Forced update notices block entry into gameplay from lobby.
- If a forced update arrives mid-round, Godot blocks new commands after the current safe server state is applied.
- Hub `Error` and heartbeat timeout use the recovery overlay, not the notice overlay.

Backend dependency:

- Can start with local fixture notices.
- Later backend may emit `forced_update` or `notification` cabinet events.

### P5. Asset Preloading And Disabled States

Goal: replace procedural placeholders with explicit asset loading and robust
disabled/missing states.

Asset groups:

- card fronts and `bside.png`
- HOLD/CANCEL/DEAL/BET/BIG/SMALL/TAKE HALF/TAKE SCORE/MENU buttons
- Lucky5 logo/splash/board/cabinet art
- `press.mp3` and any approved future sound pack
- font assets

Acceptance:

- Game scene does not enable commands until required assets and first snapshot are loaded.
- Missing assets render a deliberate fallback state and a recovery message.
- Button disabled, pressed, hover/focus, and pending states are visually distinct.
- Asset preload result is included in diagnostics but does not alter game state.

### P6. Event Adapter And Store Normalization

Goal: create the Godot path that can consume both current legacy hub/REST payloads
and future schema events through one store API.

Target store methods:

- `apply_snapshot(snapshot)`
- `apply_event(event)`
- `apply_legacy_machine_state(payload)`
- `apply_round_update(payload)`
- `apply_double_up(payload)`
- `apply_credits(payload)`
- `apply_jackpot(payload)`
- `enter_recovery(reason)`

Acceptance:

- Legacy payloads are converted once at the adapter boundary.
- Store never mutates cards, credits, jackpots, or outcomes from UI guesses.
- Out-of-order or duplicate events are ignored or moved to recovery according to `sequence_number`.
- Renderer only reads normalized store state.

### P7. Presentation Diagnostics

Goal: add operator-friendly diagnostics for cabinet migration testing.

Fields:

- connection state
- active machine/session
- last `state_version`
- last `sequence_number`
- pending command ID
- last event type
- last recovery reason
- asset preload status

Acceptance:

- Diagnostics can be shown in development builds without changing gameplay UI.
- Diagnostics are read-only and cannot trigger gameplay commands.
- A tester can capture enough evidence to reproduce reconnect or disabled-button issues.

## Recommended Implementation Order

1. Snapshot compatibility adapter.
2. Event adapter and store normalization.
3. Action-lock component.
4. Reconnect state machine with full-snapshot fallback.
5. Machine-selection screen contract.
6. Asset preloading and disabled states.
7. Forced update and notification overlay.
8. Presentation diagnostics.

This order lets Godot become safer first, then richer. It also avoids building a
polished screen on top of ambiguous snapshot/button IDs.

## Non-Goals

- No payout table changes.
- No RNG changes.
- No hand evaluation changes.
- No double-up math changes.
- No RTP changes.
- No jackpot math changes.
- No wallet settlement rule changes.
- No backend financial authority moved into Godot.
- No AI9Poker endpoint or hub name copied directly into Lucky5 contracts.

