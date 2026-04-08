# Frontend Rules

## Allowed

- Mapping DTOs into view models
- Rendering placeholders when optional fields are absent
- Cosmetic animation driven by `PresentationNoiseDto`
- Clearing local round UI when backend settlement becomes terminal

## Forbidden

- `Math.random()` for gameplay display decisions
- Local card trails or fake shuffle paths
- Assuming payout settlement without a backend response
- Mixing raw DTO fields and unrelated fallback state inside render expressions
- Reusing stale dealer/challenger cards when a new DTO omits them

## Implementation rule

Do not render from raw `DoubleUpResultDto` inside JSX.
Always render from `DoubleUpViewModel`.
