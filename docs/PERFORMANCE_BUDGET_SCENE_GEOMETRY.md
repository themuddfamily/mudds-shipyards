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
| Triangles | 1,887,703 | 2,021,837 | +134,134 |
| Mesh renderer nodes | 5,557 | 5,766 | +209 |
| Surfaces | 5,980 | 6,189 | +209 |
| Unique meshes | 3,058 | 3,198 | +140 |
| Bound-phase materials | 706 | 748 | +42 |
| Retained/reachable materials | 1,009 | 1,056 | +47 |
| Unique shaders | 7 | 7 | 0 |
| Text triangles / instances | 79,591 / 43 | 100,157 / 56 | +20,566 / +13 |
| Lights / shadow lights | 341 / 20 | 368 / 20 | +27 / 0 |
| Particle systems | 54 | 54 | 0 |
| Scene-tree nodes | 10,593 | 11,016 | +423 |

Re-measured on 2026-09-15 for the Cinder damage-presentation coverage pass. The
three runtime-composed Cinder craft carried no `HeroDamagePresentation` at all;
they now attach the same shared scene the six authored craft instance. **No
triangle, renderer, surface, unique mesh or bound-phase material moves** — the
rig owns no renderer at rest — and the whole delta is three identical six-node
rigs: **+18 scene-tree nodes**, **+6 lights** (none shadow-casting), **+9
particle systems** (45 → 54, all `emitting = false` at rest) and **+27
retained/reachable materials** (the nine shared spark/smoke/flash/debris recipes
each rig allocates). Every loaded-minus-resident delta is unchanged. A further
**+3 nodes in each scenario** in the rows above is inherited, not introduced:
eea0b6e09 added the "Limit ultrawide field of view" settings row to the pause
settings page without re-measuring this census, and those three Control nodes
carry no renderer, mesh, material, light or particle. Measure this scenario on
**fresh private user data**: a saved recovery choice left in `user://` by an
earlier run legitimately adds one HUD control, which moves both node rows and
both census fingerprints by one.

Re-measured on 2026-09-15 for FREIGHT-FINISH-001, the station-wide
freight-container finish (Dock 04's seven yard containers and the Jovian freight
berth's eight tagged cargo units, `scripts/world/freight_container_kit.gd`). The
pass **adds no renderer node, no scene-tree node, no light, no unique mesh and no
particle system** — the container shells replace the boxes one for one — so only
three rows move, and this is what they cost:

- **Triangles +41,116** in each scenario, 1,918,333 → 1,959,449 resident. Dock 04
  is 7 × (3,504 − 12) = 24,444 and the freight berth is +16,672. That is the
  price of a container being a frame with corrugated skins hung on it rather than
  a slab, and it is spent entirely on the two places a player meets freight.
  Resident triangles move from 6.5% to **8.9% over the 1,800,000 ceiling**; the
  ceiling is not raised, and the headroom analysis below is unchanged — the
  remaining bulk is still imported hero art.
- **Surfaces +27**, 5,953 → 5,980. One shell mesh carries four surfaces because
  painted skin, cast steel, door leaves and printed plate are four finishes.
- **Bound +13 / retained +13 materials**, three operator liveries plus one shared
  casting and four stencil plates, replacing the five module colours the freight
  used to borrow from the rooms around it.

Textures move 34 → 38 and 83,355,976 → 85,453,128 bytes, exactly 2 MiB, which is
the four 512 × 256 marking plates `tools/generate_ship_markings.py` now emits.

#### 2026-09-15 FREIGHT-CRATE-001: the freight berth's small crates, +8,352 resident triangles

Re-measured on 2026-09-15 for FREIGHT-CRATE-001, the crate finish the container
pass recorded as its residual: the Jovian freight berth's six `RackStoredCrate*`
totes on the rack decking and the two staged pallet stacks' `StagedCrateLower` /
`StagedCrateUpper` (1.1 × 0.62 × 1.5 m, 2.2 × 1.3 × 1.9 m and 1.6 × 0.9 × 1.5 m)
were still chamfered slabs in the berth's own `ceramic_warm`, `ceramic` and
`orange`, and the orange upper crate filled the foreground of the rack-line
review view. They are now moulded stores totes from
`scripts/world/freight_crate_kit.gd`, a deliberately different object class from
the containers: four full-height corner battens (the only parts on the published
envelope, so the crate stands on four feet with a shadow line under a lifted
skirt rail), recessed panels split by a mid rail, a lid slab with a lip and a
seam line, a strap pair over the lid on the eight strapped units (the two staged
lower crates keep their existing separate `StagedStrap` nodes and take the
unstrapped lid-seam variant), one `freight-tote` stores plate on each long side,
and three moulded-polymer finishes — olive `5c6b3f`, plum `6b3b56`, stone
`7f8478` — with one shared dark trim `2c3133`. None of the three is a container
livery, the station's teal or a frozen craft tone. Every part is
`ShipChamferedStock.box_mesh` through the container kit's own emitter; there is
no new mesh family, shader, light, node or collider, and each crate's mesh AABB
is exactly the `size` that still builds its `BoxShape3D`.

The pass **adds no renderer node, scene-tree node, unique mesh, light or particle
system**: one shell per (size, strapped) is shared through the berth's crate
cache and the finishes are per-instance surface overrides. Measured twice on an
empty `XDG_DATA_HOME` from the suite's own `GEOMETRY_CENSUS_*` lines, identical
in both scenarios:

- **Triangles +8,352**, 1,887,703 → 1,896,055 resident and 2,021,837 →
  2,030,189 loaded, measured on top of the ninth trim. Eight strapped totes at
  948 and two lidded at 684, less the ten 60-triangle slabs they replace.
  Resident triangles move from 4.9% to **5.3% over the 1,800,000 ceiling**; the
  ceiling is not raised.
- **Surfaces +20**, 5,980 → 6,000 resident and 6,189 → 6,209 loaded: three
  finishes per crate (shell, trim, plate) instead of one.
- **Bound +5 / retained +5 materials**, 706 → 711 and 1,009 → 1,014 resident
  (748 → 753 and 1,056 → 1,061 loaded): three tote shells, one shared trim and
  one shared stores plate.
- **Textures +1**, 38 → 39 and 85,453,128 → 85,977,416 bytes — exactly 524,288,
  the one 512 × 256 `freight-tote` plate the marking generator now emits.

Mesh instances (5,557 / 5,766), unique meshes (3,058 / 3,198), lights (341 / 368),
nodes (10,593 / 11,016), shaders (7) and particle systems (54) are unchanged, and
every loaded-minus-resident delta is untouched. The berth's own standalone census
(`jovian_freight_berth_batch_test`) moves the same way: 429 → 449 submissions and
93,692 → 102,044 drawn triangles through the same 893 descendants, 389 mesh
instances, 16 batches, 477 visible copies and 206 / 209 collision.

The three production audits, run headlessly on private user data before (a
pristine copy of `82f4e42b5`, the main this pass is rebased on) and after:

| Audit | before | after |
| --- | --- | --- |
| `tools/coplanar_seam_audit.gd` | 1,334 pairs reported, 1,338 back-to-back, 294 buried, 28 declared; `ShipyardWorld/JovianFreightBerth` 125 pairs / 59.167 m² | identical on every line but the timing: **same 1,334 / 1,338 / 294 / 28, same 125 / 59.167**, zero pairs naming a crate node on either side |
| `tools/station_walkability_sweep.gd` | 82 surfaces, 135,137 cells, 39,939 blocked, 19 findings; three `jovian_freight_berth` lane rows | the whole log is byte-identical, lane rows included |
| `tools/camera_intrusion_audit.gd` | 24 `near_plane_in_world_mesh`, 1 `camera_sphere_in_world_collision`, 6 `camera_sphere_in_own_hull`; `jovian_provisional` 6 findings, `cinder_cargo_hauler` 3 | 25 `near_plane_in_world_mesh`, 0 `camera_sphere_in_world_collision`, 6 `camera_sphere_in_own_hull`; `jovian_provisional` 5, `cinder_cargo_hauler` 3, every other `CAMERA_INTRUSION_CRAFT` line byte-identical; the 25th group is the documented one — `arrow_provisional` against `TargetDrone01/DroneVisual/DressingRenderBatch01` at `[-14.24, 7.95, -95.1]`, one sample, 95 m down the outbound range lane — and no finding names a crate |

That camera row was taken twice on each side, because one run per side is
not enough for this probe. The baseline's first run reported a
`camera_sphere_in_world_collision` group — `jovian_provisional`, chase rig,
outbound route, one 16:9 sample against an anonymous `StaticBody3D` at
`[14.34, 0.2, -66.3]`, ninety metres from the freight berth — and its second
run did not, reading 24 / 6 with `jovian_provisional` at 5 like the after tree;
so that group is the baseline's own run-to-run noise, not a difference between
the trees. Both after runs reported the 25th `near_plane_in_world_mesh` group,
and both times it was the same single-sample drone graze the container pass
recorded appearing in three of four runs on an unchanged tree. Everything a
crate could touch — the two craft that park among this freight, the retracted
boom counts, the shortest approach — is identical in all four runs.

The audits cannot see inside one mesh, so the kit's own coplanar discipline is
stated in `freight_crate_kit.gd` and was checked by eye in the close views: the
envelope (battens), 6 mm (straps, plate), 12 mm (rails, lid) and ≥ 25 mm (shell)
planes are all more than the audit's 3 mm tolerance apart, and nothing
flickers in either renderer.

Rendered before/after pairs — the same seven container-review views as
FREIGHT-FINISH-001 (the Dock 04 walker, yard and chase, the freight berth's
apron, one unit and the rack line, and the Cinder cargo terminal) plus two new
close views of the port staged pallet and rack bay 01's shelf — are in
`/root/.cache/mudds-shipyards/agent-crates/captures/{before,after}-{forward,compat}/`,
Forward+ on llvmpipe and Compatibility on D3D12 (RTX 5070 Ti), the same camera
transforms on both sides and no blank or uniform frame in any of the thirty-six.
The "before" side was rendered from a pristine copy of the baseline commit.

**Verdict.** The residual the container pass recorded is closed. In the rack-line
view the object that fills the foreground is no longer an orange slab but the
plum upper tote: two dark straps over its lid, four corner battens, a recessed
side panel and the lid seam above it, all readable at that range on both
renderers. In the staged-pallet close view the olive lower tote and the plum
upper tote read as two moulded totes on a pallet — battens, mid rail, recessed
panels, the lid lip, the strap pair, and a legible "SHIPYARD STORES / STK 0412"
plate — where before there were a ceramic block and an orange block. In the
rack-shelf close view the plum tote visibly stands on its four batten feet with
a shadow line under the lifted skirt, the olive tote behind it, and the plates
face the lane. The Dock 04 views, the freight unit view and the Cinder terminal
are unchanged, as they should be: this pass touched nothing but the ten crates.

Honest residuals: the three finishes are deliberately muted moulded-polymer
colours, and in the wide rack-line view the plum tote reads dark against the
navy container behind it; a lighter fourth finish would separate them further
but was not needed to make the object read. The stores plate is one shared
texture for all three finishes by design, so every tote carries the same stock
code; per-crate codes would cost one plate per crate and were not warranted at
this size. Outside the freight berth, `grep Crate scripts/world/` finds two
other placements. The habitat's `BerthStowedCrate` (0.27 m stowage under a bunk,
`habitat_spine.gd`) is domestic stowage rather than freight and is left alone.
The station-operations cargo lines' thirteen `Crate*` boxes
(`station_operations_activity_presentation_builder.gd`, 0.7–1.5 m palletised
crates in `crate` / `crate_alt`) are the same object class and were **not on
this recipe yet** when this pass was written: that builder is a separate
presentation family with its own frozen material rosters and three placements,
and taking it onto `FreightCrateKit` was a bounded follow-up (thirteen `_box`
calls, one helper, one more triplanar and census refreeze) that this pass did
not claim. **That follow-up is closed — see the 2026-09-20 section below.**

#### 2026-09-20 FREIGHT-CRATE-001 (station operations): the cargo lines' thirteen crates, +11,220 resident triangles

Re-measured on 2026-09-20 for the residual the freight-berth crate pass recorded
five days earlier and explicitly did not claim: the thirteen palletised `Crate*`
boxes in `scripts/world/station_operations_activity_presentation_builder.gd`
(0.7–1.5 m, `CrateLower/LowerAlt/Upper/Outbound/OutboundSmall` on the short
transfer line, `CrateInbound*/CrateOutbound*` on each 21.6 m line, and
`SupplyCrate`/`SupplyCrateTop` on the crew work post). They were the same object
class as the berth's ten totes and were still chamfered slabs in the builder's
own `crate` teal and `crate_alt` orange — the same two colours the module's sled
container wears, so the cargo a player walks up to was painted the colour of the
machine beside it.

They are now the same stores totes, from the same
`scripts/world/freight_crate_kit.gd`: four full-height corner battens, recessed
panels split by a mid rail and closed by a skirt rail lifted off the deck so the
crate stands on four feet with a shadow line under it, a lid slab dropped below
the batten tops with a lip and a seam, a strap pair where the crate is strapped,
the `freight-tote` stores plate on both long sides, and the kit's three
moulded-polymer finishes — olive `5c6b3f`, plum `6b3b56`, stone `7f8478` — over
one shared dark trim `2c3133`, varied so no two adjacent crates match. A crate
carrying another crate takes the unstrapped lid-seam variant, because a strap
band over its lid would be under the load; every other crate is strapped. That
rule makes eight strapped and eleven lidded totes across the ten-placement
production roster (one short line, two long lines, one crew work post = nineteen
crates).

`crate` and `crate_alt` stay in the catalog and are now what they always
described: the powered sled's container body and its two formed ribs, which
really are a small container rather than a tote.

The pass **adds no renderer node, scene-tree node, unique mesh, light, collider,
shader or particle system, and changes no authored size, position, solid volume,
clearance sweep, handling fixture, node name or lifecycle**. Each tote's mesh
AABB is exactly the `size` the slab published, one shell is retained per
(`size`, `strapped`) recipe — so the three equally-sized unstrapped totes on a
long line share one `ArrayMesh` exactly as the three equally-sized slabs did —
and the activity's process-wide fingerprint cache then shares each shell across
placements. Measured from the suite's own `GEOMETRY_CENSUS_*` lines, identical
in both scenarios:

- **Triangles +11,220**, 1,896,055 → 1,907,275 resident and 2,030,189 →
  2,041,409 loaded. That is +15,108 of tote (eight strapped at 948, eleven
  lidded at 684), less the 2,052 the nineteen 108-triangle slabs cost, less a
  further 1,836 because seventeen of those slabs were also merged copies inside
  the two cargo lines' `OpaqueEnvelopeShadowBatch` and are no longer.
  Resident triangles move from 5.3% to **6.0% over the 1,800,000 ceiling**; the
  ceiling is not raised.
- **Surfaces +38**, 6,000 → 6,038 resident and 6,209 → 6,247 loaded: three
  finishes per crate (shell, trim, plate) instead of one.
- **Bound +5 / retained +5 materials**, 711 → 716 and 1,014 → 1,019 resident
  (753 → 758 and 1,061 → 1,066 loaded): three tote shells, one shared trim and
  one shared stores plate, added to the activity's shared catalog.
- **Textures do not move** (39 / 85,977,416 bytes). The `freight-tote` plate the
  berth pass generated is reused as it stands, so `ASSETS.md` needs no new
  entry — its `freight-tote` paragraph already reads "every small crate and tote
  built by `scripts/world/freight_crate_kit.gd`", which is now true at both
  sites.

Mesh instances (5,557 / 5,766), unique meshes (3,058 / 3,198), lights
(341 / 368), nodes (10,593 / 11,016), shaders (7) and particle systems (54) are
unchanged, and every loaded-minus-resident delta is untouched.
`station_triplanar_material_test` moves 1937 → 1956 mapped station surfaces with
the 0.30 m column 1249 → 1268 (shell and trim where there was one slab; the
0.22 m and 0.28 m columns do not move, and the printed plate stays outside the
family for the reason the container data plate does).

Two contracts in `station_operations_activity.gd` follow the finish rather than
the geometry, and both are stated here because they are real:

- The shared material catalog is **17 → 22 entries**, on every profile row and
  on the production roster row, because the set is built whole regardless of
  profile. Node (500), MeshInstance (359), batch (24), batched-copy (107),
  submission (383) and drawn-copy (461) rows do not move.
- A renderer's finish binding may now be one owned material per surface instead
  of one `material_override`. The build contract captures the surface bindings
  and re-checks them exactly as strictly, and `bound_material_references` counts
  a surface-bound renderer, so the roster still reports **383** bound renderers
  and 57 dynamic lens bindings.

**The shadow cost is not free and is not hidden.** `StaticShadowBatch` merges
single-surface sources only, and a tote is three surfaces, so the seventeen
totes on the three cargo lines left those rosters: the short line's batch is
now 12 sources / 1,284 triangles and each long line's 15 sources / 1,608. Those
seventeen crates now cast through their own renderers, as the berth's ten totes
already do. In the shadow pass that is seventeen extra draws and 13,476
triangles of real silhouette where 1,836 triangles of merged slab used to be.
(The two crew-workpost totes were never batched and are unaffected.) It buys the
silhouette actually matching the object — battens, skirt gap and strap pair
included — and it is what keeps the two sites on one recipe.

The three production audits, run headlessly on private `XDG_DATA_HOME` before
and after, on the same source tree either side:

