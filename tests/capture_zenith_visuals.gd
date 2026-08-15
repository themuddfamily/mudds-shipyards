extends SceneTree

## Transactional native visual evidence for the production Zenith reconstruction.
##
## This harness instantiates the complete production Main scene, uses its exact
## ZenithInterceptor and world-owned Fleet Dock berth, hides every CanvasLayer,
## and adds one evidence-only camera. Automated gates reject blank, clipped,
## duplicate, incorrectly sized, or severely exposed captures. They deliberately
## do not judge B7 fidelity or visual craftsmanship; original-resolution human
## review remains mandatory before these images can be cited as accepted art.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/zenith_visuals"
const TRANSACTION_DIR := OUTPUT_DIR + "/.capture_transaction"
const EVIDENCE_MANIFEST_PATH := OUTPUT_DIR + "/evidence_manifest.json"
const SOURCE_MANIFEST_PATH := OUTPUT_DIR + "/source_manifest.sha256"
const STAGED_EVIDENCE_MANIFEST_PATH := TRANSACTION_DIR + "/evidence_manifest.json"
const STAGED_SOURCE_MANIFEST_PATH := TRANSACTION_DIR + "/source_manifest.sha256"
const CAPTURE_LOG_PATH := OUTPUT_DIR + "/capture_forward_plus_2560x1440.log"
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "MUDDS_CAPTURE_ZENITH_VISUALS_PARSE_ONLY"

const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const CAPTURE_FILES: Array[String] = [
	"01_fleet_dock_occupied_three_quarter.png",
	"02_true_dorsal_planform.png",
	"03_starboard_profile.png",
	"04_aft_engines_online.png",
	"05_cockpit_canopy_closed.png",
	"06_cockpit_canopy_open.png",
	"07_short_flight_combat.png",
]
const CAPTURE_STATES: Array[String] = [
	"fleet_dock_occupied_three_quarter",
	"true_dorsal_planform",
	"starboard_profile",
	"aft_engines_online",
	"cockpit_canopy_closed",
	"cockpit_canopy_open",
	"short_flight_combat",
]
const SOURCE_ROOTS: Array[String] = [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://default_bus_layout.tres",
	"res://tests/capture_zenith_visuals.gd",
	"res://tests/capture_zenith_visuals.gd.uid",
	"res://tests/zenith_authored_asset_test.gd",
	"res://tests/zenith_authored_asset_test.gd.uid",
	"res://tests/zenith_fleet_dock_integration_test.gd",
	"res://tests/zenith_fleet_dock_integration_test.gd.uid",
	"res://tests/zenith_interceptor_test.gd",
	"res://tests/zenith_interceptor_test.gd.uid",
	"res://scripts",
	"res://scenes",
	"res://assets",
	"res://art_source",
	"res://tools",
]

const EXPECTED_BOUNDS := AABB(
	Vector3(-7.20, -1.05, -5.35),
	Vector3(14.40, 4.25, 10.65)
)
const EXPECTED_BERTH_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3))
const EXPECTED_COMB_TRANSFORM := Transform3D(
	Basis(Vector3.UP, PI * 0.5),
	Vector3(12.0, 4.2, 68.3)
)
const COMBAT_ORIGIN := Vector3(180.0, 54.0, -230.0)
const EXPECTED_CLOSE_TRIANGLES := 47_274
const EXPECTED_FAR_TRIANGLES := 5_412
const EXPECTED_RUNTIME_MESHES := 22
const EXPECTED_RUNTIME_SURFACES := 22
const EXPECTED_MATERIAL_ROLES := 10
const EXPECTED_COLLISION_SHAPE_COUNT := 24
const EXPECTED_COLLISION_GEOMETRY_SHA256 := "7717ba624158dca52c71dc271e13663436b9b9bf52658972f92fbc9e4482c273"
# Re-frozen 2026-08-15 for the cockpit seat/camera anchor correction below.
const EXPECTED_RUNTIME_V2_SHA256 := "d74e5f31665502c714b3ef96d615ebd56a24d99124573da346b8c09e01d54062"
const EXPECTED_INTEGRATION_SHA256 := "a9559c66cd0d743c7cfbd4c4c7d42d63e6e68ddf3a9077a01a4ba06b6b0601fd"
# RE-FROZEN 2026-08-15 with tests/zenith_interceptor_test.gd: the cockpit seat
# anchor moved 1.58 -> 1.11 (it is a feet-frame marker, not a cushion height)
# and the cockpit camera (0, 2.28, -1.24) -> (0, 2.87, -0.80). Modern cockpit
# ergonomics only; the B7 source-core macroform and its evidence scope are
# unchanged, so these captures still show the same silhouette.
const EXPECTED_ANCHORS := {
	&"PilotSeatAnchor": Vector3(0.0, 1.11, -0.55),
	&"BoardingEntry": Vector3(-1.18, 1.62, -0.32),
	&"BoardingPoint": Vector3(-7.65, -0.55, 0.55),
	&"ExitPoint": Vector3(-7.85, -0.55, 0.85),
	&"LeftMuzzle": Vector3(-1.25, 0.34, -4.25),
	&"RightMuzzle": Vector3(1.25, 0.34, -4.25),
	&"CockpitCamera": Vector3(0.0, 2.87, -0.80),
	&"DockingReceiver": Vector3(0.0, -0.82, 1.05),
	&"DamageCenter": Vector3(0.0, 0.48, 0.0),
	&"DamagePortWing": Vector3(-4.55, 0.18, 0.20),
	&"DamageStarboardWing": Vector3(4.55, 0.18, 0.20),
	&"PortEnginePlume": Vector3(-2.20, 0.38, 4.95),
	&"StarboardEnginePlume": Vector3(2.20, 0.38, 4.95),
}

const MINIMUM_PNG_BYTES := 120_000
const MINIMUM_LUMINANCE_RANGE := 0.045
const MINIMUM_LUMINANCE_VARIANCE := 0.00012
const MINIMUM_MEAN_LUMINANCE := 0.025
const MAXIMUM_MEAN_LUMINANCE := 0.82
const MAXIMUM_DARK_CLIP_FRACTION := 0.82
const MAXIMUM_BRIGHT_CLIP_FRACTION := 0.24
const MINIMUM_SHIP_SCREEN_FRACTION := 0.055
const MINIMUM_CANOPY_CHANGED_FRACTION := 0.002
const PIXEL_CHANGE_THRESHOLD := 0.045

var _failures: Array[String] = []
var _game: GameFlow
var _world: ShipyardWorld
var _zenith: ZenithInterceptor
var _berth: ShipBerth
var _comb: FleetDockComb
var _opponent: RangeOpponent
var _camera: Camera3D

