extends SceneTree

## HUD-free source-current evidence for the production combat presentation.
##
## This harness instantiates the complete production Main scene, stages the live
## Torrent and range interceptor in the established combat arena, and submits
## every photographed shot through GameFlow's real live-combat handlers. It adds
## one evidence Camera3D, freezes craft navigation, and advances only the pooled
## PulseWeaponPresentation's public deterministic clock. Those interventions are
## evidence controls, not claims of an uninterrupted player-driven dogfight.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/combat_visuals"
const TRANSACTION_DIR := OUTPUT_DIR + "/.capture_transaction"
const EVIDENCE_MANIFEST_PATH := OUTPUT_DIR + "/evidence_manifest.json"
const SOURCE_MANIFEST_PATH := OUTPUT_DIR + "/source_manifest.sha256"
const STAGED_EVIDENCE_MANIFEST_PATH := TRANSACTION_DIR + "/evidence_manifest.json"
const STAGED_SOURCE_MANIFEST_PATH := TRANSACTION_DIR + "/source_manifest.sha256"
const CAPTURE_LOG_PATH := OUTPUT_DIR + "/capture_forward_plus_2560x1440.log"
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "MUDDS_CAPTURE_COMBAT_VISUALS_PARSE_ONLY"

const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const CAPTURE_FILES: Array[String] = [
	"01_damaged_opponent_baseline.png",
	"02_cyan_muzzle_midflight.png",
	"03_cyan_impact_critical.png",
	"04_amber_midflight.png",
	"05_amber_hero_impact.png",
	"06_lethal_cyan_inflight.png",
	"07_lethal_arrival_destruction.png",
]
const CAPTURE_STATES: Array[String] = [
	"damaged_opponent_baseline",
	"cyan_muzzle_midflight",
	"cyan_impact_critical",
	"amber_midflight",
	"amber_hero_impact",
	"lethal_cyan_inflight",
	"lethal_arrival_destruction",
]

const SOURCE_ROOTS: Array[String] = [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://default_bus_layout.tres",
	"res://tests/capture_combat_visuals.gd",
	"res://tests/capture_combat_visuals.gd.uid",
	"res://scripts",
	"res://scenes",
	"res://assets",
	"res://art_source",
	"res://tools",
]

const ARENA_ORIGIN := Vector3(180.0, 54.0, -230.0)
const OPPONENT_OFFSET := Vector3(0.0, 0.0, -34.0)
const CAMERA_DIRECTION := Vector3(1.0, 0.34, 0.0)
const CAMERA_DISTANCE := 38.0
const CAMERA_FOV := 42.0
const FRAME_MARGIN_FRACTION := 0.035
const CYAN_MIDFLIGHT_PROGRESS := 0.38
const CYAN_IMPACT_AGE := 0.045
const AMBER_MIDFLIGHT_PROGRESS := 0.58
const AMBER_IMPACT_AGE := 0.040
const LETHAL_MIDFLIGHT_PROGRESS := 0.55
const LETHAL_IMPACT_AGE := 0.045

const MINIMUM_PNG_BYTES := 140_000
const MINIMUM_LUMINANCE_RANGE := 0.035
const MINIMUM_LUMINANCE_VARIANCE := 0.00010
const ROI_SIZE := Vector2i(144, 144)
const PIXEL_CHANGE_THRESHOLD := 0.045
const MINIMUM_ROI_MEAN_DIFFERENCE := 0.010
const MINIMUM_ROI_CHANGED_FRACTION := 0.025
const MINIMUM_EFFECT_COLOURED_PIXELS := 48
const MINIMUM_ROI_PEAK_LUMINANCE := 0.55
const MINIMUM_DESTRUCTION_MEAN_DIFFERENCE := 0.012
const MINIMUM_DESTRUCTION_CHANGED_FRACTION := 0.035

const SETUP_EXPECTED_HEALTH := 51.0
const CRITICAL_EXPECTED_HEALTH := 17.0
const HERO_EXPECTED_HULL_AFTER_HIT := 89.0

var _failures: Array[String] = []
var _game: GameFlow
var _world: ShipyardWorld
var _hero: HeroShip
var _opponent: RangeOpponent
var _pulse: PulseWeaponPresentation
var _camera: Camera3D
var _opponent_visual: Node3D
var _opponent_smoke: CPUParticles3D

var _source_paths := PackedStringArray()
var _source_snapshot: Dictionary = {}
var _source_aggregate_sha256 := ""
var _source_frozen_validated := false
var _semantic_frames: Array[Dictionary] = []
var _captured_images: Dictionary = {}
var _pair_metrics: Dictionary = {}
var _fixed_camera_contract: Dictionary = {}
var _frame_anchors := PackedVector3Array()
var _lethal_effect_pose := Transform3D.IDENTITY


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("MUDDS_CAPTURE_COMBAT_VISUALS_PARSE_OK")
		quit(0)
		return

	_reset_capture_transaction()
	_source_paths = _collect_source_paths()
	_source_snapshot = _snapshot_source_files(_source_paths)
	_source_aggregate_sha256 = _source_snapshot_hash(_source_snapshot, _source_paths)
	_check(
		_source_paths.size() > SOURCE_ROOTS.size(),
		"source freeze recursively expands the declared production roots"
	)
	_check(not _source_aggregate_sha256.is_empty(), "source freeze has a nonempty aggregate SHA-256")
	if not _failures.is_empty():
		_finish()
		return

	_configure_capture_viewport()
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	_check(DisplayServer.get_name() == "X11", "capture uses a native X11 display rather than headless rendering")
	_check(
		DisplayServer.window_get_size() == CAPTURE_RESOLUTION,
		"native capture window is exactly 2560x1440"
	)
	print(
		"COMBAT_VISUAL_RENDERER: method=%s adapter=%s display=%s window=%s"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			DisplayServer.get_name(),
			str(DisplayServer.window_get_size()),
		]
	)

	_game = MAIN_SCENE.instantiate() as GameFlow
	_check(_game != null, "complete production main scene instantiates")
	if _game == null:
		_finish()
		return
	root.add_child(_game)
	await _settle_render(12)
	await physics_frame

	if not _resolve_production_contracts():
		await _dispose_game()
		_finish()
		return
	_disable_all_canvas_layers()
	_validate_hud_policy()
	_prepare_deterministic_combat_stage()
	# CharacterBody transforms enter the physics broadphase at the next tick.
	# No live shot is submitted before both staged collision rosters are current.
	await physics_frame
	await _settle_render(4)
	if not _failures.is_empty():
		await _dispose_game()
		_finish()
		return

	await _capture_sequence()
	_validate_capture_set()
	_validate_source_frozen()
	if _failures.is_empty() and _source_frozen_validated:
		_write_source_manifest()
		_write_evidence_manifest()
		_publish_capture_transaction()

	await _dispose_game()
	_finish()


func _configure_capture_viewport() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X