| Audit | before | after |
| --- | --- | --- |
| `tools/coplanar_seam_audit.gd` | 1,334 pairs reported, 1,338 back-to-back, 294 buried, 28 declared; 5,142 placements / 168,905 faces | **the entire ranked report is identical, pair for pair, 1,334 reported**; faces 168,905 → 170,173 (the tote faces) and the excluded counters move 1,338 → 1,320 back-to-back and 294 → 293 buried, because a tote stands on four battens instead of lying flat on the pallet deck. No reported pair names a crate on either side. |
| `tools/station_walkability_sweep.gd` | `surfaces=82 cells=135137 blocked=39939 findings=19` | **the whole log is byte-identical**, line for line, including every `OperationalLattice/Activities/*CargoLine` and `AftCrewWorkPost` row |
| `tools/camera_intrusion_audit.gd` | `near_plane_in_world_mesh=24`, `camera_sphere_in_own_hull=6`; per-craft findings 1/4/3/3/3/4/5/3/4 | the same class totals and the same per-craft finding counts; every difference is inside the documented range-drone group (`ExteriorTargetRange/TargetDrone*` depths and which drone part a graze lands on) plus two retracted-sample counts moving by one. No finding names a crate, and nothing at the station's operations decks moved. |

Rendered before/after pairs are in
`/root/.cache/mudds-shipyards/agent-ops-crates/captures/{before,after}-{forward-plus,compatibility}/`
at 1280 × 720, from a harness modelled on `.godot/arrow_access_root.gd` that
boots the production boot scene, starts the game through the HUD, hides every
`CanvasLayer` and derives each camera pose from the live crate nodes, so both
sides are framed identically. Forward+ carries seven views (a walker view at
each of the four crate groups, the short line's outbound pair, a mid-range view
down the short line, and one arm's-length view of a stores plate);
Compatibility, which renders this scene at minutes per frame on software GL,
carries the five that matter — the three cargo-line walker views, the supply
post and the mid-range view. Twenty-four frames, none blank or uniform (772 to
1,482 distinct colours on a 64 × 36 grid; the harness fails below 12, and the
low end is the arm's-length plate view, which is mostly one crate face). The
"before" side was rendered from the baseline commit checked out in the same
worktree. Both renderers were software (llvmpipe / lavapipe): this establishes
composition, not native GPU rendering or performance.

**Verdict.** The residual is closed and the family reads as one across the
station. In the short line's walker view three rounded teal-and-orange slabs
have become an olive and a plum tote side by side under a stone one, each on
four black battens with a mid rail, a skirt rail lifted off the pallet deck and
a lid lip above. In both long-line views the stack reads the same way and no two
adjacent totes share a finish. At the crew work post the olive lower tote and
the strapped plum top tote both carry a legible "SHIPYARD STORES / STK 0412 /
RETURNABLE TOTE" plate, and the strap pair over the top tote's lid is plain at
walking distance. In the mid-range view the totes and the sled's teal container
now read as two different object classes at a glance, which is the whole point:
before, the crates and the container were the same two colours. Compatibility
shows the same objects with its usual flatter ambient; nothing flickers on
either renderer.

Honest residuals. The stores plate sits on the crate's two **X** faces, so on
the short and long lines — where a player stands off the crate's Z face — the
plate is edge-on and the white rectangle in those frames is the line's own
`CrateManifest` board, not the tote plate; the plate is visible along the line
and at the work post. Putting a plate on all four faces would cost two more
quads per crate and was not taken. At arm's length the recessed shell core's
chamfer reads as a slightly pillowed panel rather than a flat moulded one; that
is the shared kit's own stock and is identical on the berth's ten totes, so it
is a kit-level observation rather than something this pass introduced. Every
tote carries the same stock code, by the same design decision the berth pass
recorded. No human has reviewed these frames.

Measured on `main` on 2026-09-15 with the service-line/registry batches (−49) and
the ship fitout batches (−96, then +2 for the protected Zenith wing shells) and the chase-lane station collision (+28 nodes) merged on top of the Habitat/Aft batches; the
renderer, surface and unique-mesh rows are read from the same
`geometry_census_scenario_test` log. Resident nodes are 50% over the 7,000
ceiling; what remains is indexing and resource contracts (shared-stock resource
audits on the ships, identity proofs in the OperationalLattice), not anonymous
dressing.

Measured on `main` on 2026-09-14 (evening) with the station round-stock trim, the
fleet fitout budget, the hero/opponent fitting budget, the defender heat vents,
the walkability dressing, the solid Aft gate ribs (+12 collision nodes), the
seam standoffs (transforms only) and the station dressing batcher (−190 nodes,
−154 renderers) merged together. Resident triangles are 6.5% over the 1,800,000
ceiling and nodes 64% over the 7,000 ceiling; the remaining triangle headroom is
imported hero art (Torrent 100,098, Zenith 52,686) and the remaining node volume
is HabitatSpine, AftJunctionStack, the ship fitouts and the count-audited
OperationalLattice, none of which this pass touched.

The first three 2026-09-14 trims below were each measured on their own branch
from the same 2,407,157-triangle base (the first station trim). Merged on `main`
together with the defender heat vents (+448 triangles, +1
renderer/mesh/material/node) and the walkability dressing (+32 nodes, no
triangles), the combined resident scene measured **1,951,735 triangles** — the
**1,951,853** this table and `geometry_census_scenario_test.gd` previously
carried was 118 high, because content landed after that refreeze and the freeze
was not re-taken. The fourth trim (the hero/opponent pass, first below) takes
the measured scene to **1,917,359 triangles** — 1,018,358 fewer than the
2,935,717 the morning census found, and now 6.5% over the 1,800,000 ceiling
instead of 63%. **The ceiling is still not met**, and the reason the remaining
117,359 triangles are not reachable through this rule is set out in that
section. The node count (11,645) remains 66% over its 7,000 ceiling.

#### 2026-09-14 hero/opponent trim: -34,376 resident triangles, and the ceiling is still not met

The three passes recorded below left the station-resident scene at 1,951,735
triangles against the 1,800,000 ceiling. This pass takes the five craft those
passes did not touch — the Arrow, the Zenith, the Bulwark and the four opponent archetypes
— to **1,917,359**, and raises no ceiling, relaxes no assertion and invents no
second tolerance.

**It does not reach the ceiling, and it cannot.** 1,917,359 is 117,359 triangles
— 6.5% — over. The arithmetic is set out under "why the remaining 117,359 is not
here" below, because a pass that misses its number by that much owes the reader
the reason rather than the number alone.

| Bucket | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `ArrowReconShip` | 121,746 | 103,002 | -18,744 |
| `BulwarkHeavyGunship` | 66,134 | 58,726 | -7,408 |
| `ZenithInterceptor` | 86,690 | 83,490 | -3,200 |
| `ShipyardWorld/StationDefenseEncounter` (its three opponent craft) | 72,550 | 70,342 | -2,208 |
| `WingSkirmisherLead` | 19,808 | 19,232 | -576 |
| `WingSkirmisherWing` | 19,808 | 19,232 | -576 |
| `StandoffPicket` | 19,796 | 19,220 | -576 |
| `CourierRunner` | 21,126 | 20,582 | -544 |
| `RangeOpponent` | 17,846 | 17,302 | -544 |
| **Whole scene** | **1,951,735** | **1,917,359** | **-34,376** |

No other bucket moves, and the change is triangle-only on every other census
row: 6,589 mesh renderer nodes, 6,687 surfaces, 3,356 unique meshes, 693 bound
and 969 retained materials, 7 shaders, 34 textures, 335 lights (20 shadow
casting), 45 particle systems, 79,591 text triangles across 43 signs and 11,645
scene-tree nodes are identical on both sides, as is the loaded-minus-resident
Cinder delta of +134,134. No collision shape, interaction marker, boarding
route, seat anchor, light, material or evidence label changed, and nothing added
per-frame work.

**Note on the previous freeze.** `geometry_census_scenario_test.gd` and the
measurement table above both carried **1,951,853**, and the scene on `main` at
17a536702 actually measured **1,951,735** — the suite was failing its resident
and loaded totals and both fingerprints before this pass began, because content
landed after the last refreeze. Every before-figure in this section is what the
scene was, not what the freeze said it was; the table above is corrected to
match.

**The same rule as the ship trim, applied where it had not reached.** The five
craft used `ShipGeometryBudget` and `ShipChamferedStock` nowhere, so every
turned part, bead and box on them carried one authored tessellation whatever its
size. They now carry local overrides of the same three builders the Jovian, the
Halyard and the three Cinder craft already override, and `HeroShip`'s own shared
builders are untouched, so the Torrent — which is a bare `HeroShip` — is
deliberately unchanged.

- The Arrow's `_cylinder` was frozen at 36 radial segments for stock from a 2 cm
  toggle to a 20 cm mast pedestal; `ShipGeometryBudget.tube_segments` takes its
  38 turned surfaces from 10,944 triangles to 5,696. Its `_sphere` was 28 x 14
  from a 3.5 cm curve joint to the 42 cm ventral gimbal; `sphere_plan` leaves the
  gimbal and its lens exactly as authored and takes the centimetre beads to
  20 x 10 and 16 x 8.
- The Zenith and the Bulwark pick up `_rounded_box_mesh`, `_cylinder` and
  `_frustum`, which is the Bulwark's 31 chamfered cylinders and the 53 fitted
  boxes across both craft.
- The four opponent archetypes budget through `RangeOpponent`, which all four
  inherit: its 28-segment chamfered cylinders, its 24 x 12 beads, and its exhaust
  plumes, which were 32 radial segments with Godot's four default wall rings on a
  30 cm cone. The rings go to `ShipSurfaceDetail.CYLINDER_WALL_RINGS`; a frustum
  wall is planar along its length and carries constant vertex normals there, so
  the intermediate rings resolve nothing and the surface is bit-identical without
  them.

**Two rules were measured and deliberately not applied**, because applying them
would have been a no-op dressed up as a change. The opponents' pressure shells
roll each shoulder as a quarter ellipse at eight segments;
`ShipGeometryBudget.arc_segments` answers eight for every shell on all four
craft, because a quarter turn gets a quarter of the 32-segment floor the project
rendered and accepted for a closed circle and that floor binds at every shoulder
radius here. The same floor is why no lofted hull on any of these craft loses a
ring: `revolved_segments` and `tube_segments` both return 32 for anything at or
above about 30 cm in radius, and these are hero airframes.

**The Arrow's shadow twin stopped being an exact copy — for twelve of its
twenty-eight sources.** `StaticShadowBatch` merged the colour triangles of the
Arrow's whole rigid envelope, so 22,908 triangles of skin were paid for twice:
once to be shaded and once to be a silhouette. The batch now merges a proven
stand-in for the twelve cambered planform panels — the six sensor wing skins,
two wing insets, two recognition marks and two sensor wings — whose authored
8 x 12 grid exists to carry a camber crown across a *lit* surface. Held to
`StationSurfaceKit.SHADOW_MAP_TEXEL_METRES` with the same parabolic residual
model `span_steps` uses, those grids coarsen to grids that still divide the
authored one, so every stand-in vertex is a vertex of the shipped skin and every
outline corner survives. The batch goes from 22,908 to 17,772 triangles.

**The other sixteen sources are merged exactly, and that is a measured result
this pass got wrong first.** The twelve lofted skins were given stand-ins too,
at 16 rings, by asking `StationSurfaceKit.shadow_radial_segments_for` for the
count. That helper caps at `MAXIMUM_SHADOW_RADIAL_SEGMENTS` and returns the cap
whether or not the cap satisfies its own sagitta test — correct for the
station's sub-metre pipe and collar stock, wrong for the Arrow's 1.05 m
fuselage, where 16 rings leave 20 mm of silhouette error against a 6 mm texel.
The rendered cockpit-sill walk-up below caught it immediately: the caster sat
that far inside its own colour surface and laid dithered self-shadow acne right
across the sill band at walking range. Solving the ring count against the texel
directly puts every lofted skin back at its authored 32, at which point the
"reduced" loft is *larger* than the panel-cut surface it would replace. So the
loft stand-in was removed rather than kept as machinery that never fires. The
Arrow's lofted skins are already at the tessellation their own shadow needs.

**One defect fixed on the way.** `ShipChamferedStock`'s `FACE_GRID` atlas gives a
chamfer band's and a corner facet's vertices coordinates from two or three
different face charts. On stock that is square in two axes both charts normalise
by the same extent, every vertex of the seam lands on the same atlas column, the
UV triangle collapses to zero area and `generate_tangents` hands the shader a
singular tangent frame. The Zenith's 45 x 200 x 45 mm instrument stanchions are
the first parts in the fleet to hit it. Collapsed triangles now fall back to the
unit triangle, which is what `UNIT_PER_QUAD` would have given them; every
polygon whose atlas mapping is a real triangle keeps exactly the coordinates it
had, and the Jovian, Halyard and Cinder suites are unchanged.

##### Rendered evidence

At 1280x720 through `gl_compatibility` on a D3D12 GPU under Xvfb, from eight
fixed gameplay viewpoints with the production root disabled and the station
activity and service-agent clocks seeked to zero, so both sides frame the
identical scene: the Arrow at its berth at chase standoff, a cockpit-sill
walk-up, its port wing skins, the Zenith and the Bulwark at their fleet-dock
berths, a Bulwark gunner-station walk-up, one long station view with the fleet's
cast shadows, and the deck pool the Arrow's envelope casts. Captures, 16x
difference images and crops are under
`/root/.cache/mudds-shipyards/hero-trim-root/`.

- Two runs of the *same* build differ on **8.564%** of pixels before and
  **0.886%** after. Almost all of that is sub-quantisation dither and a
  whole-frame exposure wobble: the count beyond 32 of 255 is **606 px (0.008%)**
  and **1,517 px (0.021%)** respectively, and it is concentrated on the guide
  lens markers and range drones, which drift.
- Before against after differs on **3.575%** of pixels, and beyond 32 of 255 on
  **638 px, 0.009%** — at the same-build floor, not above it. Per view the >32
  count runs from 1 px (the cast-shadow pool) to 314 px (the Arrow at chase, a
  view whose own same-build floor is 972 px). The 16x difference images are
  black except for thin outlines on the fittings whose tessellation changed: the
  Bulwark walk-up's diff is a handful of grip, mount and rail edges and nothing
  else in the frame.
- **Shadow verdict, attributed rather than assumed.** Each view was rendered
  twice from the same build, once as shipped and once with the Arrow's
  `OpaqueEnvelopeShadowBatch` switched to `SHADOW_CASTING_SETTING_OFF`, and the
  pixels that differ by more than 8 of 255 are the pixels that batch owns — 6.45%
  of the wing-skin view, 4.50% of the chase view, 2.64% of the cast-shadow view,
  0.86% of the sill walk-up, 0.20% of the long view, none of either Bulwark view.
  A >0 mask is useless at this noise floor and was not used. Restricted to that
  mask, before against after moves 0.83% of the cast-shadow view's shadow pixels
  (none beyond 32), 2.66% of the wing-skin view's (none beyond 32), 3.73% of the
  sill walk-up's (42 px beyond 32, against a same-build floor of 118 px in the
  same mask) and 6.15% of the chase view's (309 px beyond 32, against a
  same-build floor of 971). No shadow detaches from its caster, no contact gap
  opens, and no acne appears.
- Direct inspection. At 3x the deck pool the Arrow casts is the same shape at the
  same edge softness in the same place on both sides. At 4x on the nearest turned
  stock a player can stand beside — the cockpit's console toggles and control
  stick shaft, budgeted from 36 radial segments down to 12 and 16 — the pair is
  indistinguishable apart from a roughly one-pixel shift in one toggle's
  highlight band; no silhouette reads as polygonal on either side. The sill
  shadow band that the first attempt covered in acne is, after the fix, identical
  before and after at 2x.

##### Why the remaining 117,359 is not here

Stated plainly, because the roadmap item asked for 152,000 and this pass
delivered 34,376.

The in-scope *procedural* geometry on these craft — everything their own scripts
build, excluding imported art — totals about 317,700 triangles. Reaching
1,800,000 would have required taking 48% of it. The ship trim reached 33% on the
Jovian, and it could do that because the Jovian had genuinely gross
over-tessellation: 96-segment nozzles, 12-step roof patches, 128-segment
quarter-ellipse fillets. These five craft do not. They were authored at 28, 32
and 36 segments, which is already at or within one step of the floors this
project established by *looking at renders* — `MIN_REVOLVED_SEGMENTS = 32`,
`MIN_TUBE_SEGMENTS = 12`, `MIN_SPHERE_RADIAL_SEGMENTS = 16`. The only way to
take another 117,359 triangles out of them through this rule would be to lower a
floor that has photographs behind it, and this pass is not willing to do that.

The remaining headroom is in **imported art**, which this pass did not touch:
the Torrent's Blender hero art (100,098 triangles, of which four LOD0 static
batches are 61,216), the Zenith's authored art (52,686) and the pilot suit
(14,576). `tools/blender/` does have deterministic regeneration paths for all
three — `generate_torrent_hero_v1.py`, `generate_zenith_authored_v1.py`,
`generate_pilot_motion_v2.py` — so the option is real; it was declined here
because closing a 117,359 gap out of a 167,360 imported pool means decimating
hero craft by roughly 70%, which is a silhouette change on the fleet's most
prominent models and not something "no visible change at gameplay distance" can
cover. The honest next step for Phase 10 item 2 is an art pass on those three
generators with its own rendered review, not a further squeeze on procedural
tessellation.

The Torrent's *procedural* fittings (58,080 triangles) are also untouched, and
for a structural reason worth recording: the Torrent has no craft script. It
instances `scripts/ships/hero_ship.gd` directly, so the only way to budget its
fittings is to change the shared builders every craft inherits — which is
exactly what the local-override pattern exists to avoid.

This is a scene-content measurement plus a rendered-composition check. It is not
a frame-time, GPU-time or VRAM claim, and the software/remote-display caveats at
the top of this document still apply. **No ceiling in this document has been
raised, and the 1,800,000 triangle ceiling is not met.**

