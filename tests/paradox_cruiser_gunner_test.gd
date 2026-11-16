extends SceneTree

## Once-staged actual two-Player fixture, not ordinary Main or network proof.
const PREFAB := preload("res://scenes/ships/paradox_cruiser_pilot.tscn")
const CRAFT := preload("res://scripts/ships/paradox_cruiser.gd")
const PRIMARY := preload("res://assets/weapons/jovian_combat_pulse.tres")
const GUN := preload("res://assets/weapons/bulwark_combat_pulse.tres")
const AVATAR := &"fixture_gunner"
var _ship: HeroShip
var _pilot: PlayerController
var _gunner: PlayerController
var _seat: ShipCrewSeat
var _owner: CrewSeatRoleAuthority
var _combat: LiveCombatAuthority
var _seq := 1
var _failed := false
var _started := 0
var _held := false
var _shots: Array[Dictionary] = []
var _requests: Array[ShotRequest] = []
var _damage_count := 0
var _owned: Array[Node] = []

class FixtureCommands:
	extends ShipCommandSource
	var fire := false
	var brake := false
	func _sample_controls() -> Dictionary:
		return {"fire":fire,"brake":brake,"throttle":0.0,"yaw":0.0}

class GunnerProducer:
	extends Node
	var tick: Callable
	func _physics_process(_delta: float) -> void:
		if tick.is_valid(): tick.call()

func _init() -> void:
	_started = Time.get_ticks_msec()
	call_deferred("_run")

