extends SceneTree

const ROUTE := preload("res://tests/predator_detention_transport_berth_test.gd").ROUTE
const OLD_TRANSFORMS := preload("res://tests/station_route_registry_integration_test.gd").EXPECTED_BERTH_TRANSFORMS
var _failed := false
var _frames := 0
var _supported := 0
var _clear := 0
var _active := false
var _player: PlayerController
var _ship: HeroShip
var _game: GameFlow
var _observer: CompletedPlayerTick
var _last_frame := -1
var _last_point := Vector3.INF
var _body_layer := 0
var _body_mask := 0
var _gravity := 0.0
var _capsule_size := Vector2.ZERO
var _capsule_pose := Transform3D.IDENTITY
var _engine_edges: Array[Dictionary] = []
var _shots := 0
var _projectiles := 0

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
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate() as StartupLoader
	root.add_child(boot)
	_game = await boot.startup_completed as GameFlow
	await _wait_frames(3)
	if not _check(StartupLoader.is_title_menu_ready(_game),"ordinary Boot reaches Begin Shift"): return
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_X
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _wait_frames(2)
	await _wait_frames(45)
	_player = _game.player
	_ship = _game.get_node("PredatorDetentionTransport") as HeroShip
	_ship.engine_state_changed.connect(_on_engine_edge)
	_ship.projectile_fired.connect(func(_o: Vector3,_d: Vector3): _projectiles += 1)
	_game.get_combat_authority().authoritative_shot_submitted.connect(func(request: Variant,_result: Dictionary):
		if request.source_entity==_ship: _shots += 1)
	var identity := _player.get_instance_id()
	var world := _game.world
	var berth := world.get_berth_node(&"predator_home_berth") as ShipBerth
	var dock := berth.get_dock_transform()
	if not _check(_game.phase == GameFlow.Phase.APPROACH_SHIP and _player.is_control_enabled()
		and _player.global_position.distance_to(world.get_player_spawn().origin)<0.25
		and _game.get_flyable_ships().size()==11 and berth.get_occupant()==_ship
		and berth.get_reservation_owner()==_ship,"actual normal Main spawn and eleventh production craft with occupied own home"): return
	var sources := {}
	var poses := {}
	var leases := {}
	var settings := {}
	var unique := {}
	for craft: HeroShip in _game.get_flyable_ships():
		if not _check(not unique.has(craft.get_ship_id()),"unique production ship identity "+str(craft.get_ship_id())): return
		unique[craft.get_ship_id()] = true
		if craft == _ship: continue
		poses[craft] = craft.global_transform
		sources[craft] = _game.get_combat_authority().get_source_id(craft)
		settings[craft] = [craft.mouse_sensitivity,craft.invert_mouse_y,craft.get_camera().fov,craft.maximum_chase_camera_rotation_lag_degrees]
		var home := world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		if home != null: leases[home] = home.audit()
	for id in OLD_TRANSFORMS:
		if not _check(world.get_berth_transform(id).is_equal_approx(OLD_TRANSFORMS[id]),"old berth transform "+str(id)): return
	var roster := _game._build_fleet_registry_snapshot()
	if not _check(roster.rows.size()==11 and (_ship.get_node("AuthoritativeDamageable") as LifecycleDamageableAdapter).get_target_entity()==_ship,"actual registry console roster includes11 and unarmed craft remains damageable"): return
	var area := _ship.get_node("ShipBoardingArea") as ShipBoardingArea
	var before_generation := _game._transition_generation
	_game._board_ship(_ship)
	if not _check(not area.is_reserved() and not _game._transition_busy
		and _game._transition_generation==before_generation,"outside/through-wall direct board refuses before reservation/generation"): return
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	_body_layer = _player.collision_layer
	_body_mask = _player.collision_mask
	_gravity = _player.gravity_multiplier
	_capsule_size = Vector2(capsule.radius,capsule.height)
	_capsule_pose = collision.transform
	_observer = CompletedPlayerTick.new()
	_observer.process_physics_priority = 1000
	_observer.observe = _observe_completed_player_tick
	root.add_child(_observer)
	_active = true
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index],index): return
	for sortie in 2:
		if not await _board_from_stern(sortie,identity,area): return
		if not await _sortie_home(sortie,identity,area,berth,dock): return
		if not await _walk_out(sortie): return
	if not _check(_frames>1000 and _supported==_frames and _clear==_frames,
		"all completed walking physics ticks current/adjacent/continuous/supported/capsule/head-clear: "+str(_frames)): return
	for craft: HeroShip in poses:
		if not _check(craft.global_transform.is_equal_approx(poses[craft])
			and _game.get_combat_authority().get_source_id(craft)==sources[craft]
			and [craft.mouse_sensitivity,craft.invert_mouse_y,craft.get_camera().fov,craft.maximum_chase_camera_rotation_lag_degrees]==settings[craft],"old craft pose/source/settings preserved "+str(craft.name)): return
	for home: ShipBerth in leases:
		if not _check(home.audit()==leases[home],"old occupied lease immutable "+str(home.get_berth_id())): return
	if not _check(_player.get_instance_id()==identity and unique.size()==11
		and _game.get_flyable_ships().size()==11 and not area.is_reserved()
		and not _ship.is_canopy_open(),"same Player finishes second complete sortie outside sealed unique real craft"): return
	await _quit_normally()

