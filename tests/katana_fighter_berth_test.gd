extends SceneTree

## Full production-world berth fixture; unposed Main Player and once-staged standalone Katana.
const MAIN := preload("res://scenes/main.tscn")
const KATANA := preload("res://scenes/ships/katana_fighter.tscn")
const DOCK := Transform3D(Basis.IDENTITY, Vector3(72,-0.02,-30))
const DEFINITION := preload("res://assets/ships/katana_provisional.tres")
const WRONG := preload("res://assets/ships/torrent_provisional.tres")
const OLD_TRANSFORMS := {
	&"dynamic_home_berth": Transform3D(Basis.IDENTITY,Vector3(108,-0.02,-30)),
	&"utopia_home_berth": Transform3D(Basis.IDENTITY,Vector3(144,0.38,-30)),
	&"bulwark_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(52.0, 7.68, 53.05)),
	&"dock_04_cargo": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(7.0, 5.81, 84.7)),
	&"dock_05_bomber": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-15.0, 5.535, 34.3)),
	&"dock_06_interceptor": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(64.0, 5.26, 85.3)),
	&"central_berth": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -10.0)),
	&"arrow_recon_berth": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-43.0, 1.15, 15.5)),
	&"jovian_freight_berth": Transform3D(Basis(Vector3.UP, PI), Vector3(-53.0, 1.63, 57.3)),
	&"zenith_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(22.0, 5.28, 53.3)),
	&"halyard_fleet_dock_berth": Transform3D(Basis.IDENTITY, Vector3(37.0, 5.28, 53.3)),
	&"titan_home_berth": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(154, 0.38, 38)),
	&"predator_home_berth": Transform3D(Basis.IDENTITY, Vector3(39, -0.02, -30)),
	&"paradox_home_berth": Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(154,0.38,90)),
}
# Exact frozen station prefix, then the new dogleg/apron/control endpoints.
const ROUTE := [
	Vector3(8,0,11), Vector3(8,0,13.5), Vector3(35,0,13.5),
	Vector3(35,0,15.5), Vector3(39,0,15.5), Vector3(47,0,15.5),
	# Return through the accepted Predator aisle around the Habitat connector
	# side rail; preserve the frozen node endpoints without crossing that rail.
	Vector3(39,0,15.5), Vector3(39,0,8.5),
	Vector3(47,0,8.5), Vector3(47,0,7), Vector3(47,0,-8),
	Vector3(64,0,-8), Vector3(64,0,-22), Vector3(64,0,-30), Vector3(65.4,0,-28.4),
]
var _failed := false
var _game: GameFlow
var _player: PlayerController
var _ship: HeroShip
var _hatch: ShipCabinHatch
var _observer: CompletedPlayerTick
var _observing := false
var _last_tick := -1
var _last_position := Vector3.INF
var _samples := 0
var _started := 0
var _player_id := 0
var _walking_layer := 0
var _walking_mask := 0
var _walking_gravity := 0.0

class CompletedPlayerTick:
	extends Node
	signal completed_tick
	var observe: Callable
	func _physics_process(_delta: float) -> void:
		if observe.is_valid(): observe.call()
		completed_tick.emit()

func _init() -> void:
	_started = Time.get_ticks_msec()
	call_deferred("_run")

