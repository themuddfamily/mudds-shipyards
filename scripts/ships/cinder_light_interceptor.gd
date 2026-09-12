class_name CinderLightInterceptor
extends HeroShip

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const SHIP_DEFINITION_TEMPLATE: ShipDefinition = preload(
	"res://assets/ships/cinder_light_interceptor_new_design.tres"
)

## Original-modern lightweight interceptor. No historical craft, weapon, or
## combat claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder_light_interceptor"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder light interceptor"
const HULL_SIZE := Vector3(4.8, 2.5, 8.8)
const HULL_COLOR := Color("6d7777")
const CANOPY_COLOR := Color("315b68")
const CANOPY_POSITION := Vector3(0.0, 1.505, -3.0)
const CANOPY_SCALE := Vector3.ONE
## The fixed cockpit support origin is retained; a continuous shoulder now
## ramps from the nose into the floor platform and back down to the aft hull.
const COCKPIT_FAIRING_POSITION := Vector3(0.0, 1.56, -0.2)
const WING_COLOR := Color("273641")
## Upper starboard aft shoulder: the full lens clears the hull silhouette in Y
## and the centreline recognition fin in X when viewed from behind the craft.
const ENGINE_DAMAGE_BEACON_POSITION := Vector3(1.9, 1.54, 3.82)
## Failure reuses the retained engine-bay beacon lens as a tall, static vane.
## That change in outline remains legible when its red emission is not, while
## the nominal/impaired lens keeps its exact compact authored pose.
const ENGINE_DAMAGE_BEACON_NOMINAL_SCALE := Vector3.ONE
const ENGINE_DAMAGE_BEACON_FAILED_SCALE := Vector3(1.35, 3.4, 1.0)
const ENGINE_DAMAGE_IMPAIRED_COLOR := Color("ffd166")
const ENGINE_DAMAGE_FAILED_COLOR := Color("ff4b3e")
const AFT_RECOGNITION_FIN_SIZE := Vector3(2.7, 1.8, 0.32)
const AFT_RECOGNITION_FIN_POSITION := Vector3(0.0, 1.2, 2.45)
const AFT_RECOGNITION_FIN_ROTATION_Y := PI * 0.5
## Mirrored outboard response rails and blades give the lightweight craft a
## fast, directional planform at normal chase distance. Their transformed
## bounds stay inside the existing 12 m wing, 8.8 m hull and 2.5 m hull-height
## envelope: this is presentation detail, not a new berth-fit claim.
const SPEED_RAIL_SIZE := Vector3(3.2, 0.28, 0.32)
# The deeper rail section seats below the skin while its crown clears the
# service armor. A shallow mirrored span slope follows
# its falling outboard skin, including the rail's thin terminal edges.
const SPEED_RAIL_OFFSET := Vector3(4.25, 0.02, 0.35)
const SPEED_RAIL_SWEEP_DEGREES := 22.0
const WINGTIP_BLADE_SIZE := Vector3(0.28, 0.78, 2.6)
const WINGTIP_BLADE_OFFSET := Vector3(5.52, 0.225, 0.72)
const WINGTIP_BLADE_CANT_DEGREES := 10.0
const WEAPON_ID: StringName = &"cinder_light_repeater"
const CONSOLE_TOGGLE_VISIBLE_COPIES := 8
const CONSOLE_TOGGLE_LEGACY_SUBMISSIONS := 8
const CONSOLE_TOGGLE_BATCH_SUBMISSIONS := 1
const CONSOLE_TOGGLE_NAMES := [
	"PortConsoleToggle00",
	"PortConsoleToggle01",
	"PortConsoleToggle02",
	"PortConsoleToggle03",
	"StarboardConsoleToggle00",
	"StarboardConsoleToggle01",
	"StarboardConsoleToggle02",
	"StarboardConsoleToggle03",
]
const CONSOLE_KEY_VISIBLE_COPIES := 4
const CONSOLE_KEY_LEGACY_SUBMISSIONS := 4
const CONSOLE_KEY_BATCH_SUBMISSIONS := 1
const CONSOLE_KEY_NAMES := [
	"PortConsoleKey00",
	"PortConsoleKey02",
	"StarboardConsoleKey00",
	"StarboardConsoleKey02",
]
const CONSOLE_CENTER_KEY_VISIBLE_COPIES := 2
const CONSOLE_CENTER_KEY_LEGACY_SUBMISSIONS := 2
const CONSOLE_CENTER_KEY_BATCH_SUBMISSIONS := 1
const CONSOLE_CENTER_KEY_NAMES := [
	"PortConsoleKey01",
	"StarboardConsoleKey01",
]
const STATUS_REPEATER_VISIBLE_COPIES := 2
const STATUS_REPEATER_LEGACY_SUBMISSIONS := 2
const STATUS_REPEATER_BATCH_SUBMISSIONS := 1
const STATUS_REPEATER_NAMES := [
	"PortStatusRepeater",
	"StarboardStatusRepeater",
]

# The primary hull is immutable presentation stock. Fleet composition and ship
# replacement can briefly retain multiple interceptors, so cache this exact
# recipe across copies while renderer nodes, submissions, transforms, collision,
# and all gameplay authority remain per craft.
static var _shared_hull_mesh: ArrayMesh
static var _shared_hull_material: StandardMaterial3D
# The broad response wing is likewise immutable exterior presentation stock.
# Sharing its exact mesh and finish across briefly coexisting fleet copies saves
# duplicate resources without merging renderer nodes or changing submissions.
static var _shared_wing_mesh: ArrayMesh
static var _shared_wing_material: StandardMaterial3D
# The swept aft fin makes the interceptor's heading readable in profile. It is
# immutable visual stock, shared across briefly coexisting fleet copies without
# adding collision, damage routing, or lifecycle ownership.
static var _shared_aft_recognition_fin_mesh: ArrayMesh
static var _shared_speed_rail_mesh: ArrayMesh
static var _shared_speed_rail_material: StandardMaterial3D
static var _shared_wingtip_blade_mesh: ArrayMesh
# The small optical panel keeps the legacy Canopy renderer identity while the
# inherited cockpit retains the operable transparent canopy and pilot rig.
# This fitted pane replaces the redundant opaque bubble on the former nose.
static var _shared_canopy_mesh: ArrayMesh
static var _shared_canopy_material: StandardMaterial3D
static var _shared_cockpit_fairing_mesh: ArrayMesh

static var _shared_engine_exhaust_mesh: WeakRef

var _interceptor_boarding_marker: Marker3D
var _interceptor_built := false
var _weapon_definition: WeaponDefinition
var _ship_perspective_audio_binding: RefCounted
var _console_toggle_batch: MultiMeshInstance3D
var _console_key_batch: MultiMeshInstance3D
var _console_center_key_batch: MultiMeshInstance3D
var _status_repeater_batch: MultiMeshInstance3D
var _engine_damage_beacon_lens: MeshInstance3D
var _engine_damage_beacon_light: OmniLight3D
var _engine_damage_beacon_material: StandardMaterial3D
var _speed_rail_batch: MultiMeshInstance3D
var _wingtip_blade_batch: MultiMeshInstance3D

func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_cinder_interceptor_perspective_audio")


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	# Production composition instantiates this script directly rather than a
	# packed scene, so the authored handling resource must be installed here
	# before HeroShip consumes it. A per-craft copy prevents one live instance or
	# test probe from mutating the template used by another generation.
	ship_definition = SHIP_DEFINITION_TEMPLATE.duplicate(true) as ShipDefinition
	_weapon_definition = _build_weapon_definition()
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Light interceptor"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_cinder_interceptor_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not _interceptor_built:
		_interceptor_built = rebuild_variant_presentation(_build_interceptor_variant)
	if not component_damage_changed.is_connected(_on_interceptor_component_damage_changed):
		component_damage_changed.connect(_on_interceptor_component_damage_changed)
	_sync_engine_damage_beacon()

func _exit_tree() -> void:
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_cinder_interceptor_camera_view_changed):
			camera_view_changed.disconnect(_on_cinder_interceptor_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	super._exit_tree()

func _rebind_cinder_interceptor_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null or _ship_audio_rig == null:
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) and not camera_view_changed.is_connected(_on_cinder_interceptor_camera_view_changed):
		camera_view_changed.connect(_on_cinder_interceptor_camera_view_changed)

func _on_cinder_interceptor_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)

func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() if _ship_perspective_audio_binding != null else {"attached": false}


func _build_interceptor_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderInterceptorVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_batch_console_toggles(visual)
	_batch_console_keys(visual)
	_batch_console_center_keys(visual)
	_batch_status_repeaters(visual)
	_build_hull(visual)
	_build_engine_exhaust(visual)
	_build_speed_silhouette(visual)
	_build_engine_damage_beacon(visual)
	_build_boarding_marker(visual)
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _interceptor_boarding_marker


