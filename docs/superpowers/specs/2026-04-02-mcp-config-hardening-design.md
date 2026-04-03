# MCP Config Hardening and Auto-Start Reliability Design

- Date: 2026-04-02
- Status: Approved for spec write-up
- Primary target: `C:\Users\Gabi\.verdent\mcp.json`

## 1. Summary

This design hardens and stabilizes the external MCP client configuration in `C:\Users\Gabi\.verdent\mcp.json` without removing any existing server entries. The configuration will remain the declarative inventory of enabled MCP servers, but startup-sensitive behavior will move into a small PowerShell launcher layer so server startup becomes more reliable, more portable across runtime upgrades, and easier to debug.

The design also removes inline secrets from the config, normalizes malformed or inconsistent fields, and adds a health-check workflow so each configured server can be validated before the client launches.

## 2. Goals

1. Keep every existing MCP server entry.
2. Remove inline credentials and source them from environment variables.
3. Make startup safer and more reliable across Node, Python, `uvx`, Docker, and local HTTP-backed servers.
4. Fix startup-breaking issues such as malformed arguments, whitespace-padded secrets, and brittle executable paths.
5. Centralize repeated runtime logic so future MCP server additions are easier to maintain.
6. Add verification tooling that reports per-server readiness and failure reasons.

## 3. Non-Goals

1. Removing servers that are currently present in `mcp.json`.
2. Replacing the user’s MCP client or changing its transport model.
3. Adding multiple new MCP servers unrelated to startup reliability.
4. Building a large orchestration framework beyond what is required for reliable launch, validation, and diagnostics.

## 4. Current Problems

Based on the supplied config, the current file has several structural and operational risks:

1. Secrets are embedded inline for GitHub, Sentry, Notion, and E2B.
2. Multiple Node-based servers are pinned to a hard-coded NVM-managed `node.exe` path, which is likely to break when the active Node version changes.
3. Several entries duplicate command-shape logic even though they differ only by runtime target.
4. The Sentry token argument contains leading whitespace, which is likely to break authentication.
5. Some servers depend on local services or installed runtimes that are not prevalidated before the MCP client attempts startup.
6. Field usage is inconsistent across entries (`disabled`, `timeout`, `alwaysAllow`, transport declarations), which makes the file harder to audit and maintain.
7. Local HTTP or streamable HTTP endpoints cannot be reliably auto-started by raw JSON alone, because the MCP config schema can describe endpoints but cannot express prerequisite startup logic.

## 5. Proposed Architecture

### 5.1 Declarative inventory plus launcher layer

`C:\Users\Gabi\.verdent\mcp.json` remains the MCP client’s source-of-truth configuration, but most stdio-launched servers will route through a shared PowerShell launcher rather than invoking raw executables directly.

The launcher will:

1. Resolve the correct runtime executable at launch time.
2. Validate required environment variables.
3. Normalize arguments before process start.
4. Fail fast with actionable diagnostics.
5. Start or wait for prerequisite local services where a known startup path exists.

This preserves a readable config while moving non-declarative operational logic into scripts that can be tested.

### 5.2 Supported launch patterns

The launcher layer will support these runtime categories:

1. **Node-backed stdio servers**: filesystem, Playwright, Context7, Notion, E2B, Firebase, `n8n-mcp`, Puppeteer.
2. **Python-backed stdio servers**: local virtualenv-based bridges such as `ai-agents-swiss-knife`.
3. **`uvx`-backed stdio servers**: Sentry and IDA Pro MCP servers.
4. **Docker-backed stdio servers**: GitHub MCP server.
5. **HTTP/streamable-http servers**: local endpoint-based servers such as Agent Maestro. These cannot be launched purely by MCP config, so they will be validated and optionally prestarted through the preflight layer when a known local start path exists.

## 6. File and Component Layout

The design introduces the following support files:

1. `scripts/mcp/launch-server.ps1`
   - Shared stdio entry point.
   - Accepts a logical server key and launches the resolved runtime command.

2. `scripts/mcp/preflight.ps1`
   - Validates runtimes and required secrets.
   - Optionally starts known local prerequisites before the MCP client is opened.

3. `scripts/mcp/check.ps1`
   - Health-check utility for per-server readiness reporting.
   - Safe to run independently of the MCP client.

4. `scripts/mcp/.env.mcp.example`
   - Lists all required secret names and non-secret runtime toggles.
   - Provides a deterministic place to document expected environment variables.

5. `C:\Users\Gabi\.verdent\mcp.json`
   - Remains the client-consumed file.
   - Uses normalized server blocks and references launcher commands or validated endpoints instead of embedding operational complexity.

## 7. Configuration Design

### 7.1 Normalized server shape

Where supported by the client schema, every server block should use a consistent field order and structure:

1. transport-defining fields first (`type` or `command`)
2. `args`
3. `env`
4. `timeout`
5. `disabled`
6. `alwaysAllow`

This is a readability and maintenance improvement only; behavior remains compatible with the existing MCP client expectations.

### 7.2 Secret management

Inline credentials will be removed from the checked-in or user-edited config and replaced with environment-variable references.