func _board_from_stern(sortie: int,identity: int,area: ShipBoardingArea) -> bool:
	var hatch := _ship.get_node("PredatorOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	await _aim(hatch.global_position)
	if not _check(_game.station_interaction_candidate==hatch,"normal look discovers real reachable stern control"): return false
	await _tap(&"interact")
	# While access is moving/open the normal start API must remain inert.
	_ship.request_engine_start()
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE,"moving hatch refuses engine start"): return false
	await _wait_frames(30)
	_ship.request_engine_start()
	if not _check(_ship.is_canopy_open() and StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE,"open hatch refuses engine start"): return false
	var generation := _game._transition_generation
	_game._board_ship(_ship)
	if not _check(not area.is_reserved() and _game._transition_generation==generation,"open but outside helm approach still refuses claim"): return false
	# Main's finite apron has a stern rail at z13.04 outside x+/-1.4.
	# Cross behind the deployed leaves at the authored stern-apron z12.1,
	# then retain the accepted x1/z13 endpoint through the connector opening.
	for point in [Vector3(3.2,0,12.1),Vector3(1,0,12.1),Vector3(1,0,13),Vector3(1,0,11),Vector3(1,0.5,9),Vector3(1,1,7),Vector3(1,1,6),Vector3(1,1,0),Vector3(1,1,-5.5)]:
		if not await _walk_to(_ship.to_global(point),30+sortie,true): return false
	if not _check(_ship.can_board_from_landed_approach(_player),"full normal Player physically reaches supported helm"): return false
	if not _check(area.try_reserve(_game) and area.try_reserve(_game) and not area.try_reserve(_player)
		and not area.release_reservation(_player) and area.get_reservation_token()==_game,
		"foreign and duplicate reservation requests preserve actual owner"): return false
	await _tap(&"interact")
	if not _check(not _game._piloting and area.get_reservation_token()==_game,"foreign held helm refuses ordinary Interact atomically"): return false
	if not _check(area.release_reservation(_game) and not area.release_reservation(_game),"reservation retires once and stale release refuses"): return false
	await _aim(_ship.get_pilot_seat_anchor().global_position)
	await _tap(&"interact")
	for frame in 240:
		if _game._piloting and not _game._transition_busy: break
		await _wait_frames(1)
	if not _check(_game.active_ship==_ship and _game._piloting and not _game._transition_busy
		and _player.is_seated_at(_ship.get_pilot_seat_anchor()) and area.get_reservation_token()==_player
		and _player.get_instance_id()==identity and not _ship.is_canopy_open()
		and _ship.get_camera().current and not _ship.has_node("MovingInteriorFrame"),
		"normal Interact boards exact production seat/camera/claim and seals hatch sortie="+str(sortie)): return false
	generation = _game._transition_generation
	_game._board_ship(_ship)
	if not _check(_game._transition_generation==generation and area.get_reservation_token()==_player,
		"duplicate seated boarding cannot replace current transaction"): return false
	var body := _player.get_node("PlayerCollision") as CollisionShape3D
	var seated_capsule := body.shape.duplicate() as CapsuleShape3D
	seated_capsule.radius -= 0.005
	seated_capsule.height -= 0.01
	var seated_query := PhysicsShapeQueryParameters3D.new()
	seated_query.shape = seated_capsule
	seated_query.transform = body.global_transform
	seated_query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	seated_query.exclude = [_player.get_rid()]
	seated_query.margin = 0
	if not _check(_ship.get_world_3d().direct_space_state.intersect_shape(seated_query,16).is_empty(),
		"actual seated full Player capsule/head clears actual production shell and pilot chair"): return false
	for pair in [["PilotSeat","PilotSeatCollision"],["PilotBack","PilotBackCollision"]]:
		var mesh := _ship.get_node(pair[0]) as MeshInstance3D
		var solid := _ship.get_node(pair[1]) as CollisionShape3D
		var size := (solid.shape as BoxShape3D).size
		if not _check((mesh.mesh as BoxMesh).size==size and mesh.transform==solid.transform
			and solid.position.x+size.x*0.5<=0.2+0.000001 and not solid.disabled,
			"actual pilot furniture visual/solid match outside clear aisle "+str(pair[0])): return false
	var hud: Dictionary = _game.hud.get_weapon_heat_component_hud_snapshot()
	var cockpit := _ship.get_node("PredatorOriginalShell/PilotFixture/CockpitCamera") as Camera3D
	var eye := SphereShape3D.new()
	eye.radius = 0.08
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = eye
	query.transform = cockpit.global_transform
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	if not _check(_ship.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
		and _game.hud._active_ship_name==_ship.get_display_name().to_upper()
		and _game.hud._active_ship_role=="DETENTION TRANSPORT"
		and hud.readiness=="UNARMED" and "UNARMED" in hud.label_text
		and "UNARMED" in _ship._cockpit_readout.text,"actual cockpit eye clears full fitout and actual bound identity/readiness show UNARMED"): return false
	return true

