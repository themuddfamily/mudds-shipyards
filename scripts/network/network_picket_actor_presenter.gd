extends Node3D

## One bounded visual copy, driven only by accepted host movement snapshots.
## The retained solo picket stays hidden and frozen; this copy has no scripts,
## collision, timers, lights, audio, weapon or damage authority.
const MODE: StringName = &"picket_actor"
const ACTOR_ID: StringName = &"standoff_picket_actor"
const CUE_COUNT := 9
const POSTURES := [&"dormant", &"closing", &"holding", &"breaking", &"relocating"]
const FIELDS := ["entity_id", "entity_generation", "owner_peer_id", "mode", "actor_epoch",
	"pose_tick", "position", "rotation", "available", "present", "retired", "destroyed",
	"health", "maximum_health", "charge_active", "posture", "cues"]
const MAX_VISUAL_NODES := 256

var _host_record: Dictionary = {}
var _record: Dictionary = {}
var _epoch := 0
var _generation := 0
var _retired := false
var _destroyed := false
var _visual: Node3D
var _cues: Array[Node3D] = []
var _materials: Array[Dictionary] = []
var _reduced_flash := false


## Keep the last owned life after its source disappears. A dormant initial
## actor publishes nothing: it must not retire the first real activation.
func build_host_entries(picket: StandoffPicketOpponent, epoch: int, tick: int, station_origin: Vector3) -> Array:
	var available := is_instance_valid(picket) and picket.is_inside_tree() and not picket.is_queued_for_deletion()
	var state: Dictionary = picket.get_network_actor_presentation_snapshot() if available else {}
	var generation := int(state.get("activation_generation", 0))
	if generation <= 0 and _host_record.is_empty():
		return []
	if generation < int(_host_record.get("entity_generation", 0)):
		available = false
		state = {}
		generation = int(_host_record.entity_generation)
	if not available:
		var missing := _host_record.duplicate(true)
		if missing.is_empty():
			return []
		missing.merge({"actor_epoch": epoch, "pose_tick": tick, "available": false,
			"present": false, "retired": true, "charge_active": false, "posture": &"dormant"}, true)
		_host_record = missing
		return [missing.duplicate(true)]
	var health := float(state.health)
	var retired := not bool(state.active)
	var destroyed := health <= 0.0
	if generation == int(_host_record.get("entity_generation", 0)):
		retired = retired or bool(_host_record.get("retired", false))
		destroyed = destroyed or bool(_host_record.get("destroyed", false))
		if destroyed:
			health = 0.0
	_host_record = {"entity_id": ACTOR_ID, "entity_generation": generation,
		"owner_peer_id": 1, "mode": MODE, "actor_epoch": epoch, "pose_tick": tick,
		"position": picket.global_position - station_origin,
		"rotation": picket.global_basis.orthonormalized().get_rotation_quaternion(),
		"available": true, "present": bool(state.active) and not retired and not destroyed,
		"retired": retired, "destroyed": destroyed, "health": health,
		"maximum_health": float(state.maximum_health), "charge_active": bool(state.charge_active),
		"posture": state.posture, "cues": state.cues}
	if retired or destroyed:
		_host_record.charge_active = false
		_host_record.posture = &"dormant"
	return [_host_record.duplicate(true)]


func configure(picket: StandoffPicketOpponent) -> void:
	if is_instance_valid(_visual) or not is_instance_valid(picket):
		return
	var templates := picket.get_network_actor_visual_templates()
	var count := 1
	for template: Node3D in templates:
		if not is_instance_valid(template):
			return
		count += 1 + template.find_children("*", "Node3D", true, false).size()
	if count > MAX_VISUAL_NODES:
		return
	_visual = Node3D.new()
	_visual.name = "RemotePicketVisual"
	_visual.process_mode = Node.PROCESS_MODE_DISABLED
	_visual.visible = false
	add_child(_visual)
	var materials: Dictionary = {}
	var copies: Dictionary = {}
	for template: Node3D in templates:
		_visual.add_child(_clone_visual(template, materials, copies))
	for cue: Node3D in picket.get_network_actor_cue_nodes():
		_cues.append(copies.get(cue.get_instance_id()) as Node3D)
	for material: StandardMaterial3D in materials.values():
		_materials.append({"material": material, "color": material.albedo_color,
			"energy": material.emission_energy_multiplier})
	set_process(false)
	set_physics_process(false)