## Returns a defensive copy of the interceptor's explicit modern combat role.
## Shared combat resolution remains outside this presentation/flight component.
func get_weapon_definition() -> WeaponDefinition:
	return _weapon_definition.duplicate(true) as WeaponDefinition if _weapon_definition != null else null


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var speed_silhouette := get_speed_silhouette_visual_audit()
	if not _interceptor_built:
		errors.append("interceptor has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_interceptor_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if not bool(get_landing_collision_report().get("valid", false)):
		errors.append("interceptor requires HeroShip root collision")
	if not bool(speed_silhouette.get("valid", false)):
		errors.append("interceptor speed-silhouette presentation drifted")
	if ship_definition == null \
			or not ship_definition.is_definition_valid() \
			or ship_definition.get_ship_id() != COMPONENT_ID:
		errors.append("authored interceptor flight definition is not applied")
	if _weapon_definition == null \
			or not _weapon_definition.is_definition_valid() \
			or _weapon_definition.weapon_id != WEAPON_ID \
			or not is_equal_approx(
				_weapon_definition.cadence_shots_per_second,
				1.0 / maxf(weapon_cooldown, 0.001)
			):
		errors.append("rapid repeater definition disagrees with the live fire gate")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"combat_authority": false,
		"weapon_authority": false,
		"weapon_definition_valid": _weapon_definition != null and _weapon_definition.is_definition_valid(),
		"weapon_id": WEAPON_ID,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
		"speed_silhouette_visual": speed_silhouette,
	}.duplicate(true)


## Detached audit for the presentation-only recognition batches. Structural
## submissions are reported as renderer surfaces, not as a driver draw-call
## claim; collision, lights and gameplay authority remain explicitly absent.
func get_speed_silhouette_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var rails := visual.get_node_or_null(^"InterceptorSpeedRailBatch") as MultiMeshInstance3D \
			if visual != null else null
	var blades := visual.get_node_or_null(^"InterceptorWingtipBladeBatch") as MultiMeshInstance3D \
			if visual != null else null
	if rails == null or rails.multimesh == null:
		errors.append("mirrored speed-rail batch is missing")
	else:
		if rails != _speed_rail_batch \
				or rails.multimesh.mesh != _shared_speed_rail_mesh \
				or rails.material_override != _shared_speed_rail_material:
			errors.append("speed-rail immutable resource identity drifted")
		if rails.multimesh.instance_count != 2 \
				or rails.multimesh.visible_instance_count != 2 \
				or not rails.visible \
				or rails.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			errors.append("speed-rail renderer state drifted")
		if rails.get_child_count() != 0 or rails.get_script() != null:
			errors.append("speed rails gained semantic children or authority")
	if blades == null or blades.multimesh == null:
		errors.append("mirrored wingtip-blade batch is missing")
	else:
		if blades != _wingtip_blade_batch \
				or blades.multimesh.mesh != _shared_wingtip_blade_mesh \
				or blades.material_override != _shared_wing_material:
			errors.append("wingtip-blade immutable resource identity drifted")
		if blades.multimesh.instance_count != 2 \
				or blades.multimesh.visible_instance_count != 2 \
				or not blades.visible \
				or blades.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("wingtip-blade renderer state drifted")
		if blades.get_child_count() != 0 or blades.get_script() != null:
			errors.append("wingtip blades gained semantic children or authority")
	if _shared_speed_rail_mesh == null \
			or not _shared_speed_rail_mesh.get_aabb().size.is_equal_approx(SPEED_RAIL_SIZE) \
			or _shared_speed_rail_mesh.resource_local_to_scene:
		errors.append("speed-rail mesh recipe drifted")
	if _shared_wingtip_blade_mesh == null \
			or not _shared_wingtip_blade_mesh.get_aabb().size.is_equal_approx(WINGTIP_BLADE_SIZE) \
			or _shared_wingtip_blade_mesh.resource_local_to_scene:
		errors.append("wingtip-blade mesh recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"renderer_nodes_per_copy": int(rails != null) + int(blades != null),
		"geometry_submissions_per_copy": 2 if rails != null and blades != null else 0,
		"rail_instances_per_copy": rails.multimesh.instance_count if rails != null and rails.multimesh != null else 0,
		"blade_instances_per_copy": blades.multimesh.instance_count if blades != null and blades.multimesh != null else 0,
		"lights": 0,
		"collision_shapes": 0,
		"gameplay_authority": false,
	}.duplicate(true)


func _build_weapon_definition() -> WeaponDefinition:
	var definition := WeaponDefinitionType.new() as WeaponDefinition
	definition.weapon_id = WEAPON_ID
	definition.display_name = "Cinder rapid repeater"
	definition.resolution_mode = WeaponDefinition.ResolutionMode.HITSCAN
	definition.evidence_status = WeaponDefinition.EvidenceStatus.NEW
	definition.evidence_notes = "Original-modern lightweight interceptor tuning; not a recovered historical weapon specification."
	definition.range_meters = 320.0
	definition.damage_per_hit = 18.0
	definition.cadence_shots_per_second = (
		1.0 / maxf(ship_definition.weapon_cooldown, 0.001)
		if ship_definition != null else 1.0 / 0.28
	)
	# The first production slice deliberately reuses the bounded cyan pulse pool
	# and resident player fire/impact bank. These IDs describe what the running
	# game actually presents; no parallel effect or audio authority is implied.
	definition.presentation_id = &"cyan"
	definition.fire_audio_id = &"player_pulse_fire"
	definition.impact_audio_id = &"hull_impact_medium"
	definition.dry_fire_audio_id = &"dry_fire_click"
	return definition


