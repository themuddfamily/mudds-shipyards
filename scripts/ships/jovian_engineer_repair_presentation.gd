class_name JovianEngineerRepairPresentation
extends Node3D

## Bounded ship-local work cue for an authority-admitted Jovian repair.
##
## The owning ship supplies an already-resolved repair snapshot and exterior
## component anchor. This component only renders that observation: it owns no
## repair, component, seat, movement, collision, network, or persistence state.

const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_SAFE_SEQUENCE := 9_007_199_254_740_991
const ENGINEER_SEAT_ID: StringName = &"passenger_port_01"
const ARC_SEGMENT_COUNT := 7
const ARC_RADIUS := 0.82
const COMPONENT_CLEARANCE := Vector3(0.0, 0.24, 0.0)
const LOCAL_EFFECT_BOUNDS := AABB(Vector3(-1.2, -0.15, -1.2), Vector3(2.4, 1.1, 2.4))
const WORK_COLOR := Color("70eee7")
const READY_COLOR := Color("e9a844")
const INACTIVE_SLOT_COLOR := Color("163943")
const WORK_EMISSION_ENERGY := 2.0
const READY_EMISSION_ENERGY := 2.5
const WORK_LIGHT_ENERGY := 0.72
const READY_LIGHT_ENERGY := 1.15

var _arc_segments: Array[MeshInstance3D] = []
var _work_lamp: MeshInstance3D
var _work_light: OmniLight3D
var _work_material: StandardMaterial3D
var _ready_material: StandardMaterial3D
var _inactive_slot_material: StandardMaterial3D
var _work_lamp_material: StandardMaterial3D
var _ready_lamp_material: StandardMaterial3D
var _generation := 0
var _last_sequence := -1
var _attached := false
var _component_id: StringName = &""
var _component_generation := 0
var _target_local_position := Vector3.ZERO
var _visible_segment_count := 0
var _last_clear_reason: StringName = &"ready"
var _visual_phase: StringName = &"cleared"


func _ready() -> void:
	_build_visuals()
	_clear_visuals(&"ready")
	process_mode = Node.PROCESS_MODE_DISABLED
	set_meta(&"presentation_only", true)
	set_meta(&"repair_authority", false)
	set_meta(&"admission_authority", false)
	set_meta(&"movement_authority", false)
	set_meta(&"collision_authority", false)
	set_meta(&"network_authority", false)
	set_meta(&"persistence_authority", false)


func attach(expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _attached:
		return _result(false, &"already_attached")
	_attached = true
	_last_sequence = -1
	_clear_visuals(&"attached")
	return _result(true, &"attached")


func present_snapshot(envelope: Dictionary, component_local_position: Vector3) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	var decoded := _decode(envelope, component_local_position)
	if not bool(decoded.get("accepted", false)):
		return decoded
	var sequence := int(decoded.get("sequence", -1))
	if sequence <= _last_sequence:
		return _result(
			false,
			&"duplicate_sequence" if sequence == _last_sequence else &"stale_sequence"
		)
	_last_sequence = sequence
	if not bool(decoded.get("active", false)):
		_clear_visuals(StringName(decoded.get("clear_reason", &"inactive")))
		return _result(true, &"repair_presentation_cleared")

	_component_id = StringName(decoded.get("component_id", &""))
	_component_generation = int(decoded.get("component_generation", 0))
	_target_local_position = component_local_position
	position = component_local_position + COMPONENT_CLEARANCE
	_visible_segment_count = clampi(
		ceili(float(decoded.get("progress", 0.0)) * float(ARC_SEGMENT_COUNT)),
		1,
		ARC_SEGMENT_COUNT
	)
	_apply_progress_hierarchy(float(decoded.get("progress", 0.0)))
	visible = true
	_last_clear_reason = &""
	return _result(true, &"repair_presentation_presented")


func begin_generation(generation: int) -> Dictionary:
	if generation <= _generation or generation > MAX_SAFE_GENERATION:
		return _result(false, &"stale_generation")
	_generation = generation
	_last_sequence = -1
	_clear_visuals(&"generation_started")
	return _result(true, &"generation_started")


func detach(expected_generation: int) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_attached = false
	_generation += 1
	_last_sequence = -1
	_clear_visuals(&"detached")
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_sequence": _last_sequence,
		"visible": visible,
		"component_id": _component_id,
		"component_generation": _component_generation,
		"target_local_position": _target_local_position,
		"effect_local_position": position,
		"effect_world_position": global_position if is_inside_tree() else Vector3.INF,
		"visible_segment_count": _visible_segment_count,
		"inactive_slot_count": ARC_SEGMENT_COUNT - _visible_segment_count,
		"arc_segment_count": ARC_SEGMENT_COUNT,
		"visual_phase": _visual_phase,
		"shape_hierarchy": &"segmented_work_arc_to_full_ready_crown",
		"local_effect_bounds": LOCAL_EFFECT_BOUNDS,
		"last_clear_reason": _last_clear_reason,
		"steady": true,
		"processes": false,
		"collision_nodes": find_children("*", "CollisionObject3D", true, false).size(),
		"authority": {
			"repair": false,
			"admission": false,
			"movement": false,
			"collision": false,
			"network": false,
			"persistence": false,
			"presentation": true,
		},
	}.duplicate(true)


