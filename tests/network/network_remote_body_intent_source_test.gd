extends SceneTree

## Deterministic contract for the client-side on-foot intent stream: fixed
## cadence, edge latching, strictly ordered tick stamps derived from the
## observed server tick, and the bounded prediction reconciliation. No peer,
## no physics; the integration is `tests/network_remote_body_simulation_test.gd`.

const IntentSource := preload("res://scripts/network/network_remote_body_intent_source.gd")
const Intent := preload("res://scripts/network/network_movement_intent.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_cadence_and_framing()
	_test_edges_survive_between_sends()
	_test_stamp_tracks_the_observed_server_tick()
	_test_reconciliation_is_bounded()
	if _failures.is_empty():
		print("OK: network remote body intent source (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _sample(move_axis: Vector2 = Vector2.ZERO, run: bool = false) -> Dictionary:
	return {"move_axis": move_axis, "look_yaw": 0.5, "look_pitch": 0.1, "run": run, "crouch": false}


func _test_cadence_and_framing() -> void:
	var source := IntentSource.new(4)
	_check(source.advance(2, _sample(), 10).is_empty(), "an unbound source sends nothing")
	var bound: Dictionary = source.bind(&"crew_a", 3)
	_check(bound.accepted and int(bound.stream_id) == 1, "binding opens the first stream")
	var sent := 0
	var wires: Array = []
	for _tick in 12:
		var wire: Dictionary = source.advance(2, _sample(Vector2(0.0, -1.0), true), 100)
		if not wire.is_empty():
			sent += 1
			wires.append(wire)
	_check(sent == 3, "twelve ticks at a four-tick cadence send exactly three intents (%d)" % sent)
	var first = Intent.from_dictionary(wires[0] as Dictionary)
	_check(
		first.is_valid() and first.get_peer_id() == 2 and first.get_entity_id() == &"crew_a"
		and first.get_entity_generation() == 3 and first.get_stream_id() == 1
		and first.get_sequence() == 0 and first.is_running()
		and first.get_move_axis().is_equal_approx(Vector2(0.0, -1.0))
		and is_equal_approx(first.get_look_yaw(), 0.5),
		"the first wire is a valid schema 2 intent framed with the bound identity"
	)
	var second = Intent.from_dictionary(wires[1] as Dictionary)
	var third = Intent.from_dictionary(wires[2] as Dictionary)
	_check(
		second.get_sequence() == 1 and third.get_sequence() == 2
		and second.get_client_tick() > first.get_client_tick()
		and third.get_client_tick() > second.get_client_tick(),
		"sequence and client tick advance strictly across sends"
	)
	var rebound: Dictionary = source.bind(&"crew_a", 3)
	_check(int(rebound.stream_id) == 2, "rebinding opens a new stream so the sequence may restart")
	var oversized: Dictionary = source.advance(2, _sample(Vector2(3.0, 4.0)), 100)
	_check(
		Intent.from_dictionary(oversized).is_valid()
		and Intent.from_dictionary(oversized).get_move_axis().length() <= 1.0 + 0.000001,
		"an oversized local axis is clamped to the unit disc before it is framed"
	)


func _test_edges_survive_between_sends() -> void:
	var source := IntentSource.new(4)
	source.bind(&"crew_a", 1)
	var wires: Array = []
	for tick in 12:
		if tick == 1:
			source.request_jump()
		if tick == 2:
			source.request_interaction()
		var wire: Dictionary = source.advance(2, _sample(), 50)
		if not wire.is_empty():
			wires.append(wire)
	_check(wires.size() == 3, "twelve ticks send three intents")
	var carrying = Intent.from_dictionary(wires[1] as Dictionary)
	var after = Intent.from_dictionary(wires[2] as Dictionary)
	_check(
		carrying.has_jump_request() and carrying.get_interaction_request_id() == 1,
		"a jump and an interaction pressed between sends ride the next send"
	)
	_check(
		not after.has_jump_request() and after.get_interaction_request_id() == 1,
		"the jump edge is consumed by one send; the interaction id stays monotonic"
	)
	source.request_interaction()
	var next: Dictionary = {}
	for _tick in 4:
		var candidate: Dictionary = source.advance(2, _sample(), 50)
		if not candidate.is_empty():
			next = candidate
	_check(
		Intent.from_dictionary(next).get_interaction_request_id() == 2,
		"a second interaction request is a new id, never a repeat"
	)


func _test_stamp_tracks_the_observed_server_tick() -> void:
	var source := IntentSource.new(1)
	source.bind(&"crew_a", 1)
	_check(source.estimated_server_tick() == 0, "before any observation the estimate starts at zero")
	var wire: Dictionary = source.advance(2, _sample(), 120)
	_check(int(wire.client_tick) == 120, "the first stamp is the observed server tick")
	for _tick in 5:
		wire = source.advance(2, _sample(), 120)
	_check(
		int(wire.client_tick) == 125,
		"with no new observation the stamp advances one per local tick (%d)" % int(wire.client_tick)
	)
	wire = source.advance(2, _sample(), 140)
	_check(int(wire.client_tick) == 140, "a newer observation re-anchors the estimate")
	wire = source.advance(2, _sample(), 130)
	_check(
		int(wire.client_tick) == 141,
		"an older observation can never move a stream backwards (%d)" % int(wire.client_tick)
	)
	wire = source.advance(2, _sample(), -1)
	_check(int(wire.client_tick) == 142, "losing every relationship keeps the stream strictly ordered")


func _test_reconciliation_is_bounded() -> void:
	var source := IntentSource.new(1)
	source.bind(&"crew_a", 1)
	for tick in range(10, 20):
		source.record_local_pose(tick, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, float(tick) * 0.1)))
	var unknown: Dictionary = source.reconcile(5, Transform3D.IDENTITY, 0.5)
	_check(
		not bool(unknown.correct) and unknown.status == &"no_local_pose",
		"a server tick with no local pose on record corrects nothing"
	)
	var agree: Dictionary = source.reconcile(12, Transform3D(Basis.IDENTITY, Vector3(0.1, 0.5, 1.2)), 0.5)
	_check(
		not bool(agree.correct) and agree.status == &"within_tolerance" and float(agree.error_m) < 0.11,
		"a server pose within tolerance of the local one at the same stamp is left alone"
	)
	_check(
		int(source.get_audit().pose_history) == 7,
		"reconciling a tick retires every recorded pose at or before it"
	)
	var diverge: Dictionary = source.reconcile(15, Transform3D(Basis.IDENTITY, Vector3(2.0, 0.5, 1.5)), 0.5)
	_check(
		bool(diverge.correct) and diverge.status == &"corrected" and float(diverge.error_m) > 1.9,
		"a divergence past tolerance asks the caller to snap"
	)
	for tick in 400:
		source.record_local_pose(1000 + tick, Transform3D.IDENTITY)
	_check(
		int(source.get_audit().pose_history) <= IntentSource.MAX_POSE_HISTORY,
		"the pose history is a bounded ring"
	)
	var audit: Dictionary = source.get_audit()
	_check(
		int(audit.corrections) == 1 and not bool(audit.owns_movement_authority),
		"the audit counts corrections and claims no movement authority"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
