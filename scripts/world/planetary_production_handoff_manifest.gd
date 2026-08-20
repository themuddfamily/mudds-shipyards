class_name PlanetaryProductionHandoffManifest
extends RefCounted

## Detached production handoff manifest for one Player/ship planetary visit.
##
## This is the last validation seam before a future GameFlow owner composes the
## existing PlayerController, HeroShip and planetary loop owners. It joins
## their identities and generation fences, and checks that a controller-only
## route has a real return and recovery edge. It never moves an actor, samples
## Input, starts a loop, streams terrain, saves, awards, or mutates authority.

const SCHEMA_VERSION := 1
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_PHASES := 16
const MAX_ACTIONS := 32

const DEFAULT_WORLD_ID: StringName = &"ember_moon"
const DEFAULT_LANDING_REGION_ID: StringName = &"ember_caldera"
const DEFAULT_RETURN_TARGET_ID: StringName = &"mudds_shipyards"

const REQUIRED_AUTHORITY_IDS := {
	"player": &"player_controller",
	"ship": &"hero_ship",
	"planetary_loop": &"planetary_orbit_surface_loop",
	"controller": &"controller_input",
	"origin": &"common_world_origin_rebase_owner",
	"streaming": &"planetary_origin_stream_contract",
	"landing": &"ship_berth",
	"return": &"planetary_landing_return_contract",
	"station": &"mudds_shipyards",
}

const REQUIRED_CONTROLLER_ACTIONS := [
	&"interact", &"landing_assist", &"throttle", &"disembark",
	&"reboard", &"takeoff", &"orbit_return",
]

const AIRLESS_PHASE_PATH := [
	&"orbit_approach", &"descent", &"surface_flight", &"landed",
	&"on_foot", &"reboarded", &"takeoff", &"ascent", &"orbit",
	&"return_approach", &"completed",
]

const ATMOSPHERIC_PHASE_PATH := [
	&"orbit_approach", &"atmospheric_entry", &"descent",
	&"surface_flight", &"landed", &"on_foot", &"reboarded", &"takeoff",
	&"ascent", &"orbit", &"return_approach", &"completed",
]

const REQUIRED_ROUTE_IDS := [
	&"surface_egress", &"surface_return", &"orbit_return",
]

var _world_id: StringName = DEFAULT_WORLD_ID
var _landing_region_id: StringName = DEFAULT_LANDING_REGION_ID
var _return_target_id: StringName = DEFAULT_RETURN_TARGET_ID
var _has_atmosphere := false
var _configuration_errors := PackedStringArray()
var _last_validation: Dictionary = {}


func _init(
		world_id: StringName = DEFAULT_WORLD_ID,
		landing_region_id: StringName = DEFAULT_LANDING_REGION_ID,
		return_target_id: StringName = DEFAULT_RETURN_TARGET_ID,
		has_atmosphere: bool = false
	) -> void:
	_world_id = world_id
	_landing_region_id = landing_region_id
	_return_target_id = return_target_id
	_has_atmosphere = has_atmosphere
	_configuration_errors = _validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


