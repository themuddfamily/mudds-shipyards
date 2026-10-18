# Component damage model contract

`ComponentDamageModel` is a strict, standalone `RefCounted` foundation for an
ordered roster of damageable components. It snapshots its constructor input,
and tracks only an isolated component-health ledger.

The existing RangeOpponent adapter remains unchanged and does not use the new
batch APIs. `ShipComponentDamage` is now the one scene-local Hero adapter over
one `ComponentDamageModel` ledger: it retains only collision-derived section
geometry, hull-normalized attribution, parked-repair authorization, the legacy
presentation report/signal shape, and Hero's opaque reset fence. It owns no
second component-health ledger. `HeroShip`, target, `GameFlow`, resolver,
presentation, destruction, and recovery authority remain with their existing
owners.

## Definition schema

The public schema version is exactly `3`. Version 2 added ordered repair,
`component_repair_applied`, and the canonical shared-operation cursor. Version
3 adds atomic ordered homogeneous damage and repair batches. The scalar APIs
and original damage cursor remain compatibility surfaces on the same ledger.

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

Scalar damage and repair remain one-operation commits: each accepted scalar
call advances revision once, consumes its explicit operation sequence, returns
the same per-operation result roster as version 2, and emits the same signals
in the same order. They share the batch planner and commit path, but do not
return aggregate-only fields.

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

### Atomic homogeneous batches

`apply_component_damage_batch(contexts)` and
`apply_component_repair_batch(contexts)` accept one to sixty-four scalar
contexts of their matching kind. An input array is a captured ordered roster:
the model never derives commit or signal order from dictionary iteration. Every
component ID must be stable, known, and distinct within that roster. Every
entry must carry the exact active generation and an explicit signed-safe
operation sequence. Sequences may begin at any identity newer than the shared
cursor but must then be contiguous in input order, and the complete range must
fit through the maximum signed-safe identity.

The entire roster is validated and planned before mutation. This includes
exact context keys, numeric types, finite positive requested amounts, component
health, overflow-safe clamps, representable health effects, and every resulting
stage. Empty or over-bound rosters, non-dictionary entries, duplicate component
IDs, malformed or unknown components, invalid amounts, stale generations,
stale/duplicate/gapped identities, insufficient safe sequence capacity, and a
no-effect operation anywhere in the roster reject the complete batch. No
health, stage, generation, revision, sequence, or signal is partially changed.

On acceptance, all planned component health and stage values commit first. The
shared cursor becomes the roster's last sequence and the model revision
increments exactly once for the aggregate batch, regardless of roster length.
The existing per-operation signals then dispatch in captured input order under
the same mutation guard: a changed stage signal precedes that operation's
damage or repair signal. Every per-operation result carries its own input
sequence and the one aggregate revision, and every callback observes the fully
committed batch rather than an intermediate component ledger. There is no
additional aggregate signal.

The returned aggregate receipt contains exactly:

```text
accepted, reason, generation, sequence, revision, operation_kind,
operation_count, first_sequence, last_sequence, operations
```

`sequence` and `last_sequence` are the same committed high-water identity.
`operation_kind` is exactly `damage` or `repair`; `operations` is the detached
ordered roster of the existing scalar per-operation results. The accepted
reason is `applied_batch` or `repaired_batch`. A rejected batch returns the
same exact five-field rejection result as a rejected scalar operation:

```text
accepted, reason, generation, sequence, revision
```

The damage per-operation result contains exactly:

```text
accepted, reason, generation, sequence, revision, component_id,
requested_damage, applied_damage, previous_health, current_health,
maximum_health, stage, stage_changed
```

The repair result has the same roster with `requested_repair` and
`applied_repair` in place of the damage amount fields.

