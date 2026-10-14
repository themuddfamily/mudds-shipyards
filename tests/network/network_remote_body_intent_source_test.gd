extends SceneTree

## Deterministic contract for the client-side on-foot intent stream: fixed
## cadence, edge latching, strictly ordered tick stamps derived from the
## observed server tick, and the bounded prediction reconciliation. No peer,
## no actors; only edge tests await the engine's actual physics-frame clock.
## The integration is `tests/network_remote_body_simulation_test.gd`.

const IntentSource := preload("res://scripts/network/network_remote_body_intent_source.gd")
const Authority := preload("res://scripts/network/network_movement_authority.gd")
const Intent := preload("res://scripts/network/network_movement_intent.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_cadence_and_framing()
	await _test_edges_survive_between_sends()
	await _test_same_physics_frame_interaction_is_one_edge()
	_test_stamp_tracks_the_observed_server_tick()
	_test_reconciliation_is_bounded()
	_test_delayed_correction_preserves_newer_movement()
	_test_reconciliation_between_cadence_samples()
	_test_prediction_history_on_unsent_physics_ticks()
	_test_future_authority_observations_do_not_starve_judgment()
	_test_rejected_opening_recovers()
	_test_established_future_clock_recovers()
	if _failures.is_empty():
		print("OK: network remote body intent source (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _sample(move_axis: Vector2 = Vector2.ZERO, run: bool = false) -> Dictionary:
	return {"move_axis": move_axis, "look_yaw": 0.5, "look_pitch": 0.1, "run": run, "crouch": false}


func _clock_refusal_reply(wire: Dictionary, result: Dictionary, authority: RefCounted) -> Dictionary:
	var reply := _opening_reply(wire, result, authority.get_server_tick())
	var ledger: Dictionary = authority.get_avatar_snapshot(wire.entity_id)
	reply["accepted_sequence"] = ledger.last_sequence
	reply["accepted_client_tick"] = ledger.last_client_tick
	return reply


func _consume_clock_refusal(source: RefCounted, peer: int, reply: Dictionary) -> Dictionary:
	return source.call(&"accept_clock_refusal", peer, reply) if source.has_method(&"accept_clock_refusal") else {}


func _test_established_future_clock_recovers() -> void:
	var authority := Authority.new(1)
	authority.configure_tick_window(1, 60, 6)
	authority.register_avatar(1, 2, &"crew_clock", 3)
	authority.set_server_tick(1, 200)
	var source := IntentSource.new(1)
	source.bind(&"crew_clock", 3)
	source.request_interaction()
	var opening: Dictionary = source.advance(2, _sample(), 200)
	var opened: Dictionary = authority.accept_intent(2, opening)
	source.accept_opening_result(2, _opening_reply(opening, opened, 200))
	var first: Dictionary = authority.consume_for_tick(&"crew_clock", 3, 200)
	source.record_local_pose(200, Transform3D.IDENTITY, 77)
	source.reconcile(200, Transform3D.IDENTITY)
	_check(opened.accepted and first.accepted and first.intent.interaction_request_id == 1,
		"established clock fixture delivers its original interaction once through the real ledger")
	var speculative: Dictionary = {}
	for _tick in 40:
		speculative = source.advance(2, _sample(Vector2(-1, 0)), -1)
	var refused: Dictionary = authority.accept_intent(2, speculative)
	source.record_local_pose(int(speculative.client_tick), Transform3D.IDENTITY, 77)
	source.reconcile(201, Transform3D.IDENTITY)
	_check(refused.status == &"client_tick_too_far_ahead", "real +6 authority refuses speculative established-stream timestamp after host stall")
	authority.set_server_tick(1, 201)
	source.observe_movement_clock(201)
	var stranded: Dictionary = source.advance(2, _sample(Vector2(-1, 0)), 201)
	var still_refused: Dictionary = authority.accept_intent(2, stranded)
	_check(stranded.client_tick > 207 and still_refused.status == &"client_tick_too_far_ahead",
		"fresh authentic host sample alone cannot discard the previous rejected sent floor")
	var reply := _clock_refusal_reply(stranded, still_refused, authority)
	var before := source.get_audit()
	for field in ["recipient_peer_id", "entity_generation", "stream_id", "client_tick", "accepted_sequence"]:
		var wrong := reply.duplicate(true)
		wrong[field] = int(wrong[field]) + (100 if field == "accepted_sequence" else 1)
		_check(not bool(_consume_clock_refusal(source, 2, wrong).get("accepted", false)) and source.get_audit() == before,
			"clock repair refuses mismatched " + field + " without changing current source")
	_check(not bool(_consume_clock_refusal(source, 3, reply).get("accepted", false)), "clock repair cannot be consumed by another owner peer")
	var repaired := _consume_clock_refusal(source, 2, reply)
	_check(source.estimated_server_tick() == 201, "fresh refusal also retires extrapolated time when its host tick matches the latest sample")
	authority.set_server_tick(1, 202)
	var current: Dictionary = source.advance(2, _sample(Vector2(1, 0)), 202)
	var accepted: Dictionary = authority.accept_intent(2, current)
	_check(bool(repaired.get("accepted", false)) and accepted.accepted and current.sequence > stranded.sequence and current.stream_id == opening.stream_id,
		"fresh exact ledger refusal repairs only speculative stamps within original +6 gate and same ordered stream")
	var delivered: Dictionary = authority.consume_for_tick(&"crew_clock", 3, int(current.client_tick))
	_check(delivered.accepted and Intent.from_dictionary(delivered.intent).get_move_axis() == Vector2(1, 0)
		and delivered.intent.interaction_request_id == first.intent.interaction_request_id and not bool(delivered.intent.jump),
		"repair builds a current input sample without replaying rejected movement or inventing a new interaction edge")
	source.record_local_pose(int(current.client_tick), Transform3D(Basis.IDENTITY, Vector3(2, 0, 0)), 77)
	var pose_audit := source.get_audit()
	_check(int(pose_audit.pose_history) == 1 and int(pose_audit.last_observed_pose_tick) == 201 and int(pose_audit.last_judged_tick) == 200,
		"repaired clock immediately retains a new local pose while preserving authority observation and judgment fences")
	var correction := source.reconcile(int(current.client_tick), Transform3D.IDENTITY, 0.05)
	_check(bool(correction.get("correct", false)) and (correction.get("correction_delta", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(-2, 0, 0)),
		"first repaired-clock local pose immediately reconciles against its real authoritative tick")
	_check(not bool(_consume_clock_refusal(source, 2, reply).get("accepted", false)) and not authority.accept_intent(2, opening).accepted,
		"duplicate clock refusal and already accepted opening cannot replay host actions")
	source.bind(&"crew_clock", 3)
	_check(not bool(_consume_clock_refusal(source, 2, reply).get("accepted", false)), "retired stream cannot repair a rebound source")


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
	await physics_frame
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


func _test_same_physics_frame_interaction_is_one_edge() -> void:
	var source := IntentSource.new(1)
	source.bind(&"crew_a", 1)
	# Production's sampler sends before the same-frame Player interaction signal.
	source.request_interaction()
	var sampled := source.advance(2, _sample(), 50)
	source.request_interaction()
	var signalled := source.advance(2, _sample(), 51)
	_check(sampled.interaction_request_id == 1 and signalled.interaction_request_id == 1,
		"same-frame sampler and Player signal deliver one host interaction across a cadence send")
	await physics_frame
	source.request_interaction()
	var next_press := source.advance(2, _sample(), 52)
	_check(next_press.interaction_request_id == 2,
		"a distinct press in the next physics frame retains its host interaction")
	source.unbind()
	source.bind(&"crew_b", 2)
	source.request_interaction()
	var rebound := source.advance(2, _sample(), 53)
	_check(rebound.entity_generation == 2 and rebound.interaction_request_id == 3,
		"same-frame stream rebind retires the old edge fence and preserves interaction highwater")


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
		"a divergence past tolerance asks the caller to correct the historical error"
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


func _test_delayed_correction_preserves_newer_movement() -> void:
	var source := IntentSource.new(1)
	source.bind(&"crew_a", 1)
	var judged := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, -7.9))
	var newer := Transform3D(Basis.IDENTITY, Vector3(1.0, 0.5, -5.8))
	source.record_local_pose(100, judged)
	source.record_local_pose(104, newer)
	var authoritative := judged
	authoritative.origin.x -= 0.8
	var correction := source.reconcile(100, authoritative)
	var translated := newer.origin + (correction.correction_delta as Vector3)
	_check(correction.correct and translated.is_equal_approx(Vector3(0.2, 0.5, -5.8))
		and (translated - authoritative.origin).is_equal_approx(newer.origin - judged.origin),
		"a delayed historical correction preserves the movement since its judged tick instead of rewinding to that old server pose")
	var later := Transform3D(newer.basis, translated)
	var matched := source.reconcile(104, later)
	_check(not matched.correct and matched.status == &"within_tolerance"
		and is_zero_approx(float(matched.error_m)) and source.get_audit().corrections == 1,
		"the retained newer pose receives the same translation so its matching judgment cannot repeat the correction")
	_check(not source.reconcile(100, authoritative).correct and source.get_audit().pose_history == 0,
		"retired historical judgments remain stale after a delayed correction")
	var escaped := Transform3D(Basis.IDENTITY, Vector3(20.0, 0.5, -5.8))
	var clamped := Transform3D(Basis.IDENTITY, Vector3(2.6, 0.5, -5.8))
	source.record_local_pose(108, escaped)
	var containment := source.reconcile(108, clamped)
	_check(containment.correct and (escaped.origin + (containment.correction_delta as Vector3)).is_equal_approx(clamped.origin),
		"a genuine authoritative cabin-boundary correction still removes the entire out-of-bounds error")


func _test_reconciliation_between_cadence_samples() -> void:
	var source := IntentSource.new(4)
	source.bind(&"crew_a", 1)
	# The authority publishes on ticks that do not coincide with the client's
	# four-tick sends. Only gaps within that cadence may be interpolated.
	for tick in [100, 104, 108, 112]:
		source.record_local_pose(tick, Transform3D(Basis.IDENTITY, Vector3(float(tick - 100) * 0.1, 0.5, -4.8)))
	var correction := source.reconcile(106, Transform3D(Basis.IDENTITY, Vector3(-0.6, 0.5, -4.8)))
	_check(correction.correct and is_equal_approx(float(correction.error_m), 1.2)
		and (correction.correction_delta as Vector3).is_equal_approx(Vector3(-1.2, 0.0, 0.0)),
		"a publication between cadence samples corrects the interpolated historical error")
	_check(source.get_audit().pose_history == 2,
		"an interpolated judgment retires only samples at or before its tick")
	var later := source.reconcile(111, Transform3D(Basis.IDENTITY, Vector3(-0.1, 0.5, -4.8)))
	_check(not later.correct and later.status == &"within_tolerance" and is_zero_approx(float(later.error_m)),
		"newer interpolated judgments include the earlier translation without repeating the correction")
	_check(not source.reconcile(106, Transform3D.IDENTITY).correct
		and not source.reconcile(114, Transform3D.IDENTITY).correct
		and source.get_audit().corrections == 1,
		"retired or future ticks never extrapolate a current-pose correction")
	source.record_local_pose(120, Transform3D.IDENTITY)
	_check(not source.reconcile(116, Transform3D.IDENTITY).correct,
		"a clock gap longer than one intent cadence cannot manufacture a historical pose")
	source.bind(&"crew_a", 1)
	source.record_local_pose(200, Transform3D.IDENTITY, 1)
	source.record_local_pose(204, Transform3D.IDENTITY, 2)
	_check(not source.reconcile(202, Transform3D.IDENTITY).correct,
		"a frame replacement discards the prior frame instead of interpolating across it")
	source.record_local_pose(203, Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)), 2)
	_check(not source.reconcile(203, Transform3D.IDENTITY).correct,
		"out-of-order pose samples cannot reopen a retired history interval")
	source.clear_pose_history()
	source.record_local_pose(208, Transform3D.IDENTITY, 2)
	_check(not source.reconcile(206, Transform3D.IDENTITY).correct,
		"a seat or disembark history reset cannot bridge a physical transition")
	for replacement_tick in [200, 199]:
		source.bind(&"crew_a", 1)
		source.record_local_pose(200, Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)), 1)
		source.record_local_pose(replacement_tick, Transform3D.IDENTITY, 2)
		_check(not source.reconcile(200, Transform3D.IDENTITY).correct and source.get_audit().pose_history == 0,
			"a frame replacement at a repeated or backward clock stamp retires the old frame before tick refusal")
		source.record_local_pose(201, Transform3D.IDENTITY, 2)
		_check(not source.reconcile(201, Transform3D.IDENTITY).correct and source.get_audit().pose_history == 0,
			"the new frame resumes at the next increasing stamp without retaining old-frame divergence")


