class_name CinderLongRangeBomber
extends HeroShip

## Original-modern long-range bomber component. No historical craft, weapon,
## payload, or mission claim is authenticated here.

const PayloadAuthority := preload("res://scripts/combat/bomber_payload_authority.gd")
const PayloadPresentation := preload("res://scripts/effects/bomber_payload_presentation.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const BomberPayloadAudioBindingType := preload("res://scripts/audio/bomber_payload_audio_binding.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

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
const ORDNANCE_SPINE_SIZE := Vector3(2.2, 1.25, 8.4)
const ORDNANCE_SPINE_POSITION := Vector3(0.0, -0.15, 1.5)
const STRIKE_WING_SIZE := Vector3(5.0, 0.3, 6.2)
const STRIKE_WING_OFFSET := Vector3(5.15, -0.45, 0.65)
const STRIKE_WING_SWEEP_DEGREES := 12.0
const SENSOR_RADIUS := 0.62
const SENSOR_HEIGHT := 1.24
const SENSOR_POSITION := Vector3(0.0, 1.6, -5.2)
const HULL_COLOR := Color("3e4d57")
const ORDNANCE_COLOR := Color("b85a3c")
const SENSOR_COLOR := Color("d6b45d")
## Static presentation of an already-authoritative starboard-wing stage. The
## raised vane sits on the bomber's outboard upper surface, where the chase view
## sees both its hot face and its silhouette without crossing the central aim,
## cockpit, boarding, or payload lanes.
const DAMAGE_CUE_COMPONENT_ID: StringName = &"starboard_wing"
const DAMAGE_CUE_POSITION := Vector3(5.15, -0.45, 0.65)
const DAMAGE_CUE_ROTATION_DEGREES := Vector3(0.0, 12.0, 0.0)
const DAMAGE_SCORCH_SIZE := Vector3(2.6, 0.06, 2.4)
const DAMAGE_SCORCH_POSITION := Vector3(0.0, 0.18, 0.0)
const DAMAGE_VANE_SIZE := Vector3(0.22, 0.66, 2.2)
const DAMAGE_VANE_POSITION := Vector3(0.0, 0.51, 0.0)
const DAMAGE_SCORCH_COLOR := Color("171b1d")
const DAMAGE_VANE_COLOR := Color("ff6a36")

# The primary hull, painted ordnance spine and sensor are immutable presentation stock.
# Production may briefly own more than one bomber during fleet composition or
# replacement, so retain one process-local recipe instead of allocating the
# same meshes and materials for every copy. Renderer nodes, submissions,
# transforms and physical authority remain per craft.
static var _shared_hull_mesh: BoxMesh
static var _shared_hull_material: StandardMaterial3D
static var _shared_ordnance_spine_mesh: BoxMesh
static var _shared_ordnance_spine_material: StandardMaterial3D
static var _shared_strike_wing_mesh: BoxMesh
static var _shared_sensor_mesh: SphereMesh
static var _shared_sensor_material: StandardMaterial3D
static var _shared_damage_scorch_mesh: BoxMesh
static var _shared_damage_scorch_material: StandardMaterial3D
static var _shared_damage_vane_mesh: BoxMesh
static var _shared_damage_vane_material: StandardMaterial3D

var _bomber_boarding_marker: Marker3D
var _payload_hardpoints: Array[Marker3D] = []
var _bomber_built := false
var _payload_authority: BomberPayloadAuthority
var _payload_presentation
var _ship_perspective_audio_binding: RefCounted
var _payload_audio_binding: Node
var _component_damage_cue: Node3D


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
	if not component_damage_changed.is_connected(_on_bomber_component_damage_changed):
		component_damage_changed.connect(_on_bomber_component_damage_changed)
	_sync_component_damage_cue()
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
	_sync_component_damage_cue()
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
	_build_strike_wings(visual)
	_build_cockpit_and_boarding(visual)
	_build_payload_hardpoints(visual)
	_build_component_damage_cue(visual)
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
	var strike_wing_visual := get_strike_wing_visual_audit()
	var sensor_sharing := get_sensor_resource_sharing_audit()
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
		errors.append("bomber immutable primary visual resource sharing drifted")
	if not bool(strike_wing_visual.get("valid", false)):
		errors.append("bomber swept strike-wing silhouette drifted")
	if not bool(sensor_sharing.get("valid", false)):
		errors.append("bomber immutable sensor visual resource sharing drifted")
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
		"strike_wing_visual": strike_wing_visual,
		"sensor_resource_sharing": sensor_sharing,
	}.duplicate(true)


