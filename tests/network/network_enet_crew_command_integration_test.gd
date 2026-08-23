extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.get_crew_command_snapshot().tracked_stream_count == 0,
		"adapter starts with detached command streams")
	_check(adapter.get_crew_command_snapshot().policy_version == &"network_crew_command_authority_v1",
		"adapter exposes command authority policy")
	_check(adapter.accept_crew_command(7, 1, &"avatar_7", &"flight_command", 1, 10,
		{"thrust_x": 0.0, "thrust_y": 0.0}).status == &"authority_required",
		"client-side command acceptance cannot mutate authority")
	_check(adapter.send_crew_command(&"avatar_7", &"flight_command", 1, 10,
		{"thrust_x": 0.0, "thrust_y": 0.0}).status == &"invalid_crew_command",
		"command transport requires a configured client session")
	_check(adapter.get_crew_command_snapshot().tracked_tick_count == 0,
		"rejected command attempts leave detached state unchanged")
	_check(adapter.reset_snapshot_jitter(2).accepted
		and adapter.get_crew_command_snapshot().migration_generation == 2,
		"migration reset clears and advances command generation")
	if _failures.is_empty():
		print("OK: ENet crew command integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