func _resolve_production_contracts() -> bool:
	_world = _game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_hero = _game.get_node_or_null("TorrentInterceptor") as HeroShip
	_opponent = _game.get_node_or_null("RangeOpponent") as RangeOpponent
	_pulse = _game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	_check(_world != null, "production ShipyardWorld exists")
	_check(_hero != null, "production Torrent hero exists")
	_check(_opponent != null, "production range interceptor exists")
	_check(_pulse != null, "production pooled pulse presentation exists")
	_check(_game.get_combat_authority() != null, "production live combat authority exists")
	_check(_game.get_combat_resolver() != null, "production combat resolver exists")
	if _world == null or _hero == null or _opponent == null or _pulse == null:
		return false

	_opponent_visual = _opponent.get_node_or_null("RangeInterceptorVisual") as Node3D
	_opponent_smoke = _opponent.get_node_or_null("EngineSmoke") as CPUParticles3D
	_check(_opponent_visual != null, "opponent exposes its authored hull presentation root")
	_check(_opponent_smoke != null, "opponent exposes its critical engine-smoke presentation")
	_check(
		_pulse.has_method("get_active_shot_snapshots")
		and _pulse.has_method("advance_simulation")
		and _pulse.has_method("set_auto_advance_enabled"),
		"production pulse publishes deterministic manual timing controls"
	)
	var audit := _pulse.get_audit_report()
	_check(
		bool(audit.get("valid", false))
		and (audit.get("errors", PackedStringArray()) as PackedStringArray).is_empty(),
		"production pulse component passes its deep audit"
	)
	_check(
		int(audit.get("schema_version", 0)) == 2,
		"capture is bound to the Combat V2 pulse schema"
	)
	return _opponent_visual != null and _opponent_smoke != null


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


func _prepare_deterministic_combat_stage() -> void:
	var high_quality := _world.apply_visual_quality(2)
	_check(bool(high_quality.get("applied", false)), "production High visual-quality profile applies")
	_pulse.reset_for_reuse()
	_pulse.set_presentation_enabled(true)
	_pulse.set_auto_advance_enabled(false)
	_check(not _pulse.is_auto_advance_enabled(), "pulse automatic advancement is disabled for exact phase capture")

	_hero.global_transform = Transform3D(Basis.IDENTITY, ARENA_ORIGIN)
	_hero.velocity = Vector3.ZERO
	_hero.set_physics_process(false)
	var opponent_position := ARENA_ORIGIN + OPPONENT_OFFSET
	var aim_direction := (_hero.global_position - opponent_position).normalized()
	var opponent_basis := Basis.looking_at(aim_direction, Vector3.UP).orthonormalized()
	_opponent.activate(Transform3D(opponent_basis, opponent_position))
	_opponent.set_target(_hero)
	_opponent.set_physics_process(false)
	_game.active_ship = _hero
	_game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT

	_camera = Camera3D.new()
	_camera.name = "CombatVisualEvidenceCamera"
	_camera.near = 0.06
	_camera.far = 1800.0
	_camera.fov = CAMERA_FOV
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_game.add_child(_camera)
	_frame_anchors = _combat_frame_anchors()
	_frame_combat(_frame_anchors)
	_validate_frame_anchors(_frame_anchors, "fixed combat composition")
	_fixed_camera_contract = {
		"instance_id": _camera.get_instance_id(),
		"transform": _camera.global_transform,
		"fov": _camera.fov,
		"near": _camera.near,
		"far": _camera.far,
		"projection": _camera.projection,
		"keep_aspect": _camera.keep_aspect,
		"cull_mask": _camera.cull_mask,
	}

	_check(_opponent.is_active(), "opponent is active in the staged production encounter")
	_check(is_equal_approx(_opponent.get_health(), 85.0), "opponent begins at production maximum health")
	_check(_hero.get_telemetry().get("hull", 0.0) == 100.0, "hero begins at production maximum hull")
	_check(_opponent.collision_layer != 0, "opponent begins with authoritative collision enabled")


func _capture_sequence() -> void:
	# Setup damage creates the baseline 60%-health hull. Its travelling pulse and
	# transient impact are allowed to finish before any evidence frame is read.
	var setup_result := _submit_player_shot()
	_validate_player_result(setup_result, "setup cyan hit")
	var setup_snapshot := _single_active_snapshot("setup cyan hit")
	if setup_snapshot.is_empty():
		return
	_pulse.advance_simulation(float(setup_snapshot.get("total_lifetime", 0.0)) + 0.01)
	await create_timer(1.05).timeout
	await _settle_render(4)
	_check(is_equal_approx(_opponent.get_health(), SETUP_EXPECTED_HEALTH), "setup hit leaves opponent at 51 health")
	_check(_opponent.get_pending_damage_presentation_count() == 0, "setup receipt is fully presented before baseline")
	_check(_pulse.get_active_effect_count() == 0, "setup pulse retires before baseline")
	_check(not _opponent_smoke.emitting, "damaged baseline has no critical smoke")
	await _capture_frame(
		CAPTURE_FILES[0],
		CAPTURE_STATES[0],
		_roi_for_world_position(_opponent.global_position),
		{"opponent_health": _opponent.get_health(), "critical_smoke": _opponent_smoke.emitting}
	)

	# The second player shot resolves authority synchronously, while the exact
	# receipt keeps critical smoke and target impact behind the travelling pulse.
	var cyan_result := _submit_player_shot()
	_validate_player_result(cyan_result, "critical cyan hit")
	var cyan_snapshot := _single_active_snapshot("critical cyan hit")
	if cyan_snapshot.is_empty():
		return
	var cyan_travel := float(cyan_snapshot.get("travel_duration", 0.0))
	_pulse.advance_simulation(cyan_travel * CYAN_MIDFLIGHT_PROGRESS)
	cyan_snapshot = _single_active_snapshot("cyan midflight")
	_validate_cyan_midflight(cyan_snapshot)
	await _capture_frame(
		CAPTURE_FILES[1],
		CAPTURE_STATES[1],
		_roi_for_world_position(cyan_snapshot.get("pulse_position", Vector3.ZERO)),
		_combat_markers(cyan_snapshot)
	)

	_pulse.advance_simulation(cyan_travel * (1.0 - CYAN_MIDFLIGHT_PROGRESS) + CYAN_IMPACT_AGE)
	var cyan_impact := _single_active_snapshot("cyan arrival")
	_validate_cyan_arrival(cyan_impact)
	await _capture_frame(
		CAPTURE_FILES[2],
		CAPTURE_STATES[2],
		_roi_for_world_position(cyan_impact.get("end", _opponent.global_position)),
		_combat_markers(cyan_impact)
	)
	_pulse.clear_effects()

	# Opponent fire traverses the same resolver and queues the hero's world-space
	# impact until its amber pulse reaches the Torrent collision surface.
	var amber_result := _submit_opponent_shot()
	_validate_opponent_result(amber_result)
	var amber_snapshot := _single_active_snapshot("amber hero hit")
	if amber_snapshot.is_empty():
		return
	var amber_travel := float(amber_snapshot.get("travel_duration", 0.0))
	_pulse.advance_simulation(amber_travel * AMBER_MIDFLIGHT_PROGRESS)
	amber_snapshot = _single_active_snapshot("amber midflight")
	_validate_amber_midflight(amber_snapshot)
	await _capture_frame(
		CAPTURE_FILES[3],
		CAPTURE_STATES[3],
		_roi_for_world_position(amber_snapshot.get("pulse_position", Vector3.ZERO)),
		_combat_markers(amber_snapshot)
	)

	_pulse.advance_simulation(amber_travel * (1.0 - AMBER_MIDFLIGHT_PROGRESS) + AMBER_IMPACT_AGE)
	var amber_impact := _single_active_snapshot("amber arrival")
	_validate_amber_arrival(amber_impact)
	await _capture_frame(
		CAPTURE_FILES[4],
		CAPTURE_STATES[4],
		_roi_for_world_position(amber_impact.get("end", _hero.global_position)),
		_combat_markers(amber_impact)
	)
	_pulse.clear_effects()

	# Health/collision/destruction authority resolves at trigger pull. The target
	# hull and world-stable destruction burst remain presentation-gated until the
	# lethal cyan pulse reaches the exact resolved collision point.
	_lethal_effect_pose = _opponent.global_transform
	var lethal_result := _submit_player_shot()
	_validate_player_result(lethal_result, "lethal cyan hit")
	var lethal_snapshot := _single_active_snapshot("lethal cyan hit")
	if lethal_snapshot.is_empty():
		return
	var lethal_travel := float(lethal_snapshot.get("travel_duration", 0.0))
	_pulse.advance_simulation(lethal_travel * LETHAL_MIDFLIGHT_PROGRESS)
	lethal_snapshot = _single_active_snapshot("lethal cyan midflight")
	_validate_lethal_midflight(lethal_snapshot)
	await _capture_frame(
		CAPTURE_FILES[5],
		CAPTURE_STATES[5],
		_roi_for_world_position(lethal_snapshot.get("pulse_position", Vector3.ZERO)),
		_combat_markers(lethal_snapshot)
	)

	_pulse.advance_simulation(lethal_travel * (1.0 - LETHAL_MIDFLIGHT_PROGRESS) + LETHAL_IMPACT_AGE)
	var lethal_arrival := _single_active_snapshot("lethal cyan arrival")
	_validate_lethal_arrival(lethal_arrival)
	await _capture_frame(
		CAPTURE_FILES[6],
		CAPTURE_STATES[6],
		_roi_for_world_position(_lethal_effect_pose.origin),
		_combat_markers(lethal_arrival)
	)


