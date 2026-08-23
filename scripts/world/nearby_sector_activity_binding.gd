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
const CARGO_REWARD_HANDOFF := preload("res://scripts/cargo/cinder_cargo_reward_handoff.gd")
const MINING_ACTIVITY := preload("res://scripts/world/cinder_mining_platform_activity.gd")
const SCAN_ACTIVITY := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")
const BEACON_ACTIVITY := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")
const CINDER_FIELD_AUDIO := preload("res://scripts/audio/cinder_field_activity_audio_binding.gd")
const CINDER_CARGO_TERMINAL_AUDIO := preload("res://scripts/audio/cinder_cargo_terminal_audio_binding.gd")
const REWARD_ADAPTER := preload("res://scripts/world/nearby_activity_reward_adapter.gd")
const SESSION_ADAPTER := preload("res://scripts/persistence/nearby_sector_activity_session_adapter.gd")
const PERSISTENCE_BINDING := preload("res://scripts/persistence/nearby_sector_activity_persistence_binding.gd")
const RACE_BEST_PERSISTENCE := preload("res://scripts/persistence/cinder_race_best_persistence.gd")
const SCAN_DISCOVERY_PERSISTENCE := preload(
	"res://scripts/persistence/cinder_scan_discovery_persistence.gd"
)
const ENCOUNTER_DIRECTOR_SCRIPT_PATH := "res://scripts/combat/encounter_scenario_director.gd"
const PRESENTATION_OBSERVER_LIMIT := 3
const CINDER_PATROL_DWELL_SECONDS := 2.0
const CINDER_RACE_COUNTDOWN_SECONDS := 3.0

var _host: CinderConvoyEscortHost
var _race_director: ActivityDirector
var _race_session: CinderTimedRaceSession
var _patrol_director: ActivityDirector
var _patrol: PatrolActivity
var _cargo_authority: CargoTransferAuthority
var _cargo_activity: CargoDeliveryActivity
var _cargo_reward_handoff: RefCounted
var _cargo_source_handle: Dictionary
var _cargo_destination_handle: Dictionary
var _cargo_access: CinderCargoAccess
var _cargo_terminal: CargoTransferTerminal
var _cargo_source_entity: Node
var _cargo_access_attachment_generation := 0
var _last_cargo_terminal_request: Dictionary = {}
var _station_director: Node
var _station_target: Node3D
var _station_anchor: Node3D
var _station_defense_snapshot_provider: Callable
var _mining_activity: RefCounted
var _scan_activity: RefCounted
var _beacon_activity: RefCounted
var _race_presentation_consumers: Array[Callable] = []
var _patrol_presentation_consumers: Array[Callable] = []
var _mining_presentation_consumers: Array[Callable] = []
var _structure_scan_presentation_consumers: Array[Callable] = []
var _beacon_traversal_presentation_consumers: Array[Callable] = []
var _session_adapter: RefCounted
var _persistence_binding: RefCounted
var _restored_session: Dictionary = {}
var _race_best_persistence: RefCounted
var _race_best_result: Dictionary = {}
var _last_race_best_persistence_result: Dictionary = {}
var _scan_discovery_persistence: RefCounted
var _restored_scan_discovery: Dictionary = {}
var _last_scan_discovery_persistence_result: Dictionary = {}
var _station_reward_adapter: RefCounted
var _cinder_field_audio: RefCounted
var _cinder_cargo_terminal_audio: RefCounted
var _last_race_feedback_reason: StringName = &""
var _last_patrol_feedback_reason: StringName = &""
var _last_patrol_reward_result: Dictionary = {}
var _last_beacon_feedback_reason: StringName = &""
var _last_beacon_reward_result: Dictionary = {}


func _enter_tree() -> void:
	if _mining_activity != null:
		call_deferred("_restore_presentation_observers_after_reentry")


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
	_race_session = RACE_SESSION.new(
		1, CINDER_RACE_COUNTDOWN_SECONDS, 120.0
	) as CinderTimedRaceSession
	_race_session.attach(_race_director, _race_session.get_session_generation())
	_race_session.session_completed.connect(_on_race_session_completed)
	_patrol_director = ActivityDirector.new()
	_patrol_director.name = "CinderBeaconPatrolDirector"
	add_child(_patrol_director)
	_patrol_director.register_definition(RACE_ROUTE)
	# A patrol is an inspection sweep rather than a second zero-dwell race.
	# Holding each authored beacon for two seconds gives the player a readable
	# station-keeping objective while PatrolActivity retains all route/dwell
	# authority.
	_patrol = PATROL_ACTIVITY.new(
		RACE_ROUTE, CINDER_PATROL_DWELL_SECONDS
	) as PatrolActivity
	_patrol.attach(_patrol_director, _patrol.get_generation())
	_cargo_authority = CargoTransferAuthority.new()
	_cargo_authority.name = "CinderCargoTransferAuthority"
	add_child(_cargo_authority)
	_cargo_authority.manifest_retired.connect(_on_cargo_manifest_retired)
	var cargo_item := CargoItemDefinition.new()
	cargo_item.item_id = &"cinder_supply_crates"
	cargo_item.display_name = "Cinder supply crates"
	cargo_item.unit_capacity = 1
	_cargo_authority.register_item(cargo_item)
	_mining_activity = MINING_ACTIVITY.new() as RefCounted
	_scan_activity = SCAN_ACTIVITY.new() as RefCounted
	_beacon_activity = BEACON_ACTIVITY.new() as RefCounted
	_session_adapter = SESSION_ADAPTER.new() as RefCounted
	_cinder_field_audio = CINDER_FIELD_AUDIO.new() as RefCounted
	_cinder_field_audio.attach()
	_cinder_cargo_terminal_audio = CINDER_CARGO_TERMINAL_AUDIO.new() as RefCounted
	_cinder_cargo_terminal_audio.attach()
	_bind_audio_presentation_observers()
	_publish_cinder_route_audio()
	call_deferred("_bind_production_station_defense_snapshot_provider")


func _exit_tree() -> void:
	_clear_presentation_observers()
	if _cinder_field_audio != null:
		_cinder_field_audio.detach()
	if _cinder_cargo_terminal_audio != null:
		_cinder_cargo_terminal_audio.detach()


