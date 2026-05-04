# Lucky5 Godot Cabinet Phase 0 Discovery

Status: Phase 0 Production Edition complete for documentation and contract
definition before implementation-heavy Godot work.

Last source audit: 2026-05-04.

Scope: this document catalogs the current web cabinet and defines the JSON-first
contracts Godot should target. It does not authorize any change to payout tables,
RNG, hand evaluation, double-up math, RTP, jackpot math, or machine rules.

## Source Of Truth

`server/src/Lucky5.Api/wwwroot` is the visual source of truth for the current
playable cabinet.

Evidence:

- `server/src/Lucky5.Api/Program.cs` serves default files and static files before
  mapping controllers and `CarrePokerGameHub`.
- `server/src/Lucky5.Api/wwwroot/index.html` is the current cabinet entry point
  and loads the cabinet CSS, JS, image, font, and audio assets.
- `docs/GAME_FEEL_REFERENCE.md` describes the same Lebanese arcade cabinet target
  and reinforces that the web cabinet is the playable visual reference.
- The current read-only inventory was reproduced with `tmp/phase0_inventory.py`;
  captured output for this audit is `tmp/phase0_inventory_output.txt`.

Godot must reproduce the player-facing cabinet feel from this directory first,
then consume JSON contracts from the backend. It must not couple to DOM IDs,
CSS selectors, or backend C# type names.

The durable Phase 0 contract package is this directory:
`docs/contracts/godot-cabinet/`. Any older or transitional schema copy outside
`docs/` is not the source of truth for Godot implementation decisions unless it
is explicitly reconciled back into this package.

## Frontend Version Catalog

This repository contains several Lucky5 frontend generations and mirrors. Phase 0
uses them for discovery only; it does not select a new runtime implementation or
add gameplay.

| Surface | Path | Stack / version evidence | Current role for Godot migration |
| --- | --- | --- | --- |
| Web cabinet visual oracle | `server/src/Lucky5.Api/wwwroot` | Static ASP.NET-hosted HTML/CSS/JS served by `Program.cs`; `index.html` loads `game.css?v=17`, vnext cabinet CSS `?v=2`, v8 CSS `?v=3`/`?v=5`, SignalR CDN, `game-config.js?v=5`, and `game.js?v=24`. Asset count from audit: 1 HTML, 8 CSS, 14 JS, 89 PNG, 1 TTF, 1 MP3. | Canonical playable visual reference. Godot must reproduce this cabinet feel first. |
| Capacitor Android web mirror | `mobile/www` plus `mobile/android` | `mobile/package.json` names `lucky5-mobile` `0.1.0` with Capacitor `^8.2.0`; `mobile/www` is a copied web bundle with 1 HTML, 6 CSS, 6 JS, 89 PNG, 1 MP3. | Packaging/mirror reference only. Not the visual oracle because it can lag `wwwroot` and currently has fewer v8/cabinet JS/CSS files. |
| Next/React web prototype | `src/web` | `src/web/package.json` names `lucky5-web` `0.1.0`, Next `15.3.0`, React `^19.0.0`; key files include `components/lucky5-cabinet.tsx`, `app/globals.css`, `lib/api.ts`, and `models/DoubleUpViewModel.ts`. | Historical/prototype frontend. Useful for UI ideas and TS API typing only; do not treat as cabinet oracle. |
| Flutter client | `client` | `client/pubspec.yaml` names `lucky5_client` `0.1.0+1`, Dart SDK `>=3.4.0 <4.0.0`, `http`, `signalr_netcore`, Firebase, notifications, wakelock. | Mobile/client reference for API models and SignalR usage. Not a replacement for the web cabinet oracle. |
| Active Godot cabinet project | `godot/cabinet` | Godot project `config_version=5`, project name `Lucky5 Cabinet`, feature `4.6`, main scene `res://scenes/CabinetRoot.tscn`, viewport `720x1280`, renderer `mobile`; contains fixture `classic_snapshot.json` and GDScript cabinet scripts. | Target migration project. Current behavior is a presentation slice/fixture path, not authoritative gameplay. |
| Earlier Godot scratch project | `lucky-5-v-7-godot` | Godot project `Lucky5-v7-Godot`, feature `4.6`, plugin `godot_symbol_search`, minimal files. | Scratch/reference only; do not build new migration work here unless explicitly reassigned. |
| Double-up remediation artifact | `lucky5-doubleup-remediation` | Contains `double-up-remediation.diff`, memory notes, and a partial `src/web` tree. | Forensic/remediation context only. Do not treat as current frontend. |
| AI9Poker extracted APK reference | `ai9poker` | Decompiled APK/export with `root/assets/flutter_assets`, Android resources, smali, libapp bundles, and extracted images/fonts/sound. | Asset and protocol reference only. Do not copy gameplay logic, payout, RNG, hand evaluation, or settlement behavior. |

Frontend routing decisions:

- `server/src/Lucky5.Api/wwwroot` is the only Phase 0 visual oracle.
- `mobile/www` can confirm asset parity and provides a repaired `10C.png`, but
  it is a mirror rather than the canonical source.
- `ai9poker/root/assets/flutter_assets/assets` can fill missing asset evidence
  and inspire presentation affordances, but Lucky5 contract names and backend
  authority rules win over AI9Poker runtime names.
- `src/web`, `client`, and both Godot projects are implementation references,
  not sources of game truth.

## Player-Facing Surface Catalog

### Screens

| Screen | Current source | Godot requirement |
| --- | --- | --- |
| Asset loader | `#asset-loader` in `index.html`, loader logic in `game.js` and `cabinet-image-cache.js` | Preserve Lucky5 loading title, progress bar, blocking preload behavior, and error fallback. |
| Auth | `#auth-screen` in `index.html` | Preserve login/signup toggle, Lucky5 cabinet identity, auth error line, and token-backed session entry. |
| Lobby | `#lobby-screen` in `index.html` | Preserve credit display, game cards, machine availability, bonus banner, wallet summary, user display, logout, and bottom nav. |
| Wallet | `#wallet-screen` in `index.html` | Preserve balance summary, current disabled deposit/withdraw affordances, transaction empty state, and error state. |
| Admin | `#admin-screen` in `index.html` | Preserve admin-only player search, player credit action, machine list, RTP display, and reset action if Godot exposes admin tools. |
| Game cabinet | `#game-screen` in `index.html` and cabinet CSS/JS | Primary Godot target. Preserve portrait cabinet layout, paytable, cards, jackpot meters, machine labels, control deck, messages, and pacing. |
| Menu overlay | `#menu-panel` in `index.html` | Preserve cash in, cash out, back to lobby, reset machine, logout, and close actions. |

### Game States And Recovery States

| State | Current behavior | Godot requirement |
| --- | --- | --- |
| Idle | Shows credit/stake, paytable, cards/backing, machine info, `INSERT COIN`, `PRESS DEAL`, `PLACE YOUR BET`, or `CASH IN FROM MENU`; idle title overlay appears after a delay. | Preserve attract and idle cadence. Buttons reflect backend snapshot, not local guesses. |
| Cash in | Menu prompt asks for amount and posts `cash-in`; session credit display updates. | Replace prompt with cabinet-native amount control backed by JSON command. |
| Cash out | Menu posts `cash-out`; success shows `CASHED OUT - MACHINE READY`; blocked states show backend error. | Use backend command result and recovery overlay if session closes mid-round. |
| Deal | Posts deal, animates dealing, displays advised holds and `AUTO-HOLD SUGGESTED - DRAW OR ADJUST`. | Keep deal pacing and require server state before enabling draw/hold controls. |
| Hold | Hold buttons toggle local `holdIndexes`; badges show held/cancel state. | Current hold is local-only until draw. Godot contract includes optional server-visible hold commands for authoritative state. |
| Bet / jackpot selector | BET cycles stake locally in 100-credit steps between machine min/max. Idle BET also fire-and-forget cycles the Full House jackpot rank; HOLD[0] can cycle that rank when the idle selector is armed. | Godot must not keep this as an unsynchronized side effect. Use explicit `bet_change` and `jackpot_rank_change` commands, or a combined backend command if Phase 1 chooses that surface. |
| Draw | Posts draw with held indexes, animates replacement cards, then shows hand result or `NO WIN`. | Keep draw pacing and result timing. |
| Win | Shows win amount and `TAKE SCORE`, `TAKE HALF`, or `DOUBLE UP` prompts depending on backend state. | Server snapshot drives available buttons and pending win. |
| Double-up | Shows dealer card, Big/Small controls, switching, Lucky5 no-lose messaging, card trail, and take options. | Server owns current amount, card trail, switch count, lucky state, and terminal result. |
| Machine closed | Displays close and cash-out messages such as `MACHINE CLOSED - TAKE SCORE THEN CASH OUT FROM MENU`. | Godot must not allow new gameplay commands while the session is closed or cash-out recovery is pending. |
| Active round recovery | `GET /api/Game/machine/{id}/active-round` restores a dealt, drawn, or double-up round after refresh. | Reconnect must hydrate from snapshot or replay before controls are enabled. |
| Error | Web writes errors to auth, wallet/admin sections, or `#game-message`; hub `Error` is console-only today. | Godot needs a visible cabinet error/recovery overlay for transport, stale state, and command rejection. |
| Offline/reconnect | No dedicated blocking offline overlay exists in the web cabinet. SignalR reconnect rejoins the machine; REST commands may still be attempted. | Godot must show a blocking recovery overlay, disable gameplay commands, and reconcile by sequence/state before resuming. |

