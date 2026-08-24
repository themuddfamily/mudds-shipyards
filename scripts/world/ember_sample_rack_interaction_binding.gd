class_name EmberSampleRackInteractionBinding
extends Area3D

## Generation-fenced interaction point over the existing authored Ember sample
## rack. The Area supplies only proximity discovery and a text marker; it owns
## no route, reward, movement, save, history, or solid-geometry authority.

signal sample_rack_completed(receipt: Dictionary)

const INTERACTION_LAYER := 1 << 3
const INTERACTION_ID: StringName = &"ember_sample_rack_analysis"
const CHECKPOINT_ID: StringName = &"ember_sample_rack_analysis_log"
const COMPLETION_RESPONSE_ID: StringName = &"ember_sample_rack_analysis_marker"
const PROMPT_READY := "[ E ]  ANALYSE SAMPLE RACK"
const PROMPT_COMPLETE := "[ COMPLETE ]  SAMPLE RACK ANALYSED"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MARKER_OFFSET_M := Vector3(0.0, 1.8, 0.0)
const READY_COLOR := Color(0.95, 0.52, 0.18, 1.0)
const COMPLETE_COLOR := Color(0.32, 0.86, 0.78, 1.0)

var _host: Object
var _host_generation := -1
var _attachment_generation := -1
var _activity_generation := -1
var _configured := false
var _attached := false
var _completed := false
var _completion_attachment_generation := -1
var _definition: Dictionary = {}
var _last_receipt: Dictionary = {}
var _marker: Label3D
var _activity_state_source: Callable
var _submission_sink: Callable


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 0
	set_meta("station_interactable", true)
	# GameFlow's Ember reboard gate yields its interaction press only to this
	# existing generic surface-interaction tag.
	set_meta("ember_surface_survey_interaction", true)
	set_meta("interaction_id", INTERACTION_ID)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "SampleRackInteractionShape"
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	shape_node.shape = shape
	add_child(shape_node)
	_marker = Label3D.new()
	_marker.name = "SampleRackAnalysisMarker"
	_marker.position = MARKER_OFFSET_M
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.font_size = 34
	_marker.outline_size = 8
	_marker.modulate = READY_COLOR
	add_child(_marker)
	_apply_presentation()


func configure(
		host: Object,
		definition: Variant,
		activity_state_source: Callable,
		submission_sink: Callable
	) -> Dictionary:
	if _configured or host == null or not is_instance_valid(host) \
			or not host.has_method(&"get_generation") \
			or not host.has_method(&"get_attachment_generation") \
			or not definition is Dictionary \
			or not activity_state_source.is_valid() \
			or not submission_sink.is_valid():
		return _result(false, &"invalid_sample_rack_configuration")
	var record := definition as Dictionary
	var position_value: Variant = record.get("position_body_local_m", Vector3.INF)
	var landmark_ids: Variant = record.get("landmark_ids", PackedStringArray())
	if StringName(record.get("interaction_id", &"")) != INTERACTION_ID \
			or StringName(record.get("checkpoint_id", &"")) != CHECKPOINT_ID \
			or StringName(record.get("world_id", &"")) != &"ember_moon" \
			or StringName(record.get("completion_response_id", &"")) \
				!= COMPLETION_RESPONSE_ID \
			or position_value is not Vector3 \
			or not (position_value as Vector3).is_finite() \
			or landmark_ids is not PackedStringArray \
			or not (landmark_ids as PackedStringArray).has("ember_sample_rack") \
			or bool(record.get("historical_claim", true)):
		return _result(false, &"invalid_sample_rack_configuration")
	_host = host
	_host_generation = int(host.call(&"get_generation"))
	_attachment_generation = int(host.call(&"get_attachment_generation"))
	if not _valid_generation(_host_generation) \
			or not _valid_generation(_attachment_generation):
		return _result(false, &"invalid_sample_rack_generation")
	_definition = record.duplicate(true)
	_activity_state_source = activity_state_source
	_submission_sink = submission_sink
	position = position_value as Vector3
	_configured = true
	_attached = true
	_apply_presentation()
	return _result(true, &"sample_rack_configured")


func activate_for_activity_generation(next_activity_generation: int) -> Dictionary:
	if not _configured or not _attached or not _current_host() \
			or next_activity_generation < 1 \
			or next_activity_generation > MAX_SAFE_GENERATION \
			or next_activity_generation <= _activity_generation \
			or not _authoritative_activity_current(next_activity_generation):
		return _result(false, &"sample_rack_activation_invalid")
	_activity_generation = next_activity_generation
	_completed = false
	_completion_attachment_generation = -1
	_last_receipt.clear()
	_apply_presentation()
	return _result(true, &"sample_rack_activated")


func get_interaction_prompt() -> String:
	if not _current():
		return ""
	return PROMPT_COMPLETE if _completed else PROMPT_READY


func can_interact(actor: Node = null) -> bool:
	return _current() and not _completed and _actor_is_current(actor)