func consume_movement_section(movement: Array, station_origin: Vector3) -> void:
	for raw: Variant in movement:
		if not raw is Dictionary or (raw as Dictionary).get("mode") != MODE:
			continue
		var entry := raw as Dictionary
		if not _valid_entry(entry):
			continue
		var epoch := int(entry.actor_epoch)
		var generation := int(entry.entity_generation)
		if (_epoch > 0 and epoch != _epoch) or generation < _generation:
			continue
		if generation == _generation and (int(entry.pose_tick) <= int(_record.get("pose_tick", -1)) \
				or (_retired and not bool(entry.retired)) \
				or (_destroyed and not bool(entry.destroyed))):
			continue
		if generation > _generation:
			_retired = false
			_destroyed = false
		_epoch = epoch
		_generation = generation
		_retired = _retired or bool(entry.retired)
		_destroyed = _destroyed or bool(entry.destroyed)
		_record = entry.duplicate(true)
		if is_instance_valid(_visual):
			_visual.global_transform = Transform3D(Basis(entry.rotation as Quaternion),
				(entry.position as Vector3) + station_origin)
			_visual.visible = bool(entry.present)
			for index in _cues.size():
				var cue := _cues[index]
				if is_instance_valid(cue):
					cue.transform = entry.cues[index][0] as Transform3D
					cue.visible = bool(entry.cues[index][1])
			_apply_materials()


func clear_replica() -> void:
	if is_instance_valid(_visual):
		_visual.visible = false
	_record.clear()
	_epoch = 0
	_generation = 0
	_retired = false
	_destroyed = false


func clear() -> void:
	clear_replica()
	_host_record.clear()


func _exit_tree() -> void:
	clear()


func get_visual() -> Node3D:
	return _visual


func get_cue_visual(index: int) -> Node3D:
	return _cues[index] if index >= 0 and index < _cues.size() else null


func get_snapshot() -> Dictionary:
	return {"actor": _record.duplicate(true), "epoch": _epoch, "generation": _generation,
		"reduced_flash": _reduced_flash, "owns_combat_authority": false}


func set_reduced_flash_enabled(enabled: bool) -> void:
	_reduced_flash = enabled
	_apply_materials()


func _apply_materials() -> void:
	var ratio := float(_record.get("health", 1.0)) / maxf(0.001, float(_record.get("maximum_health", 1.0)))
	for row: Dictionary in _materials:
		var material := row.material as StandardMaterial3D
		material.albedo_color = (row.color as Color).lerp(Color("26211f"), (1.0 - ratio) * 0.7)
		material.emission_energy_multiplier = minf(float(row.energy), 1.0) if _reduced_flash else float(row.energy)


