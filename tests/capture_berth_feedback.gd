extends SceneTree

## HUD-free Forward+ evidence for the four production berth-state displays.
##
## The complete production main scene supplies every photographed berth, ship,
## deck, and feedback component. This harness adds only an evidence camera and
## drives GameFlow's existing lease coordinator through release, reservation,
## and occupancy; it never assigns a visual state or moves a craft directly.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/berth_feedback"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "KETH_CAPTURE_BERTH_FEEDBACK_PARSE_ONLY"
const MANUAL_FEEDBACK_TIME := 0.375

const BERTH_ORDER: Array[StringName] = [
	&"central_berth",
	&"arrow_recon_berth",
	&"jovian_freight_berth",
	&"zenith_fleet_dock_berth",
]
const STATE_ORDER: Array[StringName] = [
	&"released",
	&"approach",
	&"occupied",
]
const EXPECTED_SHIP_BY_BERTH := {
	&"central_berth": &"torrent_provisional",
	&"arrow_recon_berth": &"arrow_provisional",
	&"jovian_freight_berth": &"jovian_provisional",
	&"zenith_fleet_dock_berth": &"zenith_b7_observed",
}
const CAMERA_LOCAL_DIRECTIONS := {
	&"central_berth": Vector3(0.76, 0.92, 0.82),
	&"arrow_recon_berth": Vector3(-0.82, 0.90, 0.72),
	&"jovian_freight_berth": Vector3(0.72, 0.96, -0.82),
	&"zenith_fleet_dock_berth": Vector3(-0.78, 0.92, 0.78),
}
const CAMERA_FOV := {
	&"central_berth": 45.0,
	&"arrow_recon_berth": 43.0,
	&"jovian_freight_berth": 47.0,
	&"zenith_fleet_dock_berth": 44.0,
}
const CAPTURE_FILES := {
	&"central_berth": {
		&"released": "01_central_berth_released.png",
		&"approach": "02_central_berth_approach.png",
		&"occupied": "03_central_berth_occupied.png",
	},
	&"arrow_recon_berth": {
		&"released": "04_arrow_recon_berth_released.png",
		&"approach": "05_arrow_recon_berth_approach.png",
		&"occupied": "06_arrow_recon_berth_occupied.png",
	},
	&"jovian_freight_berth": {
		&"released": "07_jovian_freight_berth_released.png",
		&"approach": "08_jovian_freight_berth_approach.png",
		&"occupied": "09_jovian_freight_berth_occupied.png",
	},
	&"zenith_fleet_dock_berth": {
		&"released": "10_zenith_fleet_dock_berth_released.png",
		&"approach": "11_zenith_fleet_dock_berth_approach.png",
		&"occupied": "12_zenith_fleet_dock_berth_occupied.png",
	},
}

const EXPECTED_COMPONENT_COUNT := 4
# Re-frozen 11 -> 16 when the berth cue gained its shape channel: five glyph
# meshes (two gate marks, two chevron arms, one secured bar) of which exactly one
# state's set is ever rendered. See the header of scripts/world/ship_berth_feedback.gd.
const EXPECTED_MESHES_PER_COMPONENT := 16
const EXPECTED_MATERIALS_PER_COMPONENT := 4
const MINIMUM_PNG_BYTES := 220_000
const MINIMUM_LUMINANCE_RANGE := 0.030
const MINIMUM_LUMINANCE_VARIANCE := 0.00008
const PIXEL_CHANGE_THRESHOLD := 0.022
const MINIMUM_PAIR_MEAN_DIFFERENCE := 0.00035
const MINIMUM_PAIR_CHANGED_FRACTION := 0.0025
const FRAME_MARGIN_FRACTION := 0.025

var _failures: Array[String] = []
var _captured_images: Dictionary = {}
var _capture_order: Array[String] = []
var _capture_contracts: Dictionary = {}
var _ships_by_berth: Dictionary = {}
var _feedback_by_berth: Dictionary = {}
var _initial_ship_transforms: Dictionary = {}