### Cabinet State Machine Inventory

These states are the required Godot-facing inventory of cabinet states discovered
from the web oracle, current backend surfaces, and the contract needs above.

| State | Entry evidence | Allowed player input | Exit condition |
| --- | --- | --- | --- |
| `boot_loading` | `#asset-loader`, `cabinet-image-cache.js`, static asset preload. | None except app/system back if supported. | Required assets and first runtime config are loaded, or `asset_load_error`. |
| `asset_load_error` | Loader failure text in `#loader-text`. | Retry/close only. | Retry succeeds or player exits. |
| `auth_login` | `#auth-screen`, `doLogin`. | Username/password, signup toggle. | Login token/profile accepted, then lobby bootstrap. |
| `auth_signup` | Auth toggle, `doSignup`, hard-coded web OTP compatibility path. | Username/password/signup flow. | Signup plus OTP verification compatibility completes, then login/lobby; real onboarding should replace hard-coded OTP. |
| `lobby_loading` | `loadAvailableMachines()`, reward/profile refresh. | Logout/back only; machine cards disabled while stale. | Machine list/profile/reward data rendered or recoverable error shown. |
| `lobby_ready` | `#lobby-screen` with machine grid and wallet summary. | Select open machine, wallet, admin if role allows, reward claim, logout. | Machine selected, wallet/admin opened, logout, or transport recovery. |
| `wallet` | `#wallet-screen`, `MemberHistory`. | Back to lobby; deposit/withdraw currently disabled. | Back to lobby or auth/recovery failure. |
| `admin` | `#admin-screen`, admin users/machines APIs. | Search/refresh/users credit/reset where role allows. | Back to lobby or auth/recovery failure. |
| `machine_joining` | Web invokes hub `JoinMachine(machineId)` then `initGame`. | Mutating cabinet controls disabled. | Join/snapshot/session fetch succeeds, or join error/recovery. |
| `idle_no_session` | Web messages like `CASH IN FROM MENU`. | Menu, cash in, bet selector only if backend permits. | Cash-in/session fetch creates machine session. |
| `idle_ready` | Cards/backing, paytable, credit/stake, `PRESS DEAL` or `PLACE YOUR BET`. | Deal, bet change, jackpot rank change, menu/cash-out if safe. | Deal accepted, cash-out/menu action, disconnect, or error. |
| `cash_in_pending` | Menu prompt posts `machine/{id}/cash-in`. | No additional mutating command; amount dialog can cancel before submit. | Session response applied or error shown. |
| `cash_out_pending` | Menu posts `machine/{id}/cash-out`. | No gameplay controls. | Session response applied; if unresolved round exists, command rejected and snapshot/recovery required. |
| `deal_pending` | `Deal` REST/hub command. | No gameplay controls; cosmetic deal anticipation only. | Deal result/snapshot arrives, or timeout enters recovery. |
| `dealt_hold_select` | Dealt cards with advised holds, local `holdIndexes`. | Hold/cancel hold/draw/menu only as backend `buttons` allow. | Draw accepted, clear/cancel holds, recovery, or command rejection. |
| `draw_pending` | `Draw` REST/hub command with held indexes. | No gameplay controls. | Draw result/snapshot arrives. |
| `draw_result_loss` | `NO WIN` and post-loss idle title delay. | None until backend buttons re-enable idle controls. | Idle snapshot/render delay completes. |
| `draw_result_win` | Win amount, paytable highlight, double-up availability. | Take score, take half, double-up start, menu if safe. | Double-up starts, win collected, or recovery. |
| `double_up_start_pending` | `double-up/start`. | No double-up choices yet. | Dealer card/current amount returned. |
| `double_up_choice` | Dealer card plus Big/Small/Switch/Take controls. | Big, Small, Switch, Take Half, Take Score as backend permits. | Guess/switch/take command accepted. |
| `double_up_reveal_pending` | Guess sent, reveal pacing active. | No double-up choices while locked. | Result event/snapshot arrives. |
| `double_up_win` | Status `Win`, current amount, trail update. | Continue choice after backend/presentation delay, take options. | Next choice, take score/half, machine close, or recovery. |
| `double_up_lucky5_safe` | `Lucky5`, `SafeFail`, `isNoLoseActive`, flash banner. | Continue/take options only after backend state is applied. | Next double-up state or collection. |
| `double_up_loss` | Status `Lose`, drain/exit delay. | None until backend returns idle buttons. | Idle snapshot/render delay completes. |
| `take_half_pending` | `double-up/take-half`. | No double-up/game controls. | Remaining win applied; return to win/double-up choice or idle. |
| `take_score_pending` | `double-up/cashout`. | No gameplay controls. | Credits/session applied; if machine closes, transition through machine closed/cash-out. |
| `machine_closed` | Status `MachineClosed`, close messages, cash-out attempt. | New gameplay disabled; cash-out/recovery only. | Cash-out/session cleanup completes or recovery. |
| `menu_overlay` | `#menu-panel`. | Non-mutating close/back; mutating entries gated by state and backend. | Close menu or command submitted. |
| `notification_notice` | Firebase foreground banner/bonus notices. | Acknowledge/claim depending notice. | Notice dismissed or claim result applied. |
| `command_rejected` | HTTP bad request or hub `Error`. | Retry only when backend marks retryable; otherwise snapshot recovery. | Snapshot applied, auth restored, or fatal error. |
| `offline` | Transport unavailable before first connection or after hard loss. | Gameplay disabled; logout/back if non-mutating. | Authenticated reconnect starts. |
| `reconnecting` | SignalR automatic reconnect or Godot connection state. | Gameplay disabled. | `reconnect_sync` plus replay/snapshot completes, or `recovery_required`. |
| `recovery_required` | Sequence gap, stale command, heartbeat timeout, lost command result. | Gameplay disabled; blocking overlay. | Full snapshot or replay applied and authoritative buttons available. |
| `fatal_error` | Unrecoverable auth/config/schema mismatch. | Logout/restart/support only. | New session/app restart. |

### Overlays, Modals, And Notices

- Asset loader overlay with Lucky5 title, progress bar, loading text, and failure
  text.
- Idle title overlay inside the card area after idle delay.
- Lucky5 flash banner for double-up no-lose/Lucky5 moments.
- Bonus banner and bonus result text.
- Menu panel overlay with machine/session commands.
- Browser `prompt`, `confirm`, and `alert` calls for cash-in, reset, logout, and
  error acknowledgment. These must become Godot-native JSON command flows.
- Firebase notification foreground banner in the web DOM.
- CRT/frame/shine overlays from cabinet CSS and v8 effects.
- No current web-only full offline or reconnect overlay. Godot must add this as
  part of the contract-compliant recovery flow.

### Pacing Cues

Current pacing values come from `server/src/Lucky5.Api/wwwroot/game-config.js`.
Godot should preserve the feel unless a variant presentation profile overrides it.