func _run() -> void:
	_box("SupportedDeck",Vector3(0,-0.5,8),Vector3(24,1,40),PhysicsLayers.WORLD)
	_ship = PREFAB.instantiate() as HeroShip
	root.add_child(_ship)
	_owned.append(_ship)
	_combat = LiveCombatAuthority.new()
	root.add_child(_combat)
	_owned.append(_combat)
	_combat.authoritative_shot_submitted.connect(func(request: ShotRequest,result: Dictionary):
		_requests.append(request)
		_shots.append({"weapon":request.weapon_id,"tick":Engine.get_physics_frames(),"result":result}))
	await _frames(3)
	var definition := _ship.call("get_gunner_weapon_definition") as WeaponDefinition
	_check(definition.weapon_id == GUN.weapon_id and definition.range_meters == 360 and definition.damage_per_hit == 50
		and is_equal_approx(definition.cadence_shots_per_second,1.0/0.30) and not definition.heat_enabled
		and not definition.ammunition_enabled and not definition.spread_enabled and definition.get_resolution_mode_id() == &"hitscan",
		"exact unchanged Bulwark pulse360/50/.30; no charge/heat/ammunition")
	definition.damage_per_hit = 1
	_check((_ship.call("get_gunner_weapon_definition") as WeaponDefinition).damage_per_hit == 50,"gunner definition immutable by detached copy")
	var profiles := WeaponDefinitionResolverProfile.to_resolver_profiles(PRIMARY,CRAFT.GUNNER_FACTION,32)
	profiles.merge(WeaponDefinitionResolverProfile.to_resolver_profiles(GUN,CRAFT.GUNNER_FACTION,24))
	_check(_combat.register_source(_ship,1111,CRAFT.GUNNER_FACTION,profiles)
		and _ship.call("attach_gunner_combat_authority",_combat).accepted
		and _combat.get_resolver().get_registered_source_count() == 1
		and _combat.get_weapon_profile(_ship,PRIMARY.weapon_id) == profiles[PRIMARY.weapon_id],
		"one source1111 owns both exact independent profiles; gunner bind never overwrites primary")
	var muzzle := _ship.call("get_gunner_muzzle") as Marker3D
	_check(_ship.to_local(muzzle.global_position) == CRAFT.GUNNER_MUZZLE,"exact fixed physical gunner muzzle0/5.7/-8")
	_pilot = _player_at(_ship.get_boarding_entry_transform())
	var anchor := _ship.get_node("ParadoxOriginalShell/GunnerStationAnchor") as Marker3D
	_seat = anchor.get_node("SoloGunnerSeatInteraction") as ShipCrewSeat
	_gunner = _player_at(_seat.get_entry_transform())
	await _frames(10)
	_ship.set_canopy_open(true,0)
	await _frames(2)
	var area := _ship.get_node("ShipBoardingArea") as ShipBoardingArea
	_check(area.try_reserve(_pilot),"actual pilot owns real supported boarding reservation")
	_ship.get_interior_frame().unregister_occupant(_pilot,false,&"pilot_handoff")
	_check(_pilot.begin_boarding(_ship.get_boarding_entry_transform(),_ship.get_pilot_seat_anchor(),0.75,_ship),"actual pilot begins normal physical boarding")
	_owner = CrewSeatRoleAuthority.new(1)
	_check(_ship.call("register_crew_seat_roster",_owner).accepted and _ship.call("attach_crew_role_authority",_owner).accepted
		and _owner.claim(1,1,AVATAR,&"gunner_station",&"gunner",1).accepted,"exact role authority claims real gunner station")
	_ship.get_interior_frame().unregister_occupant(_gunner,false,&"gunner_handoff")
	_check(_ship.attach_solo_crew_role_occupant(AVATAR,_seat,_gunner).accepted
		and _gunner.begin_boarding(_seat.get_entry_transform(),anchor,0.75,_ship),"actual gunner metadata/frame attaches and normal Player seats")
	await _frames(50)
	_ship.set_canopy_open(false,0)
	await _frames(2)
	_check(_pilot.is_seated_at(_ship.get_pilot_seat_anchor()) and _gunner.is_seated_at(anchor)
		and _ship.get_interior_frame().is_occupant_registered(_gunner),"two distinct real physical bodies remain correctly owned")
	var snapshot := _owner.get_snapshot()
	_check(not _submit(Vector3.FORWARD).accepted and _owner.get_snapshot() == snapshot,"offline valid gunner intent refuses without ledger/clock mutation")
	var latch: bool = _ship.get("_docked_latch")
	_check(not _ship.request_solo_crew_weapon_power(AVATAR,_seat,_gunner)
		and _ship.get_telemetry().engine_state == HeroShip.ENGINE_STARTING
		and is_equal_approx(float(_ship.get("_engine_timer")),3.2) and _ship.get("_docked_latch") == latch
		and not _ship.is_piloted(),"actual gunner demand starts timed3.2 power without pilot or dock-latch release")
	await _frames(205)
	_check(_ship.request_solo_crew_weapon_power(AVATAR,_seat,_gunner) and _ship.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE
		and _ship.velocity == Vector3.ZERO,"normal gunner startup finishes without motion grant")
	for yaw in [-35.0,35.0]:
		for elevation in [0.0,45.0]:
			var aim := _direction(yaw,elevation)
			_check(_ship.call("get_gunner_aim_status",aim).accepted and _submit(aim,false).get("consumed",false),"inclusive actual arc boundary "+str([yaw,elevation]))
			_check_geometry()
			await _frames(1)
			var clear_ray := PhysicsRayQueryParameters3D.create(muzzle.global_position+aim*0.002,muzzle.global_position+aim*360,PhysicsLayers.SHIP)
			_check(_ship.get_world_3d().direct_space_state.intersect_ray(clear_ray).is_empty(),"actual allowed boundary ray clears physical own hull and mount")
	for aim in [_direction(-35.01,0),_direction(35.01,0),_direction(0,-0.01),_direction(0,45.01),Vector3.ZERO,Vector3(INF,0,0),Vector3.BACK]:
		snapshot = _owner.get_snapshot()
		_check(not _ship.call("get_gunner_aim_status",aim).accepted and not _submit(aim).accepted
			and _owner.get_snapshot() == snapshot and _ship.call("get_gunner_gameplay_state").cooldown_remaining == 0,
			"out-of-arc/negative/nonfinite/backward aim refuses before ledger/power/clock mutation")
	var bad := _payload(Vector3.FORWARD)
	bad.origin += Vector3.RIGHT
	snapshot = _owner.get_snapshot()
	_check(not _send(bad,_owner).accepted and _owner.get_snapshot() == snapshot,"forged origin refuses atomically")
	bad = _payload(Vector3.FORWARD)
	bad.target_generation = 2
	_check(not _send(bad,_owner).accepted and _owner.get_snapshot() == snapshot,"stale target/seat generation refuses atomically")
	var foreign := CrewSeatRoleAuthority.new(1)
	_ship.call("register_crew_seat_roster",foreign)
	_check(not _send(_payload(Vector3.FORWARD),foreign).accepted and _owner.get_snapshot() == snapshot,"foreign authority cannot impersonate exact current gunner")
	var own_hull_ray := PhysicsRayQueryParameters3D.create(muzzle.global_position,muzzle.global_position+Vector3.BACK*20,PhysicsLayers.SHIP)
	var own_hit := _ship.get_world_3d().direct_space_state.intersect_ray(own_hull_ray)
	_check(not own_hit.is_empty() and own_hit.collider == _ship,"backward refused aim physically intersects actual own hull")
	_seq += 1
	_check(_owner.claim(1,1,&"fixture_passenger",&"passenger_station",&"passenger",_seq).accepted,"existing authority admits separate passenger ledger identity for negative action probe")
	snapshot = _owner.get_snapshot()
	_seq += 1
	_check(not _ship.call("submit_crew_intent",1,1,&"fixture_passenger",CrewSeatRoleAuthority.ACTION_GUNNER_FIRE,_payload(Vector3.FORWARD),_seq,_owner).accepted
		and _owner.get_snapshot() == snapshot and not _owner.authorize_action(1,&"fixture_passenger",CrewSeatRoleAuthority.CAPABILITY_WEAPON_CONTROL).accepted,
		"passenger role cannot issue mount action or acquire weapon capability")
	_seq += 1
	_check(_owner.release(1,1,&"fixture_passenger",&"passenger_station",_seq,1).accepted,"negative passenger probe retires through role owner")
	var target := _target("SharedStreamEnemy",Vector3(0,5.7,-80),Vector3(12,12,1),&"enemy",10000)
	await _frames(2)
	var damageable := target.get_node("Damageable") as Damageable
	var controls := FixtureCommands.new()
	_ship.add_child(controls)
	_ship.set_command_source(controls)
	_ship.set_piloted(true)
	await _aim_actual_gunner()
	_ship.projectile_fired.connect(func(origin: Vector3,direction: Vector3):
		_check(_ship.call("consume_primary_emission",origin,direction),"primary keeps its own exact single emission")
		_combat.submit_hitscan(_ship,PRIMARY.weapon_id,origin,direction))
	var producer := GunnerProducer.new()
	producer.process_physics_priority = _ship.process_physics_priority+10
	producer.tick = func():
		if _held: _submit(_gunner.get_interaction_direction())
	root.add_child(producer)
	_owned.append(producer)
	controls.fire = true
	_held = true
	await _frames(160)
	controls.fire = false
	_held = false
	var primary_count := 0
	var gunner_count := 0
	var last := {}
	for shot in _shots:
		if shot.weapon == PRIMARY.weapon_id: primary_count += 1
		if shot.weapon == GUN.weapon_id: gunner_count += 1
		if last.has(shot.weapon):
			var gap: int = int(shot.tick)-int(last[shot.weapon])
			_check(gap >= (37 if shot.weapon == PRIMARY.weapon_id else 18)
				and gap <= (39 if shot.weapon == PRIMARY.weapon_id else 19),"independent held70/.62 or50/.30 cadence: "+str(gap))
		last[shot.weapon] = shot.tick
	_check(primary_count>=4 and gunner_count>=8 and _damage_count == primary_count+gunner_count
		and damageable.get_health() == 10000-70*primary_count-50*gunner_count and _ship.get("_weapon_heat") == 0,
		"two actual seated Players simultaneously produce distinct one-hit70 and50 streams without alias/double damage/heat")
	await _frames(40)
	controls.fire = true
	_held = true
	await _frames(2)
	controls.fire = false
	_held = false
	controls.brake = true
	var pilot_timer: float = _ship.get("_weapon_timer")
	var mount_timer: float = _ship.call("get_gunner_gameplay_state").cooldown_remaining
	_check(pilot_timer>0 and mount_timer>0,"both independent real clocks active before owner retirement")
	var retired := _owner
	_seq += 1
	_check(_ship.release_solo_crew_role_occupant(AVATAR,&"gunner_station",_gunner,_seq,1,_owner).accepted
		and _ship.call("detach_crew_role_authority",_owner),"same-physics retirement uses exact role/frame/metadata owners")
	_owner = CrewSeatRoleAuthority.new(1)
	_check(_ship.call("register_crew_seat_roster",_owner).accepted and _ship.call("attach_crew_role_authority",_owner).accepted
		and _owner.claim(1,1,AVATAR,&"gunner_station",&"gunner",1).accepted
		and _ship.attach_solo_crew_role_occupant(AVATAR,_seat,_gunner).accepted,"replacement owner reacquires same physically seated body")
	_seq = 1
	_check(_ship.get("_weapon_timer") == pilot_timer and _ship.call("get_gunner_gameplay_state").cooldown_remaining == mount_timer
		and not _send(_payload(Vector3.FORWARD),retired).accepted,"same-tick owner replacement preserves both clocks and rejects retired owner")
	_check(not _submit(Vector3.FORWARD).accepted,"new occupant authority cannot erase active mount cooldown")
	_check(_gunner.begin_disembark(_seat.get_exit_transform(),0.65,_ship),"real gunner begins full normal stand")
	await _frames(45)
	_seq += 1
	_check(_ship.release_solo_crew_role_occupant(AVATAR,&"gunner_station",_gunner,_seq,1,_owner).accepted,
		"normal physical stand releases exact claim and metadata")
	_ship.get_interior_frame().register_occupant(_gunner,{"require_inside_bounds":true})
	_check(_gunner.is_on_floor() and not _gunner.is_seated() and _gunner.collision_layer == PhysicsLayers.PLAYER_BODY_LAYER
		and _gunner.collision_mask == PhysicsLayers.PLAYER_BODY_MASK,"stood actual body restores normal supported capsule/masks")
	_ship.get_interior_frame().unregister_occupant(_gunner,false,&"reseat_handoff")
	_seq += 1
	_check(_owner.claim(1,1,AVATAR,&"gunner_station",&"gunner",_seq).accepted
		and _ship.attach_solo_crew_role_occupant(AVATAR,_seat,_gunner).accepted
		and _gunner.begin_boarding(_seat.get_entry_transform(),anchor,0.75,_ship),"actual same body normally reseats without timer writes")
	await _frames(50)
	_check(_gunner.is_seated_at(anchor) and _ship.call("get_gunner_gameplay_state").cooldown_remaining == 0,"normal stand/reseat only naturally ages shared cooldown")
	var last_request := _requests[-1]
	var health := damageable.get_health()
	_check(not _combat.get_resolver().resolve_hitscan(last_request).accepted and damageable.get_health() == health,"duplicate/stale resolver request cannot redamage")
	await _remove(target)
	await _test_policy_rays()
	controls.brake = false
	_ship.request_engine_stop(false)
	_ship.set_piloted(false)
	snapshot = _owner.get_snapshot()
	_check(not _submit(Vector3.FORWARD).accepted and _owner.get_snapshot() == snapshot,"offline intent preserves body/ledger")
	_ship.set_canopy_open(true,0)
	await _frames(2)
	_check(not _submit(Vector3.FORWARD).accepted and not _ship.request_solo_crew_weapon_power(AVATAR,_seat,_gunner),"open physical access blocks gunner intent and power")
	_ship.set_canopy_open(false,0)
	await _frames(2)
	_ship.request_solo_crew_weapon_power(AVATAR,_seat,_gunner)
	await _frames(205)
	var model := _ship.get_component_damage()
	for component: Dictionary in _ship.get_component_damage_report().components:
		if component.id == ShipComponentDamage.COMPONENT_PORT_WING:
			for attempt in 4: model.record_damage(_ship.maximum_hull*2,component.local_position)
	snapshot = _owner.get_snapshot()
	_check(not _submit(Vector3.FORWARD).accepted and _ship.call("get_gunner_gameplay_state").status == &"gunner_weapon_component_failed"
		and _owner.get_snapshot() == snapshot,"existing failed weapon component refuses gunner without ledger mutation")
	_check(not _owner.authorize_action(1,AVATAR,CrewSeatRoleAuthority.CAPABILITY_SHIP_COMMAND).accepted
		and not _ship.request_solo_crew_weapon_power(&"wrong_avatar",_seat,_gunner),"gunner gains no helm and wrong identity gains no power")
	_check(_gunner.begin_disembark(_seat.get_exit_transform(),0.65,_ship)
		and _pilot.begin_disembark(_ship.get_exit_transform(),0.65,_ship),"both actual Players use normal cleanup stand")
	await _frames(45)
	_seq += 1
	_check(_ship.release_solo_crew_role_occupant(AVATAR,&"gunner_station",_gunner,_seq,1,_owner).accepted
		and _ship.call("detach_crew_role_authority",_owner) and area.release_reservation(_pilot)
		and not _gunner.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META),"cleanup retires exact role/frame/metadata and pilot reservation")
	_ship.get_interior_frame().unregister_occupant(_gunner,false,&"fixture_complete")
	_ship.get_interior_frame().unregister_occupant(_pilot,false,&"fixture_complete")
	_combat.forget_source(_ship,1111)
	_check(_combat.get_source_id(_ship) == 0 and not _send(_payload(Vector3.FORWARD),retired).accepted,"retired source and owner cannot emit after cleanup")
	for node in _owned:
		if is_instance_valid(node): node.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _failed: print("PARADOX_CRUISER_GUNNER_TEST_PASS")
	quit(1 if _failed else 0)

