# Indexed Gameplay Pacing Audit

Date: 2026-04-05
Source: `C:\Users\Gabi\Documents\GitHub\indexed-lucky5-gameplay`
Input artifacts: `Recording-2026-04-05-112331_compressed_(1).txt`, `ocr.json`, `labels.computervision.json`, `_KeyFrameThumbnail.zip`

## What This Export Can Reliably Tell Us

- The capture is `0:04:14.1` long.
- Azure Video Indexer OCR is strong enough to recover cabinet text, brand flashes, control labels, and the moving top-right balance/credit value.
- The export is best for timing and UI-state inference, not exact card-by-card reconstruction.
- A few OCR values are clearly wrong by one digit or one character. Example: `57500` around `0:01:16.8` is almost certainly `157500`.

## Verified Cabinet Details

- Portrait layout at `720x1280`.
- Persistent top paytable text:
  `ROYAL FLUSH 2500000`
  `STRAIGHT FLUSH 187500`
  `4 OF A KIND 37500`
  `FULL HOUSE 30000`
  `FLUSH 25000`
  `STRAIGHT 20000`
  `3 OF A KIND 7500`
  `2 PAIR 5000`
- Top-right labels show `CREDIT` and `STAKE`.
- The sampled opening state shows `CREDIT 195000` and `STAKE 2500`.
- Mid-screen prompt is `PRESS HOLDS TO KEEP CARD`.
- Five yellow `HOLD` lamps sit above the control bank.
- Lower controls are always visible and match the clone cabinet layout:
  `BIG`, `SMALL`, `CANCEL HOLD`, `DEAL DRAW`, `BET`, `TAKE HALF`, `MENU`, `TAKE SCORE`.
- The line `4 OF A KIND WINS BONUS` is persistent under the serial/jackpot strip.

## Pacing Findings

- The strongest repeatable cadence marker is the OCR span for `PRESS HOLDS TO KEEP CARD`.
- That prompt appears `44` times in `254.1s`, which implies about one playable hand-state every `5.85s` on average.
- The prompt itself stays visible for an average of `1.60s`.
- The shortest prompt window is `0.83s`.
- The longest prompt window is `3.50s`.
- The branded result flash `LUCKY5` appears `43` times.
- `LUCKY5` stays on screen for an average of `0.70s`.
- The branded `POKER` overlay appears `49` times and tracks the same cadence.
- The average delay from `PRESS HOLDS TO KEEP CARD` to the next `LUCKY5` flash is about `4.91s`.

## Practical Loop Interpretation

- The clone does not linger on a completed hand.
- The player is given a very short hold-selection window, then the game transitions quickly into a result/brand flash.
- The result flash is brief and acts like punctuation, not a long celebration.
- The cabinet keeps all action-critical controls visible at all times, even when a hand is between states.
- The machine feels fast mostly because the non-interactive windows are short, not because the UI is complex.

## Credit Animation Behavior

- The visible credit stream is dominated by `2500`-step changes, which strongly suggests a base stake/bet loop around `2500`.
- Loss-like states usually settle immediately into a new stable balance.
- Win-like states count upward in several fast intermediate steps instead of jumping instantly.
- OCR caught repeated short count-up bursts around:
  `21.333s` to `22.167s`
  `38.667s` to `39.500s`
  `51.200s` to `52.033s`
  `116.267s` to `117.600s`
  `140.000s` to `141.067s`
  `147.200s` to `148.267s`
  `160.267s` to `161.333s`
- The intermediate values are noisy, but the presentation pattern is clear: the clone animates winnings as a rolling meter, not an instant ledger update.

## Rhythm Changes Over The Clip

- Early segment: wider gaps between result flashes, including `7s` to `10s` stretches, which reads like setup plus first few hands.
- Core segment: mostly `3s` to `5s` gaps between hold prompt and result punctuation.
- Longer interruptions show up around:
  `108.800s` to `118.667s`
  `134.667s` to `149.600s`
  `188.267s` to `204.033s`
- Those long windows likely correspond to payout count-up, user hesitation, or a slower transition after a notable outcome.

## What Lucky5 Should Borrow

- Keep the interaction loop tight: hold-selection prompt visible for roughly `1s` to `2s`, not long enough to feel draggy.
- Keep outcome punctuation short: brand/result flash closer to `0.5s` to `0.8s` than to multi-second celebration.
- Animate wins as short rolling count-ups instead of instant number swaps.
- Preserve always-visible cabinet controls so the player never feels mode-switched out of the machine.
- Preserve the harsh, sparse, almost homemade pacing. The clone feels fast because it is blunt and repetitive.

## What Lucky5 Should Not Copy Blindly

- OCR suggests some state transitions are abrupt enough to become unreadable.
- Several hands appear to resolve with almost no breathing room after the result flash.
- The clone likely sacrifices clarity for churn.
- Lucky5 should keep the fast loop, but make result readability and deterministic state sync cleaner than the clone.

## Confidence And Limits

- High confidence: cabinet layout, persistent labels, stake size clue, repeated loop cadence, brief brand/result flash behavior, rolling credit-count animation.
- Medium confidence: exact number of hands actually completed, because OCR groups some adjacent states together and misses a few digits.
- Low confidence: exact card-by-card play decisions from this export alone.

## Bottom Line

- Yes, the indexed export is enough to understand the clone's pacing.
- The clone's usable rhythm is roughly one hand beat every `5s` to `6s`, with a `1s` to `2s` hold-selection window and a sub-`1s` result flash.
- The strongest upgrade target for Lucky5 is not outcome logic. It is presentation timing: faster hold windows, shorter result punctuation, and a convincing rolling credit animation layered over the clean-room engine.
