# Design: Lucky5 Sprint 1 Cabinet UI Parity

**Date**: 2026-04-04
**Status**: Drafted for review
**Implementation scope**: visual-only Sprint 1 pass
**Primary files**: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), [`src/web/app/globals.css`](src/web/app/globals.css)

## Goal

Deliver a focused Sprint 1 visual upgrade that moves the active web cabinet much closer to the APK look and layout shown in [`screenshots/Screenshot 2026-03-11 014751.png`](screenshots/Screenshot%202026-03-11%20014751.png), with **special emphasis on a much more prominent APK-like jackpot strip** and a cabinet-faithful lower control area, while preserving existing behavior and avoiding gameplay, API, Redis, and RTP changes.

## Scope

### In scope

- Light JSX regrouping inside [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- Targeted cabinet-focused CSS rebuild inside [`src/web/app/globals.css`](src/web/app/globals.css)
- Stronger APK-style visual hierarchy for:
  - playfield framing
  - jackpot strip presentation and emphasis
  - lower control deck
  - cabinet button styling
  - typography rhythm and spacing
- Keeping telemetry present but visually secondary

### Out of scope

- No component architecture rewrite
- No new React subcomponent extraction beyond trivial local cleanup
- No API contract changes
- No double-up logic changes
- No Redis or Azure behavior changes
- No RTP or CleanRoom rule changes

## Current Repo Context

- The active cabinet is a single large React component in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- Cabinet styling is centralized in [`src/web/app/globals.css`](src/web/app/globals.css)
- Local guidance confirms the current web cabinet is still incomplete versus the older cabinet experience in [`src/web/CLAUDE.md`](src/web/CLAUDE.md)
- The legacy cabinet reference already contains jackpot and cabinet behavior cues in [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js)
- Screenshot evidence shows the desired cabinet hierarchy: black playfield, a highly noticeable text-led jackpot strip directly supporting the playfield, and a dominant wood-toned lower control deck in [`screenshots/Screenshot 2026-03-11 014751.png`](screenshots/Screenshot%202026-03-11%20014751.png)

## Explored Approaches

### Approach A — CSS-heavy reskin only

Change mostly styles in [`src/web/app/globals.css`](src/web/app/globals.css) and avoid touching layout structure.

**Pros**
- Fastest
- Lowest JSX risk

**Cons**
- Harder to achieve convincing APK-style cabinet proportions
- Existing grouping remains too dashboard-like

### Approach B — Recommended

Lightly regroup JSX in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx) and do a targeted CSS rebuild in [`src/web/app/globals.css`](src/web/app/globals.css).

**Pros**
- Best balance of fidelity and safety
- Improves layout semantics without a large refactor
- Sets up Sprint 2 cleanly

**Cons**
- Slightly more risk than pure CSS
- Requires careful preservation of button wiring

### Approach C — Same-file full layout rewrite

Rewrite most cabinet markup inside [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx) without splitting files.

**Pros**
- Highest fidelity potential in one pass

**Cons**
- Highest regression risk
- Too much scope for a visual-only Sprint 1

## Chosen Approach

Use **Approach B**.

Sprint 1 should stay focused: light markup regrouping plus a targeted CSS rebuild so the cabinet feels much closer to the APK without turning this into a structural rewrite.

## Approved Design

### 1. Structural design

The cabinet remains a single main React file in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), but the JSX will be regrouped into clearer visual zones:

- paytable and top information area
- main card stage and gameplay surface
- jackpot and machine-info strip
- double-up panel
- large APK-style lower control deck

This is a visual regrouping, not a gameplay rewrite. Existing handlers and state wiring remain intact.

### 2. Visual design direction

The cabinet will shift toward the APK look in [`screenshots/Screenshot 2026-03-11 014751.png`](screenshots/Screenshot%202026-03-11%20014751.png):

- darker black playfield background
- tighter amber, gold, white, and accent text usage
- a much more prominent jackpot strip beneath the play area, closer to the APK hierarchy and visual weight
- a stronger wood-toned cabinet base for the lower control deck
- bigger cabinet-style button blocks with clearer color separation
- telemetry visually demoted so cabinet hardware remains the focal point

The telemetry remains available, but it should read as supporting information rather than competing with the jackpot strip or cabinet controls.

### 3. Safety boundary

Sprint 1 is strictly visual.

No changes will be made to:

- backend contracts
- double-up outcomes
- machine policy
- Redis integration
- RTP tuning

If a desired visual change would require behavioral changes, that work is deferred to later sprints from [`plans/lucky5-major-upgrade-chatgpt54-pro-plan.md`](plans/lucky5-major-upgrade-chatgpt54-pro-plan.md).

## Implementation Notes

### JSX regrouping rules

- Keep button handlers and disable logic attached to the same controls they already drive
- Prefer wrapping existing sections over rewriting logic-heavy fragments
- Avoid introducing new top-level state for Sprint 1

### CSS rules

- Prefer cabinet-specific class additions over broad global overrides
- Make the lower control deck visually dominant
- Make the jackpot strip clearly more prominent than telemetry and visually closer to the APK strip treatment
- Preserve responsiveness enough that the cabinet still works on current supported screen sizes

### APK fidelity priorities

If trade-offs are needed, prioritize these in order:

1. jackpot strip placement, emphasis, and APK similarity
2. lower control deck look and hierarchy
3. overall cabinet framing and black playfield feel
4. typography and spacing polish
5. telemetry restyling

## Verification Plan

Sprint 1 is complete only if all of the following are true:

- [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx) still renders without changing gameplay behavior
- Existing button behavior is smoke-tested after layout changes
- The jackpot strip and lower control deck are manually checked against [`screenshots/`](screenshots)
- The cabinet hardware is visually dominant and telemetry is clearly secondary
- Tightest relevant project checks are run before claiming success

## Risks and Mitigations

### Risk: layout polish breaks button affordances

**Mitigation**: keep markup changes light and preserve current control wiring.

### Risk: telemetry still overwhelms the cabinet

**Mitigation**: treat telemetry as secondary in spacing, contrast, and placement.

### Risk: visual pass accidentally expands into Sprint 2 behavior work

**Mitigation**: reject any change that requires contract or logic updates and defer it.

### Risk: APK fidelity becomes too literal for the current responsive layout

**Mitigation**: preserve cabinet feel first, literal 1:1 pixel matching second.

## Scope Check

This spec is intentionally narrow enough for a single implementation pass. It does not attempt to solve fixed 5-card double-up pagination, Redis caching, or RTP balancing. Those remain separate later-sprint work.
