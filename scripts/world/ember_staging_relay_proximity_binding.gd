class_name EmberStagingRelayProximityBinding
extends Area3D

## Proximity-only diagnostic at the existing Ember staging-relay access marker.
## This Area observes the exact current surface player and owns one runtime-local
## presentation fact. It has no solid, HUD, GameFlow, activity, route, reward,
## history, persistence, save, network, or movement authority.

signal diagnostic_completed(receipt: Dictionary)

const PhysicsLayersScript := preload("res://scripts/core/physics_layers.gd")
const INTERACTION_ID: StringName = &"ember_staging_relay_local_diagnostic"
const LANDMARK_ID: StringName = &"ember_staging_relay"
const ACCESS_MARKER_ID: StringName = &"ember_staging_relay_access"
const READY_TEXT := "STAGING RELAY\nLOCAL DIAGNOSTIC"
const COMPLETE_TEXT := "STAGING RELAY\nCHECK RECORDED"
const READY_COLOR := Color(0.95, 0.52, 0.18, 1.0)
const COMPLETE_COLOR := Color(0.32, 0.86, 0.78, 1.0)
const PROXIMITY_RADIUS_M := 0.85
const PROXIMITY_CENTER_M := Vector3(0.0, 0.9, 0.0)
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _host: Object
var _actor: Node3D
var _host_generation := -1
var _attachment_generation := -1
var _production_generation := -1
var _loaded_scene_instance_id := 0
var _configured := false
var _attached := false
var _completed := false
var _completion_attachment_generation := -1
var _last_receipt: Dictionary = {}
var _marker: Label3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	collision_layer = PhysicsLayersScript.PLAYER_BODY_LAYER
	collision_mask = PhysicsLayersScript.NONE
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "StagingRelayProximityShape"
	shape_node.position = PROXIMITY_CENTER_M
	var shape := SphereShape3D.new()
	shape.radius = PROXIMITY_RADIUS_M
	shape_node.shape = shape
	add_child(shape_node)
	_marker = Label3D.new()
	_marker.name = "StagingRelayDiagnosticMarker"
	_marker.position = Vector3(0.0, 1.35, 0.0)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.font_size = 30
	_marker.outline_size = 8
	add_child(_marker)
	_apply_presentation()


func configure(
		host: Object,
		actor: Node3D,
		expected_host_generation: int,
		expected_production_generation: int,
		expected_loaded_scene_instance_id: int
	) -> Dictionary:
	if _configured or host == null or not is_instance_valid(host) \
			or actor == null or not is_instance_valid(actor) \
			or not host.has_method(&"get_generation") \
			or not host.has_method(&"get_attachment_generation") \
			or not host.has_method(&"get_snapshot") \
			or not _valid_generation(expected_host_generation) \
			or expected_production_generation < 1 \
			or expected_production_generation > MAX_SAFE_GENERATION \
			or expected_loaded_scene_instance_id < 1:
		return _result(false, &"invalid_staging_relay_configuration")
	var host_snapshot := host.call(&"get_snapshot") as Dictionary
	var identities := host_snapshot.get("identities", {}) as Dictionary
	var attachment_generation := int(host.call(&"get_attachment_generation"))
	if int(host.call(&"get_generation")) != expected_host_generation \
			or not _valid_generation(attachment_generation) \
			or int(identities.get("player_instance_id", 0)) \
				!= actor.get_instance_id() \
			or int(identities.get("loaded_scene_instance_id", 0)) \
				!= expected_loaded_scene_instance_id:
		return _result(false, &"stale_staging_relay_configuration")
	_host = host
	_actor = actor
	_host_generation = expected_host_generation
	_attachment_generation = attachment_generation
	_production_generation = expected_production_generation
	_loaded_scene_instance_id = expected_loaded_scene_instance_id
	_configured = true
	_attached = true
	_apply_presentation()
	return _result(true, &"staging_relay_configured")


func refresh_authoritative_state() -> Dictionary:
	if not _configured:
		return _result(false, &"staging_relay_not_configured")
	_apply_presentation()
	return _result(true, &"staging_relay_refreshed")


