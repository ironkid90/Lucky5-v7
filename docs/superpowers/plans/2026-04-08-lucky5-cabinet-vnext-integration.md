# Lucky5 Cabinet VNext Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the approved Lucky5 cabinet vnext bundle into the vanilla JS cabinet with guarded compatibility hardening, debugging hooks, regression coverage, and verification strong enough to support a PR.

**Architecture:** Keep `game.js` authoritative for gameplay and backend interactions, add the new vnext modules as an adapter/debug layer, and route only safe presentation concerns through the orchestrator. Preserve the current portrait cabinet DOM/CSS structure, fix the duplicate `btn-take-score` bug, and add regression checks for wiring, config, and debug surfaces.

**Tech Stack:** Vanilla JavaScript, HTML, CSS, ASP.NET Core static assets, custom C# console regression tests, Node syntax checks, browser smoke verification

---

### Task 1: Add Regression Coverage For VNext Wiring

**Files:**
- Modify: `server/tests/Lucky5.Tests/FrontendRegressionTests.cs`
- Test: `server/tests/Lucky5.Tests/Lucky5.Tests.csproj`

- [ ] **Step 1: Add failing regression assertions for the vnext integration**

```csharp
Assert(
    failures,
    "index.html should load the vnext cabinet adapter scripts",
    indexHtml.Contains("/js/cabinet-state-vnext.js", StringComparison.Ordinal)
        && indexHtml.Contains("/js/cabinet-audio-vnext.js", StringComparison.Ordinal)
        && indexHtml.Contains("/js/cabinet-transition-vnext.js", StringComparison.Ordinal)
        && indexHtml.Contains("/js/cabinet-orchestrator-vnext.js", StringComparison.Ordinal));

Assert(
    failures,
    "index.html should load the cabinet frame stylesheet",
    indexHtml.Contains("/css/cabinet-frame-vnext.css", StringComparison.Ordinal));

Assert(
    failures,
    "index.html should only define one take-score button id",
    Regex.Matches(indexHtml, "id=\"btn-take-score\"", RegexOptions.CultureInvariant).Count == 1);

Assert(
    failures,
    "game-config.js should define cabinet layout and audio event config for the vnext modules",
    gameConfigJs.Contains("cabinet: Object.freeze(", StringComparison.Ordinal)
        && gameConfigJs.Contains("audio: Object.freeze(", StringComparison.Ordinal));

Assert(
    failures,
    "cabinet-orchestrator-vnext.js should expose render_game_to_text and advanceTime debug hooks",
    orchestratorJs.Contains("window.render_game_to_text = function renderGameToText()", StringComparison.Ordinal)
        && orchestratorJs.Contains("window.advanceTime = function advanceTime(ms)", StringComparison.Ordinal));
```

- [ ] **Step 2: Extend test setup to read the new JS file and config file content**

```csharp
string gameConfigJs;
string orchestratorJs;
try
{
    gameConfigJs = await File.ReadAllTextAsync(ResolveWwwrootFilePath("js", "game-config.js"));
    orchestratorJs = await File.ReadAllTextAsync(ResolveWwwrootFilePath("js", "cabinet-orchestrator-vnext.js"));
}
catch (Exception ex)
{
    failures.Add($"Frontend regression setup failed: {ex.Message}");
    return;
}
```

- [ ] **Step 3: Run the frontend regression suite and verify the new checks fail before implementation**

Run:

```powershell
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Expected:

```text
FAIL ... index.html should load the vnext cabinet adapter scripts
FAIL ... index.html should load the cabinet frame stylesheet
FAIL ... index.html should only define one take-score button id
```

- [ ] **Step 4: Commit the failing test scaffold**

```bash
git add server/tests/Lucky5.Tests/FrontendRegressionTests.cs
git commit -m "test: add Lucky5 vnext integration regression coverage"
```

### Task 2: Integrate Bundle Assets, Markup, And Config

**Files:**
- Create: `server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js`
- Create: `server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js`
- Create: `server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js`
- Create: `server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js`
- Create: `server/src/Lucky5.Api/wwwroot/css/cabinet-frame-vnext.css`
- Modify: `server/src/Lucky5.Api/wwwroot/index.html`
- Modify: `server/src/Lucky5.Api/wwwroot/js/game-config.js`

- [ ] **Step 1: Copy the bundle modules into the live cabinet tree**

Run:

```powershell
Copy-Item 'plans/lucky5_refactor_patch/js/cabinet-state-vnext.js' 'server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js'
Copy-Item 'plans/lucky5_refactor_patch/js/cabinet-audio-vnext.js' 'server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js'
Copy-Item 'plans/lucky5_refactor_patch/js/cabinet-transition-vnext.js' 'server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js'
Copy-Item 'plans/lucky5_refactor_patch/js/cabinet-orchestrator-vnext.js' 'server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js'
Copy-Item 'plans/lucky5_refactor_patch/css/cabinet-frame-vnext.css' 'server/src/Lucky5.Api/wwwroot/css/cabinet-frame-vnext.css'
```

- [ ] **Step 2: Update `index.html` to fix duplicate markup and load the new assets**

```html
<link rel="stylesheet" href="/css/cabinet-shell-vnext.css?v=1">
<link rel="stylesheet" href="/css/cabinet-frame-vnext.css?v=1">
...
<div id="bottom-row" data-zone="bottom-row" class="bottom-row">
    <button id="btn-take-half" class="cab-btn cab-takehalf"></button>
    <button id="btn-menu" class="cab-btn cab-menu"></button>
    <button id="btn-take-score" class="cab-btn cab-takescore"></button>
</div>
...
<script src="/js/cabinet-stage-vnext.js?v=1"></script>
<script src="/js/cabinet-pace-vnext.js?v=1"></script>
<script src="/js/cabinet-shell-vnext.js?v=1"></script>
<script src="/js/cabinet-state-vnext.js?v=1"></script>
<script src="/js/cabinet-audio-vnext.js?v=1"></script>
<script src="/js/cabinet-transition-vnext.js?v=1"></script>
<script src="/js/cabinet-orchestrator-vnext.js?v=1"></script>
```

- [ ] **Step 3: Extend `game-config.js` with the cabinet layout and audio sections expected by the bundle**

```javascript
cabinet: Object.freeze({
    fps: 60,
    layout: Object.freeze({
        width: 720,
        height: 1280,
        zones: Object.freeze({
            paytable: Object.freeze({ left: 8, top: 8, width: 350, height: 250 }),
            counters: Object.freeze({ left: 505, top: 8, width: 190, height: 185 }),
            cards: Object.freeze({ left: 8, top: 238, width: 705, height: 270 }),
            machine: Object.freeze({ left: 8, top: 505, width: 705, height: 120 }),
            controls: Object.freeze({ left: 0, top: 640, width: 720, height: 640 })
        })
    })
}),
...
audio: Object.freeze({
    events: Object.freeze({
        press:        Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.30, priority: 'normal' }),
        invalid:      Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.18, priority: 'high' }),
        deal:         Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.24, priority: 'normal' }),
        draw:         Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.24, priority: 'normal' }),
        collect:      Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.20, priority: 'low' }),
        lucky5:       Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.40, priority: 'high' }),
        machineClose: Object.freeze({ src: '/assets/sounds/press.mp3', volume: 0.40, priority: 'high' })
    })
}),
```

- [ ] **Step 4: Run syntax checks on the new assets**

Run:

```powershell
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/game-config.js
```

Expected:

```text
(no output from node --check; exit code 0 for each file)
```

- [ ] **Step 5: Run the regression suite and verify the wiring/config checks now pass**

Run:

```powershell
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Expected:

```text
PASS ... index.html should load the vnext cabinet adapter scripts
PASS ... index.html should load the cabinet frame stylesheet
PASS ... index.html should only define one take-score button id
```

- [ ] **Step 6: Commit the asset/config/markup integration**

```bash
git add server/src/Lucky5.Api/wwwroot/index.html server/src/Lucky5.Api/wwwroot/js/game-config.js server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js server/src/Lucky5.Api/wwwroot/css/cabinet-frame-vnext.css
git commit -m "feat: integrate Lucky5 cabinet vnext runtime"
```

### Task 3: Harden Orchestrator Compatibility With The Existing Cabinet

**Files:**
- Modify: `server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js`
- Modify: `server/src/Lucky5.Api/wwwroot/css/cabinet-frame-vnext.css`
- Modify: `server/tests/Lucky5.Tests/FrontendRegressionTests.cs`

- [ ] **Step 1: Add regression checks for guarded patching and soft install behavior**

