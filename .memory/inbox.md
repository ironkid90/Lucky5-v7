# Inbox — Inferred Items Awaiting Confirmation

## Pending

- [ ] React cabinet missing lobby/game screen separation — may need dedicated Lobby component
- [ ] React cabinet needs menu overlay parity with vanilla JS
- [ ] Consider adding session heartbeat for prolonged sessions (InMemory data can be lost on restart)
- [ ] MACHINE_CREDIT_LIMIT (50M client) vs CloseThreshold (40M server) discrepancy — intentional?
- [ ] Admin panel in React cabinet not yet implemented

## Confirmed

- [x] ResetMachine must reset sessions, not just ledger (fixed 2026-03-15)
- [x] Go-back-to-lobby moved into menu panel (fixed 2026-03-15)
