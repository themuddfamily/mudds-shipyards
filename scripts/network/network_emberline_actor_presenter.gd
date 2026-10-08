class_name NetworkEmberlineActorPresenter
extends Node3D

## Two collision-free visual copies of the existing Emberline actors. Committed
## host poses and hull health ride the authenticated movement snapshot; this
## owner never starts an activity, registers a source or touches a Damageable.
signal actor_destroyed(position: Vector3)

const MODE: StringName = &"emberline_actor"
const TENDER_ID: StringName = &"emberline_supply_tender"
const RAIDER_ID: StringName = &"emberline_raider"
const IDS := [TENDER_ID, RAIDER_ID]

var _visuals: Dictionary = {}
var _materials: Dictionary = {}
var _records: Dictionary = {}
var _retired: Dictionary = {}
var _destroyed: Dictionary = {}
var _epoch := 0
var _generation := 0
var _reduced_flash := false
var _destruction_cues := 0


static func build_host_entries(
	host: CinderConvoyEscortHost, threat: CinderConvoyThreat,
	epoch: int, generation: int, tick: int, station_origin: Vector3
) -> Array:
	var host_state := host.get_snapshot() if is_instance_valid(host) and host.is_inside_tree() else {}
	var threat_state := threat.get_snapshot() if is_instance_valid(threat) and threat.is_inside_tree() else {}
	var tender := host.get_entity_presentation_root() if not host_state.is_empty() else null
	var raider := threat.get_attacker() if not threat_state.is_empty() else null
	var active := bool(threat_state.get("active", false)) \
		and int(threat_state.get("generation", 0)) == generation \
		and int((host_state.get("activity", {}) as Dictionary).get("generation", 0)) == generation \
		and StringName((host_state.get("activity", {}) as Dictionary).get("state_id", &"")) == &"active"
	var retired := host_state.is_empty() or threat_state.is_empty() \
		or not is_instance_valid(tender) or not tender.is_inside_tree() \
		or (int(threat_state.get("generation", 0)) == generation and not active)
	var entries: Array = []
	var current_threat := int(threat_state.get("generation", 0)) == generation
	for index in 2:
		var node := tender if index == 0 else raider
		var maximum := float(threat_state.get("tender_maximum_health", 75.0)) if index == 0 else 35.0
		var health := float(threat_state.get("tender_health", maximum)) if index == 0 \
			else float(threat_state.get("attacker_health", maximum))
		# A reset has no new damage outcome until its threat opens. Never
		# assign the prior generation's destroyed hull to the pending retry.
		health = clampf(health, 0.0, maximum)
		if not current_threat:
			health = maximum
		var available := is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
		entries.append({
			"entity_id": IDS[index], "entity_generation": generation,
			"owner_peer_id": 1, "mode": MODE, "convoy_epoch": epoch, "pose_tick": tick,
			"position": node.global_position - station_origin if available else Vector3.ZERO,
			"rotation": node.global_basis.orthonormalized().get_rotation_quaternion() if available else Quaternion.IDENTITY,
			"health": health, "maximum_health": maximum, "available": available, "destroyed": current_threat and available and health <= 0.0,
			"present": active and not retired and available and health > 0.0,
			"retired": retired or not available,
		})
	return entries


func configure(tender_template: Node3D, raider_template: Node3D) -> void:
	for index in 2:
		var actor_id: StringName = IDS[index]
		if _visuals.has(actor_id):
			continue
		var template := tender_template if index == 0 else raider_template
		if not is_instance_valid(template):
			continue
		var visual := _clone_visual(template, {})
		visual.name = "EmberlineRemoteTender" if index == 0 else "EmberlineRemoteRaider"
		visual.visible = false
		add_child(visual)
		_visuals[actor_id] = visual
		_materials[actor_id] = _material_rows(visual)
	set_process(false)
	set_physics_process(false)


func _exit_tree() -> void:
	clear()


## Called only from GameFlow's accepted authoritative-snapshot signal. The
## transport owns authentication, ordering and jitter; this seam additionally
## rejects malformed actor fields and stale convoy epochs/generations.
func consume_movement_section(movement: Array, station_origin: Vector3) -> void:
	for raw: Variant in movement:
		if not raw is Dictionary or StringName((raw as Dictionary).get("mode", &"")) != MODE:
			continue
		var entry := raw as Dictionary
		if not _valid_entry(entry):
			continue
		var epoch := int(entry.convoy_epoch)
		var generation := int(entry.entity_generation)
		if (_epoch > 0 and epoch != _epoch) or generation < _generation:
			continue
		_epoch = epoch
		if generation > _generation:
			_generation = generation
			_records.clear()
			_retired.clear()
			_destroyed.clear()
			_hide_visuals()
		var actor_id := StringName(entry.entity_id)
		var previous := _records.get(actor_id, {}) as Dictionary
		if (not previous.is_empty() and int(entry.pose_tick) <= int(previous.pose_tick)) \
				or (_retired.has(actor_id) and bool(entry.present)) \
				or (_destroyed.has(actor_id) and (bool(entry.present) or (bool(entry.available) and not bool(entry.destroyed)))):
			continue
		if bool(entry.destroyed):
			_destroyed[actor_id] = true
		if bool(entry.retired):
			_retired[actor_id] = true
		var record := entry.duplicate(true)
		record["world_position"] = (entry.position as Vector3) + station_origin
		_records[actor_id] = record
		var visual := _visuals.get(actor_id) as Node3D
		if is_instance_valid(visual):
			visual.global_transform = Transform3D(Basis(entry.rotation as Quaternion), record.world_position as Vector3)
			visual.visible = bool(entry.present)
			_apply_health_materials(actor_id)
		if bool(previous.get("present", false)) and bool(entry.destroyed) and bool(entry.available):
			_destruction_cues += 1
			actor_destroyed.emit(record.world_position as Vector3)


