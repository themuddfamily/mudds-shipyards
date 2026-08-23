class_name BomberPayloadPresentation
extends Node3D

## Fixed-budget, presentation-only visuals for caller-resolved bomber payloads.
##
## Release and terminal records are copied from BomberPayloadAuthority and
## BomberPayloadProjectile. The component performs no collision query, damage,
## scoring, audio, or authoritative projectile motion. Between exact caller
## poses it only extrapolates the visible model; a terminal record always snaps
## the slot back to its exact supplied world pose.

signal payload_presented(record_id: StringName)
signal payload_terminal_presented(record_id: StringName, kind: StringName)
signal payload_visual_finished(record_id: StringName)
signal payload_visual_recycled(retired_record_id: StringName, replacement_record_id: StringName)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"bomber-payload-presentation"
const POOL_CAPACITY := 4
const MESHES_PER_SLOT := 7
const GENERATED_NODES_PER_SLOT := 8
const GENERATED_NODE_COUNT := POOL_CAPACITY * GENERATED_NODES_PER_SLOT
const GENERATED_MESH_INSTANCE_COUNT := POOL_CAPACITY * MESHES_PER_SLOT
const GENERATED_LIGHT_COUNT := 0
const SHARED_MESH_RESOURCE_COUNT := 5
const SHARED_MATERIAL_RESOURCE_COUNT := 4
const TERMINAL_VISUAL_LIFETIME := 0.32
const MAX_FLIGHT_VISUAL_LIFETIME := 8.0
const MAX_WORLD_POSITION := 2_000_000.0
const MAX_RELEASE_SPEED := 10_000.0

const RELEASE_REQUIRED_KEYS := [
	"schema_version", "record_id", "release_sequence", "generation",
	"request_sequence", "release_position", "release_velocity",
]
const TERMINAL_REQUIRED_KEYS := [
	"schema_version", "terminal_sequence", "generation", "release_sequence",
	"request_sequence", "record_id", "kind", "position", "velocity", "normal",
	"resolver_ready",
]

static var _shared_catalog: Dictionary = {}
static var _shared_catalog_build_count := 0

var _pool_root: Node3D
var _slots: Array[Dictionary] = []
var _built := false
var _explicitly_detached := false
var _activation_serial := 0
var _presented_count := 0
var _terminal_count := 0
var _finished_count := 0
var _recycled_count := 0
var _rejected_count := 0


func _ready() -> void:
	if not _built:
		_build()
	set_process(false)


func _exit_tree() -> void:
	_clear_slots(false)
	set_process(false)


func get_component_id() -> StringName:
	return COMPONENT_ID


## Consumes one already-accepted authority record. The exact world pose is
## copied before any pool mutation and is never derived from the owner transform.
func consume_release_record(record: Dictionary) -> Dictionary:
	if not _can_present() or not _valid_release_record(record):
		_rejected_count += 1
		return _result(false, &"invalid_release_record")
	var record_id := StringName(record.get("record_id", &""))
	if _find_record_slot(record_id) >= 0:
		_rejected_count += 1
		return _result(false, &"duplicate_release_record")

	var slot_index := _find_free_slot()
	var retired_id: StringName = &""
	if slot_index < 0:
		slot_index = _find_oldest_slot()
		retired_id = StringName(_slots[slot_index].get("record_id", &""))
		_deactivate_slot(slot_index, false)
		_recycled_count += 1

	_activation_serial += 1
	var slot := _slots[slot_index]
	var release_position := record.get("release_position") as Vector3
	var release_velocity := record.get("release_velocity") as Vector3
	slot["active"] = true
	slot["phase"] = &"flight"
	slot["activation_serial"] = _activation_serial
	slot["record_id"] = record_id
	slot["generation"] = int(record.get("generation", 0))
	slot["release_sequence"] = int(record.get("release_sequence", 0))
	slot["request_sequence"] = int(record.get("request_sequence", 0))
	slot["release_position"] = release_position
	slot["release_velocity"] = release_velocity
	slot["terminal_position"] = Vector3.ZERO
	slot["terminal_velocity"] = Vector3.ZERO
	slot["terminal_normal"] = Vector3.ZERO
	slot["terminal_kind"] = &""
	slot["age"] = 0.0
	_slots[slot_index] = slot
	_apply_flight_pose(slot_index, release_position, release_velocity)
	_presented_count += 1
	payload_presented.emit(record_id)
	if not retired_id.is_empty():
		payload_visual_recycled.emit(retired_id, record_id)
		payload_visual_finished.emit(retired_id)
	return _result(true, &"release_presented", {"slot_index": slot_index, "record_id": record_id})


