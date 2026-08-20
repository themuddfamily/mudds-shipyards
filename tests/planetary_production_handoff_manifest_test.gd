extends SceneTree

const ManifestScript := preload("res://scripts/world/planetary_production_handoff_manifest.gd")
const LoopScript := preload("res://scripts/world/planetary_orbit_surface_loop_contract.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var loop := LoopScript.new(&"ember_moon", &"ember_caldera", &"mudds_shipyards", false)
	_complete_loop(loop)
	var manifest := ManifestScript.new()
	_check(manifest.is_configuration_valid(), "default Ember production manifest configures")
	var evidence := _evidence()
	var accepted := manifest.validate_handoff(
		loop.get_snapshot(), evidence.player, evidence.ship, evidence.handoff
	)
	_check(bool(accepted.get("accepted", false)), "complete Player/ship loop accepts the production handoff")
	_check(
		accepted.get("reason", &"") == &"production_handoff_valid"
			and int((accepted.get("validation", {}) as Dictionary).get("run_generation", 0)) == 7,
		"accepted handoff freezes the exact run generation",
	)
	_check(
		manifest.audit().get("valid", false)
			and not bool((manifest.get_snapshot().get("authority", {}) as Dictionary).get("planetary_loop", true)),
		"manifest audit is valid and owns no planetary authority",
	)
	_check(
		((accepted.get("manifest", {}) as Dictionary).get("required_phase_path", []) as Array).size() == 11,
		"airless Ember manifest publishes the complete ordered path",
	)

	var wrong_world := _evidence_loop_override(loop.get_snapshot(), &"aurora_temperate_world")
	_check(
		manifest.validate_handoff(wrong_world, evidence.player, evidence.ship, evidence.handoff).reason
			== &"production_handoff_rejected",
		"foreign planetary world ID is rejected",
	)
	var stale_player: Dictionary = evidence.player.duplicate(true)
	stale_player.attachment_generation = 6
	_check(
		manifest.validate_handoff(loop.get_snapshot(), stale_player, evidence.ship, evidence.handoff).reason
			== &"production_handoff_rejected",
		"stale Player attachment generation is rejected",
	)
	var stale_ship: Dictionary = evidence.ship.duplicate(true)
	stale_ship.coordinate_frame_generation = 3
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, stale_ship, evidence.handoff).reason
			== &"production_handoff_rejected",
		"stale ship coordinate-frame generation is rejected",
	)
	var keyboard_path: Dictionary = evidence.handoff.duplicate(true)
	(keyboard_path.controller_path as Dictionary).raw_input = true
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, keyboard_path).reason
			== &"production_handoff_rejected",
		"raw-input or keyboard fallback cannot satisfy controller-only proof",
	)
	var missing_action: Dictionary = evidence.handoff.duplicate(true)
	(missing_action.controller_path.action_ids as Array).erase("orbit_return")
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, missing_action).reason
			== &"production_handoff_rejected",
		"controller path missing the return action is rejected",
	)
	var skipped_phase: Dictionary = evidence.handoff.duplicate(true)
	(skipped_phase.phase_path as Array).remove_at(1)
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, skipped_phase).reason
			== &"production_handoff_rejected",
		"a skipped planetary phase is rejected as a dead end",
	)
	var missing_route: Dictionary = evidence.handoff.duplicate(true)
	(missing_route.route_ids as Array).erase("orbit_return")
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, missing_route).reason
			== &"production_handoff_rejected",
		"a route graph without station return is rejected",
	)
	var missing_recovery: Dictionary = evidence.handoff.duplicate(true)
	missing_recovery.failure_recovery_ids = ["return_to_landed_ship"]
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, missing_recovery).reason
			== &"production_handoff_rejected",
		"a route without both recoverable exits is rejected",
	)
	var foreign_authority: Dictionary = evidence.handoff.duplicate(true)
	(foreign_authority.authority_ids as Dictionary).ship = &"foreign_ship"
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, foreign_authority).reason
			== &"production_handoff_rejected",
		"foreign ship authority ID is rejected",
	)
	var mismatched_instance: Dictionary = evidence.handoff.duplicate(true)
	mismatched_instance.ship_instance_id = 999
	_check(
		manifest.validate_handoff(loop.get_snapshot(), evidence.player, evidence.ship, mismatched_instance).reason
			== &"production_handoff_rejected",
		"handoff cannot bind a different ship instance",
	)
	var not_terminal := loop.get_snapshot()
	not_terminal.phase_id = &"landed"
	_check(
		manifest.validate_handoff(not_terminal, evidence.player, evidence.ship, evidence.handoff).reason
			== &"production_handoff_rejected",
		"a non-terminal loop cannot be presented as a completed production handoff",
	)
	var atmosphere_manifest := ManifestScript.new(
		&"aurora_temperate_world", &"aurora_landing", &"mudds_shipyards", true
	)
	var atmosphere_loop := LoopScript.new(
		&"aurora_temperate_world", &"aurora_landing", &"mudds_shipyards", true
	)
	_complete_atmospheric_loop(atmosphere_loop)
	var atmosphere_evidence := _evidence_for(
		&"aurora_temperate_world", &"aurora_landing", 17, 23, true
	)
	_check(
		atmosphere_manifest.validate_handoff(
			atmosphere_loop.get_snapshot(), atmosphere_evidence.player,
			atmosphere_evidence.ship, atmosphere_evidence.handoff
		).accepted,
		"atmospheric worlds retain the entry phase without weakening the same handoff contract",
	)
	_finish()


