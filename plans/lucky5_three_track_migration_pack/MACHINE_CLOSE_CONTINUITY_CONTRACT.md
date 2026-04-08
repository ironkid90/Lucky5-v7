# Machine Close Continuity Contract

This contract isolates the highest-risk gameplay correctness path in Lucky5:

- machine reaches the close threshold (40,000,000+ machine credits)
- the player cashes out the closed session
- the player cashes in again and resumes play
- machine RTP / ledger history continues without reset

## Source-of-truth constraints

1. Machine close is a **player-session gameplay state**, not a machine-ledger reset.
2. Wallet cash-out after a drained close path must be **idempotent**.
3. Player reset must clear only the player machine session when no recoverable round exists.
4. Machine ledger / RTP memory must continue across closes and cash-outs.
5. No force-reset should be required to resume play after a successful close-path cash-out.

## Required backend behavior

### A. When a machine closes at 40M+

- `MachineSessionState.IsMachineClosed = true`
- `MachineSessionState.MachineCredits` holds the closed-session credits until cash-out
- `MachineLedgerState` is **not** reset
- `NetSinceLastClose`, RTP aggregates, jackpot aggregates, and round counters remain authoritative

### B. When the player cashes out a closed machine session

Expected outcome:

- machine credits drain to `MemberProfile.WalletBalance`
- session machine credits become `0`
- session `TotalCashIn` resets to `0`
- session `IsMachineClosed` becomes `false`
- machine session remains reusable for the same machine id
- machine ledger remains untouched except for normal cash-flow accounting already required by the service

### C. Repeated close-path cash-out

If the player retries cash-out after the first drain completed:

- do **not** throw an invalid-state exception
- return the current `MachineSessionDto`
- keep wallet and ledger unchanged

### D. Resume play after closed-session cash-out

If the player cashes in after the closed-session drain:

- `DealAsync()` must accept the session as playable
- no reset action is required
- no admin intervention is required
- prior RTP / jackpot / machine-ledger state continues to influence policy

### E. Player reset

If no recoverable round exists:

- auto-cash-out any eligible machine credits
- clear only the player machine session
- preserve machine ledger / jackpot / RTP history

## Persistence requirements

Durable persistence must preserve enough state so restart/redeploy does not regress the above:

- `MachineLedgerState`
- `MachineSessionState`
- active `GameRound`
- `MemberProfile.WalletBalance`
- `WalletLedgerEntry`

## Regression scenarios that must exist

1. close at 40M+ -> cash-out -> cash-in -> play continues
2. close at 40M+ -> repeated cash-out retry is idempotent
3. close at 40M+ with no active round -> player reset clears session only
4. close at 40M+ -> restart/restore -> session + ledger restore correctly
5. close-path cash-out does not reset RTP counters or jackpot history

## Suggested file targets

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs`
- `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs`
- `server/src/Lucky5.Infrastructure/Persistence/*`
- `server/tests/Lucky5.Tests/`
