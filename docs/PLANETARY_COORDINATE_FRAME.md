# Planetary Coordinate Frame foundation

`PlanetaryCoordinateFrame` is a standalone, typed metre-scale conversion and
floating-origin policy. It is intentionally not wired into `Main`, `GameFlow`,
the renderer, physics, world streaming, or persistence.

## Coordinate contract

One Godot world unit equals one metre.

| Frame | Representation | Meaning |
|---|---|---|
| Planetary-body local | bounded `Vector3` metres | Position from the configured body centre |
| Surface tangent | bounded `Vector3` metres | Affine patch at one surface reference; +X east, +Y radial up, +Z south (-Z north) |
| Radial altitude | scalar metres | `length(body_local) - body_radius` |
| Orbital | safe integer cells plus canonical offset | Stable system-wide absolute coordinate |
| World streaming | bounded `Vector3` metres | Orbital coordinate relative to the active streaming origin |

Surface-tangent Y equals radial altitude only along the reference normal. Away
from that normal, tangent Y remains the affine plane coordinate while altitude
remains radial. This prevents a flat local patch from silently claiming planet
curvature.

Orbital coordinates use this exact detached record:

```gdscript
{
    "schema_version": 1,
    "frame_id": &"stable_orbital_frame_id",
    "cell_x": 0,
    "cell_y": 0,
    "cell_z": 0,
    "offset_meters": Vector3.ZERO,
}
```

Cells must be integers in ±(2^53-1). Offsets are finite and canonical in the
half-open interval `[-cell_size/2, cell_size/2)` on every axis. The validator
rejects missing/extra fields, coercible floats, wrong frame IDs, unsafe cells,
and noncanonical offsets. Relative conversion subtracts integer cells before
float multiplication, so nearby sub-metre detail is not lost beside very large
orbital cell identities.

The configured mean radius is bounded to 1m–100,000km; cell size to
1m–1,000,000km; and the inclusive origin threshold to 1m–10,000km. Relative
body-local, tangent, and world-streaming components are bounded to ±1,000,000km.
These are numerical safety limits, not promises about playable planet sizes or
travel speeds.

## Deterministic conversion

Callers configure one immutable body ID, orbital frame ID and cell size, mean
radius, absolute body centre, surface reference direction, nonparallel north
hint, absolute streaming origin, and origin-shift threshold. Successful
configuration starts local mapping generation 1.

`encode_body_local_position()` and `decode_world_streaming_position()` return
the same canonical record: body ID, local generation, body-local and
surface-tangent positions, radial altitude, absolute orbital coordinate, and
world-streaming position. Repeating a conversion with the same state and input
produces the same result. Local conversion requires the caller's expected
generation; pre-rebase local values fail closed after a commit. Absolute orbital
coordinates carry no origin generation and remain meaningful across rebases.

## Explicit origin rebase

Rebasing has no hidden tick or automatic trigger:

1. `evaluate_origin_shift()` reports whether a caller-owned focus is at or
   beyond the inclusive threshold.
2. `request_rebase()` freezes source/target generations, canonical source and
   target orbital origins, and `world_translation_delta`.
3. The caller may coordinate its own streaming, physics, rendering, and actor
   work, then call `commit_rebase()` with the exact request ID and source
   generation—or `cancel_rebase()`.
4. Commit advances exactly one local generation and changes only the policy's
   streaming-origin coordinate. It returns the translation delta but never
   applies it to a node.

Only one request can be pending. Duplicate, stale-generation, wrong-ID,
nonfinite, unsafe-cell, out-of-bounds, and below-threshold requests reject
without coordinate or generation drift. Snapshots, coordinates, requests,
results, and audits are deeply detached dictionaries containing values only.

## Deliberate ownership boundary

This foundation owns coordinate validation, deterministic conversion, threshold
evaluation, and rebase identity only. It owns no:

- `_process` or `_physics_process` loop;
- actor, camera, or scene-node movement;
- renderer or physics origin shift;
- world-streaming coordinator or distance-policy call;
- planetary world-definition, terrain, atmosphere, or geometry data;
- gameplay, missions, rewards, ships, berths, saves, or network authority.

A later integration may compose this policy with planetary definitions and a
streaming owner. That layer must explicitly apply returned translation deltas
and choose when its physics, renderer, moving interiors, particles, audio, and
streaming generations are safe to shift.
