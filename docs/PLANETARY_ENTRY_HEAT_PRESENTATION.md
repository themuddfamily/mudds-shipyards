# Planetary entry-heat presentation foundation

`PlanetaryEntryHeatPresentation` is a passive renderer adapter for the existing
`PlanetaryAtmosphereProfile` and `PlanetaryAtmosphereSampler`. The checked-in
`PlanetaryEntryHeatTarget` scene supplies its dedicated visual target. Stage 2
attaches one still-unconfigured target to the Arrow host; Main, GameFlow, and
atmosphere-observation composition remain absent.

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

Generic callers must attach and align the target to an appropriate stable visual
anchor. Arrow now performs that narrow host step after `_build_arrow_variant()`
has installed its final `ArrowReconVisual`: exactly one target is a direct child,
with `top_level = false`, position `(0, 1.4, -0.15)` m, zero rotation, and scale
`(1.45, 1.4, 1.08)`. The fitted authored bounds are
`AABB((-5.8,-1.4,-7.71), (11.6,5.6,15.12))`; the 0.25 m standoff bounds are
`AABB((-6.1625,-1.75,-7.98), (12.325,6.3,15.66))` in Arrow visual-root space.

The host attachment adds exactly three nodes (target, overlay, presentation),
one renderer, one surface/submission, one visible geometry copy, one shared-mesh
allocation reference, and one exclusive live material. Two Arrows share the
immutable mesh and shader but never their live material. Attachment does not
configure the presentation, sample atmosphere state, or add a process loop. Its
zero intensity therefore remains invisible until a later caller explicitly
configures and drives it. Because it is under the stable final visual root, the
same target and material follow inherited hull hide, damage/reset, reuse, and
whole-ship detach/re-entry without rebuilding or duplicating the target.
Arrow audits the untouched zero/generation-0 state only while the adapter is
unconfigured. Once an external composition owner configures it, the host accepts
bounded live intensity only when the adapter's own generation, renderer target,
transaction, and baseline audit is green; valid driving does not invalidate the
Arrow census.
Arrow's performance report retains the Phase-9 pre-attachment census separately;
its current `reductions` values are honest legacy-minus-current deltas, so nodes
and visible copies are `-2` and `-1` after this deliberate renderer addition.

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

Stage 2 provides only the first Arrow host attachment. It does **not** configure
the adapter or provide production atmosphere sampling, physical heating, damage,
directional flow, clouds, weather, camera logic, audio, or calibrated photometry.
A later composition owner must explicitly configure the existing adapter and
feed complete observations while preserving this exclusive-material and
zero-gameplay-authority boundary. The generic target's
`ship_integration = false` capability remains truthful: it implements no ship
logic; Arrow alone owns the hosting relationship.

## Focused evidence

- `tests/planetary_entry_heat_presentation_test.gd` freezes sampler boundaries,
  finite/type/generation rejection, source detachment, one-uniform ownership,
  real `Resource.changed` rollback/reentry attacks, lifecycle/reset behavior,
  weak-target expiry, evidence, authority, and deep-detached reports.
- `tests/planetary_entry_heat_target_test.gd` loads two real scene instances and
  freezes the AABB, mesh/surface/submission roster, per-live-target material
  exclusivity, shared mesh/shader identity, absence of collision/authority
  nodes, structured-red mutations, and whole-target detach/reentry.
- `tests/arrow_recon_ship_test.gd` freezes the direct-child transform/bounds,
  exact +3/+1/+1 census, one target per Arrow, shared mesh/shader with distinct
  materials across two ships, zero/unconfigured baseline, structured-red host
  mutations, and stable damage/reset/detach/re-entry identity.

An optional isolated same-process Forward+ review may compare the attached Arrow
under HIGH/LOW at intensity 0, 0.25, and 1 from fixed external chase and cockpit
views. It is presentation evidence only: it cannot prove atmosphere composition
or establish a frame-time claim.
