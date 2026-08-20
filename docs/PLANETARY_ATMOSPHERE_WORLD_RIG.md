# Planetary atmosphere world rig

`PlanetaryAtmosphereWorldRig` is a standalone authored renderer-target
prerequisite for a future atmospheric planetary world. It composes the existing
validated world/profile/terrain contracts and the existing atmosphere, sky,
cloud, and sun presentation adapters. It does not define or make a planet
visitable, and it is not wired into `Main`, `GameFlow`, streaming, or a camera.

The scene is:

```text
PlanetaryAtmosphereWorldRig (Node3D)
├── CloudShell (MeshInstance3D)
├── SunLight (DirectionalLight3D)
├── AtmospherePresentation (Node)
├── SkyPresentation (Node)
├── CloudPresentation (Node)
└── SunPresentation (Node)
```

That is exactly seven nodes including the root. The scene deliberately has no
`WorldEnvironment`. Its `Environment -> Sky -> ProceduralSkyMaterial` chain is
a scene-local Resource graph exported by the root, ready for a later explicit
composition owner to install. Keeping the Environment as a Resource on the root
is what permits the seven-node contract without fusing an adapter into a target
node.

## Authored target ownership

Every live scene instance exclusively owns these mutable Resources through
`resource_local_to_scene=true`:

- one `Environment`;
- its one `Sky`;
- its one `ProceduralSkyMaterial`;
- the cloud shell's one `ShaderMaterial`.

All instances share the immutable one-surface unit `SphereMesh` and the external
`planetary_cloud_shell.gdshader`. The rig freezes their exact instance identity,
mesh recipe, shader source, spatial mode, and six-uniform reflection contract at
scene readiness. A private same-recipe mesh replacement or shader source/schema
change is structured red. Configuration scales only the shell node, never the
shared mesh, to `planet_radius + cloud_top_altitude` in body-local metres.

The shader has exactly the six parameters owned by
`PlanetaryCloudPresentation`:

```text
float cloud_base_radius_m
float cloud_top_radius_m
float cloud_coverage_unitless
float cloud_observer_layer_factor_unitless
vec3  cloud_wind_velocity_mps
vec3  cloud_wind_offset_m
```

Its pale colour, 0.36 maximum alpha, and simple analytic band pattern are
immutable modern display tuning. This is a thin stylised shell, not cloud
volume, texture/noise asset, physical multiple scattering, cloud shadowing, or
a claim of final visual quality. The mesh casts no shadows, has GI disabled,
and owns no collision.

The fixed non-shadow `SunLight` emits exactly along global -Y. The rig
authenticates that emitted direction against the authored identity global basis,
derives its +Y body-to-sun policy input as the inverse, and supplies that same
derived vector to both sky and sun adapters. The rig never rotates the light.
Sun direction, time-of-day, and ephemeris remain outside this foundation.

## Configuration

```gdscript
configure(
    world: PlanetaryWorldDefinition,
    atmosphere: PlanetaryAtmosphereProfile,
    terrain: PlanetaryTerrainProfile,
) -> Dictionary
```

The exact atmospheric triple must pass `PlanetaryWorldCompositionValidator`:
IDs, radius datum, terrain envelope, atmosphere shell, and body-centred anchors
must agree. The rig freezes detached world/profile/terrain/composition reports
and retains none of the caller Resources.

The four child adapters configure once, in exact order:

```text
atmosphere -> sky -> cloud -> sun
```

Each reaches generation 1. After every accepted child configuration (including
its synchronous callbacks), the rig repeats both the authored scene contract
and the world/profile/terrain composition validation before another child can
configure. A callback that changes a source definition is therefore terminally
red before it can create a mixed frozen prefix. A later caller mutation cannot
change the frozen composition. A child failure after an accepted prefix returns
`partial_configuration_failure`, identifies the prefix and failed adapter, and
terminally invalidates that rig instance. Existing one-shot adapters cannot be
unconfigured, so discarding the failed instance is the only honest recovery.
There is intentionally no cross-child reset operation.

## Caller-owned observations

`present_observation(observation, expected_generation)` accepts an exact
seven-key dictionary:

```text
body_local_observer_m: Vector3
view_direction_body_local: unit Vector3
fog_path_distance_m: finite metres
speed_mps: finite metres/second
weather_scalar: [0, 1]
cloud_scalar: [0, 1]
caller_time_seconds: finite nonnegative epoch-local seconds
```

The rig derives altitude and radial surface-up from the body-local observer and
uses its immutable authored body-to-sun direction for both sky and sun policy.
The observer must be on or above sea level and inside the existing bounded local
coordinate window. Caller time is absolute input; the rig never accumulates,
wraps, or advances it. It preflights the cloud wind-offset ceiling before any
child call.

`planetary_body_local` observations are invariant under translation-only common
world-origin rebases. The rig proves this frame precondition continuously: its
global basis must be identity and every `Node3D` ancestor must have an identity
local basis, so any root/ancestor rotation or scale is structured red while
translation remains permitted. The caller owns conversion into that frame and
the freshness of every value. The rig does not accept a world-streaming position
or perform a rebase.

## Honest partial-failure semantics

The existing adapters commit independently, so the rig does **not** claim a
cross-adapter transaction. It calls in the exact order above and stops at the
first red receipt. `partial_presentation_failure` contains detached receipts,
the accepted and committed prefix, the failed adapter, and the unattempted
suffix. Rig revision, successful count, and success signal do not advance; only
the explicit partial-failure counter advances.

The exact canonical observation is then pending. A different observation is
rejected as `pending_observation_mismatch`. Retrying the exact same observation
after target repair lets already committed children return `unchanged` and the
remaining suffix catch up. Only complete convergence clears the pending state,
advances rig revision/count, and emits `presentation_committed`. No compensating
write or fictional rollback is attempted across child adapters.

An exact duplicate after convergence is deterministic and signal-free. All rig
mutators reject with `reentrant_call` while a child callback or the root success
signal is dispatching.

## Lifecycle and authority

The four existing adapters restore their exact authored baselines when the
whole rig exits the tree and reapply their retained current generation on
re-entry. This does not change rig or child generation, revision, count,
allocation, or success-signal state.

Renderer target composition is the sole positive common authority. The rig has
no process or physics callback and no WorldEnvironment installation, concrete
planet resource, terrain mesh or height generation, collision, camera, entry
heat, cloud volume, weather selection/clock, sun ephemeris/orientation,
movement, gameplay, streaming, origin application, save, network, or audio
authority. Evidence is exactly `NEW`, `modern_interpretation`,
`source_bounded=false`, confidence `none`; source definition evidence remains a
separate detached composition snapshot.

## Focused verification

After independent static review, run only:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 planetary_atmosphere_world_rig_test
```

The focused suite freezes the seven-node topology, exclusive versus shared
resource identities, mesh/shader contracts, non-shadow/no-collision/no-process
census, composition detachment, surface/cloud/top boundaries, strict inputs,
signal re-entry, real Resource-callback partial failure and exact repair,
whole-rig detach/re-entry, structured identity/source mutations, and detached
evidence/authority reports. Headless property truth does not establish visual
quality. No render is authorized by this slice without a later explicit gate.
