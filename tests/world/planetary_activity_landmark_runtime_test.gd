extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_activity_landmark_cluster_contract.gd")
const RuntimeScript := preload("res://scripts/world/planetary_activity_landmark_runtime.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime := RuntimeScript.new()
	_check(runtime.configure(ContractScript.new()).accepted, "authored landmark cluster configures runtime")
	var discoveries := runtime.discover(Vector3(18.0, 0.0, 0.0), 100.0)
	_check(
		discoveries.accepted and discoveries.discoveries.size() > 0
			and discoveries.discoveries[0].landmark_id == &"ember_caldera_pad"
			and discoveries.discoveries[0].discovery_receipt,
		"nearby query returns stable authored landmark discovery receipts"
	)
	_check(
		runtime.begin_activity_sequence([
			&"ember_beacon_survey", &"ember_kit_cargo_run",
		] as Array[StringName]).accepted,
		"activity sequence resolves its authored start landmarks"
	)
	_check(
		runtime.activate_landmark(&"ember_mining_platform", Vector3(480.0, 3.0, -210.0)).reason == &"landmark_order_mismatch",
		"ordered activation rejects a later landmark"
	)
	var first := runtime.activate_landmark(&"ember_caldera_pad", Vector3(18.0, 0.0, 0.0))
	_check(
		first.accepted and first.receipt.route_eligible
			and first.receipt.route_id == &"ember_beacon_route"
			and runtime.get_snapshot().next_landmark_id == &"ember_mining_platform",
		"activation emits route eligibility and advances to the next authored activity"
	)
	var second := runtime.activate_landmark(
		&"ember_mining_platform", Vector3(480.0, 3.0, -210.0)
	)
	_check(
		second.accepted and second.receipt.activity_id == &"ember_kit_cargo_run"
			and runtime.get_snapshot().next_landmark_id == &"",
		"the sequence closes after the ordered landmark receipts"
	)
	_check(
		runtime.get_snapshot().authority.activity == false
			and runtime.get_snapshot().authority.reward == false,
		"landmark runtime owns no activity or reward authority"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_activity_landmark_runtime (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
