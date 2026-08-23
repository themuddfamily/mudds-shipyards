class_name EmberSurveyBunkerInteractionBinding
extends Area3D

## Physical, presentation-owning interaction point for the authored Ember
## bunker/gantry survey site. GameFlow supplies the nearby actor through its
## existing generic interaction seam. This binding retains one completion fact
## but owns no movement, activity progression, reward, save, or history claim.

signal survey_completed(receipt: Dictionary)

const INTERACTION_LAYER := 1 << 3
const INTERACTION_ID: StringName = &"ember_bunker_gantry_survey"
const PROMPT_READY := "[ E ]  LOG BUNKER / GANTRY SURVEY"
const PROMPT_COMPLETE := "[ COMPLETE ]  BUNKER / GANTRY SURVEY LOGGED"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

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
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 1.15, 0.72)
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
	if StringName(record.get("interaction_id", &"")) != INTERACTION_ID \
			or StringName(record.get("world_id", &"")) != &"ember_moon" \
			or position_value is not Vector3 or not (position_value as Vector3).is_finite() \
			or bool(record.get("historical_claim", true)):
		return _result(false, &"invalid_survey_interaction_configuration")
	_host = host
	_host_generation = int(host.call(&"get_generation"))
	_attachment_generation = int(host.call(&"get_attachment_generation"))
	if not _valid_generation(_host_generation) or not _valid_generation(_attachment_generation):
		return _result(false, &"invalid_survey_interaction_generation")
	_definition = record.duplicate(true)
	position = position_value as Vector3
	_configured = true
	_attached = true
	_apply_presentation()
	return _result(true, &"survey_interaction_configured")


func get_interaction_prompt() -> String:
	if not _current():
		return ""
	return PROMPT_COMPLETE if _completed else PROMPT_READY


func can_interact(actor: Node = null) -> bool:
	return _current() and not _completed and _actor_is_current(actor)


func interact(actor: Node = null) -> bool:
	if not _current():
		return false
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
	}.duplicate(true)
	_apply_presentation()
	survey_completed.emit(_last_receipt.duplicate(true))
	return _result(true, &"survey_interaction_completed")


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


func get_snapshot() -> Dictionary:
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
	collision_layer = INTERACTION_LAYER if _configured and _attached else 0
	if _marker != null:
		_marker.visible = _configured and _attached
	if _material != null:
		_material.albedo_color = Color(0.32, 0.86, 0.78, 1.0) if _completed \
			else Color(0.95, 0.52, 0.18, 1.0)
		_material.emission = _material.albedo_color
		_material.emission_energy_multiplier = 1.2 if _completed else 0.7


func _valid_generation(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_GENERATION


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"interaction": get_snapshot(),
	}.duplicate(true)
