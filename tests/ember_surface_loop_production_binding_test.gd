extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CALLER_DELTA := 1.0 / 12.0
const TEST_TIME_SCALE := 5.0

var _failures := PackedStringArray()
var _assertions := 0
var _original_time_scale := 1.0
var _active_production: EmberSurfaceLoopProductionBinding


class EarlyCaller:
	extends Node

	signal nested_probe_finished
	signal reentry_finished

	var production: EmberSurfaceLoopProductionBinding
	var streaming: EmberMoonStreamingProductionBinding
	var origin_owner: CommonWorldOriginRebaseOwner
	var frame: PlanetaryCoordinateFrame
	var host: EmberSurfaceLoopHost
	var ship: ArrowReconShip
	var player: PlayerController
	var enabled := false
	var actor_kind: StringName = &"ship"
	var sample_count := 0
	var last_prepare: Dictionary = {}
	var last_origin: Dictionary = {}
	var last_sample: Dictionary = {}
	var last_early_position := Vector3.ZERO
	var queued_intent: StringName = &""
	var queued_intent_serial := 0
	var last_intent: Dictionary = {}
	var frame_offset_red := 0
	var retry_after_frame_red := false
	var reenter_binding_after_prepare := false
	var caller_serial_red_offset := 0
	var last_caller_serial_red: Dictionary = {}
	var reentrant_probe: Dictionary = {}
	var take_handback_after_completion := false
	var last_handback: Dictionary = {}

	func _ready() -> void:
		process_physics_priority = -100

	func _physics_process(_delta: float) -> void:
		if not enabled:
			return
		if take_handback_after_completion:
			last_handback = production.take_completion_handback(production.get_generation())
			take_handback_after_completion = false
			return
		var actor: Node3D = ship if actor_kind == &"ship" else player
		last_sample = {
			"available": true,
			"position": actor.global_position,
			"actor_kind": actor_kind,
			"actor_instance_id": actor.get_instance_id(),
		}.duplicate(true)
		last_early_position = actor.global_position
		sample_count += 1
		var stream_result := streaming.physics_tick_from_caller_sample(
			CALLER_DELTA, last_sample
		)
		var preview := streaming.preview_origin_rebase(
			int(stream_result.get("coordinate_frame_generation", frame.get_generation()))
		)
		last_origin = origin_owner.consume_rebase_preview(preview, last_sample)
		if bool(last_origin.get("accepted", false)) \
				and last_origin.has("actor_sample"):
			last_sample = (last_origin.actor_sample as Dictionary).duplicate(true)
		var serial := int(production.get_snapshot().last_caller_serial) + 1
		var current_generation := int(last_origin.get(
			"coordinate_frame_generation", frame.get_generation()
		))
		if caller_serial_red_offset != 0:
			last_caller_serial_red = production.prepare_early_tick(
				serial + caller_serial_red_offset, CALLER_DELTA, last_sample, last_origin,
				current_generation, 1, production.get_generation(),
			)
			caller_serial_red_offset = 0
		if frame_offset_red != 0:
			last_prepare = production.prepare_early_tick(
				serial, CALLER_DELTA, last_sample, last_origin,
				current_generation + frame_offset_red, 1,
				production.get_generation(),
			)
			if retry_after_frame_red:
				reentrant_probe = last_prepare.duplicate(true)
				last_prepare = production.prepare_early_tick(
					serial, CALLER_DELTA, last_sample, last_origin,
					current_generation, 1, production.get_generation(),
				)
			frame_offset_red = 0
			retry_after_frame_red = false
		else:
			last_prepare = production.prepare_early_tick(
				serial, CALLER_DELTA, last_sample, last_origin,
				current_generation, 1, production.get_generation(),
			)
		if reenter_binding_after_prepare and bool(last_prepare.get("accepted", false)):
			var binding_parent := production.get_parent()
			binding_parent.remove_child(production)
			binding_parent.add_child(production)
			reenter_binding_after_prepare = false
			reentry_finished.emit()
		if not queued_intent.is_empty() and bool(last_prepare.get("accepted", false)):
			match queued_intent:
				&"disembark":
					last_intent = production.queue_disembark_intent(
						queued_intent_serial, production.get_generation()
					)
				&"reboard":
					last_intent = production.queue_reboard_intent(
						queued_intent_serial, production.get_generation()
					)
				&"takeoff":
					last_intent = production.queue_takeoff_intent(
						queued_intent_serial, production.get_generation()
					)
				_:
					last_intent = {"accepted": false, "reason": &"invalid_test_intent"}
			queued_intent = &""

	func arm_intent(serial: int, intent_id: StringName) -> void:
		queued_intent_serial = serial
		queued_intent = intent_id