func _clone_visual(template: Node3D, materials: Dictionary, copies: Dictionary) -> Node3D:
	var copy := Node3D.new()
	if template is MeshInstance3D:
		copy.free()
		var mesh := MeshInstance3D.new()
		mesh.mesh = (template as MeshInstance3D).mesh
		copy = mesh
	elif template is MultiMeshInstance3D:
		copy.free()
		var batch := MultiMeshInstance3D.new()
		var source := (template as MultiMeshInstance3D).multimesh
		var multi := MultiMesh.new()
		# Resource.duplicate() can assign the buffer before allocating its layout.
		# Configure the complete format before instance_count sizes that buffer.
		multi.transform_format = source.transform_format
		multi.use_colors = source.use_colors
		multi.use_custom_data = source.use_custom_data
		multi.mesh = source.mesh
		multi.instance_count = source.instance_count
		multi.buffer = source.buffer
		multi.visible_instance_count = source.visible_instance_count
		multi.custom_aabb = source.custom_aabb
		multi.physics_interpolation_quality = source.physics_interpolation_quality
		batch.multimesh = multi
		copy = batch
	elif template is Decal:
		copy.free()
		copy = Decal.new()
		for property in ["size", "texture_albedo", "texture_normal", "texture_orm", "texture_emission",
			"cull_mask", "upper_fade", "lower_fade", "normal_fade", "distance_fade_enabled",
			"distance_fade_begin", "distance_fade_length", "albedo_mix", "modulate", "emission_energy"]:
			copy.set(property, template.get(property))
	copy.name = template.name
	copy.transform = template.transform
	copy.visible = template.visible
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	copies[template.get_instance_id()] = copy
	if copy is GeometryInstance3D:
		(copy as GeometryInstance3D).layers = (template as GeometryInstance3D).layers
		(copy as GeometryInstance3D).cast_shadow = (template as GeometryInstance3D).cast_shadow
		var material := (template as GeometryInstance3D).material_override as StandardMaterial3D
		if material != null:
			(copy as GeometryInstance3D).material_override = _copy_material(material, materials)
		elif copy is MeshInstance3D:
			var source := template as MeshInstance3D
			for index in source.mesh.get_surface_count():
				var surface := source.get_surface_override_material(index) as StandardMaterial3D
				if surface == null:
					surface = source.mesh.surface_get_material(index) as StandardMaterial3D
				if surface != null:
					(copy as MeshInstance3D).set_surface_override_material(index, _copy_material(surface, materials))
		elif copy is MultiMeshInstance3D:
			# Preserve every authored surface palette; changing a shared Mesh's
			# materials would otherwise alter the frozen solo hull too.
			var mesh_resource := (template as MultiMeshInstance3D).multimesh.mesh.duplicate() as Mesh
			(copy as MultiMeshInstance3D).multimesh.mesh = mesh_resource
			for index in mesh_resource.get_surface_count():
				var surface := mesh_resource.surface_get_material(index) as StandardMaterial3D
				if surface != null:
					if mesh_resource is PrimitiveMesh:
						(mesh_resource as PrimitiveMesh).material = _copy_material(surface, materials)
					elif mesh_resource is ArrayMesh:
						(mesh_resource as ArrayMesh).surface_set_material(index, _copy_material(surface, materials))
	for child: Node in template.get_children():
		if child is Node3D and not child is CollisionObject3D and not child is CollisionShape3D \
				and not child is Light3D and not child is GPUParticles3D and not child is CPUParticles3D:
			copy.add_child(_clone_visual(child as Node3D, materials, copies))
	return copy


func _copy_material(material: StandardMaterial3D, materials: Dictionary) -> StandardMaterial3D:
	if not materials.has(material.get_instance_id()):
		materials[material.get_instance_id()] = material.duplicate() as StandardMaterial3D
	return materials[material.get_instance_id()] as StandardMaterial3D


func _valid_entry(entry: Dictionary) -> bool:
	if entry.size() != FIELDS.size():
		return false
	for field: String in FIELDS:
		if not entry.has(field):
			return false
	if entry.entity_id != ACTOR_ID or entry.mode != MODE or not entry.owner_peer_id is int or entry.owner_peer_id != 1:
		return false
	for field in ["entity_generation", "actor_epoch", "pose_tick"]:
		if not entry[field] is int or int(entry[field]) < (0 if field == "pose_tick" else 1) \
				or int(entry[field]) > NetworkAuthoritativeSnapshot.MAX_SAFE_INTEGER:
			return false
	for field in ["available", "present", "retired", "destroyed", "charge_active"]:
		if not entry[field] is bool:
			return false
	for field in ["health", "maximum_health"]:
		if not (entry[field] is float or entry[field] is int) or not is_finite(float(entry[field])):
			return false
	if float(entry.maximum_health) <= 0.0 or float(entry.maximum_health) > 1000.0 \
			or float(entry.health) < 0.0 or float(entry.health) > float(entry.maximum_health) \
			or bool(entry.destroyed) != (float(entry.health) <= 0.0) \
			or (bool(entry.present) and (not bool(entry.available) or bool(entry.retired) or bool(entry.destroyed))) \
			or (bool(entry.charge_active) and not bool(entry.present)) or entry.posture not in POSTURES:
		return false
	if not entry.position is Vector3 or not (entry.position as Vector3).is_finite() \
			or not entry.rotation is Quaternion or not (entry.rotation as Quaternion).is_finite() \
			or not is_equal_approx((entry.rotation as Quaternion).length_squared(), 1.0) \
			or not entry.cues is Array or (entry.cues as Array).size() != CUE_COUNT:
		return false
	for raw: Variant in entry.cues:
		if not raw is Array or (raw as Array).size() != 2 or not raw[0] is Transform3D or not raw[1] is bool:
			return false
		var pose := raw[0] as Transform3D
		if not pose.is_finite() or pose.origin.length() > 100.0 \
				or pose.basis.x.length() > 100.0 or pose.basis.y.length() > 100.0 or pose.basis.z.length() > 100.0:
			return false
	return true