func _build_collision() -> void:
	_add_box_collision_shape("InterceptorHullCollision", Vector3.ZERO, HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var sill_finish := _material(Color("586569"), 0.48, 0.42)
	for sill_name in ["PortSill", "StarboardSill"]:
		var sill := visual.find_child(sill_name, true, false) as MeshInstance3D
		if sill != null:
			sill.material_override = sill_finish
	var hull := MeshInstance3D.new()
	hull.name = "HighVisibilityHull"
	if _shared_hull_mesh == null:
		_shared_hull_mesh = _formed_pressure_mesh(Vector3(3.7, 2.1, HULL_SIZE.z), null, false, true)
		_shared_hull_mesh.resource_local_to_scene = false
	if _shared_hull_material == null:
		_shared_hull_material = _material(HULL_COLOR, 0.12, 0.62)
		ShipSurfaceDetail.bind_manufactured_paint(_shared_hull_material)
		# Satin freight/combat coating retains grain without broad glossy scuff patches.
		_shared_hull_material.roughness = 0.72
		_shared_hull_material.clearcoat_enabled = false
		_shared_hull_material.vertex_color_use_as_albedo = true
		_shared_hull_material.uv1_triplanar = true
		_shared_hull_material.uv1_scale = Vector3.ONE * 0.33
		_shared_hull_material.resource_local_to_scene = false
	hull.mesh = _shared_hull_mesh
	hull.material_override = _shared_hull_material
	visual.add_child(hull)
	var cockpit_fairing := MeshInstance3D.new()
	cockpit_fairing.name = "ClosedCockpitFairing"
	if _shared_cockpit_fairing_mesh == null:
		_shared_cockpit_fairing_mesh = _cockpit_shoulder_mesh(COCKPIT_FAIRING_POSITION, 1.04, 3.55, null)
		_shared_cockpit_fairing_mesh.resource_local_to_scene = false
	cockpit_fairing.mesh = _shared_cockpit_fairing_mesh
	cockpit_fairing.position = COCKPIT_FAIRING_POSITION
	cockpit_fairing.material_override = _shared_hull_material
	cockpit_fairing.set_meta(&"visual_detail_only", true)
	cockpit_fairing.set_meta(&"presentation_only", true)
	cockpit_fairing.set_meta(&"gameplay_authority", false)
	visual.add_child(cockpit_fairing)
	var wing := MeshInstance3D.new()
	wing.name = "RapidResponseWing"
	if _shared_wing_mesh == null:
		_shared_wing_mesh = _formed_aero_mesh(Vector3(12.0, 0.55, 5.8))
		_shared_wing_mesh.resource_local_to_scene = false
	if _shared_wing_material == null:
		_shared_wing_material = _material(WING_COLOR, 0.12, 0.62)
		_shared_wing_material.resource_local_to_scene = false
	wing.mesh = _shared_wing_mesh
	wing.position = Vector3(0.0, -0.15, 0.55)
	wing.material_override = _shared_wing_material
	visual.add_child(wing)
	var aft_fin := MeshInstance3D.new()
	aft_fin.name = "AftRecognitionFin"
	if _shared_aft_recognition_fin_mesh == null:
		_shared_aft_recognition_fin_mesh = _formed_recognition_fin_mesh()
		_shared_aft_recognition_fin_mesh.resource_local_to_scene = false
	aft_fin.mesh = _shared_aft_recognition_fin_mesh
	aft_fin.position = AFT_RECOGNITION_FIN_POSITION
	aft_fin.rotation.y = AFT_RECOGNITION_FIN_ROTATION_Y
	aft_fin.material_override = _shared_wing_material
	aft_fin.set_meta(&"visual_detail_only", true)
	visual.add_child(aft_fin)
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	if _shared_canopy_mesh == null:
		_shared_canopy_mesh = _pressure_mesh(0.95, 0.82, 0.40, 0.035, null)
		_shared_canopy_mesh.resource_local_to_scene = false
	if _shared_canopy_material == null:
		_shared_canopy_material = _material(CANOPY_COLOR, 0.75, 0.18)
		_shared_canopy_material.resource_local_to_scene = false
	canopy.mesh = _shared_canopy_mesh
	canopy.position = CANOPY_POSITION
	canopy.scale = CANOPY_SCALE
	canopy.rotation.x = deg_to_rad(49.0)
	canopy.material_override = _shared_canopy_material
	visual.add_child(canopy)
	_build_interceptor_propulsion(visual)
	for side in [-1.0, 1.0]:
		# Centre the shallow projection on the rolled shoulder's 45-degree arc.
		ShipSurfaceDetail.mark_surface(visual, "PressureHullRegistration" + str(side), "cinder-interceptor", Vector3(side * 1.555, 1.590, -0.42), Vector2(1.8, 0.9), Vector3(side * 0.807, 0.591, 0), Vector3.UP, 0.32)
	ShipSurfaceDetail.mark_surface(visual, "AftServiceMark", "service", Vector3(0.92, 0.99, 3.45), Vector2(1.25, 0.625), Vector3(0, 1, 0.14), Vector3.FORWARD)


## The propulsion booms bridge the swept pressure shell and wing with an open
## maintenance channel. Exhaust bells are hollow, with recessed hot throats.
func _build_interceptor_propulsion(visual: Node3D) -> void:
	var titanium := _material(Color("69727a"), 0.82, 0.29)
	var ceramic := _material(Color("15222b"), 0.45, 0.48)
	for side in [-1.0, 1.0]:
		var plate := _pressure_panel(visual, "DorsalServiceArmor" + str(side), Vector3(side * 0.82, 1.073, 2.2), 0.65, 0.72, 1.65, 0.045, ceramic)
		plate.rotation.x = PI * 0.5

	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		_service_bay(visual, tag + "InductionDuct", Vector3(side * 2.1, 0.92, 1.0), 0.68, 1.1, _shared_hull_material, ceramic, titanium)
		var nacelle_size := Vector3(1.26, 1.34, 5.8)
		_armor_shell(visual, tag + "IntakeShoulder", Vector3(side * 2.1, 0.22, 0.0),
			nacelle_size, _shared_hull_material, 0.0,
			_formed_pressure_mesh(nacelle_size, _shared_hull_material, true))
		_armor_shell(visual, tag + "EngineBoom", Vector3(side * 3.45, 0.0, 1.05),
			Vector3(1.6, 0.38, 4.4), ceramic, side * -0.08, _formed_root_mesh(side, ceramic))
		_cylinder(visual, tag + "TurbineCase", Vector3(side * 2.1, 0.2, 3.65), 0.60, 1.5, titanium, Vector3(90, 0, 0))
		preload("res://scripts/ships/cinder_exhaust_machinery.gd").bell(visual, tag + "ExhaustBell", Vector3(side * 2.1, 0.2, 4.80), 0.72, 0.48, 0.65, ceramic)
		_cylinder(visual, tag + "RecessedThroat", Vector3(side * 2.1, 0.2, 4.52), 0.39, 0.08, ceramic, Vector3(90, 0, 0))
		_engine_mechanics(visual, tag, Vector3(side * 2.1, 0.2, 4.98), 0.62, titanium, ceramic)
		var intake := Node3D.new()
		intake.name = tag + "InductionMouth"
		# Seat the retained louvered mouth on the new full inlet bulkhead.
		intake.position = Vector3(side * 2.1, 0.22, -2.93)
		intake.rotation.x = -PI * 0.5
		visual.add_child(intake)
		_service_bay(intake, "Intake", Vector3.ZERO, 0.69, 0.55, titanium, ceramic, ceramic)
		_deck_plate(visual, tag + "RootService", Vector3(side * 2.09, 0.913, 1.99), 0.85, 0.64, _shared_hull_material, ceramic)
		_armor_shell(visual, tag + "CannonMount", Vector3(side * 3.15, 0.08, -0.50), Vector3(0.58, 0.38, 2.85), ceramic)
		_cylinder(visual, tag + "CannonSleeve", Vector3(side * 3.15, 0.05, -1.90), 0.16, 0.58, titanium, Vector3(90, 0, 0))
		_frustum(visual, tag + "CannonBore", Vector3(side * 3.15, 0.05, -2.23), 0.19, 0.14, 0.18, ceramic, Vector3(90, 0, 0), false, false)
		# A recessed, fitted lens supplies the inherited static weapon damage cue.
		# Shot-clearance markers retain their existing combat-authoritative pose.
		var lens := _cylinder(visual, tag + "MuzzleLens", Vector3(side * 3.15, 0.05, -2.30), 0.105, 0.012, _materials.cyan, Vector3(90, 0, 0))
		lens.set_meta("presentation_only", true)
		lens.set_meta("gameplay_authority", false)
		# A continuous load-spreading cover runs under all three service lids.
		# Its skirt embeds in the wing; the inboard edge meets the engine boom.
		var armor := _armor_shell(visual, tag + "WingArmor", Vector3(side * 4.05, 0.1, 0.75),
			Vector3(1.65, 0.065, 2.4), _shared_hull_material)
		armor.mesh = _wing_fitting_mesh(armor.position, 1.65, 2.4, -0.014, 0.083, 0.13, _shared_hull_material, side)
		# The wider forward gap leaves the structural response rail clear of lids.
		var stations := [-0.2, 0.6, 1.4]
		for index in stations.size():
			_wing_service_plate(visual, tag + "WingService" + str(stations[index]),
				Vector3(side * 4.39, 0.13, [-0.08, 0.90, 1.48][index]), 0.61, 0.43, _shared_wing_material, ceramic)



func _build_speed_silhouette(visual: Node3D) -> void:
	if _shared_speed_rail_mesh == null:
		_shared_speed_rail_mesh = _formed_aero_mesh(SPEED_RAIL_SIZE)
		_shared_speed_rail_mesh.resource_local_to_scene = false
	if _shared_speed_rail_material == null:
		_shared_speed_rail_material = _material(
			Color("87959b"), 0.68, 0.32
		)
		_shared_speed_rail_material.resource_local_to_scene = false
	var rail_transforms: Array[Transform3D] = [
		Transform3D(
			Basis(Vector3.UP, deg_to_rad(SPEED_RAIL_SWEEP_DEGREES)),
			Vector3(-SPEED_RAIL_OFFSET.x, SPEED_RAIL_OFFSET.y, SPEED_RAIL_OFFSET.z)
		),
		Transform3D(
			Basis(Vector3.UP, deg_to_rad(-SPEED_RAIL_SWEEP_DEGREES)),
			SPEED_RAIL_OFFSET
		),
	]
	# Keep one immutable rail mesh while each side follows the wing crown.
	# This shear preserves the exact X/Z planform; the shallow end closures
	# now embed into the wing instead of floating above it by up to 15 cm.
	rail_transforms[0].basis.x.y = 0.04
	rail_transforms[1].basis.x.y = -0.04
	_speed_rail_batch = _build_visual_batch(
		"InterceptorSpeedRailBatch",
		_shared_speed_rail_mesh,
		_shared_speed_rail_material,
		rail_transforms,
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	visual.add_child(_speed_rail_batch)

	if _shared_wingtip_blade_mesh == null:
		_shared_wingtip_blade_mesh = _formed_aero_mesh(WINGTIP_BLADE_SIZE, true)
		_shared_wingtip_blade_mesh.resource_local_to_scene = false
	var blade_transforms: Array[Transform3D] = [
		Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(-WINGTIP_BLADE_CANT_DEGREES)),
			Vector3(-WINGTIP_BLADE_OFFSET.x, WINGTIP_BLADE_OFFSET.y, WINGTIP_BLADE_OFFSET.z)
		),
		Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(WINGTIP_BLADE_CANT_DEGREES)),
			WINGTIP_BLADE_OFFSET
		),
	]
	_wingtip_blade_batch = _build_visual_batch(
		"InterceptorWingtipBladeBatch",
		_shared_wingtip_blade_mesh,
		_shared_wing_material,
		blade_transforms,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	visual.add_child(_wingtip_blade_batch)


func _build_visual_batch(
	batch_name: String,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D],
	shadow_setting: GeometryInstance3D.ShadowCastingSetting
	) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multi
	batch.material_override = material
	batch.cast_shadow = shadow_setting
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"gameplay_authority", false)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	return batch