Reset, scalar damage/repair, and batch damage/repair commits include their
synchronous signal dispatch in one non-nestable mutation boundary. A reset,
stage-change, damage, or repair callback may inspect detached snapshots, but
any nested call to any of the five public mutators returns `reentrant_call`.
Reentrant calls change no health, stage, generation, revision, sequence, or
signal state. This preserves the exact outer chronology: reset emits
`model_reset`; a stage-changing health operation emits
`component_stage_changed` before its matching damage or repair signal; an
operation without a stage transition emits only its matching signal.

## Snapshots, audit, and authority

Definition, component-state, aggregate-state, evidence, signal payload, and
audit dictionaries are detached value snapshots. Component order always
matches captured definition order; no unordered dictionary iteration defines
published ordering. Repeated reads of unchanged state are equal.

The version-3 definition snapshot contains exactly:

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

## Fleet coverage

The adapter is craft-agnostic: `HeroShip._ready()` derives the component
envelope from whatever root collision the craft actually has, so every
production craft carries the same ordered five-section roster
(`forward_hull`, `port_wing`, `starboard_wing`, `core_systems`, `engine_bay`)
with the same stage thresholds, the same repair rate, and the same reset
generation fence. That holds for all nine flyable craft, whether they are
instanced from a `scenes/ships/*.tscn` or composed from script by
`FleetExpansionProductionBinding`. A script-composed craft must call
`install_shared_damage_presentation()` before `super._ready()`; without it the
model still registers, but nothing presents it.

Damage attribution, local engine/weapon/sensor cues, failed-section silhouette,
passive repair, destruction and berth regeneration share these owners across
the fleet. The parity suites enumerate all nine craft, directly dirtying engine,
port wing and core and checking repair/reuse. That does not qualify every real
role, contact route, or remote HUD consumer.

Two things are deliberately **not** uniform, because they are role contracts
rather than damage-model contracts:

- **Idle charge emitters.** Hulls with no authored cannon lens (the Cinder
  cargo hauler and long-range bomber) mount no idle charge point rather than
  hanging a marker sphere on a shot-clearance anchor. The weapon component
  still grades through every stage and still gates fire through the existing
  authority; only the optional mesh is absent.
- **Engineer repair.** The crewed craft that carry an engineer seat (Jovian,
  Halyard, Bulwark) admit an authority-gated engineer repair. Craft without
  that seat retain passive landed repair through HeroShip and `tick_repair()`.
  Engineer callers commit through `RepairAuthority.commit_component_repair()`
  to `ShipComponentDamage.tick_component_repair()`. The Ember terminal uses
  that authority commit too. These are distinct repair entry points on one ledger.

Being damageable and being able to fire are separate registrations.
`GameFlow._initialize_live_combat()` attaches the lifecycle damageable adapter
to every flyable craft, and gates only the firing-source registration on an
authored weapon profile. A craft with no offensive weapon is still a valid
target; bundling the two previously left the cargo hauler silently
invulnerable, with every hitscan against it resolving
`non_damageable_blocked`.

## Actual consequences and remaining qualification

Source inventory on `82a7564cb` (2026-10-18), shared by roadmap parents 11/21.
This is source definition, not another gameplay pass or full-craft acceptance.

| Component | Existing runtime consequence |
| --- | --- |
| `forward_hull` | Integrity, attribution and localized presentation; no separate operational multiplier |
| `port_wing`, `starboard_wing` | The weaker wing sets the fire channel |
| `core_systems` | Targeting distance and convergence availability |
| `engine_bay` | Thrust, steering, departure/cruise acceleration, speed cap and manual braking |

At integrity <=0.62 the impaired multiplier is 0.62; at <=0.24 the failed
multiplier is zero. Terminal zero remains failed in the legacy presentation.
These apply to Torrent, Arrow, Jovian, Zenith, Halyard, Bulwark, Cinder light
interceptor, cargo hauler and long-range bomber. Eight missing-original craft
have UNKNOWN component/role definitions; this shared roster does not specify them.

