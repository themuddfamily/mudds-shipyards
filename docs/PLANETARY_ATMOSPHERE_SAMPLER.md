# Planetary Atmosphere Sampler foundation

`PlanetaryAtmosphereSampler` is a pure, deterministic consumer of one validated
`PlanetaryAtmosphereProfile`. Configuration copies detached value snapshots and
releases the source Resource; neither configuration nor sampling mutates it.
This foundation is not wired into a world, renderer, physics body, ship, weather
clock, gameplay flow, audio system, save, or network path.

## Inputs and units

`sample(altitude_m, path_distance_m, speed_mps, weather_scalar, cloud_scalar)`
uses the profile's game-scale SI units:

- altitude is finite metres relative to the profile surface datum;
- path distance is finite, nonnegative metres for a local homogeneous optical
  estimate;
- speed is finite, nonnegative metres per second;
- optional weather and cloud multipliers are normalized `0..1` and default to
  one.

Altitude is bounded from the body centre (`-planet_radius_m`) through the
profile's global supported atmosphere-altitude ceiling. Path and speed use the
profile contract's global visibility and entry-speed ceilings. Values outside
those bounds, invalid normalized multipliers, NaN, and infinity reject.
Sampling takes no delta or clock time, so equivalent calls at 30, 60, or 120Hz
return identical values and do not accumulate state.

## Equations and exact boundaries

Let `h0` be reference altitude, `ht` atmosphere top, `H` density scale height,
`p` falloff exponent, and `rho0` reference density.

Below the reference, density clamps to the reference value. Below the atmosphere
top, the sampler evaluates:

```text
height = max(altitude - h0, 0)
density_ratio = exp(-pow(height / H, p))
density_kg_m3 = rho0 * density_ratio
```

At and above `ht`, the result is exact vacuum: zero density, optical depth, fog,
cloud, wind, and entry intensity; optical transmittance is one and visibility is
the profile maximum. This explicit ceiling may be discontinuous with the last
representable point below it.

The sampler deliberately performs a local homogeneous path estimate rather than
inventing curved-atmosphere ray integration:

```text
extinction_rgb = rayleigh_rgb + mie_rgb + absorption_rgb
local_extinction_rgb = extinction_rgb * density_ratio
depth_rgb = clamp(local_extinction_rgb * path_distance, 0, 64)
depth = luminance(depth_rgb)
transmittance = exp(-depth)
```

One-optical-depth visibility is the smaller of the authored maximum and
`1 / max(local_extinction_rgb)`. Zero extinction and vacuum use the authored
maximum without an epsilon-dependent division.

Fog follows the authored path interval exactly:

```text
t = clamp((path_distance - fog_start) / (fog_end - fog_start), 0, 1)
smooth_distance = t * t * (3 - 2 * t)
fog_factor = smooth_distance * fog_density * density_ratio * weather_scalar
```

Fog is exactly zero at the start and reaches the bounded authored density term
at the end; it is never silently forced opaque. Visibility and fog are
independent deterministic hints, not a rendered ray march or line-of-sight
query.

The cloud layer is the field-complete half-open box `[base, top)`:
`cloud_layer_factor = profile_coverage * cloud_scalar` inside and zero outside.
No un-authored transition thickness or midpoint peak is invented. Wind is
`profile_wind * weather_scalar`, preserving its authored metric direction and
500m/s bound. Vacuum overrides both to exact zero. The sample separately returns
`profile_weather_intensity * weather_scalar` for a later weather consumer.

Entry altitude is zero at the upper start threshold and linearly reaches one at
the lower full threshold. Entry speed is zero at the minimum threshold and
linearly reaches one at full speed. The two factors multiply. Values below the
full altitude or above the full speed stay clamped at one; vacuum overrides the
product to zero.

## Result and ownership

Each accepted result contains detached inputs plus bounded density ratio and
kg/m³ density, local RGB extinction, RGB/scalar optical depth and transmittance,
visibility, fog factor, cloud-layer factor, wind velocity, and entry-effect
intensity. Results, configuration snapshots, and nested audits are deeply
detached.

The sampler owns no:

- `_process`, `_physics_process`, delta, or weather clock;
- renderer, fog volume, cloud, particle, or entry-FX node;
- physics force, drag, heating, collision, or ship movement;
- gameplay, damage, mission, reward, or world-generation decision;
- audio playback, bus, save, migration, or network authority.

Later adapters may consume these values, but they must own application timing,
scene lifecycle, physical forces, rendering, audio, persistence, and replication.