## Projects a read-only component point to the top exterior plane of the final
## collision envelope. X/Z continue to identify the selected authoritative
## component while the complete bounded effect remains outside the hull.
static func resolve_exterior_anchor(
		component_local_position: Vector3,
		component_local_bounds: AABB
	) -> Vector3:
	var bounds_position := component_local_bounds.position
	var bounds_size := component_local_bounds.size
	if not component_local_position.is_finite() \
			or not bounds_position.is_finite() \
			or not bounds_size.is_finite() \
			or bounds_size.x <= 0.0 \
			or bounds_size.y <= 0.0 \
			or bounds_size.z <= 0.0:
		return Vector3.INF
	return Vector3(
		component_local_position.x,
		component_local_bounds.end.y,
		component_local_position.z
	)


func _decode(envelope: Dictionary, component_local_position: Vector3) -> Dictionary:
	var raw_generation: Variant = envelope.get("generation", -1)
	var raw_sequence: Variant = envelope.get("sequence", -1)
	var raw_snapshot: Variant = envelope.get("repair_snapshot", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return _result(false, &"stale_generation")
	if not raw_sequence is int or int(raw_sequence) < 0 \
			or int(raw_sequence) > MAX_SAFE_SEQUENCE:
		return _result(false, &"invalid_sequence")
	if not raw_snapshot is Dictionary:
		return _result(false, &"invalid_repair_snapshot")
	var network_snapshot := raw_snapshot as Dictionary
	if not bool(network_snapshot.get("presentation_only", false)):
		return _result(false, &"authority_snapshot_rejected")
	var repair_variant: Variant = network_snapshot.get("repair", null)
	var owner_variant: Variant = network_snapshot.get("owner", null)
	if not repair_variant is Dictionary or not owner_variant is Dictionary:
		return _result(false, &"invalid_repair_snapshot")
	var repair := repair_variant as Dictionary
	var owner := owner_variant as Dictionary
	var status := StringName(repair.get("status", &""))
	if status not in [&"idle", &"repairing", &"completed", &"interrupted"]:
		return _result(false, &"invalid_repair_state")
	if status != &"repairing":
		return {
			"accepted": true,
			"sequence": int(raw_sequence),
			"active": false,
			"clear_reason": StringName(repair.get("reason", status)),
		}
	if not bool(repair.get("active", false)):
		return _result(false, &"inactive_repair_claim")
	if StringName(owner.get("seat_id", &"")) != ENGINEER_SEAT_ID \
			or int(owner.get("occupant_peer_id", 0)) <= 0 \
			or StringName(owner.get("avatar_id", &"")) == &"":
		return _result(false, &"engineer_owner_missing")
	var component_id := StringName(repair.get("component_id", &""))
	var component_generation := int(repair.get("component_generation", 0))
	var progress := float(repair.get("progress", -1.0))
	if component_id == &"" or component_generation <= 0:
		return _result(false, &"component_identity_missing")
	if not component_local_position.is_finite():
		return _result(false, &"component_position_invalid")
	if not is_finite(progress) or progress < 0.0 or progress > 1.0:
		return _result(false, &"repair_progress_invalid")
	return {
		"accepted": true,
		"sequence": int(raw_sequence),
		"active": true,
		"component_id": component_id,
		"component_generation": component_generation,
		"progress": progress,
	}


func _build_visuals() -> void:
	if not _arc_segments.is_empty():
		return
	_work_material = _emissive_material(WORK_COLOR, WORK_EMISSION_ENERGY, 0.28)
	_ready_material = _emissive_material(READY_COLOR, WORK_EMISSION_ENERGY, 0.28)
	_inactive_slot_material = StandardMaterial3D.new()
	_inactive_slot_material.albedo_color = INACTIVE_SLOT_COLOR
	_inactive_slot_material.metallic = 0.48
	_inactive_slot_material.roughness = 0.54
	var segment_mesh := BoxMesh.new()
	segment_mesh.size = Vector3(0.42, 0.09, 0.14)
	for index in ARC_SEGMENT_COUNT:
		var angle := deg_to_rad(-120.0 + float(index) * 40.0)
		var segment := MeshInstance3D.new()
		segment.name = "RepairArcSegment%02d" % index
		segment.mesh = segment_mesh
		segment.material_override = _inactive_slot_material
		segment.position = Vector3(cos(angle) * ARC_RADIUS, 0.0, sin(angle) * ARC_RADIUS)
		segment.rotation.y = -angle
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(segment)
		_arc_segments.append(segment)

	_work_lamp_material = _emissive_material(WORK_COLOR, 1.55, 0.25)
	_ready_lamp_material = _emissive_material(
		READY_COLOR, READY_EMISSION_ENERGY, 0.2
	)
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.18
	lamp_mesh.height = 0.36
	lamp_mesh.radial_segments = 16
	lamp_mesh.rings = 8
	_work_lamp = MeshInstance3D.new()
	_work_lamp.name = "RepairWorkLamp"
	_work_lamp.mesh = lamp_mesh
	_work_lamp.material_override = _work_lamp_material
	_work_lamp.position = Vector3(0.0, 0.22, 0.0)
	_work_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_work_lamp)

	_work_light = OmniLight3D.new()
	_work_light.name = "RepairWorkLight"
	_work_light.position = Vector3(0.0, 0.28, 0.0)
	_work_light.light_color = WORK_COLOR
	_work_light.light_energy = WORK_LIGHT_ENERGY
	_work_light.omni_range = 2.4
	_work_light.shadow_enabled = false
	_work_light.set_meta(&"reduced_flash_safe", true)
	add_child(_work_light)


