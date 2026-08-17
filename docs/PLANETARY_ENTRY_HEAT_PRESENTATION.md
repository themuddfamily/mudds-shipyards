# Planetary entry-heat presentation foundation

`PlanetaryEntryHeatPresentation` is a passive Stage-1 renderer adapter for the
existing `PlanetaryAtmosphereProfile` and `PlanetaryAtmosphereSampler`. The
checked-in `PlanetaryEntryHeatTarget` scene supplies its dedicated visual target.
This slice is generic and is not attached to Arrow, another ship, Main, or
GameFlow.

## Exact contract

The caller configures one adapter once:

```gdscript
var result := presentation.configure(valid_profile, exclusive_shader_material)
```

The caller then supplies altitude in metres, scalar speed in metres per second,
and the adapter generation:

```gdscript
var result := presentation.present_observation(
    altitude_m,
    speed_mps,
    presentation.get_generation()
)
```

The adapter calls the frozen `PlanetaryAtmosphereSampler` with an exact zero
optical path, weather scalar, and cloud scalar. It copies the sampler's
`entry_effect_intensity` directly to one owned material parameter:

```text
entry_effect_intensity_unitless
```

That value is a bounded game-scale visual hint, not temperature, heat flux,
drag, damage, or a calibrated plasma result. The underlying sampler multiplies
the profile's linear altitude and speed factors:

- altitude at `entry_effect_start_altitude_m` is exactly zero;
- altitude at or below `entry_effect_full_altitude_m` is exactly full;
- speed at `entry_effect_minimum_speed_mps` is exactly zero;
- speed at or above `entry_effect_full_speed_mps` is exactly full;
- altitude at or above `atmosphere_top_altitude_m` is vacuum and exactly zero;
- otherwise the result is the product of both normalized factors.

No delta or clock is accepted. Identical complete inputs therefore produce the
same observation at caller cadences equivalent to 30, 60, or 120 Hz.

## Authored renderer target

`res://scenes/effects/planetary_entry_heat_target.tscn` contains exactly one
`MeshInstance3D` and one passive adapter child. Its authored visual bounds are
`AABB((-4,-2,-7), (8,4,14))` metres, expanded by a 0.25 m overlay standoff. A
one-surface unit `SphereMesh` (32 radial segments, 16 rings) is scaled to that
bounded box. It casts no shadows, contributes no GI, and owns no collision,
light, particle, audio, animation, or timer node.

The sphere mesh and shader are immutable shared resources. The
`ShaderMaterial` is `resource_local_to_scene`, so every live target owns a
distinct material. The owned intensity baseline is exactly `0.0`, making the
additive overlay invisible. HIGH and LOW use the same one-node, one-surface,
one-submission target and the same intensity mapping; no quality selection is
hidden in the target or adapter. Bloom may affect appearance outside this
contract, so LOW must remain legible without relying on bloom.

The shader is an unshaded additive Fresnel envelope with four caller-authored,
non-owned display uniforms (colour, maximum alpha, emission multiplier, and
Fresnel exponent). It uses no `TIME`, noise, screen/depth texture, light, or
particle system. The isotropic envelope is deliberately not a directional bow
shock.

The caller must attach and align the target to an appropriate stable visual
anchor. Stage 1 does not choose a ship, infer airflow direction, or affect the
parent's visibility.

## Transaction and lifecycle

Configuration requires a valid profile, a `resource_local_to_scene` exclusive
material, a spatial shader with the exact owned float uniform, and an exact zero
baseline. A shared material rejects as `material_not_exclusive`. The adapter
freezes detached profile and sampler snapshots and then keeps only weak
material/shader references plus their identities and exact shader source.

For a changed observation, the adapter builds and validates a complete
candidate before mutation. Under one reentry guard it writes the uniform,
explicitly emits one consolidated `Resource.changed`, then re-resolves the exact
material-to-shader chain, frozen shader source/schema, and exact readback. A
callback that replaces the shader, changes its schema, or overwrites the owned
uniform returns a typed red result. Property drift is rolled back to its exact
pre-call scalar. No failed transaction changes retained observation,
generation, revision, presentation count, or `presentation_committed` count.
Every public mutator rejects as `reentrant_call` during material and signal
callbacks.

Tree exit restores exact zero. Tree reentry reapplies the retained current
generation. Neither lifecycle action changes generation/revision or emits a
presentation signal. A successful reset restores zero before advancing the
safe-integer generation. Expired or replaced weak renderer targets fail closed.

## Evidence and authority

The policy evidence roster is exact and distinct from the frozen source-profile
evidence:

```text
content_class = NEW
status = modern_interpretation
source_bounded = false
confidence = none
```

The adapter and target report renderer authority only. Gameplay, streaming,
save, network, physics, world/terrain/collision generation, origin shifting,
weather clock, and audio authority are false. The adapter denies material,
shader, target-geometry, and ship ownership: it receives weak caller targets.
The authored target, by contrast, owns its exact target resource contract under
renderer authority: one live-local material plus the exact checked-in shared
mesh and shader. Neither component owns movement, airflow direction, drag,
damage, gameplay heat, weather/time selection, quality policy, particles,
lights, or playback.

Stage 1 does **not** provide production ship integration, physical heating,
damage, directional flow, clouds, weather, camera logic, audio, or calibrated
photometry. A later integration may attach one target under a ship's stable
visual root and explicitly feed observations; it must preserve the exclusive
material and zero-authority boundaries here.

## Focused evidence

- `tests/planetary_entry_heat_presentation_test.gd` freezes sampler boundaries,
  finite/type/generation rejection, source detachment, one-uniform ownership,
  real `Resource.changed` rollback/reentry attacks, lifecycle/reset behavior,
  weak-target expiry, evidence, authority, and deep-detached reports.
- `tests/planetary_entry_heat_target_test.gd` loads two real scene instances and
  freezes the AABB, mesh/surface/submission roster, per-live-target material
  exclusivity, shared mesh/shader identity, absence of collision/authority
  nodes, structured-red mutations, and whole-target detach/reentry.

An optional isolated Forward+ review may compare HIGH/LOW at intensity 0, 0.25,
and 1 with a fixed camera. It is presentation evidence only: it cannot prove
production attachment or establish a frame-time claim.