The three 2026-09-14 trims below were each measured on their own branch from the
same 2,407,157-triangle base (the first station trim). Merged on `main` together
with the defender heat vents (+448 triangles, +1 renderer/mesh/material/node)
and the walkability dressing (+32 nodes, no triangles), the combined resident
scene measures **1,951,735 triangles** — 983,982 fewer than the 2,935,717 the
morning census found, and now 8.4% over the 1,800,000 ceiling instead of 63%.
The node count is **11,455** after the dressing-consolidation pass recorded
below, and remains 64% over its 7,000 ceiling. The second node trim recorded
immediately below takes the live resident count from **11,467 to 10,627** —
still 52% over the 7,000 ceiling, and still not met. The 2026-09-15 ship trim
recorded further below takes it from **10,647 to 10,551**, 51% over, still not
met.

#### 2026-09-14 node trim: -190 resident scene-tree nodes, zero triangles

`StationDressingBatch` (`scripts/world/station_dressing_batch.gd`) is the colour
-pass twin of the existing `StaticShadowBatch`. At the end of the world build it
merges sibling dressing that carries no authority into one multi-surface
`MeshInstance3D` per locality, and collapses sibling `_box(collidable = true)`
triples into a single `StaticBody3D` that still owns **one `CollisionShape3D`
per original piece**. Batches carry one surface per distinct source material, so
the same panel maps are bound to the same triangles at the same world transforms
through `set_surface_override_material()` instead of through a separate node's
`material_override`.

| Bucket | Nodes before | Nodes after | Renderers before | Renderers after | Triangles |
| --- | ---: | ---: | ---: | ---: | ---: |
| `JovianFreightBerth` | 894 | 825 | 413 | 353 | 64,852 unchanged |
| `ExposedDockLattice` | 299 | 247 | 119 | 88 | 21,475 unchanged |
| `LandingPad` | 180 | 146 | 116 | 82 | 42,116 unchanged |
| `UpperOperations` | 140 | 127 | 67 | 59 | 20,562 unchanged |
| `ExteriorTargetRange` | 128 | 116 | 69 | 57 | 27,707 unchanged |
| `CargoAndMachinery` | 62 | 52 | 30 | 21 | 4,068 unchanged |
| **Resident total** | **11,645** | **11,455** | **6,589** | **6,435** | **1,951,735 unchanged** |

Triangles, lights (335, of which 20 cast shadows), particle systems (45),
bound-phase (693) and retained (969) materials, shaders (7), textures
(34 / 83,355,976 bytes), text triangles/instances and the whole
loaded-minus-resident Cinder delta are identical on both sides. Surfaces fall
6,687 -> 6,570 because pieces that shared a material with a sibling now share
one submission; that is a draw-call reduction, not lost geometry.

`tools/station_walkability_sweep.gd` is unchanged end to end — 82 surfaces,
135,137 cells, 39,620 blocked, 37 findings, `invisible_blocker`/`choke`/`gap`
all zero, and the same per-module split — because no collision shape moved.

Four walking-distance framings were captured against the untrimmed build under
Xvfb at 1280x720. On **Forward+**, which the desktop build ships, the
before/after difference is inside the renderer's own same-build noise floor
(mean |delta| 0.44-1.04 of 255 against a 0.56-1.77 floor). On the
**Compatibility** fallback the difference is larger than its much quieter floor
(mean |delta| up to 0.34 against 0.06) and is confined to per-object light-list
reassignment: that renderer caps how many lights reach one instance, so a merged
bound can pick up or drop a practical. Batches are therefore capped at 16 m on
every axis, the value that measured the least deviation of the 8/16/32 m caps
tried, and no geometry, silhouette, material or placement differs in any framing.

What was deliberately left alone, and why:

* `OperationalLattice`, `CentralBerthServiceLine`, `ModernFleetRegistry` and
  `IndustrialInfrastructure` each publish a frozen per-component count or
  one-mesh-per-collider audit keyed to their own node roster. Batching inside
  them changes that indexing contract, and no audit was relaxed to buy nodes.
* Any node carrying metadata, a script, a group, a node-driven signal, a child,
  or a name that `scripts/`, `tests/`, `tools/`, `docs/`, `scenes/` or `assets/`
  resolves. That covers every walkable surface, evidence label, route marker,
  berth anchor and interaction body.
* Any node a live script variable still holds — the scan that protects the Jovian
  berth's handling-fixture, cargo-unit and service-detail rosters, which is why
  that module keeps 825 of its 894 nodes.
* `AftJunctionStack`, `HabitatSpine`, `VipReceptionSuite`,
  `ObservationLogisticsSpur`, `SalvageTerrace`, `FabricationAnnex`, the parked
  craft and their fitouts: geometry owned elsewhere.

#### 2026-09-14 second node trim: -840 resident scene-tree nodes, zero triangles

The six modules the first pass could not touch were owned by other agents at the
time. `HabitatSpine` and `AftJunctionStack` — the station's two largest node
buckets — now run through the same `StationDressingBatch`, and the other four
were each evaluated and are recorded below with the reason they were left as
they are. Measured on `608772c15` with fresh private user data on both sides.

| Bucket | Nodes before | Nodes after | Renderers before | Renderers after | Surfaces before | Surfaces after | Triangles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `HabitatSpine` | 1,923 | 1,453 | 1,251 | 848 | 1,251 | 975 | 209,990 unchanged |
| `AftJunctionStack` | 1,190 | 818 | 754 | 396 | 754 | 491 | 161,168 unchanged |
| `JovianFreightBerth` | 825 | 826 | 353 | 354 | 361 | 362 | 64,852 unchanged |
| `LandingPad` | 146 | 147 | 82 | 83 | 105 | 106 | 42,116 unchanged |
| **Resident total** | **11,467** | **10,627** | **6,435** | **5,676** | **6,570** | **6,033** | **1,917,477 unchanged** |

No other bucket moves at all. The two **+1** rows are not a regression: the
protected-name roster is one global list, so four names this pass added for the
habitat and the Aft room also stand in those two modules and cost one fold each.

Triangles (1,917,477 resident / 2,051,611 with Cinder loaded), lights (335, of
which 20 cast shadows), particle systems (45), bound-phase (693) and retained
(969) materials, shaders (7), textures (34 / 83,355,976 bytes), text
triangles/instances, every collision shape's world extent and the whole
loaded-minus-resident Cinder delta (+134,134 triangles, +209 renderers, +140
unique meshes, +47 retained materials, +27 lights, +423 nodes) are identical on
both sides. Unique meshes fall 3,355 -> 3,167 because a merged renderer replaces
several cached box meshes with one, and surfaces fall 6,570 -> 6,033 because
pieces that shared a material with a sibling now share one submission — a
draw-call reduction, not lost geometry.

**The two modules still publish exactly what they build.** Each publishes a
frozen whole-module allocation census — descendant nodes, renderer nodes, drawn
copies, surface submissions and unique mesh and material resources — and gates
`validate()` on it. Rather than restate a roster the *world*, not the module,
changed, every batch now records the exact census row it replaced
(`StationDressingBatch.AUTHORED_CENSUS_META`) and both module audits add those
rows back. `HabitatSpine.get_render_allocation_report()` still reports 1,882
descendants on the live batched station, and
`AftJunctionStack.get_pod_corner_collar_visual_allocation_audit()` still reports
its frozen census; `ShipyardWorld.get_dressing_consolidation_report()` remains
the one place the world's own arithmetic is published. Reconstruction is
asserted end to end in `tests/station_dressing_batch_test.gd`.

`tools/station_walkability_sweep.gd` is **byte-identical end to end** — 82
surfaces, 135,137 cells, 39,689 blocked, 31 findings, the same per-module split,
`invisible_blocker`/`choke`/`gap` all zero, and the same 31 blamed paths — because
no collision shape moved. `tools/coplanar_seam_audit.gd` falls 1,412 -> 1,344
pairs and 414 -> 388 families, entirely inside `HabitatSpine` (301 -> 242) and
`AftJunctionStack` (248 -> 239); every other module's pair count, the 28
`coplanar_by_design` declarations and the five worst-scoring families are
unchanged, and the 30 new families are the same seams re-blamed on the batch,
worst score 0.0038 against the audit's worst standing 0.2655.

**Rendered check, and one honest caveat.** Four walking-distance framings were
captured under Xvfb at 1280x720 with the camera transform resolved from the live
floor, so before and after are byte-identical viewpoints: the habitat corridor
between the bunk alcoves, the observation common room, the Aft operations room
across the coordinator desk, and VIP reception — which this pass does not touch
at all and is therefore the control. Captures are in
`/root/.cache/mudds-shipyards/node-trim2-root/`.

On **Forward+**, which `project.godot` selects for desktop, the before/after
difference is inside the renderer's own same-build noise floor on every framing:
mean |delta| 0.49-0.68 of 255, against same-build rerun floors of 0.29-0.56
(before) and 0.30-0.80 (after). The *largest* of the four before/after deltas is
the VIP framing, where nothing was batched at all — the measurement saying
"noise" as plainly as it can.

On **Compatibility** — which this project ships only as the mobile rendering
method — three framings are at or near the floor (VIP 0.0004, habitat common
0.04, habitat corridor 0.27) but the **Aft operations room is not**: mean |delta|
3.29 against same-build rerun floors of 0.73 (before) and 0.07 (after), and the
coordinator desk top moves from RGB 90/113/119 to 192/188/173. That is a real, visible tone change, and it is the
per-object light cap doing exactly what the first pass recorded, one order of
magnitude larger in the station's most light-dense room: the desk top is *not*
batched and did not move, but merging its neighbours changes which eight lights
win its per-object slots, and it gains the warm wash of the task lamp standing on
it. It is bound-independent — 4 m and 8 m locality caps reproduce the same
192/188/173 byte for byte while costing 339 of the 840 nodes — so the cap stays
at 16 m. Forward+ clusters lights instead of capping them per object and shows
none of it. **This is not qualified as "no visible change" under the mobile
rendering method.**

What was left alone in this pass, and by whose authority:

* **`VipReceptionSuite`** (515 nodes, ~71 available).
  `tests/vip_reception_suite_test.gd` asserts, body by body, that every
  `StaticBody3D` in the suite owns a `Mesh` and a `Collision` child whose box is
  exactly the drawn mesh's size, and that the module presents a floor of visible
  renderers to its "nothing floats" sweep. A solid batch is one body, one merged
  renderer and one `CollisionShape3D` per original piece by design, so neither
  contract survives it without being restated per shape. No audit was relaxed to
  buy nodes.
* **`ObservationLogisticsSpur`, `SalvageTerrace`, `FabricationAnnex`.** These are
  on the roster and produce **no batch at all**: every piece each of them builds
  is either held by a live script variable or already folded into a
  `MultiMeshInstance3D`. They are listed so that stays measured rather than
  assumed — each also publishes an exact whole-module descendant node count, and
  all three still validate clean on the live batched station.
* **Three families declared rather than folded.** The six Aft ceiling-luminaire
  housings and the nine Aft operations floor pressure plates are counted by
  *recipe* by `AftJunctionStack`'s own fixture audit and by
  `tests/station_surface_playability_test.gd`, and the habitat's side-window
  frames are what that test measures the fabrication connector's 3.280 m
  clearance against. Only the first of several identically named siblings keeps a
  readable name, so each family now carries a marker; the metadata gate then
  keeps the pass out of it.
* **The habitat berth roster.** Its board is a stack of 5 cm plates standing off
  the partition at slightly different depths, 1.3 m up a wall the common-room
  floor runs past. Merged they become one 30 cm-thick, 1.32 m-tall face that
  reaches into the standing capsule of the cells in front of it, which the
  walkability sweep correctly reports as a piece the player strolls through — a
  defect the merge would invent rather than one the module built. The family is
  marked, and the sweep is unchanged.
* Everything the first pass already refused: metadata, script, group,
  node-driven signal, child, protected name, live script reference, the 16 m
  locality cap and the walkable-plate refusal. `PROTECTED_DRESSING_NAMES` grew
  from 204 to 431 names, found by matching every candidate node name against
  every string literal in `scripts/`, `tests/`, `tools/`, `docs/`, `scenes/` and
  `assets/`, including `%s`/`%d` format and `find_children` glob patterns.

#### 2026-09-15 third node trim: -49 resident scene-tree nodes, zero triangles

The four buckets the first two passes refused are the ones this pass was sent at:
`OperationalLattice`, `CentralBerthServiceLine`, `ModernFleetRegistry` and
`IndustrialInfrastructure`. Three of them now run through the same
`StationDressingBatch`. The fourth does not, and the measurement of *why* is the
more useful half of this entry: the roadmap item behind this pass expected roughly
379 batchable nodes in `OperationalLattice`, and the honest figure is 38.

| Bucket | Nodes before | Nodes after | Renderers before | Renderers after | Surfaces before | Surfaces after | Triangles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `CentralBerthServiceLine` | 223 | 180 | 95 | 69 | 95 | 81 | 14,692 unchanged |
| `ModernFleetRegistry` | 64 | 58 | 35 | 30 | 35 | 33 | 16,476 unchanged |
| `IndustrialInfrastructure` | 10 | 10 | 9 | 9 | 9 | 9 | 11,328 unchanged |
| `OperationalLattice` | 848 | 848 | 478 | 478 | 490 | 490 | 82,692 unchanged |
| **Resident total** | **10,647** | **10,598** | **5,676** | **5,645** | **6,033** | **6,017** | **1,917,477 unchanged** |

No other bucket moves at all. Triangles (1,917,477 resident / 2,051,611 with
Cinder loaded), lights (335, of which 20 cast shadows), particle systems (45),
bound-phase (693) and retained (969) materials, shaders (7), textures
(34 / 83,355,976 bytes), text triangles/instances (79,709 / 43), every collision
shape's world extent and the whole loaded-minus-resident Cinder delta (+134,134
triangles, +209 renderers, +140 unique meshes, +47 retained materials, +27 lights,
+423 nodes) are identical on both sides. Unique meshes fall 3,167 -> 3,151 because
a merged renderer replaces N cached box meshes with one, and surfaces fall
6,033 -> 6,017 because pieces that shared a material with a sibling now share one
submission — a draw-call reduction, not lost geometry. Measured on `aa3d935c7`
with a pristine Godot user-data home on both sides; persisted pilot state adds one
node per scenario and moves the census fingerprints, which is why the frozen
counts in `tests/geometry_census_scenario_test.gd` now say so out loud.

**Both modules still publish exactly what they build.** Neither audit was
relaxed; both were restated:

* `get_central_berth_service_line_render_contract()` and
  `get_modern_fleet_registry_render_contract()` add each batch's authored row
  (`StationDressingBatch.AUTHORED_CENSUS_META`) back into the descendant,
  renderer, drawn-copy, submission and static-body counts. Every published
  constant is unchanged — the line still reports 222 descendants / 93 renderers /
  100 drawn copies / 95 submissions / 56 bodies / 56 shapes, and the pod still
  reports 63 / 34 / 38 / 35 / 12 / 12, on the live batched station. Each contract
  also now publishes `live_mesh_instances`, so the difference between what the
  module built and what the world left standing is visible rather than inferred.
* `get_central_berth_service_line_report()` states its "looks solid, is solid"
  pairing per **authored piece** instead of per node, because a merged renderer
  cannot satisfy one-drawn-mesh-per-collider node for node.
  `StationDressingBatch.solid_batch_pairing_errors()` asks the same question of
  the live merged triangle buffer: every collider must be spanned by the geometry
  drawn inside it, and no vertex may be drawn outside every collider. That reads
  the merged vertex arrays rather than any stored record of what was merged, and
  it is asserted both ways in `tests/station_dressing_batch_test.gd`, where moving
  a collider off its piece, growing it past its piece and dropping one each turn
  the check red.

`tools/station_walkability_sweep.gd` is **byte-identical end to end** — 82
surfaces, 135,137 cells, 39,904 blocked, 19 findings,
`invisible_blocker`/`choke`/`gap` all zero, 345 lanes measured, and the same 19
blamed paths, 12 narrowest lanes and per-module split — because no collision shape
moved. `tools/coplanar_seam_audit.gd` reports the same **1,341 pairs and 388
families** with the same 28 `coplanar_by_design` declarations, the same worst
families and a byte-identical per-module table; the only movement anywhere in it
is one pair reclassified from `back_to_back` (1,291 -> 1,290), which is a merged
renderer presenting one of its own internal faces to the classifier rather than
two nodes' faces to each other. No class regressed in either tool.

**Rendered check.** Five walking-distance framings were captured under Xvfb at
1280x720 with the camera transform resolved from the live floor, so before and
after are byte-identical viewpoints: the operations lattice across the maintenance
gantry, the berth service line down the port flank, the access work stand (the
ten-piece solid batch), the fleet registry pod across its terminal and berth
board, and VIP reception. **Two of the five are controls this pass does not touch
a node in** — the lattice and VIP. Each framing was captured twice per renderer
per side, so each cell below sits against two same-build rerun floors. Captures,
logs and the full cross-matrix are in
`/root/.cache/mudds-shipyards/node-trim3-root/` (`pixdiffs.txt`).

| Renderer | Framing | floor(before) | floor(after) | before->after | before2->after2 |
| --- | --- | ---: | ---: | ---: | ---: |
| Forward+ | operations-lattice *(control)* | 1.73 | 0.88 | 1.97 | 1.24 |
| Forward+ | berth-service-line | 0.91 | 0.65 | 0.78 | 0.80 |
| Forward+ | berth-work-stand | 0.60 | 0.36 | 0.56 | 0.40 |
| Forward+ | fleet-registry | 0.87 | 1.14 | 1.31 | 1.01 |
| Forward+ | vip-reception *(control)* | 0.33 | 0.55 | 0.46 | 0.57 |
| Compatibility | operations-lattice *(control)* | 1.17 | 0.14 | 0.90 | 0.36 |
| Compatibility | berth-service-line | 0.21 | 0.02 | 0.34 | 0.20 |
| Compatibility | berth-work-stand | 0.85 | 0.05 | 1.01 | 0.28 |
| Compatibility | fleet-registry | 0.41 | 0.16 | 0.34 | 0.14 |
| Compatibility | vip-reception *(control)* | 0.00 | 0.00 | 0.00 | 0.00 |