## Validate detached evidence from the production owners. Every argument is
## copied before it is retained, so callers cannot mutate an accepted result
## after the handoff has been checked.
##
## `loop_snapshot` is the snapshot/audit payload from
## PlanetaryOrbitSurfaceLoopContract or PlanetaryLandingReturnContract.
## `player_identity` and `ship_identity` carry stable instance IDs and the
## current lifecycle generations. `handoff` carries the shared generation
## tuple, authority IDs, phase/route path, and controller-only proof.
func validate_handoff(
		loop_snapshot: Dictionary,
		player_identity: Dictionary,
		ship_identity: Dictionary,
		handoff: Dictionary
	) -> Dictionary:
	var errors := PackedStringArray()
	if not is_configuration_valid():
		errors.append_array(_configuration_errors)
	if loop_snapshot.is_empty():
		errors.append("planetary loop snapshot is required")
	if player_identity.is_empty():
		errors.append("Player identity evidence is required")
	if ship_identity.is_empty():
		errors.append("ship identity evidence is required")
	if handoff.is_empty():
		errors.append("production handoff evidence is required")
	if not errors.is_empty():
		return _finish(false, &"evidence_required", errors)

	_validate_loop_identity(errors, loop_snapshot)
	_validate_identity_record(errors, "player", player_identity)
	_validate_identity_record(errors, "ship", ship_identity)
	_validate_authority_ids(errors, handoff.get("authority_ids", {}))
	_validate_generations(errors, loop_snapshot, player_identity, ship_identity, handoff)
	_validate_controller_path(errors, handoff.get("controller_path", {}))
	_validate_phase_path(errors, handoff.get("phase_path", []))
	_validate_routes_and_recovery(errors, handoff)
	_validate_cross_identity(errors, player_identity, ship_identity, handoff)

	if errors.is_empty():
		_last_validation = {
			"world_id": _world_id,
			"landing_region_id": _landing_region_id,
			"return_target_id": _return_target_id,
			"run_generation": int(handoff.get("run_generation", 0)),
			"attachment_generation": int(handoff.get("attachment_generation", 0)),
			"coordinate_frame_generation": int(handoff.get("coordinate_frame_generation", 0)),
			"location_generation": int(handoff.get("location_generation", 0)),
			"player_instance_id": int(player_identity.get("instance_id", 0)),
			"ship_instance_id": int(ship_identity.get("instance_id", 0)),
			"phase_path": (handoff.get("phase_path", []) as Array).duplicate(),
			"controller_path": (handoff.get("controller_path", {}) as Dictionary).duplicate(true),
		}.duplicate(true)
		return {
			"accepted": true,
			"reason": &"production_handoff_valid",
			"manifest": get_snapshot(),
			"validation": _last_validation.duplicate(true),
		}
	return _finish(false, &"production_handoff_rejected", errors)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"world_id": _world_id,
		"landing_region_id": _landing_region_id,
		"return_target_id": _return_target_id,
		"has_atmosphere": _has_atmosphere,
		"required_phase_path": _required_phase_path().duplicate(),
		"required_route_ids": REQUIRED_ROUTE_IDS.duplicate(),
		"required_controller_actions": REQUIRED_CONTROLLER_ACTIONS.duplicate(),
		"required_authority_ids": REQUIRED_AUTHORITY_IDS.duplicate(true),
		"last_validation": _last_validation.duplicate(true),
		"authority": {
			"player_movement": false,
			"ship_motion": false,
			"planetary_loop": false,
			"controller_input": false,
			"origin_shift": false,
			"streaming": false,
			"landing": false,
			"save": false,
			"network": false,
		}.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": is_configuration_valid() and _last_validation.is_empty() == false,
		"configuration_valid": is_configuration_valid(),
		"errors": get_configuration_errors(),
		"snapshot": get_snapshot(),
		"authority": get_snapshot().get("authority", {}).duplicate(true),
		"production_wiring": false,
		"movement": false,
		"input_sampling": false,
		"streaming": false,
		"save": false,
		"network": false,
	}.duplicate(true)


func _validate_loop_identity(errors: PackedStringArray, loop_snapshot: Dictionary) -> void:
	if StringName(loop_snapshot.get("world_id", &"")) != _world_id:
		errors.append("planetary loop world ID does not match the manifest")
	if StringName(loop_snapshot.get("landing_region_id", &"")) != _landing_region_id \
			and StringName(loop_snapshot.get("region_id", &"")) != _landing_region_id:
		errors.append("planetary loop landing-region ID does not match the manifest")
	if StringName(loop_snapshot.get("return_target_id", &"")) != _return_target_id:
		errors.append("planetary loop return target ID does not match the manifest")
	var authority: Variant = loop_snapshot.get("authority", {})
	if not authority is Dictionary:
		errors.append("planetary loop authority roster is missing")
	else:
		for key in (authority as Dictionary).keys():
			if bool((authority as Dictionary).get(key, false)):
				errors.append("planetary loop must not claim production authority: %s" % key)
	var phase_id := StringName(loop_snapshot.get("phase_id", &""))
	if phase_id != &"completed":
		errors.append("planetary loop handoff must end at completed, not %s" % phase_id)