func _submit_player_shot() -> Dictionary:
	var origin := _hero.global_position + Vector3(0.0, 0.85, -5.25)
	var direction := (_opponent.global_position - origin).normalized()
	_game.call("_on_projectile_fired", origin, direction, _hero)
	return _game.get_last_player_shot_result()


func _submit_opponent_shot() -> Dictionary:
	var muzzle := _opponent.get_node_or_null("PortMuzzle") as Marker3D
	var origin := muzzle.global_position if muzzle != null else _opponent.global_position
	var hero_aim := _hero.global_position + Vector3(0.0, 1.0, 0.0)
	_game.call("_on_opponent_projectile_fired", origin, (hero_aim - origin).normalized())
	return _game.get_last_opponent_shot_result()


func _validate_player_result(result: Dictionary, label: String) -> void:
	_check(bool(result.get("accepted", false)), "%s is accepted by live authority" % label)
	_check(bool(result.get("resolved", false)), "%s is resolved by the production resolver" % label)
	_check(bool(result.get("hit", false)), "%s hits a production collision surface" % label)
	_check(bool(result.get("damaged", false)), "%s applies authoritative damage" % label)
	_check(result.get("target_entity") == _opponent, "%s identifies the opponent lifecycle" % label)
	_check(
		(result.get("position", Vector3.INF) as Vector3).is_finite(),
		"%s publishes a finite collision endpoint" % label
	)


func _validate_opponent_result(result: Dictionary) -> void:
	_check(bool(result.get("accepted", false)), "amber shot is accepted by live authority")
	_check(bool(result.get("resolved", false)), "amber shot is resolved by the production resolver")
	_check(bool(result.get("hit", false)), "amber shot hits a production hero collision surface")
	_check(bool(result.get("damaged", false)), "amber shot applies authoritative hero damage")
	_check(result.get("target_entity") == _hero, "amber shot identifies the active hero lifecycle")


func _validate_cyan_midflight(snapshot: Dictionary) -> void:
	_check(is_equal_approx(_opponent.get_health(), CRITICAL_EXPECTED_HEALTH), "cyan in-flight authority has already reduced opponent health to critical")
	_check(_opponent.get_pending_damage_presentation_count() == 1, "cyan in-flight owns exactly one pending opponent presentation receipt")
	_check(not _opponent_smoke.emitting, "cyan in-flight critical smoke has not started before pulse arrival")
	_check(bool(snapshot.get("pulse_visible", false)), "cyan in-flight pulse is visible")
	_check(not bool(snapshot.get("impact_visible", true)), "cyan in-flight impact is hidden")
	_check(
		is_equal_approx(float(snapshot.get("travel_progress", 0.0)), CYAN_MIDFLIGHT_PROGRESS),
		"cyan in-flight uses exact 0.38 travel progress"
	)


func _validate_cyan_arrival(snapshot: Dictionary) -> void:
	_check(_opponent.get_pending_damage_presentation_count() == 0, "cyan arrival releases the opponent presentation receipt")
	_check(_opponent_smoke.emitting, "cyan arrival starts critical opponent smoke")
	_check(not bool(snapshot.get("pulse_visible", true)), "cyan arrival hides the travelling pulse")
	_check(bool(snapshot.get("impact_visible", false)), "cyan arrival displays the impact flare")
	_check(
		float(snapshot.get("age", 0.0)) >= float(snapshot.get("travel_duration", INF)),
		"cyan arrival snapshot is at or beyond the exact endpoint"
	)


func _validate_amber_midflight(snapshot: Dictionary) -> void:
	var presentation := _hero.get_damage_presentation()
	_check(is_equal_approx(float(_hero.get_telemetry().get("hull", 0.0)), HERO_EXPECTED_HULL_AFTER_HIT), "amber in-flight authority has already reduced hero hull to 89")
	_check(presentation.get_pending_damage_presentation_count() == 1, "amber in-flight owns exactly one pending hero presentation receipt")
	_check(presentation.get_live_world_effect_count() == 0, "amber in-flight has not spawned the hero world-space impact")
	_check(bool(snapshot.get("pulse_visible", false)), "amber in-flight pulse is visible")
	_check(not bool(snapshot.get("impact_visible", true)), "amber in-flight impact is hidden")
	_check(
		is_equal_approx(float(snapshot.get("travel_progress", 0.0)), AMBER_MIDFLIGHT_PROGRESS),
		"amber in-flight uses exact 0.58 travel progress"
	)


func _validate_amber_arrival(snapshot: Dictionary) -> void:
	var presentation := _hero.get_damage_presentation()
	_check(presentation.get_pending_damage_presentation_count() == 0, "amber arrival releases the hero presentation receipt")
	_check(presentation.get_live_world_effect_count() > 0, "amber arrival owns a live detached hero impact")
	_check(not bool(snapshot.get("pulse_visible", true)), "amber arrival hides the travelling pulse")
	_check(bool(snapshot.get("impact_visible", false)), "amber arrival displays the impact flare")
	var hero_impacts := root.find_children("HeroDamageImpact", "Node3D", true, false)
	_check(not hero_impacts.is_empty(), "amber arrival creates the named production HeroDamageImpact")
	if not hero_impacts.is_empty():
		_check(
			not _hero.is_ancestor_of(hero_impacts[0]),
			"hero impact is detached into world space rather than parented under the moving hull"
		)