Mean |delta| of 255. On **Forward+** every before/after cell is inside the band
its own two floors define, and the largest number on the whole board — 1.97, and
2.20 on the before->after2 pairing — is `operations-lattice`, a framing in which
this pass does not change a single node. That is the measurement saying "noise" as
plainly as it can. On **Compatibility** the VIP control is 0.0000 across all six
pairings, and the other four sit at or below their own before-side floor while the
after-side floor is much quieter. The reason is visible and was tracked down
rather than averaged away: of the four Compatibility runs, `compat-before` alone
rendered the berth deck beside the work stand *without* a specular pool that
`compat-before2`, `compat-after` and `compat-after2` all show. That is the same
per-object light-slot instability the second trim recorded, occurring here
**within one build** — which is exactly why the noise floor takes two runs a side.
No geometry, silhouette, material, light or placement differs in any framing on
either renderer, and unlike the second trim there is no bound-dependent tone
change to record.

What was left alone in this pass, and by whose authority:

* **`OperationalLattice`** (848 nodes). This is the bucket the roadmap item aimed
  at, and it is measured rather than assumed: run the pass over it and it forms
  **7 batches out of 45 renderers, worth 38 nodes**, every one of them inside a
  `StationOperationsActivity` (`CentralTowServiceActivity`,
  `FreightApproachGantry`, `AftCrewWorkPost`, `HabitatSkywatchPost`,
  `FreightApproachSignage`). That component does **not** publish a count roster
  that an authored-census row can restore.
  `_built_presentation_hierarchy_is_live()` requires the live node set to equal
  the built node set *by instance id at its authored path*, and
  `_built_mesh_contracts_are_live()` re-checks every built renderer's own mesh
  resource id, storage fingerprint and bound `material_override`. A merge frees
  the source nodes and their meshes by design, so those are identity and
  resource-storage proofs that would have to be deleted, not counts that could be
  added back. `get_operational_lattice_audit_report()` gates on each activity's
  audit and inherits the same answer. Thirty-eight nodes do not buy deleting a
  proof that every authored renderer is still the resource it was built from.
* **The rest of the lattice**, by subtree: `ActivityCollision` (71 nodes) is
  collision authority; `ServiceAgents` (85) and `Ambience` (13) are script-owned
  movers and emitters; and all 20 renderers of the four
  `StationStructuralServiceDressing` instances (177 nodes) carry the
  `detail_role`/`quality_tier` metadata their quality lifecycle reads, so the
  metadata gate already keeps the pass out of them.
* **Ninety lattice renderers that are structurally foldable and must not be
  folded.** The service arm's segments, both service drones and every safety
  beacon carry a **hard near-camera guard** (`visibility_range_begin`, fade
  disabled) so a drone flying at the player does not fill the screen. That guard
  triggers on the *instance's* bounding volume, so merging even two siblings moves
  the distance at which each one disappears. That is a visible change by
  definition, and `_mesh_is_mergeable()` already refuses any renderer with a
  visibility range.
* **Seven names added to `PROTECTED_DRESSING_NAMES`**, taking it to 443, found by
  grepping all 91 leaf names this pass would otherwise have folded in the three
  new modules. `RegistryBerthTile01`…`06` are the pod's own declared readability
  roster, resolved by formatted name inside its render contract and tracking
  `SHIP_BERTH_FEEDBACK_BERTH_IDS`. `StandPlatform` and `MastBaseFlange` are
  resolved by path from `tests/station_presentation_defect_witness_test.gd`.
  `BoardLampLens`, `MastFootLens`, `RackStripLens` and `WorkLampLens` are the four
  lens names the service line's fixture-practical sweep resolves beside each of
  its six lights; that audit asks whether the spill comes from a *drawn lens*, and
  a merged renderer could only answer "some geometry is near", which is a weaker
  question. Those seven names cost 12 of the 61 nodes the three modules could
  otherwise have given up, and every one was paid deliberately.
* **`IndustrialInfrastructure` produces no batch at all.** Each of its six utility
  runs is a single 72 m cylinder — longer on its own than the 16 m locality cap —
  so every one gets a chunk to itself, and a chunk of one is never merged; its 54
  couplers are already one `MultiMeshInstance3D` per radius. It is on the roster
  so that stays measured rather than assumed.
* Everything the earlier passes already refused: metadata, script, group,
  node-driven signal, child, protected name, live script reference, the 16 m
  locality cap and the walkable-plate refusal.

**The node ceiling is still not met, and these four buckets are now close to
exhausted.** Resident nodes are 10,598 against 7,000 — 51% over. Of the 1,145
nodes the four buckets hold, 49 were available without weakening a published
audit, 38 more sit behind `StationOperationsActivity`'s identity contract, and the
remaining ~1,058 are collision, mover, lifecycle, quality-tier or name-resolved
authority. The next real node headroom is not in this module.

#### 2026-09-15 ship node trim: -96 resident scene-tree nodes, zero triangles

`ShipFitoutBatch` (`scripts/rendering/ship_fitout_batch.gd`) is the ship-side
sibling of `StationDressingBatch`, called from each craft's own variant builder
as the last step of its build. It merges anonymous sibling fitout dressing —
cabin liners, window surrounds, wall and ceiling cassettes, container faces,
bunk and locker joinery, curtain rails, systems racks, light strips, access trim
— into one multi-surface `MeshInstance3D` per locality, in the exact parent that
built it. Batches carry one surface per distinct source material, so the same
finishes are bound to the same triangles at the same local placements through
`set_surface_override_material()`.

It is a separate class rather than a caller of the station one for two reasons a
ship has and the station does not. A craft is built **before** it is in the tree
and rebuilt by `reset_for_reuse`, so every placement here is composed from local
transforms only — the station pass reads `global_transform`, which is meaningless
in those states. And ship fitout is drawn stock whose collision is authored
separately as root shapes and interaction areas: no ship fitout piece owns a body
of its own, so there is no solid-batch path at all and **the pass creates, moves
and removes no collision shape**.

| Bucket | Nodes before | Nodes after | Renderers before | Renderers after | Surfaces before | Surfaces after | Triangles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `FleetExpansionProductionBinding` | 792 | 759 | 597 | 564 | 606 | 582 | 193,858 unchanged |
| `ZenithInterceptor` | 198 | 170 | 99 | 71 | 116 | 87 | 83,490 unchanged |
| `JovianLightFreighter` | 621 | 601 | 453 | 433 | 472 | 460 | 167,594 unchanged |
| `BulwarkHeavyGunship` | 270 | 259 | 214 | 203 | 218 | 213 | 58,726 unchanged |
| `ArrowReconShip` | 324 | 322 | 252 | 250 | 256 | 255 | 103,002 unchanged |
| `HalyardCrewTransport` | 459 | 457 | 349 | 347 | 356 | 355 | 150,748 unchanged |
| **Resident total** | **10,648** | **10,552** | **5,676** | **5,580** | **6,033** | **5,961** | **1,917,477 unchanged** |

The bucket rows above are the census tool's own run on this box. The frozen
scenario contract in `tests/geometry_census_scenario_test.gd` measures the same
scene with fresh private user data, as that contract requires, and reads one
node lower in each scenario for the reason the previous freeze already records:
**10,647 -> 10,551 resident and 11,070 -> 10,974 loaded**. The delta is 96
either way.

No station bucket moves at all. Triangles (1,917,477 resident / 2,051,611 with
Cinder loaded), lights (335, of which 20 cast shadows), particle systems (45),
bound-phase (693) and retained (969) materials, shaders (7), textures
(34 / 83,355,976 bytes), text triangles/instances, every collision shape's world
extent and the whole loaded-minus-resident Cinder delta are identical on both
sides. Unique meshes fall 3,167 -> 3,071 because a merged renderer replaces
several privately owned box meshes with one, and surfaces fall because pieces
that shared a finish with a sibling now share one submission — a draw-call
reduction, not lost geometry. `tools/station_walkability_sweep.gd` is unchanged
end to end: the same 19 findings at the same coordinates, the same per-module
split (`aft_junction_stack` 2, `habitat_spine` 6, `shipyard_world` 11),
`invisible_blocker`/`choke`/`gap` all zero and the same pinch-lane roster,
because no collision shape moved.

**The craft still publish exactly what they build.** `EXPECTED_ARROW_VISUAL_CENSUS`
is a frozen roster of what the Arrow *allocates*, so each batch is added back as
the renderer nodes, drawn copies, submissions, mesh resources and auto-named
sources it stands in for (`ShipFitoutBatch.authored_render_census_delta` /
`authored_node_delta`, the same contract `HabitatSpine` and `AftJunctionStack`
use). The delta is zero on a craft built without the pass, so an unbatched build
reads identically. The Halyard's `RENDER_DESCENDANT_COUNT` roster is scoped to
`HalyardTransportVisual` and its cabin fittings live on the moving interior root,
so it is unaffected and unchanged.

Five walking-distance interior framings — the Jovian cargo bay and passenger
cabin, the Halyard crew cabin and flight deck, and the Cinder cargo hauler's
cockpit — were captured against the untrimmed build under Xvfb at 1280x720 on
both renderers. The compartment bounds the framing is derived from are identical
before and after, so the camera transforms are bit-identical. On **Forward+**,
which the desktop build ships, every framing is inside or at the renderer's own
same-build noise floor (mean |delta| 0.376-0.565 of 255 against a 0.321-0.602
floor). On the **Compatibility** fallback the difference is larger than its much
quieter floor and is confined to per-object light-list reassignment: that
renderer caps how many lights reach one instance, so a merged bound can pick up
or drop a cabin practical. The largest is the Halyard crew cabin at mean |delta|
3.01 of 255 (1.2%) against a 0.002 floor — a uniform low-amplitude luminance
shift across the whole frame, strongest on the ceiling, with no geometry,
silhouette, material or placement difference in any framing. Tightening the
locality cap does not touch it: at a 4 m cap the same framing measures 3.006,
because what moves there is which lights win an instance's per-object slots and
that ordering follows how many instances the compartment has, not how large any
one of them is. The cap therefore stays at the station pass's 16 m, which costs
74 fewer nodes than 4 m for no measured rendering difference.

**Why 96 and not several hundred.** An unguarded pass over the same eight craft
folds 401 nodes. Each guard below removes part of that, and each removes it
because folding there would trade away a production property rather than buy a
free one. **No audit was relaxed to buy nodes**, and the measured cost of each is
recorded so a later pass can revisit it deliberately rather than by accident:

* **Deliberately shared stock meshes — about 170 nodes.** The Jovian's
  dorsal-rib and shoulder-rail joints, cargo-frame joints, cabin light strips and
  landing-gear legs, the Arrow's collar and main-gear-foot stock, and every other
  family a `*_resource_sharing_test` proves. Merging N renderers of one cached
  mesh stores that geometry N times, which is the opposite of what the sharing
  exists for, and dissolves the resource identity those audits check. A renderer
  whose mesh is drawn more than once, or held by a live craft variable, is never
  folded.
* **Live `PrimitiveMesh` stock — about 25 nodes.** `TorusGeometryBudget.normalise_tree`
  sweeps the finished tree and re-tessellates turned and swept stock from its own
  radius, and only while the recipe is still a primitive. Baking one into a
  merged `ArrayMesh` takes it out of that sweep and freezes it at the segment
  count it was authored with; the Bulwark's cockpit gimbal measured +112
  triangles that way before the rule was added.
* **Camera-distance LOD bands — about 32 nodes.** The seat and container
  furniture `_configure_interior_furnishing_ranges` bands is left standing piece
  by piece, so exactly the renderers that carried a band still carry one.
* **Names a craft assembles at runtime — about 60 nodes.** Ship audits build
  paths by concatenation and formatting, so a whole-name grep cannot see them;
  every fragment a composed lookup contributes protects every name it occurs in.
* **`PilotAccessSteps`, `MainFrame` and `ToeFrame`**, whose contents are an exact
  renderer roster their own audits index.
* Any node carrying metadata, a script, a group, a node-driven signal, a child,
  or a name that `scripts/`, `tests/`, `tools/`, `docs/`, `scenes/` or `assets/`
  resolves — which covers every seat, bunk, anchor, console, instrument face,
  hatch, route inlay, damage cue, hull marking and canopy fitting, and is why the
  shared `CockpitInterior` the common controller indexes contributes almost
  nothing. Any node a live script variable still holds. A merged bound that would
  read as a walkable plate. And any merge whose triangle count would not
  reproduce its sources' exactly.

The resident node count is **10,551** and remains 51% over its 7,000 ceiling.
The ceiling is not met. The remaining ship node volume is the shared cockpit
roster, the shared-stock families above and metadata-bearing presentation
renderers — indexing and resource contracts rather than anonymous dressing — so
the next worthwhile ship-side trim is a deliberate decision about one of those
contracts, not another sweep of this one.

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
eleven fixed gameplay viewpoints — the habitat corridor at walking distance, a
walk-up on one rib foot, a look up at a rib crown, the common room, a bunk
privacy arch, the Aft operations room inside and its envelope from the open deck
outside, a freight-berth tie-down ring close under the apron's two
shadow-casting spots, the whole station in a long view with its cast shadows,
the backdrop worlds, and one flight-range target drone — with station activity
and service-agent clocks seeked to zero so both sides frame the identical scene.
Captures and diffs are under
`/root/.cache/mudds-shipyards/station-trim2-root/`.

Ten of the eleven views are static; the eleventh (the target drone) is excluded
from the totals below because the drone drifts, which moves 25.6% of that
frame's pixels between two runs of the *same* build.

