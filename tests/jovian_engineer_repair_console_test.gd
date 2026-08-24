extends SceneTree

const ConsoleType := preload("res://scripts/ships/jovian_engineer_repair_console.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var readout := Label3D.new()
	var console = ConsoleType.new()
	_check(bool(console.bind(readout, 0).get("accepted", false)), "console binds its physical readout")
	_check(readout.text == "IDLE // REPAIR READY", "idle is conveyed by text, not colour")

	var repairing := _envelope(0, 1, &"repairing", 0.42, &"engine_array", &"")
	_check(bool(console.present_snapshot(repairing).get("accepted", false)), "repair snapshot is presented")
	_check(
		readout.text == "REPAIRING // ENGINE ARRAY\nPROGRESS // 42%",
		"repairing names the component and numeric progress"
	)
	_check(
		console.present_snapshot(repairing).get("reason", &"") == &"duplicate_sequence",
		"duplicate sequence cannot replay console state"
	)
	_check(
		console.present_snapshot(_envelope(0, 0, &"completed", 1.0, &"engine_array", &"")).get("reason", &"") == &"stale_sequence",
		"out-of-order sequence cannot replace current progress"
	)
	_check(
		console.present_snapshot(_envelope(1, 2, &"completed", 1.0, &"engine_array", &"")).get("reason", &"") == &"stale_generation",
		"foreign generation cannot cross a console lifecycle"
	)

	_check(
		bool(console.present_snapshot(_envelope(0, 2, &"completed", 1.0, &"engine_array", &"")).get("accepted", false))
			and readout.text.contains("COMPLETED // ENGINE ARRAY")
			and readout.text.contains("PROGRESS // 100%"),
		"completion remains an explicit non-colour-only state"
	)
	_check(
		bool(console.present_snapshot(_envelope(0, 3, &"interrupted", 0.58, &"engine_array", &"role_released")).get("accepted", false))
			and readout.text == "ABORTED // ROLE RELEASED\nENGINE ARRAY // 58%",
		"authority interruption is rendered as a concise aborted state"
	)
	_check(bool(console.begin_generation(1).get("accepted", false)), "role cleanup advances presentation generation")
	var cleared: Dictionary = console.get_snapshot()
	_check(
		StringName(cleared.get("state", &"")) == &"idle"
			and int(cleared.get("last_sequence", -2)) == -1
			and readout.text == "IDLE // REPAIR READY",
		"new role generation clears component, progress, and sequence presentation"
	)
	_check(
		console.present_snapshot(_envelope(0, 4, &"completed", 1.0, &"engine_array", &"")).get("reason", &"") == &"stale_generation",
		"released-role snapshots stay fenced after cleanup"
	)
	_check(
		not bool((cleared.get("authority", {}) as Dictionary).get("repair", true))
			and not bool((cleared.get("authority", {}) as Dictionary).get("network", true))
			and bool((cleared.get("authority", {}) as Dictionary).get("presentation", false)),
		"console declares presentation ownership only"
	)

	readout.free()
	for failure in _failures:
		push_error(failure)
	print("JOVIAN_ENGINEER_REPAIR_CONSOLE: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _envelope(
	generation: int,
	sequence: int,
	status: StringName,
	progress: float,
	component_id: StringName,
	reason: StringName
) -> Dictionary:
	return {
		"generation": generation,
		"sequence": sequence,
		"repair_snapshot": {
			"repair": {
				"status": status,
				"reason": reason,
				"component_id": component_id,
				"component_generation": 1,
				"progress": progress,
				"cooldown_remaining": 0.5 if status == &"completed" else 0.0,
			},
			"owner": {
				"seat_id": &"passenger_port_01",
				"occupant_peer_id": 77,
			},
			"presentation_only": true,
		},
	}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
