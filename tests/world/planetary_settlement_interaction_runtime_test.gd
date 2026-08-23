extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
const RuntimeScript := preload("res://scripts/world/planetary_settlement_interaction_runtime.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime := RuntimeScript.new()
	_check(runtime.configure(ContractScript.new()).accepted, "authored settlement configures interaction runtime")
	var discovered := runtime.discover(Vector3(92.0, 120000.5, -18.0), 30.0)
	_check(
		discovered.accepted and discovered.discoveries.size() == 1
			and discovered.discoveries[0].structure_id == &"ember_habitat_spine",
		"proximity discovery returns the stable authored structure ID"
	)
	_check(
		runtime.enter_structure(&"ember_habitat_spine", Vector3.ZERO, 1).reason == &"structure_out_of_range",
		"structure entry requires caller proximity evidence"
	)
	var entered := runtime.enter_structure(&"ember_habitat_spine", Vector3(92.0, 120000.5, -18.0), 1)
	_check(
		entered.accepted and entered.receipt.interaction_id == &"structure:ember_habitat_spine:enter"
			and entered.receipt.activity_intents.size() > 0,
		"entry emits a stable interaction ID and caller-facing activity intents"
	)
	_check(runtime.detach().accepted, "structure interaction detaches without moving the caller")
	_check(
		runtime.reenter(1).reason == &"stale_attachment_generation"
			and runtime.reenter(2).accepted
			and runtime.get_snapshot().active_structure_id == &"ember_habitat_spine",
		"detached structure entry requires a fresh attachment generation"
	)
	_check(runtime.exit_structure(2).accepted, "re-entered structure exits cleanly")
	_check(
		runtime.get_snapshot().authority.movement == false
			and runtime.get_snapshot().authority.reward == false,
		"settlement interaction owns no movement or reward authority"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_settlement_interaction_runtime (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures: push_error("FAIL: " + failure)
		quit(1)
