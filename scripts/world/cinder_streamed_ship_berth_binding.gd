class_name CinderStreamedShipBerthBinding
extends Node

## Production composition for one lifetime-stable StreamedShipBerthOverlay.
##
## Main owns this node beside the existing Cinder streaming bootstrap. It binds
## the overlay to that bootstrap's coordinator before the deferred streaming
## driver can request a load, and supplies the exact five resident ShipyardWorld
## IDs for collision-free merged reads. It does not add streamed content or
## change ShipyardWorld's physical registry.

const SCHEMA_VERSION := 1
const BOOTSTRAP_PATH := NodePath("../CinderStreamingBootstrap")
const WORLD_PATH := NodePath("../ShipyardWorld")
const COORDINATOR_PATH := NodePath("WorldStreamingCoordinator")
const RESIDENT_BERTH_IDS: Array[StringName] = [
	&"arrow_recon_berth",
	&"central_berth",
	&"halyard_fleet_dock_berth",
	&"jovian_freight_berth",
	&"zenith_fleet_dock_berth",
]

const AUTHORITY := {
	"renderer": false,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": false,
}
const ADJACENT_AUTHORITY := {
	"scene_tree_mutation": false,
	"berth_lease": false,
	"reservation": false,
	"occupancy": false,
	"ship_token": false,
	"landing": false,
	"ship_movement": false,
	"streaming_decision": false,
	"cargo": false,
	"route": false,
	"reward": false,
	"ui": false,
}

var _overlay := StreamedShipBerthOverlay.new()
var _bootstrap: CinderStreamingBootstrap
var _coordinator: WorldStreamingCoordinator
var _world: ShipyardWorld
var _configuration_attempted := false
var _configured := false
var _configuration_attempt_count := 0
var _configuration_success_count := 0
var _ready_count := 0
var _tree_exit_count := 0
var _configuration_result: Dictionary = {}
var _registration_signal_count := 0
var _retirement_signal_count := 0
var _last_registration: Dictionary = {}
var _last_retirement: Dictionary = {}


func _ready() -> void:
	_ready_count += 1
	if _configuration_attempted:
		return
	_configuration_attempted = true
	_configuration_attempt_count += 1
	_bootstrap = get_node_or_null(BOOTSTRAP_PATH) as CinderStreamingBootstrap
	_world = get_node_or_null(WORLD_PATH) as ShipyardWorld
	_coordinator = (
		_bootstrap.get_node_or_null(COORDINATOR_PATH) as WorldStreamingCoordinator
		if is_instance_valid(_bootstrap)
		else null
	)
	var preflight_error := _configuration_preflight_error()
	if not preflight_error.is_empty():
		_configuration_result = {
			"accepted": false,
			"reason": preflight_error,
		}.duplicate(true)
		return
	_overlay.location_registered.connect(_on_location_registered)
	_overlay.location_retired.connect(_on_location_retired)
	_configuration_result = _overlay.configure(
		_coordinator,
		PackedStringArray(RESIDENT_BERTH_IDS)
	).duplicate(true)
	_configured = bool(_configuration_result.get("accepted", false))
	if _configured:
		_configuration_success_count += 1


func _exit_tree() -> void:
	_tree_exit_count += 1


## Detached resident + streamed view for a later ShipyardWorld merge owner.
func get_merged_berth_snapshot() -> Dictionary:
	if not _configured:
		return {
			"schema_version": StreamedShipBerthOverlay.SCHEMA_VERSION,
			"resident_configured": false,
			"berth_ids": [],
			"entries": [],
		}.duplicate(true)
	return _overlay.get_merged_read_snapshot()


func lookup_streamed_berth_record(berth_id: StringName) -> Dictionary:
	if not _configured:
		return {
			"schema_version": StreamedShipBerthOverlay.SCHEMA_VERSION,
			"found": false,
			"berth_id": berth_id,
		}.duplicate(true)
	return _overlay.lookup_record(berth_id)