var _game: GameFlow
var _world: ShipyardWorld
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("SHIP_BERTH_FEEDBACK_CAPTURE_PARSE_OK")
		quit(0)
		return

	_configure_capture_viewport()
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	print(
		"BERTH_FEEDBACK_RENDERER: method=%s adapter=%s display=%s requested=%dx%d"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			DisplayServer.get_name(),
			CAPTURE_RESOLUTION.x,
			CAPTURE_RESOLUTION.y,
		]
	)

	_game = MAIN_SCENE.instantiate() as GameFlow
	_check(_game != null, "complete production main scene instantiates")
	if _game == null:
		_finish()
		return
	root.add_child(_game)
	await _settle_render(10)
	await physics_frame

	if not _resolve_production_contracts():
		await _dispose_game()
		_finish()
		return
	_disable_all_canvas_layers()
	_validate_hud_exclusion()
	_validate_exact_feedback_roster()
	_validate_initial_fleet_leases()
	_prepare_deterministic_presentation()
	_validate_component_audits_and_budgets()
	if not _failures.is_empty():
		await _dispose_game()
		_finish()
		return

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_check(
		directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
		"berth-feedback output directory is available"
	)
	if not _failures.is_empty():
		await _dispose_game()
		_finish()
		return

	_camera = Camera3D.new()
	_camera.name = "BerthFeedbackEvidenceCamera"
	_camera.near = 0.06
	_camera.far = 1800.0
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_game.add_child(_camera)
	_camera.current = true

	for berth_id in BERTH_ORDER:
		await _capture_berth_state_sequence(berth_id)

	_validate_capture_set()
	_validate_all_berths_restored()
	await _dispose_game()
	_finish()


func _configure_capture_viewport() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X


func _resolve_production_contracts() -> bool:
	_world = _game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(_world != null, "production ShipyardWorld exists")
	_check(_game.has_method("get_flyable_ships"), "main scene publishes its live flyable fleet")
	_check(_game.has_method("_release_ship_berth"), "GameFlow publishes its real lease-release coordinator")
	_check(_game.has_method("_reserve_berth_for_ship"), "GameFlow publishes its real lease-reservation coordinator")
	_check(_game.has_method("_occupy_reserved_berth"), "GameFlow publishes its real lease-occupancy coordinator")
	if _world == null:
		return false
	_check(_world.has_method("get_berth_ids"), "world publishes its physical berth registry")
	_check(_world.has_method("get_berth_node"), "world resolves authoritative ShipBerth nodes")
	_check(
		_world.has_method("get_ship_berth_feedback_nodes"),
		"world publishes its exact berth-feedback roster"
	)
	_check(
		_world.has_method("get_ship_berth_feedback_audit_report"),
		"world publishes its fail-red berth-feedback integration audit"
	)
	return _game.has_method("get_flyable_ships") \
		and _game.has_method("_release_ship_berth") \
		and _game.has_method("_reserve_berth_for_ship") \
		and _game.has_method("_occupy_reserved_berth") \
		and _world.has_method("get_berth_ids") \
		and _world.has_method("get_berth_node") \
		and _world.has_method("get_ship_berth_feedback_nodes") \
		and _world.has_method("get_ship_berth_feedback_audit_report")


func _disable_all_canvas_layers() -> void:
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED


func _validate_hud_exclusion() -> void:
	var layers := _game.find_children("*", "CanvasLayer", true, false)
	var visible_layers: Array[String] = []
	for candidate in layers:
		var layer := candidate as CanvasLayer
		if layer.visible:
			visible_layers.append(str(layer.get_path()))
	_check(_game.get_node_or_null("HUD") is CanvasLayer, "production HUD exists and is explicitly excluded")
	_check(not layers.is_empty(), "production scene contains at least one CanvasLayer")
	_check(visible_layers.is_empty(), "all HUD and CanvasLayer presentation is disabled")
	_check(
		_game.find_child("BerthFeedbackEvidenceCamera", true, false) == null,
		"production tree contains no pre-authored berth-feedback evidence camera"
	)


