extends SceneTree

## Complete normal Main Player round trip to the occupied physical Utopia home.
## The real Main Utopia proves strict fit, actual convex/camera clearance and
## supported control access; all fourteen other craft and leases stay intact.
## Preloads reference production only, so the same fixture uses the real PCK.
const MAIN := preload("res://scenes/main.tscn")
const UTOPIA := preload("res://scenes/ships/utopia_dropship.tscn")
const DEFINITION := preload("res://assets/ships/utopia_provisional.tres")
const WRONG := preload("res://assets/ships/torrent_provisional.tres")
const OLD_TRANSFORMS := {
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
	&"dynamic_home_berth": Transform3D(Basis.IDENTITY,Vector3(108,-0.02,-30)),
}
const OLD_CENTERS := {
	&"arrow_recon_berth": Vector3(0.0,0.0,0.0),
	&"bulwark_fleet_dock_berth": Vector3(0.0,0.0,0.0),
	&"central_berth": Vector3(0.0,0.0,0.0),
	&"dock_04_cargo": Vector3(0.0,0.0,0.0),
	&"dock_05_bomber": Vector3(0.0,0.0,0.0),
	&"dock_06_interceptor": Vector3(0.0,0.0,0.0),
	&"halyard_fleet_dock_berth": Vector3(0.0,0.0,0.0),
	&"jovian_freight_berth": Vector3(0.0,0.0,0.0),
	&"paradox_home_berth": Vector3(0.0,3.0,2.0),
	&"dynamic_home_berth": Vector3.ZERO,
	&"predator_home_berth": Vector3(0.0,2.5,1.5),
	&"titan_home_berth": Vector3(0.0,0.0,0.0),
	&"zenith_fleet_dock_berth": Vector3(0.0,0.0,0.0),
}
const ROUTE := [
	Vector3(8,0,11),Vector3(8,0,13.5),Vector3(35,0,13.5),
	Vector3(35,0,15.5),Vector3(43,0,15.5),Vector3(43,0,24.8),
	Vector3(48.1,0,24.8),Vector3(48.1,0,28),Vector3(68.5,0,28),
	Vector3(68.5,0,38),Vector3(83,0,38),Vector3(93.3,0,38),
	Vector3(116.5,0,38),Vector3(116.5,0,46),Vector3(124.5,0,46),
	Vector3(129.65,0,41.55),Vector3(130.5,0.38,38),Vector3(135,0.38,38),
	Vector3(135,0.38,-16.4),Vector3(140.6,0.38,-16.4),Vector3(140.6,0.38,-19.9),
]
var _failed := false
var _started := 0
var _checks := 0
var _game: GameFlow
var _player: PlayerController
var _ship: HeroShip
var _observer: CompletedPlayerTick
var _active := false
var _samples := 0
var _last_frame := -1
var _last_point := Vector3.INF
var _body_layer := 0
var _body_mask := 0
var _gravity := 0.0
var _capsule_size := Vector2.ZERO
var _capsule_pose := Transform3D.IDENTITY

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
	var watchdog := create_timer(240.0)
	watchdog.timeout.connect(func(): _check(false,"complete fixture exceeds unchanged240s cap"))
	_game = MAIN.instantiate() as GameFlow
	root.add_child(_game)
	await _frames(3)
	_game.start_shift()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := _game.get_node("ShipyardWorld") as ShipyardWorld
	_player = _game.get_node("Player") as PlayerController
	_player.set_camera_active(false)
	await _frames(10)
	var spawn := _player.global_position
	if not _check(spawn.distance_to(world.get_player_spawn().origin) < 0.25 and _player.is_on_floor(),"same actual Main Player starts at supported normal production spawn"): return
	var module := world.get_node("UtopiaDropshipBerth") as UtopiaDropshipBerth
	var berth := world.get_berth_node(&"utopia_home_berth")
	if not _check(module != null and berth != null and berth == module.get_node("ShipBerth") and module.get_validation_errors().is_empty(),"world discovers valid signed physical Utopia module and its own berth"): return
	var matching := 0
	for candidate in get_nodes_in_group(ShipBerth.GROUP):
		if candidate.get_berth_id() == &"utopia_home_berth": matching += 1
	if not _check(matching == 1 and world.get_berth_ids().size() == 15 and _game.get_flyable_ships().size() == 15 and _game.get_node_or_null("UtopiaDropship") != null and berth.get_occupant() == _game.get_node("UtopiaDropship") and berth.get_reservation_owner() == _game.get_node("UtopiaDropship"),"fifteen physical berths and fifteen actual flyables; Utopia owns its unique occupied home"): return
	var dock := Transform3D(Basis.IDENTITY,Vector3(144,0.38,-30))
	if not _check(berth.get_dock_transform().is_equal_approx(dock) and berth.dock_transform == Transform3D.IDENTITY and berth.compatibility_tags == PackedStringArray(["utopia_supply"]) and berth.landing_volume_center == Vector3.ZERO and berth.landing_half_extents == Vector3(5.5,6,14) and berth.assist_capture_center == Vector3(0,8,-20) and berth.assist_capture_half_extents == Vector3(18,14,32) and berth.assist_capture_maximum_speed == 28 and berth.assist_maximum_tilt_degrees == 70 and berth.departure_lift_height == 4 and DEFINITION.landing_maximum_speed == 10.5,"exact adopted root/strict-center/fit/capture/speed/tilt/departure contract"): return
	var registry := world.get_station_route_registry_report()
	var graph := world.get_station_navigation_graph_report()
	var edge := (graph.get("edges",{}) as Dictionary).get(&"hub-utopia-dropship-berth",{}) as Dictionary
	if not _check(registry.valid and registry.modules.size() == 13 and registry.route_marker_count == 69 and registry.hub_endpoints.size() == 13 and registry.slots.size() == 13 and graph.valid and is_equal_approx(float(edge.get("length",-1)),1.5) and edge.get("hub_node_id") == &"station-hub:hub-utopia-dropship-berth" and edge.get("module_node_id") == &"utopia-dropship-berth:approach","complete thirteen-module/69-marker registry and actual 1.5m supported navigation edge"): return
	if not _check(world.get_ship_berth_feedback_audit_report().valid,"existing six feedback owners remain valid with fifteenth berth"): return
	var saved_berths := {}
	var saved_craft := {}
	for id: StringName in OLD_TRANSFORMS:
		var old := world.get_berth_node(id)
		if not _check(old != null and world.get_berth_transform(id).is_equal_approx(OLD_TRANSFORMS[id]) and old.landing_volume_center.is_equal_approx(OLD_CENTERS[id]),"all old berth poses and strict centers remain exact " + str(id)): return
		var owner := old.get_reservation_owner()
		saved_berths[id] = {"owner":owner,"occupant":old.get_occupant(),"token":old.get_reservation_token(owner),"ship_id":old.get_reserved_ship_id(),"audit":old.audit()}
	for craft: HeroShip in _game.get_flyable_ships():
		if craft != _game.get_node("UtopiaDropship"):
			saved_craft[craft] = craft.global_transform
	if not _check(saved_berths.size() == 13 and saved_craft.size() == 14,"all thirteen original berth and fourteen other craft states retained before candidate probes"): return
	_ship = _game.get_node("UtopiaDropship") as HeroShip
	if not _check((_ship.get_node("DockingReceiver") as Marker3D).transform == Transform3D.IDENTITY and _game.get_flyable_ships().has(_ship) and _ship.global_transform.is_equal_approx(dock),"actual registered Main Utopia has identity receiver and exact own dock pose"): return
	if not _test_module_geometry(module): return
	var occupied_before := berth.audit()
	var live_token := berth.get_reservation_token(_ship)
	if not _check(berth.try_reserve(_ship,DEFINITION) == live_token and berth.occupy(_ship,live_token) and not berth.can_accept(WRONG,_player) and berth.try_reserve(_player,WRONG).is_empty() and not berth.occupy(_player,live_token) and not berth.release(_player,live_token) and not berth.release(_ship,&"stale") and berth.try_reserve(_player,DEFINITION).is_empty() and berth.audit() == occupied_before,"actual occupied Main lease preserves owner/token through idempotent/wrong-tag/foreign/stale requests"): return
	# Preserve every original empty/fresh/stale lifecycle case on the exact
	# production component and fields, without cloning or moving a live hull.
	var ledger := ShipBerth.new()
	ledger.berth_id = &"utopia_independent_lease_fixture"
	for field in [&"compatibility_tags",&"dock_transform",&"landing_volume_center",&"landing_half_extents",&"assist_capture_center",&"assist_capture_half_extents",&"assist_capture_maximum_speed",&"assist_maximum_tilt_degrees",&"departure_lift_height"]:
		ledger.set(field,berth.get(field))
	root.add_child(ledger)
	if not _test_leases(ledger): return
	ledger.free()
	if not _check(berth.audit() == occupied_before and berth.get_occupant() == _ship and berth.get_reservation_token(_ship) == live_token and _ship.global_transform.is_equal_approx(dock),"independent empty-ledger cases leave actual Main geometry and occupied home unchanged"): return
	for deployed in [false,true]:
		_ship.set_canopy_open(deployed,0)
		await _frames(80)
		var bounds: AABB = _ship.get_landing_collision_report().local_bounds
		var expected := AABB(Vector3(-4.5,0,-8.5),Vector3(9,4.8,21)) if deployed else AABB(Vector3(-4.5,0,-8.5),Vector3(9,4.8,17))
		if not _check(_ship.is_canopy_open() == deployed and bounds.is_equal_approx(expected) and berth.contains_oriented_bounds(dock,bounds),"complete actual closed/deployed candidate fits exact strict volume " + str(bounds)): return
		var outside := dock
		outside.origin += dock.basis.x * 1.01
		if not _check(berth.contains(outside.origin) and not berth.contains_oriented_bounds(outside,bounds),"root-inside full-envelope overhang refuses without broadening strict fit"): return
		if not _test_clearance(module,deployed): return
	var bounds: AABB = _ship.get_landing_collision_report().local_bounds
	var staging := berth.get_assist_staging_transform()
	if not _check(berth.evaluate_assist_capture_candidate(staging,bounds,Vector3.RIGHT*28,10.5).valid and not berth.evaluate_assist_capture_candidate(staging,bounds,Vector3.RIGHT*28.1,10.5).valid and not berth.evaluate_landing_candidate(dock,bounds,Vector3.RIGHT*10.6,10.5).valid and berth.evaluate_landing_candidate(dock,bounds,Vector3.RIGHT*10.5,10.5).valid and berth.get_departure_lift_for(dock.origin).height == 4,"real independent 28m/s capture and 10.5m/s strict landing gates retain exact 4m departure"): return
	_ship.set_canopy_open(false,0)
	await _frames(80)
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	_body_layer = _player.collision_layer
	_body_mask = _player.collision_mask
	_gravity = _player.gravity_multiplier
	_capsule_size = Vector2(capsule.radius,capsule.height)
	_capsule_pose = collision.transform
	_observer = CompletedPlayerTick.new()
	_observer.process_physics_priority = _player.process_physics_priority + 1
	_observer.observe = _observe_completed_tick
	root.add_child(_observer)
	_active = true
	print("UTOPIA_BERTH_FROZEN_ROUTE: ",ROUTE)
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index],index): return
	var local := _ship.to_local(_player.global_position)
	var hatch := _ship.get_node("CabinHatchInteraction") as ShipCabinHatch
	if not _check(Vector2(local.x+3.4,local.z-10.1).length() < 0.08 and absf(local.y) < 0.03 and hatch.is_available() and _player.get_nearby_interactables().has(hatch) and _player.get_interaction_origin().distance_to(hatch.global_position) < ShipCabinHatch.MAX_REACH,"same ordinary Player reaches physically discovered hatch control within unchanged 2.5m reach"): return
	if not _check(hatch.interact(_player),"physically reached normal hatch API opens"): return
	await _frames(80)
	if not _check(_ship.is_canopy_open() and not _ship.call("is_access_motion_active"),"reached hatch opens fully on actual supported deck"): return
	if not _check(hatch.interact(_player),"same physical normal hatch API seals"): return
	await _frames(80)
	if not _check(not _ship.is_canopy_open(),"reached hatch seals fully"): return
	for index in range(ROUTE.size()-2,-1,-1):
		if not await _walk_to(ROUTE[index],100+index): return
	if not await _walk_to(spawn,199): return
	_active = false
	if not _check(_samples > 1000,"whole route and complete reverse to actual original spawn audited on every completed Player tick samples=" + str(_samples)): return
	for id: StringName in OLD_TRANSFORMS:
		var old := world.get_berth_node(id)
		var saved: Dictionary = saved_berths[id]
		if not _check(world.get_berth_transform(id).is_equal_approx(OLD_TRANSFORMS[id]) and old.landing_volume_center.is_equal_approx(OLD_CENTERS[id]) and old.get_reservation_owner() == saved.owner and old.get_occupant() == saved.occupant and old.get_reservation_token(saved.owner) == saved.token and old.get_reserved_ship_id() == saved.ship_id and old.audit() == saved.audit,"all thirteen old complete berth states preserved " + str(id)): return
	for craft: HeroShip in saved_craft:
		if not _check(craft.global_transform.is_equal_approx(saved_craft[craft]),"all fourteen old craft poses preserved " + String(craft.name)): return
	if not _check(berth.audit() == occupied_before and berth.get_occupant() == _ship and berth.get_reservation_owner() == _ship and berth.get_reservation_token(_ship) == live_token and _game.get_flyable_ships().has(_ship),"actual Utopia occupied home and exact live lease remain unchanged after complete probes and route"): return
	print("UTOPIA_BERTH_MODULE_BUDGET: ",module.get_performance_contract())
	_release_inputs()
	_observer.queue_free()
	_game.queue_free()
	await _frames(3)
	print("UTOPIA_DROPSHIP_BERTH_TEST_OK: checks=",_checks," walking_ticks=",_samples)
	quit(0)

