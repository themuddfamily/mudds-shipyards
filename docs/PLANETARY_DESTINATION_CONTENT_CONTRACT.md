# Planetary destination content contract

`PlanetaryDestinationContentContract` is the data-only content join for one
authored visitable destination. The checked-in Ember Moon instance is
`res://assets/world/planets/ember_moon_content.tres`.

It records the bounded authored content required before a world is presented
as a destination:

- one named orbital silhouette and three fixed orbital/surface handoff
  landmarks;
- one substantial `ember_caldera` landing region with a 9,216 m² authored
  walkable support envelope;
- three named surface landmarks connected by the existing
  `ember_caldera_pad_to_staging` route;
- the `caldera_relay_scan` activity, an `ember_relay_data` reward key, and
  two recoverable failure paths;
- explicit activity, reward, and return/recovery authority IDs, including the
  existing `mudds_shipyards` return target.

The manifest only validates identity, references, cardinality, scale, and
handoff keys. It does not instantiate or stream the scene, generate terrain,
move a ship or player, select or complete an activity, grant a reward, save a
session, or own network/recovery state. The production owners remain
`ActivityDirector`/`GameFlow`, the existing landing/return contract, and the
existing world/streaming bindings.

Ember Moon is an original modern airless interpretation. The manifest is
content evidence for the bounded slice, not historical authentication and not
evidence of a completed packaged orbit-to-surface loop. Atmosphere, weather,
terrain generation/LOD production, save/network persistence, native hardware
performance, and human flight review remain separate gates.
