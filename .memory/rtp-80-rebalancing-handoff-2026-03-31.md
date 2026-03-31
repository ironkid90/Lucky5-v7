# RTP / Fun / Tension Handoff — 2026-03-31

## Scope

- Repository scope for this mission is **`Lucky5-v7/` only**.
- Ignore sibling repositories in the workspace.
- Treat this file as the fastest bootstrap for future agents working on RTP, fun/tension, and clean-room balancing.

---

## Mission Snapshot

User goal:

- study the Lucky5 codebase and Markdown corpus
- keep the information as shared global context
- move from the previously attempted **85% RTP** balancing direction to a **better system targeting 80% RTP**
- preserve:
  - fun
  - tension
  - excitement
  - clean-room feel
  - deterministic pre-shuffled outcome logic
- avoid turning the game into obviously scripted or post-choice-rigged gameplay

User clarification:

- previous **85% target** proved hard to balance cleanly, especially because double-up is strong and the team does **not** want obviously scripted gameplay
- the desired direction is a **middle ground**:
  - not too loose / too hot
  - not too cold / dead
  - not predictably scripted
  - still maintain cabinet drama and comeback potential

---

## Current Task Status

Because the chat TODO tool hit a repetition limit, current task state is tracked here.

- [x] Identify target repo and tech stack
- [~] Read and digest Markdown corpus into shared context
- [x] Map current RTP / payout / jackpot / double-up control flow in code
- [x] Identify major doc-vs-code drift that can mislead future agents
- [x] Research/design a better non-scripted 80% RTP system
- [ ] Implement the redesign in code
- [ ] Validate with a live-path-accurate simulation pass
- [ ] Update docs/memory after implementation

`[~]` = in progress / partially complete

---

## Authoritative Files for RTP Work

When docs conflict, prefer these files:

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`
- `server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs`
- `server/src/Lucky5.Domain/Game/CleanRoom/FiveCardDrawEngine.cs`
- `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`
- `server/src/Lucky5.Domain/Entities/MachineLedgerState.cs`
- `server/src/Lucky5.Domain/Entities/GameRound.cs`
- `server/src/Lucky5.Simulation/Program.cs`

---

## High-Confidence Live Code Facts

## 1) The live target in code is 85%, not 87.5%

In `EngineConfig`:

- `TargetRtp = 0.85m`
- `TargetDoubleUpRtp = 0.090m`
- computed jackpot target helper is `0.035m`
- computed scaled-base target is effectively `0.85 - 0.09 - jackpot`

Key file:

- `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`

## 2) Lebanese paytable is authoritative and Two Pair is the minimum paying hand

`PaytableProfile.Lebanese` pays:

- Royal Flush = 1000x
- Straight Flush = 75x
- Four of a Kind = 15x
- Full House = 12x
- Flush = 10x
- Straight = 8x
- Three of a Kind = 3x
- Two Pair = 2x

And:

- `MinimumPairRankForPayout = int.MaxValue`
- meaning **no single pair pays**

Key file:

- `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`

## 3) Live double-up is currently offered on every paying hand

In the live service path (`GameService.DrawAsync()`):

- `doubleUpAvailable = payout > 0`
- `round.DoubleUpOffered = doubleUpAvailable`

This means:

- `MachinePolicy.ShouldOfferDoubleUp()` is **not** part of the live gameplay path today
- docs/simulation notes about a probabilistic offer curve are currently misleading if treated as live authority

Key file:

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`

## 4) Live jackpot wins can currently flow into double-up

Current draw flow:

- hand payout is computed
- jackpot replacement can overwrite payout with jackpot amount
- final `doubleUpAvailable` is still `payout > 0`

So in current code:

- jackpot wins are not auto-settled at draw time
- jackpot wins can still proceed into double-up unless explicitly cashed out

This conflicts with older docs claiming jackpot wins go straight to machine credits and never enter double-up.

Key file:

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`

## 5) Double-up deck is currently not policy-shaped

`MachinePolicy.BuildDoubleUpDeck()` currently returns the standard deck unchanged.

So live double-up pressure is currently driven mainly by:

- the rule set itself
- deterministic shuffle
- player decisions
- machine-close threshold

Not by DU deck manipulation.

Key file:

- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`

## 6) Deal deck is policy-shaped, but only mildly

Pre-deal policy can:

- choose `Cold`, `Neutral`, or `Hot`
- in `Cold`, remove up to one high card
- in `Hot`, add `5♠` and maybe one high card
- never remove `5♠`
- keep the deck close to standard size

This is a bounded pre-shuffle lever, not post-choice scripting.

Key file:

- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`

## 7) Payout scaling is the main live RTP lever

The controller:

- measures observed RTP / base RTP / jackpot RTP
- computes a base-game equilibrium scale
- applies warmup bias, jitter, drift correction, and streak/crisis relief
- applies tier factors for small / medium / big wins

This is the dominant balancing mechanism today.

Key file:

- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`

## 8) Machine close is 40,000,000 credits in live code

Relevant places:

- `EngineConfig.CloseThreshold = 40_000_000m`
- double-up `MaxCreditLimit` is built from that threshold
- session machine-close state is used to block further play and allow collection

Key files:

- `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`
- `server/src/Lucky5.Infrastructure/Services/GameService.cs`

## 9) Deferred settlement is real

Draw wins are not immediately credited to machine credits.

They settle on:

- take score
- take half
- double-up finalization
- machine-close finalization path

Key file:

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`

---

## Live Round Control Flow

## Deal phase

`GameService.DealAsync()`:

1. validate machine and machine session
2. require enough credits for **deal + draw**
3. build `MachinePolicyState` from ledger
4. resolve distribution mode
5. if player counterplay score is high enough, suppress `Cold` to `Neutral`
6. mutate ledger:
   - +bet to capital in
   - increment round count
   - increment drought counters
   - decrement cooldown if active
   - set 4K active slot
   - add jackpot contributions
7. alter the deal deck via `MachinePolicy.AlterDeck()`
8. shuffle deterministically
9. take first 5 cards
10. subtract first bet from machine credits
11. store a `GameRound`

## Draw phase

`GameService.DrawAsync()`:

1. validate active round and phase
2. subtract second bet from machine credits
3. add second bet to ledger capital-in
4. add jackpot contributions again
5. apply holds and draw replacements
6. evaluate final hand
7. compute raw base payout from Lebanese paytable
8. compute payout scale from `MachinePolicy.ResolvePayoutScale()`
9. scale the base payout
10. if win:

- add scaled payout to `CapitalOut`
- add raw base payout to `BaseCapitalOut`
- reset loss streak
- set cooldown
- maybe replace payout with jackpot amount

11. if loss:

- increment consecutive losses

12. mark round completed
13. set `DoubleUpOffered = payout > 0`

---

## Live Double-Up Control Flow

## Start

`GameService.StartDoubleUpAsync()`:

1. require completed winning round
2. require unsolved payout
3. require machine not already closed
4. build DU deck via `MachinePolicy.BuildDoubleUpDeck()`
5. shuffle deterministic DU deck
6. create `Lucky5DoubleUpSession`

## Switch

`GameService.SwitchDealerAsync()` + `Lucky5DoubleUpEngine.SwitchDealer()`:

1. consume next card as new dealer
2. if switched dealer is `5♠`:
   - apply `4x` on first Lucky hit
   - apply `2x` on repeat Lucky hits
   - arm no-lose mode
   - reset `RoundsSinceLucky5Hit`

## Guess

`GameService.GuessDoubleUpAsync()` + `Lucky5DoubleUpEngine.ResolveGuess()`:

1. challenger card is next deck card
2. Ace auto-wins under current options
3. otherwise comparison is plain higher/lower rank
4. on win:
   - amount doubles
   - may hard-stop with machine close if crossing close threshold
5. on loss with Lucky no-lose active:
   - `SafeFail`
   - current amount is banked
6. on ordinary loss:
   - amount goes to 0
7. finalization updates machine credits and ledger delta

---

## Biggest Doc / Code Drift Found So Far

Future agents must not trust older docs blindly.

## Drift 1 — 87.5% vs 85%

Some docs still mention **87.5% RTP**, but code uses **85%**.

## Drift 2 — Double-up offer curve

Docs and simulation talk about probabilistic DU offer bands, but live code currently offers DU on **every win**.

## Drift 3 — Jackpot wins vs double-up

Some docs say jackpot wins never enter double-up.
Live code currently allows them to.

## Drift 4 — 7 behavior in double-up

Some docs describe 7 as automatic lose/push territory.
Current clean-room double-up code has **no special-case 7 handling** in resolution.

## Drift 5 — Joker / “standard 52 + joker”

Some older wording implies joker-based deck composition.
Current clean-room `BuildStandardDeck()` is a plain **52-card deck**.

---

## Why the 85% Direction Became Difficult

The main problem is not just target percentage. It is **where the controllability lives**.

### Current tension

The team wants:

- authentic-feeling clean-room randomness
- no obvious scripting
- strong double-up excitement
- Lucky 5 drama
- cabinet-closing fantasy

### Current balancing reality

But current live control has a mismatch:

- deal/base game is strongly controlled by payout scale and mild deck alteration
- jackpot overlay is partially controlled by contributions/caps
- double-up is **very powerful**, but live control over DU is weak because:
  - DU is always offered on wins
  - DU deck is standard / unshaped
  - Ace auto-win remains on
  - Lucky 5 multipliers remain strong
  - chains are unlimited

So if the goal is strict long-run RTP while preserving clean-room feel, the hardest part is not base game — it is **double-up EV plus player behavior variance**.

That is why 85% proved awkward: once you try to keep the feature fun and authentic, the remaining precision levers are limited unless you start visibly scripting outcomes.

---

## Recommended Middle-Ground Direction for 80%

This is the current best design direction to preserve fun and avoid obvious scripting.

## Principle

Do **not** solve 80% by post-choice rigging or obvious scripted outcomes.

Instead, use only:

1. pre-shuffle deck shaping
2. payout-scale envelopes
3. jackpot economics
4. bounded stateful pacing logic
5. exact same visible rules

## Recommended visible-rule constraints to preserve

Treat these as preserved unless product explicitly says otherwise:

- Lebanese paytable unchanged
- no single-pair payout
- double deduction per round unchanged
- Ace auto-win in double-up unchanged
- `5♠` Lucky5 remains **switch-only**
- Lucky5 first/repeat multipliers unchanged
- no-loss `SafeFail` identity unchanged
- unlimited double-up chains unchanged
- deterministic pre-shuffled outcome logic unchanged
- no post-choice outcome rigging

## Proposed 80% architecture

### A) Make payout scale the primary reduction lever

For 80%, most RTP reduction should come from the base layer, not from killing the fun layer.

Working direction:

- lower base target materially from the 85% design
- keep warmup slightly generous, but not as hot
- tighten the scale orbit so it does less dramatic overshoot
- keep hot/cold swings smaller and more stable

### B) Lower jackpot budget modestly, not brutally

Jackpots are dream fuel. Do not delete them.

Better approach:

- slightly lower contribution rates
- slightly lower reset/start values
- slightly lower cap sizes if needed
- keep jackpots visible and reachable

### C) Reintroduce **bounded** double-up deck shaping instead of obvious scripting

This is the likely missing middle ground.

Current live DU uses a standard deck. That gives excitement, but weak operator-side control.

A better clean-room compromise is:

- still pre-shuffle the whole DU deck deterministically
- still never rig after player choice
- but allow very small DU deck envelopes selected before the round

Example envelope idea:

- `RecoveryDU`:
  - maybe add 1 Ace or 1 `5♠`
  - used when machine is cold or in clear player-drought states
- `NeutralDU`:
  - standard deck
- `PressureDU`:
  - maybe remove 1 Ace **or** add 1 neutral-bad card profile
  - never stack heavy manipulations
  - never use during crisis-recovery windows

The key is subtlety:

- no hard scripting
- no guaranteed win/loss rails
- only tiny composition nudges before shuffle

This preserves the cabinet feel far better than post-choice intervention.

### D) Use authored pacing bands instead of one raw drift number

Current system mostly reacts to RTP drift plus streak counters.

A better tension model is to choose a round envelope such as:

- `Recovery`
- `Neutral`
- `Celebrate`
- `Cooldown`
- `Pressure`

Each envelope would define allowed ranges for:

- deal deck shaping
- payout scale band
- DU deck envelope
- jackpot softness/pressure

That produces authored rhythm without scripting exact outcomes.

### E) Keep DU availability visible unless product explicitly decides otherwise

Because live path currently offers DU on every win, and because removing visible access changes player expectation, the cleaner 80% direction is:

    - keep DU always available
    - control DU EV softly through pre-shuffle DU deck envelopes
    - avoid harsh offer gating as the first-choice lever

    ### F) Important refinement from gameplay systems analysis

    A gameplay-systems review suggested that reintroducing live double-up offer control on small wins would be a low-risk RTP lever. That may be mathematically useful, but under the current user direction it should **not** be the first implementation choice because it changes visible behavior. The preferred first pass is:

        - lower the payout-scale orbit
        - modestly cool jackpot economics if needed
        - add subtle pre-shuffle double-up deck shaping
        - keep the visible double-up rule/availability experience intact unless product explicitly approves a visible change

---

## Working 80% Budget Direction

Not yet implemented, but likely sane starting point:

- Base scaled RTP: ~67.5% to 68.5%
- Jackpot RTP: ~2.5% to 3.0%
- Double-up RTP: ~9.0% to 10.0%
- Total: ~80%

Why:

- preserves double-up as the excitement layer
- avoids making base play feel dead
- avoids requiring strong visible DU suppression
- uses a more believable cabinet feel distribution

---

## Immediate Next Steps for Future Agents

1. **Finish Markdown digest**
   - confirm remaining authored docs
   - record additional drift/must-keep constraints

2. **Refresh the simulation harness against live code**
   - live DU is unconditional on wins
   - jackpot wins currently can enter DU
   - DU deck is currently standard
   - docs are not enough; mirror live code exactly

3. **Prototype the 80% redesign**
   - lower base target
   - modest jackpot budget reduction
   - add bounded DU deck shaping
   - add envelope-based pacing

4. **Validate for “not obviously scripted” feel**
   - look for repeated patterns
   - ensure deck shaping remains tiny and hard to perceive
   - preserve surprise and comeback paths

5. **Update docs after code**
   - especially `docs/README.md`
   - RTP docs
   - any doc claiming jackpot wins never enter DU if that remains false or gets changed intentionally

---

## Key Caution

Do not accidentally “fix” doc drift by changing gameplay rules unless the user explicitly approves it.

Especially dangerous accidental rule changes:

- blocking jackpot wins from DU
- changing Ace auto-win
- changing 5♠ switch-only behavior
- adding special-case 7 behavior
- capping chains
- removing take-half flow

Those may look like balancing cleanups, but they are actual rule changes.
