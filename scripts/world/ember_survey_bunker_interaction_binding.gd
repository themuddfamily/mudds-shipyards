class_name EmberSurveyBunkerInteractionBinding
extends Area3D

## Physical, presentation-owning interaction point for the authored Ember
## bunker/gantry survey site. GameFlow supplies the nearby actor through its
## existing generic interaction seam. This binding retains one completion fact
## but owns no movement, activity progression, reward, save, or history claim.

signal survey_completed(receipt: Dictionary)
signal service_repair_feedback(feedback: Dictionary)

const INTERACTION_LAYER := 1 << 3
const WORLD_LAYER := PhysicsLayers.WORLD_BODY_LAYER
const INTERACTION_ID: StringName = &"ember_bunker_gantry_survey"
const COMPLETION_RESPONSE_ID: StringName = &"ember_bunker_service_alcove"
const SERVICE_TERMINAL_ID: StringName = &"ember_bunker_service_terminal"
const PROMPT_READY := "[ E ]  LOG BUNKER / GANTRY SURVEY"
const PROMPT_COMPLETE := "[ COMPLETE ]  BUNKER / GANTRY SURVEY LOGGED"
const PROMPT_SERVICE := "[ E ]  SERVICE NEARBY LANDED CRAFT"
const PROMPT_SERVICE_COMPLETE := "[ COMPLETE ]  CRAFT COMPONENT SERVICED"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const ALCOVE_WALL_THICKNESS_M := 0.18
const ALCOVE_FRONT_CLEARANCE_M := 0.65
const ALCOVE_DOOR_CLEARANCE_M := 0.45
const ALCOVE_RUNTIME_NODE_COUNT := 7
const ALCOVE_MESH_INSTANCE_COUNT := 3
const ALCOVE_COLLISION_SHAPE_COUNT := 3
const ALCOVE_TRIANGLE_COUNT := 36
const WAYFINDING_READY_SCALE := Vector3(0.48, 1.9, 2.2)
const WAYFINDING_COMPLETE_SCALE := Vector3(2.2, 0.22, 0.7)
const WAYFINDING_READY_POSITION := Vector3(0.0, 1.1, 0.0)
const WAYFINDING_COMPLETE_HEIGHT_M := 2.35
const WAYFINDING_LINTEL_SIZE_M := Vector3(0.72, 1.15, 0.72)

var _host: Object
var _host_generation := -1
var _attachment_generation := -1
var _configured := false
var _attached := false
var _completed := false
var _completion_attachment_generation := -1
var _definition: Dictionary = {}
var _last_receipt: Dictionary = {}
var _marker: MeshInstance3D
var _material: StandardMaterial3D
var _response_body: StaticBody3D
var _response_meshes: Array[MeshInstance3D] = []
var _response_material: StandardMaterial3D
var _response_center_body_local_m := Vector3.ZERO
var _response_width_m := 0.0
var _response_height_m := 0.0
var _response_length_m := 0.0
var _wayfinding_direction := Vector3.ZERO
var _service_repair_sink := Callable()
var _service_terminal_generation := -1
var _service_request_sequence := 0
var _service_feedback_generation := 0
var _service_feedback_sequence := 0
var _service_consumed := false
var _service_status: StringName = &"locked"
var _last_service_receipt: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 0
	set_meta("station_interactable", true)
	set_meta("ember_surface_survey_interaction", true)
	set_meta("interaction_id", INTERACTION_ID)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "SurveyInteractionShape"
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	shape_node.shape = shape
	add_child(shape_node)
	_marker = MeshInstance3D.new()
	_marker.name = "SurveyLogPedestal"
	# One retained prism serves both states: upright it is the access blade;
	# after completion its stretched sloped profile becomes the overhead entry
	# lintel. Its authored bounds exactly match the old rectangular box.
	var mesh := PrismMesh.new()
	mesh.size = WAYFINDING_LINTEL_SIZE_M
	_marker.mesh = mesh
	_marker.position = Vector3(0.0, 0.575, 0.0)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_marker.material_override = _material
	add_child(_marker)
	_apply_presentation()


