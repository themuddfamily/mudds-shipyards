extends SceneTree

## Source-current Forward+ acceptance harness for the production hero cell.
##
## This runner instantiates the live ShipyardWorld, Torrent, and PlayerController.
## It adds only an evidence camera and temporary neutral review lights. It never
## adds a HUD, reticle, toast, or CanvasLayer and never replaces production art.
##
## Set KETH_CAPTURE_HERO_CELL_PARSE_ONLY=1 to validate the script without
## opening a renderer or touching artifacts/hero_cell. Set
## KETH_CAPTURE_HERO_CELL_STAGING_ONLY=1 to execute only the real automatic
## propulsion wake and 1.5-second neutral shutdown route. The production capture
## is intentionally run only after the art/source freeze has been declared stable.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const PILOT_SCENE := preload("res://scenes/player/player.tscn")

const PARSE_ONLY_ENVIRONMENT_VARIABLE := "KETH_CAPTURE_HERO_CELL_PARSE_ONLY"
const STAGING_ONLY_ENVIRONMENT_VARIABLE := "KETH_CAPTURE_HERO_CELL_STAGING_ONLY"
const OUTPUT_DIR := "res://artifacts/hero_cell"
const EVIDENCE_MANIFEST_PATH := OUTPUT_DIR + "/evidence_manifest.json"
const SOURCE_MANIFEST_PATH := OUTPUT_DIR + "/source_manifest.sha256"
const TRANSACTION_DIR := OUTPUT_DIR + "/.capture_transaction"
const STAGED_EVIDENCE_MANIFEST_PATH := TRANSACTION_DIR + "/evidence_manifest.json"
const STAGED_SOURCE_MANIFEST_PATH := TRANSACTION_DIR + "/source_manifest.sha256"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const RECONSTRUCTION_AUDIT_METHOD := &"get_torrent_reconstruction_audit_report"
const ART_AUDIT_METHOD := &"get_torrent_art_audit_report"

const CAPTURE_FILES := [
	"01_wide_berth.png",
	"02_torrent_front_three_quarter_sealed.png",
	"03_torrent_true_profile.png",
	"04_torrent_true_dorsal.png",
	"05_landing_gear_clamps.png",
	"06_pilot_walk_up.png",
	"07_canopy_open_boarding.png",
	"08_seated_cockpit_exterior_sealed.png",
	"09_lod0_near_whole_ship_34m.png",
	"10_lod1_far_whole_ship_52m.png",
	"11_aft_engines_offline_fixed.png",
	"12_aft_engines_online_fixed.png",
	"13_powered_chase_25m.png",
	"14_powered_chase_50m.png",
	"15_neutral_light_uv_material_crop.png",
	"16_cockpit_offline_fixed.png",
	"17_cockpit_online_fixed.png",
	"18_cockpit_critical_fixed.png",
]
const CAPTURE_STATES := [
	"wide_berth",
	"front_three_quarter_sealed",
	"true_profile",
	"true_dorsal",
	"landing_gear_clamps",
	"pilot_walk_up",
	"canopy_open_boarding",
	"seated_exterior_sealed",
	"lod0_near_whole_ship",
	"lod1_far_whole_ship",
	"aft_engines_offline",
	"aft_engines_online",
	"powered_chase_25m",
	"powered_chase_50m",
	"neutral_light_uv_material_crop",
	"cockpit_offline",
	"cockpit_online",
	"cockpit_critical",
]

const SOURCE_ROOTS := [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://default_bus_layout.tres",
	"res://tests/capture_hero_cell.gd",
	"res://tests/capture_hero_cell.gd.uid",
	"res://scripts",
	"res://scenes",
	"res://assets",
	"res://art_source",
	"res://tools",
]

const REQUIRED_RECONSTRUCTION_NODES: Array[String] = [
	"visual_root",
	"pointed_nose",
	"raised_spine",
	"blocky_aft",
	"port_lower_side_plane",
	"port_upper_side_plane",
	"starboard_lower_side_plane",
	"starboard_upper_side_plane",
	"port_aft_housing",
	"starboard_aft_housing",
	"port_aft_rail",
	"starboard_aft_rail",
	"pilot_area",
	"pilot_seat",
	"forward_panel",
]

const REQUIRED_IMPORTED_ROOTS := [
	&"LOD0", &"LOD1", &"CockpitArt", &"CanopyPivot", &"SemanticAnchors",
]
const REQUIRED_CANOPY_SOURCE_OBJECTS := [
	"CanopyGlass",
	"CanopyForwardFrame",
	"CanopyRearFrame",
	"CanopyTopSpine",
	"CanopyRearSeal",
	"CanopyHingeBar",
	"PortCanopySill",
	"PortCanopyUpright",
	"PortCanopyForwardRake",
	"PortCanopySideRail",
	"PortCanopySeal",
	"PortCanopyHinge",
	"PortCanopyLatch",
	"PortCanopyStriker",
	"StarboardCanopySill",
	"StarboardCanopyUpright",
	"StarboardCanopyForwardRake",
	"StarboardCanopySideRail",
	"StarboardCanopySeal",
	"StarboardCanopyHinge",
	"StarboardCanopyLatch",
	"StarboardCanopyStriker",
]
const REQUIRED_ENGINE_DEPTH_LAYERS := [
	"AftCircularHousing",
	"EngineOuterCollar",
	"EngineNozzle",
	"EngineThermalLip",
	"EngineCore",
]
const MATERIAL_ROLES := [
	&"WarmIvoryHull",
	&"IvorySecondary",
	&"GraphiteMachinery",
	&"ExposedAlloy",
	&"CyanStatus",
	&"AmberPanel",
	&"CrimsonSeat",
	&"CrimsonLivery",
	&"NeutralCanopyGlass",
	&"ThermalCeramic",
]
const EXPECTED_RUNTIME_MESH_COUNTS := {
	"CanopyPivot": 3,
	"CockpitArt": 7,
	"LOD0": 17,
	"LOD1": 5,
	"SemanticAnchors": 0,
}
const EXPECTED_SOURCE_MESH_COUNTS := {
	"CanopyPivot": 22,
	"CockpitArt": 39,
	"LOD0": 238,
	"LOD1": 18,
	"SemanticAnchors": 0,
}

const MINIMUM_PNG_BYTES := 150_000
const MINIMUM_LUMINANCE_RANGE := 0.055
const MINIMUM_LUMINANCE_VARIANCE := 0.00018
const PIXEL_CHANGE_THRESHOLD := 0.018
const MINIMUM_DISTINCT_MEAN_DIFFERENCE := 0.00012
const MINIMUM_DISTINCT_CHANGED_FRACTION := 0.0015

const COCKPIT_OFFLINE_ONLINE_MINIMUM_CHANGED_FRACTION := 0.03
const COCKPIT_ONLINE_CRITICAL_MINIMUM_CHANGED_FRACTION := 0.05
const COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION := 0.005
const COCKPIT_DISPLAY_ROI_MINIMUM_SAMPLES := 20
const COCKPIT_EXTERIOR_MINIMUM_SAMPLES := 1000
const COCKPIT_INSTRUMENT_MINIMUM_TOP_FRACTION := 0.64
const COCKPIT_INSTRUMENT_MAXIMUM_TOP_FRACTION := 0.82
const COCKPIT_INSTRUMENT_MAXIMUM_HEIGHT_FRACTION := 0.35

## Frames each fixed-cockpit differential state settles for before readback.
##
## The exterior control is a pixel differential of a deliberately frozen scene,
## so it is only as tight as the renderer's own frame-to-frame reproducibility.
## TAA is enabled on this viewport (`_configure_native_capture`) and never stops
## jittering, so that floor is not zero. Settling longer was tried as a repair and
## bought nothing: the floor measured 0.0044 and 0.0120 on two runs at 8 frames
## and 0.0124 on one at 48, so it is unstable run to run and independent of this
## value, while 48 frames cost roughly three times the harness runtime. It
## therefore stays at the original 8, and the floor is instead measured every run
## and printed as `HERO_CELL_DIAGNOSTIC` — which is what lets a reader tell a
## marginal exterior number apart from renderer noise instead of guessing at it.
const COCKPIT_DIFFERENTIAL_SETTLE_FRAMES := 8

## Simulated frames granted on top of a nominal duration, so a condition that
## settles right on the edge of its budget is not lost to rounding.
const FRAME_BUDGET_GRACE := 30
const AUTOMATIC_ENGINE_IDLE_SHUTDOWN_GRACE_FRAMES := 3
const FLIGHT_CONTROL_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"hover",
	&"fire", &"sprint_boost", &"jump",
]

const SHIP_MASK_GRID := Vector2i(128, 72)
const SHIP_MASK_MINIMUM_SAMPLES := 120
const MATERIAL_MASK_MINIMUM_SAMPLES := 20
const SHIP_LUMINANCE_P5_MINIMUM := 0.04
const SHIP_LUMINANCE_P95_MAXIMUM := 0.95
const IVORY_LUMINANCE_MEDIAN_MINIMUM := 0.35
const IVORY_LUMINANCE_MEDIAN_MAXIMUM := 0.72
## The neutral crop acceptance is a ship-material check. The station backdrop
## is intentionally uncontrolled, so it is recorded for diagnosis only and
## never decides whether the crop passes.
const IVORY_GRAPHITE_MINIMUM_DELTA := 0.08
const SHIP_MAXIMUM_CLIPPED_FRACTION := 0.005

var _failures: Array[String] = []
var _captured_images: Dictionary = {}
var _semantic_frames: Array[Dictionary] = []
var _pair_metrics: Dictionary = {}
var _fixed_camera_contracts: Dictionary = {}
var _reconstruction_nodes: Dictionary = {}
var _source_snapshot: Dictionary = {}
var _source_aggregate_sha256 := ""
var _source_paths := PackedStringArray()
var _source_frozen_validated := false
var _lighting_metrics: Dictionary = {}
var _cockpit_display_roi := Rect2i()
var _triangle_mesh_cache: Dictionary = {}
var _cockpit_camera_for_metrics: Camera3D
var _cockpit_critical_exterior_control: Image
var _quiesced_damage_emitters := PackedStringArray()

