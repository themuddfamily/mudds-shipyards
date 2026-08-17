# Weapon definition contract

`WeaponDefinition` is a strict, reusable Godot `Resource` for authoring one
weapon configuration. The Resource itself remains a zero-authority Phase 6 data
foundation. One bounded production migration now converts the Torrent combat
pulse into the unchanged resolver profile dictionary; it does not alter combat
source registration, resolver behavior, damage, presentation/audio pools, save
format, or networking.

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

## Current registration map

Every production call to `LiveCombatAuthority.register_source()` is accounted
for below. Values are `range / damage / origin tolerance`; cadence is still
owned by each ship or opponent lifecycle and is not part of the resolver
dictionary.

| Registration owner | Source IDs and faction | Weapon profiles | Migration state |
| --- | --- | --- | --- |
| `GameFlow` player fleet | Torrent `1101`, Arrow `1102`, Jovian `1103`, Zenith `1104`, Halyard `1105`; `shipyard_flight_test` | All: `range_pulse_cannon` `360 / 50 / 24`. Combat: Torrent `360 / 34 / 24`, Arrow `410 / 25 / 24`, Jovian `315 / 23 / 32`, Zenith `390 / 27 / 24`, Halyard `280 / 18 / 30` | Torrent, Arrow, and Zenith combat are converted from their checked-in resources in `assets/weapons/`; Jovian and Halyard remain their existing dictionaries. |
| `GameFlow` range defender | `2101`; `range_defence` | `defence_pulse_cannon` `420 / 11 / 18` | Unmigrated. |
| `StandoffPicketOpponent` | `2102`; `range_defence` | `picket_lance_cannon` `520 / 21 / 22` | Unmigrated component-local dictionary. |
| `ResolverBackedOpponent` skirmishers | `2103`, `2104`; `range_defence` | `skirmisher_repeater` `150 / 6 / 22` | Unmigrated component-local dictionary. |
| `ResolverBackedOpponent` courier | `2105`; `range_defence` | `courier_tail_deterrent` `110 / 8 / 22` | Unmigrated component-local dictionary. |
| `StationDefenseEncounterContent` | `2121`, `2122`, `2123`; checked-in `perimeter_raiders` faction | `perimeter_defense_pulse` `170 / 11 / 18` | Unmigrated shared encounter dictionary; the atomic-acquire and wire paths submit the same profile. |

Tests construct additional registration dictionaries, but they are fixtures and
not production profile owners.

## Bounded converter and next migration seam

`WeaponDefinitionResolverProfile` is a pure converter. It accepts a validated
definition, the already-authoritative registered faction, and the per-source
origin tolerance, then returns a newly detached dictionary in the existing
`{weapon_id: {range, damage, origin_tolerance}}` shape. It accepts hitscan,
inherited faction or an exactly matching fixed faction, denied friendly fire,
and disabled spread/heat/ammunition only. Any unsupported or invalid input
returns an empty dictionary without a legacy fallback.

The Torrent, Arrow, and Zenith resources are now the sole production sources of
their respective combat-pulse range and damage. Each cadence is guarded for
exact equivalence with its existing `HeroShip.weapon_cooldown`; presentation
and cue IDs are likewise guarded against the existing cyan/player-fire/
medium-impact/dry-fire route. Those lifecycle and presentation owners have not
moved.
`LiveCombatAuthority`, `ShotRequest`, and `CombatResolver` still exclusively own
registration, sequence, receipt, validation, and damage state, including
detach/re-entry.

The next migration should choose one row above, add its checked-in definition,
and prove exact behavior before removing that row's dictionary. Cadence can
move only after the relevant cooldown tests demonstrate identical accepted-shot
timing. Presentation/audio IDs can become active routing inputs only after pool
and cue tests prove the same atomic acceptance behavior. Projectile, beam,
spread, heat, ammunition, and allowed friendly fire remain unsupported and
must continue to fail closed rather than being approximated.