Hero engine output also takes the minimum with critical-hull stutter. Halyard's
admitted engineer selection adds 0.15 (capped at 1) to one surviving engine,
fire or targeting channel; it cannot revive zero. Its gunner uses inherited
Hero fire readiness/cadence. Bulwark gunner charge duration and cooldown divide
by the live fire multiplier, and failed fire blocks discharge. Bomber payload
release checks failed fire; this does not establish impaired payload cadence.

`HeroShip.apply_damage()` owns hull loss/destruction; component attribution
observes already-applied hull loss. `ShipComponentDamage` owns geometry and
adapter access to the sole `ComponentDamageModel` ledger. GameFlow schedules
berth recovery and owns its lease; Hero preflights/commits reset and supplies
the adapter capability fence. Passive repair requires landed, intact and not
landing. Engineer/terminal authority commits use the distinct path above.

### Concrete remote presentation gap

`GameFlow._publish_active_ship_telemetry_to_hud()` overlays accepted host hull/
status and observer engine/throttle. `HeroComponentHudBinding.refresh()` still
reads the local `get_component_damage_report()`, while accepted host component
facts are retained in Hero's `_network_damage_state.components`. The component
row could therefore disagree with the accepted host silhouette at inventory.
That seam is repaired in checkpoint `39a2ad7`: a detached display report and
presentation-only change signal feed a source-aware binding. Host generation/
tick and local ledger ordering remain independent; host reports cannot invent
local repair/recovery facts. Old actual row/label regression, existing local
HUD checks, full pose and independent Main/ENet checks pass; see delivery history.

The HUD's engine/weapon/targeting power scalars also remain local. Source review
on `b00ab078f` resolves the production seam: `HeroShip.get_telemetry()` samples
actual live powers, including critical-hull stutter and Halyard routing. The
canonical snapshot bridge already carries these for the host active craft, but
`NetworkRemoteCraftPoseStream.build_pose_entry()`, `pack_display_facts()` and
`_sample_from_entry()` omit them for arbitrary observed craft. Existing optional
primitive power fields are already bounded by the authoritative snapshot contract;
no new protocol version or compressed row layout is required. Settled rows retain
the last pose tick and already advance operation tick, allowing fresh display
facts without fresh movement. Integrity alone cannot reconstruct live powers.

[The executable card](../ROADMAP.md#next-executable-card-net-component-powers)
retains the selected implementation and focused proof. Candidate `9a3e16604`
implements the projection and passes the full pose302 regression after one
fixture sequence repair. Main/ENet then fails the existing nine-craft live-delta
ceiling at12408 bytes. The candidate remains unmerged/withheld; a production
encoding fix is required before acceptance. Remaining Halyard/local runtime
checks and all checkpoint work are NOT_RUN. Keep its detached power projection separate from the accepted
component-row report and local repair ledger. Host display eligibility must
preserve client/session and locally-flown exclusions, accepted generation/tick
order, destruction fencing and clear/re-entry. A newer missing-power row must
clear the prior projection; incomplete or invalid triples cannot become accepted
power facts. Display facts never mutate local simulation.

Existing adapter checks cover attribution/stages/authorization/repair/cleanup;
Main integration explicitly enumerates five earlier craft; nine-craft recovery
parities directly dirty engine/port/core. Detached repair-network snapshots do
not establish physical engineer admission, and the canonical snapshot check
creates no ENet peer. Preserve ordinary full-craft/role routes, original Phase 6
combat/recovery requirements, native/human gates and parked admission failures.
No further missing runtime component feature was established by this inventory.

## Explicitly outside this foundation

There is no direct `HeroShip`, target, `GameFlow`, resolver, or Main-scene
authority in the detached model. The narrow `ShipComponentDamage` adapter is
the sole current Hero integration; it supplies repair authorization/rate and
presentation geometry without granting those concerns to the ledger. There is
no shield model, debris model, power bus, effect spawning, audio routing, or
wall-clock behavior. Those systems cannot be inferred from a health mutation,
stage flag, or multiplier and require their own separately reviewed contracts
and acceptance evidence.
