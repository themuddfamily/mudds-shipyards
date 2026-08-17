extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PHYSICS_DELTA := 1.0 / 12.0
const TEST_TIME_SCALE := 5.0

var _failures := PackedStringArray()
var _original_time_scale := 1.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_original_time_scale = Engine.time_scale
	Engine.time_scale = TEST_TIME_SCALE
	await _test_normal_public_actor_loop()
	await _test_exact_generation_and_loaded_root_freshness()
	await _test_tangent_frame_and_continuous_support_fail_closed()
	await _test_synchronous_destruction_first_wins()
	for phase in [
		EmberSurfaceLoopHost.Phase.DISEMBARKING,
		EmberSurfaceLoopHost.Phase.BOARDING,
	]:
		await _test_transition_terminal_atomicity(phase, &"detach")
		await _test_transition_terminal_atomicity(phase, &"lease_loss")
		await _test_transition_terminal_atomicity(phase, &"queued_surface")
	Engine.time_scale = _original_time_scale
	_finish()


func _test_normal_public_actor_loop() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var berth := fixture.berth as EmberSurfaceBerth
	var area := fixture.area as ShipBoardingArea
	var original_source := fixture.original_source as ShipCommandSource
	var reached_landed := await _drive_to_phase(
		fixture, EmberSurfaceLoopHost.Phase.LANDED, 660
	)
	_check(
		reached_landed,
		"real Arrow command/physics and strict berth lease reach LANDED",
	)
	if not reached_landed:
		await _cleanup(fixture)
		return
	var landed_report := ship.get_landing_contract_report()
	_check(
		bool(ship.get_telemetry().get("landed", false))
			and bool(landed_report.get("strict_dock_acceptance", false))
			and berth.get_occupant() == ship
			and not berth.get_reservation_token(ship).is_empty(),
		"TravelSession landing follows exact public telemetry, hull acceptance, occupant and token",
	)
	_check(
		host.request_disembark(host.get_generation(), host.get_attachment_generation()).accepted,
		"ordered disembark intent is accepted once",
	)
	var reached_surface := await _drive_to_phase(
		fixture, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 300
	)
	_check(
		reached_surface,
		"public Player disembark completes with embodied collision",
	)
	if not reached_surface:
		await _cleanup(fixture)
		return
	_check(
		not player.is_seated() and player.collision_layer != 0
			and area.get_reservation_token() == null,
		"disembark releases the exact initial boarding reservation",
	)
	var reached_staging := await _walk_outbound_route(fixture)
	_check(
		reached_staging,
		"real Player locomotion crosses ordered egress then staging on live support",
	)
	if not reached_staging:
		await _cleanup(fixture)
		return
	var return_ready := await _walk_return_to_boarding(fixture)
	_check(return_ready, "return route reaches egress then the exact live BoardingArea")

	var thief := Node.new()
	thief.name = "CompetingBoardingReservation"
	(fixture.world as Node).add_child(thief)
	_check(area.try_reserve(thief), "competing token can claim the unreserved seat")
	var before_conflict := host.get_snapshot()
	var conflict := host.request_reboard(
		host.get_generation(), host.get_attachment_generation()
	)
	_check(
		conflict.reason == &"boarding_reservation_unavailable"
			and host.get_snapshot() == before_conflict
			and area.get_reservation_token() == thief,
		"reboard conflict is state-preserving and cannot steal another exact token",
	)
	_check(area.release_reservation(thief), "competing token releases exactly")
	thief.queue_free()
	_check(
		host.request_reboard(host.get_generation(), host.get_attachment_generation()).accepted,
		"current Player acquires the real BoardingArea and begins public boarding",
	)
	_check(
		await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.REBOARDED, 20)
			and player.is_seated() and ship.is_piloted()
			and area.get_reservation_token() == player,
		"public reboard completes seated/piloted with the exact Player reservation",
	)
	_check(
		host.request_takeoff(host.get_generation(), host.get_attachment_generation()).accepted,
		"ordered takeoff intent is accepted once",
	)
	var takeoff_lease_seen := false
	var completed := false
	for _index in 2700:
		var was_landed := bool(ship.get_telemetry().get("landed", true))
		var token_before := berth.get_reservation_token(ship)
		var tick := await _tick(fixture)
		if was_landed and not token_before.is_empty():
			takeoff_lease_seen = true
		if not bool(tick.get("accepted", false)):
			break
		if host.get_phase() == EmberSurfaceLoopHost.Phase.COMPLETED:
			completed = true
			break
	_check(
		completed and takeoff_lease_seen
			and not bool(ship.get_telemetry().get("landed", true))
			and berth.get_reservation_token(ship).is_empty(),
		"real takeoff keeps the berth through landed=true then releases it before orbit completion",
	)
	var audit := host.audit()
	var route_snapshot := host.get_snapshot().surface_route as Dictionary
	_check(
		bool(audit.get("valid", false))
			and route_snapshot.coordinate_space == &"gravity_policy_reference_tangent"
			and route_snapshot.reference_tangent_basis_body_local == Basis.IDENTITY
			and int(route_snapshot.walkable_body_instance_id)
				== (fixture.walkable as StaticBody3D).get_instance_id(),
		"completed audit freezes tangent identity and exact loaded support body",
	)
	_check(
		host.detach(host.get_generation(), host.get_attachment_generation()).accepted
			and ship.get_command_source() == original_source,
		"clean completion detach restores the prior command source",
	)
	await _cleanup(fixture)


