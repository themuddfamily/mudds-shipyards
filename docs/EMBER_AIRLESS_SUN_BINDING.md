# Ember airless sun binding foundation

`EmberAirlessSunBinding` is a passive, standalone production-shaped
composition for Ember Moon's airless directional sunlight. It authors one
`DirectionalLight3D` and delegates the only live renderer writes—baseline-
relative `light_color` and `light_energy`—to the existing
`PlanetarySunPresentation` and its private `PlanetarySunLightingPolicy`.

This foundation is deliberately **not wired into Main, GameFlow, Ember's
streamed scene, or the Ember surface host**. A later production caller must
instantiate the standalone rig as a direct sibling of the exact
`EmberMoonStreamingBootstrap`, bind the current loaded Ember generation, and
submit observations after the common-world rebase branch. This change creates
no automatic production cadence and does not make a new world visitable.

## Authored rig

`res://scenes/world/components/ember_airless_sun_rig.tscn` contains exactly:

- the typed `EmberAirlessSunBinding` root;
- one `SunLight` `DirectionalLight3D`; and
- one child `PlanetarySunPresentation` adapter.

The immutable body-local direction from Ember's centre toward the authored sun
is `Vector3.UP`. Godot directional light rays travel along the light's local
`-Z` axis, so the scene authors that axis as body-local `Vector3.DOWN`. The
exact light transform is:

```text
Basis(x = +X, y = -Z, z = +Y), origin = Vector3.ZERO
```

The exact baseline is display-relative energy `1.5` and color
`Color(1.0, 0.75, 0.5, 1.0)`. This is not lux, calibrated colorimetry, a star
spectrum, temperature, or historical evidence. Shadows remain disabled in the
authored scene, but shadow state is outside the binding's owned property set.
The binding never writes the rig transform, light transform, direction,
shadows, visibility, cull mask, indirect energy, volumetric-fog energy, or any
property other than the two delegated presentation values.

The scene is standalone because adding it below the existing streamed Ember
root would change that scene's separately audited fixed topology. In a future
Main composition, the existing sole common-world origin owner will translate
the rig and bootstrap as sibling `Node3D` roots. Translation does not change the
authored directional basis.

## Configuration contract

The caller invokes:

```text
configure(
    exact_ember_world_definition,
    ember_streaming_bootstrap,
    bootstrap_coordinate_frame,
    bootstrap_loaded_ember_root,
    current_coordinate_frame_generation,
    current_location_generation,
)
```

Configuration accepts only the canonical checked-in Ember world resource. It
must remain valid, radius `120000 m`, `has_atmosphere=false`, and have an empty
atmosphere definition ID. No atmosphere profile is accepted or invented.

The bootstrap must be live and audit-valid, own the exact supplied coordinate
frame and loaded `EmberMoonAuthoredScene`, and share the rig's direct parent.
The frame must retain Ember's exact body, orbital datum, metre scale, radius,
surface axes, and origin-shift threshold with no pending rebase. The loaded root
must be the bootstrap's current instance, retain exact location metadata and
generation, remain local identity, and align its global body centre with the
current coordinate frame. The rig, light, and adapter identities and authored
orientation are frozen for the binding lifetime. Replacement requires a new
rig/binding instance; there is no target rebind.

Configuration passes the exact Ember world and `null` atmosphere into
`PlanetarySunPresentation`. That adapter configures its private pure policy and
freezes detached source values. The binding does not create a policy, adapter,
light, or any renderer target at runtime.

## Post-rebase observation contract

The caller invokes:

```text
present_post_rebase_observation(
    body_local_observer_m,
    current_coordinate_frame_generation,
    bound_location_generation,
    binding_generation,
)
```

`body_local_observer_m` is an already-decoded finite Ember body-local position
in metres. The binding never reads an actor, camera, transform, velocity, or
world-streaming position and never performs coordinate conversion. It supplies
only that exact value and the immutable authored `Vector3.UP` body-to-sun
direction to the existing sun presentation.

The production order required of a later caller is:

1. capture the authoritative actor or viewer sample once;
2. run existing Ember streaming evaluation;
3. let the sole `CommonWorldOriginRebaseOwner` optionally apply and commit the
   rebase and return the adjusted sample/current frame generation;
4. decode that adjusted sample through the current `PlanetaryCoordinateFrame`;
5. submit the resulting body-local observer and exact current generations to
   this binding.

Calls reject before presentation if the binding/location generation is stale,
the supplied frame generation is not exactly current, a rebase remains pending,
the bootstrap/frame/root/rig/light/adapter identity changed, the root no longer
aligns with the current frame, or any retained object is detached, queued, or
freed. Frame generation is independent from binding and location generations.
A legitimate N→N+1 origin rebase does not reset or recreate the sun adapter; the
caller supplies N+1 with the invariant body-local observer. Forged N and N+2
values fail closed.

The child adapter is private to this composition boundary. Any external
connection to its `presentation_committed` signal makes the binding audit red
and rejects before renderer dispatch. This prevents a synchronous adapter
callback from unloading, replacing, detaching, or reparenting composition after
the adapter has committed but before the binding can commit its own observation.
Callers use only the binding result and detached reports; they do not call or
observe the child adapter directly.

On tree exit, the existing `PlanetarySunPresentation` restores the exact
baseline; tree re-entry reapplies its retained current values. Streaming unload
or replacement invalidates the frozen loaded-root identity. A later production
owner must discard this binding with that root generation and create a fresh
rig for a replacement generation; teardown never requests a rebase or moves a
node.

## Exact authority boundary

The common authority roster is positive only for renderer presentation. The
authored scene provides the existing target, while the existing sun adapter
owns only:

- `DirectionalLight3D.light_color`;
- `DirectionalLight3D.light_energy`.

Atmosphere, camera, observation sampling, coordinate conversion, runtime target
creation, direction/orientation mutation, ephemeris, time/day-night clock,
absolute energy/lux, calibrated colorimetry, temperature, angular size,
shadows, terrain/cloud occlusion, Environment/Sky, origin/rebase, streaming
load/unload or generation, movement, physics, gameplay, save, network, and
audio authority are all explicitly false.

Evidence is exactly `NEW`, `modern_interpretation`, `source_bounded=false`, and
confidence `none`. Reports are deeply detached and contain instance IDs rather
than live Nodes, Resources, weak references, callables, or signals.

## Focused verification

After independent static review, run only:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 ember_airless_sun_binding_test
```

The focused suite freezes the authored scene topology, orientation and baseline;
exact airless world/bootstrap/frame/root/location joins; direct-day and night
mapping; post-rebase continuity; stale/pending/invalid generation reds;
detachment, unloading, replacement, and transform/metadata drift; synchronous
re-entry; forbidden-property preservation; detached reporting; evidence and
exact authority. Exact light property assertions are sufficient for this
foundation, so no render claim or render test is required.