func _aim_actual_gunner() -> void:
	# Fresh production Players look down ten degrees. Use their normal seated
	# look input to enter the mount's authored upward arc before holding FIRE.
	_gunner.set_station_seated_context(true)
	_gunner.set_control_enabled(true)
	_gunner.set_camera_active(true)
	for tick in 180:
		var direction := (_ship.global_basis.inverse()*_gunner.get_interaction_direction()).normalized()
		var elevation := asin(clampf(direction.y,-1,1))
		if elevation >= deg_to_rad(1): break
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_RIGHT_Y
		event.axis_value = -clampf((deg_to_rad(1)-elevation)*4,0.3,1)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(1)
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_RIGHT_Y
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _frames(2)
	var observed := (_ship.global_basis.inverse()*_gunner.get_interaction_direction()).normalized()
	_check(_ship.call("get_gunner_aim_status",_gunner.get_interaction_direction()).accepted
		and observed.y >= sin(deg_to_rad(0.5)) and observed.y <= sin(deg_to_rad(2)),
		"actual normal seated right-stick input aims gunner about one degree upward inside fixed arc")
	_gunner.set_control_enabled(false)
	_gunner.set_camera_active(false)
	_ship.get_camera().make_current()

func _test_policy_rays() -> void:
	var muzzle := (_ship.call("get_gunner_muzzle") as Marker3D).global_position
	var boundary := _target("GunnerBoundary360",muzzle+Vector3.FORWARD*360.5,Vector3(1,1,1),&"enemy",1000)
	await _frames(2)
	var result := _submit(Vector3.FORWARD)
	_check(result.get("effect",{}).get("damaged",false) and (boundary.get_node("Damageable") as Damageable).get_health() == 950,"gunner exact360m boundary applies one50")
	await _remove(boundary)
	await _frames(19)
	var beyond := _target("BeyondGunner360",muzzle+Vector3.FORWARD*360.6,Vector3(1,1,1),&"enemy",1000)
	await _frames(2)
	result = _submit(Vector3.FORWARD)
	_check(result.get("effect",{}).get("status") == &"miss" and (beyond.get_node("Damageable") as Damageable).get_health() == 1000,"gunner cannot borrow primary650m range")
	await _remove(beyond)
	await _frames(19)
	var friendly := _target("Friendly",muzzle+Vector3.FORWARD*60,Vector3(2,2,1),CRAFT.GUNNER_FACTION,1000)
	await _frames(2)
	result = _submit(Vector3.FORWARD)
	_check(result.get("effect",{}).get("status") == &"friendly_fire_blocked" and (friendly.get_node("Damageable") as Damageable).get_health() == 1000,"actual friendly refusal preserves health")
	await _remove(friendly)
	await _frames(19)
	var enemy := _target("WorldOccluded",muzzle+Vector3.FORWARD*60,Vector3(2,2,1),&"enemy",1000)
	var wall := _box("WorldWall",muzzle+Vector3.FORWARD*30,Vector3(3,3,1),PhysicsLayers.WORLD)
	await _frames(2)
	var before := _requests.size()
	result = _submit(Vector3.FORWARD)
	_check(not result.accepted and result.status == &"gunner_world_blocked" and _requests.size() == before
		and (enemy.get_node("Damageable") as Damageable).get_health() == 1000,"real world occlusion refuses before offensive effect")
	await _remove(wall)
	await _remove(enemy)

