# Weapon definition contract

`WeaponDefinition` is a strict, reusable Godot `Resource` for authoring one
weapon configuration. It is a Phase 6 data foundation, not a gameplay
integration. No production weapon constants, combat source registration,
resolver behavior, damage path, presentation pool, audio pool, save format, or
network contract changes with this foundation.

## Stable data

Every definition declares:

- a lowercase snake-case `weapon_id` and display name;
- an explicit resolution mode: `hitscan`, `projectile`, or `beam`;
- range in metres, damage per hit, and cadence in shots per second;
- whether faction identity is inherited from the registered source or fixed by
  the definition, plus an explicit deny/allow friendly-fire policy;
- optional spread, heat, and ammunition models guarded by explicit enabled
  flags, with finite ceilings and canonical all-zero disabled states;
- stable presentation, fire-audio, impact-audio, and dry-fire-audio IDs; and
- evidence status, references, notes, and the scoped evidence record published
  by its audit.

The optional fields are data only. In particular, enabling projectile, beam,
spread, heat, or ammunition data does not imply that a runtime consumer exists.
Unknown enum values and malformed identifiers fail validation instead of
falling back to another behavior.

## Bounds and cross-field rules

All floating-point gameplay values reject `NaN` and infinities. Range, damage,
cadence, spread, heat, cooldown, magazine, reserve, and per-shot ammunition are
bounded by named schema constants. Enabled spread must be positive. Enabled
heat requires positive per-shot heat, capacity, and cooldown, and per-shot heat
cannot exceed capacity. Enabled ammunition requires a positive magazine and
per-shot cost, and one shot cannot cost more than the magazine holds. Disabled
optional systems require exact zero values so snapshots have one canonical
meaning.

A fixed-faction definition must carry a valid faction ID. A definition that
inherits its faction must leave `fixed_faction_id` empty. Authenticated and
provisional historical claims require at least one bounded, unique evidence
reference; new tuning does not claim historical authenticity.

## Snapshot, audit, and authority

`get_definition_snapshot()` and `get_audit_report()` return detached data;
mutating their nested dictionaries or packed arrays cannot mutate the Resource.
The Resource owns exactly zero common runtime authority. Its authority report
contains the common twelve keys—renderer, gameplay, streaming, save, network,
physics, world generation, terrain generation, collision generation, origin
shift, weather clock, and audio—and every value is exactly `false`.

Godot Resource save/load round trips preserve the typed definition, enum
meaning, optional systems, evidence, presentation/audio IDs, validation result,
and zero-authority report.

## Evidence status

The schema and default numbers are `NEW` gameplay design. They are not recovered
weapon specifications. A future authenticated or provisional definition must
name its evidence and still receives no runtime authority from that status.

## Exact next migration seam

The next migration should be a separate change that creates authored `.tres`
resources and converts validated `WeaponDefinition` resolution envelopes into
the existing `{range, damage, origin_tolerance}` profiles at
`LiveCombatAuthority.register_source()`. The source registration remains the
authority for live source identity and inherited faction. `ShotRequest` and
`CombatResolver` remain the sole shot-validation and damage-resolution path.

That migration must first prove equivalence for the current player and defender
profiles assembled in `scripts/game/game_flow.gd`, then for the independent
profiles exposed by `scripts/ships/resolver_backed_opponent.gd` and
`scripts/ships/standoff_picket_opponent.gd`. Cadence currently owned by ship and
opponent lifecycle code must move only after its cooldown tests demonstrate the
same accepted-shot timing. Presentation/audio IDs should be consumed by their
existing bounded pools only after cue and receipt tests prove the same atomic
acceptance behavior. Projectile, beam, spread, heat, ammunition, fixed-faction,
and per-weapon friendly-fire behavior remain unsupported until explicitly
implemented and tested; consumers must reject those modes rather than silently
approximate them.
