class_name StationDefenseActivityBoard
extends Area3D

## Physical station-side request adapter for the production defense encounter.
## StationDefenseEncounterContent/Host remains the activity authority and the
## injected LiveCombatAuthority remains the only combat resolver.

signal interaction_resolved(actor: Node, result: Dictionary)

const COMPONENT_ID: StringName = &"station-defense-activity-board"
const ACTIVITY_ID: StringName = &"shipyard_perimeter_defense"
const REWARD_ADAPTER := preload("res://scripts/world/nearby_activity_reward_adapter.gd")
const SESSION_ADAPTER := preload("res://scripts/persistence/station_defense_session_adapter.gd")
const PERSISTENCE_BINDING := preload(
	"res://scripts/persistence/nearby_sector_activity_persistence_binding.gd"
)
const INTERACTION_RADIUS := 2.6
const BOARD_SIZE := Vector3(0.75, 1.35, 1.8)
const PEDESTAL_SIZE := Vector3(1.4, 1.0, 2.2)
const CONSOLE_OFFSET := Vector3(1.25, 0.0, 0.0)
const STATUS_COLOR_READY := Color("8ef4f2")
const STATUS_COLOR_ACTIVE := Color("ffd27a")
const STATUS_COLOR_SECURE := Color("92efb1")
const STATUS_COLOR_RECOVERY := Color("ff9b86")

var _content: StationDefenseEncounterContent
var _combat_authority: LiveCombatAuthority
var _activity_director: ActivityDirector
var _built := false
var _last_result: Dictionary = {}
var _reward_adapter: RefCounted
var _last_reward_result: Dictionary = {}
var _highest_reward_generation := 0
var _reward_replay_generation_floor := 0
var _terminal_history: Dictionary = {}
var _session_adapter: RefCounted
var _persistence_binding: RefCounted
var _restored_session: Dictionary = {}
var _presentation_generation := -1
var _presentation_state_id: StringName = &"unavailable"
var _presentation_text := "AWAITING LINK"


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
	if not _content.snapshot_changed.is_connected(_on_content_snapshot_changed):
		_content.snapshot_changed.connect(_on_content_snapshot_changed)
	var content_snapshot := _content.get_snapshot()
	_refresh_presentation(content_snapshot)
	_capture_safe_history(content_snapshot)
	return _result(true, &"configured")


## Configures the shared nearby-activity handoff. The callback remains the
## reward owner; this board only forwards a completed detached activity snapshot.
func configure_reward_handoff(callback: Callable) -> Dictionary:
	if _reward_adapter != null:
		return _result(false, &"reward_handoff_already_configured")
	var adapter := REWARD_ADAPTER.new() as RefCounted
	var configured: Dictionary = adapter.call(
		"configure", callback, ACTIVITY_ID, &"return_defense_report_to_shipyard"
	)
	if not bool(configured.get("accepted", false)):
		return configured
	_reward_adapter = adapter
	return _result(true, &"reward_handoff_configured")


func configure_session_persistence(store: RefCounted, slot_id: StringName) -> bool:
	if _persistence_binding != null or store == null or slot_id.is_empty():
		return false
	_session_adapter = SESSION_ADAPTER.new() as RefCounted
	_persistence_binding = PERSISTENCE_BINDING.new() as RefCounted
	if not bool(_persistence_binding.call(
		"configure", store, _session_adapter, slot_id
	)):
		_session_adapter = null
		_persistence_binding = null
		return false
	return true


func save_session(expected_store_generation: int, commit_id: String) -> Dictionary:
	if _persistence_binding == null:
		return _result(false, &"persistence_not_configured")
	return _persistence_binding.call(
		"save", get_session_persistence_snapshot(), expected_store_generation, commit_id
	)