var _stage: Node3D
var _world: ShipyardWorld
var _torrent: HeroShip
var _pilot: PlayerController
var _central_berth: ShipBerth
var _evidence_camera: Camera3D
var _hero_presentation: TorrentHeroPresentation
var _hero_asset_root: Node3D
var _asset_manifest: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("HERO_CELL_CAPTURE_PARSE_OK: 18-frame v5 acceptance inventory")
		quit(0)
		return
	if OS.get_environment(STAGING_ONLY_ENVIRONMENT_VARIABLE) == "1":
		await _run_automatic_propulsion_witness()
		return

	_configure_native_capture()
	if not _capture_renderer_is_available():
		_fail("capture renderer is unavailable; refusing to wait for a frame that cannot be read back")
		_finish()
		return
	_source_paths = _collect_source_paths()
	_source_snapshot = _snapshot_source_files()
	_source_aggregate_sha256 = _source_snapshot_hash(_source_snapshot)
	_check(
		_source_paths.size() > SOURCE_ROOTS.size()
		and _source_snapshot.size() == _source_paths.size()
		and not _source_aggregate_sha256.is_empty(),
		"source-current capture scope has a complete frozen start snapshot"
	)

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_check(
		directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
		"hero-cell output directory is available"
	)
	_reset_capture_transaction()
	_check(
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TRANSACTION_DIR)),
		"isolated hero-cell capture transaction directory is available"
	)

	_stage = Node3D.new()
	_stage.name = "HeroCellForwardCaptureV5"
	root.add_child(_stage)

	_world = WORLD_SCENE.instantiate() as ShipyardWorld
	_check(_world != null, "production ShipyardWorld instantiates")
	if _world == null:
		_finish()
		return
	_stage.add_child(_world)
	await _settle_render(3)
	await physics_frame

	_central_berth = _world.get_berth_node(&"central_berth")
	_check(_central_berth != null, "production central ShipBerth exists")
	_check(
		_central_berth != null
		and _central_berth.get_berth_id() == &"central_berth"
		and _central_berth.get_validation_errors().is_empty(),
		"central berth contract is valid"
	)
	if _central_berth == null:
		_finish()
		return

	_torrent = TORRENT_SCENE.instantiate() as HeroShip
	_check(_torrent != null, "production Torrent instantiates as HeroShip")
	if _torrent == null:
		_finish()
		return
	_torrent.transform = _central_berth.get_dock_transform()
	_stage.add_child(_torrent)
	await process_frame
	_torrent.reset_for_reuse(_central_berth.get_dock_transform())

	_pilot = PILOT_SCENE.instantiate() as PlayerController
	_check(_pilot != null, "production pilot instantiates as PlayerController")
	if _pilot == null:
		_finish()
		return
	_pilot.transform = _world.get_player_spawn()
	_stage.add_child(_pilot)
	await process_frame
	await physics_frame
	_pilot.set_control_enabled(false)
	_pilot.set_camera_active(false)
	_pilot.teleport_to(_world.get_player_spawn())

	_hero_presentation = _torrent.get_node_or_null(
		^"TorrentVisual/TorrentHeroPresentation"
	) as TorrentHeroPresentation
	_hero_asset_root = (
		_hero_presentation.get_asset_root() if _hero_presentation != null else null
	)
	_asset_manifest = _read_json(
		"res://assets/models/torrent/hero/torrent_hero_asset_manifest.json"
	)
	_validate_source_components()
	_validate_hud_policy()

	_evidence_camera = Camera3D.new()
	_evidence_camera.name = "HeroCellEvidenceCamera"
	_evidence_camera.near = 0.06
	_evidence_camera.far = 2200.0
	_stage.add_child(_evidence_camera)
	_evidence_camera.current = true

	# 01 — Production berth, station scale, live pilot, and parked craft.
	_frame_camera(
		_berth_point(Vector3(-30.0, 24.0, 37.0)),
		_berth_point(Vector3(0.0, 1.0, -4.0)),
		58.0
	)
	await _capture_frame(CAPTURE_FILES[0], &"wide_berth", {
		"world": "production_shipyard_world",
		"berth": "central_berth",
		"hud_policy": "HUD_OFF_NO_CANVASLAYER",
	})

	# 02 — Sealed low front three-quarter identity view.
	_frame_camera(
		_ship_point(Vector3(-8.6, 4.6, -10.8)),
		_ship_point(Vector3(0.0, 0.9, -0.5)),
		32.0
	)
	await _capture_frame(CAPTURE_FILES[1], &"front_three_quarter_sealed", {
		"canopy": "sealed",
		"identity": "b5_observed_source_aligned_partial",
	})

	# 03 — Exact starboard profile: camera-to-focus is ship-local -X.
	var profile_focus := _ship_point(Vector3(0.0, 1.45, -0.35))
	_frame_camera(_ship_point(Vector3(15.5, 1.45, -0.35)), profile_focus, 34.0)
	_check(
		(-_evidence_camera.global_basis.z).normalized().dot(
			-_torrent.global_basis.x.normalized()
		) >= 0.9999,
		"profile frame uses a true ship-local side elevation"
	)
	await _capture_frame(CAPTURE_FILES[2], &"true_profile", {
		"projection": "true_starboard_profile",
	})

	# 04 — True dorsal/top. A ship-forward up vector avoids look-at singularity.
	var dorsal_focus := _ship_point(Vector3(0.0, 1.0, -0.2))
	_frame_camera(
		_ship_point(Vector3(0.0, 24.0, -0.2)),
		dorsal_focus,
		30.0,
		-_torrent.global_basis.z.normalized()
	)
	_check(
		(-_evidence_camera.global_basis.z).normalized().dot(
			-_torrent.global_basis.y.normalized()
		) >= 0.9999,
		"dorsal frame is a true ship-local top view"
	)
	await _capture_frame(CAPTURE_FILES[3], &"true_dorsal", {
		"projection": "true_dorsal_top",
	})

	# 05 — Physical tricycle gear, authored clamp jaws, and berth hardware.
	_frame_camera(
		_ship_point(Vector3(-7.4, 0.75, 5.5)),
		_ship_point(Vector3(-0.65, -0.18, 0.8)),
		34.0
	)
	await _capture_frame(CAPTURE_FILES[4], &"landing_gear_clamps", {
		"gear_assemblies": 3,
		"berth_clamps": 3,
	})

	# 06 — Actual PlayerController at the walk-up approach.
	var boarding_point := _torrent.get_boarding_position()
	var walk_up_position := _ship_point(Vector3(-7.9, -0.97, -1.7))
	_pilot.force_recovery_to_on_foot(
		Transform3D(Basis(Vector3.UP, -PI * 0.5), walk_up_position)
	)
	await physics_frame
	await process_frame
	_check(
		Vector2(
			_pilot.global_position.x - walk_up_position.x,
			_pilot.global_position.z - walk_up_position.z
		).length() < 0.15 and not _pilot.is_seated(),
		"walk-up frame uses the live on-foot pilot beside the Torrent"
	)
	_frame_camera(
		_ship_point(Vector3(-14.5, 4.2, -3.8)),
		_ship_point(Vector3(-1.5, 1.0, -0.4)),
		37.0
	)
	await _capture_frame(CAPTURE_FILES[5], &"pilot_walk_up", {
		"pilot_authority": "production_player_controller",
		"embodiment": "ON_FOOT",
	})

	# 07 — Real canopy hinge and real boarding state machine, sampled pre-seat.
	var boarding_start_position := Vector3(
		boarding_point.x - 0.72,
		_world.get_player_spawn().origin.y,
		boarding_point.z + 0.25
	)
	_pilot.force_recovery_to_on_foot(
		Transform3D(Basis(Vector3.UP, -PI * 0.5), boarding_start_position)
	)
	await physics_frame
	await process_frame
	_torrent.set_canopy_open(true, 0.0)
	await process_frame
	_check(
		_pilot.begin_boarding(
			_torrent.get_boarding_entry_transform(),
			_torrent.get_pilot_seat_anchor(),
			2.8
		),
		"live pilot begins the production boarding transition"
	)
	# Wait for the boarding transition the frame below asserts on, rather than for
	# 1.25 s of smoothed engine delta. `is_seated()` ends the wait too, so an
	# overshoot fails loudly on the assertions instead of burning the budget.
	await _wait_until(
		func() -> bool:
			return (
				_pilot.is_seated()
				or _pilot.global_position.distance_to(boarding_start_position) > 0.65
			),
		1.25
	)
	_validate_open_canopy_semantics()
	_check(
		not _pilot.is_seated()
		and _pilot.global_position.distance_to(boarding_start_position) > 0.65,
		"boarding frame visibly precedes the seated state"
	)
	_frame_camera(
		_ship_point(Vector3(-9.0, 6.2, -2.5)),
		_ship_point(Vector3(-0.45, 3.05, -0.2)),
		44.0
	)
	await _capture_frame(CAPTURE_FILES[6], &"canopy_open_boarding", {
		"canopy": "fully_open_63_degrees",
		"embodiment": "BOARDING",
		"human_review_required": "continuous thin glass/frame/hinge and no clipping",
	})

	if not await _wait_for_seated(4.0):
		_fail("pilot did not finish boarding at the production seat anchor")
	else:
		_torrent.set_canopy_open(false, 0.0)
		await process_frame
		await physics_frame
	_validate_sealed_exterior_semantics()

	# 08 — Same live pilot seated behind the sealed imported canopy.
	_frame_camera(
		_ship_point(Vector3(6.4, 5.65, -5.2)),
		_ship_point(Vector3(0.0, 2.95, -0.45)),
		36.0
	)
	await _capture_frame(CAPTURE_FILES[7], &"seated_exterior_sealed", {
		"canopy": "sealed",
		"embodiment": "SEATED",
		"human_review_required": "helmet visible and at least 60 percent crimson-seat silhouette retained",
	})

	# 09/10 — Whole-ship LOD handoff at exact controlled camera distances.
	_set_lod_review_camera(34.0, 20.0)
	_hero_presentation.update_lod_for_distance(34.0)
	await process_frame
	_validate_active_lod(0, 34.0)
	await _capture_frame(CAPTURE_FILES[8], &"lod0_near_whole_ship", {
		"camera_distance_m": 34.0,
		"expected_lod": 0,
		"whole_ship": true,
	})

	_set_lod_review_camera(52.0, 15.5)
	_hero_presentation.update_lod_for_distance(52.0)
	await process_frame
	_validate_active_lod(1, 52.0)
	await _capture_frame(CAPTURE_FILES[9], &"lod1_far_whole_ship", {
		"camera_distance_m": 52.0,
		"expected_lod": 1,
		"whole_ship": true,
	})

	# Return to close art before fixed aft engine evidence.
	_hero_presentation.update_lod_for_distance(0.0)
	await process_frame
	_validate_active_lod(0, 0.0)
	_frame_camera(
		_ship_point(Vector3(0.0, 4.5, 12.5)),
		_ship_point(Vector3(0.0, 1.55, 2.55)),
		38.0
	)
	_validate_engine_depth_contract()
	_check(str(_torrent.get_telemetry().get("engine_state", "")) == "OFFLINE", "aft baseline is engine-offline")
	await _capture_frame(CAPTURE_FILES[10], &"aft_engines_offline", {
		"engine_state": "offline",
		"source_depth_layers_per_side": 5,
	}, &"aft_fixed")

	_check(
		await _wake_engine_with_hover(_evidence_camera),
		"accepted hover demand wakes Torrent ONLINE in one physics tick"
	)
	await _settle_render(8)
	await _capture_frame(CAPTURE_FILES[11], &"aft_engines_online", {
		"engine_state": "online",
		"source_depth_layers_per_side": 5,
	}, &"aft_fixed")

	# 13/14 — Powered chase-like review views at exact 25 m and 50 m.
	_set_powered_chase_camera(25.0, 38.0)
	_hero_presentation.update_lod_for_distance(25.0)
	await process_frame
	_validate_active_lod(0, 25.0)
	await _capture_frame(CAPTURE_FILES[12], &"powered_chase_25m", {
		"camera_distance_m": 25.0,
		"engine_state": "online",
		"expected_lod": 0,
		"camera_kind": "capture_only_chase_aligned_review",
	})

	_set_powered_chase_camera(50.0, 25.0)
	_hero_presentation.update_lod_for_distance(50.0)
	await process_frame
	_validate_active_lod(1, 50.0)
	await _capture_frame(CAPTURE_FILES[13], &"powered_chase_50m", {
		"camera_distance_m": 50.0,
		"engine_state": "online",
		"expected_lod": 1,
		"camera_kind": "capture_only_chase_aligned_review",
	})

	# 15 — Close UV/PBR material crop under capture-only neutral key/fill/rim.
	_check(
		await _idle_engine_offline(),
		"neutral material crop reaches OFFLINE on the exact production 1.5-second physics clock"
	)
	_hero_presentation.update_lod_for_distance(0.0)
	await process_frame
	_validate_active_lod(0, 0.0)
	var light_snapshot := _enable_neutral_review_lighting()
	_frame_camera(
		_ship_point(Vector3(-5.6, 4.8, -9.2)),
		_ship_point(Vector3(-0.45, 1.0, -2.15)),
		24.0
	)
	_validate_uv_material_crop_contract()
	await _capture_frame(CAPTURE_FILES[14], &"neutral_light_uv_material_crop", {
		"lighting": "capture_only_D65_key_fill_rim",
		"production_lights": "temporarily_hidden_and_restored",
		"production_environment": "unchanged",
		"engine_state": "offline",
		"material_roles": ["WarmIvoryHull", "GraphiteMachinery"],
	}, &"", true)
	_restore_production_lighting(light_snapshot)

	# 16/17/18 — One physical pilot-eye camera and immutable world/craft pose.
	# Freeze only the production world's presentation tick so rail activity cannot
	# manufacture false outside-ROI changes. The Torrent remains fully live: its
	# actual engine, readout, practical light, and damage state still advance.
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_torrent.set_cockpit_view(true)
	_torrent.set_piloted(true)
	_evidence_camera.current = false
	var cockpit_camera := _torrent.get_camera()
	_check(
		cockpit_camera != null
		and cockpit_camera.name == &"CockpitCamera"
		and cockpit_camera.current,
		"cockpit states use the production physical pilot-eye camera"
	)
	_hero_presentation.update_lod_for_distance(0.0)
	await _settle_render(COCKPIT_DIFFERENTIAL_SETTLE_FRAMES)
	_validate_cockpit_acceptance_contract(cockpit_camera)
	await _capture_frame(CAPTURE_FILES[15], &"cockpit_offline", {
		"engine_state": "offline",
		"damage_status": "healthy",
		"sight_corridor_degrees": [20.0, 12.0],
		"world_presentation_tick": "capture_only_frozen_for_pixel_differential",
	}, &"cockpit_fixed")

	_check(
		await _wake_engine_with_hover(cockpit_camera),
		"accepted cockpit hover demand wakes Torrent ONLINE in one physics tick"
	)
	await _settle_render(COCKPIT_DIFFERENTIAL_SETTLE_FRAMES)
	await _capture_frame(CAPTURE_FILES[16], &"cockpit_online", {
		"engine_state": "online",
		"damage_status": "healthy",
		"sight_corridor_degrees": [20.0, 12.0],
		"world_presentation_tick": "capture_only_frozen_for_pixel_differential",
	}, &"cockpit_fixed")

	await _diagnose_exterior_noise_floor()

	_torrent.apply_damage(_torrent.maximum_hull * 0.76)
	await _settle_render(COCKPIT_DIFFERENTIAL_SETTLE_FRAMES)
	var critical_telemetry := _torrent.get_telemetry()
	_check(
		str(critical_telemetry.get("damage_status", "")) == "critical"
		and float(critical_telemetry.get("hull", 100.0)) <= _torrent.maximum_hull * 0.3,
		"fixed cockpit critical frame uses the live production damage state"
	)
	await _capture_frame(CAPTURE_FILES[17], &"cockpit_critical", {
		"engine_state": "online",
		"damage_status": "critical",
		"sight_corridor_degrees": [20.0, 12.0],
		"world_presentation_tick": "capture_only_frozen_for_pixel_differential",
	}, &"cockpit_fixed")

	await _capture_cockpit_critical_exterior_control()

	_validate_capture_set()
	_validate_source_frozen()
	if _failures.is_empty():
		_write_source_manifest()
		_write_evidence_manifest()
	# Freeze once more after all staged evidence I/O. The evidence manifest is
	# published only if the source tree still has the identical recursive roster
	# and byte hashes at the actual publication boundary.
	if _failures.is_empty():
		_validate_source_frozen()
	if _failures.is_empty():
		_publish_capture_transaction()

	_release_flight_controls()
	_torrent.set_piloted(false)
	_stage.queue_free()
	await process_frame
	_finish()


func _configure_native_capture() -> void:
	DisplayServer.window_set_size(CAPTURE_RESOLUTION)
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	var display_name := DisplayServer.get_name()
	var native_window_size := DisplayServer.window_get_size()
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	_check(display_name == "X11", "capture uses a native X11 display")
	_check(root.size == CAPTURE_RESOLUTION, "root viewport accepts exact 2560x1440 output")
	_check(
		native_window_size == CAPTURE_RESOLUTION,
		"native X11 window content is exactly 2560x1440"
	)
	print(
		"HERO_CELL_RENDERER: method=%s adapter=%s display=%s window=%dx%d viewport=%dx%d"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			display_name,
			native_window_size.x,
			native_window_size.y,
			CAPTURE_RESOLUTION.x,
			CAPTURE_RESOLUTION.y,
		]
	)


