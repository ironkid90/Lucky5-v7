# Lucky5-v7 — Full-HD + Mobile / ai9poker Parity Overhaul — Implementation Plan

## 0. What I found (grounding)

I explored the repo, the 4 reference screenshots (committed in repo root), the attached `main.dart.js`, the forensics/protocol docs, the Godot cabinet, and the .NET server. Key conclusion:

**The cabinet is already a mature ai9poker clean-room and structurally/textually matches the screenshots.** Paytable layout, 8 hand rows + rainbow colors, FULL HOUSE white box, "A" rank + full-house pool box, `CREDIT`/`STAKE` block, 3-row wood control deck (HOLD×5 / BIG·SMALL·CANCEL HOLD·DEAL DRAW·BET / TAKE HALF·MENU·TAKE SCORE), `SERIE` / `KENT /3` / jackpot counters / `S/N` / `4 OF A KIND WINS BONUS`, the cyan dot-matrix `LUCKY5 POKER` idle title, and DU texts (`HI LO GAMBLE`, `ACE COUNTS`, `HI OR LO`, `5♠ NEVER LOSE`) all already exist and match `main.dart.js` strings.

So this is **refinement + a real responsiveness change + targeted gameplay/admin/release hardening — NOT a rebuild.**

Verified facts that shape the plan:
- **Paytable is already consistent.** Server `PaytableProfile.Lebanese` (RF×1000, SF×75, 4K×15, FH×12, Fl×10, St×8, 3K×3, 2P×2) == cabinet `hands[]` multipliers == Screenshots 2/3/4 @ STAKE 5000. The cabinet computes amounts as `stake × multiplier` in `_refresh_paytable_values()`.
- **Screenshot 1 (STAKE 10000)** uses a *different* profile (×1000/300/120/20/14/10/6/4 = the live `defaultRules` capture). That is a different machine, not a contradiction. → paytable should become **data-driven** (render server-provided rule multipliers when present, fall back to Lebanese).
- **The single biggest real gap is resolution/responsiveness.** `project.godot` uses `stretch/mode="canvas_items"`, `stretch/aspect="keep"`, base `1080×1920`. On any non-9:16 surface it **letterboxes** (confirmed live: on a 1024-wide window the cabinet is a thin centered strip with huge black side bars). Layout uses fixed `CARD_SIZE`, fixed button heights, fixed font sizes; the only `size_changed` handler (`_update_crt_viewport_size`) just updates a shader param.
- **Admin console already exists** (`_build_admin_screen`): OVERVIEW / AGENTS / USERS / MACHINES / DEVICES / AUDIT tabs, agent create + credit load, user search/detail, machine list/detail, device provision/revoke, audit log, diagnostics.
- **Tooling blocker:** neither `dotnet` nor `godot` is installed on this VM (`node` is). Building the desktop/web exports and running `Lucky5.Tests` requires installing **Godot 4.6.3** + **.NET 9 SDK**. The web cabinet that ships (`src/web/public/godot-cabinet/`) is a prebuilt `.pck`/`.wasm`; any cabinet change must be **re-exported** with Godot or it won't show up on web.

## 1. Decisions I need confirmed (these change the implementation materially)

1. **"Full HD" interpretation.** ai9poker is portrait-only; on desktop it runs in a portrait window (Screenshot 1) and even letterboxes. My plan keeps the **portrait cabinet, scaled crisply to fill the available height, centered with authentic side panels on wide screens** (true to ai9poker + AGENTS.md "preserve retro cabinet feel, portrait-first"). I will *not* convert it to a landscape layout. → Confirm this is what you want, or tell me you want a true landscape relayout.
2. **Paytable multipliers.** Keep the **Lebanese profile** (matches 3 of 4 screenshots) as the canonical default, and make rendering data-driven so a machine that sends different rules (like Screenshot 1) displays correctly. → Confirm, or tell me to globally switch to the Screenshot-1 profile.
3. **Tooling install.** I'll install Godot 4.6.3 + .NET 9 SDK on this VM so I can build, **re-export the web cabinet**, and run tests. It's a sizeable download but required for a real "release playstate". → OK to proceed?

I'll start implementing the parts that don't depend on these answers, but these three gate the big strokes.

## 2. Symbols to modify — in control/data-flow order

### A. Resolution / full-HD + mobile responsiveness (highest priority)

**`godot/cabinet/project.godot`** — `[display]` / `[rendering]`
```ini
; change letterbox -> fill, keep portrait design res, add an expand axis so tall
; phones and full-HD portrait both fill without pillarboxing.
[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/window_width_override=600     ; friendlier desktop window default
window/size/window_height_override=1067
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"            ; was "keep" (the letterbox cause)
window/stretch/scale_mode="fractional"    ; crisp scaling on HD
```