| Cue | Current value |
| --- | --- |
| Deal base delay | 50 ms |
| Deal stagger | 90 ms |
| Deal animation | 180 ms |
| Draw out | 55 ms |
| Draw in | 75 ms |
| Draw stagger | 45 ms |
| Draw reveal start | 50 ms |
| Shuffle frame | 90 ms |
| Double-up reveal delay | 120 ms |
| Double-up win hold | 550 ms |
| Double-up stagger per card | 65 ms |
| Count-up duration | 1400-3500 ms |
| Credit tick | 90 ms |
| Jackpot fill | 2800-5500 ms |
| Jackpot drain delay | 700 ms |
| Double-up loss exit | 750 ms |
| Lucky5 catch exit | 1000 ms |
| Lucky5 flash | 500 ms |
| Lucky5 active screen | 1300 ms |
| Draw result delay | 350 ms |
| Win to double-up prompt | 400 ms |
| Post-loss idle title | 1400 ms |
| Take-half continue | 550 ms |
| Idle overlay appear | 2200 ms |
| Idle attract mode | 12000 ms |

### Visual Identity And Assets

Godot must preserve the Lebanese arcade cabinet identity, not modernize the game
into a generic casino UI.

Layout:

- Portrait cabinet, target `720x1280`, scaled from `--game-width` and
  `--game-height`.
- Zones: paytable and credit header, Lucky5 label, card row, win area, machine
  info, and large control deck.
- Five-card row with card backs from `assets/images/cards/bside.png`.
- Machine info block with `SERIE`, `KENT /3`, and `S/N`.
- Jackpot counters for `4K-A`, `SF`, and `4K-B`, plus full-house jackpot and rank.

Buttons:

| Control | Current asset or style | Identity rule |
| --- | --- | --- |
| HOLD | `hold_off.png`, `hold_on.png` | Amber arcade hold button, one per card. |
| CANCEL HOLD | `cancel_hold.png`, `cancel_hold_on.png` | Cream/beige cancel button. |
| DEAL/DRAW | `deal_draw.png`, `deal_draw_on.png` | Red primary action button. |
| BET | `bet.png`, `bet_on.png` | Green stake button. |
| BIG | `big.png`, `big_on.png` | Amber double-up high choice. |
| SMALL | `small.png`, `small_on.png` | Amber double-up low choice. |
| TAKE HALF | `take_half.png`, `take_half_on.png` | Red take-half action. |
| TAKE SCORE | `take_score.png`, `take_score_on.png` | Orange/amber collect action. |
| MENU | CSS dark circular button | Dark cabinet utility button. |

Color cues:

| Use | Color |
| --- | --- |
| Credit label | `#00ff44` |
| Stake label | `#ffcc00` |
| Value text | `#ffffff` |
| Royal flush | `#ff4444` |
| Straight flush | `#ff8800` |
| Four of a kind | `#44ffcc` |
| Full house | `#ffff00` |
| Flush | `#ff6666` |
| Straight | `#44ff88` |
| Three of a kind | `#44ddff` |
| Two pair | `#ddddaa` |
| Machine info | `#44ff88` |
| Straight-flush jackpot | `#ff4444` |
| Active jackpot outline | `#ffcc00` |

Cabinet chrome/wood/black framing, CRT glow, scanlines, reflections, and
pressed-button image swaps are part of the identity, not optional decoration.

Asset inventory:

- Font: `assets/fonts/ARCADE.ttf`.
- Cabinet/logo images: `lucky5.png`, `splash.png`, `board.png`, `coin.png`.
- Button images in `assets/images/` and duplicate copies under
  `assets/images/buttons/`.
- Card images under `assets/images/cards/` for card codes and `bside.png`.
- Sound: `assets/sounds/press.mp3`.

### Production Asset Catalog And Decisions

Inventory evidence from the 2026-05-04 audit:

- `server/src/Lucky5.Api/wwwroot/assets`: 1 font, 89 PNG files, 1 MP3.
- `ai9poker/root/assets/flutter_assets/assets`: exported Flutter asset root with
  Lucky5-compatible images, card sheets/files, fonts, `press.mp3`, and additional
  UI artwork. Count: 96 PNG, 30 SVG, 3 GIF, 7 TTF, 1 MP3, and one `.gitkeep`.
- `mobile/www/assets`: web mirror with 89 PNG files and `press.mp3`; unlike the
  current `wwwroot` oracle, its card set contains a non-zero `10C.png`.
- Full APK extraction `ai9poker`: 339 PNG, 30 SVG, 10 WEBP, 3 GIF, 8 TTF, 1 OTF,
  1 MP3, plus Android framework resources and compiled bundles. Android system
  drawables/resources are not Lucky5 cabinet assets.
- Only zero-byte Lucky5 cabinet asset found in the visual oracle is
  `server/src/Lucky5.Api/wwwroot/assets/images/cards/10C.png`. The full APK
  extraction also has zero-byte `ai9poker.gpr` and the Flutter asset `.gitkeep`,
  which are not cabinet runtime assets.

Preferred asset decisions:

| Asset group | Preferred source | Preferred files | Decision and rationale |
| --- | --- | --- | --- |
| Card fronts | `server/src/Lucky5.Api/wwwroot/assets/images/cards` except `10C.png` | 52 current non-zero card fronts, dimensions `313x528`. | Use current web oracle card art for parity. Repair `10C.png` from `mobile/www/assets/images/cards/10C.png` or `ai9poker/root/assets/flutter_assets/assets/images/cards/10C.png`, both non-zero `313x528`, before Godot import validation. |
| Card back | `server/src/Lucky5.Api/wwwroot/assets/images/cards/bside.png` | `bside.png`, `313x528`, 280967 bytes. | Canonical current card back. APK and mobile copies match; keep web oracle as source path. |
| Optional hold card back | `ai9poker/root/assets/flutter_assets/assets/images/holdbside.png` | `holdbside.png`, 661817 bytes. | Useful reference for an explicit held-card presentation, but not preferred for Phase 0 because the web oracle uses badges/button state over a separate held card back. |
| Button deck | `server/src/Lucky5.Api/wwwroot/assets/images` | `hold_off/on`, `cancel_hold/_on`, `deal_draw/_on`, `bet/_on`, `big/_on`, `small/_on`, `take_half/_on`, `take_score/_on`, all `1024x1536`. | Preferred. These are the large retro cabinet buttons visible in the web oracle. Duplicate `assets/images/buttons/*` copies are byte/dimension matches and may be used for organized import if the manifest points back to the oracle. |
| Menu button | Web CSS plus optional APK icon reference | CSS dark circular menu button; APK `images/menu.png` is 1890 bytes. | Prefer reproducing the CSS dark utility button in Godot. APK `menu.png` is a small icon reference, not the oracle control. |
| Cabinet board/background | `server/src/Lucky5.Api/wwwroot/assets/images/board.png` plus CSS chrome | `board.png`, `1024x1024`; cabinet frame/CRT/shine from CSS. | Preferred for board texture. Godot must also port CSS chrome/wood/black frame, CRT glow, scanlines, reflections, and v8 quality effects as presentation materials/shaders. |
| Splash/logo | `server/src/Lucky5.Api/wwwroot/assets/images` | `splash.png` `390x844`, `lucky5.png` `313x528`, `coin.png` `1024x1024`. | Preferred for loader, lobby, favicon/coin, and cabinet branding. APK/mobile copies can verify parity but are not authoritative. |
| Lobby/support wallet artwork | `ai9poker/root/assets/flutter_assets/assets/images` | `machine2.png`, `machine21.png`, `treasurecoins.gif`, `treasureempty.gif`, `img_wallet.png`, `img_currency_bag*.png`, `img_support*.svg`, `whatsapp.svg`. | Reference only. These can inspire future lobby/wallet polish, but Phase 0 keeps the web cabinet and existing lobby shell as oracle. Do not import as required Godot gameplay assets yet. |
| Suit vector icons | `ai9poker/root/assets/flutter_assets/assets/images` | `club.svg`, `diamond.svg`, `heart.svg`, `spade.svg`. | Reference only. Current card fronts are raster PNG and should remain preferred. Vectors may help debug/placeholders but are not a source of card truth. |
| Fonts | `server/src/Lucky5.Api/wwwroot/assets/fonts/ARCADE.ttf`; optional browser font from Google `Press Start 2P`; APK reference fonts | `ARCADE.ttf` 27700 bytes; APK also has `Impact.ttf`, Inter family, Material Icons, LineAwesome. | Preferred cabinet font is `ARCADE.ttf` plus web CSS fallback behavior. Inter/Impact/Material icons are UI/reference fonts only and should not replace the retro cabinet identity. |
| Sound | `server/src/Lucky5.Api/wwwroot/assets/sounds/press.mp3` | `press.mp3`, 6144 bytes. | Preferred and only approved sound today. APK copy matches path/content role. Missing named event sounds remain a gap; do not synthesize or invent them. |

