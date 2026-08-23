extends SceneTree

const Presenter := preload("res://scripts/ui/crew_role_seat_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var snapshot := presenter.present_snapshot({
		"actor_id": "pilot-7",
		"roles": {
			&"pilot": {"seat_id": &"cockpit", "occupant": "pilot-7", "available": false},
			&"gunner": {"seat_id": &"turret", "occupant": "", "available": true},
			&"engineer": {"seat_id": &"systems", "occupant": "engineer-2", "available": false},
			&"passenger": {"seat_id": &"cabin-01", "available": true},
		},
	})
	_check(snapshot.rows.size() == 4 and snapshot.rows[0].status == "pilot-7" and snapshot.rows[1].status == "Available", "role rows expose deterministic occupancy and availability")
	_check(snapshot.actions.size() == 3 and snapshot.actions[0].focusable and snapshot.actions[2].focusable, "claim release and transfer actions are controller-focusable")
	_check(presenter.request_claim(&"gunner").accepted and presenter.request_release(&"pilot").accepted, "claim and release return external role intents")
	var transfer := presenter.request_transfer(&"pilot", &"gunner")
	_check(transfer.accepted and transfer.from_role == &"pilot" and transfer.to_role == &"gunner", "transfer intent preserves both role identities")
	_check(not presenter.request_claim(&"captain").accepted, "unknown role fails closed without authority")
	var detached := presenter.get_snapshot()
	(detached.rows[0] as Dictionary)["status"] = "forged"
	_check(presenter.get_snapshot().rows[0].status == "pilot-7", "role presentation snapshot is detached")
	if _failures.is_empty():
		print("CREW_ROLE_SEAT_PRESENTER_TEST_OK: 6 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
