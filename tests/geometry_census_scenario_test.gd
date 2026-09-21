extends SceneTree

## Focused production proof that the geometry/material census cannot mix the
## resident station baseline with one streamed Cinder generation. Run with fresh
## private user data: saved recovery choices legitimately add HUD controls.

const CENSUS := preload("res://tools/geometry_census.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

# Current authored composition includes the nine-craft fleet, physical berth
# feedback, embodied service/activity/destination boards, Salvage work lighting,
# the loaded Cinder berth/cargo presentation, and Halyard liveaboard berths.
# Bedding, emissive reading fixtures and berth labels add 10 renderers and five
# materials while preserving the light budget. Retained materials include
# unloaded reachable content; the existing schema and Cinder delta stay fixed.
#
# Refrozen 2026-09-14 for the Phase 10 "trim before raising budgets" pass. Two
# reductions land here and nothing else moved: the station's chamfered cylinder
# and frustum walls lost Godot's four lateral rings, and the 2,600-star backdrop
# shell became one camera-facing quad per star instead of a 48-triangle sphere.
#
# Refrozen 2026-09-14 for the ship trim: `ShipGeometryBudget` and
# `ShipChamferedStock` budget the Jovian's, the Halyard's and the three Cinder
# craft's detail tessellation from the size each part is drawn at, taking
# 204,888 resident triangles (2,407,157 -> 2,202,269). It is again triangle-only
# on every count except one: renderer nodes, surfaces, materials, lights,
# particle systems and scene-tree nodes are identical on both sides, and the
# loaded-minus-resident Cinder delta is untouched. Unique meshes move by one in
# each scenario (3,354 -> 3,355 resident, 3,494 -> 3,495 loaded) because the
# Cinder nozzle family now keys its shared unit meshes by the budgeted segment
# count, so a mount that budgets differently can no longer silently reuse
# another mount's recipe.
# Both are triangle-only — renderer count, surface count, unique meshes,
# materials, lights, particle systems and nodes are all unchanged from the
# previous freeze's live scene, and the loaded-minus-resident Cinder delta is
# untouched. Print lines `GEOMETRY_CENSUS_*_GEOMETRY` / `_RESOURCES` /
# `_FINGERPRINT` below carry the numbers a future refreeze must read.
#
# Refrozen 2026-09-14 for the Phase 10 §2 scene-node trim. `StationDressingBatch`
# merges anonymous sibling dressing in the world-built station modules into one
# multi-surface renderer per locality, and collapses `_box(collidable = true)`
# triples that carry no authority into one static body that still owns one
# `CollisionShape3D` per original piece. It is a **node and submission** trim, not
# a geometry trim:
#
#   resident 11,645 -> 11,455 nodes, 6,589 -> 6,435 renderers,
#            6,687 -> 6,570 surfaces, 3,356 -> 3,355 unique meshes
#   loaded   12,068 -> 11,878 nodes, 6,798 -> 6,644 renderers,
#            6,896 -> 6,779 surfaces, 3,496 -> 3,495 unique meshes
#
# Lights (335/362, 20 shadow-casting), particle systems (45), bound (693/735) and
# retained (969/1,016) materials, shaders (7), textures (34 / 83,355,976 bytes),
# text triangles/instances and every loaded-minus-resident delta are identical on
# both sides, and the streamed Cinder bucket is untouched.
#
# The triangle rows move by -118 in each scenario (1,951,853 -> 1,951,735 and
# 2,085,987 -> 2,085,869). That is *not* this pass: the same -118 was already
# present in the live tree this branch started from, exactly as the second
# 2026-09-14 trim recorded content landing after a freeze. The batcher reproduces
# every source triangle at its former world transform, and the resident bucket
# triangle totals of every module it touched are byte-identical before and after.
#
# Refrozen again for the second scene-node trim, which extends the same pass to
# `HabitatSpine` and `AftJunctionStack`. Identical arithmetic, one module deeper:
#
#   resident 11,467 -> 10,627 nodes, 6,435 -> 5,676 renderers,
#            6,570 -> 6,033 surfaces, 3,355 -> 3,167 unique meshes
#   loaded   11,890 -> 11,050 nodes, 6,644 -> 5,885 renderers,
#            6,779 -> 6,242 surfaces, 3,495 -> 3,307 unique meshes
#
# **Triangles do not move at all this time** — 1,917,477 resident and 2,051,611
# loaded on both sides — and neither do lights (335/362, 20 shadow-casting),
# particle systems (45), bound (693/735) and retained (969/1,016) materials,
# shaders (7), textures (34 / 83,355,976 bytes) or text triangles/instances.
# Every loaded-minus-resident delta is untouched: +134,134 triangles, +209
# renderers, +140 unique meshes, +47 retained materials, +27 lights, +423 nodes.
# Unique meshes fall because a merged renderer replaces N cached box meshes with
# one, and surfaces fall because pieces that shared a material with a sibling now
# share one submission — a draw-call reduction, not lost geometry.
#
# Refrozen 2026-09-15 for the Dock 04 approach-lane fix. **Nothing in that fix
# moves a count.** Dock 04's berth node moved 3.0 m along its own axis so the
# cargo hauler can fly the lane it publishes; the pad, its sign, its service
# dressing and its guide lights are the same nodes with the same meshes at a new
# transform, and every geometry, renderer, surface, mesh, material, light,
# particle and node row below was measured byte-identical with the move applied
# and with it reverted, fingerprints included.
#
# What does move is a **+1 node in each scenario** (10,647 -> 10,648 resident,
# 11,070 -> 11,071 loaded) and the two fingerprints that cover them. That delta
# is inherited, not introduced: it reproduces with this branch's change reverted,
# and it still reproduces with `scripts/ui/hud.gd`,
# `scripts/audio/optional_semantic_audio_composition.gd` and
# `scripts/activities/station_defense_encounter_content.gd` restored to
# 4d0190061 — the commit that last re-measured this census — so it was already
# in the live tree that commit froze against. Triangles (1,917,477 / 2,051,611),
# renderers (5,676 / 5,885), surfaces (6,033 / 6,242), unique meshes
# (3,167 / 3,307), lights (335 / 362), bound (693 / 735) and retained
# (969 / 1,016) materials, shaders (7), textures (34 / 83,355,976 bytes),
# particle systems (45) and every loaded-minus-resident delta are unchanged.
#
# Refrozen 2026-09-15 for the Phase 10 §1 camera-lane pass. **Only nodes move,
# and only collision nodes.** Eight station pieces that a craft's chase camera
# flew through were given the collision they visually imply, or moved onto their
# own pad and then given it: Dock 06's launch frame and rails and Dock 04's
# container row (`ServiceStructure`, one body per pad and one shape per drawn
# piece), the fleet-dock comb's three outboard service risers, the launch
# spine's signal crossbeam, and the three exposed-lattice mast caps (also
# finally named, `MastCap01`…`MastCap03`).
#
#   resident 10,647 -> 10,675 nodes, loaded 11,070 -> 11,098
#
# +28 in each scenario, and it decomposes exactly: 11 from the expansion berths
# (one `ServiceStructure` root, two bodies, eight shapes), 9 from the comb
# (three bodies, six shapes), 2 from the signal crossbeam and 6 from the three
# mast caps (each `MeshInstance3D` becomes a body with a mesh and a shape).
# Everything else is byte-identical: triangles (1,917,477 / 2,051,611),
# renderers (5,676 / 5,885), surfaces (6,033 / 6,242), unique meshes
# (3,167 / 3,307), lights (335 / 362), bound (693 / 735) and retained
# (969 / 1,016) materials, shaders (7), textures (34 / 83,355,976 bytes),
# particle systems (45) and every loaded-minus-resident delta. Dock 04's
# containers were resized 7 x 3.6 x 7 -> 3 x 3.6 x 4 and Dock 06's rails and
# header shortened, which moves no count at all: they are the same `BoxMesh`
# and `MultiMesh` resources at new dimensions.
#
# Refrozen 2026-09-15 for the Cinder damage-presentation coverage pass. The three
# runtime-composed Cinder craft carried no `HeroDamagePresentation` at all; they
# now attach the same `scenes/effects/hero_damage_presentation.tscn` the six
# authored craft instance, with anchors on their own engines, flanks and spines.
# **No mesh, surface, triangle or unique mesh moves** — the presentation owns no
# renderer at rest — and the whole delta is the three identical six-node rigs:
#
#   +18 nodes (6 per craft: the rig plus `DamageSparks`, `EngineFailureSparks`,
#              `EngineSmoke`, `DamageWarningLight`, `EngineFailureLight`)
#   +6 lights (the two practicals per craft, neither shadow-casting)
#   +9 particle systems (45 -> 54; all three are `emitting = false` at rest)
#   +27 retained materials (the nine shared spark/smoke/flash/debris recipes
#              each rig allocates; bound-phase materials do not move, because
#              nothing the rig owns is drawn in the frozen phase)
#
# A path-level walk of the resident scene before and after shows exactly those
# 18 nodes and nothing else. Triangles (1,917,477 / 2,051,611), renderers
# (5,551 / 5,760), surfaces (5,947 / 6,156), unique meshes (3,057 / 3,197),
# bound materials (693 / 735), shaders (7), textures (34 / 83,355,976 bytes) and
# every loaded-minus-resident delta (+134,134 triangles, +209 renderers, +140
# unique meshes, +47 retained materials, +27 lights, +423 nodes) are unchanged.
#
# A further **+3 nodes in each scenario** (10,531 -> 10,534 resident,
# 10,954 -> 10,957 loaded, measured on fresh private user data with this pass's
# change disabled) is inherited, not introduced: eea0b6e09 added the "Limit
# ultrawide field of view" settings row -- `LimitUltrawideFovRow`, its label and
# `LimitUltrawideFovControl` -- to the pause settings page without re-measuring
# this census. All three are Control nodes with no renderer, mesh, material,
# light or particle, so they move the node rows and the two fingerprints and
# nothing else.
#
# **Measure this suite on fresh private user data**, as the header above says:
# a saved recovery choice left in `user://` by an earlier run legitimately adds
# one HUD control, and that one node moves both node rows and both fingerprints.
# The numbers below were taken twice from an empty `XDG_DATA_HOME` and reproduce
# exactly; the same runs against a shared, written-to user directory read one
# node higher.
#
# Refrozen 2026-09-15 for the Phase 10 §3 Dock 04/06 art-direction pass. The two
# pads' dressing was rebuilt inside its existing clearance contracts, and the
# whole delta is 71 new drawn box copies, 4 batch renderers, 2 `Label3D` pad
# boards and the collision those structural pieces imply:
#
#   +856 triangles   (71 copies x 12 + 2 label quads x 2)
#   +6 renderers     (4 `MultiMeshInstance3D`, 2 `Label3D`)
#   +6 surfaces      (one each)
#   +1 unique mesh   (one 1 x 1 x 1 `BoxMesh` shared by all four new batches,
#                     scaled per instance, so 71 pieces cost one allocation)
#   +34 nodes        (the 6 renderers plus 28 `CollisionShape3D`: the module's
#                     service-structure colliders go 8 -> 36)
#
# Everything else is byte-identical on both sides and was measured, not assumed:
# bound (693 / 735) and retained (996 / 1,043) materials — the pass adds no
# material and reuses each pad's existing four — lights (341 / 368), shaders (7),
# textures (34 / 83,355,976 bytes) and particle systems (54). Every
# loaded-minus-resident delta is untouched: +134,134 triangles, +209 renderers,
# +140 unique meshes, +47 retained materials, +27 lights, +423 nodes.
# Refrozen 2026-09-15 for FREIGHT-CRATE-001, the freight berth's small-crate
# finish (`scripts/world/freight_crate_kit.gd`), measured on top of the ninth
# trim: the six rack totes and the two staged pallet stacks' four crates stopped
# being chamfered slabs in the berth's module colours and became moulded stores
# totes. Measured twice on an empty `XDG_DATA_HOME`, and the whole delta,
# identical in both scenarios, is:
#
#   +8,352 triangles   (eight strapped totes at 948, two lidded at 684, less the
#                       ten 60-triangle slabs they replace)
#   +20 surfaces       (three finishes per crate instead of one)
#   +5 bound / +5 retained materials (three tote shells, one shared trim, one
#                       shared stores plate)
#   +1 texture         (38 -> 39, +524,288 bytes: the one 512 x 256 `freight-tote`
#                       plate the marking generator now emits)
#
# No renderer, unique mesh, light, node, shader or particle system moves: the
# tote's AABB is the slab's, one mesh per size is shared through the berth's
# crate cache and the finishes are per-instance surface overrides.
# Refrozen 2026-09-20 for the station-operations half of FREIGHT-CRATE-001: the
# thirteen palletised `Crate*` boxes in
# `scripts/world/station_operations_activity_presentation_builder.gd` — nineteen
# instances across the one short cargo line, the two 21.6 m cargo lines and the
# crew work post — stopped being teal and orange slabs and became the same
# moulded stores totes as the freight berth's. Measured from the suite's own
# printed lines, identical in both scenarios:
#
#   +11,220 triangles  (eight strapped totes at 948 and eleven lidded at 684,
#                       less the nineteen 60-triangle slabs they replace)
#   +38 surfaces       (shell, trim and plate instead of one painted box)
#   +5 bound / +5 retained materials (three tote shells, one shared trim and
#                       one shared stores plate, added to the activity's shared
#                       22-entry catalog)
#
# Renderers (5,557 / 5,766), unique meshes (3,058 / 3,198), lights (341 / 368),
# nodes (10,593 / 11,016), shaders (7), textures (39 / 85,977,416 bytes) and
# particle systems (54) are all unchanged, and every loaded-minus-resident delta
# is untouched. The tote's AABB is the slab's, one shell is retained per
# (size, strapped) recipe and shared across placements by the activity's own
# fingerprint cache, the `freight-tote` plate already existed, and the finishes
# arrive as per-instance surface overrides.
# Refrozen 2026-09-20 for the abandoned station hulk
# (`scripts/world/abandoned_station_hulk.gd`), the nearby sector's first
# destination with an inside. It is streamed content, so **the whole
# station-resident line is byte-identical** - 1,907,275 triangles, 5,366
# renderers, 5,895 surfaces, 2,945 unique meshes, 716/1,019 materials, 341
# lights, 10,391 nodes and fingerprint b5bebf53... all unchanged. Only the
# loaded scenario moves, and it moves by exactly what the hulk authors:
#
#   +5,448 triangles   (one 78 m hull shell, its dock shelf, two bulkheads with
#                       doorways, four interior fittings and the exterior trim,
#                       all from the cluster's own cached chamfered stock)
#   +39 renderers      (no MultiMesh added: the streamed bucket's 584 copies
#                       are unchanged)
#   +24 unique meshes  (39 instances, 15 of which reuse a cluster recipe)
#   +9 bound / +9 retained materials (its own finish family)
#   +8 lights          (shadowless emergency practicals; shadow-casting stays 20)
#   +92 nodes          (18 solid bodies with a shape each, 21 loose renderers,
#                       8 practicals, one ShipBerth, the breaker volume and
#                       five roots)
#
# Loaded-minus-resident therefore becomes +139,582 triangles, +248 renderers,
# +164 unique meshes, +56 retained materials, +35 lights and +515 nodes, and
# the streamed Cinder bucket accounts for all of it on its own.
#
# `CinderStreamingTransitionPresentation`'s authored/bound renderer and light
# rosters were refrozen with it (211/215/27 -> 250/254/35). That contract fails
# visually closed, so without the refreeze the whole generation bound as
# `renderer_roster_mismatch` and hid itself - which is the only reason an
# intermediate measurement of this census ever showed the triangle line
# falling. Measured on the corrected bind, every delta above is additive.
# Refrozen 2026-09-20 for the Phase 8 starboard asteroid belt
# (`scripts/world/cinder_asteroid_field.gd`), the nearby sector's first
# navigable rock. It is a **loaded-only** move: every resident row above is
# byte-identical, because the belt ships inside the streamed Cinder component
# and the station owns none of it.
#
#   Cinder bucket  139,582 -> 153,406 triangles, 248 -> 256 renderers/surfaces,
#                  584 -> 712 MultiMesh copies, 518 -> 590 nodes, lights 35
#                  unchanged (the belt adds no light at all).
#   loaded totals  2,046,857 -> 2,060,681 triangles, 5,614 -> 5,622 meshes,
#                  6,143 -> 6,151 surfaces, 3,109 -> 3,117 unique meshes,
#                  767 -> 768 bound / 1,075 -> 1,076 retained materials,
#                  10,906 -> 10,978 nodes.
#
# The +8 unique meshes are the belt's six shared stock recipes and its two
# chevron meshes; the +1 material is the one neutral vertex-colour rock
# material the six stock batches share. The +30 solid bodies and their 30
# collision shapes are nodes, not renderers, which is why renderers move by 8
# while nodes move by 72.
# Refrozen 2026-09-20 for the Destination Board's two new sector-site rows: the
# board now lists the abandoned hulk's dock and the belt's bore beside Ember and
# Aurora, and each retained pause-menu card is nine Controls (panel, margin, row,
# copy column, three labels, status label, action button). That is +18 nodes on
# both scenarios and nothing else at all - triangles, renderers, surfaces, unique
# meshes, materials, lights, shaders, textures and particle systems are all
# byte-identical, and every loaded-minus-resident delta is unchanged, because the
# rows are HUD Controls with no renderer of their own.
#
#   resident nodes  10,391 -> 10,409
#   loaded nodes    10,978 -> 10,996
#
# Refrozen 2026-09-21 for the curved/bevelled authored-geometry pass, which
# chamfers the fleet expansion berths' structural slab stock and replaces the
# Arrow's raw-`BoxMesh` `_box` override with the fleet chamfer. Two rows move,
# in opposite directions, and they have different causes.
#
#   resident triangles  1,907,275 -> 1,911,083   (+3,808, +0.20%)
#   loaded triangles    2,060,681 -> 2,064,489   (+3,808, the same pieces)
#
# The triangles are the chamfer itself: a 44-triangle tangent-chamfered box, or
# the fleet's 108-triangle rolled edge where the chamfer is wide enough to earn
# it, in place of a 12-triangle primitive. Measured with the roster probe, the
# station half is +1,024 across 19 single renderers, 11 batched support posts
# and 2 batched launch rails; the rest is the Arrow's 61 fitted renderers.
#
#   resident meshes 5,366 -> 5,350, surfaces 5,895 -> 5,884,
#                   unique meshes 2,945 -> 2,929, nodes 10,409 -> 10,393
#   loaded  meshes 5,622 -> 5,606, surfaces 6,151 -> 6,140,
#                   unique meshes 3,117 -> 3,101, nodes 10,996 -> 10,980
#
# That -16 is **entirely the Arrow** and it is a consequence, not a decision.
# `ShipFitoutBatch` refuses to fold live `PrimitiveMesh` stock, because the
# tree-wide geometry-budget sweep re-tessellates exactly those renderers and
# baking one into a merged `ArrayMesh` takes it out of that sweep. Sixteen of
# the Arrow's renderers were refused on that ground alone; once they stopped
# being primitives the existing batcher folded them on its existing rules. A
# direct roster probe of the two touched subtrees confirms the attribution:
# `ArrowReconShip` goes 322 -> 306 nodes, 244 -> 228 mesh instances, 195 -> 179
# unique meshes and 251 -> 240 surfaces, while
# `FleetExpansionBerths` is byte-identical at 105 nodes, 21 mesh instances,
# 7 MultiMesh batches, 25 unique meshes and 31 surfaces.
#
# Everything else is byte-identical on both scenarios: 716/768 bound and
# 1,019/1,076 retained materials, 341/376 lights, 7 shaders, 39 textures,
# 85,977,416 texture bytes, 54 particle systems. The streamed Cinder bucket is
# untouched (153,406 triangles, 256 instances, 256 surfaces, 712 MultiMesh
# copies, 35 lights, 590 nodes) and every loaded-minus-resident delta holds at
# its frozen value, which is what says the pass reached only the station-
# resident scene.
const RESIDENT_FINGERPRINT := "44d3e7fc4b4be6311482250f85360deee307ffc72f8fde5ff74ed8834dfd25f9"
const CINDER_LOADED_FINGERPRINT := "b651ea37e21566d03094449fe98095aaa27c7ddfc4a0f142c78a54575d5ff380"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		CENSUS.force_high_visual_quality(game),
		"production HIGH geometry profile is explicit and independent of saved settings"
	)
	await _settle()
	_check(CENSUS.freeze_production_phase(game), "material-switching station presentations freeze at the declared zero-second phase")

	var resident_contract := CENSUS.inspect_production_scenario(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		bool(resident_contract.get("valid", false))
			and int(resident_contract.get("loaded_instance_count", -1)) == 0,
		"station-resident census requires zero loaded Cinder generations"
	)
	var resident_census := CENSUS.new()
	var resident := resident_census.measure_frozen_scene(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT,
		0
	) as Dictionary
	print(
		"GEOMETRY_CENSUS_RESIDENT_FINGERPRINT: ",
		resident.get("measurement_fingerprint", "")
	)
	print("GEOMETRY_CENSUS_RESIDENT_GEOMETRY: ", _geometry_counts(resident))
	_check(
		int(resident.get("schema_version", 0)) == 2
			and resident.get("scenario") == CENSUS.SCENARIO_STATION_RESIDENT
			and int(resident.get("loaded_instance_count", -1)) == 0,
		"resident report freezes schema, scenario identity, and exact loaded count"
	)
	_check(
		int(resident.get("total_triangles", -1)) == 1911083
			and int(resident.get("total_mesh_instances", -1)) == 5350
			and int(resident.get("total_surfaces", -1)) == 5884
			and int(resident.get("unique_meshes", -1)) == 2929,
		"resident geometry freezes 1,911,083 triangles / 5,350 meshes / 5,884 surfaces / 2,929 unique meshes"
	)
	_check(
		int(resident.get("bound_phase_unique_materials", -1)) == 716
			and int(resident.get("retained_reachable_unique_materials", -1)) == 1019
			and int(resident.get("lights", -1)) == 341
			and int(resident.get("nodes", -1)) == 10393,
		"resident resource roster freezes 716 bound / 1,019 retained materials, 341 lights, and 10,393 nodes"
	)
	_check(
		str(resident.get("measurement_fingerprint", "")) == RESIDENT_FINGERPRINT,
		"resident measurement fingerprint freezes the complete deterministic count contract"
	)
	print("GEOMETRY_CENSUS_RESIDENT_RESOURCES: ", _resource_counts(resident))
	resident_census.free()

	game.process_mode = Node.PROCESS_MODE_INHERIT
	var prepared := await CENSUS.prepare_cinder_loaded_scenario(game)
	_check(
		bool(prepared.get("accepted", false))
			and int(prepared.get("generation", -1)) == 1
			and int(prepared.get("loaded_instance_count", -1)) == 1,
		"loaded scenario commits exactly one real Cinder generation through production streaming"
	)
	await _settle()
	_check(CENSUS.freeze_production_phase(game), "material-switching station presentations freeze at the declared zero-second phase")
	var loaded_contract := CENSUS.inspect_production_scenario(
		game,
		CENSUS.SCENARIO_CINDER_LOADED
	)
	_check(
		bool(loaded_contract.get("valid", false))
			and int(loaded_contract.get("loaded_instance_count", -1)) == 1,
		"Cinder-loaded census recognizes only the coordinator-owned generation"
	)
	var resident_mismatch := CENSUS.inspect_production_scenario(
		game,
		CENSUS.SCENARIO_STATION_RESIDENT
	)
	_check(
		not bool(resident_mismatch.get("valid", true))
			and str(
				(resident_mismatch.get("errors") as PackedStringArray)[0]
			).contains("requires zero"),
		"MUTATION: a live destination generation makes the resident scenario fail closed"
	)

	var loaded_census := CENSUS.new()
	var loaded := loaded_census.measure_frozen_scene(
		game,
		CENSUS.SCENARIO_CINDER_LOADED,
		1
	) as Dictionary
	print(
		"GEOMETRY_CENSUS_LOADED_FINGERPRINT: ",
		loaded.get("measurement_fingerprint", "")
	)
	print("GEOMETRY_CENSUS_LOADED_GEOMETRY: ", _geometry_counts(loaded))
	_check(
		loaded.get("scenario") == CENSUS.SCENARIO_CINDER_LOADED
			and int(loaded.get("loaded_instance_count", -1)) == 1,
		"loaded report freezes destination identity and one committed generation"
	)
	_check(
		int(loaded.get("total_triangles", -1)) == 2064489
			and int(loaded.get("total_mesh_instances", -1)) == 5606
			and int(loaded.get("total_surfaces", -1)) == 6140
			and int(loaded.get("unique_meshes", -1)) == 3101,
		"loaded geometry freezes 2,064,489 triangles / 5,606 meshes / 6,140 surfaces / 3,101 unique meshes"
	)
	_check(
		int(loaded.get("bound_phase_unique_materials", -1)) == 768
			and int(loaded.get("retained_reachable_unique_materials", -1)) == 1076
			and int(loaded.get("lights", -1)) == 376
			and int(loaded.get("nodes", -1)) == 10980,
		"loaded resource roster freezes 768 bound / 1,076 retained materials, 376 lights, and 10,980 nodes"
	)
	var cinder_bucket := (loaded.get("buckets", {}) as Dictionary).get(
		"CinderStreamingBootstrap", {}
	) as Dictionary
	# Printed for the same reason the totals above are: a legitimate refreeze
	# should read the streamed destination's new roster straight off the run.
	print("GEOMETRY_CENSUS_LOADED_CINDER_BUCKET: ", cinder_bucket)
	_check(
		int(cinder_bucket.get("triangles", -1)) == 153406
			and int(cinder_bucket.get("instances", -1)) == 256
			and int(cinder_bucket.get("surfaces", -1)) == 256
			and int(cinder_bucket.get("multimesh_instances", -1)) == 712
			and int(cinder_bucket.get("lights", -1)) == 35
			and int(cinder_bucket.get("nodes", -1)) == 590,
		"the streamed Cinder bucket independently accounts for its exact renderer and node roster"
	)
	_check(
		int(loaded.get("total_triangles", 0)) - int(resident.get("total_triangles", 0)) == 153406
			and int(loaded.get("total_mesh_instances", 0)) - int(resident.get("total_mesh_instances", 0)) == 256
			and int(loaded.get("unique_meshes", 0)) - int(resident.get("unique_meshes", 0)) == 172
			and int(loaded.get("retained_reachable_unique_materials", 0)) - int(resident.get("retained_reachable_unique_materials", 0)) == 57
			and int(loaded.get("lights", 0)) - int(resident.get("lights", 0)) == 35
			and int(loaded.get("nodes", 0)) - int(resident.get("nodes", 0)) == 587,
		"loaded-minus-resident delta is exact across geometry, retained resources, lights, and nodes"
	)
	_check(
		str(loaded.get("measurement_fingerprint", "")) == CINDER_LOADED_FINGERPRINT
			and str(loaded.get("measurement_fingerprint", ""))
				!= str(resident.get("measurement_fingerprint", "")),
		"loaded measurement has its own exact scenario-sensitive fingerprint"
	)
	print("GEOMETRY_CENSUS_LOADED_RESOURCES: ", _resource_counts(loaded))
	loaded_census.free()

	game.queue_free()
	await process_frame
	_finish()


## Printed beside the fingerprint so a legitimate refreeze reads the new
## truthful numbers straight off the run instead of reconstructing them.
func _geometry_counts(report: Dictionary) -> Dictionary:
	var counts := {}
	for key in ["total_triangles", "total_mesh_instances", "total_surfaces", "unique_meshes"]:
		counts[key] = report.get(key)
	return counts


func _resource_counts(report: Dictionary) -> Dictionary:
	var counts := {}
	for key in ["bound_phase_unique_materials", "retained_reachable_unique_materials", "lights", "nodes", "unique_shaders", "unique_textures", "texture_bytes", "particle_systems"]:
		counts[key] = report.get(key)
	return counts


func _settle() -> void:
	for _frame in CENSUS.DEFAULT_SETTLE_FRAMES:
		await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("GEOMETRY_CENSUS_SCENARIO_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("GEOMETRY_CENSUS_SCENARIO_TEST_FAILED: %d of %d assertions failed" % [
		_failures.size(), _assertions,
	])
	for failure in _failures:
		print(" - ", failure)
	quit(1)
