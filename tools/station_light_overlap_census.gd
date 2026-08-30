extends SceneTree

## Deterministic geometric light-influence census for the production Main scene.
##
## This tool answers a narrow scene question: which enabled Light3D nodes can
## geometrically influence each frozen route sample according to their actual
## type, range, spot cone, camera-point distance fade, visibility, energy and
## cull mask? It does not measure occlusion, pixels shaded, draw submissions,
## GPU time or frame time.
##
## Usage:
##   KETH_LIGHT_CENSUS_JSON=/tmp/station-light-overlap.json \
##     godot --headless --audio-driver Dummy \
##     --script res://tools/station_light_overlap_census.gd
##
## Optional environment variable:
##   KETH_LIGHT_CENSUS_SCENARIO=station_resident  (default)
##   KETH_LIGHT_CENSUS_SCENARIO=cinder_loaded

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CINDER_ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const CINDER_LOCATION := preload("res://assets/world/locations/cinder_reach.tres")

const SCHEMA_VERSION := 3
const DEFAULT_SETTLE_FRAMES := 8
const DEFAULT_OUTPUT_PATH := "/tmp/station-light-overlap-census.json"
const DEFAULT_VISUAL_LAYER_MASK := 1
const POSITION_EPSILON_M := 0.001
const FLOAT_PRECISION := 0.000001
const WORST_POINT_LIMIT := 5
const SCENARIO_FIXTURE: StringName = &"fixture"
const SCENARIO_STATION_RESIDENT: StringName = &"station_resident"
const SCENARIO_CINDER_LOADED: StringName = &"cinder_loaded"
const DEFAULT_SCENARIO: StringName = SCENARIO_STATION_RESIDENT
const SCENARIO_ENVIRONMENT_VARIABLE := "KETH_LIGHT_CENSUS_SCENARIO"
const HIGH_VISUAL_QUALITY_LEVEL := 2
const CINDER_CLEAR_APPROACH_OFFSET := Vector3(0.0, 4.0, 170.0)
const CINDER_LOAD_FRAME_BUDGET := 60

