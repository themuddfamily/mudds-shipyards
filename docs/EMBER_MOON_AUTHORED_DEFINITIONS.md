# Ember Moon authored definitions

Ember Moon is one original modern airless vertical-slice candidate in the
`nearby_sector`. These checked-in Resources author identity and composition data
only. They do not place a destination in `Main`, load or stream a scene, render
terrain, generate collision, move a ship, approve a landing, grant rewards, or
persist state.

## Exact authored join

- World ID: `ember_moon`; body ID: `ember_body`.
- Terrain profile: `ember_basalt_terrain`.
- Sole landing region: `ember_caldera`.
- Body-centre-to-sea-level radius: exactly 120,000 m.
- Terrain elevation envelope: exactly -2,500 m through 8,500 m.
- Body-centred anchors: surface 120,000 m, navigation 130,000 m, orbit
  140,000 m, all on +Y.
- Landing-region centre: `(0, 120000, 0)` m with basis +Y aligned to the
  outward radial normal.
- Atmosphere: absent. The world has `has_atmosphere=false`, an empty atmosphere
  ID, and composes only when the resolved atmosphere input is null.

The world scene reference resolves to the standalone authored
`res://scenes/world/planets/ember_moon.tscn`. The Resource still neither places,
streams, nor loads that scene. Production's separate
`EmberMoonStreamingBootstrap` resolves, registers, and streams the reference.

## Evidence and visual boundary

All three Resources are `NEW` / `modern_interpretation`. No source establishes
an Ember Moon destination. `SpaceBackdrop/CelestialOrangeBody` is palette
inspiration only: its node, local transform, 105 m decorative radius, simple
material, and presentation-only identity are not reused and are not evidence
of a physical body. Cinder Reach and its ringed moonlet are likewise separate
authored content and provide no orbital placement datum for Ember Moon.

The Resources themselves do not assign an absolute orbital cell. The separate
`NearbySectorOrbitalRegistry` now authors Ember's original modern 8,000 km datum
in a shared orbital frame. Production `Main` now owns one
`EmberMoonStreamingBootstrap`, its caller-physics observation binding, and one
`CommonWorldOriginRebaseOwner`. The bootstrap can own an isolated scene
generation, while the rebase owner atomically moves the station, Cinder, actors,
effects, and Ember roots together. None of those authorities is implied by these
definition Resources.

## First-loop boundary

The sole bounded content promise is enough authored data for the standalone
`EmberSurfaceLoopHost` proof to compose one orbital handoff, descent,
surface-flight handoff, landing region, on-foot egress, reboarding, takeoff, and
orbit return. That host is not selected or entered by production GameFlow or an
activity. This slice does not claim visitability, a global terrain,
circumnavigation, atmosphere, settlements, NPCs, economy, cargo, missions,
rewards, save, networking, or a production-ready runtime.

Focused verification loads the three Resources, proves both world/terrain and
world/terrain/coordinate-frame/landing joins, checks the exact scene reference
resolves without placing it, and round-trips detached copies through Godot
Resource serialization.