## Presentation-only silhouette recipe. The mirrored renderers share one
## immutable mesh and the primary hull material; they own no collision or
## gameplay children.
func get_strike_wing_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var port := visual.get_node_or_null(^"PortStrikeWing") as MeshInstance3D \
			if visual != null else null
	var starboard := visual.get_node_or_null(^"StarboardStrikeWing") as MeshInstance3D \
			if visual != null else null
	for entry in [
		[port, -STRIKE_WING_OFFSET.x, -STRIKE_WING_SWEEP_DEGREES],
		[starboard, STRIKE_WING_OFFSET.x, STRIKE_WING_SWEEP_DEGREES],
	]:
		var wing := entry[0] as MeshInstance3D
		if wing == null:
			errors.append("strike-wing renderer is missing")
			continue
		var expected_position := Vector3(float(entry[1]), STRIKE_WING_OFFSET.y, STRIKE_WING_OFFSET.z)
		if not wing.position.is_equal_approx(expected_position) \
				or not is_equal_approx(wing.rotation_degrees.y, float(entry[2])):
			errors.append("strike-wing mirrored sweep drifted")
		if not wing.visible or wing.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("strike-wing renderer state drifted")
		if wing.get_child_count() != 0 or wing.get_script() != null:
			errors.append("strike wing gained semantic children or authority")
		if wing.mesh != _shared_strike_wing_mesh \
				or wing.material_override != _shared_hull_material:
			errors.append("strike-wing immutable resource identity drifted")
	if _shared_strike_wing_mesh == null \
			or not _shared_strike_wing_mesh.size.is_equal_approx(STRIKE_WING_SIZE) \
			or _shared_strike_wing_mesh.resource_local_to_scene:
		errors.append("strike-wing mesh recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"renderer_nodes_per_copy": int(port != null) + int(starboard != null),
		"geometry_submissions_per_copy": 2 if port != null and starboard != null else 0,
		"shared_mesh_resource_id": _shared_strike_wing_mesh.get_instance_id() \
				if _shared_strike_wing_mesh != null else 0,
		"shared_hull_material_resource_id": _shared_hull_material.get_instance_id() \
				if _shared_hull_material != null else 0,
	}.duplicate(true)


