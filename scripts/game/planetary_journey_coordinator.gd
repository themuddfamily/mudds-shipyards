extends RefCounted
## Retained owner of the one Ember expedition and its station-return handoffs.
## GameFlow calls advance_world at its existing early physics priority; actors
## still move themselves and the surface binding alone consumes the late tick.
## Dependencies are observed through the retained Main. Berth leases, boarding,
## reward persistence and ordinary yard lifecycle remain with their owners.

## Bounded retries for arming an abandoned visit's return approach. The craft is
## flyable and under manual control throughout; this only stops a permanently
## refused arm from asking every tick forever.
const MAX_ABANDON_RETURN_ARM_ATTEMPTS := 900

const MAX_TRANSIT_RESUME_ATTEMPTS := 600
var _last_ember_origin_announcement: Dictionary = {}
var _ember_outbound_resume_attempts := 0
var _last_ember_outbound_resume_result: Dictionary = {}

var _flow: GameFlow

var _planetary_return_receipt_consumed := false
var _planetary_cruise_caller_tick := 0
var _ember_surface_caller_serial := 0
var _pending_ember_surface_request: Dictionary = {}
var _pending_ember_surface_host: Object
var _pending_ember_surface_director: ActivityDirector
var _pending_ember_surface_reward_sink := Callable()
var _pending_ember_surface_serial := 0
var _last_ember_surface_forward_result: Dictionary = {}
## The most recent surface-cadence outcome, retained as diagnostics only. A
## stalled Host is almost always a refused cadence tick, and this names it.
var _last_ember_surface_cadence_result: Dictionary = {}
## The most recent refused common-world rebase, retained as diagnostics only.
var _last_ember_origin_rejection: Dictionary = {}
var _ember_surface_forward_count := 0
var _ember_survey_start_context: Dictionary = {}
var _ember_survey_return_manifest: Dictionary = {}
var _ember_surface_journey_active := false
## An expedition the player gave up on. The Host holds the abandon until the
## craft is airborne again, so a pilot on the caldera keeps their objective and
## their craft's pad lease until they have boarded it.
var _ember_surface_abandon_pending := false
var _ember_surface_abandon_reason: StringName = &""
var _ember_surface_abandon_count := 0
var _ember_abandon_observed_commit_count := 0
var _last_ember_surface_abandon_result: Dictionary = {}
## The abandoned visit's way home: the same Mudds return approach the completed
## loop arms, without the station-return contract an abandoned visit never
## earned. Arming can be refused while the craft is still climbing out of the
## caldera, so it is retried on the ordinary cadence until it takes.
var _ember_abandon_return_active := false
var _ember_abandon_return_arm_pending := false
var _ember_abandon_return_arm_attempts := 0
var _last_ember_abandon_return_arm_result: Dictionary = {}
var _ember_final_approach_handoff_ready := false
var _ember_final_approach_completion_receipt: Dictionary = {}
var _ember_final_approach_rearm_count := 0
var _last_ember_final_approach_rearm_result: Dictionary = {}
var _mudds_return_handback_consumption_attempted := false
var _mudds_return_handback_receipt: Dictionary = {}
var _mudds_station_return_intent_consumption_attempted := false
var _mudds_station_return_intent_receipt: Dictionary = {}
var _last_mudds_station_return_intent_result: Dictionary = {}
var _mudds_return_approach_active := false
var _mudds_return_approach_completion_attempted := false
var _mudds_return_approach_completion_receipt: Dictionary = {}
var _last_mudds_return_approach_result: Dictionary = {}
## The Aurora visit lane. Aurora is the second world the planetary subsystem
## serves, and it is admitted, cruised, streamed, rebased and approached through
## exactly the components Ember uses - the one cruise binding pointed at
## Aurora's bootstrap, the one common-world origin owner, and Aurora's own
## streaming binding. It has no surface Host: a coastal visit has no expedition
## loop to run, so the visit itself owns embodiment once the craft is docked.
var _aurora_visit_active := false
var _aurora_return_active := false
var _aurora_return_departure_pending := false
var _aurora_return_handoff_ready := false
var _aurora_return_arm_attempts := 0
var _last_aurora_return_result: Dictionary = {}
var _aurora_visit_rebase_commit_count := 0
var _aurora_final_approach_handoff_ready := false
var _aurora_final_approach_armed := false
var _aurora_final_approach_source_ref: WeakRef
var _aurora_final_approach_completion_receipt: Dictionary = {}
var _last_aurora_streaming_result: Dictionary = {}
var _last_aurora_origin_result: Dictionary = {}
var _last_aurora_cruise_result: Dictionary = {}
var _last_aurora_admission_result: Dictionary = {}
var _last_aurora_retirement_result: Dictionary = {}
var _planetary_return_physical_arrival_required := false
var _planetary_return_physical_arrival_armed := false
var _last_planetary_return_physical_arrival_result: Dictionary = {}


func _init(flow: GameFlow) -> void:
	_flow = flow


func advance_world(delta: float, actor_sample: Dictionary) -> Dictionary:
	var coordinate_frame_generation := 0
	# A live cruise requires the same accepted Ember streaming observation that
	# supplied its frame/sample. A frame commit alone is insufficient: the
	# binding reconciles its generation before reporting the resulting streaming
	# transition, which can still reject (for example, a load failure).
	var ember_streaming_accepted := false
	var ember_origin_result: Dictionary = {}
	# A required rebase may enter Ember's load envelope. In that exact case, an
	# asynchronous `load_requested` acknowledgement is not yet a physical world
	# root for HeroShip's collision proof; do not queue cruise until it exists.
	var ember_streaming_residency_required := false
	# Cruise may decode its canonical destination only after an origin rebase
	# required by this exact actor observation has committed. A rejected owner
	# transaction leaves the source frame live, but that frame is not a valid
	# substitute for the required post-rebase handoff.
	var required_origin_rebase_uncommitted := false
	if is_instance_valid(_flow.ember_streaming_binding):
		var ember_tick := _flow.ember_streaming_binding.physics_tick_from_caller_sample(
			delta, actor_sample
		)
		ember_streaming_accepted = bool(ember_tick.get("accepted", false))
		coordinate_frame_generation = int(
			ember_tick.get("coordinate_frame_generation", 0)
		)
		if ember_tick.has("coordinate_frame_generation"):
			var preview := _flow.ember_streaming_binding.preview_origin_rebase(
				int(ember_tick.get("coordinate_frame_generation", 0))
			)
			if bool(preview.get("accepted", false)):
				var preview_requires_rebase := bool(preview.get("rebase_required", false))
				required_origin_rebase_uncommitted = preview_requires_rebase
				if is_instance_valid(_flow.common_world_origin_rebase_owner):
					var rebase := _flow.common_world_origin_rebase_owner.consume_rebase_preview(
						preview, actor_sample
					)
					if preview_requires_rebase \
							and not bool(rebase.get("accepted", false)):
						_last_ember_origin_rejection = {
							"reason": rebase.get("reason", &"origin_rebase_rejected"),
							"coordinate_frame_generation": coordinate_frame_generation,
						}.duplicate(true)
					if bool(rebase.get("accepted", false)):
						ember_origin_result = rebase.duplicate(true)
					if bool(rebase.get("accepted", false)) and rebase.has("actor_sample"):
						actor_sample = (rebase.get("actor_sample", {}) as Dictionary).duplicate(true)
						coordinate_frame_generation = int(
							rebase.get(
								"coordinate_frame_generation",
								coordinate_frame_generation,
							)
							)
						if preview_requires_rebase:
							required_origin_rebase_uncommitted = false
							var receipt := rebase.get("receipt", {}) as Dictionary
							var streaming := receipt.get("world_streaming", {}) as Dictionary
							ember_streaming_accepted = bool(streaming.get("accepted", false))
							ember_streaming_residency_required = (
								ember_streaming_accepted
								and streaming.get("action", &"") == &"load"
							)
	if ember_origin_result.is_empty() and ember_streaming_accepted \
			and not required_origin_rebase_uncommitted \
			and coordinate_frame_generation > 0:
		ember_origin_result = {
			"accepted": true,
			"actor_sample": actor_sample.duplicate(true),
			"coordinate_frame_generation": coordinate_frame_generation,
			"reason": &"no_rebase_required",
		}.duplicate(true)
	if ember_origin_result.get("reason", &"") == &"rebase_committed":
		_last_ember_origin_announcement = _announce_committed_origin_rebase(
			ember_origin_result.get("receipt", {}) as Dictionary)
	var ember_host_bind_result := _ensure_ember_surface_loop_host_bound(
		ember_streaming_accepted and not required_origin_rebase_uncommitted
	)
	if bool(ember_host_bind_result.get("accepted", false)):
		_flow._ensure_ember_surface_presentations()
	if bool(ember_host_bind_result.get("accepted", false)) \
			and not _pending_ember_surface_request.is_empty():
		_last_ember_surface_forward_result = _forward_pending_ember_surface_journey()
		if bool(_last_ember_surface_forward_result.get("accepted", false)):
			_ember_surface_forward_count += 1
	_advance_ember_surface_abandon(coordinate_frame_generation)
	if _ember_surface_journey_active:
		if required_origin_rebase_uncommitted or not ember_streaming_accepted:
			_last_ember_final_approach_rearm_result = {
				"accepted": false,
				"reason": &"ember_final_approach_rearm_observation_unavailable",
			}.duplicate(true)
		else:
			_last_ember_final_approach_rearm_result = \
				_rearm_retired_ember_final_approach()
			if bool(_last_ember_final_approach_rearm_result.get("accepted", false)):
				_ember_final_approach_rearm_count += 1
	if not required_origin_rebase_uncommitted and ember_streaming_accepted:
		_last_ember_outbound_resume_result = _resume_ember_outbound_transit(coordinate_frame_generation)
	if not required_origin_rebase_uncommitted:
		_consume_mudds_station_return_handoff_intent(
			coordinate_frame_generation
		)
		_advance_mudds_return_approach_handoff(coordinate_frame_generation)
	if is_instance_valid(_flow.planetary_cruise_binding):
		var cruise_gate_reason := _flow._planetary_cruise_gate_reason(false)
		var return_approach_cadence := (
			_mudds_return_approach_active
			and not _mudds_return_approach_completion_attempted
		)
		if required_origin_rebase_uncommitted:
			cruise_gate_reason = &"origin_rebase_required"
		elif not return_approach_cadence and not ember_streaming_accepted:
			cruise_gate_reason = &"ember_streaming_unavailable"
		elif (
			not return_approach_cadence
			and
			ember_streaming_residency_required
			and (
				not is_instance_valid(_flow.ember_streaming_bootstrap)
				or not is_instance_valid(_flow.ember_streaming_bootstrap.get_loaded_instance())
			)
		):
			cruise_gate_reason = &"ember_streaming_pending"
		if _planetary_cruise_caller_tick >= _flow.PLANETARY_CRUISE_MAX_CALLER_TICK:
			_flow.planetary_cruise_binding.request_caller_tick_exhausted(
				_flow.planetary_cruise_binding.get_generation()
			)
		else:
			_planetary_cruise_caller_tick += 1
			var location_generation := _flow.ember_surface_loop_host.get_location_generation() \
				if is_instance_valid(_flow.ember_surface_loop_host) else 0
			var cruise_tick := _flow.planetary_cruise_binding.physics_tick_from_caller_sample(
				_planetary_cruise_caller_tick,
				actor_sample,
				_flow.active_ship,
				coordinate_frame_generation,
				_flow._planetary_cruise_combat_active(),
				cruise_gate_reason,
				location_generation,
			)
			if return_approach_cadence:
				_observe_abandon_return_departure_tick(cruise_tick)
			if cruise_tick.get("reason") == &"final_approach_handoff_ready":
				_consume_ember_final_approach_completion(cruise_tick)
			elif cruise_tick.get("reason") == &"return_approach_handoff_ready":
				_consume_mudds_return_approach_completion(cruise_tick)
			elif return_approach_cadence \
					and not bool(cruise_tick.get("accepted", false)):
				_mudds_return_approach_active = false
				_ember_surface_journey_active = false
				_last_mudds_return_approach_result = cruise_tick.duplicate(true)
	# The completing cruise tick releases its Hero attachment before this one
	# retained late Host envelope is prepared. Keeping both operations in the same
	# GameFlow callback prevents a new origin transaction from reaching an IDLE
	# Host between completion and start; the priority-2 surface binding still
	# performs the one actual Host.start() after Hero's current physics tick.
	_last_ember_surface_cadence_result = _advance_ember_surface_loop_cadence(
		delta, actor_sample, ember_origin_result, coordinate_frame_generation
	)
	_flow._sync_planetary_cruise_hud()
	return actor_sample



# --- the Aurora visit lane ----------------------------------------------------


