extends SceneTree

## Focused detached regression for multiplayer session admission. It does not
## open ENet peers, load a production scene, or run a soak; transport and
## native two-client acceptance remain separate gates.

const Handshake := preload("res://scripts/network/network_session_handshake.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wire_and_compatibility_guards()
	_test_admission_generation_and_disconnect()
	_test_authoritative_rotation_and_snapshot()
	if _failures.is_empty():
		print("OK: network session handshake (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_handshake() -> Handshake:
	return Handshake.new(99, 4, 12, 3)


func _hello(
	peer_id: int = 7,
	peer_generation: int = 1,
	protocol_version: int = 4,
	package_generation: int = 12,
	session_generation: int = 3,
	schema_version: int = Handshake.SCHEMA_VERSION
) -> Dictionary:
	return Handshake.create_hello(
		peer_id, peer_generation, protocol_version, package_generation,
		session_generation, schema_version
	)


func _test_wire_and_compatibility_guards() -> void:
	var authority := _new_handshake()
	var hello := _hello()
	var accepted := authority.accept_hello(7, hello)
	_check(accepted.accepted and accepted.status == &"accepted", "matching hello is admitted")
	var extra := hello.duplicate(true)
	extra["client_transform"] = Vector3.ZERO
	var malformed := authority.accept_hello(7, extra)
	_check(not malformed.accepted and malformed.status == &"invalid_hello", "extra client state fails the exact wire schema")
	var protocol := _hello(8)
	protocol.protocol_id = &"other_game"
	_check(authority.accept_hello(8, protocol).status == &"protocol_mismatch", "foreign protocol identity is rejected")
	var version := _hello(8, 1, 5)
	_check(authority.accept_hello(8, version).status == &"protocol_version_mismatch", "protocol version drift is rejected")
	var schema := _hello(8, 1, 4, 12, 3, 2)
	_check(authority.accept_hello(8, schema).status == &"schema_version_mismatch", "handshake schema drift is rejected")
	var package_generation := _hello(8, 1, 4, 13)
	_check(authority.accept_hello(8, package_generation).status == &"package_generation_mismatch", "stale package generation is rejected")
	var stale_session := _hello(8, 1, 4, 12, 2)
	_check(authority.accept_hello(8, stale_session).status == &"stale_session_generation", "stale session generation is rejected")
	var future_session := _hello(8, 1, 4, 12, 4)
	_check(authority.accept_hello(8, future_session).status == &"future_session_generation", "future session generation is rejected")
	_check(authority.accept_hello(8, _hello(7)).status == &"spoofed_peer", "transport peer cannot be spoofed by packet identity")
	_check(authority.accept_hello(99, _hello(99)).status == &"authority_peer_reserved", "server authority peer cannot join as a client")
	var bad_type := hello.duplicate(true)
	bad_type.peer_generation = 1.5
	_check(authority.accept_hello(7, bad_type).status == &"invalid_hello", "non-integer peer generation fails closed")


func _test_admission_generation_and_disconnect() -> void:
	var authority := _new_handshake()
	var first := authority.accept_hello(7, _hello())
	_check(first.accepted and first.peer.peer_generation == 1, "first peer generation is recorded by the server")
	var duplicate := authority.accept_hello(7, _hello())
	_check(not duplicate.accepted and duplicate.status == &"stale_peer_generation", "duplicate peer generation cannot replay admission")
	var second := authority.accept_hello(8, _hello(8, 1))
	_check(second.accepted and authority.get_snapshot().peers.size() == 2, "independent peer admissions remain bounded and detached")
	var unauthorized_release := authority.release_peer(8, 7, 1)
	_check(not unauthorized_release.accepted and unauthorized_release.status == &"unauthorized_source", "clients cannot release server peer records")
	var stale_release := authority.release_peer(99, 7, 2)
	_check(not stale_release.accepted and stale_release.status == &"stale_peer_generation", "disconnect cleanup is generation-fenced")
	var released := authority.release_peer(99, 7, 1)
	_check(released.accepted and released.status == &"released", "server can release the current peer generation")
	_check(authority.get_peer(7).is_empty(), "released peer is absent from the active snapshot")
	var late_old_hello := authority.accept_hello(7, _hello(7, 1))
	_check(not late_old_hello.accepted and late_old_hello.status == &"stale_peer_generation", "late old hello cannot resurrect a released peer")
	var reconnect := authority.accept_hello(7, _hello(7, 2))
	_check(reconnect.accepted and reconnect.peer.peer_generation == 2, "new peer generation can reconnect after release")


func _test_authoritative_rotation_and_snapshot() -> void:
	var authority := _new_handshake()
	_check(authority.accept_hello(7, _hello()).accepted, "peer is connected before session rotation")
	var unauthorized_rotate := authority.rotate_session(7, 13)
	_check(not unauthorized_rotate.accepted and unauthorized_rotate.status == &"unauthorized_source", "only server authority can rotate a session")
	var rotated := authority.rotate_session(99, 13)
	_check(
		rotated.accepted
		and rotated.status == &"session_rotated"
		and int(rotated.session_generation) == 4
		and int(rotated.package_generation) == 13,
		"server rotation advances session and package generations atomically"
	)
	_check(authority.get_snapshot().peers.is_empty(), "rotation clears old peer attachments")
	var old_session_new_package := _hello(7, 2, 4, 13, 3)
	_check(authority.accept_hello(7, old_session_new_package).status == &"stale_session_generation", "old session hello remains stale after rotation")
	var current := _hello(7, 2, 4, 13, 4)
	_check(authority.accept_hello(7, current).accepted, "matching current session/package can rejoin")
	var detached := authority.get_server_offer()
	detached["package_generation"] = 999
	_check(int(authority.get_server_offer().package_generation) == 13, "server offer is a detached copy")
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_compatibility)
		and bool(audit.server_owns_session_generation)
		and bool(audit.server_owns_peer_admission)
		and bool(audit.stale_peer_generations_rejected)
		and not bool(audit.client_can_mutate_session),
		"audit states the server ownership and stale-peer boundary"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
