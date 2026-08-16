extends SceneTree

## HUD-free Forward+ evidence harness for the operational station lattice.
##
## This runner instantiates the complete production scene so the five live
## spacecraft, their direct world berths, the station modules, operational
## activity, and positional ambience are reviewed as one integrated world. It
## never adds capture-only architecture or signage. The only staged objects are
## a temporary evidence camera, deterministic presentation clocks, and the
## Torrent's final real departure for the flypast frame.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/station_operations"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const CAPTURE_FILES: Array[String] = [
	"01_exposed_lattice_overview.png",
	"02_central_berth_operations.png",
	"03_aft_operations_route.png",
	"04_habitat_service_access.png",
	"05_jovian_freight_operations.png",
	"06_launch_landmark_flypast.png",
	"07_original_identity_backdrop.png",
]

const EXPECTED_SHIP_IDS: Array[StringName] = [
	&"arrow_provisional",
	&"halyard_new_design",
	&"jovian_provisional",
	&"torrent_provisional",
	&"zenith_b7_observed",
]
const EXPECTED_BERTH_IDS: Array[StringName] = [
	&"arrow_recon_berth",
	&"central_berth",
	&"halyard_fleet_dock_berth",
	&"jovian_freight_berth",
	&"zenith_fleet_dock_berth",
]

const WORLD_ACTIVITY_GETTER := &"get_station_operations_activities"
const WORLD_AMBIENCE_GETTER := &"get_station_machinery_ambience_nodes"
const WORLD_OPERATIONS_AUDIT_GETTER := &"get_operational_lattice_audit_report"
const WORLD_ACTIVITY_ENABLE_SETTER := &"set_station_activity_enabled"
const ACTIVITY_GROUP := &"station_operations_activity"
const AMBIENCE_GROUP := &"station_machinery_ambience"

## Re-frozen from 4 by the station-life pass: the four original fixed-rail roles
## plus the cargo line, wayfinding pylon, skywatch post and crew work post.
##
## Re-frozen again from 8 by the long-cargo pass, which added a 21.6 m transfer
## run to each branch arm. The profile list below is a sorted multiset and keeps
## `cargo_line_long` twice on purpose.
const EXPECTED_ACTIVITY_COUNT := 10
const EXPECTED_AMBIENCE_COUNT := 4
const EXPECTED_ACTIVITY_PROFILES: Array[String] = [
	"cargo_line",
	"cargo_line_long",
	"cargo_line_long",
	"crew_workpost",
	"drone_patrol",
	"full",
	"gantry",
	"observatory",
	"service_arm",
	"signage_pylon",
]
const MINIMUM_SIGN_COUNT := 16
const MINIMUM_PNG_BYTES := 140_000
const MINIMUM_LUMINANCE_RANGE := 0.035
const MINIMUM_LUMINANCE_VARIANCE := 0.00010
const NEAR_DUPLICATE_MEAN_DIFFERENCE := 0.006
const NEAR_DUPLICATE_CHANGED_FRACTION := 0.055
const PIXEL_CHANGE_THRESHOLD := 0.035
const FRAME_MARGIN_FRACTION := 0.018
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "KETH_CAPTURE_STATION_OPERATIONS_PARSE_ONLY"

var _failures: Array[String] = []
var _captured_images: Dictionary = {}
var _capture_order: Array[String] = []
var _capture_anchor_sets: Dictionary = {}