func _run() -> void:
	_game = MAIN.instantiate() as GameFlow
	root.add_child(_game)
	await _frames(3)
	_game.start_shift()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := _game.get_node("ShipyardWorld") as ShipyardWorld
	_player = _game.get_node("Player") as PlayerController
	_player.set_camera_active(false)
	await _frames(10)
	if not _check(_player.global_position.distance_to(world.get_player_spawn().origin) < 0.25
		and _player.is_on_floor(), "normal Main Player spawn without any pose write"): return
	var spawn := _player.global_position
	var module := world.get_node("KatanaFighterBerth") as KatanaFighterBerth
	var berth := world.get_berth_node(&"katana_home_berth")
	if not _check(berth != null and berth == module.get_node("ShipBerth")
		and berth.get_validation_errors().is_empty() and module.get_validation_errors().is_empty(), "valid own module and berth discovered"): return
	var matching := 0
	for candidate in get_nodes_in_group(ShipBerth.GROUP):
		if candidate.get_berth_id() == &"katana_home_berth": matching += 1
	if not _check(matching == 1 and world.get_berth_ids().size() == 15
		and _game.get_flyable_ships().size() == 14 and berth.get_occupant() == null
		and berth.get_reservation_owner() == null, "fifteen berths, fourteen flyable craft; new Katana berth initially empty"): return
	var old_leases: Dictionary = {}
	var old_craft := {}
	for craft in _game.get_flyable_ships(): old_craft[craft] = craft.global_transform
	for berth_id in OLD_TRANSFORMS:
		var old := world.get_berth_node(berth_id)
		var old_center := Vector3(0, 2.5, 1.5) if berth_id == &"predator_home_berth" else Vector3.ZERO
		if berth_id == &"paradox_home_berth": old_center = Vector3(0,3,2)
		if not _check(old.get_dock_transform().is_equal_approx(OLD_TRANSFORMS[berth_id])
			and old.landing_volume_center == old_center
			and old.get_landing_volume_transform().is_equal_approx(old.get_dock_transform() * Transform3D(Basis.IDENTITY, old_center)), "old berth pose and accepted center semantics preserved: " + str(berth_id)): return
		old_leases[berth_id] = {"audit": old.get_audit_report(), "owner": old.get_reservation_owner(),
			"occupant": old.get_occupant(), "token": old.get_reservation_token(old.get_reservation_owner())}
	var dock := DOCK
	if not _check(berth.get_dock_transform().is_equal_approx(dock)
		and berth.compatibility_tags == PackedStringArray(["katana_fighter"])
		and berth.landing_volume_center == Vector3.ZERO and berth.landing_half_extents == Vector3(7,6.5,7)
		and berth.assist_capture_center == Vector3(0,8,-18) and berth.assist_capture_half_extents == Vector3(20,14,30)
		and berth.assist_capture_maximum_speed == 28 and berth.assist_maximum_tilt_degrees == 70
		and berth.departure_lift_height == 4 and DEFINITION.landing_maximum_speed == 15, "exact frozen root, fit, capture and departure fields"): return
	var marker := berth.get_node("LandingVolumeCenter") as Marker3D
	if not _check(marker.global_transform.is_equal_approx(berth.get_landing_volume_transform())
		and marker.position == Vector3.ZERO
		and berth.get_assist_capture_transform().origin.is_equal_approx(dock * Vector3(0,8,-18))
		and berth.get_departure_lift_for(dock.origin).height == 4, "physical tight marker composes center while capture and departure stay root based"): return
	var registry := world.get_station_route_registry_report()
	var graph := world.get_station_navigation_graph_report()
	var edge: Dictionary = graph.get("edges", {}).get(&"hub-katana-fighter-berth", {})
	if not _check(registry.valid and registry.modules.size() == 13 and registry.route_marker_count == 69
		and registry.slots.size() == 13 and registry.hub_endpoints.size() == 13 and registry.modules.has(&"katana-fighter-berth")
		and graph.valid and is_equal_approx(float(edge.get("length", -1)), 1.5)
		and edge.get("hub_node_id") == &"station-hub:hub-katana-fighter-berth"
		and edge.get("module_node_id") == &"katana-fighter-berth:approach", "real new 1.5m supported navigation edge"): return
	if not _test_module_geometry(module): return
	# One initial fixture pose only; this candidate never joins Main's roster.
	_ship = KATANA.instantiate() as HeroShip
	_ship.name = "KatanaBerthFixture"
	_ship.transform = DOCK
	root.add_child(_ship)
	await _frames(3)
	if not _check((_ship.get_node("DockingReceiver") as Node3D).transform == Transform3D.IDENTITY
		and _ship.global_transform.is_equal_approx(DOCK) and not _game.get_flyable_ships().has(_ship),
		"actual standalone candidate initially staged at exact dock; identity receiver and no Main registration"): return
	if not _test_leases(berth): return
	for open in [false, true]:
		_ship.set_canopy_open(open, 0.0)
		await _frames(3)
		var bounds: AABB = _ship.get_landing_collision_report().local_bounds
		var expected_bounds := AABB(Vector3(-6 if open else -5.5,0,-6), Vector3(11.5 if open else 11,5.8 if open else 3.8,12))
		if not _check(_ship.is_canopy_open() == open and bounds.is_equal_approx(expected_bounds)
			and berth.contains_oriented_bounds(_ship.global_transform, bounds) and _ship.call("is_access_supported"), "whole actual candidate closed/deployed bounds fit tight volume: " + str(bounds)): return
		var outside := _ship.global_transform
		outside.origin += dock.basis.x * 2.0
		if not _check(berth.contains_assist_capture(outside.origin) and berth.contains(outside.origin) and not berth.contains_oriented_bounds(outside, bounds)
			and berth.contains_oriented_bounds(dock, bounds), "actual outside hull corner refuses despite root remaining inside tight volume"): return
		if not _test_ship_render_geometry() or not _test_clearance(module, open): return
	_ship.set_canopy_open(false, 0.0)
	await _frames(3)
	_hatch = _ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	_observer = CompletedPlayerTick.new()
	_observer.name = "CompletedPlayerPhysicsObserver"
	_player_id = _player.get_instance_id()
	_walking_layer = _player.collision_layer
	_walking_mask = _player.collision_mask
	_walking_gravity = _player.gravity_multiplier
	_observer.process_physics_priority = _player.process_physics_priority + 1
	_observer.observe = _observe_completed_tick
	root.add_child(_observer)
	_observing = true
	print("KATANA_BERTH_FROZEN_ROUTE: ", ROUTE)
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index], index): return
	var local := _ship.to_local(_player.global_position)
	if not _check(Vector2(local.x + 6.6, local.z - 1.6).length() < 0.08
		and absf(local.y) < 0.03 and _hatch.is_available()
		and _player.get_interaction_origin().distance_to(_hatch.global_position) < ShipCabinHatch.MAX_REACH,
		"ordinary route reaches actual supported candidate control within unchanged 2.5m reach"): return
	var discovered := false
	for area in (_player.get_node("InteractionArea") as Area3D).get_overlapping_areas():
		if area == _hatch: discovered = true
	if not _check(discovered, "actual Main Player proximity discovers available production control"): return
	for index in range(ROUTE.size()-2,-1,-1):
		if not await _walk_to(ROUTE[index],100+index): return
	if not await _walk_to(spawn,200): return
	if not _check(_samples > 1000 and _player.global_position.distance_to(spawn) < 0.08,
		"same actual Player returns along full frozen route to original Main spawn with every tick observed"): return
	for berth_id in OLD_TRANSFORMS:
		var old := world.get_berth_node(berth_id)
		var saved: Dictionary = old_leases[berth_id]
		if not _check(old.get_dock_transform().is_equal_approx(OLD_TRANSFORMS[berth_id]) and old.get_audit_report() == saved.audit and old.get_reservation_owner() == saved.owner
			and old.get_occupant() == saved.occupant and old.get_reservation_token(saved.owner) == saved.token,
			"old lease remains unchanged: " + str(berth_id)): return
	for craft in old_craft:
		if not _check(is_instance_valid(craft) and craft.global_transform.is_equal_approx(old_craft[craft]),
			"all fourteen old occupied craft retain exact poses"): return
	if not _check(berth.get_occupant() == null and berth.get_reservation_owner() == null
		and _game.get_flyable_ships().size() == 14, "fixture leaves new berth empty and Main roster unchanged"): return
	_observing = false
	_release_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_observer.queue_free()
	_ship.queue_free()
	_game.queue_free()
	await _frames(3)
	print("KATANA_FIGHTER_BERTH_TEST_PASS")
	quit(0)