func _test_module_geometry(module: UtopiaDropshipBerth) -> bool:
	var floor := module.get_node("BerthDeck") as StaticBody3D
	var collision := floor.get_node("CollisionShape3D") as CollisionShape3D
	var mesh := floor.get_node("Mesh") as MeshInstance3D
	if not _check((collision.shape as BoxShape3D).size == Vector3(13,0.4,30) and (mesh.mesh as BoxMesh).size == Vector3(13,0.4,30) and floor.global_position.is_equal_approx(Vector3(144,0.18,-30)) and mesh.transform == collision.transform,"matching13x30 physical/visible deck gives2.5m stern apron beyond actual deployed ramp and flush+.38 support"): return false
	var bodies := module.find_children("*","StaticBody3D",true,false)
	var shapes := module.find_children("*","CollisionShape3D",true,false)
	var meshes := module.find_children("*","MeshInstance3D",true,false)
	var signs := module.find_children("*","Label3D",true,false)
	if not _check(bodies.size() == 10 and shapes.size() == 12 and meshes.size() == 110 and signs.size() == 1 and "UTOPIA" in (signs[0] as Label3D).text and "STERN ACCESS" in (signs[0] as Label3D).text and module.get_performance_contract().within_budget,"exact10body/12shape/110mesh signed production module stays within frozen component budget"): return false
	var mount := module.get_node("SafetyEdge05") as StaticBody3D
	if not _check(signs[0].get_parent() == mount and (signs[0] as Label3D).billboard == BaseMaterial3D.BILLBOARD_DISABLED,"single physical sign remains fixed to the actual stern safety rail"): return false
	for part in ["SignPost","SignBacking"]:
		var solid := mount.get_node(part+"Collision") as CollisionShape3D
		var visual := mount.get_node(part) as MeshInstance3D
		if not _check(solid.transform == visual.transform and (solid.shape as BoxShape3D).size == (visual.mesh as BoxMesh).size,"mounted sign backing/post rendered and solid geometry agree "+part): return false
	# Live 2.4-metre standing volume checks cover the whole new supported route,
	# both turns and operator apron, against the real station and old fleet.
	for i in range(17,ROUTE.size()-1):
		var first: Vector3 = ROUTE[i]
		var last: Vector3 = ROUTE[i+1]
		var direction := (last-first).slide(Vector3.UP)
		var pose := Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP),(first+last)*0.5+Vector3.UP*1.151)
		var clear := BoxShape3D.new()
		clear.size = Vector3(2.4,2.3,direction.length())
		if not _query_clear(clear,pose,Vector3.ZERO,[_player.get_rid()],0,"actual2.4m-wide supported new approach headroom leg="+str(i)): return false
	return true