## A static, exterior-readable consequence of the existing engine-bay ledger.
## The beacon observes component state only: it owns no health, timing, repair,
## movement, collision, or damage decision and therefore remains safe across
## detach/re-entry and the inherited whole-craft reuse transaction.
func _build_engine_damage_beacon(visual: Node3D) -> void:
	_engine_damage_beacon_lens = MeshInstance3D.new()
	_engine_damage_beacon_lens.name = "EngineDamageBeaconLens"
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.24
	lens_mesh.height = 0.48
	_engine_damage_beacon_material = _material(
		ENGINE_DAMAGE_IMPAIRED_COLOR.darkened(0.72),
		0.08,
		0.22,
		ENGINE_DAMAGE_IMPAIRED_COLOR,
		0.0
	)
	_engine_damage_beacon_material.emission_enabled = true
	lens_mesh.material = _engine_damage_beacon_material
	_engine_damage_beacon_lens.mesh = lens_mesh
	_engine_damage_beacon_lens.position = ENGINE_DAMAGE_BEACON_POSITION
	_engine_damage_beacon_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_engine_damage_beacon_lens.set_meta(&"presentation_only", true)
	_engine_damage_beacon_lens.set_meta(&"damage_authority", false)
	_engine_damage_beacon_lens.set_meta(&"animated", false)
	visual.add_child(_engine_damage_beacon_lens)

	_engine_damage_beacon_light = OmniLight3D.new()
	_engine_damage_beacon_light.name = "EngineDamageBeaconLight"
	_engine_damage_beacon_light.position = ENGINE_DAMAGE_BEACON_POSITION
	_engine_damage_beacon_light.omni_range = 4.8
	_engine_damage_beacon_light.shadow_enabled = false
	_engine_damage_beacon_light.set_meta(&"presentation_only", true)
	_engine_damage_beacon_light.set_meta(&"damage_authority", false)
	_engine_damage_beacon_light.set_meta(&"reduced_flash_safe", true)
	_engine_damage_beacon_light.set_meta(&"animated", false)
	visual.add_child(_engine_damage_beacon_light)


func _on_interceptor_component_damage_changed(
		component_id: StringName,
		state: int,
		_integrity: float
	) -> void:
	if component_id == ShipComponentDamage.COMPONENT_ENGINE_BAY:
		_apply_engine_damage_beacon_state(state)


func _sync_engine_damage_beacon() -> void:
	var model := get_component_damage()
	if model == null or not model.is_configured():
		_apply_engine_damage_beacon_state(ShipComponentDamage.ComponentState.NOMINAL)
		return
	_apply_engine_damage_beacon_state(
		model.get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY)
	)


func _apply_engine_damage_beacon_state(state: int) -> void:
	if not is_instance_valid(_engine_damage_beacon_lens) \
			or not is_instance_valid(_engine_damage_beacon_light) \
			or _engine_damage_beacon_material == null:
		return
	var colour := ENGINE_DAMAGE_IMPAIRED_COLOR
	var energy := 0.0
	var lens_scale := ENGINE_DAMAGE_BEACON_NOMINAL_SCALE
	match state:
		ShipComponentDamage.ComponentState.IMPAIRED:
			energy = 3.2
		ShipComponentDamage.ComponentState.FAILED:
			colour = ENGINE_DAMAGE_FAILED_COLOR
			energy = 5.0
			lens_scale = ENGINE_DAMAGE_BEACON_FAILED_SCALE
	_engine_damage_beacon_material.albedo_color = colour.darkened(0.72)
	_engine_damage_beacon_material.emission = colour
	_engine_damage_beacon_material.emission_energy_multiplier = energy
	_engine_damage_beacon_lens.position = ENGINE_DAMAGE_BEACON_POSITION
	_engine_damage_beacon_lens.scale = lens_scale
	_engine_damage_beacon_lens.visible = energy > 0.0
	_engine_damage_beacon_light.light_color = colour
	_engine_damage_beacon_light.light_energy = energy * 0.48
	_engine_damage_beacon_light.visible = energy > 0.0