func load_session() -> Dictionary:
	if _persistence_binding == null or not is_instance_valid(_content):
		return _result(false, &"persistence_not_configured")
	var loaded: Dictionary = _persistence_binding.call("load")
	if not bool(loaded.get("accepted", false)):
		return loaded
	var session := loaded.get("session", {}) as Dictionary
	var history := session.get("history", {}) as Dictionary
	var restored := _content.restore_terminal_session_history(history)
	if not bool(restored.get("accepted", false)):
		return restored
	_terminal_history = history.duplicate(true)
	_highest_reward_generation = maxi(
		_highest_reward_generation,
		int(history.get("reward_handoff_generation", 0))
	)
	_reward_replay_generation_floor = maxi(
		_reward_replay_generation_floor,
		int(history.get("generation", 0))
	)
	_restored_session = {
		"history": history.duplicate(true),
		"runtime_state": &"idle",
		"reward_replayable": false,
	}.duplicate(true)
	return {
		"accepted": true,
		"reason": &"terminal_history_loaded_idle",
		"history": history.duplicate(true),
		"content": restored.duplicate(true),
	}.duplicate(true)


func get_session_persistence_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"history": _terminal_history.duplicate(true),
		"restored_session": _restored_session.duplicate(true),
		"store_authority": false,
		"active_runtime_state_persisted": false,
		"combat_sources_persisted": false,
		"asset_damage_persisted": false,
		"leases_persisted": false,
		"reward_replayable": false,
	}.duplicate(true)


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


## Physical recovery seam. Active encounters abort before reset; terminal
## encounters reset directly. The content remains the sole lifecycle owner.
func abort_and_reset(actor: Node, expected_generation: int) -> Dictionary:
	var gate := get_interaction_snapshot(actor, expected_generation)
	if not bool(gate.get("available", false)):
		_last_result = gate.duplicate(true)
		return _last_result.duplicate(true)
	var activity := (_content.get_snapshot().get("host", {}) as Dictionary).get(
		"activity", {}
	) as Dictionary
	var state_id := StringName(activity.get("state_id", &""))
	var aborted: Dictionary = {}
	if state_id == &"active":
		aborted = _content.abort(expected_generation)
		if not bool(aborted.get("accepted", false)):
			_last_result = aborted.duplicate(true)
			return _last_result.duplicate(true)
	var reset_result := _content.reset(expected_generation)
	_last_result = {
		"accepted": bool(reset_result.get("accepted", false)),
		"reason": reset_result.get("reason", &"reset_rejected"),
		"aborted": aborted.duplicate(true),
		"reset": reset_result.duplicate(true),
	}.duplicate(true)
	return _last_result.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func get_reward_handoff_snapshot() -> Dictionary:
	return {
		"configured": _reward_adapter != null,
		"highest_reward_generation": _highest_reward_generation,
		"replay_generation_floor": _reward_replay_generation_floor,
		"last_result": _last_reward_result.duplicate(true),
		"adapter": (
			_reward_adapter.call("get_snapshot")
			if _reward_adapter != null else {}
		),
		"reward_authority": false,
	}.duplicate(true)


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
		"reward_handoff": get_reward_handoff_snapshot(),
		"session_persistence": get_session_persistence_snapshot(),
		"combat_authority": false,
		"activity_authority": false,
		"health_authority": false,
		"reward_authority": false,
		"ship_motion_authority": false,
		"process_loops": int(is_processing()) + int(is_physics_processing()),
		"presentation": get_presentation_snapshot(),
	}.duplicate(true)


func get_presentation_snapshot() -> Dictionary:
	return {
		"generation": _presentation_generation,
		"state_id": _presentation_state_id,
		"text": _presentation_text,
		"snapshot_driven": true,
		"steady": true,
	}.duplicate(true)


