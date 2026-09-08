extends RefCounted
## Retained owner of the one Ember expedition and its station-return handoffs.
## GameFlow calls advance_world at its existing early physics priority; actors
## still move themselves and the surface binding alone consumes the late tick.
## Dependencies are observed through the retained Main. Berth leases, boarding,
## reward persistence and ordinary yard lifecycle remain with their owners.

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
var _ember_surface_forward_count := 0
var _ember_survey_start_context: Dictionary = {}
var _ember_survey_return_manifest: Dictionary = {}
var _ember_surface_journey_active := false
var _ember_final_approach_handoff_ready := false
var _ember_final_approach_completion_receipt: Dictionary = {}
var _mudds_return_handback_consumption_attempted := false
var _mudds_return_handback_receipt: Dictionary = {}
var _mudds_station_return_intent_consumption_attempted := false
var _mudds_station_return_intent_receipt: Dictionary = {}
var _last_mudds_station_return_intent_result: Dictionary = {}
var _mudds_return_approach_active := false
var _mudds_return_approach_completion_attempted := false
var _mudds_return_approach_completion_receipt: Dictionary = {}
var _last_mudds_return_approach_result: Dictionary = {}
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
							var streaming := receipt.get("ember_streaming", {}) as Dictionary
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
	_advance_ember_surface_loop_cadence(
		delta, actor_sample, ember_origin_result, coordinate_frame_generation
	)
	_flow._sync_planetary_cruise_hud()
	return actor_sample



func detach() -> void:
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
		return {"accepted": true, "reason": &"already_bound"}
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
	var binding_snapshot := _flow.ember_surface_loop_production_binding.get_snapshot()
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
					and _ember_survey_context(binding.get_snapshot()) == context:
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
	var snapshot := _flow.ember_surface_loop_production_binding.get_snapshot()
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
		if not _ember_survey_return_is_admitted(_flow.ember_surface_loop_production_binding.get_snapshot()):
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
	if not bool(cruise_snapshot.get("engagement_requested", false)):
		var engaged := _flow.planetary_cruise_binding.request_engage(
			_flow.active_ship,
			int(cruise_snapshot.get("current_coordinate_frame_generation", 0)),
			&"",
			_flow.planetary_cruise_binding.get_generation()
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
	var binding_snapshot := _flow.ember_surface_loop_production_binding.get_snapshot()
	if not bool(binding_snapshot.get("station_return_handoff_pending", false)):
		return {
			"accepted": false,
			"reason": &"station_return_handoff_not_pending",
		}.duplicate(true)
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
	var surface_snapshot := _flow.ember_surface_loop_production_binding.get_snapshot()
	if StringName(surface_snapshot.get("state_id", &"")) != &"handoff_pending":
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
		_flow.planetary_cruise_binding.get_generation(),
	)
	if not bool(engaged.get("accepted", false)):
		_last_mudds_return_approach_result = engaged.duplicate(true)
		return engaged
	var armed := _flow.planetary_cruise_binding.request_return_approach(
		target_result.get("target", {}) as Dictionary,
		coordinate_frame_generation,
		_flow.planetary_cruise_binding.get_generation(),
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
	_ember_surface_journey_active = false
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