func configure(host: Object, definition: Variant) -> Dictionary:
	if _configured or host == null or not is_instance_valid(host) \
			or not host.has_method(&"get_generation") \
			or not host.has_method(&"get_attachment_generation") \
			or not definition is Dictionary:
		return _result(false, &"invalid_survey_interaction_configuration")
	var record := definition as Dictionary
	var position_value: Variant = record.get("position_body_local_m", Vector3.INF)
	var door_value: Variant = record.get("bunker_door_ground_body_local_m", Vector3.INF)
	var response_width := float(record.get("service_alcove_width_m", 0.0))
	var response_height := float(record.get("service_alcove_height_m", 0.0))
	if StringName(record.get("interaction_id", &"")) != INTERACTION_ID \
			or StringName(record.get("world_id", &"")) != &"ember_moon" \
			or position_value is not Vector3 or not (position_value as Vector3).is_finite() \
			or StringName(record.get("completion_response_id", &"")) != COMPLETION_RESPONSE_ID \
			or door_value is not Vector3 or not (door_value as Vector3).is_finite() \
			or not is_finite(response_width) or response_width < 2.0 \
			or not is_finite(response_height) or response_height < 2.3 \
			or bool(record.get("historical_claim", true)):
		return _result(false, &"invalid_survey_interaction_configuration")
	var route_delta := (door_value as Vector3) - (position_value as Vector3)
	route_delta.y = 0.0
	if route_delta.length() <= ALCOVE_FRONT_CLEARANCE_M + ALCOVE_DOOR_CLEARANCE_M + 1.0:
		return _result(false, &"invalid_survey_interaction_configuration")
	_host = host
	_host_generation = int(host.call(&"get_generation"))
	_attachment_generation = int(host.call(&"get_attachment_generation"))
	if not _valid_generation(_host_generation) or not _valid_generation(_attachment_generation):
		return _result(false, &"invalid_survey_interaction_generation")
	_definition = record.duplicate(true)
	position = position_value as Vector3
	_build_completion_response(
		door_value as Vector3, response_width, response_height
	)
	_configured = true
	_attached = true
	_apply_presentation()
	return _result(true, &"survey_interaction_configured")


func get_interaction_prompt() -> String:
	if not _current():
		return ""
	if not _completed:
		return PROMPT_READY
	if _service_terminal_generation > 0:
		return PROMPT_SERVICE_COMPLETE if _service_consumed else PROMPT_SERVICE
	return PROMPT_COMPLETE


func can_interact(actor: Node = null) -> bool:
	return _current() and _actor_is_current(actor) and (
		not _completed or (
			_service_terminal_generation > 0 and not _service_consumed \
			and _service_repair_sink.is_valid()
		)
	)


func interact(actor: Node = null) -> bool:
	if not _current():
		return false
	if _completed:
		return bool(submit_service_repair(
			actor, _host_generation, _attachment_generation,
			_service_terminal_generation
		).get("accepted", false))
	var submitted := submit_interaction(
		actor, _host_generation, _attachment_generation
	)
	return bool(submitted.get("accepted", false))