func _test_leases(berth: ShipBerth) -> bool:
	var before := berth.audit()
	if not _check(not berth.can_accept(WRONG,_player) and berth.try_reserve(_player,WRONG).is_empty() and berth.audit() == before,"wrong-tag refusal preserves real empty berth atomically"): return false
	var token := berth.try_reserve(_ship,DEFINITION)
	if not _check(not token.is_empty() and berth.try_reserve(_ship,DEFINITION) == token and berth.occupy(_ship,token) and berth.occupy(_ship,token) and berth.get_occupant() == _ship,"real compatible lease reserves/occupies exclusively and idempotently"): return false
	before = berth.audit()
	if not _check(not berth.can_accept(DEFINITION,_player) and berth.try_reserve(_player,DEFINITION).is_empty() and not berth.occupy(_player,token) and not berth.release(_player,token) and not berth.release(_ship,&"stale") and berth.audit() == before and berth.has_valid_lease(_ship,token,DEFINITION.ship_id),"occupied/foreign/stale real berth refusals preserve rightful lease atomically"): return false
	if not _check(berth.release(_ship,token) and not berth.release(_ship,token) and berth.get_occupant() == null and berth.get_reservation_owner() == null,"correct release clears real berth exactly once"): return false
	var fresh := berth.try_reserve(_ship,DEFINITION)
	before = berth.audit()
	if not _check(not fresh.is_empty() and fresh != token and not berth.occupy(_ship,token) and not berth.release(_ship,token) and not berth.has_valid_lease(_ship,token,DEFINITION.ship_id) and berth.audit() == before and berth.has_valid_lease(_ship,fresh,DEFINITION.ship_id),"old token cannot touch fresh reused real berth lease"): return false
	return _check(berth.occupy(_ship,fresh) and berth.release(_ship,fresh),"fresh lease occupies and releases normally")