class PartialReceiptHost:
	extends EmberSurfaceLoopHost

	var fake_generation := 0
	var fake_attachment_generation := 1
	var fake_phase := EmberSurfaceLoopHost.Phase.IDLE
	var fake_coordinate_generation := 1
	var fake_identities: Dictionary = {}
	var fake_attached := true
	var forged_live_receipt := false
	var forged_boarding_area_instance_id := 0
	var fake_ship_instance_id := 0
	var fake_player_instance_id := 0
	var fake_restored_command_source_instance_id := 0
	var fake_return_receipt: Dictionary = {}

	func get_generation() -> int: return fake_generation
	func get_attachment_generation() -> int: return fake_attachment_generation
	func get_phase() -> int: return fake_phase
	func get_snapshot() -> Dictionary:
		return {
			"attached": fake_attached,
			"phase": fake_phase,
			"generation": fake_generation,
			"attachment_generation": fake_attachment_generation,
			"coordinate_frame_generation": fake_coordinate_generation,
			"location_generation": 1,
			"identities": fake_identities.duplicate(true),
			"runtime_ownership_return": {
				"returned": not fake_return_receipt.is_empty(),
				"last_receipt": fake_return_receipt.duplicate(true),
			}.duplicate(true),
		}.duplicate(true)
	func audit() -> Dictionary: return {"valid": true}
	func start(_g: int, _a: int, _f: int) -> Dictionary:
		fake_generation += 1
		fake_phase = EmberSurfaceLoopHost.Phase.ORBIT_APPROACH
		return {"accepted": true, "reason": &"started"}
	func advance_physics(_d: float, _g: int, _a: int, _f: int, _l: int) -> Dictionary:
		fake_phase = EmberSurfaceLoopHost.Phase.COMPLETED
		return {"accepted": true, "reason": &"completed"}
	func return_runtime_ownership(_g: int, _a: int) -> Dictionary:
		fake_attachment_generation += 1
		fake_attached = false
		if forged_live_receipt:
			fake_return_receipt = {
				"schema_version": EmberSurfaceLoopHost.SCHEMA_VERSION,
				"reason": &"runtime_ownership_returned",
				"host_id": EmberSurfaceLoopHost.HOST_ID,
				"generation": fake_generation,
				"retired_attachment_generation": fake_attachment_generation - 1,
				"current_attachment_generation": fake_attachment_generation,
				"ship_instance_id": fake_ship_instance_id,
				"player_instance_id": fake_player_instance_id,
				"boarding_area_instance_id": forged_boarding_area_instance_id,
				"boarding_reservation_token_instance_id": fake_player_instance_id,
				"boarding_reservation_retained": true,
				"host_command_source_instance_id": fake_restored_command_source_instance_id + 1,
				"restored_command_source_instance_id": fake_restored_command_source_instance_id,
				"command_source_restored": true,
				"ship_piloted": true,
				"player_seated": true,
				"host_attached": false,
			}.duplicate(true)
			return {
				"accepted": true, "reason": &"runtime_ownership_returned",
				"runtime_ownership_return": fake_return_receipt.duplicate(true),
			}
		return {
			"accepted": true,
			"reason": &"runtime_ownership_returned",
			"runtime_ownership_return": {
				"schema_version": 1,
				"reason": &"runtime_ownership_returned",
			}.duplicate(true),
		}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_original_time_scale = Engine.time_scale
	Engine.time_scale = TEST_TIME_SCALE
	await _test_real_scheduler_complete_loop()
	await _test_stale_frame_and_partial_handback_reds()
	Engine.time_scale = _original_time_scale
	_finish()