func _sortie_home(sortie: int,identity: int,area: ShipBoardingArea,berth: ShipBerth,dock: Transform3D) -> bool:
	if not _check(_hull_leg_clear(Vector3.UP*5),"whole production fitout clears exact departure lift"): return false
	_engine_edges.clear()
	Input.action_press(&"move_forward")
	for frame in 500:
		if not bool(_ship.get_telemetry().landed) and not _ship._departure_lift_active: break
		await _wait_frames(1)
	_release_inputs()
	if not _check(_engine_edges.size()==2 and _engine_edges[0].state==HeroShip.ENGINE_STARTING
		and _engine_edges[1].state==HeroShip.ENGINE_ONLINE
		and is_equal_approx(float(_engine_edges[0].remaining),3.8)
		and int(_engine_edges[1].tick)-int(_engine_edges[0].tick)>=227
		and int(_engine_edges[1].tick)-int(_engine_edges[0].tick)<=229
		and StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_ONLINE,
		"actual inherited3.8 startup ticks/edges="+str(_engine_edges)): return false
	if not _check((_ship.global_position-dock.origin).dot(dock.basis.y)>=4.99
		and berth.get_occupant()==null and berth.get_reservation_owner()==null,
		"actual five metre departure releases own occupied lease"): return false
	await _tap(&"interact")
	if not _check(_game._piloting and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and area.get_reservation_token()==_player and not _game._transition_busy,"active airborne exit refuses exact current pilot"): return false
	var target := dock*Vector3(0,10,-31.2)
	if not _check(_hull_leg_clear(target-_ship.global_position),"whole production hull clears flight lane"): return false
	var arrived := false
	for frame in 1800:
		var offset := target-_ship.global_position
		var distance := offset.length()
		_release_inputs()
		if distance<0.6 and _ship.velocity.length()<=0.35:
			arrived=true
			break
		var local_direction := _ship.global_basis.inverse()*offset.normalized()
		var pitch_error := atan2(local_direction.y,-local_direction.z)
		if absf(pitch_error)>0.003:
			Input.action_press(&"pitch_up" if pitch_error>0 else &"pitch_down",clampf(absf(pitch_error)*3,0.08,1))
		var desired_speed := minf(6.0,distance*0.9)
		if _ship.velocity.length()>desired_speed+0.1: Input.action_press(&"brake")
		elif distance>0.45:
			Input.action_press(&"move_forward",clampf((desired_speed-_ship.velocity.length())*0.3+0.13,0.12,0.8))
		await _wait_frames(1)
		if frame%180==0: print("PREDATOR_FLIGHT: sortie=",sortie," frame=",frame," local=",dock.affine_inverse()*_ship.global_position," speed=",_ship.velocity.length())
	_release_inputs()
	var point := dock.affine_inverse()*_ship.global_position
	if not _check(arrived and _game.phase==GameFlow.Phase.FREE_FLIGHT
		and point.distance_to(Vector3(0,10,-30))<=2 and -point.z>=30 and _ship.velocity.length()<=0.5
		and not berth.contains_oriented_bounds(_ship.global_transform,_ship.get_landing_collision_report().local_bounds),
		"actual same Titan-controller flight endpoint="+str(point)+" speed="+str(_ship.velocity.length())): return false
	var shots := _shots
	var projectiles := _projectiles
	var health: float = float(_ship.get_telemetry().hull)
	Input.action_press(&"fire")
	await _wait_frames(20)
	Input.action_release(&"fire")
	_ship._fire_weapon()
	_ship._fire_weapon_with_aim()
	_game._on_projectile_fired(_ship.global_position,-_ship.global_basis.z,_ship)
	if not _check(_shots==shots and _projectiles==projectiles and _ship.get_telemetry().hull==health
		and _ship._weapon_heat==0 and _ship._weapon_timer==0
		and _game._last_player_shot_result.reason==&"unarmed"
		and _game._get_player_weapon_profiles(_ship).is_empty()
		and _game.get_combat_authority().get_source_id(_ship)==0
		and not GameFlow.PLAYER_SOURCE_IDS.has(&"predator_provisional"),"actual held/direct/generic FIRE produces no shot/profile/source/heat/cooldown/damage"): return false
	Input.action_press(&"brake")
	await _wait_frames(30)
	_release_inputs()
	await _wait_frames(95)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE
		and not bool(_ship.get_telemetry().landed),"real neutral95 reaches airborne OFFLINE"): return false
	var generation := _game._transition_generation
	await _tap(&"interact")
	await _tap(&"interact")
	if not _check(_game._piloting and _ship.is_piloted() and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and _player.get_instance_id()==identity and area.get_reservation_token()==_player
		and _ship.get_camera().current and _game._transition_generation==generation
		and not _game._transition_busy and _player.collision_layer==0,"duplicate airborne OFFLINE exit refuses without body/camera/claim/generation mutation"): return false
	Input.action_press(&"brake")
	for frame in 300:
		if StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_ONLINE: break
		await _wait_frames(1)
	_release_inputs()
	var capture := _game._get_active_landing_assist_report()
	if not _check(bool(capture.get("assist_capture_accepted",false))
		and StringName(capture.get("selected_berth_id",&""))==&"predator_home_berth","existing capture accepts exact own home"): return false
	await _tap(&"landing_assist")
	for frame in 600:
		if _game.phase==GameFlow.Phase.SHUT_DOWN: break
		await _wait_frames(1)
	var landing := _ship.get_landing_contract_report()
	if not _check(_game.phase==GameFlow.Phase.SHUT_DOWN and berth.get_occupant()==_ship
		and berth.get_reservation_owner()==_ship and _ship.global_position.distance_to(dock.origin)<=0.05
		and _ship.velocity.length()<=0.05 and _ship.global_basis.is_equal_approx(dock.basis)
		and landing.strict_dock_acceptance and landing.contract_accepted
		and _game._ship_owns_exact_occupied_berth(_ship,&"predator_home_berth")
		and berth.contains_oriented_bounds(_ship.global_transform,_ship.get_landing_collision_report().local_bounds),
		"normal L within600 restores strict whole hull exact own dock/current occupied lease"): return false
	await _wait_frames(95)
	if not _check(StringName(_ship.get_telemetry().engine_state)==HeroShip.ENGINE_OFFLINE,"normal landed neutral95 shuts down"): return false
	await _tap(&"interact")
	for frame in 180:
		if not _game._transition_busy and not _player.is_seated(): break
		await _wait_frames(1)
	await _wait_frames(3)
	return _check(not _game._piloting and not _ship.is_piloted() and not _player.is_seated()
		and _player.get_instance_id()==identity and _player.is_control_enabled() and _player.is_on_floor()
		and (_player.get_node("%PlayerCamera") as Camera3D).current and not _ship.get_camera().current
		and _player.collision_layer==_body_layer and _player.collision_mask==_body_mask
		and not (_player.get_node("PlayerCollision") as CollisionShape3D).disabled
		and not area.is_reserved() and _game._boarding_area==null and not _ship.is_canopy_open()
		and _ship.to_local(_player.global_position).distance_to(Vector3(1,1,-5.5))<0.05
		and not bool(_player.get_cabin_containment_report().get("active",false)),
		"normal supported inside stand restores body/control/camera/claim with outer hatch still closed")

