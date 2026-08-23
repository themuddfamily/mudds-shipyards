extends SceneTree

## Focused Jovian multicrew production coverage. The physical cockpit-side
## copilot seat uses the existing passenger-access role contract to submit a
## generation/sequence-fenced navigation route receipt. It only observes cargo
## and berth state; the ship pilot, movement, cargo, and landing authorities
## remain untouched.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _checks := 0
var _failures: Array[String] = []
var _clears := 0
var _last_clear_generation := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(craft != null, "production Jovian instantiates for copilot navigation support")
	if craft == null:
		_finish()
		return
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var authority := _build_authority()
	var attached := craft.attach_crew_role_authority(authority)
	_check(
		bool(attached.get("accepted", false)),
		"Jovian accepts the sealed pilot/engineer/copilot role roster"
	)
	var copilot_anchor := craft.get_copilot_seat_anchor()
	_check(
		copilot_anchor != null
			and copilot_anchor.get_meta("seat_id", &"") == &"co_pilot_station"
			and copilot_anchor.get_meta("role_id", &"") == &"copilot_navigation_support"
			and copilot_anchor.get_parent() != craft.get_passenger_cabin_root(),
		"copilot navigation support is a physical cockpit-side seat, not a cabin alias"
	)
	craft.copilot_navigation_intent_cleared.connect(
		func(generation: int, _reason: StringName) -> void:
			_clears += 1
			_last_clear_generation = generation
	)
	_check(
		bool(authority.claim(
			1, 77, &"copilot_avatar", &"co_pilot_station", Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"server admits the optional copilot at the physical cockpit station"
	)
	var initial_generation := int(craft.get_copilot_navigation_state().navigation_generation)
	var nav := craft.submit_crew_intent(
		1,
		77,
		&"copilot_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"navigation_route", "marker_id": &"jovian_freight_berth"},
		2
	)
	var receipt := nav.get("effect", {}).get("receipt", {}) as Dictionary
	var nav_state := craft.get_copilot_navigation_state()
	_check(
		bool(nav.get("accepted", false))
			and bool(nav.get("consumed", false))
			and nav.get("status", &"") == &"intent_consumed"
			and receipt.get("route_id", &"") == &"jovian_freight_berth"
			and int(receipt.get("seat_generation", 0)) == 1
			and int(receipt.get("navigation_generation", 0)) == initial_generation,
		"authority-admitted copilot receipt becomes one detached navigation route record"
	)
	_check(
		int(nav_state.cargo_status.hardpoint_count) == 4
			and bool(nav_state.cargo_status.secured)
			and nav_state.berth_status.home_berth_id == &"jovian_freight_berth"
			and not bool(nav_state.authority.movement)
			and not bool(nav_state.authority.throttle)
			and not bool(nav_state.authority.fire)
			and not craft.is_piloted(),
		"navigation receipt inspects cargo/berth status without steering or claiming the helm"
	)
	var wrong_channel := craft.submit_crew_intent(
		1,
		77,
		&"copilot_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"passenger_status", "marker_id": &"jovian_freight_berth"},
		3
	)
	_check(
		bool(wrong_channel.get("accepted", false))
			and not bool(wrong_channel.get("consumed", false))
			and wrong_channel.get("effect", {}).get("status", &"") == &"unsupported_navigation_channel",
		"copilot cannot turn a passenger ping into an unbounded non-navigation command"
	)
	var replay := craft.submit_crew_intent(
		1,
		77,
		&"copilot_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"navigation_route", "marker_id": &"jovian_freight_berth"},
		2
	)
	_check(not bool(replay.get("accepted", false)) and replay.get("status", &"") == &"stale_request_sequence", "replayed copilot receipt is fenced by authority sequence")
	var handoff := craft.handoff_crew_role(
		1,
		77,
		&"copilot_avatar",
		&"co_pilot_station",
		4,
		99,
		&"replacement_copilot",
		Authority.ROLE_PASSENGER,
		5
	)
	var handed_state := craft.get_copilot_navigation_state()
	_check(
		bool(handoff.get("accepted", false))
			and _clears == 1
			and handed_state.receipt.is_empty()
			and _last_clear_generation > initial_generation,
		"copilot handoff clears the outgoing route receipt and advances its generation"
	)
	var replacement := craft.submit_crew_intent(
		1,
		99,
		&"replacement_copilot",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"navigation_route", "marker_id": &"central_berth"},
		6
	)
	var replacement_receipt := replacement.get("effect", {}).get("receipt", {}) as Dictionary
	_check(
		bool(replacement.get("consumed", false))
			and replacement_receipt.get("target_id", &"") == &"central_berth"
			and int(replacement_receipt.get("navigation_generation", 0)) > initial_generation,
		"replacement copilot receives a fresh generation-fenced route target"
	)
	var released := craft.release_crew_role(
		1, 99, &"replacement_copilot", &"co_pilot_station", 7
	)
	_check(
		bool(released.get("accepted", false))
			and _clears == 2
			and craft.get_copilot_navigation_state().receipt.is_empty(),
		"copilot release clears route state exactly once"
	)
	var stale_after_release := craft.submit_crew_intent(
		1,
		99,
		&"replacement_copilot",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"navigation_route", "marker_id": &"central_berth"},
		8
	)
	_check(
		not bool(stale_after_release.get("accepted", false))
			and stale_after_release.get("status", &"") == &"assignment_not_found",
		"released copilot cannot submit a stale route after the seat lease ends"
	)
	var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, 6.0)))
	_check(bool(reset.get("accepted", false)), "Jovian reuse transaction remains available after copilot cleanup")
	var reset_state := craft.get_copilot_navigation_state()
	_check(
		reset_state.receipt.is_empty()
			and int(reset_state.navigation_generation) == 1,
		"reuse resets copilot route state and generation"
	)
	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	_check(
		craft.get_copilot_navigation_state().receipt.is_empty()
			and int(craft.get_copilot_navigation_state().navigation_generation) > 1,
		"detach and re-entry advance copilot generation without retaining a route"
	)
	craft.queue_free()
	await process_frame
	_finish()


func _build_authority() -> CrewSeatRoleAuthority:
	var authority := Authority.new(1)
	for seat in [
		[&"pilot_station", Authority.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"co_pilot_station", Authority.ROLE_PASSENGER, &"copilot_seat_anchor"],
		[&"passenger_port_01", Authority.ROLE_ENGINEER, &"passenger_port_01"],
		[&"freight_defense_slot", Authority.ROLE_GUNNER, &""],
	]:
		var result := authority.register_seat(
			seat[0], &"jovian_provisional", seat[1], &"jovian_walkable_interior", 1, seat[2]
		)
		_check(bool(result.get("accepted", false)), "Jovian role seat registers: %s" % seat[0])
	var sealed := authority.seal_roster()
	_check(bool(sealed.get("accepted", false)), "Jovian copilot role roster seals before claims")
	return authority


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_COPILOT_NAVIGATION_GAMEPLAY_TEST_OK: %d checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("JOVIAN_COPILOT_NAVIGATION_GAMEPLAY_TEST_FAILED: %d checks, %d failures" % [_checks, _failures.size()])
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
