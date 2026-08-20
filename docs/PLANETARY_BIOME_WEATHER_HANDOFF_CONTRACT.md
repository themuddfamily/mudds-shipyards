# Planetary biome and weather handoff contract

`PlanetaryBiomeWeatherHandoffContract` is a bounded, data-only declaration for
one authored surface region. It records fixed biome/material layer IDs,
body-local altitude bands, weather profile kinds, visibility envelopes, opaque
audio hints, and route references.

The contract intentionally does not generate terrain, resolve materials,
simulate weather, stream cells, move actors, resolve hazards, or own audio.
Those responsibilities remain with later runtime authorities. `procedural_noise`
and other un-authored weather kinds are rejected, and all parallel arrays must
remain aligned. Snapshot and audit results are detached copies.

Validation is focused on the Ember Caldera authored fixture and is not evidence
of a complete visitable-planet production loop.
