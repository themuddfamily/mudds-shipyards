# Station-defense encounter content

`station_defense_encounter.tscn` is a checked-in production composition for the
existing `StationDefenseEncounterHost`. It closes the host foundation's manual
staging gap with three pre-created production `RangeOpponent` instances, one
`LiveCombatAuthority`/`CombatResolver`, and one validated contract resource.

The original `shipyard_perimeter_defense.tres` contract contains one ordered
approach hostile followed, after 0.5 caller-supplied physics seconds, by two
simultaneous relief hostiles. The contract has one protected station handle and
a 12-second caller-timed timeout. Content is capped at eight hostiles even
though the generic activity foundation accepts a larger bounded roster.

Each hostile has an exact generation-bearing `Marker3D` and a centered 9 m
spherical `Area3D` keep-clear volume. The volumes are query-inert: their shapes
document and validate reserved staging space without becoming world collision,
damage targets, launch-clearance authority, or navigation geometry. The scene
validates a minimum 4 m gap between volumes before registering any opponent.

All encounter, wave, identity, timing, and spawn layout decisions are explicitly
`modern_interpretation`. No historical Keth Shipyards encounter is claimed.

Authority boundaries:

- `StationDefenseActivity` owns objective state, generation, waves, and timeout.
- `StationDefenseEncounterHost` observes resolver-confirmed terminal damage and
  maps contract handles to the pre-created roster.
- `RangeOpponent` and `LifecycleDamageableAdapter` retain hull and destruction.
- `CombatResolver` remains the only combat-resolution authority.
- The content owns no rewards, ships, berths, protected-object health, save,
  networking, HUD, GameFlow, Main, or runtime spawning authority.

Current limitations:

- The scene is not yet placed by `ShipyardWorld` or selected by `GameFlow`.
- No player/fleet target is wired; an integrating world must assign opponent
  targets and register its existing combat source.
- Protected-station damage/destruction remains an explicit caller observation.
- Detach/re-entry preserves the same in-memory scene instance; it is not save or
  network restoration.
