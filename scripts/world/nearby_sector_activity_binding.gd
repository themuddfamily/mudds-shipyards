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
const MINING_ACTIVITY := preload("res://scripts/world/cinder_mining_platform_activity.gd")
const SCAN_ACTIVITY := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")
const BEACON_ACTIVITY := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")
const REWARD_ADAPTER := preload("res://scripts/world/nearby_activity_reward_adapter.gd")
const SESSION_ADAPTER := preload("res://scripts/persistence/nearby_sector_activity_session_adapter.gd")
const PERSISTENCE_BINDING := preload("res://scripts/persistence/nearby_sector_activity_persistence_binding.gd")
const ENCOUNTER_DIRECTOR_SCRIPT_PATH := "res://scripts/combat/encounter_scenario_director.gd"

var _host: CinderConvoyEscortHost
var _race_director: ActivityDirector
var _race_session: CinderTimedRaceSession
var _patrol_director: ActivityDirector
var _patrol: PatrolActivity
var _cargo_authority: CargoTransferAuthority
var _cargo_activity: CargoDeliveryActivity
var _cargo_source_handle: Dictionary
var _cargo_destination_handle: Dictionary
var _station_director: Node
var _station_target: Node3D
var _station_anchor: Node3D
var _mining_activity: RefCounted
var _scan_activity: RefCounted
var _beacon_activity: RefCounted
var _session_adapter: RefCounted
var _persistence_binding: RefCounted
var _restored_session: Dictionary = {}
var _station_reward_adapter: RefCounted


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
	_mining_activity = MINING_ACTIVITY.new() as RefCounted
	_scan_activity = SCAN_ACTIVITY.new() as RefCounted
	_beacon_activity = BEACON_ACTIVITY.new() as RefCounted
	_session_adapter = SESSION_ADAPTER.new() as RefCounted


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


## Binds the existing EncounterScenarioDirector and caller-owned station anchor.
## The nearby cluster never creates combat sources or opponents; Main's existing
## encounter roster remains the sole station-defense authority.
func bind_station_defense(director: Node, target: Node3D, protected_anchor: Node3D) -> Dictionary:
	if not is_inside_tree() or director == null or target == null or protected_anchor == null:
		return _result(false, &"invalid_station_defense_binding")
	if director.get_script() == null or director.get_script().resource_path != ENCOUNTER_DIRECTOR_SCRIPT_PATH:
		return _result(false, &"wrong_encounter_authority")
	_station_director = director
	_station_target = target
	_station_anchor = protected_anchor
	return _result(true, &"station_defense_bound")


func start_station_defense() -> Dictionary:
	if not _station_binding_current():
		return _result(false, &"station_defense_unbound")
	var accepted := bool(_station_director.call("begin_station_defense", _station_target, _station_anchor))
	return _result(accepted, &"station_defense_started" if accepted else &"station_defense_rejected")


func reset_station_defense() -> Dictionary:
	if not _station_binding_current():
		return _result(false, &"station_defense_unbound")
	_station_director.call("abort")
	if _station_reward_adapter != null:
		_station_reward_adapter.call("reset")
	return _result(true, &"station_defense_reset")


func configure_station_defense_reward(
		reward_callback: Callable,
		reward_id: StringName = &"return_defense_report_to_shipyard"
	) -> Dictionary:
	if _station_reward_adapter != null:
		return _result(false, &"station_reward_already_configured")
	_station_reward_adapter = REWARD_ADAPTER.new() as RefCounted
	var result: Dictionary = _station_reward_adapter.call(
		"configure", reward_callback, &"shipyard_perimeter_defense", reward_id
	)
	if not bool(result.get("accepted", false)):
		_station_reward_adapter = null
	else:
		_station_reward_adapter.call(
			"register_activity", &"cinder_reach_emberline_convoy",
			&"return_convoy_credit_to_shipyard"
		)
	return result


func request_station_defense_reward(expected_generation: int) -> Dictionary:
	if not _station_binding_current() or _station_reward_adapter == null:
		return _result(false, &"station_defense_reward_unavailable")
	var snapshot := {
		"activity_id": &"shipyard_perimeter_defense",
		"state_id": _station_director.call("get_state"),
		"outcome": _station_director.call("get_outcome"),
		"generation": _station_director.call("get_scenario_generation"),
	}.duplicate(true)
	return _station_reward_adapter.call("consume", snapshot, expected_generation)


func get_station_defense_reward_snapshot() -> Dictionary:
	return _station_reward_adapter.call("get_snapshot") if _station_reward_adapter != null else {}


