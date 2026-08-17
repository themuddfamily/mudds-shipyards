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

The public schema version is exactly `2`. Version 2 adds ordered repair,
`component_repair_applied`, and the canonical shared-operation cursor while
retaining the original damage cursor as a compatibility alias.

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

## Generation and ordered health operations

`reset_for_reuse(expected_generation)` is the only activation/reset seam. The
expected generation must equal the model's current generation. An accepted
reset advances the positive generation exactly once, restores every current
health value to its maximum, recomputes the first stage, clears the new
generation's shared operation-sequence ledger, increments revision, and emits
one detached reset result. Stale, duplicate, invalid-definition, and exhausted
resets leave all state unchanged.

Damage and repair use one total operation order per generation. A sequence
accepted by either operation is consumed for both: the other operation cannot
reuse it, and neither operation can move behind the shared high-water mark.
Gaps are allowed. The maximum signed-safe integer is the last admissible
identity; a request for a newer identity after that commit returns
`sequence_exhausted`. Rejected operations consume nothing. Reset is the only
way to enter a new generation and start again at sequence zero.

`get_last_operation_sequence()` and the `last_operation_sequence` snapshot field
publish the canonical cursor. `get_last_damage_sequence()` and
`last_damage_sequence` remain compatibility aliases for damage-only consumers;
after repair they expose the same shared damage-or-repair high-water mark.

`apply_component_damage(context)` accepts exactly four fields:

```text
component_id, damage, generation, sequence
```

The generation must be current. Sequence is a non-negative, signed-safe integer
newer than the shared operation cursor. The component ID must be valid and
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

`apply_component_repair(context)` accepts exactly four fields:

```text
component_id, repair, generation, sequence
```

It uses the same generation, identity, exact-key, component, and atomicity gates
as damage. Repair must be numeric, finite, and strictly positive. An accepted
repair adds health, clamps exactly at the captured maximum, reports requested
and committed repair, recomputes the inclusive stage, consumes the shared
operation sequence, increments revision once, and emits one detached repair
signal. A detached stage signal is emitted only when the resulting stage
changes.

Saturation is overflow-safe: the model first computes finite remaining health,
clamps the applied amount to that remainder, then adds only the applied amount.
A maximum finite requested repair therefore reaches the exact captured maximum
without an infinite intermediate value and consumes exactly one sequence.

Repair at maximum health, repair below the current value's representable
precision, malformed or unknown components, stale or duplicate operations,
non-finite or non-positive amounts, and operation-sequence exhaustion are
rejected before mutation. Health, stage, generation, revision, sequence, and
signals remain unchanged. The model applies one explicit amount only; it does
not choose a rate, authorize a repair site, read time, or tick itself.

Reset, damage, and repair commits include their synchronous signal dispatch in
one non-nestable mutation boundary. A reset, stage-change, damage, or repair
callback may inspect detached snapshots, but any nested call to any of the
three public mutators returns `reentrant_call`. Reentrant calls change no
health, stage, generation, revision, sequence, or signal state. This preserves
the exact outer chronology: reset emits `model_reset`; a stage-changing health
operation emits `component_stage_changed` before its matching damage or repair
signal; an operation without a stage transition emits only its matching signal.

## Snapshots, audit, and authority

Definition, component-state, aggregate-state, evidence, signal payload, and
audit dictionaries are detached value snapshots. Component order always
matches captured definition order; no unordered dictionary iteration defines
published ordering. Repeated reads of unchanged state are equal.

The version-2 definition snapshot contains exactly:

```text
schema_version, components, evidence, authority
```

Each component-state snapshot contains exactly:

```text
component_id, maximum_health, current_health, health_ratio, stage
```

The aggregate state snapshot contains exactly:

```text
schema_version, generation, revision, last_operation_sequence,
last_damage_sequence, active, component_order, components, evidence, authority
```

The audit snapshot contains exactly:

```text
schema_version, valid, configuration_errors, definition, state, evidence,
authority
```

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
integration. There is no repair authorization, repair-rate policy, shield model,
debris model, power bus, effect spawning, audio routing, automatic ticking, or
wall-clock behavior. Those systems cannot be inferred from a health mutation,
stage flag, or multiplier and require their own separately reviewed contracts
and acceptance evidence.