## Node samples use an embodied torso offset where their authored marker lies on
## a walking plane. Ship/flight markers are already body-centre positions.
const FROZEN_SAMPLE_SPECS := [
	{
		"point_id": &"walk-player-spawn",
		"category": &"walking",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/PlayerSpawn"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(-8.5, 1.18, 11.0),
	},
	{
		"point_id": &"walk-aft-lower-junction",
		"category": &"walking",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/AftJunctionStack/RouteLowerJunction"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(0, 1.15, 55.2),
	},
	{
		"point_id": &"walk-aft-upper-floor",
		"category": &"walking",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/AftJunctionStack/UpperFloorAnchor"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(-5.2, 5.35, 64.2),
	},
	{
		"point_id": &"walk-habitat-corridor",
		"category": &"walking",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/HabitatSpine/RouteCorridor"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(59.15, 1.15, 15.5),
	},
	{
		"point_id": &"walk-habitat-common",
		"category": &"walking",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/HabitatSpine/RouteCommonEntry"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(67.65, 1.15, 15.5),
	},
	{
		"point_id": &"walk-vip-reception",
		"category": &"walking",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/VipReceptionSuite/ReceptionAnchor"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(-6.45, 5.35, 73.2),
	},
	{
		"point_id": &"board-central-berth",
		"category": &"boarding",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/LandingZone"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(0, 1.12, -10),
	},
	{
		"point_id": &"board-arrow-berth",
		"category": &"boarding",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/ArrowReconBerth"),
		"offset": Vector3.ZERO,
		"expected_world_position": Vector3(-43, 1.15, 15.5),
	},
	{
		"point_id": &"board-zenith-berth",
		"category": &"boarding",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/ZenithFleetDockBerth"),
		"offset": Vector3.ZERO,
		"expected_world_position": Vector3(22, 5.28, 53.3),
	},
	{
		"point_id": &"board-halyard-berth",
		"category": &"boarding",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/HalyardFleetDockBerth"),
		"offset": Vector3.ZERO,
		"expected_world_position": Vector3(37, 5.28, 53.3),
	},
	{
		"point_id": &"board-freight-staging",
		"category": &"boarding",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/JovianFreightBerth/RouteBoardingStaging"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(-44.1, 1.53, 56.6),
	},
	{
		"point_id": &"operate-central-tow",
		"category": &"operations",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/OperationalLattice/Activities/CentralTowServiceActivity"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(6.8, 1, 14),
	},
	{
		"point_id": &"operate-aft-service-arm",
		"category": &"operations",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/OperationalLattice/Activities/AftOperationsActivity"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(5.8, 5.99, 61.2),
	},
	{
		"point_id": &"operate-habitat-patrol",
		"category": &"operations",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/OperationalLattice/Activities/HabitatServicePatrol"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(59.15, 5.88, 15.5),
	},
	{
		"point_id": &"operate-freight-gantry",
		"category": &"operations",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/OperationalLattice/Activities/FreightApproachGantry"),
		"offset": Vector3(0, 1, 0),
		"expected_world_position": Vector3(-53, 1.38, 29.7),
	},
	{
		"point_id": &"flight-ship-spawn",
		"category": &"flight_route",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/ShipSpawn"),
		"offset": Vector3.ZERO,
		"expected_world_position": Vector3(0, 1.15, -10),
	},
	{
		"point_id": &"flight-launch-gate",
		"category": &"flight_route",
		"source_kind": &"node_path",
		"source_path": NodePath("ShipyardWorld/LaunchGate"),
		"offset": Vector3.ZERO,
		"expected_world_position": Vector3(0, 2.7, -64),
	},
	{
		"point_id": &"flight-cinder-checkpoint-01",
		"category": &"flight_route",
		"source_kind": &"cinder_checkpoint",
		"checkpoint_index": 0,
		"expected_world_position": Vector3(16, -9, -240),
	},
	{
		"point_id": &"flight-cinder-checkpoint-02",
		"category": &"flight_route",
		"source_kind": &"cinder_checkpoint",
		"checkpoint_index": 1,
		"expected_world_position": Vector3(32, -26, -372),
	},
	{
		"point_id": &"flight-cinder-checkpoint-03",
		"category": &"flight_route",
		"source_kind": &"cinder_checkpoint",
		"checkpoint_index": 2,
		"expected_world_position": Vector3(46, -44, -498),
	},
	{
		"point_id": &"flight-cinder-checkpoint-04",
		"category": &"flight_route",
		"source_kind": &"cinder_checkpoint",
		"checkpoint_index": 3,
		"expected_world_position": Vector3(30, -46, -600),
	},
	{
		"point_id": &"flight-cinder-checkpoint-05",
		"category": &"flight_route",
		"source_kind": &"cinder_checkpoint",
		"checkpoint_index": 4,
		"expected_world_position": Vector3(60, -70, -700),
	},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var scenario := StringName(OS.get_environment(SCENARIO_ENVIRONMENT_VARIABLE).strip_edges())
	if scenario.is_empty():
		scenario = DEFAULT_SCENARIO
	if scenario not in [SCENARIO_STATION_RESIDENT, SCENARIO_CINDER_LOADED]:
		printerr("station light census: unsupported scenario: %s" % scenario)
		quit(1)
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null:
		printerr("station light census: Main failed to instantiate")
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	if not force_high_visual_quality(game):
		printerr("station light census: production HIGH visual quality is unavailable")
		game.queue_free()
		await process_frame
		quit(1)
		return
	if scenario == SCENARIO_CINDER_LOADED:
		var prepared := await prepare_cinder_loaded_scenario(game)
		if not bool(prepared.get("accepted", false)):
			printerr("station light census: Cinder scenario preparation failed: %s" % prepared)
			game.queue_free()
			await process_frame
			quit(1)
			return
	for _frame in DEFAULT_SETTLE_FRAMES:
		await process_frame
	await physics_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var scenario_contract := inspect_production_scenario(game, scenario)
	if not bool(scenario_contract.get("valid", false)):
		printerr("station light census: invalid production scenario: %s" % scenario_contract)
		game.queue_free()
		await process_frame
		quit(1)
		return

	var roster := build_frozen_production_roster(game)
	if not bool(roster.valid):
		printerr("station light census: invalid frozen sample roster: %s" % ", ".join(roster.errors as PackedStringArray))
		game.queue_free()
		await process_frame
		quit(1)
		return
	var report := measure_scene(
		game,
		roster.points as Array[Dictionary],
		scenario,
		int(scenario_contract.get("loaded_instance_count", -1))
	)
	report["visual_quality"] = {
		"level": HIGH_VISUAL_QUALITY_LEVEL,
		"name": &"high",
	}
	report["frozen_phase"] = {
		"idle_frames_before_freeze": DEFAULT_SETTLE_FRAMES,
		"physics_frames_before_freeze": 1,
		"final_idle_frames_before_freeze": 1,
		"freeze": "Main process_mode set to PROCESS_MODE_DISABLED before synchronous measurement",
	}
	var json_text := deterministic_json(report)
	var output_path := OS.get_environment("KETH_LIGHT_CENSUS_JSON")
	if output_path.is_empty():
		output_path = DEFAULT_OUTPUT_PATH
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		printerr("station light census: cannot write %s" % output_path)
		game.queue_free()
		await process_frame
		quit(1)
		return
	output.store_string(json_text + "\n")
	output.close()
	print("STATION_LIGHT_OVERLAP_CENSUS_OK: ", {
		"scenario": report.scenario,
		"loaded_instance_count": report.loaded_instance_count,
		"sample_count": report.sample_count,
		"total_scene_lights": (report.scene_lights as Dictionary).total,
		"enabled_scene_lights": (report.scene_lights as Dictionary).enabled,
		"maximum_influence_count": report.maximum_influence_count,
		"maximum_shadow_caster_count": report.maximum_shadow_caster_count,
		"output": output_path,
	})
	game.queue_free()
	await process_frame
	quit(0)


## The census always freezes the authored HIGH profile so saved local settings
## cannot silently change enabled-light or presentation evidence.
static func force_high_visual_quality(game: GameFlow) -> bool:
	if not is_instance_valid(game):
		return false
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	if not is_instance_valid(world):
		return false
	world.apply_visual_quality(HIGH_VISUAL_QUALITY_LEVEL)
	return world.visual_quality_level == HIGH_VISUAL_QUALITY_LEVEL


## Loads one real Cinder generation through Main's checked production binding.
## The piloted guided ship is retained in the authored clear approach lane, so
## the distance policy keeps the generation resident without embedding the body
## in platform collision geometry.
static func prepare_cinder_loaded_scenario(game: GameFlow) -> Dictionary:
	if not is_instance_valid(game) or not game.is_inside_tree():
		return {"accepted": false, "reason": &"invalid_main"}
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var ship := game.get_guided_ship()
	if not is_instance_valid(bootstrap) \
		or not is_instance_valid(binding) \
		or not is_instance_valid(ship):
		return {"accepted": false, "reason": &"production_streaming_unavailable"}
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = CINDER_LOCATION.get_anchor_position() \
		+ CINDER_CLEAR_APPROACH_OFFSET
	var tree := game.get_tree()
	for _frame in CINDER_LOAD_FRAME_BUDGET:
		await tree.physics_frame
		await tree.process_frame
		var loaded := bootstrap.get_loaded_instance()
		if is_instance_valid(loaded) and int(
			binding.get_snapshot().get("quality_synced_instance_id", 0)
		) == loaded.get_instance_id():
			return {
				"accepted": true,
				"reason": &"loaded",
				"loaded_instance_count": game.find_children(
					"*", "NearbySectorCluster", true, false
				).size(),
				"generation": int(loaded.get_meta(
					&"world_location_generation", -1
				)),
			}.duplicate(true)
	return {"accepted": false, "reason": &"load_timeout"}


## Read-only scenario guard used before every production measurement. The
## default resident path is invalid if any streamed Cinder instance is present;
## the loaded path requires exactly the coordinator-owned committed instance.
static func inspect_production_scenario(
		scene_root: Node,
		scenario: StringName
	) -> Dictionary:
	var errors := PackedStringArray()
	var loaded_instances := scene_root.find_children(
		"*", "NearbySectorCluster", true, false
	) if is_instance_valid(scene_root) else []
	var loaded_instance_count := loaded_instances.size()
	var bootstrap := scene_root.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap if is_instance_valid(scene_root) else null
	var coordinator_loaded := bootstrap.get_loaded_instance() \
		if is_instance_valid(bootstrap) else null
	if scenario == SCENARIO_STATION_RESIDENT:
		if loaded_instance_count != 0 or is_instance_valid(coordinator_loaded):
			errors.append("station-resident scenario requires zero loaded Cinder instances")
	elif scenario == SCENARIO_CINDER_LOADED:
		if loaded_instance_count != 1:
			errors.append("Cinder-loaded scenario requires exactly one loaded instance")
		elif not is_instance_valid(coordinator_loaded) \
			or coordinator_loaded != loaded_instances[0]:
			errors.append("loaded Cinder instance must be the coordinator-owned generation")
	else:
		errors.append("unsupported production scenario: %s" % scenario)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scenario": scenario,
		"loaded_instance_count": loaded_instance_count,
	}.duplicate(true)