## Detached exact-recipe evidence for the cross-copy cached primary visual stock.
## Structural submissions are mesh surfaces, not a driver draw-call claim.
func get_hull_resource_sharing_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var hull := visual.get_node_or_null(^"LongRangeHull") as MeshInstance3D if visual != null else null
	var mesh := hull.mesh as BoxMesh if hull != null else null
	var material := hull.material_override as StandardMaterial3D if hull != null else null
	var ordnance := visual.get_node_or_null(^"OrdnanceSpine") as MeshInstance3D if visual != null else null
	var ordnance_mesh := ordnance.mesh as BoxMesh if ordnance != null else null
	var ordnance_material := ordnance.material_override as StandardMaterial3D if ordnance != null else null
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
	if ordnance == null:
		errors.append("OrdnanceSpine renderer is missing")
	else:
		var expected_transform := Transform3D(Basis.IDENTITY, ORDNANCE_SPINE_POSITION)
		if not ordnance.transform.is_equal_approx(expected_transform):
			errors.append("OrdnanceSpine transform drifted")
		if not ordnance.visible \
				or ordnance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("OrdnanceSpine renderer state drifted")
		if ordnance.get_child_count() != 0 or ordnance.get_script() != null:
			errors.append("OrdnanceSpine gained semantic children or authority")
	if ordnance_mesh == null or ordnance_mesh != _shared_ordnance_spine_mesh:
		errors.append("OrdnanceSpine shared mesh identity drifted")
	elif not ordnance_mesh.size.is_equal_approx(ORDNANCE_SPINE_SIZE) \
			or ordnance_mesh.get_surface_count() != 1:
		errors.append("OrdnanceSpine mesh recipe drifted")
	elif ordnance_mesh.resource_local_to_scene:
		errors.append("OrdnanceSpine mesh became scene-local")
	if ordnance_material == null or ordnance_material != _shared_ordnance_spine_material:
		errors.append("OrdnanceSpine shared material identity drifted")
	elif (
		not ordnance_material.albedo_color.is_equal_approx(ORDNANCE_COLOR)
		or not is_equal_approx(ordnance_material.metallic, 0.52)
		or not is_equal_approx(ordnance_material.roughness, 0.4)
		or ordnance_material.resource_local_to_scene
	):
		errors.append("OrdnanceSpine material recipe drifted")
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
		"ordnance_spine": {
			"renderer_nodes_per_copy": 1 if ordnance != null else 0,
			"geometry_submissions_per_copy": ordnance_mesh.get_surface_count() \
				if ordnance_mesh != null else 0,
			"visible_copies_per_bomber": 1 if ordnance != null and ordnance.visible else 0,
			"mesh_resource_id": ordnance_mesh.get_instance_id() if ordnance_mesh != null else 0,
			"material_resource_id": ordnance_material.get_instance_id() \
				if ordnance_material != null else 0,
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
		},
	}.duplicate(true)


