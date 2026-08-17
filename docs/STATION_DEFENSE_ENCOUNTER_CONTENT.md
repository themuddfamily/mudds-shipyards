# Station-defense encounter content

`station_defense_encounter.tscn` is a checked-in production composition for the
existing `StationDefenseEncounterHost`. It closes the host foundation's manual
staging gap with three pre-created production `RangeOpponent` instances, one
dedicated renewable perimeter asset, and one validated contract resource. The
scene contains no `LiveCombatAuthority` or `CombatResolver`; the integrating
session must inject its one existing authority before content initialization.

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
It is authored at the audited world transform `(90, 0, -10)` and reports both
required and live transforms. Audit and start fail closed if that pose drifts.

The dedicated `StationDefensePerimeterAsset` is original `NEW` /
`modern_interpretation` presentation. Its existing `AuthoritativeDamageable`
child is the sole health and damage store. The wrapper only translates its
damage/destruction signals into generation-bearing activity observations.
Reset first runs a nonmutating physical-renewal preflight, then commits the Host
reset and exact protected handle generation `old + 1`, and finally resets the
same Damageable through its existing API. Observation-time reentry fails before
any Host/activity/physical snapshot changes.

All three opponents target that asset and register fixed, distinct source IDs
and one bounded weapon profile on the injected authority. Source acquisition is
transactional: an existing ID conflict rolls back every newly acquired source
and leaves the Host unconfigured in an explicit terminal configuration state.
The hostile local-origin leash is enforced on caller-physics advancement; an
exit aborts through the public Host authority before opponents and source
registrations retire.

All encounter, wave, identity, timing, and spawn layout decisions are explicitly
`modern_interpretation`. No historical Keth Shipyards encounter is claimed.

Authority boundaries:

- `StationDefenseActivity` owns objective state, generation, waves, and timeout.
- `StationDefenseEncounterHost` observes resolver-confirmed terminal damage and
  maps contract handles to the pre-created roster.
- `RangeOpponent` and `LifecycleDamageableAdapter` retain hull and destruction.
- `CombatResolver` remains the only combat-resolution authority.
- `AuthoritativeDamageable` retains protected-object health and damage.
- The content owns no rewards, ships, berths, save,
  networking, HUD, GameFlow, Main, or runtime spawning authority.

Current limitations:

- The authored safe pose is not instantiated by `ShipyardWorld`, selected by
  `GameFlow`, or surfaced in HUD/Main.
- The integrating session must inject its existing combat authority and decide
  when to start/advance the encounter. Fixed source-ID conflict is terminal for
  that content instance; callers must discard it and resolve the shared-session
  identity conflict.
- The player/ship engagement envelope is published data, not a player-flight,
  launch, berth, route, or world-geometry authority.
- No reward, recovery, repair, audio, save, networking, or post-encounter flow
  is defined.
- Detach/re-entry preserves the same in-memory scene instance; it is not save or
  network restoration.

Focused proof:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/station_defense_encounter_content_test.gd
```

The suite directly instances `ShipyardWorld` (not `Main`) and exercises the
audited pose, all three real projectile/source paths, resolver completion,
renewal preflight/reentry, fixed-ID rollback, live-pose structured red,
detach/re-entry, asset destruction/reset, leash abort, and a full 12 seconds of
real physics clearance and timeout lifecycle.
