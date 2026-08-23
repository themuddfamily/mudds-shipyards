extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")
const RuntimeScript := preload("res://scripts/world/planetary_water_contact_runtime.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime := RuntimeScript.new()
	_check(runtime.configure(ContractScript.new()).accepted, "authored water contract configures runtime")
	_check(
		runtime.enter_water(Vector3.ZERO, 1).accepted
			and runtime.get_snapshot().water_body_id == &"aurora_coastal_shelf_water",
		"water contact enters with authored body identity"
	)
	var shallow := runtime.sample_contact(2.0, Vector3(4.0, 0.0, 0.0), 0.1, 1)
	_check(
		shallow.accepted
			and is_equal_approx(float(shallow.buoyancy_request.unitless), 0.1)
			and shallow.buoyancy_request.physics_mutation == false,
		"shallow contact emits bounded buoyancy without physics mutation"
	)
	var deep := runtime.sample_contact(20.0, Vector3(30.0, 0.0, 0.0), 0.1, 1)
	_check(
		deep.accepted and deep.recovery_request.requested
			and deep.recovery_request.recovery_id == &"return_to_landed_ship",
		"deep contact emits the authored recoverable shoreline request"
	)
	_check(
		runtime.sample_contact(2.0, Vector3.ZERO, 0.1, 2).reason == &"stale_attachment_generation",
		"contact samples are fenced to their attachment generation"
	)
	_check(runtime.detach().accepted, "contact can detach without moving the caller")
	_check(
		runtime.reenter(1).reason == &"stale_attachment_generation"
			and runtime.reenter(2).accepted
			and runtime.get_snapshot().state == &"contact",
		"detached contact requires a newer attachment before re-entry"
	)
	_check(runtime.exit_water(2).accepted, "re-entered contact exits cleanly")
	_check(
		runtime.get_snapshot().authority.physics == false
			and runtime.get_snapshot().authority.movement == false,
		"water runtime retains no physics or movement authority"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_water_contact_runtime (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