func _payload(direction: Vector3,trigger: bool = true) -> Dictionary:
	return {"weapon_id":GUN.weapon_id,"target_id":&"free_aim","target_generation":1,"trigger":trigger,
		"origin":(_ship.call("get_gunner_muzzle") as Marker3D).global_position,"direction":direction}

func _submit(direction: Vector3,trigger: bool = true) -> Dictionary:
	return _send(_payload(direction,trigger),_owner)

func _send(payload: Dictionary,owner: CrewSeatRoleAuthority) -> Dictionary:
	_seq += 1
	return _ship.call("submit_crew_intent",1,1,AVATAR,CrewSeatRoleAuthority.ACTION_GUNNER_FIRE,payload,_seq,owner)

func _direction(yaw: float,elevation: float) -> Vector3:
	return Vector3(sin(deg_to_rad(yaw))*cos(deg_to_rad(elevation)),sin(deg_to_rad(elevation)),-cos(deg_to_rad(yaw))*cos(deg_to_rad(elevation)))

func _check_geometry() -> void:
	for pair in [["Pedestal","DefensiveMountPedestalCollision"],["Barrel","DefensiveMountBarrelCollision"]]:
		var mesh := _ship.get_node("ParadoxDefensiveMount/"+pair[0]) as MeshInstance3D
		var collision := _ship.get_node(pair[1]) as CollisionShape3D
		_check((mesh.mesh as BoxMesh).size == (collision.shape as BoxShape3D).size and mesh.global_transform.is_equal_approx(collision.global_transform),"actual mount mesh matches physical collider "+pair[0])
		var half := (mesh.mesh as BoxMesh).size*0.5
		for x in [-1,1]:
			for y in [-1,1]:
				for z in [-1,1]:
					var point := mesh.transform*Vector3(x*half.x,y*half.y,z*half.z)
					_check(point.x >= -8 and point.x <=8 and point.y >=0 and point.y <=6 and point.z >=-14 and point.z <=14,"real authored mount arc stays original16x28x6 envelope")

