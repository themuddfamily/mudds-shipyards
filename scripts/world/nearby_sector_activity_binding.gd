class_name NearbySectorActivityBinding
extends Node3D

## Production owner for the one authored activity that belongs in Cinder Reach.
##
## The convoy host already owns its route, movement, and escort lifecycle. This
## binding gives the streamed cluster one stable composition seam without
## handing the cluster any GameFlow, HUD, combat, reward, save, or network
## authority. The route is checked against the cluster's authored envelope; no
## points are generated or extended here.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"cinder_reach_emberline_convoy"
const RACE_ACTIVITY_ID: StringName = &"cinder_reach_checkpoint_route"
const HOST_PATH := NodePath("EmberlineSupplyTenderHost")
const RACE_ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const RACE_SESSION := preload("res://scripts/activities/cinder_timed_race_session.gd")
const PATROL_ACTIVITY := preload("res://scripts/activities/patrol_activity.gd")
const CARGO_ACTIVITY := preload("res://scripts/cargo/cargo_delivery_activity.gd")
const CARGO_CONTRACT := preload("res://scripts/cargo/cargo_delivery_contract.gd")

var _host: CinderConvoyEscortHost
var _race_director: ActivityDirector
var _race_session: CinderTimedRaceSession
var _patrol_director: ActivityDirector
var _patrol: PatrolActivity
var _cargo_authority: CargoTransferAuthority
var _cargo_activity: CargoDeliveryActivity
var _cargo_source_handle: Dictionary
var _cargo_destination_handle: Dictionary


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	# The host normalises its display name while building, so resolve the
	# authored child by type after child-ready rather than relying on that name.
	_host = get_child(0) as CinderConvoyEscortHost
	_race_director = ActivityDirector.new()
	_race_director.name = "CinderBeaconRaceDirector"
	add_child(_race_director)
	_race_director.register_definition(RACE_ROUTE)
	_race_session = RACE_SESSION.new(1, 0.0, 120.0) as CinderTimedRaceSession
	_race_session.attach(_race_director, _race_session.get_session_generation())
	_patrol_director = ActivityDirector.new()
	_patrol_director.name = "CinderBeaconPatrolDirector"
	add_child(_patrol_director)
	_patrol_director.register_definition(RACE_ROUTE)
	_patrol = PATROL_ACTIVITY.new(RACE_ROUTE, 0.0) as PatrolActivity
	_patrol.attach(_patrol_director, _patrol.get_generation())
	_cargo_authority = CargoTransferAuthority.new()
	_cargo_authority.name = "CinderCargoTransferAuthority"
	add_child(_cargo_authority)
	var cargo_item := CargoItemDefinition.new()
	cargo_item.item_id = &"cinder_supply_crates"
	cargo_item.display_name = "Cinder supply crates"
	cargo_item.unit_capacity = 1
	_cargo_authority.register_item(cargo_item)
	var source := Node.new()
	source.name = "CinderCargoSource"
	add_child(source)
	var destination := Node.new()
	destination.name = "CinderCargoDestination"
	add_child(destination)
	var source_registration := _cargo_authority.register_entity(
		source, &"cinder_supply_tender", &"cinder_supply_manifest", 8,
		{&"cinder_supply_crates": 2}
	)
	var destination_registration := _cargo_authority.register_entity(
		destination, &"cinder_platform", &"cinder_platform_manifest", 8
	)
	_cargo_source_handle = source_registration.get("handle", {}).duplicate(true)
	_cargo_destination_handle = destination_registration.get("handle", {}).duplicate(true)
	var cargo_contract := CARGO_CONTRACT.new(
		&"cinder_platform_supply_run", _cargo_source_handle,
		_cargo_destination_handle, &"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0
	)
	_cargo_activity = CARGO_ACTIVITY.new(_cargo_authority, cargo_contract) as CargoDeliveryActivity