func request_convoy_reward(expected_generation: int) -> Dictionary:
	if _host == null or _station_reward_adapter == null:
		return _result(false, &"convoy_reward_unavailable")
	var activity := (_host.get_snapshot().get("activity", {}) as Dictionary)
	var normalized := {
		"activity_id": activity.get("activity_id", ACTIVITY_ID),
		"state_id": activity.get("state_id", &""),
		"outcome": &"cleared" if activity.get("terminal_result_id", &"") == &"safely_arrived" else &"",
		"generation": activity.get("generation", 0),
	}.duplicate(true)
	return _station_reward_adapter.call("consume", normalized, expected_generation)


func detach_station_defense_reward() -> Dictionary:
	if _station_reward_adapter == null:
		return _result(false, &"station_defense_reward_unavailable")
	return _station_reward_adapter.call("detach")


func reenter_station_defense_reward(attachment_generation: int) -> Dictionary:
	if _station_reward_adapter == null:
		return _result(false, &"station_defense_reward_unavailable")
	return _station_reward_adapter.call("reenter", attachment_generation)


func start_mining_activity(caller_position: Vector3) -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	return _mining_activity.call("start", caller_position)


func advance_mining_activity(delta: float) -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	return _mining_activity.call("advance_physics", delta)


func request_mining_reward() -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	return _mining_activity.call("request_reward")


func reset_mining_activity() -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	return _mining_activity.call("reset")


func start_structure_scan(caller_position: Vector3) -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	return _scan_activity.call("start", caller_position)


func advance_structure_scan(delta: float) -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	return _scan_activity.call("advance_physics", delta)


func request_structure_scan_reward() -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	return _scan_activity.call("request_reward")


func reset_structure_scan() -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	return _scan_activity.call("reset")


func start_beacon_traversal(caller_position: Vector3) -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	return _beacon_activity.call("start", caller_position)


func submit_beacon_traversal(index: int, caller_position: Vector3) -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	return _beacon_activity.call("submit_beacon", index, caller_position)


func request_beacon_traversal_reward() -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	return _beacon_activity.call("request_reward")


func reset_beacon_traversal() -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	return _beacon_activity.call("reset")


## Caller-owned persistence seam. Configuration does not read or write files;
## callers explicitly request each transaction through UserDataStore.
func configure_activity_persistence(store: RefCounted, slot_id: StringName) -> bool:
	if store == null or _session_adapter == null:
		return false
	_persistence_binding = PERSISTENCE_BINDING.new() as RefCounted
	return bool(_persistence_binding.call("configure", store, _session_adapter, slot_id))


func save_activity_session(expected_generation: int, commit_id: String) -> Dictionary:
	if _persistence_binding == null:
		return {"accepted": false, "reason": &"persistence_unconfigured"}
	return _persistence_binding.call("save", get_snapshot(), expected_generation, commit_id)


func load_activity_session() -> Dictionary:
	if _persistence_binding == null:
		return {"accepted": false, "reason": &"persistence_unconfigured"}
	var result: Dictionary = _persistence_binding.call("load")
	if bool(result.get("accepted", false)):
		_restored_session = (result.get("session", {}) as Dictionary).duplicate(true)
	return result


func get_restored_activity_session() -> Dictionary:
	return _restored_session.duplicate(true)


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
		"station_defense_bound": _station_binding_current(),
		"station_defense_state": (
			_station_director.call("get_state") if _station_binding_current() else &"unbound"
		),
		"station_defense_reward": get_station_defense_reward_snapshot(),
		"mining": _mining_activity.call("get_snapshot") if is_instance_valid(_mining_activity) else {},
		"structure_scan": _scan_activity.call("get_snapshot") if is_instance_valid(_scan_activity) else {},
		"beacon_traversal": _beacon_activity.call("get_snapshot") if is_instance_valid(_beacon_activity) else {},
		"restored_session": _restored_session.duplicate(true),
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
	if _station_binding_current() and not _station_director.has_method("begin_station_defense"):
		errors.append("station defense authority contract is incomplete")
	if not is_instance_valid(_mining_activity) or not bool(_mining_activity.call("audit").get("valid", false)):
		errors.append("authored mining platform activity audit failed")
	if not is_instance_valid(_scan_activity) or not bool(_scan_activity.call("audit").get("valid", false)):
		errors.append("authored abandoned structure scan audit failed")
	if not is_instance_valid(_beacon_activity) or not bool(_beacon_activity.call("audit").get("valid", false)):
		errors.append("authored beacon traversal audit failed")
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


func _station_binding_current() -> bool:
	return (
		is_instance_valid(_station_director)
		and is_instance_valid(_station_target)
		and is_instance_valid(_station_anchor)
		and _station_director.is_inside_tree()
		and _station_target.is_inside_tree()
		and _station_anchor.is_inside_tree()
	)