- Over the ten static views, two runs of the same build differ on **0.16%** of
  pixels (a second same-build pair differs on 0.54%, driven by the backdrop's
  own star field and the range markers' drift).
- Before against after differs on **0.93%** of pixels over the same ten views.
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

#### 2026-09-14 ship trim: -204,888 resident triangles

The station pass above left the scene at 2,407,157 against the 1,800,000
ceiling, with the ship buckets as the largest remaining growth. This pass
budgets the fleet's *detail* tessellation from the size each part is actually
drawn at, and again raises no ceiling and relaxes no assertion.

| Bucket | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `JovianLightFreighter` | 249,282 | 167,594 | -81,688 |
| `ShipyardWorld/FleetExpansionProductionBinding` (three Cinder craft) | 263,746 | 193,858 | -69,888 |
| `HalyardCrewTransport` | 204,060 | 150,748 | -53,312 |
| **Whole scene** | **2,407,157** | **2,202,269** | **-204,888** |

No other bucket moves, and the change is triangle-only on every other census
row: 6,588 mesh renderer nodes, 6,686 surfaces, 692 bound and 968 retained
materials, 7 shaders, 34 textures, 335 lights (20 shadow-casting), 45 particle
systems and 11,612 scene-tree nodes are identical on both sides, as is the
loaded-minus-resident Cinder delta of +134,134. Unique meshes move by exactly
one (3,354 -> 3,355) because the Cinder nozzle family now keys its shared unit
meshes by the budgeted segment count. No collision shape, interaction marker,
boarding route, seat anchor, light, material or evidence label changed, and
nothing added per-frame work.

**Two owners, both modelled on `TorusGeometryBudget`.** They import its
`TOLERANCE_RADIANS`, `NEAR_EYE_METRES` and `FRAME_RATIO` and call its
`segments_for` rather than deriving a second tolerance, so the fleet and the
station answer the same question the same way.

- `scripts/rendering/ship_geometry_budget.gd` solves revolved segments, joint
  sphere tessellation, arc steps, tube segments and shallow-span steps from a
  part's own world-space size, floored at the counts this project has rendered
  and accepted (32 for a circle read as a circle, 12 for a tube cross-section).
  Every entry point returns `min(authored, budgeted)`, so it can only reduce.
  Radial counts are snapped up to a multiple of four, which keeps a vertex on
  each cardinal direction of the section and therefore keeps every reduced
  part's extrema and AABB exact rather than approximately exact.
- `scripts/rendering/ship_chamfered_stock.gd` builds fitted box stock with a
  single *tangent* chamfer instead of the two-segment quarter-round the kit
  gives every box. The tangent placement is what makes this safe: the chamfer
  plane touches the authored rolled edge at 45 degrees and lies outside it
  everywhere else, so the face planes and the AABB are exact and the surface
  never moves inward. Its worst departure is `0.1589 * bevel` at the eight
  corner vertices — 1.9 mm on the 12 mm chamfer most fitted stock carries.
  Stock whose chamfer is wide enough for that to resolve at the 1.5 m walking
  range keeps the authored roll.

**What the budget reached.** The Cinder nozzle family (`_turned` revolved every
part at 96 radial segments, from a two-metre bell mouth down to a
twenty-centimetre thrust plug, and its stator blades at 16 x 9); the Jovian's
rib, rail and cargo-frame joint spheres; both craft's *baked* fitout rings,
which `TorusGeometryBudget.normalise_tree` never reaches because it sweeps live
`TorusMesh` renderers only; the Jovian's roof service patches, which were 12
steps wide whether the patch spanned 3.5 m of crown or 12 cm; its flight-deck
transition fillets, which rolled a quarter-ellipse at 32 segments (128 around a
full section); the Cinder beacon lens, at Godot's default 64 x 32 for a 48 cm
bead; the Halyard's bunk-tie lattice; and every chamfered cylinder and frustum
the five craft build, which were all frozen at 32 radial segments.

Four of the Halyard's five berth-fabric kinds kept their authored 32 x 24
lattice and that is the honest result: the pillow wrinkle, the curtain's five
fold periods and the blanket and fold ripples carry real high-frequency shape,
and every coarser candidate aliased them by more than a centimetre.

**Rendered evidence**, at 1280x720 through `gl_compatibility` on a D3D12 GPU
under Xvfb, from ten fixed gameplay viewpoints: the Jovian cargo bay at walking
distance and a walk-up on its cargo frames, its engine cooling fins, and a
chase framing of the whole craft; the Halyard crew cabin, a liveaboard berth and
the engine service fitout; a Cinder interceptor and a Cinder bomber at their
expansion berths, and a walk-up on an interceptor nozzle.

- Two runs of the *same* build differ on **2.18%** (before, 200,564 px of
  9,216,000) and **3.10%** (after, 285,962 px) of pixels. This scene is not
  bit-deterministic between runs: most of that is sub-quantisation drift at a
  mean amplitude of 1 of 255, and a whole-frame exposure wobble can move every
  pixel of a view by one or two levels.
- Before against after differs on **7.35%** (677,147 px), against those two
  floors. The figure that isolates geometry from the exposure wobble is the
  count beyond 32 of 255: **20,486 px, 0.222%**, against same-build floors of
  1,821 (0.020%) and 1,695 (0.018%). That residual is real and it is confined to
  the edited surfaces — the difference image over the nozzle view is thin
  outlines on the bell, lip and stator blades and nothing anywhere else in the
  frame.
- Direct inspection, 1:1 and magnified: at 1:1 the pairs are indistinguishable
  on all ten views. At 9x the nozzle bell rim is a smooth arc on both sides with
  no straight run or corner, pulled in by well under one screen pixel. At 8x on
  the *nearest* fitted stock — a cargo restraint corner about 40 px across — the
  two-segment rolled edge does read as a single chamfer facet with two creases
  where it used to read as a roll. That is the one difference this pass can
  honestly find, it is about two pixels wide, it does not show at 1:1, and it is
  a bounded presentation trade rather than a free reduction. Reverting it is a
  single gate in `ShipChamferedStock.rolled_edge_is_resolvable` and costs about
  12,400 triangles.

This is a scene-content measurement plus a rendered-composition check. It is not
a frame-time, GPU-time or VRAM claim, and the software/remote-display caveats at
the top of this document still apply.

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
`4e17fb5a350d68b541f9699c0f7cc51d4bfdc76e21e0ebf416c0f9f286b92d7e`;
the loaded fingerprint is
`3c580432aa2db57b929c6f10c9590a8d5edf8681cd7b6497874c3c5aaee4d917`.
`tests/geometry_census_scenario_test.gd` takes its own settle and therefore
carries its own pair, `7971c6656cf8a2d8f67cf907b4b60b25b1c21bc9526e4c9ce511f94174db7594`
and `ec255de3a54bfa7082f49bd40d1281aa53d7c9baf36e9fd00ff25db8a72878b5`.
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

## Ninth trim (2026-09-15): declared-view tessellation for torus and sphere stock

Phase 10 §2 asked for the resident scene to come under the 1,800,000
ceiling by trimming primitive stock before any budget is raised. Measured on
`de8d162d6` with `tools/geometry_census.gd` under fresh private user data, this
pass takes the station-resident scene from **1,918,333 to 1,846,587 triangles
(-71,746, 3.7%)**. **The ceiling is still not met**: the scene is 46,587
triangles (2.6%) over it, and the arithmetic of why the rest is not available
from this stock is set out at the end, as the hero/opponent pass did.

The change is triangle-only. Before and after, the census counts **5,557 mesh
renderers, 5,953 surfaces, 3,058 unique meshes, 693 bound and 996 retained
materials, 7 shaders, 34 textures, 341 lights (20 shadow casting), 54 particle
systems, 79,709 text triangles across 43 signs and 10,587 scene-tree nodes**
identically, and the bound-material fingerprint is unchanged
(`86b6a683…`). No node name, count, material identity or mesh-sharing
relationship moves; no collision shape is derived from any of the primitives
touched (every one was checked to be a `MeshInstance3D` or `MultiMesh`
visual whose body, where it has one, is a separate cylinder or box shape).

### The policy

The whole-scene census had 192 `TorusMesh` instances at 905 triangles each
and 226 `SphereMesh` at 474. Every one of them was already budgeted, but at
one range: `TorusGeometryBudget` solves the tube at `NEAR_EYE_METRES` (0.6 m)
and floors everything at the photographed 32x12, because a torus *can* be
anywhere. Most of these cannot. A pipe collar on a 3.6 m service run, a
roof-vent collar on a 5.3 m roof, a lashing ring recessed into a deck plate
under a standing eye and a navigation light 4.9 m above an apron are all held
to the walk-up answer for a range no camera reaches.

So a builder may now **declare** the nearest distance a camera is taken to a
ring or a lens — the same declaration the module rib builders and
`StationSurfaceKit.radial_segments_for` already make for round stock — and the
shared rule is solved there:

- `TorusGeometryBudget.plan(outer, inner, nearest_view_metres)` keeps the
  sagitta rule and `TOLERANCE_RADIANS` unchanged, applied at the declared
  range instead of 0.6 m, still capped at a fifth of the tube on the major
  sweep. **The floors scale with the declaration**: a polygon is read by its
  angular edge, not its metric error, so the photographed 32x12 at 0.6 m is
  carried out as `32 * 0.6 / d` and `12 * 0.6 / d`, the same angular sampling
  the walk-up floor was judged clean at, and never below `FAR_MIN_RINGS` x
  `FAR_MIN_RING_SEGMENTS` = 12x8. Declared answers are rounded up to a
  multiple of four so a vertex lands on every cardinal direction of both
  circles, which is what keeps every family's AABB contract exact.
- A declaration reaches a live `MeshInstance3D` family through the existing
  startup sweep: `TorusGeometryBudget.declare_nearest_view(mesh, metres)` is a
  registry keyed by mesh, not metadata, because the module audits freeze the
  exact metadata list on those meshes and renderers. A shared mesh is
  budgeted at the **closest** of its declarations; the authored recipe stays
  pristine until the sweep exactly as before. MultiMesh stock and craft
  assembled after the sweep pass the distance to `apply` directly, as they
  already did for the walk-up rule.
- `StationSurfaceKit.sphere_tessellation_for(radius, nearest_view_metres,
  authored_radial, authored_rings)` is `ShipGeometryBudget.sphere_plan`
  carried out the same way: identical at walk-up, floors scaling from 16x8 to
  12 meridians. One property the sphere rule adds, found by the Halyard's
  lens-dimension contract: Godot's `SphereMesh` cuts the meridian into
  `rings + 1` bands, so only an **odd** ring count places a vertex ring on
  the equator — the widest circle of the silhouette. A declared sphere is
  therefore 12x7, 16x9 or 20x11 rather than 12x6, 16x8 or 20x10: 24
  triangles more per sphere, and the authored radius exact on all three axes,
  where the even authored 24x12 already sat 0.7% inside it.
- `StationSurfaceKit.DECK_FLUSH_NEAREST_VIEW_METRES` (1.6 m) names the one
  range most of the declarations share: a ring recessed into or lying on the
  deck a player stands on is at least 1.6 m from a 1.75 m standing eye,
  straight down being the closest case.
- Undeclared rings and spheres keep the walk-up rule bit for bit; a
  declaration never raises tessellation and never lowers the floor a walk-up
  ring is held to. `tests/torus_geometry_budget_test.gd` now asserts all of
  this on synthetic radii, and holds every live world ring to the floor at its
  own declared range.

### What was declared, and what was left alone

Every declaration is a measured height or standoff written next to the
constant, not a guess about where the level puts the player. Per instance,
before -> after:

| Family | Declared range and why | Recipe | Copies | Saved |
| --- | --- | --- | --- | ---: |
| Cinder nozzle lips (`cinder_exhaust_machinery.gd`) | walk-up; the one revolved part the ship trim left at the authored 96x16 | 96x16 -> 40x12 | 6 | 12,672 |
| Guide lenses, four batches (`shipyard_world.gd`) | 1.0 m: the safety-pylon lamps at 1.95 m, ~0.8 m from an eye beside the 0.8 m pylon, govern all fifty | 24x12 -> 20x11 | 50 | 7,200 |
| Jovian dorsal rib joints | 2.9 m: the lowest hull-top fitting, the nav light at 3.7 m ship-local, is 4.9 m above the apron | 20x10 -> 12x7 | 25 | 6,200 |
| Jovian shoulder-rail joints | 2.9 m, as above | 23x12 -> 12x7 | 7 | 2,842 |
| Jovian navigation lights / windscreen post joints | 2.9 m / walk-up (`_sphere` now budgets its bead) | 24x12 -> 12x7 / 16x8 | 2 / 2 | 864 / 672 |
| Habitat environmental-main pipe collars | 3.6 m run less 0.19 m radius less a 1.75 m eye = 1.66 m | 32x12 -> 16x8 | 6 | 3,072 |
| Habitat isolation valves | 3.25 m less 0.23 m less 1.75 m = 1.27 m | 32x13 -> 20x12 | 6 | 2,112 |
| Habitat common-chair bearings | 1.0 m, inside the pedestal/seat overlap; tube keeps the occluded 8 | 32x8 -> 24x8 | 8 | 1,024 |
| Habitat garden column head ring | 5.16 m less 0.9 m less 1.75 m = 2.51 m | 40x16 -> 28x12 | 1 | 608 |
| Habitat nutrient tank bands / valves (MultiMesh) | 1.0 m beside the 0.47 m tanks / 0.8 m under the 2.3 m valves | 40x12 -> 32x12 / 32x12 -> 24x12 | 3 / 3 | 576 / 576 |
| Aft roof-vent collars and roof-spine clamps | `ROOF_MEMBER_NEAREST_VIEW_METRES` (3.4 m), already declared for the vents and spine | 40x16 -> 20x8 / 32x8 -> 16x8 | 2 / 5 | 1,920 / 1,280 |
| Aft pod-corner collars | deck-flush 1.6 m: the west pair sit 0.25 m above the upper open deck | 34x14 -> 24x12 | 4 | 1,504 |
| Aft console shock collars (MultiMesh) | deck-flush 1.6 m at the console feet | 32x8 -> 16x8 | 6 | 1,536 |
| Aft conduit collars / pedestal bearings | 3.0 m less 0.16 m less 1.75 m = 1.09 m / 1.0 m | 32x8 -> 20x8 / 32x8 -> 24x8 | 3 / 4 | 576 / 512 |
| Aft underfloor support collars | `UNDERFLOOR_MEMBER_NEAREST_VIEW_METRES` (2.5 m), already declared for the braces | 36x16 -> 20x8 | 2 | 1,664 |
| Aft VIP facade column trims (MultiMesh) | deck-flush 1.6 m: the foot pair sit 0.2 m above the VIP deck | 32x14 -> 20x12 | 4 | 1,664 |
| Landing pad tie-down sockets / umbilical deck connectors | deck-flush 1.6 m | 32x14 -> 20x12 / 32x13 -> 20x8 | 6 / 3 | 2,496 / 1,536 |
| Freight-berth lashing rings (anchors and batch) | deck-flush 1.6 m; tube keeps the profile's 8 | 32x8 -> 20x8 | 16 | 3,072 |
| VIP servery stool foot rings | 1.75 m eye less 0.26 m = 1.49 m | 32x12 -> 20x8 | 3 | 1,344 |
| Exterior range drone rings and beacon ring | `EXTERIOR_TARGET_RANGE_APPROACH_METRES` (3 m), already declared for the lamps | 40x16 -> 40x12 | 9 | 2,880 |
| Cinder cockpit control-stick gimbals | walk-up; `HeroShip._torus` now budgets as built, so craft assembled after the sweep match the resident hulls | 48x16 -> 32x12 | 3 | 2,304 |
| Halyard defensive muzzle lenses | 2.5 m across the bow overhang from the midships deck | 24x12 -> 12x7 | 2 | 864 |
| Opponent weapon telegraphs, lenses, blisters, beacons (`range_opponent.gd`) | 3 m: flight-only craft, budgeted at the range's own hull approach | 24x12 -> 12x7 / 16x9 | 18 | 5,200 |
| Torrent recessed igniters / navigation light | walk-up; `_sphere` now budgets its bead | 24x12 -> 16x8 / 20x10 | 2 / 2 | 672 / 368 |

Left at walk-up range on purpose, with the reason: the three dock mast
collars (1.0 m up, beside a walkable mast), the garden column collars (the
planting bed keeps a player 1.2 m off the axis but the lowest collar is 0.8 m
from the eye), the catwalk ladder hoops (the lowest is 0.7 m above a standing
eye), the Torrent's engine collars (2.2 m up on a hull a player walks
around), the Bulwark's collars and lamps (walk-up answers already at 40x8 and
24x12), the Aft rack-tray and exterior pipe clamps (0.55 m and walk-up), the
big deck rings on the landing pad and freight apron (their tubes need 16
segments even at 1.6 m), and the Jovian cargo-frame joints (their lower
joints are at eye level in a walkable bay). The Arrow's 21,000 triangles of
rings and beads were not touched: its builder is owned by another workstream.

### The numbers

| Bucket | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `ShipyardWorld/FleetExpansionProductionBinding` | 194,714 | 179,738 | -14,976 |
| `ShipyardWorld/AftJunctionStack` | 161,168 | 150,512 | -10,656 |
| `JovianLightFreighter` | 167,594 | 157,016 | -10,578 |
| `ShipyardWorld/HabitatSpine` | 209,990 | 202,022 | -7,968 |
| `ShipyardWorld/GuideLensBatch{Red,Cyan,Orange,Neutral}` | 31,200 | 24,000 | -7,200 |
| `ShipyardWorld/LandingPad` | 42,116 | 38,084 | -4,032 |
| `ShipyardWorld/StationDefenseEncounter` | 70,342 | 67,014 | -3,328 |
| `ShipyardWorld/JovianFreightBerth` | 64,852 | 61,780 | -3,072 |
| `ShipyardWorld/ExteriorTargetRange` | 27,707 | 24,827 | -2,880 |
| `ShipyardWorld/VipReceptionSuite` | 47,767 | 46,423 | -1,344 |
| `TorrentInterceptor` | 158,600 | 157,560 | -1,040 |
| `HalyardCrewTransport` | 150,748 | 149,884 | -864 |
| `RangeOpponent` | 17,302 | 16,438 | -864 |
| `StandoffPicket`, `WingSkirmisherLead`, `WingSkirmisherWing`, `CourierRunner` | 19,220 / 19,232 / 19,232 / 20,582 | 18,484 / 18,496 / 18,496 / 19,846 | -736 each |
| **Whole scene** | **1,918,333** | **1,846,587** | **-71,746** |

By mesh kind: `TorusMesh` 173,884 -> 128,956 across the same 192 instances
(905 -> 671 each), `SphereMesh` 107,146 -> 80,328 across the same 226 (474 ->
355). `ArrayMesh`, `TextMesh`, `BoxMesh`, `QuadMesh`, `CylinderMesh` and
`CapsuleMesh` are identical. `tools/torus_census.gd` reports the live ring
population at 242,816 authored -> 112,508 budgeted (53.7% cut); the standalone
world subtree freezes at 87,520 triangles across the same 133 ordinary ring
renderers in `torus_geometry_budget_test.gd` (was 111,584).

`geometry_census_scenario_test.gd` on this branch prints, for the integrator
to refreeze on `main` (its four triangle and fingerprint assertions fail with
exactly these values; the other thirteen pass):

```
GEOMETRY_CENSUS_RESIDENT_FINGERPRINT: 12edd5e47fc7053e4754ff1b527dbc4dc5d3985b573619eb303cdfe5a6f72731
GEOMETRY_CENSUS_RESIDENT_GEOMETRY: { "total_triangles": 1846587, "total_mesh_instances": 5557, "total_surfaces": 5953, "unique_meshes": 3058 }
GEOMETRY_CENSUS_RESIDENT_RESOURCES: { "bound_phase_unique_materials": 693, "retained_reachable_unique_materials": 996, "lights": 341, "nodes": 10587, "unique_shaders": 7, "unique_textures": 34, "texture_bytes": 83355976, "particle_systems": 54 }
GEOMETRY_CENSUS_LOADED_FINGERPRINT: a06fb2c14e2459edeb03ef9f6e861a233b6046ae19ce83bab048673242e35d27
GEOMETRY_CENSUS_LOADED_GEOMETRY: { "total_triangles": 1980721, "total_mesh_instances": 5766, "total_surfaces": 6162, "unique_meshes": 3198 }
GEOMETRY_CENSUS_LOADED_RESOURCES: { "bound_phase_unique_materials": 735, "retained_reachable_unique_materials": 1043, "lights": 368, "nodes": 11010, "unique_shaders": 7, "unique_textures": 34, "texture_bytes": 83355976, "particle_systems": 54 }
```

The loaded-minus-resident Cinder delta stays +134,134 triangles, +209
renderers, +209 surfaces and +140 unique meshes: nothing streamed changed.

### Rendered evidence

