Original prompt: Implement frontend jackpot cabinet UI fixes in the vanilla cabinet: add visible Full House jackpot meter, fix active 4K side highlight to use live DOM nodes, correct jackpot messaging/slot-tag visuals, add regression coverage, and verify with the Lucky5 test runner.

- 2026-03-15: Started investigating the vanilla cabinet jackpot UI in [`server/src/Lucky5.Api/wwwroot/index.html`](server/src/Lucky5.Api/wwwroot/index.html) and [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js).
- Findings so far:
  - The cabinet renders three visible jackpot counters only, while [`game.js`](server/src/Lucky5.Api/wwwroot/js/game.js:303) still updates legacy Full House jackpot hooks (`jp-fh-rank`, `jp-fh-val`) that are not present in live markup.
  - [`updateActive4kHighlight()`](server/src/Lucky5.Api/wwwroot/js/game.js:313) still targets dead `.jackpot-slot.jp-4k` nodes.
  - Jackpot win amount/tag UI likely needs conditional slot-tag handling because [`updateWinAmountDisplay()`](server/src/Lucky5.Api/wwwroot/js/game.js:343) always accepts a slot tag even when the hand is not Four of a Kind.
- TODO:
  - Inspect [`server/tests/Lucky5.Tests/FrontendRegressionTests.cs`](server/tests/Lucky5.Tests/FrontendRegressionTests.cs) for existing frontend regression coverage.
  - Add visible Full House meter markup/styling with retro cabinet look.
  - Rebind active 4K highlight to live counter nodes and adjust messaging/tag behavior.
