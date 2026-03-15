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