func _restore_presentation_observers_after_reentry() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if _cinder_field_audio != null:
		_cinder_field_audio.attach(
			int(_cinder_field_audio.get_snapshot().get("generation", 0))
		)
	if _cinder_cargo_terminal_audio != null:
		_cinder_cargo_terminal_audio.attach(
			int(_cinder_cargo_terminal_audio.get_snapshot().get("generation", 0))
		)
	_bind_audio_presentation_observers()
	_publish_cinder_route_audio()


func _bind_audio_presentation_observers() -> void:
	bind_mining_presentation(Callable(self, "_on_mining_audio_snapshot"))
	bind_structure_scan_presentation(Callable(self, "_on_structure_scan_audio_snapshot"))
	bind_beacon_traversal_presentation(Callable(self, "_on_beacon_audio_snapshot"))


func _clear_presentation_observers() -> void:
	_race_presentation_consumers.clear()
	_patrol_presentation_consumers.clear()
	_mining_presentation_consumers.clear()
	_structure_scan_presentation_consumers.clear()
	_beacon_traversal_presentation_consumers.clear()


func get_cinder_field_audio_binding_snapshot() -> Dictionary:
	return _cinder_field_audio.get_snapshot() if _cinder_field_audio != null else {}

func get_cinder_cargo_terminal_audio_snapshot() -> Dictionary:
	return _cinder_cargo_terminal_audio.get_snapshot() if _cinder_cargo_terminal_audio != null else {}


func _on_mining_audio_snapshot(snapshot: Dictionary) -> void:
	_cinder_field_audio.present_activity_snapshot(snapshot)


func _on_structure_scan_audio_snapshot(snapshot: Dictionary) -> void:
	_cinder_field_audio.present_activity_snapshot(snapshot)


func _on_beacon_audio_snapshot(snapshot: Dictionary) -> void:
	_cinder_field_audio.present_activity_snapshot(snapshot)


func _on_beacon_audio_result(result: Dictionary) -> void:
	_cinder_field_audio.present_beacon_result(result)


func _publish_cinder_route_audio() -> void:
	if _cinder_field_audio == null:
		return
	if _race_session != null:
		_cinder_field_audio.present_activity_snapshot(
			(_race_session.get_presentation_snapshot() as Dictionary).duplicate(true)
		)
	if _patrol != null:
		_cinder_field_audio.present_activity_snapshot(
			(_patrol.get_presentation_snapshot() as Dictionary).duplicate(true)
		)


## Binds the production physical adapters to the one existing cargo authority.
## The destination can bind immediately; the source manifest is created only
## for the actual craft occupying the exact Cinder berth.
func bind_cargo_access(
		access: CinderCargoAccess,
		terminal: CargoTransferTerminal,
		expected_attachment_generation: int
	) -> Dictionary:
	if not is_inside_tree() or not is_instance_valid(_cargo_authority):
		return _result(false, &"cargo_authority_unavailable")
	if not is_instance_valid(access) or not is_instance_valid(terminal):
		return _result(false, &"cargo_physical_endpoint_required")
	var attachment := access.get_attachment_snapshot(expected_attachment_generation)
	if not bool(attachment.get("accepted", false)):
		return _result(false, StringName(attachment.get("reason", &"stale_attachment_generation")))
	if is_instance_valid(_cargo_access) or is_instance_valid(_cargo_terminal):
		if _cargo_access == access and _cargo_terminal == terminal:
			_cargo_access_attachment_generation = expected_attachment_generation
			_publish_cargo_presentation()
			return _result(true, &"cargo_access_already_bound")
		return _result(false, &"cargo_access_already_bound")
	var destination_registration := _cargo_authority.register_entity(
		terminal, terminal.terminal_id, terminal.manifest_id, 8
	)
	if not bool(destination_registration.get("accepted", false)):
		return _result(false, &"cargo_destination_registration_failed")
	var destination_handle := (
		destination_registration.get("handle", {}) as Dictionary
	).duplicate(true)
	var terminal_binding := terminal.bind_authority(
		_cargo_authority, destination_handle, terminal.get_terminal_generation()
	)
	if not bool(terminal_binding.get("accepted", false)):
		_cargo_authority.retire_entity(destination_handle)
		return _result(false, StringName(terminal_binding.get("reason", &"cargo_terminal_binding_failed")))
	_cargo_access = access
	_cargo_terminal = terminal
	_cargo_access_attachment_generation = expected_attachment_generation
	_cargo_destination_handle = destination_handle
	if not terminal.interaction_requested.is_connected(_on_cargo_terminal_interaction_requested):
		terminal.interaction_requested.connect(_on_cargo_terminal_interaction_requested)
	var berth := access.get_berth()
	if not berth.occupancy_changed.is_connected(_on_cargo_berth_occupancy_changed):
		berth.occupancy_changed.connect(_on_cargo_berth_occupancy_changed)
	var occupant := berth.get_occupant()
	if is_instance_valid(occupant):
		_on_cargo_berth_occupancy_changed(occupant)
	_publish_cargo_presentation()
	return _result(true, &"cargo_access_bound")


func get_cargo_transfer_authority() -> CargoTransferAuthority:
	return _cargo_authority if is_instance_valid(_cargo_authority) else null


func get_cargo_source_handle() -> Dictionary:
	return _cargo_source_handle.duplicate(true)


func get_cargo_destination_handle() -> Dictionary:
	return _cargo_destination_handle.duplicate(true)


func _on_cargo_berth_occupancy_changed(occupant: Node) -> void:
	if not is_instance_valid(occupant) or not _cargo_source_handle.is_empty():
		return
	if not occupant.has_method("get_ship_id") \
		or StringName(occupant.call("get_ship_id")) != &"jovian_provisional":
		return
	var source_registration := _cargo_authority.register_entity(
		occupant, &"jovian_provisional", &"cinder_jovian_source_manifest", 8,
		{&"cinder_supply_crates": 2}
	)
	if not bool(source_registration.get("accepted", false)):
		return
	_cargo_source_entity = occupant
	_cargo_source_handle = (
		source_registration.get("handle", {}) as Dictionary
	).duplicate(true)
	var cargo_contract := CARGO_CONTRACT.new(
		&"cinder_platform_supply_run", _cargo_source_handle,
		_cargo_destination_handle, &"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0
	)
	_cargo_activity = CARGO_ACTIVITY.new(
		_cargo_authority, cargo_contract
	) as CargoDeliveryActivity
	_bind_cargo_reward_handoff()
	_publish_cargo_presentation()


