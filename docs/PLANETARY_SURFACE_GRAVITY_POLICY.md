# Planetary surface gravity policy foundation

`PlanetarySurfaceGravityPolicy` is a pure, stateless evaluator for radial
gravity and tangent-orientation hints in planetary body-local coordinates. It
does not make a craft or character fall. A later physics owner may consume a
sample, but remains responsible for all movement, integration, collision, and
gameplay decisions.

## Composed datum

Configuration accepts exactly four inputs:

1. a valid `PlanetaryWorldDefinition`;
2. its valid resolved `PlanetaryTerrainProfile`;
3. a valid configured `PlanetaryCoordinateFrame`; and
4. a finite sea-level reference acceleration in metres per second squared.

The world terrain ID must equal the resolved terrain profile ID. World,
terrain, and coordinate frame must publish exactly the same body-centre to
sea-level radius; equality is exact, not approximate. The policy also rejects
source audits that claim authority. Successful configuration freezes the world,
body, and terrain identities, source schema versions, coordinate-frame
generation, elevation envelope, surface radii, reference acceleration, tangent
north seed, and detached world/terrain evidence. It retains no source object,
and later Resource edits or coordinate-frame rebases cannot retune it.

The acceleration is caller-authored game data. This foundation does not infer
mass, density, or historical/real-body gravity from the body's radius.

## Explicit sample contract

`sample(body_local_position_meters)` is the only evaluation entry point. The
caller supplies a finite position relative to the body centre. No delta, clock,
actor, Node, transform owner, or global/world-streaming position is sampled
implicitly.

For an accepted point with radial distance `r`, sea-level radius `R`, and
configured reference acceleration `g0`, the policy returns:

```text
radial_up = body_local_position / r
altitude = r - R
gravity_magnitude = g0 * (R / r)^2
gravity_vector = -radial_up * gravity_magnitude
```

The result also contains an orthonormal, positive-determinant body-local tangent
basis with `+X` east, `+Y` radial up, and `+Z` south (`-Z` north), plus the
individual east/north/south vectors. North is the coordinate frame's frozen
surface-north seed projected onto the current tangent plane. At a point where
that projection is degenerate, the least-aligned body axis supplies a stable
deterministic fallback; `tangent_fallback_used` makes that boundary visible.
These are orientation hints, not a rotation or movement command.

All results, nested shell data, snapshots, source evidence, and audits are
deeply detached.

## Centre and shell boundaries

The radial domain is explicit:

- NaN or infinite positions reject as `nonfinite_body_local_position`.
- Radius at or below `0.000001 m` rejects as
  `radial_up_undefined_at_center`; no arbitrary up vector is fabricated.
- Positive radii below the terrain profile's minimum surface radius reject as
  `below_minimum_surface_shell`. This policy has no interior mass/density model.
- The exact minimum terrain radius, sea-level radius, and maximum terrain radius
  are accepted, inclusive, named boundaries.
- Positions between the terrain endpoints are reported as inside the terrain
  elevation envelope.
- Positions above the maximum terrain radius remain accepted and continue the
  inverse-square equation.
- Radius above `1,000,000,000 m` rejects as
  `body_local_position_out_of_bounds`, matching the bounded local-coordinate
  foundation and keeping every returned scalar finite and positive.

The shell report exposes the named state, endpoint flags, envelope membership,
and signed clearance from both terrain-radius endpoints. It does not classify
terrain height, slope, roughness, collision, landing suitability, atmosphere,
orbit, or navigation.

## Purity and authority

The audit publishes the exact common twelve-key authority roster, all `false`:
renderer, gameplay, streaming, save, network, physics, world generation,
terrain generation, collision generation, origin shift, weather clock, and
audio. A separate adjacent roster explicitly keeps Node movement, physics
integration, collision, origin rebase, landing decision, renderer, clock,
streaming, save, and network authority false.

The policy owns no:

- Node movement, velocity, force application, physics step, or delta;
- collision body, collision generation, contact, or terrain sampling;
- landing eligibility, assist, berth, route, spawn, or re-entry decision;
- renderer, material, atmosphere, camera, or presentation state;
- origin rebase, world streaming, lifecycle, automatic process, or clock;
- gameplay, save, migration, reward, audio, or network authority.

Consumers must validate the returned `accepted` flag and remain the sole owners
of every effect they choose to derive from a sample.