var _game: Node3D
var _world: ShipyardWorld
var _ships: Array[HeroShip] = []
var _activities: Array[StationOperationsActivity] = []
var _ambience_nodes: Array[Node] = []
var _aft: AftJunctionStack
var _habitat: HabitatSpine
var _freight: JovianFreightBerth
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# This explicit path lets maintainers prove parser/resource cleanliness before
	# the integrated production nodes are stable, without creating evidence files.
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("STATION_OPERATIONS_CAPTURE_PARSE_OK")
		quit(0)
		return

	_configure_capture_viewport()
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	print(
		"STATION_OPERATIONS_RENDERER: method=%s adapter=%s display=%s requested=%dx%d"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			DisplayServer.get_name(),
			CAPTURE_RESOLUTION.x,
			CAPTURE_RESOLUTION.y,
		]
	)

	_game = MAIN_SCENE.instantiate() as Node3D
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
	_validate_no_capture_ui()
	_validate_fleet_and_berths()
	_validate_station_modules()
	_discover_operational_components()
	_validate_operational_components()
	_validate_station_signage()

	# Do not write stale station imagery if the production integration contract is
	# absent or invalid. Normal evidence rendering begins only after every required
	# gameplay, evidence, lifecycle, and audio dependency above has passed.
	if not _failures.is_empty():
		await _dispose_game()
		_finish()
		return

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_check(
		directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
		"station-operations output directory is available"
	)
	if not _failures.is_empty():
		await _dispose_game()
		_finish()
		return

	_prepare_deterministic_activity()
	_camera = Camera3D.new()
	_camera.name = "StationOperationsEvidenceCamera"
	_camera.near = 0.08
	_camera.far = 2500.0
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_game.add_child(_camera)
	_camera.current = true

	await _capture_lattice_overview()
	await _capture_central_operations()
	await _capture_aft_operations()
	await _capture_habitat_operations()
	await _capture_freight_operations()
	await _capture_launch_flypast()
	await _capture_original_identity_backdrop()

	_validate_capture_set()
	Input.action_release("move_forward")
	for ship in _ships:
		if is_instance_valid(ship) and ship.is_piloted():
			ship.set_piloted(false)
	await _dispose_game()
	_finish()


func _configure_capture_viewport() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X


func _resolve_production_contracts() -> bool:
	_world = _game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_aft = _world.get_node_or_null("AftJunctionStack") as AftJunctionStack if _world != null else null
	_habitat = _world.get_habitat_spine() if _world != null else null
	_freight = _world.get_jovian_freight_berth() if _world != null else null
	_check(_world != null, "production ShipyardWorld exists")
	_check(_aft != null, "integrated Aft Junction Stack exists")
	_check(_habitat != null, "integrated Habitat Spine exists")
	_check(_freight != null, "integrated Jovian freight berth exists")
	_check(_game.has_method("get_flyable_ships"), "main scene publishes its live flyable-fleet registry")
	return _world != null and _aft != null and _habitat != null and _freight != null \
		and _game.has_method("get_flyable_ships")


func _disable_all_canvas_layers() -> void:
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED


func _validate_no_capture_ui() -> void:
	var canvas_layers := _game.find_children("*", "CanvasLayer", true, false)
	var visible_layers: Array[String] = []
	for candidate in canvas_layers:
		var layer := candidate as CanvasLayer
		if layer.visible:
			visible_layers.append(str(layer.get_path()))
	_check(not canvas_layers.is_empty(), "production HUD exists and can be explicitly excluded")
	_check(visible_layers.is_empty(), "all HUD and CanvasLayer presentation is disabled for evidence")
	_check(
		_game.find_child("StationOperationsEvidenceCamera", true, false) == null,
		"production tree contains no pre-authored evidence camera"
	)


func _validate_fleet_and_berths() -> void:
	_ships = _game.call("get_flyable_ships") as Array[HeroShip]
	var ship_ids: Array[StringName] = []
	var home_berth_ids: Array[StringName] = []
	for ship in _ships:
		ship_ids.append(ship.get_ship_id())
		home_berth_ids.append(ship.get_home_berth_id())
	ship_ids.sort()
	home_berth_ids.sort()
	var berth_ids := _world.get_berth_ids()
	berth_ids.sort()
	print(
		"STATION_OPERATIONS_FLEET_CONTRACT: ships=%s berths=%s homes=%s"
		% [str(ship_ids), str(berth_ids), str(home_berth_ids)]
	)
	_check(_ships.size() == 5, "capture world contains exactly five flyable spacecraft")
	_check(
		_string_name_arrays_match(ship_ids, EXPECTED_SHIP_IDS),
		"flyable fleet is exactly Arrow, Halyard, Jovian, Torrent, and Zenith"
	)
	_check(
		_string_name_arrays_match(berth_ids, EXPECTED_BERTH_IDS),
		"world registry contains exactly five physical berths"
	)
	_check(
		_string_name_arrays_match(home_berth_ids, EXPECTED_BERTH_IDS),
		"each flyable owns one distinct registered home berth"
	)
	for ship in _ships:
		var berth_id := ship.get_home_berth_id()
		var berth := _world.get_berth_node(berth_id)
		_check(berth != null, "%s resolves its direct ShipBerth" % ship.get_ship_id())
		if berth == null:
			continue
		_check(
			berth.get_validation_errors().is_empty(),
			"%s berth contract is valid" % berth_id
		)
		_check(
			ship.global_transform.is_equal_approx(_world.get_berth_transform(berth_id)),
			"%s begins at its exact production berth transform" % ship.get_ship_id()
		)