func _validate_lethal_midflight(snapshot: Dictionary) -> void:
	_check(is_zero_approx(_opponent.get_health()), "lethal in-flight authority has reduced opponent health to zero")
	_check(not _opponent.is_active(), "lethal in-flight authority has deactivated the opponent")
	_check(_opponent.collision_layer == 0 and _opponent.collision_mask == 0, "lethal in-flight authority has removed opponent collision")
	_check(_opponent.get_pending_damage_presentation_count() == 1, "lethal in-flight owns exactly one pending terminal receipt")
	_check(_opponent_visual.visible, "lethal in-flight keeps the opponent hull presentation visible")
	_check(_opponent.get_destruction_effect_root() == null, "lethal in-flight has no premature destruction root")
	_check(bool(snapshot.get("pulse_visible", false)), "lethal in-flight pulse is visible")
	_check(not bool(snapshot.get("impact_visible", true)), "lethal in-flight impact is hidden")
	_check(
		is_equal_approx(float(snapshot.get("travel_progress", 0.0)), LETHAL_MIDFLIGHT_PROGRESS),
		"lethal in-flight uses exact 0.55 travel progress"
	)


func _validate_lethal_arrival(snapshot: Dictionary) -> void:
	var destruction := _opponent.get_destruction_effect_root()
	_check(_opponent.get_pending_damage_presentation_count() == 0, "lethal arrival releases the terminal presentation receipt")
	_check(not _opponent_visual.visible, "lethal arrival hides the opponent hull presentation")
	_check(destruction != null, "lethal arrival creates the detached destruction root")
	_check(not bool(snapshot.get("pulse_visible", true)), "lethal arrival hides the travelling pulse")
	_check(bool(snapshot.get("impact_visible", false)), "lethal arrival displays the endpoint impact flare")
	if destruction != null:
		_check(destruction.get_parent() != _opponent, "destruction root is not parented under the opponent")
		_check(not _opponent.is_ancestor_of(destruction), "destruction root is world-owned rather than opponent-owned")
		_check(
			destruction.global_transform.is_equal_approx(_lethal_effect_pose),
			"destruction root retains the captured world pose at pulse arrival"
		)


func _single_active_snapshot(label: String) -> Dictionary:
	var snapshots := _pulse.get_active_shot_snapshots()
	_check(snapshots.size() == 1, "%s has exactly one active pooled shot" % label)
	return snapshots[0] as Dictionary if snapshots.size() == 1 else {}


func _combat_markers(snapshot: Dictionary) -> Dictionary:
	var hero_presentation := _hero.get_damage_presentation()
	var destruction := _opponent.get_destruction_effect_root()
	return {
		"opponent_health": snappedf(_opponent.get_health(), 0.0001),
		"opponent_active": _opponent.is_active(),
		"opponent_collision_layer": _opponent.collision_layer,
		"opponent_collision_mask": _opponent.collision_mask,
		"opponent_pending_presentations": _opponent.get_pending_damage_presentation_count(),
		"opponent_hull_visible": _opponent_visual.visible,
		"opponent_critical_smoke": _opponent_smoke.emitting,
		"opponent_destruction_root": is_instance_valid(destruction),
		"opponent_destruction_parented_under_hull": (
			_opponent.is_ancestor_of(destruction) if is_instance_valid(destruction) else false
		),
		"hero_hull": snappedf(float(_hero.get_telemetry().get("hull", 0.0)), 0.0001),
		"hero_pending_presentations": hero_presentation.get_pending_damage_presentation_count(),
		"hero_world_effect_count": hero_presentation.get_live_world_effect_count(),
		"pulse_snapshot": _snapshot_record(snapshot),
	}


func _snapshot_record(snapshot: Dictionary) -> Dictionary:
	return {
		"shot_id": int(snapshot.get("shot_id", 0)),
		"style_id": String(snapshot.get("style_id", &"")),
		"source_instance_id": int(snapshot.get("source_instance_id", 0)),
		"hit": bool(snapshot.get("hit", false)),
		"age": snappedf(float(snapshot.get("age", 0.0)), 0.000001),
		"travel_duration": snappedf(float(snapshot.get("travel_duration", 0.0)), 0.000001),
		"total_lifetime": snappedf(float(snapshot.get("total_lifetime", 0.0)), 0.000001),
		"travel_progress": snappedf(float(snapshot.get("travel_progress", 0.0)), 0.000001),
		"origin": _vector3_array(snapshot.get("origin", Vector3.ZERO)),
		"end": _vector3_array(snapshot.get("end", Vector3.ZERO)),
		"pulse_position": _vector3_array(snapshot.get("pulse_position", Vector3.ZERO)),
		"pulse_visible": bool(snapshot.get("pulse_visible", false)),
		"impact_visible": bool(snapshot.get("impact_visible", false)),
		"visible_beam_segments": int(snapshot.get("visible_beam_segments", 0)),
	}


func _combat_frame_anchors() -> PackedVector3Array:
	var points := PackedVector3Array()
	_append_collision_corners(points, _hero)
	_append_collision_corners(points, _opponent)
	var player_origin := _hero.global_position + Vector3(0.0, 0.85, -5.25)
	var opponent_muzzle := _opponent.get_node_or_null("PortMuzzle") as Marker3D
	var amber_origin := opponent_muzzle.global_position if opponent_muzzle != null else _opponent.global_position
	points.append(player_origin)
	points.append(amber_origin)
	points.append(player_origin.lerp(_opponent.global_position, 0.5))
	points.append(amber_origin.lerp(_hero.global_position, 0.5))
	points.append(_opponent.global_position)
	points.append(_hero.global_position + Vector3.UP)
	return points


func _append_collision_corners(points: PackedVector3Array, body: Node3D) -> void:
	for candidate in body.get_children():
		var collision := candidate as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var local_box := _shape_local_aabb(collision.shape)
		if local_box.size == Vector3.ZERO:
			continue
		for x in [local_box.position.x, local_box.end.x]:
			for y in [local_box.position.y, local_box.end.y]:
				for z in [local_box.position.z, local_box.end.z]:
					points.append(collision.global_transform * Vector3(x, y, z))


func _shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var capsule_size := Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
		return AABB(-capsule_size * 0.5, capsule_size)
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		var cylinder_size := Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		return AABB(-cylinder_size * 0.5, cylinder_size)
	return AABB()


func _frame_combat(points: PackedVector3Array) -> void:
	if points.is_empty():
		_fail("combat stage has no semantic framing anchors")
		return
	var bounds := _point_bounds(points)
	var centre := ((bounds.minimum as Vector3) + (bounds.maximum as Vector3)) * 0.5
	var radius := 1.0
	for point in points:
		radius = maxf(radius, point.distance_to(centre))
	# The beam corridor runs along world Z. A near-orthogonal side view makes the
	# VFX materially legible while the semantic anchor gate, below, proves the
	# full collision roster still fits with the required 3.5 percent margin.
	_camera.global_position = centre + CAMERA_DIRECTION.normalized() * CAMERA_DISTANCE
	_camera.look_at(centre + Vector3.UP * 0.25, Vector3.UP)
	_camera.current = true
	print(
		"COMBAT_VISUAL_CAMERA: position=%s focus=%s fov=%.1f radius=%.2f"
		% [str(_camera.global_position), str(centre), CAMERA_FOV, radius]
	)


func _validate_frame_anchors(points: PackedVector3Array, label: String) -> void:
	var clipped: Array[String] = []
	var minimum := Vector2(CAPTURE_RESOLUTION) * FRAME_MARGIN_FRACTION
	var maximum := Vector2(CAPTURE_RESOLUTION) - minimum
	for index in points.size():
		var point := points[index]
		if _camera.is_position_behind(point):
			clipped.append("%d:behind" % index)
			continue
		var screen := _camera.unproject_position(point)
		if screen.x < minimum.x or screen.y < minimum.y or screen.x > maximum.x or screen.y > maximum.y:
			clipped.append("%d:frame" % index)
	_check(
		clipped.is_empty(),
		"%s keeps all %d source/target/bounds/corridor anchors inside the 3.5%% margin"
		% [label, points.size()]
	)