static func build_frozen_production_roster(scene_root: Node) -> Dictionary:
	var errors := PackedStringArray()
	var points: Array[Dictionary] = []
	var seen_ids := {}
	for spec_variant in FROZEN_SAMPLE_SPECS:
		var spec := spec_variant as Dictionary
		var point_id := StringName(spec.point_id)
		if point_id.is_empty() or seen_ids.has(point_id):
			errors.append("sample id is empty or duplicated: %s" % point_id)
			continue
		seen_ids[point_id] = true
		var source_kind := StringName(spec.source_kind)
		var position := Vector3.INF
		var source_path := ""
		if source_kind == &"node_path":
			var path := spec.source_path as NodePath
			var source := scene_root.get_node_or_null(path) as Node3D
			if source == null:
				errors.append("sample source is missing: %s -> %s" % [point_id, path])
				continue
			position = source.global_position + (spec.offset as Vector3)
			source_path = str(path)
		elif source_kind == &"cinder_checkpoint":
			var checkpoint_index := int(spec.checkpoint_index)
			if checkpoint_index < 0 or checkpoint_index >= CINDER_ROUTE.get_checkpoint_count():
				errors.append("Cinder checkpoint index is invalid: %s" % checkpoint_index)
				continue
			position = CINDER_ROUTE.get_checkpoint_position(checkpoint_index)
			source_path = "res://assets/activities/cinder_reach_checkpoint_route.tres#checkpoint_positions[%d]" % checkpoint_index
		else:
			errors.append("sample source kind is unsupported: %s" % source_kind)
			continue
		var expected := spec.expected_world_position as Vector3
		if position.distance_to(expected) > POSITION_EPSILON_M:
			errors.append("sample position drifted: %s expected %s observed %s" % [point_id, expected, position])
		points.append({
			"point_id": point_id,
			"category": StringName(spec.category),
			"position": position,
			"source_kind": source_kind,
			"source_path": source_path,
			"visual_layer_mask": DEFAULT_VISUAL_LAYER_MASK,
		})
	return {
		"valid": errors.is_empty() and points.size() == FROZEN_SAMPLE_SPECS.size(),
		"errors": errors,
		"points": points,
		"sample_count": points.size(),
		"roster_fingerprint": _sample_roster_fingerprint(points),
	}.duplicate(true)


