# Scene geometry budget — representative mid-range Windows PC

Status: **modern interpretation.** These are presentation-engineering numbers
chosen by measuring this project. Nothing here is a recovered or authenticated
value, and nothing here is a claim about the original game.

First written 2026-08-16, against the scene at that date. Measured with
`tools/geometry_census.gd`. Regression-gated for lettering by
`tests/sign_geometry_budget_test.gd`.

---

## What this document can and cannot say

The machine this project is developed on renders through **llvmpipe, a software
rasteriser**. Frame time measured there is a property of the CPU emulating a GPU,
not of the game. So this budget deliberately contains **no frame-time, GPU-time
or VRAM-occupancy figures**, and none should be added to it from this
environment. Anyone who does measure them must record the hardware, driver,
resolution and graphics profile alongside, as Phase 9 item 7 of `ROADMAP.md`
already requires.

What *is* measurable here, and is identical on the player's Windows GPU build
because it is a property of the scene rather than of the renderer:

- triangle counts, per bucket and per object
- mesh instances and surfaces (the upper bound on draw submissions)
- unique meshes, materials and shaders (state changes)
- texture count and uncompressed texture bytes
- `Light3D` count and how many of those cast shadows
- particle systems
- scene-tree node count

Those are the budget's currency. They are **whole-scene ceilings, not per-frame
figures** — Godot frustum- and occlusion-culls, so what a frame actually submits
is a fraction of these. A whole-scene ceiling is still the right thing to hold,
because it is what bounds load time, memory, and the worst-case wide shot, and
because it is the only figure this project can currently verify.

## The target machine

Defined here so future work has something concrete to check against rather than
"mid-range".

| | Minimum | Target |
| --- | --- | --- |
| CPU | 4 core / 8 thread, ~2018 desktop class | 6 core / 12 thread, ~2022 desktop class |
| RAM | 8 GB | 16 GB |
| GPU | GTX 1060 6 GB / RX 580 8 GB class | RTX 3060 8 GB / RX 6600 8 GB class |
| Display | 1920x1080 | 1920x1080, headroom toward 2560x1440 |
| Renderer | Forward+ | Forward+ |

The reason the budget below leans on **draw calls, materials and shadow-casting
lights** rather than on raw triangles is that this is where a GPU of that class
actually runs out first. An RTX 3060 will chew through a million and a half
triangles without noticing; what costs it, and much more so the minimum spec's
CPU, is thousands of separate draw submissions, hundreds of distinct materials,
and lights that force the scene to be re-rasterised into a shadow map. The
triangle ceiling is a coarse headroom marker, not the binding constraint.

## The budget

Measured with the documented headless command and independently with Forward+
Vulkan under Xvfb/llvmpipe.

| Metric | Measured on merged `33bd5a9` | Budget | Status |
| --- | ---: | ---: | ---: |
| Scene triangles | 1,792,816 | **1,800,000** | 7,184 / 0.4% under |
| Mesh instances | 5,776 | **4,200** | **1,576 / 37.5% over** |
| Surfaces (draw-call upper bound) | 5,783 | **4,300** | **1,483 / 34.5% over** |
| Unique meshes | 2,756 | **2,200** | **556 / 25.3% over** |
| Unique materials | 583 observed bound; retained total is higher † | **550** | **at least 33 / 6.0% over** |
| Unique shaders | 0 | **8** | 8 under |
| Textures / uncompressed bytes | 22 / 106.98 MiB | **40 / 192 MiB** | 18 / 85.02 MiB under |
| `Light3D` nodes | 309 | **240** | **69 / 28.8% over** |
| …of which shadow-casting | 19 | **16** | **3 / 18.8% over** |
| Particle systems | 25 | **24** | **1 / 4.2% over** |
| Scene-tree nodes | 9,128 | **7,000** | **2,128 / 30.4% over** |
| `TextMesh` lettering, total | 75,702 / 4.22% of scene | **80,000 and ≤ 5%** | 4,298 / 0.78 percentage points under |
| `TextMesh` lettering, worst sign | 4,239 | **6,000** | 1,761 / 29.4% under |

These are end-to-end census values from the exact clean merge commit
`33bd5a9f0b7d87ef3318251b0de5cd627d96f64e`, after a fresh import. Three
headless runs and two Forward+ Vulkan/X11 runs agreed exactly on every scalar,
bucket and sign row except the material row. The two Vulkan JSON files were
byte-identical. A 60-frame comparison also made headless and Vulkan agree on
the same phase sample, confirming that the other figures are renderer
independent.

† This row is the historical `33bd5a9` phase sample, retained so the recorded
budget decision remains auditable. It must not be presented as an exhaustive
resource count. The measurement defect has since been repaired in
`tools/geometry_census.gd`; final merged content still needs a fresh census
before this row can be re-frozen.

### Material census methodology after the retained-resource repair

The tool now publishes two different quantities instead of allowing one sampled
number to stand for both:

1. `bound_phase_unique_materials` is the unique `Material` resource set attached
   at one declared frozen phase. It includes every live `GeometryInstance3D`
   `material_override` and `material_overlay`, each ordinary `MeshInstance3D`
   surface override and mesh-surface material, and each `MultiMesh` mesh-surface
   material. The old `unique_materials` JSON key remains for consumers, but now
   aliases the retained union below rather than this phase sample.
2. `retained_reachable_unique_materials` is the identity-deduplicated union of
   all `Material` resources reachable from the instantiated production scene.
   Traversal covers stored engine properties and non-exported script variables,
   recursively enters arrays and dictionaries (including activity, courier and
   berth material catalogues), follows `Resource` dependencies such as
   `next_pass`, explicitly visits Mesh/MultiMesh surfaces, and follows each
   `ShaderMaterial`'s shader parameters. Retained shaders and `Texture2D`
   dependencies are reported from the same graph. The collector holds strong
   references to every discovered resource through reporting, so a count cannot
   change because a temporarily unbound resource is released mid-census.

Before either view is taken, the production scene settles for the configured
number of idle frames (default eight), then one physics frame and one final idle
frame. The production root is immediately switched to
`PROCESS_MODE_DISABLED`; both walks are synchronous after that freeze. Each JSON
result records the exact engine version, Git commit and dirty state, runtime and
project rendering method, display and audio driver, visual-quality level/report,
command line, settle counts, and freeze strategy. Both material sets also carry
their sorted deterministic origin/class/resource-path descriptors and a SHA-256
fingerprint over that exact list. The focused fixture in
`tests/geometry_census_retained_material_test.gd` locks overrides, overlays,
ordinary and MultiMesh surfaces, an unbound component catalogue, a `next_pass`
dependency, a shader parameter texture, identity deduplication, byte accounting,
and repeatable fingerprints.

One dirty-tree validation run on Godot `4.7.1-stable (official)`, source commit
`8dec8b113fd3cdf44fd90a3504b7f3c1abec3af0`, Forward+ / headless display /
Dummy audio, visual-quality level 2 (High), and the default 8+1+1 settle/freeze
strategy reported **578 bound-at-phase materials** and **842 retained/reachable
materials**. This is tool-validation evidence, not a new merged baseline and not
permission to change the 550-material ceiling; final merged content will be
measured later.

The retained union is deliberately a live-object-graph census, not a project
file inventory or VRAM measurement. It excludes resources that are neither
instantiated nor retained by the frozen production scene, renderer-internal
caches, freed object slots (whose skipped count is emitted), and resources that
future code could load only after another gameplay state. Texture bytes remain
the same uncompressed `width × height × 4` upper-bound proxy for discovered
`Texture2D` resources; they are not compressed package size or actual residency.

### Scenario-aware geometry and material census

The production census now makes streaming residency explicit instead of letting
the words “whole scene” hide two different live graphs. `station_resident` is
the default and fails closed if any `NearbySectorCluster` is loaded.
`cinder_loaded` moves the real guided ship to the documented clear approach and
drives `CinderStreamingProductionBinding` until exactly one coordinator-owned
Cinder generation is committed. Baseline runs use fresh private user data, so
recovery controls from an interrupted earlier session do not change the declared
HUD graph. Both paths wait for `Main` to apply startup settings, force the
production HIGH visual-quality profile, take the same
eight-idle/one-physics/one-idle settle, and disable `Main` before synchronous
geometry and retained-resource traversal. Before measurement, the existing
station activity and service-agent capture APIs seek their material-switching
presentations to zero seconds. Frame counts settle construction but cannot
freeze the same blink/readout material phase at different machine speeds.

Every schema-v2 JSON report publishes `scenario` and
`loaded_instance_count` both at top level and in run metadata. The whole-census
`measurement_fingerprint` hashes those fields, exact geometry/text/material-
count/resource/light/node totals, and every sorted bucket count. It deliberately
excludes Git dirty state, command line, output path and other run provenance.
The two detailed bound/retained material descriptor fingerprints remain
separate diagnostics rather than being recursively folded into the count
fingerprint. Runtime fallback node names are normalized to stable
class-and-sibling ordinals in both bucket paths and material origins.

