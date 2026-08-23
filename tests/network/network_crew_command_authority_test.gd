extends SceneTree

const SeatAuthority := preload("res://scripts/network/network_seat_authority.gd")
const RoleAuthority := preload("res://scripts/network/network_crew_role_authority.gd")
const CommandAuthority := preload("res://scripts/network/network_crew_command_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var seats := SeatAuthority.new(1)
	_check(seats.register_seat(&"pilot_seat", &"ship_7", &"pilot", &"frame_7", 1).accepted, "seat is registered")
	_check(seats.claim(1, 7, &"avatar_7", &"pilot_seat", &"pilot", 1).accepted, "seat is occupied")
	var roles := RoleAuthority.new(seats, 1)
	_check(roles.admit_peer(1, 7, 3).accepted and roles.accept_role_intent(1, 7, 3, &"avatar_7", &"pilot", 1).accepted, "role admission is established")
	var commands := CommandAuthority.new(roles, 1)
	var accepted := commands.accept_command(1, 7, 3, &"avatar_7", &"flight_command", 1, 100, {"thrust_x": 0.5, "thrust_y": -0.25})
	_check(accepted.accepted and accepted.receipt.action == &"flight_command", "pilot command produces a detached receipt")
	_check(commands.accept_command(1, 7, 3, &"avatar_7", &"flight_command", 1, 101, {"thrust_x": 0.0, "thrust_y": 0.0}).status == &"stale_command_sequence", "command replay is rejected")
	_check(commands.accept_command(1, 7, 3, &"avatar_7", &"fire", 2, 102, {"weapon_id": "laser"}).status == &"role_action_mismatch", "cross-role action is rejected")
	_check(commands.accept_command(1, 7, 3, &"avatar_7", &"flight_command", 2, 103, {"thrust_x": 2.0, "thrust_y": 0.0}).status == &"invalid_flight_payload", "out-of-bounds payload is rejected")
	for sequence in range(3, 7):
		commands.accept_command(1, 7, 3, &"avatar_7", &"flight_command", sequence, 200, {"thrust_x": 0.0, "thrust_y": 0.0})
	_check(commands.accept_command(1, 7, 3, &"avatar_7", &"flight_command", 7, 200, {"thrust_x": 0.0, "thrust_y": 0.0}).status == &"command_rate_limited", "per-tick command rate is bounded")
	_check(commands.release_peer(1, 7, 3).accepted and commands.reset_migration(1, 2).accepted
		and commands.get_snapshot().tracked_stream_count == 0, "disconnect and migration clear command state")
	if _failures.is_empty():
		print("OK: crew command authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
