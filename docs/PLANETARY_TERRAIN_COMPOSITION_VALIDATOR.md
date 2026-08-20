# Planetary terrain composition validator

`PlanetaryTerrainCompositionValidator` is the authority-free join between one
validated `PlanetaryTerrainProfile` and one configured
`PlanetaryTerrainLodPolicy`. It freezes no resources and performs no terrain
work; it proves that the future terrain owner will use one coherent set of
scale, clipmap, collision, tile-budget, and biome/material declarations.

The policy must retain the exact profile identity, schema, ring distances,
collision ring and distance, and all four tile ceilings. A changed profile must
therefore be explicitly reconfigured rather than silently consuming a stale
policy. The profile's ordered biome IDs are returned as the material/splat
channel order under `declared_biome_layer_order`; this is a deterministic data
seam, not a material allocator or renderer.

The detached report exposes the shared metres-based LOD and collision limits,
the origin-shift threshold that a later observer owner may use, the ordered
surface-classification layers, policy snapshot, evidence, and a common
all-false authority roster. It owns no renderer, gameplay, streaming, save,
network, physics, terrain generation, collision generation, origin shift,
weather clock, or audio behavior.

Focused acceptance:

```bash
godot --headless --audio-driver Dummy --path . \
  --script res://tests/planetary_terrain_composition_validator_test.gd
```