## Admits one Aurora visit: points the one cruise binding at Aurora's bootstrap,
## makes sure the origin owner holds Aurora's pair, and engages the cruise. No
## craft moves here; the first accepted lane tick is what starts the trip.
func admit_aurora_visit(ship: HeroShip, engage_cruise: bool = true) -> Dictionary:
	if _aurora_visit_active:
		return _aurora_admitted(false, &"aurora_visit_already_active")
	if _ember_surface_journey_active or not _pending_ember_surface_request.is_empty():
		return _aurora_admitted(false, &"ember_surface_journey_active")
	if not is_instance_valid(ship) or ship.is_destroyed() \
			or (engage_cruise and not ship.is_piloted()):
		return _aurora_admitted(false, &"aurora_visit_craft_unavailable")
	if not is_instance_valid(_flow.aurora_streaming_bootstrap) \
			or not is_instance_valid(_flow.aurora_streaming_binding) \
			or not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.common_world_origin_rebase_owner):
		return _aurora_admitted(false, &"aurora_composition_unavailable")
	var owner_rebind := _flow.common_world_origin_rebase_owner.rebind_composed_worlds()
	if not bool(owner_rebind.get("accepted", false)) \
			or not owner_rebind.get("world_count", 0) is int \
			or not _flow.common_world_origin_rebase_owner.get_bound_world_ids().has(
				String(AuroraTemperateStreamingBootstrap.WORLD_ID)
			):
		return _aurora_admitted(false, &"aurora_origin_owner_unbound")
	var bound := _flow.planetary_cruise_binding.bind_world(
		_flow.aurora_streaming_bootstrap
	)
	if not bool(bound.get("accepted", false)):
		return _aurora_admitted(
			false, bound.get("reason", &"aurora_cruise_bind_refused") as StringName
		)
	var frame := _flow.aurora_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return _aurora_admitted(false, &"aurora_coordinate_frame_unavailable")
	var engaged: Dictionary = {"accepted": true, "reason": &"cruise_not_requested"}
	if engage_cruise:
		engaged = _flow.planetary_cruise_binding.request_engage(
			ship, frame.get_generation(), &"",
			_flow.planetary_cruise_binding.get_generation(),
		)
	if not bool(engaged.get("accepted", false)):
		_restore_ember_cruise_binding()
		return _aurora_admitted(
			false, engaged.get("reason", &"aurora_cruise_engage_refused") as StringName
		)
	_aurora_visit_active = true
	_aurora_visit_rebase_commit_count = 0
	_aurora_final_approach_handoff_ready = false
	_aurora_final_approach_armed = false
	_aurora_final_approach_source_ref = null
	_aurora_final_approach_completion_receipt.clear()
	_last_aurora_streaming_result.clear()
	_last_aurora_origin_result.clear()
	_last_aurora_cruise_result.clear()
	return _aurora_admitted(true, &"aurora_visit_admitted", {
		"coordinate_frame_generation": frame.get_generation(),
	})


## One physics tick of the Aurora lane, in the same order Ember's runs: the
## world's own streaming observation, then the caller-owned origin transaction,
## then the cruise. Returns the actor sample later consumers must use, which is
## the translated one whenever a rebase committed on this tick.
func advance_aurora_visit(delta: float, actor_sample: Dictionary) -> Dictionary:
	if not _aurora_visit_active:
		return {"accepted": false, "reason": &"aurora_visit_inactive",
			"actor_sample": actor_sample.duplicate(true)}
	var binding := _flow.aurora_streaming_binding
	var bootstrap := _flow.aurora_streaming_bootstrap
	if not is_instance_valid(binding) or not is_instance_valid(bootstrap):
		return {"accepted": false, "reason": &"aurora_composition_unavailable",
			"actor_sample": actor_sample.duplicate(true)}
	var streaming_tick := binding.physics_tick_from_caller_sample(delta, actor_sample)
	_last_aurora_streaming_result = streaming_tick.duplicate(true)
	var streaming_accepted := bool(streaming_tick.get("accepted", false))
	var coordinate_frame_generation := int(
		streaming_tick.get("coordinate_frame_generation", 0)
	)
	var residency_required := false
	var rebase_uncommitted := false
	var origin_adoption_rejected := false
	if streaming_tick.has("coordinate_frame_generation"):
		var preview := binding.preview_origin_rebase(coordinate_frame_generation)
		if bool(preview.get("accepted", false)):
			var required := bool(preview.get("rebase_required", false))
			rebase_uncommitted = required
			var rebase := _flow.common_world_origin_rebase_owner.consume_rebase_preview(
				preview, actor_sample
			)
			_last_aurora_origin_result = rebase.duplicate(true)
			if required and bool(rebase.get("accepted", false)):
				rebase_uncommitted = false
				_aurora_visit_rebase_commit_count += 1
				actor_sample = (
					rebase.get("actor_sample", {}) as Dictionary
				).duplicate(true)
				coordinate_frame_generation = int(rebase.get(
					"coordinate_frame_generation", coordinate_frame_generation
				))
				var committed_streaming := (
					rebase.get("receipt", {}) as Dictionary
				).get("world_streaming", {}) as Dictionary
				streaming_accepted = bool(committed_streaming.get("accepted", false))
				residency_required = streaming_accepted \
					and committed_streaming.get("action", &"") == &"load"
				var adopted := _adopt_aurora_origin_receipt(
					rebase.get("receipt", {}) as Dictionary)
				_last_aurora_origin_result["adoption"] = adopted.duplicate(true)
				origin_adoption_rejected = not bool(adopted.get("accepted", false))
	var gate_reason: StringName = _aurora_cruise_gate_reason()
	if origin_adoption_rejected:
		gate_reason = &"aurora_origin_adoption_rejected"
	elif rebase_uncommitted:
		gate_reason = &"origin_rebase_required"
	elif not streaming_accepted:
		gate_reason = &"aurora_streaming_unavailable"
	elif residency_required and not is_instance_valid(bootstrap.get_loaded_instance()):
		gate_reason = &"aurora_streaming_pending"
	if _aurora_return_departure_pending and not _mudds_return_approach_active:
		_retry_aurora_return_approach(coordinate_frame_generation)
	# The cruise only participates while the craft is actually travelling. Once
	# the visit has landed and disengaged, the lane keeps streaming and rebasing
	# without pretending a cruise is in flight.
	if is_instance_valid(_flow.planetary_cruise_binding) and bool(
		_flow.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)
	):
		if _planetary_cruise_caller_tick >= _flow.PLANETARY_CRUISE_MAX_CALLER_TICK:
			_flow.planetary_cruise_binding.request_caller_tick_exhausted(
				_flow.planetary_cruise_binding.get_generation()
			)
		else:
			_planetary_cruise_caller_tick += 1
			var cruise_tick := _flow.planetary_cruise_binding.physics_tick_from_caller_sample(
				_planetary_cruise_caller_tick,
				actor_sample,
				_flow.active_ship,
				coordinate_frame_generation,
				_flow._planetary_cruise_combat_active(),
				gate_reason,
				int(bootstrap.get_snapshot().get("location_generation", 0)),
			)
			_last_aurora_cruise_result = cruise_tick.duplicate(true)
			_observe_aurora_return_tick(cruise_tick)
			if cruise_tick.get("reason") == &"final_approach_handoff_ready":
				var consumed := _flow.planetary_cruise_binding.consume_final_approach_completion(
					int(cruise_tick.get("target_generation", 0)),
					_flow.planetary_cruise_binding.get_generation(),
				)
				if bool(consumed.get("accepted", false)):
					_aurora_final_approach_completion_receipt = consumed.duplicate(true)
					_aurora_final_approach_handoff_ready = true
			if not _aurora_final_approach_handoff_ready and not bool(
					_flow.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)):
				_aurora_final_approach_armed = false
	return {
		"accepted": true,
		"reason": &"aurora_visit_advanced",
		"actor_sample": actor_sample.duplicate(true),
		"coordinate_frame_generation": coordinate_frame_generation,
		"streaming_accepted": streaming_accepted,
		"gate_reason": gate_reason,
		"rebase_commit_count": _aurora_visit_rebase_commit_count,
		"final_approach_handoff_ready": _aurora_final_approach_handoff_ready,
	}.duplicate(true)


## RETURN revokes the consumed outbound source, not the landed craft's lease.
## The pilot owns lift-off; the existing cruise admits flight after clearance.
func begin_aurora_return() -> Dictionary:
	if not _aurora_visit_active or _aurora_return_active:
		return {"accepted": false, "reason": &"aurora_return_unavailable"}
	if not is_instance_valid(_flow.active_ship) or not _flow.active_ship.is_piloted():
		return {"accepted": false, "reason": &"pilot_unseated"}
	_aurora_final_approach_source_ref = null
	_aurora_final_approach_armed = false
	_aurora_return_active = true
	_aurora_return_departure_pending = true
	_aurora_return_handoff_ready = false
	_aurora_return_arm_attempts = 0
	_mudds_return_approach_active = false
	_mudds_return_approach_completion_attempted = false
	_mudds_return_approach_completion_receipt.clear()
	_last_aurora_return_result = {"accepted": true, "reason": &"manual_departure_required"}
	return _last_aurora_return_result.duplicate(true)


func _retry_aurora_return_approach(frame_generation: int) -> void:
	var gate := _aurora_cruise_gate_reason()
	if not gate.is_empty():
		if gate != &"origin_rebase_pending":
			cancel_return_departure(gate)
		return
	var ship := _flow.active_ship
	if ship.has_manual_flight_intent() or bool(ship.get_telemetry().get("landed", true)):
		_last_aurora_return_result = {"accepted": false, "reason": &"manual_departure_required"}
		return
	if _aurora_return_arm_attempts >= MAX_ABANDON_RETURN_ARM_ATTEMPTS:
		cancel_return_departure(&"aurora_return_arm_exhausted")
		return
	_aurora_return_arm_attempts += 1
	var target := _build_mudds_return_approach_target()
	if not bool(target.get("accepted", false)):
		cancel_return_departure(StringName(target.get("reason", &"return_target_unavailable")))
		return
	var cruise := _flow.planetary_cruise_binding
	var engaged := engage_aurora_cruise(ship, true)
	if not bool(engaged.get("accepted", false)):
		_last_aurora_return_result = engaged.duplicate(true)
		if engaged.get("reason") != &"braking_in_progress":
			cancel_return_departure(StringName(engaged.get("reason", &"return_engagement_refused")))
		return
	var armed := cruise.request_return_approach(
		target.get("target", {}) as Dictionary, frame_generation,
		cruise.get_generation(), _flow.world.ship_spawn)
	_last_aurora_return_result = armed.duplicate(true)
	if not bool(armed.get("accepted", false)):
		cancel_return_departure(StringName(armed.get("reason", &"return_arm_refused")))
		return
	_mudds_return_approach_active = true


func _observe_aurora_return_tick(tick: Dictionary) -> void:
	if not _aurora_return_active:
		return
	_last_aurora_return_result = tick.duplicate(true)
	if tick.get("reason") == &"return_approach_handoff_ready":
		_aurora_return_departure_pending = false
		var consumed := _consume_mudds_return_approach_completion(tick)
		if not bool(consumed.get("accepted", false)):
			cancel_return_departure(StringName(consumed.get("reason", &"return_completion_refused")), false)
			_last_aurora_return_result = consumed.duplicate(true)
		return
	if bool(tick.get("accepted", false)):
		var policy := (tick.get("controller", {}) as Dictionary).get("policy", {}) as Dictionary
		if bool(policy.get("desired_cruise_participation", false)):
			_aurora_return_departure_pending = false
		return
	_mudds_return_approach_active = false
	var reason := StringName(tick.get("reason", &"return_cruise_refused"))
	if _aurora_return_departure_pending and (reason == &"obstacle_detected" or (
			reason == &"ship_attachment_retired" and is_instance_valid(_flow.active_ship)
			and _flow.active_ship.is_piloted() and _flow.active_ship.has_manual_flight_intent())):
		return
	cancel_return_departure(reason, false)


## Both observers adopt the same committed receipt before the next cruise tick.
## The source retains its approach identity; only its coordinate-frame fence moves.
func _adopt_aurora_origin_receipt(receipt: Dictionary) -> Dictionary:
	var result := {"accepted": true, "source": {}, "cruise": {}}
	if _aurora_final_approach_source_ref != null:
		var source := _aurora_final_approach_source_ref.get_ref() as Node
		if not is_instance_valid(source) or not source.is_inside_tree() \
				or source.is_queued_for_deletion() \
				or not source.has_method(&"accept_committed_origin_rebase"):
			return {"accepted": false, "reason": &"aurora_approach_source_unavailable"}
		var record := source.call(&"get_final_approach_source_snapshot") as Dictionary
		var adopted := source.call(&"accept_committed_origin_rebase", receipt,
			int(record.get("generation", -1)),
			int(record.get("attachment_generation", -1))) as Dictionary
		result["source"] = adopted.duplicate(true)
		if not bool(adopted.get("accepted", false)):
			result["accepted"] = false
			return result
	var cruise := _flow.planetary_cruise_binding
	if is_instance_valid(cruise):
		var current := cruise.get_snapshot()
		if bool(current.get("engagement_requested", false)) \
				and bool(current.get("carry_transit", false)):
			var adopted := cruise.accept_committed_origin_rebase(
				receipt, cruise.get_generation())
			result["cruise"] = adopted.duplicate(true)
			result["accepted"] = bool(adopted.get("accepted", false))
	return result


## Engages an admitted Aurora visit. Physical outbound travel carries the
## attached controller through authenticated origin shifts; local/legacy callers
## can retain the default generation-bound engagement.
func engage_aurora_cruise(ship: HeroShip, carry_transit: bool = false) -> Dictionary:
	if not _aurora_visit_active:
		return {"accepted": false, "reason": &"aurora_visit_inactive"}
	if not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.aurora_streaming_bootstrap):
		return {"accepted": false, "reason": &"aurora_composition_unavailable"}
	var cruise := _flow.planetary_cruise_binding
	var current := cruise.get_snapshot()
	if bool(current.get("engagement_requested", false)) \
			and (not carry_transit or bool(current.get("carry_transit", false))):
		return {"accepted": true, "reason": &"already_engaged"}
	var frame := _flow.aurora_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return {"accepted": false, "reason": &"aurora_coordinate_frame_unavailable"}
	if not (frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty():
		return {"accepted": false, "reason": &"origin_rebase_pending"}
	return cruise.request_engage(
		ship, frame.get_generation(), _aurora_cruise_gate_reason(),
		cruise.get_generation(), carry_transit,
	)


## Arms the authored Aurora approach corridor against the streamed world's own
## landing region. `source` is the visit's approach source - any node declaring
## `get_final_approach_source_snapshot()`; the cruise binding never learns which
## world's host is on the other end.
func arm_aurora_final_approach(
		source: Node,
		landing_root: Node3D,
		envelope: Dictionary,
	) -> Dictionary:
	if not _aurora_visit_active:
		return {"accepted": false, "reason": &"aurora_visit_inactive"}
	if _aurora_final_approach_armed:
		return {"accepted": true, "reason": &"aurora_final_approach_already_armed"}
	if not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.aurora_streaming_bootstrap):
		return {"accepted": false, "reason": &"aurora_composition_unavailable"}
	var bootstrap_snapshot := _flow.aurora_streaming_bootstrap.get_snapshot()
	var frame := _flow.aurora_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return {"accepted": false, "reason": &"aurora_coordinate_frame_unavailable"}
	var record := source.call(&"get_final_approach_source_snapshot") as Dictionary
	var armed := _flow.planetary_cruise_binding.request_final_approach(
		source,
		landing_root,
		envelope,
		frame.get_generation(),
		int(bootstrap_snapshot.get("location_generation", 0)),
		int(record.get("generation", -1)),
		int(record.get("attachment_generation", 0)),
		_flow.planetary_cruise_binding.get_generation(),
	)
	if bool(armed.get("accepted", false)):
		_aurora_final_approach_armed = true
		_aurora_final_approach_source_ref = weakref(source)
	return armed