The 2026-09-14 census measures the current nine-craft production composition:
physical berth feedback, the embodied destination/activity/service boards,
current combat presentation, Salvage work lighting, and the streamed Cinder
berth/cargo fitout. Existing `geometry_census_scenario_test.gd` freezes both
scenarios with Godot 4.7.1, headless Forward+, Dummy audio and HIGH quality.
These are measured totals; the budgets above remain unchanged, and **no ceiling
in this document has been raised.**

| Schema-v2 metric | Station resident (0 loaded) | Cinder loaded (1 loaded) | Loaded delta |
| --- | ---: | ---: | ---: |
| Triangles | 2,156,175 | 2,290,309 | +134,134 |
| Mesh renderer nodes | 6,588 | 6,797 | +209 |
| Surfaces | 6,686 | 6,895 | +209 |
| Unique meshes | 3,354 | 3,494 | +140 |
| Bound-phase materials | 692 | 734 | +42 |
| Retained/reachable materials | 968 | 1,015 | +47 |
| Unique shaders | 7 | 7 | 0 |
| Text triangles / instances | 79,591 / 43 | 100,157 / 56 | +20,566 / +13 |
| Lights / shadow lights | 335 / 20 | 362 / 20 | +27 / 0 |
| Particle systems | 45 | 45 | 0 |
| Scene-tree nodes | 11,612 | 12,035 | +423 |

#### 2026-09-14 second trim: -250,864 more resident triangles

Measured on merged `4808160f` the station-resident scene was 2,407,039
triangles — 118 under what the previous freeze recorded, because content landed
after it. This pass takes it to **2,156,175**, and again nothing else moves:
renderer nodes (6,588), surfaces (6,686), unique meshes (3,354), bound-phase
materials (692), retained materials (968), shaders (7), textures (34), lights
(335, of which 20 cast shadows), particle systems (45), scene-tree nodes
(11,612), collision shapes, interaction markers, evidence labels and walkable
routes are identical on both sides, and the streamed Cinder delta is unchanged
at +134,134.

| Bucket | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `ShipyardWorld/HabitatSpine` | 379,494 | 209,990 | -169,504 |
| `ShipyardWorld/AftJunctionStack` | 214,314 | 161,050 | -53,264 |
| `ShipyardWorld/SpaceBackdrop` | 22,096 | 7,696 | -14,400 |
| `ShipyardWorld/ExteriorTargetRange` | 33,083 | 27,707 | -5,376 |
| `ShipyardWorld/VipReceptionSuite` | 52,567 | 47,767 | -4,800 |
| `ShipyardWorld/OperationalLattice` | 84,452 | 82,692 | -1,760 |
| `ShipyardWorld/CentralBerthServiceLine` | 15,428 | 14,692 | -736 |
| `ShipyardWorld/LandingPad` | 42,756 | 42,116 | -640 |
| `ShipyardWorld/ExposedDockLattice` | 21,667 | 21,475 | -192 |
| `ShipyardWorld/IndustrialInfrastructure` | 11,520 | 11,328 | -192 |
| **Whole scene** | **2,407,039** | **2,156,175** | **-250,864** |

**Round stock is now budgeted by one rule, and it is not a new one.** The
station interiors tessellated every turned part at a flat 32 radial segments,
from a 4.5 m column to a 2.5 cm fastener head.
`StationSurfaceKit.radial_segments_for` answers the count from the chord sagitta
instead — the whole visual difference between an `n`-gon and the circle it
stands for — and it does so by *reusing `TorusGeometryBudget`'s own tolerance
and floor* rather than inventing a second standard. A cylinder's radial count
tessellates exactly what that class calls the tube cross-section: one circle,
seen locally, whose faceting shows as flats along a silhouette. Its 0.0021 rad
tolerance is calibrated so the game's biggest circles come out at the 40 they
were already authored at, and its `MIN_RING_SEGMENTS = 12` floor is the coarsest
tessellation that survived a magnified walk-up photo sweep of the worst case in
the game. Both numbers already have pictures behind them, which is the point.

The rule adds exactly one thing: *distance*. `TorusGeometryBudget` budgets every
tube cross-section at `NEAR_EYE_METRES` (0.6 m, the closest a camera is taken to
a solid in this game) because a torus can be anywhere; a station module knows
where it bolted each part. So a builder may declare the closest a player's
camera can actually get to a family — the Habitat's four overhead rib families
at 2.41 m to 2.90 m (their springing height less a deliberately tall 1.75 m
eye), the Aft operations ribs at 3.07 m, the Aft roof spine and vents at 3.4 m,
the Aft underfloor keel, cross members, braces and lower truss at 2.5 m, the
three utility runs slung under the open deck at 1.5 m — and anything that does
not declare one keeps the 0.6 m walk-up default. Every answer is quantised up
to a multiple of four so the four lateral extrema stay on real vertices and no
part's AABB, footprint or collision envelope moves, and every answer is capped
at the count the builder authored, so the rule can only ever remove segments.

**Shadow-only copies stopped being exact copies.** `StaticShadowBatch` merges an
explicit roster into one `SHADOWS_ONLY` mesh; it was merging the colour
triangles, so the Habitat's 27 pressure-rib arches cost their 378 tube segments
twice. A shadow pass consumes a silhouette and nothing else — it never shades
the surface, never samples its UVs and never sees its material — so a caller may
now supply one proven stand-in per source. Every acceptance gate still runs
against the real colour source, and each stand-in must fit inside its source's
own bounding volume. The stand-ins are held to shadow-map texels rather than
screen pixels: `ShipyardWorld` runs the key light at Godot's default 4096
directional atlas in `SHADOW_PARALLEL_4_SPLITS`, so the nearest cascade resolves
roughly 6 mm per texel before filtering and the 2-texel normal bias widen the
edge further. The Habitat's 378 arch segments went from 96,768 shadow triangles
to 15,456, and the Aft envelope's 32 round sources took the same treatment
(9,668 -> 5,332 for the whole 67-source batch). Its 35 chamfered-box sources
have no proven stand-in and are still merged exactly.

**Two families outside the modules moved on the same arithmetic.** The four
backdrop worlds were `64x32` for discs whose measured apparent radii at
1920x1080 and the default 72 degree vertical FOV are 74.5, 76.0, 49.6 and 44.1
pixels; `24x12` holds the silhouette error on the largest of them to 0.65 px,
under one pixel and nearly three times inside the shared tolerance. The sixteen
flight-range target lamps are 0.22 m spheres bolted to drones that float over
open void beyond the station's walkable envelope, reachable only by flying a
hull at them; budgeted at a deliberately close 3 m they come out at `16x8`.

Tori were left alone on purpose. `TorusGeometryBudget` already applies exactly
this reasoning, already has the rendered sweep behind its `32x12` floor, and
already refuses to raise authored values — so the only way to take triangles out
of the station's rings would be to lower a floor that was established by looking
at renders, which this pass is not willing to do.

Rendered evidence, at 1280x720 through `gl_compatibility` on a D3D12 GPU, from
ten fixed gameplay viewpoints — the habitat corridor at walking distance, a
walk-up on one rib foot, a look up at a rib crown, the common room, a bunk
privacy arch, the Aft operations room inside and its envelope from the open deck
outside, a freight-berth tie-down ring close under the apron's two
shadow-casting spots, the whole station in a long view with its cast shadows,
and the backdrop worlds — with station activity and service-agent clocks seeked
to zero so both sides frame the identical scene. Captures and diffs are under
`/root/.cache/mudds-shipyards/station-trim2-root/`.

Nine of the ten views are static; the tenth (a flight-range target drone) is
excluded from the totals below because the drone drifts, which moves 25.6% of
that frame's pixels between two runs of the *same* build.

