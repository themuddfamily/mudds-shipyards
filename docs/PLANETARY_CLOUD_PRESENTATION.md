# Planetary cloud presentation foundation

`PlanetaryCloudPresentation` is a passive six-uniform adapter for a validated
`PlanetaryAtmosphereProfile`, its deterministic sampler, and one caller-owned
spatial `ShaderMaterial`. It is not a visible-cloud renderer. The repository
does not yet contain a production planetary cloud shader, mesh/volume, noise or
texture contract, lighting model, blend/depth policy, or production world
wiring. This foundation creates none of those and is not wired into Main or
Ember Moon.

## Caller-owned material contract

The composition owner calls `configure(profile, material)` once. The material
must already contain a spatial `Shader` with these exact names and types:

```glsl
uniform float cloud_base_radius_m;
uniform float cloud_top_radius_m;
uniform float cloud_coverage_unitless;
uniform float cloud_observer_layer_factor_unitless;
uniform vec3 cloud_wind_velocity_mps;
uniform vec3 cloud_wind_offset_m;
```

Extra uniforms are allowed and remain untouched. The adapter introspects the
shader schema rather than interpreting a missing parameter's null value. It
freezes the six exact baselines, a detached profile audit, and a private sampler,
then retains only weak material/shader identities. It never allocates, replaces,
or exposes a Material, Shader, texture, noise resource, geometry, volume, light,
environment, or camera. The caller must ensure that the material is exclusive
to the intended cloud renderer and that its geometry/shader interpret radii and
wind in the same body-centred consuming-world basis; this adapter cannot prove
sharing, attachment, scale, or origin.

## Observation and exact equations

The only sampling seam is:

```text
present_observation(
    observer_altitude_m,
    caller_time_seconds,
    weather_scalar,
    cloud_scalar,
    expected_generation
)
```

Altitude is finite metres relative to the profile's surface datum, bounded from
the body centre (`-planet_radius_m`) through the profile's supported altitude
ceiling. Weather and cloud scalars are finite closed-unit values. Caller time is
a finite nonnegative absolute value in a caller-owned local epoch; it is never a
delta and the adapter never accumulates, wraps, clamps, or tests monotonicity.

From the frozen profile:

```text
base_radius = planet_radius_m + cloud_base_altitude_m
top_radius = planet_radius_m + cloud_top_altitude_m
global_coverage = profile_cloud_coverage * cloud_scalar
global_wind = profile_wind_velocity_mps * weather_scalar
wind_offset = global_wind * caller_time_seconds
```

The offset magnitude must not exceed `1,048,576 m`; a larger or nonfinite result
returns `wind_offset_out_of_bounds`. The weather-clock owner must choose a new
epoch before that limit only where its future shader domain can repeat safely.
The adapter cannot silently wrap because the profile declares no texture/noise
period. Zero weather produces exact zero velocity and offset, and authored
negative wind components remain negative.

The private sampler is evaluated at the caller's observer altitude with zero
path/speed. Its `cloud_layer_factor` becomes only
`cloud_observer_layer_factor_unitless`. The exact membership is base-inclusive
and top-exclusive. Below base, at top, above the layer, and in sampler vacuum,
the observer factor is zero while the global layer coverage and wind continue
unchanged. This separation prevents an observer below clouds or in orbit from
erasing or freezing the global cloud layer.

These uniforms are bounded presentation facts, not an opacity, density field,
lighting solution, or promise that compatible geometry exists. A future shader
owner decides how to render them.

## Generation, lifecycle, and transactions

Successful configuration starts generation 1 and revision 1. An exact duplicate
observation with matching target values is signal-free. Invalid input, stale
generation, schema/identity failure, and offset overflow are atomic. A successful
`reset_for_reuse(expected_generation)` applies the exact captured baseline before
advancing the safe-integer-bounded generation and clearing the observation.

Tree exit transactionally restores the six baselines. Tree re-entry reapplies
the retained current generation without changing generation, revision, counters,
signals, or allocations. There is no `_process`, `_physics_process`, Timer,
Tween, AnimationPlayer, or private time.

Every apply keeps candidate state provisional, writes changed parameters, emits
one consolidated `Resource.changed` under a reentry guard, then revalidates the
exact material-to-shader identity, configured shader source, spatial six-uniform
schema, and all six read-back values. Only then do state, count, revision, and
`presentation_committed`
commit. Callback target replacement, schema mutation, and property overwrite
return distinct typed failures with no successful commit or presentation signal.
Prior values are restored whenever the original compatible material/shader
still exists. Persistent identity/schema corruption remains an honest red audit
until the composition owner restores it. Resource and presentation-signal
callbacks cannot reenter configure, present, or reset.

## Authority and limitations

Renderer parameter presentation is the only positive common authority.
Gameplay, streaming, save, network, physics, world/terrain/collision generation,
origin shift, weather clock, and audio remain false. Material/shader ownership,
cloud geometry/volume, textures/noise, density/lighting, weather selection,
clock/time accumulation/wrapping, wind simulation, camera, quality, origin
application, movement, landing, and gameplay are also explicitly false.

Evidence is `NEW`, `modern_interpretation`, `source_bounded=false`, confidence
`none`. Headless uniform assertions establish deterministic values and lifecycle,
not visible-cloud quality or GPU cost. No Forward+ render is meaningful until a
separately reviewed production shader and geometry contract exists.

## Focused verification

Run only:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 planetary_cloud_presentation_test
```

The suite freezes shader-schema gates; source detachment; exact layer boundaries;
global-versus-observer coverage and wind; caller-time/offset limits; duplicate
cadence; invalid/stale atomicity; exact six-parameter ownership; non-owned state;
transactional Resource/signal attacks; detach/re-entry/reset; weak expiry; deep
report detachment; and the exact authority, capability, and allocation rosters.