func _validate_station_modules() -> void:
	_validate_module_evidence(_aft, &"modern_interpretation", "Aft Junction")
	_validate_module_evidence(
		_habitat,
		&"fixed_era_inspired_modern_interpretation",
		"Habitat Spine"
	)
	_validate_module_evidence(
		_freight,
		&"creator_roster_supported_modern_interpretation",
		"Jovian freight berth"
	)
	_check(
		_world.get_node_or_null("ExposedDockLattice") is Node3D
		and _world.get_node_or_null("OpenLaunchSpine") is Node3D,
		"source-bounded exposed lattice and open launch spine remain present"
	)
	var quality := _world.apply_visual_quality(2)
	_check(bool(quality.get("applied", false)), "production High visual profile applies for evidence")


func _validate_module_evidence(module: Node, expected_status: StringName, description: String) -> void:
	_check(module.has_method("get_audit_report"), "%s publishes an audit" % description)
	if not module.has_method("get_audit_report"):
		return
	var value: Variant = module.call("get_audit_report")
	_check(value is Dictionary, "%s audit returns a Dictionary" % description)
	if value is not Dictionary:
		return
	var report := value as Dictionary
	_check(_report_is_valid(report), "%s production audit is valid" % description)
	var evidence := report.get("evidence", {}) as Dictionary
	_check(
		StringName(evidence.get("evidence_status", &"")) == expected_status,
		"%s retains its bounded evidence status" % description
	)
	_check(bool(evidence.get("source_bounded", false)), "%s remains explicitly source-bounded" % description)
	if evidence.has("authenticated_original_geometry"):
		_check(
			not bool(evidence.authenticated_original_geometry),
			"%s rejects an authenticated-original geometry claim" % description
		)


func _discover_operational_components() -> void:
	_check(
		_world.has_method(WORLD_ACTIVITY_GETTER),
		"ShipyardWorld publishes integrated station-activity instances"
	)
	_check(
		_world.has_method(WORLD_AMBIENCE_GETTER),
		"ShipyardWorld publishes integrated positional machinery ambience"
	)
	_check(
		_world.has_method(WORLD_OPERATIONS_AUDIT_GETTER),
		"ShipyardWorld publishes its operational-lattice audit"
	)
	_check(
		_world.has_method(WORLD_ACTIVITY_ENABLE_SETTER),
		"ShipyardWorld publishes a station-activity lifecycle switch"
	)

	_activities.clear()
	if _world.has_method(WORLD_ACTIVITY_GETTER):
		var activity_value: Variant = _world.call(WORLD_ACTIVITY_GETTER)
		if activity_value is Array:
			for candidate: Variant in activity_value as Array:
				if candidate is StationOperationsActivity and not _activities.has(candidate):
					_activities.append(candidate as StationOperationsActivity)

	_ambience_nodes.clear()
	if _world.has_method(WORLD_AMBIENCE_GETTER):
		var ambience_value: Variant = _world.call(WORLD_AMBIENCE_GETTER)
		if ambience_value is Array:
			for candidate: Variant in ambience_value as Array:
				if candidate is Node and not _ambience_nodes.has(candidate):
					_ambience_nodes.append(candidate as Node)

	var grouped_activities: Array[Node] = []
	for candidate in get_nodes_in_group(ACTIVITY_GROUP):
		if candidate is Node and _world.is_ancestor_of(candidate as Node):
			grouped_activities.append(candidate as Node)
	_check(
		_node_sets_match(_activities, grouped_activities),
		"world activity accessor and station_operations_activity group identify the same instances"
	)

	var grouped_ambience: Array[Node] = []
	for candidate in get_nodes_in_group(AMBIENCE_GROUP):
		if candidate is Node and _world.is_ancestor_of(candidate as Node):
			grouped_ambience.append(candidate as Node)
	if not grouped_ambience.is_empty():
		_check(
			_node_sets_match(_ambience_nodes, grouped_ambience),
			"world ambience accessor and station_machinery_ambience group identify the same instances"
		)