func _validate_identity_record(
		errors: PackedStringArray,
		kind: String,
		record: Dictionary
	) -> void:
	var expected: StringName = REQUIRED_AUTHORITY_IDS.get(kind, &"") as StringName
	if StringName(record.get("authority_id", &"")) != expected:
		errors.append("%s authority ID is not %s" % [kind, expected])
	var instance_id: Variant = record.get("instance_id", 0)
	if not instance_id is int or int(instance_id) <= 0:
		errors.append("%s instance ID must be a positive integer" % kind)
	var attachment: Variant = record.get("attachment_generation", 0)
	if not _valid_generation(attachment):
		errors.append("%s attachment generation is invalid" % kind)


func _validate_authority_ids(errors: PackedStringArray, candidate: Variant) -> void:
	if not candidate is Dictionary:
		errors.append("authority_ids must be a dictionary")
		return
	var ids := candidate as Dictionary
	if ids.size() != REQUIRED_AUTHORITY_IDS.size():
		errors.append("authority_ids must contain the exact production roster")
	for key in REQUIRED_AUTHORITY_IDS.keys():
		if StringName(ids.get(key, &"")) != REQUIRED_AUTHORITY_IDS[key]:
			errors.append("authority ID drifted for %s" % key)


func _validate_generations(
		errors: PackedStringArray,
		loop_snapshot: Dictionary,
		player_identity: Dictionary,
		ship_identity: Dictionary,
		handoff: Dictionary
	) -> void:
	var run_generation: Variant = handoff.get("run_generation", 0)
	var attachment_generation: Variant = handoff.get("attachment_generation", 0)
	var coordinate_generation: Variant = handoff.get("coordinate_frame_generation", 0)
	var location_generation: Variant = handoff.get("location_generation", 0)
	for pair in [
		["run_generation", run_generation],
		["attachment_generation", attachment_generation],
		["coordinate_frame_generation", coordinate_generation],
		["location_generation", location_generation],
	]:
		if not _valid_generation(pair[1]):
			errors.append("%s must be a positive lifecycle generation" % pair[0])
	if int(loop_snapshot.get("run_generation", 0)) != int(run_generation):
		errors.append("planetary loop run generation is stale")
	if int(player_identity.get("attachment_generation", 0)) != int(attachment_generation):
		errors.append("Player attachment generation is stale")
	if int(ship_identity.get("attachment_generation", 0)) != int(attachment_generation):
		errors.append("ship attachment generation is stale")
	if int(ship_identity.get("coordinate_frame_generation", 0)) != int(coordinate_generation):
		errors.append("ship coordinate-frame generation is stale")
	var host: Variant = handoff.get("host", {})
	if host is Dictionary and not (host as Dictionary).is_empty():
		var host_dict := host as Dictionary
		for key in ["generation", "attachment_generation", "coordinate_frame_generation", "location_generation"]:
			if host_dict.has(key) and int(host_dict.get(key, 0)) <= 0:
				errors.append("host %s is invalid" % key)
		if host_dict.has("attachment_generation") \
				and int(host_dict.get("attachment_generation")) != int(attachment_generation):
			errors.append("host attachment generation is stale")
		if host_dict.has("coordinate_frame_generation") \
				and int(host_dict.get("coordinate_frame_generation")) != int(coordinate_generation):
			errors.append("host coordinate-frame generation is stale")


func _validate_controller_path(errors: PackedStringArray, candidate: Variant) -> void:
	if not candidate is Dictionary:
		errors.append("controller_path must be a dictionary")
		return
	var path := candidate as Dictionary
	if path.get("controller_only", false) != true:
		errors.append("handoff must explicitly prove controller-only navigation")
	if StringName(path.get("authority_id", &"")) != REQUIRED_AUTHORITY_IDS.controller:
		errors.append("controller path authority ID is not controller_input")
	if path.get("raw_input", true) != false:
		errors.append("controller handoff must not poll raw Input")
	if path.get("keyboard_fallback", true) != false:
		errors.append("controller-only path cannot depend on a keyboard fallback")
	var actions: Variant = path.get("action_ids", [])
	if not actions is Array:
		errors.append("controller action_ids must be an array")
		return
	if (actions as Array).size() > MAX_ACTIONS:
		errors.append("controller action roster exceeds the bounded limit")
	for action in REQUIRED_CONTROLLER_ACTIONS:
		if not (actions as Array).has(action) and not (actions as Array).has(String(action)):
			errors.append("controller path is missing action %s" % action)


