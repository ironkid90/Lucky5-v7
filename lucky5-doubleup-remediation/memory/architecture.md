# Lucky5 Architecture Memory

## Core layering

1. CleanRoom domain is the authoritative rules engine.
   - Path: `server/src/Lucky5.Domain/Game/CleanRoom/`
   - Owns deterministic cards, draw resolution, double-up resolution, and machine policy decisions.
2. Application DTOs are the only backend-to-frontend contract.
   - Path: `server/src/Lucky5.Application/Dtos/`
3. Frontend is a projection layer.
   - It may animate after a server result arrives.
   - It may never invent, predict, or interpolate gameplay state.

## Double-up contract

The authoritative backend payload is `DoubleUpResultDto`.
Frontend code must map that DTO into a rigid presentation model before rendering.
No component should consume raw double-up DTO fields ad hoc.

## Presentation noise boundary

`PresentationNoiseDto` is presentation-only.
It may influence post-outcome reveal timing or polish.
It may never change cards, status, switches, amount, or win/loss outcomes.

## Source-of-truth rule

When frontend display and backend DTO disagree, backend DTO wins.