At 1280x720 through `gl_compatibility` on the D3D12 device under Xvfb, from
fifteen fixed gameplay viewpoints that look at trimmed stock at the range a
player reads it from — the habitat service run and a valve walk-up, the
garden column head ring, the nutrient tanks, the VIP servery stools, the dock
mast collar with its lens, a safety-pylon guide lens, a landing-pad tie-down
socket and a deck connector, a freight-berth lashing ring, the Jovian's
hull-top fittings, a Cinder bomber nozzle lip, the Aft roof vents and a pod
corner from the upper deck, and a range drone. Both sides come from this
worktree: "before" with `scripts/` checked out from `de8d162d6`, "after" from
the working state, and a same-build "after" repeat for the noise floor.
Captures, 8x difference images and 3x side-by-side crops are under
`/root/.cache/mudds-shipyards/agent-torus-trim/captures/{before,after,after2,diff,diff-samebuild,crops}`;
the harness is `.godot/torus_trim_capture.gd` (untracked, modelled on
`arrow_access_root.gd`).

Per pair, mean and maximum absolute RGB difference (0-255) and the share of
pixels whose largest channel moves by more than 8 and 32, before against
after, with the same-build repeat's figure in brackets:

| View | mean | max | >8 | >32 |
| --- | ---: | ---: | ---: | ---: |
| `habitat_pipe_collars` | 0.015 | 186 | 0.039% (0.000%) | 0.013% |
| `habitat_isolation_valve_walkup` | 0.021 | 204 | 0.040% (0.000%) | 0.022% |
| `garden_column_head_ring` | 0.020 | 84 | 0.063% (0.000%) | 0.012% |
| `garden_nutrient_tanks` | 0.005 | 73 | 0.018% (0.000%) | 0.003% |
| `vip_servery_stools` | 0.016 | 174 | 0.056% (0.000%) | 0.014% |
| `dock_mast_collar_and_lens` | 0.871 | 237 | 4.759% (0.037%) | 1.930% |
| `safety_pylon_guide_lens` | 0.115 | 255 | 0.237% (0.015%) | 0.115% |
| `landing_pad_tie_down` | 1.390 | 207 | 3.833% (0.010%) | 2.077% |
| `landing_pad_deck_connector` | 0.020 | 130 | 0.049% (0.000%) | 0.006% |
| `freight_lashing_ring` | 0.040 | 54 | 0.054% (0.000%) | 0.002% |
| `cinder_bomber_nozzle_lip` | 0.031 | 139 | 0.088% (0.009%) | 0.018% |
| `aft_roof_vent_collars` | 0.179 | 211 | 0.502% (0.045%) | 0.134% |
| `aft_pod_corner_collar` | 0.142 | 208 | 0.176% (0.001%) | 0.055% |
| `jovian_nav_light_and_ribs` (`captures/{before,after,after}-jovian*`) | 0.043 | 255 | 0.062% (0.042%) | 0.043% |
| `range_drone_rings` (drones parked; `captures/{before,after,after}-drones*`) | 1.728 | 255 | 2.943% (2.184%) | 1.322% |

Two pairs stand well above their same-build floor and neither is
tessellation. The dock-mast view's difference image is a broad red wash over
the mast and deck — a pulsing guide light caught at a different phase,
because the base and working builds reach the pause at different frame
counts — plus the outline of a service vehicle further along its route; the
mast collar itself is untrimmed. The tie-down view has the same red wash and
a moving outline at the top of frame; the socket's own difference is a thin
outline at its rim. The range drones drift on a time-based phase, so the
first pass photographed them displaced; the harness now parks every target at
its authored position before the pair is taken, and the row above is that
parked pair.

Direct inspection at 3x on the centre crops: the tie-down socket (32x14 ->
20x12), the stool foot rings (32x12 -> 20x8), the lashing ring (32x8 ->
20x8), the isolation valve (32x13 -> 20x12) and pipe collar (32x12 -> 16x8)
on the service run, the column head ring (40x16 -> 28x12), the roof-vent
collars and spine clamps from the upper deck, and the Cinder lip (96x16 ->
40x12) are indistinguishable from the authored side; no silhouette reads as
polygonal at 1:1 or at 3x. The one visible change is the pylon guide lens
(24x12 -> 20x11), where at 3x a faint straightness can be found on the
upper-left silhouette that is not there at 1:1; that lens is the closest
approach of the whole family and sets its recipe, and it is left as the
declared 1.0 m answer rather than backed off, since the same-build repeat's
0.015% shows the 0.237% it moves is the lens itself and the crop shows what
that amounts to. The Jovian's port navigation light (24x12 -> 12x7, about
30 px across from the apron) likewise shows a faint twelve-sided outline at
3x and none at 1:1, which is the twelve-meridian floor doing exactly what the
freight berth's own lenses already do. Nothing else was backed off; the
pod-corner declaration was
*tightened* during the pass (from 2.36 m to the deck-flush 1.6 m) when the
upper open deck was found to run along the pod wall.

### Suites

`tools/run_affected_suites.sh --jobs 3` over every `*census*`,
`*silhouette*` and `*geometry_budget*` suite, `station_light_overlap_census_test`,
`habitat_spine_*`, `vip_reception_*`, `aft_junction_*`, `jovian_freight_berth_*`,
`shipyard_world_*`, the Jovian, Halyard, Bulwark, Cinder, hero and opponent
suites, `combat_test`, `ship_fitout_batch_test`, `station_expansion_test`,
`outbound_route_clearance_test`, `vertical_slice_test` and `smoke_test`: 184
suites, all passing after the four frozen literals that moved with this pass
were refrozen (`aft_junction_stack_test`, `halyard_crew_transport_test`,
`jovian_freight_berth_test`, `torus_geometry_budget_test`; the Halyard one is
what surfaced the odd-ring rule), except `geometry_census_scenario_test`,
whose four triangle and fingerprint freezes fail with the values printed above
and are the integrator's to refreeze. No `*roster*`, `*mesh_storage*`,
`landing_pad_*`, `coplanar_seam_*` or `station_walkability_*` suite exists
under those names; the freezes those globs were meant to reach live in the
module suites above.

### Why the remaining 46,587 is not here

Stated plainly, because the item asked for 118,333 and this pass delivered
71,746.

After the pass, 128,956 triangles of `TorusMesh` and 80,328 of `SphereMesh`
remain. Of those, the guide lenses (24,000) are at the range their closest
copy is actually seen from; the drone and beacon rings (9,600) and the
lamps (4,608) are at the range's declared approach; and about 80,000 sit on
stock a player walks up to — the pad and apron deck rings, the dock-mast and
garden column collars, the ladder hoops, the Torrent's engine collars and
gear beads, the Jovian's cargo-frame joints, the Aft plot-table rings and
clamps — where the recipe is already the photographed floor and the only
way to take more is to lower a floor that has photographs behind it or the
0.0021 rad tolerance every budget in this project shares. This pass, like the
hero/opponent pass before it, is not willing to do that. The Arrow's 21,000
are owned by another workstream. The remaining headroom is where that pass
left it: the imported hero art (the Torrent's 100,098, the Zenith's 52,686)
and the pilot suit, through their own generators and their own rendered
review.

This is a scene-content measurement plus a rendered-composition check. It is
not a frame-time, GPU-time or VRAM claim, and the software/remote-display
caveats at the top of this document still apply. **No ceiling in this
document has been raised, and the 1,800,000 triangle ceiling is not met.**

## Tenth trim (2026-09-20): the authored-piece index, -202 resident nodes

Phase 10 §2's remaining overrun is the scene tree, not the triangles. Measured
on `7e0d17f1c` with `tools/geometry_census.gd` under fresh private user data,
the resident scene holds **10,593 scene-tree nodes against a 7,000 ceiling —
51% over** — while triangles are 5.3% over. The eight previous trims batched
everything that could be batched without touching an audit contract, and this
document recorded that the next reduction "means restating the ships'
shared-stock resource audits — a deliberate contract change, not a batching
pass". That restatement was authorised, and it is what this pass builds.

The pass takes the resident scene from **10,593 to 10,391 nodes (-202)** and
the Cinder-loaded scene from 11,016 to 10,814, with **zero triangles moved**.
**The node ceiling is still not met**: the scene is 3,391 nodes (48%) over it.
The arithmetic of why the rest is not available is set out at the end, because
the honest figure is a long way short of what the item hoped for, and — as with
the third trim, which expected 379 nodes from `OperationalLattice` and found
38 — the measurement of *why* is the more useful half of this entry.

### The contract upgrade

`AUTHORED_CENSUS_META` already let a module restate its **counts** after a
merge. Both batchers now also carry `AUTHORED_PIECE_INDEX_META`
(`station_dressing_batch_authored_pieces`, `ship_fitout_batch_authored_pieces`),
which restates **identity**: one record per absorbed piece, in authored order,
carrying the piece's authored name, its placement in the batch parent's space,
its own metadata verbatim, its mesh's untransformed bound and surface count,
its visibility and render state, the resolved material of every surface, and —
conditionally — the source `Mesh` resource itself.
`find_authored_piece(search_root, name)` answers with that record, or with the
live node when the piece kept one, so a suite asks one question and gets the
same answer on a batched and an unbatched build; `authored_piece_mesh()` is the
one-line form a resource-sharing audit wants. Retaining the resource is
*stronger* than the `mesh_resource_ids` beside it: an instance id names a
resource that may since have been freed, a reference cannot be anything else.

That index is what allows two refusals to be lifted without weakening an audit.

**Shared stock.** A `*_resource_sharing_test` proves "these N pieces are drawn
from one mesh allocation" by comparing `a.mesh == b.mesh`, and before the index
a merge could only answer that by not happening: it frees the source renderers,
and `a.mesh` afterwards is the merged buffer. The index hands the audit back
the same resource, so the identity it compares is the one it always compared.

**Authored metadata.** It no longer refuses a piece outright, but it constrains
the group: `_metadata_digest()` is part of every group key, so a batch only ever
absorbs pieces whose metadata is identical key for key *and* value for value, it
carries that metadata verbatim onto the batch — with one exception found after
the fact and recorded under *Follow-up* below — and the index records each
piece's own copy. A value that differs splits the group rather than being
averaged into one. `tests/station_dressing_batch_test.gd` and
`tests/ship_fitout_batch_test.gd` assert all of this directly — that two folded
pieces still resolve to one retained `Mesh`, that their placements, bounds and
finishes come back exactly, that a differing metadata value keeps its piece out
of the group, and that a mesh only one folded piece drew is *not* retained.

Retention is deliberately conditional, and that condition is what keeps the
trade honest. A mesh only the replaced piece drew is freed exactly as before. A
mesh that is **shared** — drawn by another renderer — is retained, and that
costs nothing at all, because the merge never had the right to free it. The
census proves the property rather than the intention: `unique_meshes` **falls**
3,058 -> 2,945, and `retained_reachable_unique_materials` is **identical** at
1,014, so the index retains nothing that was not already reachable. What the
ship side does pay is vertex storage: merging N renderers of one cached mesh
stores that geometry N times in the merged buffer while the original stays
alive. That is real, it is bought deliberately for scene-tree nodes — the
budget this scene is 51% over while its triangle count is 5% — and it is stated
here rather than absorbed quietly.

Two refusals were **added**, both found by measurement rather than by reasoning:

* **`KEEP_OUT_META_KEYS`.** Until now *any* metadata refused a piece, and two
  habitat families quietly relied on that: `habitat_spine.gd` sets a marker and
  its comment says outright that the marker is what keeps `StationDressingBatch`
  away. Relaxing the blanket rule folded both, and
  `tools/station_walkability_sweep.gd` immediately reported a **twentieth**
  `walk_through` — a 1.32 m board face merged out of 5 cm plates, reaching into
  the standing capsule of the cells in front of it. The opt-out is now a
  contract (`NO_BATCH_META`) instead of a side effect, and the two legacy
  markers (`crew_berth_roster_piece`, `side_window_frame`) are honoured by name,
  because quietly dropping an authored decision while claiming the pass weakens
  nothing would be exactly the wrong trade.
* **`_manufactures_standing_solid()`.** `_reads_as_walkable_plate` already
  refuses an aggregate that would read as a *floor*; this refuses the other
  shape the same sweep blames. A run of individually short pieces whose merged
  bound crosses the sweep's own 0.4 m piece height for the first time is
  refused, because the air between them is still air. It is scoped to the groups
  this trim newly reaches: re-refusing batches the shipped pass already formed
  costs 136 nodes to re-litigate findings that the trim which introduced them
  already measured clean.

### The roster re-grep

Lifting the two refusals exposed **806 leaf names** that earlier passes never
had to grep, because some other guard had always kept the pass out of them.
Every one went through this roster's own criteria again, sharpened so that a
builder naming the node it is creating is not mistaken for a consumer of it:
the whole name resolved anywhere outside `scripts/`, or on a `scripts/` line
that also resolves a node; a `find_child`/`find_children` glob that matches it;
or a composed lookup where **both halves** of some split of the name are
literals a resolving line joins. **107 names hit and are protected** (65 of them
in both rosters, plus `DockUmbilicalHead02`/`03` added after the fact); the
other 699 fold. Names the shipped pass already folded are excluded from the
re-grep, because re-protecting those would *undo* nodes an earlier trim already
banked.

`*MuzzleLens` is why this re-grep exists rather than being assumed unnecessary.
`HeroShip._ensure_weapon_component_emitters()` counts authored lenses by that
glob and **builds two fallback spheres** when it finds fewer than two, so
folding the Jovian's lenses silently added two nodes and 336 triangles instead
of failing anything. The census caught it because triangles are frozen exactly;
no suite would have.

Two modules were also enrolled in `CONSOLIDATED_DRESSING_MODULES` for the first
time — `VipReceptionSuite` and `StationDefenseEncounter`. Neither was ever
refused on a contract; they had simply never been added. The VIP suite publishes
a frozen render roster, so enrolling it meant **restating** that roster rather
than refreezing it: `get_render_batch_contract()` now adds each batch's authored
row back through `authored_render_census_delta()`, `_render_descendant_count()`
adds `authored_node_delta()`, every published constant is unchanged, and the
contract additionally publishes `live_mesh_instances` so the difference between
what the module built and what the world left standing is visible rather than
inferred. Three assertions in its own suite were restated the same way: the
whole-module sweep's coverage threshold counts what the module allocates; the
threshold wall and floor placements resolve through `find_authored_piece()`; and
a solid batch's colliders are blamed on their authored pieces and additionally
put through `solid_batch_pairing_errors()`, which asks this check's own
question — every collider spanned by geometry drawn inside it, and no vertex
drawn outside every collider — of the merged pair.

### The numbers

Measured with `tools/geometry_census.gd` under fresh private user data, before
on `7e0d17f1c` and after on this branch. Only these six buckets move at all:

| Bucket | Nodes | Renderers | Surfaces | Triangles |
| --- | ---: | ---: | ---: | ---: |
| `ShipyardWorld/StationDefenseEncounter` | 225 -> 151 (**-74**) | 116 -> 42 | 125 -> 65 | unchanged |
| `ShipyardWorld/VipReceptionSuite` | 515 -> 444 (**-71**) | 237 -> 177 | 237 -> 188 | unchanged |
| `HalyardCrewTransport` | 457 -> 427 (**-30**) | 347 -> 317 | 355 -> 340 | unchanged |
| `JovianLightFreighter` | 601 -> 589 (**-12**) | 433 -> 421 | 460 -> 455 | unchanged |
| `ShipyardWorld/JovianFreightBerth` | 826 -> 815 (**-11**) | 354 -> 343 | 406 -> 395 | unchanged |
| `ZenithInterceptor` | 172 -> 168 (**-4**) | 73 -> 69 | 89 -> 86 | unchanged |
| **Resident total** | **10,593 -> 10,391 (-202)** | **5,557 -> 5,366** | **6,000 -> 5,857** | **1,896,055 unchanged** |

Everything else in the census is **identical on both sides**: 1,896,055 resident
triangles, 341 lights of which 20 cast shadows, 54 particle systems, 711
bound-phase and 1,014 retained materials, 7 shaders, 39 textures / 85,977,416
bytes, 79,709 text triangles across 43 signs, and no drawn `MultiMesh` copy
moved. `unique_meshes` falls 3,058 -> 2,945 because a merged renderer replaces
several privately owned box meshes with one, and surfaces fall because pieces
that shared a finish with a sibling now share one submission — a draw-call
reduction, not lost geometry.

`tests/geometry_census_scenario_test.gd` measures the same scene with its own
fresh private user data and reads **exactly the same node count** here, which
the previous two freezes could not say. Its six frozen literals are refreshed in
this branch and now read:

```
GEOMETRY_CENSUS_RESIDENT_FINGERPRINT: 9394d9274d15c7b7e3ef159c4a86d25a498ab012456947131116f351f792015f
GEOMETRY_CENSUS_RESIDENT_GEOMETRY: { "total_triangles": 1896055, "total_mesh_instances": 5366, "total_surfaces": 5857, "unique_meshes": 2945 }
GEOMETRY_CENSUS_RESIDENT_RESOURCES: { "bound_phase_unique_materials": 711, "retained_reachable_unique_materials": 1014, "lights": 341, "nodes": 10391, "unique_shaders": 7, "unique_textures": 39, "texture_bytes": 85977416, "particle_systems": 54 }
GEOMETRY_CENSUS_LOADED_FINGERPRINT: 2073da183f95141d6ecdc9b6f8945dbcf3696b0e7705625e68d08f7d3c0f3fcc
GEOMETRY_CENSUS_LOADED_GEOMETRY: { "total_triangles": 2030189, "total_mesh_instances": 5575, "total_surfaces": 6066, "unique_meshes": 3085 }
GEOMETRY_CENSUS_LOADED_RESOURCES: { "bound_phase_unique_materials": 753, "retained_reachable_unique_materials": 1061, "lights": 368, "nodes": 10814, "unique_shaders": 7, "unique_textures": 39, "texture_bytes": 85977416, "particle_systems": 54 }
```

The loaded-minus-resident Cinder delta stays +134,134 triangles, +209 renderers,
+209 surfaces, +140 unique meshes, +27 lights and +423 nodes: nothing streamed
changed.