func _test_real_scheduler_complete_loop() -> void:
	var fixture := await _real_fixture()
	if fixture.is_empty():
		return
	var world := fixture.world as Node3D
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	var original_source := fixture.original_source as ShipCommandSource
	var production := EmberSurfaceLoopProductionBinding.new()
	production.name = "EmberSurfaceLoopProductionBinding"
	world.add_child(production)
	_active_production = production
	var early := EarlyCaller.new()
	early.name = "GameFlowEarlyCaller"
	early.production = production
	early.streaming = fixture.origin_binding
	early.origin_owner = fixture.origin_owner
	early.frame = fixture.frame
	early.host = host
	early.ship = ship
	early.player = player
	world.add_child(early)
	await process_frame
	_check(production.configure(host, 0).accepted, "real bound Host configures exactly once")
	var planetary_director := ActivityDirector.new()
	world.add_child(planetary_director)
	var planetary_bound := production.configure_planetary_surface(
		planetary_director, Callable(self, "_planetary_reward_sink")
	)
	var planetary_discovery := production.discover_planetary_settlements(
		Vector3(92.0, 120000.5, -18.0), 20.0
	)
	var planetary_entry := production.enter_planetary_settlement(
		&"ember_habitat_spine", Vector3(92.0, 120000.5, -18.0)
	)
	_check(
		planetary_bound.accepted and planetary_discovery.accepted
			and planetary_entry.accepted
			and production.get_planetary_surface_snapshot().settlement.state == &"inside",
		"real Ember production owner consumes authored planetary settlement entry"
	)
	var planetary_rebase := production.accept_planetary_origin_rebase({
		"accepted": true,
		"source_generation": 0,
		"target_generation": 1,
		"target_location_generation": 3,
	})
	_check(
		planetary_rebase.accepted
			and planetary_rebase.reason == &"origin_rebase_accepted"
			and planetary_rebase.route_identity_preserved
			and production.get_planetary_surface_snapshot().settlement.active_structure_id == &"ember_habitat_spine",
		"caller-owned origin rebase preserves authored route and settlement identity"
	)
	var sheltered_exposure := production.submit_planetary_weather_exposure(
		&"caldera_thermal_vent", Vector3(58.0, 120000.0, -4.0),
		1000.0, 12.0, 1.0, 1.0 / 60.0, 0.8
	)
	_check(
		sheltered_exposure.accepted
			and sheltered_exposure.weather.shelter_scalar == 0.8
			and production.get_planetary_surface_snapshot().weather.valid,
		"retained Ember hazard samples authored weather and shelter without damage authority"
	)
	var solar := production.submit_planetary_solar_observation(
		Vector3.UP, Vector3(0.0, 1.0, 0.0), 180.0
	)
	_check(
		solar.accepted
			and solar.reason == &"solar_observation_accepted"
			and production.get_planetary_surface_snapshot().solar_phase.state == &"daylight",
		"caller-owned solar observation publishes bounded daylight state without a clock"
	)
	var water_entered := production.enter_planetary_water(
		Vector3(20.0, 120000.0, 0.0)
	)
	var water_contact := production.submit_planetary_water_contact(
		Vector3(20.0, 120000.0, 0.0), 25.0, Vector3(3.0, 0.0, 0.0), 1.0
	)
	_check(
		water_entered.accepted and water_contact.accepted
			and water_contact.reason == &"water_contact_sampled"
			and water_contact.recovery_request.requested
			and water_contact.recovery_request.movement_mutation == false,
		"caller-owned deep-water contact publishes a bounded shoreline recovery request"
	)
	var planetary_session := production.get_planetary_surface_session_snapshot()
	var malformed_session := planetary_session.duplicate(true)
	malformed_session.schema_version = 99
	var stale_session := planetary_session.duplicate(true)
	stale_session.attachment_generation = host.get_attachment_generation()
	_check(
		planetary_session.schema_version == 1
			and production.restore_planetary_surface_session_snapshot(malformed_session).reason == &"unsupported_planetary_session_schema"
			and production.restore_planetary_surface_session_snapshot(stale_session).reason == &"stale_planetary_attachment_generation",
		"planetary session snapshots validate schema and attachment fencing"
	)
	_check(
		production.detach_planetary_surface().accepted
			and production.get_planetary_surface_snapshot().state == &"detached",
		"real Ember production owner publishes planetary detach state",
	)
	var audit := production.audit()
	_check(
		early.process_physics_priority == -100 and ship.process_physics_priority == 0
			and player.process_physics_priority in [0, 1]
			and production.process_physics_priority == 2,
		"real scheduler order is exactly -100 then actor 0/1 then late 2",
	)
	_check(
		bool(audit.valid) and not bool(audit.snapshot.automatic_process)
			and bool(audit.snapshot.automatic_late_physics_process),
		"binding owns only its audited late physics callback",
	)
	var nested_probe: Dictionary = {}
	production.state_changed.connect(func(_snapshot: Dictionary) -> void:
		var nested := production.queue_disembark_intent(1, production.get_generation())
		nested_probe["reason"] = nested.get("reason", &"") as StringName
		early.nested_probe_finished.emit()
	)
	var streaming_before := int((fixture.origin_binding as EmberMoonStreamingProductionBinding).get_snapshot().accepted_sample_count)
	early.enabled = true
	await early.nested_probe_finished
	var start_snapshot := production.get_snapshot()
	_check(
		early.last_prepare.accepted and production.get_state() == EmberSurfaceLoopProductionBinding.State.RUNNING
			and int(start_snapshot.start_count) == 1 and int(start_snapshot.advance_count) == 0
			and int(start_snapshot.late_consume_count) == 1
			and int(start_snapshot.last_consumed_caller_serial) == 1
			and int(start_snapshot.last_prepared_physics_frame) == int(start_snapshot.last_consumed_physics_frame),
		"one same-frame early serial starts late exactly once and skips advance",
	)
	_check(
		ship.get_command_source() != original_source
			and int((host.get_snapshot().command_source as Dictionary).sample_count) == 0,
		"late S installs the Host command after the real Hero sampled S",
	)
	_check(
		nested_probe.get("reason", &"") == &"reentrant_call",
		"Host-call state signal rejects nested binding mutation",
	)
	await _one_physics()
	_check(
		int((host.get_snapshot().command_source as Dictionary).sample_count) >= 1
			and int(production.get_snapshot().advance_count) == 1,
		"the new command is visible in S+1 and one later envelope advances once",
	)
	_check(
		int((fixture.origin_binding as EmberMoonStreamingProductionBinding).get_snapshot().accepted_sample_count)
			== streaming_before + early.sample_count,
		"the fixture supplies one shared actor sample per prepared serial with no binding resample",
	)

	# N+1 and N+2 reds retry the exact same current observation in the same early
	# callback, so they cannot consume a serial or leak a late envelope.
	early.frame_offset_red = 1
	early.retry_after_frame_red = true
	await _one_physics()
	_check(
		early.reentrant_probe.reason == &"stale_coordinate_frame_generation"
			and early.last_prepare.accepted,
		"N+1 frame forgery rejects before the same-frame current-N retry",
	)
	early.frame_offset_red = 2
	early.retry_after_frame_red = true
	await _one_physics()
	_check(
		early.reentrant_probe.reason == &"stale_coordinate_frame_generation"
			and early.last_prepare.accepted,
		"N+2 frame forgery rejects without consuming the current serial",
	)

	# Commit one real owner transaction while the Host runs. The EarlyCaller then
	# passes its exact returned sample/result to the binding in that same P0 frame.
	world.global_position += Vector3(12_000.0, 0.0, 0.0)
	var adoption_before := int((host.get_snapshot().origin_rebase as Dictionary).adoption_count)
	await _one_physics()
	_check(
		early.last_origin.reason == &"rebase_committed"
			and int((host.get_snapshot().origin_rebase as Dictionary).adoption_count) == adoption_before + 1
			and int(host.get_snapshot().coordinate_frame_generation) == (fixture.frame as PlanetaryCoordinateFrame).get_generation(),
		"real N to N+1 receipt is adopted synchronously at P0 before Arrow movement",
	)
	var detached := production.get_snapshot().last_prepared_evidence as Dictionary
	var saved_origin := early.last_origin.duplicate(true)
	(early.last_origin.actor_sample as Dictionary)["position"] = Vector3.INF
	_check(
		(detached.actor_sample.position as Vector3).is_finite(),
		"only detached origin/sample evidence crosses from early to late",
	)
	early.last_origin = saved_origin
	early.last_sample = (saved_origin.actor_sample as Dictionary).duplicate(true)

	# Replay/skip failures occur in the genuine priority--100 route before it
	# prepares the current serial, so neither can consume an envelope.
	early.caller_serial_red_offset = -1
	await _one_physics()
	_check(early.last_caller_serial_red.reason == &"caller_serial_replayed", "caller replay rejects")
	early.caller_serial_red_offset = 1
	await _one_physics()
	_check(early.last_caller_serial_red.reason == &"caller_serial_skipped", "caller skip rejects")

	_check(
		await _wait_phase(fixture, EmberSurfaceLoopHost.Phase.LANDED, 660),
		"real loop reaches LANDED",
	)
	early.arm_intent(2, &"takeoff")
	await _one_physics()
	_check(early.last_intent.reason == &"intent_serial_skipped", "intent serial skip rejects before Host mutation")
	early.arm_intent(1, &"takeoff")
	await _one_physics()
	_check(early.last_intent.reason == &"host_intent_phase_mismatch", "out-of-order takeoff intent rejects")
	early.arm_intent(1, &"disembark")
	await _one_physics()
	_check(
		early.last_intent.accepted and int(production.get_snapshot().intent_consume_count) == 1,
		"typed disembark intent is queued and consumed once at late priority 2",
	)
	_check(await _wait_phase(fixture, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 300), "real disembark reaches surface route")
	early.actor_kind = &"player"
	_check(await _walk_outbound(fixture), "real Player crosses the ordered outbound route")
	_check(await _walk_return(fixture), "real Player returns to the exact BoardingArea")
	early.arm_intent(1, &"reboard")
	await _one_physics()
	_check(early.last_intent.reason == &"intent_serial_replayed", "intent replay rejects")
	early.arm_intent(2, &"reboard")
	await _one_physics()
	_check(early.last_intent.accepted, "typed reboard intent consumes serial two")
	_check(await _wait_phase(fixture, EmberSurfaceLoopHost.Phase.REBOARDED, 30), "real reboard completes")
	early.actor_kind = &"ship"
	early.arm_intent(3, &"takeoff")
	await _one_physics()
	_check(early.last_intent.accepted, "typed takeoff intent consumes serial three")
	_check(await _wait_binding_state(
		fixture, EmberSurfaceLoopProductionBinding.State.HANDOFF_PENDING, 2700
	), "real physical loop reaches completion and atomic handback")
	var final_snapshot := production.get_snapshot()
	_check(
		int(final_snapshot.prepared_count) == int(final_snapshot.late_consume_count)
			and int(final_snapshot.handback_count) == 1
			and int(final_snapshot.intent_consume_count) == 3,
		"every prepared envelope has exactly one late consume, including completion",
	)
	var receipt := final_snapshot.completion_handback as Dictionary
	_check(
		receipt.size() == EmberSurfaceLoopProductionBinding.HAND_BACK_RECEIPT_KEYS.size()
			and bool(receipt.boarding_reservation_retained)
			and bool(receipt.command_source_restored)
			and not bool(receipt.host_attached)
			and ship.get_command_source() == original_source
			and area.get_reservation_token() == player,
		"real exact Host receipt restores command while retaining the seated Player token",
	)
	var planetary_return := production.consume_planetary_orbit_return(receipt)
	_check(
		planetary_return.accepted
			and planetary_return.reason == &"planetary_orbit_return_consumed"
			and production.get_planetary_surface_snapshot().state == &"detached",
		"planetary composition consumes the caller-owned orbit return handback once",
	)
	early.take_handback_after_completion = true
	await _one_physics(false)
	var taken := early.last_handback
	_check(taken.accepted, "caller takes detached completion handback once")
	(taken.runtime_ownership_return as Dictionary)["ship_instance_id"] = -1
	_check(
		int(production.get_snapshot().completion_handback.ship_instance_id) == ship.get_instance_id()
			and production.take_completion_handback(production.get_generation()).reason == &"handback_already_delivered",
		"handback mutation and replay cannot change or repeat the real receipt",
	)
	var common := audit.common_authority as Dictionary
	var adjacent := audit.adjacent_authority as Dictionary
	_check(
		common.size() == 12 and adjacent.size() == 13
			and common.values().all(func(value: Variant) -> bool: return value == false)
			and adjacent.values().all(func(value: Variant) -> bool: return value == false),
		"audit freezes exact zero common and adjacent authority",
	)
	await _cleanup(world)