func _walk_out(sortie: int) -> bool:
	for point in [Vector3(1,1,0),Vector3(1,1,6.5)]:
		if not await _walk_to(_ship.to_global(point),60+sortie,true): return false
	var hatch := _ship.get_node("PredatorOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	await _aim(hatch.global_position)
	if not _check(_game.station_interaction_candidate==hatch,"actual standing Player reaches interior stern control"): return false
	await _tap(&"interact")
	await _wait_frames(30)
	if not _check(_ship.is_canopy_open(),"normal inside Interact opens supported physical hatch"): return false
	for point in [Vector3(1,1,7),Vector3(1,0.5,9),Vector3(1,0,11),Vector3(1,0,13),Vector3(1,0,12.1),Vector3(3.2,0,12.1),Vector3(3.2,0,8.8)]:
		if not await _walk_to(_ship.to_global(point),70+sortie,true): return false
	await _aim(hatch.global_position)
	await _tap(&"interact")
	await _wait_frames(30)
	return _check(not _ship.is_canopy_open() and _player.is_on_floor(),"same Player walks out real aisle/ramp onto apron and seals outside sweep")

func _observe_completed_player_tick() -> void:
	if not _active or _failed: return
	if _game._transition_busy or _player.is_seated() or not _player.is_control_enabled() \
			or bool(_player.get("_disembarking_completion_pending")):
		_last_frame = -1
		_last_point = Vector3.INF
		return
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

func _walk_to(target: Vector3,index: int, cabin: bool = false) -> bool:
	var reached := false
	for frame in (400 if cabin else 900):
		if _failed: return false
		var offset := target-_player.global_position
		offset.y=0
		if absf(offset.x)<(0.005 if cabin else 0.02): offset.x=0
		if absf(offset.z)<(0.005 if cabin else 0.02): offset.z=0
		if offset.length()<=(0.01 if cabin else 0.035):
			reached=true
			break
		var direction := (_player.get_node("%CameraYaw") as Node3D).global_basis.inverse()*offset.normalized()
		_release_inputs()
		var axis := Vector2(direction.x,direction.z)*((0.23 if offset.length()<0.12 else (0.35 if offset.length()<0.7 else 1.0)) if cabin else (0.4 if offset.length()<0.8 else 1.0))
		Input.action_press(&"move_right" if axis.x>0 else &"move_left",absf(axis.x))
		Input.action_press(&"move_back" if axis.y>0 else &"move_forward",absf(axis.y))
		await _observer.completed_tick
	_release_inputs()
	for frame in 12: await _observer.completed_tick
	print("PREDATOR_ROUTE_LEG: ",index," target=",target," actual=",_player.global_position," reached=",reached)
	_check(reached and (not cabin or Vector2(target.x-_player.global_position.x,target.z-_player.global_position.z).length()<0.02),"unchanged station .035/900/12 or cabin .02/400 endpoint leg "+str(index))
	return reached and not _failed

func _aim(target: Vector3) -> void:
	# Right-stick events work through the real on-foot look sampler even on a
	# headless display, where mouse capture has no operating-system surface.
	for frame in 180:
		var direction := (target - _player.get_interaction_origin()).slide(Vector3.UP).normalized()
		var forward := _player.get_interaction_direction().slide(Vector3.UP).normalized()
		var angle := forward.signed_angle_to(direction, Vector3.UP)
		if absf(angle) < 0.03: break
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_RIGHT_X
		motion.axis_value = -signf(angle) * (0.4 if absf(angle) < 0.25 else 1.0)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await _wait_frames(1)
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_RIGHT_X
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _wait_frames(2)
	print("TITAN_AIM: direction=", _player.get_interaction_direction(), " target=", target, " origin=", _player.get_interaction_origin(), " selected=", _game.station_interaction_candidate)

func _tap(action: StringName) -> void:
	if action == &"interact" or action == &"landing_assist":
		await _key(KEY_E if action == &"interact" else KEY_L)
		return
	Input.action_press(action)
	await _wait_frames(2)
	Input.action_release(action)
	await _wait_frames(2)

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame

func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"pitch_up", &"pitch_down", &"brake", &"sprint_boost", &"interact", &"landing_assist", &"fire"]:
		Input.action_release(action)