func _on_cargo_manifest_retired(handle: Dictionary) -> void:
	if handle != _cargo_source_handle:
		return
	_cargo_source_handle.clear()
	_cargo_source_entity = null
	if _cargo_reward_handoff != null:
		_cargo_reward_handoff.detach()
		_cargo_reward_handoff = null
	_cargo_activity = null
	_publish_cargo_presentation()


func _on_cargo_terminal_interaction_requested(actor: Node, snapshot: Dictionary) -> void:
	_last_cargo_terminal_request = _submit_cargo_terminal_request(actor, snapshot)
	_publish_cargo_presentation(_last_cargo_terminal_request)


func _submit_cargo_terminal_request(actor: Node, snapshot: Dictionary) -> Dictionary:
	if not is_instance_valid(_cargo_terminal) or not is_instance_valid(_cargo_access):
		return _cargo_terminal_result(false, &"cargo_physical_endpoint_required")
	if (
		StringName(snapshot.get("terminal_id", &"")) != _cargo_terminal.terminal_id
		or int(snapshot.get("terminal_generation", -1)) \
			!= _cargo_terminal.get_terminal_generation()
	):
		return _cargo_terminal_result(false, &"stale_terminal_generation")
	if not is_instance_valid(_cargo_source_entity):
		return _cargo_terminal_result(false, &"cargo_source_unavailable")
	var actor_validation := _cargo_access.validate_terminal_actor(
		actor, _cargo_source_entity, _cargo_access_attachment_generation
	)
	if not bool(actor_validation.get("accepted", false)):
		return _cargo_terminal_result(
			false, StringName(actor_validation.get("reason", &"wrong_terminal_actor"))
		)
	if not is_instance_valid(_cargo_activity):
		return _cargo_terminal_result(false, &"cargo_activity_unavailable")
	var delivered := _cargo_activity.submit_transfer(_cargo_activity.get_generation())
	if not bool(delivered.get("accepted", false)):
		return _cargo_terminal_result(
			false, StringName(delivered.get("reason", &"cargo_transfer_rejected")),
			delivered
		)
	return _cargo_terminal_result(true, &"cargo_terminal_delivery_committed", delivered)


func get_last_cargo_terminal_request() -> Dictionary:
	return _last_cargo_terminal_request.duplicate(true)


## Produces one detached presentation record from existing cargo activity,
## berth/source and terminal authority outputs. The visual consumers cannot
## mutate any of those owners.
func _publish_cargo_presentation(authority_record: Dictionary = {}) -> void:
	if not is_instance_valid(_cargo_access) or not is_instance_valid(_cargo_terminal):
		return
	var activity := (
		_cargo_activity.get_snapshot().duplicate(true)
		if is_instance_valid(_cargo_activity) else {}
	)
	var state_id: StringName = &"unavailable"
	if is_instance_valid(_cargo_source_entity) and not activity.is_empty():
		var activity_state := int(activity.get("state", CARGO_ACTIVITY.State.IDLE))
		if not authority_record.is_empty() and not bool(authority_record.get("accepted", true)):
			state_id = &"stale_rejected"
		elif activity_state == CARGO_ACTIVITY.State.COMPLETED:
			state_id = &"committed"
		elif activity_state in [CARGO_ACTIVITY.State.FAILED, CARGO_ACTIVITY.State.EXPIRED]:
			state_id = &"stale_rejected"
		elif activity_state == CARGO_ACTIVITY.State.ACTIVE:
			state_id = (
				&"at_terminal" if bool(activity.get("phases_complete", false)) else &"carrying"
			)
		elif StringName(authority_record.get("reason", &"")) == &"reset":
			state_id = &"reset"
		else:
			state_id = &"ready"
	var terminal_state := _cargo_terminal.get_state_snapshot()
	var detached := {
		"component_id": CinderCargoAccess.COMPONENT_ID,
		"terminal_id": _cargo_terminal.terminal_id,
		"attachment_generation": _cargo_access_attachment_generation,
		"terminal_generation": _cargo_terminal.get_terminal_generation(),
		"state_id": state_id,
		"activity": activity,
		"terminal": terminal_state,
		"authority_record": authority_record.duplicate(true),
		"source_available": is_instance_valid(_cargo_source_entity),
		"inventory_authority": false,
		"reward_authority": false,
		"interaction_authority": false,
	}.duplicate(true)
	_cargo_access.apply_cargo_presentation_snapshot(detached)
	_cargo_terminal.apply_cargo_presentation_snapshot(detached)
	if _cinder_cargo_terminal_audio != null:
		_cinder_cargo_terminal_audio.present_snapshot(detached)


func _cargo_terminal_result(
		accepted: bool,
		reason: StringName,
		delivery: Dictionary = {}
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"delivery": delivery.duplicate(true),
		"receipt": (delivery.get("receipt", {}) as Dictionary).duplicate(true),
		"inventory_authority": false,
		"reward_authority": false,
		"ship_motion_authority": false,
	}.duplicate(true)


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
	var result: Dictionary = _race_session.start(_race_session.get_session_generation())
	if bool(result.get("accepted", false)):
		_last_race_feedback_reason = &""
	_publish_race_presentation()
	_publish_cinder_route_audio()
	return result


func advance_race(delta: float) -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _race_session.advance_physics(delta, _race_session.get_session_generation())
	_publish_race_presentation()
	_publish_cinder_route_audio()
	return result


func submit_race_position(position: Vector3) -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	var result := _race_session.submit_position(
		position, _race_session.get_session_generation()
	)
	_last_race_feedback_reason = (
		&"" if bool(result.get("accepted", false))
		else StringName(result.get("reason", &""))
	)
	_publish_race_presentation()
	return result


func reset_race() -> Dictionary:
	if not is_inside_tree() or _race_session == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _race_session.reset(_race_session.get_session_generation())
	if bool(result.get("accepted", false)):
		_last_race_feedback_reason = &""
	_publish_race_presentation()
	_publish_cinder_route_audio()
	return result


func start_patrol() -> Dictionary:
	if not is_inside_tree() or _patrol == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _patrol.start(_patrol.get_generation())
	if bool(result.get("accepted", false)):
		_last_patrol_feedback_reason = &""
		_last_patrol_reward_result.clear()
	_publish_patrol_presentation(result)
	_publish_cinder_route_audio()
	return result


