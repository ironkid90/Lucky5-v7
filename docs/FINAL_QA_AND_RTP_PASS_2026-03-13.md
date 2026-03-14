# Final QA and RTP Pass — 2026-03-13

This document records the last debugging / optimization pass applied to the current repo snapshot.

## What was fixed in this pass

### 1. Deal / draw affordability bug

The live frontend and backend could previously let a player start a round with only enough machine credits for the **deal** even though the game always requires a second bet for the **draw**.

Fix:

- `GameService.DealAsync()` now requires enough credits for **deal + draw** up front
- `wwwroot/js/game.js` now blocks starting the hand unless the player has at least `currentBet * 2`

Result:

- no more dead-end hands where the player can deal but cannot legally draw

### 2. Lucky 5 machine-close timing bug

The older double-up logic could close the machine too early when a `5S` switch inflated the preview amount, even before a real winning guess had happened.

Fix:

- `Lucky5DoubleUpEngine` no longer auto-closes on session start or on switch preview
- machine close is now evaluated only on the **actual winning collection step**
- added regression coverage for the "5S switch near cap" path

Result:

- `5S` can still create the dramatic preview multiplier
- the machine only closes when the real post-win amount would actually push collected credits over the cap

### 3. Async blocking cleanup

`GameService` still had `.Result` calls inside async gameplay paths.

Fix:

- `DoubleUpAsync()` and `GuessDoubleUpAsync()` were cleaned up to use proper `await`

Result:

- lower deadlock / blocking risk in the request path

### 4. Shared ledger locking

Machine/admin/game code paths were not using the same lock object.

Fix:

- added `InMemoryDataStore.LedgerSync`
- switched gameplay/admin machine-ledger mutations to the shared lock

Result:

- lower risk of inconsistent machine-state mutation under concurrent access

### 5. Jackpot-aware payout scaling

The biggest RTP bug found during the pass was that the payout-scale logic was mostly looking at **base-game RTP** and only weakly correcting for jackpot overshoot.

Fix:

- `MachinePolicyState` now exposes `JackpotRtp`
- `MachinePolicy.ResolvePayoutScale()` now reduces the **base-game target** by observed jackpot RTP before deciding the scale
- overshoot correction was made materially stronger when live RTP is already above target
- fun-pressure bonuses are now damped when the machine is already overshooting
- win-tier spread was tightened from a wider small/medium/big separation to a narrower one

Result:

- jackpot-heavy periods pull the ordinary paytable scale down faster
- the machine still keeps rhythm / suspense, but it does not compound overshoot as aggressively

### 6. Double-up pressure tuning

The double-up deck pressure previously leaned too much on extra aces in hot states, which is especially generous because aces are auto-win cards in the current rule set.

Fix:

- reduced extra ace injection in `MachinePolicy.BuildDoubleUpDeck()`
- left Lucky 5 pressure focused more on `5S` than on free ace-heavy decks

Result:

- Lucky 5 remains visible and dramatic
- neutral / hot double-up becomes less automatically player-favorable than before

### 7. Frontend machine-close guard after jackpot fill

A jackpot animation could finish and immediately auto-enter double-up even when the machine was already effectively closed.

Fix:

- `game.js` now stops the auto-start and shows `MACHINE CLOSED - TAKE SCORE / CASH OUT` if jackpot fill reaches the machine-credit limit first

## Replay / regression updates

- replay test setup now cashes into the machine session before dealing
- added coverage for the Lucky 5 switch + machine close timing path

## Approximate RTP simulation notes used during tuning

A lightweight mirror simulation was used during this pass to check **behavioral direction**. It is useful for tuning, but it is still an approximation of the live service path rather than a formal authoritative production certification run.

The main findings from that tuning pass were:

- raw base-game RTP versus the full **deal + draw** cost was roughly **0.455**
- base game plus old payout scaling without jackpots sat around **0.883**
- once jackpot overlay was included, the older scale logic could overshoot badly because jackpot RTP was not being compensated enough
- after switching to jackpot-aware payout scaling, the mirrored total moved much closer to the target band (roughly around **0.90** in the tuning pass instead of the previous catastrophic overshoot)
- the biggest remaining generosity comes from **double-up**, especially with optimal or near-optimal player behavior

## Important remaining limitation

This pass improved the policy loop and removed several correctness bugs, but it does **not** claim that the current in-memory build has been mathematically certified to 87.5% across every long-run player strategy.

The remaining high-variance area is still the double-up layer:

- Ace-as-auto-win is generous
- optimal BIG/SMALL play remains strong
- true month-scale balancing should eventually be measured from a refreshed simulation harness that matches the live service rules exactly

## Recommended next step if more tuning is needed

If you want one more balancing pass after this, focus on only one thing next:

1. refresh the simulation harness so it mirrors the live service exactly
2. then tune double-up EV using data rather than intuition

That is the cleanest next lever if the production telemetry still trends hot.