## Ends the lane and gives the one cruise binding back to Ember, so the next
## Ember expedition finds the composition exactly as it was.
func retire_aurora_visit() -> Dictionary:
	if not _aurora_visit_active:
		return _aurora_retired(true, &"aurora_visit_inactive")
	_aurora_visit_active = false
	if _aurora_return_active:
		cancel_return_departure(&"aurora_visit_retired")
	_aurora_return_departure_pending = false
	_aurora_final_approach_handoff_ready = false
	_aurora_final_approach_armed = false
	_aurora_final_approach_source_ref = null
	_aurora_final_approach_completion_receipt.clear()
	var disengaged: Dictionary = {}
	if is_instance_valid(_flow.planetary_cruise_binding):
		disengaged = _flow.planetary_cruise_binding.request_disengage(
			_flow.planetary_cruise_binding.get_generation(), true
		)
	var restored := _restore_ember_cruise_binding()
	return _aurora_retired(
		bool(restored.get("accepted", false)), &"aurora_visit_retired", {
			"disengage": disengaged.duplicate(true),
			"cruise_rebind": restored.duplicate(true),
		}
	)


func is_aurora_visit_active() -> bool:
	return _aurora_visit_active


func aurora_final_approach_handoff_ready() -> bool:
	return _aurora_final_approach_handoff_ready


func get_aurora_visit_snapshot() -> Dictionary:
	return {
		"active": _aurora_visit_active,
		"return_active": _aurora_return_active,
		"return_departure_pending": _aurora_return_departure_pending,
		"return_handoff_ready": _aurora_return_handoff_ready,
		"last_return_result": _last_aurora_return_result.duplicate(true),
		"rebase_commit_count": _aurora_visit_rebase_commit_count,
		"final_approach_armed": _aurora_final_approach_armed,
		"final_approach_handoff_ready": _aurora_final_approach_handoff_ready,
		"final_approach_completion_receipt":
			_aurora_final_approach_completion_receipt.duplicate(true),
		"last_streaming_result": _last_aurora_streaming_result.duplicate(true),
		"last_origin_result": _last_aurora_origin_result.duplicate(true),
		"last_cruise_result": _last_aurora_cruise_result.duplicate(true),
		"last_admission_result": _last_aurora_admission_result.duplicate(true),
		"last_retirement_result": _last_aurora_retirement_result.duplicate(true),
	}.duplicate(true)


## The production gate for an Aurora cruise. It is `_planetary_cruise_gate_reason`
## without the clause that refuses while an Aurora visit is running, and against
## Aurora's own frame rather than Ember's.
func _aurora_cruise_gate_reason() -> StringName:
	if not _flow.is_inside_tree() or _flow.is_queued_for_deletion():
		return &"main_unavailable"
	var ship := _flow.active_ship
	if not is_instance_valid(ship) or ship.is_queued_for_deletion() \
			or not ship.is_inside_tree():
		return &"active_ship_unavailable"
	if ship.is_destroyed():
		return &"ship_destroyed"
	if not _flow._piloting or not ship.is_piloted():
		return &"pilot_unseated"
	if _flow._landing_request_active or ship.is_landing_active():
		return &"landing_active"
	if _flow._planetary_cruise_combat_active():
		return &"combat_active"
	if _flow._recovering or _flow.phase == GameFlow.Phase.RECOVERING:
		return &"ship_recovery"
	if not is_instance_valid(_flow.aurora_streaming_bootstrap):
		return &"coordinate_frame_unavailable"
	var frame := _flow.aurora_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return &"coordinate_frame_unavailable"
	if not (frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty():
		return &"origin_rebase_pending"
	return &""


func _restore_ember_cruise_binding() -> Dictionary:
	if not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.ember_streaming_bootstrap):
		return {"accepted": false, "reason": &"ember_composition_unavailable"}
	if _flow.planetary_cruise_binding.get_bound_world_id() \
			== EmberMoonStreamingBootstrap.WORLD_ID:
		return {"accepted": true, "reason": &"already_bound_to_ember"}
	return _flow.planetary_cruise_binding.bind_world(_flow.ember_streaming_bootstrap)