func _validate_operational_components() -> void:
	_check(
		_activities.size() == EXPECTED_ACTIVITY_COUNT,
		"station integrates exactly eight role-specific operations vignettes"
	)
	_check(
		_ambience_nodes.size() == EXPECTED_AMBIENCE_COUNT,
		"station integrates exactly four positional machinery ambience zones"
	)
	var activity_contracts: Array[String] = []
	for activity in _activities:
		activity_contracts.append(
			"%s=%s@%s"
			% [activity.get_path(), activity.get_activity_profile_id(), activity.global_position]
		)
	print(
		"STATION_OPERATIONS_ACTIVITY_CONTRACT: count=%d nodes=%s"
		% [_activities.size(), str(activity_contracts)]
	)

	var activity_profiles: Array[String] = []
	for index in _activities.size():
		var activity := _activities[index]
		activity_profiles.append(str(activity.get_activity_profile_id()))
		var audit := activity.get_audit_report()
		var evidence := audit.get("evidence", {}) as Dictionary
		var performance := audit.get("performance", {}) as Dictionary
		var counts := performance.get("counts", {}) as Dictionary
		_check(_report_is_valid(audit), "activity %d passes its reusable component audit" % (index + 1))
		_check(
			StringName(audit.get("evidence_status", &"")) == &"modern_interpretation"
			and StringName(evidence.get("evidence_status", &"")) == &"modern_interpretation",
			"activity %d is explicitly modern interpretation" % (index + 1)
		)
		_check(
			not bool(evidence.get("authenticated_original_geometry", true))
			and not bool(evidence.get("authenticated_original_placement", true)),
			"activity %d makes no historical geometry or placement claim" % (index + 1)
		)
		# Was `collision_nodes == 0`. Reversed with the component's own rule on
		# 2026-08-16: the gantry, service-arm and cargo-line vignettes now carry
		# solid colliders for their own drawn columns, crates and posts. The budget
		# check below is the one that still pins the count exactly, per profile.
		_check(
			bool(performance.get("within_budget", false)),
			"activity %d stays within its published budget" % (index + 1)
		)
	activity_profiles.sort()
	_check(
		activity_profiles == EXPECTED_ACTIVITY_PROFILES,
		"production activity roster contains Full, Gantry, Service Arm, and Drone Patrol exactly once"
	)

	for index in _ambience_nodes.size():
		_validate_ambience_node(_ambience_nodes[index], index)

	if _world.has_method(WORLD_OPERATIONS_AUDIT_GETTER):
		var audit_value: Variant = _world.call(WORLD_OPERATIONS_AUDIT_GETTER)
		_check(audit_value is Dictionary, "operational-lattice audit returns a Dictionary")
		if audit_value is Dictionary:
			var report := audit_value as Dictionary
			print(
				"STATION_OPERATIONS_WORLD_AUDIT: valid=%s errors=%s"
				% [str(report.get("valid", false)), str(report.get("errors", []))]
			)
			_check(_report_is_valid(report), "integrated operational-lattice audit is valid")
			var evidence := report.get("evidence", {}) as Dictionary
			var status := StringName(
				report.get("evidence_status", evidence.get("evidence_status", &""))
			)
			_check(
				status == &"modern_interpretation",
				"integrated operational dressing remains modern interpretation"
			)
			if evidence.has("authenticated_original_geometry"):
				_check(
					not bool(evidence.authenticated_original_geometry),
					"integrated audit rejects an authenticated-original geometry claim"
				)