func _validate_exact_feedback_roster() -> void:
	var actual_ids := _world.get_berth_ids()
	_check(
		_string_name_arrays_match(actual_ids, BERTH_ORDER),
		"world registry is exactly central, Arrow recon, Jovian freight, and Zenith fleet-dock berths"
	)

	var feedback_nodes := _world.get_ship_berth_feedback_nodes()
	var grouped_nodes: Array[Node] = []
	for candidate in get_nodes_in_group(&"ship_berth_feedback"):
		if candidate is Node and _world.is_ancestor_of(candidate as Node):
			grouped_nodes.append(candidate as Node)
	var typed_descendants := _world.find_children("*", "ShipBerthFeedback", true, false)
	_check(
		feedback_nodes.size() == EXPECTED_COMPONENT_COUNT,
		"production world exposes exactly four berth-feedback components"
	)
	_check(
		_node_sets_match(feedback_nodes, grouped_nodes),
		"world roster and ship_berth_feedback group identify the same exact instances"
	)
	_check(
		_node_sets_match(feedback_nodes, typed_descendants),
		"world roster matches every live ShipBerthFeedback descendant"
	)

	_feedback_by_berth.clear()
	for berth_id in BERTH_ORDER:
		var berth := _world.get_berth_node(berth_id)
		var feedback := berth.get_node_or_null("BerthFeedback") as ShipBerthFeedback \
			if berth != null else null
		_check(berth != null, "%s resolves its authoritative ShipBerth" % berth_id)
		_check(
			feedback != null and feedback.get_parent() == berth,
			"%s owns one direct typed BerthFeedback child" % berth_id
		)
		if feedback != null:
			_feedback_by_berth[berth_id] = feedback
	_check(
		_feedback_by_berth.size() == EXPECTED_COMPONENT_COUNT,
		"all and only the four authoritative berths map to feedback components"
	)
	var freight_marker := _world.get_node_or_null("JovianFreightBerth/BerthDockMarker")
	_check(
		freight_marker is Marker3D and freight_marker is not ShipBerthFeedback,
		"freight module marker remains geometry-only and outside lease-feedback authority"
	)

	var world_audit := _world.get_ship_berth_feedback_audit_report()
	_check(_report_is_valid(world_audit), "production berth-feedback roster audit is valid")
	_check(
		int(world_audit.get("component_count", 0)) == EXPECTED_COMPONENT_COUNT,
		"world audit reports exactly four feedback components"
	)
	_check(
		StringName(world_audit.get("evidence_status", &"")) == &"modern_interpretation"
		and not bool(world_audit.get("authenticated_original_docking_feedback", true))
		and bool(world_audit.get("presentation_only", false)),
		"world audit keeps feedback explicitly modern, unauthenticated, and presentation-only"
	)


func _validate_initial_fleet_leases() -> void:
	var fleet := _game.get_flyable_ships()
	_check(fleet.size() == EXPECTED_COMPONENT_COUNT, "production main scene contains exactly four flyable ships")
	_ships_by_berth.clear()
	_initial_ship_transforms.clear()
	for candidate in fleet:
		var ship := candidate as HeroShip
		if ship == null:
			continue
		var berth_id := ship.get_home_berth_id()
		_check(BERTH_ORDER.has(berth_id), "%s owns a captured production berth" % ship.get_ship_id())
		_check(
			ship.get_ship_id() == StringName(EXPECTED_SHIP_BY_BERTH.get(berth_id, &"")),
			"%s maps to the expected production craft" % berth_id
		)
		_ships_by_berth[berth_id] = ship
		_initial_ship_transforms[berth_id] = ship.global_transform
	_check(_ships_by_berth.size() == EXPECTED_COMPONENT_COUNT, "each berth maps to one distinct production craft")

	for berth_id in BERTH_ORDER:
		var ship := _ships_by_berth.get(berth_id) as HeroShip
		var berth := _world.get_berth_node(berth_id)
		var feedback := _feedback_by_berth.get(berth_id) as ShipBerthFeedback
		_check(
			ship != null and berth != null and feedback != null,
			"%s initial lease dependencies resolve" % berth_id
		)
		if ship == null or berth == null or feedback == null:
			continue
		_check(
			berth.get_reservation_owner() == ship
			and berth.get_occupant() == ship
			and berth.get_reserved_ship_id() == ship.get_ship_id(),
			"%s begins with its real production occupied lease" % berth_id
		)
		_check(
			feedback.get_feedback_state() == &"occupied",
			"%s feedback begins synchronized to occupied" % berth_id
		)
		_check(
			ship.global_transform.is_equal_approx(berth.get_dock_transform()),
			"%s craft begins at its exact dock transform" % berth_id
		)


func _prepare_deterministic_presentation() -> void:
	for berth_id in BERTH_ORDER:
		var feedback := _feedback_by_berth.get(berth_id) as ShipBerthFeedback
		if feedback == null:
			continue
		feedback.set_feedback_enabled(true)
		feedback.set_feedback_paused(false)
		feedback.set_auto_advance_enabled(false)
		feedback.seek_simulation(MANUAL_FEEDBACK_TIME)

	# Freeze only presentation-owned deterministic clocks. Lease authority,
	# physical craft transforms, and gameplay lifecycle remain untouched.
	var activities := _world.get_station_operations_activities()
	for index in activities.size():
		var activity := activities[index]
		activity.set_activity_enabled(true)
		activity.set_activity_paused(true)
		activity.set_activity_time(2.25 + float(index) * 1.37)
	var freight := _world.get_jovian_freight_berth()
	if freight != null:
		freight.set_equipment_animation_enabled(false)
		freight.advance_equipment_simulation(3.85)
	var quality := _world.apply_visual_quality(2)
	_check(bool(quality.get("applied", false)), "production High visual profile applies for evidence")