var _source_paths := PackedStringArray()
var _source_snapshot: Dictionary = {}
var _source_aggregate_sha256 := ""
var _source_frozen_validated := false
var _semantic_frames: Array[Dictionary] = []
var _captured_images: Dictionary = {}
var _pair_metrics: Dictionary = {}
var _production_contract_snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("MUDDS_CAPTURE_ZENITH_VISUALS_PARSE_OK")
		quit(0)
		return

	_reset_capture_transaction()
	_source_paths = _collect_source_paths()
	_source_snapshot = _snapshot_source_files(_source_paths)
	_source_aggregate_sha256 = _source_snapshot_hash(_source_snapshot, _source_paths)
	_check(_source_paths.size() > SOURCE_ROOTS.size(), "source freeze expands declared production roots")
	_check(not _source_aggregate_sha256.is_empty(), "source freeze has a nonempty aggregate SHA-256")
	if not _failures.is_empty():
		_finish()
		return

	_configure_native_viewport()
	_validate_native_renderer()
	if not _failures.is_empty():
		_finish()
		return

	_game = MAIN_SCENE.instantiate() as GameFlow
	_check(_game != null, "complete production Main scene instantiates")
	if _game == null:
		_finish()
		return
	root.add_child(_game)
	await _settle_render(12)
	await physics_frame

	if not _resolve_and_validate_production_contracts():
		await _dispose_game()
		_finish()
		return
	_disable_all_canvas_layers()
	_validate_hud_policy()
	var quality := _world.apply_visual_quality(2)
	_check(bool(quality.get("applied", false)), "production High visual profile applies")
	_install_capture_camera()
	if not _failures.is_empty():
		await _dispose_game()
		_finish()
		return

	await _capture_sequence()
	_validate_capture_set()
	_validate_production_contracts_unchanged()
	_validate_source_frozen()
	if _failures.is_empty() and _source_frozen_validated:
		_write_source_manifest()
		_write_evidence_manifest()
		_publish_capture_transaction()

	await _dispose_game()
	_finish()


func _configure_native_viewport() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X


func _validate_native_renderer() -> void:
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	_check(DisplayServer.get_name() == "X11", "capture uses native X11 rather than headless rendering")
	_check(
		DisplayServer.window_get_size() == CAPTURE_RESOLUTION,
		"native capture window is exactly 2560x1440"
	)
	print(
		"ZENITH_VISUAL_RENDERER: method=%s adapter=%s display=%s window=%s"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			DisplayServer.get_name(),
			str(DisplayServer.window_get_size()),
		]
	)