func advance_patrol(delta: float, position: Vector3) -> Dictionary:
	if not is_inside_tree() or _patrol == null:
		return _result(false, &"not_ready")
	# This is the production caller seam, so translate arrival samples before
	# advancing dwell. Previously no public binding method submitted an arrival;
	# callers could start the patrol but could never leave its first travel leg.
	var before := _patrol.get_presentation_snapshot()
	if before.get("state_id", &"") == &"active" \
		and before.get("phase_id", &"") == &"travel":
		_patrol.submit_position(position, _patrol.get_generation())
	var result: Dictionary = _patrol.advance_physics(delta, position, _patrol.get_generation())
	var reason := StringName(result.get("reason", &""))
	var after := _patrol.get_presentation_snapshot()
	if reason == &"dwell_interrupted":
		_last_patrol_feedback_reason = reason
	elif bool(after.get("checkpoint_occupied", false)) \
			or reason == &"dwell_completed" or after.get("phase_id", &"") == &"travel":
		_last_patrol_feedback_reason = &""
	_publish_patrol_presentation(result)
	_publish_cinder_route_audio()
	return result


func reset_patrol() -> Dictionary:
	if not is_inside_tree() or _patrol == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _patrol.reset(_patrol.get_generation())
	if bool(result.get("accepted", false)):
		_last_patrol_feedback_reason = &""
		_last_patrol_reward_result.clear()
	_publish_patrol_presentation(result)
	_publish_cinder_route_audio()
	return result


func bind_patrol_presentation(consumer: Callable) -> Dictionary:
	var current := _patrol_presentation_snapshot() if _patrol != null else {}
	return _bind_presentation_observer(
		_patrol_presentation_consumers, consumer, current, &"patrol"
	)


func unbind_patrol_presentation(consumer: Callable) -> Dictionary:
	return _unbind_presentation_observer(
		_patrol_presentation_consumers, consumer, &"patrol"
	)


func _publish_patrol_presentation(authority_record: Dictionary = {}) -> void:
	if _patrol == null:
		return
	var detached := authority_record.duplicate(true)
	if detached.is_empty():
		detached = _patrol_presentation_snapshot()
	detached["presentation_reason"] = _last_patrol_feedback_reason
	_publish_presentation_observers(_patrol_presentation_consumers, detached)


func start_cargo_run() -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	var result := _cargo_activity.start(_cargo_activity.get_generation())
	_publish_cargo_presentation(result)
	return result


func advance_cargo_run(delta: float) -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	var result := _cargo_activity.advance_physics(delta, _cargo_activity.get_generation())
	_publish_cargo_presentation(result)
	return result


func submit_cargo_phase(phase_id: StringName) -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	var result := _cargo_activity.submit_phase(phase_id, _cargo_activity.get_generation())
	_publish_cargo_presentation(result)
	return result


func reset_cargo_run() -> Dictionary:
	if not is_inside_tree() or _cargo_activity == null:
		return _result(false, &"not_ready")
	var result := _cargo_activity.reset(_cargo_activity.get_generation())
	if bool(result.get("accepted", false)) and _cargo_reward_handoff != null:
		_cargo_reward_handoff.reset(int(result.get("generation", 0)))
	_publish_cargo_presentation(result)
	return result


func abort_cargo_run(expected_generation: int) -> Dictionary:
	if not is_instance_valid(_cargo_activity):
		return _result(false, &"not_ready")
	var result := _cargo_activity.fail(&"embodied_transfer_aborted", expected_generation)
	_publish_cargo_presentation(result)
	return result


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


## Presentation-only seam for the production StationDefenseEncounterContent.
## The provider remains the authority and is sampled only when a detached HUD
## snapshot is requested; this binding never advances combat or activity state.
func bind_station_defense_snapshot_provider(provider: Callable) -> Dictionary:
	if not provider.is_valid():
		return _result(false, &"invalid_station_defense_snapshot_provider")
	var candidate: Variant = provider.call()
	if not candidate is Dictionary or not (candidate as Dictionary).has("host"):
		return _result(false, &"invalid_station_defense_snapshot")
	_station_defense_snapshot_provider = provider
	return _result(true, &"station_defense_snapshot_provider_bound")


## The streamed cluster and ShipyardWorld are composed beneath the same Main.
## Resolve that authored sibling once per loaded cluster generation; HUD reads
## remain detached Callable snapshots and never search or poll the scene tree.
func _bind_production_station_defense_snapshot_provider() -> void:
	if _station_defense_snapshot_provider.is_valid() or not is_inside_tree():
		return
	var ancestor := get_parent()
	while ancestor != null:
		var content := ancestor.get_node_or_null(
			^"ShipyardWorld/StationDefenseEncounter"
		)
		if is_instance_valid(content) and content.has_method(&"get_snapshot"):
			bind_station_defense_snapshot_provider(Callable(content, &"get_snapshot"))
			return
		ancestor = ancestor.get_parent()


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
		_station_reward_adapter.call(
			"register_activity", &"cinder_kit_cargo_run",
			&"return_fabrication_kits_to_shipyard"
		)
		_bind_cargo_reward_handoff()
		_station_reward_adapter.call(
			"register_activity", &"cinder_relay_patrol",
			&"return_patrol_log_to_shipyard"
		)
		_station_reward_adapter.call(
			"register_activity", RACE_ACTIVITY_ID,
			&"return_race_record_to_shipyard"
		)
		_station_reward_adapter.call(
			"register_activity", BEACON_ACTIVITY.ACTIVITY_ID,
			BEACON_ACTIVITY.REWARD_ID
		)
	return result


func configure_cargo_reward_handoff(reward_callback: Callable) -> Dictionary:
	return configure_station_defense_reward(reward_callback)


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


func request_cargo_reward(expected_generation: int) -> Dictionary:
	if _cargo_activity == null or _station_reward_adapter == null:
		return _result(false, &"cargo_reward_unavailable")
	_bind_cargo_reward_handoff()
	if _cargo_reward_handoff == null:
		return _result(false, &"cargo_reward_unavailable")
	return _cargo_reward_handoff.request(expected_generation)


func get_cargo_reward_handoff_snapshot() -> Dictionary:
	return (
		_cargo_reward_handoff.get_snapshot()
		if _cargo_reward_handoff != null else {}
	)


func _bind_cargo_reward_handoff() -> void:
	if _cargo_reward_handoff != null or _cargo_activity == null \
			or _station_reward_adapter == null:
		return
	var handoff := CARGO_REWARD_HANDOFF.new() as RefCounted
	var attached: Dictionary = handoff.call(
		&"attach", _cargo_activity, _station_reward_adapter
	)
	if bool(attached.get("accepted", false)):
		_cargo_reward_handoff = handoff