## The only live-capability seam. Callers must echo all primitive provenance
## from lookup_streamed_berth_record(), so reload cannot silently replace a
## consumer's berth identity.
func resolve_streamed_berth_node(
	location_id: StringName,
	load_generation: int,
	root_instance_id: int,
	berth_id: StringName,
	berth_instance_id: int
	) -> ShipBerth:
	if not _configured:
		return null
	return _overlay.resolve_berth_node(
		location_id,
		load_generation,
		root_instance_id,
		berth_id,
		berth_instance_id
	)


func get_snapshot() -> Dictionary:
	var overlay_snapshot := (
		_overlay.get_snapshot() if _configured else {}
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"configuration_attempted": _configuration_attempted,
		"configuration_attempt_count": _configuration_attempt_count,
		"configuration_success_count": _configuration_success_count,
		"configuration_result": _configuration_result.duplicate(true),
		"ready_count": _ready_count,
		"tree_exit_count": _tree_exit_count,
		"inside_tree": is_inside_tree(),
		"binding_instance_id": get_instance_id(),
		"bootstrap_instance_id": (
			_bootstrap.get_instance_id() if is_instance_valid(_bootstrap) else 0
		),
		"coordinator_instance_id": (
			_coordinator.get_instance_id() if is_instance_valid(_coordinator) else 0
		),
		"world_instance_id": (
			_world.get_instance_id() if is_instance_valid(_world) else 0
		),
		"resident_berth_ids": RESIDENT_BERTH_IDS.duplicate(),
		"registration_signal_count": _registration_signal_count,
		"retirement_signal_count": _retirement_signal_count,
		"last_registration": _last_registration.duplicate(true),
		"last_retirement": _last_retirement.duplicate(true),
		"merged_berths": get_merged_berth_snapshot(),
		"overlay": overlay_snapshot,
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var host := get_parent()
	var binding_count := 0
	if host != null:
		binding_count = host.find_children(
			"*", "CinderStreamedShipBerthBinding", true, false
		).size()
	if not _configuration_attempted or _configuration_attempt_count != 1:
		errors.append("binding must attempt configuration exactly once")
	if not _configured or _configuration_success_count != 1:
		errors.append(
			"binding configuration failed: %s"
			% String(_configuration_result.get("reason", &"not_attempted"))
		)
	if binding_count != 1:
		errors.append("Main must own exactly one Cinder streamed berth binding")
	if not is_instance_valid(_bootstrap) \
			or _bootstrap.get_parent() != host \
			or get_node_or_null(BOOTSTRAP_PATH) != _bootstrap:
		errors.append("Cinder bootstrap identity drifted")
	if not is_instance_valid(_world) \
			or _world.get_parent() != host \
			or get_node_or_null(WORLD_PATH) != _world:
		errors.append("ShipyardWorld identity drifted")
	elif _sorted_world_berth_ids() != RESIDENT_BERTH_IDS:
		errors.append("resident ShipyardWorld berth roster drifted")
	if not is_instance_valid(_coordinator) \
			or not is_instance_valid(_bootstrap) \
			or _coordinator.get_parent() != _bootstrap \
			or _bootstrap.get_node_or_null(COORDINATOR_PATH) != _coordinator:
		errors.append("Cinder coordinator identity drifted")
	if _configured:
		var overlay_audit := _overlay.audit()
		if not bool(overlay_audit.get("valid", false)):
			errors.append("streamed berth overlay audit is invalid")
		var overlay_snapshot := _overlay.get_snapshot()
		if not is_instance_valid(_coordinator) \
				or int(overlay_snapshot.get("coordinator_instance_id", 0)) \
				!= _coordinator.get_instance_id():
			errors.append("overlay coordinator identity drifted")
		if overlay_snapshot.get("resident_berth_ids") != RESIDENT_BERTH_IDS:
			errors.append("overlay resident berth roster drifted")
		_audit_live_cinder_observation(errors, overlay_snapshot)
	if not _overlay.location_registered.is_connected(_on_location_registered):
		errors.append("overlay registration observer disconnected")
	if not _overlay.location_retired.is_connected(_on_location_retired):
		errors.append("overlay retirement observer disconnected")
	if _registration_signal_count > int(
		(_overlay.get_snapshot() if _configured else {}).get(
			"loaded_observation_count", 0
		)
	):
		errors.append("registration signal count exceeds load observations")
	if _retirement_signal_count > int(
		(_overlay.get_snapshot() if _configured else {}).get(
			"unloaded_observation_count", 0
		)
	):
		errors.append("retirement signal count exceeds unload observations")
	if is_processing() or is_physics_processing():
		errors.append("binding must own no idle or physics process loop")
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"binding_count": binding_count,
		"zero_berth_load_policy": &"typed_no_ship_berths_no_registration",
		"zero_berth_unload_policy": &"typed_unknown_location_no_retirement",
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
	}.duplicate(true)


