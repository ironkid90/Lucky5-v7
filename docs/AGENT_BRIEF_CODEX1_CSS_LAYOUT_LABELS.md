# Agent Brief: Codex 1 — CSS Layout, Labels, Jackpot Surface

## What You Are Building

Lucky5 is a Lebanese video-poker arcade cabinet recreation running as a web app. The backend is an ASP.NET Core 9 server. The frontend is a single-page vanilla JS + CSS cabinet served from `server/src/Lucky5.Api/wwwroot/`.

Your job is to bring the **visual layout and label system** of the cabinet to clone parity. You are writing CSS only. You do not touch JS, HTML, or backend files.

---

## Your Files

Write into these files only. They are pre-created stubs:

- `server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css`
- `server/src/Lucky5.Api/wwwroot/css/cabinet-labels-vnext.css`

Both files are loaded after `game.css` in `index.html`. Your rules override `game.css` where needed. Do not edit `game.css` itself.

---

## Files You Must Not Touch

- `index.html` — frozen after Phase 0.4, lead agent only
- `game.css` — legacy, keep loading, do not edit
- any `.js` files
- any `.cs` backend files

---

## DOM Contract: Zones You Can Target

These are the stable hooks added in Phase 0.4. Target them by `id` or `data-zone`:

| Zone | Selector | Your responsibility |
|------|----------|-------------------|
| Whole game screen | `#game-screen` | portrait cabinet board |
| Paytable | `[data-zone="paytable"]` / `#paytable` | rainbow pixel rows, highlight box |
| Credit/stake | `[data-zone="credit-stake"]` / `#credit-stake-bar` | top-right, green/amber labels |
| Label band | `[data-zone="label-band"]` / `#lucky5-banner` | between paytable and cards |
| Card stage | `[data-zone="card-stage"]` / `#card-area` | sizing, not animation |
| Win amount | `[data-zone="win-amount"]` / `#win-amount-display` | gold embossed number |
| Machine-info block | `[data-zone="machine-info"]` / `#machine-info-block` | SERIE, KENT, jackpot counters, FH, S/N, bonus text |
| Hold lamp row | `[data-zone="hold-row"]` / `#hold-row` | sizing/alignment only |
| Main action row | `[data-zone="action-row"]` / `#action-row` | sizing/alignment only |
| Bottom row | `[data-zone="bottom-row"]` / `#bottom-row` | sizing/alignment only |
| Info bar | `[data-zone="info-bar"]` / `#info-bar` | centered text messages |
| Double-up info | `[data-zone="du-info"]` / `#du-info-panel` | HI LO GAMBLE labels |

---

## cabinet-layout-vnext.css: What To Implement

### Goal

Make `#game-screen` behave as a single `720x1280` portrait cabinet board that scales as one unit. No reflowing controls into side columns.

### Vertical zone map (use percentage heights inside `#game-screen`)

```
0%  - 15%  → #paytable + #credit-stake-bar
15% - 19%  → #lucky5-banner (label band)
19% - 38%  → #card-area (card stage)
38% - 42%  → #win-amount-display
42% - 53%  → #machine-info-block
53% - 67%  → #hold-row
67% - 84%  → #action-row
84% - 97%  → #bottom-row
```

### Layout rules

- `#game-screen` is `position: relative; width: 100%; height: 100%;` — it fills the game container which is already `max-width: 540px` centered
- Each zone uses `position: absolute` with `top`/`height` set to the percentages above
- Desktop: the container is already centered. Add negative space on sides. Do not create a sidebar.
- The cabinet does not reflow. Portrait column only.

### Paytable + credit-stake split

- `#paytable` occupies left ~65% of the 0%–15% zone
- `#credit-stake-bar` occupies right ~35% of the same zone
- Both `position: absolute` within `#game-screen`, same top/height band

---

## cabinet-labels-vnext.css: What To Implement

### Typography base

- Pixel font: `'Press Start 2P', 'Arcade', monospace` — already loaded
- All paytable, label, and counter text uses this font
- No smooth rounded fonts anywhere in the cabinet face

### Paytable rows (`#paytable .pay-row`)

Match these exact colors per hand row:

| Hand | Color |
|------|-------|
| ROYAL FLUSH | `#ff4444` (red/white) |
| STRAIGHT FLUSH | `#ff8800` (orange-red) |
| 4 OF A KIND (`foak`) | `#44ffcc` (cyan) |
| FULL HOUSE (`fh`) | `#ffff00` (yellow) |
| FLUSH (`fl`) | `#ff6666` (red) |
| STRAIGHT (`st`) | `#44ff88` (green) |
| 3 OF A KIND (`tok`) | `#44ddff` (cyan) |
| 2 PAIR (`tp`) | `#ddddaa` (yellow-white) |

Active/selected jackpot row: add a solid box highlight (not glow) around the full row — `outline: 2px solid currentColor; background: rgba(255,255,255,0.08)`.

Payout amounts (`.pay-amount`): same color as row, right-aligned.

### Credit and stake labels (`#credit-stake-bar`)

- `CREDIT` label text: `color: #00ff44` (green)
- `STAKE` label text: `color: #ffcc00` (amber)
- Numeric values below each label: `color: #ffffff`
- Font size: approximately `8px` pixel font (adjust for fit)
- Right-aligned within their container

### Lucky5 banner (`#lucky5-banner`)

- Between paytable and cards
- Green pixel text: `color: #00ff44`
- Centered
- Hidden by default, shown via `.active` class when triggered
- No reflow — uses reserved height in the label-band zone

### Machine-info block (`#machine-info-block`)

Vertical order within the block:

1. `.machine-identity` row — SERIE and KENT in green (`#44ff88`)
2. `#jackpot-counters` — three counters side by side
   - `#jp-counter-a` (4K A): green text
   - `#jp-counter-center` (SF): red text (`#ff4444`)
   - `#jp-counter-b` (4K B): green text
   - Active counter gets a solid amber box: `outline: 2px solid #ffcc00; background: rgba(255,200,0,0.1)`
3. `#jackpot-full-house` — FH rank + FH meter
   - **Black text on white container**: `background: #ffffff; color: #111111; padding: 2px 6px`
   - FH rank badge (`#jp-fh-rank`): same treatment
4. `#machine-serial` (S/N) — green text
5. `#bonus-hand-text` — white pixel text, full width, large, centered
   - When showing `4 OF A KIND WINS BONUS`: font-size larger than body text, color `#ffffff`

### Win amount display (`#win-amount-display`)

- Gold color: `#ffcc00`
- Text shadow/outline effect: `text-shadow: 1px 1px 0 #000, -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000`
- Large font (relative to cabinet height — approx 20–24px pixel font)
- Slot tag (`#win-slot-tag`) sits immediately left of the amount, same gold color
- Only visible when a win amount is set (controlled by JS via display/visibility)

### Info bar (`#info-bar`)

- Centered text, white, pixel font ~8px
- Messages: `INSERT COIN`, `PLAY 5000`, win collection messages
- No overlay, no modal

### Double-up info panel (`#du-info-panel`)

- `#du-label`: `HI LO GAMBLE` — amber text
- `#du-ace-info`: `ACE COUNTS HI OR LO` — white text
- `#du-lucky-info`: rule text — cyan text
- Visible only during double-up (JS toggles `.active`)

---

## Available Assets

All in `server/src/Lucky5.Api/wwwroot/assets/`:

- `fonts/ARCADE.ttf` — already loaded in game.css
- `images/board.png` — wood deck texture (for control deck background — Codex 2 handles JS, you handle CSS background)
- `images/lucky5.png` — brand logo (used in shell, not in game screen)

You do not need to reference card or button images — those are Codex 2's domain.

---

## Non-Negotiable Rules

- Do not change any payout multipliers or hand names — they come from the backend
- Do not add any JS
- Do not create modals, drawers, or slide-in panels for gameplay info
- Do not add sidebars or reflowing secondary panels
- The cabinet must look like one physical machine face at any viewport size
- Keep the retro CRT pixel aesthetic — no gradients on text, no rounded corners on paytable, no generic SaaS styling

---

## Verification Criteria

After your CSS is applied:

1. Portrait screenshot at 540×960 shows all zones in correct vertical order
2. Paytable rows each have correct clone colors
3. CREDIT is green-labeled, STAKE is amber-labeled
4. Machine-info block shows all six sub-elements in correct order
5. FH meter shows black text on white background
6. Win amount shows gold with outline when visible
7. No layout overflow or zone overlap
8. Cabinet does not reflow on desktop viewport
