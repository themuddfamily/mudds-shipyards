extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_landing_return_contract.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_configuration_valid(), "default landing/return declaration validates")
	_check(
		(contract.get_snapshot().authority as Dictionary).movement == false
			and (contract.get_snapshot().authority as Dictionary).game_flow == false,
		"contract owns neither movement nor GameFlow authority",
	)
	_check(
		contract.begin(1, 1, 1, 1).accepted
			and contract.get_phase_id() == &"orbit_approach",
		"begin fences a fresh run at orbital approach",
	)
	_check(
		contract.confirm_orbit_approach(
			true, _observation(), 9, 1
		).reason == &"stale_generation",
		"stale run generations cannot advance the loop",
	)
	_check(
		contract.confirm_orbit_approach(
			true, _observation(), 1, 1
		).accepted and contract.get_phase_id() == &"surface_flight",
		"orbital handoff enters surface flight",
	)
	_check(
		contract.commit_origin_rebase(2, 2, {
			"accepted": true, "source_generation": 1, "target_generation": 2,
		}).accepted,
		"an atomic origin receipt advances both live generation fences",
	)
	_check(
		contract.get_snapshot().coordinate_frame_generation == 2
			and contract.get_snapshot().origin_rebase_count == 1,
		"origin rebase is recorded without claiming a transform write",
	)
	_check(
		contract.confirm_landing(
			true, &"wrong_region",
			{"world_id": &"ember_moon", "region_id": &"wrong_region", "landing_confirmed": true},
			true, 1, 1
		).reason == &"landing_prerequisites_not_met",
		"landing region identity is strict",
	)
	_check(
		contract.confirm_landing(
			true, &"ember_caldera",
			{"world_id": &"ember_moon", "region_id": &"ember_caldera", "landing_confirmed": true},
			true, 1, 1
		).accepted and contract.get_phase_id() == &"landed",
		"supported landing commits LANDED",
	)
	_check(
		contract.confirm_on_foot(
			&"pad_alpha_egress", &"missing_activity", true, 1, 1
		).reason == &"surface_activity_prerequisites_not_met",
		"unknown activities cannot satisfy the surface visit",
	)
	_check(
		contract.confirm_on_foot(
			&"pad_alpha_egress", &"caldera_relay_scan", true, 1, 1
		).accepted and contract.get_phase_id() == &"on_foot",
		"authored egress and activity commit ON_FOOT",
	)
	_check(
		contract.confirm_reboarded(false, true, 1, 1).reason
			== &"reboard_prerequisites_not_met",
		"reboarding requires the player to be seated while the ship remains landed",
	)
	_check(
		contract.confirm_reboarded(true, true, 1, 1).accepted
			and contract.get_phase_id() == &"reboarded",
		"reboarding commits REBOARDED",
	)
	_check(
		contract.confirm_takeoff(true, false, 1, 1).accepted
			and contract.get_phase_id() == &"takeoff",
		"physical takeoff commits TAKEOFF",
	)
	_check(
		contract.confirm_orbit_return(
			true, &"wrong_station", _observation(), 1, 1
		).reason == &"orbit_return_prerequisites_not_met",
		"return cannot complete against an unknown station target",
	)
	_check(
		contract.confirm_orbit_return(
			true, &"mudds_shipyards", _observation(), 1, 1
		).accepted and contract.get_phase_id() == &"completed",
		"orbit return to the authored station target completes the loop",
	)
	_check(
		contract.confirm_orbit_return(
			true, &"mudds_shipyards", _observation(), 1, 1
		).reason == &"terminal_state",
		"completion is emitted once and terminal state is replay-safe",
	)
	var invalid := ContractScript.new(
		&"Bad World", &"ember_caldera", &"mudds_shipyards",
		PackedStringArray(["pad_alpha_egress"]), PackedStringArray(["activity"]),
	)
	_check(not invalid.is_configuration_valid(), "unstable world IDs fail closed")
	_finish()


func _observation() -> Dictionary:
	return {"position": Vector3.ZERO, "speed_meters_per_second": 0.0}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_landing_return_contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
