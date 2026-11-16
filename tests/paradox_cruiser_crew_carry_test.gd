extends SceneTree

## Production-prefab local carrier fixture, not Main or network qualification.
const CRUISER := preload("res://scenes/ships/paradox_cruiser_pilot.tscn")
const CRAFT := preload("res://scripts/ships/paradox_cruiser.gd")
const PLAYER := preload("res://scenes/player/player.tscn")
var _failed := false
var _started := 0
var _observer: CompletedPlayerTick
var _body_states: Dictionary = {}

class FixtureCommands:
	extends ShipCommandSource
	var throttle := 0.0
	var yaw := 0.0
	var brake := false
	var fire := false
	func _sample_controls() -> Dictionary:
		return {"throttle": throttle, "yaw": yaw, "brake": brake, "fire": fire}

class CompletedPlayerTick:
	extends Node
	signal completed_tick
	func _physics_process(_delta: float) -> void:
		completed_tick.emit()

func _init() -> void:
	_started = Time.get_ticks_msec()
	call_deferred("_run")

func _run() -> void:
	var ship := CRUISER.instantiate() as HeroShip
	# Once-stage only. Subsequent craft/body motion belongs to production owners.
	ship.position = Vector3(0,20,0)
	root.add_child(ship)
	await _frames(3)
	var frame := ship.get_interior_frame() as MovingInteriorFrame
	var seats: Array[ShipCrewSeat] = []
	var players: Array[PlayerController] = []
	for index in 2:
		var anchor := ship.get_node("ParadoxOriginalShell/" + String(CRAFT.CREW_ANCHOR_NAMES[index])) as Marker3D
		var seat := anchor.get_node("Solo%sSeatInteraction" % String(CRAFT.CREW_ROLES[index]).capitalize()) as ShipCrewSeat
		seats.append(seat)
		_check(anchor.position == CRAFT.CREW_POSITIONS[index] and seat.get_role() == CRAFT.CREW_ROLES[index]
			and ship.to_local(seat.get_entry_transform().origin).is_equal_approx(CRAFT.CREW_STANDS[index]),
			"exact distinct authored physical crew anchor and aisle-facing supported stand " + str(index))
		var actor := PLAYER.instantiate() as PlayerController
		actor.transform = seat.get_entry_transform()
		root.add_child(actor)
		actor.set_control_enabled(false)
		players.append(actor)
		var collision := actor.get_node("PlayerCollision") as CollisionShape3D
		var capsule := collision.shape as CapsuleShape3D
		_body_states[actor] = [actor.collision_layer,actor.collision_mask,actor.gravity_multiplier,
			Vector2(capsule.radius,capsule.height),collision.transform]
	_observer = CompletedPlayerTick.new()
	_observer.process_physics_priority = maxi(maxi(players[0].process_physics_priority,players[1].process_physics_priority),
		frame.process_physics_priority + frame.occupant_priority_offset) + 1
	root.add_child(_observer)
	await _frames(10)
	var unsealed := CrewSeatRoleAuthority.new(1)
	_check(not ship.call("attach_crew_role_authority",unsealed).accepted and ship.call("get_crew_role_authority") == null,
		"unsealed authority refuses without changing owner")
	for changed_field in ["vessel_id","seat_id","role","frame_id","anchor_id","seat_generation"]:
		var wrong := CrewSeatRoleAuthority.new(1)
		for record: Dictionary in ship.call("_crew_seat_records"):
			var identity := {"seat_id":record.seat_id,"role":record.role,"vessel_id":ship.get_ship_id(),
				"frame_id":CRAFT.CREW_FRAME_ID,"anchor_id":record.anchor_id,"seat_generation":1}
			if record.seat_id == CRAFT.CREW_IDS[0]:
				identity[changed_field] = 2 if changed_field == "seat_generation" else (&"engineer" if changed_field == "role" else &"foreign_identity")
			wrong.register_seat(identity.seat_id,identity.vessel_id,identity.role,identity.frame_id,identity.seat_generation,identity.anchor_id)
		wrong.seal_roster([&"pilot",&"passenger"])
		var before := wrong.get_snapshot()
		_check(not ship.call("attach_crew_role_authority",wrong).accepted and ship.call("get_crew_role_authority") == null
			and wrong.get_snapshot() == before,"wrong sealed roster refuses atomically " + changed_field)
	var authority := CrewSeatRoleAuthority.new(1)
	_check(ship.call("register_crew_seat_roster",authority).accepted and ship.call("attach_crew_role_authority",authority).accepted
		and (authority.get_snapshot().seats as Array).size() == 3,"exact sealed one-pilot/gunner/passenger ledger attaches")
	var foreign := CrewSeatRoleAuthority.new(1)
	ship.call("register_crew_seat_roster",foreign)
	_check(not ship.call("attach_crew_role_authority",foreign).accepted and not ship.call("detach_crew_role_authority",foreign),
		"foreign authority cannot replace or detach current owner")
	for index in 2:
		var avatar := StringName("fixture_crew_" + str(index))
		_check(authority.claim(1,1,avatar,seats[index].get_seat_id(),seats[index].get_role(),index+1).accepted,
			"distinct actual body claims its exact role")
		frame.unregister_occupant(players[index],false,&"seat_handoff")
		_check(ship.attach_solo_crew_role_occupant(avatar,seats[index],players[index]).accepted
			and players[index].begin_boarding(seats[index].get_entry_transform(),seats[index].get_seat_anchor(),0.75,ship),
			"shared occupant owner and normal Player boarding transition")
	await _frames(50)
	for index in 2:
		_check(players[index].is_seated_at(seats[index].get_seat_anchor()) and _clear_body(players[index])
			and frame.is_occupant_registered(players[index]),"real distinct seated body capsule and eye clear and carried " + str(index))
	var before := authority.get_snapshot()
	var metadata: Dictionary = players[0].get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
	_check(not authority.claim(1,2,&"duplicate",seats[0].get_seat_id(),&"gunner",1).accepted
		and not authority.claim(1,1,&"wrong_role",seats[1].get_seat_id(),&"pilot",3).accepted
		and not authority.claim(2,1,&"foreign",&"pilot_station",&"pilot",3).accepted
		and not authority.claim(1,1,&"extra_pilot",&"second_pilot_station",&"pilot",3).accepted
		and not authority.release(1,1,&"fixture_crew_0",seats[0].get_seat_id(),3,2).accepted
		and not authority.release(1,1,&"fixture_crew_0",seats[0].get_seat_id(),1,1).accepted
		and authority.get_snapshot() == before,"occupied/foreign/cross-role/extra-pilot/stale sequence and generation refuse atomically")
	_check(not ship.attach_solo_crew_role_occupant(&"fixture_crew_0",seats[1],players[0]).accepted
		and not ship.attach_solo_crew_role_occupant(&"fixture_crew_0",seats[0],players[0]).accepted
		and not ship.release_solo_crew_role_occupant(&"wrong_avatar",seats[0].get_seat_id(),players[0],3,1,authority).accepted
		and not ship.release_solo_crew_role_occupant(&"fixture_crew_0",seats[1].get_seat_id(),players[0],3,1,authority).accepted
		and not ship.release_solo_crew_role_occupant(&"fixture_crew_0",seats[0].get_seat_id(),players[0],3,2,authority).accepted
		and players[0].get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) == metadata and authority.get_snapshot() == before,
		"cross-seat duplicate attach and wrong release preserve exact metadata/frame/ledger")
	_check(not ship.call("detach_crew_role_authority",authority),"occupied authority cannot detach")
	for index in 2:
		var avatar := StringName("fixture_crew_" + str(index))
		for capability in [CrewSeatRoleAuthority.CAPABILITY_SHIP_COMMAND,CrewSeatRoleAuthority.CAPABILITY_SYSTEMS_CONTROL]:
			_check(not authority.authorize_action(1,avatar,capability).accepted,"crew cannot acquire flight or system capability")
	_check(authority.authorize_action(1,&"fixture_crew_0",CrewSeatRoleAuthority.CAPABILITY_WEAPON_CONTROL).accepted
		and authority.authorize_action(1,&"fixture_crew_1",CrewSeatRoleAuthority.CAPABILITY_PASSENGER_ACCESS).accepted
		and not authority.authorize_action(1,&"fixture_crew_1",CrewSeatRoleAuthority.CAPABILITY_WEAPON_CONTROL).accepted,
		"gunner has weapon-control only and passenger has passenger-access only")
	for action in [CrewSeatRoleAuthority.ACTION_FLIGHT_COMMAND,CrewSeatRoleAuthority.ACTION_GUNNER_FIRE,CrewSeatRoleAuthority.ACTION_ENGINEER_REPAIR]:
		_check(not authority.submit_intent(1,1,&"fixture_crew_1",action,{},3).accepted,"passenger cannot issue ship/weapon/system intent")
	_check(authority.get_snapshot() == before and not ship.request_solo_crew_weapon_power(&"fixture_crew_0",seats[0],players[0])
		and ship.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE,"unfitted gunner has no weapon power consumer or action side effect")
	var controls := FixtureCommands.new()
	ship.add_child(controls)
	ship.set_command_source(controls)
	ship.set_piloted(true)
	ship.request_engine_start()
	_check(ship.get_telemetry().engine_state == HeroShip.ENGINE_STARTING and is_equal_approx(float(ship.get("_engine_timer")),3.2),
		"normal fixture command owner starts inherited 3.2-second engine clock")
	await _frames(205)
	_check(ship.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE,"ordinary startup completes before fixture flight")
	var origin := ship.global_transform
	controls.throttle = 0.18
	controls.yaw = 0.12
	await _frames(45)
	for index in 2:
		_check(players[index].begin_disembark(seats[index].get_exit_transform(),0.65,ship),"normal moving stand starts")
	await _frames(45)
	for index in 2:
		var avatar := StringName("fixture_crew_" + str(index))
		_check(ship.release_solo_crew_role_occupant(avatar,seats[index].get_seat_id(),players[index],index+3,1,authority).accepted,
			"shared owner releases exact role metadata/claim")
		frame.register_occupant(players[index],{"require_inside_bounds":true})
		players[index].set_cabin_containment(ship,CRAFT.CABIN_VOID,seats[index].get_exit_transform())
	await _frames(5)
	for index in 2:
		_check(not players[index].is_seated() and players[index].is_on_floor() and _normal_body(players[index]) and _clear_body(players[index])
			and ship.to_local(players[index].global_position).distance_to(CRAFT.CREW_STANDS[index]) < 0.08
			and players[index].get_cabin_containment_report().get("frame") == ship,"moving actual body restores supported authored stand, normal capsule/gravity/masks and containment")
		players[index].set_control_enabled(true)
		var target: Vector3 = CRAFT.CREW_STANDS[index] + Vector3(0,0,1.3)
		_check(await _walk_local(players[index],ship,target),"actual supported body walks over one metre on moving cabin")
		_check(await _walk_local(players[index],ship,CRAFT.CREW_STANDS[index]),"actual supported body returns to authored own entry")
		players[index].set_control_enabled(false)
		players[index].clear_cabin_containment()
		frame.unregister_occupant(players[index],false,&"reseat_handoff")
		var reseat_avatar := StringName("fixture_crew_" + str(index))
		_check(authority.claim(1,1,reseat_avatar,seats[index].get_seat_id(),seats[index].get_role(),index+5).accepted
			and ship.attach_solo_crew_role_occupant(reseat_avatar,seats[index],players[index]).accepted
			and players[index].begin_boarding(seats[index].get_entry_transform(),seats[index].get_seat_anchor(),0.75,ship),
			"same real body reseats through existing owners while moving")
		await _frames(50)
	_check(ship.global_position.distance_to(origin.origin) > 2 and not ship.global_basis.is_equal_approx(origin.basis)
		and players[0].is_seated_at(seats[0].get_seat_anchor()) and players[1].is_seated_at(seats[1].get_seat_anchor())
		and _clear_body(players[0]) and _clear_body(players[1]) and frame.get_occupant_count() == 2,
		"actual command translation over two metres and changed basis carry both reseated real bodies")
	controls.throttle = 0
	controls.yaw = 0
	controls.brake = true
	await _frames(120)
	controls.brake = false
	await _frames(95)
	ship.set_piloted(false)
	for index in 2:
		_check(players[index].begin_disembark(seats[index].get_exit_transform(),0.65,ship),"cleanup uses normal Player stand")
	await _frames(45)
	for index in 2:
		var avatar := StringName("fixture_crew_" + str(index))
		_check(ship.release_solo_crew_role_occupant(avatar,seats[index].get_seat_id(),players[index],index+7,1,authority).accepted
			and not players[index].has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
			and not frame.is_occupant_registered(players[index]),"cleanup retires exact claim/metadata/frame through owners")
		players[index].clear_cabin_containment()
	_check((authority.get_snapshot().assignments as Array).is_empty() and ship.call("detach_crew_role_authority",authority)
		and ship.call("get_crew_role_authority") == null and frame.get_occupant_count() == 0,"empty role owner and both carried bodies cleanly retire")
	for player in players: player.queue_free()
	ship.queue_free()
	_observer.queue_free()
	_observer = null
	await process_frame
	if not _failed: print("PARADOX_CRUISER_CREW_CARRY_TEST_PASS")
	quit(1 if _failed else 0)

