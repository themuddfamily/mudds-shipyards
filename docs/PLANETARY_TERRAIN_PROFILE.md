# Planetary terrain profile

`PlanetaryTerrainProfile` is a typed, side-effect-free contract for the scale
and budgets of a future planetary terrain implementation. It deliberately has
no dependency on a planetary world definition or atmosphere profile, so those
resources can be composed later without either one owning the other.

## Deterministic coordinate and unit contract

- `reference_planet_radius_meters` is the game-scale radial distance from the
  body-centred planetary scene root to the shared sea-level datum. Its composable
  default is 120,000 m, exactly matching the world and atmosphere defaults.
  Elevations are signed metre offsets from that reference; the minimum elevation
  must still leave a positive radius. The default −2,500..8,500 m envelope sits
  wholly inside the default atmosphere's 20,000 m top.
- All distances are metres and landing slopes are degrees. Tile resolution is
  vertices per edge, while tile budgets are exact integer tile ceilings. No
  implicit world-scale conversion is permitted.
- The current LOD strategy is `clipmap_rings`. Ring distances are inclusive
  outer distances from a later terrain focus and are stored strictly from the
  finest/nearest ring to the coarsest/farthest ring.
- Collision names one clipmap ring index, where zero is finest, and an exact
  maximum distance no farther than that ring. These are data limits, not a
  collision builder.
- Tile grids use a bounded `2^n + 1` vertex edge so neighbours can share their
  boundary sample. Visible, resident, and collision tile counts are ceilings;
  resident covers visible, and collision never exceeds visible.
- Biome IDs are unique lowercase snake-case IDs. Declared order is retained as
  the deterministic material/splat channel order; no profile method reorders
  them.
- Profile and biome IDs use the shared 1–64 character grammar and begin with a
  lowercase letter, so a valid profile identity is also a valid world logical
  reference.
- Landing slope and roughness are eligibility limits only. Roughness means the
  maximum peak-to-mean height deviation, in metres, inside a later evaluator's
  chosen footprint. This contract does not choose that footprint or approve a
  site.
- `origin_shift_threshold_meters` is observer distance from the current local
  origin at which a later owner may request a shift. The profile neither tracks
  an observer nor performs a shift.

## Validation, snapshots, and audit

Every float must be finite and inside the bounds published as class constants.
Cross-field validation rejects inverted elevations, collision outside its LOD
ring, inconsistent tile ceilings, duplicate/invalid biome IDs, and an origin
shift threshold at or beyond the planet radius. `get_snapshot()` and `audit()`
return deeply detached dictionaries and packed arrays, so presentation or tool
callers cannot mutate the source resource through a returned value.

`get_planet_radius_meters()`, `get_minimum_elevation_meters()`, and
`get_maximum_elevation_meters()` are canonical composition accessors. Evidence
is explicitly `NEW / modern_interpretation`, with a bounded reference roster and
scope limited to game-scale terrain parameters.

The audit freezes the schema, units, ordering, LOD/radius references, validation
errors, and the full snapshot. It explicitly reports false for terrain renderer,
terrain generation, collision generation, gameplay, streaming, save, network,
and origin-shift authority. It also publishes the shared nested authority roster
and nested evidence vocabulary used by the other planetary contracts, without
granting any authority.

## Deliberate limits

This foundation does not select a height source, generate terrain or collision,
allocate meshes or textures, stream tiles, shift an origin, classify a live
surface, approve a landing, mutate gameplay, persist data, or integrate with
`Main`, `GameFlow`, HUD, world streaming, a planetary world definition, or an
atmosphere profile. Those remain later, explicit composition steps.
