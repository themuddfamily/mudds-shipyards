extends SceneTree

## Once-staged production-prefab/component fixture; ordinary Main remains separate.
const CRUISER := preload("res://scenes/ships/paradox_cruiser_pilot.tscn")
const PROFILE := preload("res://assets/weapons/jovian_combat_pulse.tres")
const CRAFT := preload("res://scripts/ships/paradox_cruiser.gd")
const SOURCE_ID := 1111
const FACTION := &"player"
var _failed := false
var _started := 0
var _ship: HeroShip
var _player: PlayerController
var _authority: LiveCombatAuthority
var _shots: Array[Dictionary] = []
var _requests: Array[ShotRequest] = []
var _damage_events := 0
var _owned: Array[Node] = []

class FixtureCommands:
	extends ShipCommandSource
	var fire := false
	func _sample_controls() -> Dictionary:
		return {"fire":fire,"throttle":0.0,"yaw":0.0}

func _init() -> void:
	_started = Time.get_ticks_msec()
	call_deferred("_run")

func _run() -> void:
	var floor := StaticBody3D.new()
	floor.collision_layer = PhysicsLayers.WORLD
	floor.position = Vector3(0,-0.5,8)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(24,1,40)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	root.add_child(floor)
	_owned.append(floor)
	_ship = CRUISER.instantiate() as HeroShip
	root.add_child(_ship)
	_owned.append(_ship)
	_authority = LiveCombatAuthority.new()
	root.add_child(_authority)
	_owned.append(_authority)
	_authority.authoritative_shot_submitted.connect(func(request: ShotRequest,_result: Dictionary): _requests.append(request))
	await _frames(3)
	var definition := _ship.call("get_weapon_definition") as WeaponDefinition
	_check(definition != null and definition.weapon_id == PROFILE.weapon_id and definition.range_meters == 650
		and definition.damage_per_hit == 70 and is_equal_approx(definition.cadence_shots_per_second,1.61290322580645)
		and not definition.heat_enabled and not definition.ammunition_enabled and not definition.spread_enabled
		and definition.get_resolution_mode_id() == &"hitscan" and _ship.weapon_cooldown == 0.62,
		"exact unchanged Jovian hitscan650/70/.62 profile; no authored heat/ammunition/charge")
	definition.damage_per_hit = 1
	_check((_ship.call("get_weapon_definition") as WeaponDefinition).damage_per_hit == 70 and PROFILE.damage_per_hit == 70,
		"caller cannot mutate fitted or shared definition")
	var profiles := WeaponDefinitionResolverProfile.to_resolver_profiles(PROFILE,FACTION,32)
	_check(_authority.register_source(_ship,SOURCE_ID,FACTION,profiles)
		and _authority.get_source_id(_ship) == SOURCE_ID and _authority.get_resolver().get_registered_source_count() == 1,
		"one unique1111 source with exact resource conversion")
	_ship.projectile_fired.connect(_on_emission)
	var area := _ship.get_node("ShipBoardingArea") as ShipBoardingArea
	_ship.call("_fire_weapon")
	_check(_shots.is_empty() and not _ship.call("get_primary_pilot_claim_is_current")
		and not _ship.call("consume_primary_emission",Vector3.ZERO,Vector3.FORWARD),"no-owner/direct manual emission refuses before pilot claim")
	for index in 2:
		var marker := _ship.get_node("LeftMuzzle" if index == 0 else "RightMuzzle") as Marker3D
		_check(marker.get_parent() == _ship and marker.position == CRAFT.PRIMARY_MUZZLES[index],"exact stable physical nose muzzle " + str(index))
		var inward := PhysicsRayQueryParameters3D.create(marker.global_position+Vector3.FORWARD*0.002,
			marker.global_position+Vector3.BACK*0.05,PhysicsLayers.SHIP)
		var outward := PhysicsRayQueryParameters3D.create(marker.global_position+Vector3.FORWARD*0.002,
			marker.global_position+Vector3.FORWARD,PhysicsLayers.SHIP)
		var inside_hit := _ship.get_world_3d().direct_space_state.intersect_ray(inward)
		_check(not inside_hit.is_empty() and inside_hit.collider == _ship
			and _ship.get_world_3d().direct_space_state.intersect_ray(outward).is_empty(),
			"physical exact nose face measured: solid behind and unobstructed outward ray")
	_player = preload("res://scenes/player/player.tscn").instantiate() as PlayerController
	_player.transform = _ship.get_boarding_entry_transform()
	root.add_child(_player)
	_owned.append(_player)
	_player.set_control_enabled(false)
	await _frames(10)
	_ship.set_canopy_open(true,0)
	await _frames(2)
	_check(area.try_reserve(_player),"ordinary owner reserves real supported open helm")
	_ship.get_interior_frame().unregister_occupant(_player,false,&"pilot_handoff")
	_check(_player.begin_boarding(_ship.get_boarding_entry_transform(),_ship.get_pilot_seat_anchor(),0.75,_ship),
		"actual Player uses normal physical pilot transition")
	await _frames(50)
	_ship.set_canopy_open(false,0)
	await _frames(2)
	var controls := FixtureCommands.new()
	_ship.add_child(controls)
	_ship.set_command_source(controls)
	_ship.set_piloted(true)
	var roster := CrewSeatRoleAuthority.new(1)
	_check(_ship.call("register_crew_seat_roster",roster).accepted and _ship.call("attach_crew_role_authority",roster).accepted,
		"existing exact three-seat role owner remains intact alongside pilot reservation")
	var ledger := roster.get_snapshot()
	_check(_ship.call("get_primary_pilot_claim_is_current") and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and _ship.get_weapon_fire_status().reason == &"engine_not_online","actual current seated pilot remains offline until ordinary startup")
	_ship.call("_fire_weapon")
	_check(_shots.is_empty(),"offline actual pilot cannot fire")
	_ship.request_engine_start()
	_check(_ship.get_telemetry().engine_state == HeroShip.ENGINE_STARTING and is_equal_approx(float(_ship.get("_engine_timer")),3.2),
		"unchanged normal3.2 startup")
	await _frames(205)
	_check(_ship.get_weapon_fire_status().ready,"online current pilot/component readiness")
	var camera := _ship.get_camera()
	var direction := camera.project_ray_normal(camera.get_viewport().get_visible_rect().size*0.5).normalized()
	var target := _target("PrimaryEnemy",camera.global_position+direction*100,Vector3(8,8,1),&"enemy",10000)
	await _frames(2)
	var health := (target.get_node("Damageable") as Damageable).get_health()
	controls.fire = true
	await _frames(2)
	controls.fire = false
	_check(_shots.size() == 1 and _damage_events == 1 and (target.get_node("Damageable") as Damageable).get_health() == health-70,
		"normal valid command produces exactly one hit70/event, never two hits for paired barrels")
	_ship.call("_fire_weapon")
	_check(_shots.size() == 1,"same-trigger immediate direct retry cannot double-hit during real cooldown")
	await _frames(39)
	controls.fire = true
	await _frames(2)
	controls.fire = false
	_check(_shots.size() == 2 and _damage_events == 2 and (target.get_node("Damageable") as Damageable).get_health() == health-140
		and _shots[0].origin == (_ship.get_node("LeftMuzzle") as Marker3D).global_position
		and _shots[1].origin == (_ship.get_node("RightMuzzle") as Marker3D).global_position,
		"second ordinary trigger alternates exact right muzzle, one more70 damage")
	await _frames(39)
	var held_start := _shots.size()
	controls.fire = true
	await _frames(160)
	controls.fire = false
	_check(_shots.size() >= held_start+4,"held ordinary FIRE continues original cadence")
	for index in range(held_start+1,_shots.size()):
		var gap := int(_shots[index].tick)-int(_shots[index-1].tick)
		_check(gap >= 37 and gap <= 39 and _shots[index].origin != _shots[index-1].origin,
			"held .62-second single-stream cadence alternates exactly once per accepted shot: " + str(gap))
	_check(_ship.get("_weapon_heat") == 0 and not _ship.get("_weapon_overheated") and _ship.get("_weapon_overheat_remaining") == 0
		and roster.get_snapshot() == ledger and _damage_events == _shots.size(),"no inherited heat mechanic or crew ledger mutation; one damage event per shot")
	var captured := _requests[-1]
	var damage_before := (target.get_node("Damageable") as Damageable).get_health()
	_check(not _authority.get_resolver().resolve_hitscan(captured).accepted
		and not _authority.get_resolver().resolve_hitscan(_requests[0]).accepted
		and (target.get_node("Damageable") as Damageable).get_health() == damage_before,"duplicate and stale requests cannot redamage actual target")
	var count := _shots.size()
	var body_pose := _player.global_transform
	_ship.call("_fire_weapon_with_aim",_player.global_position,Vector3.BACK)
	_ship.call("_fire_weapon_with_aim",Vector3.INF,Vector3.BACK)
	_check(_shots.size() == count and _ship.get_weapon_fire_status().last_refusal == &"primary_pilot_aim_only"
		and not _ship.call("consume_primary_emission",_shots[-1].origin,_shots[-1].direction)
		and _player.global_transform == body_pose and roster.get_snapshot() == ledger,
		"direct crew/backward/manual stale emission refuses without body/claim/effect mutation")
	await _remove(target)
	# These exact production resolver cases isolate its650m envelope and faction
	# policy from camera aiming; the ordinary-command positives above own firing.
	var muzzle := (_ship.get_node("LeftMuzzle") as Marker3D).global_position
	var boundary := _target("Boundary650",muzzle+Vector3.FORWARD*650.5,Vector3(1,1,1),&"enemy",1000)
	await _frames(2)
	var result := _authority.submit_hitscan(_ship,PROFILE.weapon_id,muzzle,Vector3.FORWARD)
	_check(result.get("damaged",false) and absf(float(result.get("distance",0))-650)<0.001
		and (boundary.get_node("Damageable") as Damageable).get_health() == 930,"exact650m front-face boundary applies one70 damage")
	await _remove(boundary)
	var beyond := _target("Beyond650",muzzle+Vector3.FORWARD*650.6,Vector3(1,1,1),&"enemy",1000)
	await _frames(2)
	result = _authority.submit_hitscan(_ship,PROFILE.weapon_id,muzzle,Vector3.FORWARD)
	_check(result.status == &"miss" and (beyond.get_node("Damageable") as Damageable).get_health() == 1000,"overrange beyond650m is miss and preserves health")
	await _remove(beyond)
	result = _authority.submit_hitscan(_ship,PROFILE.weapon_id,muzzle,Vector3.LEFT)
	_check(result.status == &"miss","empty supported ray misses without damage")
	var friendly := _target("Friendly",muzzle+Vector3.FORWARD*40,Vector3(2,2,1),FACTION,1000)
	await _frames(2)
	result = _authority.submit_hitscan(_ship,PROFILE.weapon_id,muzzle,Vector3.FORWARD)
	_check(result.status == &"friendly_fire_blocked" and (friendly.get_node("Damageable") as Damageable).get_health() == 1000,
		"production inherited friendly deny preserves friendly health")
	await _remove(friendly)
	var occluded := _target("OccludedEnemy",muzzle+Vector3.FORWARD*40,Vector3(2,2,1),&"enemy",1000)
	var wall := _box("WorldOccluder",muzzle+Vector3.FORWARD*20,Vector3(3,3,1),PhysicsLayers.WORLD)
	await _frames(2)
	result = _authority.submit_hitscan(_ship,PROFILE.weapon_id,muzzle,Vector3.FORWARD)
	_check(result.status == &"world_blocked" and (occluded.get_node("Damageable") as Damageable).get_health() == 1000,
		"actual solid world obstruction blocks damage")
	await _remove(wall)
	await _remove(occluded)
	var hull: float = _ship.get_telemetry().hull
	_authority.submit_hitscan(_ship,PROFILE.weapon_id,muzzle,Vector3.BACK)
	_check(_ship.get_telemetry().hull == hull,"source self-exclusion cannot damage own actual hull")
	await _frames(39)
	count = _shots.size()
	_check(area.release_reservation(_player),"current reservation releases through owner")
	_ship.call("_fire_weapon")
	_check(_shots.size() == count and not _ship.call("get_primary_pilot_claim_is_current"),"nonowner seated body cannot fire after claim retirement")
	# Restore only through ordinary owner admission while physically at its seat.
	_ship.request_engine_stop(false)
	_ship.set_piloted(false)
	_ship.set_canopy_open(true,0)
	await _frames(2)
	_check(area.try_reserve(_player),"real owner reacquires through supported open reservation gate")
	_ship.set_piloted(true)
	_ship.call("_fire_weapon")
	_check(_shots.size() == count and not _ship.call("get_primary_pilot_claim_is_current"),"open hatch/current body refuses primary and engine power")
	_ship.set_canopy_open(false,0)
	await _frames(2)
	_ship.request_engine_start()
	await _frames(205)
	var model := _ship.get_component_damage()
	for component: Dictionary in _ship.get_component_damage_report().get("components",[]):
		if component.id == ShipComponentDamage.COMPONENT_PORT_WING:
			for attempt in 4: model.record_damage(_ship.maximum_hull*2,component.local_position)
	_ship.call("_fire_weapon")
	_check(_shots.size() == count and _ship.get_weapon_fire_status().reason == &"weapon_component_failed"
		and roster.get_snapshot() == ledger and _player.is_seated_at(_ship.get_pilot_seat_anchor()),
		"failed existing weapon component blocks fire while actual body and role ledger remain intact")
	_ship.request_engine_stop(false)
	_ship.set_piloted(false)
	_check(_player.begin_disembark(_ship.get_exit_transform(),0.65,_ship),"cleanup uses ordinary supported Player stand")
	await _frames(45)
	_check(area.release_reservation(_player) and _ship.call("detach_crew_role_authority",roster)
		and not _player.is_seated() and not _player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META),"cleanup releases actual reservation, body and empty role authority")
	_authority.forget_source(_ship,SOURCE_ID)
	_check(_authority.get_source_id(_ship) == 0 and not _authority.get_resolver().resolve_hitscan(captured).accepted,
		"retired source request cannot damage after owner cleanup")
	for node in _owned:
		if is_instance_valid(node): node.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _failed: print("PARADOX_CRUISER_PRIMARY_TEST_PASS")
	quit(1 if _failed else 0)