## A graphical invocation can still fall back to a displayless renderer. Do not
## enter the frame-post-draw capture path in that state: it cannot produce
## evidence, and waiting for it would make this fail-open harness hang instead
## of reporting an actionable failure.
func _capture_renderer_is_available() -> bool:
	var adapter := RenderingServer.get_video_adapter_name().strip_edges()
	return (
		RenderingServer.get_current_rendering_method() == &"forward_plus"
		and DisplayServer.get_name() == "X11"
		and not adapter.is_empty()
		and adapter != "Unknown"
		and root.get_texture() != null
	)


func _validate_hud_policy() -> void:
	_check(
		_stage.find_children("*", "CanvasLayer", true, false).is_empty()
		and _stage.find_child("HUD", true, false) == null,
		"HUD policy is explicit: isolated stage contains no HUD or CanvasLayer"
	)


func _validate_source_components() -> void:
	var berth_audit := _world.get_central_berth_audit_report()
	_check(
		bool(berth_audit.get("valid", false))
		and _string_array(berth_audit.get("errors", PackedStringArray())).is_empty(),
		"capture berth passes its production hero-cell audit"
	)
	var berth_features := berth_audit.get("feature_counts", {}) as Dictionary
	var berth_asset_audit := berth_audit.get("authored_asset_audit", {}) as Dictionary
	_check(
		int(berth_features.get(&"docking_clamp", 0)) == 3
		and int(berth_features.get(&"umbilical_housing", 0)) == 3
		and bool(berth_asset_audit.get("valid", false))
		and int(berth_asset_audit.get("runtime_mesh_count", 0)) == 8
		and int(berth_asset_audit.get("runtime_triangle_count", 0)) == 11_508,
		"capture berth has exact clamps and its source-current Blender-authored service hierarchy"
	)

	_check(_torrent.has_method(ART_AUDIT_METHOD), "Torrent publishes the combined production art audit")
	var art_audit: Dictionary = {}
	if _torrent.has_method(ART_AUDIT_METHOD):
		var art_value: Variant = _torrent.call(ART_AUDIT_METHOD)
		if art_value is Dictionary:
			art_audit = art_value as Dictionary
	_check(
		bool(art_audit.get("valid", false))
		and _string_array(art_audit.get("errors", PackedStringArray())).is_empty(),
		"capture Torrent passes the complete source-current art audit"
	)
	_check(
		int(art_audit.get("schema_version", 0)) >= 4
		and bool(art_audit.get("close_art_active", false))
		and not bool(art_audit.get("legacy_far_visible", true))
		and bool(art_audit.get("gameplay_authority_unchanged", false))
		and bool(art_audit.get("collision_authority_unchanged", false))
		and bool(art_audit.get("functional_authority_unchanged", false))
		and bool(art_audit.get("presentation_lifecycle_valid", false)),
		"combined audit proves close art, hidden fallback, gameplay authority, and lifecycle integrity"
	)

	_check(_hero_presentation != null, "production Torrent owns the exact hero presentation adapter")
	var close_audit := (
		_hero_presentation.get_asset_audit_report() if _hero_presentation != null else {}
	)
	_check(
		bool(close_audit.get("valid", false))
		and _string_array(close_audit.get("errors", PackedStringArray())).is_empty(),
		"Blender-authored close presentation passes its immutable runtime audit"
	)
	_check(
		_hero_asset_root != null and _hero_asset_root.name == &"TorrentHeroArt",
		"close presentation exposes the exact imported TorrentHeroArt root"
	)
	for required_root: StringName in REQUIRED_IMPORTED_ROOTS:
		_check(
			_hero_asset_root != null
			and _hero_asset_root.get_node_or_null(NodePath(String(required_root))) != null,
			"close presentation exposes required root %s" % required_root
		)
	_check(
		str(close_audit.get("manifest_glb_sha256", ""))
		== FileAccess.get_sha256("res://assets/models/torrent/hero/torrent_hero_art.glb"),
		"live close presentation is pinned to the checked-in GLB hash"
	)

	_check(_torrent.has_method(RECONSTRUCTION_AUDIT_METHOD), "Torrent publishes the dated-reconstruction audit")
	var reconstruction: Dictionary = {}
	if _torrent.has_method(RECONSTRUCTION_AUDIT_METHOD):
		var reconstruction_value: Variant = _torrent.call(RECONSTRUCTION_AUDIT_METHOD)
		if reconstruction_value is Dictionary:
			reconstruction = reconstruction_value as Dictionary
	_check(
		bool(reconstruction.get("valid", false))
		and _string_array(reconstruction.get("errors", PackedStringArray())).is_empty(),
		"capture Torrent retains a valid source-aligned B5-observed reconstruction audit"
	)
	_check(
		str(reconstruction.get("identity_lock", "")) == "b5_observed_name_to_model"
		and str(reconstruction.get("historical_revision", "")) == "unverified"
		and str(reconstruction.get("source_upload_date", "")) == "2011-06-29"
		and str(reconstruction.get("recording_date_status", "")) == "unknown"
		and str(reconstruction.get("game_build_revision_status", "")) == "unknown"
		and str(reconstruction.get("reconstruction_status", "")) == "partial"
		and str(reconstruction.get("2009_continuity", "")) == "unproved"
		and not bool(reconstruction.get("authenticated_geometry", true)),
		"capture preserves the exact honest historical-claim boundary"
	)
	var source_references := _string_array(
		reconstruction.get("source_references", PackedStringArray())
	)
	_check(
		_contains_tokens(source_references, ["B5"])
		and _contains_tokens(source_references, ["B6"]),
		"capture reconstruction cites decisive B5 and independent B6"
	)
	var contract_value: Variant = reconstruction.get("node_contract", {})
	_check(contract_value is Dictionary, "capture audit exposes semantic reconstruction paths")
	var node_contract := contract_value as Dictionary if contract_value is Dictionary else {}
	_reconstruction_nodes.clear()
	for key: String in REQUIRED_RECONSTRUCTION_NODES:
		var component := _resolve_contract_node(node_contract, key)
		_check(component != null, "capture reconstruction component %s resolves" % key)
		if component != null:
			_reconstruction_nodes[key] = component

	_check(
		int(_asset_manifest.get("schema_version", 0)) == 1
		and str(_asset_manifest.get("glb_sha256", ""))
		== FileAccess.get_sha256("res://assets/models/torrent/hero/torrent_hero_art.glb")
		and str(_asset_manifest.get("blend_sha256", ""))
		== FileAccess.get_sha256("res://art_source/torrent/torrent_hero_v1.blend"),
		"hero asset manifest pins the exact runtime GLB and editable Blender source"
	)
	var batching := _asset_manifest.get("runtime_static_batching", {}) as Dictionary
	_check(
		str(batching.get("strategy", ""))
			== "per_semantic_root_per_material_static_join"
		and bool(batching.get("source_preserved_in_blend", false))
		and int(batching.get("runtime_mesh_count_total", -1)) == 32
		and int(batching.get("source_mesh_count_total", -1)) == 317
		and _integer_dictionary_matches(
			batching.get("runtime_mesh_counts_by_root", {}) as Dictionary,
			EXPECTED_RUNTIME_MESH_COUNTS
		)
		and _integer_dictionary_matches(
			batching.get("source_mesh_counts_by_root", {}) as Dictionary,
			EXPECTED_SOURCE_MESH_COUNTS
		),
		"capture pins the exact 317-source / 32-runtime semantic-root batching contract"
	)

	var pilot_audit := _pilot.get_pilot_presentation_audit()
	_check(
		_pilot.get_pilot_visual_root() != null
		and bool(pilot_audit.get("valid", false))
		and int(pilot_audit.get("skinned_mesh_count", 0)) == 1
		and int(pilot_audit.get("bone_count", 0)) == 23
		and float(pilot_audit.get("visible_height_m", 0.0)) > 1.5,
		"capture pilot is the complete Blender-skinned production presentation"
	)
	_check(
		_torrent.global_transform.is_equal_approx(_central_berth.get_dock_transform())
		and _central_berth.contains_transform(_torrent.global_transform),
		"parked Torrent occupies the production central berth transform"
	)


func _validate_open_canopy_semantics() -> void:
	var imported_canopy := _hero_presentation.get_canopy_pivot() if _hero_presentation != null else null
	var source_canopy := (_asset_manifest.get("collections", {}) as Dictionary).get(
		"CanopyPivot", []
	) as Array
	var exact_source_roster := source_canopy.size() == REQUIRED_CANOPY_SOURCE_OBJECTS.size()
	for object_name in REQUIRED_CANOPY_SOURCE_OBJECTS:
		exact_source_roster = exact_source_roster and source_canopy.has(object_name)
	_check(
		_torrent.is_canopy_open()
		and imported_canopy != null
		and is_equal_approx(imported_canopy.rotation.x, deg_to_rad(63.0))
		and imported_canopy.visible
		and exact_source_roster,
		"open canopy retains its exact glass/frame source roster and 63-degree live hinge"
	)
	_check(
		_torrent.get_node_or_null(^"TorrentVisual/CanopyHinge") is Node3D
		and _torrent.find_child("CanopyHingeBar", true, false) is MeshInstance3D
		and _torrent.find_children("*CanopyHingeMount", "MeshInstance3D", true, false).size() == 2,
		"open canopy retains the functional pivot, hinge bar, and paired mounts"
	)


func _validate_sealed_exterior_semantics() -> void:
	var seat_anchor := _torrent.get_pilot_seat_anchor()
	var pilot_parts := _pilot.get_pilot_visual_parts()
	var imported_canopy := _hero_presentation.get_canopy_pivot() if _hero_presentation != null else null
	var source_cockpit := (_asset_manifest.get("collections", {}) as Dictionary).get(
		"CockpitArt", []
	) as Array
	var cockpit_root := _hero_presentation.get_cockpit_art_root() if _hero_presentation != null else null
	var crimson_batches: Array[Node] = []
	if cockpit_root != null:
		for candidate in cockpit_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if StringName(mesh_instance.get_meta("torrent_material_role", &"")) == &"CrimsonSeat":
				crimson_batches.append(mesh_instance)
	_check(
		_pilot.is_seated()
		and seat_anchor != null
		and _pilot.global_position.distance_to(seat_anchor.global_position) < 0.08,
		"sealed exterior uses the live pilot at the production seat anchor"
	)
	_check(
		not _torrent.is_canopy_open()
		and imported_canopy != null
		and is_zero_approx(imported_canopy.rotation.x)
		and imported_canopy.visible,
		"sealed exterior uses the continuous imported canopy at its closed transform"
	)
	_check(
		pilot_parts.size() == 1
		and (pilot_parts[0] as MeshInstance3D).is_visible_in_tree()
		and source_cockpit.has("CrimsonSeatPan")
		and source_cockpit.has("CrimsonSeatBack")
		and crimson_batches.size() == 2
		and (crimson_batches[0] as MeshInstance3D).is_visible_in_tree()
		and (crimson_batches[1] as MeshInstance3D).is_visible_in_tree(),
		"sealed frame contains the live skinned pilot, protected seat pan, and crimson seat-back batch"
	)
	# Pixel colour alone cannot reliably distinguish shaded crimson upholstery
	# from the pilot and canopy. The 60% silhouette threshold remains an explicit
	# original-resolution human review item in the evidence manifest.


func _validate_active_lod(expected_lod: int, camera_distance: float) -> void:
	var lod0 := _hero_presentation.get_lod0_root() if _hero_presentation != null else null
	var lod1 := _hero_presentation.get_lod1_root() if _hero_presentation != null else null
	var cockpit := _hero_presentation.get_cockpit_art_root() if _hero_presentation != null else null
	var canopy := _hero_presentation.get_canopy_pivot() if _hero_presentation != null else null
	_check(
		_hero_presentation != null
		and _hero_presentation.get_active_lod() == expected_lod
		and lod0 != null and lod0.visible == (expected_lod == 0)
		and lod1 != null and lod1.visible == (expected_lod == 1)
		and cockpit != null and cockpit.visible == (expected_lod == 0)
		and canopy != null and canopy.visible == (expected_lod == 0),
		"%.1f m camera distance selects atomic whole-ship LOD%d" % [camera_distance, expected_lod]
	)
	var report := _hero_presentation.get_asset_audit_report() if _hero_presentation != null else {}
	_check(
		bool(report.get("valid", false))
		and int(report.get("active_lod", -1)) == expected_lod,
		"LOD%d handoff remains green in the immutable asset audit" % expected_lod
	)


func _validate_engine_depth_contract() -> void:
	var lod0_source := (_asset_manifest.get("collections", {}) as Dictionary).get(
		"LOD0", []
	) as Array
	for side in ["Port", "Starboard"]:
		var all_layers_present := true
		for suffix in REQUIRED_ENGINE_DEPTH_LAYERS:
			all_layers_present = all_layers_present and lod0_source.has(side + suffix)
		_check(
			all_layers_present,
			"%s engine retains housing, collar, nozzle, thermal lip, and core depth layers in pinned source" % side
		)
	var plumes := _hero_presentation.get_engine_plumes() if _hero_presentation != null else []
	var cores := _hero_presentation.get_engine_cores() if _hero_presentation != null else []
	_check(
		plumes.size() == 4 and cores.size() == 2,
		"runtime presentation exposes paired close/far plumes plus paired close engine cores"
	)