func _aurora_admitted(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	_last_aurora_admission_result = result.duplicate(true)
	return result.duplicate(true)


func _aurora_retired(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	_last_aurora_retirement_result = result.duplicate(true)
	return result.duplicate(true)


func detach() -> void:
	cancel_return_departure(&"return_main_detached")
	if _aurora_visit_active:
		retire_aurora_visit()
	if _planetary_return_physical_arrival_armed:
		_abort_planetary_return_physical_arrival(&"return_main_detached")
		_flow._landing_request_active = false
		_flow._active_landing_berth_id = &""
	if _mudds_return_approach_active \
			and not _mudds_return_approach_completion_attempted:
		_mudds_return_approach_active = false
		_ember_surface_journey_active = false
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_main_detached",
		}.duplicate(true)
	if not _pending_ember_surface_request.is_empty():
		cancel_ember_surface_journey()



func _ensure_ember_surface_loop_host_bound(streaming_ready: bool) -> Dictionary:
	if not streaming_ready:
		return {"accepted": false, "reason": &"streaming_not_ready"}
	if not is_instance_valid(_flow.ember_surface_loop_host) \
			or not is_instance_valid(_flow.ember_surface_berth) \
			or not is_instance_valid(_flow.ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"composition_missing"}
	if _flow.ember_surface_loop_host.is_attached():
		# A retained Host that is idle between visits can still be holding the
		# streamed world of the previous one: Ember unloads behind a departing
		# craft and the Host's frozen loaded-root identity goes stale, which its
		# own audit reports and the surface binding refuses to configure against.
		# Nothing is running, so release that binding here and rebind below
		# against the world that is actually loaded now.
		if _ember_surface_journey_active \
				or not _pending_ember_surface_request.is_empty() \
				or _flow.ember_surface_loop_host.get_phase() \
					!= EmberSurfaceLoopHost.Phase.IDLE \
				or bool(_flow.ember_surface_loop_host.audit().get("valid", false)):
			return {"accepted": true, "reason": &"already_bound"}
		var released := _flow.ember_surface_loop_host.detach(
			_flow.ember_surface_loop_host.get_generation(),
			_flow.ember_surface_loop_host.get_attachment_generation(),
		)
		if not bool(released.get("accepted", false)):
			return released
	if _flow.ember_surface_loop_production_binding.is_configured():
		return {"accepted": true, "reason": &"already_configured"}
	var loaded_scene := _flow.ember_streaming_bootstrap.get_loaded_instance() \
			if is_instance_valid(_flow.ember_streaming_bootstrap) else null
	var player_controller := _flow.player as PlayerController
	if not is_instance_valid(loaded_scene) or not is_instance_valid(_flow.active_ship) \
			or not is_instance_valid(player_controller):
		return {"accepted": false, "reason": &"loaded_actor_unavailable"}
	var location_generation := int(
		_flow.ember_streaming_bootstrap.get_snapshot().get("location_generation", 0)
	)
	if location_generation < 1:
		return {"accepted": false, "reason": &"location_generation_unavailable"}
	var frame := _flow.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null or not frame.is_configured():
		return {"accepted": false, "reason": &"coordinate_frame_unavailable"}
	var landing_region := loaded_scene.get_node_or_null(^"LandingRegion") as Node3D
	if not is_instance_valid(landing_region):
		return {"accepted": false, "reason": &"loaded_landing_region_unavailable"}
	_flow.ember_surface_berth.global_transform = landing_region.global_transform
	var bound := _flow.ember_surface_loop_host.bind_dependencies(
		_flow.ember_streaming_bootstrap, _flow.ember_surface_berth, _flow.active_ship,
		player_controller, 1.62, location_generation,
		_flow.ember_surface_loop_host.get_generation(),
		_flow.ember_surface_loop_host.get_attachment_generation(), _flow,
		_flow.common_world_origin_rebase_owner
	)
	if not bool(bound.get("accepted", false)):
		return bound
	var configured := _flow.ember_surface_loop_production_binding.configure(
		_flow.ember_surface_loop_host, _flow.ember_surface_loop_production_binding.get_generation()
	)
	if not bool(configured.get("accepted", false)):
		return configured
	return {"accepted": true, "reason": &"bound_after_stream_load"}


func _advance_ember_surface_loop_cadence(
	delta: float,
	actor_sample: Dictionary,
	origin_result: Dictionary,
	coordinate_frame_generation: int,
) -> Dictionary:
	if not _ember_surface_journey_active \
			or not _ember_final_approach_handoff_ready \
			or not is_instance_valid(_flow.ember_surface_loop_production_binding) \
			or not is_instance_valid(_flow.active_ship) \
			or not is_instance_valid(_flow.player):
		return {"accepted": false, "reason": &"ember_surface_cadence_unavailable"}
	var binding_snapshot := _flow.ember_surface_loop_production_binding.get_caller_snapshot()
	if StringName(binding_snapshot.get("state_id", &"")) \
			not in [&"idle", &"start_pending", &"running"]:
		return {"accepted": false, "reason": &"ember_surface_cadence_inactive"}
	if origin_result.is_empty() or not bool(origin_result.get("accepted", false)) \
			or not bool(actor_sample.get("available", false)) \
			or coordinate_frame_generation < 1:
		return {"accepted": false, "reason": &"ember_surface_observation_unavailable"}
	var actor_kind := StringName(actor_sample.get("actor_kind", &""))
	var actor_instance_id := int(actor_sample.get("actor_instance_id", 0))
	var actor_position_value: Variant = actor_sample.get("position", Vector3.INF)
	if actor_kind not in [&"ship", &"player"] \
			or not actor_position_value is Vector3 \
			or not (actor_position_value as Vector3).is_finite() \
			or (actor_kind == &"ship" and actor_instance_id != _flow.active_ship.get_instance_id()) \
			or (actor_kind == &"player" and actor_instance_id != _flow.player.get_instance_id()):
		return {"accepted": false, "reason": &"ember_surface_actor_sample_mismatch"}
	var location_generation := int(
		(binding_snapshot.get("identities", {}) as Dictionary).get(
			"location_generation", 0
		)
	)
	if location_generation < 1 \
			or _ember_surface_caller_serial >= EmberSurfaceLoopHost.MAX_SAFE_INTEGER:
		return {"accepted": false, "reason": &"ember_surface_generation_unavailable"}
	_ember_surface_caller_serial += 1
	var telemetry := _flow.active_ship.get_telemetry()
	var host_phase := _flow.ember_surface_loop_production_binding.get_host_phase()
	var advanced := _flow.ember_surface_loop_production_binding.advance_from_caller_sample(
		_ember_surface_caller_serial,
		delta,
		actor_kind,
		actor_instance_id,
		_flow.active_ship.get_instance_id(),
		actor_position_value as Vector3,
		_flow.active_ship.velocity,
		bool(telemetry.get("landed", false)),
		false,
		false,
		origin_result,
		coordinate_frame_generation,
		location_generation,
		_flow.ember_surface_loop_production_binding.get_generation(),
	)
	if not bool(advanced.get("accepted", false)):
		return advanced
	var survey_lifecycle := _advance_ember_survey_lifecycle(binding_snapshot)
	if not survey_lifecycle.is_empty():
		advanced["relay_survey"] = survey_lifecycle.duplicate(true)
	var intent_result: Dictionary = {}
	if host_phase == EmberSurfaceLoopHost.Phase.LANDED \
			and not _ember_surface_abandon_pending \
			and str(telemetry.get("engine_state", "ONLINE")) == "OFFLINE":
		intent_result = _queue_ember_surface_intent(&"disembark")
	elif host_phase == EmberSurfaceLoopHost.Phase.REBOARDED:
		intent_result = _queue_ember_surface_intent(&"takeoff")
	if not intent_result.is_empty():
		advanced["intent"] = intent_result.duplicate(true)
	return advanced.duplicate(true)


func _ember_survey_context(binding_snapshot: Dictionary) -> Dictionary:
	var host := _flow.ember_surface_loop_host
	if not is_instance_valid(host) or not is_instance_valid(_flow.player) \
			or not is_instance_valid(_flow.active_ship):
		return {}
	var identities := binding_snapshot.get("identities", {}) as Dictionary
	var session := host.get_travel_session_observation_source()
	if not is_instance_valid(session) \
			or int(identities.get("host_instance_id", 0)) != host.get_instance_id() \
			or int(identities.get("player_instance_id", 0)) != _flow.player.get_instance_id() \
			or int(identities.get("ship_instance_id", 0)) != _flow.active_ship.get_instance_id():
		return {}
	return {
		"owner_generation": int(binding_snapshot.get("generation", -1)),
		"host_instance_id": host.get_instance_id(),
		"host_generation": host.get_generation(),
		"host_attachment_generation": host.get_attachment_generation(),
		"session_instance_id": session.get_instance_id(),
		"actor_instance_id": _flow.player.get_instance_id(),
		"craft_instance_id": _flow.active_ship.get_instance_id(),
	}


func _ember_survey_return_is_admitted(binding_snapshot: Dictionary) -> bool:
	var context := _ember_survey_context(binding_snapshot)
	if context.is_empty():
		return false
	var retained := binding_snapshot.get("retained_return_context", {}) as Dictionary
	for key in context:
		if key != "owner_generation" and retained.get(key) != context[key]:
			return false
	return true


## The caller starts the authored route once at the real on-foot boundary.
## Reward and persistence remain the late binding's authorities; only their
## matching committed receipt permits the existing route-home admission.
func _advance_ember_survey_lifecycle(binding_snapshot: Dictionary) -> Dictionary:
	if _ember_surface_abandon_pending:
		# An abandoned expedition starts no authored work and earns no reward.
		return {}
	var binding := _flow.ember_surface_loop_production_binding
	if binding.get_host_phase() != EmberSurfaceLoopHost.Phase.ON_FOOT:
		return {}
	var context := _ember_survey_context(binding_snapshot)
	if context.is_empty():
		return {"accepted": false, "reason": &"ember_survey_context_unavailable"}
	var surface := binding_snapshot.get("planetary_surface", {}) as Dictionary
	var activity := (surface.get("adapter", {}) as Dictionary).get("activity_reward", {}) as Dictionary
	var activity_state := StringName(activity.get("state", &""))
	if _ember_survey_start_context.is_empty():
		if activity_state in [&"active", &"awaiting_reward"]:
			# Persistence has already authenticated this live route. Adopt its
			# current visit without restarting its checkpoints or optional work.
			_ember_survey_start_context = context.duplicate(true)
		elif activity_state in [&"ready", &"completed", &"failed"]:
			# Only a newly admitted journey reaches a prior terminal activity
			# with no start context; the existing facade owns repeat/retry.
			var started := binding.start_planetary_relay_survey()
			if bool(started.get("accepted", false)) \
					and _ember_survey_context(binding.get_caller_snapshot()) == context:
				_ember_survey_start_context = context.duplicate(true)
			return started
	if _ember_survey_start_context != context \
			or StringName(activity.get("state", &"")) != &"completed" \
			or _ember_survey_return_is_admitted(binding_snapshot):
		return {}
	var reward := binding_snapshot.get("relay_reward_commit", {}) as Dictionary
	var committed := reward.get("commit_receipt", {}) as Dictionary
	if not bool((committed.get("persistence", {}) as Dictionary).get("accepted", false)) \
			or int(committed.get("activity_generation", -1)) != int(activity.get("activity_generation", -2)):
		return {"accepted": false, "reason": &"ember_survey_reward_not_persisted"}
	for key in ["owner_generation", "host_generation", "host_attachment_generation", "actor_instance_id", "session_instance_id"]:
		if committed.get(key) != context[key]:
			return {"accepted": false, "reason": &"ember_survey_reward_context_mismatch"}
	if _ember_survey_return_manifest.is_empty():
		var issued := binding.issue_planetary_relay_survey_return_manifest()
		if not bool(issued.get("accepted", false)):
			return issued
		_ember_survey_return_manifest = issued.duplicate(true)
	return binding.admit_planetary_relay_survey_return(
		_ember_survey_return_manifest,
		int(context.actor_instance_id), int(context.craft_instance_id)
	)


func _queue_ember_surface_intent(intent_id: StringName) -> Dictionary:
	if not is_instance_valid(_flow.ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"ember_surface_binding_unavailable"}
	var snapshot := _flow.ember_surface_loop_production_binding.get_caller_snapshot()
	if StringName(snapshot.get("state_id", &"")) != &"running":
		return {"accepted": false, "reason": &"ember_surface_intent_out_of_order"}
	var pending := snapshot.get("pending_envelope", {}) as Dictionary
	if pending.is_empty() \
			or int(pending.get("physics_frame", -1)) != int(Engine.get_physics_frames()) \
			or not (snapshot.get("pending_intent", {}) as Dictionary).is_empty():
		return {"accepted": false, "reason": &"ember_surface_intent_without_current_tick"}
	var intent_serial := int(snapshot.get("last_intent_serial", 0)) + 1
	match intent_id:
		&"disembark":
			return _flow.ember_surface_loop_production_binding.queue_disembark_intent(
				intent_serial, _flow.ember_surface_loop_production_binding.get_generation()
			)
		&"reboard":
			return _flow.ember_surface_loop_production_binding.queue_reboard_intent(
				intent_serial, _flow.ember_surface_loop_production_binding.get_generation()
			)
		&"takeoff":
			return _flow.ember_surface_loop_production_binding.queue_takeoff_intent(
				intent_serial, _flow.ember_surface_loop_production_binding.get_generation()
			)
	return {"accepted": false, "reason": &"ember_surface_intent_invalid"}


func _consume_ember_surface_reboard_interaction() -> bool:
	if not _ember_surface_journey_active \
			or not is_instance_valid(_flow.ember_surface_loop_host) \
			or not is_instance_valid(_flow.ember_surface_loop_production_binding) \
			or _flow.ember_surface_loop_production_binding.get_host_phase() \
				!= EmberSurfaceLoopHost.Phase.ON_FOOT:
		return false
	var host_snapshot := _flow.ember_surface_loop_host.get_snapshot()
	# The authored bunker survey uses the existing generic nearby-interaction
	# seam. Let that exact Ember-owned point pass through before this handler
	# reserves all other ON_FOOT presses for the return-to-ship lifecycle.
	var nearby_surface_interaction := _flow._find_station_interaction_candidate()
	if is_instance_valid(nearby_surface_interaction) and bool(
		nearby_surface_interaction.get_meta("ember_surface_survey_interaction", false)
	):
		return false
	if not bool(
		(host_snapshot.get("surface_route", {}) as Dictionary).get(
			"return_complete", false
		)
	):
		return true
	var boarding_area := _flow.active_ship.get_node_or_null(^"ShipBoardingArea") \
		as ShipBoardingArea if is_instance_valid(_flow.active_ship) else null
	if not is_instance_valid(boarding_area) or not is_instance_valid(_flow.player):
		return true
	var boarding_area_nearby := false
	for nearby in _flow.player.get_nearby_interactables():
		if nearby == boarding_area:
			boarding_area_nearby = true
			break
	if boarding_area_nearby:
		if not _ember_surface_abandon_pending \
				and not _ember_survey_return_is_admitted(_flow.ember_surface_loop_production_binding.get_snapshot()):
			if is_instance_valid(_flow.hud):
				_flow.hud.toast("Survey return pending", "Complete the Ember relay survey and save its reward before boarding for home")
			return true
		_queue_ember_surface_intent(&"reboard")
	return true


func begin_ember_surface_journey(
		host: Object, director: ActivityDirector, reward_sink: Callable,
		caller_serial: int
	) -> Dictionary:
	if host == null or director == null or not reward_sink.is_valid() or caller_serial < 1:
		return {"accepted": false, "reason": &"ember_surface_request_invalid"}
	if not is_instance_valid(_flow.active_ship) or not _flow.active_ship.is_piloted() \
			or _flow.phase in [_flow.Phase.INTERCEPTOR_ENGAGEMENT, _flow.Phase.FAILED, _flow.Phase.SHUT_DOWN]:
		return {"accepted": false, "reason": &"ember_surface_actor_unavailable"}
	var cruise_gate_reason := _flow._planetary_cruise_gate_reason(false)
	if not cruise_gate_reason.is_empty():
		return {"accepted": false, "reason": cruise_gate_reason}
	if not is_instance_valid(_flow.planetary_cruise_binding):
		return {"accepted": false, "reason": &"ember_cruise_binding_unavailable"}
	var cruise_snapshot := _flow.planetary_cruise_binding.get_snapshot()
	if not bool(cruise_snapshot.get("activated", false)):
		return {"accepted": false, "reason": &"ember_cruise_binding_not_ready"}
	if not bool(cruise_snapshot.get("engagement_requested", false)) \
			or not bool(cruise_snapshot.get("carry_transit", false)):
		var engaged := _flow.planetary_cruise_binding.request_engage(
			_flow.active_ship,
			int(cruise_snapshot.get("current_coordinate_frame_generation", 0)),
			&"",
			_flow.planetary_cruise_binding.get_generation(), true
		)
		if not bool(engaged.get("accepted", false)):
			return engaged
	if not is_instance_valid(_flow.ember_streaming_binding):
		return {"accepted": false, "reason": &"ember_streaming_binding_unavailable"}
	var streaming := _flow.ember_streaming_binding.get_snapshot()
	var host_snapshot: Dictionary = host.get_snapshot()
	var host_ready := bool(host_snapshot.get("attached", false)) \
			and int(host_snapshot.get("phase", -1)) == EmberSurfaceLoopHost.Phase.IDLE
	if not host_ready \
			or not bool(streaming.get("activated", false)) \
			or int(streaming.get("bound_coordinate_frame_generation", 0)) \
			!= int(streaming.get("current_coordinate_frame_generation", -1)):
		_pending_ember_surface_host = host
		_pending_ember_surface_director = director
		_pending_ember_surface_reward_sink = reward_sink
		_pending_ember_surface_serial = caller_serial
		_pending_ember_surface_request = {
			"host_instance_id": host.get_instance_id(),
			"caller_serial": caller_serial,
			"streaming_generation": int(streaming.get("current_coordinate_frame_generation", -1)),
		}.duplicate(true)
		return {"accepted": true, "reason": &"ember_surface_journey_pending_stream", "pending": _pending_ember_surface_request.duplicate(true)}
	if not is_instance_valid(_flow.ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"ember_surface_binding_unavailable"}
	var binding := _flow.ember_surface_loop_production_binding
	var binding_snapshot := binding.get_snapshot()
	if not bool(binding_snapshot.get("configured", false)):
		var configured: Dictionary = binding.configure(host, binding.get_generation())
		if not bool(configured.get("accepted", false)):
			return configured
	if binding.get_planetary_surface_snapshot().is_empty():
		var composed: Dictionary = binding.configure_planetary_surface(
			director, reward_sink, null,
			Callable(_flow, &"_commit_ember_service_terminal_repair")
		)
		if not bool(composed.get("accepted", false)):
			return composed
	var final_approach := _arm_ember_final_approach(host)
	if not bool(final_approach.get("accepted", false)):
		return final_approach
	var survey_restore: Dictionary = {}
	if binding == _flow._ember_relay_survey_persistence_binding:
		survey_restore = _flow._restore_ember_surface_persistence_for_admission()
	# Admission starts the retained surface journey. Disembark is a later,
	# phase-specific caller intent after the Host has actually reached LANDED;
	# queuing it while the binding is still IDLE necessarily rejects because no
	# same-frame caller envelope exists yet.
	_ember_survey_start_context.clear()
	_ember_survey_return_manifest.clear()
	# The surface binding's caller-serial fence belongs to the visit-scoped
	# composition, and resets with it. A retained coordinator that kept counting
	# from the previous expedition handed every later visit a skipped serial, so
	# the binding refused every cadence tick: the second visit consumed its
	# final-approach completion, reported the handoff ready, and then left the
	# Host at `IDLE` forever. Adopt the fence the binding is actually holding.
	_ember_surface_caller_serial = int(
		binding.get_caller_snapshot().get("last_caller_serial", 0)
	)
	_ember_surface_abandon_pending = false
	_ember_surface_abandon_reason = &""
	_ember_abandon_return_active = false
	_ember_abandon_return_arm_pending = false
	_ember_abandon_return_arm_attempts = 0
	_ember_abandon_observed_commit_count = int(
		host.call(&"get_abandon_snapshot").get("commit_count", 0)
	)
	_ember_surface_journey_active = true
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	_mudds_return_handback_consumption_attempted = false
	_mudds_return_handback_receipt.clear()
	_mudds_station_return_intent_consumption_attempted = false
	_mudds_station_return_intent_receipt.clear()
	_last_mudds_station_return_intent_result.clear()
	_mudds_return_approach_active = false
	_mudds_return_approach_completion_attempted = false
	_mudds_return_approach_completion_receipt.clear()
	_last_mudds_return_approach_result.clear()
	_planetary_return_receipt_consumed = false
	_planetary_return_physical_arrival_required = false
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result.clear()
	# A prior completed attempt retains evidence until a new journey is admitted.
	# Resetting here cannot release GameFlow's berth because the physical adapter
	# explicitly adopts, rather than owns, that lease.
	if _flow.ember_surface_loop_production_binding.has_method(
		&"reset_planetary_return_berth"
	):
		_flow.ember_surface_loop_production_binding.reset_planetary_return_berth()
	return {
		"accepted": true,
		"reason": &"ember_surface_journey_admitted",
		"binding_generation": binding.get_generation(),
		"caller_serial": caller_serial,
		"relay_survey_persistence": survey_restore.duplicate(true),
	}


func _arm_ember_final_approach(host: Object) -> Dictionary:
	if host != _flow.ember_surface_loop_host \
			or not is_instance_valid(_flow.ember_surface_loop_host):
		return {"accepted": false, "reason": &"ember_surface_host_identity_mismatch"}
	if not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.ember_streaming_bootstrap):
		return {"accepted": false, "reason": &"ember_final_approach_unavailable"}
	var host_snapshot := _flow.ember_surface_loop_host.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE:
		return {"accepted": false, "reason": &"ember_surface_host_not_ready"}
	var approach := host_snapshot.get("approach_entry", {}) as Dictionary
	var envelope := approach.get("envelope", {}) as Dictionary
	if envelope.is_empty():
		return {"accepted": false, "reason": &"ember_approach_envelope_unavailable"}
	var loaded_scene := _flow.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded_scene):
		return {"accepted": false, "reason": &"ember_loaded_scene_unavailable"}
	var landing_root := loaded_scene.get_node_or_null(^"LandingRegion") as Node3D
	if not is_instance_valid(landing_root):
		return {"accepted": false, "reason": &"ember_landing_root_unavailable"}
	var cruise_snapshot := _flow.planetary_cruise_binding.get_snapshot()
	var existing := cruise_snapshot.get("final_approach", {}) as Dictionary
	if int(existing.get("target_generation", 0)) > 0:
		return {"accepted": true, "reason": &"final_approach_already_armed"}
	return _flow.planetary_cruise_binding.request_final_approach(
		_flow.ember_surface_loop_host,
		landing_root,
		envelope,
		int(host_snapshot.get("coordinate_frame_generation", 0)),
		int(host_snapshot.get("location_generation", 0)),
		int(host_snapshot.get("generation", -1)),
		int(host_snapshot.get("attachment_generation", 0)),
		_flow.planetary_cruise_binding.get_generation(),
	)


