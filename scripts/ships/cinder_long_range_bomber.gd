class_name CinderLongRangeBomber
extends HeroShip

## Original-modern long-range bomber component. No historical craft, weapon,
## payload, or mission claim is authenticated here.

const PayloadAuthority := preload("res://scripts/combat/bomber_payload_authority.gd")
const PayloadPresentation := preload("res://scripts/effects/bomber_payload_presentation.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const BomberPayloadAudioBindingType := preload("res://scripts/audio/bomber_payload_audio_binding.gd")

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-long-range-bomber"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder long-range bomber"
const PAYLOAD_HARDPOINT_COUNT := 4
const PAYLOAD_AUTHORITY_PEER_ID := 1
const PAYLOAD_AMMUNITION := 4
const PAYLOAD_COOLDOWN_SECONDS := 1.0
const PAYLOAD_ID: StringName = &"cinder_payload_alpha"
const PAYLOAD_WEAPON_ID: StringName = &"bomber_payload_release"
const PAYLOAD_PRESENTATION_ID: StringName = &"payload_release_flash"
const PAYLOAD_AUDIO_ID: StringName = &"payload_release_audio"
const HULL_SIZE := Vector3(7.0, 3.0, 15.5)
const HULL_COLOR := Color("3e4d57")
const ORDNANCE_COLOR := Color("b85a3c")
const SENSOR_COLOR := Color("d6b45d")

# The primary hull is immutable presentation stock. Production may briefly own
# more than one bomber during fleet composition/replacement, so retain one
# process-local recipe instead of allocating the same mesh and material for
# every copy. Renderer nodes, submissions, transforms and physical authority
# remain per craft.
static var _shared_hull_mesh: BoxMesh
static var _shared_hull_material: StandardMaterial3D

var _bomber_boarding_marker: Marker3D
var _payload_hardpoints: Array[Marker3D] = []
var _bomber_built := false
var _payload_authority: BomberPayloadAuthority
var _payload_presentation
var _ship_perspective_audio_binding: RefCounted
var _payload_audio_binding: Node


func _init() -> void:
	_payload_authority = PayloadAuthority.new(
		PAYLOAD_AUTHORITY_PEER_ID,
		PAYLOAD_AMMUNITION,
		PAYLOAD_COOLDOWN_SECONDS
	)


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_cinder_perspective_audio")
	if _payload_audio_binding != null:
		call_deferred("_rebind_cinder_payload_audio")


func _ready() -> void:
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Long-range bomber"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_cinder_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not _bomber_built:
		_bomber_built = rebuild_variant_presentation(_build_bomber_variant)
	_build_payload_presentation()
	_build_payload_audio_binding()


func _exit_tree() -> void:
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_cinder_camera_view_changed):
			camera_view_changed.disconnect(_on_cinder_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	if _payload_audio_binding != null:
		_payload_audio_binding.detach()
	super._exit_tree()

func _rebind_cinder_payload_audio() -> void:
	if not is_inside_tree() or _payload_audio_binding == null:
		return
	var snapshot: Dictionary = _payload_audio_binding.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		_payload_audio_binding.attach(int(snapshot.get("generation", 0)))


func _rebind_cinder_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null \
			or _ship_audio_rig == null or not is_instance_valid(_ship_audio_rig):
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) \
			and not camera_view_changed.is_connected(_on_cinder_camera_view_changed):
		camera_view_changed.connect(_on_cinder_camera_view_changed)


func _on_cinder_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)


func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() \
		if _ship_perspective_audio_binding != null else {"attached": false}


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	if _payload_authority != null:
		_payload_authority.advance(maxf(delta, 0.0))
	if is_instance_valid(_payload_presentation):
		_payload_presentation.advance_simulation(maxf(delta, 0.0))


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	if _payload_authority != null and bool(_payload_authority.get_snapshot().get("active", false)):
		_payload_authority.detach(&"ship_reused")
	if is_instance_valid(_payload_presentation):
		_payload_presentation.detach()