## The inherited cockpit's eight toggles are childless visual dressing. Their
## authored names and local transforms remain inspectable on the one batch;
## functional cockpit, command, canopy, weapon, and damage nodes are untouched.
func _batch_console_toggles(visual: Node3D) -> void:
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit == null:
		return
	var toggles: Array[MeshInstance3D] = []
	for toggle_name in CONSOLE_TOGGLE_NAMES:
		var toggle := cockpit.get_node_or_null(toggle_name) as MeshInstance3D
		if toggle == null or toggle.get_child_count() != 0 or toggle.mesh == null:
			return
		toggles.append(toggle)
	var source := toggles[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for toggle in toggles:
		if (
			toggle.mesh.get_class() != source_mesh.get_class()
			or toggle.mesh.get_aabb() != source_mesh.get_aabb()
			or toggle.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(toggle) != source_material
			or toggle.cast_shadow != source.cast_shadow
			or toggle.layers != source.layers
			or toggle.extra_cull_margin != source.extra_cull_margin
			or toggle.visibility_range_begin != source.visibility_range_begin
			or toggle.visibility_range_end != source.visibility_range_end
			or toggle.visibility_range_begin_margin != source.visibility_range_begin_margin
			or toggle.visibility_range_end_margin != source.visibility_range_end_margin
			or toggle.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for toggle in toggles:
		transforms.append(toggle.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_console_toggle_batch = MultiMeshInstance3D.new()
	_console_toggle_batch.name = "CinderConsoleToggleBatch"
	_console_toggle_batch.multimesh = multi
	_console_toggle_batch.material_override = source.material_override
	_console_toggle_batch.cast_shadow = source.cast_shadow
	_console_toggle_batch.layers = source.layers
	_console_toggle_batch.extra_cull_margin = source.extra_cull_margin
	_console_toggle_batch.visibility_range_begin = source.visibility_range_begin
	_console_toggle_batch.visibility_range_end = source.visibility_range_end
	_console_toggle_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_console_toggle_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_console_toggle_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_console_toggle_batch.set_meta(&"visual_detail_only", true)
	_console_toggle_batch.set_meta(&"authored_visual_names", PackedStringArray(CONSOLE_TOGGLE_NAMES))
	_console_toggle_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for toggle in toggles:
		toggle.free()
	cockpit.add_child(_console_toggle_batch)


## Four cyan console keys are childless visual dressing. The two gold centre
## keys and every functional cockpit/command node remain individually authored.
func _batch_console_keys(visual: Node3D) -> void:
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit == null:
		return
	var keys: Array[MeshInstance3D] = []
	for key_name in CONSOLE_KEY_NAMES:
		var key := cockpit.get_node_or_null(key_name) as MeshInstance3D
		if (
			key == null
			or key.get_child_count() != 0
			or key.mesh == null
			or key.get_script() != null
			or not key.get_groups().is_empty()
			or not key.get_meta_list().is_empty()
		):
			return
		keys.append(key)
	var source := keys[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for key in keys:
		if (
			key.mesh.get_class() != source_mesh.get_class()
			or key.mesh.get_aabb() != source_mesh.get_aabb()
			or key.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(key) != source_material
			or key.material_overlay != source.material_overlay
			or key.visible != source.visible
			or key.cast_shadow != source.cast_shadow
			or key.layers != source.layers
			or key.extra_cull_margin != source.extra_cull_margin
			or key.ignore_occlusion_culling != source.ignore_occlusion_culling
			or key.lod_bias != source.lod_bias
			or key.visibility_range_begin != source.visibility_range_begin
			or key.visibility_range_end != source.visibility_range_end
			or key.visibility_range_begin_margin != source.visibility_range_begin_margin
			or key.visibility_range_end_margin != source.visibility_range_end_margin
			or key.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for key in keys:
		transforms.append(key.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_console_key_batch = MultiMeshInstance3D.new()
	_console_key_batch.name = "CinderConsoleKeyBatch"
	_console_key_batch.multimesh = multi
	_console_key_batch.material_override = source.material_override
	_console_key_batch.material_overlay = source.material_overlay
	_console_key_batch.visible = source.visible
	_console_key_batch.cast_shadow = source.cast_shadow
	_console_key_batch.layers = source.layers
	_console_key_batch.extra_cull_margin = source.extra_cull_margin
	_console_key_batch.ignore_occlusion_culling = source.ignore_occlusion_culling
	_console_key_batch.lod_bias = source.lod_bias
	_console_key_batch.visibility_range_begin = source.visibility_range_begin
	_console_key_batch.visibility_range_end = source.visibility_range_end
	_console_key_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_console_key_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_console_key_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_console_key_batch.set_meta(&"visual_detail_only", true)
	_console_key_batch.set_meta(&"authored_visual_names", PackedStringArray(CONSOLE_KEY_NAMES))
	_console_key_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for key in keys:
		key.free()
	cockpit.add_child(_console_key_batch)


## The two gold centre console keys are likewise childless, immutable visual
## dressing. They retain their authored identities/transforms on one batch;
## controls, cockpit authority, and all non-gold keys remain independently
## authored.
func _batch_console_center_keys(visual: Node3D) -> void:
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit == null:
		return
	var keys: Array[MeshInstance3D] = []
	for key_name in CONSOLE_CENTER_KEY_NAMES:
		var key := cockpit.get_node_or_null(key_name) as MeshInstance3D
		if (
			key == null
			or key.get_child_count() != 0
			or key.mesh == null
			or key.get_script() != null
			or not key.get_groups().is_empty()
			or not key.get_meta_list().is_empty()
		):
			return
		keys.append(key)
	var source := keys[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for key in keys:
		if (
			key.mesh.get_class() != source_mesh.get_class()
			or key.mesh.get_aabb() != source_mesh.get_aabb()
			or key.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(key) != source_material
			or key.material_overlay != source.material_overlay
			or key.visible != source.visible
			or key.cast_shadow != source.cast_shadow
			or key.layers != source.layers
			or key.extra_cull_margin != source.extra_cull_margin
			or key.ignore_occlusion_culling != source.ignore_occlusion_culling
			or key.lod_bias != source.lod_bias
			or key.visibility_range_begin != source.visibility_range_begin
			or key.visibility_range_end != source.visibility_range_end
			or key.visibility_range_begin_margin != source.visibility_range_begin_margin
			or key.visibility_range_end_margin != source.visibility_range_end_margin
			or key.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for key in keys:
		transforms.append(key.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_console_center_key_batch = MultiMeshInstance3D.new()
	_console_center_key_batch.name = "CinderConsoleCenterKeyBatch"
	_console_center_key_batch.multimesh = multi
	_console_center_key_batch.material_override = source.material_override
	_console_center_key_batch.material_overlay = source.material_overlay
	_console_center_key_batch.visible = source.visible
	_console_center_key_batch.cast_shadow = source.cast_shadow
	_console_center_key_batch.layers = source.layers
	_console_center_key_batch.extra_cull_margin = source.extra_cull_margin
	_console_center_key_batch.ignore_occlusion_culling = source.ignore_occlusion_culling
	_console_center_key_batch.lod_bias = source.lod_bias
	_console_center_key_batch.visibility_range_begin = source.visibility_range_begin
	_console_center_key_batch.visibility_range_end = source.visibility_range_end
	_console_center_key_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_console_center_key_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_console_center_key_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_console_center_key_batch.set_meta(&"visual_detail_only", true)
	_console_center_key_batch.set_meta(&"authored_visual_names", PackedStringArray(CONSOLE_CENTER_KEY_NAMES))
	_console_center_key_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for key in keys:
		key.free()
	cockpit.add_child(_console_center_key_batch)


## The mirrored status repeaters are identical, childless instrument faces
## under one immutable instrument cluster. One two-instance renderer preserves
## their exact positions, finish, and culling bounds while leaving the primary
## display, functional cockpit nodes, lights, and command authority untouched.
func _batch_status_repeaters(visual: Node3D) -> void:
	var instrument_cluster := visual.get_node_or_null(
		^"CockpitInterior/InstrumentCluster"
	) as Node3D
	if instrument_cluster == null:
		return
	var repeaters: Array[MeshInstance3D] = []
	for repeater_name in STATUS_REPEATER_NAMES:
		var repeater := instrument_cluster.get_node_or_null(repeater_name) as MeshInstance3D
		if (
			repeater == null
			or repeater.get_child_count() != 0
			or repeater.mesh == null
			or repeater.get_script() != null
			or not repeater.get_groups().is_empty()
			or not repeater.get_meta_list().is_empty()
		):
			return
		repeaters.append(repeater)
	var source := repeaters[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for repeater in repeaters:
		if (
			repeater.mesh.get_class() != source_mesh.get_class()
			or repeater.mesh.get_aabb() != source_mesh.get_aabb()
			or repeater.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(repeater) != source_material
			or repeater.material_override != source.material_override
			or repeater.material_overlay != source.material_overlay
			or repeater.visible != source.visible
			or repeater.cast_shadow != source.cast_shadow
			or repeater.layers != source.layers
			or repeater.extra_cull_margin != source.extra_cull_margin
			or repeater.ignore_occlusion_culling != source.ignore_occlusion_culling
			or repeater.lod_bias != source.lod_bias
			or repeater.visibility_range_begin != source.visibility_range_begin
			or repeater.visibility_range_end != source.visibility_range_end
			or repeater.visibility_range_begin_margin != source.visibility_range_begin_margin
			or repeater.visibility_range_end_margin != source.visibility_range_end_margin
			or repeater.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for repeater in repeaters:
		transforms.append(repeater.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_status_repeater_batch = MultiMeshInstance3D.new()
	_status_repeater_batch.name = "CinderStatusRepeaterBatch"
	_status_repeater_batch.multimesh = multi
	_status_repeater_batch.material_override = source.material_override
	_status_repeater_batch.material_overlay = source.material_overlay
	_status_repeater_batch.visible = source.visible
	_status_repeater_batch.cast_shadow = source.cast_shadow
	_status_repeater_batch.layers = source.layers
	_status_repeater_batch.extra_cull_margin = source.extra_cull_margin
	_status_repeater_batch.ignore_occlusion_culling = source.ignore_occlusion_culling
	_status_repeater_batch.lod_bias = source.lod_bias
	_status_repeater_batch.visibility_range_begin = source.visibility_range_begin
	_status_repeater_batch.visibility_range_end = source.visibility_range_end
	_status_repeater_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_status_repeater_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_status_repeater_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_status_repeater_batch.set_meta(&"visual_detail_only", true)
	_status_repeater_batch.set_meta(&"presentation_only", true)
	_status_repeater_batch.set_meta(&"gameplay_authority", false)
	_status_repeater_batch.set_meta(
		&"authored_visual_names", PackedStringArray(STATUS_REPEATER_NAMES)
	)
	_status_repeater_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for repeater in repeaters:
		repeater.free()
	instrument_cluster.add_child(_status_repeater_batch)


static func _renderer_material(instance: MeshInstance3D) -> Material:
	if instance.material_override != null:
		return instance.material_override
	return instance.mesh.surface_get_material(0) if instance.mesh.get_surface_count() > 0 else null


static func _encode_visual_transforms(
	transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


static func _visual_bounds(
	mesh_bounds: AABB,
	transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	for index in transforms.size():
		var transformed := (transforms[index] * mesh_bounds).abs()
		result = transformed if index == 0 else result.merge(transformed)
	return result


func _build_boarding_marker(visual: Node3D) -> void:
	_interceptor_boarding_marker = Marker3D.new()
	_interceptor_boarding_marker.name = "BoardingMarker"
	_interceptor_boarding_marker.position = Vector3(-2.7, -0.85, 0.0)
	_interceptor_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_interceptor_boarding_marker)



## Formed skins retain the authored planform while rolling continuously from
## a load-bearing crown into thin perimeter edges. The response wing retains its
## immutable mesh; the mirrored rails and blades retain their two batches.
func _formed_aero_mesh(size: Vector3, vertical: bool = false) -> ArrayMesh:
	var stations := PackedFloat32Array([0.0, 0.06, 0.14, 0.22, 0.28, 0.36, 0.43, 0.5, 0.62, 0.74, 0.83, 0.91, 0.97, 1.0])
	var rings: Array[PackedVector3Array] = []
	const SEGMENTS := 32
	for t in stations:
		var extent := _aero_section_extent(size, t, vertical)
		var ring := PackedVector3Array()
		for edge in SEGMENTS:
			var angle := TAU * float(edge) / float(SEGMENTS)
			var section := Vector2(sin(angle), cos(angle))
			# Retain a narrow perimeter land for the rolled skin closure;
			# a mathematically sharp ellipse would read as a paper edge.
			if vertical:
				section.y = clampf(section.y / 0.94, -1.0, 1.0)
			else:
				section.x = clampf(section.x / 0.94, -1.0, 1.0)
			ring.append(Vector3(section.x * extent.x, section.y * extent.y, (t - 0.5) * size.z))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bay in stations.size() - 1:
		for edge in SEGMENTS:
			var next := (edge + 1) % SEGMENTS
			for corner in [Vector2i(edge, bay), Vector2i(next, bay), Vector2i(next, bay + 1), Vector2i(edge, bay), Vector2i(next, bay + 1), Vector2i(edge, bay + 1)]:
				var around := rings[corner.y][(corner.x + 1) % SEGMENTS] - rings[corner.y][(corner.x + SEGMENTS - 1) % SEGMENTS]
				var along := rings[mini(corner.y + 1, stations.size() - 1)][corner.x] - rings[maxi(corner.y - 1, 0)][corner.x]
				surface.set_normal(along.cross(around).normalized())
				var u := 1.0 if edge == SEGMENTS - 1 and corner.x == 0 else float(corner.x) / float(SEGMENTS)
				surface.set_uv(Vector2(u, stations[corner.y]))
				surface.add_vertex(rings[corner.y][corner.x])
	for cap in [0, stations.size() - 1]:
		for edge in SEGMENTS:
			var next := (edge + 1) % SEGMENTS
			for corner in ([-1, next, edge] if cap == 0 else [-1, edge, next]):
				var point := Vector3(0, 0, rings[cap][0].z) if corner < 0 else rings[cap][corner]
				surface.set_normal(Vector3.FORWARD if cap == 0 else Vector3.BACK)
				surface.set_uv(Vector2(point.x / size.x, point.y / size.y) + Vector2.ONE * 0.5)
				surface.add_vertex(point)
	surface.generate_tangents()
	return surface.commit()


func _aero_section_extent(size: Vector3, t: float, vertical: bool) -> Vector2:
	# Preserve the original span/sweep stations in the horizontal planform,
	# and the fin's leading rise and aft rake in the vertical planform.
	var planform := minf(1.0, lerpf(0.35 if vertical else 0.12, 1.0, t / (0.28 if vertical else 0.43)))
	if t > 0.83:
		planform = lerpf(1.0, 0.8 if vertical else 0.9, (t - 0.83) / 0.17)
	# A rounded leading closure feeds the full-depth spar section, then
	# eases into a retained thin trailing edge instead of a squared slab.
	var thickness := lerpf(0.18, 1.0, sin(minf(t / 0.43, 1.0) * PI * 0.5))
	if t > 0.5:
		thickness = lerpf(1.0, 0.12, smoothstep(0.5, 1.0, t))
	return Vector2(size.x * thickness, size.y * planform) * 0.5 if vertical else Vector2(size.x * planform, size.y * thickness) * 0.5


## The recognition fin keeps the exact triangular X/Y outline of its former
## prism. A crowned skin thins toward all three welded perimeter lands.
func _formed_recognition_fin_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 12
	for side in [-1.0, 1.0]:
		for row in STEPS:
			for column in STEPS - row:
				var a := Vector2(float(column), float(row)) / STEPS
				var b := a + Vector2(1.0 / STEPS, 0)
				var c := a + Vector2(0, 1.0 / STEPS)
				var corners := [a, c, b] if side > 0 else [a, b, c]
				if column + row < STEPS - 1:
					var d := a + Vector2.ONE / STEPS
					corners.append_array([b, c, d] if side > 0 else [b, d, c])
				for uv: Vector2 in corners:
					var u := uv.x
					var v := uv.y
					var w := 1.0 - u - v
					var depth := 0.025 + 0.135 * 27.0 * u * v * w
					var du := 0.135 * 27.0 * v * (w - u)
					var dv := 0.135 * 27.0 * u * (w - v)
					surface.set_normal(Vector3(-du / 2.7, -(dv - du * 0.5) / 1.8, side).normalized())
					surface.set_uv(uv)
					surface.add_vertex(Vector3(-1.35 + 2.7 * u + 1.35 * v, -0.9 + 1.8 * v, side * depth))
	# Close the retained 5 cm perimeter land with crisp outward edge normals.
	var outline := [Vector2(-1.35, -0.9), Vector2(1.35, -0.9), Vector2(0, 0.9)]
	for edge in 3:
		var a: Vector2 = outline[edge]
		var b: Vector2 = outline[(edge + 1) % 3]
		var direction := b - a
		for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]:
			var xy := a if corner.x == 0 else b
			surface.set_normal(Vector3(direction.y, -direction.x, 0).normalized())
			surface.set_uv(Vector2(corner))
			surface.add_vertex(Vector3(xy.x, xy.y, -0.025 if corner.y == 0 else 0.025))
	surface.generate_tangents()
	return surface.commit()


func _wing_skin_height(x: float, z: float) -> float:
	var t := clampf((z - 0.55) / 5.8 + 0.5, 0.0, 1.0)
	var extent := _aero_section_extent(Vector3(12.0, 0.55, 5.8), t, false)
	return -0.15 + extent.y * sqrt(maxf(0.0, 1.0 - pow(x * 0.94 / extent.x, 2.0)))


## The dark seal is a narrow seated perimeter, with a beveled lid nested into
## it. All surfaces use the same wing crown, so no panel floats across curvature.
func _wing_service_plate(parent: Node3D, tag: String, at: Vector3, width: float, length: float, paint: Material, gasket: Material) -> void:
	var seal := _box(parent, tag + "Gasket", at, Vector3.ONE, gasket)
	seal.mesh = _wing_fitting_mesh(at, width, length, 0.016, 0.049, 0.045, gasket)
	var panel := _box(parent, tag + "Panel", at, Vector3.ONE, paint)
	panel.mesh = _wing_fitting_mesh(at, width - 0.024, length - 0.024, 0.043, 0.067, 0.040, paint)


## Chamfered planform with a rolled-down perimeter and a sampled wing crown.
## The carrier, seal and lid share this construction instead of stacking flat
## boxes. Closed undersides intersect their supporting skin or seal by design.
func _wing_fitting_mesh(at: Vector3, width: float, length: float, bottom: float, top: float, bevel: float, coating: Material, carrier_side: float = 0.0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(coating)
	var rings: Array[PackedVector3Array] = []
	# Explicit perimeter bevel stations keep the central access land flat.
	var spans := PackedFloat32Array([-0.5, -0.5 + bevel / width, -0.25, 0.0, 0.25, 0.5 - bevel / width, 0.5])
	var chords := PackedFloat32Array([-0.5, -0.5 + bevel / length, -0.25, 0.0, 0.25, 0.5 - bevel / length, 0.5])
	if not is_zero_approx(carrier_side):
		for edge in [-0.305, -0.270, 0.270, 0.305]:
			spans.append((carrier_side * 0.34 + edge) / width)
		for station in [-0.08, 0.90, 1.48]:
			for edge in [-0.215, -0.180, 0.180, 0.215]:
				chords.append((station - at.z + edge) / length)
		spans.sort()
		chords.sort()
	var columns := spans.size()
	var rows := chords.size()
	for layer in 2:
		var points := PackedVector3Array()
		for z in chords:
			var corner_cut := maxf(0.0, bevel - (0.5 - absf(z)) * length)
			for x in spans:
				var point := Vector3(x * (width - 2.0 * corner_cut), 0, z * length)
				var edge := minf((0.5 - absf(x)) * width, (0.5 - absf(z)) * length)
				var height := bottom if layer == 0 else lerpf(bottom + (top - bottom) * 0.32, top, clampf(edge / bevel, 0.0, 1.0))
				if layer == 1 and not is_zero_approx(carrier_side):
					for station in [-0.08, 0.90, 1.48]:
						var slot_edge := minf(0.305 - absf(at.x + point.x - carrier_side * 4.39), 0.215 - absf(at.z + point.z - station))
						height -= 0.061 * clampf(slot_edge / 0.035, 0.0, 1.0)
				point.y = _wing_skin_height(at.x + point.x, at.z + point.z) - at.y + height
				points.append(point)
		rings.append(points)
	for layer in 2:
		surface.set_smooth_group(layer)
		for row in range(rows - 1):
			for col in range(columns - 1):
				var a := row * columns + col
				var corners := [a, a + 1, a + columns + 1, a + columns]
				if layer == 0:
					corners.reverse()
				_wing_fitting_quad(surface, rings[layer][corners[0]], rings[layer][corners[1]], rings[layer][corners[2]], rings[layer][corners[3]])
	var perimeter: Array[int] = []
	for col in columns:
		perimeter.append(col)
	for row in range(1, rows):
		perimeter.append(row * columns + columns - 1)
	for col in range(columns - 2, -1, -1):
		perimeter.append((rows - 1) * columns + col)
	for row in range(rows - 2, 0, -1):
		perimeter.append(row * columns)
	surface.set_smooth_group(2)
	for index in perimeter.size():
		var a := perimeter[index]
		var b := perimeter[(index + 1) % perimeter.size()]
		_wing_fitting_quad(surface, rings[1][a], rings[0][a], rings[0][b], rings[1][b])
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _wing_fitting_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for triangle in [[a, b, c], [a, c, d]]:
		var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
		for point: Vector3 in triangle:
			surface.set_normal(normal)
			surface.set_uv(Vector2(point.x, point.z))
			surface.add_vertex(point)


## Chamfered pressure-shell stock reuses the inherited closed loft topology.
## Broad planar stations carry armor panels; corner facets catch a narrow edge
## highlight without inflating the entire silhouette like a superellipse.
func _loft_mesh(size: Vector3, material: Material) -> ArrayMesh:
	# Use the actual profile breaks as stations. The broad pressure faces
	# stay continuous between those breaks instead of introducing redundant
	# almost-coplanar strips along the manufactured edges.
	var section := PackedVector2Array([
		Vector2(0, 1), Vector2(0.94, 1), Vector2(1, 0.94), Vector2(1, 0.36),
		Vector2(1, 0), Vector2(1, -0.36), Vector2(1, -0.94), Vector2(0.94, -1),
		Vector2(0, -1), Vector2(-0.94, -1), Vector2(-1, -0.94), Vector2(-1, -0.36),
		Vector2(-1, 0), Vector2(-1, 0.36), Vector2(-1, 0.94), Vector2(-0.94, 1),
	])
	return _section_loft_mesh(size, material, section)


## The interceptor's narrow pressure body has a rolled shoulder and tucked
## belly. Broad crowns still carry the fixed cockpit and access hardware.
## Nacelles keep a full inlet section, swell into their duct, and terminate at
## the turbine diameter instead of tapering to the same pointed stock nose.
func _formed_pressure_mesh(size: Vector3, material: Material, nacelle: bool = false, primary_bow: bool = false) -> ArrayMesh:
	# Flat crown and belly lands support the existing cockpit and service
	# panels. Elliptical shoulders meet those lands tangentially, so a close
	# highlight describes a rolled shell instead of sixteen straight facets.
	var right := PackedVector2Array([Vector2(0, 1), Vector2(0.56, 1)])
	const ARC_STEPS := 12
	for step in range(1, ARC_STEPS + 1):
		var angle := float(step) / ARC_STEPS * PI * 0.5
		right.append(Vector2(0.56 + 0.44 * sin(angle), 0.18 + 0.82 * cos(angle)))
	for step in range(1, ARC_STEPS + 1):
		var angle := float(step) / ARC_STEPS * PI * 0.5
		right.append(Vector2(0.44 + 0.56 * cos(angle), 0.18 - 1.18 * sin(angle)))
	right.append(Vector2(0, -1))
	var section := right.duplicate()
	for index in range(right.size() - 2, 0, -1):
		section.append(Vector2(-right[index].x, right[index].y))
	return _section_loft_mesh(size, material, section, true, nacelle, primary_bow)


## Swept saddle fairings carry the engine loads into the wing. A narrow rounded
## forefoot widens around the cannon cradle, then rolls down into an aft feather
## edge. The continuously crowned section replaces the former flat shelf; the
## fixed renderer, shear, cannon and engine interfaces remain unchanged.
func _formed_root_mesh(side: float, material: Material) -> ArrayMesh:
	var stations := PackedFloat32Array([0.0, 0.02, 0.04, 0.07, 0.12, 0.18, 0.24, 0.30, 0.34, 0.40, 0.46, 0.52, 0.56, 0.62, 0.68, 0.74, 0.78, 0.83, 0.88, 0.92, 0.95, 0.975, 0.99, 1.0])
	const SEGMENTS := 32
	var points: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for t in stations:
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for edge in SEGMENTS:
			var angle := TAU * float(edge) / float(SEGMENTS)
			ring.append(_root_fairing_point(t, angle, side))
			var around := _root_fairing_point(t, angle + 0.001, side) - _root_fairing_point(t, angle - 0.001, side)
			var along := _root_fairing_point(minf(t + 0.001, 1.0), angle, side) - _root_fairing_point(maxf(t - 0.001, 0.0), angle, side)
			ring_normals.append(along.cross(around).normalized())
		points.append(ring)
		normals.append(ring_normals)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for bay in stations.size() - 1:
		for edge in SEGMENTS:
			for corner in [Vector2i(edge, bay), Vector2i(edge + 1, bay), Vector2i(edge + 1, bay + 1), Vector2i(edge, bay), Vector2i(edge + 1, bay + 1), Vector2i(edge, bay + 1)]:
				surface.set_normal(normals[corner.y][corner.x % SEGMENTS])
				surface.set_uv(Vector2(float(corner.x) / float(SEGMENTS), stations[corner.y]))
				surface.add_vertex(points[corner.y][corner.x % SEGMENTS])
	for cap in [0.0, 1.0]:
		var centre := (_root_fairing_point(cap, 0.0, side) + _root_fairing_point(cap, PI, side)) * 0.5
		for edge in SEGMENTS:
			for corner in ([-1, edge + 1, edge] if cap == 0.0 else [-1, edge, edge + 1]):
				var point := centre if corner < 0 else _root_fairing_point(cap, TAU * float(corner) / float(SEGMENTS), side)
				surface.set_normal(Vector3.FORWARD if cap == 0.0 else Vector3.BACK)
				surface.set_uv(Vector2(point.x / 1.6, point.y / 0.7) + Vector2.ONE * 0.5)
				surface.add_vertex(point)
	surface.generate_tangents()
	return surface.commit()


func _root_fairing_point(t: float, angle: float, side: float) -> Vector3:
	var knots := PackedFloat32Array([0.0, 0.12, 0.34, 0.56, 0.78, 1.0])
	var inner := _pressure_profile(t, knots, PackedFloat32Array([-0.38, -0.58, -0.79, -0.80, -0.80, -0.80]), true)
	var outer := _pressure_profile(t, knots, PackedFloat32Array([-0.18, 0.14, 0.65, 0.80, 0.72, 0.72]), true)
	var width := (outer - inner) * 0.5
	var centre := (outer + inner) * 0.5
	# An elliptical aft planform turns through the final shoulder instead of
	# terminating the broad saddle with a straight transverse cut.
	if t > 0.78:
		var aft := (t - 0.78) / 0.22
		width = 0.04 + 0.72 * sqrt(maxf(0.0, 1.0 - aft * aft))
	var depth := _pressure_profile(t, knots, PackedFloat32Array([0.045, 0.12, 0.19, 0.19, 0.14, 0.025]), true)
	var x := side * centre + width * sin(angle)
	var span := clampf((x * side + 0.8) / 1.6, 0.0, 1.0)
	# The raised inboard saddle feeds the nacelle. Across the exposed span the
	# ellipse turns the highlight continuously into the lower perimeter return.
	var y := depth * cos(angle) + 0.30 * pow(1.0 - span, 3.0)
	return Vector3(x, y, (t - 0.5) * 4.4)


## Monotone Hermite profile retains the original station envelopes, inlet and
## turbine interfaces while rolling the skin into its straight midbody. Zero
## tangents at flat spans prevent overshoot beyond the fixed collision bounds.
func _pressure_extent(t: float, nacelle: bool, formed: bool, primary_bow: bool = false) -> Vector2:
	var knots := PackedFloat32Array([0.0, 0.28, 0.43, 0.83, 1.0])
	var widths := PackedFloat32Array([0.12, lerpf(0.12, 1.0, 0.28 / 0.43), 1.0, 1.0, 0.9])
	var heights := PackedFloat32Array([0.35, 1.0, 1.0, 1.0, 0.8])
	if nacelle:
		widths = PackedFloat32Array([0.72, 0.97, 1.0, 1.0, 1.2 / 1.26])
		heights = PackedFloat32Array([0.58, 0.96, 1.0, 1.0, 1.2 / 1.34])
	var extent := Vector2(_pressure_profile(t, knots, widths, formed), _pressure_profile(t, knots, heights, formed))
	if primary_bow:
		# The primary shell carries a full ogive shoulder beneath the cockpit,
		# while its forefoot rises into a small rounded bow instead of a tall
		# cut-off blade. The crown stays at the existing fairing seating height.
		extent.x = _pressure_profile(t, PackedFloat32Array([0.0, 0.08, 0.20, 0.32, 0.43, 0.83, 1.0]), PackedFloat32Array([0.12, 0.40, 0.72, 0.93, 1.0, 1.0, 0.9]), true)
		extent.y -= _primary_bow_lift(t)
	if nacelle and formed:
		extent *= 1.0 - 0.045 * _nacelle_joint_depth(t)
	return extent


## Half-height removed from the belly is added to the section centre, retaining
## the upper crown height for the existing fairing and sensor assembly.
func _primary_bow_lift(t: float) -> float:
	return 0.28 * (1.0 - smoothstep(0.0, 0.28, t))


## Two recessed joints separate the inlet collar and removable aft cowl from
## the pressure jacket. They are built into its single retained skin surface.
func _nacelle_joint_depth(t: float) -> float:
	var depth := 0.0
	for centre in [0.19, 0.92]:
		depth = maxf(depth, 1.0 - smoothstep(0.004, 0.012, absf(t - centre)))
	return depth


func _pressure_profile(t: float, knots: PackedFloat32Array, values: PackedFloat32Array, curved: bool) -> float:
	var bay := 0
	while bay < knots.size() - 2 and t > knots[bay + 1]:
		bay += 1
	var run := knots[bay + 1] - knots[bay]
	var u := clampf((t - knots[bay]) / run, 0.0, 1.0)
	if not curved:
		return lerpf(values[bay], values[bay + 1], u)
	var slopes := PackedFloat32Array()
	for index in range(bay, bay + 2):
		var before := maxi(index - 1, 0)
		var after := mini(index + 1, knots.size() - 1)
		var left := (values[index] - values[before]) / (knots[index] - knots[before]) if before != index else (values[after] - values[index]) / (knots[after] - knots[index])
		var right := (values[after] - values[index]) / (knots[after] - knots[index]) if after != index else left
		slopes.append(2.0 * left * right / (left + right) if left * right > 0.0 else 0.0)
	var u2 := u * u
	var u3 := u2 * u
	return (
		(2.0 * u3 - 3.0 * u2 + 1.0) * values[bay]
		+ (u3 - 2.0 * u2 + u) * run * slopes[0]
		+ (-2.0 * u3 + 3.0 * u2) * values[bay + 1]
		+ (u3 - u2) * run * slopes[1]
	)


func _section_loft_mesh(size: Vector3, material: Material, section: PackedVector2Array, formed: bool = false, nacelle: bool = false, primary_bow: bool = false) -> ArrayMesh:
	var stations := PackedFloat32Array([0.0, 0.28, 0.43, 0.83, 1.0])
	if formed:
		stations = PackedFloat32Array([0.0, 0.04, 0.08, 0.14, 0.20, 0.28, 0.36, 0.43, 0.52, 0.64, 0.74, 0.83, 0.90, 0.95, 1.0])
	if primary_bow:
		stations.append_array(PackedFloat32Array([0.015, 0.025, 0.06, 0.11, 0.17, 0.24, 0.32, 0.39]))
		stations.sort()
	if formed and nacelle:
		for centre in [0.19, 0.92]:
			for offset in [-0.012, -0.008, -0.004, 0.0, 0.004, 0.008, 0.012]:
				stations.append(centre + offset)
		stations.sort()
	var extents: Array[Vector2] = []
	var slopes: Array[Vector2] = []
	for t in stations:
		var extent := _pressure_extent(t, nacelle, formed, primary_bow)
		extents.append(Vector2(extent.x * size.x * 0.5, extent.y * size.y * 0.5))
		if formed:
			var lo := maxf(0.0, t - 0.0005)
			var hi := minf(1.0, t + 0.0005)
			var derivative := (_pressure_extent(hi, nacelle, true, primary_bow) - _pressure_extent(lo, nacelle, true, primary_bow)) / (hi - lo)
			slopes.append(Vector2(derivative.x * size.x, derivative.y * size.y) / (2.0 * size.z))
	var count := section.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for bay in stations.size() - 1:
		var extent_delta := extents[bay + 1] - extents[bay]
		var run: float = size.z * (stations[bay + 1] - stations[bay])
		for edge in count:
			var next := (edge + 1) % count
			var edge_direction := section[next] - section[edge]
			# Clockwise exterior winding, with analytic bilinear-patch
			# normals on the tapered chamfers rather than triangle fans.
			for corner in [Vector2i(edge, bay), Vector2i(next, bay), Vector2i(next, bay + 1), Vector2i(edge, bay), Vector2i(next, bay + 1), Vector2i(edge, bay + 1)]:
				var extent := extents[corner.y]
				var tangent := edge_direction
				if formed:
					tangent = section[(corner.x + 1) % count] - section[(corner.x + count - 1) % count]
					if is_equal_approx(absf(section[corner.x].y), 1.0):
						tangent = Vector2(section[corner.x].y, 0)
				var around := Vector3(tangent.x * extent.x, tangent.y * extent.y, 0)
				var slope := slopes[corner.y] if formed else extent_delta / run
				var along := Vector3(section[corner.x].x * slope.x, section[corner.x].y * slope.y, 1.0)
				if primary_bow:
					var t := stations[corner.y]
					var lo := maxf(0.0, t - 0.0005)
					var hi := minf(1.0, t + 0.0005)
					along.y += (_primary_bow_lift(hi) - _primary_bow_lift(lo)) / (hi - lo) * size.y / (2.0 * size.z)
				var u := 1.0 if edge == count - 1 and corner.x == 0 else float(corner.x) / float(count)
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(u, stations[corner.y]))
				var joint := _nacelle_joint_depth(stations[corner.y]) if nacelle else 0.0
				surface.set_color(Color.WHITE.lerp(Color(0.19, 0.23, 0.26), joint))
				surface.add_vertex(Vector3(section[corner.x].x * extent.x, section[corner.x].y * extent.y + (_primary_bow_lift(stations[corner.y]) * size.y * 0.5 if primary_bow else 0.0), (stations[corner.y] - 0.5) * size.z))
	for cap in [0, stations.size() - 1]:
		var z: float = (stations[cap] - 0.5) * size.z
		for edge in count:
			var next := (edge + 1) % count
			var order := [-1, next, edge] if cap == 0 else [-1, edge, next]
			for corner in order:
				var point := Vector3(0, 0, z) if corner < 0 else Vector3(section[corner].x * extents[cap].x, section[corner].y * extents[cap].y, z)
				if primary_bow:
					point.y += _primary_bow_lift(stations[cap]) * size.y * 0.5
				surface.set_normal(Vector3.FORWARD if cap == 0 else Vector3.BACK)
				surface.set_color(Color.WHITE)
				# XY cap projection retains a usable tangent frame.
				surface.set_uv(Vector2(point.x / size.x, point.y / size.y) + Vector2.ONE * 0.5)
				surface.add_vertex(point)
	surface.generate_tangents()
	return surface.commit()


func _armor_shell(parent: Node3D, node_name: String, at: Vector3, size: Vector3, coating: Material, skew: float = 0.0, formed_mesh: ArrayMesh = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	instance.mesh = formed_mesh if formed_mesh != null else _loft_mesh(size, coating)
	# Shear the assembly into the wing root without an intersecting box joint.
	instance.transform.basis.z.x = -skew
	parent.add_child(instance)
	return instance


func _service_bay(parent: Node3D, tag: String, at: Vector3, width: float, length: float, frame: Material, dark: Material, metal: Material) -> void:
	preload("res://scripts/ships/ship_service_cassette.gd").install(parent, tag, at, width, length, frame, dark, metal)


func _pressure_panel(parent: Node3D, label: String, at: Vector3, top: float, bottom: float, height: float, depth: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = at
	instance.mesh = _pressure_mesh(top, bottom, height, depth, material)
	parent.add_child(instance)
	return instance


func _pressure_mesh(top: float, bottom: float, height: float, depth: float, material: Material) -> ArrayMesh:
	var source := _trapezoid_prism_mesh(top, bottom, height, depth, material)
	var arrays := source.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index in points.size():
			indices.append(index)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for triangle in range(0, indices.size(), 3):
		var normal := (points[indices[triangle + 2]] - points[indices[triangle]]).cross(points[indices[triangle + 1]] - points[indices[triangle]]).normalized()
		for corner in 3:
			var index := indices[triangle + corner]
			surface.set_normal(normal)
			surface.set_uv(uv[index])
			surface.add_vertex(points[index])
	surface.generate_tangents()
	return surface.commit()


## Recessed stator and turned hub share the Cinder family machinery meshes.
func _engine_mechanics(parent: Node3D, tag: String, at: Vector3, radius: float, metal: Material, dark: Material) -> void:
	preload("res://scripts/ships/cinder_exhaust_machinery.gd").install(parent, tag, at, radius, metal, dark)


## Flush service plates have their own bevel and dark gasket; the narrow edge
## catches light while a readable seam separates adjacent manufactured parts.
func _deck_plate(parent: Node3D, tag: String, at: Vector3, width: float, length: float, paint: Material, gasket: Material) -> void:
	_box(parent, tag + "Gasket", at, Vector3(width, 0.028, length), gasket)
	_box(parent, tag + "Panel", at + Vector3(0, 0.022, 0), Vector3(width - 0.06, 0.032, length - 0.06), paint)


## A continuous shoulder carries the fixed cockpit floor into the pressure
## body. Its forward and aft ramps replace the stacked plinth silhouettes;
## all pilot, canopy hinge and boarding transforms stay on their original rig.
func _cockpit_shoulder_mesh(origin: Vector3, crown: float, width: float, material: Material) -> ArrayMesh:
	# The interceptor carries its cockpit in a long, narrow formed bow. Its
	# upper crown still supports the unchanged floor; the lower rolled return
	# seats inside the primary body instead of projecting a separate plinth.
	return preload("res://scripts/ships/cinder_cockpit_pressure_fairing.gd").build(origin, crown, width, material, {
		"stations": [-4.35, -2.25, 1.15, 3.1],
		"tops": [0.36, 1.89, 1.89, crown],
		"widths": [0.4, width, width, width * 0.95],
		"top_widths": [0.24, 2.18, 2.18, width * 0.85],
		"tucked_return": true,
		"bow_tangent": 0.45,
	})


## Add the missing propulsion presentation at this hull's nozzle mouths. The
## envelope is baked along local +Z with its base at zero, so HeroShip's axial
## throttle/damage scaling cannot widen the plume or pull it out of its mount.
func _build_engine_exhaust(visual: Node3D) -> void:
	var radius := 0.62
	var nozzle := Vector3(2.1, 0.2, 4.98)
	var plume_mesh := (
		_shared_engine_exhaust_mesh.get_ref() as ArrayMesh
		if _shared_engine_exhaust_mesh != null else null
	)
	if plume_mesh == null:
		var envelope := CylinderMesh.new()
		envelope.bottom_radius = radius * 0.78
		envelope.top_radius = radius * 0.18
		envelope.height = radius * 2.8
		envelope.radial_segments = 24
		var surface := SurfaceTool.new()
		surface.append_from(envelope, 0, Transform3D(
			Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, envelope.height * 0.5)
		))
		plume_mesh = surface.commit()
		_shared_engine_exhaust_mesh = weakref(plume_mesh)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var mouth := Vector3(nozzle.x * side, nozzle.y, nozzle.z + radius * 0.05)
		var plume := MeshInstance3D.new()
		plume.name = ("Port" if index == 0 else "Starboard") + "EnginePlume"
		plume.transform = Transform3D(Basis.IDENTITY, mouth)
		plume.mesh = plume_mesh
		plume.visible = false
		visual.add_child(plume)
		_engine_glows.append(plume)
		EngineExhaustPresentation.install(plume, Vector3.BACK)
	_sync_engine_visuals_immediately()