func _normal_body(player: PlayerController) -> bool:
	var state: Array = _body_states[player]
	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	return player.collision_layer == state[0] and player.collision_mask == state[1] and is_equal_approx(player.gravity_multiplier,state[2]) \
		and Vector2(capsule.radius,capsule.height) == state[3] and collision.transform == state[4] and not collision.disabled

func _clear_body(player: PlayerController) -> bool:
	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.margin = 0
	query.exclude = [player.get_rid()]
	if not player.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty(): return false
	var eye := SphereShape3D.new()
	eye.radius = 0.08
	query.shape = eye
	query.transform = (player.get_node("%PlayerCamera") as Camera3D).global_transform
	return player.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty()

func _walk_local(player: PlayerController,ship: HeroShip,target: Vector3) -> bool:
	var frames := 0
	var supported := 0
	var clear := 0
	var reached := false
	for tick in 180:
		var offset := (ship.to_global(target)-player.global_position).slide(ship.global_basis.y)
		if offset.length() < 0.035:
			reached = true
			break
		var direction := (player.get_node("%CameraYaw") as Node3D).global_basis.inverse()*offset.normalized()
		_release_inputs()
		var strength := 0.4 if offset.length()<0.8 else 1.0
		Input.action_press(&"move_right" if direction.x>0 else &"move_left",absf(direction.x)*strength)
		Input.action_press(&"move_back" if direction.z>0 else &"move_forward",absf(direction.z)*strength)
		await _frames(1)
		frames += 1
		if player.is_on_floor(): supported += 1
		if _clear_body(player) and _normal_body(player): clear += 1
	_release_inputs()
	await _frames(12)
	print("PARADOX_CREW_WALK: local=",ship.to_local(player.global_position)," target=",target," frames=",frames," supported=",supported," clear=",clear)
	return reached and frames>10 and supported==frames and clear==frames

func _release_inputs() -> void:
	for action in [&"move_forward",&"move_back",&"move_left",&"move_right",&"fire"]: Input.action_release(action)

func _frames(count: int) -> void:
	for tick in count:
		if is_instance_valid(_observer): await _observer.completed_tick
		else: await physics_frame
		if Time.get_ticks_msec()-_started > 180000: _check(false,"original 180-second fixture cap")
	await process_frame

func _check(condition: bool,message: String) -> void:
	if _failed: return
	print("PASS: " if condition else "FAIL: ",message)
	if not condition:
		_failed = true
		_release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		quit(1)