func _build_bomber_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderBomberVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_build_hull(visual)
	_build_cockpit_and_boarding(visual)
	_build_payload_hardpoints(visual)
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _bomber_boarding_marker


func get_payload_hardpoints() -> Array[Marker3D]:
	return _payload_hardpoints.duplicate()


## Starts the caller-owned payload admission lifecycle. Cinder does not infer a
## generation from scene entry; its session/shipyard owner must provide one.
func begin_payload_generation(generation: int) -> Dictionary:
	var result := _payload_authority.begin_generation(generation)
	if bool(result.get("accepted", false)):
		_sync_payload_audio_generation(generation)
	return result


## Re-enters payload admission after explicit detach or HeroShip reuse cleanup.
func reset_payload_for_reuse(generation: int) -> Dictionary:
	var result := _payload_authority.reset_for_reuse(generation)
	if bool(result.get("accepted", false)) and is_instance_valid(_payload_presentation):
		_payload_presentation.reset_for_reuse()
	if bool(result.get("accepted", false)):
		_sync_payload_audio_generation(generation)
	return result


func detach_payload_authority(reason: StringName = &"detached") -> Dictionary:
	var result := _payload_authority.detach(reason)
	if bool(result.get("accepted", false)) and is_instance_valid(_payload_presentation):
		_payload_presentation.detach()
	if bool(result.get("accepted", false)) and _payload_audio_binding != null:
		_payload_audio_binding.detach()
	return result


func advance_payload_cooldown(delta: float) -> Dictionary:
	return _payload_authority.advance(delta)


func get_payload_authority_snapshot() -> Dictionary:
	return _payload_authority.get_snapshot()


func get_payload_presentation():
	return _payload_presentation

func get_payload_audio_binding() -> Node:
	return _payload_audio_binding


## Presentation-only caller seam for graphics/accessibility composition. The
## bomber forwards policy but retains no settings, UI, or profile authority.
func set_payload_presentation_profile(
		payload_visual_intensity: StringName,
		reduced_flash: bool
) -> Dictionary:
	if not is_instance_valid(_payload_presentation):
		return {"accepted": false, "reason": &"payload_presentation_unavailable"}
	return _payload_presentation.apply_presentation_profile(payload_visual_intensity, reduced_flash)


## Mirrors one terminal record already emitted by BomberPayloadProjectile (and
## accepted by the caller's combat path) into the visual pool. Cinder neither
## submits collision evidence nor interprets target, damage, or scoring fields.
func present_payload_terminal_record(terminal_record: Dictionary) -> Dictionary:
	if not is_instance_valid(_payload_presentation):
		return {"accepted": false, "reason": &"payload_presentation_unavailable"}
	var result: Dictionary = _payload_presentation.consume_terminal_record(terminal_record)
	if bool(result.get("accepted", false)) and _payload_audio_binding != null:
		result["audio"] = _payload_audio_binding.present_projectile_terminal(terminal_record)
	return result


