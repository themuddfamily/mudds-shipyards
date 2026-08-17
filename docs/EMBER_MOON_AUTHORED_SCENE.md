# Ember Moon authored scene

`EmberMoonAuthoredScene` is a standalone, loadable, body-centred witness for the
existing Ember Moon definitions. It owns four static presentation primitives
and one bounded World-layer collision box. It is not registered with production
streaming, `Main`, `GameFlow`, Cinder Reach, or a travel session.

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
It supports the pad and both on-foot markers, uses the canonical World layer and
zero mask, and is the entire collision promise. The silhouette, caldera rim,
approach corridor, and everything outside +/-48 m are non-colliding.

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

The exact budget is thirteen nodes, four mesh submissions, one static body, one
box collision shape, no active presentation/integration nodes, and at most
8,192 primitive triangles. Audit reports presentation geometry and bounded
static collision as owned capabilities. Streaming, GameFlow, gameplay, landing
decisions, movement, world/terrain/collision generation, origin shifting, save,
network, rewards, audio, camera, and lighting authority are all false.

The opt-in Ember orbital bootstrap now supplies a checked absolute datum and an
isolated streaming generation for this scene without placing it in `Main`.
Production rebase application, actor spawning, travel-session integration,
landing eligibility, approach navigation, global terrain and collision,
spherical gravity, atmosphere, production light and sky, audio/VFX, missions,
economy, persistence, and networking remain deferred.