func request_patrol_reward(expected_generation: int) -> Dictionary:
	if _patrol == null or _station_reward_adapter == null:
		return _result(false, &"patrol_reward_unavailable")
	var patrol := _patrol.get_presentation_snapshot()
	var normalized := {
		"activity_id": &"cinder_relay_patrol",
		"state_id": patrol.get("state_id", &""),
		"outcome": &"cleared" if patrol.get("state_id", &"") == &"completed" else &"",
		"generation": patrol.get("generation", 0),
	}.duplicate(true)
	var result := _station_reward_adapter.call("consume", normalized, expected_generation) as Dictionary
	_last_patrol_reward_result = result.duplicate(true)
	return result


func request_race_reward(expected_generation: int) -> Dictionary:
	if _race_session == null or _station_reward_adapter == null:
		return _result(false, &"race_reward_unavailable")
	var race := _race_session.get_presentation_snapshot()
	var normalized := {
		"activity_id": RACE_ACTIVITY_ID,
		"state_id": race.get("state_id", &""),
		"outcome": &"cleared" if race.get("state_id", &"") == &"completed" else &"",
		"generation": race.get("activity_generation", 0),
	}.duplicate(true)
	var result := _station_reward_adapter.call(
		"consume", normalized, expected_generation
	) as Dictionary
	if bool(result.get("accepted", false)):
		_persist_race_best_result(true)
		_publish_race_presentation()
	return result


## Composes the retained race with GameFlow's existing atomic store. Restore is
## presentation-only: no completed/running session or transient generation is
## recreated, so a saved completion cannot be presented to reward authority.
func configure_cinder_race_best_persistence(
		store: RefCounted, slot_id: StringName = &"cinder_race_best_result"
	) -> Dictionary:
	if _race_best_persistence != null:
		return _result(true, &"race_best_persistence_already_configured")
	var persistence := RACE_BEST_PERSISTENCE.new() as RefCounted
	var configured := persistence.call(&"configure", store, slot_id) as Dictionary
	if not bool(configured.get("accepted", false)):
		return configured
	_race_best_persistence = persistence
	var restored := persistence.call(&"load") as Dictionary
	if bool(restored.get("accepted", false)):
		_race_best_result = (
			restored.get("best_result", {}) as Dictionary
		).duplicate(true)
		_last_race_best_persistence_result = restored.duplicate(true)
		_publish_race_presentation()
	elif StringName(restored.get("reason", &"")) != &"race_best_not_found":
		_last_race_best_persistence_result = restored.duplicate(true)
		return restored
	return configured


func get_cinder_race_best_persistence_snapshot() -> Dictionary:
	return {
		"configured": _race_best_persistence != null,
		"best_result": _race_best_result.duplicate(true),
		"last_result": _last_race_best_persistence_result.duplicate(true),
		"restores_activity_authority": false,
		"restores_reward_authority": false,
	}.duplicate(true)


func _on_race_session_completed(snapshot: Dictionary) -> void:
	_capture_race_best_result(snapshot)
	_persist_race_best_result(false)


func _capture_race_best_result(snapshot: Dictionary) -> void:
	if StringName(snapshot.get("state_id", &"")) != &"completed":
		return
	var time := float(snapshot.get("last_time_seconds", -1.0))
	var penalty := float(snapshot.get("penalty_seconds", 0.0))
	if not is_finite(time) or time <= 0.0 or time > 86_400.0 \
			or not is_finite(penalty) or penalty < 0.0 or penalty > time:
		return
	var previous_time := float(_race_best_result.get("time_seconds", INF))
	if time >= previous_time:
		return
	_race_best_result = {
		"activity_id": String(RACE_ACTIVITY_ID),
		"time_seconds": time,
		"penalty_seconds": penalty,
		"reward_receipt": {},
	}.duplicate(true)


func _persist_race_best_result(reward_consumed: bool) -> void:
	if _race_best_persistence == null or _race_best_result.is_empty():
		return
	if reward_consumed:
		var race := _race_session.get_presentation_snapshot() as Dictionary
		if is_equal_approx(
			float(race.get("last_time_seconds", -1.0)),
			float(_race_best_result.get("time_seconds", -2.0))
		):
			_race_best_result["reward_receipt"] = {
				"activity_id": String(RACE_ACTIVITY_ID),
				"reward_id": "return_race_record_to_shipyard",
				"replay_allowed": false,
			}
	var store_generation := int(_race_best_persistence.call(&"get_store_generation")) \
		if _race_best_persistence.has_method(&"get_store_generation") else 0
	var commit_id := "cinder-race-best-%010d" % (store_generation + 1)
	_last_race_best_persistence_result = _race_best_persistence.call(
		&"save", _race_best_result, commit_id
	) as Dictionary