func _test_stale_frame_and_partial_handback_reds() -> void:
	var fixture := await _partial_fixture()
	if fixture.is_empty():
		return
	var production := fixture.production as EmberSurfaceLoopProductionBinding
	var early := fixture.early as EarlyCaller
	# Calling outside the -100 callback freezes the completed prior physics frame;
	# the next automatic priority-2 callback must fail it rather than replay it.
	var current := _current_origin_result(fixture, fixture.ship as ArrowReconShip)
	var prepared := production.prepare_early_tick(
		1, CALLER_DELTA, current.actor_sample, current,
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(), 1,
		production.get_generation(),
	)
	_check(prepared.accepted, "stale-frame red stages outside the early callback")
	production.set_physics_process(false)
	await physics_frame
	production.set_physics_process(true)
	await _one_physics()
	_check(
		production.get_state() == EmberSurfaceLoopProductionBinding.State.FAILED
			and production.get_snapshot().last_late_result.reason == &"stale_physics_frame",
		"late callback rejects an envelope from an earlier engine physics frame",
	)
	await _cleanup(fixture.world as Node)

	fixture = await _partial_fixture()
	if fixture.is_empty():
		return
	production = fixture.production
	early = fixture.early
	early.reenter_binding_after_prepare = true
	early.enabled = true
	await early.reentry_finished
	var reentry_snapshot := production.get_snapshot()
	_check(
		early.last_prepare.accepted
			and production.get_state() == EmberSurfaceLoopProductionBinding.State.IDLE
			and (reentry_snapshot.pending_envelope as Dictionary).is_empty()
			and int(reentry_snapshot.late_consume_count) == 0
			and int(reentry_snapshot.last_consumed_caller_serial) == 0
			and (fixture.host as PartialReceiptHost).get_phase() == EmberSurfaceLoopHost.Phase.IDLE,
		"tree re-entry discards a real early S envelope before late priority 2",
	)
	await _cleanup(fixture.world as Node)

	fixture = await _partial_fixture()
	if fixture.is_empty():
		return
	production = fixture.production
	early = fixture.early
	early.enabled = true
	await _one_physics()
	await _one_physics()
	_check(
		production.get_state() == EmberSurfaceLoopProductionBinding.State.FAILED
			and production.get_snapshot().last_late_result.reason == &"runtime_ownership_return_schema_mismatch"
			and (production.get_snapshot().completion_handback as Dictionary).is_empty(),
		"partial Host handback cannot be published as committed evidence",
	)
	await _one_physics(false)
	production.set("_last_caller_serial", EmberSurfaceLoopProductionBinding.MAX_SAFE_INTEGER)
	var max_result := production.prepare_early_tick(
		EmberSurfaceLoopProductionBinding.MAX_SAFE_INTEGER,
		CALLER_DELTA, early.last_sample, early.last_origin,
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(), 1,
		production.get_generation(),
	)
	_check(
		max_result.reason in [&"terminal_state", &"caller_serial_exhausted"]
			and (production.get_snapshot().pending_envelope as Dictionary).is_empty(),
		"terminal/MAX caller state cannot wrap or stage another envelope",
	)
	await _cleanup(fixture.world as Node)

	fixture = await _partial_fixture()
	if fixture.is_empty():
		return
	var forged_host := fixture.host as PartialReceiptHost
	forged_host.forged_live_receipt = true
	forged_host.forged_boarding_area_instance_id = (fixture.world as Node).get_instance_id()
	forged_host.fake_ship_instance_id = (fixture.ship as ArrowReconShip).get_instance_id()
	forged_host.fake_player_instance_id = (fixture.player as PlayerController).get_instance_id()
	forged_host.fake_restored_command_source_instance_id = (
		fixture.original_source as ShipCommandSource
	).get_instance_id()
	production = fixture.production
	early = fixture.early
	early.enabled = true
	await _one_physics()
	await _one_physics()
	_check(
		production.get_state() == EmberSurfaceLoopProductionBinding.State.FAILED
			and production.get_snapshot().last_late_result.reason
				== &"runtime_ownership_return_live_reservation_mismatch",
		"full-shaped forged handback cannot substitute a non-boarding live reservation",
	)
	await _cleanup(fixture.world as Node)


