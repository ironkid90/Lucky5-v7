# lucky5-cabinet.tsx surgical audit

## No local RNG found

The audited `src/web/components/lucky5-cabinet.tsx` does not currently use `Math.random()` or an explicit randomized trail.
The main desync risk is not RNG simulation; it is authority leakage through mixed state and local settlement assumptions.

## Concrete violations

1. Base-win cashout is assumed locally instead of settled through the backend.

```tsx
if (!doubleUpResult) {
  setMessage("Score taken. The wallet already reflects the round payout.");
  setMessageTone("ready");
  return;
}
```

2. Double-up rendering consumes raw DTO fields directly inside JSX instead of a rigid view model.

```tsx
<PlayingCard card={doubleUpResult?.dealerCard} label="Dealer" />
<PlayingCard card={doubleUpResult?.challengerCard} label="Challenger" />
```

3. Amount display blends authoritative DTO state with unrelated draw-state fallback.

```tsx
formatMoney(doubleUpResult?.currentAmount ?? drawResult?.winAmount ?? 0)
```

4. Button enablement is keyed off DTO presence instead of explicit terminal state.

```tsx
disabled={busy || !doubleUpResult}
```

## Remediation summary

- Always settle TAKE SCORE through the backend endpoint.
- Normalize `DoubleUpResultDto` into `DoubleUpViewModel` before rendering.
- Render placeholders when the backend omits cards.
- Disable interaction from `viewModel.isTerminal`, `viewModel.canGuess`, and `viewModel.canSwitch`.
- Clear active round UI after terminal settlement while keeping the terminal result visible if desired.