func _test_prediction_history_on_unsent_physics_ticks() -> void:
	var authority := Authority.new(1)
	authority.register_avatar(1, 2, &"crew_a", 1)
	var source := IntentSource.new(4)
	source.bind(&"crew_a", 1)
	var sent := 0
	for tick in range(100, 112):
		authority.set_server_tick(1, tick)
		var wire := source.advance(2, _sample(), tick)
		if not wire.is_empty():
			sent += 1
			_check(authority.accept_intent(2, wire).accepted,
				"the unchanged authority admits the ordinary cadence intent")
		authority.consume_for_tick(&"crew_a", 1, tick)
		source.record_local_pose(source.estimated_server_tick(),
			Transform3D(Basis.IDENTITY, Vector3(float(tick - 100) * 0.1, 0.5, -4.8)))
	_check(sent == 3 and source.get_audit().pose_history == 12,
		"twelve simulated physics ticks retain twelve poses while still sending only three packets")
	var correction := source.reconcile(authority.get_server_tick(),
		Transform3D(Basis.IDENTITY, Vector3(-0.7, 0.5, -4.8)))
	_check(correction.correct and is_equal_approx(float(correction.error_m), 1.8),
		"an actual authoritative tick outside the send phase corrects a hatch-sized body disagreement")


func _test_future_authority_observations_do_not_starve_judgment() -> void:
	var source := IntentSource.new(4)
	source.bind(&"crew_a", 1)
	var translation := Vector3.ZERO
	for tick in range(100, 107):
		source.record_local_pose(tick, Transform3D(Basis.IDENTITY, Vector3(float(tick - 100) * 0.1, 0.5, -4.8) + translation), 1)
		# Each real authority sample arrives three ticks ahead. The newest sample
		# is never directly comparable with history on its delivery tick.
		var verdict := source.reconcile(tick + 3,
			Transform3D(Basis.IDENTITY, Vector3(float(tick + 3 - 100) * 0.1 - 1.8, 0.5, -4.8)))
		if verdict.correct:
			translation += verdict.correction_delta as Vector3
		if tick == 102:
			_check(not verdict.correct and source.get_audit().pending_pose_tick == 103
				and source.get_audit().last_judged_tick == -1,
				"future samples retain one actual authority observation without extrapolating or advancing the judged fence")
	_check(source.get_audit().last_observed_pose_tick == 109 and source.get_audit().last_judged_tick == 106
		and source.get_audit().corrections == 1 and translation.is_equal_approx(Vector3(-1.8, 0.0, 0.0)),
		"a continuously advancing future stream eventually judges its retained actual ticks and corrects one historical hatch-sized error")
	var stale := source.reconcile(105, Transform3D.IDENTITY)
	_check(not stale.correct and source.get_audit().pending_pose_tick == 109,
		"older authority traffic cannot replace a pending observation or rewind the observed fence")
	source.record_local_pose(107, Transform3D.IDENTITY, 2)
	_check(source.get_audit().pending_pose_tick == -1 and source.get_audit().last_observed_pose_tick == 109,
		"a frame change retires pending authority work while preserving the observed stream fence")
	source.reconcile(110, Transform3D.IDENTITY)
	source.clear_pose_history()
	_check(source.get_audit().pending_pose_tick == -1,
		"seat and physical transition history resets also retire future authority observations")
	source.bind(&"crew_a", 2)
	_check(source.get_audit().pending_pose_tick == -1 and source.get_audit().last_observed_pose_tick == -1
		and source.get_audit().last_judged_tick == -1,
		"a new body stream cannot inherit pending observations or prior tick fences")