**`cabinet_root.gd :: _ready()`** (~319) — keep `get_viewport().size_changed.connect(...)`, additionally connect the new responsive handler.
```gdscript
# connect responsive relayout in addition to the CRT param update
get_viewport().size_changed.connect(_apply_responsive_metrics)
```

**`cabinet_root.gd :: _apply_responsive_metrics() -> void`** (NEW, called from `_ready` + on `size_changed`)
```gdscript
# Compute a UI scale from actual viewport vs the 1080x1920 baseline, clamp it,
# and push derived sizes into cards, control-deck buttons, fonts, separations and
# the centered max-width so: full-HD scales up crisply, tall phones fill, and
# ultra-wide is centered with side panels (no stretch). Drives B-section metrics.
func _apply_responsive_metrics() -> void
```

**`cabinet_root.gd :: _build_ui()`** (~800) — wrap `cabinet_layout` in a width-clamped CenterContainer so on wide/HD screens the portrait column is centered (authentic side panels) instead of stretched; feed `_apply_responsive_metrics()` the real rect. The three stretch ratios (1.5 / 3.0 / 2.5) stay.

**Card / button / font sizing** — convert the fixed constants consumed by `_build_card_area` (~1344), `_build_control_deck` (~938), `_make_button` (~598), `_make_label` (~587) to read from scale-derived runtime vars set in `_apply_responsive_metrics()` (baseline values unchanged at scale 1.0): `CARD_SIZE`, `CONTROL_HOLD_BUTTON_HEIGHT`, `CONTROL_ACTION_BUTTON_HEIGHT`, `CONTROL_BOTTOM_BUTTON_HEIGHT`, paytable/credit/title font sizes.

**Web/mobile surface**
- `godot/cabinet/export_presets.cfg` (Web preset): set `progressive_web_app/ensure_cross_origin_isolation_headers=true`; keep `canvas_resize_policy=2`, `orientation=2` (portrait).
- `src/web/app/globals.css :: .godot-web-frame` (~84): already `100dvh`; add `width:100vw`, `viewport-fit: cover`, safe-area insets, and `background:#060606` letterbox so mobile notches look intentional.
- Verify `netlify.toml` / `src/web/public/_headers` send `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` for the embed (required for Godot threads/SharedArrayBuffer). Add if missing.

### B. Paytable / UI / graphics parity (data-driven + color/style polish)

**`cabinet_root.gd :: _build_paytable(parent)`** (~1194) — keep the 8-row grid; replace the hardcoded multiplier in `hands[]` (1227-1234) with a lookup that prefers server rules.
```gdscript
# hands[] keeps name+color; multiplier now sourced via _paytable_multiplier(key)
# so server-provided machine rules win, Lebanese profile is the fallback.
```

**`cabinet_root.gd :: _paytable_multiplier(key: String) -> int`** (NEW)
```gdscript
# return store rule multiplier for hand key if the snapshot carries paytable
# rules, else the Lebanese default (1000/75/15/12/10/8/3/2).
func _paytable_multiplier(key: String) -> int
```

**`cabinet_root.gd :: _refresh_paytable_values()`** (~3202) — already does `stake × multiplier`; switch the multiplier source to `_paytable_multiplier(key)` and re-verify color overrides match the screenshots (RF gold, SF red, 4K green, FH black-on-white box, Fl gold, St cyan, 3K gold, 2P cyan).

**Server side (only if data-driven paytable is confirmed):** `GameService` cabinet snapshot/`ActiveRoundStateDto`/`CabinetContractsDto` — include the active machine's payout multipliers so the cabinet can render any machine's table (Screenshot 1 included). Falls back gracefully when absent.

**Button / idle-title / machine-info fidelity pass** in `_build_control_deck` (~938), `_make_button` (~598), idle title (`IDLE_TITLE_TEXT`), `_build_machine_info` (~1432): confirm gloss gradients, rounded-top HOLD caps, exact color hexes from `docs/GAME_FEEL_REFERENCE.md`, and the cyan dot-matrix `LUCKY5 POKER` rendering match the screenshots at the new scales.

### C. Gameplay parity referencing main.dart.js (server is authority)

Cross-check the CleanRoom engine + DTOs against the documented live contract (`docs/forensics/live_protocol_2026-05-02.md`) and close gaps that affect play parity:
- **`server/.../CleanRoom/FiveCardDrawEngine.cs`** — single `Deal` semantics (fresh deal vs draw via `dealCount`), hold mask handling.
- **`server/.../CleanRoom/Lucky5DoubleUpEngine.cs`** (~74-84) — switch-only Lucky5 (4× first / 2× repeat, 5♠ never-lose), `aceCard`/`aceMultiplier`, BIG≥8 / SMALL≤6 / 7 push, door open/close percentage.
- **DTOs** `DealResultDto`, `DoubleUpResultDto`, `ActiveRoundStateDto`, `CabinetContractsDto` — surface fields the cabinet reads: `kentRounds`, `inDoubleUp`, `doubleUpCard`, `fullHouseBonus`, `currentCarre1/2`, `currentFullHouse`, `currentKent`, `carreIndex`, `freeGameCount`, `wasFreeGameRound`, `aceCard`, `aceMultiplier`.
- **`cabinet_root.gd`** consumers: `_refresh_du_panel` (~2528), `_refresh_jackpots` (~2993), `_refresh_bonus_stage` (~3069), `_send_double_up_guess` (~4287) — bind any newly surfaced fields.