static func measure_scene(
		scene_root: Node,
		samples: Array[Dictionary],
		scenario: StringName = SCENARIO_FIXTURE,
		loaded_instance_count: int = 0
	) -> Dictionary:
	var lights: Array[Light3D] = []
	if scene_root is Light3D:
		lights.append(scene_root as Light3D)
	for candidate in scene_root.find_children("*", "Light3D", true, false):
		lights.append(candidate as Light3D)
	lights.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return _stable_node_path(scene_root, a) < _stable_node_path(scene_root, b)
	)

	var scene_counts := {
		"total": lights.size(),
		"enabled": 0,
		"disabled": 0,
		"shadow_casting_total": 0,
		"enabled_shadow_casting": 0,
		"by_type": {
			"directional": {"total": 0, "enabled": 0},
			"omni": {"total": 0, "enabled": 0},
			"spot": {"total": 0, "enabled": 0},
			"other": {"total": 0, "enabled": 0},
		},
	}
	for light in lights:
		var light_type := _light_type(light)
		var type_counts := (scene_counts.by_type as Dictionary)[light_type] as Dictionary
		type_counts.total = int(type_counts.total) + 1
		if light.shadow_enabled:
			scene_counts.shadow_casting_total = int(scene_counts.shadow_casting_total) + 1
		if _light_is_enabled(light):
			scene_counts.enabled = int(scene_counts.enabled) + 1
			type_counts.enabled = int(type_counts.enabled) + 1
			if light.shadow_enabled:
				scene_counts.enabled_shadow_casting = int(scene_counts.enabled_shadow_casting) + 1
		else:
			scene_counts.disabled = int(scene_counts.disabled) + 1

	var point_rows: Array[Dictionary] = []
	for sample in samples:
		point_rows.append(_measure_point(scene_root, sample, lights))
	point_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.point_id) < str(b.point_id)
	)
	var worst_rows := point_rows.duplicate(true)
	worst_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.influence_count) != int(b.influence_count):
			return int(a.influence_count) > int(b.influence_count)
		if int(a.shadow_caster_count) != int(b.shadow_caster_count):
			return int(a.shadow_caster_count) > int(b.shadow_caster_count)
		return str(a.point_id) < str(b.point_id)
	)
	var top_worst: Array[Dictionary] = []
	for index in mini(WORST_POINT_LIMIT, worst_rows.size()):
		var row := worst_rows[index] as Dictionary
		top_worst.append({
			"point_id": row.point_id,
			"category": row.category,
			"influence_count": row.influence_count,
			"shadow_caster_count": row.shadow_caster_count,
			"contributing_node_paths": row.contributing_node_paths,
		})
	var maximum_influence := int(worst_rows[0].influence_count) if not worst_rows.is_empty() else 0
	var maximum_shadows := 0
	for row in point_rows:
		maximum_shadows = maxi(maximum_shadows, int(row.shadow_caster_count))
	var measurement_fingerprint := build_measurement_fingerprint(
		point_rows, scene_counts, scenario, loaded_instance_count
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"scenario": scenario,
		"loaded_instance_count": loaded_instance_count,
		"method": {
			"name": "geometric_light_influence_proxy",
			"includes": "enabled visibility, positive energy, cull mask, DirectionalLight3D global reach, OmniLight3D range, SpotLight3D range and cone, local-light distance-fade endpoint and separate shadow-fade endpoint using each sample as the camera point",
			"excludes": "occlusion, screen visibility, pixels shaded, draw cost, GPU time, CPU time, shadow-map update cost and frame time",
			"performance_claim": false,
			"llvmpipe_benchmark": false,
		},
		"sample_count": point_rows.size(),
		"sample_roster_fingerprint": _sample_roster_fingerprint(samples),
		"measurement_fingerprint": measurement_fingerprint,
		"scene_lights": scene_counts,
		"maximum_influence_count": maximum_influence,
		"maximum_shadow_caster_count": maximum_shadows,
		"top_worst_points": top_worst,
		"points": point_rows,
	}.duplicate(true)