func _apply_progress_hierarchy(progress: float) -> void:
	var ready_to_commit := progress >= 1.0
	_visual_phase = &"ready_to_commit" if ready_to_commit else &"work_in_progress"
	for index in _arc_segments.size():
		var segment := _arc_segments[index]
		segment.visible = true
		if ready_to_commit:
			segment.material_override = _ready_material
		else:
			segment.material_override = (
				_work_material if index < _visible_segment_count else _inactive_slot_material
			)
	_work_lamp.visible = true
	_work_lamp.material_override = (
		_ready_lamp_material if ready_to_commit else _work_lamp_material
	)
	_work_light.visible = true
	_work_light.light_color = READY_COLOR if ready_to_commit else WORK_COLOR
	_work_light.light_energy = (
		READY_LIGHT_ENERGY if ready_to_commit else WORK_LIGHT_ENERGY
	)


func _emissive_material(
		color: Color, emission_energy: float, material_roughness: float
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	material.roughness = material_roughness
	return material


func _clear_visuals(reason: StringName) -> void:
	visible = false
	for segment in _arc_segments:
		segment.visible = false
	if _work_lamp != null:
		_work_lamp.visible = false
	if _work_light != null:
		_work_light.visible = false
	_component_id = &""
	_component_generation = 0
	_target_local_position = Vector3.ZERO
	_visible_segment_count = 0
	_last_clear_reason = reason
	_visual_phase = &"cleared"


static func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
