# Lucky5 Godot playable expansion bundle

Generated: 2026-05-24

Artifacts:

- `lucky5-godot-playable-expansion.patch` - unified diff to apply at the repository root.
- `lucky5-godot-playable-expansion-files/` - materialized new files for code review.

Apply:

```bash
git checkout -b feature/godot-playable-cabinet
git apply lucky5-godot-playable-expansion.patch
```

Verify after applying inside the repo:

```bash
dotnet build server/Lucky5.sln -v minimal
dotnet test server/tests/Lucky5.Tests/Lucky5.Tests.csproj --no-build
LUCKY5_API_BASE_URL=http://127.0.0.1:8080 LUCKY5_ACCESS_TOKEN=<token> LUCKY5_MACHINE_ID=1 godot4 --path godot/cabinet
```

Notes:

- The patch adds a Godot client only; backend RNG, payouts, wallets, jackpots, and double-up authority remain on the server.
- The session environment could not clone GitHub because DNS resolution for `github.com` failed, so the patch was prepared from GitHub connector-fetched files and uploaded migration/source artifacts.
- Godot syntax/build was not executed in this environment because the Godot editor/CLI is not installed here.