func _test_clearance(module: UtopiaDropshipBerth, deployed: bool) -> bool:
	var support := module.get_node("BerthDeck") as StaticBody3D
	var exclude: Array[RID] = [_ship.get_rid(),support.get_rid()]
	# Departure is full4m lift,20m forward and4m staging rise. Reverse
	# casts prove return/approach/descent; the high staging-to-home alignment
	# and complete8m vertical approach also remain clear in both directions.
	var legs := [
		[Vector3.ZERO,Vector3(0,4,0)],
		[Vector3(0,4,0),Vector3(0,4,-20)],
		[Vector3(0,4,-20),Vector3(0,8,-20)],
		[Vector3(0,8,-20),Vector3(0,8,0)],
		[Vector3(0,8,0),Vector3.ZERO],
	]
	for child in _ship.get_children():
		if not child is CollisionShape3D: continue
		var collision := child as CollisionShape3D
		if collision.disabled: continue
		for leg in legs:
			var first: Vector3 = leg[0]
			var last: Vector3 = leg[1]
			var start := collision.global_transform
			start.origin += _ship.global_basis * first
			var motion := _ship.global_basis * (last-first)
			var label := "actual hull/access continuous sweep deployed=%s shape=%s from=%s to=%s" % [deployed,collision.name,first,last]
			if not _query_clear(collision.shape,start,motion,exclude,0,label): return false
			start.origin += motion
			if not _query_clear(collision.shape,start,-motion,exclude,0,label+" reverse"): return false
	return _test_camera_clearance(legs,deployed)