Card set audit:

| Source | Card PNG count | Zero-byte files | Missing expected files | Decision |
| --- | ---: | --- | --- | --- |
| `server/src/Lucky5.Api/wwwroot/assets/images/cards` | 53 | `10C.png` | none | Preferred set after repairing `10C.png`. |
| `ai9poker/root/assets/flutter_assets/assets/images/cards` | 53 | none | none | Approved candidate source for the `10C.png` repair and parity comparison. |
| `mobile/www/assets/images/cards` | 53 | none | none | Also approved candidate source for the `10C.png` repair because it mirrors Lucky5 assets and has the non-zero file. |

APK asset notes:

- The exported Flutter root includes top-level `images/ACX.png`, `ADX.png`,
  `AHX.png`, and `ASX.png` plus `bonus.png`/`free.png`. These appear to be
  presentation or special-card variants, not replacements for the canonical
  `cards/` deck.
- Android `resources/package_1/res/drawable-*` contains framework icons,
  notification backgrounds, Google sign-in images, and app shell drawables. Do
  not treat these as Lucky5 cabinet assets unless a later task proves a direct
  cabinet use.
- `ai9poker` compiled bundles and smali are reference/forensic material only;
  no game logic or math should be ported from them.

Card asset catalog:

- Back: `bside.png`.
- Clubs: `2C.png`, `3C.png`, `4C.png`, `5C.png`, `6C.png`, `7C.png`,
  `8C.png`, `9C.png`, `10C.png`, `JC.png`, `QC.png`, `KC.png`, `AC.png`.
- Diamonds: `2D.png`, `3D.png`, `4D.png`, `5D.png`, `6D.png`, `7D.png`,
  `8D.png`, `9D.png`, `10D.png`, `JD.png`, `QD.png`, `KD.png`, `AD.png`.
- Hearts: `2H.png`, `3H.png`, `4H.png`, `5H.png`, `6H.png`, `7H.png`,
  `8H.png`, `9H.png`, `10H.png`, `JH.png`, `QH.png`, `KH.png`, `AH.png`.
- Spades: `2S.png`, `3S.png`, `4S.png`, `5S.png`, `6S.png`, `7S.png`,
  `8S.png`, `9S.png`, `10S.png`, `JS.png`, `QS.png`, `KS.png`, `AS.png`.

Known asset risks:

- `assets/images/cards/10C.png` is currently zero bytes and should be repaired
  before Godot asset import is treated as complete.
- `assets/sounds/press.mp3` is the only sound file present. `game-config.js`
  falls back to it for core events, but `cabinet-audio-vnext.js` references
  missing event-specific files: `deal.mp3`, `draw.mp3`, `collect.mp3`,
  `lucky5.mp3`, `machine-close.mp3`, `win.mp3`, `bonus-claim.mp3`,
  `doubleup-win.mp3`, `doubleup-lose.mp3`, `cash-in.mp3`, `cash-out.mp3`,
  `hold.mp3`, and `jackpot.mp3`.

## REST Endpoint Audit

All web cabinet API calls use `GAME_CONFIG.api.baseUrl`, bearer auth from local
storage when available, and an `ApiResponse<T>` envelope from the backend unless
the endpoint is static content.

Auth model from `server/src/Lucky5.Api/Program.cs` and controller helpers:

- Bearer tokens are accepted from the `Authorization: Bearer <token>` header or
  `access_token` query string.
- Token validation sets `ClaimTypes.NameIdentifier` and `ClaimTypes.Role` on
  `HttpContext.User`; there is no ASP.NET `[Authorize]` attribute gate in these
  controllers today.
- User-protected endpoints call `HttpContext.RequireUserId()`; admin endpoints
  call `HttpContext.RequireAdminRole()`.
- `POST /api/Auth/login`, `POST /api/Auth/signup`, `POST /api/Auth/verify-otp`,
  `POST /api/Auth/resend-otp`, `GET /api/config/firebase`, and public general
  read endpoints do not call those helpers.
- `GET /api/config/firebase` returns a plain object, not `ApiResponse<T>`.

### Cabinet And Web-Used Endpoint Catalog

| Surface | Method and path | Request body used by web | Response data shape | Godot contract decision |
| --- | --- | --- | --- | --- |
| Login | `POST /api/Auth/login` | `{ username, password }` | `ApiResponse.data = { tokens, profile }` | Keep JSON. Godot stores token securely and treats profile as session seed. |
| Signup | `POST /api/Auth/signup` | `{ username, password, phoneNumber }` | `MemberProfileDto` | Keep JSON. Do not rely on the web placeholder phone number. |
| OTP | `POST /api/Auth/verify-otp` | `{ username, otpCode }` | `{ verified: true }` in the response envelope | Optional for Godot onboarding. The current web uses a hard-coded OTP after signup and should not be copied as a real onboarding flow. |
| Profile | `GET /api/Auth/GetUserById` | none | `MemberProfileDto` | Keep as current balance/profile source until cabinet snapshot covers all fields. |
| Member history | `GET /api/Auth/MemberHistory` | none | transaction/history records | Wallet screen only. |
| Logout | `POST /api/Auth/logout` | none | message/envelope | Endpoint exists, but current web logout clears local state without calling it. Godot should call it when available. |
| Firebase config | `GET /api/config/firebase` | none | `{ configured: false }` or `{ configured: true, config }` without `ApiResponse<T>` envelope | Web-specific notification setup. Optional for Godot unless push is reused. |
| Reward status | `GET /api/Reward/status` | none | `BonusStatusDto` | Optional lobby banner contract. |
| Reward claim | `POST /api/Reward/claim` | none | `BonusClaimResultDto` | Optional lobby command. |
| Notification device | `POST /api/Notification/register-device` | `{ Token, Platform }` | message/envelope | Web push-specific today. Godot needs platform-specific equivalent only if notifications ship. |
| Machine list | `GET /api/Game/games/machines` | none | `MachineListingDto[]` | Keep for lobby. Alias `/api/Game/machines` also exists. |
| Rules | `GET /api/Game/defaultRules` | none | `DefaultRulesDto` | Keep for display only. VariantDefinition is the stronger Godot source. Alias `/api/Game/rules` also exists. |
| Machine session | `GET /api/Game/machine/{machineId}/session` | none | `MachineSessionDto` | Keep for wallet/machine credit visibility. Snapshot should include active session fields. |
| Active round | `GET /api/Game/machine/{machineId}/active-round` | none | `ActiveRoundStateDto` or null | Current refresh recovery. Godot should prefer CabinetSnapshot/replay and use this only as compatibility fallback. |
| Machine state | `GET /api/Game/machine/{machineId}/state` | none | Machine ledger/jackpot object | Current debug/jackpot source. Godot should prefer CabinetSnapshot. |
| Cabinet snapshot | `GET /api/Game/machine/{machineId}/cabinet-snapshot` | none | `CabinetSnapshotDto` | Existing seed for Godot, but v1 contract must become monotonic and JSON-schema aligned. |
| Cash in | `POST /api/Game/machine/{machineId}/cash-in` | `{ amount }` | `MachineSessionDto` | Godot command type `cash_in`. |
| Cash out | `POST /api/Game/machine/{machineId}/cash-out` | none | `MachineSessionDto` | Godot command type `cash_out`; block while active unresolved round exists. |
| Reset machine | `POST /api/Game/machine/{machineId}/reset` | none | message/envelope | Admin/maintenance command only. |
| Deal | `POST /api/Game/cards/deal` | `{ machineId, betAmount }` | `DealResultDto` | Godot command type `deal`. Alias `/api/Game/deal` exists. |
| Draw | `POST /api/Game/cards/draw` | `{ roundId, holdIndexes }` | `DrawResultDto` | Godot command type `draw`. Alias `/api/Game/draw` exists. |
| Jackpot rank | `POST /api/Game/jackpot/rank` | `{ machineId, rank }` | `JackpotInfoDto` | Idle BET and idle HOLD[0] can call this today as the Full House rank selector. Godot should make it explicit, ordered, and backend-authorized. |
| Double-up start | `POST /api/Game/double-up/start` | `{ roundId }` | `DoubleUpResultDto` | Godot command type `double_up_start`. |
| Double-up guess | `POST /api/Game/double-up/guess` | `{ roundId, guess }` | `DoubleUpResultDto` | Godot command type `double_up_guess`, canonical guesses `big` and `small`. |
| Double-up switch | `POST /api/Game/double-up/switch` | `{ roundId }` | `DoubleUpResultDto` | Godot command type `double_up_switch`. |
| Take half | `POST /api/Game/double-up/take-half` | `{ roundId }` | `DoubleUpResultDto` | Godot command type `take_half`. |
| Take score | `POST /api/Game/double-up/cashout` | `{ roundId }` | `DoubleUpResultDto` | Godot command type `take_score`. |
| Admin users | `GET /api/Admin/users` | none | `AdminUserDto[]` | Admin-only, not part of normal cabinet play. |
| Admin user search | `GET /api/Admin/users/search?q=...` | none | `AdminUserDto[]` | Admin-only. |
| Admin credit | `POST /api/Admin/users/credit` | `{ targetUserId, amount, reason }` | user/credit result | Admin-only. |
| Admin machines | `GET /api/Admin/machines` | none | `AdminMachineDto[]` | Admin-only. |
| Admin reset | `POST /api/Admin/machines/{machineId}/reset` | none | message/envelope | Admin-only. |

