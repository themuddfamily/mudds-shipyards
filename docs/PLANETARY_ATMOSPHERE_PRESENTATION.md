# Planetary atmosphere presentation foundation

`PlanetaryAtmospherePresentation` is a standalone, passive renderer adapter for
the validated `PlanetaryAtmosphereProfile` and pure
`PlanetaryAtmosphereSampler`. It is not wired into Main, Ember Moon, planetary
travel, streaming, landing, or a visual-quality controller.

## Composition and lifecycle

The caller supplies one valid profile and one existing `Environment` to
`configure(profile, environment)`. Configuration succeeds once, starts
generation 1, configures a private immutable sampler, and retains only detached
profile values plus a weak renderer-target identity. Mutating or releasing the
source profile cannot retune the component.

Every visual change comes from
`present_observation(altitude_m, path_distance_m, speed_mps, weather_scalar,
cloud_scalar, expected_generation)`. The caller chooses cadence and inputs; the
component has no `_process`, `_physics_process`, wall clock, timer, smoothing,
interpolation, weather selection, or autonomous resampling. Invalid input and a
stale generation leave state, signals, and renderer values unchanged. An exact
duplicate is signal-free. Signals fire only after state and renderer properties
commit, and every synchronous mutator re-entry is rejected.

`reset_for_reuse(expected_generation)` advances the bounded generation, clears
the last sample, and restores the captured renderer baseline. Tree exit also
restores that baseline so an unloaded presentation cannot leak fog into another
world. Re-entry reapplies the retained current-generation values without a new
revision, generation, signal, sampler, or renderer allocation.

## Exact renderer ownership

This slice owns exactly four standard `Environment` properties:

| Property | Mapping |
| --- | --- |
| `fog_density` | Exact vacuum or zero sample fog gives 0. Otherwise `clamp(-log(max(1 - fog_factor, 1e-28)) / max(path_distance_m, 0.1), 0, 1)`. |
| `fog_light_color` | Modern display tint from normalized frozen Rayleigh + Mie RGB, remapped per channel as `0.18 + 0.62 * normalized`. Zero scattering resolves neutral grey. |
| `fog_light_energy` | `clamp(0.35 + 0.65 * density_ratio, 0, 1)`. |
| `fog_sky_affect` | `clamp(0.5 * fog_factor, 0, 1)`. |

The adapter deliberately does **not** own `fog_enabled`, fog depth/curve,
aerial perspective, sun scatter, volumetric fog, tonemapping, grading, glow,
SSAO, SSIL, TAA, WorldEnvironment/Sky resources, cameras, lights, shaders,
shells, or cloud geometry. A later composition owner must coordinate those with
the visual-quality policy. Cloud, wind, optical, and entry values remain in the
detached sample for honest future consumers; this foundation claims only the
four implemented fog mappings.

The profile and sampler retain their exact upstream boundaries: atmosphere top
is vacuum; cloud base is inclusive and top exclusive; fog is zero at its start;
entry intensity is zero at start/minimum and full at its full thresholds.

## Evidence and authority

This is `NEW`, `modern_interpretation`, `source_bounded=false`, confidence
`none`. It authenticates no historical or real atmosphere.

Renderer presentation is the sole positive authority. Gameplay, physics,
streaming, save, network, world/terrain/collision generation, origin shift,
weather clock, audio, ship/player movement, landing, navigation, camera,
weather selection, cloud advection, damage, entry gameplay, and rewards remain
false. The childless adapter allocates no Environment, Sky, WorldEnvironment,
mesh, light, collision, timer, animation, or process loop.

## Focused verification

Run only:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 planetary_atmosphere_presentation_test
```

The focused suite freezes profile/target identity, equations and exact
boundaries; invalid inputs and generation tombstones; signal re-entry; baseline
restore/re-entry; deep-copy reports; the authority and allocation rosters; and
structured-red renderer, child-node, profile-identity, and expired-target
mutations.

A single optional Forward+ review harness is intentionally deferred until the
static implementation review. Headless resource assertions prove deterministic
state, not final visual quality or GPU cost.
