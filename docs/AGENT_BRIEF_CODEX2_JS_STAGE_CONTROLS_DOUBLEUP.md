# Agent Brief: Codex 2 — JS Card Stage, Controls, Double-Up, Pace

## What You Are Building

Lucky5 is a Lebanese video-poker arcade cabinet recreation. The backend is ASP.NET Core 9. The frontend is a single-page vanilla JS + CSS cabinet served from `server/src/Lucky5.Api/wwwroot/`.

Your job is to bring the **card stage choreography, control deck press behavior, double-up viewport, and pace animations** to clone parity. You write JavaScript only into two new files. You do not touch CSS, HTML, or backend files.

---

## Your Files

Write into these files only. They are pre-created stubs:

- `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js`

Both are loaded after `game.js` in `index.html`. You expose functions on a `CabinetStage` and `CabinetPace` namespace object. The existing `game.js` calls these after the DOM contract freeze hooks are in place.

---

## Files You Must Not Touch

- `index.html` — frozen after Phase 0.4, lead agent only
- `game.css`, `game.js` — legacy, do not edit
- any CSS files
- any `.cs` backend files

---

## DOM Contract: Elements You Can Target

All element IDs below exist in the frozen `index.html`. Do not invent new IDs.

| Element | ID / Selector | Your use |
|---------|--------------|----------|
| Card area | `#card-area` | render and animate card slots |
| Individual card slots | `.cab-card[data-slot="0..4"]` | deal/draw targets |
| Hold lamp row | `#hold-row` | hold state toggling |
| Hold buttons | `.cab-btn.cab-hold[data-index="0..4"]` | pressed state |
| BIG button | `#btn-big` | pressed state + enable/disable |
| SMALL button | `#btn-small` | pressed state + enable/disable |
| CANCEL HOLD | `#btn-cancel` | pressed state |
| DEAL DRAW | `#btn-deal` | pressed state |
| BET | `#btn-bet` | pressed state |
| TAKE HALF | `#btn-take-half` | pressed state |
| TAKE SCORE | `#btn-take-score` | pressed state |
| Win amount | `#win-amount-value` | count-up animation target |
| Win slot tag | `#win-slot-tag` | A/B tag beside win amount |
| Lucky5 flash | `#lucky5-flash` | flash overlay |
| Lucky5 banner | `#lucky5-banner` | text banner |
| Info bar message | `#game-message` | status messages |
| Bonus text | `#bonus-text` | bonus hand text |
| Jackpot counter values | `.jp-cval` inside `#jp-counter-a`, `#jp-counter-center`, `#jp-counter-b`, `#jp-counter-fh` | count-up |
| FH rank badge | `#jp-fh-rank` | rank letter |
| Credits display | `#credits span` | credit count-up |

---

## Available Card Assets

All 52 card PNGs are at `/assets/images/cards/{rank}{suit}.png`.

- Ranks: `2 3 4 5 6 7 8 9 10 J Q K A`
- Suits: `H D C S`
- Examples: `AH.png`, `KS.png`, `5S.png`, `10C.png`
- Card back: `/assets/images/cards/bside.png`

All preloaded via `preloadAllAssets()` in `game.js` — already available in `preloadedImages[path]` at runtime.

## Available Button Assets

All at `/assets/images/`:

| Button | Off state | On/pressed state |
|--------|-----------|-----------------|
| HOLD | `hold_off.png` | `hold_on.png` |
| BIG | `big.png` | `big_on.png` |
| SMALL | `small.png` | `small_on.png` |
| CANCEL HOLD | `cancel_hold.png` | `cancel_hold_on.png` |
| DEAL DRAW | `deal_draw.png` | `deal_draw_on.png` |
| BET | `bet.png` | `bet_on.png` |
| TAKE HALF | `take_half.png` | `take_half_on.png` |
| TAKE SCORE | `take_score.png` | `take_score_on.png` |
| Board (wood texture) | `board.png` | — |

