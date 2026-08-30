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
- one 16,640-vertex / 32,768-triangle relief-matched collision shape reaching
  the profile's 1.5 km physical boundary;
- a 750 m flat approach envelope covering the complete authored landing
  corridor, with relief blended back outside it;
- a 94 m visual opening for the authored landing-floor disc and a separate
  48 m square collision opening for the existing 96 m walkable patch.

The collision surface is generated independently of the visual grid overlap.
Its inner loop follows the authored patch's exact square boundary, then expands
to the profile's circular collision limit while sampling the same spherical
height field as the renderer. This keeps the centre support single-owned and
provides physical relief beyond the old 256 m finest-ring footprint.
When an authored collision clearance exists, that surface remains centred on
the authored flatten/landing direction and its immutable concave shape is
reused across later visual-focus rebuilds. The visual clearance is also tested
against that fixed body direction rather than drifting with the current focus.
This lets a production caller move the visible rings without moving the pad
hole, duplicating landing support, or rebuilding 32,768 collision triangles.

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
