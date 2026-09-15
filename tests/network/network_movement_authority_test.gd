extends SceneTree

## Focused contract regression for server validation of movement/boarding input.
## It deliberately does not start MultiplayerPeer, PlayerController, physics,
## or the production station; those integration gates remain separate.

const Intent := preload("res://scripts/network/network_movement_intent.gd")
const Authority := preload("res://scripts/network/network_movement_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wire_contract()
	_test_remote_body_wire_fields()
	_test_authority_ordering_and_delivery()
	_test_mode_and_generation_guards()
	_test_tick_window_and_peer_release()
	if _failures.is_empty():
		print("OK: network movement authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_wire_contract() -> void:
	var intent = Intent.create(7, &"avatar_a", 2, 4, 0, 12, Vector2(0.6, -0.25))
	_check(intent.is_valid(), "finite movement intent accepts the typed wire contract")
	var decoded = Intent.from_dictionary(intent.to_dictionary())
	_check(
		decoded.is_valid()
		and decoded.get_move_axis().is_equal_approx(Vector2(0.6, -0.25))
		and decoded.get_entity_generation() == 2,
		"movement intent round-trips as an independent snapshot"
	)
	var board = Intent.create(
		7, &"avatar_a", 2, 4, 1, 13, Vector2.ZERO, true, &"jovian_pilot"
	)
	_check(board.is_valid() and board.has_board_request(), "boarding target is explicit and typed")
	var malformed = board.to_dictionary()
	malformed.move_axis = [NAN, 0.0]
	_check(not Intent.from_dictionary(malformed).is_valid(), "non-finite movement input fails closed")
	var missing_target = Intent.create(7, &"avatar_a", 2, 4, 2, 14, Vector2.ZERO, true)
	_check(not missing_target.is_valid(), "boarding without a target fails closed")


func _test_authority_ordering_and_delivery() -> void:
	var authority := Authority.new(99, 3, 1)
	_check(
		authority.register_avatar(99, 7, &"avatar_a", 1).accepted,
		"server registers the generation-bearing avatar"
	)
	_check(authority.set_server_tick(99, 10).accepted, "server tick is caller-driven")
	var spoofed = Intent.create(8, &"avatar_a", 1, 1, 0, 10, Vector2.RIGHT)
	var spoofed_result := authority.accept_intent(7, spoofed.to_dictionary())
	_check(not spoofed_result.accepted and spoofed_result.status == &"spoofed_peer", "sender cannot spoof packet peer identity")
	var valid = Intent.create(7, &"avatar_a", 1, 1, 0, 10, Vector2.RIGHT)
	_check(authority.accept_intent(7, valid.to_dictionary()).accepted, "owner movement intent is accepted by the server")
	var duplicate := authority.accept_intent(7, valid.to_dictionary())
	_check(not duplicate.accepted and duplicate.status == &"stale_sequence", "duplicate movement intent cannot replay")
	var delivered := authority.consume_for_tick(&"avatar_a", 1, 10)
	_check(
		bool(delivered.accepted)
		and Intent.from_dictionary(delivered.intent).get_move_axis().is_equal_approx(Vector2.RIGHT),
		"one accepted intent is delivered to the movement owner for a physics tick"
	)
	_check(
		authority.consume_for_tick(&"avatar_a", 1, 10).status == &"already_consumed_tick",
		"a physics tick cannot consume movement twice"
	)
	var too_old = Intent.create(7, &"avatar_a", 1, 1, 1, 0, Vector2.ZERO)
	_check(
		authority.accept_intent(7, too_old.to_dictionary()).status == &"client_tick_too_old",
		"late movement input is rejected against the server tick window"
	)


func _test_mode_and_generation_guards() -> void:
	var authority := Authority.new(1, 4, 2)
	authority.register_avatar(1, 3, &"avatar_b", 5)
	authority.set_server_tick(1, 20)
	var board = Intent.create(3, &"avatar_b", 5, 2, 0, 20, Vector2.ZERO, true, &"jovian_pilot")
	_check(authority.accept_intent(3, board.to_dictionary()).accepted, "on-foot avatar can request a concrete boarding target")
	_check(
		authority.set_avatar_mode(1, &"avatar_b", 5, &"seated").accepted,
		"server can record the external physical seat result"
	)
	var walking_while_seated = Intent.create(3, &"avatar_b", 5, 2, 1, 21, Vector2.UP)
	_check(
		authority.accept_intent(3, walking_while_seated.to_dictionary()).status == &"action_not_allowed_in_mode",
		"seated avatar cannot author movement through the on-foot channel"
	)
	var disembark = Intent.create(3, &"avatar_b", 5, 2, 1, 21, Vector2.ZERO, false, &"", true)
	_check(authority.accept_intent(3, disembark.to_dictionary()).accepted, "seated avatar can request disembark")
	var stale = Intent.create(3, &"avatar_b", 4, 2, 2, 22, Vector2.ZERO)
	_check(
		authority.accept_intent(3, stale.to_dictionary()).status == &"stale_avatar_generation",
		"late generation input cannot reach a reused avatar"
	)
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_intent_validation)
		and bool(audit.server_owns_delivery_order)
		and not bool(audit.server_owns_movement_truth)
		and not bool(audit.server_owns_seat_reservation),
		"audit names the server boundary without duplicating movement or seat authority"
	)