func _test_camera_clearance(legs: Array, deployed: bool) -> bool:
	var arm := _ship.get_node("CameraRig/CameraCollisionArm") as SpringArm3D
	var camera := _ship.get_camera()
	var exclude: Array[RID] = [_ship.get_rid()]
	for point in [Vector3.ZERO,Vector3(0,4,0),Vector3(0,4,-20),Vector3(0,8,-20),Vector3(0,8,0)]:
		var pose := arm.global_transform
		pose.origin += _ship.global_basis * point
		if not _query_clear(arm.shape,pose,arm.global_basis.z*arm.spring_length,exclude,arm.margin,"actual full chase spring arm deployed=%s at=%s" % [deployed,point]): return false
	for leg in legs:
		var first: Vector3 = leg[0]
		var last: Vector3 = leg[1]
		var pose := camera.global_transform
		pose.origin += _ship.global_basis * first
		var motion := _ship.global_basis * (last-first)
		if not _query_clear(arm.shape,pose,motion,exclude,arm.margin,"actual chase-camera sphere complete departure/approach sweep deployed=%s from=%s to=%s" % [deployed,first,last]): return false
		pose.origin += motion
		if not _query_clear(arm.shape,pose,-motion,exclude,arm.margin,"actual chase-camera sphere reverse sweep deployed=%s from=%s to=%s" % [deployed,last,first]): return false
	return _check(_ship.get_chase_camera_self_hull_boundary_report().valid,"actual default chase camera near plane clears its own closed/deployed hull")


