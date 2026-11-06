extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const DEFINITION := preload("res://assets/ships/predator_provisional.tres")
const WRONG := preload("res://assets/ships/torrent_provisional.tres")
const OLD_TRANSFORMS := preload("res://tests/station_route_registry_integration_test.gd").EXPECTED_BERTH_TRANSFORMS
const TITAN_POSE := Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(154,0.38,38))
# Frozen before traversal. Only ordinary input moves the one production Player.
const ROUTE := [
	Vector3(8,0,11), Vector3(8,0,13.5), Vector3(35,0,13.5),
	Vector3(35,0,15.5), Vector3(39,0,15.5), Vector3(39,0,8.5),
	Vector3(39,0,7), Vector3(39,0,-17), Vector3(39,0,-17.9),
	Vector3(42.2,0,-17.9), Vector3(42.2,0,-21.2),
]
var _failed := false
var _frames := 0
var _supported := 0
var _clear := 0
var _active := false
var _player: PlayerController
var _observer: CompletedPlayerTick
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
	call_deferred("_run")

func _run() -> void:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	_player = game.get_node("Player") as PlayerController
	_player.set_camera_active(false)
	await _wait_frames(10)
	var spawn := _player.global_position
	_check(spawn.distance_to(world.get_player_spawn().origin)<0.25 and _player.is_on_floor(), "same Main Player begins at supported normal production spawn")
	var module := world.get_node("PredatorDetentionTransportBerth") as PredatorDetentionTransportBerth
	var berth := world.get_berth_node(&"predator_home_berth")
	_check(berth != null and berth == module.get_node("ShipBerth") and module.get_validation_errors().is_empty(), "production discovery finds valid signed physical Predator berth")
	var matching := 0
	for candidate in get_nodes_in_group(ShipBerth.GROUP):
		if candidate.get_berth_id() == &"predator_home_berth": matching += 1
	_check(matching == 1 and world.get_berth_ids().size()==11 and game.get_flyable_ships().size()==11, "eleven physical berths and eleven registered flyable craft")
	var original_berths := OLD_TRANSFORMS.duplicate()
	original_berths[&"titan_home_berth"] = TITAN_POSE
	var old_leases := {}
	var old_poses := {}
	for id: StringName in original_berths:
		var old := world.get_berth_node(id)
		var owner := old.get_reservation_owner()
		_check(world.get_berth_transform(id).is_equal_approx(original_berths[id]), "preserved old berth transform "+str(id))
		old_leases[id] = [owner,old.get_occupant(),old.get_reservation_token(owner),old.get_reserved_ship_id()]
	for craft in game.get_flyable_ships(): old_poses[craft] = craft.global_transform
	_check(berth.get_dock_transform().is_equal_approx(Transform3D(Basis.IDENTITY,Vector3(39,-0.02,-30)))
		and berth.dock_transform==Transform3D.IDENTITY and berth.compatibility_tags==PackedStringArray(["predator_transport"])
		and berth.landing_volume_center==Vector3(0,2.5,1.5) and berth.landing_half_extents==Vector3(5.5,4,11.5)
		and berth.assist_capture_center==Vector3(0,8,-18) and berth.assist_capture_half_extents==Vector3(24,16,36)
		and berth.assist_capture_maximum_speed==32 and berth.assist_maximum_tilt_degrees==75
		and berth.departure_lift_height==5 and DEFINITION.landing_maximum_speed==11, "exact frozen strict/capture/root/speed/lift contract")
	var registry := world.get_station_route_registry_report()
	var graph := world.get_station_navigation_graph_report()
	var edge := (graph.get("edges",{}) as Dictionary).get(&"hub-predator-detention-berth",{}) as Dictionary
	_check(registry.valid and registry.modules.size()==9 and registry.route_marker_count==57
		and registry.hub_endpoints.size()==9 and registry.slots.size()==9
		and graph.valid and is_equal_approx(float(edge.get("length",-1)),1.5)
		and edge.get("hub_node_id")==&"station-hub:hub-predator-detention-berth"
		and edge.get("module_node_id")==&"predator-detention-berth:approach", "complete nine-module/57-marker supported 1.5m navigation edge")
	_check(world.get_ship_berth_feedback_audit_report().valid, "existing six feedback owners remain valid with eleventh berth")
	var ship := game.get_node("PredatorDetentionTransport") as HeroShip
	_check(game.get_flyable_ships().has(ship) and berth.get_occupant()==ship and berth.get_reservation_owner()==ship, "actual registered production pilot craft owns its existing occupied lease")
	_check(berth.contains_oriented_bounds(ship.global_transform,ship.get_landing_collision_report().local_bounds), "complete closed actual Predator fits exact strict volume")
	_check(world.is_landing_position_for_berth(berth.to_global(Vector3(0,6,12)),&"predator_home_berth")
		and not world.is_landing_position_for_berth(berth.to_global(Vector3(0,-2,0)),&"predator_home_berth"), "world direct strict query honors offset volume")
	var occupied_before := berth.audit()
	var live_token := berth.get_reservation_token(ship)
	_check(berth.try_reserve(ship,DEFINITION)==live_token and berth.occupy(ship,live_token)
		and not berth.occupy(_player,live_token) and not berth.release(_player,live_token)
		and not berth.release(ship,&"stale") and berth.try_reserve(_player,DEFINITION).is_empty()
		and berth.audit()==occupied_before,"actual occupied lease idempotency and foreign/stale refusals preserve exact rightful claim")
	var ledger := ShipBerth.new()
	ledger.berth_id = &"predator_independent_lease_fixture"
	ledger.compatibility_tags = berth.compatibility_tags.duplicate()
	ledger.dock_transform = berth.dock_transform
	ledger.landing_volume_center = berth.landing_volume_center
	ledger.landing_half_extents = berth.landing_half_extents
	ledger.assist_capture_center = berth.assist_capture_center
	ledger.assist_capture_half_extents = berth.assist_capture_half_extents
	ledger.assist_capture_maximum_speed = berth.assist_capture_maximum_speed
	ledger.assist_maximum_tilt_degrees = berth.assist_maximum_tilt_degrees
	ledger.departure_lift_height = berth.departure_lift_height
	root.add_child(ledger)
	_test_leases(ledger,ship,_player)
	ledger.free()
	_check(berth.audit()==occupied_before,"independent empty-ledger cases never release production lease")
	var bounds: AABB = ship.get_landing_collision_report().local_bounds
	_check(berth.evaluate_assist_capture_candidate(berth.get_assist_staging_transform(),bounds,Vector3.ZERO,11).valid
		and berth.get_departure_lift_for(ship.global_position).height==5, "real closed hull captures with original defaults and exact departure owner")
	await _test_clearance(ship,module,false)
	ship.set_canopy_open(true,0)
	await _wait_frames(3)
	_check(ship.is_canopy_open() and berth.contains_oriented_bounds(ship.global_transform,ship.get_landing_collision_report().local_bounds), "real deployed access fits exact strict volume")
	await _test_clearance(ship,module,true)
	ship.set_canopy_open(false,0)
	await _wait_frames(3)
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	_body_layer=_player.collision_layer
	_body_mask=_player.collision_mask
	_gravity=_player.gravity_multiplier
	_capsule_size=Vector2(capsule.radius,capsule.height)
	_capsule_pose=collision.transform
	_observer=CompletedPlayerTick.new()
	_observer.name="CompletedPlayerPhysicsObserver"
	_observer.process_physics_priority=_player.process_physics_priority+1
	_observer.observe=_observe_completed_player_tick
	root.add_child(_observer)
	_active=true
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index],index): return
	var local := ship.to_local(_player.global_position)
	var hatch := ship.get_node("PredatorOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	_check(Vector2(local.x-3.2,local.z-8.8).length()<0.08 and absf(local.y)<0.03
		and local.x>2.2 and hatch.is_available()
		and _player.get_interaction_origin().distance_to(hatch.global_position)<ShipCabinHatch.MAX_REACH,
		"same Player reaches supported endpoint outside entire ramp sweep at normal hatch reach")
	_check(hatch.interact(_player), "physically reached existing hatch API accepts opening")
	await _wait_frames(25)
	_check(ship.is_canopy_open(),"reached hatch physically opens access")
	_check(hatch.interact(_player),"same reached existing hatch API accepts sealing")
	await _wait_frames(25)
	_check(not ship.is_canopy_open(),"reached hatch physically seals access")
	for index in range(ROUTE.size()-2,-1,-1):
		if not await _walk_to(ROUTE[index],ROUTE.size()+index): return
	if not await _walk_to(spawn,99): return
	_active=false
	_check(_frames>1000 and _supported==_frames and _clear==_frames, "every completed tick supported/current/adjacent/capsule-clear with unchanged body and continuous movement; ticks="+str(_frames))
	for id: StringName in original_berths:
		var old := world.get_berth_node(id)
		var owner := old.get_reservation_owner()
		_check(world.get_berth_transform(id).is_equal_approx(original_berths[id]) and old_leases[id]==[owner,old.get_occupant(),old.get_reservation_token(owner),old.get_reserved_ship_id()],"all old berth poses and leases preserved after walk/control/return "+str(id))
	for craft: HeroShip in old_poses: _check(craft.global_transform.is_equal_approx(old_poses[craft]),"old craft pose preserved "+str(craft.name))
	print("PREDATOR_MODULE_BUDGET: ",module.get_performance_contract())
	_release_inputs()
	_observer.queue_free()
	game.queue_free()
	await _wait_frames(3)
	if not _failed:
		print("PREDATOR_DETENTION_TRANSPORT_BERTH_TEST_PASS")
		quit(0)