func _validate_uv_material_crop_contract() -> void:
	var role_meshes: Dictionary = {}
	if _hero_asset_root != null:
		for candidate in _hero_asset_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			var role := StringName(mesh_instance.get_meta("torrent_material_role", &""))
			if role in MATERIAL_ROLES:
				var existing := role_meshes.get(role, []) as Array
				existing.append(mesh_instance)
				role_meshes[role] = existing
	var ivory_meshes := role_meshes.get(&"WarmIvoryHull", []) as Array
	var graphite_meshes := role_meshes.get(&"GraphiteMachinery", []) as Array
	var uv_contract := not ivory_meshes.is_empty() and not graphite_meshes.is_empty()
	for candidate in ivory_meshes + graphite_meshes:
		uv_contract = uv_contract and _mesh_has_uvs((candidate as MeshInstance3D).mesh)
	var ivory_material := (
		(ivory_meshes[0] as MeshInstance3D).material_override as StandardMaterial3D
		if not ivory_meshes.is_empty() else null
	)
	_check(
		uv_contract,
		"neutral material crop uses live imported UV-bearing ivory and graphite meshes"
	)
	_check(
		ivory_material != null
		and ivory_material.albedo_texture != null
		and ivory_material.albedo_texture.resource_path
			== "res://assets/materials/torrent-hull-albedo-v1.png"
		and ivory_material.normal_enabled
		and ivory_material.normal_texture != null
		and ivory_material.roughness_texture != null
		and not ivory_material.uv1_triplanar,
		"ivory crop retains authored UV albedo, normal, and roughness surface maps"
	)


func _validate_cockpit_acceptance_contract(camera: Camera3D) -> void:
	_cockpit_camera_for_metrics = camera
	var quality := _torrent.get_cockpit_quality_report()
	_check(
		bool(quality.get("valid", false))
		and bool(quality.get("forward_sight_clear", false))
		and int(quality.get("opaque_obstruction_count", -1)) == 0
		and bool(quality.get("instrument_readout_present", false))
		and bool(quality.get("practical_light_present", false)),
		"production cockpit quality audit is green before fixed-camera capture"
	)
	_check(
		_count_imported_cockpit_sight_obstructions(camera) == 0,
		"imported cockpit/canopy leaves the full sampled 20x12-degree sight corridor clear"
	)

	var physical_display := (
		_hero_presentation.get_cockpit_art_root().get_node_or_null("PrimaryDisplay")
		as VisualInstance3D
		if _hero_presentation != null and _hero_presentation.get_cockpit_art_root() != null
		else null
	)
	_check(physical_display != null, "cockpit has one imported physical PrimaryDisplay")
	var display_rect := _project_visual_rect(physical_display, camera) if physical_display != null else Rect2()
	var padded_display := display_rect.grow(10.0)
	_cockpit_display_roi = _rect2_to_bounded_rect2i(padded_display, CAPTURE_RESOLUTION)
	var top_fraction := float(_cockpit_display_roi.position.y) / float(CAPTURE_RESOLUTION.y)
	var height_fraction := float(_cockpit_display_roi.size.y) / float(CAPTURE_RESOLUTION.y)
	_check(
		_cockpit_display_roi.size.x >= 24 and _cockpit_display_roi.size.y >= 16
		and top_fraction >= COCKPIT_INSTRUMENT_MINIMUM_TOP_FRACTION
		and top_fraction <= COCKPIT_INSTRUMENT_MAXIMUM_TOP_FRACTION
		and height_fraction <= COCKPIT_INSTRUMENT_MAXIMUM_HEIGHT_FRACTION
		and _cockpit_display_roi.end.y <= CAPTURE_RESOLUTION.y,
		"physical instrument ROI occupies the required lower 20-35 percent band"
	)

	var labels := _torrent.find_children("*", "Label3D", true, false)
	var every_text_bounded := labels.size() == 1
	for candidate in labels:
		var label := candidate as Label3D
		var label_rect := _project_visual_rect(label, camera)
		every_text_bounded = (
			every_text_bounded
			and label.name == &"FlightDataReadout"
			and label.is_visible_in_tree()
			and padded_display.encloses(label_rect)
		)
	_check(
		every_text_bounded,
		"every visible cockpit text glyph bound stays inside the physical PrimaryDisplay"
	)


func _count_imported_cockpit_sight_obstructions(camera: Camera3D) -> int:
	if camera == null or _hero_presentation == null:
		return 77
	var roots: Array[Node] = [_hero_asset_root]
	var directions := PackedVector2Array()
	for vertical_index in 7:
		var vertical_degrees := -6.0 + float(vertical_index) * 2.0
		for horizontal_index in 11:
			var horizontal_degrees := -10.0 + float(horizontal_index) * 2.0
			directions.append(Vector2(horizontal_degrees, vertical_degrees))
	var blocked := 0
	for angles in directions:
		var local_direction := Vector3(
			tan(deg_to_rad(angles.x)),
			tan(deg_to_rad(angles.y)),
			-1.0
		).normalized()
		var segment_start_distance := maxf(camera.near + 0.002, 0.002)
		var world_start := camera.to_global(local_direction * segment_start_distance)
		var world_end := camera.to_global(local_direction * 10.0)
		var sample_blocked := false
		for root_node in roots:
			if root_node == null:
				continue
			for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := candidate as MeshInstance3D
				if not mesh_instance.is_visible_in_tree() or _mesh_is_translucent(mesh_instance):
					continue
				if _mesh_intersects_world_segment(mesh_instance, world_start, world_end):
					sample_blocked = true
					break
			if sample_blocked:
				break
		if sample_blocked:
			blocked += 1
	return blocked