func _complete_loop(loop: PlanetaryOrbitSurfaceLoopContract) -> void:
	_check(loop.begin(7).accepted, "airless loop starts for fixture")
	var observation := {"position": Vector3(0.0, 220_000.0, 0.0), "speed_meters_per_second": 300.0}
	_check(loop.confirm_orbit_approach(true, observation, 7).accepted, "fixture confirms orbit approach")
	_check(loop.confirm_descent(true, &"ember_caldera", true, observation, 7).accepted, "fixture confirms descent")
	_check(loop.confirm_landing(true, &"ember_caldera", true, true, 7).accepted, "fixture confirms supported landing")
	_check(loop.confirm_on_foot(true, true, 7).accepted, "fixture confirms on-foot route")
	_check(loop.confirm_reboarded(true, true, 7).accepted, "fixture confirms reboarding")
	_check(loop.confirm_takeoff(true, false, 7).accepted, "fixture confirms takeoff")
	_check(loop.confirm_ascent(true, observation, 7).accepted, "fixture confirms ascent")
	_check(loop.confirm_orbit(true, observation, 7).accepted, "fixture confirms orbit")
	_check(loop.confirm_return_approach(true, &"mudds_shipyards", observation, 7).accepted, "fixture confirms return corridor")
	_check(loop.confirm_return(true, &"mudds_shipyards", 7).accepted, "fixture confirms station return")


func _complete_atmospheric_loop(loop: PlanetaryOrbitSurfaceLoopContract) -> void:
	_check(loop.begin(17).accepted, "atmospheric fixture starts")
	var observation := {"position": Vector3(0.0, 220_000.0, 0.0), "speed_meters_per_second": 300.0}
	_check(loop.confirm_orbit_approach(true, observation, 17).accepted, "atmospheric fixture confirms orbit approach")
	_check(loop.confirm_atmospheric_entry(true, observation, 17).accepted, "atmospheric fixture confirms entry")
	_check(loop.confirm_descent(true, &"aurora_landing", true, observation, 17).accepted, "atmospheric fixture confirms descent")
	_check(loop.confirm_landing(true, &"aurora_landing", true, true, 17).accepted, "atmospheric fixture confirms landing")
	_check(loop.confirm_on_foot(true, true, 17).accepted, "atmospheric fixture confirms route")
	_check(loop.confirm_reboarded(true, true, 17).accepted, "atmospheric fixture confirms reboard")
	_check(loop.confirm_takeoff(true, false, 17).accepted, "atmospheric fixture confirms takeoff")
	_check(loop.confirm_ascent(true, observation, 17).accepted, "atmospheric fixture confirms ascent")
	_check(loop.confirm_orbit(true, observation, 17).accepted, "atmospheric fixture confirms orbit")
	_check(loop.confirm_return_approach(true, &"mudds_shipyards", observation, 17).accepted, "atmospheric fixture confirms return corridor")
	_check(loop.confirm_return(true, &"mudds_shipyards", 17).accepted, "atmospheric fixture confirms return")


func _evidence() -> Dictionary:
	return _evidence_for(&"ember_moon", &"ember_caldera", 101, 202)


func _evidence_for(
		world_id: StringName,
		region_id: StringName,
		player_id: int,
		ship_id: int,
		has_atmosphere: bool = false
	) -> Dictionary:
	var player := {
		"authority_id": &"player_controller",
		"instance_id": player_id,
		"attachment_generation": 3,
		"world_id": world_id,
		"landing_region_id": region_id,
	}.duplicate(true)
	var ship := {
		"authority_id": &"hero_ship",
		"instance_id": ship_id,
		"attachment_generation": 3,
		"coordinate_frame_generation": 2,
		"world_id": world_id,
		"landing_region_id": region_id,
	}.duplicate(true)
	var authority_ids := {
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
	var phase_path := (
		[
			"orbit_approach", "atmospheric_entry", "descent", "surface_flight", "landed",
			"on_foot", "reboarded", "takeoff", "ascent", "orbit", "return_approach", "completed",
		]
		if has_atmosphere
		else [
			"orbit_approach", "descent", "surface_flight", "landed", "on_foot",
			"reboarded", "takeoff", "ascent", "orbit", "return_approach", "completed",
		]
	)
	var handoff := {
		"run_generation": 17 if has_atmosphere else 7,
		"attachment_generation": 3,
		"coordinate_frame_generation": 2,
		"location_generation": 4,
		"player_instance_id": player_id,
		"ship_instance_id": ship_id,
		"return_target_id": &"mudds_shipyards",
		"authority_ids": authority_ids,
		"phase_path": phase_path,
		"route_ids": ["surface_egress", "surface_return", "orbit_return"],
		"failure_recovery_ids": ["return_to_landed_ship", "abort_to_orbit_return"],
		"controller_path": {
			"controller_only": true,
			"authority_id": &"controller_input",
			"raw_input": false,
			"keyboard_fallback": false,
			"action_ids": [
				"interact", "landing_assist", "throttle", "disembark",
				"reboard", "takeoff", "orbit_return",
			],
		},
		"host": {
			"generation": 5,
			"attachment_generation": 3,
			"coordinate_frame_generation": 2,
			"location_generation": 4,
		},
	}.duplicate(true)
	return {"player": player, "ship": ship, "handoff": handoff}


func _evidence_loop_override(snapshot: Dictionary, world_id: StringName) -> Dictionary:
	var result := snapshot.duplicate(true)
	result["world_id"] = world_id
	return result


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_PRODUCTION_HANDOFF_MANIFEST_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("PLANETARY_PRODUCTION_HANDOFF_MANIFEST_TEST_FAIL: " + "; ".join(_failures))
		quit(1)