func _on_emission(origin: Vector3,direction: Vector3) -> void:
	_check(_ship.call("get_primary_pilot_claim_is_current") and _ship.call("consume_primary_emission",origin,direction)
		and not _ship.call("consume_primary_emission",origin,direction),"exact synchronous emission consumed once only")
	var result := _authority.submit_hitscan(_ship,PROFILE.weapon_id,origin,direction)
	_shots.append({"origin":origin,"direction":direction,"tick":Engine.get_physics_frames(),"result":result})

func _target(label: String,position: Vector3,size: Vector3,faction: StringName,health: float) -> StaticBody3D:
	var body := _box(label,position,size,PhysicsLayers.TARGET)
	var damageable := Damageable.new()
	damageable.name = "Damageable"
	damageable.maximum_health = health
	damageable.faction_id = faction
	damageable.damage_applied.connect(func(_a: float,_h: float,_m: float,_p: Vector3,_n: Vector3,_s: Dictionary): _damage_events += 1)
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
		if Time.get_ticks_msec()-_started>180000: _check(false,"original180-second fixture cap")
	await process_frame

func _check(condition: bool,message: String) -> void:
	if _failed: return
	print("PASS: " if condition else "FAIL: ",message)
	if not condition:
		_failed = true
		for action in [&"fire",&"move_forward",&"move_right",&"pitch_up"]: Input.action_release(action)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		quit(1)