func _resolve_and_validate_production_contracts() -> bool:
	_world = _game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_zenith = _game.get_node_or_null("ZenithInterceptor") as ZenithInterceptor
	_opponent = _game.get_node_or_null("RangeOpponent") as RangeOpponent
	_check(_world != null, "production ShipyardWorld exists")
	_check(_zenith != null, "production Main owns the exact ZenithInterceptor instance")
	_check(_opponent != null, "production range opponent exists for the combat frame")
	if _world == null or _zenith == null or _opponent == null:
		return false

	_comb = _world.get_fleet_dock_comb()
	_berth = _world.get_berth_node(&"zenith_fleet_dock_berth")
	_check(_comb != null, "production world owns the Fleet Dock Comb")
	_check(_berth != null, "production world owns the Zenith Fleet Dock berth")
	if _comb == null or _berth == null:
		return false

	var fleet := _game.get_flyable_ships()
	var zenith_matches: Array[HeroShip] = []
	for candidate in fleet:
		if candidate.get_ship_id() == &"zenith_b7_observed":
			zenith_matches.append(candidate)
	_check(zenith_matches.size() == 1 and zenith_matches[0] == _zenith, "fleet registry contains exactly the production Zenith identity")
	_check(_zenith.get_home_berth_id() == &"zenith_fleet_dock_berth", "Zenith retains exact home berth identity")
	_check(_zenith.global_transform.is_equal_approx(EXPECTED_BERTH_TRANSFORM), "Zenith begins at the exact production berth transform")
	_check(_berth.global_transform.is_equal_approx(EXPECTED_BERTH_TRANSFORM), "world berth retains exact production transform")
	_check(_berth.is_occupied() and _berth.get_occupant() == _zenith, "world berth is physically occupied by the exact Zenith instance")
	_check(_comb.global_transform.is_equal_approx(EXPECTED_COMB_TRANSFORM), "Fleet Dock Comb retains exact production placement")

	var world_audit := _world.get_fleet_dock_comb_integration_audit_report()
	_check(bool(world_audit.get("valid", false)), "world Fleet Dock integration audit is green")
	_check(int(world_audit.get("external_assignment_count", 0)) == 1, "Fleet Dock exposes exactly one external assignment")
	_check(int(world_audit.get("deferred_empty_dock_count", 0)) == 2, "Fleet Dock retains exactly two deferred empty docks")
	_check(not bool(world_audit.get("historical_class_to_berth_mapping", true)), "Fleet Dock assignment remains explicitly modern")
	_check(StringName(world_audit.get("zenith_ship_id", &"")) == &"zenith_b7_observed", "Fleet Dock assignment names exact Zenith ID")
	_check(StringName(world_audit.get("zenith_berth_id", &"")) == &"zenith_fleet_dock_berth", "Fleet Dock assignment names exact berth ID")

	var runtime_audit := _zenith.get_zenith_audit_report()
	var authored := runtime_audit.get("authored_asset", {}) as Dictionary
	_check(bool(runtime_audit.get("valid", false)), "production Zenith runtime audit is green")
	_check(StringName(runtime_audit.get("ship_id", &"")) == &"zenith_b7_observed", "runtime audit pins exact B7-observed identity")
	_check(int(authored.get("close_triangle_count", 0)) == EXPECTED_CLOSE_TRIANGLES, "authored audit pins 47,274 close triangles")
	_check(int(authored.get("far_triangle_count", 0)) == EXPECTED_FAR_TRIANGLES, "authored audit pins 5,412 far triangles")
	_check(int(authored.get("runtime_mesh_count", 0)) == EXPECTED_RUNTIME_MESHES and int(authored.get("runtime_surface_count", 0)) == EXPECTED_RUNTIME_SURFACES, "authored audit pins twenty-two runtime meshes and surfaces")
	_check(int(authored.get("material_role_count", 0)) == EXPECTED_MATERIAL_ROLES, "authored audit pins ten exact material roles")
	_check(bool(authored.get("presentation_only", false)), "imported Zenith art remains presentation-only")
	_check(not bool(authored.get("gameplay_authority", true)) and not bool(authored.get("collision_authority", true)), "imported Zenith art owns no gameplay or collision authority")
	_check(int(authored.get("forbidden_authority_node_count", -1)) == 0, "imported Zenith art contains zero forbidden authority nodes")
	_check(bool(authored.get("source_core_removable", false)) and bool(authored.get("modern_systems_removable", false)), "audit preserves removable SourceCore/ModernSystems split")
	_check(bool(authored.get("whole_ship_lod_atomic", false)) and bool(authored.get("far_lod_unbounded", false)), "audit preserves atomic whole-ship LOD")
	_check(not bool(authored.get("historical_geometry_authenticated", true)), "audit does not authenticate historical dimensions or geometry")
	_check(StringName(authored.get("evidence_scope", &"")) == &"B7_frames_373_467_only", "audit retains exact bounded B7 scope")

	var presentation := _zenith.get_zenith_authored_presentation()
	_check(presentation != null, "runtime exposes the exact authored presentation wrapper")
	if presentation != null:
		var asset_root := presentation.call("get_asset_root") as Node3D
		var source_core := presentation.call("get_source_core_root") as Node3D
		var modern_systems := presentation.call("get_modern_systems_root") as Node3D
		_check(asset_root != null and source_core != null and modern_systems != null, "authored roots resolve through wrapper API")
		_check(source_core != null and modern_systems != null and source_core.get_parent() == asset_root and modern_systems.get_parent() == asset_root, "SourceCore and ModernSystems remain direct removable siblings")
		_check(asset_root != null and asset_root.find_children("*", "CollisionObject3D", true, false).is_empty(), "imported asset subtree contains no collision authority")
		_check(asset_root != null and asset_root.find_children("*", "Camera3D", true, false).is_empty(), "imported asset subtree contains no camera authority")
		var anchors_are_exact := true
		for anchor_name: StringName in EXPECTED_ANCHORS:
			var anchor := presentation.call("get_semantic_anchor", anchor_name) as Node3D
			anchors_are_exact = anchors_are_exact and anchor != null and anchor.position.distance_to(EXPECTED_ANCHORS[anchor_name]) <= 0.0001
		_check(anchors_are_exact, "all thirteen authored alignment-witness anchors match the exact V2 contract")

	var collision_contract := _zenith.get_zenith_collision_contract_report()
	var collision_type_counts := collision_contract.get("shape_type_counts", {}) as Dictionary
	_check(bool(collision_contract.get("valid", false)), "runtime V2 collision contract audit is green")
	_check(str(collision_contract.get("oracle_id", "")) == "zenith_b7_runtime_24_mixed_v2", "runtime collision uses exact V2 oracle identity")
	_check(str(collision_contract.get("geometry_sha256", "")) == EXPECTED_COLLISION_GEOMETRY_SHA256, "runtime collision geometry matches exact frozen SHA-256")
	_check(int(collision_contract.get("shape_count", 0)) == EXPECTED_COLLISION_SHAPE_COUNT, "runtime owns exactly twenty-four mixed collision shapes")
	_check(int(collision_type_counts.get(&"ConvexPolygonShape3D", 0)) == 18 and int(collision_type_counts.get(&"CylinderShape3D", 0)) == 3 and int(collision_type_counts.get(&"BoxShape3D", 0)) == 3, "runtime collision roster is exactly eighteen convex, three cylinder and three box shapes")
	_check(not bool(collision_contract.get("manifest_loaded_for_authority", true)) and not bool(collision_contract.get("imported_collision_authority", true)), "hard-coded runtime owns collision without manifest/import authority")
	var landing_collision := collision_contract.get("landing", {}) as Dictionary
	_check(bool(landing_collision.get("valid", false)) and int(landing_collision.get("shape_count", 0)) == EXPECTED_COLLISION_SHAPE_COUNT, "landing envelope consumes all twenty-four live shapes")
	_check(bool(authored.get("collision_proposal_ready", false)) and int(authored.get("collision_proposal_shape_count", 0)) == EXPECTED_COLLISION_SHAPE_COUNT, "authored audit publishes the exact non-authoritative twenty-four-shape proposal")
	_check(float(authored.get("collision_proposal_maximum_miss_m", INF)) <= 0.020 and float(authored.get("collision_proposal_reverse_bound_m", INF)) <= 0.150, "two-way collision oracle remains within frozen coverage/overreach bounds")
	_check(bool(authored.get("boarding_route_clear", false)) and float(authored.get("boarding_route_clearance_m", 0.0)) >= 0.05, "V2 boarding route has at least 50 mm conservative clearance")
	_check((authored.get("boarding_area_center", Vector3.INF) as Vector3).distance_to(Vector3(-7.65, -0.05, 0.55)) <= 0.0001, "boarding area centre retains exact clear V2 placement")
	_check(FileAccess.get_sha256("res://scripts/ships/zenith_interceptor.gd") == EXPECTED_RUNTIME_V2_SHA256, "production Zenith runtime file matches frozen V2 SHA-256")
	_check(FileAccess.get_sha256("res://tests/zenith_fleet_dock_integration_test.gd") == EXPECTED_INTEGRATION_SHA256, "production integration oracle matches frozen SHA-256")

	_zenith.update_zenith_lod_for_distance(1000.0)
	_check(_zenith.get_zenith_active_lod() == 1, "whole-ship LOD switches atomically to far")
	_zenith.update_zenith_lod_for_distance(0.0)
	_check(_zenith.get_zenith_active_lod() == 0, "whole-ship LOD restores atomically to close")
	_check(bool(_zenith.get_zenith_audit_report().get("valid", false)), "LOD round trip leaves production Zenith audit green")

	_production_contract_snapshot = _capture_production_contract_snapshot()
	return _failures.is_empty()


func _capture_production_contract_snapshot() -> Dictionary:
	var presentation := _zenith.get_zenith_authored_presentation()
	var asset_root := presentation.call("get_asset_root") as Node3D if presentation != null else null
	return {
		"zenith_instance_id": _zenith.get_instance_id(),
		"berth_instance_id": _berth.get_instance_id(),
		"comb_instance_id": _comb.get_instance_id(),
		"presentation_instance_id": presentation.get_instance_id() if presentation != null else 0,
		"asset_root_instance_id": asset_root.get_instance_id() if asset_root != null else 0,
		"runtime_identity_baseline": _zenith.get_zenith_runtime_identity_report().get("baseline", {}).duplicate(true),
		"berth_transform": _berth.global_transform,
		"comb_transform": _comb.global_transform,
	}


func _validate_production_contracts_unchanged() -> void:
	var presentation := _zenith.get_zenith_authored_presentation()
	var asset_root := presentation.call("get_asset_root") as Node3D if presentation != null else null
	_check(_zenith.get_instance_id() == int(_production_contract_snapshot.get("zenith_instance_id", 0)), "capture preserves production Zenith node identity")
	_check(_berth.get_instance_id() == int(_production_contract_snapshot.get("berth_instance_id", 0)), "capture preserves production berth node identity")
	_check(_comb.get_instance_id() == int(_production_contract_snapshot.get("comb_instance_id", 0)), "capture preserves Fleet Dock node identity")
	_check(presentation != null and presentation.get_instance_id() == int(_production_contract_snapshot.get("presentation_instance_id", 0)), "capture preserves authored wrapper identity")
	_check(asset_root != null and asset_root.get_instance_id() == int(_production_contract_snapshot.get("asset_root_instance_id", 0)), "capture preserves imported asset-root identity")
	_check(_berth.global_transform.is_equal_approx(_production_contract_snapshot.get("berth_transform", Transform3D.IDENTITY)), "capture never moves the authoritative berth")
	_check(_comb.global_transform.is_equal_approx(_production_contract_snapshot.get("comb_transform", Transform3D.IDENTITY)), "capture never moves the Fleet Dock module")
	_check(bool(_zenith.get_zenith_audit_report().get("valid", false)), "production Zenith audit remains green after staged frames")
	_check(bool(_world.get_fleet_dock_comb_integration_audit_report().get("valid", false)), "world Fleet Dock audit remains green after staged frames")
	_check(bool(_zenith.get_zenith_runtime_identity_report().get("stable", false)), "all pinned Zenith runtime/resource identities remain stable")
	_check(_zenith.get_zenith_runtime_identity_report().get("baseline", {}) == _production_contract_snapshot.get("runtime_identity_baseline", {}), "capture retains exact runtime identity baseline")


