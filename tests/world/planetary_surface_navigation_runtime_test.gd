extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const RuntimeScript := preload("res://scripts/world/planetary_surface_navigation_runtime.gd")

var _failures: PackedStringArray = []
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime := RuntimeScript.new()
	var contract := ContractScript.new()
	_check(runtime.configure(contract).accepted, "authored navigation contract configures runtime")
	_check(runtime.start_route(&"pad_to_surface_staging").accepted, "ordered surface route starts at first landmark")
	_check(
		runtime.submit_landmark_evidence(&"caldera_overlook", Vector3(42.0, 120000.0, 0.0)).reason == &"landmark_mismatch",
		"wrong landmark evidence cannot skip the ordered waypoint"
	)
	_check(
		runtime.submit_landmark_evidence(&"surface_staging_gate", Vector3(100.0, 120000.0, 0.0)).reason == &"landmark_out_of_range",
		"matching landmark evidence outside its authored radius does not advance"
	)
	var first := runtime.submit_landmark_evidence(
		&"surface_staging_gate", Vector3(42.0, 120000.0, 0.0)
	)
	_check(
		first.accepted and first.reason == &"waypoint_reached"
			and first.runtime.waypoint_index == 1
			and first.runtime.next_landmark_id == &"caldera_overlook",
		"caller position evidence commits only the next authored waypoint"
	)
	_check(runtime.interrupt(&"surface_route_lost").accepted, "active route interruption is recoverable")
	var interrupted := runtime.get_snapshot()
	_check(
		interrupted.state == &"interrupted"
			and interrupted.waypoint_index == 1
			and interrupted.authority.movement == false,
		"interruption preserves progress without taking movement authority"
	)
	_check(
		runtime.resume_route(Vector3(60.0, 120000.0, 0.0)).reason == &"route_resumed"
			and runtime.get_snapshot().waypoint_index == 1,
		"caller re-entry resumes the same next waypoint"
	)
	var completed := runtime.submit_landmark_evidence(
		&"caldera_overlook", Vector3(420.0, 120025.0, -180.0)
	)
	_check(
		completed.accepted and completed.reason == &"route_completed"
			and completed.runtime.state == &"completed",
		"the final authored landmark closes the route"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_surface_navigation_runtime (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
