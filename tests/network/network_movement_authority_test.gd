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
	_test_authority_ordering_and_delivery()
	_test_mode_and_generation_guards()
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


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