func _wait_frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _on_engine_edge(state: StringName) -> void:
	_engine_edges.append({"state": state, "tick": Engine.get_physics_frames(), "remaining": _ship.get("_engine_timer")})

func _hull_leg_clear(motion: Vector3) -> bool:
	var support := _game.world.get_node("PredatorDetentionTransportBerth/BerthDeck") as StaticBody3D
	for node in _ship.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision.disabled or not collision.get_parent() is PhysicsBody3D: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.motion = motion
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		query.margin = 0
		query.exclude = [_ship.get_rid(), support.get_rid()]
		var result := _ship.get_world_3d().direct_space_state.cast_motion(query)
		if result[0] < 1 or result[1] < 1:
			print("TITAN_BLOCKED_LEG: ", collision.name, " motion=", motion, " fractions=", result)
			return false
	return true

func _quit_normally() -> void:
	_release_inputs()
	await _key(KEY_ESCAPE)
	var exit_button := _game.hud.find_child("ExitButton", true, false) as Control
	for frame in 160:
		if root.gui_get_focus_owner() == exit_button: break
		await _key(KEY_TAB)
	_check(is_instance_valid(exit_button) and root.gui_get_focus_owner() == exit_button, "normal pause Tab reaches Exit to desktop")
	if _failed:
		_check(false,"normal Quit focus failed")
		return
	print("PREDATOR_USER_DATA_DIR: ", OS.get_user_data_dir())
	print("GAME_FLOW_PREDATOR_INTEGRATION_TEST_PASS")
	await _key(KEY_ENTER)
	for frame in 120: await process_frame
	_check(false,"normal Main Quit did not terminate OS process")


func _check(condition: bool,message: String) -> bool:
	if _failed: return false
	print("PASS: " if condition else "FAIL: ",message)
	if not condition:
		_failed = true
		_release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		quit(1)
	return condition
