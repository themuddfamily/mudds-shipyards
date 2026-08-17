# Planetary sun presentation foundation

`PlanetarySunPresentation` is a passive adapter between the pure
`PlanetarySunLightingPolicy` and one caller-owned `DirectionalLight3D`. It is
not wired into Main, Ember Moon, streaming, travel, or GameFlow. It creates no
light and does not make a world visitable.

## Composition and lifecycle

The composition owner calls:

```text
configure(world, atmosphere_or_null, directional_light,
          authored_baseline_energy, authored_baseline_color)
```

The world/profile join follows `PlanetarySunLightingPolicy` exactly: an
atmospheric world requires the matching valid profile and an airless world
requires null. The component configures a private policy that retains no caller
Resource, then freezes its detached snapshot. Later mutation or release of the
source definitions cannot retune the presentation.

The target must be an existing, non-queued `DirectionalLight3D`. The explicit
authored baseline must exactly equal its current `light_energy` and
`light_color`; configuration never silently overwrites an unexpected light.
Energy is finite in the adapter safety range `[0,64]`, not a physical or lux
range. Every color channel is finite in `[0,1]`. The target remains
caller-owned and is retained only through a weak identity.

`present_observation(observation, expected_generation)` accepts the policy's
exact body-local observation:

```text
body_local_observer_m: Vector3
normalized_body_to_sun: Vector3
```

The caller owns both values and cadence. There is no delta, process callback,
clock, timer, interpolation, ephemeris, orbit derivation, or observation
freshness inference. Invalid policy input, stale or non-integer generations,
an expired/queued target, or invalid output fails without changing retained or
renderer state. An exact duplicate with an exact target is signal-free; a
duplicate repairs external drift in either owned property.

Configuration commits generation 1. `reset_for_reuse(expected_generation)`
restores the baseline before advancing one safe-integer-bounded generation and
clearing the retained evaluation. Tree exit restores the baseline. Tree re-entry
reapplies the retained generation without changing generation, revision,
counter, or signal count. Independent target tree exit/re-entry has the same
baseline/current behavior. A target that is destroyed remains a structured-red
identity until its composition owner destroys the adapter; there is no rebind
or replacement authority.

All writes are transactional. Candidate state remains provisional until both
properties have been written and read back exactly from the same live target.
An identity or readback failure attempts to restore the cached prior pair and
returns `target_changed_during_apply`,
`renderer_state_changed_during_apply`, or `rollback_failed`; it never commits
candidate state or emits `presentation_committed`. `DirectionalLight3D` is a
Node rather than a Resource, so the adapter does not invent a consolidated
`Resource.changed` notification. Its own commit signal fires only after both
renderer properties and retained state have committed, and all public mutators
reject synchronous signal/lifecycle re-entry.

## Exact two-property mapping

The policy has no star spectrum, luminosity, or absolute Godot energy, so its
outputs are normalized hints. Let authored baseline energy/color be `E` and
`C`, and the accepted policy recommendation be factor `f` and normalized
linear-RGB tint `T`. The adapter owns exactly:

```text
DirectionalLight3D.light_energy = renderer_real(E * f)
DirectionalLight3D.light_color.rgb = C.rgb * T.rgb
DirectionalLight3D.light_color.a = C.a
```

Both `f` and every `T` channel are in `[0,1]`, so outputs never exceed the
authored baseline. Direct airless or above-atmosphere daylight returns white
`T` and unit `f`, preserving the exact baseline. The horizon, occulted night,
and atmospheric twilight have zero directional energy; their neutral white
color hint retains baseline color metadata while energy disables the light.
Atmospheric direct daylight may reduce and tint the baseline through the
policy's bounded clear-sky approximation. `renderer_real` canonicalizes the
finite scalar to the build's `real_t` representation before the property write;
post-write verification remains exact rather than hiding drift behind an
epsilon.

This is baseline-relative display modulation, not calibrated colorimetry,
candela, or lux. In particular, `normalized_body_to_sun` is used only by the
policy's visibility/attenuation calculation. A composition owner must
separately orient the `DirectionalLight3D` so its emitted local `-Z` axis is
consistent with the caller's coordinate frame. This adapter does not verify or
change direction.

## Exact ownership boundary

The only owned renderer properties are:

- `DirectionalLight3D.light_color`
- `DirectionalLight3D.light_energy`

Transform/rotation, `light_intensity_lux`, temperature, angular distance,
shadow settings, cull mask, indirect energy, volumetric-fog energy, sky mode,
visibility, layer/parent/owner, Environment/Sky/material values, and target
lifetime remain untouched.

Renderer property presentation is the only positive common authority.
Gameplay, streaming, save, network, physics, world/terrain/collision
generation, origin shift, weather clock, and audio are false. The adjacent
authority roster also denies light-node creation/ownership, direction,
ephemeris/time, absolute energy/lux, calibrated colorimetry, temperature,
angular size, shadows/occlusion, terrain/cloud/weather, Environment/Sky,
camera, origin, physics, gameplay, streaming, save, and network authority.

Policy evidence is exactly `NEW`, `modern_interpretation`,
`source_bounded=false`, confidence `none`, and is distinct from the frozen
source evidence. Reports and signals contain detached values only; no Node,
Resource, `WeakRef`, callable, or signal is exposed.

## Focused verification

Run only:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 planetary_sun_presentation_test
```

The focused suite freezes atmospheric, vacuum, airless, horizon and night
mapping; explicit baseline validation; policy/source detachment; strict input
and generation rejection; external drift repair; forbidden-property
preservation; signal re-entry; adapter/target detach and re-entry; reset,
generation exhaustion, target expiry, evidence, authority, capabilities, and
deeply detached reports. Headless assertions establish exact owned property
values, so no render or native light-quality claim belongs to this foundation.
