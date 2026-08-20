extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Layers := preload("res://scripts/core/physics_layers.gd")
const STORE_PATH := "memory://planetary-cruise-production-settings.json"
const EXPECTED_ASSERTIONS := 40

var _assertions := 0
var _failures: Array[String] = []
var _reentry_receipt: Dictionary = {}


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with cruise composition")
	if game == null:
		_finish(); return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://planetary-cruise-production-legacy.cfg"
		),
		"production cruise journey isolates settings persistence",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var binding := game.get_node_or_null(
		^"PlanetaryCruiseProductionBinding"
	) as PlanetaryCruiseProductionBinding
	var ember := game.get_node_or_null(
		^"EmberMoonStreamingBootstrap"
	) as EmberMoonStreamingBootstrap
	var owner := game.get_node_or_null(
		^"CommonWorldOriginRebaseOwner"
	) as CommonWorldOriginRebaseOwner
	var ship := game.get_active_ship()
	_check(
		binding != null and ember != null and owner != null and ship != null,
		"Main resolves the binding, Ember frame, origin owner, and active HeroShip",
	)
	if binding == null or ember == null or owner == null or ship == null:
		await _cleanup(game); _finish(); return
	var controller := binding.get_controller()
	var identities := [binding.get_instance_id(), controller.get_instance_id()]
	var audit := binding.audit()
	_check(
		bool(audit.get("valid", false))
			and int(audit.get("binding_count", 0)) == 1
			and int(audit.get("controller_count", 0)) == 1
			and controller.get_parent() == binding,
		"Main owns exactly one binding with one binding-owned physical controller",
	)
	_check(
		not binding.is_processing()
			and not binding.is_physics_processing()
			and not controller.is_processing()
			and not controller.is_physics_processing()
			and game.process_physics_priority < ship.process_physics_priority,
		"caller-only composition explicitly runs GameFlow before HeroShip physics",
	)
	var snapshot := binding.get_snapshot()
	var canonical := snapshot.get("canonical_destination_orbital", {}) as Dictionary
	_check(
		snapshot.get("destination_id") == &"ember_navigation"
			and int(canonical.get("cell_z", 0)) == -8
			and canonical.get("offset_meters") == Vector3(0.0, 130_000.0, 0.0),
		"binding freezes Ember's canonical navigation anchor as one absolute coordinate",
	)
	_check(_has_exact_zero_common_authority(audit), "binding has exact zero common authority")
	var capabilities := audit.get("adjacent_capabilities", {}) as Dictionary
	_check(
		bool(capabilities.get("controller_cadence", false))
			and not bool(capabilities.get("actor_sampling", true))
			and not bool(capabilities.get("collision_query", true))
			and not bool(capabilities.get("velocity_write", true))
			and not bool(capabilities.get("move_and_slide", true))
			and not bool(capabilities.get("origin_rebase_commit", true)),
		"binding owns cadence only and duplicates no sampler, proof, mover, or origin authority",
	)
	_check(
		game.engage_planetary_cruise().get("reason") == &"pilot_unseated",
		"public engage fails closed before the exact production pilot gate",
	)

	game.set_physics_process(false)
	for fleet_ship in game.get_flyable_ships():
		fleet_ship.set_physics_process(false)
	ship.global_position = Vector3(0.0, 5_000.0, 0.0)
	var frame := ember.get_coordinate_frame_for_session()
	var destination_result := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	)
	var destination := destination_result.get("position", Vector3.INF) as Vector3
	var initial_direction := (destination - ship.global_position).normalized()
	ship.global_basis = Basis.looking_at(initial_direction, Vector3.UP)
	ship.velocity = Vector3.ZERO
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT

	binding.engagement_changed.connect(func(_value: Dictionary) -> void:
		_reentry_receipt = game.disengage_planetary_cruise()
	, CONNECT_ONE_SHOT)
	var controller_bind_reentry := [{}]
	controller.binding_changed.connect(func(_value: Dictionary) -> void:
		controller_bind_reentry[0] = game.disengage_planetary_cruise()
	, CONNECT_ONE_SHOT)
	var engage := game.engage_planetary_cruise()
	_check(
		bool(engage.get("accepted", false))
			and bool(binding.get_snapshot().get("engagement_requested", false)),
		"public engage binds the exact active HeroShip for the next physics tick",
	)
	_check(
		not bool(_reentry_receipt.get("accepted", true))
			and _reentry_receipt.get("reason") == &"reentrant_call",
		"committed engagement signal rejects synchronous public API reentry",
	)
	_check(
		not bool((controller_bind_reentry[0] as Dictionary).get("accepted", true))
			and (controller_bind_reentry[0] as Dictionary).get("reason")
				== &"reentrant_call"
			and bool(binding.get_snapshot().get("engagement_requested", false)),
		"nested controller bind signal cannot disengage the outer atomic engage",
	)
	_reentry_receipt.clear()
	var controller_evaluation_reentry := [{}]
	controller.evaluation_committed.connect(func(_value: Dictionary) -> void:
		controller_evaluation_reentry[0] = game.disengage_planetary_cruise()
	, CONNECT_ONE_SHOT)
	var before_position := ship.global_position
	var before_actor_reads := int(
		game.get_activity_integration_report().get("actor_position_sample_count", -1)
	)
	game._physics_process(1.0 / 60.0)
	var queued := binding.get_snapshot()
	var ship_pending := ship.get_planetary_cruise_attachment_report()
	_check(
		int(game.get_activity_integration_report().get("actor_position_sample_count", -1))
			== before_actor_reads + 1
			and int(queued.get("accepted_tick_count", 0)) == 1,
		"one GameFlow actor read drives one accepted production cruise cadence",
	)
	_check(
		ship.global_position.is_equal_approx(before_position)
			and not (ship_pending.get("pending_envelope", {}) as Dictionary).is_empty()
			and int((ship_pending.get("pending_envelope", {}) as Dictionary)
				.get("coordinate_frame_generation", 0)) == frame.get_generation(),
		"GameFlow queues one current-generation envelope without moving HeroShip",
	)
	_check(
		not bool((controller_evaluation_reentry[0] as Dictionary).get("accepted", true))
			and (controller_evaluation_reentry[0] as Dictionary).get("reason")
				== &"reentrant_call"
			and not (ship_pending.get("pending_envelope", {}) as Dictionary).is_empty(),
		"nested controller evaluation signal cannot clear or counterfeit the outer envelope",
	)
	var last_caller_tick := int(queued.get("last_caller_tick", 0))
	var sequence_before_replay := int(
		(queued.get("controller", {}) as Dictionary).get("sequence", 0)
	)
	var replay := binding.physics_tick_from_caller_sample(
		last_caller_tick,
		{
			"available": true,
			"position": ship.global_position,
			"actor_kind": &"ship",
			"actor_instance_id": ship.get_instance_id(),
		},
		ship,
		frame.get_generation(),
		false,
		&"",
	)
	_check(
		replay.get("reason") == &"caller_tick_replay"
			and int(binding.get_controller().get_snapshot().get("sequence", -1))
				== sequence_before_replay,
		"duplicate caller tick cannot mint a second controller envelope",
	)
	var tick_destination := queued.get("last_destination_world", Vector3.INF) as Vector3
	_check(
		tick_destination.is_equal_approx(destination)
			and int(queued.get("bound_coordinate_frame_generation", 0)) == 1,
		"the exact generation-one absolute destination is decoded only after streaming",
	)
	ship._physics_process(1.0 / 60.0)
	_check(
		ship.global_position.distance_to(before_position) > 0.0
			and (ship.get_planetary_cruise_attachment_report()
				.get("pending_envelope", {}) as Dictionary).is_empty(),
		"the next HeroShip physics tick alone consumes and physically applies the envelope",
	)
	var generation_before_rejected_release := binding.get_generation()
	var retirements_before_rejected_release := int(
		binding.get_snapshot().get("retirement_count", -1)
	)
	# Freeze the controller in its own signal-dispatch guard to model an exact
	# synchronous release rejection without triggering Node.reparent()'s real
	# _exit_tree lifecycle, which correctly retires the Hero attachment first.
	controller._signal_dispatch_active = true
	var rejected_release := game.disengage_planetary_cruise(false)
	controller._signal_dispatch_active = false
	_check(
		not bool(rejected_release.get("accepted", true))
			and rejected_release.get("reason") == &"controller_release_rejected"
			and binding.get_generation() == generation_before_rejected_release
			and int(binding.get_snapshot().get("retirement_count", -2))
				== retirements_before_rejected_release
			and bool(binding.get_snapshot().get("engagement_requested", false)),
		"controller release rejection is atomic and cannot erase live ownership",
	)

	var old_controller_generation := controller.get_generation()
	var old_destination_world := tick_destination
	var travel_direction := (old_destination_world - ship.global_position).normalized()
	ship.global_position = travel_direction * 10_000.0
	ship.velocity = travel_direction * 10.0
	var accepted_ticks_before_rebase_failure := int(
		binding.get_snapshot().get("accepted_tick_count", -1)
	)
	owner._commit_adapter = Callable(self, &"_reject_rebase_commit")
	game._physics_process(1.0 / 60.0)
	owner._commit_adapter = Callable()
	var failed_rebase := binding.get_snapshot()
	var failed_rebase_pending := (
		ship.get_planetary_cruise_attachment_report().get("pending_envelope", {})
		as Dictionary
	)
	ship._physics_process(1.0 / 60.0)
	ship.velocity = travel_direction * 10.0
	var resumed_after_failed_rebase := game.engage_planetary_cruise()
	_check(
		frame.get_generation() == 1
			and (frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty()
			and failed_rebase.get("last_reason") == &"origin_rebase_required"
			and not bool(failed_rebase.get("engagement_requested", true))
			and failed_rebase_pending.is_empty()
			and int(failed_rebase.get("accepted_tick_count", -2))
				== accepted_ticks_before_rebase_failure
			and bool(resumed_after_failed_rebase.get("accepted", false)),
		"an uncommitted required common-origin rebase retires cruise before it can queue a source-frame envelope",
	)
	game._physics_process(1.0 / 60.0)
	var rebound := binding.get_snapshot()
	var rebound_pending := (
		ship.get_planetary_cruise_attachment_report().get("pending_envelope", {})
		as Dictionary
	)
	_check(
		frame.get_generation() == 2
			and int(rebound.get("bound_coordinate_frame_generation", 0)) == 2
			and int(rebound.get("rebind_count", 0)) == 1
			and controller.get_generation() > old_controller_generation,
		"committed N-to-N+1 rebase retires and rebinds the same controller identity",
	)
	_check(
		int(rebound_pending.get("coordinate_frame_generation", 0)) == 2
			and rebound.get("canonical_destination_orbital") == canonical
			and (rebound.get("last_destination_world", Vector3.INF) as Vector3)
				.is_equal_approx(old_destination_world - travel_direction * 10_000.0)
			and ship.get_planetary_cruise_attachment_report().get("state")
				!= HeroShip.PLANETARY_CRUISE_STATE_BRAKING,
		"post-rebase tick uses adjusted sample and freshly decoded destination without artificial braking",
	)
	ship._physics_process(1.0 / 60.0)
	game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	game._physics_process(1.0 / 60.0)
	var combat_retired := binding.get_snapshot()
	_check(
		not bool(combat_retired.get("engagement_requested", true))
			and combat_retired.get("last_reason") == &"combat_active"
			and not bool(binding.get_controller().get_snapshot().get("attached", true)),
		"authoritative live-combat observation reaches policy and retires cruise closed",
	)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	ship.velocity = Vector3.ZERO
	ship._physics_process(1.0 / 60.0)

	# Freeze the inverse broadphase adversary too: sync the actor and blocker at
	# their pre-rebase positions, then translate both in the same GameFlow tick.
	# A stale physics server would leave the blocker 10 km away and counterfeit a
	# clear corridor; the origin owner must make the current blocker visible at
	# 250 m before HeroShip derives its generation-three full-hull proof.
	var second_rebase_direction := (
		(binding.get_snapshot().get("last_destination_world", destination) as Vector3)
		- ship.global_position
	).normalized()
	ship.global_position = second_rebase_direction * 10_000.0
	var blocker := _make_blocker(
		"ProductionCruiseBlocker",
		Vector3(100.0, 100.0, 100.0),
		ship.global_position + second_rebase_direction * 250.0,
	)
	game.add_child(blocker)
	await physics_frame
	_check(
		bool(game.engage_planetary_cruise().get("accepted", false)),
		"clear lifecycle can request a fresh cruise before a second rebase",
	)
	game._physics_process(1.0 / 60.0)
	_check(
		frame.get_generation() == 3
			and blocker.global_position.is_equal_approx(
				second_rebase_direction * 250.0
			)
			and binding.get_snapshot().get("last_reason") == &"obstacle_detected"
			and not bool(binding.get_snapshot().get("engagement_requested", true)),
		"same-tick translated blocker cannot become a stale-broadphase false clear",
	)
	blocker.queue_free()
	await physics_frame

	_check(bool(game.engage_planetary_cruise().get("accepted", false)), "production can engage after obstruction retirement")
	game._physics_process(1.0 / 60.0)
	ship.set_piloted(false)
	game._physics_process(1.0 / 60.0)
	_check(
		binding.get_snapshot().get("last_reason") == &"pilot_unseated"
			and not bool(controller.get_snapshot().get("attached", true))
			and not bool(binding.get_snapshot().get("engagement_requested", true)),
		"Hero-owned unpilot generation is reconciled without a stale-controller deadlock",
	)
	ship.set_piloted(true)
	_check(
		bool(game.engage_planetary_cruise().get("accepted", false)),
		"the same controller identity can bind freshly after lifecycle reconciliation",
	)
	var other_ship := game.get_flyable_ships()[1]
	other_ship.set_piloted(true)
	game.active_ship = other_ship
	game._physics_process(1.0 / 60.0)
	_check(
		binding.get_snapshot().get("last_reason") == &"active_ship_replaced"
			and not bool(binding.get_snapshot().get("engagement_requested", true))
			and int(controller.get_snapshot().get("ship_instance_id", -1)) == 0,
		"active hull replacement retires cruise without migrating it to the new ship",
	)
	other_ship.set_piloted(false)
	game.active_ship = ship
	_check(bool(game.engage_planetary_cruise().get("accepted", false)), "safe-integer witness begins from one live engagement")
	game.set("_planetary_cruise_caller_tick", PlanetaryCruiseProductionBinding.MAX_SAFE_INTEGER)
	game._physics_process(1.0 / 60.0)
	_check(
		binding.get_snapshot().get("last_reason") == &"caller_tick_exhausted"
			and not bool(binding.get_snapshot().get("engagement_requested", true))
			and int(game.get_planetary_cruise_report().get("caller_tick", 0))
				== PlanetaryCruiseProductionBinding.MAX_SAFE_INTEGER,
		"caller-tick exhaustion retires closed without wrapping or replaying MAX",
	)
	game.set(
		"_planetary_cruise_caller_tick",
		int(binding.get_snapshot().get("last_caller_tick", 0)),
	)

	var mutable := binding.get_snapshot()
	(mutable.get("canonical_destination_orbital", {}) as Dictionary)["cell_z"] = 99
	(mutable.get("last_result", {}) as Dictionary).clear()
	_check(
		int((binding.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary)
			.get("cell_z", 0)) == -8
			and not (binding.get_snapshot().get("last_result", {}) as Dictionary).is_empty(),
		"production binding snapshots are deeply detached",
	)
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	_check(
		game.get_node(^"PlanetaryCruiseProductionBinding") == binding
			and binding.get_controller() == controller
			and not game.disengage_planetary_cruise().get("accepted", true),
		"whole-Main detach freezes the exact binding/controller identities and rejects mutation",
	)
	parent.add_child(game)
	await process_frame
	await process_frame
	_check(
		[binding.get_instance_id(), controller.get_instance_id()] == identities
			and bool(binding.audit().get("valid", false))
			and game.find_children(
				"*", "PlanetaryCruiseProductionBinding", true, false
			).size() == 1,
		"whole-Main re-entry preserves one binding/controller without duplicate activation",
	)
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var pre_boundary_generation := binding.get_generation()
	binding.set(
		"_generation", PlanetaryCruiseProductionBinding.MAX_SAFE_INTEGER - 1
	)
	var reserved_retirement_boundary := game.engage_planetary_cruise()
	_check(
		not bool(reserved_retirement_boundary.get("accepted", true))
			and reserved_retirement_boundary.get("reason") == &"generation_exhausted"
			and not bool(binding.get_snapshot().get("engagement_requested", true))
			and not bool(controller.get_snapshot().get("attached", true))
			and binding.get_generation()
				== PlanetaryCruiseProductionBinding.MAX_SAFE_INTEGER - 1,
		"MAX-1 engage is rejected before attachment so one retirement serial remains reserved",
	)
	binding.set("_generation", pre_boundary_generation)
	_check(bool(game.engage_planetary_cruise().get("accepted", false)), "controller-loss witness starts with one exact live attachment")
	controller.queue_free()
	await process_frame
	game._physics_process(1.0 / 60.0)
	var loss_snapshot := binding.get_snapshot()
	_check(
		loss_snapshot.get("last_reason") == &"controller_identity_drift"
			and not bool(loss_snapshot.get("engagement_requested", true))
			and not bool((loss_snapshot.get("controller", {}) as Dictionary)
				.get("available", true))
			and not bool(binding.audit().get("valid", true)),
		"freed controller produces detached structured red without invalid-instance access",
	)
	binding.set("_generation", PlanetaryCruiseProductionBinding.MAX_SAFE_INTEGER)
	var exhausted_generation := game.engage_planetary_cruise()
	_check(
		not bool(exhausted_generation.get("accepted", true))
			and exhausted_generation.get("reason") == &"generation_exhausted"
			and binding.get_generation() == PlanetaryCruiseProductionBinding.MAX_SAFE_INTEGER,
		"binding generation exhaustion rejects rather than wrapping to one",
	)
	await _test_post_rebase_streaming_loader_gate()
	await _test_post_rebase_streaming_pending_gate()

	await _cleanup(game)
	_finish()


func _make_blocker(
		blocker_name: String,
		size: Vector3,
		world_position: Vector3,
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = blocker_name
	body.collision_layer = Layers.WORLD
	body.collision_mask = Layers.NONE
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % blocker_name
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	body.position = world_position
	return body


func _reject_rebase_commit(
		_request_id: int,
		_source_generation: int,
	) -> Dictionary:
	return {"accepted": false, "reason": &"forced_rebase_commit_rejection"}


func _reject_ember_scene_loader(
		_definition: Variant,
		_generation: int,
		_completion: Callable,
	) -> bool:
	return false


func _accept_ember_scene_loader_without_completion(
		_definition: Variant,
		_generation: int,
		_completion: Callable,
	) -> bool:
	return true


func _test_post_rebase_streaming_loader_gate() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null:
		_check(false, "post-rebase streaming witness instantiates a second production Main")
		return
	var settings_ready := game.configure_runtime_settings_persistence(
		Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore,
		"memory://planetary-cruise-streaming-gate-legacy.cfg",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var binding := game.get_node_or_null(
		^"PlanetaryCruiseProductionBinding"
	) as PlanetaryCruiseProductionBinding
	var ember := game.get_node_or_null(
		^"EmberMoonStreamingBootstrap"
	) as EmberMoonStreamingBootstrap
	var ship := game.get_active_ship()
	if binding == null or ember == null or ship == null:
		_check(false, "post-rebase streaming witness resolves production cruise, Ember, and ship")
		await _cleanup(game)
		return
	var rejecting_loader_installed := ember.set_scene_loader(
		Callable(self, &"_reject_ember_scene_loader")
	)
	game.set_physics_process(false)
	for fleet_ship in game.get_flyable_ships():
		fleet_ship.set_physics_process(false)
	ship.global_position = EmberMoonStreamingBootstrap.INITIAL_BODY_CENTER_WORLD_POSITION
	ship.velocity = Vector3.ZERO
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var frame := ember.get_coordinate_frame_for_session()
	var generation_before := frame.get_generation() if frame != null else 0
	var engaged := bool(game.engage_planetary_cruise().get("accepted", false))
	var accepted_ticks_before := int(binding.get_snapshot().get("accepted_tick_count", -1))
	game._physics_process(1.0 / 60.0)
	var streaming := ember.get_snapshot().get("last_update_result", {}) as Dictionary
	var gate := binding.get_snapshot()
	var pending := (
		ship.get_planetary_cruise_attachment_report().get("pending_envelope", {})
		as Dictionary
	)
	_check(
		settings_ready
			and rejecting_loader_installed
			and frame != null
			and engaged
			and frame.get_generation() == generation_before + 1
			and not bool(streaming.get("accepted", true))
			and streaming.get("reason") == &"loader_rejected"
			and gate.get("last_reason") == &"ember_streaming_unavailable"
			and not bool(gate.get("engagement_requested", true))
			and int(gate.get("accepted_tick_count", -2)) == accepted_ticks_before
			and pending.is_empty()
			and ship.global_position.is_zero_approx(),
		"a committed origin shift whose required Ember load rejects retires cruise before it queues an envelope",
	)
	await _cleanup(game)


func _test_post_rebase_streaming_pending_gate() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null:
		_check(false, "pending Ember-streaming witness instantiates a second production Main")
		return
	var settings_ready := game.configure_runtime_settings_persistence(
		Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore,
		"memory://planetary-cruise-streaming-pending-legacy.cfg",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var binding := game.get_node_or_null(
		^"PlanetaryCruiseProductionBinding"
	) as PlanetaryCruiseProductionBinding
	var ember := game.get_node_or_null(
		^"EmberMoonStreamingBootstrap"
	) as EmberMoonStreamingBootstrap
	var ship := game.get_active_ship()
	if binding == null or ember == null or ship == null:
		_check(false, "pending Ember-streaming witness resolves production cruise, Ember, and ship")
		await _cleanup(game)
		return
	var pending_loader_installed := ember.set_scene_loader(
		Callable(self, &"_accept_ember_scene_loader_without_completion")
	)
	game.set_physics_process(false)
	for fleet_ship in game.get_flyable_ships():
		fleet_ship.set_physics_process(false)
	ship.global_position = EmberMoonStreamingBootstrap.INITIAL_BODY_CENTER_WORLD_POSITION
	ship.velocity = Vector3.ZERO
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var frame := ember.get_coordinate_frame_for_session()
	var generation_before := frame.get_generation() if frame != null else 0
	var engaged := bool(game.engage_planetary_cruise().get("accepted", false))
	var accepted_ticks_before := int(binding.get_snapshot().get("accepted_tick_count", -1))
	game._physics_process(1.0 / 60.0)
	var streaming := ember.get_snapshot().get("last_update_result", {}) as Dictionary
	var gate := binding.get_snapshot()
	var pending := (
		ship.get_planetary_cruise_attachment_report().get("pending_envelope", {})
		as Dictionary
	)
	_check(
		settings_ready
			and pending_loader_installed
			and frame != null
			and engaged
			and frame.get_generation() == generation_before + 1
			and bool(streaming.get("accepted", false))
			and streaming.get("reason") == &"load_requested"
			and streaming.get("action") == &"load"
			and ember.get_loaded_instance() == null
			and gate.get("last_reason") == &"ember_streaming_pending"
			and not bool(gate.get("engagement_requested", true))
			and int(gate.get("accepted_tick_count", -2)) == accepted_ticks_before
			and pending.is_empty()
			and ship.global_position.is_zero_approx(),
		"a pending accepted Ember load retires cruise before it queues an envelope",
	)
	await _cleanup(game)


func _has_exact_zero_common_authority(audit: Dictionary) -> bool:
	const KEYS := [
		"renderer", "gameplay", "streaming", "save", "network", "physics",
		"world_generation", "terrain_generation", "collision_generation",
		"origin_shift", "weather_clock", "audio",
	]
	var authority := audit.get("common_authority", {}) as Dictionary
	if authority.size() != KEYS.size(): return false
	for key in KEYS:
		if not authority.has(key) or not authority[key] is bool or bool(authority[key]):
			return false
	return true


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game): game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions])
	if _failures.is_empty():
		print("PLANETARY_CRUISE_PRODUCTION_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0); return
	for failure in _failures:
		push_error("PLANETARY_CRUISE_PRODUCTION_INTEGRATION_TEST: %s" % failure)
	quit(1)
