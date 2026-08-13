class_name ArrowReconShip
extends HeroShip

## Evidence-bounded Arrow-class Recon Ship candidate.
##
## Creator-authored material supports only the Arrow-class name, reconnaissance
## role, and two escape pods. This slender procedural airframe, all proportions,
## pod placement/release treatment, cockpit, entry, sensors, engines, weapons,
## materials, and handling are a modern provisional interpretation. The common
## HeroShip controller supplies already-tested flight, cameras, boarding,
## landing, damage, destruction, and reuse behavior.

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"provisional"
const EVIDENCE_SCOPE: StringName = &"name_role_pod_count_only"
const SUPPORTED_ESCAPE_POD_COUNT := 2
const PROVISIONAL_NOTE := (
	"Creator-supported facts: Arrow-class Recon Ship; reconnaissance role; two "
	+ "escape pods. The displayed geometry, materials, entry, pod locations and "
	+ "release concept, systems, handling, and weapons are a modern provisional "
	+ "interpretation with no authenticated historical silhouette mapping."
)

const PEARL := Color("e9eee9")
const CERAMIC := Color("c7d2ce")
const TITANIUM := Color("59686c")
const GRAPHITE := Color("15282e")
const SENSOR_CYAN := Color("65e4e8")
const POD_ORANGE := Color("e59a43")
const ENGINE_CYAN := Color("7cf5ef")
const ARROW_NAV_RED := Color("ff6460")
const ARROW_NAV_GREEN := Color("7cf0a3")

var _arrow_built := false
var _arrow_visual: Node3D
var _arrow_materials: Dictionary = {}
var _escape_pods: Array[Node3D] = []
var _engine_plumes: Array[MeshInstance3D] = []
var _arrow_engine_lights: Array[OmniLight3D] = []
var _sensor_sweep: Node3D
var _elapsed_arrow := 0.0


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	super._ready()
	if not _arrow_built:
		_arrow_built = rebuild_variant_presentation(_build_arrow_variant)
	_apply_arrow_metadata()
	_sync_arrow_engine_presentation_immediately()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_elapsed_arrow += delta
	_update_arrow_presentation(delta)


func get_escape_pod_count() -> int:
	return _escape_pods.size()


func get_escape_pods() -> Array[Node3D]:
	return _escape_pods.duplicate()


func get_escape_pod(side_id: StringName) -> Node3D:
	for pod in _escape_pods:
		if StringName(pod.get_meta("pod_side", &"")) == side_id:
			return pod
	return null


func get_sensor_mast() -> Node3D:
	return _sensor_sweep


func get_arrow_visual_root() -> Node3D:
	return _arrow_visual


func get_arrow_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"authenticated_geometry": false,
		"creator_supported": PackedStringArray([
			"Arrow-class Recon Ship name",
			"reconnaissance role",
			"two escape pods",
		]),
		"modern_provisional": PackedStringArray([
			"slender silhouette and every dimension",
			"cockpit, canopy, seat, entry side, and cameras",
			"escape-pod shape, position, markings, and release concept",
			"sensor mast and lateral arrays",
			"twin engines, light weapons, materials, and handling values",
		]),
		"content_note": PROVISIONAL_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


func get_arrow_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid provisional ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"provisional":
		errors.append("Arrow definition must remain provisional")
	if get_escape_pod_count() != SUPPORTED_ESCAPE_POD_COUNT:
		errors.append("Arrow must visibly expose exactly two escape pods")
	if _arrow_visual == null:
		errors.append("Arrow variant visual root is missing")
	if _sensor_sweep == null:
		errors.append("provisional recon sensor mast is missing")
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if left_muzzle == null or right_muzzle == null:
		errors.append("light weapon muzzle markers are missing")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"display_name": get_display_name(),
		"role": get_role(),
		"escape_pod_count": get_escape_pod_count(),
		"sensor_mast_present": _sensor_sweep != null,
		"weapon_class": &"light_recon_pulse",
		"engine_count": _engine_plumes.size(),
		"evidence": get_arrow_evidence_report(),
	}


