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
const RESIDENT_FINGERPRINT := "60a98b4222d23448f5245692511a151fb8416c296c4cb610ce728430ec2067d4"
const CINDER_LOADED_FINGERPRINT := "25f65add1a76167a3e6e62613339c231acb5750426ffcef606019e868cf4352e"

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
		int(resident.get("total_triangles", -1)) == 1917477
			and int(resident.get("total_mesh_instances", -1)) == 5551
			and int(resident.get("total_surfaces", -1)) == 5947
			and int(resident.get("unique_meshes", -1)) == 3057,
		"resident geometry freezes 1,917,477 triangles / 5,551 meshes / 5,947 surfaces / 3,057 unique meshes"
	)
	_check(
		int(resident.get("bound_phase_unique_materials", -1)) == 693
			and int(resident.get("retained_reachable_unique_materials", -1)) == 969
			and int(resident.get("lights", -1)) == 335
			and int(resident.get("nodes", -1)) == 10532,
		"resident resource roster freezes 693 bound / 969 retained materials, 335 lights, and 10,532 nodes"
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
		int(loaded.get("total_triangles", -1)) == 2051611
			and int(loaded.get("total_mesh_instances", -1)) == 5760
			and int(loaded.get("total_surfaces", -1)) == 6156
			and int(loaded.get("unique_meshes", -1)) == 3197,
		"loaded geometry freezes 2,051,611 triangles / 5,760 meshes / 6,156 surfaces / 3,197 unique meshes"
	)
	_check(
		int(loaded.get("bound_phase_unique_materials", -1)) == 735
			and int(loaded.get("retained_reachable_unique_materials", -1)) == 1016
			and int(loaded.get("lights", -1)) == 362
			and int(loaded.get("nodes", -1)) == 10955,
		"loaded resource roster freezes 735 bound / 1,016 retained materials, 362 lights, and 10,955 nodes"
	)
	var cinder_bucket := (loaded.get("buckets", {}) as Dictionary).get(
		"CinderStreamingBootstrap", {}
	) as Dictionary
	_check(
		int(cinder_bucket.get("triangles", -1)) == 134134
			and int(cinder_bucket.get("instances", -1)) == 209
			and int(cinder_bucket.get("surfaces", -1)) == 209
			and int(cinder_bucket.get("multimesh_instances", -1)) == 584
			and int(cinder_bucket.get("lights", -1)) == 27
			and int(cinder_bucket.get("nodes", -1)) == 426,
		"the streamed Cinder bucket independently accounts for its exact renderer and node roster"
	)
	_check(
		int(loaded.get("total_triangles", 0)) - int(resident.get("total_triangles", 0)) == 134134
			and int(loaded.get("total_mesh_instances", 0)) - int(resident.get("total_mesh_instances", 0)) == 209
			and int(loaded.get("unique_meshes", 0)) - int(resident.get("unique_meshes", 0)) == 140
			and int(loaded.get("retained_reachable_unique_materials", 0)) - int(resident.get("retained_reachable_unique_materials", 0)) == 47
			and int(loaded.get("lights", 0)) - int(resident.get("lights", 0)) == 27
			and int(loaded.get("nodes", 0)) - int(resident.get("nodes", 0)) == 423,
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