func _validate_ambience_node(node: Node, index: int) -> void:
	var audit_method := StringName()
	for candidate_method in [&"get_ambience_audit_report", &"get_audit_report"]:
		if node.has_method(candidate_method):
			audit_method = candidate_method
			break
	_check(not audit_method.is_empty(), "ambience %d publishes an audit" % (index + 1))
	if audit_method.is_empty():
		return
	var value: Variant = node.call(audit_method)
	_check(value is Dictionary, "ambience %d audit returns a Dictionary" % (index + 1))
	if value is not Dictionary:
		return
	var report := value as Dictionary
	var evidence := report.get("evidence", {}) as Dictionary
	var synthesis := report.get("synthesis", {}) as Dictionary
	var performance := report.get("performance", {}) as Dictionary
	var status := StringName(report.get("evidence_status", evidence.get("evidence_status", &"")))
	_check(_report_is_valid(report), "ambience %d passes its component audit" % (index + 1))
	_check(status == &"modern_interpretation", "ambience %d is explicitly modern interpretation" % (index + 1))
	_check(
		StringName(evidence.get("design_origin", &"")) == &"project_original_procedural_audio"
		and not bool(evidence.get("historically_supported", true)),
		"ambience %d records original procedural provenance without a historical-audio claim"
		% (index + 1)
	)
	_check(
		bool(synthesis.get("resources_ready", false))
		and bool(performance.get("within_resident_budget", false))
		and int(performance.get("maximum_simultaneous_voices", 0)) == 2,
		"ambience %d keeps deterministic synthesis inside its two-voice memory budget"
		% (index + 1)
	)
	if evidence.has("authenticated_original_geometry"):
		_check(
			not bool(evidence.authenticated_original_geometry),
			"ambience %d makes no authenticated station-layout claim" % (index + 1)
		)

	var emitters := node.find_children("*", "AudioStreamPlayer3D", true, false)
	_check(not emitters.is_empty(), "ambience %d contains positional AudioStreamPlayer3D emitters" % (index + 1))
	for emitter_node in emitters:
		var emitter := emitter_node as AudioStreamPlayer3D
		_check(
			emitter.max_distance > 0.0
			and emitter.max_distance <= 120.0
			and emitter.bus == &"Ambience",
			"ambience %d emitter is finite-range and routed to Ambience" % (index + 1)
		)


func _validate_station_signage() -> void:
	var sign_count := 0
	var malformed: Array[String] = []
	var mirrored: Array[String] = []
	for candidate in _game.find_children("*", "", true, false):
		var sign_text := ""
		var is_sign := false
		if candidate is Label3D and "Sign" in str(candidate.name):
			is_sign = true
			sign_text = (candidate as Label3D).text
		elif candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh is TextMesh and "Sign" in str(candidate.name):
				is_sign = true
				sign_text = (mesh_instance.mesh as TextMesh).text
		if not is_sign:
			continue
		sign_count += 1
		if not _is_clean_sign_text(sign_text):
			malformed.append(str(candidate.get_path()))
		if candidate is Node3D and (candidate as Node3D).global_basis.determinant() <= 0.0001:
			mirrored.append(str(candidate.get_path()))
	_check(sign_count >= MINIMUM_SIGN_COUNT, "integrated station exposes substantive diegetic signage")
	_check(malformed.is_empty(), "station signs contain printable, non-garbled authored text")
	_check(mirrored.is_empty(), "station sign transforms contain no negative-scale mirroring")


func _is_clean_sign_text(value: String) -> bool:
	if value.strip_edges().is_empty() or "�" in value:
		return false
	for character_index in value.length():
		var codepoint := value.unicode_at(character_index)
		if codepoint == 10:
			continue
		if codepoint < 32 or codepoint > 126:
			return false
	return true


func _prepare_deterministic_activity() -> void:
	_world.call(WORLD_ACTIVITY_ENABLE_SETTER, true)
	for index in _activities.size():
		var activity := _activities[index]
		activity.set_activity_enabled(true)
		activity.set_activity_paused(true)
		activity.set_activity_time(2.25 + float(index) * 1.37)
	_freight.set_equipment_animation_enabled(false)
	_freight.advance_equipment_simulation(3.85)


func _capture_lattice_overview() -> void:
	var points := PackedVector3Array()
	_append_footprint_points(points, _aft, _aft.get_integration_footprint())
	_append_footprint_points(points, _habitat, _habitat.get_integration_footprint())
	_append_footprint_points(points, _freight, _freight.get_integration_footprint())
	points.append(_world.get_node("LaunchGate").global_position)
	points.append(_world.get_berth_transform(&"central_berth").origin)
	points.append(_world.get_berth_transform(&"arrow_recon_berth").origin)
	for activity in _activities:
		points.append(activity.global_position + Vector3.UP * 3.0)
	var bounds := _point_bounds(points)
	var size := (bounds.get("maximum", Vector3.ZERO) as Vector3) \
		- (bounds.get("minimum", Vector3.ZERO) as Vector3)
	_check(size.x >= 140.0 and size.z >= 140.0, "overview anchors span the full separated lattice and open endpoints")
	await _render_shot(
		CAPTURE_FILES[0],
		points,
		Vector3(0.82, 0.68, 0.88),
		52.0,
		4.5
	)