func _point_bounds(points: PackedVector3Array) -> Dictionary:
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return {"minimum": minimum, "maximum": maximum}


func _roi_for_world_position(world_position: Vector3) -> Rect2i:
	_check(world_position.is_finite(), "ROI world anchor is finite")
	_check(not _camera.is_position_behind(world_position), "ROI world anchor is in front of the evidence camera")
	var screen := _camera.unproject_position(world_position)
	var origin := Vector2i(roundi(screen.x), roundi(screen.y)) - ROI_SIZE / 2
	origin.x = clampi(origin.x, 0, CAPTURE_RESOLUTION.x - ROI_SIZE.x)
	origin.y = clampi(origin.y, 0, CAPTURE_RESOLUTION.y - ROI_SIZE.y)
	var roi := Rect2i(origin, ROI_SIZE)
	var frame_margin := Vector2i(Vector2(CAPTURE_RESOLUTION) * FRAME_MARGIN_FRACTION)
	_check(
		roi.position.x >= frame_margin.x
		and roi.position.y >= frame_margin.y
		and roi.end.x <= CAPTURE_RESOLUTION.x - frame_margin.x
		and roi.end.y <= CAPTURE_RESOLUTION.y - frame_margin.y,
		"144x144 effect ROI remains inside the 3.5% frame margin"
	)
	return roi


func _capture_frame(
	file_name: String,
	semantic_state: String,
	effect_roi: Rect2i,
	markers: Dictionary
	) -> void:
	_validate_hud_policy()
	_validate_fixed_camera(file_name)
	_validate_frame_anchors(_frame_anchors, file_name)
	await _settle_render(4)
	_validate_fixed_camera(file_name + " [settled]")
	await RenderingServer.frame_post_draw
	_validate_fixed_camera(file_name + " [post-draw]")
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("%s produced an empty viewport image" % file_name)
		return
	image.convert(Image.FORMAT_RGB8)
	var actual_size := image.get_size()
	_check(actual_size == CAPTURE_RESOLUTION, "%s is exactly 2560x1440" % file_name)
	if actual_size != CAPTURE_RESOLUTION:
		return

	var statistics := _sample_luminance_statistics(image)
	_check(
		float(statistics.get("range", 0.0)) >= MINIMUM_LUMINANCE_RANGE,
		"%s has luminance range at least %.3f" % [file_name, MINIMUM_LUMINANCE_RANGE]
	)
	_check(
		float(statistics.get("variance", 0.0)) >= MINIMUM_LUMINANCE_VARIANCE,
		"%s has luminance variance at least %.5f" % [file_name, MINIMUM_LUMINANCE_VARIANCE]
	)

	var path := TRANSACTION_DIR.path_join(file_name)
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saves into the isolated capture transaction" % file_name)
	if save_error != OK:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var byte_count := file.get_length() if file != null else 0
	_check(byte_count >= MINIMUM_PNG_BYTES, "%s contains at least 140 KB of rendered detail" % file_name)
	var png_header := _inspect_png_header(path)
	_check(
		bool(png_header.get("valid", false))
		and int(png_header.get("width", 0)) == CAPTURE_RESOLUTION.x
		and int(png_header.get("height", 0)) == CAPTURE_RESOLUTION.y
		and int(png_header.get("bit_depth", 0)) == 8
		and int(png_header.get("colour_type", -1)) == 2
		and int(png_header.get("interlace", -1)) == 0,
		"%s is exact RGB8 non-interlaced 2560x1440 PNG" % file_name
	)
	var roi_metrics := _measure_roi(image, effect_roi)
	var record := {
		"file": file_name,
		"semantic_state": semantic_state,
		"sha256": FileAccess.get_sha256(path),
		"png_bytes": byte_count,
		"resolution": [actual_size.x, actual_size.y],
		"png_header": png_header,
		"luminance_range": snappedf(float(statistics.get("range", 0.0)), 0.000001),
		"luminance_variance": snappedf(float(statistics.get("variance", 0.0)), 0.000001),
		"effect_roi_pixels": _rect2i_dictionary(effect_roi),
		"effect_roi_peak_luminance": snappedf(float(roi_metrics.get("peak_luminance", 0.0)), 0.000001),
		"camera_transform": _transform_dictionary(_camera.global_transform),
		"camera_fov": _camera.fov,
		"markers": markers.duplicate(true),
	}
	_semantic_frames.append(record)
	_captured_images[file_name] = image
	print(
		"COMBAT_VISUAL_CAPTURED: %s state=%s bytes=%d range=%.5f variance=%.6f roi_peak=%.4f"
		% [
			ProjectSettings.globalize_path(path),
			semantic_state,
			byte_count,
			float(statistics.get("range", 0.0)),
			float(statistics.get("variance", 0.0)),
			float(roi_metrics.get("peak_luminance", 0.0)),
		]
	)


func _validate_fixed_camera(label: String) -> void:
	var active := root.get_camera_3d()
	_check(active == _camera, "%s retains the capture-only camera" % label)
	if active != _camera:
		return
	_check(
		_camera.get_instance_id() == int(_fixed_camera_contract.get("instance_id", 0))
		and _camera.global_transform.is_equal_approx(_fixed_camera_contract.get("transform", Transform3D.IDENTITY))
		and is_equal_approx(_camera.fov, float(_fixed_camera_contract.get("fov", 0.0)))
		and is_equal_approx(_camera.near, float(_fixed_camera_contract.get("near", 0.0)))
		and is_equal_approx(_camera.far, float(_fixed_camera_contract.get("far", 0.0)))
		and _camera.projection == int(_fixed_camera_contract.get("projection", -1))
		and _camera.keep_aspect == int(_fixed_camera_contract.get("keep_aspect", -1))
		and _camera.cull_mask == int(_fixed_camera_contract.get("cull_mask", -1)),
		"%s retains the immutable camera and projection contract" % label
	)
	_check(not _pulse.is_auto_advance_enabled(), "%s retains the manual pulse clock" % label)


func _validate_capture_set() -> void:
	_check(_semantic_frames.size() == CAPTURE_FILES.size(), "exactly seven semantic combat frames were captured")
	_check(_captured_images.size() == CAPTURE_FILES.size(), "all seven frame filenames are unique")
	var hashes := PackedStringArray()
	for index in CAPTURE_FILES.size():
		var file_name := CAPTURE_FILES[index]
		_check(_captured_images.has(file_name), "required combat frame exists: %s" % file_name)
		if index < _semantic_frames.size():
			var record := _semantic_frames[index]
			_check(
				str(record.get("file", "")) == file_name
				and str(record.get("semantic_state", "")) == CAPTURE_STATES[index],
				"frame %d retains its exact file/state inventory" % (index + 1)
			)
			hashes.append(str(record.get("sha256", "")))
	var unique_hashes := {}
	for digest in hashes:
		unique_hashes[digest] = true
	_check(unique_hashes.size() == CAPTURE_FILES.size(), "all seven PNGs have unique SHA-256 digests")

	_validate_effect_pair(0, 1, &"cyan", "baseline_to_cyan_midflight")
	_validate_effect_pair(1, 2, &"cyan", "cyan_midflight_to_critical_impact")
	_validate_effect_pair(2, 3, &"amber", "critical_impact_to_amber_midflight")
	_validate_effect_pair(3, 4, &"amber", "amber_midflight_to_hero_impact")
	_validate_effect_pair(4, 5, &"cyan", "hero_impact_to_lethal_midflight")
	_validate_destruction_pair()