func clear() -> void:
	_hide_visuals()
	_records.clear()
	_retired.clear()
	_destroyed.clear()
	_epoch = 0
	_generation = 0
	_destruction_cues = 0


func set_reduced_flash_enabled(enabled: bool) -> void:
	_reduced_flash = enabled
	for actor_id: StringName in IDS:
		_apply_health_materials(actor_id)


func get_snapshot() -> Dictionary:
	return {"actors": _records.duplicate(true), "epoch": _epoch, "generation": _generation,
		"destruction_cues": _destruction_cues, "reduced_flash": _reduced_flash,
		"owns_combat_authority": false}


func get_visual(actor_id: StringName) -> Node3D:
	return _visuals.get(actor_id) as Node3D


func _hide_visuals() -> void:
	for visual: Node3D in _visuals.values():
		visual.visible = false


func _apply_health_materials(actor_id: StringName) -> void:
	var record := _records.get(actor_id, {}) as Dictionary
	var ratio := float(record.get("health", 1.0)) / maxf(0.001, float(record.get("maximum_health", 1.0)))
	for row: Dictionary in _materials.get(actor_id, []):
		var material := row.material as StandardMaterial3D
		material.albedo_color = (row.color as Color).lerp(Color("26211f"), (1.0 - ratio) * 0.7)
		material.emission_energy_multiplier = minf(float(row.energy), 1.0) if _reduced_flash else float(row.energy)


func _clone_visual(template: Node3D, materials: Dictionary) -> Node3D:
	var copy := Node3D.new()
	copy.name = template.name
	copy.transform = template.transform
	copy.visible = template.visible
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	if template is MeshInstance3D:
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = (template as MeshInstance3D).mesh
		copy.free()
		copy = mesh_copy
	elif template is MultiMeshInstance3D:
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = (template as MultiMeshInstance3D).multimesh.duplicate() as MultiMesh
		copy.free()
		copy = batch
	if copy is GeometryInstance3D:
		copy.name = template.name
		copy.transform = template.transform
		copy.visible = template.visible
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		var source_material := (template as GeometryInstance3D).material_override as StandardMaterial3D
		if source_material != null:
			var key := source_material.get_instance_id()
			if not materials.has(key):
				materials[key] = source_material.duplicate() as StandardMaterial3D
			(copy as GeometryInstance3D).material_override = materials[key]
	for child in template.get_children():
		if child is Node3D and not child is CollisionShape3D and not child is CollisionObject3D and not child is Light3D:
			copy.add_child(_clone_visual(child as Node3D, materials))
	return copy


func _material_rows(visual: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node in visual.find_children("*", "GeometryInstance3D", true, false):
		var material := (node as GeometryInstance3D).material_override as StandardMaterial3D
		if material != null and not seen.has(material.get_instance_id()):
			seen[material.get_instance_id()] = true
			rows.append({"material": material, "color": material.albedo_color, "energy": material.emission_energy_multiplier})
	return rows


func _valid_entry(entry: Dictionary) -> bool:
	if StringName(entry.get("entity_id", &"")) not in IDS or int(entry.get("owner_peer_id", 0)) != 1:
		return false
	for key in ["entity_generation", "convoy_epoch", "pose_tick"]:
		if not entry.get(key) is int or int(entry[key]) < (0 if key == "pose_tick" else 1):
			return false
	for key in ["present", "retired", "destroyed", "available"]:
		if not entry.get(key) is bool:
			return false
	for key in ["health", "maximum_health"]:
		if not (entry.get(key) is float or entry.get(key) is int) or not is_finite(float(entry[key])):
			return false
	var maximum := 75.0 if StringName(entry.entity_id) == TENDER_ID else 35.0
	return float(entry.maximum_health) == maximum and float(entry.health) >= 0.0 and float(entry.health) <= maximum \
		and bool(entry.destroyed) == (bool(entry.available) and float(entry.health) <= 0.0) \
		and not (bool(entry.present) and (not bool(entry.available) or bool(entry.destroyed) or bool(entry.retired))) \
		and entry.get("position") is Vector3 and (entry.position as Vector3).is_finite() \
		and entry.get("rotation") is Quaternion and (entry.rotation as Quaternion).is_finite() \
		and is_equal_approx((entry.rotation as Quaternion).length_squared(), 1.0)
