# Double-Up Remediation Workstreams

## Workstream 1: Memory and rules
Create permanent architecture memory in `memory/` so future changes do not reintroduce authority leaks.

## Workstream 2: Frontend contract hardening
Add `DoubleUpViewModel` and map raw DTOs into a deterministic presentation model.

## Workstream 3: Authority cleanup
Remove frontend assumptions about settlement and stale card reuse.
All collect actions must call the backend.

## Workstream 4: Rendering cleanup
Make double-up JSX render from the view model only.
Disable controls from terminal view-model state rather than DTO presence checks alone.

## Workstream 5: Optional polish
If reveal animation is desired later, wire it only from `PresentationNoiseDto` and only after the authoritative outcome is already known.