func _test_module_geometry(module: KatanaFighterBerth) -> bool:
	var expected := {
		"BerthDeck": AABB(Vector3(-9,-0.4,-9),Vector3(18,0.4,18)),
		"SpurA": AABB(Vector3(-26.4,-0.4,20.6),Vector3(2.8,0.4,16.4)),
		"SpurB": AABB(Vector3(-23.6,-0.4,20.6),Vector3(17,0.4,2.8)),
		"SpurC": AABB(Vector3(-9.4,-0.4,9),Vector3(2.8,0.4,11.6)),
	}
	for node_name: String in expected:
		var body := module.get_node(node_name) as StaticBody3D
		var collision := body.get_node("CollisionShape3D") as CollisionShape3D
		var mesh := body.get_node("Mesh") as MeshInstance3D
		var shape := collision.shape as BoxShape3D
		var bounds := AABB(body.position-shape.size*0.5,shape.size)
		if not _check(bounds.is_equal_approx(expected[node_name]) and (mesh.mesh as BoxMesh).size == shape.size
			and mesh.global_transform.is_equal_approx(collision.global_transform) and not collision.disabled
			and body.collision_layer == PhysicsLayers.WORLD and body.get_meta("walkable_surface",false),
			"exact frozen physical support slab and visible size: " + node_name): return false
	return _check(module.get_route_transform(&"approach").origin.is_equal_approx(Vector3(47,-0.02,7))
		and module.get_route_transform(&"port-apron").origin.is_equal_approx(Vector3(64,-0.02,-30))
		and module.get_route_transform(&"hatch-control").origin.is_equal_approx(Vector3(65.4,-0.02,-28.4))
		and module.get_node("KatanaBerthSign") is Label3D, "signed route markers agree with real support")