## Stable read-only roster used by the focused production refreeze to identify
## which authored subtrees contributed a scene-total delta. It is deliberately
## separate from the measurement payload so adding audit evidence cannot change
## the current deterministic JSON contract or its per-point fingerprint.
static func build_scene_light_roster(scene_root: Node) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	var lights: Array[Light3D] = []
	if scene_root is Light3D:
		lights.append(scene_root as Light3D)
	for candidate in scene_root.find_children("*", "Light3D", true, false):
		lights.append(candidate as Light3D)
	lights.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return _stable_node_path(scene_root, a) < _stable_node_path(scene_root, b)
	)
	for light in lights:
		roster.append({
			"path": _stable_node_path(scene_root, light),
			"type": _light_type(light),
			"enabled": _light_is_enabled(light),
			"shadow_enabled": light.shadow_enabled,
		})
	return roster.duplicate(true)


static func deterministic_json(report: Dictionary) -> String:
	return JSON.stringify(_canonicalize(report), "  ", false)


static func _measure_point(
		scene_root: Node,
		sample: Dictionary,
		lights: Array[Light3D]
	) -> Dictionary:
	var position := sample.position as Vector3
	var visual_layer_mask := int(sample.get("visual_layer_mask", DEFAULT_VISUAL_LAYER_MASK))
	var contributors: Array[Dictionary] = []
	var shadow_paths := PackedStringArray()
	var type_counts := {"directional": 0, "omni": 0, "spot": 0, "other": 0}
	for light in lights:
		if not _light_can_influence_point(light, position, visual_layer_mask):
			continue
		var path := _stable_node_path(scene_root, light)
		var light_type := _light_type(light)
		type_counts[light_type] = int(type_counts[light_type]) + 1
		if _light_shadow_can_influence_point(light, position):
			shadow_paths.append(path)
		contributors.append(_contributor_record(scene_root, light, position))
	contributors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.path) < str(b.path)
	)
	shadow_paths.sort()
	var contributing_paths := PackedStringArray()
	for contributor in contributors:
		contributing_paths.append(str(contributor.path))
	return {
		"point_id": StringName(sample.point_id),
		"category": StringName(sample.category),
		"position": _vector_to_array(position),
		"source_kind": StringName(sample.get("source_kind", &"fixture")),
		"source_path": str(sample.get("source_path", "")),
		"visual_layer_mask": visual_layer_mask,
		"influence_count": contributors.size(),
		"shadow_caster_count": shadow_paths.size(),
		"counts_by_type": type_counts,
		"contributing_node_paths": contributing_paths,
		"shadow_caster_node_paths": shadow_paths,
		"contributors": contributors,
	}