func _mesh_is_translucent(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null:
		return false
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		material = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
	return material != null and (
		material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		or material.albedo_color.a < 0.95
	)


func _mesh_intersects_world_segment(
	mesh_instance: MeshInstance3D,
	world_start: Vector3,
	world_end: Vector3
	) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null:
		return false
	var triangle_mesh := _triangle_mesh_for(mesh_instance.mesh)
	if triangle_mesh == null:
		return false
	var inverse := mesh_instance.global_transform.affine_inverse()
	var result := triangle_mesh.intersect_segment(inverse * world_start, inverse * world_end)
	return not result.is_empty()


func _mesh_has_uvs(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	for surface_index in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
		if uvs != null and uvs.size() > 0:
			return true
	return false


func _set_lod_review_camera(distance_metres: float, field_of_view: float) -> void:
	var direction_local := Vector3(-0.56, 0.30, -0.77201036).normalized()
	var focus := _ship_point(Vector3(0.0, 1.2, -0.25))
	var position := _torrent.global_position + _torrent.global_basis * direction_local * distance_metres
	_frame_camera(position, focus, field_of_view)
	_check(
		is_equal_approx(_evidence_camera.global_position.distance_to(_torrent.global_position), distance_metres),
		"LOD review camera is exactly %.1f m from the ship origin" % distance_metres
	)


func _set_powered_chase_camera(distance_metres: float, field_of_view: float) -> void:
	var local_offset := (
		Vector3(0.0, 7.0, 24.0)
		if is_equal_approx(distance_metres, 25.0)
		else Vector3(0.0, 14.0, 48.0)
	)
	_frame_camera(
		_ship_point(local_offset),
		_ship_point(Vector3(0.0, 1.1, 0.0)),
		field_of_view
	)
	_check(
		is_equal_approx(_evidence_camera.global_position.distance_to(_torrent.global_position), distance_metres),
		"powered chase review camera is exactly %.1f m from the ship origin" % distance_metres
	)


func _frame_camera(
	world_position: Vector3,
	focus: Vector3,
	field_of_view: float,
	up_vector: Vector3 = Vector3.UP
	) -> void:
	_evidence_camera.global_position = world_position
	_evidence_camera.fov = field_of_view
	_evidence_camera.look_at(focus, up_vector)
	_evidence_camera.current = true


func _ship_point(local_point: Vector3) -> Vector3:
	return _torrent.global_transform * local_point


func _berth_point(local_point: Vector3) -> Vector3:
	return _central_berth.get_dock_transform() * local_point


func _settle_render(frame_count: int = 7) -> void:
	for _index in frame_count:
		await process_frame


func _wait_for_seated(timeout_seconds: float) -> bool:
	return await _wait_until(func() -> bool: return _pilot.is_seated(), timeout_seconds)


## Waits for `predicate` on both the simulation clock and the monotonic clock,
## giving up only once both budgets are spent.
##
## The previous form combined the worst of two clocks: a `SceneTreeTimer`
## deadline counting Godot's smoothed engine delta, guarding a loop that advances
## the physics clock. Software-rendered 2560x1440 Forward+ capture is exactly the
## load under which the engine drops physics steps rather than letting the
## simulation spiral, so the timer expired with the boarding transition only
## part-stepped and the harness failed a pilot who was still climbing in.
##
## `timeout_seconds` is kept as the *nominal* duration and becomes both a budget
## of simulated frames and a wall-clock deadline. The frame budget is added
## alongside the original deadline rather than replacing it, so anything released
## against a monotonic deadline stays bounded on the clock that owns it, and a
## frame budget alone cannot stretch the window over an unbounded run of wall
## clock. Both bounds stay finite, so a genuinely stuck condition still fails.
func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _run_automatic_propulsion_witness() -> void:
	_torrent = TORRENT_SCENE.instantiate() as HeroShip
	_check(_torrent != null, "production Torrent instantiates for automatic propulsion staging")
	if _torrent == null:
		quit(1)
		return
	root.add_child(_torrent)
	_evidence_camera = Camera3D.new()
	root.add_child(_evidence_camera)
	_check(
		await _wake_engine_with_hover(_evidence_camera),
		"accepted hover demand wakes Torrent ONLINE in one physics tick"
	)
	_check(
		await _idle_engine_offline(),
		"neutral demand reaches OFFLINE on the exact production 1.5-second physics clock"
	)
	_release_flight_controls()
	_torrent.set_piloted(false)
	_torrent.queue_free()
	_evidence_camera.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HERO_CELL_AUTOMATIC_PROPULSION_STAGING_OK")
	quit(0 if _failures.is_empty() else 1)


func _wake_engine_with_hover(active_camera: Camera3D) -> bool:
	_release_flight_controls()
	_torrent.set_piloted(true)
	Input.action_press(&"hover")
	await physics_frame
	await process_frame
	var accepted := (
		StringName(_torrent.get_telemetry().get("engine_state", &""))
		== HeroShip.ENGINE_ONLINE
		and _torrent.get_last_ship_command().hover
	)
	if is_instance_valid(active_camera):
		active_camera.current = true
	return accepted


func _idle_engine_offline() -> bool:
	_release_flight_controls()
	# HeroShip's own physics idle clock commits the stop. This loop only provides
	# a finite observation budget; it owns no second timer and cannot stop the
	# engine directly.
	var frame_budget := (
		int(ceil(
			HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS
			* float(Engine.physics_ticks_per_second)
		))
		+ AUTOMATIC_ENGINE_IDLE_SHUTDOWN_GRACE_FRAMES
	)
	for _frame_index in frame_budget:
		if (
			StringName(_torrent.get_telemetry().get("engine_state", &""))
			== HeroShip.ENGINE_OFFLINE
		):
			_evidence_camera.current = true
			return true
		await physics_frame
	_evidence_camera.current = true
	return false


func _release_flight_controls() -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)


func _capture_frame(
	file_name: String,
	semantic_state: StringName,
	markers: Dictionary,
	fixed_camera_group: StringName = &"",
	measure_material_lighting := false
	) -> void:
	_validate_hud_policy()
	var active_camera := root.get_camera_3d()
	_check(active_camera != null, "%s has one active 3D evidence camera" % file_name)
	if active_camera == null:
		return
	if not fixed_camera_group.is_empty():
		_validate_fixed_camera(fixed_camera_group, active_camera, file_name)

	await _settle_render(3)
	var settled_camera := root.get_camera_3d()
	_check(
		settled_camera == active_camera,
		"%s retains the same active camera through settle and readback" % file_name
	)
	if settled_camera != active_camera:
		return
	if not fixed_camera_group.is_empty():
		_validate_fixed_camera(fixed_camera_group, active_camera, file_name + " [readback]")
	await RenderingServer.frame_post_draw
	_check(
		root.get_camera_3d() == active_camera,
		"%s retains the same active camera at frame-post-draw readback" % file_name
	)
	if root.get_camera_3d() != active_camera:
		return
	if not fixed_camera_group.is_empty():
		_validate_fixed_camera(fixed_camera_group, active_camera, file_name + " [post-draw]")
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced an empty viewport image" % file_name)
		return
	var actual_size := Vector2i(image.get_width(), image.get_height())
	_check(actual_size == CAPTURE_RESOLUTION, "%s is exactly 2560x1440" % file_name)
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

	var path := "%s/%s" % [TRANSACTION_DIR, file_name]
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

	var record := {
		"file": file_name,
		"semantic_state": String(semantic_state),
		"sha256": FileAccess.get_sha256(path),
		"png_bytes": byte_count,
		"resolution": [actual_size.x, actual_size.y],
		"luminance_range": snappedf(luminance_range, 0.000001),
		"luminance_variance": snappedf(variance, 0.000001),
		"camera_name": String(active_camera.name),
		"camera_instance_id": active_camera.get_instance_id(),
		"camera_transform": _transform_dictionary(active_camera.global_transform),
		"camera_fov": active_camera.fov,
		"fixed_camera_group": String(fixed_camera_group),
		"ship_transform": _transform_dictionary(_torrent.global_transform),
		"engine_state": str(_torrent.get_telemetry().get("engine_state", "")),
		"damage_status": str(_torrent.get_telemetry().get("damage_status", "")),
		"active_lod": _hero_presentation.get_active_lod() if _hero_presentation != null else -1,
		"markers": markers.duplicate(true),
	}
	if semantic_state in [&"cockpit_offline", &"cockpit_online", &"cockpit_critical"]:
		record["physical_display_roi_pixels"] = _rect2i_dictionary(_cockpit_display_roi)
	if measure_material_lighting:
		_lighting_metrics = _measure_ship_mask_lighting(image, active_camera)
		record["ship_mask_lighting"] = _lighting_metrics.duplicate(true)
		_validate_ship_mask_lighting(_lighting_metrics)

	_semantic_frames.append(record)
	_captured_images[file_name] = image
	print(
		"HERO_CELL_CAPTURED: %s state=%s camera=%s lod=%d %dx%d %d bytes"
		% [
			ProjectSettings.globalize_path(path),
			semantic_state,
			active_camera.name,
			int(record.active_lod),
			actual_size.x,
			actual_size.y,
			byte_count,
		]
	)


func _validate_fixed_camera(group: StringName, camera: Camera3D, file_name: String) -> void:
	var current := {
		"camera_instance_id": camera.get_instance_id(),
		"camera_transform": camera.global_transform,
		"camera_fov": camera.fov,
		"camera_near": camera.near,
		"camera_far": camera.far,
		"camera_projection": camera.projection,
		"camera_keep_aspect": camera.keep_aspect,
		"camera_h_offset": camera.h_offset,
		"camera_v_offset": camera.v_offset,
		"camera_frustum_offset": camera.frustum_offset,
		"camera_cull_mask": camera.cull_mask,
		"ship_transform": _torrent.global_transform,
		"world_transform": _world.global_transform,
	}
	if not _fixed_camera_contracts.has(group):
		_fixed_camera_contracts[group] = current
		_check(true, "%s establishes immutable %s camera/world contract" % [file_name, group])
		return
	var expected := _fixed_camera_contracts[group] as Dictionary
	_check(
		int(current.camera_instance_id) == int(expected.camera_instance_id)
		and (current.camera_transform as Transform3D).is_equal_approx(
			expected.camera_transform as Transform3D
		)
		and is_equal_approx(float(current.camera_fov), float(expected.camera_fov))
		and is_equal_approx(float(current.camera_near), float(expected.camera_near))
		and is_equal_approx(float(current.camera_far), float(expected.camera_far))
		and int(current.camera_projection) == int(expected.camera_projection)
		and int(current.camera_keep_aspect) == int(expected.camera_keep_aspect)
		and is_equal_approx(float(current.camera_h_offset), float(expected.camera_h_offset))
		and is_equal_approx(float(current.camera_v_offset), float(expected.camera_v_offset))
		and (current.camera_frustum_offset as Vector2).is_equal_approx(
			expected.camera_frustum_offset as Vector2
		)
		and int(current.camera_cull_mask) == int(expected.camera_cull_mask)
		and (current.ship_transform as Transform3D).is_equal_approx(
			expected.ship_transform as Transform3D
		)
		and (current.world_transform as Transform3D).is_equal_approx(
			expected.world_transform as Transform3D
		),
		"%s exactly retains the %s camera, projection, ship, and world pose" % [file_name, group]
	)


func _sample_luminance_statistics(image: Image) -> Dictionary:
	var values: Array[float] = []
	for sample_y in 45:
		var y := roundi(float(sample_y) / 44.0 * float(image.get_height() - 1))
		for sample_x in 80:
			var x := roundi(float(sample_x) / 79.0 * float(image.get_width() - 1))
			values.append(image.get_pixel(x, y).get_luminance())
	if values.is_empty():
		return {"range": 0.0, "mean": 0.0, "variance": 0.0}
	var darkest := 1.0
	var brightest := 0.0
	var total := 0.0
	var total_squared := 0.0
	for luminance in values:
		darkest = minf(darkest, luminance)
		brightest = maxf(brightest, luminance)
		total += luminance
		total_squared += luminance * luminance
	var mean := total / float(values.size())
	return {
		"range": brightest - darkest,
		"mean": mean,
		"variance": maxf(0.0, total_squared / float(values.size()) - mean * mean),
	}


func _validate_capture_set() -> void:
	_check(_semantic_frames.size() == CAPTURE_FILES.size(), "every declared PNG has one semantic evidence record")
	var hashes := PackedStringArray()
	for frame_index in CAPTURE_FILES.size():
		var file_name: String = CAPTURE_FILES[frame_index]
		_check(_captured_images.has(file_name), "required hero-cell frame exists: %s" % file_name)
		_check(FileAccess.file_exists("%s/%s" % [TRANSACTION_DIR, file_name]), "required staged PNG is on disk: %s" % file_name)
		if frame_index < _semantic_frames.size():
			var record := _semantic_frames[frame_index]
			_check(
				str(record.get("file", "")) == file_name
				and str(record.get("semantic_state", "")) == CAPTURE_STATES[frame_index],
				"frame %02d retains its exact file/state semantic inventory" % (frame_index + 1)
			)
		if _captured_images.has(file_name):
			hashes.append(FileAccess.get_sha256("%s/%s" % [TRANSACTION_DIR, file_name]))
	var unique_hashes := {}
	for hash_value in hashes:
		unique_hashes[hash_value] = true
	_check(unique_hashes.size() == CAPTURE_FILES.size(), "all 18 hero-cell PNGs have unique full-file hashes")

	_validate_distinct_pair(CAPTURE_FILES[1], CAPTURE_FILES[2], "front three-quarter versus profile")
	_validate_distinct_pair(CAPTURE_FILES[2], CAPTURE_FILES[3], "profile versus true dorsal")
	_validate_distinct_pair(CAPTURE_FILES[8], CAPTURE_FILES[9], "LOD0 near versus LOD1 far")
	_validate_distinct_pair(CAPTURE_FILES[10], CAPTURE_FILES[11], "fixed aft engines offline versus online")
	_validate_distinct_pair(CAPTURE_FILES[12], CAPTURE_FILES[13], "powered chase 25 m versus 50 m")
	_validate_cockpit_roi_pairs()


func _validate_distinct_pair(first_name: String, second_name: String, label: String) -> void:
	if not _captured_images.has(first_name) or not _captured_images.has(second_name):
		return
	var comparison := _compare_region(
		_captured_images[first_name] as Image,
		_captured_images[second_name] as Image,
		Rect2i(Vector2i.ZERO, CAPTURE_RESOLUTION),
		false
	)
	_pair_metrics[label] = comparison
	_check(
		float(comparison.get("mean_difference", 0.0)) >= MINIMUM_DISTINCT_MEAN_DIFFERENCE
		and float(comparison.get("changed_fraction", 0.0)) >= MINIMUM_DISTINCT_CHANGED_FRACTION,
		"%s are visibly distinct (mean %.6f, changed %.4f)"
		% [
			label,
			float(comparison.get("mean_difference", 0.0)),
			float(comparison.get("changed_fraction", 0.0)),
		]
	)


func _validate_cockpit_roi_pairs() -> void:
	if _cockpit_display_roi.size.x <= 0 or _cockpit_display_roi.size.y <= 0:
		_fail("physical cockpit display ROI was not established")
		return
	var offline := _captured_images.get(CAPTURE_FILES[15]) as Image
	var online := _captured_images.get(CAPTURE_FILES[16]) as Image
	var critical := _captured_images.get(CAPTURE_FILES[17]) as Image
	if offline == null or online == null or critical == null:
		return
	var offline_online_roi := _compare_region(offline, online, _cockpit_display_roi, false)
	var online_critical_roi := _compare_region(online, critical, _cockpit_display_roi, false)
	var offline_online_raw_outside := _compare_region(offline, online, _cockpit_display_roi, true)
	var online_critical_raw_outside := _compare_region(online, critical, _cockpit_display_roi, true)
	var offline_online_outside := _compare_exterior_world(offline, online)
	# The gated ONLINE/CRITICAL exterior comparison uses the deterministic half of
	# the critical state. See `_capture_cockpit_critical_exterior_control` for why
	# the live transient damage emitters cannot be measured by an immutability
	# control. The fully live number is still measured, and recorded below.
	var online_critical_live_outside := _compare_exterior_world(online, critical)
	_check(
		_cockpit_critical_exterior_control != null,
		"fixed cockpit ONLINE/CRITICAL exterior control frame is available"
	)
	var online_critical_outside := (
		_compare_exterior_world(online, _cockpit_critical_exterior_control)
		if _cockpit_critical_exterior_control != null
		else online_critical_live_outside
	)
	online_critical_outside["comparison"] = (
		"CRITICAL with transient damage emitters quiesced: [%s]"
		% ", ".join(_quiesced_damage_emitters)
	)
	online_critical_live_outside["comparison"] = (
		"CRITICAL with every live transient damage emitter running; recorded, not gated,"
		+ " because pulsing damage illumination and stochastic particles are neither"
		+ " the world nor the pose this control exists to police"
	)
	_pair_metrics["cockpit_online_critical_live_damage_exterior_world_non_gated"] = (
		online_critical_live_outside
	)
	print(
		(
			"HERO_CELL_DIAGNOSTIC: ONLINE/CRITICAL exterior — live damage presentation %.4f"
			+ " (non-gated), transient emitters quiesced %.4f (gated at %.4f)"
		)
		% [
			float(online_critical_live_outside.get("changed_fraction", 0.0)),
			float(online_critical_outside.get("changed_fraction", 0.0)),
			COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION,
		]
	)
	_pair_metrics["cockpit_offline_online_roi"] = offline_online_roi
	_pair_metrics["cockpit_online_critical_roi"] = online_critical_roi
	_pair_metrics["cockpit_offline_online_raw_outside_display_roi_non_gated"] = offline_online_raw_outside
	_pair_metrics["cockpit_online_critical_raw_outside_display_roi_non_gated"] = online_critical_raw_outside
	_pair_metrics["cockpit_offline_online_exterior_world"] = offline_online_outside
	_pair_metrics["cockpit_online_critical_exterior_world"] = online_critical_outside
	_check(
		int(offline_online_roi.get("sample_count", 0)) >= COCKPIT_DISPLAY_ROI_MINIMUM_SAMPLES
		and int(online_critical_roi.get("sample_count", 0)) >= COCKPIT_DISPLAY_ROI_MINIMUM_SAMPLES,
		"fixed cockpit physical display comparisons each retain at least %d grid samples"
		% COCKPIT_DISPLAY_ROI_MINIMUM_SAMPLES
	)
	_check(
		float(offline_online_roi.get("changed_fraction", 0.0))
		>= COCKPIT_OFFLINE_ONLINE_MINIMUM_CHANGED_FRACTION,
		"fixed cockpit OFFLINE/ONLINE physical display ROI changes at least 3%% (%.3f)"
		% float(offline_online_roi.get("changed_fraction", 0.0))
	)
	_check(
		float(online_critical_roi.get("changed_fraction", 0.0))
		>= COCKPIT_ONLINE_CRITICAL_MINIMUM_CHANGED_FRACTION,
		"fixed cockpit ONLINE/CRITICAL physical display ROI changes at least 5%% (%.3f)"
		% float(online_critical_roi.get("changed_fraction", 0.0))
	)
	_check(
		float(offline_online_outside.get("changed_fraction", 1.0))
		<= COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION,
		"fixed cockpit OFFLINE/ONLINE triangle-unoccluded exterior remains within 0.5%% change (%.4f)"
		% float(offline_online_outside.get("changed_fraction", 1.0))
	)
	_check(
		float(online_critical_outside.get("changed_fraction", 1.0))
		<= COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION,
		"fixed cockpit ONLINE/CRITICAL triangle-unoccluded exterior, transient damage emitters quiesced, remains within 0.5%% change (%.4f)"
		% float(online_critical_outside.get("changed_fraction", 1.0))
	)


func _compare_region(first: Image, second: Image, roi: Rect2i, invert_roi: bool) -> Dictionary:
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for sample_y in 144:
		var y := roundi(float(sample_y) / 143.0 * float(first.get_height() - 1))
		for sample_x in 256:
			var x := roundi(float(sample_x) / 255.0 * float(first.get_width() - 1))
			var inside := roi.has_point(Vector2i(x, y))
			if inside == invert_roi:
				continue
			var first_pixel := first.get_pixel(x, y)
			var second_pixel := second.get_pixel(x, y)
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
		"sample_count": sample_count,
		"mean_difference": total_difference / float(maxi(sample_count, 1)),
		"changed_fraction": float(changed_pixels) / float(maxi(sample_count, 1)),
		"pixel_change_threshold": PIXEL_CHANGE_THRESHOLD,
		"roi": _rect2i_dictionary(roi),
		"outside_roi": invert_roi,
	}


