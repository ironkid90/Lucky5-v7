# Minimal live-repo wiring notes

## `index.html`

Load the new files **after** the legacy bundle:

```html
<link rel="stylesheet" href="css/cabinet-layout-vnext.css?v=1">
<link rel="stylesheet" href="css/cabinet-labels-vnext.css?v=1">
<script src="js/cabinet-stage-vnext.js?v=1"></script>
<script src="js/cabinet-pace-vnext.js?v=1"></script>
```

## `game.js`

### Deal path
Call `CabinetStage.dealCards(cards)` with the actual dealt face cards immediately. Do **not** stage card backs before the real images.

### Draw path
Call `CabinetStage.drawCards(cards, holdIndexes)` and keep held slots visually stable.

### Idle/title path
Add:

```js
CabinetStage.setIdleBackground(gameState === 'idle' && (!cards || !cards.length));
```

### Double-up path
Use the existing DTO cards and `Status` to drive presentation:

```js
CabinetStage.enterDoubleUp(result.dealerCard);
CabinetStage.updateDoubleUpTrail(window.duCardTrail || [], result.dealerCard, result.challengerCard, result.status);
```

Before the next reveal, call:

```js
CabinetStage.updateDoubleUpTrail(window.duCardTrail || [], result.dealerCard, null, '');
```

That lets the frontend keep the requested left-to-right fill and the `slot 4 -> slot 0` carry-over without changing backend rules.