func _test_leases(berth: ShipBerth, owner: Node, foreign: Node) -> void:
	var before := berth.audit()
	_check(not berth.can_accept(WRONG,owner) and berth.try_reserve(owner,WRONG).is_empty() and berth.audit()==before,"wrong-tag refusal is atomic")
	var token := berth.try_reserve(owner,DEFINITION)
	_check(not token.is_empty() and berth.try_reserve(owner,DEFINITION)==token and berth.occupy(owner,token) and berth.occupy(owner,token),"legitimate reservation and duplicate occupancy are idempotent")
	before=berth.audit()
	_check(not berth.can_accept(DEFINITION,foreign) and berth.try_reserve(foreign,DEFINITION).is_empty()
		and not berth.occupy(foreign,token) and not berth.release(foreign,token)
		and not berth.release(owner,&"stale") and berth.audit()==before,"occupied/foreign/stale lease refusals preserve rightful claim atomically")
	_check(berth.release(owner,token) and not berth.release(owner,token),"legitimate release succeeds exactly once")
	var renewed := berth.try_reserve(owner,DEFINITION)
	_check(not renewed.is_empty() and renewed!=token and not berth.has_valid_lease(owner,token,DEFINITION.ship_id)
		and not berth.occupy(owner,token) and not berth.release(owner,token)
		and berth.has_valid_lease(owner,renewed,DEFINITION.ship_id) and berth.release(owner,renewed),"release/reuse gives fresh authority and refuses old token")

