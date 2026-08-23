extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

class SnapshotSource:
	extends Node
	var snapshot: Dictionary = {}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	var source := SnapshotSource.new()
	root.add_child(source)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	source.snapshot = _content_snapshot(&"active", 4, 2, 3, 5, 1, 0, &"")
	var bound := binding.bind_station_defense_snapshot_provider(Callable(source, &"get_snapshot"))
	var view := hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var row := _defense_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(bool(bound.get("accepted", false)) and _row_text(row).contains(
		"WAVE 2/3  //  5 HOSTILES REMAIN  //  ASSETS 2/2 INTACT  //  1 DAMAGED"
	), "binding exposes authoritative wave, threat, and protected-asset state")

	source.snapshot = _content_snapshot(&"failed", 4, 2, 3, 5, 0, 1, &"protected_asset_destroyed")
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	row = _defense_row(hud)
	_check(row != null and row.get_instance_id() == retained_id
		and _row_text(row).contains("DEFENSE FAILED  //  PROTECTED ASSET DESTROYED")
		and str(_defense_card(view).objective_text) == "RESET AT THE DEFENSE BOARD TO TRY AGAIN",
		"failure updates the retained row with recovery and asset loss")

	var configured := binding.configure_station_defense_reward(Callable(self, &"_accept_reward"))
	var adapter := binding.get("_station_reward_adapter") as RefCounted
	var requested: Dictionary = adapter.call("consume", {
		"activity_id": &"shipyard_perimeter_defense", "state_id": &"completed",
		"outcome": &"cleared", "generation": 4,
	}, 4)
	source.snapshot = _content_snapshot(&"completed", 5, 3, 3, 0, 0, 0, &"")
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(bool(configured.get("accepted", false)) and bool(requested.get("accepted", false))
		and _row_text(_defense_row(hud)).contains("REPORT READY")
		and not bool(_defense_card(view).reward_pending),
		"a stale reward generation is not presented as pending")

	source.snapshot = _content_snapshot(&"completed", 4, 3, 3, 0, 0, 0, &"")
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var text := _row_text(_defense_row(hud))
	var feedback := _defense_card(view).station_defense_feedback as Dictionary
	_check(text.contains("DEFENSE COMPLETE  //  ASSETS 2/2 SECURE  //  REWARD PENDING")
		and text.count("REWARD PENDING") == 1 and bool(feedback.reward_pending)
		and not bool(feedback.activity_authority) and not bool(feedback.combat_authority)
		and not bool(feedback.health_authority) and not bool(feedback.reward_authority),
		"matching completion generation presents one pending reward cue without authority")

	hud.queue_free(); cluster.queue_free(); source.queue_free()
	for _frame in 4: await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty(): print("STATION_DEFENSE_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _content_snapshot(state_id: StringName, generation: int, wave: int, wave_count: int,
		hostiles: int, damaged: int, lost: int, failure: StringName) -> Dictionary:
	var assets: Array[Dictionary] = []
	for index in 2:
		assets.append({"handle": {"asset_id": StringName("asset_%d" % index)},
			"damage_event_count": damaged if index == 0 else 0,
			"destroyed": lost > 0 and index == 1})
	return {"host": {"activity": {"activity_id": &"shipyard_perimeter_defense",
		"state_id": state_id, "generation": generation, "wave_number": wave,
		"wave_count": wave_count, "remaining_hostile_count": hostiles,
		"protected_assets": assets, "failure_reason": failure}}}

func _accept_reward(_request: Dictionary) -> Dictionary: return {"accepted": true}

func _defense_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"station_defense": return card
	return {}

func _defense_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "station_defense" in str(candidate.name): return candidate as Control
	return null

func _row_text(row: Control) -> String: return str((row.get_child(0) as Label).text) if row != null else ""

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
