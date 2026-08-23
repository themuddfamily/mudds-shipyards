class_name StationDefenseActivityBoard
extends Area3D

## Physical station-side request adapter for the production defense encounter.
## StationDefenseEncounterContent/Host remains the activity authority and the
## injected LiveCombatAuthority remains the only combat resolver.

signal interaction_resolved(actor: Node, result: Dictionary)

const COMPONENT_ID: StringName = &"station-defense-activity-board"
const ACTIVITY_ID: StringName = &"shipyard_perimeter_defense"
const INTERACTION_RADIUS := 2.6
const BOARD_SIZE := Vector3(0.75, 1.35, 1.8)
const PEDESTAL_SIZE := Vector3(1.4, 1.0, 2.2)
const CONSOLE_OFFSET := Vector3(1.25, 0.0, 0.0)

var _content: StationDefenseEncounterContent
var _combat_authority: LiveCombatAuthority
var _activity_director: ActivityDirector
var _built := false
var _last_result: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	monitoring = false
	monitorable = true
	if not _built:
		_built = true
		_build_physical_board()


func configure_external_owners(
		content: StationDefenseEncounterContent,
		combat_authority: LiveCombatAuthority,
		activity_director: ActivityDirector
	) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"board_unavailable")
	if (
		not is_instance_valid(content)
		or not is_instance_valid(combat_authority)
		or not is_instance_valid(activity_director)
		or content.get_parent() != get_parent()
		or combat_authority.is_ancestor_of(content)
	):
		return _result(false, &"external_owner_required")
	if is_instance_valid(_content):
		if (
			_content == content
			and _combat_authority == combat_authority
			and _activity_director == activity_director
		):
			return _result(true, &"already_configured")
		return _result(false, &"already_configured")
	var configured := content.configure_external_combat_authority(combat_authority)
	if not bool(configured.get("accepted", false)):
		return _result(false, StringName(configured.get("reason", &"content_configuration_failed")))
	_content = content
	_combat_authority = combat_authority
	_activity_director = activity_director
	return _result(true, &"configured")


func get_interaction_snapshot(actor: Node, expected_generation: int) -> Dictionary:
	var generation := _content.get_generation() if is_instance_valid(_content) else 0
	var result := {
		"accepted": false,
		"available": false,
		"reason": &"unavailable",
		"activity_id": ACTIVITY_ID,
		"generation": generation,
		"maximum_distance": INTERACTION_RADIUS,
		"distance": -1.0,
	}
	if expected_generation != generation:
		result["reason"] = &"stale_generation"
		return result
	if not actor is Node3D or not is_instance_valid(_content) or not _content.is_content_ready():
		result["reason"] = &"invalid_actor_or_content"
		return result
	var distance := (actor as Node3D).global_position.distance_to(global_position)
	result["distance"] = distance
	result["accepted"] = true
	if distance > INTERACTION_RADIUS:
		result["reason"] = &"out_of_range"
		return result
	if not is_instance_valid(_activity_director) or not _activity_director.is_inside_tree():
		result["reason"] = &"activity_director_unavailable"
		return result
	result["available"] = true
	result["reason"] = &"ready"
	return result


func interact(actor: Node = null) -> bool:
	var generation := _content.get_generation() if is_instance_valid(_content) else 0
	var gate := get_interaction_snapshot(actor, generation)
	if not bool(gate.get("available", false)):
		_last_result = gate.duplicate(true)
		interaction_resolved.emit(actor, _last_result.duplicate(true))
		return false
	_last_result = _content.start(generation)
	interaction_resolved.emit(actor, _last_result.duplicate(true))
	return bool(_last_result.get("accepted", false))


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"activity_id": ACTIVITY_ID,
		"configured": is_instance_valid(_content),
		"content_instance_id": _content.get_instance_id() if is_instance_valid(_content) else 0,
		"combat_authority_instance_id": (
			_combat_authority.get_instance_id() if is_instance_valid(_combat_authority) else 0
		),
		"activity_director_instance_id": (
			_activity_director.get_instance_id() if is_instance_valid(_activity_director) else 0
		),
		"last_result": _last_result.duplicate(true),
		"combat_authority": false,
		"activity_authority": false,
		"health_authority": false,
		"reward_authority": false,
		"ship_motion_authority": false,
		"process_loops": int(is_processing()) + int(is_physics_processing()),
	}.duplicate(true)


func _build_physical_board() -> void:
	var body := StaticBody3D.new()
	body.name = "CollisionBackedConsole"
	body.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	body.collision_mask = PhysicsLayers.WORLD_BODY_MASK
	add_child(body)
	var body_shape := CollisionShape3D.new()
	body_shape.name = "Collision"
	var pedestal_shape := BoxShape3D.new()
	pedestal_shape.size = PEDESTAL_SIZE
	body_shape.shape = pedestal_shape
	body_shape.position = CONSOLE_OFFSET + Vector3(0.0, -0.5, 0.0)
	body.add_child(body_shape)
	var pedestal_mesh := MeshInstance3D.new()
	pedestal_mesh.name = "Pedestal"
	var pedestal_box := BoxMesh.new()
	pedestal_box.size = PEDESTAL_SIZE
	pedestal_mesh.mesh = pedestal_box
	pedestal_mesh.position = body_shape.position
	body.add_child(pedestal_mesh)
	var console := MeshInstance3D.new()
	console.name = "ActivityBoardConsole"
	var console_box := BoxMesh.new()
	console_box.size = BOARD_SIZE
	console.mesh = console_box
	console.position = CONSOLE_OFFSET + Vector3(0.0, 0.62, 0.0)
	body.add_child(console)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("17424d")
	material.metallic = 0.45
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color("39c7d5")
	material.emission_energy_multiplier = 0.35
	console.material_override = material
	var label := Label3D.new()
	label.name = "ActivityLabel"
	label.text = "PERIMETER DEFENSE"
	label.font_size = 32
	label.modulate = Color("8ef4f2")
	label.position = CONSOLE_OFFSET + Vector3(0.0, 0.72, 0.94)
	label.pixel_size = 0.006
	add_child(label)
	var interaction_shape := CollisionShape3D.new()
	interaction_shape.name = "InteractionCollision"
	var interaction_box := BoxShape3D.new()
	interaction_box.size = Vector3(2.4, 2.2, 1.8)
	interaction_shape.shape = interaction_box
	interaction_shape.position = CONSOLE_OFFSET + Vector3(0.0, 0.25, 0.45)
	add_child(interaction_shape)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "snapshot": get_snapshot()}