## Maps one authored hardpoint to a finite release pose and delegates all
## admission/resource/sequence checks to BomberPayloadAuthority. The returned
## record is unresolved; a later CombatResolver owns actual ordnance effects.
func request_payload_release(
		source_peer_id: int,
		actor_id: StringName,
		generation: int,
		request_sequence: int,
		hardpoint_index: int,
		release_velocity: Vector3,
		payload_id: StringName = PAYLOAD_ID,
		weapon_id: StringName = PAYLOAD_WEAPON_ID,
		presentation_id: StringName = PAYLOAD_PRESENTATION_ID,
		audio_id: StringName = PAYLOAD_AUDIO_ID
) -> Dictionary:
	if hardpoint_index < 0 or hardpoint_index >= _payload_hardpoints.size():
		return {"accepted": false, "reason": &"invalid_hardpoint"}
	var hardpoint := _payload_hardpoints[hardpoint_index]
	if not is_instance_valid(hardpoint):
		return {"accepted": false, "reason": &"hardpoint_unavailable"}
	var payload := {
		"generation": generation,
		"payload_id": payload_id,
		"weapon_id": weapon_id,
		"presentation_id": presentation_id,
		"audio_id": audio_id,
		"release_position": hardpoint.global_position,
		"release_velocity": release_velocity,
	}
	var result := _payload_authority.submit_release_intent(
		source_peer_id,
		actor_id,
		payload,
		request_sequence
	)
	if bool(result.get("accepted", false)):
		result["hardpoint_index"] = hardpoint_index
		result["presentation"] = (
			_payload_presentation.consume_release_record(result.get("record", {}) as Dictionary)
			if is_instance_valid(_payload_presentation)
			else {"accepted": false, "reason": &"payload_presentation_unavailable"}
		)
		if _payload_audio_binding != null:
			result["audio"] = _payload_audio_binding.present_release_record(result.get("record", {}) as Dictionary)
	return result.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var hull_sharing := get_hull_resource_sharing_audit()
	if not _bomber_built:
		errors.append("bomber has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_bomber_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if _payload_hardpoints.size() != PAYLOAD_HARDPOINT_COUNT:
		errors.append("four caller-owned payload hardpoints are required")
	if _payload_authority == null or not _payload_authority.is_configuration_valid():
		errors.append("bomber payload admission authority is unavailable")
	if (
		not is_instance_valid(_payload_presentation)
		or _payload_presentation.get_parent() != self
		or not bool(_payload_presentation.get_audit_report().get("valid", false))
	):
		errors.append("bounded bomber payload presentation is unavailable")
	if not bool(get_landing_collision_report().get("valid", false)):
		errors.append("bomber requires HeroShip root collision")
	if not bool(hull_sharing.get("valid", false)):
		errors.append("bomber immutable hull resource sharing drifted")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"payload_hardpoint_count": _payload_hardpoints.size(),
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"combat_authority": false,
		"ordnance_authority": false,
		"payload_admission_authority": true,
		"payload_records_unresolved": true,
		"payload_presentation_composed": is_instance_valid(_payload_presentation),
		"payload_presentation_authority": false,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
		"hull_resource_sharing": hull_sharing,
	}.duplicate(true)


## Detached exact-recipe evidence for the one cross-copy cached visual family.
## Structural submissions are mesh surfaces, not a driver draw-call claim.
func get_hull_resource_sharing_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var hull := visual.get_node_or_null(^"LongRangeHull") as MeshInstance3D if visual != null else null
	var mesh := hull.mesh as BoxMesh if hull != null else null
	var material := hull.material_override as StandardMaterial3D if hull != null else null
	if hull == null:
		errors.append("LongRangeHull renderer is missing")
	else:
		if not hull.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("LongRangeHull transform drifted")
		if not hull.visible or hull.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("LongRangeHull renderer state drifted")
		if hull.get_child_count() != 0 or hull.get_script() != null:
			errors.append("LongRangeHull gained semantic children or authority")
	if mesh == null or mesh != _shared_hull_mesh:
		errors.append("LongRangeHull shared mesh identity drifted")
	elif not mesh.size.is_equal_approx(HULL_SIZE) or mesh.get_surface_count() != 1:
		errors.append("LongRangeHull mesh recipe drifted")
	elif mesh.resource_local_to_scene:
		errors.append("LongRangeHull mesh became scene-local")
	if material == null or material != _shared_hull_material:
		errors.append("LongRangeHull shared material identity drifted")
	elif (
		not material.albedo_color.is_equal_approx(HULL_COLOR)
		or not is_equal_approx(material.metallic, 0.78)
		or not is_equal_approx(material.roughness, 0.4)
		or material.resource_local_to_scene
	):
		errors.append("LongRangeHull material recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family": &"LongRangeHull",
		"renderer_nodes_per_copy": 1 if hull != null else 0,
		"geometry_submissions_per_copy": mesh.get_surface_count() if mesh != null else 0,
		"visible_copies_per_bomber": 1 if hull != null and hull.visible else 0,
		"mesh_resource_id": mesh.get_instance_id() if mesh != null else 0,
		"material_resource_id": material.get_instance_id() if material != null else 0,
		"legacy_two_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"unique_mesh_resources": 2,
			"unique_material_resources": 2,
		},
		"current_two_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"unique_mesh_resources": 1,
			"unique_material_resources": 1,
		},
	}.duplicate(true)