## Detached exact-recipe evidence for the cross-copy cached sensor visual stock.
## Each craft retains its own renderer and structural surface submission.
func get_sensor_resource_sharing_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var sensor := visual.get_node_or_null(^"LongRangeSensor") as MeshInstance3D \
			if visual != null else null
	var mesh := sensor.mesh as SphereMesh if sensor != null else null
	var material := sensor.material_override as StandardMaterial3D if sensor != null else null
	if sensor == null:
		errors.append("LongRangeSensor renderer is missing")
	else:
		var expected_transform := Transform3D(Basis.IDENTITY, SENSOR_POSITION)
		if not sensor.transform.is_equal_approx(expected_transform):
			errors.append("LongRangeSensor transform drifted")
		if not sensor.visible \
				or sensor.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("LongRangeSensor renderer state drifted")
		if sensor.get_child_count() != 0 or sensor.get_script() != null:
			errors.append("LongRangeSensor gained semantic children or authority")
	if mesh == null or mesh != _shared_sensor_mesh:
		errors.append("LongRangeSensor shared mesh identity drifted")
	elif (
		not is_equal_approx(mesh.radius, SENSOR_RADIUS)
		or not is_equal_approx(mesh.height, SENSOR_HEIGHT)
		or mesh.get_surface_count() != 1
	):
		errors.append("LongRangeSensor mesh recipe drifted")
	elif mesh.resource_local_to_scene:
		errors.append("LongRangeSensor mesh became scene-local")
	if material == null or material != _shared_sensor_material:
		errors.append("LongRangeSensor shared material identity drifted")
	elif (
		not material.albedo_color.is_equal_approx(SENSOR_COLOR)
		or not is_equal_approx(material.metallic, 0.35)
		or not is_equal_approx(material.roughness, 0.4)
		or not material.emission_enabled
		or not material.emission.is_equal_approx(SENSOR_COLOR)
		or not is_equal_approx(material.emission_energy_multiplier, 1.8)
		or material.resource_local_to_scene
	):
		errors.append("LongRangeSensor material recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family": &"LongRangeSensor",
		"renderer_nodes_per_copy": 1 if sensor != null else 0,
		"geometry_submissions_per_copy": mesh.get_surface_count() if mesh != null else 0,
		"visible_copies_per_bomber": 1 if sensor != null and sensor.visible else 0,
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


## Detached presentation snapshot. It reports the retained renderer state but
## offers no mutation seam into the component ledger or HeroShip recovery path.
func get_component_damage_cue_snapshot() -> Dictionary:
	var visual := get_variant_visual_root()
	var cue := visual.get_node_or_null(^"StarboardWingDamageCue") as Node3D \
			if visual != null else null
	var scorch := cue.get_node_or_null(^"DamageScorch") as MeshInstance3D \
			if cue != null else null
	var vane := cue.get_node_or_null(^"ExposedDamageVane") as MeshInstance3D \
			if cue != null else null
	var bounds := AABB()
	var has_bounds := false
	for renderer in [scorch, vane]:
		if renderer == null or renderer.mesh == null or cue == null:
			continue
		var renderer_bounds: AABB = cue.transform * renderer.transform * renderer.mesh.get_aabb()
		bounds = renderer_bounds if not has_bounds else bounds.merge(renderer_bounds)
		has_bounds = true
	var model := get_component_damage()
	return {
		"component_id": DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamageType.state_id_for(
			model.get_component_state(DAMAGE_CUE_COMPONENT_ID)
		) if model != null and model.is_configured() else &"unavailable",
		"visible": cue.visible if cue != null else false,
		"local_bounds": bounds,
		"view_lane_clear": has_bounds and bounds.position.x > HULL_SIZE.x * 0.5,
		"renderer_nodes_per_copy": int(scorch != null) + int(vane != null),
		"geometry_submissions_per_copy": 2 if scorch != null and vane != null else 0,
		"mesh_resource_ids": PackedInt64Array([
			_shared_damage_scorch_mesh.get_instance_id() if _shared_damage_scorch_mesh != null else 0,
			_shared_damage_vane_mesh.get_instance_id() if _shared_damage_vane_mesh != null else 0,
		]),
		"material_resource_ids": PackedInt64Array([
			_shared_damage_scorch_material.get_instance_id() if _shared_damage_scorch_material != null else 0,
			_shared_damage_vane_material.get_instance_id() if _shared_damage_vane_material != null else 0,
		]),
		"processes": false,
		"flashes": false,
		"damage_authority": false,
		"repair_authority": false,
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
	if _shared_ordnance_spine_mesh == null:
		_shared_ordnance_spine_mesh = BoxMesh.new()
		_shared_ordnance_spine_mesh.size = ORDNANCE_SPINE_SIZE
		_shared_ordnance_spine_mesh.resource_local_to_scene = false
	if _shared_ordnance_spine_material == null:
		_shared_ordnance_spine_material = _material(ORDNANCE_COLOR, 0.52, 0.4)
		_shared_ordnance_spine_material.resource_local_to_scene = false
	ordnance.mesh = _shared_ordnance_spine_mesh
	ordnance.position = ORDNANCE_SPINE_POSITION
	ordnance.material_override = _shared_ordnance_spine_material
	visual.add_child(ordnance)
	var sensor := MeshInstance3D.new()
	sensor.name = "LongRangeSensor"
	if _shared_sensor_mesh == null:
		_shared_sensor_mesh = SphereMesh.new()
		_shared_sensor_mesh.radius = SENSOR_RADIUS
		_shared_sensor_mesh.height = SENSOR_HEIGHT
		_shared_sensor_mesh.resource_local_to_scene = false
	if _shared_sensor_material == null:
		_shared_sensor_material = _material(SENSOR_COLOR, 0.35, 0.4, SENSOR_COLOR, 1.8)
		_shared_sensor_material.resource_local_to_scene = false
	sensor.mesh = _shared_sensor_mesh
	sensor.position = SENSOR_POSITION
	sensor.material_override = _shared_sensor_material
	visual.add_child(sensor)


func _build_strike_wings(visual: Node3D) -> void:
	if _shared_strike_wing_mesh == null:
		_shared_strike_wing_mesh = BoxMesh.new()
		_shared_strike_wing_mesh.size = STRIKE_WING_SIZE
		_shared_strike_wing_mesh.resource_local_to_scene = false
	for entry in [
		["PortStrikeWing", -STRIKE_WING_OFFSET.x, -STRIKE_WING_SWEEP_DEGREES],
		["StarboardStrikeWing", STRIKE_WING_OFFSET.x, STRIKE_WING_SWEEP_DEGREES],
	]:
		var wing := MeshInstance3D.new()
		wing.name = entry[0]
		wing.mesh = _shared_strike_wing_mesh
		wing.position = Vector3(float(entry[1]), STRIKE_WING_OFFSET.y, STRIKE_WING_OFFSET.z)
		wing.rotation_degrees.y = float(entry[2])
		wing.material_override = _shared_hull_material
		visual.add_child(wing)


func _build_component_damage_cue(visual: Node3D) -> void:
	_component_damage_cue = Node3D.new()
	_component_damage_cue.name = "StarboardWingDamageCue"
	_component_damage_cue.position = DAMAGE_CUE_POSITION
	_component_damage_cue.rotation_degrees = DAMAGE_CUE_ROTATION_DEGREES
	_component_damage_cue.process_mode = Node.PROCESS_MODE_DISABLED
	_component_damage_cue.set_meta(&"presentation_only", true)
	_component_damage_cue.set_meta(&"component_id", DAMAGE_CUE_COMPONENT_ID)
	_component_damage_cue.set_meta(&"damage_authority", false)
	_component_damage_cue.set_meta(&"repair_authority", false)
	visual.add_child(_component_damage_cue)

	if _shared_damage_scorch_mesh == null:
		_shared_damage_scorch_mesh = BoxMesh.new()
		_shared_damage_scorch_mesh.size = DAMAGE_SCORCH_SIZE
		_shared_damage_scorch_mesh.resource_local_to_scene = false
	if _shared_damage_scorch_material == null:
		_shared_damage_scorch_material = _material(DAMAGE_SCORCH_COLOR, 0.08, 0.92)
		_shared_damage_scorch_material.resource_local_to_scene = false
	var scorch := MeshInstance3D.new()
	scorch.name = "DamageScorch"
	scorch.mesh = _shared_damage_scorch_mesh
	scorch.material_override = _shared_damage_scorch_material
	scorch.position = DAMAGE_SCORCH_POSITION
	_component_damage_cue.add_child(scorch)

	if _shared_damage_vane_mesh == null:
		_shared_damage_vane_mesh = BoxMesh.new()
		_shared_damage_vane_mesh.size = DAMAGE_VANE_SIZE
		_shared_damage_vane_mesh.resource_local_to_scene = false
	if _shared_damage_vane_material == null:
		_shared_damage_vane_material = _material(
			DAMAGE_VANE_COLOR, 0.18, 0.38, DAMAGE_VANE_COLOR, 1.35
		)
		_shared_damage_vane_material.resource_local_to_scene = false
	var vane := MeshInstance3D.new()
	vane.name = "ExposedDamageVane"
	vane.mesh = _shared_damage_vane_mesh
	vane.material_override = _shared_damage_vane_material
	vane.position = DAMAGE_VANE_POSITION
	_component_damage_cue.add_child(vane)
	_component_damage_cue.visible = false


func _on_bomber_component_damage_changed(
		component_id: StringName,
		_state: int,
		_integrity: float
	) -> void:
	if component_id == DAMAGE_CUE_COMPONENT_ID:
		_sync_component_damage_cue()


func _sync_component_damage_cue() -> void:
	if not is_instance_valid(_component_damage_cue):
		return
	var model := get_component_damage()
	_component_damage_cue.visible = model != null \
		and model.is_configured() \
		and model.get_component_state(DAMAGE_CUE_COMPONENT_ID) \
			!= ShipComponentDamageType.ComponentState.NOMINAL


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
