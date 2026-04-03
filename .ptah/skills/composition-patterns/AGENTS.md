# React Composition Patterns

**Version 1.0.0**  
Engineering  
January 2026

> **Note:**  
> This document is mainly for agents and LLMs to follow when maintaining,  
> generating, or refactoring React codebases using composition. Humans  
> may also find it useful, but guidance here is optimized for automation  
> and consistency by AI-assisted workflows.

---

## Abstract

Composition patterns for building flexible, maintainable React components. Avoid boolean prop proliferation by using compound components, lifting state, and composing internals. These patterns make codebases easier for both humans and AI agents to work with as they scale.

---

## Table of Contents

1. [Component Architecture](#1-component-architecture) — **HIGH**
   - 1.1 [Avoid Boolean Prop Proliferation](#11-avoid-boolean-prop-proliferation)
   - 1.2 [Use Compound Components](#12-use-compound-components)
2. [State Management](#2-state-management) — **MEDIUM**
   - 2.1 [Decouple State Management from UI](#21-decouple-state-management-from-ui)
   - 2.2 [Define Generic Context Interfaces for Dependency Injection](#22-define-generic-context-interfaces-for-dependency-injection)
   - 2.3 [Lift State into Provider Components](#23-lift-state-into-provider-components)
3. [Implementation Patterns](#3-implementation-patterns) — **MEDIUM**
   - 3.1 [Create Explicit Component Variants](#31-create-explicit-component-variants)
   - 3.2 [Prefer Composing Children Over Render Props](#32-prefer-composing-children-over-render-props)
4. [React 19 APIs](#4-react-19-apis) — **MEDIUM**
   - 4.1 [React 19 API Changes](#41-react-19-api-changes)

---

## 1. Component Architecture

**Impact: HIGH**

Fundamental patterns for structuring components to avoid prop
proliferation and enable flexible composition.

### 1.1 Avoid Boolean Prop Proliferation

**Impact: CRITICAL (prevents unmaintainable component variants)**

Don't add boolean props like `isThread`, `isEditing`, `isDMThread` to customize

component behavior. Each boolean doubles possible states and creates

unmaintainable conditional logic. Use composition instead.

**Incorrect: boolean props create exponential complexity**

```tsx
function Composer({ onSubmit, isThread, channelId, isDMThread, dmId, isEditing, isForwarding }: Props) {
  return (
    <form>
      <Header />
      <Input />
      {isDMThread ? <AlsoSendToDMField id={dmId} /> : isThread ? <AlsoSendToChannelField id={channelId} /> : null}
      {isEditing ? <EditActions /> : isForwarding ? <ForwardActions /> : <DefaultActions />}
      <Footer onSubmit={onSubmit} />
    </form>
  );
}
```

**Correct: composition eliminates conditionals**

```tsx
// Channel composer
function ChannelComposer() {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <Composer.Footer>
        <Composer.Attachments />
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  );
}

// Thread composer - adds "also send to channel" field
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <AlsoSendToChannelField id={channelId} />
      <Composer.Footer>
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  );
}

// Edit composer - different footer actions
function EditComposer() {
  return (
    <Composer.Frame>
      <Composer.Input />
      <Composer.Footer>
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.CancelEdit />
        <Composer.SaveEdit />
      </Composer.Footer>
    </Composer.Frame>
  );
}
```

Each variant is explicit about what it renders. We can share internals without

sharing a single monolithic parent.

### 1.2 Use Compound Components

**Impact: HIGH (enables flexible composition without prop drilling)**

Structure complex components as compound components with a shared context. Each

subcomponent accesses shared state via context, not props. Consumers compose the

pieces they need.

**Incorrect: monolithic component with render props**

```tsx
function Composer({ renderHeader, renderFooter, renderActions, showAttachments, showFormatting, showEmojis }: Props) {
  return (
    <form>
      {renderHeader?.()}
      <Input />
      {showAttachments && <Attachments />}
      {renderFooter ? (
        renderFooter()
      ) : (
        <Footer>
          {showFormatting && <Formatting />}
          {showEmojis && <Emojis />}
          {renderActions?.()}
        </Footer>
      )}
    </form>
  );
}
```

**Correct: compound components with shared context**

```tsx
const ComposerContext = createContext<ComposerContextValue | null>(null);

function ComposerProvider({ children, state, actions, meta }: ProviderProps) {
  return <ComposerContext value={{ state, actions, meta }}>{children}</ComposerContext>;
}

function ComposerFrame({ children }: { children: React.ReactNode }) {
  return <form>{children}</form>;
}

function ComposerInput() {
  const {
    state,
    actions: { update },
    meta: { inputRef },
  } = use(ComposerContext);
  return <TextInput ref={inputRef} value={state.input} onChangeText={(text) => update((s) => ({ ...s, input: text }))} />;
}

function ComposerSubmit() {
  const {
    actions: { submit },
  } = use(ComposerContext);
  return <Button onPress={submit}>Send</Button>;
}

// Export as compound component
const Composer = {
  Provider: ComposerProvider,
  Frame: ComposerFrame,
  Input: ComposerInput,
  Submit: ComposerSubmit,
  Header: ComposerHeader,
  Footer: ComposerFooter,
  Attachments: ComposerAttachments,
  Formatting: ComposerFormatting,
  Emojis: ComposerEmojis,
};
```

**Usage:**

```tsx
<Composer.Provider state={state} actions={actions} meta={meta}>
  <Composer.Frame>
    <Composer.Header />
    <Composer.Input />
    <Composer.Footer>
      <Composer.Formatting />
      <Composer.Submit />
    </Composer.Footer>
  </Composer.Frame>
</Composer.Provider>
```

Consumers explicitly compose exactly what they need. No hidden conditionals. And the state, actions and meta are dependency-injected by a parent provider, allowing multiple usages of the same component structure.

---

## 2. State Management

**Impact: MEDIUM**

Patterns for lifting state and managing shared context across
composed components.

### 2.1 Decouple State Management from UI

**Impact: MEDIUM (enables swapping state implementations without changing UI)**

The provider component should be the only place that knows how state is managed.

UI components consume the context interface—they don't know if state comes from

useState, Zustand, or a server sync.

**Incorrect: UI coupled to state implementation**

```tsx
function ChannelComposer({ channelId }: { channelId: string }) {
  // UI component knows about global state implementation
  const state = useGlobalChannelState(channelId);
  const { submit, updateInput } = useChannelSync(channelId);

  return (
    <Composer.Frame>
      <Composer.Input value={state.input} onChange={(text) => sync.updateInput(text)} />
      <Composer.Submit onPress={() => sync.submit()} />
    </Composer.Frame>
  );
}
```

**Correct: state management isolated in provider**

```tsx
// Provider handles all state management details
function ChannelProvider({ channelId, children }: { channelId: string; children: React.ReactNode }) {
  const { state, update, submit } = useGlobalChannel(channelId);
  const inputRef = useRef(null);

  return (
    <Composer.Provider state={state} actions={{ update, submit }} meta={{ inputRef }}>
      {children}
    </Composer.Provider>
  );
}

// UI component only knows about the context interface
function ChannelComposer() {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <Composer.Footer>
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  );
}

// Usage
function Channel({ channelId }: { channelId: string }) {
  return (
    <ChannelProvider channelId={channelId}>
      <ChannelComposer />
    </ChannelProvider>
  );
}
```

**Different providers, same UI:**

```tsx
// Local state for ephemeral forms
function ForwardMessageProvider({ children }) {
  const [state, setState] = useState(initialState);
  const forwardMessage = useForwardMessage();

  return (
    <Composer.Provider state={state} actions={{ update: setState, submit: forwardMessage }}>
      {children}
    </Composer.Provider>
  );
}

// Global synced state for channels
function ChannelProvider({ channelId, children }) {
  const { state, update, submit } = useGlobalChannel(channelId);

  return (
    <Composer.Provider state={state} actions={{ update, submit }}>
      {children}
    </Composer.Provider>
  );
}
```

The same `Composer.Input` component works with both providers because it only

depends on the context interface, not the implementation.

### 2.2 Define Generic Context Interfaces for Dependency Injection

**Impact: HIGH (enables dependency-injectable state across use-cases)**

Define a **generic interface** for your component context with three parts:

`state`, `actions`, and `meta`. This interface is a contract that any provider

can implement—enabling the same UI components to work with completely different

state implementations.

**Core principle:** Lift state, compose internals, make state

dependency-injectable.

**Incorrect: UI coupled to specific state implementation**

```tsx
function ComposerInput() {
  // Tightly coupled to a specific hook
  const { input, setInput } = useChannelComposerState();
  return <TextInput value={input} onChangeText={setInput} />;
}
```

**Correct: generic interface enables dependency injection**

```tsx
// Define a GENERIC interface that any provider can implement
interface ComposerState {
  input: string;
  attachments: Attachment[];
  isSubmitting: boolean;
}

interface ComposerActions {
  update: (updater: (state: ComposerState) => ComposerState) => void;
  submit: () => void;
}

interface ComposerMeta {
  inputRef: React.RefObject<TextInput>;
}

interface ComposerContextValue {
  state: ComposerState;
  actions: ComposerActions;
  meta: ComposerMeta;
}

const ComposerContext = createContext<ComposerContextValue | null>(null);
```

**UI components consume the interface, not the implementation:**

```tsx
function ComposerInput() {
  const {
    state,
    actions: { update },
    meta,
  } = use(ComposerContext);

  // This component works with ANY provider that implements the interface
  return <TextInput ref={meta.inputRef} value={state.input} onChangeText={(text) => update((s) => ({ ...s, input: text }))} />;
}
```

**Different providers implement the same interface:**

```tsx
// Provider A: Local state for ephemeral forms
function ForwardMessageProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState(initialState);
  const inputRef = useRef(null);
  const submit = useForwardMessage();

  return (
    <ComposerContext
      value={{
        state,
        actions: { update: setState, submit },
        meta: { inputRef },
      }}
    >
      {children}
    </ComposerContext>
  );
}

// Provider B: Global synced state for channels
function ChannelProvider({ channelId, children }: Props) {
  const { state, update, submit } = useGlobalChannel(channelId);
  const inputRef = useRef(null);

  return (
    <ComposerContext
      value={{
        state,
        actions: { update, submit },
        meta: { inputRef },
      }}
    >
      {children}
    </ComposerContext>
  );
}
```

**The same composed UI works with both:**

```tsx
// Works with ForwardMessageProvider (local state)
<ForwardMessageProvider>
  <Composer.Frame>
    <Composer.Input />
    <Composer.Submit />
  </Composer.Frame>
</ForwardMessageProvider>

// Works with ChannelProvider (global synced state)
<ChannelProvider channelId="abc">
  <Composer.Frame>
    <Composer.Input />
    <Composer.Submit />
  </Composer.Frame>
</ChannelProvider>
```

**Custom UI outside the component can access state and actions:**

```tsx
function ForwardMessageDialog() {
  return (
    <ForwardMessageProvider>
      <Dialog>
        {/* The composer UI */}
        <Composer.Frame>
          <Composer.Input placeholder="Add a message, if you'd like." />
          <Composer.Footer>
            <Composer.Formatting />
            <Composer.Emojis />
          </Composer.Footer>
        </Composer.Frame>

        {/* Custom UI OUTSIDE the composer, but INSIDE the provider */}
        <MessagePreview />

        {/* Actions at the bottom of the dialog */}
        <DialogActions>
          <CancelButton />
          <ForwardButton />
        </DialogActions>
      </Dialog>
    </ForwardMessageProvider>
  );
}

// This button lives OUTSIDE Composer.Frame but can still submit based on its context!
function ForwardButton() {
  const {
    actions: { submit },
  } = use(ComposerContext);
  return <Button onPress={submit}>Forward</Button>;
}

// This preview lives OUTSIDE Composer.Frame but can read composer's state!
function MessagePreview() {
  const { state } = use(ComposerContext);
  return <Preview message={state.input} attachments={state.attachments} />;
}
```

The provider boundary is what matters—not the visual nesting. Components that

need shared state don't have to be inside the `Composer.Frame`. They just need

to be within the provider.

The `ForwardButton` and `MessagePreview` are not visually inside the composer

box, but they can still access its state and actions. This is the power of

lifting state into providers.

The UI is reusable bits you compose together. The state is dependency-injected

by the provider. Swap the provider, keep the UI.

### 2.3 Lift State into Provider Components

**Impact: HIGH (enables state sharing outside component boundaries)**

Move state management into dedicated provider components. This allows sibling

components outside the main UI to access and modify state without prop drilling

or awkward refs.

**Incorrect: state trapped inside component**

```tsx
function ForwardMessageComposer() {
  const [state, setState] = useState(initialState);
  const forwardMessage = useForwardMessage();

  return (
    <Composer.Frame>
      <Composer.Input />
      <Composer.Footer />
    </Composer.Frame>
  );
}

// Problem: How does this button access composer state?
function ForwardMessageDialog() {
  return (
    <Dialog>
      <ForwardMessageComposer />
      <MessagePreview /> {/* Needs composer state */}
      <DialogActions>
        <CancelButton />
        <ForwardButton /> {/* Needs to call submit */}
      </DialogActions>
    </Dialog>
  );
}
```

**Incorrect: useEffect to sync state up**

```tsx
function ForwardMessageDialog() {
  const [input, setInput] = useState('');
  return (
    <Dialog>
      <ForwardMessageComposer onInputChange={setInput} />
      <MessagePreview input={input} />
    </Dialog>
  );
}

function ForwardMessageComposer({ onInputChange }) {
  const [state, setState] = useState(initialState);
  useEffect(() => {
    onInputChange(state.input); // Sync on every change 😬
  }, [state.input]);
}
```

**Incorrect: reading state from ref on submit**

```tsx
function ForwardMessageDialog() {
  const stateRef = useRef(null);
  return (
    <Dialog>
      <ForwardMessageComposer stateRef={stateRef} />
      <ForwardButton onPress={() => submit(stateRef.current)} />
    </Dialog>
  );
}
```

**Correct: state lifted to provider**

```tsx
function ForwardMessageProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState(initialState);
  const forwardMessage = useForwardMessage();
  const inputRef = useRef(null);

  return (
    <Composer.Provider state={state} actions={{ update: setState, submit: forwardMessage }} meta={{ inputRef }}>
      {children}
    </Composer.Provider>
  );
}

function ForwardMessageDialog() {
  return (
    <ForwardMessageProvider>
      <Dialog>
        <ForwardMessageComposer />
        <MessagePreview /> {/* Custom components can access state and actions */}
        <DialogActions>
          <CancelButton />
          <ForwardButton /> {/* Custom components can access state and actions */}
        </DialogActions>
      </Dialog>
    </ForwardMessageProvider>
  );
}

function ForwardButton() {
  const { actions } = use(Composer.Context);
  return <Button onPress={actions.submit}>Forward</Button>;
}
```

The ForwardButton lives outside the Composer.Frame but still has access to the

submit action because it's within the provider. Even though it's a one-off

component, it can still access the composer's state and actions from outside the

UI itself.

**Key insight:** Components that need shared state don't have to be visually

nested inside each other—they just need to be within the same provider.

---

## 3. Implementation Patterns

**Impact: MEDIUM**

Specific techniques for implementing compound components and
context providers.

### 3.1 Create Explicit Component Variants

**Impact: MEDIUM (self-documenting code, no hidden conditionals)**

Instead of one component with many boolean props, create explicit variant

components. Each variant composes the pieces it needs. The code documents

itself.

**Incorrect: one component, many modes**

```tsx
// What does this component actually render?
<Composer isThread isEditing={false} channelId="abc" showAttachments showFormatting={false} />
```

**Correct: explicit variants**

```tsx
// Immediately clear what this renders
<ThreadComposer channelId="abc" />

// Or
<EditMessageComposer messageId="xyz" />

// Or
<ForwardMessageComposer messageId="123" />
```

Each implementation is unique, explicit and self-contained. Yet they can each

use shared parts.

**Implementation:**

```tsx
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <ThreadProvider channelId={channelId}>
      <Composer.Frame>
        <Composer.Input />
        <AlsoSendToChannelField channelId={channelId} />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.Submit />
        </Composer.Footer>
      </Composer.Frame>
    </ThreadProvider>
  );
}

function EditMessageComposer({ messageId }: { messageId: string }) {
  return (
    <EditMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.CancelEdit />
          <Composer.SaveEdit />
        </Composer.Footer>
      </Composer.Frame>
    </EditMessageProvider>
  );
}

function ForwardMessageComposer({ messageId }: { messageId: string }) {
  return (
    <ForwardMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input placeholder="Add a message, if you'd like." />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.Mentions />
        </Composer.Footer>
      </Composer.Frame>
    </ForwardMessageProvider>
  );
}
```

Each variant is explicit about:

- What provider/state it uses

- What UI elements it includes

- What actions are available

No boolean prop combinations to reason about. No impossible states.

### 3.2 Prefer Composing Children Over Render Props

**Impact: MEDIUM (cleaner composition, better readability)**

Use `children` for composition instead of `renderX` props. Children are more

readable, compose naturally, and don't require understanding callback

signatures.

**Incorrect: render props**

```tsx
function Composer({ renderHeader, renderFooter, renderActions }: { renderHeader?: () => React.ReactNode; renderFooter?: () => React.ReactNode; renderActions?: () => React.ReactNode }) {
  return (
    <form>
      {renderHeader?.()}
      <Input />
      {renderFooter ? renderFooter() : <DefaultFooter />}
      {renderActions?.()}
    </form>
  );
}

// Usage is awkward and inflexible
return (
  <Composer
    renderHeader={() => <CustomHeader />}
    renderFooter={() => (
      <>
        <Formatting />
        <Emojis />
      </>
    )}
    renderActions={() => <SubmitButton />}
  />
);
```

**Correct: compound components with children**

```tsx
function ComposerFrame({ children }: { children: React.ReactNode }) {
  return <form>{children}</form>;
}

function ComposerFooter({ children }: { children: React.ReactNode }) {
  return <footer className="flex">{children}</footer>;
}

// Usage is flexible
return (
  <Composer.Frame>
    <CustomHeader />
    <Composer.Input />
    <Composer.Footer>
      <Composer.Formatting />
      <Composer.Emojis />
      <SubmitButton />
    </Composer.Footer>
  </Composer.Frame>
);
```

**When render props are appropriate:**

```tsx
// Render props work well when you need to pass data back
<List data={items} renderItem={({ item, index }) => <Item item={item} index={index} />} />
```

Use render props when the parent needs to provide data or state to the child.

Use children when composing static structure.

---

## 4. React 19 APIs

**Impact: MEDIUM**

React 19+ only. Don't use `forwardRef`; use `use()` instead of `useContext()`.

### 4.1 React 19 API Changes

**Impact: MEDIUM (cleaner component definitions and context usage)**

> **⚠️ React 19+ only.** Skip this if you're on React 18 or earlier.

In React 19, `ref` is now a regular prop (no `forwardRef` wrapper needed), and `use()` replaces `useContext()`.

**Incorrect: forwardRef in React 19**

```tsx
const ComposerInput = forwardRef<TextInput, Props>((props, ref) => {
  return <TextInput ref={ref} {...props} />;
});
```

**Correct: ref as a regular prop**

```tsx
function ComposerInput({ ref, ...props }: Props & { ref?: React.Ref<TextInput> }) {
  return <TextInput ref={ref} {...props} />;
}
```

**Incorrect: useContext in React 19**

```tsx
const value = useContext(MyContext);
```

**Correct: use instead of useContext**

```tsx
const value = use(MyContext);
```

`use()` can also be called conditionally, unlike `useContext()`.

---

## References

1. [https://react.dev](https://react.dev)
2. [https://react.dev/learn/passing-data-deeply-with-context](https://react.dev/learn/passing-data-deeply-with-context)
3. [https://react.dev/reference/react/use](https://react.dev/reference/react/use)
 
Durable agent contract for this repository. Keep this file compact, reusable, and focused on behavior that improves long-run agent quality. 
 
## Mission 
- Optimize for correctness, safety, reversibility, context efficiency, and maintainability. 
- Prefer durable workflow rules over tool dumps, copied docs, or temporary task notes. 
- Treat AGENTS.md as policy, not as a scratchpad or knowledge base. 
 
## Default Operating Loop 
1. Restate the objective and success criteria briefly. 
2. Inspect the repo and runtime before editing anything. 
3. Read only the files needed for the task. 
4. Make a short plan when the work is non-trivial. 
5. Implement the smallest change that solves the problem. 
6. Verify with the tightest relevant checks. 
7. Report what changed, what was verified, assumptions, and remaining risk. 
## Core Behavior Rules 
- Never invent file contents, command results, tests, runtime state, or tool capabilities. 
- Inspect before editing. Verify after editing. 
- Prefer reversible actions and previews before risky operations. 
- Preserve existing project conventions unless the task explicitly changes them. 
- Make local, minimal edits instead of broad rewrites unless a rewrite is the task. 
- Do not revert unrelated user changes. 
- Ask only when blocked on a truly risky unknown; otherwise make a reasonable assumption and state it. 
 
## Context And Memory Discipline 
- Keep active context lean. Search first, then open only the relevant files and line ranges. 
- Prefer local source-of-truth docs over memory or guesswork. 
- Do not paste large logs, generated files, external docs, or tool schemas into AGENTS.md or chat unless they are necessary. 
- Summarize bulky output instead of carrying it forward verbatim. 
- Offload large transient output to task artifacts under `tmp/` when useful instead of keeping it in live context. 
- After meaningful tasks, update `C:/Users/Gabi/.codex/memory.json` with current objective, environment facts, decisions, open questions, and next steps. 
- After meaningful tasks, write `tmp/summary-<timestamp>.json` with edits, commands, verification, and outcome. 
## Tool Strategy 
- Use the smallest toolset that can complete the task well. 
- Prefer fast targeted search tools such as `rg` or equivalent. 
- Use explicit working directories for shell commands. 
- Prefer shared local MCP wrappers and existing repo scripts when they help. 
- For third-party libraries, prefer current official docs rather than stale recollection. 
- Do not serialize raw tool catalogs or copied vendor docs into repo instruction files. 
 
## Editing And Verification 
- Keep changes ASCII unless the file already requires Unicode. 
- Add comments only when they clarify non-obvious logic. 
- Validate with the smallest relevant check: build, test, lint, typecheck, smoke test, or targeted script. 
- If verification cannot run, say so and provide the exact command that should be run next. 
- Never claim a fix is complete without evidence from inspection or verification. 
 
## Safety Rules 
- Confirm before destructive or high-risk actions such as deleting data, rewriting git history, force-pushing, registry edits, production deploys, or cloud deletions. 
- Prefer dry runs such as `-WhatIf`, preview modes, or read-only inspection before mutation. 
## Lucky5 Repo Invariants 
- `docs/` is the active source of truth for product and engineering behavior. 
- `sources/` contains decompiled reference material only; never edit it. 
- Tests run with `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`, not `dotnet test`. 
- Authoritative game logic belongs in `server/src/Lucky5.Domain/Game/CleanRoom/` and must stay deterministic. 
- The backend is authoritative for balance, machine state, session state, and realtime behavior. 
- The current persistence model is in-memory; do not assume a real database exists. 
- Preserve the retro cabinet feel; do not modernize the product into a generic casino UI. 
- Prefer the web cabinet as the primary playable target before Flutter or mobile-specific work unless the task says otherwise. 
 
## Repo Routing 
- Root AGENTS.md provides the default contract for the whole repo. 
- For subsystem detail, read the nearest local `CLAUDE.md` or nested instruction file before making deeper changes. 
## Smart General Defaults 
- Favor search-driven discovery over loading entire files or directories. 
- Prefer narrow diffs, stable interfaces, and changes that make future agent work easier. 
- When touching workflows or tooling, improve reproducibility, naming, logging, and failure clarity. 
- When touching docs, keep them actionable and aligned with the current repo reality. 
- When tasks span coding, docs, infra, automation, or local ops, use the same workflow: inspect, plan, implement minimally, verify, summarize. 
 
## Anti-Bloat Maintenance Rule 
Never let this file grow into a prompt dump again. 
 
Do not paste any of the following into AGENTS.md: 
- external documentation 
- API references 
- vendor tool catalogs 
- raw prompts or session transcripts 
- giant command outputs or logs 
- copied schemas or generated content 
 
## Reinforcements 
- Keep the summary artifact step explicit after meaningful tasks. 
- If memory, MCP, or helper tools are unavailable, fall back cleanly to direct repo inspection. 
- Never expose secrets, tokens, private keys, session data, or sensitive personal information. 
- High-value local context files include `docs/CLAUDE.md`, `src/web/CLAUDE.md`, `server/src/Lucky5.Api/CLAUDE.md`, `server/src/Lucky5.Domain/Game/CleanRoom/CLAUDE.md`, and `server/tests/CLAUDE.md`. 

Follow Agents.md  Claude.md  Gemini.md etc # Unified Engineering + PC Ops Agent Instructions

This is the **global default** instruction set. To override for a specific project, add a more specific `AGENTS.md` inside that project folder (more specific files take precedence).

You are an expert engineering and PC-operations agent for coding, automation, and system orchestration across Windows and Linux.
Primary domains: PowerShell, Bash, Python, Node/TS, Git, CI/testing, Azure/Bicep, local files (docs/spreadsheets), and safe desktop/server operations.

## Mission & Priorities
- Mission: deliver correct, safe, reproducible outcomes end-to-end (not just advice).
- Priorities (in order): correctness & safety → reproducibility → clarity → performance/efficiency.
- Treat every command as a real-world action with side effects. Default to reversible steps.

## Safety & Trust (Non-Negotiables)
- Never leak secrets: no tokens, passwords, API keys, private keys, session cookies, or sensitive personal data.
- Confirm before destructive or risky actions:
  - deleting files, `rm -rf`, `Remove-Item -Recurse -Force`
  - formatting disks, changing partitions, registry edits, driver installs
  - `git reset --hard`, rewriting history, force-push
  - cloud resource deletion, IAM changes, production deploys
- Prefer dry-runs / previews:
  - Azure: `what-if` before `apply`
  - PowerShell: `-WhatIf` where available
  - package changes: show the plan and impact before executing
- If operating in a sandbox or constrained environment, stay within it unless explicitly escalated.

## Anti-Hallucination & Reality Checks
- Do not invent: file contents, command outputs, flags, API responses, test results, or environment state.
- Inspect before editing: read files, check repo status, confirm paths, confirm OS/shell.
- Verify after editing: run the smallest relevant checks (tests, lint, typecheck, build, `--what-if`), and report results.
- If you cannot run verification, provide exact commands and expected signals of success/failure.

## Autonomy, Assumptions, and Questions
- Be proactive: gather context → implement → verify → report in one pass when feasible.
- Ask only questions that unblock correctness or safety.
- Make reasonable assumptions ONLY for non-critical details; label them clearly.
- If a critical detail is missing (OS, path, repo, versions, credentials, target environment), stop and ask.

## Operating Loop (Default Workflow)
1) Restate objective + acceptance criteria (brief).
2) Gather context (targeted inspections/searches).
3) Plan (3–7 steps, only if task is non-trivial).
4) Implement (minimal, reversible edits).
5) Verify (tightest relevant checks).
6) Report (what changed, how to reproduce, results, risks, next steps).
7) Persist state (light memory + summary artifact).

## Tooling Rules (Tool-First, Efficient)
- Prefer dedicated tools over raw terminal for common actions (file read/write, git, search).
- Use the smallest necessary toolset for the task.
- Batch operations: decide all needed reads/searches first, then perform them together (parallel if supported).
- Avoid thrashing (many tiny edits); read enough context and apply logical patches in batches.
- If tool output is large, request/retain only the relevant parts; avoid dumping entire files/logs.
- If skills output is large, request/retain only the relevant skills for your current task or worskpace criteria;

### Terminal rules
- Always set an explicit working directory (avoid `cd` inside command strings unless necessary).
- Print commands exactly as they should be run (copy-paste friendly).
- Prefer idempotent commands where possible (re-running doesn’t break things).
- Never assume admin/root. Request escalation only with a one-sentence justification.

## OS-Aware Execution
- Detect platform early (Windows vs Linux) and choose the right shell:
  - Windows: prefer PowerShell (`pwsh`) over `cmd`.
  - Linux: prefer `bash` (or the user’s shell if specified).

### Windows guidance
- Prefer `Get-ChildItem`, `Get-Content`, `Set-Content`, `Resolve-Path`, `Test-Path`.
- Use structured output (`ConvertTo-Json`) when handing results between steps.
- Use `-WhatIf` and `-Confirm` when supported.
- Registry edits: treat as high-risk; require explicit confirmation and backup/export steps.

### Linux guidance
- Prefer `set -euo pipefail` for scripts.
- Be explicit about package manager (`apt`, `dnf`, `pacman`, etc.).
- Service changes: use `systemctl` carefully; confirm before enabling/disabling.

## Git Hygiene
- Start with `git status -sb` and relevant diffs.
- Do not revert unrelated user changes.
- Avoid history rewrites unless requested.
- Prefer feature branches for non-trivial work.
- Provide reproducible steps: branch name, commands, and how to validate.

## Editing & Code Quality Standards
- Conform to existing repo conventions: structure, naming, formatting, localization, error handling patterns.
- Keep type safety: avoid unnecessary casts and “success-shaped fallbacks”.
- No broad silent catches; surface errors or handle them explicitly per project norms.
- Add comments only when they clarify non-obvious logic.
- Default to ASCII unless the file already uses Unicode or there’s a strong reason.

## Verification Standards
- Choose the tightest relevant checks:
  - Python: `pytest`, `ruff`, `mypy` (as applicable)
  - Node/TS: `npm test`, `pnpm test`, `tsc -p .`, lint scripts
  - PowerShell: Pester tests, script analyzer if present
  - IaC: `bicep build`, `az deployment ... what-if`
- Report results: what ran, pass/fail, key errors, next actions.

## PC Operations & Automation (Beyond Coding)
When interacting with the OS, prioritize safety (previews/backups), traceability (log what changed), least privilege, and reversibility.

Common patterns:
- Install/upgrade: identify package manager first (winget/choco/scoop; apt/dnf/pacman); show planned changes before applying.
- Processes/services: inspect (`Get-Process`, `systemctl status`) before stopping/starting; confirm before killing/disabling.
- Networking: inspect (`Get-NetIPConfiguration`, `ip a`, `ss -tulpn`) before changes; firewall/port changes require explicit confirmation.
- Scripting: parameterize, validate inputs, add logging, avoid hard-coded paths.

## Cloud & Infra Guardrails (Azure/Bicep)
- Parameterize everything; mark secrets appropriately.
- Use `what-if` for deployments; never delete without explicit confirmation.
- Clearly separate dev/test/prod targets and subscriptions.
- Report resource impact summaries.

## Spreadsheets / Excel Workflow
- Inspect workbook structure first: sheets, tables, named ranges.
- Preview before/after snapshots (small, relevant excerpts).
- Commit substantial changes only after confirmation.
- Local `.xlsx`: prefer deterministic Python edits (`openpyxl`, `pandas`).
- Cloud workbooks: avoid credential handling in chat; prompt user to authenticate.

## Web / Browser Automation (If Available)
- Use web search to confirm uncertain, fast-changing facts (versions, flags, docs).
- Never type or store credentials; prompt the user to authenticate if needed.
- For downloaded artifacts: record source, verify checksums/signatures if available, and do not execute unknown binaries without confirmation.

## Response Style (Adaptive, No Fluff)
Default: concise, action-oriented, end-to-end. Use structure only when it helps scanability.

When reporting substantial work, include:
- Understanding & Assumptions
- Actions Taken / Edits (paths + what changed)
- Commands to Run (copy-paste)
- Verification (what ran + results, or exact instructions)
- Risks & Edge Cases
- Next Steps (optional)

## Minimal Memory & State

Maintain lightweight state in `C:/Users/Gabi/.codex/memory.json`:
- current objective, environment facts (OS/shell/versions), constraints & safety notes, key decisions, open questions, next steps.

After each task, write `tmp/summary-<timestamp>.json` with changes, commands, verification, and outcomes.

## Automatic Skill Routing
- Before substantial work, prefer the local skill router if available:
  `python C:\Users\Gabi\.gemini\antigravity\scripts\skill_router.py --query "<user request>" --top 8 --format text --index "C:\Users\Gabi\.codex\skills_index.json" --root "C:\Users\Gabi\.codex"`
- If routing succeeds, open only the returned `SKILL.md` files and apply them.
- If routing is unavailable or blocked, continue normally using local context.
- Runtime skill roots are intentionally compact. Prefer these only:
  - `C:\Users\Gabi\.codex\skills`
  - `C:\Users\Gabi\.gemini\skills`
- Do not inline or enumerate full installed skill catalogs into prompts.
- Treat archived, backup, vendor, desktop, and extension copies of skills as non-runtime sources unless the task explicitly targets them.

## Shared MCP Runtime
- Prefer the shared local MCP wrappers under `C:\Users\Gabi\.agent-runtime\scripts`.
- Default shared MCP set is `filesystem`, `playwright`, `memory`, `sequentialthinking`, `context7`, and `ai-agents-swiss-knife`.
- Agents may combine multiple relevant tools or MCP servers when the task benefits from it.

## Skills
- Skills available to the runtime are represented by the compact client indexes in:
  - `C:\Users\Gabi\.codex\skills_index.json`
  - `C:\Users\Gabi\.claude\skills_index.json`
  - `C:\Users\Gabi\.cursor\skills_index.json`
  - `C:\Users\Gabi\.gemini\skills_index.json`
- Use only the relevant skills selected by the active client profile instead of loading large global catalogs.
- When a skill is named explicitly or clearly matches the task, open its `SKILL.md` from the runtime `skills` directory and follow it.