`tests/station_triplanar_material_test.gd` is refrozen 1,937 -> 1,926 mapped
station surfaces. The 0.22 and 0.28 scale columns do not move, no previously
mapped surface was removed and no new scale was introduced; eleven surfaces
that were submitted separately are submitted once by the merged renderer that
stands in for them, at the same 0.30 m scale with the same recipe.

### Probes

`tools/station_walkability_sweep.gd` is **byte-identical end to end** — the same
82 surfaces, 135,137 cells, 39,939 blocked, 19 findings,
`invisible_blocker`/`choke`/`gap` all zero, the same per-module split and the
same 19 blamed paths — because no collision shape moved and the two new refusals
above exist precisely to keep it that way. The twentieth finding this pass
produced before those refusals were added is quoted in full in the contract
section; it is the reason they exist.

`tools/coplanar_seam_audit.gd` is **not** identical, and the movement is the
direct consequence of folding more: pieces that were two renderers presenting
coplanar faces to each other become internal faces of one mesh.

| | before | after |
| --- | ---: | ---: |
| reported findings | 1,334 | 1,245 |
| coplanar pairs examined | 3,789 | 3,645 |
| back-to-back excluded | 1,338 | 1,335 |
| interior excluded | 45 | 45 |
| occluded excluded | 249 | 249 |
| declared `coplanar_by_design` | 28 | 20 |
| families | 382 | 366 |
| renderer placements | 5,142 | 5,035 |
| unique meshes planed | 2,463 | 2,399 |

Compared as a **set** rather than as counts, **91 findings disappear and 2 appear**. Both new ones are
the Zenith's port and starboard muzzle bore against the airframe batch that now
surrounds them, at screen scores 0.00107 and 0.00076 — 0.35% of the worst seam
in the scene, whose score is **0.302121 on both sides, unchanged**. No seam class
regressed, and the `interior` and `occluded` exclusions are identical. The
`coplanar_by_design` declarations that no longer match are declarations whose
*pair no longer exists*, both faces having gone into one mesh.

`tools/camera_intrusion_audit.gd` reports the **same 21 finding lines and the same 31 counted
findings** on both sides, and the **same six `camera_sphere_in_own_hull`
findings at the same depths** against the Jovian's and the Halyard's own
envelopes. Grouped by target, the only column that moves is the exterior target
range: `TargetDrone01` 7 -> 9, `TargetDrone03` 5 -> 2, `TargetDrone04` 2 -> 2,
with one `camera_sphere_in_world_collision` appearing at a single sample
against an anonymous range body at (14.34, 0.2, -66.3), and the drone depths
moving in the third decimal (0.800 -> 0.794, 0.641 -> 0.637, 0.537 -> 0.534).
That is this probe's documented one-group range-drone variance and nothing
else: no finding outside that group changed, and the byte-identical walkability
sweep is the independent evidence that no collision body was created, removed
or moved. `renderers` falls 5,989 -> 5,872, which is the trim.

### Rendered evidence

Ten fixed gameplay viewpoints, at 1280x720, on **both renderers**, covering
every bucket this pass touches plus two controls. Camera transforms are literal
world coordinates rather than resolved from nodes, so a folded node cannot move
a viewpoint between the two sides of a pair, and every clock-driven
presentation is sought to t = 0 and the tree paused before any frame is taken.
The views are the station defence encounter's corridor, VIP reception, the
habitat spine, the freight berth apron, the fleet dock comb, the Cinder
expansion berths, the Halyard crew cabin, the Jovian freighter at its berth,
the Zenith at its berth, and the operational lattice across the station — the
last of which, plus `habitat_spine`, this pass **does not change a single node
in**, so both read as controls.

Each side was captured **twice**, so every before/after cell sits against a
same-build repeat on *its own* side rather than against one floor borrowed from
the other. Captures, 8x-amplified difference images and the harness
(`.godot/node_trim_capture.gd`, untracked, modelled on `arrow_access_root.gd`)
are under
`/root/.cache/mudds-shipyards/agent-node-trim/captures/{fp,compat}-{before,before2,after,after2}`
and `.../captures/diff/`. Figures are mean absolute RGB difference and the
share of pixels whose largest channel moves by more than 8, all of 255. Both
renderers report `llvmpipe`: the WSL d3d12 path segfaults inside
`libnvwgf2umx.so` when Godot's GL compatibility backend loads it, so that
renderer is captured on the software rasteriser, and Forward+ falls back to
llvmpipe on this box regardless.

#### Forward+

| View | before->after mean | >8 | max | floor(before) | floor(after) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fleet_dock_comb` | 0.289 | 0.975% | 96 | 0.461 (1.676%) | 0.190 (0.623%) |
| `fleet_expansion_berths` | 0.550 | 2.068% | 122 | 0.782 (3.161%) | 0.592 (2.239%) |
| `habitat_spine` | 0.614 | 1.954% | 93 | 0.541 (1.564%) | 0.613 (2.190%) |
| `halyard_cabin` | 0.073 | 0.031% | 98 | 0.017 (0.025%) | 0.024 (0.033%) |
| `jovian_freight_berth` | 0.944 | 3.667% | 214 | 0.816 (2.997%) | 0.762 (2.897%) |
| `jovian_freighter` | 0.858 | 3.273% | 114 | 0.693 (2.561%) | 0.677 (2.539%) |
| `operational_lattice_control` | 0.651 | 2.420% | 146 | 0.816 (3.401%) | 0.686 (2.781%) |
| `station_defense` | 0.176 | 0.403% | 169 | 0.229 (0.486%) | 0.174 (0.372%) |
| `vip_reception` | 0.535 | 1.719% | 173 | 0.661 (1.980%) | 0.472 (1.437%) |
| `zenith_interceptor` | 0.954 | 3.549% | 164 | 1.524 (5.790%) | 0.678 (2.470%) |

#### Compatibility

| View | before->after mean | >8 | max | floor(before) | floor(after) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fleet_dock_comb` | 0.046 | 0.001% | 11 | 0.040 (0.001%) | 0.021 (0.000%) |
| `fleet_expansion_berths` | 0.041 | 0.059% | 234 | 0.067 (0.069%) | 0.018 (0.026%) |
| `habitat_spine` | 0.018 | 0.053% | 130 | 0.002 (0.000%) | 0.001 (0.000%) |
| `halyard_cabin` | 0.087 | 0.000% | 2 | 0.000 (0.000%) | 0.000 (0.000%) |
| `jovian_freight_berth` | 0.489 | 1.728% | 255 | 0.185 (0.365%) | 0.065 (0.141%) |
| `jovian_freighter` | 0.018 | 0.036% | 121 | 0.035 (0.110%) | 0.011 (0.020%) |
| `operational_lattice_control` | 0.140 | 0.367% | 222 | 0.200 (0.314%) | 0.072 (0.175%) |
| `station_defense` | 0.178 | 0.188% | 227 | 0.228 (0.218%) | 0.089 (0.130%) |
| `vip_reception` | 0.958 | 1.906% | 42 | 0.705 (0.677%) | 0.710 (1.223%) |
| `zenith_interceptor` | 0.395 | 0.038% | 75 | 0.320 (0.025%) | 0.227 (0.012%) |

On **Forward+**, which the desktop build ships, **eight of the ten pairs are at
or below the higher of their own two floors**, including both controls
(`operational_lattice_control` 0.651 against floors of 0.816 and 0.686;
`habitat_spine` 0.614 against 0.541 and 0.613). The two that sit above are
`jovian_freight_berth` (0.944 against 0.816) and `jovian_freighter` (0.858
against 0.693), each about 1.2x its own before-side floor. `halyard_cabin` is
0.073 against a near-zero floor, three times a floor of 0.017 and 0.03% of a
channel in absolute terms. Read as images rather than as numbers, every
Forward+ difference — including the same-build repeats — is the identical
pattern: a one-pixel outline on every silhouette edge in the frame, on objects
this pass never touched as much as on the ones it did. That is the renderer's
own edge jitter, not a geometry change; a moved, resized or missing mesh shows
as a filled region, and none of the twenty images has one.

On the **Compatibility** fallback the floors are an order of magnitude quieter,
which makes it the discriminating renderer, and there **six of ten pairs are
still inside their band**, including both controls. Three of the four that are
not are small: `habitat_spine` 0.018 against 0.002 (0.007% of a channel),
`zenith_interceptor` 0.395 against 0.320, and `halyard_cabin` 0.087 against
0.000 with a **maximum channel movement of 2 of 255** — a uniform
sub-threshold luminance shift whose share of pixels over 8 is exactly zero. The
fourth, `jovian_freight_berth` at 0.489 against 0.185, is the largest number on
the whole board and was inspected rather than averaged away: its difference
image is a set of broad soft glows on lit surfaces — the mast, the crate stack,
the sign face, the deck pool — plus one small service craft caught at a
different point on its route near the top of frame. That is the per-object
light-list reassignment this document has recorded for the Compatibility
fallback since the second trim (a merged bound changes which eight lights reach
an instance) together with the mover variance the ninth trim recorded.
`vip_reception` (0.958 against 0.705) is the same effect in its purest form: a
diffuse low-amplitude wash across the whole facade, maximum 42 of 255, with no
silhouette outline anywhere in it.

**No pair on either renderer shows missing geometry, a moved silhouette, a
changed material or a changed placement.** Nothing was backed out.

### Suites

`tools/run_affected_suites.sh --jobs 2 --timeout 600` over every `station_*`,
`ship_fitout*`, `*allocation*`, `*census*` and `*resource_sharing*` suite plus
`habitat_spine_test`, `aft_junction_stack_test`, `central_berth_hero_test`,
`vip_reception_suite_test`, `jovian_freight_berth_test`,
`upper_operations_allocation_test`, `vertical_slice_test`,
`long_session_soak_test`, `lifecycle_phantom_geometry_test`,
`main_reentry_quality_test` and `smoke_test`: **83 suites, 4,250 pass
assertions, zero failures, overall PASS**, with the source manifest matching
and the import cache stable. No `*roster*` suite exists under that name; the
freezes that glob was meant to reach live in the module suites above.

All fourteen `*_resource_sharing_test` suites pass unchanged — the
shared-stock families they prove are either still their own nodes or reachable
through the index, and none of them had to be edited. Six suites moved and each
one was **restated rather than relaxed**:

* `station_dressing_batch_test` 30 -> 36 assertions and
  `ship_fitout_batch_test` 23 -> 26, both gaining direct proofs of the index:
  that two folded pieces resolve to one retained `Mesh`, that their placements,
  bounds and finishes come back exactly, that a differing metadata value keeps
  its piece out of the group, that the opt-out key is honoured, and that a mesh
  only one folded piece drew is not retained.
* `vip_reception_suite_test` 169 assertions, with the three restatements
  described above.
* `station_navigation_graph_test`, `station_route_registry_integration_test`
  and `station_topology_evidence_test` went red when `FleetDockComb`'s frozen
  renderer/batch/copy/submission roster drifted, and are green again because
  the two umbilical heads that caused it are protected. That failure is worth
  recording: the comb's roster is read by an *independent* registry built after
  the dressing pass has run, so a drift there reaches three suites that never
  mention geometry.
* `geometry_census_scenario_test` and `station_triplanar_material_test` are
  refrozen, as set out above.

`lifecycle_phantom_geometry_test` deserves a note because it failed twice
during this pass and passes here: its light-flash contract samples a
time-varying series over `OpenLaunchSpine`, a bucket with **zero node delta**,
and it fails the same way on the untouched baseline (203 of 204 assertions,
one `reduced-flash contract` diagnostic). It is timing-sensitive, not a
regression of this pass, and it passes in the closing run.

### Follow-up (2026-09-20): two defects the suite scope above missed

The scope quoted under *Suites* — `station_*`, `ship_fitout*`, `*allocation*`,
`*census*`, `*resource_sharing*` and eleven named suites — contains no
`halyard_*` suite, no `jovian_light_freighter_test` and no
`ship_surface_winding_test`. The next full matrix returned **16 failures**, all
green on the previous checkpoint. None of them was a lost triangle, but two
were real defects and only one was a freeze.

**A claim about one mesh is not a claim about the merge.** Carrying a group's
metadata verbatim onto the batch is right for a key that describes the *thing*
a piece is and wrong for one that describes the *geometry* of the renderer it
sits on. `closed_loft_hull` is the second kind: it tells
`tests/ship_surface_winding_test.gd` that the mesh surrounds its own AABB
centre, so that centre is independent evidence of which side of a triangle
faces out. The trim newly admits pieces carrying it, and ten correctly wound
engine housings and pylons merged into one buffer surround no common point —
the centre lands in the air between them. The suite read 816 of 2,896 Halyard
and 127 of 272 Zenith triangles as backwards on a batch in which **every
triangle is wound exactly as authored**: the normal-agreement sweep beside it
scores 0 backwards on the same meshes, and every placement in both batches has
determinant +1. `ShipFitoutBatch.SINGLE_MESH_CLAIM_META` now withholds that
class of key from the aggregate, and the suite scores each folded piece's own
triangles from its own interior through the index — which needed one addition
to the record, `index_ranges`, naming the `{surface, index_start, index_count}`
runs a piece occupies in the merged buffer. Coverage is unchanged at 52 closed
volumes and all 52 score 0 backwards. This is the general shape of the risk the
index carries: it restates identity faithfully, and a *claim* restated onto a
node that cannot support it is not identity.

**Handedness was judged from the wrong transform.** `_merge` applies the
composed placement while the only guard read
`visual.transform.basis.determinant()`, the renderer's own local basis. In
`StationDressingBatch` the solid path merges `<body>/Mesh` at
`body.transform * mesh.transform`, so a mirror the authoring body carries — the
usual way a starboard copy of a port part is written — was invisible to that
guard and would have merged inside out with unchanged winding, which backface
culling draws as a hole. Both batchers now settle handedness in `_merge` from
the composed placement, and a mirrored placement is merged **correctly** rather
than refused: index order reversed, tangent binormal sign flipped. Nothing in
the shipped scene folds a mirrored piece today — the Halyard's two negatively
scaled renderers are refused on other grounds and its measured allocation is
identical either way — so the path is pinned by a direct fixture in the winding
suite rather than left to content.

**One audit lost its reach, and was restored rather than refrozen.** The
Jovian's ground-support collision census walked `visual.get_children()` for the
renderers drawing its leg stock, so the six sections the trim folded stopped
being measured: it reported 10 of 16 pieces **with no mismatches**, which is
the quiet failure this index exists to prevent — everything still visible was
exactly right. Resolving through `authored_piece_index()` puts it back at 16 of
16 with nothing refrozen.

**One roster genuinely moved.** `HalyardCrewTransport`'s exterior roster is a
live-node count that does not restate itself through `AUTHORED_CENSUS_META` the
way the Arrow's and the VIP suite's do, so eighteen more folded renderers move
it: descendants 132 -> 114, `MeshInstance3D` 115 -> 97, drawn copies 201 -> 183,
geometry submissions 130 -> 115, unique meshes 92 -> 79; MultiMesh batches (9)
and unique materials (18) unchanged. Six suites had duplicated those literals
and move with it. The lesson for the next trim is the scope, not the roster: a
node trim must run the suites of every craft and module it touches, not only
the ones whose names contain the words this pass is about.

### Why 3,391 nodes are still over, and where they are

Stated plainly, because Phase 10 §2 wants 3,593 nodes and this pass delivered
202. The arithmetic, simulated against the live tree with the pass's own
grouping, chunking and refusal rules:

* **1,481 nodes sit behind the two protected-name rosters.** A run of the same
  rules with every protected name ignored folds 1,937; the rules as shipped
  reach 202, and 456 more are reachable but unreached (below). Those rosters
  hold names each of which an earlier trim proved is resolved by something — a
  test path, a `find_children` glob, a composed lookup, a doc roster. The
  re-grep in this pass covers the names the relaxations *newly* reach, and it is
  deliberately **not** run over the existing entries: a sharpened grep says 56
  of them look free, and reading them shows the grep is wrong about at least
  `RegistryBerthTile02` (resolved by formatted name inside the pod's own render
  contract) and `PortElevons` (composed at runtime by
  `tests/zenith_interceptor_test.gd`). Unprotecting roster entries on a
  heuristic that is demonstrably wrong twice in a sample of two is how a pass
  weakens an audit by accident. Reaching those nodes means migrating each
  consumer to `find_authored_piece()` one family at a time — which the index now
  makes possible, and which is a per-family job rather than a sweep.
* **`OperationalLattice` gives 55, and this pass does not take them.** This is
  the bucket the item named and the index was built partly for it, so the
  refusal is measured rather than assumed. Every one of those nodes is inside a
  `StationOperationsActivity`, whose `_built_mesh_contracts_are_live()` re-checks
  each built renderer's mesh resource id, **storage fingerprint**, class, AABB
  and bound `material_override` at its authored path, and whose
  `_built_presentation_hierarchy_is_live()` requires live-node-set equality by
  instance id. The index can restate both — but only by retaining **every**
  source mesh, not just the shared ones, because a storage fingerprint cannot be
  computed from a freed resource. That inverts the trade the rest of this pass
  is built on: instead of retaining nothing new and dropping 113 unique meshes,
  the lattice would retain every source mesh *and* add a merged mesh per batch.
  Spending mesh storage and unique-mesh count to buy 38-55 nodes is the opposite
  of what Phase 10 §2 asks for, and
  `tests/station_operations_activity_mesh_sharing_test.gd` freezes 66
  submissions / 36 retained meshes / 79 drawn copies keyed by relative
  `NodePath`, all of which would move. The remaining lattice subtrees are
  unchanged from the third trim's measurement: `ActivityCollision` (71 nodes) is
  collision authority, `ServiceAgents` (85) and `Ambience` (13) are script-owned
  movers and emitters, the four `StationStructuralServiceDressing` instances
  (177) belong to a component outside this pass's files, and 90 renderers carry a
  hard near-camera `visibility_range_begin` guard that triggers on the
  *instance's* bounding volume, so merging even two of them moves the distance at
  which each disappears.