## An admitted expedition keeps exactly one armed final-approach target, armed
## once by `begin_ember_surface_journey`. `HeroShip` may independently retire its
## cruise attachment while the Host is still IDLE — braking complete at the
## destination, a physical collision, a manual flight command — and that
## retirement clears the armed target and the engagement with it. Nothing else
## re-arms: the expedition stayed active with no path to the surface and no
## production request seam to ask again, stranding the craft in Ember orbit.
##
## This restores exactly the state the admission established and nothing more.
## It is idempotent (an armed target reports `final_approach_already_armed`), it
## never runs once a completion receipt exists or the station-return leg has
## begun, and it reuses the same public engage/arm calls, so it adds no movement,
## landing or origin authority.
func _rearm_retired_ember_final_approach() -> Dictionary:
	if _ember_final_approach_handoff_ready \
			or not _ember_final_approach_completion_receipt.is_empty() \
			or _mudds_return_approach_active \
			or _mudds_return_approach_completion_attempted:
		return {"accepted": false, "reason": &"ember_final_approach_rearm_out_of_order"}
	if not is_instance_valid(_flow.ember_surface_loop_host) \
			or not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.active_ship) \
			or not _flow.active_ship.is_piloted():
		return {"accepted": false, "reason": &"ember_final_approach_rearm_unavailable"}
	if _flow.active_ship.has_manual_flight_intent():
		return {"accepted": false, "reason": &"manual_flight_intent"}
	var host_snapshot := _flow.ember_surface_loop_host.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE:
		return {"accepted": false, "reason": &"ember_final_approach_rearm_phase_mismatch"}
	var cruise_snapshot := _flow.planetary_cruise_binding.get_snapshot()
	if int((cruise_snapshot.get("final_approach", {}) as Dictionary).get(
		"target_generation", 0
	)) > 0:
		return {"accepted": false, "reason": &"final_approach_already_armed"}
	var gate_reason := _flow._planetary_cruise_gate_reason(false)
	if not gate_reason.is_empty():
		return {"accepted": false, "reason": gate_reason}
	if not bool(cruise_snapshot.get("engagement_requested", false)):
		if _ember_outbound_resume_attempts >= MAX_TRANSIT_RESUME_ATTEMPTS:
			return {"accepted": false, "reason": &"outbound_transit_resume_exhausted"}
		_ember_outbound_resume_attempts += 1
		var engaged := _flow.planetary_cruise_binding.request_engage(
			_flow.active_ship,
			int(cruise_snapshot.get("current_coordinate_frame_generation", 0)),
			&"",
			_flow.planetary_cruise_binding.get_generation(), true
		)
		if not bool(engaged.get("accepted", false)):
			return engaged
	return _arm_ember_final_approach(_flow.ember_surface_loop_host)


func _ember_final_approach_completion_is_current(receipt: Dictionary) -> bool:
	if not is_instance_valid(_flow.ember_surface_loop_host) \
			or not is_instance_valid(_flow.active_ship) \
			or not is_instance_valid(_flow.planetary_cruise_binding):
		return false
	var host_snapshot := _flow.ember_surface_loop_host.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE \
			or int(receipt.get("host_instance_id", 0)) \
				!= _flow.ember_surface_loop_host.get_instance_id() \
			or int(receipt.get("host_generation", -2)) \
				!= int(host_snapshot.get("generation", -1)) \
			or int(receipt.get("host_attachment_generation", 0)) \
				!= int(host_snapshot.get("attachment_generation", -1)) \
			or int(receipt.get("coordinate_frame_generation", 0)) \
				!= int(host_snapshot.get("coordinate_frame_generation", -1)) \
			or int(receipt.get("location_generation", 0)) \
				!= int(host_snapshot.get("location_generation", -1)) \
			or int(receipt.get("ship_instance_id", 0)) != _flow.active_ship.get_instance_id():
		return false
	var release := receipt.get("controller_release", {}) as Dictionary
	var ship_report := _flow.active_ship.get_planetary_cruise_attachment_report()
	return bool(release.get("accepted", false)) \
		and int(receipt.get("released_ship_attachment_generation", 0)) \
			== int(ship_report.get("ship_attachment_generation", -1)) \
		and int(ship_report.get("controller_instance_id", -1)) == 0


func _consume_ember_final_approach_completion(receipt: Dictionary) -> Dictionary:
	if not is_instance_valid(_flow.planetary_cruise_binding):
		return {"accepted": false, "reason": &"ember_cruise_binding_unavailable"}
	var target_generation := int(receipt.get("target_generation", 0))
	if _ember_final_approach_completion_is_current(receipt):
		var consumed := _flow.planetary_cruise_binding.consume_final_approach_completion(
			target_generation, _flow.planetary_cruise_binding.get_generation()
		)
		if bool(consumed.get("accepted", false)):
			_ember_final_approach_completion_receipt = consumed.duplicate(true)
			_ember_final_approach_handoff_ready = true
		return consumed
	var discarded := _flow.planetary_cruise_binding.discard_final_approach_completion(
		target_generation, _flow.planetary_cruise_binding.get_generation(),
		&"final_approach_completion_stale",
	)
	_ember_surface_journey_active = false
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	return discarded


func _consume_mudds_station_return_handoff_intent(
		coordinate_frame_generation: int
	) -> Dictionary:
	if _mudds_station_return_intent_consumption_attempted:
		return {
			"accepted": false,
			"reason": &"station_return_handoff_already_observed",
		}.duplicate(true)
	if not is_instance_valid(_flow.ember_surface_loop_production_binding) \
			or not _flow.ember_surface_loop_production_binding.has_method(
				&"take_planetary_station_return_handoff_intent"
			):
		return {
			"accepted": false,
			"reason": &"station_return_handoff_binding_unavailable",
		}.duplicate(true)
	if not _flow.ember_surface_loop_production_binding.has_pending_station_return_handoff():
		return {
			"accepted": false,
			"reason": &"station_return_handoff_not_pending",
		}.duplicate(true)
	# Preserve the detached pre-consumption context for the full handoff check.
	var binding_snapshot := _flow.ember_surface_loop_production_binding.get_snapshot()
	_mudds_station_return_intent_consumption_attempted = true
	var taken := _flow.ember_surface_loop_production_binding.call(
		&"take_planetary_station_return_handoff_intent",
		_flow.ember_surface_loop_production_binding.get_generation(),
	) as Dictionary
	if not bool(taken.get("accepted", false)):
		_last_mudds_station_return_intent_result = taken.duplicate(true)
		return taken
	var intent := taken.get("intent", {}) as Dictionary
	var rejection := _mudds_station_return_handoff_rejection(
		intent, binding_snapshot, coordinate_frame_generation
	)
	if not rejection.is_empty():
		var aborted: Dictionary = {}
		if _flow.ember_surface_loop_production_binding.has_method(
			&"abort_planetary_relay_survey_return"
		):
			aborted = _flow.ember_surface_loop_production_binding.call(
				&"abort_planetary_relay_survey_return", rejection
			) as Dictionary
		_last_mudds_station_return_intent_result = {
			"accepted": false,
			"reason": rejection,
			"return_intent_abort": aborted.duplicate(true),
		}.duplicate(true)
		return _last_mudds_station_return_intent_result.duplicate(true)
	_mudds_station_return_intent_receipt = intent.duplicate(true)
	_last_mudds_station_return_intent_result = {
		"accepted": true,
		"reason": &"station_return_handoff_consumed",
		"intent": intent.duplicate(true),
	}.duplicate(true)
	return _last_mudds_station_return_intent_result.duplicate(true)


func _mudds_station_return_handoff_rejection(
		intent: Dictionary,
		binding_snapshot: Dictionary,
		coordinate_frame_generation: int
	) -> StringName:
	if intent.size() != _flow.EMBER_STATION_RETURN_HANDOFF_KEYS.size():
		return &"station_return_handoff_schema_invalid"
	for key in _flow.EMBER_STATION_RETURN_HANDOFF_KEYS:
		if not intent.has(key):
			return &"station_return_handoff_schema_invalid"
	if int(intent.get("schema_version", 0)) != 1 \
			or StringName(intent.get("intent_id", &"")) \
				!= &"ember_station_return_handoff" \
			or StringName(intent.get("destination_id", &"")) \
				!= _flow.MUDDS_RETURN_TARGET_ID \
			or StringName(intent.get("activity_id", &"")) \
				!= &"ember_beacon_survey" \
			or int(intent.get("activity_generation", 0)) < 1 \
			or bool(intent.get("arrival_confirmed", true)) \
			or not intent.get("evidence_sequence") is PackedStringArray \
			or intent.get("evidence_sequence") \
				!= PackedStringArray(_flow.EMBER_STATION_RETURN_EVIDENCE_SEQUENCE):
		return &"station_return_handoff_contract_invalid"
	if not is_instance_valid(_flow.active_ship) or not is_instance_valid(_flow.player) \
			or int(intent.get("actor_instance_id", 0)) \
				!= _flow.player.get_instance_id() \
			or int(intent.get("craft_instance_id", 0)) \
				!= _flow.active_ship.get_instance_id():
		return &"station_return_handoff_actor_drift"
	if not is_instance_valid(_flow.ember_surface_loop_host):
		return &"station_return_handoff_host_drift"
	var host_snapshot := _flow.ember_surface_loop_host.get_snapshot()
	var host_identities := host_snapshot.get("identities", {}) as Dictionary
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) \
				!= EmberSurfaceLoopHost.Phase.ORBIT_RETURN \
			or int(intent.get("session_generation", 0)) \
				!= _flow.ember_surface_loop_host.get_generation() \
			or int(intent.get("attachment_generation", 0)) \
				!= _flow.ember_surface_loop_host.get_attachment_generation() \
			or int(host_identities.get("player_instance_id", 0)) \
				!= _flow.player.get_instance_id() \
			or int(host_identities.get("ship_instance_id", 0)) \
				!= _flow.active_ship.get_instance_id():
		return &"station_return_handoff_host_drift"
	var retained := binding_snapshot.get("retained_return_context", {}) as Dictionary
	if int(retained.get("host_instance_id", 0)) \
			!= _flow.ember_surface_loop_host.get_instance_id() \
			or int(retained.get("host_generation", -1)) \
				!= int(intent.get("session_generation", 0)) \
			or int(retained.get("host_attachment_generation", -1)) \
				!= int(intent.get("attachment_generation", 0)) \
			or int(retained.get("session_instance_id", 0)) == 0 \
			or int(retained.get("actor_instance_id", 0)) \
				!= _flow.player.get_instance_id() \
			or int(retained.get("craft_instance_id", 0)) \
				!= _flow.active_ship.get_instance_id() \
			or binding_snapshot.get("station_return_handoff_intent", {}) != intent:
		return &"station_return_handoff_session_drift"
	if coordinate_frame_generation < 1 \
			or int(intent.get("coordinate_frame_generation", 0)) \
				!= coordinate_frame_generation \
			or int(host_snapshot.get("coordinate_frame_generation", 0)) \
				!= coordinate_frame_generation:
		return &"station_return_handoff_frame_drift"
	if not is_instance_valid(_flow.ember_streaming_bootstrap):
		return &"station_return_handoff_frame_unavailable"
	var frame := _flow.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if not is_instance_valid(frame) or frame.get_generation() \
			!= coordinate_frame_generation:
		return &"station_return_handoff_frame_drift"
	var orbital_validation := frame.validate_orbital_coordinate(
		intent.get("orbital_coordinate", {})
	)
	if not bool(orbital_validation.get("accepted", false)) \
			or orbital_validation.get("coordinate", {}) \
				!= intent.get("orbital_coordinate", {}):
		return &"station_return_handoff_coordinate_invalid"
	var authority := intent.get("authority", {}) as Dictionary
	if authority.size() != _flow.EMBER_STATION_RETURN_AUTHORITY_KEYS.size():
		return &"station_return_handoff_claims_authority"
	for key in _flow.EMBER_STATION_RETURN_AUTHORITY_KEYS:
		if not authority.has(key) or bool(authority.get(key, true)):
			return &"station_return_handoff_claims_authority"
	return &""


func _advance_mudds_return_approach_handoff(
		coordinate_frame_generation: int
	) -> Dictionary:
	if _mudds_return_handback_consumption_attempted \
			or _mudds_return_approach_active \
			or _mudds_return_approach_completion_attempted:
		return {"accepted": false, "reason": &"return_approach_handoff_already_observed"}
	if not is_instance_valid(_flow.ember_surface_loop_production_binding) \
			or not is_instance_valid(_flow.planetary_cruise_binding):
		return {"accepted": false, "reason": &"return_approach_binding_unavailable"}
	if _flow.ember_surface_loop_production_binding.get_state() != EmberSurfaceLoopProductionBinding.State.HANDOFF_PENDING:
		return {"accepted": false, "reason": &"return_approach_handoff_not_pending"}
	_mudds_return_handback_consumption_attempted = true
	var handback := _flow.ember_surface_loop_production_binding.take_completion_handback(
		_flow.ember_surface_loop_production_binding.get_generation()
	)
	if not bool(handback.get("accepted", false)):
		_last_mudds_return_approach_result = handback.duplicate(true)
		return handback
	var ownership := handback.get("runtime_ownership_return", {}) as Dictionary
	var handback_reason := _mudds_return_handback_rejection(ownership)
	if not handback_reason.is_empty():
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": handback_reason,
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	_mudds_return_handback_receipt = ownership.duplicate(true)
	_ember_surface_journey_active = false
	if _mudds_station_return_intent_receipt.is_empty():
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_station_intent_required",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	if int(_mudds_station_return_intent_receipt.get(
			"coordinate_frame_generation", 0
		)) != coordinate_frame_generation:
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_station_intent_stale",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var target_result := _build_mudds_return_approach_target()
	if not bool(target_result.get("accepted", false)):
		_last_mudds_return_approach_result = target_result.duplicate(true)
		return target_result
	if coordinate_frame_generation < 1:
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_coordinate_frame_unavailable",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var cruise_snapshot := _flow.planetary_cruise_binding.get_snapshot()
	if bool(cruise_snapshot.get("engagement_requested", false)):
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_cruise_already_engaged",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var engaged := _flow.planetary_cruise_binding.request_engage(
		_flow.active_ship, coordinate_frame_generation,
		_flow._planetary_cruise_gate_reason(false),
		_flow.planetary_cruise_binding.get_generation(), true,
	)
	if not bool(engaged.get("accepted", false)):
		_last_mudds_return_approach_result = engaged.duplicate(true)
		return engaged
	var armed := _flow.planetary_cruise_binding.request_return_approach(
		target_result.get("target", {}) as Dictionary,
		coordinate_frame_generation,
		_flow.planetary_cruise_binding.get_generation(),
		_flow.world.ship_spawn,
	)
	if not bool(armed.get("accepted", false)):
		_flow.planetary_cruise_binding.request_disengage(
			_flow.planetary_cruise_binding.get_generation(), true
		)
		_last_mudds_return_approach_result = armed.duplicate(true)
		return armed
	_mudds_return_approach_active = true
	_last_mudds_return_approach_result = armed.duplicate(true)
	return armed