func submit_interaction(
		actor: Node,
		expected_host_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if not _current():
		return _result(false, &"survey_interaction_unavailable")
	if expected_host_generation != _host_generation \
			or expected_attachment_generation != _attachment_generation:
		return _result(false, &"stale_survey_interaction_generation")
	if not _actor_is_current(actor):
		return _result(false, &"survey_interaction_actor_mismatch")
	if _completed:
		return _result(false, &"survey_interaction_already_completed")
	_completed = true
	_completion_attachment_generation = _attachment_generation
	_last_receipt = {
		"interaction_id": INTERACTION_ID,
		"world_id": &"ember_moon",
		"landmark_ids": _definition.get("landmark_ids", PackedStringArray()).duplicate(),
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"activity_started": false,
		"reward_granted": false,
		"historical_claim": false,
		"completion_response_id": COMPLETION_RESPONSE_ID,
	}.duplicate(true)
	_apply_presentation()
	survey_completed.emit(_last_receipt.duplicate(true))
	return _result(true, &"survey_interaction_completed")


func configure_service_repair_sink(sink: Callable) -> Dictionary:
	if _service_repair_sink.is_valid() or not sink.is_valid():
		return _result(false, &"service_repair_sink_invalid")
	_service_repair_sink = sink
	return _result(true, &"service_repair_sink_configured")


func activate_service_terminal(activity_generation: int) -> Dictionary:
	if not _current() or not _completed or not _service_repair_sink.is_valid() \
			or activity_generation < 1 or activity_generation > MAX_SAFE_GENERATION \
			or _service_terminal_generation > 0 \
			or _service_feedback_generation >= MAX_SAFE_GENERATION:
		return _result(false, &"service_terminal_activation_invalid")
	_service_terminal_generation = activity_generation
	_service_feedback_generation += 1
	_service_feedback_sequence = 0
	_service_status = &"available"
	_last_service_receipt.clear()
	return _result(true, &"service_terminal_activated")


func reset_service_terminal(next_activity_generation: int) -> Dictionary:
	if _service_terminal_generation < 1 \
			or next_activity_generation <= _service_terminal_generation \
			or next_activity_generation > MAX_SAFE_GENERATION \
			or _service_feedback_generation >= MAX_SAFE_GENERATION:
		return _result(false, &"service_terminal_reset_invalid")
	_service_terminal_generation = -1
	_service_feedback_generation += 1
	_service_feedback_sequence = 0
	_service_request_sequence = 0
	_service_consumed = false
	_service_status = &"locked"
	_last_service_receipt.clear()
	return _result(true, &"service_terminal_reset")


func submit_service_repair(
		actor: Node, expected_host_generation: int,
		expected_attachment_generation: int, expected_terminal_generation: int
	) -> Dictionary:
	if not _current() or not _completed or not _service_repair_sink.is_valid():
		return _feedback_result(_result(false, &"service_terminal_unavailable"))
	if expected_host_generation != _host_generation \
			or expected_attachment_generation != _attachment_generation \
			or expected_terminal_generation != _service_terminal_generation:
		return _feedback_result(_result(false, &"stale_service_terminal_generation"))
	if not _actor_is_current(actor):
		_service_status = &"service_terminal_actor_mismatch"
		return _feedback_result(_result(false, &"service_terminal_actor_mismatch"))
	if _service_consumed:
		return _feedback_result(_result(false, &"service_terminal_already_consumed"))
	if _service_request_sequence >= MAX_SAFE_GENERATION:
		return _feedback_result(_result(false, &"service_terminal_sequence_exhausted"))
	_service_request_sequence += 1
	var result := _service_repair_sink.call({
		"terminal_id": SERVICE_TERMINAL_ID,
		"terminal_generation": _service_terminal_generation,
		"request_sequence": _service_request_sequence,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"actor_instance_id": actor.get_instance_id(),
		"terminal_world_position": global_position,
	}) as Dictionary
	_last_service_receipt = result.duplicate(true)
	if bool(result.get("accepted", false)):
		_service_consumed = true
		_service_status = &"repair_applied"
	else:
		_service_status = StringName(result.get("reason", &"repair_rejected"))
	return _feedback_result(result)


func _feedback_result(result: Dictionary) -> Dictionary:
	if _service_feedback_sequence >= MAX_SAFE_GENERATION:
		return result
	_service_feedback_sequence += 1
	var accepted := bool(result.get("accepted", false))
	var reason := StringName(result.get("reason", &"repair_rejected"))
	var outcome := &"completed" if accepted else (
		&"unavailable" if reason == &"service_terminal_unavailable" else &"rejected"
	)
	service_repair_feedback.emit({
		"terminal_id": SERVICE_TERMINAL_ID,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"terminal_generation": _service_terminal_generation,
		"feedback_generation": _service_feedback_generation,
		"feedback_sequence": _service_feedback_sequence,
		"request_sequence": _service_request_sequence,
		"outcome": outcome,
		"reason": reason,
		"world_position": global_position,
		"presentation_only": true,
		"authority": {
			"repair": false, "components": false, "movement": false,
			"game_flow": false, "network": false, "persistence": false,
		},
	}.duplicate(true))
	return result


func detach() -> Dictionary:
	if not _configured or not _attached:
		return _result(false, &"survey_interaction_not_attached")
	_attached = false
	_apply_presentation()
	return _result(true, &"survey_interaction_detached")


func reenter(next_attachment_generation: int) -> Dictionary:
	if not _configured or _attached or not _valid_generation(next_attachment_generation) \
			or next_attachment_generation <= _attachment_generation \
			or int(_host.call(&"get_attachment_generation")) != next_attachment_generation:
		return _result(false, &"stale_survey_interaction_generation")
	_attachment_generation = next_attachment_generation
	_attached = true
	_apply_presentation()
	return _result(true, &"survey_interaction_reentered")


## Reapplies a persistence-validated active-journey completion without
## emitting another survey event or reopening the unrelated service action.
func restore_interrupted_completion(completion: Variant) -> Dictionary:
	if not _current() or _completed or not completion is Dictionary:
		return _result(false, &"survey_interrupted_restore_invalid")
	var saved := completion as Dictionary
	if saved.size() != 7 \
			or saved.get("completed") is not bool \
			or not bool(saved.get("completed", false)) \
			or StringName(saved.get("checkpoint_id", &"")) \
				!= &"ember_bunker_gantry_log" \
			or StringName(saved.get("interaction_id", &"")) != INTERACTION_ID \
			or int(saved.get("activity_generation", -1)) < 1 \
			or int(saved.get("run_generation", -1)) != _host_generation \
			or int(saved.get("attachment_generation", -1)) < 1 \
			or int(saved.get("attachment_generation", -1)) >= _attachment_generation \
			or not saved.get("receipt", {}) is Dictionary:
		return _result(false, &"survey_interrupted_restore_invalid")
	_completed = true
	_completion_attachment_generation = _attachment_generation
	_last_receipt = {
		"interaction_id": INTERACTION_ID,
		"world_id": &"ember_moon",
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"activity_started": false,
		"reward_granted": false,
		"historical_claim": false,
		"completion_response_id": COMPLETION_RESPONSE_ID,
		"restored_interrupted_presentation": true,
	}.duplicate(true)
	_apply_presentation()
	return {
		"accepted": true,
		"reason": &"survey_interrupted_completion_restored",
		"interaction_replayed": false,
		"reward_replayed": false,
	}.duplicate(true)


func get_persistence_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"interaction_id": INTERACTION_ID,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"completed": _completed,
		"completion_attachment_generation": _completion_attachment_generation,
		"receipt": _last_receipt.duplicate(true),
	}.duplicate(true)


