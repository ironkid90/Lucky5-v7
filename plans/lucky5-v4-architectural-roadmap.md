# Lucky5 v4.0.0 Architectural Roadmap

Date: 2026-04-10
Status: Strategic Draft
Objective: Enterprise Evolution & Scale

This document outlines the high-level roadmap for transitioning from Phase 3.4 hardening to a distributed, enterprise-scale v4.0.0 architecture.

## 1. Zero-Downtime Migration Strategy
Transitioning from `InMemoryDataStore` to a robust versioned persistence layer.

- [ ] **Redis State Versioning**: All keys in Redis must follow the format `lucky5:v4:{type}:{id}`.
- [ ] **Side-by-Side Session Handling**:
    - Backend must detect "legacy" in-memory or older Redis sessions during authenticated requests.
    - Gracefully migrate active sessions to the v4 model upon the next gameplay action (Deal/StartDoubleUp).
- [ ] **State Snapshotting**: Implement background checkpointing to persistent SQL for long-term auditing without impacting hot-path Redis performance.

## 2. Horizontal Scaling & Distributed GameService
Decoupling state from process memory to support multi-node Azure Container App deployments.

- [ ] **Process Statelessness**:
    - All local collections in `GameService` and `InMemoryDataStore` must be replaced by the `IPersistentStateStore` (Redis).
    - Move `MachineLedger` (RTP data) to a distributed lock model to prevent "double-win" or "lost-credits" race conditions under high concurrency.
- [ ] **Distributed SignalR Backplane**:
    - Enable Azure SignalR Service or Redis Backplane to ensure machine-sync events (Jackpots) reach clients regardless of which server instance they are pinned to.
- [ ] **Resource Partitioning**:
    - Group machines into "Clusters" managed by specific node instances if performance hot-spots are detected in the Redis global lock table.

## 3. Frontend Modernization
Moving from vanilla JS orchestration to a modular React-Native and Web engine.

- [ ] **State Reconciliation**: Replace manual DOM patching in `game.js` with a unidirectional data flow (Redux/Zustand).
- [ ] **SignalR-First Sync**:
    - Move from polling-based wallet/jackpot checks to a real-time push model.
    - Implement local "optimistic" state transitions that reconcile with the authoritative server DTO on arrival.
- [ ] **Port logic to React**: 
    - Use the validated 720x1280 CSS baseline from the Clone-Parity upgrade.
    - Encapsulate the `CleanRoom` evaluation logic as a shared library for both Web and Flutter-mobile.

## 4. Web API Breaking-Change Policy
Managing the transition from v1 to v4 endpoints.

- [ ] **Versioning Logic**: 
    - URL structure: `/api/v4/game/...`
    - Support v1 (Phase 3.x) for a 30-day overlap period post-v4.0.0 deployment.
- [ ] **Contract Hardening**: 
    - Use mandatory schema validation (FluentValidation) for all `Deal` and `DoubleUp` requests.
    - Deprecate unstructured result objects in favor of strongly-typed `OutcomeRecord` DTOs.

## 5. Global Verification & High-Concurrency Suites
Ensuring system integrity under enterprise load.

- [ ] **CleanRoom Expansion**: 
    - Add 1,000,000-hand deterministic regression tests for each major version break.
    - Verify v3->v4 state migration logic through "Red-Tape" integration tests that simulate process restarts mid-session.
- [ ] **Load Testing**:
    - Implement k6 or JMeter suites targeting 1,000 simultaneous users across multiple Azure regions.
    - Monitor Redis latency under concurrent `TakeHalf` operations.
- [ ] **Fuzzing**: Implement randomized dealer-switch sequences in the Double-Up engine to find boundary condition hangs in the recursive resolution logic.
Refactor the Lucky5 web arcade cabinet to achieve precise 1:1 hardware parity based on the 720x1280 portrait baseline. Implement a comprehensive frontend overhaul and critical logic remediation as specified:

1. UI/UX Cabinet Architecture (720x1280 Portrait):
- Re-proportion the global container to maximize the gaming canvas real estate.
- Minimize the vertical height of the bottom control deck (button panel) to the absolute functional minimum.
- Scale up interaction buttons (Bet, Deal, Hold, Double) for high-density ergonomics, significantly reducing inter-element padding and spacing.
- Enforce strict layout integrity within the 720x1280 viewport, ensuring zero overflow, no scrollbars, and pixel-perfect scaling across mobile/web environments.

2. Card Distribution Engine Fix:
- Debug the card rendering lifecycle to eliminate the "initial face-down" state during distribution.
- Ensure cards instantiate or transition to "face-up" immediately upon being dealt to the player's hand, mapped correctly to the current game state and asset textures to prevent visual flickering or state dsync.

3. Double-Up (Gamble) Logic & Sequential Progression:
- Correct the coordinate mapping for dealer and player card slots to ensure perfect alignment with the UI background assets, eliminating all overlap and misplacement issues.
- Implement sequential card placement logic for the double ups  that progresses strictly from left to right. and the shuffle/transition mechanism: the deck cards must be seqeuentially added yo from left to right  with each successful double up Hi or Lo and the 5th card  when hit and displayed during the shuffle becomes the "first card" of the subsequent deck, maintaining a seamless stateful loop.

Technical execution must strictly adhere to 'plans/lucky5-clone-parity-execution-details.md'. Analyze the provided screenshot to replicate the exact spatial relationships, asset positioning, and aesthetic fidelity of the original cabinet hardware. prioritize robust state management and high-fidelity visual parity. 