func _walk_to(target: Vector3,index: int) -> bool:
	var reached := false
	for frame in 900:
		if _failed: return false
		var offset := target-_player.global_position
		offset.y=0
		if absf(offset.x)<0.02: offset.x=0
		if absf(offset.z)<0.02: offset.z=0
		if offset.length()<=0.035:
			reached=true
			break
		var direction := (_player.get_node("%CameraYaw") as Node3D).global_basis.inverse()*offset.normalized()
		_release_inputs()
		var axis := Vector2(direction.x,direction.z)*(0.4 if offset.length()<0.8 else 1.0)
		Input.action_press(&"move_right" if axis.x>0 else &"move_left",absf(axis.x))
		Input.action_press(&"move_back" if axis.y>0 else &"move_forward",absf(axis.y))
		await _observer.completed_tick
	_release_inputs()
	for frame in 12: await _observer.completed_tick
	print("PREDATOR_ROUTE_LEG: ",index," target=",target," actual=",_player.global_position," reached=",reached)
	_check(reached,"unchanged 0.035m/900tick/12braking route leg "+str(index))
	return reached and not _failed

func _observe_completed_player_tick() -> void:
	if not _active or _failed: return
	var frame := Engine.get_physics_frames()
	var completed: Dictionary = _player.get_step_up_assist_audit().get("completed_motion",{})
	var point := _player.global_position
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var original := collision.shape as CapsuleShape3D
	var valid := _observer.process_physics_priority>_player.process_physics_priority and int(completed.get("frame",-1))==frame
	valid=valid and (_last_frame<0 or frame==_last_frame+1) and (not _last_point.is_finite() or point.distance_to(_last_point)<0.2)
	valid=valid and _player.collision_layer==_body_layer and _player.collision_mask==_body_mask and is_equal_approx(_player.gravity_multiplier,_gravity)
	valid=valid and Vector2(original.radius,original.height)==_capsule_size and collision.transform==_capsule_pose
	if not valid: print("PREDATOR_TICK_OPERANDS: ",{"frame":frame,"previous":_last_frame,"completed":completed,"point":point,"previous_point":_last_point,"velocity":_player.velocity})
	if not valid: _check(false,"completed actual Player tick stays current/adjacent/continuous and body unchanged")
	_last_frame=frame
	_last_point=point
	_frames+=1
	if _player.is_on_floor(): _supported+=1
	var capsule := original.duplicate() as CapsuleShape3D
	capsule.radius-=0.005
	capsule.height-=0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.transform=collision.global_transform
	query.margin=0
	query.collision_mask=PhysicsLayers.WORLD|PhysicsLayers.SHIP
	query.exclude=[_player.get_rid()]
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(query,16)
	if hits.is_empty(): _clear+=1
	if not _player.is_on_floor() or not hits.is_empty(): print("PREDATOR_SUPPORT_OPERANDS: point=",point," floor=",_player.is_on_floor()," hits=",hits)
	if not _player.is_on_floor() or not hits.is_empty(): _check(false,"completed actual Player capsule/head clear and supported")