func _test_ship_render_geometry() -> bool:
	for child in _ship.get_children():
		if not child is CollisionShape3D: continue
		var collision := child as CollisionShape3D
		var label := String(collision.name).trim_suffix("Collision")
		var meshes := _ship.get_node("KatanaOriginalShell").find_children(label,"MeshInstance3D",true,false)
		if not _check(meshes.size() == 1, "one actual renderer per physical section " + label): return false
		var mesh := meshes[0] as MeshInstance3D
		if not _check(mesh.global_transform.is_equal_approx(collision.global_transform), "matching actual collider/render transform " + label): return false
		if collision.shape is BoxShape3D:
			if not _check((mesh.mesh as BoxMesh).size == (collision.shape as BoxShape3D).size,"matching actual seat shape " + label): return false
			continue
		var points := (collision.shape as ConvexPolygonShape3D).points
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in points:
			if not _check(_has_point(vertices,point),"actual render buffer contains collision vertex " + label): return false
		for vertex in vertices:
			if not _check(_has_point(points,vertex),"actual collision contains render vertex " + label): return false
	return true

func _has_point(points: PackedVector3Array, target: Vector3) -> bool:
	for point in points:
		if point.is_equal_approx(target): return true
	return false

func _test_leases(berth: ShipBerth) -> bool:
	var before := berth.get_audit_report()
	if not _check(not berth.can_accept(WRONG, _player) and berth.try_reserve(_player, WRONG).is_empty()
		and berth.get_audit_report() == before, "wrong-tag reservation refuses atomically"): return false
	var token := berth.try_reserve(_ship, DEFINITION)
	if not _check(not token.is_empty() and berth.try_reserve(_ship, DEFINITION) == token
		and berth.occupy(_ship, token) and berth.get_occupant() == _ship, "compatible exclusive lease reserves idempotently and occupies"): return false
	before = berth.get_audit_report()
	if not _check(not berth.can_accept(DEFINITION, _player) and berth.try_reserve(_player, DEFINITION).is_empty()
		and not berth.occupy(_player, token) and not berth.release(_ship, &"stale")
		and berth.get_audit_report() == before and berth.get_occupant() == _ship
		and berth.has_valid_lease(_ship, token, DEFINITION.ship_id), "occupied foreign and stale-token operations refuse atomically"): return false
	if not _check(berth.release(_ship, token) and berth.get_occupant() == null
		and berth.get_reservation_owner() == null, "correct release clears own lease"): return false
	var fresh := berth.try_reserve(_ship, DEFINITION)
	before = berth.get_audit_report()
	if not _check(not fresh.is_empty() and fresh != token and not berth.occupy(_ship, token)
		and not berth.release(_ship, token) and berth.get_audit_report() == before
		and berth.has_valid_lease(_ship, fresh, DEFINITION.ship_id) and berth.get_occupant() == null, "old token cannot touch fresh reused lease"): return false
	return _check(berth.occupy(_ship, fresh) and berth.release(_ship, fresh), "fresh reused lease occupies and releases normally")

