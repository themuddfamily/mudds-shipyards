extends SceneTree

## Focused Phase 7 runtime slice: an authority-admitted passenger ping becomes
## a bounded ship-local cabin marker signal. UI, network transport, and avatar
## presentation remain downstream consumers and are intentionally not asserted.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var authority := Authority.new(1)
	_check(
		bool(authority.register_halyard_roster().get("accepted", false)),
		"the Halyard roster seals before a passenger can submit a ping"
	)
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"the real Halyard accepts the session-owned role authority"
	)
	_check(
		bool(authority.claim(
			1, 91, &"passenger_avatar", &"crew_port_00", Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the passenger claim is tied to a physical cabin seat"
	)

	var emitted := [0]
	var cleared := [0]
	var last_marker := [StringName(&"")]
	var last_position := [Vector3.INF]
	var clear_reason := [StringName(&"")]
	craft.passenger_cabin_ping_emitted.connect(
		func(marker_id: StringName, _channel: StringName, position: Vector3, _receipt: Dictionary) -> void:
			emitted[0] += 1
			last_marker[0] = marker_id
			last_position[0] = position
	)
	craft.passenger_cabin_ping_cleared.connect(
		func(marker_id: StringName, reason: StringName, _peer_id: int, _avatar_id: StringName) -> void:
			cleared[0] += 1
			last_marker[0] = marker_id
			clear_reason[0] = reason
	)
	craft.set("_landed", false)
	var first := craft.submit_crew_intent(
		1,
		91,
		&"passenger_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"cabin", "marker_id": &"cabin_marker_00"},
		2
	)
	var first_effect := first.get("effect", {}) as Dictionary
	var first_marker := first_effect.get("marker", {}) as Dictionary
	_check(
		bool(first.get("accepted", false))
			and bool(first.get("consumed", false))
			and first.get("status", &"") == &"intent_consumed"
			and first_effect.get("status", &"") == &"passenger_ping_emitted",
		"the accepted passenger receipt is consumed as a cabin ping"
	)
	_check(
		emitted[0] == 1
			and last_marker[0] == &"cabin_marker_00"
			and (last_position[0] as Vector3).is_finite()
			and first_marker.get("world_position", Vector3.INF) == last_position[0]
			and craft.get_passenger_ping_markers().size() == 1,
		"the ping uses the real moving cabin deck marker without owning UI state"
	)

	var cooldown := craft.submit_crew_intent(
		1,
		91,
		&"passenger_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"cabin", "marker_id": &"cabin_marker_01"},
		3
	)
	_check(
		bool(cooldown.get("accepted", false))
			and not bool(cooldown.get("consumed", false))
			and (cooldown.get("effect", {}) as Dictionary).get("status", &"")
			== &"passenger_ping_cooldown"
			and emitted[0] == 1,
		"the passenger ping cadence blocks a second marker during cooldown"
	)

	for _frame in 65:
		await physics_frame
	var second := craft.submit_crew_intent(
		1,
		91,
		&"passenger_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"cabin", "marker_id": &"cabin_marker_01"},
		4
	)
	_check(
		bool(second.get("accepted", false))
			and bool(second.get("consumed", false))
			and emitted[0] == 2
			and craft.get_passenger_ping_markers().size() == 1,
		"a fresh sequence can publish one replacement marker after cooldown"
	)

	var released := authority.release(1, 91, &"passenger_avatar", &"crew_port_00", 5)
	_check(bool(released.get("accepted", false)), "the session authority releases the passenger role")
	await physics_frame
	_check(
		cleared[0] == 1
			and clear_reason[0] == &"role_detached"
			and craft.get_passenger_ping_markers().is_empty(),
		"detaching the role clears the ship-local passenger marker exactly once"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_PASSENGER_PING_GAMEPLAY_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
