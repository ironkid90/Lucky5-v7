# Existing-file integration notes

These edits target files that were visible in docs/snippets but not available for safe in-place editing in this session.

## 1. `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`

Add the 80%-migration control terms to `EngineConfig`:

- `TargetRtp = 0.80m`
- `TargetJackpotRtp`
- `HouseEdgeBuffer`
- `EnvelopeScaleClamp`
- `JackpotRtpCap`
- `JackpotLeakDamp`
- `DoubleUpRtpCap`
- `DoubleUpPressureDamp`
- any new warmup/pity terms needed by unified policy telemetry

Keep existing Lebanese rules and machine-close threshold unchanged unless product explicitly approves otherwise.

## 2. `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`

Unify the policy entry point:

- add `ResolvePolicy(MachinePolicyState state, ulong entropySeed, EngineConfig? config = null)`
- keep `ResolvePayoutScale(...)` as a temporary shim if needed during migration
- compute:
  - `BaseScale`
  - `CorrectionGainAdjustment`
  - `WarmupBias`
  - `PityBoost`
  - `JackpotLeakAdjustment`
  - `DoubleUpLeakAdjustment`
- return `MachinePolicyResolution`
- expose `MachinePolicyTelemetry`

Guardrails:

- `HouseEdgeBuffer` may bias distribution/envelope selection only
- jackpot and double-up caps must affect future scaling/deck pressure only
- no post-choice outcome manipulation

## 3. `server/src/Lucky5.Infrastructure/Services/GameService.cs`

Replace duplicated `MachinePolicyState` construction with a single helper, then:

- use `ResolvePolicy(...)` at the deal-time scale decision point
- attach transparency telemetry to machine session snapshots
- ensure the persistence checkpoint coordinator can capture and restore:
  - machine sessions
  - machine ledgers
  - active rounds
  - user/profile/ledger continuity as needed

## 4. `server/src/Lucky5.Application/Dtos/MachineSessionDto.cs`

Extend the session DTO with:

```csharp
MachineTransparencyDto? Transparency
```

## 5. `server/src/Lucky5.Api/Program.cs`

Register:

- Redis-backed `IDistributedCache`
- `IPersistentStateStore`
- `IPersistentStateCoordinator`
- `PersistentStateCheckpointService`
- `PersistentStateHealthCheck`

Expose both:

- `/health/live`
- `/health/ready`

Recommended readiness behavior:

- `Healthy` when persistence is reachable
- `Degraded` when persistence is unavailable but graceful degradation is enabled
- `Unhealthy` only when graceful degradation is disabled and persistence is required

## 6. `server/src/Lucky5.Simulation/Program.cs`

Enhance the harness so it can run:

- 10,000-round simulation gate (CI)
- 500,000-round certification run

Emit:

- aggregate RTP
- 1k / 5k / 50k windows
- pity/warmup activation counts
- jackpot/double-up leak adjustments
- pass/fail exit code for `--min-rtp` and `--max-rtp`

## 7. `server/tests/Lucky5.Tests/Program.cs`

Wire in the new RED migration tests:

```csharp
await Lucky5.Tests.ThreeTrackMigrationRedTests.RunAsync(failures);
```

## 8. `.github/workflows/deploy-azure-app-service.yml`

Replace direct-to-production deployment with:

1. build
2. tests
3. 10k simulation gate
4. publish
5. deploy to staging slot
6. readiness probe
7. slot swap into production
