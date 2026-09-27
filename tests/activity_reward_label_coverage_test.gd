extends SceneTree

## Every reward the production reward authority can grant must have a HUD label.
##
## The HUD rejects a receipt summary whose last label it does not recognise, so a
## reward id added to GameFlowRewardAuthority without a matching entry in
## GameHUD.ACTIVITY_REWARD_LABELS silently blanks the Shipyard receipt summary
## after that reward is filed. Aurora, perimeter defense, hulk power, belt
## threading and two Ember rewards all shipped with that gap.

const AuthorityScript := preload("res://scripts/game/game_flow_reward_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud_labels: Array = GameHUD.ACTIVITY_REWARD_LABELS
	for activity_id: Variant in AuthorityScript.ACTIVITY_REWARDS:
		var reward_id: Variant = AuthorityScript.ACTIVITY_REWARDS[activity_id]
		_check(
			AuthorityScript.REWARD_LABELS.has(reward_id),
			"activity %s grants a reward with an authority label" % str(activity_id)
		)
	for reward_id: Variant in AuthorityScript.REWARD_LABELS:
		var label := str(AuthorityScript.REWARD_LABELS[reward_id])
		_check(
			hud_labels.has(label),
			"the HUD accepts the %s label '%s'" % [str(reward_id), label]
		)
	_check(
		AuthorityScript.ACTIVITY_REWARDS.get(AuthorityScript.TORPEDO_RUN_ACTIVITY_ID)
			== AuthorityScript.TORPEDO_RUN_REWARD_ID
			and AuthorityScript.TORPEDO_RUN_REWARD_ID != AuthorityScript.HEAVY_BREACH_REWARD_ID,
		"Torpedo Run files its own reward id, distinct from Heavy Breach"
	)

	# The live HUD accepts a summary for every grantable label.
	var hud := GameHUD.new()
	hud.name = "RewardLabelCoverageHUD"
	root.add_child(hud)
	await process_frame
	for reward_id: Variant in AuthorityScript.REWARD_LABELS:
		_check(
			hud.set_activity_reward_summary({
				"available": true,
				"total_receipts": 3,
				"last_receipt_id": 3,
				"last_reward_label": str(AuthorityScript.REWARD_LABELS[reward_id]),
			}),
			"the HUD reward summary accepts a %s receipt" % str(reward_id)
		)
	_check(
		not hud.set_activity_reward_summary({
			"available": true,
			"total_receipts": 3,
			"last_receipt_id": 3,
			"last_reward_label": "Unregistered reward",
		}),
		"an unregistered label is still rejected"
	)
	hud.queue_free()
	await process_frame

	for failure in _failures:
		push_error(failure)
	print("ACTIVITY_REWARD_LABEL_COVERAGE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