func _disable_all_canvas_layers() -> void:
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED


func _validate_hud_policy() -> void:
	var layers := _game.find_children("*", "CanvasLayer", true, false)
	var visible_layers: Array[String] = []
	for candidate in layers:
		var layer := candidate as CanvasLayer
		if layer.visible:
			visible_layers.append(str(layer.get_path()))
	_check(_game.get_node_or_null("HUD") is CanvasLayer, "production HUD exists and is explicitly excluded")
	_check(not layers.is_empty(), "production scene contains CanvasLayer presentation")
	_check(visible_layers.is_empty(), "all HUD and CanvasLayer presentation is hidden and disabled")


func _install_capture_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ZenithVisualEvidenceCamera"
	_camera.near = 0.08
	_camera.far = 2000.0
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_game.add_child(_camera)
	_camera.current = true
	_check(root.get_camera_3d() == _camera, "capture-only camera has viewport authority")


func _capture_sequence() -> void:
	# Frame 01 is the untouched production occupancy state.
	_set_camera_local(Vector3(27.0, 15.0, 23.0), Vector3(0.0, 0.9, 0.0), 43.0)
	await _capture_frame(CAPTURE_FILES[0], CAPTURE_STATES[0], 0.055, {
		"production_berth_occupied": _berth.get_occupant() == _zenith,
		"berth_transform": _transform_dictionary(_berth.global_transform),
		"comb_transform": _transform_dictionary(_comb.global_transform),
	})

	_set_camera_local(Vector3(0.0, 32.0, 0.0), Vector3(0.0, 0.65, 0.0), 34.0, Vector3.FORWARD)
	await _capture_frame(CAPTURE_FILES[1], CAPTURE_STATES[1], 0.19, {
		"projection": "true_dorsal_orthogonal_axis_perspective_camera",
		"up_vector": _vector3_array(Vector3.FORWARD),
		"historical_dimension_claim": false,
	})

	_set_camera_local(Vector3(25.0, 4.8, 0.0), Vector3(0.0, 0.7, 0.0), 34.0)
	await _capture_frame(CAPTURE_FILES[2], CAPTURE_STATES[2], 0.15, {
		"view": "starboard_profile",
		"historical_dimension_claim": false,
	})

	await _bring_engines_online()
	_set_camera_local(Vector3(0.0, 6.0, 24.0), Vector3(0.0, 0.55, 1.2), 37.0)
	await _capture_frame(CAPTURE_FILES[3], CAPTURE_STATES[3], 0.13, {
		"engine_state": str(_zenith.get_telemetry().get("engine_state", "")),
		"visible_plume_count": _visible_plume_count(),
	})

	_zenith.set_canopy_open(false, 0.0)
	await _settle_render(3)
	_set_camera_local(Vector3(8.8, 5.4, -8.8), Vector3(0.0, 1.48, -0.85), 35.0)
	await _capture_frame(CAPTURE_FILES[4], CAPTURE_STATES[4], 0.12, {
		"canopy_fraction": 0.0,
		"canopy_open": _zenith.is_canopy_open(),
	}, false)

	_zenith.set_canopy_open(true, 0.0)
	await _settle_render(3)
	# The same camera is retained so the pair can prove visible articulation.
	await _capture_frame(CAPTURE_FILES[5], CAPTURE_STATES[5], 0.12, {
		"canopy_fraction": 1.0,
		"canopy_open": _zenith.is_canopy_open(),
		"paired_fixed_camera": CAPTURE_FILES[4],
	}, false)

	_zenith.set_canopy_open(false, 0.0)
	await _stage_short_flight_combat()
	_set_camera_local(Vector3(27.0, 11.0, 26.0), Vector3(0.0, 0.3, -7.0), 43.0)
	await _capture_frame(CAPTURE_FILES[6], CAPTURE_STATES[6], 0.09, {
		"engine_state": str(_zenith.get_telemetry().get("engine_state", "")),
		"flight_speed": snappedf(_zenith.velocity.length(), 0.001),
		"opponent_active": _opponent.is_active(),
		"staged_not_uninterrupted_gameplay": true,
	})