func _capture_central_operations() -> void:
	var berth := _world.get_berth_transform(&"central_berth")
	var points := PackedVector3Array([
		berth * Vector3(-13.0, 0.0, -18.0),
		berth * Vector3(13.0, 0.0, -18.0),
		berth * Vector3(-13.0, 0.0, 18.0),
		berth * Vector3(13.0, 0.0, 18.0),
		berth.origin + Vector3.UP * 4.5,
		_world.get_player_spawn().origin + Vector3.UP,
	])
	_append_nearby_activity_points(points, berth.origin, 34.0, 3)
	await _render_shot(
		CAPTURE_FILES[1],
		points,
		Vector3(0.92, 0.58, 0.76),
		48.0,
		7.25
	)


func _capture_aft_operations() -> void:
	var points := _route_points(_aft)
	_append_footprint_points(points, _aft, _aft.get_integration_footprint())
	_append_nearby_activity_points(points, _aft.global_position + Vector3(0.0, 2.5, 10.0), 30.0, 3)
	await _render_shot(
		CAPTURE_FILES[2],
		points,
		Vector3(0.92, 0.56, 0.72),
		50.0,
		10.0
	)


func _capture_habitat_operations() -> void:
	var points := _route_points(_habitat)
	_append_footprint_points(points, _habitat, _habitat.get_integration_footprint())
	_append_nearby_activity_points(points, _habitat.global_position + Vector3(10.0, 2.0, 0.0), 34.0, 3)
	await _render_shot(
		CAPTURE_FILES[3],
		points,
		Vector3(0.90, 0.56, -0.72),
		49.0,
		12.75
	)


func _capture_freight_operations() -> void:
	var points := _route_points(_freight)
	var ship_envelope := _freight.get_ship_clearance_envelope() as Dictionary
	_append_half_extents_points(
		points,
		ship_envelope.get("world_transform", Transform3D.IDENTITY) as Transform3D,
		ship_envelope.get("half_extents", Vector3.ZERO) as Vector3
	)
	# Frame the integrated activity's actual presentation envelope instead of the
	# module's generous placement box. The latter includes intentionally empty
	# clearance and pulled unrelated central-station signage into this evidence.
	for activity in _activities:
		if activity.get_activity_profile_id() == &"gantry" and activity is Node3D:
			_append_footprint_points(
				points,
				activity as Node3D,
				activity.get_integration_contract() as Dictionary
			)
			break
	points.append(_freight.to_global(Vector3(0.0, 13.0, 27.0)))
	await _render_shot(
		CAPTURE_FILES[4],
		points,
		Vector3(0.62, 0.46, 1.0),
		49.0,
		15.5,
		1.06
	)


func _capture_launch_flypast() -> void:
	var torrent := _get_ship(&"torrent_provisional")
	_check(torrent != null, "landmark flypast resolves the production Torrent")
	if torrent == null:
		return
	var home_transform := _world.get_berth_transform(&"central_berth")
	torrent.set_cockpit_view(false)
	torrent.set_piloted(true)
	torrent.request_engine_start()
	if not await _wait_for_engine_state(torrent, "ONLINE", torrent.engine_start_time + 1.5):
		_fail("landmark flypast Torrent did not complete its real engine-start sequence")
		Input.action_release("move_forward")
		torrent.set_piloted(false)
		return
	_camera.current = true
	Input.action_press("move_forward")
	var launch_timeout := create_timer(4.5)
	while (
		torrent.global_position.distance_to(home_transform.origin) < 18.0
		and launch_timeout.time_left > 0.0
	):
		await physics_frame
		await process_frame
	Input.action_release("move_forward")
	var telemetry := torrent.get_telemetry()
	_check(
		torrent.global_position.distance_to(home_transform.origin) >= 18.0
		and not bool(telemetry.get("landed", true))
		and torrent.velocity.length() > 2.0,
		"landmark frame follows a real powered departure through the open launch vector"
	)
	# Freeze only after the departure has been physically proven. This prevents a
	# long exposure to passive drift while keeping the live online presentation.
	torrent.set_piloted(false)
	torrent.velocity = Vector3.ZERO
	torrent.reset_physics_interpolation()
	_camera.current = true

	var points := PackedVector3Array([
		torrent.global_position + Vector3.UP * 2.5,
		_world.get_node("LaunchGate").global_position,
		home_transform.origin + Vector3.UP * 3.0,
	])
	_append_nearby_activity_points(points, _world.get_node("LaunchGate").global_position, 35.0, 2)
	await _render_shot(
		CAPTURE_FILES[5],
		points,
		Vector3(0.86, 0.48, -0.60),
		48.0,
		18.25
	)
	torrent.request_engine_stop()


