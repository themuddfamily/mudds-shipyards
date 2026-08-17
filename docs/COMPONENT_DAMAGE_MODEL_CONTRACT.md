# Component damage model contract

`ComponentDamageModel` is a strict, standalone `RefCounted` foundation for an
ordered roster of damageable components. It snapshots its constructor input,
tracks only an isolated component-health ledger, and has no production adapter
in this slice.

The existing `ShipComponentDamage` observer and every current `HeroShip`,
opponent, target, `GameFlow`, resolver, presentation, destruction, and recovery
path remain unchanged. This contract is not wired beside them and does not
claim to replace them yet.

## Definition schema

Each component definition contains exactly:

- `component_id`: a unique lowercase snake-case stable ID;
- `maximum_health`: a finite value greater than zero and no greater than the
  named one-billion-unit bound; and
- `damage_stages`: one to sixteen ordered stage dictionaries.

Each stage contains exactly:

- `stage_id`: a unique stable ID within its component;
- `health_ratio_at_or_below`: an inclusive finite threshold in `0..1`;
- `disabled`: a data-only consequence flag; and
- `performance_multiplier`: a data-only consequence scalar in `0..1`.

Thresholds are strictly descending. The first is exactly `1.0`, giving every
healthy component an explicit stage, and the last is exactly `0.0`, giving zero
health an explicit terminal stage. Performance cannot improve as damage gets
worse. Enabled stages require positive performance; disabled stages require
zero performance, and a later stage cannot re-enable a component.

The model publishes the flag and scalar but never applies them to propulsion,
weapons, controls, power, AI, collision, or any other gameplay owner.

## Generation and damage acceptance

`reset_for_reuse(expected_generation)` is the only activation/reset seam. The
expected generation must equal the model's current generation. An accepted
reset advances the positive generation exactly once, restores every current
health value to its maximum, recomputes the first stage, clears the new
generation's sequence ledger, increments revision, and emits one detached
reset result. Stale, duplicate, invalid-definition, and exhausted resets leave
all state unchanged.

`apply_component_damage(context)` accepts exactly four fields:

```text
component_id, damage, generation, sequence
```

The generation must be current. Sequence is a non-negative, signed-safe integer
which increases monotonically within that generation; gaps are allowed.
Duplicate and older sequences are rejected. The component ID must be valid and
present in the captured roster, and damage must be finite and positive.
Unknown/missing fields, unknown or malformed components, non-finite damage,
stale generations, invalid sequences, damage below the current health value's
representable precision, and damage with no remaining component effect are
rejected atomically. Rejections do not change health, generation, revision,
sequence history, or signals.

Accepted damage clamps current health at zero and reports both requested and
committed damage. Inclusive stage selection is deterministic. One detached
damage signal is emitted per accepted commit, and a detached stage signal is
emitted only when that commit changes stage.

## Snapshots, audit, and authority

Definition, component-state, aggregate-state, evidence, signal payload, and
audit dictionaries are detached value snapshots. Component order always
matches captured definition order; no unordered dictionary iteration defines
published ordering. Repeated reads of unchanged state are equal.

The audit reports configuration validity, deterministic definition and state
snapshots, and explicit evidence. The model is `NEW` gameplay design with no
source references and makes no historical component-health claim.

The common authority report contains exactly these twelve keys, all `false`:

```text
renderer, gameplay, streaming, save, network, physics,
world_generation, terrain_generation, collision_generation,
origin_shift, weather_clock, audio
```

The isolated ledger therefore grants no ship, hull, combat-resolution,
destruction, collision, score, presentation, persistence, networking, or scene
authority. A future production adapter must assign those responsibilities
explicitly and prove behavior equivalence before replacing an existing damage
path.

## Explicitly outside this foundation

There is no `HeroShip`, opponent, target, `GameFlow`, resolver, or Main-scene
integration. There is no repair model, shield model, debris model, power bus,
effect spawning, audio routing, automatic ticking, or wall-clock behavior.
Those systems cannot be inferred from a stage flag or multiplier and require
their own separately reviewed contracts and acceptance evidence.