func validate_persistence_snapshot(snapshot: Variant) -> Dictionary:
	if not _configured or not _attached or not snapshot is Dictionary:
		return _result(false, &"invalid_survey_interaction_snapshot")
	var saved := snapshot as Dictionary
	if int(saved.get("schema_version", -1)) != 1 \
			or StringName(saved.get("interaction_id", &"")) != INTERACTION_ID \
			or int(saved.get("host_generation", -1)) != _host_generation \
			or int(saved.get("attachment_generation", -1)) >= _attachment_generation \
			or saved.get("completed") is not bool:
		return _result(false, &"stale_survey_interaction_snapshot")
	var completion_generation := int(saved.get("completion_attachment_generation", -1))
	if bool(saved.completed) and (completion_generation < 0 \
			or completion_generation > int(saved.attachment_generation)):
		return _result(false, &"invalid_survey_interaction_snapshot")
	return _result(true, &"survey_interaction_snapshot_valid")


func restore_persistence_snapshot(snapshot: Variant) -> Dictionary:
	var validation := validate_persistence_snapshot(snapshot)
	if not bool(validation.get("accepted", false)):
		return validation
	var saved := snapshot as Dictionary
	_completed = bool(saved.completed)
	_completion_attachment_generation = int(saved.completion_attachment_generation)
	_last_receipt = (saved.get("receipt", {}) as Dictionary).duplicate(true)
	_apply_presentation()
	return _result(true, &"survey_interaction_restored")