* **The Torrent and the four range opponents give about 126, and have no
  consolidation call at all.** `TorrentInterceptor` (62), `RangeOpponent` (18),
  `StandoffPicket` (17), `CourierRunner` (17) and the two `WingSkirmisher` craft
  (12 each) never run `ShipFitoutBatch`. Adding the call is a small change;
  restating `range_opponent.gd`'s `referenced_visual_resource_identity_count`
  allocation audit and the Torrent's imported-art roster is not, and neither was
  in scope beside the contract work. This is the largest cheap remainder and the
  obvious next pass.
* **About 275 more are reachable under the rules exactly as they now stand** —
  the Halyard's cabin (58 simulated), `CentralBerthServiceLine`'s solid runs
  (34), `FleetExpansionProductionBinding` (33), `LandingPad` (27),
  `HabitatSpine` (49, of which the keep-out markers correctly refuse most) and a
  long tail. The simulation over-counts these by roughly half, because it does
  not model the walkable-plate refusal, the triangle-parity guard,
  `PROTECTED_FITOUT_CONTAINERS` or the keep-out markers.
* **Everything the earlier passes already refused** stays refused: collision,
  interaction, evidence and lifecycle authority, scripts, groups, node-driven
  signals, children, `.tscn`-owned nodes, live script references, live
  `PrimitiveMesh` stock the geometry-budget sweep still re-tessellates,
  camera-distance LOD bands, the 16 m locality cap, the walkable-plate refusal
  and the new standing-solid refusal.

The resident node count is **10,391** against 7,000 and remains **48% over**.
**The node ceiling is not met.** This is a scene-content measurement plus a
rendered-composition check; it is not a frame-time, GPU-time or VRAM claim, and
the software/remote-display caveats at the top of this document apply — both
renderers here were captured on llvmpipe, because the WSL d3d12 path segfaults
inside `libnvwgf2umx.so` when Godot's GL compatibility backend loads it. **No
ceiling in this document has been raised.**

## Bevel pass (2026-09-21): curved and bevelled authored geometry, +3,808 resident triangles

Every trim above this line removes geometry. This one adds it, which is why it
needed a budget stated before it started rather than measured afterwards:
**no more than +4,500 resident triangles** (0.24% of the 1,907,275 the scene
was frozen at, 0.25% of the 1,800,000 ceiling), and no movement in unique
meshes, surfaces, drawn copies or any AABB. Measured with
`tests/geometry_census_scenario_test.gd` under fresh private user data, the
pass lands at **+3,808 (1,907,275 -> 1,911,083, +0.20%)**. **The ceiling is
still not met**: the scene was 5.96% over it and is now 6.17% over.

ROADMAP Phase 2 asks for the bounded Torrent/central-berth realism treatment —
rolled shoulders, eased transitions, fillets at load-bearing junctions — to
reach the remaining station and ships. The geometric half of that item was
still open: the station material-family work before it changed bindings only.

### What was still flat, and why almost none of it was reachable

A live probe of every `BoxMesh` renderer in the production scene found 387 of
them, and the first useful result was how few were both *visible* and
*chamferable*:

* **`salvage_terrace.gd`.** Its six deck and ramp slabs share **one unit
  `BoxMesh` scaled by each renderer's transform**, and its nineteen safety-rail
  renderers are `visible = false` — the rails a player sees are the 126-copy
  `RailDetailBatch`, also a scaled unit box. A chamfer cannot ride a
  non-uniform instance scale: on a 12 x 0.30 x 8 deck a shared 38 mm chamfer
  would come out 456 mm wide in x and 11 mm in y. Chamfering the decks means
  six mesh resources where there is one, against a contract
  (`tests/salvage_terrace_test.gd`, `mesh_resource_allocations 1`, plus a
  dedicated sharing suite) that an earlier pass established deliberately — to
  buy a 27 mm edge roll that stands behind a 1.3 m safety rail on every
  approach. **Left flat.**
* **`observation_logistics_spur.gd`.** Thirteen of its batches share one unit
  box the same way, and almost every per-piece `_box` call in it *frees its own
  renderer* immediately after building the collision body — the visible
  geometry is the MultiMesh batches. What is left with a real per-size mesh is
  `ObservationBench` and five light lenses. **Left flat**: there is nothing
  there to treat.
* **`fleet_expansion_berths.gd`.** The one station module whose visible flat
  stock is per-piece meshes. **Treated.**
* The other eleven station module builders are already fully on
  `StationSurfaceKit`. `jovian_freight_berth.gd` keeps its own local chamfer on
  a rationale written into the file; that is an intentional exception, not a
  gap.
* **`arrow_recon_ship.gd`.** The Arrow overrides `HeroShip._box` with a raw
  `BoxMesh`, and has since before the base builder chamfered. Because the
  override is virtual it also intercepts the **inherited** cockpit interior, so
  the Arrow alone shipped 61 unchamfered renderers — sills, pressure walls,
  console keys, seat rails, saddles, end shields, canopy rails and seals,
  emitter mounts, window and duct recesses — while every sister craft's
  identical parts were chamfered. **Treated.**

### The rule that made it affordable

`ShipChamferedStock`'s tangent chamfer costs 44 triangles against a primitive's
12; the authored two-segment roll costs 108. Which one a part gets is decided
by `rolled_edge_is_resolvable`, and on *structure* the existing bevel rule
picks the expensive one for the wrong reason: at 0.22 of the shortest side a
0.6 m walkway deck earns a 0.132 m chamfer, which is not an edge on a deck
plate but a 13 cm nosing that visibly changes its section — and, being over the
gate, costs 96 extra triangles instead of 32.

`structural_chamfer_for_size` answers both at once with the answer a fabricator
would give: **a chamfer is a tool width, not a proportion of the stock.** Large
structure is held at `largest_resolvable_chamfer()` — 38.2 mm, this project's
own calibrated width, the point at which one facet and a two-segment roll stop
being distinguishable at 1.5 m — and only stock too thin to carry that keeps
the proportional rule, which is the case where the proportion *is* the physical
answer. A 24 m blast datum and a 1.2 m frame leg come off the same edge tool.

### The numbers

| resident row | before | after | delta |
| --- | ---: | ---: | ---: |
| triangles | 1,907,275 | 1,911,083 | **+3,808** |
| mesh renderers | 5,366 | 5,350 | -16 |
| surfaces | 5,895 | 5,884 | -11 |
| unique meshes | 2,945 | 2,929 | -16 |
| scene nodes | 10,409 | 10,393 | -16 |
| bound / retained materials | 716 / 1,019 | 716 / 1,019 | 0 |
| lights, shaders, textures, texture bytes, particle systems | - | - | all identical |

The loaded scenario moves by exactly the same amounts (2,060,681 ->
2,064,489), the streamed Cinder bucket is byte-identical, and every
loaded-minus-resident delta holds at its frozen value — which is what says the
pass reached only the station-resident scene.

The triangles break down as +1,024 on the station (19 single renderers at +32
each, 11 batched underframe posts, 2 batched launch rails) and +2,784 on the
Arrow, whose 61 renderers take the fleet rule and so land on 44 or 108
depending on their own chamfer width.

**The -16 is a consequence, not a decision, and it is entirely the Arrow.**
`ShipFitoutBatch` never folds live `PrimitiveMesh` stock, because the tree-wide
geometry-budget sweep re-tessellates exactly those renderers and baking one
into a merged `ArrayMesh` takes it out of that sweep. Sixteen Arrow renderers
were refused on that ground alone; once they stopped being primitives the
existing batcher folded them on its existing rules. A direct roster probe of
the two touched subtrees attributes it exactly:

| subtree | nodes | mesh instances | MultiMesh | unique meshes | surfaces |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ArrowReconShip` before | 322 | 244 | 2 | 195 | 251 |
| `ArrowReconShip` after | 306 | 228 | 2 | 179 | 240 |
| `FleetExpansionBerths` before | 105 | 21 | 7 | 25 | 31 |
| `FleetExpansionBerths` after | 105 | 21 | 7 | 25 | 31 |

### Envelopes, and what did not move

The chamfer preserves the authored AABB exactly — every face plane is
untouched and each chamfer endpoint lies on one — so no collider, interaction
area, marker, route or published envelope moves. That is measured rather than
asserted:

* **`tools/station_walkability_sweep.gd` is byte-identical.** 82 surfaces,
  135,137 cells, 39,939 blocked, 19 findings (0 invisible blockers, 19
  walk-throughs, 0 chokes, 0 gaps), 345 lanes measured, and all twelve reported
  lane widths and all nineteen finding rows unchanged to the node path.
* `tests/station_walkable_area_census_test.gd` passes unmoved, which freezes
  the station's walkable envelope in m2.
* The fleet expansion module's own access audit still reports
  `gross_horizontal_m2 57.399999 / unique_horizontal_m2 55.399999`.

Four in-builder audits and five test assertions that read `BoxMesh.size` now
read the drawn mesh's `get_aabb().size`. That is the number the collider and
the walkable census actually have to agree with, it is exactly as strict, and
`fleet_expansion_berths.gd` already used that reasoning for its MultiMesh
envelopes ("what has to match is the *drawn envelope*, not the mesh class").

### The seam audit, which is not identical

`tools/coplanar_seam_audit.gd` moves, in two modules, and the movement is worth
setting out because the headline count goes the *wrong* way while the
physically meaningful number goes the right way.

| | before | after |
| --- | ---: | ---: |
| reported pairs | 1,245 | 1,254 |
| back-to-back / buried / declared | 1,316 / 293 / 20 | 1,316 / 293 / 20 |
| distinct renderer families | 366 | 362 |
| total flush overlap | 285.007 m2 | 283.693 m2 |
| `ArrowReconShip` | 29 pairs, 1.953 m2 | 25 pairs, 1.827 m2 |
| `ShipyardWorld/FleetExpansionProductionBinding` | 77 pairs, 34.639 m2 | 90 pairs, 33.450 m2 |

Every other module row is unchanged. The two movements have different causes
and both are the ones this pass is allowed to make.

**The expansion berths gain 13 reported pairs inside the *same* families.** No
new renderer pair appears there at all — the family set changes only on the
Arrow. A chamfered box presents 26 planar faces to the pairwise test where a
primitive presented 6, so one unchanged renderer contact is now enumerated
across more and smaller polygons. The area of that contact *fell* by 1.19 m2,
because the chamfer pulls each face plane back from the join. The two worst
families in the module are the same two before and after, and both improve:
`BomberBerthLeg/Surface` against `BomberBoardingLeg/Surface` goes 0.13293 x4
3.200 m2 -> 0.12800 x9 3.024 m2, and `CargoTrunkLeg/Surface` against
`CargoBoardingLeg/Surface` goes 0.04379 x3 2.200 m2 -> 0.03995 x8 2.112 m2.

**Seven Arrow families disappear and three appear.** Three of the new ones are
the same contact re-attributed to the local `FitoutRenderBatch01` the folded
renderers went into (`CockpitFloor` against `PortSeatRail`, and the two escape
pods' `SeparationClampBed` against `PodIdentityStripe`). The other **four are
seams that genuinely stopped existing**: `PrimaryFlightDisplay` against
`DisplayBezelBottom`, `PortConsoleKey02` against `ThrottleGate`, and both
`RecessedGraphiteMount` against `LightPulseBarrel`. In each case two faces that
had been flush are now a chamfer and a face, so there is no coplanar overlap
left to report.

### Rendered evidence

Twelve fixed viewpoints at **1280x720 on both renderers**, each parked at the
range a player actually stands at from a piece this pass altered: three walking
the pedestrian access decks, one under the underframe, one on the dock 04 crane,
two on the dock 05 ordnance gantry and blast datum, two on the dock 06 launch
frame and rails, and three on the Arrow — two seated in the cockpit and one
walk-up on the pad. Camera transforms are literal world coordinates, so a
folded node cannot move a viewpoint between the two sides of a pair. Temporal
anti-aliasing and MSAA are both off, because a chamfer band is a geometric edge
and a resolve that changes frame to frame would put the floor above the signal.

Frames, harness (`tests/capture_station_bevel_pass.gd`) and 8x-amplified
difference images are under
`/root/.cache/mudds-shipyards/agent-bevel/captures/{before,after,afterrepeat}_{forward_plus,gl_compatibility}`
and `.../captures/diff_*`. Each side was captured twice on the *same* build so
the before/after cell sits against its own noise floor. Figures are the share
of pixels whose largest channel moves by more than 2, and the mean absolute RGB
difference, of 255.

Both renderers report `llvmpipe`. The d3d12 Gallium path cannot open a
GLX/EGL context under Xvfb on this box (`glx: failed to create drisw screen`,
then `EGL version is too old! 1.0 < 1.4`), which is the same limitation the
tenth trim recorded. **These are software-rasteriser frames; they establish
what the geometry looks like, not what it costs.**

| View | compat before->after | compat floor | fp before->after | fp floor |
| --- | ---: | ---: | ---: | ---: |
| `01_cargo_trunk_walkway` | 1.146% / 0.223 | 0.000% / 0.000 | 40.17% / 5.651 | 39.90% / 5.576 |
| `02_cargo_boarding_leg` | 1.241% / 0.336 | 0.004% / 0.002 | 67.48% / 7.848 | 67.30% / 7.620 |
| `03_bomber_berth_leg` | 0.879% / 0.286 | 0.007% / 0.002 | 62.57% / 8.091 | 62.53% / 8.061 |
| `04_access_underframe` | 1.713% / 0.720 | 0.065% / 0.017 | 59.04% / 7.451 | 58.50% / 7.076 |
| `05_cargo_crane` | 0.141% / 0.081 | 0.000% / 0.000 | 74.64% / 12.284 | 74.64% / 12.264 |
| `06_blast_datum` | 0.559% / 0.254 | 0.255% / 0.123 | 39.89% / 6.968 | 39.88% / 6.939 |
| `07_ordnance_gantry` | 0.434% / 0.275 | 0.014% / 0.005 | 65.46% / 7.661 | 65.45% / 7.584 |
| `08_launch_frame` | 0.268% / 0.106 | 0.014% / 0.005 | 50.20% / 7.904 | 50.20% / 7.896 |
| `09_launch_rail_walkup` | 0.185% / 0.080 | 0.002% / 0.000 | 55.14% / 7.219 | 55.12% / 7.193 |
| `10_arrow_cockpit` | 0.947% / 0.359 | 0.156% / 0.101 | 81.32% / 7.402 | 81.29% / 7.303 |
| `11_arrow_cockpit_sill` | 2.089% / 0.908 | 0.176% / 0.160 | 91.70% / 11.442 | 91.49% / 10.954 |
| `12_arrow_walkup` | 0.943% / 0.319 | 0.733% / 0.235 | 58.35% / 7.905 | 58.35% / 7.796 |
| **mean** | **0.879% / 0.329** | **0.119% / 0.054** | **62.16% / 8.152** | **62.05% / 8.022** |

**Read the compatibility column only.** Forward+ on this software rasteriser
has a 62%-of-pixels noise floor — its before->after figure is inside its own
same-build repeat on every single view, so for this renderer the per-pixel test
carries no information about this change. What the Forward+ frames do
establish is that the scene builds and renders correctly on that path; they are
not a measurement. On `gl_compatibility` the floor is 0.119% and the change is
0.879%, about seven times it, and it is concentrated exactly where a chamfer
should be: on edges.

### The honest verdict, from the frames

**Where it reads, it reads clearly.** The strongest view is
`11_arrow_cockpit_sill`, the cockpit side-console corner about 0.6 m from the
pilot's eye. Before, the pale top face meets the dark side face on a single
zero-width line and the part reads as a shaded primitive. After, a chamfer band
runs the length of that corner carrying a bright specular highlight that
brightens toward the near end, and a second softer chamfer picks up the lower
edge. It is the difference between a box and a machined console, the broad
shape and silhouette are identical, and it shows at 1:1. `04_access_underframe`
is the station equivalent: the gold underframe chord's lower boundary gains a
distinct intermediate tone where it previously went straight from lit face to
dark face.

**Where it does not read, it does not.** `05_cargo_crane` (0.141%),
`09_launch_rail_walkup` (0.185%) and `08_launch_frame` (0.268%) are barely
above their floor, and magnifying `03_bomber_berth_leg` 5x on its hottest
window shows a support post whose new corner is, honestly, not visible: a
38 mm chamfer at 12 m is under a pixel. Roughly 860 of the 3,808 triangles went
to structure that does not resolve at the distance these viewpoints frame it
from. They are kept for two reasons — the apron is walkable, so the crane,
gantry and launch frame *can* be approached much closer than these frames
stand, and a module whose big structure is chamfered and whose bigger structure
is not would read as an inconsistency rather than as a saving — but the frames
do not demonstrate a benefit at these ranges and this document is not going to
claim one.

**No broad shape, silhouette, published envelope or composition changes on any
of the twenty-four frames.** That was the constraint and the frames hold it.

### Suites

`fleet_expansion_*` (11), `arrow_*` (9), every `station_*` (46 plus the 7 under
`tests/audio/`), every `*silhouette*` (15), every `*census*` (5), `hero_*`,
`vertical_slice_test`, `smoke_test`, `tow_tractor_test` — 96 suites at
`--jobs 3`, 4,695 pass assertions, all green except
`geometry_census_scenario_test`, refrozen here from its own printed lines and
green afterwards. `tests/station_surface_playability_test.gd` is not in the
matrix master list (it is a package probe) and was fixed and run by hand.

**No ceiling in this document has been raised, and no native-hardware or
human-review gate is claimed.**
