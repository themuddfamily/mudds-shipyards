# Ember Moon authored scene

`EmberMoonAuthoredScene` is a standalone, loadable, body-centred witness for the
existing Ember Moon definitions. It owns a bounded visual surface patch, one
World-layer walkable collision box, and a small original surface-content roster.
It is not registered with production streaming, `Main`, `GameFlow`, Cinder
Reach, or a travel session.

The scene root is the physical body centre. A non-colliding 119,999 m sphere is
an intentionally inset silhouette proxy, one metre inside the exact 120,000 m
sea-level datum. It prevents z-fighting without changing the authored radius or
claiming terrain. At +Y 120,000 m, a 256 m visual floor and 240–280 m torus rim
establish one bounded caldera. These primitives are original muted basalt and
burnt-orange blocks. `SpaceBackdrop/CelestialOrangeBody` is palette inspiration
only; its exact colour, node, transform, 105 m radius, material, and physical
identity are not reused.

## Landing and collision seam

`LandingRegion` is exactly the `ember_caldera` body-local frame. Its four markers
compose the landing resource's pad, approach, egress, and staging positions:

- `caldera_pad`: `(0, 0, 0)`;
- `caldera_approach`: `(0, 60, 300)`;
- `caldera_pad_egress`: `(18, 0, 0)`;
- `caldera_staging_gate`: `(42, 0, 0)`.

One 96 x 0.5 x 96 m box is centred at local y=-0.25, putting its top at y=0.
It supports the pad and both original on-foot route anchors, uses the canonical
World layer and zero mask, and is the entire walkable-surface promise. The
silhouette, caldera rim, approach corridor, and everything outside +/-48 m are
non-colliding.

## Bounded surface content

The `NEW` / `modern_interpretation` surface roster establishes one continuous,
four-metre-wide pad-to-egress-to-staging path along local +X. Its exact
centreline is `(0, 0, 0)` -> `(18, 0, 0)` -> `(42, 0, 0)`, and the visual stripe
touches the pad edge at x=14 without a gap. Three stable access markers identify
the guidance threshold, sealed sample-rack access, and staging-relay access.

Four stable landmark identities dress the route:

- paired `ember_pad_guidance_port` / `ember_pad_guidance_starboard` posts at
  x=14.8 and z=+/-5;
- low `ember_sample_rack` equipment at `(28, 0.5, -7)`;
- `ember_staging_relay` base, mast, and head rooted at `(42, 0, 7)`.

Every visually solid part has matching static World collision: the guides and
rack each use one exact box, while the relay uses separate base, mast, and head
shapes. The nearest solid edge remains 4.75 m from the route centreline, beyond
the 2 m route half-width plus the production Player's 0.38 m capsule radius.
Focused evidence places the body-centred authored scene behind an explicit
test-only local-origin translation, then drives the real production Player from
the pad through egress to staging using ordinary forward locomotion. After the
exact initial placement, the traversal uses neither jumping nor teleporting and
probes the route's negative space at every landmark station. This validates the
local surface while leaving production rebase application to the separate
coordinate-frame integration seam.

At 120 km, the standard single-precision build has approximately 0.0078125 m
spacing. Keeping patch vertices and marker offsets under the landing-region
parent preserves useful local authoring precision, but the scene promises no
sub-centimetre placement and no arbitrary-radius precision. The +Y polar patch
also happens to align with existing global -Y gravity; spherical gravity is not
implemented or implied.

## LOD and ownership

The component privately copies `ember_basalt_terrain` and configures one
immutable `PlanetaryTerrainLodPolicy`. `evaluate_terrain_lod_hint()` returns the
policy's detached inclusive-ring and collision hints. It never changes node
visibility, creates tiles, or disables the fixed authored collision patch. The
visual disk is not a clipmap tile or height-generation result.

The exact budget is 35 nodes, 11 mesh submissions, five static bodies, seven
collision shapes, no active presentation/integration nodes, and at most 8,192
primitive triangles. Audit reports presentation geometry, bounded static
collision, the authored landmark roster, and the authored surface route as its
only capabilities. Streaming, GameFlow, gameplay, landing decisions, movement,
world/terrain/collision generation, origin shifting, save, network, rewards,
audio, camera, and lighting authority are all false.

The opt-in Ember orbital bootstrap now supplies a checked absolute datum and an
isolated streaming generation for this scene without placing it in `Main`.
Production rebase application, actor spawning, travel-session integration,
landing eligibility, approach navigation, global terrain and collision,
spherical gravity, atmosphere, production light and sky, audio/VFX, missions,
economy, persistence, and networking remain deferred.