func request_beacon_reward(expected_generation: int) -> Dictionary:
	if _beacon_activity == null or _station_reward_adapter == null:
		return _result(false, &"beacon_reward_unavailable")
	var beacon := _beacon_activity.call("get_snapshot") as Dictionary
	var normalized := {
		"activity_id": BEACON_ACTIVITY.ACTIVITY_ID,
		"state_id": &"complete" if int(beacon.get("state", -1)) == BEACON_ACTIVITY.State.COMPLETE else &"",
		"outcome": &"cleared" if int(beacon.get("state", -1)) == BEACON_ACTIVITY.State.COMPLETE else &"",
		"generation": beacon.get("generation", 0),
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
	var result: Dictionary = _mining_activity.call("start", caller_position)
	_publish_mining_presentation()
	return result


func advance_mining_activity(delta: float) -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _mining_activity.call("advance_physics", delta)
	_publish_mining_presentation()
	return result


func request_mining_reward() -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _mining_activity.call("request_reward")
	_publish_mining_presentation()
	return result


func reset_mining_activity() -> Dictionary:
	if _mining_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _mining_activity.call("reset")
	_publish_mining_presentation()
	return result


## Presentation-only observer seam for the existing retained Cinder race gates.
## The timed race remains the sole checkpoint/order owner; consumers receive a
## detached current snapshot on registration and after every race state commit.
func bind_race_presentation(consumer: Callable) -> Dictionary:
	return _bind_presentation_observer(
		_race_presentation_consumers, consumer, _race_presentation_snapshot(), &"race"
	)


func unbind_race_presentation(consumer: Callable) -> Dictionary:
	return _unbind_presentation_observer(
		_race_presentation_consumers, consumer, &"race"
	)


func _publish_race_presentation() -> void:
	if _race_session == null:
		return
	_publish_presentation_observers(
		_race_presentation_consumers, _race_presentation_snapshot()
	)


## Presentation-only observer seam. MiningActivity remains the sole state and
## reward-request owner; each bounded observer receives one detached current
## snapshot on registration and one detached snapshot after every state commit.
func bind_mining_presentation(consumer: Callable) -> Dictionary:
	var current := (
		(_mining_activity.call("get_snapshot") as Dictionary).duplicate(true)
		if _mining_activity != null else {}
	)
	return _bind_presentation_observer(
		_mining_presentation_consumers, consumer, current, &"mining"
	)


func unbind_mining_presentation(consumer: Callable) -> Dictionary:
	return _unbind_presentation_observer(
		_mining_presentation_consumers, consumer, &"mining"
	)


func _publish_mining_presentation() -> void:
	if _mining_activity == null:
		return
	_publish_presentation_observers(
		_mining_presentation_consumers,
		_mining_activity.call("get_snapshot") as Dictionary
	)


func start_structure_scan(caller_position: Vector3) -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _scan_activity.call("start", caller_position)
	_publish_structure_scan_presentation()
	return result


func advance_structure_scan(delta: float) -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _scan_activity.call("advance_physics", delta)
	_publish_structure_scan_presentation()
	return result


func request_structure_scan_reward() -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _scan_activity.call("request_reward")
	if bool(result.get("accepted", false)):
		_persist_structure_scan_discovery(result)
	_publish_structure_scan_presentation()
	_cinder_field_audio.present_reward_result(result)
	return result


func reset_structure_scan() -> Dictionary:
	if _scan_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _scan_activity.call("reset")
	_publish_structure_scan_presentation()
	return result


func bind_structure_scan_presentation(consumer: Callable) -> Dictionary:
	return _bind_presentation_observer(
		_structure_scan_presentation_consumers, consumer,
		_structure_scan_presentation_snapshot(), &"structure_scan"
	)


func unbind_structure_scan_presentation(consumer: Callable) -> Dictionary:
	return _unbind_presentation_observer(
		_structure_scan_presentation_consumers, consumer, &"structure_scan"
	)


func _publish_structure_scan_presentation() -> void:
	if _scan_activity == null:
		return
	_publish_presentation_observers(
		_structure_scan_presentation_consumers,
		_structure_scan_presentation_snapshot()
	)


## Restores one terminal discovery receipt into presentation only. The scan
## authority remains idle after reload, so its one-shot reward request cannot
## be reconstructed or replayed.
func configure_cinder_scan_discovery_persistence(
		store: RefCounted, slot_id: StringName = &"cinder_scan_discovery"
	) -> Dictionary:
	if _scan_discovery_persistence != null:
		return _result(true, &"scan_discovery_persistence_already_configured")
	var persistence := SCAN_DISCOVERY_PERSISTENCE.new() as RefCounted
	var configured := persistence.call(&"configure", store, slot_id) as Dictionary
	if not bool(configured.get("accepted", false)):
		return configured
	_scan_discovery_persistence = persistence
	var restored := persistence.call(&"load") as Dictionary
	if bool(restored.get("accepted", false)):
		_restored_scan_discovery = (
			restored.get("discovery", {}) as Dictionary
		).duplicate(true)
		_last_scan_discovery_persistence_result = restored.duplicate(true)
		_publish_structure_scan_presentation()
	elif StringName(restored.get("reason", &"")) != &"scan_discovery_not_found":
		_last_scan_discovery_persistence_result = restored.duplicate(true)
		return restored
	return configured


func get_cinder_scan_discovery_persistence_snapshot() -> Dictionary:
	return {
		"configured": _scan_discovery_persistence != null,
		"discovery": _restored_scan_discovery.duplicate(true),
		"last_result": _last_scan_discovery_persistence_result.duplicate(true),
		"restores_activity_authority": false,
		"restores_reward_authority": false,
	}.duplicate(true)


func _persist_structure_scan_discovery(reward_result: Dictionary) -> void:
	if _scan_discovery_persistence == null:
		return
	var scan := _scan_activity.call("get_snapshot") as Dictionary
	var commit_id := "cinder-scan-discovery-%010d" % (
		int(_scan_discovery_persistence.call(&"get_store_generation")) + 1
	)
	_last_scan_discovery_persistence_result = _scan_discovery_persistence.call(
		&"save", scan, reward_result, commit_id
	) as Dictionary
	if bool(_last_scan_discovery_persistence_result.get("accepted", false)):
		var receipt := reward_result.get("reward_request", {}) as Dictionary
		_restored_scan_discovery = {
			"activity_id": String(SCAN_ACTIVITY.ACTIVITY_ID),
			"content_class": String(SCAN_ACTIVITY.CONTENT_CLASS),
			"evidence_status": String(SCAN_ACTIVITY.EVIDENCE_STATUS),
			"scan_seconds": float(scan.get("scan_seconds", 0.0)),
			"reward_receipt": {
				"activity_id": String(receipt.get("activity_id", &"")),
				"reward_id": String(receipt.get("reward_id", &"")),
				"granted": false,
				"replay_allowed": false,
			},
		}.duplicate(true)


func start_beacon_traversal(caller_position: Vector3) -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _beacon_activity.call("start", caller_position)
	if bool(result.get("accepted", false)):
		_last_beacon_feedback_reason = &""
		_last_beacon_reward_result.clear()
	_publish_beacon_traversal_presentation(result)
	return result


func submit_beacon_traversal(index: int, caller_position: Vector3) -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _beacon_activity.call("submit_beacon", index, caller_position)
	_last_beacon_feedback_reason = (
		&"" if bool(result.get("accepted", false))
		else StringName(result.get("reason", &""))
	)
	_publish_beacon_traversal_presentation(result)
	return result


func request_beacon_traversal_reward() -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _beacon_activity.call("request_reward")
	_last_beacon_reward_result = result.duplicate(true)
	_publish_beacon_traversal_presentation(result)
	_cinder_field_audio.present_reward_result(result)
	return result


func reset_beacon_traversal() -> Dictionary:
	if _beacon_activity == null:
		return _result(false, &"not_ready")
	var result: Dictionary = _beacon_activity.call("reset")
	if bool(result.get("accepted", false)):
		_last_beacon_feedback_reason = &""
		_last_beacon_reward_result.clear()
	_publish_beacon_traversal_presentation(result)
	return result


func bind_beacon_traversal_presentation(consumer: Callable) -> Dictionary:
	var current := (
		_beacon_traversal_presentation_snapshot()
		if _beacon_activity != null else {}
	)
	return _bind_presentation_observer(
		_beacon_traversal_presentation_consumers, consumer, current, &"beacon_traversal"
	)


func unbind_beacon_traversal_presentation(consumer: Callable) -> Dictionary:
	return _unbind_presentation_observer(
		_beacon_traversal_presentation_consumers, consumer, &"beacon_traversal"
	)


func _publish_beacon_traversal_presentation(authority_record: Dictionary = {}) -> void:
	if _beacon_activity == null:
		return
	var detached := authority_record.duplicate(true)
	if detached.is_empty():
		detached = (_beacon_activity.call("get_snapshot") as Dictionary).duplicate(true)
	_publish_presentation_observers(_beacon_traversal_presentation_consumers, detached)
	if not authority_record.is_empty():
		_on_beacon_audio_result(authority_record)


func get_presentation_observer_snapshot() -> Dictionary:
	_prune_invalid_presentation_observers(_race_presentation_consumers)
	_prune_invalid_presentation_observers(_patrol_presentation_consumers)
	_prune_invalid_presentation_observers(_mining_presentation_consumers)
	_prune_invalid_presentation_observers(_structure_scan_presentation_consumers)
	_prune_invalid_presentation_observers(_beacon_traversal_presentation_consumers)
	return {
		"observer_limit": PRESENTATION_OBSERVER_LIMIT,
		"race_observers": _race_presentation_consumers.size(),
		"patrol_observers": _patrol_presentation_consumers.size(),
		"mining_observers": _mining_presentation_consumers.size(),
		"structure_scan_observers": _structure_scan_presentation_consumers.size(),
		"beacon_traversal_observers": _beacon_traversal_presentation_consumers.size(),
		"activity_authority": false,
		"reward_authority": false,
		"audio_authority": false,
		"visual_authority": false,
	}.duplicate(true)


func _bind_presentation_observer(
		observers: Array[Callable],
		consumer: Callable,
		current_snapshot: Dictionary,
		channel_id: StringName
	) -> Dictionary:
	_prune_invalid_presentation_observers(observers)
	if not consumer.is_valid():
		return _presentation_observer_result(false, channel_id, &"invalid_observer", false)
	if observers.has(consumer):
		return _presentation_observer_result(false, channel_id, &"observer_already_bound", false)
	if observers.size() >= PRESENTATION_OBSERVER_LIMIT:
		return _presentation_observer_result(false, channel_id, &"observer_limit_reached", false)
	if current_snapshot.is_empty():
		return _presentation_observer_result(false, channel_id, &"presentation_unavailable", false)
	observers.append(consumer)
	consumer.call(current_snapshot.duplicate(true))
	return _presentation_observer_result(true, channel_id, &"observer_bound", true)


func _unbind_presentation_observer(
		observers: Array[Callable], consumer: Callable, channel_id: StringName
	) -> Dictionary:
	_prune_invalid_presentation_observers(observers)
	var observer_index := observers.find(consumer)
	if observer_index < 0:
		return _presentation_observer_result(false, channel_id, &"observer_not_bound", false)
	observers.remove_at(observer_index)
	return _presentation_observer_result(true, channel_id, &"observer_unbound", false)


func _publish_presentation_observers(
		observers: Array[Callable], snapshot: Dictionary
	) -> void:
	_prune_invalid_presentation_observers(observers)
	for observer in observers:
		observer.call(snapshot.duplicate(true))


func _prune_invalid_presentation_observers(observers: Array[Callable]) -> void:
	for observer_index in range(observers.size() - 1, -1, -1):
		if not observers[observer_index].is_valid():
			observers.remove_at(observer_index)


func _presentation_observer_result(
		accepted: bool,
		channel_id: StringName,
		reason: StringName,
		initial_snapshot_delivered: bool
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"channel_id": channel_id,
		"initial_snapshot_delivered": initial_snapshot_delivered,
		"observer_limit": PRESENTATION_OBSERVER_LIMIT,
		"activity_authority": false,
		"reward_authority": false,
		"audio_authority": false,
		"visual_authority": false,
		"snapshot": get_snapshot(),
	}.duplicate(true)


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
		"race": _race_presentation_snapshot(),
		"patrol": _patrol_presentation_snapshot(),
		"cargo": _cargo_presentation_snapshot(),
		"cargo_reward_handoff": get_cargo_reward_handoff_snapshot(),
		"cargo_binding": {
			"access_bound": is_instance_valid(_cargo_access),
			"access_attachment_generation": _cargo_access_attachment_generation,
			"terminal_bound": (
				bool(_cargo_terminal.get_state_snapshot().get("bound", false))
				if is_instance_valid(_cargo_terminal) else false
			),
			"terminal_ready": (
				bool(_cargo_terminal.get_state_snapshot().get("ready", false))
				if is_instance_valid(_cargo_terminal) else false
			),
			"source_entity_instance_id": (
				_cargo_source_entity.get_instance_id()
				if is_instance_valid(_cargo_source_entity) else 0
			),
			"source_handle": _cargo_source_handle.duplicate(true),
			"destination_handle": _cargo_destination_handle.duplicate(true),
			"authority_instance_id": (
				_cargo_authority.get_instance_id()
				if is_instance_valid(_cargo_authority) else 0
			),
			"inventory_authority": false,
			"ship_motion_authority": false,
			"reward_authority": false,
		},
		"station_defense_bound": _station_binding_current(),
		"station_defense_state": (
			_station_director.call("get_state") if _station_binding_current() else &"unbound"
		),
		"station_defense_reward": get_station_defense_reward_snapshot(),
		"station_defense": _station_defense_presentation_snapshot(),
		"mining": _mining_activity.call("get_snapshot") if is_instance_valid(_mining_activity) else {},
		"structure_scan": _structure_scan_presentation_snapshot(),
		"beacon_traversal": _beacon_traversal_presentation_snapshot(),
		"restored_session": _restored_session.duplicate(true),
		"production_owner": true,
		"gameplay_authority": false,
		"game_flow_authority": false,
		"hud_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _station_defense_presentation_snapshot() -> Dictionary:
	if not _station_defense_snapshot_provider.is_valid():
		return {}
	var content_variant: Variant = _station_defense_snapshot_provider.call()
	if not content_variant is Dictionary:
		return {}
	var content := content_variant as Dictionary
	var host := content.get("host", {}) as Dictionary
	var activity := (host.get("activity", {}) as Dictionary).duplicate(true)
	if activity.is_empty():
		return {}
	var generation := int(activity.get("generation", 0))
	var reward := get_station_defense_reward_snapshot()
	var request := reward.get("last_request", {}) as Dictionary
	activity["reward_pending"] = (
		generation > 0
		and int(request.get("activity_generation", -1)) == generation
		and StringName(request.get("activity_id", &"")) == &"shipyard_perimeter_defense"
	)
	activity["presentation_source"] = &"station_defense_encounter_content"
	activity["activity_authority"] = false
	activity["combat_authority"] = false
	activity["health_authority"] = false
	activity["reward_authority"] = false
	return activity.duplicate(true)


func _race_presentation_snapshot() -> Dictionary:
	if not is_instance_valid(_race_session):
		return {}
	var snapshot := _race_session.get_presentation_snapshot() as Dictionary
	var live_best := float(snapshot.get("best_time_seconds", -1.0))
	var persisted_best := float(_race_best_result.get("time_seconds", -1.0))
	if persisted_best > 0.0 and (live_best <= 0.0 or persisted_best < live_best):
		snapshot["best_time_seconds"] = persisted_best
		snapshot["best_penalty_seconds"] = float(
			_race_best_result.get("penalty_seconds", 0.0)
		)
	snapshot["best_result_persisted"] = persisted_best > 0.0
	snapshot["best_reward_consumed"] = not (
		_race_best_result.get("reward_receipt", {}) as Dictionary
	).is_empty()
	snapshot["presentation_reason"] = _last_race_feedback_reason
	return snapshot.duplicate(true)


func _structure_scan_presentation_snapshot() -> Dictionary:
	if not is_instance_valid(_scan_activity):
		return {}
	var snapshot := _scan_activity.call("get_snapshot") as Dictionary
	if _restored_scan_discovery.is_empty():
		return snapshot.duplicate(true)
	var state := int(snapshot.get("state", SCAN_ACTIVITY.State.IDLE))
	var generation := int(snapshot.get("generation", 0))
	if state == SCAN_ACTIVITY.State.IDLE and generation == 0:
		var duration := float(_restored_scan_discovery.get(
			"scan_seconds", SCAN_ACTIVITY.SCAN_SECONDS
		))
		snapshot["state"] = SCAN_ACTIVITY.State.COMPLETE
		snapshot["state_id"] = &"complete"
		snapshot["elapsed_seconds"] = duration
		snapshot["scan_seconds"] = duration
		snapshot["progress_unitless"] = 1.0
	elif state != SCAN_ACTIVITY.State.COMPLETE:
		return snapshot.duplicate(true)
	snapshot["reward_requested"] = false
	snapshot["reward_pending"] = false
	snapshot["discovery_persisted"] = true
	snapshot["discovery_receipt"] = (
		_restored_scan_discovery.get("reward_receipt", {}) as Dictionary
	).duplicate(true)
	snapshot["receipt_replay_allowed"] = false
	snapshot["presentation_reason"] = &"discovery_restored"
	return snapshot.duplicate(true)


func _cargo_presentation_snapshot() -> Dictionary:
	if not is_instance_valid(_cargo_activity):
		return {}
	var snapshot := _cargo_activity.get_snapshot().duplicate(true)
	var handoff := get_cargo_reward_handoff_snapshot()
	var result := handoff.get("last_result", {}) as Dictionary
	snapshot["reward_pending"] = (
		int(snapshot.get("state", -1)) == CARGO_ACTIVITY.State.COMPLETED
		and int(handoff.get("completion_generation", -1)) == int(snapshot.get("generation", 0))
		and bool(result.get("accepted", false))
	)
	snapshot["reward_handoff_reason"] = StringName(result.get("reason", &""))
	return snapshot.duplicate(true)


func _patrol_presentation_snapshot() -> Dictionary:
	if not is_instance_valid(_patrol):
		return {}
	var snapshot := _patrol.get_presentation_snapshot() as Dictionary
	var request := _last_patrol_reward_result.get("reward_request", {}) as Dictionary
	var request_matches := (
		StringName(request.get("activity_id", &"")) == &"cinder_relay_patrol"
		and int(request.get("activity_generation", -1)) == int(snapshot.get("generation", 0))
	)
	snapshot["presentation_reason"] = _last_patrol_feedback_reason
	snapshot["reward_pending"] = (
		bool(_last_patrol_reward_result.get("accepted", false)) and request_matches
	)
	snapshot["reward_handoff_reason"] = StringName(
		_last_patrol_reward_result.get("reason", &"")
	)
	return snapshot.duplicate(true)


func _beacon_traversal_presentation_snapshot() -> Dictionary:
	if not is_instance_valid(_beacon_activity):
		return {}
	var snapshot := _beacon_activity.call("get_snapshot") as Dictionary
	var request := _last_beacon_reward_result.get("reward_request", {}) as Dictionary
	var request_matches := (
		StringName(request.get("activity_id", &"")) == BEACON_ACTIVITY.ACTIVITY_ID
		and int(request.get("generation", -1)) == int(snapshot.get("generation", 0))
	)
	snapshot["presentation_reason"] = _last_beacon_feedback_reason
	snapshot["reward_pending"] = (
		bool(_last_beacon_reward_result.get("accepted", false))
		and bool(snapshot.get("reward_requested", false)) and request_matches
	)
	return snapshot.duplicate(true)


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
	if not is_instance_valid(_cargo_authority) or _cargo_authority.get_parent() != self:
		errors.append("one existing cargo authority is required")
	if not is_instance_valid(_cargo_access) or not is_instance_valid(_cargo_terminal):
		errors.append("production cargo physical endpoints are required")
	elif (
		_cargo_destination_handle.is_empty()
		or not bool(_cargo_terminal.get_state_snapshot().get("bound", false))
	):
		errors.append("production cargo destination terminal is not bound")
	if is_instance_valid(_cargo_activity) and not _cargo_activity.is_configuration_valid():
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