func _opening_reply(wire: Dictionary, result: Dictionary, server_tick: int) -> Dictionary:
	return {
		"recipient_peer_id": int(wire.peer_id), "entity_id": wire.entity_id,
		"entity_generation": wire.entity_generation, "stream_id": wire.stream_id,
		"sequence": wire.sequence, "client_tick": wire.client_tick,
		"server_tick": server_tick, "accepted": bool(result.accepted), "status": result.status,
	}


func _test_rejected_opening_recovers() -> void:
	var authority := Authority.new(1)
	authority.register_avatar(1, 2, &"crew_a", 3)
	authority.set_server_tick(1, 200)
	var source := IntentSource.new(1)
	source.bind(&"crew_a", 3)
	source.request_jump()
	source.request_interaction()
	var initial: Dictionary = source.advance(2, _sample(), 0)
	var refused: Dictionary = authority.accept_intent(2, initial)
	_check(not refused.accepted and refused.status == &"client_tick_too_old", "real authority rejects opening zero before committing its stream")
	var stranded: Dictionary = source.advance(2, _sample(), 200)
	_check(authority.accept_intent(2, stranded).status == &"new_stream_must_start_at_zero", "fresh later sequence cannot bypass strict stream opening")
	var reply := _opening_reply(initial, refused, 200)
	var wrong := reply.duplicate(true)
	wrong.entity_generation += 1
	_check(not source.accept_opening_result(2, wrong).accepted, "retired body opening reply cannot rewind current source")
	wrong = reply.duplicate(true)
	wrong.client_tick += 1
	_check(not source.accept_opening_result(2, wrong).accepted and not source.accept_opening_result(3, reply).accepted, "opening reply needs exact outstanding zero stamp and owner peer")
	_check(source.accept_opening_result(2, reply).status == &"opening_retry_queued", "honest clock refusal queues same-owner restamped opening")
	_check(not source.accept_opening_result(2, reply).accepted, "duplicate refusal cannot reset a queued retry")
	var retry: Dictionary = source.advance(2, _sample(), 200)
	_check(retry.stream_id == initial.stream_id and retry.sequence == 0 and retry.client_tick == 200, "retry keeps exact stream identity and strict zero with fresh host clock")
	_check(bool(retry.jump) and retry.interaction_request_id == initial.interaction_request_id, "refused opening restores jump and retains interaction highwater")
	var accepted: Dictionary = authority.accept_intent(2, retry)
	_check(accepted.accepted and source.accept_opening_result(2, _opening_reply(retry, accepted, 200)).status == &"opening_confirmed", "actual authority accepts retry and confirms this exact opening")
	var delivered: Dictionary = authority.consume_for_tick(&"crew_a", 3, 200)
	_check(delivered.accepted and bool(delivered.intent.jump) and delivered.intent.interaction_request_id == 1, "recovered edge requests reach authority delivery once")
	_check(not authority.consume_for_tick(&"crew_a", 3, 201).accepted and not source.accept_opening_result(2, reply).accepted, "delayed clock refusal cannot replay delivered edges or rewind established stream")
	var next: Dictionary = source.advance(2, _sample(Vector2(0, -1)), 201)
	_check(next.sequence == 1 and not bool(next.jump) and next.interaction_request_id == 1 and authority.accept_intent(2, next).accepted, "ordinary movement advances normally after acknowledged opening without new edges")
	_check(not authority.accept_intent(2, retry).accepted and authority.accept_intent(2, initial).status == &"client_tick_too_old", "strict replay and tick fences remain active after recovery")
	source.bind(&"crew_a", 3)
	_check(not source.accept_opening_result(2, _opening_reply(retry, accepted, 200)).accepted, "retired stream acknowledgement cannot establish a rebound producer")
	source.unbind()
	_check(not source.accept_opening_result(2, reply).accepted, "unbound producer ignores late opening replies")
	var ahead := IntentSource.new(4)
	ahead.bind(&"crew_a", 3, 3)
	var future: Dictionary = ahead.advance(2, _sample(), 500)
	var too_far: Dictionary = authority.accept_intent(2, future)
	var movement_clock := authority.get_server_tick()
	ahead.observe_movement_clock(movement_clock)
	_check(ahead.has_authoritative_movement_clock() and ahead.estimated_server_tick() == movement_clock and too_far.status == &"client_tick_too_far_ahead" and ahead.accept_opening_result(2, _opening_reply(future, too_far, movement_clock)).accepted, "unaccepted future opening can use exact authority clock correction")
	authority.set_server_tick(1, movement_clock + 1)
	ahead.observe_movement_clock(authority.get_server_tick())
	movement_clock = authority.get_server_tick()
	var corrected: Dictionary = ahead.advance(2, _sample(), 500)
	var corrected_result: Dictionary = authority.accept_intent(2, corrected)
	_check(corrected.sequence == 0 and corrected.client_tick == movement_clock and corrected_result.accepted, "future opening restamps backwards without relaxing host tick or stream fences")
	ahead.accept_opening_result(2, _opening_reply(corrected, corrected_result, movement_clock))
	var resumed: Dictionary = {}
	for _tick in 4:
		var candidate: Dictionary = ahead.advance(2, _sample(Vector2(0, -1)), -1)
		if not candidate.is_empty():
			resumed = candidate
	authority.set_server_tick(1, movement_clock + 4)
	_check(ahead.has_authoritative_movement_clock() and resumed.client_tick == movement_clock + 4
		and resumed.sequence == 1 and authority.accept_intent(2, resumed).accepted,
		"body clock continues at physics cadence in movement domain while unrelated boarding clock remains 500")

	var observed := IntentSource.new(1)
	observed.bind(&"crew_a", 3, 4)
	var opening: Dictionary = observed.advance(2, _sample(), authority.get_server_tick())
	var opening_result: Dictionary = authority.accept_intent(2, opening)
	var delayed := _opening_reply(opening, opening_result, authority.get_server_tick())
	authority.set_server_tick(1, authority.get_server_tick() + 100)
	observed.observe_movement_clock(authority.get_server_tick())
	var confirmation: Dictionary = observed.accept_opening_result(2, delayed)
	var continued: Dictionary = observed.advance(2, _sample(), -1)
	_check(opening_result.accepted and confirmation.status == &"opening_confirmed"
		and continued.client_tick == authority.get_server_tick() + 1 and authority.accept_intent(2, continued).accepted,
		"first actual movement sample establishes trust and delayed accepted opening cannot rewind its newer clock")


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