static func _light_can_influence_point(light: Light3D, point: Vector3, visual_layer_mask: int) -> bool:
	if not _light_is_enabled(light) or (light.light_cull_mask & visual_layer_mask) == 0:
		return false
	if light is DirectionalLight3D:
		return true
	var to_point := point - light.global_position
	var distance := to_point.length()
	if not _light_distance_fade_allows(light, distance):
		return false
	if light is OmniLight3D:
		return distance <= (light as OmniLight3D).omni_range + FLOAT_PRECISION
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		if distance > spot.spot_range + FLOAT_PRECISION:
			return false
		if distance <= FLOAT_PRECISION:
			return true
		var forward := -spot.global_basis.z.normalized()
		var angle_degrees := rad_to_deg(forward.angle_to(to_point / distance))
		return angle_degrees <= spot.spot_angle + FLOAT_PRECISION
	return false


static func _light_distance_fade_allows(light: Light3D, camera_distance: float) -> bool:
	if not (light is OmniLight3D or light is SpotLight3D):
		return true
	if not light.distance_fade_enabled:
		return true
	var fade_endpoint := light.distance_fade_begin + light.distance_fade_length
	return camera_distance <= fade_endpoint + FLOAT_PRECISION


static func _light_shadow_can_influence_point(light: Light3D, point: Vector3) -> bool:
	if not light.shadow_enabled:
		return false
	if not (light is OmniLight3D or light is SpotLight3D):
		return true
	if not light.distance_fade_enabled:
		return true
	var camera_distance := light.global_position.distance_to(point)
	var shadow_fade_endpoint := light.distance_fade_shadow
	return camera_distance <= shadow_fade_endpoint + FLOAT_PRECISION