func _real_fixture() -> Dictionary:
	var world := Node3D.new()
	world.name = "SharedCompositionRoot"
	root.add_child(world)
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	bootstrap.name = "EmberMoonStreamingBootstrap"
	world.add_child(bootstrap)
	var origin_binding := EmberMoonStreamingProductionBinding.new()
	origin_binding.name = "EmberMoonStreamingProductionBinding"
	world.add_child(origin_binding)
	var origin_owner := CommonWorldOriginRebaseOwner.new()
	origin_owner.name = "CommonWorldOriginRebaseOwner"
	world.add_child(origin_owner)
	var probe := Node3D.new()
	probe.name = "OriginActorProbe"
	world.add_child(probe)
	await process_frame
	await process_frame
	probe.global_position = bootstrap.global_position
	if not bool(_consume_origin(origin_binding, origin_owner, probe).get("accepted", false)):
		_check(false, "fixture commits initial Ember origin")
		await _cleanup(world)
		return {}
	await process_frame
	await process_frame
	var scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if scene == null:
		_check(false, "fixture loads authored Ember root")
		await _cleanup(world)
		return {}
	probe.global_position = (scene.get_node(^"LandingRegion") as Node3D).global_position
	if not bool(_consume_origin(origin_binding, origin_owner, probe).get("accepted", false)):
		_check(false, "fixture commits surface-local origin")
		await _cleanup(world)
		return {}
	probe.queue_free()
	var host := EmberSurfaceLoopHost.new()
	host.name = "EmberSurfaceLoopHost"
	world.add_child(host)
	var berth := EmberSurfaceBerth.new()
	berth.name = "EmberSurfaceBerth"
	world.add_child(berth)
	berth.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	ship.name = "ArrowReconShip"
	world.add_child(ship)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	world.add_child(player)
	await process_frame
	await physics_frame
	var original_source := ship.get_command_source()
	ship.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform \
		* Transform3D(Basis.IDENTITY, EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M)
	ship.velocity = Vector3.ZERO
	var area := ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	await physics_frame
	if not area.try_reserve(player) or not player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship
	):
		_check(false, "fixture establishes exact seated Player reservation")
		await _cleanup(world)
		return {}
	ship.set_piloted(true)
	var bound := host.bind_dependencies(
		bootstrap, berth, ship, player, 1.62, 1, 0, 0, world, origin_owner
	)
	if not bool(bound.get("accepted", false)):
		_check(false, "real Host dependency bind succeeds")
		await _cleanup(world)
		return {}
	return {
		"world": world, "host": host, "bootstrap": bootstrap,
		"origin_binding": origin_binding, "origin_owner": origin_owner,
		"frame": bootstrap.get_coordinate_frame_for_session(), "scene": scene,
		"berth": berth, "ship": ship, "player": player, "area": area,
		"original_source": original_source,
	}