### Full Current Backend API Surface

This table includes endpoints beyond the current web cabinet calls so Godot can
avoid accidental shadow dependencies.

| Area | Method and path | Auth requirement in code | Response/envelope | Godot migration decision |
| --- | --- | --- | --- | --- |
| Auth | `POST /api/Auth/login` | Public | `ApiResponse<object>` with `{ tokens, profile }` | Keep for session bootstrap. |
| Auth | `POST /api/Auth/signup` | Public | `ApiResponse<MemberProfileDto>` | Optional onboarding; do not preserve hard-coded web phone/OTP behavior. |
| Auth | `POST /api/Auth/verify-otp` | Public | `ApiResponse<object>` with `{ verified: true }` | Optional onboarding. |
| Auth | `POST /api/Auth/resend-otp` | Public | `ApiResponse<object>` with `{ resent: true }` | Optional onboarding. |
| Auth/profile | `GET /api/Auth/GetUserById` | User token | `ApiResponse<MemberProfileDto>` | Keep until cabinet snapshot includes all profile/balance fields. |
| Auth/history | `GET /api/Auth/MemberHistory` | User token | `ApiResponse<WalletLedgerEntryDto[]>` | Wallet/history only. |
| Wallet/admin | `POST /api/Auth/TransferBalance` | Admin token | `ApiResponse<WalletLedgerEntryDto>` | Admin/back-office only; not Godot cabinet play. |
| Wallet | `POST /api/Auth/MoveWinToBalance` | User token | `ApiResponse<WalletLedgerEntryDto>` | Legacy wallet movement; cabinet should prefer authoritative game/session command results. |
| Wallet/admin | `POST /api/Auth/UpdateCredit` | Admin token | `ApiResponse<WalletLedgerEntryDto>` | Admin/back-office only. |
| Wallet | `POST /api/Auth/Deposit` | User token | `ApiResponse<WalletLedgerEntryDto>` | Current wallet shell has disabled deposit; do not expose as cabinet gameplay. |
| Wallet | `POST /api/Auth/Withdraw` | User token | `ApiResponse<WalletLedgerEntryDto>` | Current wallet shell has disabled withdraw; do not expose as cabinet gameplay. |
| Auth | `POST /api/Auth/logout` | Token optional in code; uses `access_token` item if present | `ApiResponse<object>` | Godot should call when token exists, then clear local session. |
| Config | `GET /api/config/firebase` | Public | Plain `{ configured, config? }` | Web push setup only; optional/no-op for Godot. |
| Game/lobby | `GET /api/Game/machines` and `GET /api/Game/games/machines` | Public in code | `ApiResponse<MachineListingDto[]>` | Keep for lobby/machine selection; auth may still be enforced later. |
| Game/rules | `GET /api/Game/rules` and `GET /api/Game/defaultRules` | Public in code | `ApiResponse<DefaultRulesDto>` | Display/reference only; variant definition is stronger for Godot presentation metadata. |
| Machine/session | `GET /api/Game/machine/{machineId}/session` | User token | `ApiResponse<MachineSessionDto>` | Keep as compatibility session seed until snapshot covers it. |
| Machine/session | `POST /api/Game/machine/{machineId}/cash-in` | User token | `ApiResponse<MachineSessionDto>` | Map to `CabinetCommand` `cash_in`. |
| Machine/session | `POST /api/Game/machine/{machineId}/cash-out` | User token | `ApiResponse<MachineSessionDto>` | Map to `cash_out`; backend blocks unsafe unresolved rounds. |
| Round recovery | `GET /api/Game/active-round/{machineId}` and `GET /api/Game/machine/{machineId}/active-round` | User token | `ApiResponse<ActiveRoundStateDto?>` | Compatibility refresh only; Godot should prefer snapshot/replay. |
| Cabinet snapshot | `GET /api/Game/machine/{machineId}/cabinet-snapshot` | User token | `ApiResponse<CabinetSnapshotDto>` | Existing seed; must be promoted to schema-defined `CabinetSnapshot`. |
| Gameplay | `POST /api/Game/deal` and `POST /api/Game/cards/deal` | User token | `ApiResponse<DealResultDto>` | Map to `CabinetCommand` `deal`; no optimistic client math. |
| Gameplay | `POST /api/Game/draw` and `POST /api/Game/cards/draw` | User token | `ApiResponse<DrawResultDto>` | Map to `draw`; holds submitted in payload. |
| Double-up | `POST /api/Game/double-up/start` | User token | `ApiResponse<DoubleUpResultDto>` | Map to `double_up_start`. |
| Double-up | `POST /api/Game/double-up/guess` | User token | `ApiResponse<DoubleUpResultDto>` | Map to `double_up_guess`. |
| Double-up | `POST /api/Game/double-up/switch` | User token | `ApiResponse<DoubleUpResultDto>` | Map to `double_up_switch`. |
| Double-up | `POST /api/Game/double-up/take-half` | User token | `ApiResponse<DoubleUpResultDto>` | Map to `take_half`. |
| Double-up | `POST /api/Game/double-up/cashout` | User token | `ApiResponse<DoubleUpResultDto>` | Map to `take_score`, distinct from machine `cash_out`. |
| Machine/debug | `GET /api/Game/machine/{id}/state` | Public in code | Plain object | Debug/legacy state; Godot should prefer snapshot and treat this as compatibility only. |
| Jackpot | `POST /api/Game/jackpot/rank` | Public in code today | `ApiResponse<JackpotInfoDto>` | Must become an ordered, backend-authorized command before Godot relies on it. |
| Machine/admin-ish | `POST /api/Game/machine/{machineId}/reset` | User token; service may apply role/session checks | `ApiResponse<object>` | Maintenance/admin command only; normal Godot cabinet should not expose to players. |
| Admin/users | `GET /api/Admin/users` | Admin token | `ApiResponse<AdminUserDto[]>` | Admin-only. |
| Admin/users | `GET /api/Admin/users/search?q=...` | Admin token | `ApiResponse<AdminUserDto[]>` | Admin-only. |
| Admin/users | `GET /api/Admin/users/{userId}` | Admin token | `ApiResponse<AdminUserDto>` | Admin-only. |
| Admin/users | `POST /api/Admin/users/credit` | Admin token | `ApiResponse<WalletLedgerEntryDto>` | Admin-only credit adjustment. |
| Admin/machines | `GET /api/Admin/machines` | Admin token | `ApiResponse<AdminMachineDto[]>` | Admin-only operations console. |
| Admin/machines | `GET /api/Admin/machines/{machineId}` | Admin token | `ApiResponse<AdminMachineDto>` | Admin-only operations console. |
| Admin/machines | `POST /api/Admin/machines/{machineId}/reset` | Admin token | `ApiResponse<AdminMachineDto>` | Admin-only maintenance command. |
| Admin/machines | `POST /api/Admin/machines/{machineId}/door-state` | Admin token | `ApiResponse<DoorState>` | Admin-only cabinet operations; can inform future operator UI, not player Godot. |
| Admin/reward | `POST /api/Admin/users/recharge-bonus` | Admin token | `ApiResponse<WalletLedgerEntryDto>` | Admin-only. |
| Agent/admin | `GET /api/Agent` | Admin token | `ApiResponse<AgentDto[]>` | Back-office only; no route suffix on `[HttpGet]`. |
| Agent/admin | `POST /api/Agent` | Admin token | `ApiResponse<AgentDto>` | Back-office only; no route suffix on `[HttpPost]`. |
| Agent/admin | `POST /api/Agent/{agentId}/load-credit` | Admin token | `ApiResponse<AgentDto>` | Back-office only. |
| Agent/admin | `POST /api/Agent/{agentId}/assign-user/{userId}` | Admin token | `ApiResponse<object>` | Back-office only. |
| General | `GET /api/General/app-settings` | Public | `ApiResponse<IReadOnlyDictionary<string,string>>` | Optional shell/config display. |
| General | `GET /api/General/contact-info` | Public | `ApiResponse<IReadOnlyDictionary<string,string>>` | Optional support screen. |
| General | `GET /api/General/contact-types` | Public | `ApiResponse<ContactTypeDto[]>` | Optional support screen. |
| General | `POST /api/General/contact-report` | User token | `ApiResponse<object>` | Optional support flow; not gameplay. |
| General | `GET /api/General/terms` | Public | `ApiResponse<TermsResponseDto>` | Legal/info display only. |
| Reward | `GET /api/Reward/status` | User token | `ApiResponse<BonusStatusDto>` | Optional lobby banner. |
| Reward | `POST /api/Reward/claim` | User token | `ApiResponse<BonusClaimResultDto>` | Optional lobby command; never gameplay settlement. |
| Notification | `POST /api/Notification/register-device` | User token | `ApiResponse<object>` | Web/mobile push only; Godot platform-specific decision later. |

