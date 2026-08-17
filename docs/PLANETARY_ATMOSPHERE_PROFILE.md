# Planetary atmosphere profile foundation

`PlanetaryAtmosphereProfile` is a strict typed, standalone Godot `Resource` for
one game-scale planetary atmosphere. It is Phase 10 foundation data only. It has
no dependency on `PlanetaryWorldDefinition`, and this slice does not place a
profile in any world, scene, renderer, or gameplay flow.

## Deterministic units

The audit publishes `unit_system = game_scale_si`. Field suffixes are part of
the contract:

| Suffix | Meaning |
| --- | --- |
| `_m` | metres relative to the planet's modeled surface datum |
| `_mps` | metres per second in the consuming world's coordinate basis |
| `_kg_m3` | kilograms per cubic metre |
| `_per_m` | linear RGB coefficient per metre; alpha is exactly `1` |
| `_db` | decibels |
| `_unitless` | normalized or dimensionless scalar |

`planet_radius_m` is the game-scale body radius. Altitudes are surface-relative,
not distances from the centre. `reference_altitude_m` is the altitude at which
`reference_density_kg_m3` applies. `density_scale_height_m` and
`density_falloff_exponent` describe a later consumer's falloff inputs; this
Resource does not evaluate a density curve.

The colour coefficients are linear scattering/absorption triples, not display
colours. Fog distances and maximum visibility are separate bounded hints. The
single cloud layer declares ordered base/top altitudes and normalized coverage.
Wind is a metric vector; weather intensity is a normalized hint, not a changing
weather state. Entry effects use an upper start altitude, lower full altitude,
and ordered minimum/full speeds. Exterior/interior audio IDs and gains are lookup
hints only; they do not load a resource or select a bus.

## Validation and snapshots

The profile rejects non-finite scalars, vector components, or colour channels;
out-of-range normalized, metric, optical, and audio values; unstable IDs;
untrimmed/duplicate evidence references; and inverted dependent ranges.
Atmosphere and cloud tops stay within the declared game-scale body, fog ends
within visibility, entry start stays within the atmosphere, and wind has a
finite magnitude ceiling.

`get_geometry_snapshot()`, `get_density_snapshot()`, `get_optics_snapshot()`,
`get_weather_snapshot()`, `get_entry_effect_snapshot()`,
`get_audio_hint_snapshot()`, and `get_audit_report()` return detached data. A
caller may mutate any returned dictionary or array without changing the shared
Resource. The evidence contract is explicitly `NEW / modern_interpretation` and
scoped to game-scale atmosphere parameters.

## Authority boundary

`get_authority_report()` returns explicit `false` values for renderer, gameplay,
weather-clock, save, audio, physics, world-generation, and network authority.
The profile cannot:

- create or configure renderer nodes, fog volumes, clouds, particles, or entry FX;
- advance time, choose weather, apply forces/damage, or decide interior/exterior state;
- play audio or own audio buses;
- persist, replicate, or migrate itself as runtime state; or
- place a planet or claim a `PlanetaryWorldDefinition` relationship.

A later world owner may hold a typed reference and copy a validated snapshot
into its own renderer, audio, weather, or gameplay adapters. Those consumers own
all lifecycle, generation, failure, and persistence behavior.
