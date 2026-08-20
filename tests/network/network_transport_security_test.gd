extends SceneTree

## Focused transport security regression.  It validates only envelope schema,
## bounded size, token issuance, generation fencing, source forgery, and
## per-stream replay rejection; no multiplayer peer or scene is launched.

const Security := preload("res://scripts/network/network_transport_security.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_token_and_packet_admission()
	_test_forgery_replay_and_schema_rejection()
	_test_size_and_generation_fences()
	if _failures.is_empty():
		print("OK: network transport security (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_security() -> Security:
	return Security.new(99, 3, 7, "focused-transport-secret")


func _test_token_and_packet_admission() -> void:
	var security := _new_security()
	_check(
		not security.register_peer(7, 7, 1).accepted,
		"a client cannot register or mint its own transport identity"
	)
	var registered := security.register_peer(99, 7, 1)
	_check(
		registered.accepted and registered.status == &"peer_registered"
		and String(registered.auth_token).length() == Security.MAX_TOKEN_BYTES * 2,
		"server registration issues a bounded opaque authentication token"
	)
	var token := String(registered.auth_token)
	var packet := security.make_packet(7, 1, &"movement", 0, {"axis": 0.5})
	_check(
		String(packet.auth_token) == token
		and int(packet.schema_version) == Security.SCHEMA_VERSION
		and int(packet.session_generation) == 7,
		"packet helper binds schema, session, generation, and current token"
	)
	var accepted := security.accept_packet(7, packet)
	_check(
		accepted.accepted and accepted.status == &"packet_accepted"
		and accepted.payload.axis == 0.5,
		"valid packet reaches the transport boundary exactly once"
	)
	var second_token := security.issue_auth_token(99, 7, 1)
	_check(
		second_token.accepted and String(second_token.auth_token) != token,
		"server token rotation changes the token and clears stream replay state"
	)


func _test_forgery_replay_and_schema_rejection() -> void:
	var security := _new_security()
	security.register_peer(99, 7, 1)
	security.register_peer(99, 8, 1)
	var packet := security.make_packet(7, 1, &"command", 4, {"action": "fire"})
	_check(
		not security.accept_packet(8, packet).accepted
		and security.get_last_result().status == &"spoofed_peer",
		"transport source forgery is rejected before stream mutation"
	)
	_check(
		security.accept_packet(7, packet).accepted,
		"the original packet remains admissible after a forged delivery attempt"
	)
	var replay := security.accept_packet(7, packet)
	_check(
		not replay.accepted and replay.status == &"replayed_or_out_of_order",
		"duplicate packet replay is rejected"
	)
	var reordered := security.make_packet(7, 1, &"command", 3, {"action": "old"})
	_check(
		not security.accept_packet(7, reordered).accepted
		and security.get_last_result().status == &"replayed_or_out_of_order",
		"out-of-order packet replay is rejected"
	)
	var forged_token := security.make_packet(7, 1, &"command", 5, {"action": "fire"})
	forged_token["auth_token"] = "0".repeat(Security.MAX_TOKEN_BYTES * 2)
	_check(
		not security.accept_packet(7, forged_token).accepted
		and security.get_last_result().status == &"invalid_auth_token",
		"captured token cannot be replaced by a forged token"
	)
	var extra := packet.duplicate(true)
	extra["unexpected"] = true
	_check(
		not security.accept_packet(7, extra).accepted
		and security.get_last_result().status == &"invalid_packet_schema",
		"unknown envelope fields fail the exact schema gate"
	)


func _test_size_and_generation_fences() -> void:
	var security := _new_security()
	security.register_peer(99, 7, 1)
	var oversized := security.make_packet(7, 1, &"command", 0, {"blob": "x".repeat(Security.MAX_PAYLOAD_BYTES + 32)})
	_check(
		not security.accept_packet(7, oversized).accepted
		and security.get_last_result().status == &"packet_too_large",
		"oversized packet is rejected before authentication or replay mutation"
	)
	var invalid_sequence := security.make_packet(7, 1, &"command", -1, {})
	_check(
		not security.accept_packet(7, invalid_sequence).accepted
		and security.get_last_result().status == &"invalid_sequence",
		"negative packet sequence is rejected"
	)
	var stale_generation := security.make_packet(7, 1, &"command", 0, {})
	stale_generation["peer_generation"] = 0
	_check(
		not security.accept_packet(7, stale_generation).accepted
		and security.get_last_result().status == &"stale_peer_generation",
		"stale peer generation is rejected"
	)
	var old_session_packet := security.make_packet(7, 1, &"command", 0, {})
	_check(
		security.rotate_session(7).status == &"unauthorized_source"
		and security.rotate_session(99).accepted,
		"only the server can rotate the session generation"
	)
	_check(
		not security.accept_packet(7, old_session_packet).accepted
		and security.get_last_result().status == &"stale_session_generation",
		"session rotation invalidates packets from the previous generation"
	)
	var audit := security.audit()
	_check(
		bool(audit.server_owns_token_generation)
		and bool(audit.server_owns_replay_cursor)
		and bool(audit.exact_packet_schema)
		and bool(audit.bounded_packet_bytes),
		"audit exposes server-owned token, replay, schema, and size boundaries"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
