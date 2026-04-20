# Lucky 5 v8 — "Cabinet Real" Plan

**Status:** Tracks A+B+C code-complete. Track A RTP verification pending user-run sim.
**Last updated:** 2026-04-20
**Scope:** Major version bump focused on (a) realistic arcade-cabinet visual & tactile feel, (b) engine RTP **calibration** to 80% composite **without changing any game rules**, and (c) targeted 2026-04-20 surgery (hold-badge fix, FH-target button, FH jackpot reposition, single-star 4OAK accrual, paytable drain for wins).
**Non-goals:** Mobile-first redesign, new game modes, database migration (Data Connect schema remains aspirational).

> **New contributor?** Read `LUCKY5_V8_HANDOFF.md` first — it is the shortest path to resuming this work.

---

## Track A — Engine RTP calibration to true 80% long-term

### Guarantee
**Game rules are unchanged.** Ace still auto-wins both sides, double-up chain is still unbounded, Lucky 5 switch still arms no-lose, multipliers stay at `4x`/`2x`, and the paytable categories and multipliers are unchanged. Only the RTP controller's configuration knobs are retuned so the closed-loop controller converges to 80% composite RTP under the existing rules.

### Baseline (April 2026)
- `EngineConfig.TargetRtp = 0.80m` (unchanged).
- Closed-loop controller lives in `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs` and drives `PayoutScaleResult` from observed vs target RTP drift.
- Monte Carlo harness: `server/src/Lucky5.Simulation/Program.cs`. Acceptance band is [78%, 82%].
- Largest empirical leak under optimal play is the double-up layer (Ace-auto-win + optimal BIG/SMALL strategy + Lucky 5 no-lose safety).

### Root-cause analysis
The v7 config declared `TargetDoubleUpRtp = 0.0950` but optimal players extract closer to 0.12 – 0.13 from the DU layer once Ace-auto-win and Lucky 5 safety are exploited. Because the controller's base target is computed as `TargetRtp - TargetJackpotRtp - TargetDoubleUpRtp`, an under-estimated DU target made the controller aim for a base RTP that, when summed with reality, overshot 80%. The correction loop would eventually pull down but only after material over-payment.

### v8 calibration knob changes (rules unchanged)

All changes applied in `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs` `EngineConfig` record.

| Knob | v7 | v8 | Rationale |
|------|----|----|-----------|
| `TargetDoubleUpRtp` | 0.0950 | **0.1200** | Acknowledges optimal-player DU extraction. Pulls base target down ~3.5 pp, letting the controller converge without overshoot. |
| `DoubleUpRtpHardCap` | 0.110 | **0.130** | Keeps the DU leak clamp from firing every round while still acting on sustained overshoot. |
| `WarmupOpeningSmallScale` | 1.65 | **1.55** | Trims fresh-session over-pay; churn-heavy sessions no longer compound warmup bias. |
| `WarmupOpeningMediumScale` | 1.70 | **1.58** | Same. |
| `WarmupOpeningBigScale` | 1.75 | **1.60** | Same. |
| `DefaultPayoutScale` | 1.75 | **1.60** | Moves the neutral-state scale closer to the new target-base equilibrium. |
| `MinPayoutScale` | 1.18 | **1.08** | Extends downward headroom when live RTP trends hot. |
| `CrisisScaleBoost` | 0.07 | **0.05** | Prevents pity-boost from pushing the scale into overshoot during long loss streaks. |
| `MaxPayoutScale` | 2.05 | 2.05 *(unchanged)* | Generosity cap preserved for cold streaks. |

### Test updates required
- `CleanRoomEngineTests.cs` assertion `"Approved payout-scale defaults should match the v8 tuned architecture"` updated to the new default/min values.
- All DU rule tests (Ace auto-win, unlimited chain, Lucky 5 switch, machine close) remain **unchanged** and must still pass.

### Verification workflow (user-run)
```powershell
# 1. Regression suite (~30 s)
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj

# 2. RTP sim — 200 k rounds smoke test
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -c Release -- --rounds 200000

# 3. RTP sim — 500 k rounds certification gate
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -c Release -- --certification
```
The sim gate passes when composite RTP lands in [78%, 82%] with the Balanced player strategy. If the first pass lands outside the target band, the following single-knob tweaks are the safest next levers (still no rule changes):

1. **Persistent overshoot:** lower `DefaultPayoutScale` in 0.05 steps toward 1.50.
2. **Undershoot:** raise `WarmupOpeningBigScale` back toward 1.70, or trim `TargetDoubleUpRtp` back toward 0.11.
3. **Wide variance at 200 k rounds:** run the 500 k certification run. 200 k is inside the noise band of the controller by design.

---

## Track B — Cabinet realism (visual + tactile feel)

Implemented as a layered v8 CSS/JS pair on top of the existing vnext stack so rollback is a single `<link>` / `<script>` removal.