func _validate_effect_pair(
	baseline_index: int,
	effect_index: int,
	style_id: StringName,
	label: String
	) -> void:
	if baseline_index >= _semantic_frames.size() or effect_index >= _semantic_frames.size():
		return
	var first := _captured_images.get(CAPTURE_FILES[baseline_index]) as Image
	var second := _captured_images.get(CAPTURE_FILES[effect_index]) as Image
	if first == null or second == null:
		return
	var roi := _rect2i_from_dictionary(_semantic_frames[effect_index].get("effect_roi_pixels", {}))
	var comparison := _compare_roi(first, second, roi)
	var colour := _measure_effect_colour(second, roi, style_id)
	comparison["style_id"] = String(style_id)
	comparison["effect_colour"] = colour
	_pair_metrics[label] = comparison
	_check(
		float(comparison.get("mean_difference", 0.0)) >= MINIMUM_ROI_MEAN_DIFFERENCE,
		"%s 144x144 ROI mean RGB difference is at least %.3f (%.5f)"
		% [label, MINIMUM_ROI_MEAN_DIFFERENCE, float(comparison.get("mean_difference", 0.0))]
	)
	_check(
		float(comparison.get("changed_fraction", 0.0)) >= MINIMUM_ROI_CHANGED_FRACTION,
		"%s 144x144 ROI changed fraction is at least %.3f (%.4f)"
		% [label, MINIMUM_ROI_CHANGED_FRACTION, float(comparison.get("changed_fraction", 0.0))]
	)
	_check(
		int(colour.get("coloured_pixels", 0)) >= MINIMUM_EFFECT_COLOURED_PIXELS,
		"%s contains at least %d %s effect-coloured pixels (%d)"
		% [label, MINIMUM_EFFECT_COLOURED_PIXELS, style_id, int(colour.get("coloured_pixels", 0))]
	)
	_check(
		float(colour.get("peak_luminance", 0.0)) >= MINIMUM_ROI_PEAK_LUMINANCE,
		"%s effect ROI peak luminance is at least %.2f (%.3f)"
		% [label, MINIMUM_ROI_PEAK_LUMINANCE, float(colour.get("peak_luminance", 0.0))]
	)


func _validate_destruction_pair() -> void:
	if _semantic_frames.size() < 7:
		return
	var inflight := _captured_images.get(CAPTURE_FILES[5]) as Image
	var arrival := _captured_images.get(CAPTURE_FILES[6]) as Image
	if inflight == null or arrival == null:
		return
	var roi := _rect2i_from_dictionary(_semantic_frames[6].get("effect_roi_pixels", {}))
	var comparison := _compare_roi(inflight, arrival, roi)
	_pair_metrics["lethal_inflight_to_arrival_destruction"] = comparison
	_check(
		float(comparison.get("mean_difference", 0.0)) >= MINIMUM_DESTRUCTION_MEAN_DIFFERENCE,
		"destruction target ROI mean difference is at least %.3f (%.5f)"
		% [MINIMUM_DESTRUCTION_MEAN_DIFFERENCE, float(comparison.get("mean_difference", 0.0))]
	)
	_check(
		float(comparison.get("changed_fraction", 0.0)) >= MINIMUM_DESTRUCTION_CHANGED_FRACTION,
		"destruction target ROI changed fraction is at least %.3f (%.4f)"
		% [MINIMUM_DESTRUCTION_CHANGED_FRACTION, float(comparison.get("changed_fraction", 0.0))]
	)
	var roi_metrics := _measure_roi(arrival, roi)
	_check(
		float(roi_metrics.get("peak_luminance", 0.0)) >= MINIMUM_ROI_PEAK_LUMINANCE,
		"lethal-arrival ROI peak luminance is at least %.2f" % MINIMUM_ROI_PEAK_LUMINANCE
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
	var mean := total / float(maxi(sample_count, 1))
	return {
		"range": brightest - darkest,
		"mean": mean,
		"variance": maxf(0.0, total_squared / float(maxi(sample_count, 1)) - mean * mean),
	}


func _measure_roi(image: Image, roi: Rect2i) -> Dictionary:
	var peak_luminance := 0.0
	var mean_luminance := 0.0
	var sample_count := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var luminance := image.get_pixel(x, y).get_luminance()
			peak_luminance = maxf(peak_luminance, luminance)
			mean_luminance += luminance
			sample_count += 1
	return {
		"sample_count": sample_count,
		"peak_luminance": peak_luminance,
		"mean_luminance": mean_luminance / float(maxi(sample_count, 1)),
	}


func _compare_roi(first: Image, second: Image, roi: Rect2i) -> Dictionary:
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
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
		"roi": _rect2i_dictionary(roi),
		"sample_count": sample_count,
		"mean_difference": total_difference / float(maxi(sample_count, 1)),
		"changed_fraction": float(changed_pixels) / float(maxi(sample_count, 1)),
		"changed_pixels": changed_pixels,
		"pixel_change_threshold": PIXEL_CHANGE_THRESHOLD,
	}


func _measure_effect_colour(image: Image, roi: Rect2i, style_id: StringName) -> Dictionary:
	var coloured_pixels := 0
	var peak_luminance := 0.0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var pixel := image.get_pixel(x, y)
			peak_luminance = maxf(peak_luminance, pixel.get_luminance())
			var matches := (
				pixel.g >= pixel.r + 0.05 and pixel.b >= pixel.r + 0.05
				if style_id == &"cyan"
				else pixel.r >= pixel.b + 0.12 and pixel.g >= pixel.b + 0.08
			)
			if matches:
				coloured_pixels += 1
	return {
		"style_id": String(style_id),
		"coloured_pixels": coloured_pixels,
		"minimum_coloured_pixels": MINIMUM_EFFECT_COLOURED_PIXELS,
		"peak_luminance": peak_luminance,
		"colour_rule": (
			"green and blue each exceed red by 0.05"
			if style_id == &"cyan"
			else "red exceeds blue by 0.12 and green exceeds blue by 0.08"
		),
	}


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
	}


func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)


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
	_source_frozen_validated = (
		final_paths == _source_paths
		and final_snapshot == _source_snapshot
		and final_aggregate == _source_aggregate_sha256
	)
	_check(
		_source_frozen_validated,
		"recursive source roster and every declared production byte remain identical through capture"
	)


func _write_source_manifest() -> void:
	var temporary := STAGED_SOURCE_MANIFEST_PATH + ".tmp"
	_remove_file_if_present(temporary, "stale staged source-manifest temporary clears")
	_remove_file_if_present(STAGED_SOURCE_MANIFEST_PATH, "stale staged source manifest clears")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
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
		ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(STAGED_SOURCE_MANIFEST_PATH)
	)
	_check(rename_error == OK, "staged source SHA-256 manifest commits atomically")