```csharp
Assert(
    failures,
    "cabinet-orchestrator-vnext.js should guard patching behind function existence checks",
    orchestratorJs.Contains("if (typeof window[name] === 'function' || typeof globalThis[name] === 'function')", StringComparison.Ordinal));

Assert(
    failures,
    "cabinet-orchestrator-vnext.js should keep original functions available for debugging",
    orchestratorJs.Contains("const originals = {};", StringComparison.Ordinal)
        && orchestratorJs.Contains("return {\n        install,\n        originals", StringComparison.Ordinal));
```

- [ ] **Step 2: Run the regression suite and verify the new compatibility checks fail before hardening edits**

Run:

```powershell
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Expected:

```text
FAIL ... cabinet-orchestrator-vnext.js should guard patching behind function existence checks
```

- [ ] **Step 3: Harden the orchestrator install/patch path without changing gameplay authority**

```javascript
function _patch(name, replacement) {
    if (typeof window[name] === 'function' || typeof globalThis[name] === 'function') {
        const current = globalThis[name];
        originals[name] = current;
        globalThis[name] = replacement(current);
    }
}

function install() {
    if (installed) return;
    installed = true;
    if (!window.CabinetState || !window.CabinetTransition) return;
    CabinetState.syncFromRuntime();
    CabinetAudio?.preload?.();
    _installGeometry();
    _installDebugHooks();
    _installInputGuards();
}
```

- [ ] **Step 4: Narrow frame CSS if it conflicts with the existing cabinet layout**

```css
#game-container {
    width: var(--cabinet-width);
    height: var(--cabinet-height);
    position: relative;
    overflow: hidden;
    transform: scale(var(--cabinet-scale));
    transform-origin: center center;
}

.menu-panel {
    z-index: 10000;
}
```

- [ ] **Step 5: Run syntax checks and regression tests again**

Run:

```powershell
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Expected:

```text
PASS ... cabinet-orchestrator-vnext.js should guard patching behind function existence checks
PASS ... cabinet-orchestrator-vnext.js should keep original functions available for debugging
```

- [ ] **Step 6: Commit the compatibility hardening**

```bash
git add server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js server/src/Lucky5.Api/wwwroot/css/cabinet-frame-vnext.css server/tests/Lucky5.Tests/FrontendRegressionTests.cs
git commit -m "fix: harden Lucky5 cabinet vnext compatibility"
```

### Task 4: End-To-End Verification And PR Preparation

**Files:**
- Modify: `tmp/summary-<timestamp>.json`
- Modify: `C:/Users/Gabi/.codex/memory.json`

- [ ] **Step 1: Run the full verification suite**

Run:

```powershell
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/game-config.js
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Expected:

```text
all node --check commands exit 0
Lucky5.Tests reports 0 failures
```

- [ ] **Step 2: Run a browser smoke pass against the cabinet**

Verify manually:

```text
1. Login or restore session to the lobby
2. Select a machine and enter the game
3. Deal a hand and confirm card cadence and button gating
4. Draw with holds and confirm state sync remains correct
5. Enter double-up and confirm trail/dealer/challenger updates still render
6. Open and close the menu, then return to lobby
7. Call window.render_game_to_text() in devtools and confirm structured output
8. Call window.advanceTime(1000) and confirm debug response object shape
```

- [ ] **Step 3: Record artifacts and final repo state**

Run:

```powershell
git status -sb
git log --oneline -5
```

Expected:

```text
working tree contains only intended changes
recent commits show tests, integration, and compatibility hardening
```

- [ ] **Step 4: Create the implementation summary artifact**

```json
{
  "task": "Lucky5 cabinet vnext integration",
  "verification": ["node --check ...", "dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj", "browser smoke pass"],
  "outcome": "ready_for_pr"
}
```

- [ ] **Step 5: Prepare the PR commit range and push**

```bash
git checkout -b feat/lucky5-cabinet-vnext-integration
git push -u origin feat/lucky5-cabinet-vnext-integration
```

- [ ] **Step 6: Open the pull request**

```text
Title: feat: integrate Lucky5 cabinet vnext frontend runtime

Body:
- add state/audio/transition/orchestrator cabinet runtime modules
- wire cabinet frame css and config into the vanilla JS cabinet
- harden orchestrator compatibility with current Lucky5 runtime
- add regression coverage for wiring, config, and debug hooks
- verify with syntax checks, Lucky5.Tests, and browser smoke checks
```