(Exact list of fields to add will be finalized after a focused diff of the engine vs the forensics doc; I'll report the concrete deltas before touching server logic, since AGENTS.md makes `docs/` the source of truth and warns against changing deterministic logic casually.)

### D. Admin parity upgrade

**`cabinet_root.gd :: _build_admin_screen`** (~1568) + machine-detail handlers (`_on_admin_machines` / `_refresh_admin_*` 3756-4011): extend the **machine detail panel** to view/edit the ai9poker machine-config fields from the forensics capture that aren't editable yet: `OpenedDoubleUpPercentage` / `ClosedDoubleUpPercentage`, pool Min/Max/Current for StraightFlush/Carre1/Carre2/FullHouse/Kent, `DoubleUpLimit`, `FullHouseCardID`, `CarreIndex`, recharge tiers. Mirror with server admin DTO/controller fields as needed. Keep existing tabs intact.

### E. Release playstate

- Re-export web cabinet via `scripts/godot/Export-GodotWebCabinet.ps1` (needs Godot) → refresh `src/web/public/godot-cabinet/`.
- Build `server/Lucky5.sln`; run `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`.
- Godot smoke: `scripts/godot/Test-GodotCabinet.ps1`.
- `web`: `npm run lint` / `typecheck` / `build` in `src/web`.

## 3. Verification
- Local: serve re-exported export (node COOP/COEP server already set up) and visually diff against the 4 screenshots at desktop full-HD portrait and emulated mobile widths (DevTools device toolbar). Screen-record the golden path.
- CI: open PR, wait for checks, address failures (compare against base if any look pre-existing).

## 4. Order of execution
1. (gate) Confirm §1 decisions + install Godot/.NET.
2. Branch `devin/<ts>-fullhd-mobile-ai9-parity`.
3. A: responsiveness (biggest visible win) → re-export → verify on wide + mobile widths.
4. B: data-driven paytable + style fidelity pass → re-export → screenshot diff.
5. C: gameplay parity deltas (report concrete diff first).
6. D: admin machine-config fields.
7. E: exports + tests + lint, PR, CI, env blueprint, offer end-to-end test recording.


Notes: Got it — all three gates confirmed and the strict visual overrides noted. Proceeding now.

Locked in:

Full-HD: portrait-first, scale crisply to fill height, centered with pure-black pillarbox side panels on wide/desktop. No landscape relayout.
Paytable: data-driven from server machine rules, Lebanese profile as fallback.
Tooling/Runtime: NOT .NET 9 — I'll upgrade the whole solution to .NET 10 (all .csproj, global.json, build scripts, Dockerfiles, CI, docs) and install Godot 4.6.3 + .NET 10 SDK.
Aggressive visual overrides (not just polish): pitch-black (#000000) top/middle, thick dot-matrix font, exact high-contrast paytable colors (RF #FFFF00, SF #FF0000, 4K #00FF00, FH black-on-#FFFFFF, Fl #FFFF00, St #00FFFF, 3K #FFFF00, 2P #00FFFF), CREDIT green / STAKE yellow with massive numbers, pure-white cards, cyan blocky "LUCKY5 / POKER" title (POKER offset right), yellow+white marquee, warmer woodgrain, 3D-bevel StyleBoxFlat buttons with the exact button hexes and black text, MENU = black circle + 3 white lines.
Execution order: .NET 10 upgrade + tooling install first (gate), then responsiveness, then the visual overrides, then gameplay/admin parity, then export/tests/PR. Starting with the .NET 10 upgrade survey and kicking off the Godot + .NET 10 installs in parallel.



3:30
Worked for 26m 28s
+55
−36
Progress: .NET 10 upgrade is green, and I've applied the aggressive visual overrides to the Godot cabinet — exact paytable hexes (RF #FFFF00, SF #FF0000, 4K #00FF00, FH yellow-on-white, Fl #FFFF00, St/2P #00FFFF), pitch-black top/middle, thicker outlined font, bigger/denser paytable, CREDIT(green)+STAKE(yellow) big numbers, 3D-bevel StyleBoxFlat buttons with your exact button colors + black text, MENU black circle, pure-cyan LUCKY5/POKER title, warmer woodgrain, and CRT filter neutralized. The full regression suite passes (including the HOLD-button fix). Next: regenerate the playing cards to pure-white classic, then responsiveness + data-driven paytable, then re-export and open the PR.