# Ember Moon authored scene

`EmberMoonAuthoredScene` is the loadable, body-centred production scene for the
existing Ember Moon definitions. It owns a bounded spherical terrain build, the
authored landing patch, and a small original surface-content roster.
Production's `EmberMoonStreamingBootstrap` registers and can stream this scene
beneath its private coordinator. The scene itself owns no production `Main`,
`GameFlow`, Cinder Reach, travel-session, or streaming authority.

The scene root is the physical body centre. A non-colliding 119,999 m sphere is
an intentionally inset orbital silhouette, one metre inside the exact 120,000 m
sea-level datum. Around the +Y landing focus, five 65 x 65 spherical tangent
grids extend through 256, 768, 2,048, 6,144, and 18,432 m. They contribute
21,125 vertices and 34,504 visible triangles in five submissions, share one
opaque rust-basalt-tinted vertex-colour material, and keep the complete 600 m
approach corridor level by blending relief only beyond 750 m. A 256 m visual
opening retains the authored caldera floor and 240–280 m torus rim without
coplanar fighting. `SpaceBackdrop/CelestialOrangeBody` remains palette
inspiration only; its exact colour, node, transform, 105 m radius, material, and
physical identity are not reused.

## Landing and collision seam

`LandingRegion` is exactly the `ember_caldera` body-local frame. Its four markers
compose the landing resource's pad, approach, egress, and staging positions:

- `caldera_pad`: `(0, 0, 0)`;
- `caldera_approach`: `(0, 60, 300)`;
- `caldera_pad_egress`: `(18, 0, 0)`;
- `caldera_staging_gate`: `(42, 0, 0)`.

One 96 x 0.5 x 96 m box is centred at local y=-0.25, putting its top at y=0.
It supports the pad and both original on-foot route anchors and uses the
canonical World layer and zero mask. Generated terrain collision takes over at
the box's exact +/-48 m edge with one 16,640-vertex / 32,768-triangle concave
World shape. That relief-matched surface expands from the square handoff to the
terrain profile's circular 1.5 km boundary, so the player or ship no longer
falls into space outside the old 512 x 512 m finest-ring footprint. Once the
authenticated focus reaches 1.2 km from the caldera, one second concave sector
shares the fixed surface's exact circular seam and extends to 1.5 km beyond the
focus. Its angular width also preserves 1.5 km of lateral support around that
focus. It follows the actor only within the current 18.432 km surface envelope;
the silhouette and caldera rim remain non-colliding.

## Bounded surface content

The `NEW` / `modern_interpretation` surface roster establishes one continuous,
four-metre-wide pad-to-egress-to-staging path along local +X. Its exact
centreline is `(0, 0, 0)` -> `(18, 0, 0)` -> `(42, 0, 0)`, and the visual stripe
touches the pad edge at x=14 without a gap. Five stable access markers identify
the guidance threshold, sample-rack access, staging-relay access, derelict
gantry access, and survey-bunker access.

Six stable landmark identities dress the route:

- paired `ember_pad_guidance_port` / `ember_pad_guidance_starboard` posts at
  x=14.8 and z=+/-5;
- low `ember_sample_rack` equipment at `(28, 0.5, -7)`;
- `ember_staging_relay` base, mast, and head rooted at `(42, 0, 7)`;
- the solid `ember_derelict_survey_gantry` over the route; and
- the solid `ember_survey_service_bunker` at `(-24, 0, -24)`.

Every visually solid part has matching static World collision. The nearest
solid edge remains 4.75 m from the route centreline, beyond the 2 m route
half-width plus the production Player's 0.38 m capsule radius.
Focused evidence places the body-centred authored scene behind an explicit
test-only local-origin translation, then drives the real production Player from
the pad through egress to staging using ordinary forward locomotion. After the
exact initial placement, the traversal uses neither jumping nor teleporting and
probes the route's negative space at every landmark station. This validates the
local surface without exercising production's separate
`CommonWorldOriginRebaseOwner`, which applies the common spatial translation and
coordinate-frame commit rather than delegating either to this scene.

At 120 km, the standard single-precision build has approximately 0.0078125 m
spacing. Keeping patch vertices and marker offsets under the landing-region
parent preserves useful local authoring precision, but the scene promises no
sub-centimetre placement and no arbitrary-radius precision. The +Y polar patch
also happens to align with existing global -Y gravity. The scene owns no gravity
policy. The standalone surface-loop host composes a bounded tangent-gravity
policy for its focused proof; global spherical locomotion remains absent.

## LOD and ownership

The component privately copies `ember_basalt_terrain`, configures one immutable
`PlanetaryTerrainLodPolicy`, and gives the same profile to one
`PlanetaryTerrainClipmapRenderer`. `evaluate_terrain_lod_hint()` remains a pure
query; the clipmap itself has no camera or automatic process cadence. It builds
once during scene readiness, then accepts generation-fenced caller focus
updates. Movement below 192 m retains the current meshes; crossing that
threshold atomically recentres the five visible rings and, when required, one
bounded landing-to-focus collision corridor. The fixed authored pad and
generated 1.5 km collision remain centred on the caldera and reuse the same
concave shape across every rebuild. The corridor begins only 1.2 km from the
landing focus, is capped at 8,320 triangles, and neither enters the fixed
surface nor the authored pad opening.

The current exact baseline budget is 81 nodes, 30 render submissions (22
ordinary meshes plus eight MultiMeshes drawing 42 copies), eight static bodies,
26 collision shapes, and at most 60,000 rendered primitive triangles. An active
focus corridor adds exactly one generated node/collision shape, making the live
roster 82/27 without another render submission. Audit reports
presentation geometry, bounded static and generated terrain collision, terrain
generation, the authored landmark roster, and the authored surface route.
Streaming, GameFlow, gameplay, landing decisions, actor movement, world
generation, origin shifting, save, network, rewards, audio, camera, and lighting
authority remain false.

Production `Main` now owns the Ember orbital bootstrap and observation binding,
plus one `CommonWorldOriginRebaseOwner`; together they can make exactly one
checked scene generation resident in a correctly rebased local frame. During
the retained surface loop, the Host forwards its existing authenticated
body-local actor sample to the scene's thresholded terrain-focus seam; it gains
no terrain-generation or movement authority. The
retained surface-loop composition now connects real-actor travel, berth, egress,
activity/reward, reboarding, takeoff, orbit return, and the existing station
arrival authority. The composition still does not claim final visitability.
Collision beyond the bounded 18.432 km landing-relative surface envelope,
global spherical locomotion, atmosphere, production light and sky, native
performance review, and repeated packaged lifecycle review remain deferred.