func _test_exact_generation_and_loaded_root_freshness() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var before := host.get_snapshot()
	for mutation in [
		{"generation": host.get_generation() + 1, "attachment": host.get_attachment_generation(), "frame": frame.get_generation(), "location": 1},
		{"generation": host.get_generation(), "attachment": host.get_attachment_generation() + 1, "frame": frame.get_generation(), "location": 1},
		{"generation": host.get_generation(), "attachment": host.get_attachment_generation(), "frame": frame.get_generation() + 1, "location": 1},
		{"generation": host.get_generation(), "attachment": host.get_attachment_generation(), "frame": frame.get_generation(), "location": 2},
	]:
		var rejected := host.advance_physics(
			PHYSICS_DELTA, mutation.generation, mutation.attachment,
			mutation.frame, mutation.location
		)
		_check(
			not bool(rejected.get("accepted", true)) and host.get_snapshot() == before,
			"stale host/attachment/frame/location caller token is state-preserving",
		)
	var request := frame.request_rebase(Vector3(12_000.0, 0.0, 0.0), frame.get_generation())
	_check(bool(request.get("accepted", false)), "coordinate frame accepts an external rebase request")
	var committed := frame.commit_rebase(request.request.request_id, frame.get_generation())
	_check(bool(committed.get("accepted", false)), "external rebase advances the frame generation")
	var stale_frame := host.advance_physics(
		PHYSICS_DELTA, host.get_generation(), host.get_attachment_generation(),
		before.coordinate_frame_generation, 1
	)
	_check(
		stale_frame.reason == &"stale_coordinate_frame_generation"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED,
		"current frame generation drift terminates instead of replaying the old frame",
	)
	await _cleanup(fixture)

	fixture = await _fixture()
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	var bootstrap := fixture.bootstrap as EmberMoonStreamingBootstrap
	frame = fixture.frame as PlanetaryCoordinateFrame
	var far := _absolute(frame, Vector3(0.0, 300_001.0, 0.0))
	_check(bootstrap.update_absolute_focus(far, frame.get_generation()).accepted, "loaded root unload advances to N+1")
	await process_frame
	_check(
		host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and host.get_snapshot().terminal_reason == &"loaded_scene_detached",
		"N+1 unload immediately fails the current session with its first terminal reason",
	)
	var near := _absolute(frame, Vector3(0.0, 250_000.0, 0.0))
	_check(bootstrap.update_absolute_focus(near, frame.get_generation()).accepted, "loaded root reload advances to N+2")
	await process_frame
	await process_frame
	var replay := host.advance_physics(
		PHYSICS_DELTA, host.get_generation(), host.get_attachment_generation(),
		frame.get_generation(), 1
	)
	_check(
		replay.reason == &"not_running"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and host.get_snapshot().terminal_reason == &"loaded_scene_detached",
		"N to N+2 loaded-root replacement cannot replay the original session",
	)
	await _cleanup(fixture)


func _test_tangent_frame_and_continuous_support_fail_closed() -> void:
	var fixture := await _fixture_at_surface_outbound()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var landing_root := fixture.landing_root as Node3D
	landing_root.rotation.y = 0.01
	var transformed := await _tick(fixture)
	_check(
		transformed.reason == &"landing_surface_frame_drift"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED,
		"live landing-frame mutation invalidates tangent route and gravity composition",
	)
	await _cleanup(fixture)

	fixture = await _fixture_at_surface_outbound()
	if fixture.is_empty():
		return
	host = fixture.host as EmberSurfaceLoopHost
	var walkable := fixture.walkable as StaticBody3D
	walkable.collision_layer = PhysicsLayers.NONE
	await physics_frame
	var unsupported := host.advance_physics(
		PHYSICS_DELTA, host.get_generation(), host.get_attachment_generation(),
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(), 1
	)
	_check(
		unsupported.reason == &"surface_support_lost"
			and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED,
		"missing exact live WalkablePatch support fails between route endpoints",
	)
	await _cleanup(fixture)


