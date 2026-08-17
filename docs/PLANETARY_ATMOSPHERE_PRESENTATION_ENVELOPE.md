# Planetary atmosphere presentation envelope foundation

`PlanetaryAtmospherePresentationEnvelope` is a pure, immutable spatial policy
for presentation callers that must cross the atmosphere top, cloud layer edges,
or the hard spherical-sun visibility boundary without directly exposing a
single-sample value step. It produces normalized weights only. It does not
change a physical profile, sample density, render anything, or integrate with
the existing fog, sky, cloud, sun, or entry-heat adapters.

This is `NEW` / `modern_interpretation` presentation tuning. The widths are not
physical atmosphere claims and are not added to
`PlanetaryAtmosphereProfile`.

## Immutable configuration

`configure(profile, atmosphere_top_width_m, cloud_base_width_m,
cloud_top_width_m, sun_visibility_width_radians)` accepts one currently valid
`PlanetaryAtmosphereProfile` with its exact zero-authority contract. It freezes
detached profile audit, geometry, weather, and four explicit widths, then
retains no source `Resource`.

Every width must be finite and strictly positive. The atmosphere width must fit
within `[reference_altitude, atmosphere_top]`. Each cloud width must fit within
the cloud layer and their sum must not exceed `cloud_top-cloud_base`, so the two
one-sided ramps never overlap. Equality is valid and leaves one exact
full-weight point. The sun width must fit between the sun policy's exact direct
visibility tolerance and `PI` radians. Zero, negative, nonfinite, over-span,
over-angle, and overlapping values reject before configuration commits.
Successful configuration is immutable; rejected configuration remains
retryable.

## Caller observation and raw endpoints

`evaluate(observation)` accepts exactly:

```text
altitude_m: finite profile-relative metres
sun_horizon_clearance_radians: finite signed radians in [-PI, PI]
```

Altitude is bounded from the body centre (`-planet_radius_m`) through the
profile's global supported atmosphere-altitude ceiling. The sun clearance is
the caller-owned result of the spherical horizon calculation; this foundation
does not derive radial up, observe a sun direction, own an ephemeris, or verify
provenance.

Every result republishes the unchanged raw contracts:

```text
inside_atmosphere = altitude < atmosphere_top
vacuum = altitude >= atmosphere_top
inside_cloud_layer = cloud_base <= altitude < cloud_top
direct_sun_visible = clearance > 0.000001 rad
```

The first two match `PlanetaryAtmosphereSampler`'s exact vacuum boundary, the
cloud layer remains base-inclusive/top-exclusive, and direct visibility keeps
`PlanetarySunLightingPolicy`'s strict named tolerance. A smooth presentation
weight never replaces or moves those facts.

## One-sided smoothstep equations

For `S(x)=x*x*(3-2*x)` after clamping `x` to `[0,1]`:

```text
atmosphere_coordinate = clamp((atmosphere_top - altitude) / atmosphere_width)
atmosphere_weight = S(atmosphere_coordinate)

cloud_base_coordinate = clamp((altitude - cloud_base) / cloud_base_width)
cloud_top_coordinate = clamp((cloud_top - altitude) / cloud_top_width)
cloud_observer_weight = S(cloud_base_coordinate) * S(cloud_top_coordinate)

sun_coordinate = clamp(
    (clearance - direct_visibility_tolerance) / sun_visibility_width
)
sun_visibility_weight = S(sun_coordinate)
```

The atmosphere value is exactly zero at and above the raw top and exactly one
at and below the inner width edge. Cloud observer weight is zero outside and at
both layer endpoints, then reaches one only inside the layer. Sun weight stays
zero through the strict visibility boundary and ramps only on its visible side.
All four component ramps have exact zero first derivative at their endpoints.

These weights are intended for a later production composition caller. Such a
caller can blend a presentation-only renderer delta from its exact baseline,
for example `baseline + atmosphere_weight * (raw - baseline)`, without
retuning the sampler or profile. Global cloud coverage/wind must not be
multiplied by the observer-only cloud weight. No current adapter API consumes
these values, deliberately avoiding a second renderer owner in this slice.

## Purity, evidence, and authority

Evaluation has no delta, clock, retained observation, process loop, hysteresis,
or cadence state. Equal complete observations return equal detached values at
any call count. Teleports can still cross a complete spatial band in one caller
tick; any temporal handling is a later caller-owned decision.

The exact common authority roster is all false: renderer, gameplay, streaming,
save, network, physics, world/terrain/collision generation, origin shift,
weather clock, and audio. Adjacent authority also denies ownership of the
sampler/profile endpoints, presentation adapters, renderer resources,
Environment/Sky/material/light/cloud targets, time/delta/hysteresis,
weather/ephemeris, and production systems.

Snapshots, evaluations, and audits contain detached transport-safe values.
The focused suite freezes configuration atomicity, source detachment, exact raw
boundaries, smoothstep midpoint/endpoints and monotonicity, cloud overlap
rejection, angular/altitude bounds, cadence independence, exact evidence and
zero-authority rosters, and structured-red audit behavior. No render is valid
for this renderer-neutral foundation.