- Over the nine static views, two runs of the same build differ on **0.16%** of
  pixels (a second same-build pair differs on 0.54%, driven by the backdrop's
  own star field and the range markers' drift).
- Before against after differs on **0.93%** of pixels over the same nine views.
  This pass is *not* pixel-identical and is not claimed to be: moving a
  silhouette is what it does, and a rule held to about 1.8 px of silhouette
  error is expected to move edge pixels. Per view the figure runs 0.13% (rib
  crown) to 1.30% (common room), and the 16x-amplified difference images show it
  confined to the outlines and specular gradients of the parts whose
  tessellation changed — no panel, no label, no light pool and no material
  boundary moves.
- **Shadow verdict.** The 33 station shadow-only batches were attributed
  directly rather than assumed: each view was rendered twice from the same build,
  once as shipped and once with every batch switched to `SHADOW_CASTING_SETTING_OFF`,
  and the pixels that differ are exactly the pixels those batches own — 0.79% of
  the long view, 0.19% of the operations room, 0.09% of the envelope exterior,
  0.06% of the corridor, none of the rib-crown view. Restricted to that mask,
  before against after changes 6.4% of the long view's shadow pixels, 12.3% of
  the envelope exterior's and 13.9% of the corridor's, at a peak delta of 55 to
  85 of 255 — and at 6x magnification the deck's shadow bands are in the same
  places at the same softness in both. No shadow detaches from its caster, no
  contact gap opens, and no acne appears; what changed is the sub-pixel
  antialiasing along the soft edge of shadows that were already there.
- Direct inspection at 4x to 14x finds the backdrop worlds the same size with
  the same banding in the same places and no polygon on either silhouette, and
  the corridor ribs still reading as a single thin line across the ceiling.

This is a scene-content measurement plus a rendered-composition check. It is not
a frame-time, GPU-time or VRAM claim, and the software/remote-display caveats at
the top of this document still apply. **No ceiling in this document has been
raised.**

#### 2026-09-14 trim: -528,560 resident triangles

Superseded by the second trim above for the whole-scene totals; the bucket
figures and the reasoning below remain the record of that pass.

The station-resident scene measured 2,935,717 triangles (with the Arrow access route of `24161c6`) before this pass against
the 1,800,000 ceiling above. Phase 10 item 2 of `ROADMAP.md` says trim before
raising budgets, so two reductions were taken and nothing was relaxed. Both are
triangle-only: renderer nodes, surfaces, unique meshes, materials, shaders,
lights, particle systems, scene-tree nodes, collision shapes, interaction
markers, evidence labels and lifecycle owners are identical on both sides, and
the streamed Cinder delta is unchanged.

| Bucket | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `ShipyardWorld/HabitatSpine` | 641,126 | 379,494 | -261,632 |
| `ShipyardWorld/SpaceBackdrop` | 141,696 | 22,096 | -119,600 |
| `ShipyardWorld/AftJunctionStack` | 317,226 | 214,314 | -102,912 |
| `ShipyardWorld/VipReceptionSuite` | 71,511 | 52,567 | -18,944 |
| `ShipyardWorld/IndustrialInfrastructure` | 23,040 | 11,520 | -11,520 |
| `ShipyardWorld/FleetDockComb` | 20,404 | 16,436 | -3,968 |
| `ShipyardWorld/CentralBerthServiceLine` | 17,924 | 15,428 | -2,496 |
| `ShipyardWorld/LandingPad` | 45,060 | 42,756 | -2,304 |
| `ShipyardWorld/ExposedDockLattice` | 23,395 | 21,667 | -1,728 |
| `ShipyardWorld/CargoAndMachinery` | 5,220 | 4,068 | -1,152 |
| `ShipyardWorld/OpenLaunchSpine` | 6,068 | 5,300 | -768 |
| `ShipyardWorld/UpperOperations` | 21,330 | 20,562 | -768 |
| `ShipyardWorld/ModernFleetRegistry` | 17,052 | 16,476 | -576 |
| `ShipyardWorld/ExteriorTargetRange` | 33,275 | 33,083 | -192 |
| **Whole scene** | **2,935,717** | **2,407,157** | **-528,560** |

**Station cylinder walls lost their four lateral rings (-408,960).** Every
chamfered cylinder and frustum the station modules build was still subdividing
its wall at Godot's `CylinderMesh.rings = 4`. That wall is planar between each
pair of radial angles — on a straight cylinder both side edges are vertical, on
a frustum both are generators meeting at the cone apex — so every ring the
subdivision adds sits exactly on the plane the two-triangle version already
interpolates, at exactly the linear parameter it would have produced: no
silhouette moves, no AABB changes, the band normals are identical because a
wall's profile is one straight segment, and the axial UV is linear in y either
way. Only per-*vertex* sampling could see the difference, and the station shades
per pixel with a world-triplanar finish. The chamfer bands and caps, where the
rim highlight lives, are untouched. The fleet took the same reduction during the
ship pass; `StationSurfaceKit.CYLINDER_WALL_RINGS` is the station half, and
`tests/station_structural_bevel_contract_test.gd` and
`tests/fleet_surface_detail_test.gd` prove the property on both sides.
HabitatSpine dominates the saving because its 27 pressure-rib arches are 14
tube segments each *and* are duplicated into an opaque shadow batch, so every
triangle removed from a rib is removed twice.

**The star shell became quads (-119,600).** `SpaceBackdrop/ParallaxStars` drew
2,600 stars as six-by-three spheres — 48 triangles each, the single heaviest
renderer in the scene — to draw something that is never more than about one
pixel across at 1.45 km. Each star is now one camera-facing quad at two
triangles. Seed, positions, colours and per-instance scales are untouched. The
quad's edge is `0.9 * sqrt(PI)`, the square with the retired sphere's projected
disc area, so a sub-pixel star's brightness — coverage times colour — does not
change.

Rendered evidence, at 1280x720 through `gl_compatibility` on a D3D12 GPU, from
ten fixed gameplay viewpoints covering the central berth and its star field, the
habitat corridor and a walk-up on one pressure-rib arch, the habitat common
room, the Aft Junction operations room, the landing-pad berth ring and the dock
lattice mast, with station activity and service-agent clocks seeked to zero so
both sides frame the identical scene:

- Two runs of the *same* build differ on **7.42%** of pixels (renderer and
  particle nondeterminism).
- Before against after differs on **7.46%** of pixels — inside that noise floor,
  and lower than it on five of the ten views.
- Over the star view's sky region, mean luminance moves `11.32994 -> 11.32570`
  of 255 (0.037%) with 93,391 lit pixels against 93,396.
- Direct inspection at 8x magnification finds the stars in the same places at
  the same sizes and brightnesses, and the arch tubes, collars and masts
  unchanged in silhouette and highlight.

This is a scene-content measurement plus a rendered-composition check. It is not
a frame-time, GPU-time or VRAM claim, and the software/remote-display caveats at
the top of this document still apply.

The retained union includes reachable unloaded content and presentation material
catalogues; it is not the bound material set or a GPU residency measurement.
The larger current roster does not reset any ceiling or imply performance
acceptance on native hardware.

The following bounded-change notes record earlier measurements and their local
deltas; their historical totals are superseded by the current table above.

The only geometry-census delta from this bounded Jovian slice is the unique-mesh
row: the 20 existing joints beneath `WalkableInterior/CargoBay/CargoFrame00..03`
retain 20 named nodes, visible copies, and surface submissions but share one
immutable SphereMesh, so both production scenarios retain 19 fewer unique
meshes. No collision, interaction, evidence or lifecycle node moved into that
visual family, and its four frame roots remain in the physical moving interior.

The resident Observation Logistics Spur and Salvage Terrace shares also retain
every renderer node, submission, material, collision and authority boundary in
both scenarios. The six named practical lenses now share one BoxMesh instead of
six, while the three long safety-rail visuals share one BoxMesh instead of three
without merging their three collision shapes. Together they remove seven more
unique meshes from both complete-scene rosters, leaving the streamed Cinder
delta unchanged at `+102`.

The later resident-only Jovian Freight Berth and LandingPad shares remove a
further 22 unique meshes from each complete-scene roster: eighteen guide-lens
SphereMeshes become one, and six flush tie-down TorusMeshes become one. Their
named copies, submitted surfaces, materials, lights, collision boundaries, and
TorusGeometryBudget lifecycle stay unchanged, so the streamed Cinder delta
remains `+102`.

The VIP servery's three named stool FootRing nodes now share one TorusMesh, and
the Arrow recon sensor mast's two ArrayReceiver nodes share one SphereMesh.
Those component-local changes retain every visible copy, structural submission,
material, transform, light, collision, and authority boundary while removing a
further three unique mesh identities from each complete-scene roster; the
streamed Cinder delta remains `+102`.

The fallback pilot builder now reduces its local generated mesh identities from
79 to 65 (`-14`) while retaining its 79 named nodes and structural submissions.
The documented resident and Cinder-loaded production scenarios resolve the
Player bucket through `PilotSkinnedPresentation`, not that fallback builder, so
the direct `2f2419f` remeasurement leaves every complete-scene count and both
measurement fingerprints unchanged.

The subsequent production-reachable Habitat service-pipe-collar share reduces
its six unchanged visual copies to one immutable mesh (`-5`), and the four
resident StationStructuralServiceDressing components retain their 24 named
FasciaFastener copies through one material-free session mesh rather than four
component-local six-copy meshes (`-3`). Both changes preserve renderer nodes,
surfaces, triangles, materials, lights, collision and authority boundaries, so
each scenario's unique-mesh roster falls by exactly eight while the streamed
Cinder delta remains `+102`.

Torrent's four named CaptureJaw renderers now retain one Hero-local gold
rounded-box mesh rather than four (`-3`) with their paths, transforms, surface
material, submissions and visual-only status unchanged. The later RangeOpponent
particle-mesh cache has no effect on either frozen production scenario: neither
station-resident nor one-Cinder-loaded progression activates its transient
particle mesh, so it changes no schema-v2 count or scenario delta here.

The Arrow follow-up keeps the six existing childless `CurveJoint` sphere nodes,
their exact paths and transforms beneath `PortLateralArray` and
`StarboardLateralArray`, six visible copies, six surface submissions, sensor
material identity, and shadow state. Their identical `0.07 m`, 28-radial,
14-ring recipe now retains one component-local immutable `SphereMesh` instead
of six, reducing both production scenarios by exactly five unique meshes and
changing no other renderer, material, collision, evidence, or lifecycle count.

Three later immutable-resource slices retain every renderer node and submission
while reducing allocations: Arrow's six `SensorLeadingEdge` joints share one
SphereMesh, its three `DorsalDataConduit` joints share one SphereMesh, and its
five `FuselagePanelBand` rings share one TorusMesh while retaining the stable
named capture path and the authored-64x18 to live-41x12 torus-budget metadata.
Together these slices remove eleven unique mesh resources without changing
drawn copies, materials, collision, evidence, or lifecycle authority.

The Aft VIP facade foot/crown family and the Habitat nutrient-tank bands and
valves are now three visual-only MultiMesh batches. They retain eleven drawn
copies but remove seven renderer nodes/surface submissions and seven scene-tree
nodes. The first implementation accidentally built all three families at their
authored 48x16 TorusMesh recipes, bypassing the production TorusGeometryBudget
and adding 6,592 triangles. The landed correction applies the exact prior live
recipes (Aft 32x14, tank bands 40x12, valves 32x12) while retaining authored
48x16 metadata. The final census therefore preserves the prior triangle total
and the batching reductions; focused A/B captures made before the correction
were pixel-identical, and the corrected recipes restore the exact pre-batch
renderer geometry rather than introducing a new visual value.

Two subsequent component-local identity-only shares change no renderer value or
submission. The three ordinary Habitat `GardenColumn/ColumnCollar` TorusMesh
nodes retain their stable paths, transforms, live 40x16 recipe, copper material
and three submissions while their private mesh resources fall from three to
one. The base RangeOpponent's two ordinary `WeaponTelegraph` SphereMesh nodes
likewise retain both paths, transforms, dynamic scale/visibility, amber material
and two submissions while their private mesh resources fall from two to one.
Together they remove three unique meshes from both scenarios without changing
triangles, renderer nodes, surfaces, materials, lights, particles, scene nodes,
collision, evidence, combat, or lifecycle authority.

The later Aft `VisualPressureEnvelope/SpineClamp` identity-only share retains
all five ordinary profiled nodes, stable first/generated paths, transforms,
five visible copies and five submissions. Their exact authored 48x16 to live
32x8 `aft_interface_collar` recipe, copper material and node/mesh metadata are
unchanged; only five private TorusMesh identities become one component-local
immutable resource. This removes four further unique meshes in both scenarios
without changing any other census or authority field.

The adjacent Aft `WatchRackBank/RackCableTrayClamp` family applies the same
identity-only rule to four ordinary profiled nodes: exact authored 48x16 to
live 32x8 metadata, paths, transforms, brass material, four copies and four
submissions remain, while four private TorusMesh identities become one. That
removes three additional unique meshes in both scenarios and changes no other
census or authority field.

Three later Aft operations-room families extend the same identity-only rule.
Six rubber `ConsoleShockCollar` nodes share one exact live-32x8 TorusMesh,
four chair `PedestalBearing` nodes share one, and three brass `ConduitCollar`
nodes share one. All thirteen ordinary renderer nodes, visible copies,
submissions, paths, transforms, materials, authored-48x16 metadata and separate
collision/semantic owners remain. The three shares remove exactly ten unique
meshes in both scenarios and change no triangle, renderer, surface, material,
light, particle or node count.

Production planetary cruise adds one direct-Main binding and its one retained
physical-controller child. The controller-reachable pause row adds one
`VBoxContainer`, one `Button` and one `Label`; together those two slices add
five non-rendering scene-tree nodes in both scenarios. They do not add a
renderer, material, light, particle, physics shape or streamed-generation
delta.

Arrow's passive `PlanetaryEntryHeatTarget` is now one direct child subtree of
the final variant visual root. It adds exactly three nodes, one SphereMesh
renderer/surface/submission, 1,088 triangles, one unique mesh, one exclusive
material and one shader to both scenarios. Its checked-in intensity remains
exactly zero and no production atmosphere profile or observation caller is
wired, so these are reachability/census facts rather than a visible-entry or
physical-heating claim.

The subsequent VIP slice removes only the centre
`OutboardSillSpill02` omni while retaining the original `01`/`03` side pair and
the uninterrupted 11.4 m emissive `OutboardSillCove`. It therefore removes one
enabled, shadowless omni and one scene-tree node in both scenarios without
changing any geometry, material, collision, evidence, or authority count.
A single stable-camera 1280x720 Forward+ A/B reconstructed the old centre light
for the first capture and hid only that light for the second capture in the
same Godot process. At the gameplay-distance well-to-window framing, whole-frame
mean luminance changed `0.21202 -> 0.21093`; the centre-window ROI changed
`0.18679 -> 0.18444`, and its below-0.02-luminance fraction changed only
`5.0008% -> 5.0101%`. Direct inspection found no centre black gap: the emissive
sill and side-pair wash remain continuous. This is a bounded composition check,
not a GPU-time or frame-time claim.

The Fabrication slice retains all six authored ceiling-luminaire copies and
replaces their six static, shadowless omnis with three longitudinal
same-colour pools: warm port, cool central, and warm starboard. Each pool sits
at its pair midpoint (`z=10.75`), uses range `11.75 m` and energy `4.8`, and
geometrically contains both former range-`8 m`, energy-`3.2` source spheres
because `3.75 + 8 = 11.75`. This removes three enabled omnis and three nodes in
both scenarios without changing geometry, materials, collision, routes, or
authority. One same-process 1280x720 Forward+ A/B reconstructed the six old
lights and then enabled only the three production pools: whole-frame mean
luminance changed `0.118814 -> 0.118952`, mean absolute luminance delta was
`0.000770`, and the sampled near-black fraction decreased
`4.1142% -> 4.0268%`. Direct inspection found no black gap, label-readability
loss, or warm/cool colour drift. This is a visual-composition check, not a
GPU-time or frame-time claim.

The Music settings correction adds one reachable, labelled slider through the
existing generic HUD settings builder. Its row contributes five retained UI
nodes in both scenarios, so it changes only the absolute scene-tree node row;
the loaded-minus-resident delta remains exactly `+301`.

The production `CinderStreamedShipBerthBinding` contributes one further
resident node in both scenarios. It has no renderer, material, light, particle,
physics, audio, or process-loop contribution; its only purpose at this stage is
to observe the then-zero-berth Cinder generations and retain the then-five
resident berth IDs without fabricating a streamed record. The current authored
composition has nine resident berths and three real streamed Cinder berths.

The Main-owned Ember bootstrap/binding and atomic common-world origin owner make
the authored Ember PackedScene reachable from the production ownership graph
without loading it in the station-resident scenario. Its eight original material
resources consequently raise the retained/reachable material count from 631 to
639 while bound-phase materials stay exactly 450. The origin owner is one
non-rendering scene node and adds no mesh, surface, light, particle, physics, or
audio work.

The loaded `CinderStreamingBootstrap` bucket independently accounts for exactly
134,134 triangles, 209 mesh renderer nodes/surfaces, 584 visible MultiMesh
copies, 27 lights and 426 nodes. Its extra three nodes beyond the whole-scene
`+423` delta replace the resident bootstrap/coordinator shell nodes rather than
contradicting the total.

The 2026-09-14 `tools/geometry_census.gd` resident measurement fingerprint is
`09e5f5d597d85a2f9cb4e76bb7141f60646e5fdafd84fa06a6b3cb0ac562341d`;
the loaded fingerprint is
`69ec5823c9e6cb6ca86d256d84efbc88ba959cf779f82b43349041e0d8b74fc5`.
`tests/geometry_census_scenario_test.gd` takes its own settle and therefore
carries its own pair, `c839303341ff1af55b5739aed800d1aafc11740240f73d8191c6633446835fb1`
and `bb414bf00e3fbbfae601757ab0b5a41bb4d291f8a35a141adbff780e6d175a6b`.
`tests/geometry_census_scenario_test.gd` freezes both production scenarios,
their exact totals/delta, sole-generation ownership, a resident-mismatch red
mutation, and the separate fingerprints. These are renderer-independent live
scene-graph ceilings, not draw-call, visibility, VRAM, GPU-time or frame-time
measurements. Only one Cinder generation is covered; transition overlap,
failed loads, other future locations and package/native residency remain out of
scope.

### Deterministic station light-overlap measurement

`tools/station_light_overlap_census.gd` closes the route-overlap measurement
called for below without deleting, changing or second-guessing any fixture. It
instantiates the production `Main`, explicitly applies HIGH visual quality,
settles for eight idle frames, one physics frame and one final idle frame, then
disables processing on `Main` before taking the synchronous sample. Its default
`station_resident` scenario rejects any loaded Cinder instance. The separate
`cinder_loaded` scenario drives the checked production binding until exactly one
coordinator-owned generation has committed, then takes the same frozen sample.
The frozen roster is 22 named embodied points: six
walking, five boarding, four operations and seven flight-route samples. The
node-backed samples freeze both their exact production paths and world
positions. Five flight points are resolved directly from the published Cinder
Reach checkpoint resource rather than copying an unverified parallel route.
Walking and operations floor markers use a documented 1 m torso offset; ship
and flight markers are already body-centre positions.

Each sample is treated as the camera position for this geometric proxy. For
each point, a light counts only when it is inside the tree, visible through its
ancestors, has positive `light_energy`, shares the sample's visual layer, and
can geometrically reach the point under the live light settings:

- `DirectionalLight3D` has global reach; Godot does not apply the local-light
  distance-fade fields to this type.
- `OmniLight3D` requires distance no greater than `omni_range` and, when
  `distance_fade_enabled`, no greater than
  `distance_fade_begin + distance_fade_length`.
- `SpotLight3D` requires both `spot_range` and the actual `spot_angle` around
  the light's world-space `-Z` axis, plus the same enabled distance-fade
  endpoint.

Shadow-enabled contributors are counted and listed separately, but an
Omni/Spot shadow counts only through
`distance_fade_shadow` when distance fade is enabled; that property is the
camera-distance cutoff itself, not the start of another length-based fade.
The JSON contributor record freezes the actual enabled flag, camera distance,
begin, length, light endpoint, shadow endpoint, separate light
and shadow inclusion decisions, and human-readable reasons. Runtime fallback
names such as `@OmniLight3D@298` are converted to stable class-and-sibling
ordinals such as `OmniLight3D[01]`; this preserves identity without leaking
process-specific instance IDs into the sorted paths or JSON fingerprint. The
focused fixture turns range, cone direction, shadow state, visibility, energy,
cull mask, fade enablement, fade begin, fade length and the shadow-fade boundary
into mutation-sensitive checks. Exact-endpoint and just-beyond-endpoint
witnesses freeze the inclusive renderer cutoff.

Run the default station-resident scenario with:

```sh
KETH_LIGHT_CENSUS_JSON=/tmp/station-light-overlap-census.json \
  godot --headless --audio-driver Dummy --path . \
  --script res://tools/station_light_overlap_census.gd
```

Run the production-streamed destination scenario by adding
`KETH_LIGHT_CENSUS_SCENARIO=cinder_loaded`. Each schema-v3 JSON report records
the scenario and exact loaded-instance count, so a station baseline cannot
silently include destination lighting. Both fields are also inputs to the
measurement fingerprint; relabelling identical counts and contributor rows
therefore produces a different hash.

The production `Main` measured here is the current nine-craft composition.
The VIP sample follows its translated reception anchor at z=75.2; Salvage
contributes its three authored shadowless work-bay lights.
The roster fingerprint is
`43dabfe2e1cb3cc47caa41c34df8c71a2af9f955b8048d3c129ad5359491de07`.
The station-resident complete scene/per-point/contributor fingerprint is
`6ff23fb3dafda6c2d9a6728d1e9b5638f6b631196cf4e54e766847dc2ae1edb7`;
the separately loaded fingerprint is
`0ba07982b5c105655d224acd46480fc8c7244631dc35c02e7e31190a079c55e4`.
Pulsing lights report the stable positive-energy predicate used for inclusion,
not their clock-dependent instantaneous amplitude.

| HIGH scenario / light roster | Total | Enabled at frozen phase | Shadow casting |
| --- | ---: | ---: | ---: |
| Station resident: `DirectionalLight3D` | 3 | 3 | reported in combined row |
| Station resident: `OmniLight3D` | 319 | 242 | reported in combined row |
| Station resident: `SpotLight3D` | 13 | 13 | reported in combined row |
| **Station resident: all `Light3D`** | **335** | **258** | **20 total / 20 enabled** |
| Cinder loaded: `DirectionalLight3D` | 3 | 3 | reported in combined row |
| Cinder loaded: `OmniLight3D` | 345 | 268 | reported in combined row |
| Cinder loaded: `SpotLight3D` | 14 | 14 | reported in combined row |
| **Cinder loaded: all `Light3D`** | **362** | **285** | **20 total / 20 enabled** |

Streaming Cinder therefore adds exactly **26 enabled omnis and one enabled
spot**, with no change to the 77 disabled lights, three directionals, or 20
shadow casters. The loaded-instance count changes from zero to one.

The maximum geometric overlap is **15 enabled lights** at
`operate-aft-service-arm`; only one of those casts shadows. The largest shadow
overlap is **3** at `board-halyard-berth`, where eight lights can influence the
sample. Applying the live fade endpoints did not change any scalar row: every
sampled local contributor that already passed its smaller illumination range
also lies inside its light fade endpoint, and every sampled shadow contributor
also lies within its exact `distance_fade_shadow` cutoff. It does change the
method and evidence—the census can now reject a long-range light or shadow
culled at the camera point, and the focused fixture proves that path.

Historical note: the prior **315 -> 321 total / 263 -> 269 enabled** refreeze was
measured while Cinder was always resident. It remains valid evidence that
Observation Logistics Spur added exactly six enabled, shadowless omnis at
stable paths `Practical01` through `Practical06`; it is not the present
station-resident baseline. Fabrication now contributes three enabled,
shadowless pools at stable paths `PracticalPoolCentral`, `PracticalPoolPort`,
and `PracticalPoolStarboard`; Salvage Terrace contributes zero dynamic lights.
None of the Fabrication, Observation or Salvage paths reaches any frozen
sample. The five worst points, sorted by total overlap then shadow overlap
then stable id, remain identical in both current scenarios:

| Point | Kind | Enabled influence | Shadow casters |
| --- | --- | ---: | ---: |
| `operate-aft-service-arm` | operations | **15** | 1 |
| `walk-habitat-common` | walking | **11** | 1 |
| `walk-aft-lower-junction` | walking | **10** | 1 |
| `board-halyard-berth` | boarding | **7** | **3** |
| `walk-vip-reception` | walking | **7** | 1 |

Their contributing paths are emitted in full in deterministic JSON. In compact
path-prefix form, the same exact rosters are:

- `operate-aft-service-arm`: `ShipyardWorld/{DeckBounceFill,SpaceCounterFill,SpaceKeyLight}`
  plus `ShipyardWorld/AftJunctionStack/Structure/OperationsRoom/LocalizedLighting/`
  `{CoveSpillCool,CoveSpillWarm,OperationsPoolLight,OmniLight3D[01]` through
  `OmniLight3D[09]}`.
- `walk-habitat-common`: the same three world directional paths, plus
  `ShipyardWorld/HabitatSpine/Structure/ObservationCommon/`
  `{CommonPoolLight,TableDisplayGlow,OmniLight3D[01]` through
  `OmniLight3D[05]}` and
  `ShipyardWorld/HabitatSpine/Structure/PressurizedHabitatCorridor/OmniLight3D[02]`.
- `walk-aft-lower-junction`: the three directionals, plus
  `ShipyardWorld/AftJunctionStack/Structure/LowerOpenDeck/`
  `{JunctionArcSpill,OmniLight3D[01]}`,
  `ShipyardWorld/AftJunctionStack/Structure/OperationsRoom/LocalizedLighting/`
  `{CoveSpillCool,DoorPoolLight,OmniLight3D[01],OperationsPoolLight}`, and
  `ShipyardWorld/AftJunctionStack/Structure/OperationsRoom/VisualPressureEnvelope/ExteriorCowlSpill`.
- `board-halyard-berth`: the three directionals, plus
  `HalyardCrewTransport/WalkableInterior/CrewCabin/`
  `{OmniLight3D[01],OmniLight3D[02]}`,
  `ShipyardWorld/FleetDockComb/GeneratedComb/SurfaceDetail/SlabBeaconSpill02`,
  and `ShipyardWorld/FleetDockMastSpot`.
- `walk-vip-reception`: the three directionals, plus
  `ShipyardWorld/VipReceptionSuite/Structure/Fitout/LightColumnSpillPort` and
  `ShipyardWorld/VipReceptionSuite/Structure/Lighting/`
  `{LanternCoveSpillFront,LanternCoveSpillPort,LanternCoveSpillStarboard}`.

For completeness, every frozen point's two scalar results are:

| Point | Enabled influence | Shadow casters |
| --- | ---: | ---: |
| `board-arrow-berth` | 4 | 2 |
| `board-central-berth` | 4 | 1 |
| `board-freight-staging` | 4 | 2 |
| `board-halyard-berth` | 7 | 3 |
| `board-zenith-berth` | 4 | 1 |
| `flight-cinder-checkpoint-01` | 5 | 1 |
| `flight-cinder-checkpoint-02` | 5 | 1 |
| `flight-cinder-checkpoint-03` | 5 | 1 |
| `flight-cinder-checkpoint-04` | 5 | 1 |
| `flight-cinder-checkpoint-05` | 3 | 1 |
| `flight-launch-gate` | 3 | 1 |
| `flight-ship-spawn` | 4 | 1 |
| `operate-aft-service-arm` | 15 | 1 |
| `operate-central-tow` | 5 | 2 |
| `operate-freight-gantry` | 4 | 2 |
| `operate-habitat-patrol` | 4 | 1 |
| `walk-aft-lower-junction` | 10 | 1 |
| `walk-aft-upper-floor` | 5 | 1 |
| `walk-habitat-common` | 11 | 1 |
| `walk-habitat-corridor` | 4 | 1 |
| `walk-player-spawn` | 6 | 2 |
| `walk-vip-reception` | 7 | 1 |

These numbers are a **geometric camera-point influence proxy**, not a
performance result.
They do not account for walls or other occluders, camera/frustum visibility,
pixels shaded, shadow-map update policy, renderer clustering, draw cost, GPU
time, CPU time or frame time. In particular, this is not an llvmpipe benchmark
and cannot justify a Windows hardware claim or a light-budget increase. It is a
deterministic map of where the authored light volumes overlap, suitable for
choosing later hardware measurements or fixture-consolidation candidates.

### Merge-time decision: trim, do not raise

The frozen ceilings stay unchanged. The minimum and target hardware have not
changed, and no representative Windows GPU benchmark exists that would justify
relaxing them. Raising each limit just enough to make this scene green would
erase the allowance intentionally reserved for enemy craft, interiors and
station work. This is not a marginal miss: submission/state proxies are 25–38%
over, lights are 29% over, nodes are 30% over, and even the still-green triangle
line has only 0.4% left.

The first trim should be structural and visually lossless:

1. Share `StationOperationsActivity`'s immutable 17-material catalogue across
   its ten placements, and the six-material `StationServiceAgent` catalogue
   across its four couriers. The animated lenses swap references; they do not
   mutate those materials.
2. Extend existing `MultiMesh` use over repeated **visual-only** stock in
   `HabitatSpine` and the station-activity presentations. Named or collidable
   nodes stay ordinary meshes until their audits and collision indexing support
   batches.
3. Measure maximum active and overlapping lights along representative routes
   before removing practical fixtures. Most new habitat and VIP lights are
   shadowless and were added after rendered dark-room failures. The total-light
   ceiling remains a provisional proxy; the 16-shadow-light ceiling remains a
   hard line until real Windows GPU evidence says otherwise.

No ceiling changes from this remeasurement. Re-freeze summary: measured scene
`1,416,160 -> 1,792,816` triangles, `4,197 -> 5,776` mesh instances,
`4,204 -> 5,783` surfaces, `2,103 -> 2,756` unique meshes,
`240 -> 309` lights, and `6,582 -> 9,128` nodes. The reason is the merged
habitat, VIP, fifth craft/berth and operational presentation content that did
not coexist in either earlier worktree census.

Any remaining headroom is an **allowance to spend**, not slack. The fifth craft
has now landed, while the roadmap still owes enemy craft, a walkable freighter
interior and station-wide modelling. New content must fit through sharing,
instancing, LOD or impostors rather than larger ceilings.

Shadow-casting lights remain the most important line. Nineteen of 294 resident
lights (and 317 with Cinder loaded) cast shadows, three above the ceiling; each
can re-rasterise the geometry in its range every frame it is visible.
Consolidate at least three before adding another shadowed fixture.

### Historical: re-measured either side of the long-cargo pass

The following historical snapshot records two census runs either side of one
content change. It is retained to explain that pass, not as the current budget
status:

| Metric | Before | After | Delta | Budget | Headroom after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Scene triangles | 1,403,320 | 1,416,160 | +12,840 | 1,800,000 | 21.3% |
| Mesh instances | 4,120 | 4,197 | +77 | 4,200 | **0.1%** |
| Surfaces | 4,127 | 4,204 | +77 | 4,300 | 2.2% |
| Unique meshes | 2,045 | 2,103 | +58 | 2,200 | 4.4% |
| Unique materials | 522 | 544 | +22 | 550 | **1.1%** |
| `Light3D` nodes | 240 | 240 | 0 | 240 | **0%** |
| Scene-tree nodes | 6,440 | 6,582 | +142 | 7,000 | 6.0% |

The content added is two 21.6 m cargo transfer runs plus a re-sited short one.
Triangles are not the story: the whole addition is 0.9% of the scene and that
line still has a fifth of its allowance left.

**The three figures in bold are the ones to read, and none of them is this
pass's doing.** All three were at or near the ceiling before it started — the
table above this section records 3,605 mesh instances and 203 lights for the
same budgets, and the scene was already at 4,120 and 240 when this pass began.
`Light3D` is *exactly* at budget with no headroom at all, so the next module
that wants a practical light has nowhere to take it from.

The +77 mesh instances is deliberately the largest number this pass spends, and
it is 77 rather than 154 because every repeated element in the cargo lines is
drawn from a `MultiMesh`: twelve batches across the three lines draw 57 copies of
rail ties, hoist post bands, sled wheels and container ribs, for twelve draw
submissions instead of 57. The pre-existing short line was instanced the same way
in passing and went 47 draws to 38 for a pixel-identical result, which paid for
most of one of the two new runs.

Two things learned doing that, worth recording before someone else instances
something:

- **A `MultiMesh` buffer does not exist under `--headless`.** `instance_count`
  survives, but `buffer` comes back empty and `get_instance_transform()` returns
  identity for every copy, because the data lives on the rendering server and the
  dummy server discards it. Every audit in the test matrix runs headless, so an
  audit that reads instance transforms back off the resource passes vacuously and
  disagrees with the player's build. Audit the transforms you authored, not the
  ones you can read back.
- **Instanced geometry is invisible to the station's collision-without-visible-
  geometry sweep**, which builds its index by walking `MeshInstance3D`. Anything
  given collision must therefore stay a drawn mesh; only stock that is never
  solid — ties, bands, wheels, ribs — is safe to batch.

**Unique materials at 544/550 is the line that blocks the next placement of this
kind.** `StationOperationsActivity` builds its complete 17-material set per
instance regardless of profile — deliberately, so its audit reports retained
memory rather than the current animation phase — so each new placement costs 17
whether it uses them or not. Sharing that set across instances is the change that
buys the next ten placements, and it is not this pass's to make.

## Where the geometry actually is

Whole merged scene at `33bd5a9`:

| Bucket | Triangles | Share |
| --- | ---: | ---: |
| `ShipyardWorld/HabitatSpine` | 450,337 | 25.1% |
| `ShipyardWorld/AftJunctionStack` | 285,450 | 15.9% |
| `TorrentInterceptor` | 133,818 | 7.5% |
| `ShipyardWorld/SpaceBackdrop` | 127,296 | 7.1% |
| `ShipyardWorld/NearbySectorCluster` | 117,457 | 6.6% |
| `JovianLightFreighter` | 75,740 | 4.2% |
| `ShipyardWorld/OperationalLattice` | 72,604 | 4.0% |
| `ShipyardWorld/VipReceptionSuite` | 65,504 | 3.7% |
| `ShipyardWorld/JovianFreightBerth` | 57,018 | 3.2% |
| `ZenithInterceptor` | 52,686 | 2.9% |
| everything else | 354,906 | 19.8% |

By kind, which is the more useful cut:

| Mesh kind | Triangles | Share | Instances | Triangles each |
| --- | ---: | ---: | ---: | ---: |
| `ArrayMesh` | 1,288,590 | 71.9% | 5,714 | 225 |
| `SphereMesh` | 249,336 | 13.9% | 2,822 | 88 |
| `TorusMesh` | 174,260 | 9.7% | 180 | 968 |
| `TextMesh` | 75,702 | 4.2% | 39 | 1,941 |
| `BoxMesh` | 2,988 | 0.2% | 249 | 12 |
| everything else | 1,940 | 0.1% | 25 | 77 |

The kind table sums to 32 triangles short of the scene total: sixteen `Label3D`
nodes, two triangles each, which have no `Mesh` resource to classify. They are
listed here only to show what `Label3D` costs next to `TextMesh` — a quad and a
font atlas versus real triangulated glyph contours.

`ArrayMesh` at 72% is the authored art. The 5,714 kind instances count physical
copies inside `MultiMesh` batches, not 5,714 draw submissions. Optimise repeated
draw nodes and unshared resources before cutting authored silhouettes.

## Historical named triangle targets

These came out of the earlier census and are retained as the record of the ring
and lettering decisions. Current binding trim targets are listed in the
merge-time decision above.

1. **`TorusMesh`: done, and for less than the estimate. See "The ring fix" below.**
   213,664 → 128,316, a saving of 85,348 rather than the ~150,000 estimated here.
   The gap is the estimate's fault, not the pass's: it assumed `24 x 8` would be
   indistinguishable on a small collar, and rendered, it is not.
2. **`ShipyardWorld/SpaceBackdrop/ParallaxStars`: 124,800 triangles.** Large, but
   it is a single `MultiMeshInstance3D` of `radial_segments = 6, rings = 3`
   spheres — one draw call, already deliberately cheap per star, and the census
   counts its instanced geometry in full. Left alone: it is loud in a triangle
   census and quiet in a frame. Recorded so nobody "optimises" it twice.
3. **`NearbySectorCluster/DebrisField/DebrisChips`: 56,160 triangles**, 520
   instances in one `MultiMesh`. Same reasoning as above.
4. **Per-frame draw calls, GPU time, VRAM and frame-time percentiles are still
   unmeasured** and cannot be measured from this environment. Phase 9 item 7's
   benchmark runner is what closes that, on real Windows hardware.

## The ring fix, for the record

The second thing this budget was used for, and the first time it said **no**.

Before: 129 `TorusMesh` rings and collars, 213,664 triangles, **15.2% of the
scene**, 1,656 each. Nine builders — five station modules and four ship visuals —
had each fixed its own tessellation (`rings` 40-64, `ring_segments` 12-18) and
applied it to everything from a 148-metre moonlet ring to a 10-centimetre pipe
clamp. After: 128,316 triangles, 995 each, a saving of **85,348 triangles, 6.0%
of the whole scene**.

Owned by `scripts/world/torus_geometry_budget.gd`, swept once from
`game_flow.gd` because the rings are spread across `ShipyardWorld` *and* the four
ship scenes that are siblings of it. It changes `rings` and `ring_segments` only,
never upward, so it cannot move, resize, recolour or re-material anything.

**The estimate above was wrong and the reason matters.** It guessed ~150,000
triangles on the assumption that `24 x 8` is indistinguishable on a small collar.
It is not. The rule was first written as a pure angular-error budget — allow the
sagitta of the segmented circle to subtend at most two pixels at the distance the
ring is realistically seen from — and that rule took the 10 cm exterior pipe
clamps down to `18 x 9`. Built into the live world and photographed at walk-up
range, `18 x 9` is a **visibly polygonal ring**: straight runs and hard corners
around the top and lower-left of the silhouette. That is exactly the tell this
project is spending its effort escaping, so the reduction was refused and the
floor raised until it wasn't visible.

The floor was chosen by sweeping that clamp through `48x16`, `32x12`, `24x12`,
`20x10` and `18x9` in the live world and looking at each at 3x magnification:
`32x12` is smooth, `24x12` shows a faint flattening at the top, `20x10` has clear
corners, `18x9` is plainly a polygon. **`32 x 12` is the floor**, and it costs
about 11,000 triangles that `24 x 12` would have saved. The general lesson, which
the arithmetic missed: a silhouette *polygon* is detectable well below the point
where its deviation from a circle is two pixels, because the eye reads
straightness and corners rather than absolute error.

**Twenty of the 129 rings are left exactly as authored, and that is the point of
the pass.** The tolerance is calibrated so the budget's own answer for a large
ring is 40 — the value `nearby_sector_cluster.gd` already uses on the biggest
circles in the game. Everything a player reads *as a circle* was already at 40 or
finer than the rule asks for, so all of it is untouched to the segment: the
**Cinder Reach beacon signal and trim rings** (the named risk), the 148 m and
132 m moonlet rings, the six Reach moonlet crater rims, the Cinder Reach drum
collars, the derelict habitat can's torn rim, and the Jovian outer dock ring. The
saving comes entirely from rings authored at 48 and 64 — collars, sockets,
bearings, gimbals and clamps, none of which are circles anybody looks at.

Checked by looking, not asserted: `tests/capture_torus_smoothness.gd` builds both
tessellations out of one frozen scene and photographs fourteen rings at two
framings each. What was rendered and judged clean is recorded in the session
report; the half-metre dock mast collar at 0.6 m and the 9 m landing pad rings at
both walk-up and whole-ring framing are the two that mattered most, and both are
indistinguishable at 1:1.

### Bounded observation-chair bearing profile

A later measured pass against base `9084011` found one family where the general
floor was paying for geometry that cannot contribute a silhouette: the eight
visual-only copper bearings inside the observation-common chair pedestal/seat
overlap. The family now opts in explicitly with
`torus_geometry_budget_profile = occluded_chair_bearing`; names and paths do not
select the exception. Its major sweep remains at the globally reviewed 32-ring
floor. Only the occluded tube cross-section changes from 13 to eight segments,
aligned to the cardinal axes so the authored inner/outer-radius extrema and AABB
remain exact.

The comparison is the previously budgeted production result, not the larger
builder request: **8 instances / 8 surfaces / 6,656 triangles (`32x13`) -> 8 / 8
/ 4,096 (`32x8`)**, saving **2,560 triangles (38.5%)** with no node, resource,
surface, transform, material, radius, collision or authority change. The whole
production census moved **1,808,482 -> 1,805,922 triangles** while mesh renderer
nodes stayed 5,830, surfaces 5,837, unique meshes 2,795 and scene nodes 9,394.
Residual `TorusMesh` cost at that point was **171,700 triangles across 180
visible copies** (9.5% of the scene), down from 174,260.

One matched 1400x900 Forward+ comparison frame used the existing
observation-common camera at `(0, 2.5, 18.7)`, looking at `(0, 1.65, 27.5)`, and
rendered the same frozen scene first at `32x13` and then at `32x8`. The bearings
remain visually occluded and the two halves show no apparent change. The adapter
was llvmpipe, so this is a composition/silhouette check only, never a frame-time
or representative-hardware claim. The focused gates freeze the exact family
roster and counts and reject applying this lower tube floor to any unmarked
torus.

### Bounded Aft interface-collar profile

The next pass selects 26 small Aft Junction collars that wrap an already-drawn
solid support or service run: six console shock mounts, five roof-service spine
clamps, four exterior utility-pipe clamps, four cable-tray clamps, four chair
pedestal bearings and three service-wall conduit collars. Each is a childless,
visual-only `MeshInstance3D`; the wrapped pedestal, console, pipe, tray or
conduit remains the collision and semantic authority. An explicit
`aft_interface_collar` profile and an audited subtype tag select this exact
roster. No path/name inference or station placement code is involved.

Every member previously reached the general budget at `32x12`. The profile
retains all 32 major segments and changes only the tube cross-section to eight
cardinal-aligned segments. Therefore no global floor, radius, transform, outer
extremum or exposed major-ring sweep changes. The measured family result is
**26 resources / 26 instances / 26 surfaces / 19,968 triangles -> 26 / 26 / 26
/ 13,312**, saving **6,656 triangles (33.3%)**.

Against base `39acaed`, the production census moves **1,805,922 -> 1,799,266
triangles**, putting the scene 734 triangles below the 1.8-million ceiling.
`TorusMesh` residual cost is **165,044 triangles across 180 visible copies**
(9.2% of the scene), down from 171,700. Mesh renderer nodes stay 5,830, surfaces
5,837, unique meshes 2,795, unique materials 677 and scene nodes 9,394.

One matched 1400x900 Forward+ frame used the production operations-room camera
at local `(5.6, 2.35, 10.15)`, looking at `(5.6, 1.35, 15.4)`, with the same
frozen scene rendered first at `32x12` and then at `32x8`. At gameplay distance
the chair, console and service interfaces retain the same apparent outlines and
shading. The adapter was llvmpipe, so this is only a composition/silhouette
inspection, never representative frame-time evidence.

### Bounded freight lashing-ring profile

Against base `abb785b`, the next narrow profile selects the eight recessed
lashing rings in `JovianFreightBerth/HandlingZones`. They are childless,
visual-only TorusMesh fittings partly inset into unchanged graphite deck plates;
the apron floor and its existing static bodies remain collision authority. The
builder applies both `freight_recessed_lashing_ring` and the independent
`recessed_lashing_ring` family tag directly to those eight instances. Neither
the budget nor its tests infer membership from a broad name or path match.

The current general budget produced `32x12` for each 0.24 m outer-radius ring.
The bounded profile retains all 32 major-sweep edges and changes only the 0.04 m
tube section to eight cardinal-aligned edges. Exact tests retain the complete
eight-path/name bijection under `HandlingZones`, transforms, materials and
independent mesh resources. They also freeze the 0.16/0.24 m radii, exact AABB,
all 16 inner/outer/tube cardinal extrema, one surface per instance, and child
rosters. The family moves **8 resources / 8 instances / 8 surfaces / 6,144
triangles -> 8 / 8 / 8 / 4,096**, saving **2,048 triangles (33.3%)**.

The bounded measurements that remain valid are the freight bucket's **57,018 ->
54,970 triangles** and the complete-scene `TorusMesh` family result of **165,044
-> 162,996 triangles across the same 180 copies**. The standalone freight module
also stays at 909 descendants, 427 MeshInstance3D nodes plus one MultiMesh,
428 surfaces, 439 visible geometry copies, 207 static bodies and 210 collision
shapes; its interaction/lifecycle/authority contract is unchanged.

The current-tree scenario census above now includes Salvage Terrace and its
long-rail resource share. Any later Central or Upper performance merge must
trigger a new full production census before the main budget table is updated;
the bounded 2,048-triangle family delta above does not depend on those totals.

One matched 1920x1080 Forward+ comparison rendered the same frozen production
scene and camera first at `32x12`, then at `32x8`. Both the normal frame and its
4x nearest-neighbour silhouette crop retain a smooth circular major sweep; the
target mask has the same `(0, 0)..(1703, 675)` crop bounds in both passes. Only
the tube's specular shading changes. Production TAA/temporal lighting makes the
broader frames non-byte-stable, so this is inspected visual/silhouette evidence,
not a zero-pixel or performance claim. The renderer was Forward+ through
llvmpipe; representative hardware timing remains open.

### Bounded VIP banquette-joint batching

A submission-only pass against base `a6951659` batches the fourteen identical
lacquer joint blocks carried by the seven reception banquette segments. These
blocks were childless, visual-only and non-colliding. The seven named
`BanquetteXX` roots, their colliding `Base` children, seats, route and interaction
surfaces, materials, transforms, shadows, render layer and authored aggregate
AABB are unchanged.

The module-local renderer freeze is **482 -> 469 descendants, 278 -> 264
`MeshInstance3D` nodes, 0 -> 1 `MultiMesh` batch, 278 -> 278 drawn copies and
278 -> 265 surface submissions**. The batch stores the same fourteen transforms
in parent space as a deterministic **168-float** renderer buffer (formerly no
`MultiMesh` buffer) and publishes their exact transformed-mesh union as its
culling AABB. Focused mutation coverage changes one buffer origin and requires
the module audit to reject it before restoring the exact payload.

The production census keeps **1,805,922 triangles, 2,795 unique meshes and 677
retained materials** unchanged while renderer nodes/surface submissions move
**5,830 -> 5,817 / 5,837 -> 5,824**, and scene nodes move **9,394 -> 9,381**.
The VIP bucket itself stays at 65,504 triangles and fourteen rendered joint
copies while moving 278 -> 265 renderer submissions and 483 -> 470 nodes.

One matched 1400x900 Forward+ comparison used camera `(3.5, 1.45, 4.75)` aimed
at `(-1.6, -0.05, 8.75)`, drawing the frozen authored roster first as fourteen
ordinary meshes and then as the production batch. The two halves had zero pixel
difference. The adapter was llvmpipe, so this is only a visual-equivalence check,
not a frame-time or representative-hardware claim.

### Bounded Nearby Sector processing-spine rib batching

Against base `57e2f33`, one exact family changes: the four identical steel ribs
across the Cinder Reach processing spine. Each rib was a childless,
visual-only, non-colliding `MeshInstance3D`; none owns a route, activity,
interaction, evidence or gameplay path. The batch keeps the same cached
`13.0 x 9.5 x 1.6 m` bevel mesh, shared steel material, shadow setting and four
local transforms at `z = -24, -14, 0, 12 m`.

The family-local freeze is **4 -> 0 `MeshInstance3D` nodes, 0 -> 1 `MultiMesh`
batch, 4 -> 4 visible copies, 4 -> 1 surface submissions and 432 -> 432
triangles**. The bounded `NearbySectorCluster` result is **168 -> 164 mesh
nodes, 1 -> 2 MultiMesh nodes and 169 -> 166 renderer nodes/submissions**;
visible copies remain **688**, triangles remain **117,457**, and collision
remains **38 bodies / 38 shapes**. The component's MultiMesh budget is therefore
re-frozen **1 -> 2**: one existing debris shell plus this intentional
submission-only rib batch.

These are component-local values only. They do not re-freeze any absolute
whole-scene triangle, node, surface, unique-resource or retained-material
number; those remain deferred until the final merged-tree census.

One matched 1280x720 Forward+ comparison used a platform-local camera at
`(47, 25, 54)` aimed at `(0, 0, -7)`, first with the four ordinary ribs and then
with the final raw-buffer batch. Direct inspection and the difference image
showed no changed pixels on any rib; the only visible comparison differences
were on unrelated slowly tumbling boulders. The adapter was llvmpipe, so this is
a transform/culling/composition check, not representative frame-time evidence.

### Bounded Space Backdrop celestial-body mesh sharing

Against base `903e478`, the four named coloured celestial bodies keep their
individual `MeshInstance3D` paths, positions, effective radii, palette roles and
distinct materials, but share one immutable 24x12 unit-sphere mesh. Each node's
uniform scale carries its existing 105/120/135/165 m radius. This is the same
topology and world-space geometry the four radius-specific sphere resources
produced; the star shell, deterministic seed/roster, sky shader and key-light
orientation are untouched.

The body family moves **4 -> 1 unique mesh resources**. The bounded whole
`SpaceBackdrop` result is **5 -> 2 unique meshes, 5 -> 5 materials, 5 -> 5
renderer nodes/surface submissions, 2,604 -> 2,604 visible copies and 127,296 ->
127,296 triangles**. The four bodies remain 2,496 of those triangles and the
already-batched star shell remains 124,800; this pass does not mistake the
single star submission's instanced triangle count for a draw-call problem.

No Forward+ comparison is required for this immutable-resource substitution:
the focused production test freezes the shared mesh identity, unchanged 24x12
topology, each exact uniform scale and effective AABB, material roster, semantic
paths and component-local counts. No vertex tessellation, shading input or
world-space bound changes. These bounded values do not re-freeze any absolute
whole-scene count; that remains deferred to the final merged-tree census.

## The lettering fix, for the record

The first thing this budget was used for. Before: 31 signs, 315,360 triangles,
**18.9% of the entire scene**, 10,172 triangles per sign — about forty times the
average cost of an authored art mesh. After: 60,829 triangles, 4.3%, 1,962 per
sign. Scene total 1,664,566 → 1,410,035, a **15.3% reduction in the whole scene
from one change to how text is built**.

Two levers, both owned by `scripts/world/sign_geometry_budget.gd`:

- `depth` 0.020-0.030 → **0.0**. Extrusion is 75% of a `TextMesh`: a duplicate
  back face plus a wall of quads around every contour segment. At these depths
  and node scales it was three to twenty millimetres of lettering that no camera
  in the game is placed to see.
- `font_size` 64 → **48**, with `pixel_size` derived so `font_size * pixel_size`
  is unchanged. `font_size` is a curve-tessellation setting, not a size setting;
  world size is preserved to within 0.4% of width and 2.9% of height, both inside
  the panel each legend sits on.

Legibility was checked by looking, not asserted: `tests/capture_sign_legibility.gd`
renders four signs — the main navigation board, the densest lettering in the
game, a berth identity legend, and sector wayfinding read from a moving craft —
at reading distance, at distance, and from behind, before and after. At 1080p the
after shots are indistinguishable from the before shots, and the extrusion's
removal actually cleans up shading noise inside the glyph strokes on the
close-range terminal. `font_size = 32` was rendered too and is also legible; 48
was kept because the extra 23,000 triangles is 1.4% of the scene and is not worth
spending the whole quality margin of the one object class whose job is to be read,
particularly above 1080p.

The current 43-sign station reached 81,381 triangles, above the unchanged
80,000 lettering ceiling. A bounded 48→47 adjustment brings that standalone
world to 79,412 triangles; all per-sign, no-blanking, width/height, zero-depth
and idempotence checks still pass. A tiny pixel-size clamp removes only font
hinting growth beyond each legend's authored 64-point width (2.8 mm for the
Cinder legend before node scale). Actual 3840×2160 same-camera Forward+ A/B
images retain visible glyph clarity at the junction and Cinder reading positions.
The Cinder frames share partial streaming transparency, so this comparison
establishes the font change only; it is not whole-scene or native-hardware
readability acceptance. The existing capture runner now sets its output size
after Main's saved display settings and checks the image's actual dimensions.

