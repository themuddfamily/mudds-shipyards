extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")

const SHIP_ID: StringName = &"cinder-long-range-bomber"
const FRAME_ID: StringName = &"frame_cinder"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	_check(server.register_boarding_ship(&"cinder-long-range-bomber", 1, &"frame_cinder", 1).accepted,
		"server registers one ship boarding lifecycle")
	_check(server.register_boarding_seat(&"cinder-long-range-bomber_pilot", &"cinder-long-range-bomber", 1, &"pilot").accepted,
		"server registers pilot seat")
	var claimed := server.publish_boarding_snapshot(
		&"cinder-long-range-bomber", 1, &"cinder-long-range-bomber_pilot", 1, 1, true, [2], 10
	)
	_check(bool(claimed.get("accepted", false)), "server publishes pilot claim")
	var client := Adapter.new()
	var applied := client.consume_boarding_ownership_snapshot(claimed.get("packet", {}) as Dictionary)
	_check(bool(applied.get("accepted", false)), "client consumes presentation-only claim")
	_check(int(client.get_presentation_cursor_audit().get("boarding_count", 0)) == 1,
		"client retains one boarding presentation cursor")
	var released := server.publish_boarding_snapshot(
		&"cinder-long-range-bomber", 1, &"cinder-long-range-bomber_pilot", 1, 1, false, [2], 11
	)
	_check(bool(released.get("accepted", false)), "server publishes pilot release")
	_check(bool(client.consume_boarding_ownership_snapshot(released.get("packet", {}) as Dictionary).get("accepted", false)),
		"client consumes ordered release")
	var stale := (claimed.get("packet", {}) as Dictionary).duplicate(true)
	stale["revision"] = 1
	_check(not bool(client.consume_boarding_ownership_snapshot(stale).get("accepted", false)),
		"stale boarding transition is rejected")
	_assert_the_hatch_seam(server)
	server.reset_snapshot_jitter(2)
	server._on_peer_disconnected(2)
	_check(int(server.get_presentation_cursor_audit().get("boarding_count", 0)) == 0,
		"disconnect clears boarding presentation state")
	server.free()
	client.free()
	if _failures.is_empty():
		print("OK: GameFlow boarding network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## The hatch seam. GameFlow registers `NETWORK_CABIN_BERTH_COUNT` passenger
## berths beside each walkable craft's pilot seat, and decides what stands
## behind a claim the ledger has confirmed: a berth claim on a fleet craft
## stands a server-simulated body (proved over real ENet in
## `network_remote_body_simulation_test`), a berth claim on a craft the fleet
## does not hold is refused without a body, a pilot claim keeps the seat seam,
## and a disembark releases only a body that exists. Refused results and the
## host's own claims never reach the seam.
func _assert_the_hatch_seam(server) -> void:
	var flow := GameFlow.new()
	flow.network_session = server
	flow._network_session_mode = &"server"
	var berth := GameFlow.network_cabin_berth_seat_id(SHIP_ID, 1)
	_check(berth == &"cinder-long-range-bomber_cabin_01"
		and GameFlow.is_network_cabin_berth_seat(SHIP_ID, berth)
		and not GameFlow.is_network_cabin_berth_seat(SHIP_ID, &"cinder-long-range-bomber_pilot"),
		"cabin berths are named per craft and told apart from the pilot seat")
	var registered := 0
	for index in GameFlow.NETWORK_CABIN_BERTH_COUNT:
		if bool(server.register_boarding_seat(
				GameFlow.network_cabin_berth_seat_id(SHIP_ID, index + 1), SHIP_ID, 1,
				GameFlow.NETWORK_CABIN_BERTH_ROLE).get("accepted", false)):
			registered += 1
	_check(registered == GameFlow.NETWORK_CABIN_BERTH_COUNT,
		"every cabin berth registers with the boarding ledger as a passenger seat")
	var claim = BoardingIntent.create(
		2, &"crew-a", SHIP_ID, 1, FRAME_ID, 1, berth, 1, &"passenger", 0, 0, BoardingIntent.ACTION_BOARD
	)
	var confirmed: Dictionary = server._boarding.accept_intent(2, claim.to_dictionary())
	_check(bool(confirmed.get("accepted", false)) and confirmed.get("status") == &"boarded"
		and (confirmed.get("occupancy", {}) as Dictionary).get("role") == &"passenger",
		"the ledger confirms a passenger's berth claim")
	var wrong_role = BoardingIntent.create(
		2, &"crew-b", SHIP_ID, 1, FRAME_ID, 1, GameFlow.network_cabin_berth_seat_id(SHIP_ID, 2), 1,
		&"pilot", 0, 0, BoardingIntent.ACTION_BOARD
	)
	_check(server._boarding.accept_intent(2, wrong_role.to_dictionary()).get("status") == &"role_mismatch",
		"a pilot claim on a cabin berth is refused by the ledger")
	var taken = BoardingIntent.create(
		2, &"crew-b", SHIP_ID, 1, FRAME_ID, 1, berth, 1, &"passenger", 1, 0, BoardingIntent.ACTION_BOARD
	)
	_check(server._boarding.accept_intent(2, taken.to_dictionary()).get("status") == &"seat_occupied",
		"a berth already held is refused to the next avatar")
	# The confirmed berth claim reaches GameFlow, which holds no such craft.
	flow._on_network_boarding_intent_result(confirmed)
	var audit: Dictionary = flow.get_network_remote_body_audit()
	_check(int(audit.get("hatch_refusals", 0)) == 1 and audit.get("last_hatch_status") == &"unknown_craft"
		and int(audit.get("hatch_admissions", 0)) == 0 and int(audit.get("bodies", 0)) == 0,
		"a berth claim on a craft the fleet does not hold stands no body and is counted")
	var pilot_claim = BoardingIntent.create(
		2, &"crew-c", SHIP_ID, 1, FRAME_ID, 1, &"cinder-long-range-bomber_pilot", 1, &"pilot", 0, 0,
		BoardingIntent.ACTION_BOARD
	)
	var pilot_confirmed: Dictionary = server._boarding.accept_intent(2, pilot_claim.to_dictionary())
	_check(pilot_confirmed.get("status") == &"boarded", "the ledger confirms a pilot-seat claim")
	flow._on_network_boarding_intent_result(pilot_confirmed)
	audit = flow.get_network_remote_body_audit()
	_check(int(audit.get("hatch_pilot_seats", 0)) == 1 and audit.get("last_hatch_status") == &"pilot_seat_retained"
		and int(audit.get("hatch_refusals", 0)) == 1,
		"a remote pilot's claim keeps the seat seam: no walking body, no refusal")
	var leave = BoardingIntent.create(
		2, &"crew-a", SHIP_ID, 1, FRAME_ID, 1, berth, 1, &"passenger", 1, 0, BoardingIntent.ACTION_DISEMBARK
	)
	var left: Dictionary = server._boarding.accept_intent(2, leave.to_dictionary())
	_check(left.get("status") == &"disembarked", "the ledger releases the berth on disembark")
	flow._on_network_boarding_intent_result(left)
	audit = flow.get_network_remote_body_audit()
	_check(int(audit.get("hatch_releases", 0)) == 0 and audit.get("last_hatch_status") == &"no_body_to_release",
		"a disembark with no body behind it releases nothing")
	flow._on_network_boarding_intent_result({"accepted": false, "status": &"seat_occupied", "occupancy": {}})
	flow._on_network_boarding_intent_result({"accepted": true, "status": &"boarded", "occupancy": {
		"peer_id": 1, "avatar_id": &"pilot", "ship_id": SHIP_ID, "seat_id": berth, "role": &"passenger",
	}})
	var untouched: Dictionary = flow.get_network_remote_body_audit()
	_check(int(untouched.get("hatch_refusals", 0)) == 1 and int(untouched.get("hatch_pilot_seats", 0)) == 1
		and untouched.get("last_hatch_status") == &"no_body_to_release",
		"a refused claim and the host's own claim never reach the hatch seam")
	flow.network_session = null
	flow.free()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