static func _light_is_enabled(light: Light3D) -> bool:
	return (
		is_instance_valid(light)
		and light.is_inside_tree()
		and light.is_visible_in_tree()
		and light.light_energy > 0.0
	)


static func _light_type(light: Light3D) -> String:
	if light is DirectionalLight3D:
		return "directional"
	if light is OmniLight3D:
		return "omni"
	if light is SpotLight3D:
		return "spot"
	return "other"


static func _contributor_record(scene_root: Node, light: Light3D, point: Vector3) -> Dictionary:
	var local_light := light is OmniLight3D or light is SpotLight3D
	var camera_distance := light.global_position.distance_to(point) if local_light else 0.0
	var fade_endpoint := light.distance_fade_begin + light.distance_fade_length
	var shadow_fade_endpoint := light.distance_fade_shadow
	var light_fade_reason := "not_applicable_to_directional"
	if local_light:
		light_fade_reason = (
			"within_light_fade_endpoint"
			if light.distance_fade_enabled
			else "distance_fade_disabled"
		)
	var shadow_fade_reason := "shadow_disabled"
	if light.shadow_enabled:
		if not local_light:
			shadow_fade_reason = "not_applicable_to_directional"
		elif not light.distance_fade_enabled:
			shadow_fade_reason = "distance_fade_disabled"
		elif camera_distance <= shadow_fade_endpoint + FLOAT_PRECISION:
			shadow_fade_reason = "within_shadow_fade_endpoint"
		else:
			shadow_fade_reason = "beyond_shadow_fade_endpoint"
	var record := {
		"path": _stable_node_path(scene_root, light),
		"type": _light_type(light),
		"shadow_enabled": light.shadow_enabled,
		"shadow_contributes": _light_shadow_can_influence_point(light, point),
		# Several production beacons intentionally pulse their numeric energy.
		# Influence depends only on the stable positive-energy predicate; serializing
		# the instantaneous amplitude would make otherwise identical JSON clock-bound.
		"positive_energy": light.light_energy > 0.0,
		"cull_mask": light.light_cull_mask,
		"distance_fade": {
			"applies_to_type": local_light,
			"enabled": light.distance_fade_enabled,
			"camera_distance_m": _rounded(camera_distance) if local_light else "not_applicable",
			"begin_m": _rounded(light.distance_fade_begin),
			"length_m": _rounded(light.distance_fade_length),
			"light_endpoint_m": _rounded(fade_endpoint),
			"shadow_endpoint_m": _rounded(shadow_fade_endpoint),
			"light_inclusion_reason": light_fade_reason,
			"shadow_inclusion_reason": shadow_fade_reason,
		},
	}
	if light is OmniLight3D:
		record["distance_m"] = _rounded(light.global_position.distance_to(point))
		record["range_m"] = _rounded((light as OmniLight3D).omni_range)
	elif light is SpotLight3D:
		var spot := light as SpotLight3D
		var to_point := point - spot.global_position
		var angle_degrees := 0.0
		if to_point.length() > FLOAT_PRECISION:
			angle_degrees = rad_to_deg((-spot.global_basis.z.normalized()).angle_to(to_point.normalized()))
		record["distance_m"] = _rounded(to_point.length())
		record["range_m"] = _rounded(spot.spot_range)
		record["angle_from_axis_degrees"] = _rounded(angle_degrees)
		record["spot_angle_degrees"] = _rounded(spot.spot_angle)
	else:
		record["range_m"] = "global" if light is DirectionalLight3D else "unsupported"
	return record