func _validate_component_audits_and_budgets() -> void:
	var aggregate_meshes := 0
	var aggregate_mesh_budget := 0
	var aggregate_materials := 0
	var aggregate_material_budget := 0
	var aggregate_labels := 0
	var prohibited_totals := {
		"collision_nodes": 0,
		"physics_query_nodes": 0,
		"lights": 0,
		"audio_nodes": 0,
		"particle_emitters": 0,
		"timers": 0,
	}
	for berth_id in BERTH_ORDER:
		var feedback := _feedback_by_berth.get(berth_id) as ShipBerthFeedback
		if feedback == null:
			continue
		var audit := feedback.get_audit_report()
		var performance := feedback.get_performance_report()
		_check(_report_is_valid(audit), "%s feedback passes its deep component audit" % berth_id)
		_check(bool(performance.get("within_budget", false)), "%s feedback stays within component budget" % berth_id)
		_check(
			int(performance.get("mesh_instances", -1)) == EXPECTED_MESHES_PER_COMPONENT
			and int(performance.get("mesh_budget", -1)) == EXPECTED_MESHES_PER_COMPONENT,
			"%s owns exactly sixteen budgeted presentation meshes" % berth_id
		)
		_check(
			int(performance.get("material_resources", -1)) == EXPECTED_MATERIALS_PER_COMPONENT
			and int(performance.get("material_resources", -1)) \
				<= int(performance.get("material_budget", -1)),
			"%s owns four instance-local materials within its five-material ceiling" % berth_id
		)
		_check(
			bool(performance.get("deterministic_manual_clock", false))
			and not bool(performance.get("runtime_node_allocation", true))
			and not bool(performance.get("runtime_resource_allocation", true)),
			"%s exposes a deterministic allocation-free presentation clock" % berth_id
		)
		aggregate_meshes += int(performance.get("mesh_instances", 0))
		aggregate_mesh_budget += int(performance.get("mesh_budget", 0))
		aggregate_materials += int(performance.get("material_resources", 0))
		aggregate_material_budget += int(performance.get("material_budget", 0))
		aggregate_labels += int(performance.get("labels", 0))
		for key: String in prohibited_totals:
			var count := int(performance.get(key, 0))
			prohibited_totals[key] = int(prohibited_totals[key]) + count
			_check(count == 0, "%s feedback adds no %s" % [berth_id, key])
	_check(
		aggregate_meshes == EXPECTED_COMPONENT_COUNT * EXPECTED_MESHES_PER_COMPONENT
		and aggregate_meshes <= aggregate_mesh_budget,
		"four-component roster owns exactly 64 meshes within aggregate budget"
	)
	_check(
		aggregate_materials == EXPECTED_COMPONENT_COUNT * EXPECTED_MATERIALS_PER_COMPONENT
		and aggregate_materials <= aggregate_material_budget,
		"four-component roster owns exactly 16 isolated materials within aggregate budget"
	)
	_check(aggregate_labels == EXPECTED_COMPONENT_COUNT, "four-component roster owns exactly four diegetic labels")
	for key: String in prohibited_totals:
		_check(int(prohibited_totals[key]) == 0, "aggregate feedback roster owns zero %s" % key)
	print(
		"BERTH_FEEDBACK_BUDGET: components=%d meshes=%d/%d materials=%d/%d labels=%d prohibited=%s"
		% [
			EXPECTED_COMPONENT_COUNT,
			aggregate_meshes,
			aggregate_mesh_budget,
			aggregate_materials,
			aggregate_material_budget,
			aggregate_labels,
			str(prohibited_totals),
		]
	)


func _capture_berth_state_sequence(berth_id: StringName) -> void:
	var ship := _ships_by_berth.get(berth_id) as HeroShip
	var berth := _world.get_berth_node(berth_id)
	var feedback := _feedback_by_berth.get(berth_id) as ShipBerthFeedback
	if ship == null or berth == null or feedback == null:
		_fail("%s cannot run its state sequence because production dependencies are missing" % berth_id)
		return

	var anchors := _get_berth_frame_anchors(berth, feedback, ship)
	_frame_berth(berth_id, berth, anchors)
	_validate_frame_anchors(berth_id, anchors)

	# Boot begins occupied. GameFlow owns the opaque token map, so every mutation
	# runs through its existing coordinator and therefore through ShipBerth's real
	# release/try_reserve/occupy contract.
	_game.call("_release_ship_berth", ship)
	await process_frame
	await _capture_state(berth_id, &"released", berth, feedback, ship, anchors)

	var reserved := bool(_game.call("_reserve_berth_for_ship", ship, berth_id, false))
	_check(reserved, "%s acquires a real pending reservation through GameFlow" % berth_id)
	await process_frame
	await _capture_state(berth_id, &"approach", berth, feedback, ship, anchors)

	var occupied := bool(_game.call("_occupy_reserved_berth", ship))
	_check(occupied, "%s converts the exact pending lease to real occupancy" % berth_id)
	await process_frame
	await _capture_state(berth_id, &"occupied", berth, feedback, ship, anchors)