func _bring_engines_online() -> void:
	_zenith.set_piloted(true)
	_zenith.request_engine_start()
	for _index in 240:
		if str(_zenith.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE":
			break
		await physics_frame
	_check(str(_zenith.get_telemetry().get("engine_state", "")).to_upper() == "ONLINE", "production engine lifecycle reaches ONLINE")
	_camera.current = true
	_check(_visible_plume_count() == 4, "all two close and two far authored plume identities are online")


func _stage_short_flight_combat() -> void:
	var combat_basis := Basis(Vector3.UP, deg_to_rad(-24.0)).rotated(Vector3.FORWARD, deg_to_rad(10.0)).orthonormalized()
	_zenith.global_transform = Transform3D(combat_basis, COMBAT_ORIGIN)
	_zenith.velocity = Vector3.ZERO
	_camera.current = true
	Input.action_press("move_forward")
	Input.action_press("roll_right")
	for _index in 10:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("roll_right")
	_check(_zenith.velocity.length() > 0.5, "short frame follows real production thrust input")
	var opponent_position := _zenith.to_global(Vector3(-18.0, 5.5, -38.0))
	var opponent_direction := (_zenith.global_position - opponent_position).normalized()
	_opponent.activate(Transform3D(Basis.looking_at(opponent_direction, Vector3.UP), opponent_position))
	_opponent.set_target(_zenith)
	_opponent.set_physics_process(false)
	_zenith.set_physics_process(false)
	_camera.current = true
	await _settle_render(4)
	_check(_opponent.is_active(), "production opponent is active in staged combat tableau")


func _set_camera_local(
	local_position: Vector3,
	local_target: Vector3,
	field_of_view: float,
	up: Vector3 = Vector3.UP
	) -> void:
	_camera.global_position = _zenith.to_global(local_position)
	_camera.look_at(_zenith.to_global(local_target), _zenith.global_basis * up)
	_camera.fov = field_of_view
	_camera.current = true


func _capture_frame(
	file_name: String,
	semantic_state: String,
	minimum_ship_fraction: float,
	markers: Dictionary,
	require_complete_envelope: bool = true
	) -> void:
	_validate_hud_policy()
	_check(root.get_camera_3d() == _camera, "%s retains capture-only camera authority" % file_name)
	await _settle_render(5)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced an empty viewport image" % file_name)
		return
	image.convert(Image.FORMAT_RGB8)
	_check(image.get_size() == CAPTURE_RESOLUTION, "%s is exactly 2560x1440" % file_name)
	if image.get_size() != CAPTURE_RESOLUTION:
		return

	var frame_report := _project_zenith_envelope()
	var screen_fraction := float(frame_report.get("screen_fraction", 0.0))
	if require_complete_envelope:
		_check(bool(frame_report.get("all_in_front", false)), "%s keeps the complete Zenith envelope in front of the camera" % file_name)
		_check(bool(frame_report.get("inside_safe_frame", false)), "%s keeps the complete Zenith envelope inside the 5%% frame margin" % file_name)
	else:
		var focal_report := _project_cockpit_focal_point()
		frame_report["intentional_close_detail"] = true
		frame_report["complete_envelope_required"] = false
		frame_report["cockpit_focal_point"] = focal_report
		_check(bool(focal_report.get("in_front", false)), "%s keeps the canopy focal point in front of the camera" % file_name)
		_check(bool(focal_report.get("inside_central_safe_zone", false)), "%s keeps the canopy focal point inside the central safe zone" % file_name)
	_check(screen_fraction >= maxf(MINIMUM_SHIP_SCREEN_FRACTION, minimum_ship_fraction), "%s gives Zenith substantive screen coverage" % file_name)

	var statistics := _sample_image_statistics(image)
	_check(float(statistics.get("range", 0.0)) >= MINIMUM_LUMINANCE_RANGE, "%s has substantive luminance range" % file_name)
	_check(float(statistics.get("variance", 0.0)) >= MINIMUM_LUMINANCE_VARIANCE, "%s has substantive luminance variance" % file_name)
	_check(float(statistics.get("mean", 0.0)) >= MINIMUM_MEAN_LUMINANCE and float(statistics.get("mean", 0.0)) <= MAXIMUM_MEAN_LUMINANCE, "%s avoids blank black/white mean exposure" % file_name)
	_check(float(statistics.get("dark_clip_fraction", 1.0)) <= MAXIMUM_DARK_CLIP_FRACTION, "%s avoids excessive crushed-black coverage" % file_name)
	_check(float(statistics.get("bright_clip_fraction", 1.0)) <= MAXIMUM_BRIGHT_CLIP_FRACTION, "%s avoids excessive clipped-white coverage" % file_name)

	var staged_path := TRANSACTION_DIR.path_join(file_name)
	var save_error := image.save_png(staged_path)
	_check(save_error == OK, "%s saves into isolated capture transaction" % file_name)
	if save_error != OK:
		return
	var file := FileAccess.open(staged_path, FileAccess.READ)
	var byte_count := file.get_length() if file != null else 0
	if file != null:
		file.close()
	_check(byte_count >= MINIMUM_PNG_BYTES, "%s contains at least %d bytes of rendered detail" % [file_name, MINIMUM_PNG_BYTES])
	var png_header := _inspect_png_header(staged_path)
	_check(
		bool(png_header.get("valid", false))
		and int(png_header.get("width", 0)) == CAPTURE_RESOLUTION.x
		and int(png_header.get("height", 0)) == CAPTURE_RESOLUTION.y
		and int(png_header.get("bit_depth", 0)) == 8
		and int(png_header.get("colour_type", -1)) == 2
		and int(png_header.get("interlace", -1)) == 0,
		"%s is exact RGB8 non-interlaced 2560x1440 PNG" % file_name
	)
	var record := {
		"file": file_name,
		"semantic_state": semantic_state,
		"sha256": FileAccess.get_sha256(staged_path),
		"png_bytes": byte_count,
		"resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"png_header": png_header,
		"image_statistics": statistics,
		"projected_zenith_envelope": frame_report,
		"complete_envelope_required": require_complete_envelope,
		"camera_transform": _transform_dictionary(_camera.global_transform),
		"camera_fov": _camera.fov,
		"zenith_transform": _transform_dictionary(_zenith.global_transform),
		"markers": markers.duplicate(true),
	}
	_semantic_frames.append(record)
	_captured_images[file_name] = image
	print("ZENITH_VISUAL_CAPTURED: %s state=%s bytes=%d coverage=%.4f" % [ProjectSettings.globalize_path(staged_path), semantic_state, byte_count, screen_fraction])


func _project_zenith_envelope() -> Dictionary:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var all_in_front := true
	for corner_index in 8:
		var local_corner := EXPECTED_BOUNDS.get_endpoint(corner_index)
		var world_corner := _zenith.global_transform * local_corner
		if _camera.is_position_behind(world_corner):
			all_in_front = false
			continue
		var screen := _camera.unproject_position(world_corner)
		minimum.x = minf(minimum.x, screen.x)
		minimum.y = minf(minimum.y, screen.y)
		maximum.x = maxf(maximum.x, screen.x)
		maximum.y = maxf(maximum.y, screen.y)
	var valid_rect := minimum.is_finite() and maximum.is_finite() and maximum.x > minimum.x and maximum.y > minimum.y
	var rect := Rect2(minimum, maximum - minimum) if valid_rect else Rect2()
	var margin := Vector2(CAPTURE_RESOLUTION) * 0.05
	var inside := (
		valid_rect
		and rect.position.x >= margin.x
		and rect.position.y >= margin.y
		and rect.end.x <= float(CAPTURE_RESOLUTION.x) - margin.x
		and rect.end.y <= float(CAPTURE_RESOLUTION.y) - margin.y
	)
	return {
		"all_in_front": all_in_front and valid_rect,
		"inside_safe_frame": inside,
		"rect": _rect2_dictionary(rect),
		"screen_fraction": (rect.size.x * rect.size.y) / float(CAPTURE_RESOLUTION.x * CAPTURE_RESOLUTION.y) if valid_rect else 0.0,
		"margin_fraction": 0.05,
	}.duplicate(true)


func _project_cockpit_focal_point() -> Dictionary:
	var world_position := _zenith.to_global(Vector3(0.0, 1.48, -0.85))
	var in_front := not _camera.is_position_behind(world_position)
	var screen := _camera.unproject_position(world_position) if in_front else Vector2(-INF, -INF)
	var normalized := Vector2(
		screen.x / float(CAPTURE_RESOLUTION.x),
		screen.y / float(CAPTURE_RESOLUTION.y)
	)
	return {
		"in_front": in_front,
		"screen_pixels": [snappedf(screen.x, 0.001), snappedf(screen.y, 0.001)],
		"normalized": [snappedf(normalized.x, 0.000001), snappedf(normalized.y, 0.000001)],
		"inside_central_safe_zone": in_front and normalized.x >= 0.25 and normalized.x <= 0.75 and normalized.y >= 0.25 and normalized.y <= 0.75,
		"central_safe_zone": [0.25, 0.25, 0.75, 0.75],
	}.duplicate(true)


func _visible_plume_count() -> int:
	var count := 0
	for plume in _zenith.get_zenith_engine_plumes():
		if plume.visible:
			count += 1
	return count


func _validate_capture_set() -> void:
	_check(_semantic_frames.size() == CAPTURE_FILES.size(), "exactly seven Zenith semantic frames were captured")
	_check(_captured_images.size() == CAPTURE_FILES.size(), "all seven Zenith filenames are unique")
	var hashes := PackedStringArray()
	for index in CAPTURE_FILES.size():
		var file_name := CAPTURE_FILES[index]
		_check(_captured_images.has(file_name), "required Zenith frame exists: %s" % file_name)
		if index < _semantic_frames.size():
			var record := _semantic_frames[index]
			_check(str(record.get("file", "")) == file_name and str(record.get("semantic_state", "")) == CAPTURE_STATES[index], "frame %d retains exact file/state inventory" % (index + 1))
			hashes.append(str(record.get("sha256", "")))
	var unique_hashes := {}
	for digest in hashes:
		unique_hashes[digest] = true
	_check(unique_hashes.size() == CAPTURE_FILES.size(), "all seven Zenith PNGs have unique SHA-256 digests")
	_validate_canopy_pair()


func _validate_canopy_pair() -> void:
	var closed := _captured_images.get(CAPTURE_FILES[4]) as Image
	var opened := _captured_images.get(CAPTURE_FILES[5]) as Image
	if closed == null or opened == null:
		_fail("canopy pair images are unavailable")
		return
	var comparison := _compare_images(closed, opened)
	_pair_metrics["canopy_closed_to_open_fixed_camera"] = comparison
	_check(float(comparison.get("changed_fraction", 0.0)) >= MINIMUM_CANOPY_CHANGED_FRACTION, "fixed-camera canopy pair contains visible articulated change")
	var closed_record := _semantic_frames[4]
	var opened_record := _semantic_frames[5]
	_check(closed_record.get("camera_transform", {}) == opened_record.get("camera_transform", {}) and is_equal_approx(float(closed_record.get("camera_fov", 0.0)), float(opened_record.get("camera_fov", 1.0))), "canopy pair uses exact same camera transform and projection")


func _compare_images(first: Image, second: Image) -> Dictionary:
	var changed := 0
	var count := 0
	var total_difference := 0.0
	for sample_y in 180:
		var y := roundi(float(sample_y) / 179.0 * float(first.get_height() - 1))
		for sample_x in 320:
			var x := roundi(float(sample_x) / 319.0 * float(first.get_width() - 1))
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			var difference := (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			total_difference += difference
			if difference >= PIXEL_CHANGE_THRESHOLD:
				changed += 1
			count += 1
	return {
		"sample_count": count,
		"mean_difference": total_difference / float(maxi(count, 1)),
		"changed_pixels": changed,
		"changed_fraction": float(changed) / float(maxi(count, 1)),
		"pixel_change_threshold": PIXEL_CHANGE_THRESHOLD,
	}.duplicate(true)


func _sample_image_statistics(image: Image) -> Dictionary:
	var darkest := 1.0
	var brightest := 0.0
	var total := 0.0
	var total_squared := 0.0
	var dark_clipped := 0
	var bright_clipped := 0
	var count := 0
	for sample_y in 90:
		var y := roundi(float(sample_y) / 89.0 * float(image.get_height() - 1))
		for sample_x in 160:
			var x := roundi(float(sample_x) / 159.0 * float(image.get_width() - 1))
			var luminance := image.get_pixel(x, y).get_luminance()
			darkest = minf(darkest, luminance)
			brightest = maxf(brightest, luminance)
			total += luminance
			total_squared += luminance * luminance
			if luminance <= 0.008:
				dark_clipped += 1
			if luminance >= 0.985:
				bright_clipped += 1
			count += 1
	var mean := total / float(maxi(count, 1))
	return {
		"range": snappedf(brightest - darkest, 0.000001),
		"mean": snappedf(mean, 0.000001),
		"variance": snappedf(maxf(0.0, total_squared / float(maxi(count, 1)) - mean * mean), 0.000001),
		"dark_clip_fraction": snappedf(float(dark_clipped) / float(maxi(count, 1)), 0.000001),
		"bright_clip_fraction": snappedf(float(bright_clipped) / float(maxi(count, 1)), 0.000001),
	}.duplicate(true)


func _inspect_png_header(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 33:
		return {"valid": false}
	var bytes := file.get_buffer(33)
	file.close()
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if bytes.slice(0, 8) != signature or bytes.slice(12, 16).get_string_from_ascii() != "IHDR":
		return {"valid": false}
	return {
		"valid": true,
		"width": _read_u32_be(bytes, 16),
		"height": _read_u32_be(bytes, 20),
		"bit_depth": int(bytes[24]),
		"colour_type": int(bytes[25]),
		"compression": int(bytes[26]),
		"filter": int(bytes[27]),
		"interlace": int(bytes[28]),
	}.duplicate(true)


func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])


func _snapshot_source_files(paths: PackedStringArray) -> Dictionary:
	var snapshot := {}
	for path in paths:
		var digest := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		_check(not digest.is_empty(), "source freeze path exists and hashes: %s" % path)
		if not digest.is_empty():
			snapshot[path] = digest
	return snapshot


func _collect_source_paths() -> PackedStringArray:
	var collected := PackedStringArray()
	for root_path in SOURCE_ROOTS:
		if FileAccess.file_exists(root_path):
			collected.append(root_path)
			continue
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path)):
			_check(false, "source freeze root exists: %s" % root_path)
			continue
		_collect_source_directory(root_path, collected)
	collected.sort()
	var deduplicated := PackedStringArray()
	for path in collected:
		if not deduplicated.has(path):
			deduplicated.append(path)
	return deduplicated


