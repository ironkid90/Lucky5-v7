# Lucky5 clone-parity cabinet bundle

This bundle is mapped to the documented Lucky5 vanilla cabinet paths and focuses on the exact areas requested:

- 720x1280 portrait cabinet zoning
- minimized but denser control deck
- immediate face-up deal rendering
- left-to-right double-up progression with 5th-card carry-over
- idle `LUCKY5 POKER` background inside the cabinet face

## What is included

- `server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css`
- `server/src/Lucky5.Api/wwwroot/css/cabinet-labels-vnext.css`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js`
- `prototype/index.html` + `prototype/demo.js` visual harness

## Important limitation

The actual Lucky5 repository snapshot was **not present** in this container, so I could not patch the live repo files directly or run the real ASP.NET app. The files here are therefore a **drop-in implementation bundle** aligned to the documented paths and DOM contract from the uploaded plan/brief files.

## Suggested integration in the real repo

1. Copy the CSS and JS files into the documented `wwwroot` paths.
2. Load them after `game.css` and `game.js` in `index.html`.
3. Wire the existing `game.js` calls to:
   - `CabinetStage.dealCards(cards)` after the deal response
   - `CabinetStage.drawCards(newCards, holdIndexes)` after draw
   - `CabinetStage.enterDoubleUp(dealerCard)` when DU starts
   - `CabinetStage.updateDoubleUpTrail(trail, dealer, challenger, status)` on each DU reveal
   - `CabinetStage.setIdleBackground(true/false)` when entering or leaving idle/title mode
4. Keep the backend authoritative; the sequential left-to-right DU filling here is a frontend presentation layer that uses the existing `Status` and card fields.

## Prototype controls

- `BET` increases stake in idle mode
- `DEAL / DRAW` deals, then draws
- Hold 1st and 3rd card to see non-held-only draw behavior
- `BIG` / `SMALL` step through the double-up visual sequence
- `TAKE HALF` and `TAKE SCORE` demonstrate non-modal cabinet exits
- `MENU` resets to idle to show the `LUCKY5 POKER` background again