func _build_payload_presentation() -> void:
	if is_instance_valid(_payload_presentation):
		return
	_payload_presentation = PayloadPresentation.new()
	_payload_presentation.name = "BomberPayloadPresentation"
	add_child(_payload_presentation)

func _build_payload_audio_binding() -> void:
	if is_instance_valid(_payload_audio_binding):
		return
	_payload_audio_binding = BomberPayloadAudioBindingType.new()
	_payload_audio_binding.name = "BomberPayloadAudioBinding"
	add_child(_payload_audio_binding)
	_payload_audio_binding.attach(0)

func _sync_payload_audio_generation(generation: int) -> void:
	if _payload_audio_binding == null:
		return
	var snapshot: Dictionary = _payload_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		_payload_audio_binding.detach()
		snapshot = _payload_audio_binding.get_snapshot()
	var current := int(snapshot.get("generation", 0))
	while current < generation:
		_payload_audio_binding.attach(current)
		_payload_audio_binding.detach()
		current = int(_payload_audio_binding.get_snapshot().get("generation", current + 1))
	if current == generation:
		_payload_audio_binding.attach(current)


func _build_collision() -> void:
	_add_box_collision_shape("BomberHullCollision", Vector3(0.0, 0.0, 0.0), HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "LongRangeHull"
	if _shared_hull_mesh == null:
		_shared_hull_mesh = BoxMesh.new()
		_shared_hull_mesh.size = HULL_SIZE
		_shared_hull_mesh.resource_local_to_scene = false
	if _shared_hull_material == null:
		_shared_hull_material = _material(HULL_COLOR, 0.78, 0.4)
		_shared_hull_material.resource_local_to_scene = false
	hull.mesh = _shared_hull_mesh
	hull.material_override = _shared_hull_material
	visual.add_child(hull)
	var ordnance := MeshInstance3D.new()
	ordnance.name = "OrdnanceSpine"
	var ordnance_mesh := BoxMesh.new()
	ordnance_mesh.size = Vector3(2.2, 1.25, 8.4)
	ordnance.mesh = ordnance_mesh
	ordnance.position = Vector3(0.0, -0.15, 1.5)
	ordnance.material_override = _material(ORDNANCE_COLOR, 0.52, 0.4)
	visual.add_child(ordnance)
	var sensor := MeshInstance3D.new()
	sensor.name = "LongRangeSensor"
	var sensor_mesh := SphereMesh.new()
	sensor_mesh.radius = 0.62
	sensor_mesh.height = 1.24
	sensor.mesh = sensor_mesh
	sensor.position = Vector3(0.0, 1.6, -5.2)
	sensor.material_override = _material(SENSOR_COLOR, 0.35, 0.4, SENSOR_COLOR, 1.8)
	visual.add_child(sensor)


func _build_cockpit_and_boarding(visual: Node3D) -> void:
	_bomber_boarding_marker = Marker3D.new()
	_bomber_boarding_marker.name = "BoardingMarker"
	_bomber_boarding_marker.position = Vector3(-3.8, -1.0, -0.5)
	_bomber_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_bomber_boarding_marker)


func _build_payload_hardpoints(visual: Node3D) -> void:
	for index in PAYLOAD_HARDPOINT_COUNT:
		var hardpoint := Marker3D.new()
		hardpoint.name = "PayloadHardpoint%02d" % (index + 1)
		hardpoint.position = Vector3(-1.55 if index % 2 == 0 else 1.55, -1.0, -2.4 + float(index / 2) * 4.8)
		hardpoint.set_meta(&"payload_slot_index", index)
		hardpoint.set_meta(&"ordnance_owner", COMPONENT_ID)
		visual.add_child(hardpoint)
		_payload_hardpoints.append(hardpoint)
