# Audit Log

## 2026-03-15 — Memory Compression / Verification

- Deduplicated `.memory/` content and removed repeated fix history.
- Kept architecture facts in `decisions.md`, reusable implementation notes in `patterns.md`, and unresolved items in `inbox.md`.
- Removed the stale implication that React lobby/menu parity was already complete; current `src/web/CLAUDE.md` still lists lobby, menu, back-to-lobby, and reset/admin gaps.
- Verified current memory against `src/web/CLAUDE.md`, `server/src/Lucky5.Infrastructure/CLAUDE.md`, `server/src/Lucky5.Api/wwwroot/js/game.js`, and `server/src/Lucky5.Infrastructure/Services/GameService.cs`.

## 2026-03-31 — RTP 80% Investigation / Handoff

- Added `.memory/rtp-80-rebalancing-handoff-2026-03-31.md` as the main bootstrap for future RTP/fun/tension work.
- Recorded that the previous 85% direction became hard to balance cleanly because double-up variance is strong under the clean-room ruleset.
- Recorded the current product direction: aim for an 80% middle ground that preserves fun, tension, excitement, deterministic pre-shuffled outcomes, and avoids obviously scripted gameplay.
- Recorded the key simulation/live mismatch: simulation still uses policy-driven double-up offers while live code currently offers double-up on every paying hand.