func _collect_source_directory(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_check(false, "source freeze directory opens: %s" % directory_path)
		return
	var list_error := directory.list_dir_begin()
	_check(list_error == OK, "source freeze directory enumeration begins: %s" % directory_path)
	if list_error != OK:
		return
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and entry != "__pycache__":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_source_directory(path, output)
			elif not entry.ends_with("~") and not entry.ends_with(".pyc") and entry != ".DS_Store":
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _source_snapshot_hash(snapshot: Dictionary, paths: PackedStringArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	for path in paths:
		context.update(("%s  %s\n" % [snapshot.get(path, ""), path]).to_utf8_buffer())
	return context.finish().hex_encode()


func _validate_source_frozen() -> void:
	var final_paths := _collect_source_paths()
	var final_snapshot := _snapshot_source_files(final_paths)
	var final_aggregate := _source_snapshot_hash(final_snapshot, final_paths)
	_source_frozen_validated = final_paths == _source_paths and final_snapshot == _source_snapshot and final_aggregate == _source_aggregate_sha256
	_check(_source_frozen_validated, "recursive source roster and every declared production byte remain identical through capture")


func _write_source_manifest() -> void:
	var file := FileAccess.open(STAGED_SOURCE_MANIFEST_PATH, FileAccess.WRITE)
	_check(file != null, "staged source SHA-256 manifest opens")
	if file == null:
		return
	for path in _source_paths:
		file.store_line("%s  %s" % [_source_snapshot.get(path, ""), path])
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK, "staged source SHA-256 manifest flushes")


func _write_evidence_manifest() -> void:
	var runtime_audit := _zenith.get_zenith_audit_report()
	var authored := runtime_audit.get("authored_asset", {}) as Dictionary
	var world_audit := _world.get_fleet_dock_comb_integration_audit_report()
	var manifest := {
		"schema": "mudds_zenith_visual_rendered_evidence_v1",
		"frame_count": CAPTURE_FILES.size(),
		"frame_inventory": CAPTURE_FILES,
		"semantic_state_inventory": CAPTURE_STATES,
		"capture_resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"png_contract": "PNG RGB8, non-interlaced, exact 2560x1440",
		"renderer": String(RenderingServer.get_current_rendering_method()),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"native_window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"hud_policy": "HUD_OFF_ALL_CANVASLAYERS_HIDDEN_AND_DISABLED",
		"production_main_scene": "res://scenes/main.tscn",
		"production_ship_node": "Main/ZenithInterceptor",
		"production_berth_id": "zenith_fleet_dock_berth",
		"production_ship_id": "zenith_b7_observed",
		"source_manifest": SOURCE_MANIFEST_PATH,
		"source_manifest_sha256": FileAccess.get_sha256(STAGED_SOURCE_MANIFEST_PATH),
		"source_aggregate_sha256": _source_aggregate_sha256,
		"source_file_count": _source_paths.size(),
		"source_files": _source_snapshot.duplicate(true),
		"source_unchanged_during_capture": _source_frozen_validated,
		"capture_log_path": CAPTURE_LOG_PATH,
		"capture_log_policy": "External native launcher redirects raw stdout/stderr; this manifest is the transactional green sentinel.",
		"b7_boundary": {
			"evidence_scope": "B7_frames_373_467_only",
			"historical_geometry_authenticated": false,
			"historical_dimensions_claimed": false,
			"source_pixels_included_or_redistributed": false,
			"source_comparison_claimed": false,
			"human_review_must_use_ledger_separately": true,
		},
		"frozen_runtime_contract": {
			"runtime_audit_valid": bool(runtime_audit.get("valid", false)),
			"runtime_v2_file_sha256": EXPECTED_RUNTIME_V2_SHA256,
			"integration_oracle_sha256": EXPECTED_INTEGRATION_SHA256,
			"authored_asset_id": str(authored.get("asset_id", "")),
			"close_triangle_count": int(authored.get("close_triangle_count", 0)),
			"far_triangle_count": int(authored.get("far_triangle_count", 0)),
			"runtime_mesh_count": int(authored.get("runtime_mesh_count", 0)),
			"runtime_surface_count": int(authored.get("runtime_surface_count", 0)),
			"presentation_only": bool(authored.get("presentation_only", false)),
			"gameplay_authority": bool(authored.get("gameplay_authority", true)),
			"collision_authority": bool(authored.get("collision_authority", true)),
			"forbidden_authority_node_count": int(authored.get("forbidden_authority_node_count", -1)),
			"source_core_removable": bool(authored.get("source_core_removable", false)),
			"modern_systems_removable": bool(authored.get("modern_systems_removable", false)),
			"whole_ship_lod_atomic": bool(authored.get("whole_ship_lod_atomic", false)),
			"far_lod_unbounded": bool(authored.get("far_lod_unbounded", false)),
			"anchor_positions": _anchor_manifest_dictionary(),
			"collision_oracle_id": str(_zenith.get_zenith_collision_contract_report().get("oracle_id", "")),
			"collision_geometry_sha256": str(_zenith.get_zenith_collision_contract_report().get("geometry_sha256", "")),
			"collision_shape_count": int(_zenith.get_zenith_collision_contract_report().get("shape_count", 0)),
			"collision_shape_type_counts": _zenith.get_zenith_collision_contract_report().get("shape_type_counts", {}).duplicate(true),
		},
		"frozen_world_contract": {
			"integration_audit_valid": bool(world_audit.get("valid", false)),
			"external_assignment_count": int(world_audit.get("external_assignment_count", 0)),
			"deferred_empty_dock_count": int(world_audit.get("deferred_empty_dock_count", 0)),
			"historical_class_to_berth_mapping": bool(world_audit.get("historical_class_to_berth_mapping", true)),
			"berth_transform": _transform_dictionary(_berth.global_transform),
			"comb_transform": _transform_dictionary(_comb.global_transform),
		},
		"frames": _semantic_frames,
		"pair_metrics": _pair_metrics,
		"automated_acceptance_thresholds": {
			"minimum_png_bytes": MINIMUM_PNG_BYTES,
			"minimum_luminance_range": MINIMUM_LUMINANCE_RANGE,
			"minimum_luminance_variance": MINIMUM_LUMINANCE_VARIANCE,
			"minimum_mean_luminance": MINIMUM_MEAN_LUMINANCE,
			"maximum_mean_luminance": MAXIMUM_MEAN_LUMINANCE,
			"maximum_dark_clip_fraction": MAXIMUM_DARK_CLIP_FRACTION,
			"maximum_bright_clip_fraction": MAXIMUM_BRIGHT_CLIP_FRACTION,
			"minimum_ship_screen_fraction": MINIMUM_SHIP_SCREEN_FRACTION,
			"minimum_canopy_changed_fraction": MINIMUM_CANOPY_CHANGED_FRACTION,
			"complete_ship_frame_margin_fraction": 0.05,
			"cockpit_closeup_focal_safe_zone_normalized": [0.25, 0.25, 0.75, 0.75],
		},
		"human_review": {
			"required": true,
			"automated_fidelity_judgement": false,
			"automated_craftsmanship_judgement": false,
			"required_original_resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
			"review_questions": [
				"Does the broad pale width-dominant delta/arrow macroform remain convincing under dorsal, profile and three-quarter views?",
				"Is the tall faceted central wedge/spine legible without modern systems overwhelming SourceCore?",
				"Are materials, seams, canopy, engines, navigation accents and surface density coherent at production quality?",
				"Do the occupied berth and combat tableau read clearly without clipping, implausible contact, or staging artifacts?",
			],
		},
		"staging_interventions": [
			"Adds one capture-only Camera3D and hides/disables every CanvasLayer.",
			"Frames 01-06 use the exact production Zenith node; frame 01 preserves its exact occupied production berth pose.",
			"Starts the production engine lifecycle, exercises ten real thrust/roll physics ticks, then freezes the craft for deterministic photography.",
			"Moves the same production Zenith to the established combat arena and activates/freezes the production RangeOpponent for frame 07.",
		],
		"evidence_limits": [
			"No source-video pixels, stills, or source-comparison composite are included.",
			"These images do not authenticate historical dimensions, exact geometry, materials, cockpit, engines, weapons, handling, or class-to-berth placement.",
			"Frame 07 is a deterministic staged production-state tableau, not an uninterrupted player-controlled dogfight.",
			"Native X11 Forward+ output does not prove native-Windows rendering, native-GPU performance, flight feel, audibility, controller ergonomics, or camera comfort.",
			"Pixel gates reject blank, clipped, duplicate, corrupt, and severely exposed captures but cannot establish fidelity or craftsmanship.",
		],
	}
	var file := FileAccess.open(STAGED_EVIDENCE_MANIFEST_PATH, FileAccess.WRITE)
	_check(file != null, "staged Zenith evidence manifest opens")
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK, "staged Zenith evidence manifest flushes")