func _player_at(pose: Transform3D) -> PlayerController:
	var actor := preload("res://scenes/player/player.tscn").instantiate() as PlayerController
	actor.transform = pose
	root.add_child(actor)
	actor.set_control_enabled(false)
	_owned.append(actor)
	return actor

func _target(label: String,position: Vector3,size: Vector3,faction: StringName,health: float) -> StaticBody3D:
	var body := _box(label,position,size,PhysicsLayers.TARGET)
	var damageable := Damageable.new()
	damageable.name = "Damageable"
	damageable.maximum_health = health
	damageable.faction_id = faction
	damageable.damage_applied.connect(func(_a: float,_h: float,_m: float,_p: Vector3,_n: Vector3,_s: Dictionary): _damage_count += 1)
	body.add_child(damageable)
	return body

func _box(label: String,position: Vector3,size: Vector3,layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	_owned.append(body)
	return body

func _remove(node: Node) -> void:
	_owned.erase(node)
	node.queue_free()
	await _frames(2)

func _frames(count: int) -> void:
	for tick in count:
		await physics_frame
		if Time.get_ticks_msec()-_started>180000: _check(false,"original180s fixture cap")
	await process_frame

func _check(condition: bool,message: String) -> void:
	if _failed: return
	print("PASS: " if condition else "FAIL: ",message)
	if not condition:
		_failed = true
		_held = false
		for action in [&"fire",&"move_forward",&"move_right",&"pitch_up"]: Input.action_release(action)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		quit(1)