func _partial_fixture() -> Dictionary:
	var world := Node3D.new()
	world.name = "PartialReceiptRoot"
	root.add_child(world)
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	bootstrap.name = "EmberMoonStreamingBootstrap"
	world.add_child(bootstrap)
	var streaming := EmberMoonStreamingProductionBinding.new()
	streaming.name = "EmberMoonStreamingProductionBinding"
	world.add_child(streaming)
	var owner := CommonWorldOriginRebaseOwner.new()
	owner.name = "CommonWorldOriginRebaseOwner"
	world.add_child(owner)
	var host := PartialReceiptHost.new()
	host.name = "PartialReceiptHost"
	world.add_child(host)
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	ship.name = "ArrowReconShip"
	world.add_child(ship)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	world.add_child(player)
	var production := EmberSurfaceLoopProductionBinding.new()
	production.name = "EmberSurfaceLoopProductionBinding"
	world.add_child(production)
	_active_production = production
	var early := EarlyCaller.new()
	early.name = "GameFlowEarlyCaller"
	world.add_child(early)
	await process_frame
	await process_frame
	var frame := bootstrap.get_coordinate_frame_for_session()
	var original_source := ship.get_command_source()
	var area := ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	if not area.try_reserve(player) or not player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship
	):
		_check(false, "partial receipt fixture establishes seated Player reservation")
		await _cleanup(world)
		return {}
	ship.set_piloted(true)
	host.fake_coordinate_generation = frame.get_generation()
	host.fake_identities = {
		"composition_root_instance_id": world.get_instance_id(),
		"loaded_scene_instance_id": 99,
		"bootstrap_instance_id": bootstrap.get_instance_id(),
		"origin_owner_instance_id": owner.get_instance_id(),
		"origin_binding_instance_id": streaming.get_instance_id(),
		"ship_instance_id": ship.get_instance_id(),
		"player_instance_id": player.get_instance_id(),
	}
	if not bool(production.configure(host, 0).get("accepted", false)):
		_check(false, "partial receipt fixture configures typed Host subclass")
		await _cleanup(world)
		return {}
	early.production = production
	early.streaming = streaming
	early.origin_owner = owner
	early.frame = frame
	early.host = host
	early.ship = ship
	early.player = player
	return {
		"world": world, "host": host, "ship": ship, "player": player,
		"origin_binding": streaming, "origin_owner": owner, "frame": frame,
		"production": production, "early": early, "area": area,
		"original_source": original_source,
	}