## Schema 2 carries what a server-owned remote body is driven by; schema 1
## stays admitted with those fields neutral so the ship command wire and the
## three-process harness keep speaking it.
func _test_remote_body_wire_fields() -> void:
	var walking = Intent.create(
		7, &"avatar_a", 2, 4, 0, 12, Vector2(0.0, -1.0), false, &"", false,
		4.0, 0.3, true, false, true, 3
	)
	_check(walking.is_valid(), "schema 2 intent with look, run, jump and an interaction id is valid")
	_check(
		is_equal_approx(walking.get_look_yaw(), wrapf(4.0, -PI, PI))
		and is_equal_approx(walking.get_look_pitch(), 0.3)
		and walking.is_running() and not walking.is_crouching() and walking.has_jump_request()
		and walking.get_interaction_request_id() == 3,
		"look yaw is wrapped, pitch kept, flags and interaction id round-trip"
	)
	var decoded = Intent.from_dictionary(walking.to_dictionary())
	_check(
		decoded.is_valid() and decoded.to_dictionary().size() == 17
		and decoded.get_interaction_request_id() == 3,
		"a schema 2 wire round-trips with exactly its seventeen keys"
	)
	var legacy := {
		"schema_version": 1, "peer_id": 7, "entity_id": &"avatar_a", "entity_generation": 2,
		"stream_id": 4, "sequence": 0, "client_tick": 12, "move_axis": [0.5, 0.0],
		"board_request": false, "boarding_target_id": &"", "disembark_request": false,
	}
	var legacy_intent = Intent.from_dictionary(legacy)
	_check(
		legacy_intent.is_valid() and not legacy_intent.is_running()
		and legacy_intent.get_interaction_request_id() == 0
		and legacy_intent.to_dictionary().size() == 11,
		"a schema 1 wire is still admitted with the remote-body fields neutral"
	)
	var unbounded: Dictionary = walking.to_dictionary()
	unbounded["look_pitch"] = 3.0
	_check(not Intent.from_dictionary(unbounded).is_valid(), "look pitch beyond a half turn is rejected")
	var nan_yaw: Dictionary = walking.to_dictionary()
	nan_yaw["look_yaw"] = NAN
	_check(not Intent.from_dictionary(nan_yaw).is_valid(), "a non-finite look yaw is rejected")
	var negative: Dictionary = walking.to_dictionary()
	negative["interaction_request_id"] = -1
	_check(not Intent.from_dictionary(negative).is_valid(), "a negative interaction id is rejected")
	var extra: Dictionary = walking.to_dictionary()
	extra["teleport"] = [1.0, 2.0, 3.0]
	_check(not Intent.from_dictionary(extra).is_valid(), "an extra wire key is rejected on schema 2 too")
	var mixed := legacy.duplicate(true)
	mixed["run"] = true
	_check(not Intent.from_dictionary(mixed).is_valid(), "a schema 1 wire cannot smuggle a schema 2 field")


func _test_tick_window_and_peer_release() -> void:
	var authority := Authority.new(1)
	_check(
		authority.configure_tick_window(2, 60, 6).status == &"unauthorized_source",
		"only the authority may widen the tick window"
	)
	_check(
		not authority.configure_tick_window(1, 601, 6).accepted
		and authority.configure_tick_window(1, 60, 6).accepted,
		"the tick window stays bounded"
	)
	_check(authority.register_avatar(1, 7, &"crew_a", 1).accepted, "remote body avatar registers")
	_check(authority.register_avatar(1, 8, &"crew_b", 1).accepted, "second peer's avatar registers")
	_check(authority.set_server_tick(1, 100).accepted, "server tick advances")
	var behind = Intent.create(7, &"crew_a", 1, 1, 0, 45, Vector2.UP)
	_check(
		authority.accept_intent(7, behind.to_dictionary()).accepted,
		"an honest stamp fifty-five ticks behind is inside the widened window"
	)
	var too_far = Intent.create(7, &"crew_a", 1, 1, 1, 39, Vector2.UP)
	_check(
		authority.accept_intent(7, too_far.to_dictionary()).status == &"client_tick_too_old",
		"a stamp past the widened window is still rejected"
	)
	var snapshot: Dictionary = authority.get_avatar_snapshot(&"crew_a")
	_check(
		int(snapshot.get("last_accepted_server_tick", -1)) == 100,
		"the avatar records the server tick its last intent was accepted at"
	)
	var released: Dictionary = authority.release_peer(1, 7)
	_check(
		released.accepted and (released.released as Array).size() == 1
		and authority.get_avatar_snapshot(&"crew_a").is_empty()
		and not authority.get_avatar_snapshot(&"crew_b").is_empty(),
		"releasing a peer retires exactly that peer's avatars"
	)
	_check(
		authority.release_peer(2, 8).status == &"unauthorized_source",
		"only the authority may release a peer"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