Render buttons as `<img>` tags inside the existing button elements, or set `background-image` via JS. Use the `_on` variant on mousedown/touchstart, revert on mouseup/touchend.

---

## cabinet-stage-vnext.js: What To Implement

### Namespace

```js
window.CabinetStage = {};
```

### Card slot rendering

The `#card-area` should contain five fixed `.cab-card` slots indexed 0–4.

On load, call `CabinetStage.initCardSlots()` which:
- Empties `#card-area`
- Creates 5 divs: `<div class="cab-card" data-slot="0">` through `data-slot="4"`
- Each slot contains one `<img class="card-img">` element
- Shows card back by default

### Deal animation

`CabinetStage.dealCards(cardArray)`:
- `cardArray` is an array of 5 card objects: `{ rank, suit, code }` — e.g. `{ rank: "A", suit: "H", code: "AH" }`
- Cards enter left to right
- Stagger: 100ms between each card
- Each card: slide in from above (`translateY(-60px)` to `translateY(0)`) + opacity 0→1 over 120ms
- Set `src` to `/assets/images/cards/${code}.png`

### Draw animation

`CabinetStage.drawCards(newCardArray, heldIndexes)`:
- `heldIndexes` is a Set or array of slot indices that are held
- Only non-held slots update
- Held slots: no animation, card image stays
- Non-held slots: brief flip (opacity 1→0 over 60ms, swap image, opacity 0→1 over 80ms)

### Hold lamp state

`CabinetStage.setHold(slotIndex, isHeld)`:
- Toggle `.held` class on the card slot
- Swap the HOLD button image at that index: `hold_on.png` when held, `hold_off.png` when not
- Add `HOLD` text label on the button when held

`CabinetStage.clearAllHolds()`: reset all 5 hold lamps.

### Button press feedback

`CabinetStage.initButtonAssets()`:
- For each button listed in the DOM contract table above, set its background or inner image to the off-state asset
- Bind mousedown/touchstart → swap to `_on` asset
- Bind mouseup/touchend/mouseleave → revert to off asset
- This is purely cosmetic — do not add game logic

### Double-up viewport

`CabinetStage.enterDoubleUp(dealerCard)`:
- Repurpose `#card-area` for double-up display
- Layout: 4 trail slots + 1 active challenger slot (5 total, same positions as base game)
- Trail slots 0–3 hold the dealer/trail history
- Slot 4 is the active challenger
- Show `dealerCard` in slot 3 with gold border highlight (add class `.du-dealer`)
- Show card shuffle in slot 4 (rapid random card cycling at 80ms — see shuffle below)

`CabinetStage.updateDoubleUpTrail(trailCards, dealerCard, challengerCard, status)`:
- `trailCards`: array of up to 3 previous cards (shown in slots 0–2)
- `dealerCard`: shown in slot 3
- `challengerCard`: if null, run shuffle; if present, show revealed card + stop shuffle
- `status`: used to set labels (`BIG`, `SMALL`, `BIG / SMALL ?`) below each relevant slot
- Apply gold frame class (`.du-dealer`) to slot 3
- Apply `.du-lucky5` flash glow if the revealed card is `5S`

`CabinetStage.shuffleChallenger()`:
- Cycle random card images in slot 4 every 80ms
- Stop when `updateDoubleUpTrail` is called with a non-null `challengerCard`
- Use the preloaded `ALL_CARD_CODES` array (accessible at `window.ALL_CARD_CODES` from game.js)

`CabinetStage.exitDoubleUp()`:
- Clear all double-up state and classes
- Restore normal 5-card base-game layout

### Lucky5 active state

`CabinetStage.showLucky5Active()`:
- Add `.lucky5-active` class to card stage cards (produces glow, handled by CSS)
- Show `#lucky5-banner` by adding `.active` class
- Auto-clear after 700ms

---

## cabinet-pace-vnext.js: What To Implement

### Namespace

```js
window.CabinetPace = {};
```

### Credit count-up