## Reads one extra frame off the live viewport without staging, hashing or
## publishing it. Diagnostic comparisons need a second image of a state that is
## deliberately *not* part of the published 18-frame roster.
func _read_diagnostic_image() -> Image:
	await _settle_render(COCKPIT_DIFFERENTIAL_SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return image


## Measures the renderer's own frame-to-frame reproducibility over the
## exterior/world mask, by comparing two readbacks of a single unchanged state.
##
## `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION` claims the exterior did not
## change, which is only a claim about the scene if the renderer can reproduce an
## identical scene well below it. TAA is enabled on this viewport
## (`_configure_native_capture`), so this floor is not zero, and on a software
## rasteriser it has been observed within a factor of two of the gate. Printing
## it every run is what lets a reader tell a marginal exterior number apart from
## renderer noise instead of guessing. It is recorded, never gated: the harness
## does not get to pass by declaring its own noise acceptable.
func _diagnose_exterior_noise_floor() -> void:
	var online := _captured_images.get(CAPTURE_FILES[16]) as Image
	if online == null:
		return
	var repeat_image := await _read_diagnostic_image()
	if repeat_image == null:
		return
	var floor_metrics := _compare_exterior_world(online, repeat_image)
	floor_metrics["diagnostic"] = "renderer frame-to-frame reproducibility, identical unchanged ONLINE state"
	floor_metrics["settle_frames"] = COCKPIT_DIFFERENTIAL_SETTLE_FRAMES
	_pair_metrics["cockpit_exterior_world_renderer_noise_floor_non_gated"] = floor_metrics
	print(
		"HERO_CELL_DIAGNOSTIC: exterior renderer noise floor (ONLINE vs ONLINE repeat,"
		+ " no state change, %d settle frames) changed_fraction=%.4f mean_difference=%.6f gate=%.4f"
		% [
			COCKPIT_DIFFERENTIAL_SETTLE_FRAMES,
			float(floor_metrics.get("changed_fraction", 0.0)),
			float(floor_metrics.get("mean_difference", 0.0)),
			COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION,
		]
	)


## Reads the deterministic half of the CRITICAL state, for the exterior control
## comparison only.
##
## The exterior control asserts one thing: that the fixed cockpit camera, the
## craft pose and the frozen world are identical between the two frames, so that
## the physical-display ROI change is attributable to the readout and not to the
## whole scene having moved. `HeroDamagePresentation` also puts two *transient*
## emitters into the critical state — `DamageSparks`/`EngineFailureSparks`/
## `EngineSmoke` (world-space `CPUParticles3D`, `randomness` 0.58-0.72) and
## `DamageWarningLight`/`EngineFailureLight`, whose energies are
## `sin(elapsed * 13)` and `sin(elapsed * 29) + sin(elapsed * 61)` of accumulated
## presentation time. Neither is the world and neither is the pose; both land on
## exterior/world pixels through the glazing, and the light phase at readback is
## a function of frame timing, so the measurement varied 0.05-0.45 across runs of
## identical input. No threshold fits that, on this box or on a real GPU.
##
## This is the same carve-out the raw outside-ROI metric already documents —
## "live warning/practical lights intentionally change opaque cockpit surfaces" —
## carried the rest of the way, because those lights do not stop at the cockpit
## surfaces. The published `18_cockpit_critical_fixed.png` stays fully live and
## is not touched; only the control comparison is taken against the quiesced
## state, and the live exterior number is still measured and recorded, non-gated,
## so nothing is hidden.
func _capture_cockpit_critical_exterior_control() -> void:
	var presentation := _torrent.get_damage_presentation()
	_check(
		presentation != null,
		"fixed cockpit critical state exposes the production HeroDamagePresentation"
	)
	if presentation == null:
		return
	var transient_emitters: Array[Node] = []
	transient_emitters.append_array(presentation.find_children("*", "CPUParticles3D", true, false))
	transient_emitters.append_array(presentation.find_children("*", "Light3D", true, false))
	_check(
		not transient_emitters.is_empty(),
		"fixed cockpit critical state exposes its transient damage emitters for the exterior control"
	)
	var emitter_names := PackedStringArray()
	var restore_visibility := {}
	for node in transient_emitters:
		var emitter := node as Node3D
		if emitter == null:
			continue
		emitter_names.append(String(emitter.name))
		restore_visibility[emitter.get_instance_id()] = emitter.visible
		emitter.visible = false
	_quiesced_damage_emitters = emitter_names
	await _settle_render(COCKPIT_DIFFERENTIAL_SETTLE_FRAMES)
	_validate_fixed_camera(
		&"cockpit_fixed",
		_cockpit_camera_for_metrics,
		"cockpit critical exterior control"
	)
	_cockpit_critical_exterior_control = await _read_diagnostic_image()
	_check(
		_cockpit_critical_exterior_control != null,
		"fixed cockpit critical exterior control frame reads back"
	)
	var control_telemetry := _torrent.get_telemetry()
	_check(
		str(control_telemetry.get("damage_status", "")) == "critical"
		and float(control_telemetry.get("hull", 100.0)) <= _torrent.maximum_hull * 0.3,
		"fixed cockpit exterior control still holds the live critical hull state"
	)
	for node in transient_emitters:
		var emitter := node as Node3D
		if emitter == null:
			continue
		emitter.visible = bool(restore_visibility.get(emitter.get_instance_id(), true))
	await _settle_render(4)
	print(
		(
			"HERO_CELL_DIAGNOSTIC: cockpit exterior control quiesces transient damage"
			+ " emitters [%s]; the published critical frame remains fully live"
		)
		% ", ".join(emitter_names)
	)


func _compare_exterior_world(first: Image, second: Image) -> Dictionary:
	var camera := _cockpit_camera_for_metrics
	var mesh_records := _cockpit_occluder_mesh_records()
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	if camera == null or not is_instance_valid(camera):
		return {
			"method": "CPU TriangleMesh ray rejection of visible opaque Torrent meshes",
			"sample_count": 0,
			"mean_difference": 1.0,
			"changed_fraction": 1.0,
			"pixel_change_threshold": PIXEL_CHANGE_THRESHOLD,
			"outside_roi": true,
			"boundary": "no valid fixed cockpit camera",
		}
	for sample_y in 144:
		var y := roundi(float(sample_y) / 143.0 * float(first.get_height() - 1))
		for sample_x in 256:
			var x := roundi(float(sample_x) / 255.0 * float(first.get_width() - 1))
			# Retain only rays that do not intersect any visible opaque craft
			# triangle. This measures the exterior/world pixels actually visible
			# through transparent glazing and the fixed cockpit sight corridor without misclassifying the
			# production critical-state warning illumination on cockpit surfaces.
			if not _nearest_ship_mesh_hit(camera, Vector2(x, y), mesh_records).is_empty():
				continue
			var first_pixel := first.get_pixel(x, y)
			var second_pixel := second.get_pixel(x, y)
			var difference := (
				absf(first_pixel.r - second_pixel.r)
				+ absf(first_pixel.g - second_pixel.g)
				+ absf(first_pixel.b - second_pixel.b)
			) / 3.0
			total_difference += difference
			if difference >= PIXEL_CHANGE_THRESHOLD:
				changed_pixels += 1
			sample_count += 1
	_check(
		sample_count >= COCKPIT_EXTERIOR_MINIMUM_SAMPLES,
		"fixed cockpit exterior comparison retains at least %d triangle-unoccluded world samples (%d)"
		% [COCKPIT_EXTERIOR_MINIMUM_SAMPLES, sample_count]
	)
	return {
		"method": "CPU TriangleMesh ray rejection of visible opaque Torrent meshes",
		"grid": [256, 144],
		"sample_count": sample_count,
		"minimum_sample_count": COCKPIT_EXTERIOR_MINIMUM_SAMPLES,
		"mean_difference": total_difference / float(maxi(sample_count, 1)),
		"changed_fraction": float(changed_pixels) / float(maxi(sample_count, 1)),
		"pixel_change_threshold": PIXEL_CHANGE_THRESHOLD,
		"outside_roi": true,
		"boundary": "unoccluded exterior/world through transparent glazing; visible opaque craft/canopy-frame/cockpit/display triangles are excluded; deforming pilot skin is not triangle-classified",
	}


func _measure_ship_mask_lighting(image: Image, camera: Camera3D) -> Dictionary:
	var mesh_records := _ship_mesh_intersection_records()
	var ship_values: Array[float] = []
	var ivory_values: Array[float] = []
	var graphite_values: Array[float] = []
	var background_values: Array[float] = []
	var clipped_count := 0
	for sample_y in SHIP_MASK_GRID.y:
		var y := roundi(float(sample_y) / float(SHIP_MASK_GRID.y - 1) * float(image.get_height() - 1))
		for sample_x in SHIP_MASK_GRID.x:
			var x := roundi(float(sample_x) / float(SHIP_MASK_GRID.x - 1) * float(image.get_width() - 1))
			var screen_point := Vector2(x, y)
			var hit := _nearest_ship_mesh_hit(camera, screen_point, mesh_records)
			var luminance := image.get_pixel(x, y).get_luminance()
			if hit.is_empty():
				background_values.append(luminance)
				continue
			ship_values.append(luminance)
			if luminance <= 0.01 or luminance >= 0.99:
				clipped_count += 1
			var role := StringName(hit.get("role", &""))
			if role in [&"WarmIvoryHull", &"IvorySecondary"]:
				ivory_values.append(luminance)
			elif role == &"GraphiteMachinery":
				graphite_values.append(luminance)
	var ship_p5 := _percentile(ship_values, 0.05)
	var ship_p95 := _percentile(ship_values, 0.95)
	var ivory_median := _percentile(ivory_values, 0.5)
	var graphite_median := _percentile(graphite_values, 0.5)
	var background_median := _percentile(background_values, 0.5)
	return {
		"method": "CPU TriangleMesh ray mask over live visible opaque production ship meshes",
		"grid": [SHIP_MASK_GRID.x, SHIP_MASK_GRID.y],
		"ship_sample_count": ship_values.size(),
		"ivory_sample_count": ivory_values.size(),
		"graphite_sample_count": graphite_values.size(),
		"background_sample_count": background_values.size(),
		"ship_luminance_p5": snappedf(ship_p5, 0.000001),
		"ship_luminance_p95": snappedf(ship_p95, 0.000001),
		"ivory_luminance_median": snappedf(ivory_median, 0.000001),
		"graphite_luminance_median": snappedf(graphite_median, 0.000001),
		"background_luminance_median": snappedf(background_median, 0.000001),
		"ivory_graphite_delta": snappedf(absf(ivory_median - graphite_median), 0.000001),
		"graphite_background_delta_diagnostic": snappedf(absf(graphite_median - background_median), 0.000001),
		"clipped_fraction": snappedf(float(clipped_count) / float(maxi(ship_values.size(), 1)), 0.000001),
		"clipping_definition": "luminance <= 0.01 or >= 0.99",
		"occlusion_boundary": "crop is composed unobstructed; mask rays classify opaque ship geometry, exclude transparent glazing, and do not solve unrelated-world occlusion",
	}


func _validate_ship_mask_lighting(metrics: Dictionary) -> void:
	_check(
		int(metrics.get("ship_sample_count", 0)) >= SHIP_MASK_MINIMUM_SAMPLES
		and int(metrics.get("ivory_sample_count", 0)) >= MATERIAL_MASK_MINIMUM_SAMPLES
		and int(metrics.get("graphite_sample_count", 0)) >= MATERIAL_MASK_MINIMUM_SAMPLES,
		"neutral crop produces substantive triangle-masked ship, ivory, and graphite samples"
	)
	_check(
		float(metrics.get("ship_luminance_p5", 0.0)) > SHIP_LUMINANCE_P5_MINIMUM,
		"ship-mask luminance P5 is above 0.04 (%.4f)" % float(metrics.get("ship_luminance_p5", 0.0))
	)
	_check(
		float(metrics.get("ship_luminance_p95", 1.0)) < SHIP_LUMINANCE_P95_MAXIMUM,
		"ship-mask luminance P95 is below 0.95 (%.4f)" % float(metrics.get("ship_luminance_p95", 1.0))
	)
	var ivory_median := float(metrics.get("ivory_luminance_median", 0.0))
	_check(
		ivory_median >= IVORY_LUMINANCE_MEDIAN_MINIMUM
		and ivory_median <= IVORY_LUMINANCE_MEDIAN_MAXIMUM,
		"ivory median luminance stays in 0.35-0.72 (%.4f)" % ivory_median
	)
	_check(
		float(metrics.get("ivory_graphite_delta", 0.0)) >= IVORY_GRAPHITE_MINIMUM_DELTA,
		"ivory/graphite median delta is at least 0.08 (%.4f)"
		% float(metrics.get("ivory_graphite_delta", 0.0))
	)
	_check(
		float(metrics.get("clipped_fraction", 1.0)) < SHIP_MAXIMUM_CLIPPED_FRACTION,
		"ship-mask clipped luminance remains below 0.5%% (%.4f)"
		% float(metrics.get("clipped_fraction", 1.0))
	)


func _ship_mesh_intersection_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if _hero_asset_root == null:
		return records
	for candidate in _hero_asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if (
			not mesh_instance.is_visible_in_tree()
			or mesh_instance.mesh == null
			or _mesh_is_translucent(mesh_instance)
		):
			continue
		var triangle_mesh := _triangle_mesh_for(mesh_instance.mesh)
		if triangle_mesh == null:
			continue
		records.append({
			"node": mesh_instance,
			"triangle_mesh": triangle_mesh,
			"role": StringName(mesh_instance.get_meta("torrent_material_role", &"")),
		})
	return records


func _cockpit_occluder_mesh_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var roots: Array[Node] = [_torrent]
	var seen_instances := {}
	for source_root in roots:
		if source_root == null:
			continue
		for candidate in source_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if (
				mesh_instance == null
				or not mesh_instance.is_visible_in_tree()
				or mesh_instance.mesh == null
				or _mesh_is_translucent(mesh_instance)
				or seen_instances.has(mesh_instance.get_instance_id())
			):
				continue
			var triangle_mesh := _triangle_mesh_for(mesh_instance.mesh)
			if triangle_mesh == null:
				continue
			seen_instances[mesh_instance.get_instance_id()] = true
			records.append({
				"node": mesh_instance,
				"triangle_mesh": triangle_mesh,
				"role": StringName(mesh_instance.get_meta("torrent_material_role", &"")),
			})
	return records


func _triangle_mesh_for(mesh: Mesh) -> TriangleMesh:
	if mesh == null:
		return null
	var mesh_id := mesh.get_instance_id()
	var triangle_mesh := _triangle_mesh_cache.get(mesh_id) as TriangleMesh
	if triangle_mesh == null:
		triangle_mesh = mesh.generate_triangle_mesh()
		if triangle_mesh != null:
			_triangle_mesh_cache[mesh_id] = triangle_mesh
	return triangle_mesh


func _nearest_ship_mesh_hit(
	camera: Camera3D,
	screen_point: Vector2,
	mesh_records: Array[Dictionary]
	) -> Dictionary:
	var world_origin := camera.project_ray_origin(screen_point)
	var world_direction := camera.project_ray_normal(screen_point).normalized()
	var nearest_distance := INF
	var nearest := {}
	for record in mesh_records:
		var mesh_instance := record.get("node") as MeshInstance3D
		var triangle_mesh := record.get("triangle_mesh") as TriangleMesh
		if mesh_instance == null or triangle_mesh == null:
			continue
		var inverse := mesh_instance.global_transform.affine_inverse()
		var local_origin := inverse * world_origin
		var local_direction := inverse.basis * world_direction
		var result := triangle_mesh.intersect_ray(local_origin, local_direction)
		if result.is_empty():
			continue
		var local_position: Vector3 = result.get("position", Vector3.INF)
		if not local_position.is_finite():
			continue
		var world_position := mesh_instance.global_transform * local_position
		var distance := world_origin.distance_to(world_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = {
				"role": record.get("role", &""),
				"distance": distance,
				"node_path": str(_hero_asset_root.get_path_to(mesh_instance)),
			}
	return nearest


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(roundi(clampf(fraction, 0.0, 1.0) * float(sorted.size() - 1)), 0, sorted.size() - 1)
	return float(sorted[index])


func _enable_neutral_review_lighting() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for candidate in _stage.find_children("*", "Light3D", true, false):
		var light := candidate as Light3D
		snapshot.append({"node": light, "visible": light.visible})
		light.visible = false

	var key := DirectionalLight3D.new()
	key.name = "CaptureOnlyNeutralD65Key"
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.light_color = Color("f4f7ff")
	key.light_energy = 1.35
	key.shadow_enabled = true
	_stage.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "CaptureOnlyNeutralD65Fill"
	fill.rotation_degrees = Vector3(-18.0, 144.0, 0.0)
	fill.light_color = Color("dce8f4")
	fill.light_energy = 0.86
	fill.shadow_enabled = false
	_stage.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.name = "CaptureOnlyNeutralD65Rim"
	rim.rotation_degrees = Vector3(-12.0, 62.0, 0.0)
	rim.light_color = Color("fff8ed")
	rim.light_energy = 0.42
	rim.shadow_enabled = false
	_stage.add_child(rim)
	return snapshot


func _restore_production_lighting(snapshot: Array[Dictionary]) -> void:
	for record in snapshot:
		var light := record.get("node") as Light3D
		if light != null and is_instance_valid(light):
			light.visible = bool(record.get("visible", true))
	for child_name in [
		&"CaptureOnlyNeutralD65Key",
		&"CaptureOnlyNeutralD65Fill",
		&"CaptureOnlyNeutralD65Rim",
	]:
		var capture_light := _stage.get_node_or_null(NodePath(String(child_name)))
		if capture_light != null:
			capture_light.queue_free()


func _project_visual_rect(visual: VisualInstance3D, camera: Camera3D) -> Rect2:
	if visual == null or camera == null:
		return Rect2()
	var aabb := visual.get_aabb().abs()
	var has_point := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for endpoint_index in 8:
		var world_point := visual.global_transform * aabb.get_endpoint(endpoint_index)
		if camera.is_position_behind(world_point):
			continue
		var screen_point := camera.unproject_position(world_point)
		if not has_point:
			minimum = screen_point
			maximum = screen_point
			has_point = true
		else:
			minimum = minimum.min(screen_point)
			maximum = maximum.max(screen_point)
	return Rect2(minimum, maximum - minimum) if has_point else Rect2()


func _rect2_to_bounded_rect2i(rect: Rect2, bounds: Vector2i) -> Rect2i:
	var left := clampi(floori(rect.position.x), 0, bounds.x)
	var top := clampi(floori(rect.position.y), 0, bounds.y)
	var right := clampi(ceili(rect.end.x), left, bounds.x)
	var bottom := clampi(ceili(rect.end.y), top, bounds.y)
	return Rect2i(left, top, right - left, bottom - top)


func _resolve_contract_node(node_contract: Dictionary, key: String) -> Node:
	if not node_contract.has(key):
		return null
	var value: Variant = node_contract[key]
	if value is Node:
		var direct := value as Node
		return direct if direct == _torrent or _torrent.is_ancestor_of(direct) else null
	if value is NodePath or value is String or value is StringName:
		var path := NodePath(str(value))
		if not path.is_empty():
			return _torrent.get_node_or_null(path)
	return null


func _string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value as PackedStringArray
	var result := PackedStringArray()
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


func _contains_tokens(values: PackedStringArray, tokens: Array) -> bool:
	for value: String in values:
		var normalized := value.to_lower().replace("_", " ").replace("-", " ")
		var matches := true
		for token: String in tokens:
			if token.to_lower() not in normalized:
				matches = false
				break
		if matches:
			return true
	return false


func _snapshot_source_files(paths: PackedStringArray = PackedStringArray()) -> Dictionary:
	var snapshot := {}
	var snapshot_paths := paths if not paths.is_empty() else _source_paths
	for path in snapshot_paths:
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
			elif (
				not entry.ends_with("~")
				and not entry.ends_with(".pyc")
				and entry != ".DS_Store"
			):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _source_snapshot_hash(
	snapshot: Dictionary,
	paths: PackedStringArray = PackedStringArray()
	) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var snapshot_paths := paths if not paths.is_empty() else _source_paths
	for path in snapshot_paths:
		context.update(("%s  %s\n" % [snapshot.get(path, ""), path]).to_utf8_buffer())
	return context.finish().hex_encode()


func _validate_source_frozen() -> void:
	var final_paths := _collect_source_paths()
	var final_snapshot := _snapshot_source_files(final_paths)
	var final_aggregate := _source_snapshot_hash(final_snapshot, final_paths)
	_source_frozen_validated = (
		final_paths == _source_paths
		and final_snapshot == _source_snapshot
		and final_aggregate == _source_aggregate_sha256
	)
	_check(
		_source_frozen_validated,
		"recursive source roster and every declared production byte remain identical through the capture"
	)


func _write_source_manifest() -> void:
	var temporary_path := STAGED_SOURCE_MANIFEST_PATH + ".tmp"
	_remove_file_if_present(temporary_path, "stale staged source-manifest temporary clears")
	_remove_file_if_present(STAGED_SOURCE_MANIFEST_PATH, "stale staged source manifest clears")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	_check(file != null, "staged source SHA-256 manifest opens for writing")
	if file == null:
		return
	for path in _source_paths:
		file.store_line("%s  %s" % [_source_snapshot.get(path, ""), path])
	file.flush()
	var write_error := file.get_error()
	file.close()
	_check(write_error == OK, "staged source SHA-256 manifest flushes without error")
	if write_error != OK:
		return
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(STAGED_SOURCE_MANIFEST_PATH)
	)
	_check(rename_error == OK, "staged source SHA-256 manifest commits atomically")
	_check(
		FileAccess.file_exists(STAGED_SOURCE_MANIFEST_PATH),
		"frozen staged source SHA-256 manifest is present"
	)
	print(
		"HERO_CELL_STAGED_SOURCE_MANIFEST: aggregate=%s path=%s"
		% [_source_aggregate_sha256, ProjectSettings.globalize_path(STAGED_SOURCE_MANIFEST_PATH)]
	)


func _write_evidence_manifest() -> void:
	var fixed_contract_records := {}
	for group: StringName in _fixed_camera_contracts:
		var contract := _fixed_camera_contracts[group] as Dictionary
		fixed_contract_records[String(group)] = {
			"camera_instance_id": contract.get("camera_instance_id", 0),
			"camera_transform": _transform_dictionary(contract.get("camera_transform", Transform3D.IDENTITY)),
			"camera_fov": contract.get("camera_fov", 0.0),
				"camera_near": contract.get("camera_near", 0.0),
				"camera_far": contract.get("camera_far", 0.0),
				"camera_projection": contract.get("camera_projection", Camera3D.PROJECTION_PERSPECTIVE),
				"camera_keep_aspect": contract.get("camera_keep_aspect", Camera3D.KEEP_HEIGHT),
				"camera_h_offset": contract.get("camera_h_offset", 0.0),
				"camera_v_offset": contract.get("camera_v_offset", 0.0),
				"camera_frustum_offset": _vector2_array(contract.get("camera_frustum_offset", Vector2.ZERO)),
				"camera_cull_mask": contract.get("camera_cull_mask", 0),
			"ship_transform": _transform_dictionary(contract.get("ship_transform", Transform3D.IDENTITY)),
			"world_transform": _transform_dictionary(contract.get("world_transform", Transform3D.IDENTITY)),
		}
	var manifest := {
		"schema": "hero_cell_rendered_evidence_v5",
		"frame_count": CAPTURE_FILES.size(),
		"capture_resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"renderer": String(RenderingServer.get_current_rendering_method()),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"hud_policy": "HUD_OFF_NO_CANVASLAYER_NO_RETICLE_NO_TOAST",
		"production_scenes": [
			"res://scenes/world/shipyard_world.tscn",
			"res://scenes/ships/torrent_interceptor.tscn",
			"res://scenes/player/player.tscn",
		],
			"source_manifest": SOURCE_MANIFEST_PATH,
			"source_manifest_sha256": FileAccess.get_sha256(STAGED_SOURCE_MANIFEST_PATH),
			"source_aggregate_sha256": _source_aggregate_sha256,
			"source_files": _source_snapshot.duplicate(true),
			"source_unchanged_during_capture": _source_frozen_validated,
			"frame_inventory": CAPTURE_FILES,
			"semantic_state_inventory": CAPTURE_STATES,
		"frames": _semantic_frames,
		"fixed_camera_contracts": fixed_contract_records,
		"physical_cockpit_display_roi_pixels": _rect2i_dictionary(_cockpit_display_roi),
		"pair_metrics": _pair_metrics,
		"neutral_material_crop_lighting": _lighting_metrics,
			"automated_acceptance_thresholds": {
			"cockpit_offline_online_roi_minimum_changed_fraction": COCKPIT_OFFLINE_ONLINE_MINIMUM_CHANGED_FRACTION,
			"cockpit_online_critical_roi_minimum_changed_fraction": COCKPIT_ONLINE_CRITICAL_MINIMUM_CHANGED_FRACTION,
				"cockpit_exterior_world_maximum_changed_fraction": COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION,
				"cockpit_exterior_world_online_critical_comparison": (
					"CRITICAL with transient damage emitters quiesced: [%s]. The exterior"
					+ " comparison is a camera/pose/world immutability control; pulsing"
					+ " damage illumination and stochastic damage particles are neither,"
					+ " and the fully live figure is recorded separately under pair_metrics"
					+ " as cockpit_online_critical_live_damage_exterior_world_non_gated."
				) % ", ".join(_quiesced_damage_emitters),
				"cockpit_exterior_world_renderer_noise_floor": (
					"Measured, never gated. See pair_metrics"
					+ " cockpit_exterior_world_renderer_noise_floor_non_gated: two readbacks"
					+ " of one unchanged state through the same mask, which bounds how tight"
					+ " cockpit_exterior_world_maximum_changed_fraction can be on this"
					+ " renderer."
				),
				"cockpit_display_roi_minimum_samples": COCKPIT_DISPLAY_ROI_MINIMUM_SAMPLES,
			"ship_mask_luminance_p5_minimum": SHIP_LUMINANCE_P5_MINIMUM,
			"ship_mask_luminance_p95_maximum": SHIP_LUMINANCE_P95_MAXIMUM,
			"ivory_luminance_median_range": [IVORY_LUMINANCE_MEDIAN_MINIMUM, IVORY_LUMINANCE_MEDIAN_MAXIMUM],
			"ivory_graphite_minimum_delta": IVORY_GRAPHITE_MINIMUM_DELTA,
			"graphite_background_delta": "diagnostic only; station backdrop is not an acceptance reference",
			"ship_maximum_clipped_fraction": SHIP_MAXIMUM_CLIPPED_FRACTION,
		},
			"required_original_resolution_human_review": [
				"08 sealed exterior retains the pilot helmet and at least 60 percent of the crimson seat silhouette.",
				"07 open canopy reads as one continuous thin glass/frame/hinge assembly with no pilot or hull clipping.",
				"11/12 aft views visibly resolve at least four nested engine depth layers per side, beyond the pinned semantic-source roster.",
				"15 neutral crop shows convincing UV scale, material response, and surface continuity; numeric lighting gates are necessary but not an art-quality sign-off.",
				"02/04/06/08/15 show no unintended mirrored or rotated panel motifs across adjacent surfaces or opposite outward-facing sides.",
				"15 neutral crop makes seams and recessed fasteners read concave and raised hardware read convex; no green-channel inversion, pillow shading, or inside-out relief is accepted.",
				"16/17/18 retain a visually continuous unobstructed 20x12-degree exterior sight corridor beyond the automated finite ray grid.",
			],
		"human_review_status": "NOT_CLAIMED_BY_AUTOMATION",
		"evidence_limits": [
			"These are deterministic staged acceptance views, not an uninterrupted human playthrough.",
			"X11 Forward+ output does not prove native-Windows rendering, native-GPU performance, flight feel, or camera comfort.",
				"TriangleMesh lighting masks classify live ship geometry in an intentionally unobstructed crop; they do not solve arbitrary unrelated-world occlusion.",
				"Finite TriangleMesh sight samples and UV/normal-map contracts do not prove continuous visibility, motif handedness, or correct perceived relief; those remain listed original-resolution reviews.",
				"Pixel ROI and luminance checks do not replace the listed original-resolution human silhouette, glazing, depth, UV, or overall art reviews.",
				"Raw all-pixels-outside-display metrics are recorded but not gated because live warning/practical lights intentionally change opaque cockpit surfaces; the 0.5 percent gate applies only to triangle-unoccluded exterior/world pixels.",
			"The B5-observed identity is source-locked; recording/build dates, exact historical geometry, and continuity with 2009 remain unproved.",
		],
	}
	var temporary_path := STAGED_EVIDENCE_MANIFEST_PATH + ".tmp"
	_remove_file_if_present(temporary_path, "stale staged evidence-manifest temporary clears")
	_remove_file_if_present(STAGED_EVIDENCE_MANIFEST_PATH, "stale staged evidence manifest clears")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	_check(file != null, "staged hero-cell evidence manifest opens for writing")
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	_check(write_error == OK, "staged hero-cell evidence manifest flushes without error")
	if write_error != OK:
		return
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(STAGED_EVIDENCE_MANIFEST_PATH)
	)
	_check(rename_error == OK, "staged hero-cell evidence manifest commits atomically")
	_check(
		FileAccess.file_exists(STAGED_EVIDENCE_MANIFEST_PATH),
		"source-current staged v5 evidence manifest is present"
	)
	print(
		"HERO_CELL_STAGED_EVIDENCE_MANIFEST: %s"
		% ProjectSettings.globalize_path(STAGED_EVIDENCE_MANIFEST_PATH)
	)