func submit_proximity(
		actor: Node3D,
		expected_host_generation: int,
		expected_attachment_generation: int,
		expected_production_generation: int
	) -> Dictionary:
	if not _current():
		return _result(false, &"staging_relay_unavailable")
	if expected_host_generation != _host_generation \
			or expected_attachment_generation != _attachment_generation \
			or expected_production_generation != _production_generation:
		return _result(false, &"stale_staging_relay_generation")
	if actor == null or not is_instance_valid(actor) or actor != _actor:
		return _result(false, &"staging_relay_actor_mismatch")
	if _completed:
		return _result(false, &"staging_relay_already_completed")
	_completed = true
	_completion_attachment_generation = _attachment_generation
	_last_receipt = {
		"interaction_id": INTERACTION_ID,
		"landmark_id": LANDMARK_ID,
		"access_marker_id": ACCESS_MARKER_ID,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"production_generation": _production_generation,
		"loaded_scene_instance_id": _loaded_scene_instance_id,
		"actor_instance_id": _actor.get_instance_id(),
		"historical_claim": false,
		"activity_started": false,
		"route_advanced": false,
		"reward_granted": false,
	}.duplicate(true)
	_apply_presentation()
	diagnostic_completed.emit(_last_receipt.duplicate(true))
	return _result(true, &"staging_relay_diagnostic_completed")


func detach() -> Dictionary:
	if not _configured or not _attached:
		return _result(false, &"staging_relay_not_attached")
	_attached = false
	_apply_presentation()
	return _result(true, &"staging_relay_detached")


func reenter(next_attachment_generation: int) -> Dictionary:
	if not _configured or _attached \
			or not _valid_generation(next_attachment_generation) \
			or next_attachment_generation <= _attachment_generation \
			or int(_host.call(&"get_attachment_generation")) \
				!= next_attachment_generation:
		return _result(false, &"stale_staging_relay_generation")
	_attachment_generation = next_attachment_generation
	_attached = true
	_apply_presentation()
	return _result(true, &"staging_relay_reentered")


func get_snapshot() -> Dictionary:
	_apply_presentation()
	return {
		"configured": _configured,
		"attached": _attached,
		"active": _current(),
		"completed": _completed,
		"interaction_id": INTERACTION_ID,
		"landmark_id": LANDMARK_ID,
		"access_marker_id": ACCESS_MARKER_ID,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"production_generation": _production_generation,
		"loaded_scene_instance_id": _loaded_scene_instance_id,
		"completion_attachment_generation": _completion_attachment_generation,
		"last_receipt": _last_receipt.duplicate(true),
		"physical": {
			"area_collision_layer": collision_layer,
			"area_collision_mask": collision_mask,
			"monitoring": monitoring,
			"monitorable": monitorable,
			"shape": &"sphere",
			"radius_m": PROXIMITY_RADIUS_M,
			"center_local_m": PROXIMITY_CENTER_M,
			"solid_geometry_added": false,
			"marker_kind": &"label_3d",
			"marker_visible": _marker.visible if _marker != null else false,
			"marker_text": _marker.text if _marker != null else "",
		},
		"evidence": {
			"content_class": &"NEW",
			"status": &"modern_interpretation",
			"historical_claim": false,
		},
		"authority": {
			"hud": false, "game_flow": false, "activity": false,
			"route": false, "reward": false, "history": false,
			"save": false, "network": false, "movement": false,
			"solid_geometry": false,
		},
	}.duplicate(true)


func _on_body_entered(body: Node3D) -> void:
	if body == _actor:
		call_deferred(
			&"submit_proximity",
			body, _host_generation, _attachment_generation,
			_production_generation
		)


func _current() -> bool:
	if not _configured or not _attached or _host == null \
			or not is_instance_valid(_host) or _actor == null \
			or not is_instance_valid(_actor):
		return false
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	var identities := host_snapshot.get("identities", {}) as Dictionary
	return bool(host_snapshot.get("attached", false)) \
		and StringName(host_snapshot.get("phase_id", &"")) == &"on_foot" \
		and int(_host.call(&"get_generation")) == _host_generation \
		and int(_host.call(&"get_attachment_generation")) \
			== _attachment_generation \
		and int(identities.get("player_instance_id", 0)) \
			== _actor.get_instance_id() \
		and int(identities.get("loaded_scene_instance_id", 0)) \
			== _loaded_scene_instance_id


func _apply_presentation() -> void:
	var current := _current()
	collision_layer = PhysicsLayersScript.PLAYER_BODY_LAYER if current \
		else PhysicsLayersScript.NONE
	collision_mask = PhysicsLayersScript.PLAYER_BODY_LAYER if current \
		else PhysicsLayersScript.NONE
	monitoring = current
	monitorable = false
	if _marker != null:
		_marker.visible = current
		_marker.text = COMPLETE_TEXT if _completed else READY_TEXT
		_marker.modulate = COMPLETE_COLOR if _completed else READY_COLOR


func _valid_generation(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_GENERATION


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"diagnostic": get_snapshot(),
	}.duplicate(true)
