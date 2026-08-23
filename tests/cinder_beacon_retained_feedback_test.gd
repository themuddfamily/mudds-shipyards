extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const BeaconActivity := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")

var _assertions := 0
var _failures: Array[String] = []


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
	var row := _beacon_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(
		_beacon_text(row).contains("AVAILABLE  //  RUN READY  //  START AT BEACON 1/4")
		and str(_beacon_card(view).get("objective_text", "")) == "ENTER THE FIRST DEBRIS BEACON",
		"the real idle traversal snapshot directs the player to beacon one",
	)

	binding.start_beacon_traversal(BeaconActivity.BEACONS[0])
	binding.submit_beacon_traversal(0, BeaconActivity.BEACONS[0])
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	row = _beacon_row(hud)
	_check(
		row != null and row.get_instance_id() == retained_id
		and _beacon_text(row).contains("NEXT BEACON 2/4  //  1/4 CLEARED")
		and int((_beacon_card(view).beacon_feedback as Dictionary).expected_beacon_number) == 2,
		"ordered progress updates the same retained row with next and total beacons",
	)

	var wrong_order := binding.submit_beacon_traversal(2, BeaconActivity.BEACONS[2])
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		wrong_order.get("reason", &"") == &"out_of_order_beacon"
		and _beacon_text(_beacon_row(hud)).contains("WRONG ORDER  //  EXPECTED BEACON 2/4  //  1/4 CLEARED")
		and str(_beacon_card(view).get("objective_text", "")) == "RETURN TO EXPECTED BEACON 2",
		"the retained authoritative rejection names the expected recovery beacon",
	)

	var final: Dictionary = {}
	for index in range(1, BeaconActivity.BEACONS.size()):
		final = binding.submit_beacon_traversal(index, BeaconActivity.BEACONS[index])
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		bool(final.get("accepted", false)) and int(final.get("state", -1)) == BeaconActivity.State.COMPLETE
		and _beacon_text(_beacon_row(hud)).contains("COMPLETED  //  ROUTE COMPLETE  //  NAVIGATION DATA READY")
		and StringName((_beacon_card(view).beacon_feedback as Dictionary).stage_id) == &"complete",
		"completion distinguishes ready navigation data before reward request",
	)

	var reward := binding.request_beacon_traversal_reward()
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var pending_text := _beacon_text(_beacon_row(hud))
	var feedback := _beacon_card(view).get("beacon_feedback", {}) as Dictionary
	_check(
		bool(reward.get("accepted", false))
		and not bool((reward.get("reward_request", {}) as Dictionary).get("granted", true))
		and pending_text.contains("ROUTE COMPLETE  //  REWARD PENDING")
		and pending_text.count("REWARD PENDING") == 1
		and bool(feedback.get("reward_pending", false))
		and not bool(feedback.get("activity_authority", true))
		and not bool(feedback.get("reward_authority", true)),
		"the matching-generation non-granting request becomes reward pending",
	)

	binding.reset_beacon_traversal()
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(
		_beacon_text(_beacon_row(hud)).contains("AVAILABLE  //  TRAVERSAL RESET  //  START AGAIN AT BEACON 1/4")
		and str(_beacon_card(view).get("objective_text", "")) == "RETURN TO THE FIRST DEBRIS BEACON",
		"reset clears pending state and provides restart guidance",
	)

	hud.queue_free()
	cluster.queue_free()
	for _frame in 4:
		await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_BEACON_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _beacon_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_debris_beacon_traversal":
			return card
	return {}


func _beacon_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_debris_beacon_traversal" in str(candidate.name):
			return candidate as Control
	return null


func _beacon_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