func _validate_phase_path(errors: PackedStringArray, candidate: Variant) -> void:
	if not candidate is Array:
		errors.append("phase_path must be an array")
		return
	var path := candidate as Array
	var expected := _required_phase_path()
	if path.size() > MAX_PHASES or path.size() != expected.size():
		errors.append("phase_path must contain the complete ordered visit")
		return
	for index in expected.size():
		if StringName(path[index]) != expected[index] and String(path[index]) != String(expected[index]):
			errors.append("phase_path has a dead-end or skip at index %d" % index)
			return


func _validate_routes_and_recovery(errors: PackedStringArray, handoff: Dictionary) -> void:
	if StringName(handoff.get("return_target_id", _return_target_id)) != _return_target_id:
		errors.append("handoff return target ID does not match the manifest")
	var routes: Variant = handoff.get("route_ids", [])
	if not routes is Array:
		errors.append("route_ids must be an array")
	else:
		for route in REQUIRED_ROUTE_IDS:
			if not (routes as Array).has(route) and not (routes as Array).has(String(route)):
				errors.append("route graph has no %s edge" % route)
	var recovery: Variant = handoff.get("failure_recovery_ids", [])
	if not recovery is Array or recovery.is_empty():
		errors.append("at least one recoverable failure route is required")
	else:
		var has_landed := (recovery as Array).has(&"return_to_landed_ship") \
				or (recovery as Array).has("return_to_landed_ship")
		var has_orbit := (recovery as Array).has(&"abort_to_orbit_return") \
				or (recovery as Array).has("abort_to_orbit_return")
		if not has_landed or not has_orbit:
			errors.append("recovery must retain landed-ship and orbit-return exits")


func _validate_cross_identity(
		errors: PackedStringArray,
		player_identity: Dictionary,
		ship_identity: Dictionary,
		handoff: Dictionary
	) -> void:
	if int(handoff.get("player_instance_id", 0)) != int(player_identity.get("instance_id", -1)):
		errors.append("handoff Player instance ID does not match the Player record")
	if int(handoff.get("ship_instance_id", 0)) != int(ship_identity.get("instance_id", -1)):
		errors.append("handoff ship instance ID does not match the ship record")
	if StringName(player_identity.get("world_id", _world_id)) != _world_id:
		errors.append("Player world ID does not match the planetary visit")
	if StringName(ship_identity.get("world_id", _world_id)) != _world_id:
		errors.append("ship world ID does not match the planetary visit")
	if StringName(player_identity.get("landing_region_id", _landing_region_id)) != _landing_region_id:
		errors.append("Player landing-region ID does not match the planetary visit")
	if StringName(ship_identity.get("landing_region_id", _landing_region_id)) != _landing_region_id:
		errors.append("ship landing-region ID does not match the planetary visit")


func _required_phase_path() -> Array:
	return (ATMOSPHERIC_PHASE_PATH if _has_atmosphere else AIRLESS_PHASE_PATH).duplicate()


func _validate_configuration() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", _world_id)
	_validate_id(errors, "landing_region_id", _landing_region_id)
	_validate_id(errors, "return_target_id", _return_target_id)
	return errors


func _finish(accepted: bool, reason: StringName, errors: PackedStringArray) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"errors": errors.duplicate(),
		"manifest": get_snapshot(),
	}.duplicate(true)


func _valid_generation(value: Variant) -> bool:
	return value is int and int(value) > 0 and int(value) <= MAX_SAFE_GENERATION


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > 64 or text.begins_with("_") \
			or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be a stable lowercase snake_case identifier" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be a stable lowercase snake_case identifier" % field_name)
			return