func _capture_original_identity_backdrop() -> void:
	var audit := _world.get_space_backdrop_audit_report()
	_check(bool(audit.get("valid", false)), "source-bounded production space backdrop audit is green")
	var points := PackedVector3Array([
		_world.get_node("LaunchGate").global_position + Vector3.UP * 6.0,
		_world.get_berth_transform(&"central_berth").origin + Vector3.UP * 4.0,
	])
	var body_specs := audit.get("body_specs", {}) as Dictionary
	for spec_value: Variant in body_specs.values():
		var spec := spec_value as Dictionary
		var centre := spec.get("position", Vector3.ZERO) as Vector3
		var radius := float(spec.get("radius", 0.0))
		points.append(centre)
		points.append(centre + Vector3.RIGHT * radius)
		points.append(centre + Vector3.LEFT * radius)
		points.append(centre + Vector3.UP * radius)
		points.append(centre + Vector3.DOWN * radius)
	await _render_shot(
		CAPTURE_FILES[6],
		points,
		Vector3(0.10, 0.04, 1.0),
		58.0,
		20.0,
		1.08
	)


func _render_shot(
	file_name: String,
	anchors: PackedVector3Array,
	view_direction: Vector3,
	field_of_view: float,
	activity_time: float,
	framing_padding: float = 1.28
) -> void:
	_seek_activity_tableau(activity_time)
	_frame_points(anchors, view_direction, field_of_view, framing_padding)
	await _settle_render(9)
	_validate_frame_anchors(file_name, anchors)
	_capture_anchor_sets[file_name] = anchors.duplicate()
	await _capture(file_name)


func _seek_activity_tableau(base_time: float) -> void:
	for index in _activities.size():
		var activity := _activities[index]
		activity.set_activity_time(base_time + float(index) * 1.37)


func _frame_points(
	points: PackedVector3Array,
	view_direction: Vector3,
	field_of_view: float,
	framing_padding: float
) -> void:
	if points.is_empty():
		_fail("cannot frame an empty semantic anchor set")
		return
	var bounds := _point_bounds(points)
	var centre := ((bounds.minimum as Vector3) + (bounds.maximum as Vector3)) * 0.5
	var radius := 1.0
	for point in points:
		radius = maxf(radius, point.distance_to(centre))
	var vertical_fov := deg_to_rad(field_of_view)
	var aspect := float(CAPTURE_RESOLUTION.x) / float(CAPTURE_RESOLUTION.y)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var limiting_fov := minf(vertical_fov, horizontal_fov)
	var distance := maxf(
		12.0,
		radius / tan(limiting_fov * 0.5) * clampf(framing_padding, 1.02, 2.0)
	)
	var direction := view_direction.normalized()
	if direction.is_zero_approx() or absf(direction.dot(Vector3.UP)) > 0.96:
		direction = Vector3(0.75, 0.55, 0.68).normalized()
	_camera.global_position = centre + direction * distance
	_camera.fov = field_of_view
	_camera.look_at(centre, Vector3.UP)
	_camera.current = true


func _validate_frame_anchors(file_name: String, anchors: PackedVector3Array) -> void:
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
		"%s keeps all %d semantic anchors inside the camera frustum"
		% [file_name, anchors.size()]
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
		"STATION_OPERATIONS_CAPTURED: %s  %dx%d  %d bytes  range=%.5f variance=%.6f"
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
	for sample_y in 36:
		var y := roundi(float(sample_y) / 35.0 * float(image.get_height() - 1))
		for sample_x in 64:
			var x := roundi(float(sample_x) / 63.0 * float(image.get_width() - 1))
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
	_check(_capture_order.size() == CAPTURE_FILES.size(), "exactly seven station-operations frames were captured")
	for file_name in CAPTURE_FILES:
		_check(_captured_images.has(file_name), "required station-operations frame exists: %s" % file_name)
		_check(
			_capture_anchor_sets.has(file_name),
			"required frame has a semantic anti-clipping contract: %s" % file_name
		)
		_check(
			FileAccess.file_exists("%s/%s" % [OUTPUT_DIR, file_name]),
			"required station-operations PNG is present on disk: %s" % file_name
		)

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
			if (
				mean_difference < NEAR_DUPLICATE_MEAN_DIFFERENCE
				and changed_fraction < NEAR_DUPLICATE_CHANGED_FRACTION
			):
				_fail(
					"near-duplicate station frames %s and %s (mean %.5f, changed %.3f)"
					% [first_name, second_name, mean_difference, changed_fraction]
				)
	print(
		"STATION_OPERATIONS_VARIATION: closest=%s mean=%.5f changed=%.3f"
		% [closest_pair, closest_mean, closest_changed_fraction]
	)


