# Double-Up Model Memory

## Authoritative backend contract

`DoubleUpResultDto` carries:
- `RoundId`
- `Status`
- `CurrentAmount`
- `WalletBalance`
- `DealerCard?`
- `ChallengerCard?`
- `SwitchesRemaining`
- `IsNoLoseActive`
- `LuckyMultiplier`
- `Noise?`

## Frontend contract

Map every `DoubleUpResultDto` into a `DoubleUpViewModel`.
The view model is the only shape the cabinet renderer may consume.

## Status handling

Terminal statuses:
- `Cashout`
- `Lose`
- `SafeFail`
- `MachineClosed`

Non-terminal statuses:
- `Started`
- `Switched`
- `Lucky5`
- `Win`
- `TakeHalf`

## Important consequence

Because `DealerCard` and `ChallengerCard` are optional, the cabinet must display placeholders when they are absent.
Retaining old cards after a DTO omits them is a desync bug.