API gaps found by this audit:

- `GAME_CONFIG.api.wallet` points at `/api/Auth/wallet`, but no matching
  controller route exists in this checkout.
- Current API extraction must include no-route attributes such as
  `[HttpGet]`/`[HttpPost]` on `AgentController`; otherwise `/api/Agent` can be
  missed by route audits.
- Several routes are public in controller code because they do not call
  `RequireUserId()`/`RequireAdminRole()` (`Game/machines`, `Game/rules`,
  `Game/machine/{id}/state`, `Game/jackpot/rank`). Godot must not rely on that
  remaining public in production; contract docs should mark authority separately
  from current helper placement.
- There is no unified REST endpoint or hub method accepting the schema-defined
  `CabinetCommand` envelope.
- `GET /api/Game/machine/{machineId}/cabinet-snapshot` exists, but its DTO is a
  legacy seed shape rather than `cabinet.v1` schema output.

Current local-only actions that need server-visible equivalents or snapshot
reflection for Godot:

- Hold changes are local until draw. Godot may keep local hold preview, but the
  canonical contract includes `hold` and `clear_holds` commands so reconnect and
  multi-device visibility can be authoritative.
- Bet changes are local until deal. The canonical contract includes `bet_change`
  so the backend can validate stake and reflect enabled buttons consistently.
- The Full House jackpot rank selector is a current web side effect of idle BET
  and idle HOLD[0]. Godot should use `jackpot_rank_change` as an explicit,
  ordered command or receive the rank inside the authoritative snapshot.

Configured but not observed as current gameplay calls:

- `GAME_CONFIG.api.wallet` points at `/api/Auth/wallet`, but the current web
  wallet flow uses profile/history calls instead.

## DTO And JSON Shape Audit

Common envelope:

- `ApiResponse<T>`: `success`, `message`, `data`, `errors`, `traceId`.
- Exception: `GET /api/config/firebase` returns a plain object with
  `configured` and optional `config`; it is not wrapped in `ApiResponse<T>`.
- Web JavaScript normalizes PascalCase responses to camelCase. Godot should
  consume explicit JSON naming from OpenAPI/schema rather than rely on this
  normalization layer.

Auth/session:

- `LoginRequest`: `username`, `password`.
- Login response `data`: `tokens`, `profile`.
- `SignupRequest`: `username`, `password`, `phoneNumber`, optional `email`,
  `fullName`, `dateOfBirth`, `agentId`.
- Signup response `data`: `MemberProfileDto`.
- `VerifyOtpRequest`: `username`, `otpCode`.
- Verify OTP response `data`: `verified`.
- `ResendOtpRequest`: `username`; response `data`: `resent`.
- `AuthTokens`: `accessToken`, `refreshToken`, `expiresAtUtc`.
- `MemberProfileDto`: `userId`, `username`, `displayName`, `fullName`, `email`,
  `phoneNumber`, `dateOfBirth`, `walletBalance`, `credit`, `totalWins`,
  `agentId`, `generatedID`, `minimumOut`, `bonusDate`, `bonusRechargeCount`,
  `lastSeenUtc`, `role`.
- `WalletLedgerEntryDto`: `id`, `amount`, `balanceAfter`, `type`, `reference`,
  `createdUtc`.

Machine/session/balance:

- `MachineListingDto`: `id`, `name`, `isOpen`, `minBet`, `maxBet`.
- `DefaultRulesDto`: `payoutMultipliers`.
- `MachineCashRequest`: `amount`.
- `MachineSessionDto`: `sessionId`, `machineId`, `machineCredits`,
  `totalCashIn`, `cashOutThreshold`, `canCashOut`, `isMachineClosed`,
  `walletBalance`, optional `transparency`.
- `GET /api/Game/machine/{id}/state`: anonymous machine state with active round
  count, session count, RTP phase fields, jackpot counters, machine serial, and
  timestamp.
- Current `CabinetSnapshotDto`: `schema_version`, `state_version`,
  `session_id`, `machine_id`, `variant_id`, `game_state`, `hand`, `evaluation`,
  `double_up`, `credits`, `jackpot`, `ui_hints`, `timestamp`,
  `sequence_number`. This is a legacy seed shape, not the final Godot contract:
  it uses `schema_version: "v1"`, has no `message_type`, omits the v1
  `session`/`machine`/`buttons`/`presentation`/`recovery` sections, and sets
  `sequence_number` to the derived `state_version`.

Round and recovery:

- `ActiveRoundStateDto`: `roundId`, `machineId`, `betAmount`, `phase`,
  `handRank`, `cards`, `resultCards`, `heldIndexes`, `pendingWinAmount`,
  `doubleUpAvailable`, `takeHalfUsed`, `doubleUpSession`.
- `DoubleUpStateDto`: `dealerCard`, `currentAmount`, `switchesRemaining`,
  `isNoLoseActive`, `luckyMultiplier`, optional `cardTrail`,
  `isLucky5Active`.

Core commands:

- `DealRequest`: `machineId`, `betAmount`.
- `DealResultDto`: `roundId`, `cards`, `betAmount`, `walletBalanceAfterBet`,
  optional `jackpots`, optional `advisedHolds`, and compatibility
  `machineCreditsAfterBet`.
- `DrawRequest`: `roundId`, `holdIndexes`.
- `DrawResultDto`: `roundId`, `cards`, `handRank`, `winAmount`,
  `walletBalanceAfterRound`, `jackpotWon`, optional `jackpots`,
  `doubleUpAvailable`, and compatibility `machineCreditsAfterRound`.
- `PokerCardDto`: `rank`, `suit`, `code`.

Double-up commands:

- `StartDoubleUpRequest`: `roundId`.
- `DoubleUpRequest`: `roundId`, `guess`.
- `SwitchDealerRequest`: `roundId`.
- `TakeHalfRequest`: `roundId`.
- `CashoutDoubleUpRequest`: `roundId`.
- `DoubleUpResultDto`: `roundId`, `status`, `currentAmount`, `walletBalance`,
  optional `dealerCard`, optional `challengerCard`, `switchesRemaining`,
  `isNoLoseActive`, `luckyMultiplier`, optional `noise`, optional `cardTrail`,
  `isLucky5Active`.