func _capture_state(
	berth_id: StringName,
	expected_state: StringName,
	berth: ShipBerth,
	feedback: ShipBerthFeedback,
	ship: HeroShip,
	anchors: PackedVector3Array
	) -> void:
	feedback.seek_simulation(MANUAL_FEEDBACK_TIME)
	_validate_lease_and_feedback_state(berth_id, expected_state, berth, feedback, ship)
	_validate_other_berths_remain_occupied(berth_id)
	_validate_ship_was_not_staged(berth_id, ship)
	var file_name := str((CAPTURE_FILES[berth_id] as Dictionary)[expected_state])
	_capture_contracts[file_name] = {
		"berth_id": berth_id,
		"state": expected_state,
		"anchors": anchors.duplicate(),
	}
	await _settle_render(7)
	_validate_frame_anchors(berth_id, anchors)
	await _capture(file_name)


func _validate_lease_and_feedback_state(
	berth_id: StringName,
	expected_state: StringName,
	berth: ShipBerth,
	feedback: ShipBerthFeedback,
	ship: HeroShip
	) -> void:
	var owner := berth.get_reservation_owner()
	var occupant := berth.get_occupant()
	var reserved_ship_id := berth.get_reserved_ship_id()
	var token := berth.get_reservation_token(ship)
	var snapshot := feedback.get_state_snapshot()
	var berth_audit := berth.get_audit_report()
	var feedback_audit := feedback.get_audit_report()
	var expected_label: String = {
		&"released": "BERTH OPEN",
		&"approach": "APPROACH VECTOR",
		&"occupied": "BERTH SECURED",
	}[expected_state]

	if expected_state == &"released":
		_check(
			owner == null and occupant == null and reserved_ship_id.is_empty() and token.is_empty(),
			"%s RELEASED has no owner, occupant, ship identity, or token" % berth_id
		)
		_check(
			int(snapshot.get("reservation_owner_instance_id", -1)) == 0
			and int(snapshot.get("occupant_instance_id", -1)) == 0,
			"%s RELEASED snapshot publishes no lease identities" % berth_id
		)
	elif expected_state == &"approach":
		_check(
			owner == ship and occupant == null and reserved_ship_id == ship.get_ship_id(),
			"%s APPROACH is a real reserved-only lease" % berth_id
		)
		_check(
			not token.is_empty() and berth.has_valid_lease(ship, token, ship.get_ship_id()),
			"%s APPROACH retains its valid opaque production token" % berth_id
		)
		_check(
			int(snapshot.get("reservation_owner_instance_id", 0)) == ship.get_instance_id()
			and int(snapshot.get("occupant_instance_id", -1)) == 0,
			"%s APPROACH snapshot distinguishes reservation from occupancy" % berth_id
		)
	else:
		_check(
			owner == ship and occupant == ship and reserved_ship_id == ship.get_ship_id(),
			"%s OCCUPIED is owned and occupied by its production craft" % berth_id
		)
		_check(
			not token.is_empty() and berth.has_valid_lease(ship, token, ship.get_ship_id()),
			"%s OCCUPIED retains the same valid opaque lease authority" % berth_id
		)
		_check(
			int(snapshot.get("reservation_owner_instance_id", 0)) == ship.get_instance_id()
			and int(snapshot.get("occupant_instance_id", 0)) == ship.get_instance_id(),
			"%s OCCUPIED snapshot publishes matching owner and occupant" % berth_id
		)

	_check(
		feedback.get_feedback_state() == expected_state
		and StringName(snapshot.get("state", &"")) == expected_state
		and StringName(feedback_audit.get("state", &"")) == expected_state,
		"%s component, snapshot, and audit all render %s" % [berth_id, expected_state]
	)
	_check(
		StringName(snapshot.get("berth_id", &"")) == berth_id
		and StringName(feedback_audit.get("berth_id", &"")) == berth_id,
		"%s state evidence remains bound to the authoritative berth ID" % berth_id
	)
	_check(str(snapshot.get("label", "")) == expected_label, "%s %s uses its exact diegetic label" % [berth_id, expected_state])
	_check(
		is_equal_approx(float(snapshot.get("elapsed", -1.0)), MANUAL_FEEDBACK_TIME)
		and is_equal_approx(float(snapshot.get("phase", -1.0)), MANUAL_FEEDBACK_TIME)
		and bool(snapshot.get("enabled", false))
		and not bool(snapshot.get("paused", true))
		and not bool(snapshot.get("auto_advance", true)),
		"%s %s uses the deterministic manual presentation clock" % [berth_id, expected_state]
	)
	_check(_report_is_valid(berth_audit), "%s physical berth audit stays valid in %s" % [berth_id, expected_state])
	_check(_report_is_valid(feedback_audit), "%s feedback audit stays valid in %s" % [berth_id, expected_state])
	_check(
		bool(berth_audit.get("reserved", false)) == (expected_state != &"released")
		and bool(berth_audit.get("occupied", false)) == (expected_state == &"occupied"),
		"%s physical audit booleans exactly encode %s" % [berth_id, expected_state]
	)
	var world_audit := _world.get_ship_berth_feedback_audit_report()
	var placement := (world_audit.get("placements", {}) as Dictionary).get(berth_id, {}) as Dictionary
	_check(_report_is_valid(world_audit), "world feedback integration audit stays valid during %s %s" % [berth_id, expected_state])
	_check(
		StringName(placement.get("state", &"")) == expected_state,
		"world audit independently reports %s %s" % [berth_id, expected_state]
	)


