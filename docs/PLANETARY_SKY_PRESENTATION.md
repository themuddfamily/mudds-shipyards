# Planetary sky presentation foundation

`PlanetarySkyPresentation` is a reusable, passive renderer adapter for a
validated `PlanetaryAtmosphereProfile` and its deterministic sampler. It does
not author a planet or atmosphere and is not wired into Main, Ember Moon,
streaming, travel, landing, or a quality controller.

## Composition and lifecycle

The composition owner supplies one valid profile and one existing
`Environment -> Sky -> ProceduralSkyMaterial` chain to
`configure(profile, environment)`. The environment must already use
`Environment.BG_SKY`. A custom or missing sky material is rejected; in
particular, the component neither replaces nor targets Shipyard's deep-space
shader.

Configuration succeeds once, starts generation 1, configures a private sampler,
and freezes detached profile values and renderer baselines. The caller must
supply a target material used exclusively for this presentation; Godot Resource
identity alone cannot prove that a material is not shared. The component keeps
only weak target identities and allocates no Environment, Sky, sky material,
shader, node, light, camera, timer, or animation.

`present_observation(altitude_m, view_direction, surface_up_direction,
direction_to_sun, expected_generation)` is the only sampling seam. Altitude is
metres relative to the modeled surface/sea-level datum. Each direction is a finite unit
vector in one caller-defined frame:

- view points from the observer into the viewed sky;
- surface-up points radially outward;
- direction-to-sun points from observer to sun.

Directions accept a length error of at most `0.0001`, then normalize for
deterministic dot products. Altitude below the body centre (`-planet_radius_m`),
altitude beyond the profile's global ceiling, nonfinite inputs, non-unit
directions, and stale generations reject atomically. Altitudes below the
profile's density reference remain valid and inherit the sampler's exact
reference-density clamp. Looking below the local horizon and a sun below
the local horizon remain valid observations; this adapter owns both procedural
sky hemispheres but no camera or day/night policy.

The caller chooses cadence. There is no delta, `_process`, `_physics_process`,
wall clock, timer, interpolation, weather selection, or automatic resampling.
Identical observations with matching renderer state are signal-free.

`reset_for_reuse(expected_generation)` advances the safe-integer-bounded
generation, clears the observation, and restores the authored baseline. Tree
exit also restores the baseline. Tree re-entry reapplies the retained current
generation without another generation, revision, signal, or allocation.
Signals fire only after state and all owned fields commit. Synchronous material
`changed` callbacks and presentation-signal observers cannot reenter a mutator.
Renderer writes are transactional: the observation remains provisional while
the three setters run, then the component emits one consolidated
`Resource.changed` notification under the mutation guard and verifies the exact
Environment-to-Sky-to-material identity plus all three actual values. Callback
target replacement returns `target_chain_changed_during_apply`; callback
property overwrite returns `renderer_state_changed_during_apply`. Either leaves
generation, revision, observation, count, and presentation signal unchanged and
restores the prior values on the still-live original material. A replaced chain
remains an honest red audit until its composition owner restores the identity.

## Exact game-scale mapping

Let `R` be planet radius, `h` altitude relative to the surface datum, and `A`
the atmosphere-top height. At `altitude >= atmosphere_top`, both optical paths
are exactly zero and all three colours are restored to their authored baselines.
Below top:

```text
local_radius = R + h
outer_radius = R + A
zenith_path  = outer_radius - local_radius
horizon_path = sqrt(outer_radius^2 - local_radius^2)
```

Each path is capped to the profile's `maximum_visibility_m` before being passed
to the existing sampler with speed 0 and weather/cloud scalars 1. This is a
bounded local homogeneous optical estimate over a spherical shell, not
ray-marched curved-atmosphere rendering.

Sun/view colour uses the profile's Mie anisotropy `g`. With
`c = clamp(dot(view, direction_to_sun), -1, 1)`, the normalized
Henyey-Greenstein phase is:

```text
phase = clamp((1 - abs(g))^3 / (1 + g^2 - 2*g*c)^(3/2), 0, 1)
mie_weight = phase * max(dot(surface_up, direction_to_sun), 0)
combined_rgb = rayleigh_rgb + mie_rgb * mie_weight
```

The strongest combined channel normalizes to 1, then each tint channel is
`clamp(0.18 + 0.62 * normalized_channel, 0, 1)`. Zero scattering uses neutral
`(0.5, 0.5, 0.5)`. This is a modern display mapping, not a claim of physical or
historical fidelity.

For authored baseline RGB `B`, sampler transmittance RGB `T`, and scattering
tint `S`, the owned output is component-wise:

```text
atmospheric_colour = clamp(B * T + S * (1 - T), 0, 1)
```

Baseline alpha is preserved exactly. The top uses the zenith sample; sky and
ground horizon use the horizon sample. Vacuum bypasses arithmetic and restores
the exact authored values.

## Exact renderer ownership

The component owns only:

- `ProceduralSkyMaterial.sky_top_color`
- `ProceduralSkyMaterial.sky_horizon_color`
- `ProceduralSkyMaterial.ground_horizon_color`

It does not own `ground_bottom_color`, material curves, energy multipliers, sun
disc parameters, textures, `Environment.sky`, background mode/energy, ambient
or reflected light, fog, tonemapping, quality settings, lights, cloud geometry,
weather clock, or renderer resource lifetime. Godot setters may notify their
own engine listeners, but this adapter's public consolidated `Resource.changed`
notification occurs after all three writes and before post-write verification.
Only a successful `presentation_committed` denotes a verified completed
three-property state.

## Authority and evidence

Renderer presentation is the sole positive authority. Gameplay, physics,
streaming, save, network, world/terrain/collision generation, origin shift,
weather clock, audio, Environment/Sky ownership, ambient/reflection policy,
fog, clouds, sun lights, cameras, movement, landing, and weather selection are
all explicitly false.

Evidence is `NEW`, `modern_interpretation`, `source_bounded=false`, confidence
`none`. Headless tests establish deterministic resource values, lifecycle, and
contract boundaries. They do not establish production visual quality, shared
material safety, or GPU cost; those require later composition and Forward+
review. Airless worlds should omit this component rather than invent a profile.

## Focused verification

Run only:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 planetary_sky_presentation_test
```

The focused suite freezes the shell/path equations, atmosphere boundary,
sun/view mapping, exact colours, source detachment, generation tombstones,
real signal and Resource reentry, callback-driven target/property rollback,
target-chain identity, detach/re-entry, audit
authority/capability rosters, zero allocations/process, and structured-red
mutation behavior. No render is required because every owned value is directly
assertable headlessly.