func _reset_capture_transaction() -> void:
	var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_check(output_error == OK or output_error == ERR_ALREADY_EXISTS, "Zenith visual output directory is available")
	_remove_file_if_present(EVIDENCE_MANIFEST_PATH, "prior evidence sentinel clears")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TRANSACTION_DIR)):
		_remove_transaction_tree(TRANSACTION_DIR)
	var transaction_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRANSACTION_DIR))
	_check(transaction_error == OK or transaction_error == ERR_ALREADY_EXISTS, "fresh isolated Zenith capture transaction is available")


func _publish_capture_transaction() -> void:
	_remove_file_if_present(EVIDENCE_MANIFEST_PATH, "published evidence sentinel clears before replacement")
	for file_name in CAPTURE_FILES:
		_remove_file_if_present(OUTPUT_DIR.path_join(file_name), "prior bounded Zenith PNG clears: %s" % file_name)
	_remove_file_if_present(SOURCE_MANIFEST_PATH, "prior source manifest clears")
	if not _failures.is_empty():
		return
	for file_name in CAPTURE_FILES:
		_publish_staged_file(TRANSACTION_DIR.path_join(file_name), OUTPUT_DIR.path_join(file_name), file_name)
	_publish_staged_file(STAGED_SOURCE_MANIFEST_PATH, SOURCE_MANIFEST_PATH, "source manifest")
	_validate_source_frozen()
	if not _source_frozen_validated or not _failures.is_empty():
		return
	_publish_staged_file(STAGED_EVIDENCE_MANIFEST_PATH, EVIDENCE_MANIFEST_PATH, "evidence sentinel")
	_verify_published_transaction()
	if _failures.is_empty():
		_remove_transaction_tree(TRANSACTION_DIR)