`CabinetPace.countUp(element, startValue, endValue, durationMs)`:
- Animates a numeric display from `startValue` to `endValue` over `durationMs`
- Uses `requestAnimationFrame`
- Formats number with comma separators (use `Intl.NumberFormat`)
- Used for: `#credits span`, `#win-amount-value`, jackpot counter `.jp-cval` elements

### Win collection animation

`CabinetPace.collectWin(winAmount, currentCredits, onComplete)`:
- Display win amount in `#win-amount-value` instantly
- After 400ms, begin counting `#credits span` up by `winAmount`
- Duration: scale with amount — `1500ms` for small, up to `5000ms` for large jackpots
- On complete, call `onComplete()`

### Jackpot fill animation

`CabinetPace.fillJackpot(jpElement, fromValue, toValue, onComplete)`:
- Count-up `jpElement`'s `.jp-cval` span from `fromValue` to `toValue`
- Duration: `10000ms` to `15000ms` depending on delta
- Call `onComplete()` when done

### Lucky5 flash

`CabinetPace.flashLucky5()`:
- `#lucky5-flash` element: add class `.flash-active` for 300ms (CSS handles white/gold overlay)
- Then add `.banner-flicker` to `#lucky5-banner` for 700ms
- No blocking — non-modal, continues in background

### Pace rules

- No `alert()`, `confirm()`, or blocking modals anywhere
- All transitions are CSS class additions or `requestAnimationFrame` loops
- Player can press buttons at any time after the animation starts — do not lock input during cosmetic animations (input locking is game.js's domain)
- After deal/draw animations complete, call a completion callback so `game.js` can re-enable buttons

---

## State You Can Read (from game.js globals)

These globals are set by `game.js` and safe to read:

```js
window.cards           // current 5-card array [{rank, suit, code}]
window.holdIndexes     // Set of held slot indices
window.gameState       // 'idle' | 'deal' | 'draw' | 'win' | 'doubleup'
window.duCardTrail     // array of previous double-up cards
window.duDealerCard    // current dealer card object
window.ALL_CARD_CODES  // array of all 52 card code strings
window.preloadedImages // {path: HTMLImageElement} preloaded map
```

Do **not** write to these globals. Do not duplicate game logic.

---

## Integration Points

`game.js` will call your functions at key moments. Your functions must be ready on window load:

```js
// After deal API response:
CabinetStage.dealCards(cards);

// After draw API response:
CabinetStage.drawCards(newCards, holdIndexes);
CabinetPace.collectWin(winAmount, newCredits, () => { /* game.js re-enables input */ });

// On hold button click (game.js already handles API):
CabinetStage.setHold(index, isHeld);

// On entering double-up:
CabinetStage.enterDoubleUp(dealerCard);

// On each double-up result:
CabinetStage.updateDoubleUpTrail(trail, dealer, challenger, status);

// On Lucky5 flash:
CabinetPace.flashLucky5();
CabinetStage.showLucky5Active();
```

---

## Non-Negotiable Rules

- Do not add any game outcome logic — you render what `game.js` tells you
- Do not call backend APIs
- Do not change how `TAKE SCORE`, `TAKE HALF`, `BIG`, `SMALL` work — only their visual press state
- Do not edit `game.js` — expose your API on `window.CabinetStage` and `window.CabinetPace`
- The Lucky5 5S no-lose rule is enforced by the backend — you only need to show the glow when the card is 5S
- Double-up trail is frontend display state — build it from the `DoubleUpResultDto` data `game.js` gives you

---

## Verification Criteria

1. Deal 5 cards: they appear left-to-right with visible stagger
2. Hold cards 1 and 3, draw: only slots 0, 2, 4 flip; slots 1 and 3 stay stable
3. All buttons show correct asset images and respond with `_on` variant on press
4. Enter double-up: trail + dealer + challenger shuffle visible in card stage
5. Reveal challenger: shuffle stops, card shown, label (`BIG` or `SMALL`) visible beneath slot
6. Reveal 5S: card glows briefly
7. Win collection: credits count up visibly, not instant
8. Lucky5 flash: screen flashes white/gold briefly, no modal pause