func _test_clearance(ship: HeroShip, module: PredatorDetentionTransportBerth, deployed: bool) -> void:
	var failures: Array[String] = []
	var continuous_clear := true
	# Use every actual enabled hull/access shape, including hatch/roof slot and
	# both ramp leaves. The allowed contact deck is excluded only as support;
	# all other live station geometry and all original ten craft stay queried.
	var support := module.get_node("BerthDeck") as StaticBody3D
	for height_index in 21:
		var lift := float(height_index) * 0.25
		for candidate in ship.find_children("*", "CollisionShape3D", true, false):
			var collision := candidate as CollisionShape3D
			if collision.disabled: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collision.shape
			query.transform = collision.global_transform
			query.transform.origin += Vector3.UP * lift
			query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
			query.margin = 0
			query.exclude = [ship.get_rid(), support.get_rid()]
			if height_index == 0:
				query.motion = Vector3.UP * 5
				var fractions := ship.get_world_3d().direct_space_state.cast_motion(query)
				if fractions[0] != 1.0 or fractions[1] != 1.0: print("PREDATOR_VERTICAL_CAST: shape=",collision.get_path()," pose=",query.transform," motion=",query.motion," fractions=",fractions)
				continuous_clear = continuous_clear and fractions[0] == 1.0 and fractions[1] == 1.0
				query.transform.origin += Vector3.UP * 5
				query.motion = Vector3.DOWN * 5
				var inverse := ship.get_world_3d().direct_space_state.cast_motion(query)
				if inverse[0] != 1.0 or inverse[1] != 1.0: print("PREDATOR_INVERSE_CAST: shape=",collision.get_path()," pose=",query.transform," motion=",query.motion," fractions=",inverse)
				continuous_clear = continuous_clear and inverse[0] == 1.0 and inverse[1] == 1.0
				query.motion = -ship.global_basis.z * 54
				var forward := ship.get_world_3d().direct_space_state.cast_motion(query)
				if forward[0] != 1.0 or forward[1] != 1.0: print("PREDATOR_FORWARD_CAST: shape=",collision.get_path()," pose=",query.transform," motion=",query.motion," fractions=",forward)
				continuous_clear = continuous_clear and forward[0] == 1.0 and forward[1] == 1.0
				query.transform.origin -= Vector3.UP * 5
				query.motion = Vector3.ZERO
			for hit in ship.get_world_3d().direct_space_state.intersect_shape(query, 32):
				failures.append("lift=%.2f shape=%s neighbor=%s" % [lift, ship.get_path_to(collision), hit.collider.get_path()])
	_check(failures.is_empty() and continuous_clear, "complete %s actual hull/access shapes, full 5m vertical/inverse and 54m forward sweeps clear live neighbors: %s" % ["deployed" if deployed else "closed", failures])
	# Actual clear elevated flight lane starts after the required 5m lift and
	# extends to the front edge of the configured broad acquisition box.
	_check(_box_clear(ship, Transform3D(ship.global_basis, ship.to_global(Vector3(0, 7.5, -25.5))), Vector3(9, 4.99, 73), [ship.get_rid()]),
		"complete-width elevated approach/departure lane clears live neighboring geometry")
	_check(_box_clear(ship, Transform3D(ship.global_basis, ship.to_global(Vector3(0, 2, 25))), Vector3(2.5, 2, 23), [ship.get_rid()]),
		"stern on-foot approach headroom clears station neighbors")
	_test_actual_chase_camera(ship)

