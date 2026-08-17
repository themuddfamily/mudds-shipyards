# Planetary sun-lighting policy foundation

`PlanetarySunLightingPolicy` is a pure, caller-driven spherical-horizon and
clear-sky/airless recommendation policy. It returns normalized bounded hints;
it does not mutate a `DirectionalLight3D`, `Environment`, `Sky`, material, or
any other renderer object.

## Honest source boundary

`configure(world, atmosphere = null)` accepts one valid
`PlanetaryWorldDefinition`. An atmospheric world requires one valid
`PlanetaryAtmosphereProfile` whose profile ID exactly equals the world's
atmosphere definition ID and whose planet radius exactly equals the world's
sea-level radius. An airless world requires a null atmosphere. Configuration
also requires the sources' exact common zero-authority contracts.

Successful configuration freezes detached world, body, atmosphere geometry,
density/optics, and source-evidence values, plus a private atmosphere sampler
when needed. It retains no source Resource. Rejected configuration is retryable;
accepted configuration is immutable.

The current schemas provide no star spectrum, luminosity, angular diameter,
terrain horizon, terrain albedo, cloud shadow, or multiple-scattering model.
Consequently this policy cannot produce calibrated colorimetry, candela, lux,
or an absolute Godot light energy. Its colors are normalized linear-RGB hints
and every energy/contribution output is unitless in `[0,1]`.

## Strict caller observation

`evaluate(observation)` accepts exactly:

```text
body_local_observer_m: Vector3
normalized_body_to_sun: Vector3
```

Both values are in `planetary_body_local`. The position uses metres from the
body centre and must be finite, within `PlanetaryCoordinateFrame`'s ±1 billion
metre component bound, and on or outside the world's sea-level reference
sphere. The exact centre returns `observer_radial_up_undefined`; all other
reference-sphere interior points reject because this policy has neither terrain
height nor an interior horizon contract.

The second vector points from the body centre toward a distant sun. Its length
must differ from one by no more than `0.0001`, then a private normalized copy is
used. This distant-source direction is caller-owned. The policy does not verify
freshness, derive an orbit, read a clock, or retain ephemeris state. Body-local
observations are invariant under translation-only world-origin rebases, so no
origin generation is invented.

No missing or extra keys are accepted. Schema/type/finiteness errors precede
configured-state errors; configured body bounds follow. Evaluation is stateless
and repeated complete observations are byte-for-byte deterministic.

## Spherical reference horizon

For observer position `p`, radius `r=length(p)`, sea-level radius `R`, and unit
body-to-sun direction `s`:

```text
up = p / r
sun_elevation_sine = clamp(dot(up, s), -1, 1)
sun_elevation = asin(sun_elevation_sine)
horizon_sine = -sqrt(max(1 - (R/r)^2, 0))
horizon_elevation = asin(horizon_sine)
horizon_clearance = sun_elevation - horizon_elevation
```

This matters above the surface: the spherical horizon is depressed, so a sun
at zero local tangent elevation can remain directly visible. A clearance more
than `0.000001 rad` is direct-visible. Clearance within that named comparison
tolerance is the horizon and has zero directional energy. Negative clearance
is occulted by the reference sphere. This is not a terrain or building
occlusion query and deliberately ignores finite sun-disc penumbra.

The result publishes sine, radians, degrees, spherical horizon, angular
clearance, radial up, radius, altitude, and direct-visibility truth.

## Day, night, and twilight factors

Airless worlds have a hard terminator: direct-visible is exact day; horizon and
occulted directions are night; twilight is zero. An atmospheric world uses the
same behavior when the observer is at or above the exact atmosphere-top
boundary.

Inside a configured atmosphere, direct-visible remains day. Exact horizon is
the full atmospheric-twilight proxy. Negative clearance from horizon down to
`-6 degrees` is the NEW game-scale twilight interval; its lower endpoint is
inclusive. Let `x=clamp((clearance-(-6°))/6°,0,1)`. Then:

```text
twilight_factor = x*x*(3 - 2*x)
night_factor = 1 - twilight_factor
day_factor = 0
```

Below the lower endpoint, night is one. Factors always remain `[0,1]` and sum
to one. `-6 degrees` is a display-policy choice, not a claim of physically
calibrated civil twilight. Stable tests use the named angular tolerance rather
than claiming impossible exact trigonometric ULP classification.

## Clear-sky attenuation approximation

For a directly visible sun while the observer is inside the atmosphere shell,
the ray distance to outer radius `O=R+atmosphere_top` is:

```text
q = r * sun_elevation_sine
direct_path = -q + sqrt(q*q + O*O - r*r)
```

The path is capped to the profile's maximum visibility before sampling the
frozen atmosphere with zero speed/weather/cloud scalars. RGB optical
transmittance is used as the directional tint source; its luminance is the
unitless directional energy factor. The tint is normalized by its strongest
channel. No unattenuated star color or absolute energy is known.

A separate tangent-to-shell path
`sqrt(max(O*O-r*r,0))`, also visibility-capped, supplies an explicitly bounded
horizon-scattering proxy. `1 - horizon_transmittance_luminance` is the scattered
fraction. The NEW display mapping is:

```text
ambient_energy = scattered_fraction * (0.25*day + 0.12*twilight)
sky_contribution = scattered_fraction * (day + twilight)
```

The normalized ambient tint comes only from frozen Rayleigh plus Mie
coefficients. Absorption participates in sampler transmittance. Zero
coefficients yield exact white direct transmission and zero ambient/sky proxy.
Airless, local vacuum, and full night yield exact zero atmosphere contribution.
This is not multiple scattering, cloud lighting, terrain bounce, or weather.

## Output and authority

Accepted results contain detached input, geometry, classification,
`directional_light_hint`, `ambient_sky_hint`, and atmosphere/optical dictionaries.
The directional hint explicitly reports `absolute_energy_or_lux=false`; the
ambient hint reports `multiple_scattering_physical=false`.

The policy evidence roster is exactly `{content_class: NEW, status:
modern_interpretation, source_bounded: false, confidence: none}` and is separate
from detached source evidence. Audit validity self-checks it.

The common twelve-key authority roster is all false. Adjacent authority also
denies star/ephemeris/time ownership, directional light/Environment/Sky/material
ownership, renderer application, shadows and occlusion, terrain horizon/albedo,
cloud/weather choice, camera, origin/rebase, physics, gameplay, streaming, save,
and network control.

Headless tests establish deterministic values, exact contracts, and bounds.
They do not establish visual quality or physical calibration, so no render is
appropriate for this foundation.
