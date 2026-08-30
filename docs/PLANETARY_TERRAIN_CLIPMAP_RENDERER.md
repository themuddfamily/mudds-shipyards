# Planetary terrain clipmap renderer

`PlanetaryTerrainClipmapRenderer` is the first runtime terrain generator for an
authored planetary surface. It consumes one validated `PlanetaryTerrainProfile`
and builds only when its owner explicitly calls `rebuild()` with a finite
body-local focus and the current generation.

The renderer maps nested tangent grids onto the profile's spherical sea-level
datum. Height sampling is continuous in body direction, so the same location
has the same height when the caller rebuilds at another radial focus. Each
coarser grid is inset by a bounded radial bias; this hides LOD cracks without
coplanar overlapping faces. Vertex colours supply shoreline, lowland, highland,
rock and snow bands through one shared material.

Aurora currently uses all five authored LOD extents at a 65 × 65 grid per ring:

- 21,125 generated vertices;
- 40,096 rendered triangles after the landing-floor visual clearance;
- one 7,904-triangle finest-ring collision shape;
- a 750 m flat approach envelope covering the complete authored landing
  corridor, with relief blended back outside it;
- a 94 m visual opening for the authored landing-floor disc and a separate
  48 m square collision opening for the existing 96 m walkable patch.

The component hard-caps ring count, grid resolution, vertices and triangles
before mutation. Rebuild is staged and replaces the prior committed root only
after every ring is valid. Retirement and rebuild are generation-fenced;
detach rejects hidden rebuilds while retaining the last committed terrain for
ordinary re-entry.

This slice owns terrain rendering and generated collision only. It does not
observe a camera, tick automatically, stream tiles asynchronously, move an
actor, shift an origin, select a landing, provide navigation, save, or network.
Aurora still has no production `Main`/`GameFlow` route, so this renderer does
not by itself make the destination visitable.

Focused checks:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/planetary_terrain_clipmap_renderer_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/aurora_temperate_authored_scene_test.gd
```