## Consumes the projectile's already-resolved impact/expiry record. The supplied
## position, velocity and normal remain exact; no target or resolver field is
## interpreted beyond validation.
func consume_terminal_record(record: Dictionary) -> Dictionary:
	if not _can_present() or not _valid_terminal_record(record):
		_rejected_count += 1
		return _result(false, &"invalid_terminal_record")
	var record_id := StringName(record.get("record_id", &""))
	var slot_index := _find_record_slot(record_id)
	if slot_index < 0:
		_rejected_count += 1
		return _result(false, &"release_visual_unavailable")
	var slot := _slots[slot_index]
	if StringName(slot.get("phase", &"")) != &"flight":
		_rejected_count += 1
		return _result(false, &"terminal_already_presented")
	if (
		int(record.get("generation", 0)) != int(slot.get("generation", 0))
		or int(record.get("release_sequence", 0)) != int(slot.get("release_sequence", 0))
		or int(record.get("request_sequence", 0)) != int(slot.get("request_sequence", 0))
	):
		_rejected_count += 1
		return _result(false, &"terminal_release_mismatch")

	var terminal_position := record.get("position") as Vector3
	var terminal_velocity := record.get("velocity") as Vector3
	var terminal_normal := record.get("normal") as Vector3
	var kind := StringName(record.get("kind", &""))
	slot["phase"] = &"terminal"
	slot["age"] = 0.0
	slot["terminal_position"] = terminal_position
	slot["terminal_velocity"] = terminal_velocity
	slot["terminal_normal"] = terminal_normal
	slot["terminal_kind"] = kind
	_slots[slot_index] = slot
	_apply_terminal_pose(slot_index, terminal_position, terminal_velocity, terminal_normal, kind)
	_terminal_count += 1
	payload_terminal_presented.emit(record_id, kind)
	return _result(true, &"terminal_presented", {"slot_index": slot_index, "record_id": record_id})


## Deterministic visual clock. A hitch retires a completed terminal visual in
## one call, and a missing caller terminal cannot retain a visual indefinitely.
func advance_simulation(delta: float) -> bool:
	if not _can_present() or not is_finite(delta) or delta <= 0.0:
		return false
	var cutoff := _activation_serial
	var advanced := false
	for slot_index in _slots.size():
		var slot := _slots[slot_index]
		if not bool(slot.get("active", false)) \
				or int(slot.get("activation_serial", 0)) > cutoff:
			continue
		var age := float(slot.get("age", 0.0)) + delta
		slot["age"] = age
		_slots[slot_index] = slot
		if StringName(slot.get("phase", &"")) == &"flight":
			if age >= MAX_FLIGHT_VISUAL_LIFETIME:
				_deactivate_slot(slot_index, true)
			else:
				var release_position := slot.get("release_position") as Vector3
				var release_velocity := slot.get("release_velocity") as Vector3
				_apply_flight_pose(slot_index, release_position + release_velocity * age, release_velocity)
		else:
			if age >= TERMINAL_VISUAL_LIFETIME:
				_deactivate_slot(slot_index, true)
			else:
				_update_terminal_scale(slot_index, age / TERMINAL_VISUAL_LIFETIME)
		advanced = true
	return advanced


