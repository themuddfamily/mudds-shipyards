class_name HeavyBreachActivityBoard
extends Area3D

## Physical station contract for the production heavy-breach encounter.
##
## The board owns admission, range/generation fencing and the reward handoff
## only. EncounterScenarioDirector remains the objective authority, the
## injected LiveCombatAuthority remains the combat authority, and the world
## owns the protected objective node.

signal interaction_resolved(actor: Node, result: Dictionary)

const COMPONENT_ID: StringName = &"heavy-breach-activity-board"
const ACTIVITY_ID: StringName = &"shipyard_heavy_breach"
const REWARD_ADAPTER := preload("res://scripts/world/nearby_activity_reward_adapter.gd")
const INTERACTION_RADIUS := 2.8
const BOARD_SIZE := Vector3(0.75, 1.35, 1.8)
const PEDESTAL_SIZE := Vector3(1.4, 1.0, 2.2)
const CONSOLE_OFFSET := Vector3(0.0, 0.0, 0.0)

var _director: EncounterScenarioDirector
var _combat_authority: LiveCombatAuthority
var _protected_objective: Node3D
var _reward_adapter: RefCounted
var _last_reward_result: Dictionary = {}
var _last_result: Dictionary = {}
var _generation := 1
var _active_director_generation := 0
var _highest_reward_generation := 0
var _built := false
var _attached := false


func _enter_tree() -> void:
	_attached = true
	if _generation < 1:
		_generation = 1


func _exit_tree() -> void:
	# Streaming the world out is an explicit activity boundary. Abort before
	# clearing our references so the director stands down the real picket/screen
	# roster and cannot leave a live combat source behind on re-entry.
	if is_instance_valid(_director) and _director.is_running() \
			and _director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH:
		_director.abort(EncounterScenarioDirector.OUTCOME_WITHDRAWN)
	_active_director_generation = 0
	_attached = false
	_generation += 1


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
		protected_objective: Node3D,
		director: EncounterScenarioDirector,
		combat_authority: LiveCombatAuthority
	) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"board_unavailable")
	if not is_instance_valid(protected_objective) \
			or not is_instance_valid(director) \
			or not is_instance_valid(combat_authority):
		return _result(false, &"external_owner_required")
	if is_instance_valid(_director):
		if _director == director and _combat_authority == combat_authority \
				and _protected_objective == protected_objective:
			return _result(true, &"already_configured")
		return _result(false, &"already_configured")
	if director == self or combat_authority == self:
		return _result(false, &"board_cannot_own_authority")
	_director = director
	_combat_authority = combat_authority
	_protected_objective = protected_objective
	if not _director.scenario_concluded.is_connected(_on_scenario_concluded):
		_director.scenario_concluded.connect(_on_scenario_concluded)
	return _result(true, &"configured")


## The callback is the caller's reward authority. This board only submits one
## generation-fenced request after the director reports a cleared breach.
func configure_reward_handoff(callback: Callable) -> Dictionary:
	if _reward_adapter != null:
		return _result(false, &"reward_handoff_already_configured")
	var adapter := REWARD_ADAPTER.new() as RefCounted
	var configured: Dictionary = adapter.call(
		"configure", callback, ACTIVITY_ID, &"return_heavy_breach_credit"
	)
	if not bool(configured.get("accepted", false)):
		return configured
	_reward_adapter = adapter
	return _result(true, &"reward_handoff_configured")


func get_generation() -> int:
	return _generation


func get_interaction_snapshot(actor: Node, expected_generation: int = 0) -> Dictionary:
	var result := {
		"accepted": false,
		"available": false,
		"reason": &"unavailable",
		"activity_id": ACTIVITY_ID,
		"generation": _generation,
		"maximum_distance": INTERACTION_RADIUS,
		"distance": -1.0,
	}
	var requested_generation := _generation if expected_generation == 0 else expected_generation
	if requested_generation != _generation:
		result["reason"] = &"stale_generation"
		return result
	if not is_instance_valid(_director) or not is_instance_valid(_protected_objective) \
			or not _attached:
		result["reason"] = &"external_owners_unavailable"
		return result
	if not actor is Node3D or not is_instance_valid(actor) \
			or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		result["reason"] = &"invalid_actor"
		return result
	var distance := (actor as Node3D).global_position.distance_to(global_position)
	result["accepted"] = true
	result["distance"] = distance
	if distance > INTERACTION_RADIUS:
		result["reason"] = &"out_of_range"
		return result
	result["available"] = true
	result["reason"] = &"ready"
	return result