Examples of expected variables:

- `GITHUB_PERSONAL_ACCESS_TOKEN`
- `SENTRY_AUTH_TOKEN`
- `NOTION_API_TOKEN`
- `E2B_API_KEY`
- optional runtime toggles such as `GITHUB_TOOLSETS`, `GITHUB_READ_ONLY`, and local endpoint overrides

The launcher and preflight scripts will treat missing required secrets as hard failures for only the affected server, not the entire fleet.

### 7.3 Runtime path resolution

Hard-coded executable paths will be replaced or abstracted where possible:

1. Resolve `node` dynamically instead of pinning a single NVM version path.
2. Resolve `npx` through the active Node installation when a package-backed command must be launched.
3. Preserve direct virtualenv Python paths only where a project-local runtime is intentional and stable.
4. Validate `docker` and `uvx` presence before attempting launch.

## 8. Startup Flow

### 8.1 Standard stdio servers

For stdio-backed servers, the flow is:

1. MCP client starts server entry from `mcp.json`.
2. Entry invokes `launch-server.ps1` with a logical server identifier.
3. Launcher loads environment variables, resolves the runtime, normalizes args, and launches the actual MCP server process.
4. If a required secret or executable is missing, launcher exits quickly with a clear diagnostic.

### 8.2 Local endpoint servers

For local HTTP or streamable-http servers, the flow is:

1. `preflight.ps1` or `check.ps1` validates endpoint reachability before client startup.
2. If a known local start command exists, `preflight.ps1` may launch or wait for the dependency.
3. If no safe automated start path exists, readiness is reported clearly and the endpoint remains declared but unavailable until the dependency is started.

This limitation is explicit because endpoint-based MCP entries cannot self-bootstrap through raw client JSON alone.

## 9. Error Handling and Edge Cases

The design explicitly covers these cases:

1. **Missing secret**
   - Affected server fails fast.
   - Error names the exact missing variable.

2. **Missing runtime** (`node`, `docker`, `uvx`, Python)
   - Health check and launcher both emit actionable installation guidance.

3. **Malformed token or argument**
   - Launcher trims and normalizes values where safe.
   - Known unsafe malformed values are rejected with clear errors.

4. **Pinned path drift**
   - Dynamic runtime resolution avoids failure after Node upgrades or NVM path changes.

5. **Optional/experimental servers**
   - Remain in config.
   - Can stay disabled while still participating in config validation.

6. **Endpoint unavailable**
   - Health check marks the server as unreachable instead of failing silently.

7. **Partial readiness**
   - A failing server does not conceal readiness of the other servers.
   - Validation output is per-server, not all-or-nothing.

## 10. Testing and Verification

### 10.1 Health checks

`scripts/mcp/check.ps1` will verify:

1. required executables are available
2. required environment variables are set
3. referenced files exist
4. local HTTP endpoints respond
5. each server has a valid normalized launch shape

### 10.2 Regression checks

At least one automated regression check will validate the normalized or generated launch metadata so accidental schema drift is caught early.

### 10.3 Operational workflow

Recommended workflow for the user:

1. populate environment variables from `scripts/mcp/.env.mcp.example`
2. run `scripts/mcp/check.ps1`
3. run `scripts/mcp/preflight.ps1` when local dependencies need startup assistance
4. open the MCP client with `mcp.json`

## 11. Optional Additions

The design allows one narrowly scoped reliability addition if needed, but reliability work takes priority over expanding the server fleet.

Preferred additions are features, not unrelated servers:

1. env-template generation
2. grouped readiness reporting
3. startup diagnostics logging
4. normalized runtime classification (Node, Python, Docker, HTTP, experimental)

No optional server should be added unless it directly improves startup verification or operational reliability.

## 12. Rollout Plan

1. Add launcher, preflight, check, and env-template files.
2. Normalize `mcp.json` and move secrets to environment variables.
3. Route stdio-capable entries through the launcher.
4. Add readiness validation for HTTP-based servers.
5. Run health checks and correct per-server failures.
6. Document the final setup procedure.

## 13. Risks and Mitigations

1. **Risk:** Too much wrapper complexity.
   - **Mitigation:** Keep launcher behavior data-driven and centralize repeated logic in one script.

2. **Risk:** Client-specific MCP schema differences.
   - **Mitigation:** Keep `mcp.json` focused on fields already in use; avoid inventing unsupported schema fields.

3. **Risk:** Some HTTP servers may still require external startup.
   - **Mitigation:** Make preflight validation explicit and provide actionable readiness output.

4. **Risk:** Secret migration may temporarily break existing manual workflows.
   - **Mitigation:** Provide `.env.mcp.example` and a documented migration path before removing inline values.

## 14. Success Criteria

This design is successful when:

1. every existing server remains declared
2. no secrets remain inline in `mcp.json`
3. startup failures become diagnosable per server
4. runtime upgrades no longer break all Node-backed MCP entries
5. local prerequisites can be validated or started through a repeatable workflow
6. the config becomes easier to audit and extend without copy-pasted command logic