func _configuration_preflight_error() -> StringName:
	if not is_instance_valid(_bootstrap) or _bootstrap.get_parent() != get_parent():
		return &"invalid_cinder_bootstrap"
	if not bool(_bootstrap.audit().get("valid", false)):
		return &"invalid_cinder_bootstrap"
	if not is_instance_valid(_world) or _world.get_parent() != get_parent():
		return &"invalid_shipyard_world"
	if _sorted_world_berth_ids() != RESIDENT_BERTH_IDS:
		return &"resident_berth_roster_mismatch"
	if not is_instance_valid(_coordinator) or _coordinator.get_parent() != _bootstrap:
		return &"invalid_cinder_coordinator"
	if not _coordinator.get_loaded_ids().is_empty() \
			or not _coordinator.get_loading_ids().is_empty():
		return &"coordinator_not_quiescent"
	if int(_coordinator.audit().get("load_request_count", -1)) != 0:
		return &"coordinator_load_already_requested"
	return &""


func _audit_live_cinder_observation(
	errors: PackedStringArray,
	overlay_snapshot: Dictionary
	) -> void:
	if not is_instance_valid(_coordinator):
		return
	var loaded_root := _coordinator.get_loaded_instance(
		CinderStreamingBootstrap.LOCATION_ID
	)
	var active_locations := int(overlay_snapshot.get("active_location_count", -1))
	if not is_instance_valid(loaded_root):
		if active_locations != 0:
			errors.append("overlay retains an active location while Cinder is unloaded")
		return
	var load_generation := int(
		loaded_root.get_meta(&"world_location_generation", -1)
	)
	var last_loaded := overlay_snapshot.get("last_loaded_observation", {}) as Dictionary
	if StringName(last_loaded.get("location_id", &"")) \
			!= CinderStreamingBootstrap.LOCATION_ID \
			or int(last_loaded.get("load_generation", -1)) != load_generation:
		errors.append("overlay did not observe the exact live Cinder generation")
		return
	if active_locations == 0:
		if last_loaded.get("reason", &"") != &"no_ship_berths" \
				or bool(last_loaded.get("accepted", true)):
			errors.append("zero-berth Cinder load did not fail closed")
		return
	var location := _overlay.lookup_location(CinderStreamingBootstrap.LOCATION_ID)
	if not bool(location.get("found", false)) \
			or int(location.get("load_generation", -1)) != load_generation \
			or int(location.get("root_instance_id", 0)) != loaded_root.get_instance_id():
		errors.append("active Cinder berth roster provenance drifted")


func _sorted_world_berth_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if is_instance_valid(_world):
		ids.assign(_world.get_berth_ids())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a) < str(b)
	)
	return ids


func _on_location_registered(snapshot: Dictionary) -> void:
	_registration_signal_count += 1
	_last_registration = snapshot.duplicate(true)


func _on_location_retired(tombstone: Dictionary) -> void:
	_retirement_signal_count += 1
	_last_retirement = tombstone.duplicate(true)