func interact(actor: Node = null, expected_generation: int = 0) -> bool:
	var gate := get_interaction_snapshot(actor, expected_generation)
	if not bool(gate.get("available", false)):
		_last_result = gate.duplicate(true)
		interaction_resolved.emit(actor, _last_result.duplicate(true))
		return false
	if _director.is_running():
		_last_result = _result(false, &"activity_busy")
		interaction_resolved.emit(actor, _last_result.duplicate(true))
		return false
	var accepted := _director.begin_heavy_breach(actor as Node3D, _protected_objective)
	_last_result = {
		"accepted": accepted,
		"reason": &"heavy_breach_started" if accepted else &"director_rejected_start",
		"generation": _generation,
		"director_generation": _director.get_scenario_generation(),
		"snapshot": get_snapshot(),
	}.duplicate(true)
	if accepted:
		_active_director_generation = _director.get_scenario_generation()
	interaction_resolved.emit(actor, _last_result.duplicate(true))
	return accepted


## Recovery is physical-board gated just like start. It aborts a live director
## first, then advances this board generation so stale callers cannot restart.
func abort_and_reset(actor: Node, expected_generation: int = 0) -> Dictionary:
	var gate := get_interaction_snapshot(actor, expected_generation)
	if not bool(gate.get("accepted", false)) or not bool(gate.get("available", false)):
		_last_result = gate.duplicate(true)
		return _last_result.duplicate(true)
	var aborted := false
	if _director.is_running() \
			and _director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH:
		_director.abort(EncounterScenarioDirector.OUTCOME_WITHDRAWN)
		aborted = true
	_active_director_generation = 0
	_generation += 1
	_last_result = {
		"accepted": true,
		"reason": &"reset",
		"aborted": aborted,
		"generation": _generation,
		"snapshot": get_snapshot(),
	}.duplicate(true)
	return _last_result.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func get_reward_handoff_snapshot() -> Dictionary:
	return {
		"configured": _reward_adapter != null,
		"highest_reward_generation": _highest_reward_generation,
		"last_result": _last_reward_result.duplicate(true),
		"adapter": _reward_adapter.call("get_snapshot")
			if _reward_adapter != null else {},
		"reward_authority": false,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	var director_snapshot := (
		_director.get_audit_report() if is_instance_valid(_director) else {}
	)
	return {
		"component_id": COMPONENT_ID,
		"activity_id": ACTIVITY_ID,
		"generation": _generation,
		"active_director_generation": _active_director_generation,
		"attached": _attached,
		"configured": is_instance_valid(_director) and is_instance_valid(_protected_objective),
		"director_instance_id": _director.get_instance_id()
			if is_instance_valid(_director) else 0,
		"combat_authority_instance_id": _combat_authority.get_instance_id()
			if is_instance_valid(_combat_authority) else 0,
		"protected_objective": String(_protected_objective.name)
			if is_instance_valid(_protected_objective) else "",
		"director": director_snapshot.duplicate(true),
		"last_result": _last_result.duplicate(true),
		"reward_handoff": get_reward_handoff_snapshot(),
		"authority": {
			"board_admission": true,
			"combat": false,
			"damage": false,
			"objective": false,
			"reward": false,
		},
		"process_loops": int(is_processing()) + int(is_physics_processing()),
	}.duplicate(true)


func _on_scenario_concluded(scenario_id: StringName, outcome: StringName) -> void:
	if scenario_id != EncounterScenarioDirector.SCENARIO_HEAVY_BREACH \
			or _active_director_generation < 1:
		return
	var generation := _active_director_generation
	if outcome == EncounterScenarioDirector.OUTCOME_CLEARED \
			and _reward_adapter != null and generation > _highest_reward_generation:
		var request := {
			"activity_id": ACTIVITY_ID,
			"state_id": &"concluded",
			"outcome": outcome,
			"generation": generation,
			"scenario": scenario_id,
			"protected_objective": (
				String(_protected_objective.name)
				if is_instance_valid(_protected_objective) else ""
			),
		}.duplicate(true)
		_last_reward_result = _reward_adapter.call("consume", request, generation)
		if bool(_last_reward_result.get("accepted", false)):
			_highest_reward_generation = generation
	_active_director_generation = 0


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
	material.albedo_color = Color("4d2d17")
	material.metallic = 0.45
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color("ff9b39")
	material.emission_energy_multiplier = 0.35
	console.material_override = material
	var label := Label3D.new()
	label.name = "ActivityLabel"
	label.text = "HEAVY BREACH"
	label.font_size = 32
	label.modulate = Color("ffd08e")
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