static func _sample_roster_fingerprint(samples: Array[Dictionary]) -> String:
	var descriptors := PackedStringArray()
	for sample in samples:
		var position_value: Variant = sample.get("position", sample.get("expected_world_position", Vector3.ZERO))
		var position := position_value as Vector3
		descriptors.append("%s|%s|%.6f,%.6f,%.6f|%s|%s" % [
			str(sample.get("point_id", "")),
			str(sample.get("category", "")),
			position.x,
			position.y,
			position.z,
			str(sample.get("source_kind", "")),
			str(sample.get("source_path", "")),
		])
	descriptors.sort()
	return "\n".join(descriptors).sha256_text()


## Public so focused mutation witnesses can hold every scene/point row constant
## while proving residency identity itself participates in the hash.
static func build_measurement_fingerprint(
		point_rows: Array[Dictionary],
		scene_counts: Dictionary,
		scenario: StringName = SCENARIO_FIXTURE,
		loaded_instance_count: int = 0
	) -> String:
	var descriptors := PackedStringArray([
		"scenario|id=%s|loaded_instances=%d" % [
			str(scenario), loaded_instance_count,
		],
		"scene|total=%d|enabled=%d|shadows=%d|enabled_shadows=%d" % [
			int(scene_counts.total),
			int(scene_counts.enabled),
			int(scene_counts.shadow_casting_total),
			int(scene_counts.enabled_shadow_casting),
		],
	])
	for row in point_rows:
		descriptors.append("point|%s|influence=%d|shadows=%d|contributors=%s" % [
			str(row.point_id),
			int(row.influence_count),
			int(row.shadow_caster_count),
			JSON.stringify(_canonicalize(row.contributors)),
		])
	descriptors.sort()
	return "\n".join(descriptors).sha256_text()


static func _stable_node_path(scene_root: Node, node: Node) -> String:
	if node == scene_root:
		return "."
	var segments := PackedStringArray()
	var cursor := node
	while cursor != null and cursor != scene_root:
		segments.append(_stable_sibling_segment(cursor))
		cursor = cursor.get_parent()
	if cursor != scene_root:
		return "<outside-scene>/%s" % "/".join(segments)
	segments.reverse()
	return "/".join(segments)


static func _stable_sibling_segment(node: Node) -> String:
	var runtime_name := str(node.name)
	if not runtime_name.begins_with("@"):
		return runtime_name
	var parent := node.get_parent()
	if parent == null:
		return "%s[01]" % node.get_class()
	var ordinal := 0
	for sibling in parent.get_children():
		if sibling.get_class() == node.get_class() and str(sibling.name).begins_with("@"):
			ordinal += 1
		if sibling == node:
			break
	return "%s[%02d]" % [node.get_class(), ordinal]


static func _vector_to_array(value: Vector3) -> Array[float]:
	return [_rounded(value.x), _rounded(value.y), _rounded(value.z)]


static func _rounded(value: float) -> float:
	return snappedf(value, FLOAT_PRECISION)


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys:
			result[str(key)] = _canonicalize((value as Dictionary)[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_canonicalize(item))
		return result
	if value is PackedStringArray:
		var result: Array[String] = []
		for item in value as PackedStringArray:
			result.append(item)
		return result
	if value is StringName:
		return str(value)
	if value is Vector3:
		return _vector_to_array(value)
	if value is NodePath:
		return str(value)
	return value