func _reset_capture_transaction() -> void:
	# A run invalidates any prior claim immediately. If the process crashes later,
	# old PNGs may remain for diagnosis but no stale manifest can authenticate them.
	_invalidate_published_claims("prior published claim")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TRANSACTION_DIR)):
		_remove_directory_tree(TRANSACTION_DIR)
	var error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TRANSACTION_DIR)
	)
	_check(
		error == OK or error == ERR_ALREADY_EXISTS,
		"fresh isolated capture transaction directory is created"
	)


func _publish_capture_transaction() -> void:
	_invalidate_published_claims("published claim before replacement")
	_remove_stale_capture_pngs()
	if not _failures.is_empty():
		return

	for file_name in CAPTURE_FILES:
		if not _publish_staged_file(
			TRANSACTION_DIR.path_join(file_name),
			OUTPUT_DIR.path_join(file_name),
			"validated PNG %s" % file_name
		):
			return

	# PNG I/O can take long enough for an external source edit. Recollect the
	# entire recursive roster now; manifests remain absent if anything drifted.
	_validate_source_frozen()
	if not _source_frozen_validated or not _failures.is_empty():
		_invalidate_published_claims("claim after source drift at publish boundary")
		return
	if not _publish_staged_file(
		STAGED_SOURCE_MANIFEST_PATH,
		SOURCE_MANIFEST_PATH,
		"source SHA-256 manifest"
	):
		return

	# Fully validate the published PNG/source set against the staged evidence
	# manifest while no green sentinel exists yet.
	_verify_published_capture_transaction(STAGED_EVIDENCE_MANIFEST_PATH, "precommit staged")
	if not _failures.is_empty():
		_invalidate_published_claims("claim after precommit verification failure")
		return
	var evidence_temporary := EVIDENCE_MANIFEST_PATH + ".publish.tmp"
	if not _prepare_publish_temporary(
		STAGED_EVIDENCE_MANIFEST_PATH,
		evidence_temporary,
		"evidence manifest sentinel"
	):
		_invalidate_published_claims("claim after evidence-manifest preparation failure")
		return

	# The evidence manifest is the sole green sentinel. Recollect every source
	# after its final bytes are already prepared, then perform only one atomic
	# same-directory rename at the commit boundary.
	_validate_source_frozen()
	if not _source_frozen_validated or not _failures.is_empty():
		_invalidate_published_claims("claim after final source drift")
		return
	if not _commit_prepared_file(
		evidence_temporary,
		EVIDENCE_MANIFEST_PATH,
		"evidence manifest sentinel"
	):
		_invalidate_published_claims("claim after evidence-manifest publish failure")
		return
	_verify_published_capture_transaction(EVIDENCE_MANIFEST_PATH, "postcommit published")
	if not _failures.is_empty():
		_invalidate_published_claims("unverified published claim")
		return
	if _failures.is_empty():
		var cleanup_succeeded := _remove_directory_tree(TRANSACTION_DIR)
		if not cleanup_succeeded:
			_invalidate_published_claims("claim with unclean transaction staging")
	if _failures.is_empty():
		print(
			"HERO_CELL_SOURCE_MANIFEST: aggregate=%s path=%s"
			% [_source_aggregate_sha256, ProjectSettings.globalize_path(SOURCE_MANIFEST_PATH)]
		)
		print(
			"HERO_CELL_EVIDENCE_MANIFEST: %s"
			% ProjectSettings.globalize_path(EVIDENCE_MANIFEST_PATH)
		)


