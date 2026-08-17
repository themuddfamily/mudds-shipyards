# Planetary terrain LOD policy foundation

`PlanetaryTerrainLodPolicy` is a pure deterministic consumer of one valid
`PlanetaryTerrainProfile`. Configuration freezes a detached copy of the
profile's ordered clipmap rings, collision envelope, tile resolution, and tile
ceilings. The source Resource is neither retained nor mutated, and a configured
policy cannot be retuned by later caller mutation.

## Selection contract

`evaluate(camera_to_surface_distance_meters, collision_needed)` accepts an exact
finite nonnegative numeric distance no greater than the profile contract's
global LOD-distance ceiling. Booleans and strings are not numeric inputs;
`collision_needed` must be a boolean. Invalid input rejects without a partial
selection or retained-state change.

Clipmap ring distances are ordered nearest to farthest and are inclusive outer
boundaries. The selected render ring is the first ring whose outer distance is
greater than or equal to the camera-to-surface distance:

```text
ring 0:                   0 <= distance <= outer[0]
ring n, where n > 0: outer[n-1] < distance <= outer[n]
```

The exact outermost boundary participates in the last ring. A valid distance
beyond that boundary returns an accepted no-render-participation result with
ring index `-1`; it does not silently clamp to the farthest ring.

Collision participates only when the caller explicitly requests it and the
distance is less than or equal to the profile's collision maximum. The result
reports the profile's fixed collision LOD index even when collision does not
participate, so a later collision owner can inspect the frozen policy without
mistaking selection for generated collision.

## Tile-budget hints

The result gates the profile's exact ceilings; it does not invent an allocation
formula:

- while render participates, tile resolution, visible-tile ceiling, and
  resident-tile ceiling equal their frozen profile values;
- outside the render rings, those render hints are zero;
- collision-tile ceiling equals the profile ceiling only while collision
  participates, and is otherwise zero.

These are bounded planning hints, not reservations or live usage counts. A
later owner remains responsible for allocating tiles, resolving contention,
honouring the global ceilings across observers, and releasing resources.

## Purity and ownership

Evaluation has no delta, clock, history, hysteresis, actor, provider, or scene
input. Identical calls therefore return identical detached values regardless of
whether callers evaluate at 30, 60, or 120Hz. Results, snapshots, and audits are
deeply detached.

The audit retains the planetary contracts' exact common twelve-key authority
roster, all false. A separate policy-specific roster explicitly keeps height
generation, terrain-mesh, landing, and clock authority false without changing
the shared schema.

This policy owns no:

- height data, biome classification, or terrain/tile generation;
- terrain mesh, material, texture, renderer, or visibility application;
- physics body, collision shape, contact, or collision generation;
- world streaming, landing decision, actor movement, or gameplay state;
- clock, automatic process callback, origin shift, save, audio, or network
  authority.

Future systems may consume its hints, but they must own all generation,
allocation, rendering, collision, streaming, landing, timing, persistence, and
gameplay effects.