## Explicit detach is a presentation lifecycle operation only. It clears every
## slot synchronously and requires reset_for_reuse before accepting new records.
func detach() -> void:
	_clear_slots(true)
	_explicitly_detached = true


func reset_for_reuse() -> void:
	_clear_slots(false)
	_explicitly_detached = false
	_presented_count = 0
	_terminal_count = 0
	_finished_count = 0
	_recycled_count = 0
	_rejected_count = 0


func get_active_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		if not bool(slot.get("active", false)):
			continue
		var root := slot.get("root") as Node3D
		snapshots.append({
			"record_id": StringName(slot.get("record_id", &"")),
			"phase": StringName(slot.get("phase", &"")),
			"generation": int(slot.get("generation", 0)),
			"release_sequence": int(slot.get("release_sequence", 0)),
			"request_sequence": int(slot.get("request_sequence", 0)),
			"release_position": slot.get("release_position", Vector3.ZERO),
			"release_velocity": slot.get("release_velocity", Vector3.ZERO),
			"terminal_position": slot.get("terminal_position", Vector3.ZERO),
			"terminal_velocity": slot.get("terminal_velocity", Vector3.ZERO),
			"terminal_normal": slot.get("terminal_normal", Vector3.ZERO),
			"terminal_kind": StringName(slot.get("terminal_kind", &"")),
			"visual_position": root.global_position if is_instance_valid(root) else Vector3.ZERO,
			"age": float(slot.get("age", 0.0)),
			"silhouette_visible": _slot_flight_visible(slot),
			"trail_visible": (slot.get("trail") as MeshInstance3D).visible,
			"terminal_visible": (slot.get("terminal_flare") as MeshInstance3D).visible,
		})
	return snapshots.duplicate(true)


func get_statistics() -> Dictionary:
	return {
		"active": get_active_snapshots().size(),
		"presented": _presented_count,
		"terminal": _terminal_count,
		"finished": _finished_count,
		"recycled": _recycled_count,
		"rejected": _rejected_count,
	}.duplicate(true)


func get_integration_contract() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"coordinate_space": &"world_space_records",
		"authority_policy": &"accepted_release_and_terminal_records_presentation_only",
		"caller_owns": PackedStringArray([
			"release admission and cadence", "projectile motion and collision queries",
			"terminal resolution, damage, health, score, and audio",
		]),
		"visual_motion_policy": &"non_authoritative_velocity_extrapolation_terminal_pose_snaps_exact",
		"pool_policy": &"fixed_preallocated_oldest_visual_recycled",
		"pool_capacity": POOL_CAPACITY,
		"voice_policy": &"voice_free_no_audio_nodes",
		"light_budget": GENERATED_LIGHT_COUNT,
		"tree_exit_policy": &"synchronous_clear_reentry_safe",
	}.duplicate(true)


func get_performance_audit() -> Dictionary:
	return {
		"within_budget": (
			_built
			and _slots.size() == POOL_CAPACITY
			and _count_descendants(self) == GENERATED_NODE_COUNT + 1
			and find_children("*", "MeshInstance3D", true, false).size() == GENERATED_MESH_INSTANCE_COUNT
			and find_children("*", "Light3D", true, false).is_empty()
			and find_children("*", "AudioStreamPlayer3D", true, false).is_empty()
		),
		"pool_capacity": POOL_CAPACITY,
		"generated_nodes": GENERATED_NODE_COUNT,
		"mesh_instances": GENERATED_MESH_INSTANCE_COUNT,
		"lights": GENERATED_LIGHT_COUNT,
		"audio_nodes": 0,
		"particle_emitters": 0,
		"shared_mesh_resources": SHARED_MESH_RESOURCE_COUNT,
		"shared_material_resources": SHARED_MATERIAL_RESOURCE_COUNT,
		"catalog_build_count": _shared_catalog_build_count,
		"runtime_node_allocation": false,
		"runtime_resource_allocation": false,
	}.duplicate(true)