## Applies an already validated terminal relay-survey observation to this
## binding's physical presentation. It deliberately emits no interaction event
## and creates no activity or reward receipt.
func restore_terminal_completion_presentation(completion: Variant) -> Dictionary:
	if not _current() or _completed or not completion is Dictionary:
		return _result(false, &"terminal_survey_presentation_restore_invalid")
	var saved := completion as Dictionary
	if saved.get("completed") is not bool or not bool(saved.completed) \
			or saved.size() != 11 \
			or StringName(saved.get("checkpoint_id", &"")) \
				!= &"ember_bunker_gantry_log" \
			or StringName(saved.get("interaction_id", &"")) != INTERACTION_ID \
			or StringName(saved.get("completion_response_id", &"")) \
				!= COMPLETION_RESPONSE_ID \
			or int(saved.get("activity_generation", -1)) < 1 \
			or int(saved.get("source_run_generation", -1)) < 1 \
			or int(saved.get("source_attachment_generation", -1)) < 1 \
			or StringName(saved.get("content_class", &"")) != &"NEW" \
			or StringName(saved.get("interpretation_status", &"")) \
				!= &"modern_interpretation" \
			or bool(saved.get("historical_claim", true)) \
			or bool(saved.get("replay_allowed", true)):
		return _result(false, &"terminal_survey_presentation_restore_invalid")
	_completed = true
	_completion_attachment_generation = _attachment_generation
	_last_receipt = {
		"interaction_id": INTERACTION_ID,
		"world_id": &"ember_moon",
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"activity_started": false,
		"reward_granted": false,
		"historical_claim": false,
		"completion_response_id": COMPLETION_RESPONSE_ID,
		"restored_terminal_presentation": true,
	}.duplicate(true)
	_apply_presentation()
	return {
		"accepted": true,
		"reason": &"terminal_survey_presentation_restored",
		"interaction_replayed": false,
		"reward_replayed": false,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	_apply_presentation()
	return {
		"configured": _configured,
		"attached": _attached,
		"interaction_id": INTERACTION_ID,
		"position_body_local_m": position,
		"prompt": get_interaction_prompt(),
		"completed": _completed,
		"completion_attachment_generation": _completion_attachment_generation,
		"last_receipt": _last_receipt.duplicate(true),
		"physical": {
			"collision_layer": collision_layer,
			"shape": &"sphere",
			"radius_m": 0.65,
			"marker_visible": _marker.visible if _marker != null else false,
		},
		"completion_response": {
			"response_id": COMPLETION_RESPONSE_ID,
			"kind": &"three_sided_service_alcove",
			"revealed": _response_is_active(),
			"collision_enabled": _response_body != null and _response_body.collision_layer == WORLD_LAYER,
			"center_body_local_m": _response_center_body_local_m,
			"open_route": true,
			"open_front": true,
			"corridor_width_m": _response_width_m,
			"headroom_m": _response_height_m,
			"length_m": _response_length_m,
			"runtime_nodes": ALCOVE_RUNTIME_NODE_COUNT,
			"mesh_instances": ALCOVE_MESH_INSTANCE_COUNT,
			"collision_shapes": ALCOVE_COLLISION_SHAPE_COUNT,
			"triangles": ALCOVE_TRIANGLE_COUNT,
		},
		"service_terminal": {
			"terminal_id": SERVICE_TERMINAL_ID,
			"terminal_generation": _service_terminal_generation,
			"available": _current() and _completed \
				and _service_terminal_generation > 0 and not _service_consumed,
			"consumed": _service_consumed,
			"request_sequence": _service_request_sequence,
			"feedback_generation": _service_feedback_generation,
			"feedback_sequence": _service_feedback_sequence,
			"status": _service_status,
			"status_text": _service_status_text(),
			"last_receipt": _last_service_receipt.duplicate(true),
			"authority": {
				"repair": false, "components": false, "movement": false,
				"landing": false, "ownership": false, "hud_core": false,
			},
		},
		"wayfinding": _wayfinding_snapshot(),
		"evidence": {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"historical_claim": false,
		},
		"authority": {
			"movement": false, "activity": false, "reward": false,
			"save": false, "history": false, "hud": false,
		},
	}.duplicate(true)


func _service_status_text() -> String:
	match _service_status:
		&"available": return "SERVICE LINK READY — LANDED CRAFT IN RANGE"
		&"repair_applied": return "COMPONENT SERVICE APPLIED"
		&"no_damaged_component": return "NO DAMAGED COMPONENT REQUIRES SERVICE"
		&"service_target_out_of_range": return "LANDED CRAFT OUT OF SERVICE RANGE"
		&"service_actor_out_of_range": return "MOVE CLOSER TO THE SERVICE TERMINAL"
		&"service_terminal_actor_mismatch": return "RETURN TO THE ON-FOOT SURVEYOR TO USE SERVICE"
	return "SERVICE LINK LOCKED"


func _current() -> bool:
	if not _configured or not _attached or _host == null or not is_instance_valid(_host):
		return false
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	return int(_host.call(&"get_generation")) == _host_generation \
		and int(_host.call(&"get_attachment_generation")) == _attachment_generation \
		and bool(host_snapshot.get("attached", false)) \
		and StringName(host_snapshot.get("phase_id", &"")) == &"on_foot"


func _actor_is_current(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var identities := (_host.call(&"get_snapshot") as Dictionary).get("identities", {}) as Dictionary
	return actor.get_instance_id() == int(identities.get("player_instance_id", 0))


func _apply_presentation() -> void:
	var presentation_active := _presentation_is_current()
	collision_layer = INTERACTION_LAYER if presentation_active else 0
	if _marker != null:
		_marker.visible = presentation_active
		if _completed:
			_marker.position = _wayfinding_direction * ALCOVE_FRONT_CLEARANCE_M \
				+ Vector3.UP * WAYFINDING_COMPLETE_HEIGHT_M
			_marker.scale = WAYFINDING_COMPLETE_SCALE
		else:
			_marker.position = WAYFINDING_READY_POSITION
			_marker.scale = WAYFINDING_READY_SCALE
	if _material != null:
		_material.albedo_color = Color(0.32, 0.86, 0.78, 1.0) if _completed \
			else Color(0.95, 0.52, 0.18, 1.0)
		_material.emission = _material.albedo_color
		_material.emission_energy_multiplier = 1.2 if _completed else 0.7
	var response_active := _response_is_active()
	if _response_body != null:
		_response_body.collision_layer = WORLD_LAYER if response_active else 0
		_response_body.collision_mask = 0
	for response_mesh: MeshInstance3D in _response_meshes:
		response_mesh.visible = response_active


func _build_completion_response(
		door_ground_body_local_m: Vector3,
		corridor_width_m: float,
		headroom_m: float
	) -> void:
	var direction := door_ground_body_local_m - position
	direction.y = 0.0
	var total_distance := direction.length()
	direction /= total_distance
	_wayfinding_direction = direction
	if _marker != null:
		_marker.basis = Basis.looking_at(direction, Vector3.UP)
	_response_length_m = total_distance - ALCOVE_FRONT_CLEARANCE_M - ALCOVE_DOOR_CLEARANCE_M
	_response_width_m = corridor_width_m
	_response_height_m = headroom_m
	var center_offset := direction * (ALCOVE_FRONT_CLEARANCE_M + _response_length_m * 0.5)
	_response_center_body_local_m = position + center_offset

	_response_body = StaticBody3D.new()
	_response_body.name = "OwnedBunkerServiceAlcove"
	_response_body.position = center_offset
	_response_body.basis = Basis.looking_at(direction, Vector3.UP)
	_response_body.collision_layer = 0
	_response_body.collision_mask = 0
	_response_body.set_meta("completion_response_id", COMPLETION_RESPONSE_ID)
	_response_body.set_meta("presentation_only", true)
	add_child(_response_body)

	_response_material = StandardMaterial3D.new()
	_response_material.albedo_color = Color("786553")
	_response_material.metallic = 0.42
	_response_material.roughness = 0.68
	var wall_offset := corridor_width_m * 0.5 + ALCOVE_WALL_THICKNESS_M * 0.5
	_add_alcove_part(
		"PortWall", Vector3(ALCOVE_WALL_THICKNESS_M, headroom_m, _response_length_m),
		Vector3(-wall_offset, headroom_m * 0.5, 0.0)
	)
	_add_alcove_part(
		"StarboardWall", Vector3(ALCOVE_WALL_THICKNESS_M, headroom_m, _response_length_m),
		Vector3(wall_offset, headroom_m * 0.5, 0.0)
	)
	_add_alcove_part(
		"Roof",
		Vector3(corridor_width_m + ALCOVE_WALL_THICKNESS_M * 2.0, ALCOVE_WALL_THICKNESS_M, _response_length_m),
		Vector3(0.0, headroom_m + ALCOVE_WALL_THICKNESS_M * 0.5, 0.0)
	)


func _add_alcove_part(part_name: String, size: Vector3, local_position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name + "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _response_material
	mesh_instance.position = local_position
	mesh_instance.visible = false
	_response_body.add_child(mesh_instance)
	_response_meshes.append(mesh_instance)
	var shape_node := CollisionShape3D.new()
	shape_node.name = part_name + "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = local_position
	_response_body.add_child(shape_node)


func _response_is_active() -> bool:
	return _presentation_is_current() and _completed


func _presentation_is_current() -> bool:
	if not _configured or not _attached or _host == null or not is_instance_valid(_host):
		return false
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	return int(_host.call(&"get_generation")) == _host_generation \
		and int(_host.call(&"get_attachment_generation")) == _attachment_generation \
		and bool(host_snapshot.get("attached", false)) \
		and StringName(host_snapshot.get("phase_id", &"")) == &"on_foot"


func _wayfinding_snapshot() -> Dictionary:
	var visible := _marker != null and _marker.visible
	var lintel_mesh := _marker.mesh as PrismMesh if _marker != null else null
	return {
		"visible": visible,
		"state": (&"service_entry_lintel" if _completed else &"survey_access_blade") \
			if visible else &"hidden",
		"target_id": &"ember_survey_service_bunker_door",
		"direction_body_local": _wayfinding_direction,
		"marker_local_position": _marker.position if _marker != null else Vector3.ZERO,
		"marker_scale": _marker.scale if _marker != null else Vector3.ONE,
		"silhouette": &"elongated_directional_blade" if not _completed \
			else &"bevelled_overhead_service_entry_lintel",
		"structural_profile": {
			"shape": &"prism_bevelled_lintel",
			"bounds_m": lintel_mesh.size if lintel_mesh != null else Vector3.ZERO,
			"triangle_count": int(lintel_mesh.get_faces().size() / 3) \
				if lintel_mesh != null else 0,
			"bevelled_profile": true,
			"collision_changed": false,
		},
		"color_independent": true,
		"gameplay_readability_distance_m": 24.0,
		"reused_node": &"SurveyLogPedestal",
		"host_generation": _host_generation,
		"incremental_budget": {
			"nodes": 0, "mesh_instances": 0, "materials": 0,
			"triangles": 0, "collision_shapes": 0,
		},
		"authority": {
			"navigation": false, "movement": false, "collision": false,
			"activity": false, "reward": false,
		},
	}.duplicate(true)


func _valid_generation(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_GENERATION


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"interaction": get_snapshot(),
	}.duplicate(true)