func _test_clearance(module: KatanaFighterBerth, deployed: bool) -> bool:
	var support := module.get_node("BerthDeck") as StaticBody3D
	var state := _ship.get_world_3d().direct_space_state
	for candidate in _ship.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.disabled or not collision.get_parent() == _ship: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		query.margin = 0
		query.exclude = [_ship.get_rid(), support.get_rid()]
		query.motion = Vector3.UP * 4
		var fractions := state.cast_motion(query)
		query.motion = Vector3.ZERO
		var hits := state.intersect_shape(query, 64)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0 and hits.is_empty(), "actual hull/access full 4m continuous lift: deployed=%s shape=%s fractions=%s hits=%s" % [deployed, collision.name, fractions, hits]): return false
		# Continue every actual hull/access shape along the elevated forward lane
		# to staging (local z=-18); no neighboring craft is excluded.
		query.transform.origin += Vector3.UP * 4
		query.exclude = [_ship.get_rid()]
		query.motion = -_ship.global_basis.z * 18
		fractions = state.cast_motion(query)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0, "actual elevated forward lane shape=%s fractions=%s" % [collision.name, fractions]): return false
		query.transform.origin -= _ship.global_basis.z * 18
		query.motion = Vector3.UP * 4
		fractions = state.cast_motion(query)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0, "actual lane-to-staging rise shape=%s fractions=%s" % [collision.name, fractions]): return false
		query.transform = Transform3D(_ship.global_basis, _ship.to_global(Vector3(0,8,-18))) * collision.transform
		query.motion = Vector3.ZERO
		hits = state.intersect_shape(query, 64)
		if not _check(hits.is_empty(), "actual staging shape=%s hits=%s" % [collision.name, hits]): return false
		query.motion = Vector3.DOWN * 4
		fractions = state.cast_motion(query)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0,"actual approach staging-to-lane descent " + collision.name): return false
		query.transform.origin += Vector3.DOWN * 4
		query.motion = _ship.global_basis.z * 18
		fractions = state.cast_motion(query)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0,"actual approach lane-to-home sweep " + collision.name): return false
		query.transform.origin += _ship.global_basis.z * 18
		query.exclude = [_ship.get_rid(),support.get_rid()]
		query.motion = Vector3.DOWN * 4
		fractions = state.cast_motion(query)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0,"actual final descent to own support clears neighbors " + collision.name): return false
	return _test_actual_chase_camera()

func _test_actual_chase_camera() -> bool:
	var arm := _ship.get_node("CameraRig/CameraCollisionArm") as SpringArm3D
	var camera := _ship.get_camera()
	var state := _ship.get_world_3d().direct_space_state
	for offset in [Vector3.ZERO,Vector3.UP*4,Vector3(0,4,-18),Vector3(0,8,-18)]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = arm.shape
		query.transform = arm.global_transform
		query.transform.origin += offset
		query.motion = arm.global_basis.z * arm.spring_length
		query.margin = arm.margin
		query.exclude = [_ship.get_rid()]
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		var fractions := state.cast_motion(query)
		if not _check(fractions[0] == 1.0 and fractions[1] == 1.0, "actual default chase spring arm clears live neighbors at lift " + str(offset)): return false
		query.transform = camera.global_transform
		query.transform.origin += offset
		query.motion = Vector3.ZERO
		if not _check(state.intersect_shape(query, 64).is_empty(), "actual chase-camera sphere clears live neighbors at lift " + str(offset)): return false
		var motion := Vector3.ZERO
		if offset == Vector3.ZERO: motion = Vector3.UP * 4
		elif offset == Vector3.UP * 4: motion = Vector3.FORWARD * 18
		elif offset == Vector3(0,4,-18): motion = Vector3.UP * 4
		if motion != Vector3.ZERO:
			query.motion = motion
			fractions = state.cast_motion(query)
			if not _check(fractions[0] == 1.0 and fractions[1] == 1.0, "actual continuous camera departure segment clears neighbors " + str(offset)): return false
			query.transform.origin += motion
			query.motion = -motion
			fractions = state.cast_motion(query)
			if not _check(fractions[0] == 1.0 and fractions[1] == 1.0, "actual continuous camera approach segment clears neighbors " + str(offset)): return false
	return _check(_ship.get_chase_camera_self_hull_boundary_report().valid, "actual inherited default chase near plane clears own hull")

func _walk_to(target: Vector3, leg: int) -> bool:
	var reached := false
	for tick in 900:
		if _failed: return false
		var offset := target - _player.global_position
		offset.y = 0
		if absf(offset.x) < 0.02: offset.x = 0
		if absf(offset.z) < 0.02: offset.z = 0
		if offset.length() <= 0.035:
			reached = true
			break
		var direction := (_player.get_node("%CameraYaw") as Node3D).global_basis.inverse() * offset.normalized()
		_release_inputs()
		var strength := 0.4 if offset.length() < 0.8 else 1.0
		Input.action_press(&"move_right" if direction.x > 0 else &"move_left", absf(direction.x) * strength)
		Input.action_press(&"move_back" if direction.z > 0 else &"move_forward", absf(direction.z) * strength)
		await _observer.completed_tick
	_release_inputs()
	for tick in 12:
		await _observer.completed_tick
		if _failed: return false
	print("KATANA_BERTH_ROUTE_LEG: ", {"leg": leg, "target": target, "actual": _player.global_position, "reached": reached})
	if not reached:
		_log_route_failure(target, leg)
	return _check(reached, "ordinary walk reaches frozen endpoint " + str(leg))