- `PresentationNoiseDto`: `suspenseMs`, `revealMs`, `flipFrames`,
  `pulseFrames`.

Observed double-up statuses:

- `Started`
- `Win`
- `SafeFail`
- `MachineClosed`
- `Lose`
- `Lucky5`
- `Switched`
- `Cashout`
- `TookHalf`

Jackpot/rank:

- `ChangeJackpotRankRequest`: `machineId`, `rank`.
- `JackpotInfoDto`: `fullHouse`, `fullHouseRank`, `fourOfAKindA`,
  `fourOfAKindB`, `activeFourOfAKindSlot` as the current numeric slot,
  `straightFlush`, `machineSerial`, `machineSerie`, `machineKent`. The Godot
  v1 contract normalizes the active slot to `A` or `B`.

Reward and notification:

- `BonusStatusDto`: `isEligible`, `lastClaimUtc`, `nextEligibleUtc`,
  `bonusRechargeCount`.
- `BonusClaimResultDto`: `amountAwarded`, `newCreditBalance`, `claimedAtUtc`,
  `bonusRechargeCount`.
- `register-device` body: `Token`, `Platform`.

Admin and maintenance surfaces used by the current cabinet shell:

- `AdminCreditRequest`: `targetUserId`, `amount`, `reason`.
- `AdminUserDto`: `userId`, `username`, `displayName`, `phoneNumber`,
  `walletBalance`, `role`, `createdUtc`, `lastSeenUtc`.
- `AdminMachineDto`: machine identity, RTP fields, jackpot fields,
  `activeRounds`, `activePlayers`, and `sessions`.
- Player reset response: generic object with `success`, `message`, and
  wallet/session values depending on whether a session existed.

## SignalR And WebSocket Audit

Hub endpoint: `/CarrePokerGameHub`.

Auth: bearer token is accepted from header or `access_token` query string.

Current web usage:

- Connects with `withAutomaticReconnect()`.
- Invokes `JoinMachine(machineId)` after selecting a machine.
- Invokes `LeaveMachine(machineId)` when leaving.
- On reconnect, invokes `JoinMachine(machineId)` again.
- Listens to `MachineStateUpdated` and uses jackpot fields.
- Listens to `Error` and logs it to the browser console.
- Does not currently invoke hub `Deal`, `Draw`, `DoubleUp`, `Heartbeat`, or
  `ReconnectSync`; those commands use REST today.
- Session visibility is implicit through connection registry membership and
  heartbeat timeout handling; there is no player-facing visibility state in the
  current web UI.
- `HeartbeatMonitorService` sends hub `Error` with code `HEARTBEAT_TIMEOUT`
  when registry entries go stale. Because the web cabinet does not currently
  invoke `Heartbeat()`, this is a backend channel Godot must either use
  intentionally or replace with a contract-level heartbeat command.

Hub methods:

| Method | Current behavior | Godot contract decision |
| --- | --- | --- |
| `JoinMachine(machineId)` | Adds connection to machine group, returns current `MachineStateUpdated` to caller. | Keep as `join_machine` command or connection handshake. Response should include state and sequence. |
| `LeaveMachine(machineId)` | Removes connection from machine group. | Keep for visibility/session cleanup. |
| `Deal(machineId, betAmount)` | Server deals, sends `CardsDealt` to caller, broadcasts `MachineStateUpdated`. | Prefer unified command envelope and `CabinetEvent`. |
| `Draw(roundId, holdIndexes)` | Server draws, sends `CardRevealed`, `WalletUpdated`, broadcasts `MachineStateUpdated`. | Prefer unified command envelope and ordered event stream. |
| `DoubleUp(roundId, guess)` | Server executes double-up and sends `RewardStatus` and `DoubleUpCard`. | Prefer split command types for start, guess, switch, take-half, and take-score. |
| `Heartbeat()` | Touches connection registry. | Godot should send contract `heartbeat` while connected or rely on a documented transport keepalive; timeout becomes recovery-required. |
| `ReconnectSync(machineId)` | Sends current `MachineStateUpdated` after reconnect. | Replace with last-seen sequence/state handshake and replay-or-snapshot response. |

Hub events:

| Event | Current payload | Godot contract decision |
| --- | --- | --- |
| `MachineStateUpdated` | Machine state object with jackpot and ledger fields, no sequence/version guarantee. | Replace or wrap as `CabinetEvent` with `event_type=state_changed` or `jackpot_updated`. |
| `CardsDealt` | Deal result DTO. | Use command result plus ordered event. |
| `CardRevealed` | Draw result DTO. | Use command result plus ordered event. |
| `WalletUpdated` | Draw result DTO wallet fields. | Use `credits` inside snapshot/event. |
| `RewardStatus` | Double-up status/current amount. | Use double-up state in event payload. |
| `DoubleUpCard` | Double-up result DTO. | Use double-up event payload with ordered sequence. |
| `Error` | Object with `code` and `message`. | Use `command_rejected`, `heartbeat_timeout`, or `recovery_required` events with visible overlay behavior. |
| `heartbeat_ack` | Not emitted today. | Contract event acknowledging a Godot heartbeat when the backend needs explicit visibility confirmation. |

Current realtime gaps to close for Godot:

- Hub payloads have no monotonic `sequence_number`.
- Current `CabinetSnapshotDto` sets `sequence_number` equal to a derived
  `state_version`, which is not a replay sequence.
- No server replay buffer exists today. Until one is implemented, reconnect must
  return a full snapshot.
- Web does not visibly block commands while disconnected.
- Hub errors are not displayed to the player.

## Web-Specific Payloads Requiring JSON-Only Equivalents

The cabinet API does not intentionally return HTML fragments for gameplay.
However, several flows are web/DOM-specific and need Godot-native equivalents:

- Browser `prompt` for cash-in amount should become a structured `cash_in`
  command payload.
- Browser `prompt` for admin credit/debit amount and reason should remain
  admin-only and become structured admin command payloads if Godot exposes those
  tools.
- Browser `confirm` for reset/logout/back-to-lobby should become explicit
  Godot dialog state followed by command payloads.
- Browser `alert` for auth or network errors should become a cabinet overlay
  using structured error codes.
- DOM-built wallet/admin/game rows should be backed by JSON DTOs only.
- Firebase web service worker and foreground notification banner are web-only;
  Godot needs a platform-specific push or no-op path.
- CDN script loading and static HTML asset preloading are web-only; Godot should
  ship imported assets and use the JSON contract for runtime state.
- `cabinet-image-cache.js` fetches static image assets. These fetches are not
  REST gameplay endpoints and should not become runtime state dependencies for
  Godot.
- `GET /api/General/terms` returns Markdown-style terms content and is not used
  by the cabinet gameplay surface.

## Versioned Cabinet Contract

The schema lives in `cabinet-contract-v1.schema.json`.

General rules:

- JSON field names use snake_case.
- `schema_version` is required on every snapshot, event, command, and command
  result.
- Credits and payouts are transported as decimal strings in the contract schema
  to avoid client number precision drift. The current web may still receive
  numeric JSON from legacy DTOs.
- `state_version` is a backend-owned optimistic concurrency token for the full
  authoritative cabinet state.
- `sequence_number` is a backend-owned, monotonically increasing event stream
  position for a machine/session stream.
- Godot applies events only in sequence order.
- Godot treats snapshots as authoritative replacement state.
- Command payloads must be validated by the backend. Godot button enablement is
  advisory, not authority.

### CabinetSnapshot

`CabinetSnapshot` is the full recoverable state needed to render the cabinet:

- `schema_version`
- `state_version`
- `sequence_number`
- `server_time_utc`
- `session`
- `machine`
- `variant`
- `game_state`
- `credits`
- `hand`
- `evaluation`
- `double_up`
- `jackpot`
- `buttons`
- `presentation`
- `recovery`

Godot uses snapshots on first join, login restore, reconnect recovery, stale
command rejection, and replay gaps.

### CabinetEvent

`CabinetEvent` is an ordered incremental update:

- `schema_version`
- `event_id`
- `event_type`
- `state_version`
- `sequence_number`
- `server_time_utc`
- `payload`

Required event types for Godot:

- `snapshot`
- `state_changed`
- `jackpot_updated`
- `session_visibility_changed`
- `credits_updated`
- `round_updated`
- `double_up_updated`
- `command_accepted`
- `command_rejected`
- `heartbeat_ack`
- `replay_gap`
- `heartbeat_timeout`
- `recovery_required`