func _mudds_return_handback_rejection(receipt: Dictionary) -> StringName:
	if not is_instance_valid(_flow.active_ship) or not is_instance_valid(_flow.player):
		return &"return_approach_actor_unavailable"
	if receipt.get("reason", &"") != &"runtime_ownership_returned" \
			or int(receipt.get("ship_instance_id", 0)) != _flow.active_ship.get_instance_id() \
			or int(receipt.get("player_instance_id", 0)) != _flow.player.get_instance_id():
		return &"return_approach_handback_identity_mismatch"
	if not bool(receipt.get("command_source_restored", false)) \
			or not bool(receipt.get("boarding_reservation_retained", false)) \
			or not bool(receipt.get("ship_piloted", false)) \
			or not bool(receipt.get("player_seated", false)) \
			or bool(receipt.get("host_attached", true)) \
			or not _flow.active_ship.is_piloted() \
			or not bool(_flow.player.call(&"is_seated")):
		return &"return_approach_handback_state_mismatch"
	var retired_generation := int(receipt.get("retired_attachment_generation", 0))
	if retired_generation < 1 \
			or int(receipt.get("current_attachment_generation", 0)) \
				!= retired_generation + 1:
		return &"return_approach_handback_generation_mismatch"
	if not _mudds_station_return_intent_receipt.is_empty() \
			and (int(receipt.get("generation", 0)) \
			!= int(_mudds_station_return_intent_receipt.get(
				"session_generation", -1
			)) \
			or retired_generation \
				!= int(_mudds_station_return_intent_receipt.get(
					"attachment_generation", -1
				))):
		return &"return_approach_station_intent_generation_mismatch"
	return &""


func _build_mudds_return_approach_target() -> Dictionary:
	if not is_instance_valid(_flow.world) or not _flow.world.has_method(&"get_ship_spawn"):
		return {"accepted": false, "reason": &"return_approach_home_target_unavailable"}
	var home_transform := _flow.world.call(&"get_ship_spawn") as Transform3D
	if not home_transform.origin.is_finite() \
			or not home_transform.basis.x.is_finite() \
			or not home_transform.basis.y.is_finite() \
			or not home_transform.basis.z.is_finite() \
			or is_zero_approx(home_transform.basis.determinant()):
		return {"accepted": false, "reason": &"return_approach_home_target_invalid"}
	var fleet_bounds: Dictionary = {}
	var maximum_x := 0.0
	var maximum_y := 0.0
	for fleet_ship in _flow.ships:
		if not is_instance_valid(fleet_ship):
			return {"accepted": false, "reason": &"return_approach_fleet_hull_unavailable"}
		var ship_id := fleet_ship.get_ship_id()
		# The return proof covers every production flyable, including craft whose
		# home berth is owned by the expansion binding rather than ShipyardWorld.
		if not _flow.MUDDS_RETURN_FLEET_IDS.has(ship_id):
			continue
		if fleet_bounds.has(ship_id):
			return {"accepted": false, "reason": &"return_approach_fleet_roster_mismatch"}
		var collision_report := fleet_ship.get_landing_collision_report()
		var bounds := collision_report.get("local_bounds", AABB()) as AABB
		if not bool(collision_report.get("valid", false)) \
				or not bounds.position.is_finite() or not bounds.size.is_finite() \
				or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			return {"accepted": false, "reason": &"return_approach_fleet_hull_invalid"}
		fleet_bounds[ship_id] = bounds
		maximum_x = maxf(maximum_x, maxf(absf(bounds.position.x), absf(bounds.end.x)))
		maximum_y = maxf(maximum_y, maxf(absf(bounds.position.y), absf(bounds.end.y)))
	for expected_id in _flow.MUDDS_RETURN_FLEET_IDS:
		if not fleet_bounds.has(expected_id):
			return {"accepted": false, "reason": &"return_approach_fleet_roster_mismatch"}
	var corridor_half_extents := Vector3(
		maxf(
			_flow.MUDDS_RETURN_CORRIDOR_MINIMUM_HALF_WIDTH_METERS,
			maximum_x + _flow.MUDDS_RETURN_HULL_MARGIN_METERS,
		),
		maxf(
			_flow.MUDDS_RETURN_CORRIDOR_MINIMUM_HALF_WIDTH_METERS,
			maximum_y + _flow.MUDDS_RETURN_HULL_MARGIN_METERS,
		),
		_flow.MUDDS_RETURN_CORRIDOR_HALF_LENGTH_METERS,
	)
	return {
		"accepted": true,
		"reason": &"return_approach_target_ready",
		"target": {
			"home_target_id": _flow.MUDDS_RETURN_TARGET_ID,
			"home_target_world_transform": home_transform,
			"corridor_half_extents_m": corridor_half_extents,
			"brake_shell_min_distance_m": _flow.MUDDS_RETURN_BRAKE_SHELL_MINIMUM_METERS,
			"brake_shell_max_distance_m": _flow.MUDDS_RETURN_BRAKE_SHELL_MAXIMUM_METERS,
			"maximum_speed_mps": _flow.MUDDS_RETURN_MAXIMUM_SPEED_MPS,
			"maximum_attitude_degrees": _flow.MUDDS_RETURN_MAXIMUM_ATTITUDE_DEGREES,
			"hull_margin_m": _flow.MUDDS_RETURN_HULL_MARGIN_METERS,
			"fleet_collision_bounds": fleet_bounds.duplicate(true),
		}.duplicate(true),
	}.duplicate(true)


func _mudds_return_approach_completion_is_current(receipt: Dictionary) -> bool:
	if not _mudds_return_approach_active \
			or not is_instance_valid(_flow.active_ship) \
			or not is_instance_valid(_flow.planetary_cruise_binding):
		return false
	if receipt.get("reason", &"") != &"return_approach_handoff_ready" \
			or receipt.get("home_target_id", &"") != _flow.MUDDS_RETURN_TARGET_ID \
			or int(receipt.get("target_generation", 0)) < 1 \
			or int(receipt.get("ship_instance_id", 0)) != _flow.active_ship.get_instance_id():
		return false
	var release := receipt.get("controller_release", {}) as Dictionary
	var ship_report := _flow.active_ship.get_planetary_cruise_attachment_report()
	if not bool(release.get("accepted", false)) \
			or int(receipt.get("released_ship_attachment_generation", 0)) \
				!= int(ship_report.get("ship_attachment_generation", -1)) \
			or int(ship_report.get("controller_instance_id", -1)) != 0:
		return false
	var controller_completion := receipt.get("controller_completion", {}) as Dictionary
	var target := controller_completion.get("target", {}) as Dictionary
	var measurement := controller_completion.get("measurement", {}) as Dictionary
	var current_target := _build_mudds_return_approach_target()
	var expected := current_target.get("target", {}) as Dictionary
	return bool(current_target.get("accepted", false)) \
		and target.get("home_target_id", &"") == _flow.MUDDS_RETURN_TARGET_ID \
		and target.get("home_target_world_transform", Transform3D.IDENTITY) \
			== expected.get("home_target_world_transform", Transform3D.IDENTITY) \
		and target.get("fleet_collision_bounds", {}) \
			== expected.get("fleet_collision_bounds", {}) \
		and bool(measurement.get("full_flyable_fleet_corridor_proven", false))


func _consume_mudds_return_approach_completion(receipt: Dictionary) -> Dictionary:
	if _mudds_return_approach_completion_attempted:
		return {"accepted": false, "reason": &"return_approach_completion_replayed"}
	_mudds_return_approach_completion_attempted = true
	if not _mudds_return_approach_completion_is_current(receipt):
		if is_instance_valid(_flow.planetary_cruise_binding) \
				and int(receipt.get("target_generation", 0)) > 0:
			_flow.planetary_cruise_binding.discard_return_approach_completion(
				int(receipt.get("target_generation", 0)),
				_flow.planetary_cruise_binding.get_generation(),
				&"return_approach_completion_stale",
			)
		_mudds_return_approach_active = false
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_completion_stale",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var consumed := _flow.planetary_cruise_binding.consume_return_approach_completion(
		int(receipt.get("target_generation", 0)),
		_flow.planetary_cruise_binding.get_generation(),
	)
	if not bool(consumed.get("accepted", false)):
		_mudds_return_approach_active = false
		_last_mudds_return_approach_result = consumed.duplicate(true)
		return consumed
	_mudds_return_approach_completion_receipt = consumed.duplicate(true)
	_mudds_return_approach_active = false
	# Aurora owns no Ember reward/arrival state. Consume the same authenticated
	# corridor receipt, then let the ordinary berth lifecycle own local flight.
	if _aurora_return_active:
		_aurora_return_active = false
		_aurora_return_departure_pending = false
		_aurora_return_handoff_ready = true
		_last_aurora_return_result = {"accepted": true,
			"reason": &"aurora_return_handed_to_station_lifecycle",
			"receipt": consumed.duplicate(true)}
		return _last_aurora_return_result.duplicate(true)
	_ember_surface_journey_active = false
	if _ember_abandon_return_active:
		# An abandoned visit earned no station-return contract and carries no
		# physical arrival receipt, so the ordinary sandbox berth lifecycle owns
		# the last leg exactly as it owns any other sortie's landing.
		_ember_abandon_return_active = false
		_planetary_return_physical_arrival_required = false
		_flow._sortie_departed_berth = true
		if is_instance_valid(_flow.hud):
			_flow.hud.set_objective(
				"Re-align with a compatible registered berth and land",
				"EXPEDITION ABANDONED",
			)
			_flow.hud.toast(
				"Mudds approach complete",
				"Manual flight and the registered berth lifecycle now own the return",
			)
		_last_mudds_return_approach_result = {
			"accepted": true,
			"reason": &"abandoned_return_handed_to_station_lifecycle",
			"receipt": consumed.duplicate(true),
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	_planetary_return_receipt_consumed = false
	_planetary_return_physical_arrival_required = true
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result.clear()
	_flow._landing_request_active = false
	_flow._active_landing_berth_id = &""
	_flow._return_registered = false
	_flow._sortie_departed_berth = true
	_flow.phase = _flow.Phase.RETURN_TO_YARD
	_last_mudds_return_approach_result = {
		"accepted": true,
		"reason": &"return_approach_handed_to_station_lifecycle",
		"phase": _flow.Phase.RETURN_TO_YARD,
		"receipt": consumed.duplicate(true),
	}.duplicate(true)
	if is_instance_valid(_flow.hud):
		_flow.hud.set_objective(
			"Approach Mudds Shipyards and engage landing assist at a compatible berth",
			"RETURN TO YARD",
		)
		_flow.hud.toast(
			"Mudds approach complete",
			"Manual flight and the registered berth lifecycle now own the return",
		)
	return _last_mudds_return_approach_result.duplicate(true)


func _current_planetary_return_frame_generation() -> int:
	if not is_instance_valid(_flow.ember_streaming_bootstrap):
		return 0
	var frame := _flow.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	return frame.get_generation() if is_instance_valid(frame) else 0


func _arm_planetary_return_physical_arrival(berth: ShipBerth) -> Dictionary:
	if not _planetary_return_physical_arrival_required \
			or _planetary_return_receipt_consumed:
		return {"accepted": false, "reason": &"physical_return_not_pending"}
	if _planetary_return_physical_arrival_armed:
		return {"accepted": false, "reason": &"physical_return_already_armed"}
	if not is_instance_valid(_flow.active_ship) or not is_instance_valid(_flow.player) \
			or not is_instance_valid(berth) \
			or not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.ember_surface_loop_production_binding) \
			or not _flow.ember_surface_loop_production_binding.has_method(
				&"adopt_physical_planetary_return_arrival"
			):
		return {"accepted": false, "reason": &"physical_return_owner_unavailable"}
	var craft_instance_id := _flow.active_ship.get_instance_id()
	var home_berth_id := _flow.active_ship.get_home_berth_id()
	if berth.get_berth_id() != home_berth_id \
			or StringName(_flow._reserved_berth_ids.get(craft_instance_id, &"")) \
				!= home_berth_id:
		return {"accepted": false, "reason": &"physical_return_wrong_home_berth"}
	var token := StringName(_flow._berth_tokens.get(craft_instance_id, &""))
	var definition := _flow.active_ship.get_ship_definition()
	var frame_generation := _current_planetary_return_frame_generation()
	if token.is_empty() or definition == null or frame_generation < 1:
		return {"accepted": false, "reason": &"physical_return_identity_unavailable"}
	var adopted := _flow.ember_surface_loop_production_binding.call(
		&"adopt_physical_planetary_return_arrival",
		_mudds_return_approach_completion_receipt,
		_flow.planetary_cruise_binding.get_generation(),
		frame_generation,
		berth,
		_flow.active_ship,
		definition,
		token,
		_flow.player.get_instance_id(),
		craft_instance_id,
	) as Dictionary
	_last_planetary_return_physical_arrival_result = adopted.duplicate(true)
	_planetary_return_physical_arrival_armed = bool(adopted.get("accepted", false))
	return adopted


