# Reusable Patterns

## Last Reviewed

2026-03-15

## Vanilla JS API Access

- The original cabinet uses a shared `apiCall(method, path, body)` helper.
- Requests send JSON, attach `Authorization: Bearer <token>` when available, and surface API error messages directly.

## Session Identity

- Machine sessions are keyed by the composite string `{userId:N}:{machineId}` in `InMemoryDataStore`.

## Cash Flow / Settlement

- Flow: wallet → cash-in → machine credits → bet deduction → win settlement → take score / double-up → machine credits → cash-out → wallet.
- Win payout is not added during draw; it settles on take-score or double-up finalization.

## Machine Close Flow

- At 40,000,000 credits, `IsMachineClosed` becomes `true`.
- Closed sessions can cash out immediately.
- Machine reset clears the close flag for all sessions on that machine.

## Jackpot State / Presentation

- Backend pattern: treat `MachineLedger.ActiveFourOfAKindSlot` as live machine state only; copy it into `GameRound.ActiveFourOfAKindSlotAtDeal` while holding `LedgerSync`, and resolve 4K jackpot payouts from the round snapshot.
- Vanilla cabinet pattern: the visible jackpot block uses live `[data-jackpot-slot]` counters, including a dedicated `#jp-counter-fh` Full House meter and `.jp-counter.jp-active` to highlight the currently active 4K side.
- Win display pattern: only show A/B slot tags for Four of a Kind jackpot outcomes; do not append a duplicate jackpot amount to the main win message.

## React Cabinet Scope

- `src/web/components/lucky5-cabinet.tsx` is still the single-component React cabinet; parity work should assume one-file orchestration unless intentionally refactored.

## RTP / Feel Tuning Pattern

- Treat the **payout-scale orbit** as the primary RTP lever, **jackpot economics** as the secondary lever, and **bounded pre-shuffle deck shaping** as the tertiary lever.
- For Lucky5, preserving fun/tension means avoiding post-choice rigging and obviously scripted outcome patterns.
- If extra control is needed in double-up, prefer **tiny pre-shuffle deck envelopes** selected before shuffle over visible rule changes.

## Calibration Pattern

- Do not trust legacy RTP docs blindly when balancing. First confirm the live gameplay path in:
  - `server/src/Lucky5.Infrastructure/Services/GameService.cs`
  - `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`
  - `server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs`
  - `server/src/Lucky5.Simulation/Program.cs`
  - Before claiming a new RTP target, make the simulation mirror live gameplay exactly, especially:
    - double-up availability
    - jackpot-to-double-up eligibility
    - machine-close threshold behavior
    - jackpot contribution timing