func start_convoy() -> Dictionary:
	if not is_inside_tree() or _host == null:
		return _result(false, &"not_ready")
	return _host.start(_host.get_generation())


func advance_convoy(delta: float, escort_position: Vector3) -> Dictionary:
	if not is_inside_tree() or _host == null:
		return _result(false, &"not_ready")
	return _host.advance_physics(delta, escort_position, _host.get_generation())


func reset_convoy() -> Dictionary:
	if not is_inside_tree() or _host == null:
		return _result(false, &"not_ready")
	return _host.reset(_host.get_generation())


func start_race() -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	return _race_session.start(_race_session.get_session_generation())


func advance_race(delta: float) -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	return _race_session.advance_physics(delta, _race_session.get_session_generation())


func submit_race_position(position: Vector3) -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	return _race_session.submit_position(position, _race_session.get_session_generation())


func reset_race() -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	return _race_session.reset(_race_session.get_session_generation())


func start_patrol() -> Dictionary:
	if not is_inside_tree() or _patrol == null:
		return _result(false, &"not_ready")
	return _patrol.start(_patrol.get_generation())


func advance_patrol(delta: float, position: Vector3) -> Dictionary:
	if not is_inside_tree() or _patrol == null:
		return _result(false, &"not_ready")
	return _patrol.advance_physics(delta, position, _patrol.get_generation())


func reset_patrol() -> Dictionary:
	if not is_inside_tree() or _patrol == null:
		return _result(false, &"not_ready")
	return _patrol.reset(_patrol.get_generation())


func start_cargo_run() -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	return _cargo_activity.start(_cargo_activity.get_generation())


func advance_cargo_run(delta: float) -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	return _cargo_activity.advance_physics(delta, _cargo_activity.get_generation())


func submit_cargo_phase(phase_id: StringName) -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	return _cargo_activity.submit_phase(phase_id, _cargo_activity.get_generation())


func reset_cargo_run() -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	return _cargo_activity.reset(_cargo_activity.get_generation())


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"host_instance_id": _host.get_instance_id() if is_instance_valid(_host) else 0,
		"host": _host.get_snapshot() if is_instance_valid(_host) else {},
		"race_activity_id": RACE_ACTIVITY_ID,
		"race": _race_session.get_presentation_snapshot() if is_instance_valid(_race_session) else {},
		"patrol": _patrol.get_presentation_snapshot() if is_instance_valid(_patrol) else {},
		"cargo": _cargo_activity.get_snapshot() if is_instance_valid(_cargo_activity) else {},
		"production_owner": true,
		"gameplay_authority": false,
		"game_flow_authority": false,
		"hud_authority": false,
		"network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not is_instance_valid(_host) or _host.get_parent() != self:
		errors.append("one authored convoy host is required")
	else:
		for point in _host.get_snapshot().get("route_positions", PackedVector3Array()):
			var position := point as Vector3
			if not position.is_finite() or position.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
				errors.append("convoy route leaves the authored cluster envelope")
				break
		if not bool(_host.audit().get("valid", false)):
			errors.append("convoy host audit failed")
	if not is_instance_valid(_race_session) or not bool(_race_session.audit().get("valid", false)):
		errors.append("authored beacon race audit failed")
	if not is_instance_valid(_patrol) or not bool(_patrol.audit().get("valid", false)):
		errors.append("authored beacon patrol audit failed")
	if not is_instance_valid(_cargo_activity) or not _cargo_activity.is_configuration_valid():
		errors.append("authored platform cargo run audit failed")
	for point in RACE_ROUTE.checkpoint_positions:
		if not point.is_finite() or point.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
			errors.append("beacon race route leaves the authored cluster envelope")
			break
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"race_activity_id": RACE_ACTIVITY_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"route_policy": &"existing_authored_convoy_route_only",
		"production_owner": true,
		"gameplay_authority": false,
		"game_flow_authority": false,
		"hud_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "snapshot": get_snapshot()}
