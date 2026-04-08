# Lucky5 Three-Track Migration Validation

## Environment validation performed in this session

Validated from the uploaded onboarding and continuation docs:

- the live runtime is still **in-memory** and single-instance
- persistent storage is still explicitly pending
- the repo is still operating on the validated **85% RTP** regime
- the active production path uses GitHub Actions to deploy to Azure App Service
- the next balancing step is still pending a refreshed simulation run

## What this means against the requested target state

### Track A — Redis persistence
Current state does not yet expose durable authoritative storage. The docs still describe `InMemoryDataStore` as the source of truth, and persistence is called out as the highest-priority remaining gap.

### Track C — RTP balancing to 80%
Current state still centers the 85% target. `MachinePolicy` is documented as the balancing layer, but the 80% control loop, unified `ResolvePolicy`, and transparency telemetry are not yet described as landed.

### Track B — CI/CD slot swaps + simulation gate
Current state documents a direct GitHub Actions deployment path to Azure App Service. The zero-downtime slot-swap flow and simulation gate are not present in the uploaded repo materials.

## Hard blocker in this session

The full source tree was not mounted in the execution environment, and the GitHub connector was not queryable here. Because of that, the artifacts in this pack are:

- source-file additions that can be dropped into the repo
- RED-phase tests that will fail until existing files are integrated
- an example workflow for slot-swap deployment and simulation gating
- patch notes for existing files that could not be safely edited without the live source

## Next safe application step

Apply the files in this pack inside the real repo, then make the existing-file edits listed in `PATCH_NOTES_EXISTING_FILES.md`, then run:

```bash
dotnet build server/Lucky5.sln -v minimal
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --rounds 10000 --min-rtp 0.78 --max-rtp 0.82
```