func _abort_planetary_return_physical_arrival(reason: StringName) -> Dictionary:
	if not _planetary_return_physical_arrival_armed:
		return {"accepted": false, "reason": &"physical_return_not_armed"}
	var aborted := {"accepted": false, "reason": &"physical_return_owner_unavailable"}
	if is_instance_valid(_flow.ember_surface_loop_production_binding) \
			and _flow.ember_surface_loop_production_binding.has_method(
				&"abort_physical_planetary_return_arrival"
			):
		aborted = _flow.ember_surface_loop_production_binding.call(
			&"abort_physical_planetary_return_arrival", reason
		) as Dictionary
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result = aborted.duplicate(true)
	return aborted


func _complete_planetary_return_physical_arrival(
		berth: ShipBerth, landing_report: Dictionary
	) -> Dictionary:
	if not _planetary_return_physical_arrival_required \
			or not _planetary_return_physical_arrival_armed \
			or _planetary_return_receipt_consumed:
		return {"accepted": false, "reason": &"physical_return_not_armed"}
	if not is_instance_valid(berth) \
			or not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"physical_return_owner_unavailable"}
	var shell_generation := _flow.planetary_cruise_binding.get_generation()
	var frame_generation := _current_planetary_return_frame_generation()
	var confirmed := _flow.ember_surface_loop_production_binding.call(
		&"confirm_physical_planetary_return_arrival",
		landing_report,
		shell_generation,
		frame_generation,
	) as Dictionary
	if not bool(confirmed.get("accepted", false)):
		_last_planetary_return_physical_arrival_result = confirmed.duplicate(true)
		_abort_planetary_return_physical_arrival(&"physical_landing_confirmation_rejected")
		return confirmed
	var terminal := _flow.ember_surface_loop_production_binding.call(
		&"complete_physical_planetary_return_arrival",
		confirmed,
		shell_generation,
		frame_generation,
	) as Dictionary
	if not bool(terminal.get("accepted", false)):
		_last_planetary_return_physical_arrival_result = terminal.duplicate(true)
		_abort_planetary_return_physical_arrival(&"physical_landing_completion_rejected")
		return terminal
	var consumed := consume_planetary_return_receipt(
		terminal,
		_flow.ember_surface_loop_production_binding,
		berth,
		_flow.active_ship,
		_flow.player,
	) as Dictionary
	_last_planetary_return_physical_arrival_result = consumed.duplicate(true)
	_planetary_return_physical_arrival_armed = false
	if not bool(consumed.get("accepted", false)):
		return consumed
	_planetary_return_physical_arrival_required = false
	return consumed


## Gives up an expedition that has already started.
##
## The rule, in full. Before the Host leaves `IDLE` — the craft is still cruising
## out to Ember — this is the ordinary cancel: the cruise disengages and there is
## no expedition. Once the Host has started, the abandon terminalizes the relay
## survey's activity generation with no reward, retires the visit-scoped surface
## composition, releases the caldera lease and every piece of runtime ownership
## the Host held, and resets the retained Host in place to `IDLE`, so the same
## `Main` admits another expedition immediately. The craft then flies home on the
## same Mudds return approach the completed loop uses, and the player lands at
## their own berth through the ordinary yard lifecycle.
##
## An abandon never separates a pilot from their craft. Asked while the craft is
## on, or committed to, the caldera pad, it is recorded as pending: the authored
## survey route and its re-board gate lift at once, the player walks back to
## their craft and boards it, and the Host's own takeoff carries the abandon
## until the craft is physically off the pad and climbing, where it commits.
## Until then the pilot keeps control and the craft keeps its pad lease.
func abandon_ember_surface_journey(
	reason: StringName = &"player_abandoned"
) -> Dictionary:
	if _pending_ember_surface_request.is_empty() \
			and not _ember_surface_journey_active:
		return {"accepted": false, "reason": &"ember_surface_request_not_pending"}
	var host := _flow.ember_surface_loop_host
	if not is_instance_valid(host) \
			or host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE:
		return cancel_ember_surface_journey()
	var abandoned: Dictionary = host.abandon(
		host.get_generation(), host.get_attachment_generation(), reason
	)
	_last_ember_surface_abandon_result = abandoned.duplicate(true)
	if not bool(abandoned.get("accepted", false)):
		return abandoned
	_ember_surface_abandon_reason = reason
	_ember_abandon_observed_commit_count = int(
		host.get_abandon_snapshot().get("commit_count", 0)
	)
	if StringName(abandoned.get("reason", &"")) \
			== &"ember_surface_abandon_pending_return":
		_ember_surface_abandon_pending = true
		# The authored work is over the moment the player gives it up, even
		# though the visit itself waits for them to board. No generation keeps
		# running behind an abandoned expedition and no reward can follow.
		var binding := _flow.ember_surface_loop_production_binding
		if is_instance_valid(binding) \
				and binding.has_method(&"abort_planetary_relay_survey"):
			binding.call(&"abort_planetary_relay_survey", reason)
		if is_instance_valid(_flow.hud):
			_flow.hud.set_objective(
				"Walk back to your craft and board it to leave Ember",
				"EXPEDITION ABANDONED",
			)
			_flow.hud.toast(
				"Expedition abandoned",
				"The relay survey is cancelled — board your craft to fly home",
				3.0,
			)
		return abandoned
	var completed := _complete_ember_surface_abandon(
		reason, _current_planetary_return_frame_generation()
	)
	var result := abandoned.duplicate(true)
	result["abandon_completion"] = completed.duplicate(true)
	return result


## Watches a pending abandon the Host commits on its own cadence, and ends an
## expedition whose Host went terminal — a lost craft, a lost dependency — as an
## abandon rather than leaving the retained `Main` refusing every later visit.
func _advance_ember_surface_abandon(coordinate_frame_generation: int) -> Dictionary:
	if _ember_abandon_return_arm_pending and not _mudds_return_approach_active:
		_retry_ember_abandon_return_approach(coordinate_frame_generation)
	if not _ember_surface_journey_active:
		return {"accepted": false, "reason": &"ember_surface_abandon_not_active"}
	var host := _flow.ember_surface_loop_host
	if not is_instance_valid(host):
		return {"accepted": false, "reason": &"ember_surface_abandon_host_unavailable"}
	if _ember_surface_abandon_pending:
		var abandon := host.get_abandon_snapshot()
		if int(abandon.get("commit_count", 0)) \
				> _ember_abandon_observed_commit_count:
			_ember_abandon_observed_commit_count = int(abandon.get("commit_count", 0))
			return _complete_ember_surface_abandon(
				_ember_surface_abandon_reason, coordinate_frame_generation
			)
	if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
		return abandon_ember_surface_journey(
			StringName(host.get_snapshot().get("terminal_reason", &"host_terminal"))
		)
	return {"accepted": false, "reason": &"ember_surface_abandon_not_pending"}


func _complete_ember_surface_abandon(
	reason: StringName, coordinate_frame_generation: int
) -> Dictionary:
	_ember_surface_abandon_pending = false
	_ember_surface_abandon_count += 1
	var retired: Dictionary = {}
	var binding := _flow.ember_surface_loop_production_binding
	if is_instance_valid(binding) \
			and binding.has_method(&"abandon_planetary_surface"):
		retired = binding.call(&"abandon_planetary_surface", reason) as Dictionary
	if is_instance_valid(_flow.planetary_cruise_binding):
		var cruise := _flow.planetary_cruise_binding
		var cruise_snapshot := cruise.get_snapshot()
		var final_approach := cruise_snapshot.get("final_approach", {}) as Dictionary
		var completion := final_approach.get("completion_receipt", {}) as Dictionary
		if not completion.is_empty():
			cruise.discard_final_approach_completion(
				int(completion.get("target_generation", 0)),
				cruise.get_generation(),
				&"ember_surface_journey_abandoned",
			)
		if bool(cruise_snapshot.get("engagement_requested", false)):
			cruise.request_disengage(cruise.get_generation(), false)
	_ember_surface_journey_active = false
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	_last_ember_final_approach_rearm_result.clear()
	_ember_survey_start_context.clear()
	_ember_survey_return_manifest.clear()
	_pending_ember_surface_request.clear()
	_pending_ember_surface_host = null
	_pending_ember_surface_director = null
	_pending_ember_surface_reward_sink = Callable()
	_pending_ember_surface_serial = 0
	_mudds_return_handback_consumption_attempted = false
	_mudds_return_handback_receipt.clear()
	_mudds_station_return_intent_consumption_attempted = false
	_mudds_station_return_intent_receipt.clear()
	_mudds_return_approach_completion_attempted = false
	_mudds_return_approach_completion_receipt.clear()
	_planetary_return_physical_arrival_required = false
	_planetary_return_physical_arrival_armed = false
	_ember_abandon_return_arm_pending = true
	_ember_abandon_return_arm_attempts = 0
	var armed := _arm_ember_abandon_return_approach(coordinate_frame_generation)
	if is_instance_valid(_flow.hud):
		_flow.hud.set_objective(
			"Fly clear of Ember's surface, then release flight controls for the Mudds return",
			"EXPEDITION ABANDONED",
		)
		_flow.hud.toast(
			"Ember expedition abandoned",
			"No survey reward was granted — fly clear of the terrain to begin the return",
			3.0,
		)
	return {
		"accepted": true,
		"reason": &"ember_surface_journey_abandoned",
		"abandon_reason": reason,
		"abandon_count": _ember_surface_abandon_count,
		"surface_retirement": retired.duplicate(true),
		"return_approach": armed.duplicate(true),
	}.duplicate(true)


func _arm_ember_abandon_return_approach(
	coordinate_frame_generation: int
) -> Dictionary:
	if not _ember_abandon_return_arm_pending:
		return {"accepted": false, "reason": &"abandon_return_not_pending"}
	if not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.active_ship) \
			or not _flow.active_ship.is_piloted():
		_ember_abandon_return_arm_pending = false
		_ember_abandon_return_active = false
		_last_ember_abandon_return_arm_result = {
			"accepted": false, "reason": &"abandon_return_actor_unavailable",
		}.duplicate(true)
		return _last_ember_abandon_return_arm_result.duplicate(true)
	var gate_reason := _flow._planetary_cruise_gate_reason(false)
	if not gate_reason.is_empty():
		var refusal := {"accepted": false, "reason": gate_reason}
		if gate_reason != &"origin_rebase_pending":
			return _retire_abandon_return_departure(refusal)
		_last_ember_abandon_return_arm_result = refusal
		return refusal
	if _flow.active_ship.has_manual_flight_intent():
		_last_ember_abandon_return_arm_result = {
			"accepted": false, "reason": &"manual_departure_required",
		}
		return _last_ember_abandon_return_arm_result.duplicate(true)
	var frame_generation := coordinate_frame_generation
	if frame_generation < 1:
		frame_generation = _current_planetary_return_frame_generation()
	if frame_generation < 1:
		_last_ember_abandon_return_arm_result = {
			"accepted": false,
			"reason": &"abandon_return_coordinate_frame_unavailable",
		}.duplicate(true)
		return _retire_abandon_return_departure(_last_ember_abandon_return_arm_result)
	var target_result := _build_mudds_return_approach_target()
	if not bool(target_result.get("accepted", false)):
		return _retire_abandon_return_departure(target_result)
	var cruise := _flow.planetary_cruise_binding
	if not bool(cruise.get_snapshot().get("engagement_requested", false)):
		var engaged := cruise.request_engage(
			_flow.active_ship, frame_generation, gate_reason,
			cruise.get_generation(), true,
		)
		if not bool(engaged.get("accepted", false)):
			# A refused terrain proof first releases the attachment with braking.
			# Wait for that existing brake to settle before retrying admission.
			if engaged.get("reason") == &"braking_in_progress":
				_last_ember_abandon_return_arm_result = engaged.duplicate(true)
				return engaged
			return _retire_abandon_return_departure(engaged)
	var armed := cruise.request_return_approach(
		target_result.get("target", {}) as Dictionary,
		frame_generation,
		cruise.get_generation(),
		_flow.world.ship_spawn,
	)
	if not bool(armed.get("accepted", false)):
		return _retire_abandon_return_departure(armed)
	# Metadata admission is not flight: terrain may still refuse the first proof.
	_ember_abandon_return_active = true
	_mudds_return_approach_active = true
	_last_ember_abandon_return_arm_result = armed.duplicate(true)
	_last_mudds_return_approach_result = armed.duplicate(true)
	return armed


## A queued return survives local clearance refusal only until its first actual
## cruise participation. Manual ascent uses no retry budget; after cruise starts,
## ordinary manual override cancels it permanently.
func _observe_abandon_return_departure_tick(tick: Dictionary) -> void:
	if not _ember_abandon_return_arm_pending:
		return
	if tick.get("reason") == &"return_approach_handoff_ready":
		_ember_abandon_return_arm_pending = false
		return
	var controller := tick.get("controller", {}) as Dictionary
	var policy := controller.get("policy", {}) as Dictionary
	if bool(tick.get("accepted", false)):
		if bool(policy.get("desired_cruise_participation", false)):
			_ember_abandon_return_arm_pending = false
		return
	var reason := StringName(tick.get("reason", &""))
	if reason == &"obstacle_detected":
		_last_ember_abandon_return_arm_result = tick.duplicate(true)
		return
	# Holding flight controls before propulsion is the authored local departure,
	# not cancellation of a journey that has started. Actor loss is always final.
	if reason == &"ship_attachment_retired" \
			and is_instance_valid(_flow.active_ship) and _flow.active_ship.is_piloted() \
			and _flow.active_ship.has_manual_flight_intent():
		_last_ember_abandon_return_arm_result = {
			"accepted": false, "reason": &"manual_departure_required",
		}
		return
	_ember_abandon_return_arm_pending = false
	_ember_abandon_return_active = false
	_last_ember_abandon_return_arm_result = tick.duplicate(true)


func is_return_departure_pending() -> bool:
	return _ember_abandon_return_arm_pending or _aurora_return_departure_pending