func _test_synchronous_destruction_first_wins() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var berth := fixture.berth as EmberSurfaceBerth
	var callback := func(owner: Node, token: StringName) -> void:
		if owner == ship and not token.is_empty():
			ship.apply_damage(ship.maximum_hull + 1.0, ship.global_position, Vector3.UP)
	berth.reservation_changed.connect(callback)
	var final_result := {}
	for _index in 660:
		final_result = await _tick(fixture)
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
	_check(
		host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED
			and final_result.get("reason") == &"ship_destroyed"
			and host.get_snapshot().terminal_reason == &"ship_destroyed"
			and berth.get_reservation_owner() == null,
		"synchronous destruction in reservation signal commits first-wins failure before outer success",
	)
	await _cleanup(fixture)


func _test_transition_terminal_atomicity(phase: int, trigger: StringName) -> void:
	var fixture := await _fixture_at_transition(phase)
	if fixture.is_empty():
		return
	var host := fixture.host as EmberSurfaceLoopHost
	var ship := fixture.ship as ArrowReconShip
	var player := fixture.player as PlayerController
	var berth := fixture.berth as EmberSurfaceBerth
	var area := fixture.area as ShipBoardingArea
	var old_attachment := host.get_attachment_generation()
	var result := {}
	match trigger:
		&"detach":
			result = host.detach(host.get_generation(), old_attachment)
		&"lease_loss":
			var token := berth.get_reservation_token(ship)
			_check(not token.is_empty() and berth.release(ship, token), "exact live berth lease can be retired adversarially")
			result = await _tick(fixture)
		&"queued_surface":
			(fixture.scene as Node).queue_free()
			await process_frame
			result = host.get_snapshot()
		_:
			_check(false, "unknown transition terminal trigger")
	var detached := trigger == &"detach"
	_check(
		(detached and bool(result.get("accepted", false))
				and host.get_attachment_generation() == old_attachment + 1)
			or (not detached and host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED),
		"%s during transition phase %d commits one terminal generation" % [trigger, phase],
	)
	_check(
		not player.is_seated() and player.collision_layer != 0
			and not ship.is_piloted()
			and ship.get_command_source() == fixture.original_source
			and berth.get_reservation_owner() == null
			and area.get_reservation_token() == null,
		"%s during transition phase %d cancels embodiment and restores command/piloted/collision/tokens atomically" % [trigger, phase],
	)
	if trigger != &"queued_surface":
		await physics_frame
		await physics_frame
		_check(
			player.get_camera().current and player.is_control_enabled()
				and _player_has_live_surface_support(fixture),
			"current-surface %s recovery restores camera/control/live support" % trigger,
		)
	if detached:
		var replay := host.advance_physics(
			PHYSICS_DELTA, host.get_generation(), old_attachment,
			(fixture.frame as PlanetaryCoordinateFrame).get_generation(), 1
		)
		_check(replay.reason == &"stale_attachment_generation", "old attachment cannot resurrect a detached transition")
	await _cleanup(fixture)


func _fixture_at_surface_outbound() -> Dictionary:
	var fixture := await _fixture()
	if fixture.is_empty():
		return fixture
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.LANDED, 660):
		_check(false, "fixture reaches LANDED before surface setup")
		return {}
	var host := fixture.host as EmberSurfaceLoopHost
	host.request_disembark(host.get_generation(), host.get_attachment_generation())
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 300):
		_check(false, "fixture reaches SURFACE_OUTBOUND through public disembark")
		return {}
	return fixture