func _invalidate_published_claims(context: String) -> void:
	_remove_file_if_present(
		EVIDENCE_MANIFEST_PATH,
		"%s evidence sentinel clears" % context
	)
	_remove_file_if_present(
		SOURCE_MANIFEST_PATH,
		"%s source manifest clears" % context
	)


func _publish_staged_file(source_path: String, destination_path: String, label: String) -> bool:
	var temporary_path := destination_path + ".publish.tmp"
	if not _prepare_publish_temporary(source_path, temporary_path, label):
		return false
	return _commit_prepared_file(temporary_path, destination_path, label)


func _prepare_publish_temporary(source_path: String, temporary_path: String, label: String) -> bool:
	if not FileAccess.file_exists(source_path):
		_fail("transaction publish source is missing for %s: %s" % [label, source_path])
		return false
	var expected_hash := FileAccess.get_sha256(source_path)
	if expected_hash.is_empty():
		_fail("transaction publish source cannot be hashed for %s" % label)
		return false
	if not _remove_file_if_present(temporary_path, "stale publish temporary clears for %s" % label):
		return false
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(temporary_path)
	)
	if copy_error != OK:
		_fail("transaction copy failed for %s: %s" % [label, error_string(copy_error)])
		return false
	if FileAccess.get_sha256(temporary_path) != expected_hash:
		_fail("transaction copy hash mismatch for %s" % label)
		return false
	return true


func _commit_prepared_file(temporary_path: String, destination_path: String, label: String) -> bool:
	if not FileAccess.file_exists(temporary_path):
		_fail("prepared transaction file is missing for %s" % label)
		return false
	var expected_hash := FileAccess.get_sha256(temporary_path)
	if not _remove_file_if_present(destination_path, "old destination clears for %s" % label):
		return false
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(destination_path)
	)
	if rename_error != OK:
		_fail("transaction commit failed for %s: %s" % [label, error_string(rename_error)])
		return false
	_check(
		FileAccess.get_sha256(destination_path) == expected_hash,
		"published %s is byte-identical to its validated staged file" % label
	)
	return _failures.is_empty()


func _verify_published_capture_transaction(evidence_path: String, phase: String) -> void:
	var actual_pngs := PackedStringArray()
	var import_sidecars := PackedStringArray()
	var directory := DirAccess.open(OUTPUT_DIR)
	_check(directory != null, "published hero-cell directory opens for exact inventory")
	if directory == null:
		return
	var list_error := directory.list_dir_begin()
	_check(list_error == OK, "%s hero-cell inventory enumeration begins" % phase)
	if list_error != OK:
		return
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir():
			if entry.ends_with(".png"):
				actual_pngs.append(entry)
			elif entry.ends_with(".png.import"):
				import_sidecars.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	actual_pngs.sort()
	var expected_pngs := PackedStringArray(CAPTURE_FILES)
	expected_pngs.sort()
	_check(actual_pngs == expected_pngs, "%s top-level PNG inventory is exactly the declared 18 frames" % phase)
	_check(import_sidecars.is_empty(), "%s hero-cell inventory has no stale PNG import sidecars" % phase)

	for file_name in CAPTURE_FILES:
		var path := OUTPUT_DIR.path_join(file_name)
		var record := _semantic_frame_for_file(file_name)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and not image.is_empty(), "%s %s decodes as a nonempty PNG" % [phase, file_name])
		_check(
			image != null and image.get_size() == CAPTURE_RESOLUTION,
			"%s %s remains exactly 2560x1440" % [phase, file_name]
		)
		_check(
			FileAccess.get_sha256(path) == str(record.get("sha256", "")),
			"%s %s retains its captured SHA-256" % [phase, file_name]
		)

	var evidence := _read_json(evidence_path)
	var manifest_frames := evidence.get("frames", []) as Array
	var unique_manifest_files := {}
	var exact_manifest_frames := manifest_frames.size() == CAPTURE_FILES.size()
	for frame_index in manifest_frames.size():
		var manifest_record := manifest_frames[frame_index] as Dictionary
		var manifest_file := str(manifest_record.get("file", ""))
		unique_manifest_files[manifest_file] = true
		if frame_index >= CAPTURE_FILES.size():
			exact_manifest_frames = false
			continue
		var published_path := OUTPUT_DIR.path_join(CAPTURE_FILES[frame_index])
		exact_manifest_frames = (
			exact_manifest_frames
			and manifest_file == CAPTURE_FILES[frame_index]
			and str(manifest_record.get("semantic_state", "")) == CAPTURE_STATES[frame_index]
			and str(manifest_record.get("sha256", "")) == FileAccess.get_sha256(published_path)
			and manifest_record.get("resolution", []) == [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
		)
	_check(
		not evidence.is_empty()
		and str(evidence.get("schema", "")) == "hero_cell_rendered_evidence_v5"
		and int(evidence.get("frame_count", 0)) == CAPTURE_FILES.size()
		and evidence.get("frame_inventory", []) == CAPTURE_FILES
		and evidence.get("semantic_state_inventory", []) == CAPTURE_STATES
		and unique_manifest_files.size() == CAPTURE_FILES.size()
		and exact_manifest_frames,
		"%s evidence manifest parses with the exact ordered v5 file/state/hash inventory" % phase
	)
	_check(
		FileAccess.file_exists(SOURCE_MANIFEST_PATH)
		and str(evidence.get("source_manifest_sha256", ""))
		== FileAccess.get_sha256(SOURCE_MANIFEST_PATH)
		and bool(evidence.get("source_unchanged_during_capture", false))
		and str(evidence.get("source_aggregate_sha256", "")) == _source_aggregate_sha256
		and evidence.get("source_files", {}) == _source_snapshot,
		"%s evidence manifest authenticates the frozen source roster and published source manifest" % phase
	)


func _semantic_frame_for_file(file_name: String) -> Dictionary:
	for record in _semantic_frames:
		if str(record.get("file", "")) == file_name:
			return record
	return {}


func _remove_stale_capture_pngs() -> void:
	var directory := DirAccess.open(OUTPUT_DIR)
	_check(directory != null, "hero-cell output opens for bounded stale-frame cleanup")
	if directory == null:
		return
	var removable := PackedStringArray()
	var list_error := directory.list_dir_begin()
	_check(list_error == OK, "bounded stale hero-cell enumeration begins")
	if list_error != OK:
		return
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and (
			file_name.ends_with(".png")
			or file_name.ends_with(".png.import")
			or file_name.ends_with(".publish.tmp")
		):
			removable.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	for removable_name in removable:
		_remove_file_if_present(
			OUTPUT_DIR.path_join(removable_name),
			"bounded stale hero-cell capture clears: %s" % removable_name
		)


func _remove_file_if_present(path: String, description: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path):
		_fail("refusing to remove directory where a transaction file was expected: %s" % path)
		return false
	if not FileAccess.file_exists(path):
		return true
	var error := DirAccess.remove_absolute(absolute_path)
	_check(error == OK, description)
	return error == OK


func _remove_directory_tree(path: String) -> bool:
	if path != TRANSACTION_DIR and not path.begins_with(TRANSACTION_DIR + "/"):
		_fail("refusing broad transaction cleanup outside %s: %s" % [TRANSACTION_DIR, path])
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return true
	var directory := DirAccess.open(path)
	if directory == null:
		_fail("transaction directory cannot be opened for cleanup: %s" % path)
		return false
	var files := PackedStringArray()
	var directories := PackedStringArray()
	var list_error := directory.list_dir_begin()
	if list_error != OK:
		_fail("transaction directory enumeration failed: %s" % path)
		return false
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			if directory.current_is_dir():
				directories.append(entry)
			else:
				files.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	var valid := true
	for file_name in files:
		var error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path.path_join(file_name))
		)
		if error != OK:
			_fail("transaction file cleanup failed: %s" % path.path_join(file_name))
			valid = false
	for directory_name in directories:
		valid = _remove_directory_tree(path.path_join(directory_name)) and valid
	var remove_error := DirAccess.remove_absolute(absolute_path)
	if remove_error != OK:
		_fail("transaction directory cleanup failed: %s" % path)
		valid = false
	return valid


func _transform_dictionary(transform: Transform3D) -> Dictionary:
	return {
		"origin": _vector3_array(transform.origin),
		"basis_x": _vector3_array(transform.basis.x),
		"basis_y": _vector3_array(transform.basis.y),
		"basis_z": _vector3_array(transform.basis.z),
	}


func _vector3_array(value: Vector3) -> Array[float]:
	return [
		snappedf(value.x, 0.000001),
		snappedf(value.y, 0.000001),
		snappedf(value.z, 0.000001),
	]


func _vector2_array(value: Vector2) -> Array[float]:
	return [
		snappedf(value.x, 0.000001),
		snappedf(value.y, 0.000001),
	]


func _rect2i_dictionary(value: Rect2i) -> Dictionary:
	return {
		"x": value.position.x,
		"y": value.position.y,
		"width": value.size.x,
		"height": value.size.y,
	}


func _integer_dictionary_matches(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: String in expected:
		if not actual.has(key) or int(actual.get(key, -1)) != int(expected[key]):
			return false
	return true


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("HERO_CELL_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("HERO_CELL_FAIL: " + description)


## Prints every gated measurement to stdout whatever the outcome.
##
## The evidence manifest is only written on success, so before this a failing run
## published no numbers at all and the failure text was the sole record. The
## measurements are what a reader needs most on the failure path.
func _print_measured_metrics() -> void:
	if not _lighting_metrics.is_empty():
		print("HERO_CELL_METRICS: ship_mask_lighting=", JSON.stringify(_lighting_metrics))
	for label in _pair_metrics:
		print(
			"HERO_CELL_METRICS: %s=%s"
			% [label, JSON.stringify(_pair_metrics[label])]
		)


func _finish() -> void:
	_print_measured_metrics()
	if _failures.is_empty():
		print(
			"HERO_CELL_CAPTURE_OK: %d HUD-off source-frozen Forward+ frames at %dx%d"
			% [CAPTURE_FILES.size(), CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
		)
		quit(0)
	else:
		push_error("HERO_CELL_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)
