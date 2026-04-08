# Lucky5 Invariants

1. Backend authority is absolute.
   - All gameplay outcomes are server-resolved.
   - Frontend must not simulate RNG, deal order, trails, or outcome previews.
2. CleanRoom isolation is non-negotiable.
   - Authoritative logic stays in `server/src/Lucky5.Domain/Game/CleanRoom/`.
   - UI cannot duplicate or reinterpret engine rules.
3. Rendering must be idempotent.
   - Same DTO in -> same UI out.
   - No hidden local state may alter meaning of the DTO.
4. Optional DTO fields are authoritative too.
   - Missing dealer/challenger cards mean the frontend must not invent them.
5. Cashout and take-half are backend settlement operations.
   - The frontend must never assume settlement without calling the backend endpoint.