func _validate_other_berths_remain_occupied(active_berth_id: StringName) -> void:
	for berth_id in BERTH_ORDER:
		if berth_id == active_berth_id:
			continue
		var ship := _ships_by_berth.get(berth_id) as HeroShip
		var berth := _world.get_berth_node(berth_id)
		var feedback := _feedback_by_berth.get(berth_id) as ShipBerthFeedback
		_check(
			berth != null and ship != null and feedback != null
			and berth.get_reservation_owner() == ship
			and berth.get_occupant() == ship
			and feedback.get_feedback_state() == &"occupied",
			"controlled %s transition leaves %s authentically occupied" % [active_berth_id, berth_id]
		)


func _validate_ship_was_not_staged(berth_id: StringName, ship: HeroShip) -> void:
	var initial := _initial_ship_transforms.get(berth_id, Transform3D.IDENTITY) as Transform3D
	var telemetry := ship.get_telemetry()
	_check(
		ship.global_transform.is_equal_approx(initial),
		"%s evidence changes only lease state and never stages the production craft" % berth_id
	)
	_check(
		bool(telemetry.get("landed", false))
		and str(telemetry.get("engine_state", "")) == "OFFLINE",
		"%s craft remains physically landed and powered off throughout evidence" % berth_id
	)


func _get_berth_frame_anchors(
	berth: ShipBerth,
	feedback: ShipBerthFeedback,
	ship: HeroShip
	) -> PackedVector3Array:
	var points := PackedVector3Array()
	var feedback_aabb := feedback.get_audit_report().get("render_local_aabb", AABB()) as AABB
	_append_aabb_corners(points, feedback.global_transform, feedback_aabb)
	var collision_report := ship.get_landing_collision_report()
	if bool(collision_report.get("valid", false)):
		_append_aabb_corners(
			points,
			ship.global_transform,
			collision_report.get("local_bounds", AABB()) as AABB
		)
	points.append(berth.get_dock_transform().origin + Vector3.UP * 0.35)
	return points


func _append_aabb_corners(
	points: PackedVector3Array,
	box_transform: Transform3D,
	box: AABB
	) -> void:
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				points.append(box_transform * Vector3(x, y, z))


func _frame_berth(
	berth_id: StringName,
	berth: ShipBerth,
	points: PackedVector3Array
	) -> void:
	if points.is_empty():
		_fail("%s has no semantic framing anchors" % berth_id)
		return
	var bounds := _point_bounds(points)
	var centre := ((bounds.minimum as Vector3) + (bounds.maximum as Vector3)) * 0.5
	var radius := 1.0
	for point in points:
		radius = maxf(radius, point.distance_to(centre))
	var field_of_view := float(CAMERA_FOV.get(berth_id, 45.0))
	var vertical_fov := deg_to_rad(field_of_view)
	var aspect := float(CAPTURE_RESOLUTION.x) / float(CAPTURE_RESOLUTION.y)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var limiting_fov := minf(vertical_fov, horizontal_fov)
	var distance := maxf(12.0, radius / tan(limiting_fov * 0.5) * 1.18)
	var local_direction := CAMERA_LOCAL_DIRECTIONS.get(berth_id, Vector3(0.75, 0.9, 0.8)) as Vector3
	var direction := (berth.global_basis * local_direction).normalized()
	_camera.global_position = centre + direction * distance
	_camera.fov = field_of_view
	_camera.look_at(centre, Vector3.UP)
	_camera.current = true
	print(
		"BERTH_FEEDBACK_CAMERA: berth=%s position=%s focus=%s fov=%.1f radius=%.2f"
		% [berth_id, str(_camera.global_position), str(centre), field_of_view, radius]
	)