### CabinetCommand

`CabinetCommand` is the only Godot gameplay command envelope:

- `schema_version`
- `command_id`
- `command_type`
- `session_id`
- `machine_id`
- `expected_state_version`
- `idempotency_key`
- `client_sequence_number`
- `sent_at_utc`
- `payload`

Required command types:

- `deal`
- `draw`
- `hold`
- `clear_holds`
- `double_up_start`
- `double_up_guess`
- `double_up_switch`
- `take_half`
- `take_score`
- `cash_in`
- `cash_out`
- `bet_change`
- `jackpot_rank_change`
- `reset_machine`
- `join_machine`
- `leave_machine`
- `heartbeat`
- `reconnect_sync`

Legacy compatibility notes:

- `hold`, `clear_holds`, `bet_change`, and `heartbeat` do not have dedicated
  REST endpoints today.
- `jackpot_rank_change` exists as `/api/Game/jackpot/rank`, but the web calls
  it as an idle UI side effect rather than an ordered cabinet command.
- `join_machine`, `leave_machine`, and `reconnect_sync` exist only as hub
  methods today.

### Idempotency And Concurrency

- `command_id` is a UUID generated once per physical/intentional player action.
- `idempotency_key` is stable across retries of the same command.
- Repeating the same `idempotency_key` with identical command content returns the
  cached command result.
- Repeating the same `idempotency_key` with different content is rejected.
- `expected_state_version` is required for gameplay and session-changing
  commands.
- If `expected_state_version` is stale, the backend rejects the command and
  returns or points to a full `CabinetSnapshot`.
- Godot never fabricates wins, credits, cards, jackpot movement, or double-up
  outcomes while waiting for a command result.

## Reconnect And Gap Recovery Rules

Godot must maintain:

- `last_state_version`
- `last_sequence_number`
- active `session_id`
- active `machine_id`
- pending `command_id` and `idempotency_key` values

Disconnected behavior:

- Immediately show a blocking recovery overlay.
- Disable all gameplay commands, including deal, draw, hold, double-up, take
  half, take score, cash in, cash out, bet change, and jackpot rank change.
- Stop irreversible local animations at a recoverable loop or finish only
  cosmetic motion with no state change.
- Keep logout/back navigation available only if it cannot mutate machine state.

Reconnect handshake:

1. Reconnect transport and authenticate.
2. Send `reconnect_sync` with `machine_id`, `session_id`, `last_state_version`,
   and `last_sequence_number`.
3. Backend compares the requested sequence with its replay buffer.
4. If all missed events are available, backend sends replay events in order.
5. If any gap exists, backend sends a full `CabinetSnapshot`.
6. Godot clears the recovery overlay only after applying replay or snapshot and
   confirming controls from the authoritative `buttons` list.

Current backend limitation:

- There is no replay buffer today. The Phase 1 backend path should return a full
  snapshot for every reconnect until replay is implemented.

Stale or out-of-order handling:

- Ignore any event with `sequence_number <= last_sequence_number`.
- Enter recovery if an event arrives with `sequence_number > last_sequence_number
  + 1`.
- Reject local command retries when the server reports a mismatched
  `expected_state_version`; apply the returned snapshot before enabling buttons.
- Treat duplicated command results as idempotent success only when
  `command_id` and `idempotency_key` match the pending command.

## Variant Definition

The schema lives in `variant-definition-v1.schema.json`.

`VariantDefinition` is the versioned governance record for Lucky5 Classic and
future variants. It is not a game-rule implementation file. Backend rule engines
remain the authority for game math.

Required model areas:

- Identity: `variant_id`, `display_name`, `family`, `status`, and
  `ruleset_version`.
- Paytable: canonical multiplier map and `paytable_hash`.
- RTP gate: simulation requirement, simulation status, minimum rounds, optional
  target RTP, report URI, and production approval flag.
- Double-up profile: enabled switches, Big/Small choices, Lucky5 card identity,
  and take-half/take-score availability.
- Jackpot profile: named jackpot meters and machine counter labels.
- Machine policy: min/max bet references, cash-in unit references, and close
  threshold references.
- Cabinet skin: asset root, button assets, palette, and cabinet identity notes.
- Presentation profile: layout size, timing profile, and UX rules.
- Governance: owner, approver, approval time, change ticket, simulation report,
  and notes.
- Production activation: explicit enablement flag and required gates.
- Compatibility: minimum backend schema and minimum Godot client schema.

### Lucky5 Classic Seed

The initial record is `lucky5-classic.variant.v1.json`.

Canonical paytable JSON used for the seed hash:

```json
{"Flush":10,"FourOfAKind":15,"FullHouse":12,"RoyalFlush":1000,"Straight":8,"StraightFlush":75,"ThreeOfAKind":3,"TwoPair":2}
```

SHA-256:

```text
cbe816c3eaa3d13cf0a55850ffb27140b856a35015a8fd44d41bd507babdb196
```

Production activation rules:

- A variant cannot be `active` until the paytable hash matches the reviewed
  paytable.
- A variant cannot be `active` until the RTP simulation gate passes and the
  report URI is recorded.
- A variant cannot be `active` until governance approval fields are populated.
- A variant cannot be `active` until cabinet skin assets exist and load in the
  target Godot build.
- A variant cannot be `active` until backend schema and Godot client schema
  compatibility gates pass.

## Phase 0 Open Gaps

| Gap | Current evidence | Required follow-up | Owner area |
| --- | --- | --- | --- |
| Unified command transport | REST uses method-specific endpoints and hub uses method-specific methods; no surface accepts schema `CabinetCommand`. | Add a JSON-only REST endpoint or hub envelope that accepts and validates `CabinetCommand`, returns `CabinetCommandResult`, and preserves idempotency. | Backend contracts/realtime |
| Snapshot schema mismatch | `GET /api/Game/machine/{machineId}/cabinet-snapshot` returns legacy `CabinetSnapshotDto` with flat `session_id`, `ui_hints`, `timestamp`, and `schema_version: "v1"`. | Promote the endpoint to schema-defined `CabinetSnapshot` or add a named compatibility adapter until promotion lands. | Backend contracts + Godot adapter |
| Version/sequence authority | Current snapshot derives `sequence_number` from `state_version`; hub events do not carry monotonic sequence numbers. | Make `state_version` and `sequence_number` backend-owned monotonic fields with documented ordering semantics. | Backend authority/realtime |
| Replay buffer | `ReconnectSync(int machineId)` only emits current `MachineStateUpdated`; no replay store exists. | Add replay buffer or formally standardize snapshot-only reconnect for `cabinet.v1`; until then Godot must always fetch/apply a full snapshot after reconnect. | Backend realtime/recovery |
| Prompt/confirm flows | Web uses browser prompt/confirm/alert for cash-in, reset, logout, and admin credit. | Replace with structured Godot dialog states and command payloads. | Godot presentation |
| Asset integrity | Oracle card set has zero-byte `assets/images/cards/10C.png`; mobile and APK copies are non-zero. | Repair `10C.png` from `mobile/www` or `ai9poker/root/assets/flutter_assets/assets` before Godot import validation. | Assets/build |
| Sound pack completeness | Only approved sound is `press.mp3`; any jackpot/win sound references are not backed by approved files in the oracle. | Add governed sound assets or remove stale references; do not synthesize gameplay sounds in Phase 0. | Assets/presentation |
| Visible hub recovery | Web logs hub `Error` to console and has no blocking offline/reconnect overlay. | Expose visible recovery/error overlay and command-disable behavior in Godot. | Godot presentation/realtime adapter |
| Public helper placement | Some game routes are public in code because they do not call `RequireUserId()`/`RequireAdminRole()`. | Centralize or explicitly document auth requirements before production Godot relies on those routes. | Backend auth/API |
| API audit tooling | Simple route extraction can miss `[HttpGet]`/`[HttpPost]` without route suffixes, as on `AgentController`. | Keep route catalog generation aware of no-route HTTP attributes and aliases. | Tooling/docs |

## Non-Goals

- No payout table changes.
- No RNG changes.
- No hand evaluation changes.
- No double-up math changes.
- No RTP target changes.
- No persistence model change.
- No Godot implementation work in Phase 0.