One deliberate behaviour change, photographed in the "back" shots: a flat sign has
no back face, so a sign viewed from its non-reading side now shows nothing instead
of showing **mirrored text**. Every sign in the world is mounted on an opaque
board, panel or wall, so in most cases nothing changes at all. The one place it is
visible — looking out of the Dock Operations pod through its glazing — previously
read `SNOITAREPO KCOD` and now reads as clean glass. That is the MAP-004 mirrored-
legend complaint getting quieter, not louder.

## How to check this

```
# Resident production census. Add KETH_CENSUS_JSON=path to persist schema-v2 JSON.
godot --headless --audio-driver Dummy --script res://tools/geometry_census.gd

# One real production-streamed Cinder generation.
KETH_CENSUS_SCENARIO=cinder_loaded \
KETH_CENSUS_JSON=/tmp/geometry-census-cinder-loaded.json \
godot --headless --audio-driver Dummy --script res://tools/geometry_census.gd

# Per-ring breakdown: world-space radii, authored vs budgeted tessellation.
godot --headless --audio-driver Dummy --script res://tools/torus_census.gd

# Material-census fixture: bound/retained split and dependency traversal.
godot --headless --audio-driver Dummy \
  --script res://tests/geometry_census_retained_material_test.gd

# Production resident/loaded identities, exact counts, deltas, and fingerprints.
godot --headless --audio-driver Dummy \
  --script res://tests/geometry_census_scenario_test.gd

# Lettering and ring regression gates.
tools/release/run_test_matrix.sh --scope sign_geometry_budget_test \
  --scope torus_geometry_budget_test

# Look at the signs. Needs a display; xvfb is fine, --headless is not
# (headless has no rasteriser and writes blank frames).
KETH_SIGN_CAPTURE_TAG=after xvfb-run -a -s '-screen 0 1920x1080x24' \
  godot --path . --resolution 1920x1080 --rendering-method forward_plus \
  --audio-driver Dummy --script res://tests/capture_sign_legibility.gd

# Look at the rings. Writes a matched authored/budgeted pair per shot out of one
# frozen scene, plus a 4x magnification of each silhouette.
xvfb-run -a -s '-screen 0 1920x1080x24' godot --path . --resolution 1920x1080 \
  --rendering-method forward_plus --audio-driver Dummy \
  --script res://tests/capture_torus_smoothness.gd

# Choose a floor by looking, rather than by arithmetic: photograph one ring at
# explicit tessellations.
KETH_TORUS_CAPTURE_ONLY=exterior_pipe_clamp \
KETH_TORUS_CAPTURE_SWEEP=48x16,32x12,24x12,20x10,18x9 \
xvfb-run -a -s '-screen 0 1920x1080x24' godot --path . --resolution 1920x1080 \
  --rendering-method forward_plus --audio-driver Dummy \
  --script res://tests/capture_torus_smoothness.gd
```
