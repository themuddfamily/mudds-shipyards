# Planetary landing composition validator

`PlanetaryLandingCompositionValidator` is the pure join between one validated
planetary world, its resolved terrain profile, one detached configured
`PlanetaryCoordinateFrame` snapshot, and one landing-region definition. It
retains no input and does not load scenes or resources.

## Exact identity and datum join

The landing region's `world_id` equals the resolved world ID, its `region_id`
must occur in the world's landing-region roster, and its `body_id` equals the
coordinate frame's configured body ID. The world's terrain ID equals the
resolved terrain profile ID. World, terrain, coordinate frame, and
landing region share one exact centre-to-sea-level radius. Landing minimum and
maximum elevations exactly equal the terrain envelope. These are authored-data
foreign-key checks, so approximate equality would hide drift.

The coordinate-frame snapshot uses its exact schema and must describe a
configured, finite, metre-scale frame at a live generation. The validator
returns detached structured errors, component evidence, stable joined facts,
and the common 12-key all-false authority roster.

## Body-local seam and tangent frames

A landing child point composes as:

```gdscript
var body_local := region.body_local_center_m \
    + region.body_local_basis * region_local_position
```

That body-local point is the seam into
`PlanetaryCoordinateFrame.body_local_to_orbital_position()`. Its absolute
integer-cell orbital coordinate remains stable across an origin rebase, while
the derived world-streaming vector changes by the committed translation delta.

The landing basis +Y is the outward radial normal at its centre; arbitrary yaw
about +Y remains valid. A coordinate frame's `surface_tangent` basis is one
separately configured north-aligned affine reference. It must not be treated as
every landing region's basis. Consumers that need it must explicitly transform
between that single tangent basis and the landing region's body-local basis.

## Precision and authority limits

The canonical 120 km fixture has roughly 7.8 mm `Vector3` spacing in the
project's standard single-precision build, so its centimetre/sub-metre authored
landing values compose coherently. At the shared 100,000 km safety ceiling,
body-local `Vector3` spacing is roughly 8 m. The large maxima are finite safety
bounds, not a promise of sub-metre landing precision at every supported radius;
a later production resolver must use a region-local/floating origin or reject a
body whose required resolution cannot be represented.

The validator owns no renderer, gameplay, streaming, save, network, physics,
world/terrain/collision generation, origin shift, weather clock, or audio
authority. It validates a coordinate-frame snapshot but never requests or
commits a rebase, moves an actor, approves a landing, or mutates any input.