func _fixture_at_transition(phase: int) -> Dictionary:
	var fixture := {}
	if phase == EmberSurfaceLoopHost.Phase.DISEMBARKING:
		fixture = await _fixture()
	else:
		fixture = await _fixture_at_surface_outbound()
	if fixture.is_empty():
		return fixture
	var host := fixture.host as EmberSurfaceLoopHost
	if phase == EmberSurfaceLoopHost.Phase.DISEMBARKING:
		if not await _drive_to_phase(
			fixture, EmberSurfaceLoopHost.Phase.LANDED, 660
		):
			_check(false, "transition fixture reaches LANDED")
			return {}
		host = fixture.host as EmberSurfaceLoopHost
		host.request_disembark(host.get_generation(), host.get_attachment_generation())
		if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.DISEMBARKING, 300):
			_check(false, "transition fixture enters DISEMBARKING")
			return {}
		return fixture

	if not await _walk_outbound_route(fixture):
		_check(false, "transition fixture reaches ON_FOOT through real locomotion")
		return {}
	var area := fixture.area as ShipBoardingArea
	var player := fixture.player as PlayerController
	if not await _walk_return_to_boarding(fixture) \
			or not _player_near(area, player):
		_check(false, "transition fixture returns through egress to BoardingArea")
		return {}
	var boarded := host.request_reboard(host.get_generation(), host.get_attachment_generation())
	if not bool(boarded.get("accepted", false)) \
			or host.get_phase() != EmberSurfaceLoopHost.Phase.BOARDING:
		_check(false, "transition fixture enters BOARDING")
		return {}
	return fixture


func _fixture() -> Dictionary:
	var world := EmberSurfaceLoopHost.new()
	world.name = "EmberSurfaceLoopHost"
	root.add_child(world)
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	bootstrap.name = "EmberMoonStreamingBootstrap"
	world.add_child(bootstrap)
	var frame := bootstrap.get_coordinate_frame_for_session()
	var rebase := frame.request_rebase(bootstrap.position, frame.get_generation())
	if not bool(rebase.get("accepted", false)):
		_check(false, "fixture obtains the required Ember origin rebase")
		return {}
	bootstrap.position += rebase.request.world_translation_delta
	if not bool(frame.commit_rebase(rebase.request.request_id, 1).get("accepted", false)):
		_check(false, "fixture commits Ember frame generation two")
		return {}
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	if not bool(bootstrap.update_absolute_focus(body_coordinate, 2).get("accepted", false)):
		_check(false, "fixture loads current Ember generation one")
		return {}
	await process_frame
	await process_frame
	var scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if scene == null:
		_check(false, "fixture resolves the current authored Ember root")
		return {}
	var surface_rebase := frame.request_rebase(
		(scene.get_node(^"LandingRegion") as Node3D).global_position,
		frame.get_generation()
	)
	if not bool(surface_rebase.get("accepted", false)):
		_check(false, "fixture requests the caller-owned surface-local rebase")
		return {}
	bootstrap.position += surface_rebase.request.world_translation_delta
	if not bool(frame.commit_rebase(
		surface_rebase.request.request_id, 2
	).get("accepted", false)):
		_check(false, "fixture commits surface-local frame generation three")
		return {}

	var berth := EmberSurfaceBerth.new()
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
	ship.global_transform = Transform3D(
		Basis.IDENTITY,
		berth.global_position + EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M
	)
	ship.velocity = Vector3.ZERO
	var area := ship.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	await physics_frame
	_check(_player_near(area, player), "initial fixture physically discovers the exact Arrow BoardingArea")
	if not area.try_reserve(player) or not player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship
	):
		_check(false, "initial fixture establishes public seated/reservation state")
		return {}
	ship.set_piloted(true)
	var bound := world.bind_dependencies(
		bootstrap, berth, ship, player, 1.62, 1, 0, 0
	)
	if not bool(bound.get("accepted", false)):
		_check(false, "exact current dependencies bind: %s" % bound.get("reason", &""))
		return {}
	var started := world.start(0, world.get_attachment_generation(), 3)
	if not bool(started.get("accepted", false)):
		_check(false, "one exact staged fixture starts: %s" % started.get("reason", &""))
		return {}
	return {
		"world": world,
		"host": world,
		"bootstrap": bootstrap,
		"frame": frame,
		"scene": scene,
		"landing_root": scene.get_node(^"LandingRegion"),
		"walkable": scene.get_node(^"LandingRegion/WalkablePatch"),
		"berth": berth,
		"ship": ship,
		"player": player,
		"area": area,
		"original_source": original_source,
	}


func _drive_to_phase(fixture: Dictionary, phase: int, frame_budget: int) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	var last_result := {}
	for _index in frame_budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
		last_result = await _tick(fixture)
		if not bool(last_result.get("accepted", false)):
			break
	var reached := host.get_phase() == phase
	if not reached:
		var ship := fixture.ship as ArrowReconShip
		var player := fixture.player as PlayerController
		push_error(
			"DRIVE target=%d phase=%d reason=%s ship=%s speed=%.3f player=%s player_velocity=%s control=%s floor=%s telemetry=%s" % [
				phase, host.get_phase(), last_result.get("reason", &"budget_exhausted"),
				ship.global_position, ship.velocity.length(), player.global_position,
				player.velocity, player.is_control_enabled(), player.is_on_floor(),
				ship.get_telemetry(),
			]
		)
	return reached