func _write_evidence_manifest() -> void:
	var manifest := {
		"schema": "mudds_combat_visual_rendered_evidence_v1",
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
		"source_manifest": SOURCE_MANIFEST_PATH,
		"source_manifest_sha256": FileAccess.get_sha256(STAGED_SOURCE_MANIFEST_PATH),
		"source_aggregate_sha256": _source_aggregate_sha256,
		"source_file_count": _source_paths.size(),
		"source_files": _source_snapshot.duplicate(true),
		"source_unchanged_during_capture": _source_frozen_validated,
		"capture_log_path": CAPTURE_LOG_PATH,
		"capture_log_policy": "External native launcher redirects raw stdout/stderr to this path; the evidence manifest is the transactional green sentinel.",
		"fixed_camera": {
			"name": String(_camera.name),
			"transform": _transform_dictionary(_camera.global_transform),
			"fov": _camera.fov,
			"near": _camera.near,
			"far": _camera.far,
			"frame_margin_fraction": FRAME_MARGIN_FRACTION,
		},
		"manual_pulse_phases": {
			"cyan_midflight_progress": CYAN_MIDFLIGHT_PROGRESS,
			"cyan_arrival_impact_age_seconds": CYAN_IMPACT_AGE,
			"amber_midflight_progress": AMBER_MIDFLIGHT_PROGRESS,
			"amber_arrival_impact_age_seconds": AMBER_IMPACT_AGE,
			"lethal_midflight_progress": LETHAL_MIDFLIGHT_PROGRESS,
			"lethal_arrival_impact_age_seconds": LETHAL_IMPACT_AGE,
		},
		"frames": _semantic_frames,
		"localized_pair_metrics": _pair_metrics,
		"automated_acceptance_thresholds": {
			"minimum_png_bytes": MINIMUM_PNG_BYTES,
			"minimum_luminance_range": MINIMUM_LUMINANCE_RANGE,
			"minimum_luminance_variance": MINIMUM_LUMINANCE_VARIANCE,
			"roi_size_pixels": [ROI_SIZE.x, ROI_SIZE.y],
			"pixel_change_threshold": PIXEL_CHANGE_THRESHOLD,
			"minimum_roi_mean_rgb_difference": MINIMUM_ROI_MEAN_DIFFERENCE,
			"minimum_roi_changed_fraction": MINIMUM_ROI_CHANGED_FRACTION,
			"minimum_effect_coloured_pixels": MINIMUM_EFFECT_COLOURED_PIXELS,
			"minimum_roi_peak_luminance": MINIMUM_ROI_PEAK_LUMINANCE,
			"minimum_destruction_mean_difference": MINIMUM_DESTRUCTION_MEAN_DIFFERENCE,
			"minimum_destruction_changed_fraction": MINIMUM_DESTRUCTION_CHANGED_FRACTION,
		},
		"semantic_chronology_gates": [
			"cyan authority is critical while smoke and impact remain pending in flight",
			"cyan arrival clears receipt, shows impact, and starts critical smoke",
			"amber authority reduces hero hull while detached impact remains pending in flight",
			"amber arrival clears receipt and creates a detached world-space hero impact",
			"lethal authority deactivates health and collision while hull art remains visible in flight",
			"lethal arrival clears receipt, hides hull, and creates a world-owned destruction root at the captured pose",
		],
		"staging_interventions": [
			"Adds one capture-only Camera3D and disables every CanvasLayer.",
			"Repositions production combatants to the established 180,54,-230 test arena and disables their physics navigation.",
			"Calls production GameFlow fire handlers and never calls target damage methods directly.",
			"Disables PulseWeaponPresentation automatic advancement and advances its public deterministic clock to exact photographed phases.",
		],
		"evidence_limits": [
			"These are deterministic staged production-state frames, not an uninterrupted player-controlled dogfight.",
			"Native X11 Forward+ output does not prove native-Windows rendering, native-GPU performance, combat feel, audibility, controller ergonomics, or camera comfort.",
			"Localized pixel and semantic gates reject blank, duplicate, mistimed, weak-colour, and missing-effect captures but do not replace original-resolution human art review.",
			"The Combat V2 presentation is an original modern treatment and is not claimed as authenticated historical Keth weapon art.",
		],
	}
	var temporary := STAGED_EVIDENCE_MANIFEST_PATH + ".tmp"
	_remove_file_if_present(temporary, "stale staged evidence-manifest temporary clears")
	_remove_file_if_present(STAGED_EVIDENCE_MANIFEST_PATH, "stale staged evidence manifest clears")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	_check(file != null, "staged combat evidence manifest opens for writing")
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	_check(write_error == OK, "staged combat evidence manifest flushes without error")
	if write_error != OK:
		return
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(STAGED_EVIDENCE_MANIFEST_PATH)
	)
	_check(rename_error == OK, "staged combat evidence manifest commits atomically")


func _reset_capture_transaction() -> void:
	var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_check(output_error == OK or output_error == ERR_ALREADY_EXISTS, "combat-visual output directory is available")
	_invalidate_published_claims("prior published claim")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TRANSACTION_DIR)):
		_remove_directory_tree(TRANSACTION_DIR)
	var transaction_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRANSACTION_DIR))
	_check(transaction_error == OK or transaction_error == ERR_ALREADY_EXISTS, "fresh isolated combat capture transaction is available")


func _publish_capture_transaction() -> void:
	_invalidate_published_claims("published claim before replacement")
	_remove_stale_capture_files()
	if not _failures.is_empty():
		return
	for file_name in CAPTURE_FILES:
		if not _publish_staged_file(
			TRANSACTION_DIR.path_join(file_name),
			OUTPUT_DIR.path_join(file_name),
			"validated PNG %s" % file_name
		):
			return
	_validate_source_frozen()
	if not _source_frozen_validated or not _failures.is_empty():
		_invalidate_published_claims("source drift at publish boundary")
		return
	if not _publish_staged_file(STAGED_SOURCE_MANIFEST_PATH, SOURCE_MANIFEST_PATH, "source SHA-256 manifest"):
		return
	_verify_published_capture_transaction(STAGED_EVIDENCE_MANIFEST_PATH, "precommit staged")
	if not _failures.is_empty():
		_invalidate_published_claims("failed precommit verification")
		return
	var evidence_temporary := EVIDENCE_MANIFEST_PATH + ".publish.tmp"
	if not _prepare_publish_temporary(STAGED_EVIDENCE_MANIFEST_PATH, evidence_temporary, "evidence sentinel"):
		_invalidate_published_claims("failed evidence preparation")
		return
	_validate_source_frozen()
	if not _source_frozen_validated or not _failures.is_empty():
		_invalidate_published_claims("source drift at final commit")
		return
	if not _commit_prepared_file(evidence_temporary, EVIDENCE_MANIFEST_PATH, "evidence sentinel"):
		_invalidate_published_claims("failed evidence commit")
		return
	_verify_published_capture_transaction(EVIDENCE_MANIFEST_PATH, "postcommit published")
	if not _failures.is_empty():
		_invalidate_published_claims("unverified published claim")
		return
	if not _remove_directory_tree(TRANSACTION_DIR):
		_invalidate_published_claims("unclean capture staging")


func _invalidate_published_claims(context: String) -> void:
	_remove_file_if_present(EVIDENCE_MANIFEST_PATH, "%s evidence sentinel clears" % context)
	_remove_file_if_present(SOURCE_MANIFEST_PATH, "%s source manifest clears" % context)


func _publish_staged_file(source: String, destination: String, label: String) -> bool:
	var temporary := destination + ".publish.tmp"
	if not _prepare_publish_temporary(source, temporary, label):
		return false
	return _commit_prepared_file(temporary, destination, label)