func _box_clear(ship: HeroShip, pose: Transform3D, size: Vector3, excluded: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	query.shape = shape
	query.transform = pose
	query.margin = 0
	query.exclude = excluded
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	var hits := ship.get_world_3d().direct_space_state.intersect_shape(query, 32)
	if not hits.is_empty(): print("PREDATOR_CLEARANCE_HITS: ", hits)
	return hits.is_empty()

func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
func _wait_frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func _check(condition: bool, message: String) -> void:
	if _failed: return
	if condition: print("PASS: ", message)
	else:
		_failed = true
		_release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("FAIL: ", message)
		quit(1)


func _test_actual_chase_camera(ship: HeroShip) -> void:
	var arm := ship.get_node("CameraRig/CameraCollisionArm") as SpringArm3D
	var camera := ship.get_camera()
	var clear := true
	for lift in [0.0, 5.0]:
		var sweep := PhysicsShapeQueryParameters3D.new()
		sweep.shape = arm.shape
		sweep.transform = arm.global_transform
		sweep.transform.origin += Vector3.UP * lift
		sweep.motion = arm.global_basis.z * arm.spring_length
		sweep.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		sweep.exclude = [ship.get_rid()]
		sweep.margin = arm.margin
		var fractions := ship.get_world_3d().direct_space_state.cast_motion(sweep)
		clear = clear and fractions[0] == 1.0 and fractions[1] == 1.0
		sweep.transform = camera.global_transform
		sweep.transform.origin += Vector3.UP * lift
		sweep.motion = Vector3.ZERO
		clear = clear and ship.get_world_3d().direct_space_state.intersect_shape(sweep).is_empty()
		if lift == 5.0:
			sweep.motion = -ship.global_basis.z * 54
			var lane := ship.get_world_3d().direct_space_state.cast_motion(sweep)
			if lane[0] != 1.0 or lane[1] != 1.0: print("PREDATOR_CAMERA_LANE_CAST: ",sweep.transform," motion=",sweep.motion," fractions=",lane)
			clear = clear and lane[0] == 1.0 and lane[1] == 1.0
		if lift == 0.0:
			sweep.motion = Vector3.UP * 5
			var departure := ship.get_world_3d().direct_space_state.cast_motion(sweep)
			clear = clear and departure[0] == 1.0 and departure[1] == 1.0
	print("PREDATOR_ACTUAL_CAMERA: local=", ship.to_local(camera.global_position), " arm=", arm.spring_length, " shape=", (arm.shape as SphereShape3D).radius, " clear=", clear)
	_check(clear and ship.get_chase_camera_self_hull_boundary_report().valid,
		"actual default inherited chase-camera sphere/arm and near plane clear live neighbors and own hull at berth and full5m lift")