func _publish_staged_file(source_path: String, destination_path: String, label: String) -> void:
	_check(FileAccess.file_exists(source_path), "staged %s exists before publish" % label)
	if not FileAccess.file_exists(source_path):
		return
	_remove_file_if_present(destination_path, "destination clears before %s publish" % label)
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(destination_path))
	_check(error == OK, "%s publishes atomically" % label)


func _verify_published_transaction() -> void:
	var manifest := _read_json(EVIDENCE_MANIFEST_PATH)
	var frames := manifest.get("frames", []) as Array
	_check(str(manifest.get("schema", "")) == "mudds_zenith_visual_rendered_evidence_v1", "published evidence sentinel has exact schema")
	_check(int(manifest.get("frame_count", 0)) == CAPTURE_FILES.size() and frames.size() == CAPTURE_FILES.size(), "published evidence sentinel has exact seven-frame inventory")
	_check(bool(manifest.get("source_unchanged_during_capture", false)), "published evidence authenticates frozen source")
	_check(str(manifest.get("source_manifest_sha256", "")) == FileAccess.get_sha256(SOURCE_MANIFEST_PATH), "published evidence authenticates source manifest")
	var exact := true
	for index in CAPTURE_FILES.size():
		var record := frames[index] as Dictionary if index < frames.size() else {}
		var path := OUTPUT_DIR.path_join(CAPTURE_FILES[index])
		exact = exact and FileAccess.file_exists(path) and str(record.get("file", "")) == CAPTURE_FILES[index] and str(record.get("semantic_state", "")) == CAPTURE_STATES[index] and str(record.get("sha256", "")) == FileAccess.get_sha256(path)
	_check(exact, "published evidence authenticates exact ordered filename/state/hash inventory")


func _remove_file_if_present(path: String, description: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		_fail("refusing to remove directory where file was expected: %s" % path)
		return false
	if not FileAccess.file_exists(path):
		return true
	var error := DirAccess.remove_absolute(absolute)
	_check(error == OK, description)
	return error == OK


func _remove_transaction_tree(path: String) -> bool:
	if path != TRANSACTION_DIR and not path.begins_with(TRANSACTION_DIR + "/"):
		_fail("refusing cleanup outside bounded transaction: %s" % path)
		return false
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return true
	var directory := DirAccess.open(path)
	if directory == null:
		_fail("transaction directory cannot open: %s" % path)
		return false
	var files := PackedStringArray()
	var directories := PackedStringArray()
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir():
			directories.append(entry)
		else:
			files.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	var valid := true
	for file_name in files:
		valid = DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name))) == OK and valid
	for directory_name in directories:
		valid = _remove_transaction_tree(path.path_join(directory_name)) and valid
	valid = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and valid
	_check(valid, "bounded transaction tree clears: %s" % path)
	return valid


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _rect2_dictionary(value: Rect2) -> Dictionary:
	return {
		"x": snappedf(value.position.x, 0.001),
		"y": snappedf(value.position.y, 0.001),
		"width": snappedf(value.size.x, 0.001),
		"height": snappedf(value.size.y, 0.001),
	}.duplicate(true)


func _transform_dictionary(value: Transform3D) -> Dictionary:
	return {
		"origin": _vector3_array(value.origin),
		"basis_x": _vector3_array(value.basis.x),
		"basis_y": _vector3_array(value.basis.y),
		"basis_z": _vector3_array(value.basis.z),
	}.duplicate(true)


func _anchor_manifest_dictionary() -> Dictionary:
	var result := {}
	for anchor_name: StringName in EXPECTED_ANCHORS:
		result[String(anchor_name)] = _vector3_array(EXPECTED_ANCHORS[anchor_name])
	return result


func _vector3_array(value: Vector3) -> Array[float]:
	return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001), snappedf(value.z, 0.000001)]


func _settle_render(frame_count: int) -> void:
	for _index in frame_count:
		await process_frame


func _dispose_game() -> void:
	Input.action_release("move_forward")
	Input.action_release("roll_right")
	if is_instance_valid(_game):
		_game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("ZENITH_VISUAL_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	if not _failures.has(description):
		_failures.append(description)
	push_error("ZENITH_VISUAL_FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("MUDDS_ZENITH_VISUAL_CAPTURE_OK: %d HUD-free source-frozen native X11 Forward+ frames at %dx%d; HUMAN_ART_REVIEW_REQUIRED" % [_semantic_frames.size(), CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y])
		quit(0)
	else:
		_remove_file_if_present(EVIDENCE_MANIFEST_PATH, "failed capture invalidates evidence sentinel")
		push_error("MUDDS_ZENITH_VISUAL_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)