func _validate_frame_anchors(berth_id: StringName, anchors: PackedVector3Array) -> void:
	var clipped: Array[String] = []
	for index in anchors.size():
		var point := anchors[index]
		if _camera.is_position_behind(point):
			clipped.append("%d:behind" % index)
			continue
		var distance := _camera.global_position.distance_to(point)
		if distance <= _camera.near * 1.2 or distance >= _camera.far * 0.98:
			clipped.append("%d:depth" % index)
			continue
		var screen_position := _camera.unproject_position(point)
		var minimum := Vector2(CAPTURE_RESOLUTION) * FRAME_MARGIN_FRACTION
		var maximum := Vector2(CAPTURE_RESOLUTION) - minimum
		if (
			screen_position.x < minimum.x
			or screen_position.y < minimum.y
			or screen_position.x > maximum.x
			or screen_position.y > maximum.y
		):
			clipped.append("%d:frame" % index)
	_check(
		clipped.is_empty(),
		"%s keeps all %d berth/craft anchors inside the camera frustum"
		% [berth_id, anchors.size()]
	)


func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced an empty viewport image" % file_name)
		return
	var actual_size := Vector2i(image.get_width(), image.get_height())
	_check(
		actual_size == CAPTURE_RESOLUTION,
		"%s is exactly %dx%d" % [file_name, CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
	)
	if actual_size != CAPTURE_RESOLUTION:
		return

	var statistics := _sample_luminance_statistics(image)
	var luminance_range := float(statistics.get("range", 0.0))
	var variance := float(statistics.get("variance", 0.0))
	_check(
		luminance_range >= MINIMUM_LUMINANCE_RANGE,
		"%s is nonblank (luminance range %.5f)" % [file_name, luminance_range]
	)
	_check(
		variance >= MINIMUM_LUMINANCE_VARIANCE,
		"%s contains tonal detail (variance %.6f)" % [file_name, variance]
	)

	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saves successfully" % file_name)
	if save_error != OK:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var byte_count := file.get_length() if file != null else 0
	_check(
		byte_count >= MINIMUM_PNG_BYTES,
		"%s contains substantive rendered detail (%d bytes)" % [file_name, byte_count]
	)
	_captured_images[file_name] = image
	_capture_order.append(file_name)
	print(
		"BERTH_FEEDBACK_CAPTURED: %s  %dx%d  %d bytes  range=%.5f variance=%.6f"
		% [
			ProjectSettings.globalize_path(path),
			actual_size.x,
			actual_size.y,
			byte_count,
			luminance_range,
			variance,
		]
	)


func _sample_luminance_statistics(image: Image) -> Dictionary:
	var darkest := 1.0
	var brightest := 0.0
	var total := 0.0
	var total_squared := 0.0
	var sample_count := 0
	for sample_y in 45:
		var y := roundi(float(sample_y) / 44.0 * float(image.get_height() - 1))
		for sample_x in 80:
			var x := roundi(float(sample_x) / 79.0 * float(image.get_width() - 1))
			var luminance := image.get_pixel(x, y).get_luminance()
			darkest = minf(darkest, luminance)
			brightest = maxf(brightest, luminance)
			total += luminance
			total_squared += luminance * luminance
			sample_count += 1
	var mean := total / float(sample_count)
	var variance := maxf(0.0, total_squared / float(sample_count) - mean * mean)
	return {
		"range": brightest - darkest,
		"mean": mean,
		"variance": variance,
	}


func _validate_capture_set() -> void:
	var expected_file_count := BERTH_ORDER.size() * STATE_ORDER.size()
	_check(_capture_order.size() == expected_file_count, "exactly twelve berth-state frames were captured")
	_check(_captured_images.size() == expected_file_count, "all twelve captured images have distinct filenames")
	_check(_capture_contracts.size() == expected_file_count, "all twelve frames retain semantic berth/state contracts")
	for berth_id in BERTH_ORDER:
		for state in STATE_ORDER:
			var file_name := str((CAPTURE_FILES[berth_id] as Dictionary)[state])
			_check(_captured_images.has(file_name), "required berth-state frame exists: %s" % file_name)
			_check(FileAccess.file_exists("%s/%s" % [OUTPUT_DIR, file_name]), "required PNG is present on disk: %s" % file_name)

	var closest_pair := ""
	var closest_mean := INF
	var closest_changed_fraction := 1.0
	for first_index in _capture_order.size():
		for second_index in range(first_index + 1, _capture_order.size()):
			var first_name := _capture_order[first_index]
			var second_name := _capture_order[second_index]
			var comparison := _compare_images(
				_captured_images[first_name] as Image,
				_captured_images[second_name] as Image
			)
			var mean_difference := float(comparison.get("mean_difference", 0.0))
			var changed_fraction := float(comparison.get("changed_fraction", 0.0))
			if mean_difference < closest_mean:
				closest_mean = mean_difference
				closest_changed_fraction = changed_fraction
				closest_pair = "%s / %s" % [first_name, second_name]
			_check(
				mean_difference >= MINIMUM_PAIR_MEAN_DIFFERENCE
				or changed_fraction >= MINIMUM_PAIR_CHANGED_FRACTION,
				"%s and %s are visually distinct (mean %.5f, changed %.4f)"
				% [first_name, second_name, mean_difference, changed_fraction]
			)
	print(
		"BERTH_FEEDBACK_VARIATION: closest=%s mean=%.5f changed=%.4f"
		% [closest_pair, closest_mean, closest_changed_fraction]
	)


func _compare_images(first: Image, second: Image) -> Dictionary:
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for sample_y in 72:
		var normalized_y := float(sample_y) / 71.0
		var first_y := roundi(normalized_y * float(first.get_height() - 1))
		var second_y := roundi(normalized_y * float(second.get_height() - 1))
		for sample_x in 128:
			var normalized_x := float(sample_x) / 127.0
			var first_x := roundi(normalized_x * float(first.get_width() - 1))
			var second_x := roundi(normalized_x * float(second.get_width() - 1))
			var first_pixel := first.get_pixel(first_x, first_y)
			var second_pixel := second.get_pixel(second_x, second_y)
			var difference := (
				absf(first_pixel.r - second_pixel.r)
				+ absf(first_pixel.g - second_pixel.g)
				+ absf(first_pixel.b - second_pixel.b)
			) / 3.0
			total_difference += difference
			if difference >= PIXEL_CHANGE_THRESHOLD:
				changed_pixels += 1
			sample_count += 1
	return {
		"mean_difference": total_difference / float(sample_count),
		"changed_fraction": float(changed_pixels) / float(sample_count),
	}


func _validate_all_berths_restored() -> void:
	for berth_id in BERTH_ORDER:
		var ship := _ships_by_berth.get(berth_id) as HeroShip
		var berth := _world.get_berth_node(berth_id)
		var feedback := _feedback_by_berth.get(berth_id) as ShipBerthFeedback
		_check(
			berth != null and ship != null and feedback != null
			and berth.get_reservation_owner() == ship
			and berth.get_occupant() == ship
			and feedback.get_feedback_state() == &"occupied",
			"%s is restored to its production occupied lease" % berth_id
		)
		if ship != null:
			_validate_ship_was_not_staged(berth_id, ship)
	_check(
		_report_is_valid(_world.get_ship_berth_feedback_audit_report()),
		"final four-component production feedback audit is valid"
	)


func _point_bounds(points: PackedVector3Array) -> Dictionary:
	if points.is_empty():
		return {"minimum": Vector3.ZERO, "maximum": Vector3.ZERO}
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return {"minimum": minimum, "maximum": maximum}


func _report_is_valid(report: Dictionary) -> bool:
	return bool(report.get("valid", false)) and _error_count(report.get("errors", [])) == 0


func _error_count(value: Variant) -> int:
	if value is PackedStringArray:
		return (value as PackedStringArray).size()
	if value is Array:
		return (value as Array).size()
	return 0 if value == null else 1


func _node_sets_match(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for candidate in first:
		if not second.has(candidate):
			return false
	return true


func _string_name_arrays_match(first: Array[StringName], second: Array[StringName]) -> bool:
	if first.size() != second.size():
		return false
	for value in first:
		if not second.has(value):
			return false
	return true


func _settle_render(frame_count: int = 7) -> void:
	for _index in frame_count:
		await process_frame


func _dispose_game() -> void:
	if is_instance_valid(_game):
		_game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("BERTH_FEEDBACK_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("BERTH_FEEDBACK_FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"SHIP_BERTH_FEEDBACK_CAPTURE_OK: %d HUD-off Forward+ frames at %dx%d"
			% [_capture_order.size(), CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
		)
		quit(0)
	else:
		push_error("SHIP_BERTH_FEEDBACK_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)
