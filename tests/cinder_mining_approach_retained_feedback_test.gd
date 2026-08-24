extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const Presenter := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var presenter := Presenter.new()

	var rejected := binding.start_mining_activity(Vector3.ZERO)
	var rejected_snapshot := binding.get_snapshot().mining as Dictionary
	var rejected_card := _mining_card(presenter.present(binding.get_snapshot()))
	var feedback := rejected_card.mining_feedback as Dictionary
	_check(
		not bool(rejected.get("accepted", true))
			and rejected.get("reason", &"") == &"outside_approach_anchor"
			and rejected_snapshot.get("presentation_reason", &"") == &"outside_approach_anchor",
		"the binding retains only the authoritative out-of-range reason",
	)
	_check(
		StringName(rejected_card.get("state_id", &"")) == &"wrong_position"
			and str(rejected_card.get("text", "")).contains(
				"WRONG POSITION  //  EXTRACTION OUT OF RANGE  //  RETURN TO APPROACH MARKER"
			)
			and str(rejected_card.get("objective_text", "")) \
				== "MOVE TO THE CINDER EXTRACTION APPROACH MARKER"
			and StringName(feedback.get("stage_id", &"")) == &"wrong_position"
			and not bool(feedback.get("activity_authority", true))
			and not bool(feedback.get("reward_authority", true)),
		"the presenter gives a color-independent recovery direction without authority",
	)

	var accepted := binding.start_mining_activity(
		CinderMiningPlatformActivity.APPROACH_ANCHOR
	)
	var active_snapshot := binding.get_snapshot().mining as Dictionary
	var active_card := _mining_card(presenter.present(binding.get_snapshot()))
	_check(
		bool(accepted.get("accepted", false))
			and active_snapshot.get("presentation_reason", &"stale") == &""
			and StringName((active_card.mining_feedback as Dictionary).stage_id) == &"extracting"
			and str(active_card.get("text", "")).contains("EXTRACTING ORE"),
		"an accepted authoritative start clears the retained rejection for the new generation",
	)

	cluster.queue_free()
	for _frame in 3:
		await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("CINDER_MINING_APPROACH_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _mining_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) \
				== CinderMiningPlatformActivity.ACTIVITY_ID:
			return card
	return {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