## Diagnostic-only operands after the unchanged full walking leg has failed.
func _log_route_failure(target: Vector3, leg: int) -> void:
	print("KATANA_BERTH_ROUTE_FAILURE_ACTOR: ", {"leg": leg, "target": target,
		"position": _player.global_position, "velocity": _player.velocity,
		"physics_frame": Engine.get_physics_frames(), "floor": _player.is_on_floor(),
		"floor_normal": _player.get_floor_normal(), "collision_mask": _player.collision_mask,
		"collision_layer": _player.collision_layer, "gravity_multiplier": _player.gravity_multiplier,
		"gravity": _player.get_gravity(), "motion_audit": _player.get_step_up_assist_audit(),
		"slide_count": _player.get_slide_collision_count()})
	for index in _player.get_slide_collision_count():
		var hit := _player.get_slide_collision(index)
		var collider := hit.get_collider() as Node
		print("KATANA_BERTH_ROUTE_FAILURE_SLIDE: ", {"index": index,
			"collider_path": str(collider.get_path()) if collider != null else "<none>",
			"collider_name": str(collider.name) if collider != null else "<none>",
			"rid": hit.get_collider_rid(), "position": hit.get_position(),
			"normal": hit.get_normal(), "depth": hit.get_depth(),
			"travel": hit.get_travel(), "remainder": hit.get_remainder()})
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var direction := (target - _player.global_position).slide(Vector3.UP).normalized()
	for advance in [0.05, 0.1, 0.2, 0.4]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.transform.origin += direction * advance
		query.collision_mask = _player.collision_mask
		query.margin = 0
		query.exclude = [_player.get_rid()]
		var operands: Array[Dictionary] = []
		for hit in _player.get_world_3d().direct_space_state.intersect_shape(query, 64):
			var collider := hit.collider as Node
			operands.append({"collider_path": str(collider.get_path()) if collider != null else "<none>",
				"collider_name": str(collider.name) if collider != null else "<none>",
				"rid": hit.rid, "shape": hit.shape})
		print("KATANA_BERTH_ROUTE_FAILURE_FORWARD_CAPSULE: ", {"advance": advance,
			"transform": query.transform, "mask": query.collision_mask, "hits": operands})

func _observe_completed_tick() -> void:
	if not _observing or _failed: return
	var current := Engine.get_physics_frames()
	var completed: Dictionary = _player.get_step_up_assist_audit().get("completed_motion", {})
	if not _check(int(completed.get("frame", -1)) == current
		and _observer.process_physics_priority > _player.process_physics_priority
		and (_last_tick < 0 or current == _last_tick + 1), "adjacent completed Player physical tick; previous=%d current=%d audit=%s" % [_last_tick, current, completed], false): return
	var point := _player.global_position
	if not _check(_player.get_instance_id() == _player_id and _player.collision_layer == _walking_layer
		and _player.collision_mask == _walking_mask and _player.gravity_multiplier == _walking_gravity
		and not _player.is_seated() and not Input.is_action_pressed("jump"), "same unchanged walking actor/masks/gravity", false): return
	if not _check(_player.is_on_floor() and (not _last_position.is_finite() or point.distance_to(_last_position) < 0.2), "every completed tick has floor and <0.2m continuous movement: previous=%s current=%s" % [_last_position, point], false): return
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [_player.get_rid()]
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(query, 32)
	if not _check(hits.is_empty(), "actual capsule/head clear on every completed tick: pose=%s hits=%s" % [point, hits], false): return
	var head := SphereShape3D.new()
	head.radius = 0.16
	query.shape = head
	query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*1.76)
	if not _check(_player.get_world_3d().direct_space_state.intersect_shape(query,32).is_empty(),"actual head clearance on every completed tick",false): return
	var support := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.12,point-Vector3.UP*0.18,PhysicsLayers.WORLD|PhysicsLayers.SHIP,[_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(support)
	if not _check(not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) >= cos(_player.floor_max_angle),"actual supporting floor ray every completed tick",false): return
	_last_tick = current
	_last_position = point
	_samples += 1
	if Time.get_ticks_msec() - _started > 240000:
		_check(false, "full fixture exceeded frozen 240s hard limit")

func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump", &"interact"]:
		Input.action_release(action)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String, verbose: bool = true) -> bool:
	if not condition:
		_failed = true
		_release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("KATANA_FIGHTER_BERTH_TEST_FAIL: ", message)
		quit(1)
	elif verbose:
		print("PASS: ", message)
	return condition