func _prepare_publish_temporary(source: String, temporary: String, label: String) -> bool:
	if not FileAccess.file_exists(source):
		_fail("transaction publish source is missing for %s" % label)
		return false
	var expected_hash := FileAccess.get_sha256(source)
	if expected_hash.is_empty():
		_fail("transaction publish source cannot be hashed for %s" % label)
		return false
	if not _remove_file_if_present(temporary, "stale publish temporary clears for %s" % label):
		return false
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(temporary)
	)
	if copy_error != OK:
		_fail("transaction copy failed for %s: %s" % [label, error_string(copy_error)])
		return false
	if FileAccess.get_sha256(temporary) != expected_hash:
		_fail("transaction copy hash mismatch for %s" % label)
		return false
	return true


func _commit_prepared_file(temporary: String, destination: String, label: String) -> bool:
	if not FileAccess.file_exists(temporary):
		_fail("prepared transaction file is missing for %s" % label)
		return false
	var expected_hash := FileAccess.get_sha256(temporary)
	if not _remove_file_if_present(destination, "old destination clears for %s" % label):
		return false
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(destination)
	)
	if rename_error != OK:
		_fail("transaction commit failed for %s: %s" % [label, error_string(rename_error)])
		return false
	_check(FileAccess.get_sha256(destination) == expected_hash, "published %s is byte-identical to staging" % label)
	return _failures.is_empty()


func _verify_published_capture_transaction(evidence_path: String, phase: String) -> void:
	var actual_pngs := PackedStringArray()
	var import_sidecars := PackedStringArray()
	var directory := DirAccess.open(OUTPUT_DIR)
	_check(directory != null, "%s combat output opens for exact inventory" % phase)
	if directory == null:
		return
	var list_error := directory.list_dir_begin()
	_check(list_error == OK, "%s combat output enumeration begins" % phase)
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
	_check(actual_pngs == expected_pngs, "%s PNG inventory is exactly the declared seven frames" % phase)
	_check(import_sidecars.is_empty(), "%s inventory has no stale PNG import sidecars" % phase)

	var manifest := _read_json(evidence_path)
	var frames := manifest.get("frames", []) as Array
	var exact_frames := frames.size() == CAPTURE_FILES.size()
	var unique_files := {}
	for index in frames.size():
		var record := frames[index] as Dictionary
		var file_name := str(record.get("file", ""))
		unique_files[file_name] = true
		if index >= CAPTURE_FILES.size():
			exact_frames = false
			continue
		var path := OUTPUT_DIR.path_join(CAPTURE_FILES[index])
		exact_frames = (
			exact_frames
			and file_name == CAPTURE_FILES[index]
			and str(record.get("semantic_state", "")) == CAPTURE_STATES[index]
			and str(record.get("sha256", "")) == FileAccess.get_sha256(path)
			and _resolution_matches(record.get("resolution", []))
		)
	_check(
		str(manifest.get("schema", "")) == "mudds_combat_visual_rendered_evidence_v1"
		and int(manifest.get("frame_count", 0)) == CAPTURE_FILES.size()
		and _string_inventory_matches(manifest.get("frame_inventory", []), CAPTURE_FILES)
		and _string_inventory_matches(
			manifest.get("semantic_state_inventory", []), CAPTURE_STATES
		)
		and unique_files.size() == CAPTURE_FILES.size()
		and exact_frames,
		"%s evidence manifest authenticates exact ordered state/file/hash inventory" % phase
	)
	_check(
		FileAccess.file_exists(SOURCE_MANIFEST_PATH)
		and str(manifest.get("source_manifest_sha256", "")) == FileAccess.get_sha256(SOURCE_MANIFEST_PATH)
		and bool(manifest.get("source_unchanged_during_capture", false))
		and str(manifest.get("source_aggregate_sha256", "")) == _source_aggregate_sha256
		and manifest.get("source_files", {}) == _source_snapshot,
		"%s manifest authenticates the frozen source roster and published source manifest" % phase
	)


func _remove_stale_capture_files() -> void:
	var directory := DirAccess.open(OUTPUT_DIR)
	_check(directory != null, "combat output opens for bounded stale-file cleanup")
	if directory == null:
		return
	var removable := PackedStringArray()
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and (
			entry.ends_with(".png")
			or entry.ends_with(".png.import")
			or entry.ends_with(".publish.tmp")
		):
			removable.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	for file_name in removable:
		_remove_file_if_present(OUTPUT_DIR.path_join(file_name), "bounded stale combat file clears: %s" % file_name)


func _remove_file_if_present(path: String, description: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		_fail("refusing to remove directory where a transaction file was expected: %s" % path)
		return false
	if not FileAccess.file_exists(path):
		return true
	var error := DirAccess.remove_absolute(absolute)
	_check(error == OK, description)
	return error == OK


func _remove_directory_tree(path: String) -> bool:
	if path != TRANSACTION_DIR and not path.begins_with(TRANSACTION_DIR + "/"):
		_fail("refusing broad transaction cleanup outside %s: %s" % [TRANSACTION_DIR, path])
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
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
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name))) != OK:
			_fail("transaction file cleanup failed: %s" % path.path_join(file_name))
			valid = false
	for directory_name in directories:
		valid = _remove_directory_tree(path.path_join(directory_name)) and valid
	if DirAccess.remove_absolute(absolute) != OK:
		_fail("transaction directory cleanup failed: %s" % path)
		valid = false
	return valid


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _string_inventory_matches(actual_value: Variant, expected: Array[String]) -> bool:
	if actual_value is not Array:
		return false
	var actual := actual_value as Array
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if str(actual[index]) != expected[index]:
			return false
	return true


func _resolution_matches(actual_value: Variant) -> bool:
	if actual_value is not Array:
		return false
	var actual := actual_value as Array
	return (
		actual.size() == 2
		and int(actual[0]) == CAPTURE_RESOLUTION.x
		and int(actual[1]) == CAPTURE_RESOLUTION.y
	)


func _rect2i_dictionary(rect: Rect2i) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _rect2i_from_dictionary(value: Variant) -> Rect2i:
	var record := value as Dictionary
	return Rect2i(
		int(record.get("x", 0)),
		int(record.get("y", 0)),
		int(record.get("width", 0)),
		int(record.get("height", 0))
	)


func _transform_dictionary(value: Transform3D) -> Dictionary:
	return {
		"origin": _vector3_array(value.origin),
		"basis_x": _vector3_array(value.basis.x),
		"basis_y": _vector3_array(value.basis.y),
		"basis_z": _vector3_array(value.basis.z),
	}


func _vector3_array(value: Vector3) -> Array[float]:
	return [
		snappedf(value.x, 0.000001),
		snappedf(value.y, 0.000001),
		snappedf(value.z, 0.000001),
	]


func _settle_render(frame_count: int) -> void:
	for _index in frame_count:
		await process_frame


func _dispose_game() -> void:
	if is_instance_valid(_game):
		_game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("COMBAT_VISUAL_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	if not _failures.has(description):
		_failures.append(description)
	push_error("COMBAT_VISUAL_FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"MUDDS_COMBAT_VISUAL_CAPTURE_OK: %d HUD-free source-frozen native X11 Forward+ frames at %dx%d"
			% [_semantic_frames.size(), CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
		)
		quit(0)
	else:
		_invalidate_published_claims("failed capture")
		push_error("MUDDS_COMBAT_VISUAL_CAPTURE_FAILED: " + "; ".join(_failures))
		quit(1)
