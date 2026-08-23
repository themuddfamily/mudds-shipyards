extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")

var _assertions := 0
var _failures: Array[String] = []
var _reward_requests: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding

	var view := hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var row := _patrol_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(
		_patrol_text(row).contains("AVAILABLE  //  PATROL READY  //  APPROACH BEACON 1/5")
		and str(_patrol_card(view).get("objective_text", "")) == "START THE CINDER RELAY PATROL",
		"the real idle patrol snapshot appears as an approach objective",
	)

	binding.start_patrol()
	binding.advance_patrol(0.5, Vector3.ZERO)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	row = _patrol_row(hud)
	_check(
		row != null and row.get_instance_id() == retained_id
		and _patrol_text(row).contains("APPROACH BEACON 1/5  //  0/5 SECURED  //  0.5s"),
		"travel progress updates the same retained patrol row",
	)

	var first_point: Vector3 = ROUTE.get_checkpoint_position(0)
	binding.advance_patrol(0.75, first_point)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		_patrol_text(_patrol_row(hud)).contains("HOLD BEACON 1/5  //  0.8/2.0s  //  1.2s LEFT")
		and StringName((_patrol_card(view).patrol_feedback as Dictionary).stage_id) == &"dwell",
		"station keeping shows authoritative dwell progress and time remaining",
	)

	var outside := first_point + Vector3(ROUTE.checkpoint_radius + 1.0, 0.0, 0.0)
	var interrupted := binding.advance_patrol(0.25, outside)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		interrupted.get("reason", &"") == &"dwell_interrupted"
		and _patrol_text(_patrol_row(hud)).contains("HOLD INTERRUPTED  //  RE-ENTER BEACON 1/5")
		and str(_patrol_card(view).get("objective_text", "")).contains("RESTART THE HOLD"),
		"the real dwell interruption becomes an actionable recovery cue",
	)

	var final := binding.advance_patrol(
		NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS, first_point
	)
	for checkpoint_index in range(1, ROUTE.get_checkpoint_count()):
		final = binding.advance_patrol(
			NearbySectorActivityBinding.CINDER_PATROL_DWELL_SECONDS,
			ROUTE.get_checkpoint_position(checkpoint_index),
		)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		final.get("state_id", &"") == &"completed"
		and _patrol_text(_patrol_row(hud)).contains("PATROL COMPLETE  //  PATROL LOG READY")
		and StringName((_patrol_card(view).patrol_feedback as Dictionary).stage_id) == &"complete",
		"completion distinguishes a ready patrol log before reward handoff",
	)

	var configured := binding.configure_station_defense_reward(
		Callable(self, &"_accept_reward_request")
	)
	var patrol_generation := int((binding.get_snapshot().patrol as Dictionary).generation)
	var requested := binding.request_patrol_reward(patrol_generation)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var pending_text := _patrol_text(_patrol_row(hud))
	var feedback := _patrol_card(view).get("patrol_feedback", {}) as Dictionary
	_check(
		bool(configured.get("accepted", false)) and bool(requested.get("accepted", false))
		and _reward_requests.size() == 1 and not bool(_reward_requests[0].get("granted", true))
		and pending_text.contains("PATROL COMPLETE  //  REWARD PENDING")
		and pending_text.count("REWARD PENDING") == 1
		and bool(feedback.get("reward_pending", false))
		and not bool(feedback.get("patrol_authority", true))
		and not bool(feedback.get("reward_authority", true)),
		"the existing reward adapter request becomes pending without granting authority",
	)

	hud.queue_free()
	cluster.queue_free()
	for _frame in 4:
		await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_PATROL_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _accept_reward_request(request: Dictionary) -> Dictionary:
	_reward_requests.append(request.duplicate(true))
	return {"accepted": true, "reason": &"queued_for_grant"}


func _patrol_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_relay_patrol":
			return card
	return {}


func _patrol_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_relay_patrol" in str(candidate.name):
			return candidate as Control
	return null


func _patrol_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