### Asset restoration (Cloud Run bug fix)
All 178 card / button / font / board / logo / coin PNG + TTF files were missing from the repo (accidentally deleted in commit `933788b`). They have been restored from commit `933788b^` into `server/src/Lucky5.Api/wwwroot/assets/` and `mobile/www/assets/`. Because `Microsoft.NET.Sdk.Web` auto-publishes `wwwroot/`, the Cloud Run Docker image now ships the full asset set. This resolves the user-reported "cards missing images" bug in Cloud Run.

### B1 — Physical cabinet frame (`css/cabinet-v8-realism.css`)
`#game-container` is wrapped in a layered wooden bezel via `box-shadow`, adding:
- Inner cabinet lip, wooden side panels, outer chrome edge.
- Ambient room darkening outside the bezel.
- Responsive thicker bezel at `min-width: 768px`.

### B2 — CRT realism
- Phosphor subpixel RGB shimmer via `repeating-linear-gradient` on `.crt-overlay::before` with `mix-blend-mode: screen`.
- Animated vertical scan roll via `#game-container::after` (7 s period).
- Screen curvature / edge vignette via `#game-container::before` radial inset.
- Low-frequency phosphor flicker on `#game-screen`.
- CRT warm-up fade-in on initial load (1.2 s), driven by `body.v8-ready` toggle.

### B3 — Button haptics
- `.cab-btn.is-pressed` press animation (`translateY` + brightness dim + inset shadow) with 80 ms transition.
- LED heartbeat pulse on valid action buttons (`#btn-deal`, `#btn-bet`, `#btn-big`, `#btn-small`).
- Hold buttons glow gold when `.active`.
- Disabled state dimmed via grayscale filter.
- `js/cabinet-v8-effects.js` wires pointerdown/up across `.cab-btn`, `.menu-panel-btn`, `.lobby-btn`, `.auth-btn`.

### B4 — Card animation
- `.card-slot.v8-flipping` runs a 3D `rotateY` flip on draw.
- Winning cards pulse (`v8-card-win-pulse` keyframes with drop-shadow glow).
- Losing cards dim to 55% brightness.

### B5 — Win celebration tiers
Driven by `cabinet-v8-effects.js` observing `#win-amount-value` mutations and classifying via `#win-slot-tag` text + amount thresholds:

- **Small** (TwoPair, ThreeOfAKind): meter count-up via existing vnext animation.
- **Medium** (Straight, Flush, FullHouse): bigger scale-in animation + brightness pulse.
- **Big** (FourOfAKind, StraightFlush): cabinet camera shake, marquee strobe.
- **Jackpot** (RoyalFlush): full-screen radial siren pulse + coin shower canvas.
- Coin shower renders up to ~60 coins on a dedicated `#v8-coin-canvas` overlay for 1.6 – 2.8 s.

### B6 — Idle attract mode
- Triggers 30 s after last input if `#game-screen` is active and `#idle-overlay` is visible.
- Sequentially highlights paytable rows at 1.6 s cadence.
- Pulses `#idle-overlay-text` with a green-phosphor CTA effect.
- Any pointer, key, touch, or wheel event exits attract and resets the idle timer.

### B7 — Ambient detail
- `#cabinet-marquee` LED strip above `#game-container` scrolls `LUCKY 5 • LEBANESE LEGEND • 80% RTP • FIVE OF SPADES NEVER LOSES` at 22 s per loop.
- `#cabinet-hopper` coin tray rendered below the cabinet.
- `prefers-reduced-motion: reduce` disables all animations for users who opt out.

### Rollback
Phase 2/3/4 visuals are entirely additive:
```html
<!-- remove from index.html to fully revert -->
<link rel="stylesheet" href="/css/cabinet-v8-realism.css?v=1">
<script src="/js/cabinet-v8-effects.js?v=1"></script>
```

---

## Sequencing summary
1. **Phase 1 (engine calibration):** `EngineConfig` knob retuning. Rules untouched. **Needs user-run sim to confirm composite in [79.5%, 80.5%] target band.**
2. **Phase 2 (frame + CRT + buttons):** `cabinet-v8-realism.css` sections 1 – 5. Wired.
3. **Phase 3 (motion):** `cabinet-v8-realism.css` sections 6 – 7 + `cabinet-v8-effects.js` coin shower + win observer. Wired.
4. **Phase 4 (polish):** attract mode, marquee, hopper, reduced-motion. Wired.
5. **Asset restoration:** 178 PNG + TTF assets restored from git history (Cloud Run cards bug fix).

## Risk register
- **Calibration knobs are data — no rule change.** Worst case: sim lands outside [78%, 82%] and requires a second micro-adjustment per the contingency ladder above.
- **`.is-pressed` class is new** — existing buttons that toggle `.active` are unaffected because the selectors are independent.
- **Coin-shower canvas on underpowered devices** — throttled to ~60 concurrent coins max; auto-stops at 2.8 s. Disabled entirely by `prefers-reduced-motion: reduce`.
- **Asset size** — restored PNGs average ~1 MB each (~40 MB total). Cloud Run cold start impact is negligible (runtime boot dominates). A future WebP/AVIF conversion pass is the follow-up optimization lever.