func get_resource_identity_audit() -> Dictionary:
	var identities := {}
	for key: StringName in _shared_catalog:
		identities[key] = (_shared_catalog[key] as Resource).get_instance_id()
	return identities.duplicate(true)


func get_audit_report() -> Dictionary:
	var performance := get_performance_audit()
	return {
		"valid": bool(performance.get("within_budget", false)),
		"component_id": COMPONENT_ID,
		"performance": performance,
		"integration": get_integration_contract(),
		"presentation_only": true,
		"collision_nodes": find_children("*", "CollisionObject3D", true, false).size(),
	}.duplicate(true)


func _build() -> void:
	_built = true
	set_meta(&"presentation_only", true)
	set_meta(&"gameplay_authority", false)
	add_to_group(&"bomber_payload_presentation")
	_build_shared_catalog()
	_pool_root = Node3D.new()
	_pool_root.name = "PoolRoot"
	_pool_root.set_meta(&"presentation_only", true)
	add_child(_pool_root)
	for index in POOL_CAPACITY:
		_build_slot(index)


func _build_shared_catalog() -> void:
	if not _shared_catalog.is_empty():
		return
	var body := CylinderMesh.new()
	body.top_radius = 0.16
	body.bottom_radius = 0.19
	body.height = 0.82
	body.radial_segments = 10
	body.rings = 1
	var orb := SphereMesh.new()
	orb.radius = 0.19
	orb.height = 0.38
	orb.radial_segments = 10
	orb.rings = 5
	var fin := BoxMesh.new()
	fin.size = Vector3(0.62, 0.24, 0.045)
	var trail := CylinderMesh.new()
	trail.top_radius = 0.025
	trail.bottom_radius = 0.075
	trail.height = 3.2
	trail.radial_segments = 8
	trail.rings = 1
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.38
	ring.rings = 12
	ring.ring_segments = 6
	_shared_catalog[&"mesh_body"] = body
	_shared_catalog[&"mesh_orb"] = orb
	_shared_catalog[&"mesh_fin"] = fin
	_shared_catalog[&"mesh_trail"] = trail
	_shared_catalog[&"mesh_ring"] = ring
	_shared_catalog[&"material_hull"] = _material(Color(0.075, 0.09, 0.12), Color(0.08, 0.13, 0.18), 0.35)
	_shared_catalog[&"material_trail"] = _material(Color(0.05, 0.32, 0.42, 0.46), Color(0.1, 1.35, 1.75), 0.12, true)
	_shared_catalog[&"material_impact"] = _material(Color(0.9, 0.25, 0.04, 0.72), Color(4.6, 0.8, 0.08), 0.08, true)
	_shared_catalog[&"material_expiry"] = _material(Color(0.18, 0.38, 0.42, 0.48), Color(0.25, 0.8, 0.9), 0.2, true)
	_shared_catalog_build_count += 1