func interact(actor: Node = null) -> bool:
	return bool(submit_interaction(
		actor, _host_generation, _attachment_generation, _activity_generation
	).get("accepted", false))


func submit_interaction(
		actor: Node,
		expected_host_generation: int,
		expected_attachment_generation: int,
		expected_activity_generation: int
	) -> Dictionary:
	if not _current():
		return _result(false, &"sample_rack_unavailable")
	if expected_host_generation != _host_generation \
			or expected_attachment_generation != _attachment_generation \
			or expected_activity_generation != _activity_generation:
		return _result(false, &"stale_sample_rack_generation")
	if not _actor_is_current(actor):
		return _result(false, &"sample_rack_actor_mismatch")
	if _completed:
		return _result(false, &"sample_rack_already_completed")
	var receipt := {
		"checkpoint_id": CHECKPOINT_ID,
		"interaction_id": INTERACTION_ID,
		"world_id": &"ember_moon",
		"landmark_ids": _definition.get(
			"landmark_ids", PackedStringArray()
		).duplicate(),
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"activity_generation": _activity_generation,
		"activity_started": false,
		"reward_granted": false,
		"historical_claim": false,
		"completion_response_id": COMPLETION_RESPONSE_ID,
	}.duplicate(true)
	var admitted := _submission_sink.call(receipt.duplicate(true)) as Dictionary
	if not bool(admitted.get("accepted", false)):
		_apply_presentation()
		return _result(
			false,
			StringName(admitted.get("reason", &"sample_rack_submission_rejected"))
		)
	_completed = true
	_completion_attachment_generation = _attachment_generation
	_last_receipt = receipt
	_apply_presentation()
	sample_rack_completed.emit(_last_receipt.duplicate(true))
	return _result(true, &"sample_rack_completed")


func detach() -> Dictionary:
	if not _configured or not _attached:
		return _result(false, &"sample_rack_not_attached")
	_attached = false
	_apply_presentation()
	return _result(true, &"sample_rack_detached")


func reenter(next_attachment_generation: int) -> Dictionary:
	if not _configured or _attached or not _valid_generation(next_attachment_generation) \
			or next_attachment_generation <= _attachment_generation \
			or int(_host.call(&"get_attachment_generation")) != next_attachment_generation:
		return _result(false, &"stale_sample_rack_generation")
	_attachment_generation = next_attachment_generation
	_attached = true
	_apply_presentation()
	return _result(true, &"sample_rack_reentered")


func get_snapshot() -> Dictionary:
	_apply_presentation()
	return {
		"configured": _configured,
		"attached": _attached,
		"active": _current(),
		"checkpoint_id": CHECKPOINT_ID,
		"interaction_id": INTERACTION_ID,
		"position_body_local_m": position,
		"prompt": get_interaction_prompt(),
		"activity_generation": _activity_generation,
		"completed": _completed,
		"completion_attachment_generation": _completion_attachment_generation,
		"last_receipt": _last_receipt.duplicate(true),
		"physical": {
			"collision_layer": collision_layer,
			"shape": &"sphere",
			"radius_m": 0.65,
			"marker_kind": &"label_3d",
			"marker_visible": _marker.visible if _marker != null else false,
			"marker_text": _marker.text if _marker != null else "",
			"solid_geometry_changed": false,
		},
		"evidence": {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"historical_claim": false,
		},
		"authority": {
			"movement": false, "activity": false, "route": false,
			"reward": false, "save": false, "history": false,
			"hud": false, "solid_geometry": false,
		},
	}.duplicate(true)


func _current_host() -> bool:
	if not _configured or not _attached or _host == null \
			or not is_instance_valid(_host):
		return false
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	return int(_host.call(&"get_generation")) == _host_generation \
		and int(_host.call(&"get_attachment_generation")) \
			== _attachment_generation \
		and bool(host_snapshot.get("attached", false)) \
		and StringName(host_snapshot.get("phase_id", &"")) == &"on_foot"


func _current() -> bool:
	return _current_host() and _activity_generation > 0 \
		and _authoritative_activity_current(_activity_generation)


func _authoritative_activity_current(expected_activity_generation: int) -> bool:
	return _activity_state_source.is_valid() and bool(
		_activity_state_source.call(expected_activity_generation)
	)


func _actor_is_current(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var identities := (
		_host.call(&"get_snapshot") as Dictionary
	).get("identities", {}) as Dictionary
	return actor.get_instance_id() == int(
		identities.get("player_instance_id", 0)
	)


func _apply_presentation() -> void:
	var active := _current()
	collision_layer = INTERACTION_LAYER if active else 0
	if _marker != null:
		_marker.visible = active
		_marker.text = "SAMPLE RACK\nANALYSIS COMPLETE" if _completed \
			else "SAMPLE RACK\nANALYSIS READY"
		_marker.modulate = COMPLETE_COLOR if _completed else READY_COLOR


func _valid_generation(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_GENERATION


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"interaction": get_snapshot(),
	}.duplicate(true)
