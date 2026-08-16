# Station defense encounter host foundation

`StationDefenseEncounterHost` is the production-facing composition seam between
the existing data-only `StationDefenseActivity` and the existing combat stack.
It does not replace either authority.

Callers supply a valid `StationDefenseContract`, the session's existing
`LiveCombatAuthority`, and already-created `RangeOpponent` instances with exact
generation-bearing handles, faction IDs, and world spawn transforms. The host
orders its bounded roster by contract wave/order rather than registration order,
attaches the existing `LifecycleDamageableAdapter`, and calls each opponent's
existing `activate()`/`deactivate()` lifecycle only when the activity publishes
that handle.

Destruction advances the objective only when the injected production
`CombatResolver` emits an accepted, resolved, damaged, terminal result whose
target is the exact currently active registered instance and activity
generation. The host stores no health and never calls `apply_damage()`. Ordinary
opponent signals or caller-side node deletion do not masquerade as a combat
receipt.

## Bounded deterministic contract

- The spawn roster is capped at the contract's existing 256-total-hostile bound.
- Every roster handle must exist exactly once in the immutable contract, and one
  physical instance cannot satisfy two handles.
- Start fails until the complete roster, live nodes, and production lifecycle
  adapters are present.
- Ordered waves activate only the next activity-published handle; simultaneous
  waves activate every published handle in contract order.
- Wave delay and timeout progress only through
  `advance_physics(delta, generation)`. There is no process callback or wall
  clock.
- Reset reuses the same staged instances through their existing lifecycle and
  invalidates the prior activity generation.
- Whole-host detach/re-entry gates the activity and resolver observation while
  preserving activity time, roster identity, opponent health, and active state.
- `get_snapshot()` and `audit()` return deeply detached HUD-ready primitive data
  with stable roster order and exact authority exclusions.

## Authority exclusions and limitations

The host owns roster binding and wave-driven activation only. It owns no combat
resolution, health, damage, reward, scene instantiation, protected-object
lifecycle, ship, berth, world geometry, HUD, GameFlow, Main, persistence, or
network authority. Protected-asset damage/destruction remains a caller-supplied
observation forwarded to `StationDefenseActivity`; this foundation adds no
protected-object damage adapter.

No production scene or coordinator is wired yet. Callers must still choose and
instantiate opponent scenes, configure their targets/presentation dependencies,
supply transforms and physics delta, stage protected objects, and decide
rewards and post-encounter flow. Non-resolver destruction does not advance the
roster; a future production integration must explicitly map any accepted
non-combat failure mode to `fail()` or protected-asset evidence. There is no
save/restore, networking, pooling policy, dynamic roster replacement, HUD widget,
audio policy, or reward path in this foundation.

The focused suite uses three real production `RangeOpponent` instances, the real
`LiveCombatAuthority`, `CombatResolver`, and lifecycle adapter. It covers
scrambled registration order, incomplete/duplicate registration, nonterminal and
terminal resolver damage, ordered/delayed waves, caller-only timing, whole-host
detach/re-entry with partial hull preservation, completion, protected-asset
failure, timeout, abort, reset, signal re-entry, detached snapshots, bounds, and
exact authority exclusions. No render is required because this foundation adds
no presentation or renderer input.