func cancel_return_departure(
	reason: StringName = &"player_cancelled", brake_to_stop: bool = true
) -> Dictionary:
	if not _ember_abandon_return_arm_pending and not _ember_abandon_return_active \
			and not _aurora_return_active:
		return {"accepted": false, "reason": &"return_departure_not_pending"}
	if is_instance_valid(_flow.planetary_cruise_binding):
		var cruise := _flow.planetary_cruise_binding
		if bool(cruise.get_snapshot().get("engagement_requested", false)):
			var released := cruise.request_disengage(cruise.get_generation(), brake_to_stop)
			if not bool(released.get("accepted", false)):
				return released
	if _aurora_return_active:
		_aurora_return_departure_pending = false
		_aurora_return_active = false
		_last_aurora_return_result = {"accepted": true, "reason": reason}
	_ember_abandon_return_arm_pending = false
	_ember_abandon_return_active = false
	_mudds_return_approach_active = false
	_last_ember_abandon_return_arm_result = {"accepted": true, "reason": reason}
	return _last_ember_abandon_return_arm_result.duplicate(true)


func _retry_ember_abandon_return_approach(
	coordinate_frame_generation: int
) -> Dictionary:
	if _ember_abandon_return_arm_attempts >= MAX_ABANDON_RETURN_ARM_ATTEMPTS:
		# A held local departure remains flyable even after earlier idle refusals.
		if not is_instance_valid(_flow.active_ship) \
				or not _flow.active_ship.has_manual_flight_intent():
			return _retire_abandon_return_departure({
				"accepted": false, "reason": &"abandon_return_arm_exhausted",
			})
	var result := _arm_ember_abandon_return_approach(coordinate_frame_generation)
	if result.get("reason") != &"manual_departure_required":
		_ember_abandon_return_arm_attempts += 1
	return result


func _retire_abandon_return_departure(result: Dictionary) -> Dictionary:
	cancel_return_departure(StringName(result.get("reason", &"return_departure_refused")))
	_last_ember_abandon_return_arm_result = result.duplicate(true)
	return result


func cancel_ember_surface_journey() -> Dictionary:
	if _pending_ember_surface_request.is_empty() \
			and not _ember_surface_journey_active:
		return {"accepted": false, "reason": &"ember_surface_request_not_pending"}
	if is_instance_valid(_flow.ember_surface_loop_host) \
			or is_instance_valid(_flow.ember_surface_loop_production_binding):
		var host_phase := _flow.ember_surface_loop_host.get_phase() \
			if is_instance_valid(_flow.ember_surface_loop_host) else -1
		if host_phase != EmberSurfaceLoopHost.Phase.IDLE:
			return {"accepted": false, "reason": &"ember_surface_journey_already_started"}
	if is_instance_valid(_flow.planetary_cruise_binding):
		var cruise_snapshot: Dictionary = _flow.planetary_cruise_binding.get_snapshot()
		if bool(cruise_snapshot.get("engagement_requested", false)):
			var disengaged: Dictionary = _flow.planetary_cruise_binding.request_disengage(
				_flow.planetary_cruise_binding.get_generation(), true
			)
			if not bool(disengaged.get("accepted", false)):
				return disengaged
		else:
			var final_snapshot := cruise_snapshot.get("final_approach", {}) as Dictionary
			var completion := final_snapshot.get("completion_receipt", {}) as Dictionary
			if not completion.is_empty():
				var discarded := _flow.planetary_cruise_binding.discard_final_approach_completion(
					int(completion.get("target_generation", 0)),
					_flow.planetary_cruise_binding.get_generation(),
					&"ember_surface_journey_cancelled",
				)
				if not bool(discarded.get("accepted", false)):
					return discarded
	_pending_ember_surface_request.clear()
	_pending_ember_surface_host = null
	_pending_ember_surface_director = null
	_pending_ember_surface_reward_sink = Callable()
	_pending_ember_surface_serial = 0
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	_ember_surface_journey_active = false
	return {"accepted": true, "reason": &"ember_surface_request_cancelled"}


func _forward_pending_ember_surface_journey() -> Dictionary:
	if _pending_ember_surface_request.is_empty():
		return {"accepted": false, "reason": &"ember_surface_request_not_pending"}
	if not is_instance_valid(_pending_ember_surface_host) \
			or not is_instance_valid(_pending_ember_surface_director) \
			or not _pending_ember_surface_reward_sink.is_valid():
		cancel_ember_surface_journey()
		return {"accepted": false, "reason": &"ember_surface_request_stale"}
	var host := _pending_ember_surface_host
	var director := _pending_ember_surface_director
	var reward_sink := _pending_ember_surface_reward_sink
	var caller_serial := _pending_ember_surface_serial
	var retained_request := _pending_ember_surface_request.duplicate(true)
	# This is an internal handoff, not a caller cancellation. Clearing through
	# cancel_ember_surface_journey() disengages the cruise binding immediately
	# before begin_ember_surface_journey() tries to admit the ready surface
	# composition, losing the retained request if that admission rejects.
	_pending_ember_surface_request.clear()
	_pending_ember_surface_host = null
	_pending_ember_surface_director = null
	_pending_ember_surface_reward_sink = Callable()
	_pending_ember_surface_serial = 0
	var forwarded := begin_ember_surface_journey(
		host, director, reward_sink, caller_serial
	)
	if not bool(forwarded.get("accepted", false)):
		_pending_ember_surface_request = retained_request
		_pending_ember_surface_host = host
		_pending_ember_surface_director = director
		_pending_ember_surface_reward_sink = reward_sink
		_pending_ember_surface_serial = caller_serial
	return forwarded


func consume_planetary_return_receipt(
		receipt: Variant, planetary_binding: Object = null,
		return_berth: ShipBerth = null, return_craft: Node = null,
		return_actor: Node = null, travel_session: Object = null,
		return_contract: Object = null
	) -> Dictionary:
	if _planetary_return_receipt_consumed:
		return {"accepted": false, "reason": &"planetary_return_receipt_replayed"}
	if _flow.phase != _flow.Phase.RETURN_TO_YARD:
		return {"accepted": false, "reason": &"planetary_return_phase_mismatch"}
	if not receipt is Dictionary:
		return {"accepted": false, "reason": &"planetary_return_receipt_invalid"}
	var returned := receipt as Dictionary
	if planetary_binding == null:
		planetary_binding = _flow.ember_surface_loop_production_binding
	if not bool(returned.get("accepted", false)) \
			or StringName(returned.get("reason", &"")) != &"returned_to_station":
		return {"accepted": false, "reason": &"planetary_return_receipt_invalid"}
	var berth_receipt := returned.get("berth_receipt", {}) as Dictionary
	var contract_receipt := returned.get("contract_receipt", {}) as Dictionary
	if not bool(berth_receipt.get("accepted", false)) \
			or StringName(berth_receipt.get("reason", &"")) != &"return_berth_occupied" \
			or not bool(contract_receipt.get("accepted", false)):
		return {"accepted": false, "reason": &"planetary_return_receipt_invalid"}
	var craft: Node = return_craft if return_craft != null else _flow.active_ship
	var actor: Node = return_actor if return_actor != null else _flow.player
	if craft == null or actor == null or not is_instance_valid(craft) \
			or not is_instance_valid(actor):
		return {"accepted": false, "reason": &"planetary_return_actor_unavailable"}
	var craft_id := int(berth_receipt.get("craft_instance_id", 0))
	var actor_id := int(berth_receipt.get("actor_instance_id", 0))
	if craft_id < 1 or actor_id < 1 \
			or craft.get_instance_id() != craft_id \
			or actor.get_instance_id() != actor_id:
		return {"accepted": false, "reason": &"planetary_return_actor_mismatch"}
	var session_generation := int(berth_receipt.get("session_generation", 0))
	var attachment_generation := int(berth_receipt.get("attachment_generation", 0))
	if session_generation < 1 or attachment_generation < 1:
		return {"accepted": false, "reason": &"planetary_return_generation_invalid"}
	if planetary_binding != null:
		if planetary_binding.has_method(&"get_generation") \
				and int(planetary_binding.call(&"get_generation")) != session_generation:
			return {"accepted": false, "reason": &"planetary_return_stale_generation"}
		if planetary_binding.has_method(&"get_planetary_surface_snapshot"):
			var surface_snapshot := planetary_binding.call(&"get_planetary_surface_snapshot") as Dictionary
			var current_attachment := int(surface_snapshot.get("attachment_generation", attachment_generation))
			if current_attachment != attachment_generation:
				return {"accepted": false, "reason": &"planetary_return_stale_attachment"}
	if craft.has_method(&"is_piloted") and not bool(craft.call(&"is_piloted")):
		return {"accepted": false, "reason": &"planetary_return_craft_not_piloted"}
	var berth := return_berth
	if berth == null and is_instance_valid(_flow.world) and _flow.world.has_method(&"get_berth_node"):
		berth = _flow.world.call(&"get_berth_node", StringName(berth_receipt.get("berth_id", &""))) as ShipBerth
	if berth == null or not is_instance_valid(berth) \
			or not berth.is_occupied() \
			or berth.get_occupant() != craft:
		return {"accepted": false, "reason": &"planetary_return_berth_not_occupied"}
	var ship_id := StringName(craft.call(&"get_ship_id")) if craft.has_method(&"get_ship_id") else &""
	var token := StringName(berth_receipt.get("token", &""))
	if ship_id.is_empty() or token.is_empty() \
			or not berth.has_valid_lease(craft, token, ship_id):
		return {"accepted": false, "reason": &"planetary_return_berth_lease_invalid"}
	if planetary_binding != null and planetary_binding.has_method(&"detach_planetary_surface"):
		if travel_session != null and return_contract != null \
				and planetary_binding.has_method(&"save_planetary_return_persistence") \
				and _flow._runtime_settings_user_data_store != null:
			var commit_id := "planetary-return-%d-%d" % [actor_id, craft_id]
			var saved: Dictionary = planetary_binding.call(
				&"save_planetary_return_persistence", travel_session, return_contract,
				receipt, _flow._runtime_settings_user_data_store.get_generation(), commit_id
			)
			if not bool(saved.get("accepted", false)):
				return {"accepted": false, "reason": &"planetary_return_persistence_commit_rejected", "store": saved}
		var detached := planetary_binding.call(&"detach_planetary_surface") as Dictionary
		if not bool(detached.get("accepted", false)):
			return {"accepted": false, "reason": &"planetary_return_attachment_detach_rejected"}
	_planetary_return_receipt_consumed = true
	_flow._landing_request_active = false
	_flow._active_landing_berth_id = &""
	_flow._return_registered = true
	_flow.phase = _flow.Phase.SHUT_DOWN
	if is_instance_valid(_flow.hud):
		_flow.publish_first_sortie_tutorial_phase(&"exit", _flow._first_sortie_tutorial_generation)
		_flow.hud.set_objective("Hold controls neutral, then exit %s" % craft.name)
		_flow.hud.toast("Return complete", "Authoritative Mudds Shipyards berth occupied — propulsion will idle offline")
	return {"accepted": true, "reason": &"planetary_return_consumed", "phase": _flow.Phase.SHUT_DOWN, "berth_id": berth.get_berth_id(), "craft_instance_id": craft_id, "actor_instance_id": actor_id}


func _announce_committed_origin_rebase(receipt: Dictionary) -> Dictionary:
	var result := {"cruise": {}, "host": {}}
	if is_instance_valid(_flow.planetary_cruise_binding) \
			and bool(_flow.planetary_cruise_binding.get_snapshot().get(
				"engagement_requested", false
			)):
		result["cruise"] = _flow.planetary_cruise_binding.accept_committed_origin_rebase(
			receipt, _flow.planetary_cruise_binding.get_generation()
		)
	var host := _flow.ember_surface_loop_host
	if is_instance_valid(host) and host.is_attached() \
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
			and (_ember_surface_journey_active
				or not _pending_ember_surface_request.is_empty()):
		result["host"] = host.adopt_committed_origin_rebase(
			receipt, host.get_generation(), host.get_attachment_generation(),
			host.get_location_generation()
		)
	return result.duplicate(true)


func _ember_outbound_transit_wanted() -> bool:
	if _mudds_return_approach_active or _ember_abandon_return_active:
		return false
	if not _pending_ember_surface_request.is_empty():
		return true
	if not _ember_surface_journey_active or _ember_final_approach_handoff_ready \
			or not _ember_final_approach_completion_receipt.is_empty():
		return false
	var host := _flow.ember_surface_loop_host
	return not is_instance_valid(host) or not host.is_attached() \
		or host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE


## Keeps the outbound cruise engaged for the whole 8,000 km. The cruise binding
## releases the craft to its pilot on any refusal — a manual flight command, an
## obstacle in the swept corridor, a whole-Main re-entry — and while the
## expedition is still wanted the transit owner asks for it again on the next
## clean tick. A pilot holding the controls therefore keeps them; releasing them
## resumes the leg. The armed approach is re-established by the existing re-arm.
func _resume_ember_outbound_transit(coordinate_frame_generation: int) -> Dictionary:
	if not _ember_outbound_transit_wanted():
		_ember_outbound_resume_attempts = 0
		return {"accepted": false, "reason": &"outbound_transit_not_wanted"}
	if not is_instance_valid(_flow.planetary_cruise_binding) \
			or not is_instance_valid(_flow.active_ship):
		return {"accepted": false, "reason": &"outbound_transit_unavailable"}
	if _flow.active_ship.has_manual_flight_intent():
		return {"accepted": false, "reason": &"manual_flight_intent"}
	var cruise := _flow.planetary_cruise_binding
	var snapshot := cruise.get_snapshot()
	if bool(snapshot.get("engagement_requested", false)):
		return {"accepted": false, "reason": &"outbound_transit_engaged"}
	if _ember_outbound_resume_attempts >= MAX_TRANSIT_RESUME_ATTEMPTS:
		return {"accepted": false, "reason": &"outbound_transit_resume_exhausted"}
	var gate_reason := _flow._planetary_cruise_gate_reason(false)
	if not gate_reason.is_empty():
		return {"accepted": false, "reason": gate_reason}
	if coordinate_frame_generation < 1 \
			or coordinate_frame_generation \
				!= int(snapshot.get("current_coordinate_frame_generation", 0)):
		return {"accepted": false, "reason": &"outbound_transit_frame_unavailable"}
	_ember_outbound_resume_attempts += 1
	var engaged := cruise.request_engage(
		_flow.active_ship, coordinate_frame_generation, &"",
		cruise.get_generation(),
		true,
	)
	return engaged