func _material(color: Color, emission: Color, roughness: float, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.55 if not transparent else 0.0
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 1.0
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = false
	return material


func _build_slot(index: int) -> void:
	var slot_root := Node3D.new()
	slot_root.name = "PayloadSlot%02d" % (index + 1)
	slot_root.top_level = true
	slot_root.visible = false
	slot_root.set_meta(&"presentation_only", true)
	_pool_root.add_child(slot_root)
	var body := _mesh_node("Body", &"mesh_body", &"material_hull", slot_root)
	var nose := _mesh_node("Nose", &"mesh_orb", &"material_hull", slot_root)
	nose.position.y = 0.52
	nose.scale = Vector3(0.82, 0.72, 0.82)
	var fin_port := _mesh_node("FinPort", &"mesh_fin", &"material_hull", slot_root)
	fin_port.position = Vector3.ZERO + Vector3.DOWN * 0.27
	var fin_starboard := _mesh_node("FinStarboard", &"mesh_fin", &"material_hull", slot_root)
	fin_starboard.position = Vector3.DOWN * 0.27
	fin_starboard.rotation.y = PI * 0.5
	var trail := _mesh_node("Trail", &"mesh_trail", &"material_trail", slot_root)
	trail.position.y = -2.0
	var terminal_flare := _mesh_node("TerminalFlare", &"mesh_orb", &"material_impact", slot_root)
	var terminal_ring := _mesh_node("TerminalRing", &"mesh_ring", &"material_impact", slot_root)
	_slots.append({
		"active": false, "phase": &"", "activation_serial": 0, "record_id": &"",
		"generation": 0, "release_sequence": 0, "request_sequence": 0, "age": 0.0,
		"release_position": Vector3.ZERO, "release_velocity": Vector3.ZERO,
		"terminal_position": Vector3.ZERO, "terminal_velocity": Vector3.ZERO,
		"terminal_normal": Vector3.ZERO, "terminal_kind": &"", "root": slot_root,
		"body": body, "nose": nose, "fin_port": fin_port, "fin_starboard": fin_starboard,
		"trail": trail, "terminal_flare": terminal_flare, "terminal_ring": terminal_ring,
	})
	_hide_slot_visuals(_slots.size() - 1)


func _mesh_node(name_value: String, mesh_key: StringName, material_key: StringName, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = _shared_catalog[mesh_key] as Mesh
	node.material_override = _shared_catalog[material_key] as Material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta(&"presentation_only", true)
	parent.add_child(node)
	return node


func _apply_flight_pose(slot_index: int, position: Vector3, velocity: Vector3) -> void:
	var slot := _slots[slot_index]
	var root := slot.get("root") as Node3D
	root.global_transform = Transform3D(_basis_y_along(velocity), position)
	root.visible = true
	for key: StringName in [&"body", &"nose", &"fin_port", &"fin_starboard", &"trail"]:
		(slot.get(key) as MeshInstance3D).visible = true
	(slot.get("terminal_flare") as MeshInstance3D).visible = false
	(slot.get("terminal_ring") as MeshInstance3D).visible = false


func _apply_terminal_pose(slot_index: int, position: Vector3, velocity: Vector3, normal: Vector3, kind: StringName) -> void:
	var slot := _slots[slot_index]
	var root := slot.get("root") as Node3D
	var axis := normal if normal.length_squared() > 0.000001 else velocity
	root.global_transform = Transform3D(_basis_y_along(axis), position)
	root.visible = true
	for key: StringName in [&"body", &"nose", &"fin_port", &"fin_starboard", &"trail"]:
		(slot.get(key) as MeshInstance3D).visible = false
	var material_key: StringName = &"material_impact" if kind == &"impact" else &"material_expiry"
	var flare := slot.get("terminal_flare") as MeshInstance3D
	var ring := slot.get("terminal_ring") as MeshInstance3D
	flare.material_override = _shared_catalog[material_key] as Material
	ring.material_override = _shared_catalog[material_key] as Material
	flare.scale = Vector3.ONE
	ring.scale = Vector3.ONE
	flare.visible = true
	ring.visible = true


func _update_terminal_scale(slot_index: int, progress: float) -> void:
	var slot := _slots[slot_index]
	var eased := sin(clampf(progress, 0.0, 1.0) * PI)
	(slot.get("terminal_flare") as MeshInstance3D).scale = Vector3.ONE * (0.65 + eased * 1.55)
	(slot.get("terminal_ring") as MeshInstance3D).scale = Vector3.ONE * (1.0 + progress * 3.0)


func _deactivate_slot(slot_index: int, emit_finished: bool) -> void:
	var slot := _slots[slot_index]
	if not bool(slot.get("active", false)):
		return
	var record_id := StringName(slot.get("record_id", &""))
	_hide_slot_visuals(slot_index)
	slot["active"] = false
	slot["phase"] = &""
	slot["record_id"] = &""
	slot["age"] = 0.0
	_slots[slot_index] = slot
	_finished_count += 1
	if emit_finished:
		payload_visual_finished.emit(record_id)


func _clear_slots(emit_finished: bool) -> void:
	for index in _slots.size():
		_deactivate_slot(index, emit_finished)


func _hide_slot_visuals(slot_index: int) -> void:
	var root := _slots[slot_index].get("root") as Node3D
	root.visible = false
	for child in root.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visible = false


func _slot_flight_visible(slot: Dictionary) -> bool:
	return (
		(slot.get("body") as MeshInstance3D).visible
		and (slot.get("nose") as MeshInstance3D).visible
		and (slot.get("fin_port") as MeshInstance3D).visible
		and (slot.get("fin_starboard") as MeshInstance3D).visible
	)


func _find_record_slot(record_id: StringName) -> int:
	for index in _slots.size():
		if bool(_slots[index].get("active", false)) \
				and StringName(_slots[index].get("record_id", &"")) == record_id:
			return index
	return -1


func _find_free_slot() -> int:
	for index in _slots.size():
		if not bool(_slots[index].get("active", false)):
			return index
	return -1


func _find_oldest_slot() -> int:
	var oldest_index := 0
	var oldest_serial := 9_223_372_036_854_775_807
	for index in _slots.size():
		var serial := int(_slots[index].get("activation_serial", 0))
		if serial < oldest_serial:
			oldest_serial = serial
			oldest_index = index
	return oldest_index


func _can_present() -> bool:
	return _built and is_inside_tree() and not is_queued_for_deletion() and not _explicitly_detached


func _valid_release_record(record: Dictionary) -> bool:
	if not _has_keys(record, RELEASE_REQUIRED_KEYS) or int(record.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	return (
		_valid_id(record.get("record_id", &""))
		and int(record.get("release_sequence", 0)) > 0
		and int(record.get("generation", 0)) > 0
		and int(record.get("request_sequence", 0)) > 0
		and _valid_vector(record.get("release_position"), MAX_WORLD_POSITION)
		and _valid_vector(record.get("release_velocity"), MAX_RELEASE_SPEED)
	)


func _valid_terminal_record(record: Dictionary) -> bool:
	if not _has_keys(record, TERMINAL_REQUIRED_KEYS) or int(record.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	var kind := StringName(record.get("kind", &""))
	var normal: Variant = record.get("normal")
	return (
		_valid_id(record.get("record_id", &""))
		and int(record.get("terminal_sequence", 0)) > 0
		and int(record.get("generation", 0)) > 0
		and int(record.get("release_sequence", 0)) > 0
		and int(record.get("request_sequence", 0)) > 0
		and kind in [&"impact", &"expiry"]
		and bool(record.get("resolver_ready", false))
		and _valid_vector(record.get("position"), MAX_WORLD_POSITION)
		and _valid_vector(record.get("velocity"), MAX_RELEASE_SPEED)
		and normal is Vector3 and (normal as Vector3).is_finite()
		and (kind == &"expiry" or (normal as Vector3).length_squared() > 0.000001)
	)


func _has_keys(record: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not record.has(key):
			return false
	return true


func _valid_id(value: Variant) -> bool:
	return (value is String or value is StringName) and not String(value).is_empty() and String(value).length() <= 64


func _valid_vector(value: Variant, maximum_length: float) -> bool:
	return value is Vector3 and (value as Vector3).is_finite() and (value as Vector3).length() <= maximum_length


func _basis_y_along(vector: Vector3) -> Basis:
	var y_axis := vector.normalized() if vector.length_squared() > 0.000001 else Vector3.DOWN
	var helper := Vector3.RIGHT if absf(y_axis.dot(Vector3.UP)) > 0.94 else Vector3.UP
	var x_axis := helper.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _count_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1 + _count_descendants(child)
	return count


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	result.merge(extra, true)
	return result.duplicate(true)