func _on_content_snapshot_changed(snapshot: Dictionary) -> void:
	var host := snapshot.get("host", {}) as Dictionary
	var activity := (host.get("activity", {}) as Dictionary).duplicate(true)
	var generation := int(activity.get("generation", 0))
	if generation < _presentation_generation:
		return
	_refresh_presentation(snapshot)
	if (
		_reward_adapter != null
		and StringName(activity.get("state_id", &"")) == &"completed"
		and generation > maxi(
			_highest_reward_generation, _reward_replay_generation_floor
		)
	):
		activity["activity_id"] = ACTIVITY_ID
		# StationDefenseActivity publishes a terminal state rather than duplicating
		# EncounterScenarioDirector's outcome field. Completion is its exact cleared
		# terminal, so the adapter receives the canonical shared handoff vocabulary.
		activity["outcome"] = &"cleared"
		_last_reward_result = _reward_adapter.call("consume", activity, generation)
		if bool(_last_reward_result.get("accepted", false)):
			_highest_reward_generation = generation
	_capture_safe_history(snapshot)


func _refresh_presentation(snapshot: Dictionary) -> void:
	var host := snapshot.get("host", {}) as Dictionary
	var activity := host.get("activity", {}) as Dictionary
	if activity.is_empty():
		return
	var generation := int(activity.get("generation", -1))
	if generation < _presentation_generation:
		return
	var state_id := StringName(activity.get("state_id", &"idle"))
	var status_text := "READY\nINTERACT TO DEPLOY"
	var status_color := STATUS_COLOR_READY
	match state_id:
		&"active":
			var wave_number := maxi(0, int(activity.get("wave_number", 0)))
			var wave_count := maxi(wave_number, int(activity.get("wave_count", 0)))
			var remaining := maxi(0, int(activity.get("remaining_hostile_count", 0)))
			status_text = "WAVE %d / %d\nTHREATS %d" % [wave_number, wave_count, remaining]
			status_color = STATUS_COLOR_ACTIVE
		&"completed":
			status_text = "PERIMETER SECURE\nRECOVERY AVAILABLE"
			status_color = STATUS_COLOR_SECURE
		&"failed", &"aborted", &"timed_out":
			status_text = "DEFENSE OFFLINE\nRECOVERY REQUIRED"
			status_color = STATUS_COLOR_RECOVERY
		&"idle":
			pass
		_:
			status_text = "STATUS UNAVAILABLE"
			status_color = STATUS_COLOR_RECOVERY
	_presentation_generation = generation
	_presentation_state_id = state_id
	_presentation_text = status_text
	var status_label := get_node_or_null(^"StatusLabel") as Label3D
	if status_label != null:
		status_label.text = status_text
		status_label.modulate = status_color


func _capture_safe_history(snapshot: Dictionary) -> void:
	var activity := (
		(snapshot.get("host", {}) as Dictionary).get("activity", {}) as Dictionary
	)
	var state_id := StringName(activity.get("state_id", &""))
	if state_id not in [&"idle", &"completed", &"failed"]:
		return
	_terminal_history = {
		"activity_id": ACTIVITY_ID,
		"state_id": state_id,
		"generation": int(activity.get("generation", 0)),
		"failure_reason": (
			StringName(activity.get("failure_reason", &""))
			if state_id == &"failed" else &""
		),
		"reward_handoff_generation": _highest_reward_generation,
		"reward_replayable": false,
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
	label.text = "STATION DEFENSE"
	label.font_size = 20
	label.modulate = Color("8ef4f2")
	label.position = CONSOLE_OFFSET + Vector3(0.0, 1.04, 0.94)
	label.pixel_size = 0.0048
	label.outline_size = 5
	add_child(label)
	var status_label := Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = _presentation_text
	status_label.font_size = 17
	status_label.modulate = STATUS_COLOR_READY
	status_label.position = CONSOLE_OFFSET + Vector3(0.0, 0.47, 0.94)
	status_label.pixel_size = 0.0048
	status_label.outline_size = 5
	add_child(status_label)
	var interaction_shape := CollisionShape3D.new()
	interaction_shape.name = "InteractionCollision"
	var interaction_box := BoxShape3D.new()
	interaction_box.size = Vector3(2.4, 2.2, 1.8)
	interaction_shape.shape = interaction_box
	interaction_shape.position = CONSOLE_OFFSET + Vector3(0.0, 0.25, 0.45)
	add_child(interaction_shape)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "snapshot": get_snapshot()}