func _walk_outbound_route(fixture: Dictionary) -> bool:
	if not await _walk_until(
		fixture, &"move_back", func(local: Vector3) -> bool: return local.x <= -9.0, 60
	):
		return false
	if not await _walk_until(
		fixture, &"move_right", func(local: Vector3) -> bool: return local.z >= 8.0, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_forward", func(local: Vector3) -> bool: return local.x >= 17.5, 120
	):
		return false
	if not await _walk_until(
		fixture, &"move_left", func(local: Vector3) -> bool: return local.z <= 0.5, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_forward", func(local: Vector3) -> bool: return local.x >= 41.5, 120
	):
		return false
	return (fixture.host as EmberSurfaceLoopHost).get_phase() \
		== EmberSurfaceLoopHost.Phase.ON_FOOT


func _walk_return_to_boarding(fixture: Dictionary) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	if not await _walk_until(
		fixture, &"move_back", func(local: Vector3) -> bool: return local.x <= 18.5, 120
	):
		return false
	if not bool((host.get_snapshot().surface_route as Dictionary).return_complete):
		return false
	if not await _walk_until(
		fixture, &"move_right", func(local: Vector3) -> bool: return local.z >= 8.0, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_back", func(local: Vector3) -> bool: return local.x <= -9.0, 120
	):
		return false
	if not await _walk_until(
		fixture, &"move_left", func(local: Vector3) -> bool: return local.z <= 0.5, 90
	):
		return false
	if not await _walk_until(
		fixture, &"move_forward", func(_local: Vector3) -> bool: return _player_near(area, player), 60
	):
		return false
	return _player_near(area, player)


func _walk_until(
	fixture: Dictionary,
	action: StringName,
	reached: Callable,
	frame_budget: int
) -> bool:
	var landing_root := fixture.landing_root as Node3D
	Input.action_press(action)
	for _index in frame_budget:
		var tick := await _tick(fixture)
		if not bool(tick.get("accepted", false)):
			Input.action_release(action)
			push_error("WALK action=%s rejected=%s phase=%d local=%s" % [
				action, tick.get("reason", &""),
				(fixture.host as EmberSurfaceLoopHost).get_phase(),
				landing_root.to_local((fixture.player as PlayerController).global_position),
			])
			return false
		if bool(reached.call(landing_root.to_local(
			(fixture.player as PlayerController).global_position
		))):
			Input.action_release(action)
			return true
	Input.action_release(action)
	var player := fixture.player as PlayerController
	var collisions: Array[String] = []
	for collision_index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(collision_index)
		collisions.append("%s:%s" % [collision.get_collider(), collision.get_normal()])
	push_error("WALK action=%s exhausted phase=%d local=%s velocity=%s" % [
		action, (fixture.host as EmberSurfaceLoopHost).get_phase(),
		landing_root.to_local(player.global_position), player.velocity,
	])
	push_error("WALK_COLLISIONS %s" % [collisions])
	return false


func _tick(fixture: Dictionary) -> Dictionary:
	await physics_frame
	var host := fixture.host as EmberSurfaceLoopHost
	return host.advance_physics(
		PHYSICS_DELTA,
		host.get_generation(),
		host.get_attachment_generation(),
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(),
		1
	)


func _absolute(frame: PlanetaryCoordinateFrame, body_local: Vector3) -> Dictionary:
	var encoded := frame.encode_body_local_position(body_local, frame.get_generation())
	return (encoded.coordinate as Dictionary).orbital_coordinate as Dictionary


func _player_near(area: ShipBoardingArea, player: PlayerController) -> bool:
	return area in player.get_nearby_interactables()


func _player_has_live_surface_support(fixture: Dictionary) -> bool:
	var player := fixture.player as PlayerController
	var landing_root := fixture.landing_root as Node3D
	var walkable := fixture.walkable as StaticBody3D
	var surface_up := landing_root.global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + surface_up * 0.5,
		player.global_position - surface_up * 2.5,
		PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [player.get_rid(), (fixture.ship as ArrowReconShip).get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == walkable \
		and (hit.get("normal", Vector3.ZERO) as Vector3).dot(surface_up) >= 0.9


func _cleanup(fixture: Dictionary) -> void:
	for action in [
		&"move_left", &"move_right", &"move_forward", &"move_back",
		&"sprint_boost",
	]:
		Input.action_release(action)
	var world := fixture.get("world") as Node
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_SURFACE_LOOP_HOST_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_SURFACE_LOOP_HOST_TEST: " + failure)
	quit(1)
