Original prompt: Implement frontend jackpot cabinet UI fixes in the vanilla cabinet: add visible Full House jackpot meter, fix active 4K side highlight to use live DOM nodes, correct jackpot messaging/slot-tag visuals, add regression coverage, and verify with the Lucky5 test runner.

- 2026-03-15: Started investigating the vanilla cabinet jackpot UI in [`server/src/Lucky5.Api/wwwroot/index.html`](server/src/Lucky5.Api/wwwroot/index.html) and [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js).
- Findings so far:
  - The cabinet renders three visible jackpot counters only, while [`game.js`](server/src/Lucky5.Api/wwwroot/js/game.js:303) still updates legacy Full House jackpot hooks (`jp-fh-rank`, `jp-fh-val`) that are not present in live markup.
  - [`updateActive4kHighlight()`](server/src/Lucky5.Api/wwwroot/js/game.js:313) still targets dead `.jackpot-slot.jp-4k` nodes.
  - Jackpot win amount/tag UI likely needs conditional slot-tag handling because [`updateWinAmountDisplay()`](server/src/Lucky5.Api/wwwroot/js/game.js:343) always accepts a slot tag even when the hand is not Four of a Kind.
- 2026-03-15: Implemented the vanilla cabinet jackpot UI fix set.
- What changed:
  - Added a dedicated live Full House jackpot meter in [`server/src/Lucky5.Api/wwwroot/index.html`](server/src/Lucky5.Api/wwwroot/index.html) and styled it in [`server/src/Lucky5.Api/wwwroot/css/game.css`](server/src/Lucky5.Api/wwwroot/css/game.css) to keep the retro green/red/gold cabinet look.
  - Rewired [`updateJackpotDisplay()`](server/src/Lucky5.Api/wwwroot/js/game.js:269) so the live cabinet now updates `#jp-counter-fh` from live jackpot data and keeps the Full House rank badge visible.
  - Rewired [`updateActive4kHighlight()`](server/src/Lucky5.Api/wwwroot/js/game.js:315) to use live `[data-jackpot-slot]` counter nodes, with a visible `.jp-counter.jp-active` state in [`server/src/Lucky5.Api/wwwroot/css/game.css`](server/src/Lucky5.Api/wwwroot/css/game.css).
  - Added [`getFourOfAKindSlotTag()`](server/src/Lucky5.Api/wwwroot/js/game.js:345) and updated [`updateWinAmountDisplay()`](server/src/Lucky5.Api/wwwroot/js/game.js:361) so A/B slot tags only render for Four of a Kind outcomes.
  - Simplified jackpot win messaging in [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js) and [`updateBonusBar()`](server/src/Lucky5.Api/wwwroot/js/game.js:378) so jackpot wins no longer visually imply duplicate payout amounts.
  - Extended [`server/tests/Lucky5.Tests/FrontendRegressionTests.cs`](server/tests/Lucky5.Tests/FrontendRegressionTests.cs) to guard the live Full House meter, live 4K highlight wiring, active counter styling, and non-duplicative jackpot slot-tag/message behavior.
- Test notes:
  - Red phase: `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj` failed with the new jackpot regression assertions before the frontend runtime changes.
  - Green phase: `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj` passed after the frontend/runtime/test updates.
- Remaining TODOs:
  - None for this subtask.