func _wait_phase(fixture: Dictionary, phase: int, budget: int) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	for _index in budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await _one_physics()
	return host.get_phase() == phase


func _wait_binding_state(fixture: Dictionary, state: int, budget: int) -> bool:
	var production := (fixture.world as Node).get_node(
		^"EmberSurfaceLoopProductionBinding"
	) as EmberSurfaceLoopProductionBinding
	for _index in budget:
		if production.get_state() == state:
			return true
		if production.get_state() == EmberSurfaceLoopProductionBinding.State.FAILED:
			return false
		await _one_physics(false)
	return production.get_state() == state


func _walk_outbound(fixture: Dictionary) -> bool:
	if not await _walk_until(fixture, &"move_back", func(p: Vector3) -> bool: return p.x <= -9.0, 60): return false
	if not await _walk_until(fixture, &"move_right", func(p: Vector3) -> bool: return p.z >= 8.0, 90): return false
	if not await _walk_until(fixture, &"move_forward", func(p: Vector3) -> bool: return p.x >= 17.5, 120): return false
	if not await _walk_until(fixture, &"move_left", func(p: Vector3) -> bool: return p.z <= 0.5, 90): return false
	if not await _walk_until(fixture, &"move_forward", func(p: Vector3) -> bool: return p.x >= 41.5, 120): return false
	return (fixture.host as EmberSurfaceLoopHost).get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT


func _walk_return(fixture: Dictionary) -> bool:
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	if not await _walk_until(fixture, &"move_back", func(p: Vector3) -> bool: return p.x <= 18.5, 120): return false
	if not await _walk_until(fixture, &"move_right", func(p: Vector3) -> bool: return p.z >= 8.0, 90): return false
	if not await _walk_until(fixture, &"move_back", func(p: Vector3) -> bool: return p.x <= -9.0, 120): return false
	if not await _walk_until(fixture, &"move_left", func(p: Vector3) -> bool: return p.z <= 0.5, 90): return false
	if not await _walk_until(fixture, &"move_forward", func(_p: Vector3) -> bool: return area in player.get_nearby_interactables(), 60): return false
	return area in player.get_nearby_interactables()


func _walk_until(fixture: Dictionary, action: StringName, reached: Callable, budget: int) -> bool:
	var landing := (fixture.scene as Node).get_node(^"LandingRegion") as Node3D
	var player := fixture.player as PlayerController
	Input.action_press(action)
	for _index in budget:
		await _one_physics()
		if bool(reached.call(landing.to_local(player.global_position))):
			Input.action_release(action)
			return true
	Input.action_release(action)
	return false


func _current_origin_result(fixture: Dictionary, actor: Node3D) -> Dictionary:
	return _consume_origin(
		fixture.origin_binding as EmberMoonStreamingProductionBinding,
		fixture.origin_owner as CommonWorldOriginRebaseOwner,
		actor,
	)


func _consume_origin(
	binding: EmberMoonStreamingProductionBinding,
	owner: CommonWorldOriginRebaseOwner,
	actor: Node3D
) -> Dictionary:
	var sample := {
		"available": true,
		"position": actor.global_position,
		"actor_kind": &"ship" if actor is ArrowReconShip else &"player",
		"actor_instance_id": actor.get_instance_id(),
	}.duplicate(true)
	var tick := binding.physics_tick_from_caller_sample(CALLER_DELTA, sample)
	var preview := binding.preview_origin_rebase(
		int(tick.get("coordinate_frame_generation", 0))
	)
	if not bool(preview.get("accepted", false)):
		return preview
	return owner.consume_rebase_preview(preview, sample)


func _one_physics(expect_late_completion: bool = true) -> void:
	if expect_late_completion and is_instance_valid(_active_production):
		await _active_production.state_changed
		return
	await physics_frame
	await process_frame


func _cleanup(world: Node) -> void:
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back", &"sprint_boost"]:
		Input.action_release(action)
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _planetary_reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_SURFACE_LOOP_PRODUCTION_BINDING_TEST_OK assertions=%d diagnostics=0" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_SURFACE_LOOP_PRODUCTION_BINDING_TEST: " + failure)
	quit(1)