func _compare_images(first: Image, second: Image) -> Dictionary:
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for sample_y in 36:
		var normalized_y := float(sample_y) / 35.0
		var first_y := roundi(normalized_y * float(first.get_height() - 1))
		var second_y := roundi(normalized_y * float(second.get_height() - 1))
		for sample_x in 64:
			var normalized_x := float(sample_x) / 63.0
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


func _route_points(module: Node) -> PackedVector3Array:
	var points := PackedVector3Array()
	if not module.has_method("get_route_ids") or not module.has_method("get_route_transform"):
		return points
	var route_value: Variant = module.call("get_route_ids")
	if route_value is not Array:
		return points
	for route_id: Variant in route_value as Array:
		var route_transform: Transform3D = module.call("get_route_transform", StringName(route_id))
		points.append(route_transform.origin + Vector3.UP * 1.0)
	return points


func _append_footprint_points(points: PackedVector3Array, module: Node3D, footprint: Dictionary) -> void:
	if not footprint.has("local_min") or not footprint.has("local_max"):
		return
	var minimum := footprint.local_min as Vector3
	var maximum := footprint.local_max as Vector3
	for x in [minimum.x, maximum.x]:
		for y in [minimum.y, maximum.y]:
			for z in [minimum.z, maximum.z]:
				points.append(module.global_transform * Vector3(x, y, z))


func _append_half_extents_points(
	points: PackedVector3Array,
	box_transform: Transform3D,
	half_extents: Vector3
) -> void:
	for x in [-half_extents.x, half_extents.x]:
		for y in [-half_extents.y, half_extents.y]:
			for z in [-half_extents.z, half_extents.z]:
				points.append(box_transform * Vector3(x, y, z))


func _append_nearby_activity_points(
	points: PackedVector3Array,
	centre: Vector3,
	maximum_distance: float,
	maximum_count: int
) -> void:
	var ranked: Array[Dictionary] = []
	for activity in _activities:
		var position := activity.global_position + Vector3.UP * 3.0
		var distance := position.distance_to(centre)
		if distance <= maximum_distance:
			ranked.append({"position": position, "distance": distance})
	ranked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.distance) < float(second.distance)
	)
	for index in mini(maximum_count, ranked.size()):
		points.append((ranked[index] as Dictionary).position as Vector3)


func _point_bounds(points: PackedVector3Array) -> Dictionary:
	if points.is_empty():
		return {"minimum": Vector3.ZERO, "maximum": Vector3.ZERO}
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return {"minimum": minimum, "maximum": maximum}


func _get_ship(ship_id: StringName) -> HeroShip:
	for ship in _ships:
		if ship.get_ship_id() == ship_id:
			return ship
	return null


func _wait_for_engine_state(ship: HeroShip, expected_state: String, timeout_seconds: float) -> bool:
	var timeout := create_timer(timeout_seconds)
	while str(ship.get_telemetry().get("engine_state", "")) != expected_state and timeout.time_left > 0.0:
		await physics_frame
		await process_frame
	return str(ship.get_telemetry().get("engine_state", "")) == expected_state


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
	var first_values: Array[String] = []
	for value in first:
		first_values.append(str(value))
	for expected in second:
		if str(expected) not in first_values:
			return false
	return true


func _settle_render(frame_count: int = 7) -> void:
	for _index in frame_count:
		await process_frame


func _dispose_game() -> void:
	Input.action_release("move_forward")
	if is_instance_valid(_game):
		_game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("STATION_OPERATIONS_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("STATION_OPERATIONS_FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"STATION_OPERATIONS_CAPTURE_OK: %d HUD-off Forward+ frames at %dx%d"
			% [_capture_order.size(), CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
		)
		quit(0)
	else:
		push_error("STATION_OPERATIONS_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)