func _build_arrow_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Preserve the inherited cockpit/canopy nodes because the common controller
	# owns their private animation and camera references. Every Torrent exterior
	# node is removed; only those functional cockpit nodes are reparented.
	var cockpit := inherited_visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := inherited_visual.get_node_or_null("CanopyHinge") as Node3D
	var hinge_bar := inherited_visual.get_node_or_null("CanopyHingeBar") as Node3D
	var hinge_mounts := inherited_visual.find_children("*CanopyHingeMount", "Node3D", false, false)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(self, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(self, true)
	if inherited_visual.get_parent() != null:
		inherited_visual.get_parent().remove_child(inherited_visual)
	inherited_visual.queue_free()

	_arrow_visual = Node3D.new()
	_arrow_visual.name = "ArrowReconVisual"
	_arrow_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_arrow_visual.set_meta("authenticated_historical_silhouette", false)
	_arrow_visual.set_meta("content_note", PROVISIONAL_NOTE)
	add_child(_arrow_visual)
	if cockpit != null:
		cockpit.reparent(_arrow_visual, true)
	if canopy != null:
		canopy.reparent(_arrow_visual, true)
	if hinge_bar != null:
		hinge_bar.reparent(_arrow_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_arrow_visual, true)

	_create_arrow_materials()
	_build_slender_airframe()
	_build_recon_systems()
	_build_escape_pods()
	_build_engines_and_landing_gear()
	_restyle_inherited_cockpit(cockpit, canopy)
	_replace_collision_and_markers()
	if not replace_variant_visual_root(_arrow_visual):
		return false
	return true


func _create_arrow_materials() -> void:
	_arrow_materials.pearl = _material(PEARL, 0.18, 0.28)
	_arrow_materials.ceramic = _material(CERAMIC, 0.12, 0.36)
	_arrow_materials.titanium = _material(TITANIUM, 0.58, 0.34)
	_arrow_materials.graphite = _material(GRAPHITE, 0.64, 0.3)
	_arrow_materials.sensor = _material(SENSOR_CYAN, 0.18, 0.22, SENSOR_CYAN, 1.7)
	_arrow_materials.pod = _material(POD_ORANGE, 0.2, 0.42)
	_arrow_materials.engine = _material(ENGINE_CYAN, 0.1, 0.16, ENGINE_CYAN, 3.0)
	_arrow_materials.nav_red = _material(ARROW_NAV_RED, 0.1, 0.2, ARROW_NAV_RED, 2.2)
	_arrow_materials.nav_green = _material(ARROW_NAV_GREEN, 0.1, 0.2, ARROW_NAV_GREEN, 2.2)
	_arrow_materials.glass = _transparent_material(Color(0.3, 0.68, 0.7, 0.09), 0.04, 0.08)
	var hull_albedo := load("res://assets/materials/arrow-hull-albedo-v1.png") as Texture2D
	var hull_normal := load("res://assets/materials/arrow-hull-normal-v1.png") as Texture2D
	var hull_roughness := load("res://assets/materials/arrow-hull-roughness-v1.png") as Texture2D
	for hull_material: StandardMaterial3D in [_arrow_materials.pearl, _arrow_materials.ceramic]:
		if hull_albedo != null:
			hull_material.albedo_texture = hull_albedo
		if hull_normal != null:
			hull_material.normal_enabled = true
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.62
		if hull_roughness != null:
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		# Triplanar projection keeps the generated aerospace panel treatment stable
		# across the procedural loft and avoids stretched seams at its ring caps.
		hull_material.uv1_triplanar = true
		hull_material.uv1_triplanar_sharpness = 4.0
		hull_material.uv1_scale = Vector3(0.34, 0.34, 0.34)
		hull_material.clearcoat_enabled = true
		hull_material.clearcoat = 0.48
		hull_material.clearcoat_roughness = 0.2


func get_variant_materials() -> Dictionary:
	return _arrow_materials


func _build_slender_airframe() -> void:
	# A narrow 32-section elliptical fuselage, not the Torrent's broad delta.
	_loft_hull(
		_arrow_visual,
		"ReconFuselage",
		Vector3(0, 1.22, -0.45),
		PackedVector3Array([
			Vector3(0.18, 0.12, -7.2),
			Vector3(0.72, 0.46, -6.15),
			Vector3(1.28, 0.72, -3.7),
			Vector3(1.5, 0.86, -0.7),
			Vector3(1.62, 0.82, 2.6),
			Vector3(1.25, 0.7, 5.2),
			Vector3(0.84, 0.55, 6.3),
		]),
		_arrow_materials.pearl
	)
	_loft_hull(
		_arrow_visual,
		"GraphiteKeel",
		Vector3(0, 0.5, -0.1),
		PackedVector3Array([
			Vector3(0.12, 0.08, -5.6),
			Vector3(0.82, 0.34, -3.8),
			Vector3(1.05, 0.38, 1.8),
			Vector3(0.68, 0.3, 5.3),
		]),
		_arrow_materials.graphite
	)

	# Long swept sensor wings use curved planform lofts and inset titanium roots.
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var wing := _build_planform_surface(
			"PortSensorWing" if side_index == 0 else "StarboardSensorWing",
			PackedVector3Array([
				Vector3(side * 0.9, 1.05, -1.6),
				Vector3(side * 5.35, 0.92, 0.75),
				Vector3(side * 5.75, 0.86, 3.65),
				Vector3(side * 1.15, 0.98, 2.8),
			]),
			0.18,
			_arrow_materials.ceramic
		)
		_arrow_visual.add_child(wing)
		_box(_arrow_visual, "WingRootRib", Vector3(side * 1.45, 1.03, 1.0), Vector3(1.25, 0.34, 4.8), _arrow_materials.titanium, Vector3(0, side * -0.08, 0))
		_curve_tube(
			_arrow_visual,
			"SensorLeadingEdge",
			PackedVector3Array([
				Vector3(side * 1.0, 1.19, -1.65),
				Vector3(side * 3.4, 1.1, -0.55),
				Vector3(side * 5.35, 1.02, 0.75),
			]),
			0.105,
			_arrow_materials.sensor
		)
		_loft_hull(
			_arrow_visual,
			"WingtipSensorPod",
			Vector3(side * 5.55, 1.0, 2.45),
			PackedVector3Array([
				Vector3(0.08, 0.06, -1.85),
				Vector3(0.33, 0.24, -1.25),
				Vector3(0.42, 0.28, 0.65),
				Vector3(0.18, 0.14, 1.75),
			]),
			_arrow_materials.titanium
		)
		_sphere(_arrow_visual, "PortNavigationLight" if side_index == 0 else "StarboardNavigationLight", Vector3(side * 5.64, 1.04, 3.35), 0.115, _arrow_materials.nav_red if side < 0 else _arrow_materials.nav_green)

	# Layered dorsal shell follows the long recon fuselage rather than adding a
	# blocky superstructure. Panel seams are slim and restrained.
	_loft_hull(
		_arrow_visual,
		"DorsalSurveySpine",
		Vector3(0, 2.08, 1.55),
		PackedVector3Array([
			Vector3(0.22, 0.1, -2.4),
			Vector3(0.67, 0.38, -1.35),
			Vector3(0.76, 0.42, 1.65),
			Vector3(0.44, 0.22, 3.0),
		]),
		_arrow_materials.ceramic
	)
	_curve_tube(
		_arrow_visual,
		"DorsalDataConduit",
		PackedVector3Array([
			Vector3(0, 2.52, -0.6),
			Vector3(0, 2.65, 1.45),
			Vector3(0, 2.42, 3.8),
		]),
		0.075,
		_arrow_materials.sensor
	)
	for seam_z in [-4.4, -2.6, 0.4, 2.2, 4.3]:
		_torus(_arrow_visual, "FuselagePanelBand", Vector3(0, 1.22, seam_z), 1.31, 1.35, _arrow_materials.titanium, Vector3(90, 0, 0), Vector3(1.0, 0.58, 1.0))


func _build_recon_systems() -> void:
	var mast := Node3D.new()
	mast.name = "ReconSensorMast"
	mast.position = Vector3(0, 2.5, 3.55)
	mast.set_meta("provisional_sensor_system", true)
	_arrow_visual.add_child(mast)
	_cylinder(mast, "MastPedestal", Vector3(0, 0.45, 0), 0.16, 0.9, _arrow_materials.titanium)
	_cylinder(mast, "MastStem", Vector3(0, 1.15, 0), 0.08, 0.72, _arrow_materials.graphite)
	_sensor_sweep = Node3D.new()
	_sensor_sweep.name = "SensorSweep"
	_sensor_sweep.position = Vector3(0, 1.48, 0)
	mast.add_child(_sensor_sweep)
	_torus(_sensor_sweep, "PassiveArrayRing", Vector3.ZERO, 0.45, 0.54, _arrow_materials.sensor, Vector3(90, 0, 0))
	_cylinder(_sensor_sweep, "ArrayCrossbar", Vector3.ZERO, 0.055, 1.45, _arrow_materials.titanium, Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		_sphere(_sensor_sweep, "ArrayReceiver", Vector3(side * 0.67, 0, 0), 0.15, _arrow_materials.sensor)

	# Ventral camera/spectral turret is a smooth gimbal, not a weapon hardpoint.
	_sphere(_arrow_visual, "VentralSensorGimbal", Vector3(0, -0.06, -1.8), 0.42, _arrow_materials.titanium)
	_sphere(_arrow_visual, "VentralSensorLens", Vector3(0, -0.33, -2.08), 0.2, _arrow_materials.sensor)
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_curve_tube(
			_arrow_visual,
			"PortLateralArray" if side_index == 0 else "StarboardLateralArray",
			PackedVector3Array([
				Vector3(side * 1.35, 1.36, -2.0),
				Vector3(side * 2.25, 1.38, -1.2),
				Vector3(side * 3.45, 1.25, -0.25),
			]),
			0.07,
			_arrow_materials.sensor
		)


func _build_escape_pods() -> void:
	_escape_pods.clear()
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var pod := Node3D.new()
		pod.name = "PortEscapePod" if side_index == 0 else "StarboardEscapePod"
		pod.position = Vector3(side * 1.62, 1.18, 3.25)
		pod.set_meta("escape_pod", true)
		pod.set_meta("pod_side", &"port" if side < 0 else &"starboard")
		pod.set_meta("pod_index", 0 if side < 0 else 1)
		pod.set_meta("historical_fact", &"two_escape_pods_total")
		pod.set_meta("geometry_status", EVIDENCE_STATUS)
		pod.set_meta("separable_visual_module", true)
		pod.set_meta("release_mechanism_implemented", false)
		_arrow_visual.add_child(pod)
		_escape_pods.append(pod)
		_loft_hull(
			pod,
			"PodPressureShell",
			Vector3.ZERO,
			PackedVector3Array([
				Vector3(0.08, 0.06, -1.45),
				Vector3(0.52, 0.42, -0.82),
				Vector3(0.58, 0.47, 0.72),
				Vector3(0.24, 0.18, 1.32),
			]),
			_arrow_materials.pod
		)
		_torus(pod, "PodSeparationCollar", Vector3.ZERO, 0.57, 0.65, _arrow_materials.graphite, Vector3(90, 0, 0), Vector3(1.0, 0.82, 1.0))
		_box(pod, "PodIdentityStripe", Vector3(side * 0.48, 0.02, -0.05), Vector3(0.06, 0.22, 1.55), _arrow_materials.sensor)
		_sphere(pod, "PodStatusLight", Vector3(side * 0.53, 0.14, -0.72), 0.085, _arrow_materials.sensor)


func _build_engines_and_landing_gear() -> void:
	_engine_plumes.clear()
	_arrow_engine_lights.clear()
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_loft_hull(
			_arrow_visual,
			"EfficientEngineHousing",
			Vector3(side * 0.92, 0.94, 5.0),
			PackedVector3Array([
				Vector3(0.32, 0.28, -1.5),
				Vector3(0.64, 0.55, -0.85),
				Vector3(0.68, 0.58, 1.1),
				Vector3(0.54, 0.44, 1.6),
			]),
			_arrow_materials.titanium
		)
		_torus(_arrow_visual, "EngineCollar", Vector3(side * 0.92, 0.94, 6.48), 0.55, 0.7, _arrow_materials.ceramic, Vector3(90, 0, 0))
		var plume := _cylinder(_arrow_visual, "PortEnginePlume" if side_index == 0 else "StarboardEnginePlume", Vector3(side * 0.92, 0.94, 6.92), 0.37, 0.78, _arrow_materials.engine, Vector3(90, 0, 0))
		_engine_plumes.append(plume)
		var light := OmniLight3D.new()
		light.name = "PortEngineLight" if side_index == 0 else "StarboardEngineLight"
		light.position = Vector3(side * 0.92, 0.94, 6.7)
		light.light_color = ENGINE_CYAN
		light.light_energy = 0.0
		light.omni_range = 6.2
		light.shadow_enabled = false
		_arrow_visual.add_child(light)
		_arrow_engine_lights.append(light)

	# Narrow tricycle gear suits the slender hull and keeps a stable parked pose.
	for side in [-1.0, 1.0]:
		_cylinder(_arrow_visual, "MainGearStrut", Vector3(side * 1.55, -0.05, 2.25), 0.07, 1.25, _arrow_materials.graphite, Vector3(0, 0, side * -8.0))
		_torus(_arrow_visual, "MainGearFoot", Vector3(side * 1.7, -0.64, 2.25), 0.22, 0.34, _arrow_materials.titanium, Vector3(90, 0, 0), Vector3(1.4, 0.55, 1.0))
	_cylinder(_arrow_visual, "NoseGearStrut", Vector3(0, -0.02, -4.2), 0.065, 1.12, _arrow_materials.graphite)
	_torus(_arrow_visual, "NoseGearFoot", Vector3(0, -0.56, -4.2), 0.18, 0.29, _arrow_materials.titanium, Vector3(90, 0, 0), Vector3(1.4, 0.55, 1.0))
	for step_index in 3:
		_box(_arrow_visual, "BoardingStep", Vector3(-1.65 - float(step_index) * 0.32, -0.12 + float(step_index) * 0.28, 0.05), Vector3(0.58, 0.1, 0.62), _arrow_materials.pod)


func _restyle_inherited_cockpit(cockpit: Node3D, canopy: Node3D) -> void:
	if cockpit != null:
		# Darker interior preserves high contrast behind the unusually clear canopy.
		for node in cockpit.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if "Display" in mesh_instance.name or "ConsoleKey" in mesh_instance.name:
				mesh_instance.material_override = _arrow_materials.sensor
	if canopy != null:
		var glass := canopy.get_node_or_null("CanopyGlass") as MeshInstance3D
		if glass != null:
			glass.material_override = _arrow_materials.glass
			# Retain the inherited physical canopy envelope. Enlarging the shell
			# independently of its private camera/hinge geometry creates a cyan first-
			# person wash and overstates the high-visibility canopy from outside.
			glass.scale = Vector3.ONE
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _arrow_materials.graphite
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _arrow_materials.ceramic


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	_add_box_collision("ArrowHullCollision", Vector3(0, 0.85, -0.35), Vector3(3.1, 1.65, 12.2))
	_add_box_collision("ArrowWingCollision", Vector3(0, 0.88, 1.25), Vector3(11.1, 0.48, 4.9))

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if boarding != null:
		boarding.position = Vector3(-2.45, -0.02, 0.15)
	if exit != null:
		exit.position = Vector3(-6.6, -0.9, 0.25)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = Vector3(-1.05, 0.72, -5.7)
	if right_muzzle != null:
		right_muzzle.position = Vector3(1.05, 0.72, -5.7)
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-2.45, 0.48, 0.15)


func _add_box_collision(node_name: String, collision_position: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)


func _update_arrow_presentation(delta: float) -> void:
	if _sensor_sweep != null:
		_sensor_sweep.rotation.y = fmod(_sensor_sweep.rotation.y + delta * 0.42, TAU)
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.25 + 0.1 * sin(_elapsed_arrow * 16.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.48 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.52
	var damage_presentation := get_damage_presentation()
	if is_instance_valid(damage_presentation):
		engine_level *= clampf(damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
	for plume in _engine_plumes:
		plume.visible = engine_level > 0.01
		plume.scale.z = lerpf(plume.scale.z, 0.42 + engine_level * 1.3, 1.0 - exp(-8.0 * delta))
	for light in _arrow_engine_lights:
		light.light_energy = engine_level * 2.2


func _sync_arrow_engine_presentation_immediately() -> void:
	var telemetry := get_telemetry()
	var state := StringName(telemetry.get("engine_state", ENGINE_OFFLINE))
	var active := not is_destroyed() and state in [ENGINE_STARTING, ENGINE_ONLINE]
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = active
			if not active:
				plume.scale.z = 0.42
	for light in _arrow_engine_lights:
		if is_instance_valid(light):
			light.light_energy = 0.55 if active and state == ENGINE_STARTING else (1.1 if active else 0.0)


func request_engine_start() -> void:
	super.request_engine_start()
	_sync_arrow_engine_presentation_immediately()


func request_engine_stop(play_transition_cue: bool = true) -> void:
	super.request_engine_stop(play_transition_cue)
	_sync_arrow_engine_presentation_immediately()


func reset_for_reuse(spawn_transform: Transform3D) -> void:
	super.reset_for_reuse(spawn_transform)
	_sync_arrow_engine_presentation_immediately()


func _apply_arrow_metadata() -> void:
	set_meta("arrow_recon_candidate", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("creator_supported_escape_pod_count", SUPPORTED_ESCAPE_POD_COUNT)
	set_meta("content_note", PROVISIONAL_NOTE)
	set_meta("weapon_class", &"light_recon_pulse")
	set_meta("engine_profile", &"efficient_twin_recon")


func _material(color: Color, metallic: float, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _transparent_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := _material(color, metallic, roughness)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


func _loft_hull(parent: Node3D, node_name: String, origin: Vector3, sections: PackedVector3Array, material: Material) -> MeshInstance3D:
	const RING_COUNT := 20
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in RING_COUNT:
			var angle := TAU * float(ring_index) / float(RING_COUNT)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.72)
			var rounded_y := signf(sine) * pow(absf(sine), 0.72)
			tool.set_uv(Vector2(float(ring_index) / float(RING_COUNT), float(section_index) / float(maxi(1, sections.size() - 1))))
			tool.add_vertex(Vector3(section.x * rounded_x, section.y * rounded_y, section.z))
	for section_index in sections.size() - 1:
		for ring_index in RING_COUNT:
			var next_ring := (ring_index + 1) % RING_COUNT
			var current := section_index * RING_COUNT + ring_index
			var current_next := section_index * RING_COUNT + next_ring
			var following := (section_index + 1) * RING_COUNT + ring_index
			var following_next := (section_index + 1) * RING_COUNT + next_ring
			tool.add_index(current)
			tool.add_index(following)
			tool.add_index(following_next)
			tool.add_index(current)
			tool.add_index(following_next)
			tool.add_index(current_next)
	var front_center := sections.size() * RING_COUNT
	tool.add_vertex(Vector3(0, 0, sections[0].z))
	var rear_center := front_center + 1
	tool.add_vertex(Vector3(0, 0, sections[sections.size() - 1].z))
	for ring_index in RING_COUNT:
		var next_ring := (ring_index + 1) % RING_COUNT
		tool.add_index(front_center)
		tool.add_index(next_ring)
		tool.add_index(ring_index)
		var rear_base := (sections.size() - 1) * RING_COUNT
		tool.add_index(rear_center)
		tool.add_index(rear_base + ring_index)
		tool.add_index(rear_base + next_ring)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _build_planform_surface(node_name: String, outline: PackedVector3Array, thickness: float, material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var half_thickness := thickness * 0.5
	for point in outline:
		tool.add_vertex(point + Vector3.UP * half_thickness)
	for point in outline:
		tool.add_vertex(point - Vector3.UP * half_thickness)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		tool.add_index(triangle[0])
		tool.add_index(triangle[1])
		tool.add_index(triangle[2])
		tool.add_index(outline.size() + triangle[0])
		tool.add_index(outline.size() + triangle[2])
		tool.add_index(outline.size() + triangle[1])
	for index in outline.size():
		var next := (index + 1) % outline.size()
		var top_a := index
		var top_b := next
		var bottom_a := outline.size() + index
		var bottom_b := outline.size() + next
		tool.add_index(top_a)
		tool.add_index(bottom_a)
		tool.add_index(bottom_b)
		tool.add_index(top_a)
		tool.add_index(bottom_b)
		tool.add_index(top_b)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	return instance


func _curve_tube(parent: Node3D, node_name: String, points: PackedVector3Array, radius: float, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for index in points.size() - 1:
		var direction := points[index + 1] - points[index]
		var segment := _cylinder(root, "Segment%02d" % index, (points[index] + points[index + 1]) * 0.5, radius, direction.length(), material)
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	for point in points:
		_sphere(root, "CurveJoint", point, radius, material)
	return root


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation = rotation
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 36
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 28
	mesh.rings = 14
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _torus(parent: Node3D, node_name: String, position: Vector3, inner_radius: float, outer_radius: float, material: Material, rotation_degrees_value := Vector3.ZERO, scale_value := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	instance.scale = scale_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 64
	mesh.ring_segments = 18
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance
