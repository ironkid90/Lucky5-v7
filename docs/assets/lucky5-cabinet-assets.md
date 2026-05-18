# Lucky5 Cabinet Card and Button Asset Spec

Status: implemented for the web cabinet as generated SVG assets; ready to reuse in Godot as presentation-only sprites.

Source of truth: `docs/LUCKY5_AUTHORITATIVE_GAMEPLAY_REFERENCE.md`. This spec does not change payout tables, RNG, hand evaluation, double-up math, jackpots, settlement, or backend authority.

## Web asset pipeline

- Generator: `src/web/scripts/generate-lucky5-assets.mjs`
- Smoke check: `src/web/scripts/smoke-lucky5-assets.mjs`
- Static output root: `src/web/public/assets/lucky5/cards/`
- Runtime URL root: `/assets/lucky5/cards/`
- Cabinet integration: `src/web/components/lucky5-cabinet.tsx`
- Button normal/pressed states: `src/web/app/globals.css`

Run from `src/web`:

```powershell
npm run assets:smoke
```

The smoke command regenerates the assets and verifies the cabinet references, CSS button-state hooks, and this handoff spec.

## Card deck deliverables

The generated custom 52-card deck uses vector SVG for responsive/retina display while retaining a hard-edged arcade look. The SVGs intentionally use the existing `Lucky5Arcade` font stack so `ARCADE.ttf` remains the cabinet type identity.

Naming convention:

- Faces: `<rank><suit>.svg`
- Ranks: `A K Q J 10 9 8 7 6 5 4 3 2`
- Suits: `S H D C`
- Examples: `AS.svg`, `KS.svg`, `10D.svg`, `5S.svg`
- Back: `bside.svg`
- Held/back variant: `hold-bside.svg`

Visual requirements preserved:

- Warm ivory card face with dark cabinet outline and gold inner rule.
- Red hearts/diamonds and black spades/clubs.
- Large arcade-pip center treatment for quick portrait readability.
- `5S.svg` includes a small `NEVER LOSE` cabinet strip to support the Lucky 5 / 5 spade never-lose visual language.
- `bside.svg` uses a dark blue B-side cabinet back with `LUCKY 5♠` mark.
- Idle card row keeps card backs in slots 1, 2, 4, and 5, while slot 3 renders the rotating Full House rank card.

## Button normal/pressed states

CSS variables on `.apk-btn`, `.apk-hold-btn`, and `.apk-menu-btn-label` define the button asset colors for normal and pressed states. Pressed states are rendered with `:active` and a depressed shadow so the controls read as physical Lebanese retro cabinet buttons rather than modern app buttons.

Required cabinet controls:

| Control | Selector | Normal/pressed color intent |
| --- | --- | --- |
| BET | `.apk-btn-bet` | green, darker green pressed |
| BIG | `.apk-btn-big` | orange/yellow, brown-orange pressed |
| SMALL | `.apk-btn-small` | orange, darker orange pressed |
| CANCEL HOLD | `.apk-btn-cancel` | off-white/cream, tan pressed |
| DEAL DRAW | `.apk-btn-deal` | red, dark red pressed |
| HOLD | `.apk-hold-btn` | yellow/orange, amber pressed |
| TAKE HALF | `.apk-btn-take-half` | red, dark red pressed |
| TAKE SCORE | `.apk-btn-take-score` | yellow/orange, amber pressed |
| MENU | `.apk-menu-btn-label` | black/grey round button, near-black pressed |

Do not replace these with Material, Tailwind utility-only, glassmorphism, or generic casino styling.

## Godot reuse guidance

The current `godot/cabinet/` project is a static baseline, not the live backend-driven cabinet. Reuse these web-generated SVGs in Godot by copying or importing the contents of `src/web/public/assets/lucky5/cards/` into a future Godot asset folder such as `godot/cabinet/skins/lucky5/cards/` when that scene starts consuming card sprites.

Recommended Godot mapping:

- Texture path: `res://skins/lucky5/cards/<rank><suit>.svg`
- Card back: `res://skins/lucky5/cards/bside.svg`
- Held/back variant: `res://skins/lucky5/cards/hold-bside.svg`
- Stretch mode: keep aspect ratio, no filtering if rasterized, pixel snap enabled for cabinet UI.
- Authority boundary: Godot/web render card DTOs from the backend only; clients must not compute hand truth, payout truth, jackpot truth, wallet truth, or double-up state truth.

## Regression checklist

- `cardImgSrc` returns `/assets/lucky5/cards/<code>.svg`, not an empty placeholder.
- Empty card slots render `bside.svg`.
- Rotating Full House idle card stays in slot 3, matching the authoritative reference.
- `KENT /3`, `S/N`, `4 OF A KIND WINS BONUS`, and the double-up `5 ♠ NEVER LOSE` text remain presentation elements only.
- Responsive/retina rendering stays crisp because cards are SVG and `.card-img` avoids global pixelated raster degradation.