func _query_clear(shape: Shape3D, pose: Transform3D, motion: Vector3, exclude: Array[RID], margin: float, label: String) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.motion = Vector3.ZERO
	query.margin = margin
	query.exclude = exclude
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	var state := _player.get_world_3d().direct_space_state
	var initial := state.intersect_shape(query,64)
	query.motion = motion
	var cast := state.cast_motion(query)
	query.transform.origin += motion
	query.motion = Vector3.ZERO
	var ending := state.intersect_shape(query,64)
	return _check(initial.is_empty() and ending.is_empty() and cast[0] == 1.0 and cast[1] == 1.0,label+" initial="+str(initial)+" cast="+str(cast)+" ending="+str(ending))


func _walk_to(target: Vector3, leg: int) -> bool:
	var reached := false
	for tick in 900:
		if _failed: return false
		var offset := target-_player.global_position
		offset.y = 0
		if absf(offset.x) < 0.02: offset.x = 0
		if absf(offset.z) < 0.02: offset.z = 0
		if offset.length() <= 0.035:
			reached = true
			break
		var direction := (_player.get_node("%CameraYaw") as Node3D).global_basis.inverse()*offset.normalized()
		_release_inputs()
		var strength := 0.4 if offset.length() < 0.8 else 1.0
		Input.action_press(&"move_right" if direction.x > 0 else &"move_left",absf(direction.x)*strength)
		Input.action_press(&"move_back" if direction.z > 0 else &"move_forward",absf(direction.z)*strength)
		await _observer.completed_tick
	_release_inputs()
	for tick in 12:
		await _observer.completed_tick
		if _failed: return false
	print("UTOPIA_BERTH_ROUTE_LEG: ",{"leg":leg,"target":target,"actual":_player.global_position,"reached":reached})
	if not reached:
		print("UTOPIA_BERTH_ROUTE_FAILURE: ",{"position":_player.global_position,"velocity":_player.velocity,"floor":_player.is_on_floor(),"audit":_player.get_step_up_assist_audit()})
	return _check(reached,"ordinary complete route reaches frozen endpoint "+str(leg))


func _observe_completed_tick() -> void:
	if not _active or _failed: return
	var current := Engine.get_physics_frames()
	var completed: Dictionary = _player.get_step_up_assist_audit().get("completed_motion",{})
	var point := _player.global_position
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var original := collision.shape as CapsuleShape3D
	if not _check(int(completed.get("frame",-1)) == current and _observer.process_physics_priority > _player.process_physics_priority and (_last_frame < 0 or current == _last_frame+1) and (not _last_point.is_finite() or point.distance_to(_last_point) < 0.2),"adjacent completed actual Player physical tick and <.2m continuity",false): return
	if not _check(_player.collision_layer == _body_layer and _player.collision_mask == _body_mask and is_equal_approx(_player.gravity_multiplier,_gravity) and Vector2(original.radius,original.height) == _capsule_size and collision.transform == _capsule_pose and not collision.disabled,"walking body retains exact actual capsule/pose/masks/gravity",false): return
	var capsule := original.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = _body_mask
	query.exclude = [_player.get_rid()]
	var state := _player.get_world_3d().direct_space_state
	var hits := state.intersect_shape(query,32)
	var support := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.12,point-Vector3.UP*0.18,_body_mask)
	support.exclude = [_player.get_rid()]
	var floor_hit := state.intersect_ray(support)
	if not _check(_player.is_on_floor() and hits.is_empty() and not floor_hit.is_empty() and (floor_hit.normal as Vector3).dot(Vector3.UP) >= cos(_player.floor_max_angle),"every completed actual Player tick has capsule/head clearance and physical floor support at="+str(point)+" overlaps="+str(hits)+" support="+str(floor_hit),false): return
	_last_frame = current
	_last_point = point
	_samples += 1
	if Time.get_ticks_msec()-_started > 240000: _check(false,"complete new berth fixture exceeds unchanged240s cap")


func _release_inputs() -> void:
	for action in [&"move_forward",&"move_back",&"move_left",&"move_right",&"sprint_boost",&"jump",&"interact"]:
		Input.action_release(action)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String, verbose: bool = true) -> bool:
	_checks += 1
	if not condition:
		_failed = true
		_release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("UTOPIA_DROPSHIP_BERTH_TEST_FAIL: ",message)
		quit(1)
	elif verbose:
		print("PASS: ",message)
	return condition
