extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "authored Aurora water contract validates")
	var snapshot: Dictionary = contract.get_snapshot()
	var identity := snapshot.get("identity", {}) as Dictionary
	var water := snapshot.get("water", {}) as Dictionary
	var materials := snapshot.get("materials", []) as Array
	var hazards := snapshot.get("shoreline_hazards", []) as Array
	var audio := snapshot.get("audio", {}) as Dictionary
	var authority := snapshot.get("authority", {}) as Dictionary
	_check(
		identity.get("world_id") == &"aurora_temperate_world"
			and identity.get("landing_region_id") == &"aurora_foundation_landing"
			and water.get("water_appropriate") == true
			and water.get("body_kind") == &"coastal_inlet",
		"water is explicitly appropriate and scoped to the authored surface region",
	)
	_check(
		materials.size() == 3
			and materials[0].get("kind") == &"water"
			and materials[1].get("kind") == &"shoreline"
			and materials[2].get("kind") == &"substrate"
			and materials[0].get("id") == &"aurora_water_surface",
		"material layers preserve water, shoreline, and substrate order",
	)
	_check(
		materials[0].get("audio_route_id") == &"planetary_water_surface"
			and materials[1].get("audio_route_id") == &"planetary_shoreline_contact"
			and audio.get("authority_id") == &"planetary_surface_audio_policy"
			and bool(audio.get("routes_are_opaque_hints"))
			and not bool(audio.get("playback_requested")),
		"water and shoreline materials hand off opaque audio routes without playback",
	)
	_check(
		hazards.size() >= 2
			and hazards[0].get("kind") == &"undertow"
			and hazards[1].get("kind") == &"slippery_shore"
			and hazards[0].get("route_id") == &"aurora_coastal_access_route"
			and hazards[0].get("recovery_id") == &"return_to_landed_ship",
		"shoreline hazards publish authored routes and recoverable handoffs",
	)
	_check(
		authority.get("renderer") == false
			and authority.get("material_binding") == false
			and authority.get("water_simulation") == false
			and authority.get("audio_playback") == false
			and authority.get("hazard_resolution") == false,
		"the declaration owns no renderer, simulation, playback, or hazard authority",
	)

	var bad_layers = contract.duplicate(true)
	bad_layers.material_audio_route_ids = PackedStringArray(["only_one_route"])
	_check(
		_has_error(bad_layers.get_validation_errors(), "parallel"),
		"material audio routes must remain aligned with material layers",
	)
	var bad_kind = contract.duplicate(true)
	bad_kind.material_layer_kinds[0] = "procedural_noise"
	_check(
		_has_error(bad_kind.get_validation_errors(), "authored water/shoreline/substrate order"),
		"an unsupported material kind fails closed",
	)
	var bad_water = contract.duplicate(true)
	bad_water.water_appropriate = false
	_check(
		_has_error(bad_water.get_validation_errors(), "water_appropriate"),
		"a water contract cannot silently declare water inappropriate",
	)
	var bad_hazard = contract.duplicate(true)
	bad_hazard.shoreline_hazard_kinds[0] = "procedural_wave"
	_check(
		_has_error(bad_hazard.get_validation_errors(), "hazard catalog"),
		"an unsupported shoreline hazard kind fails closed",
	)
	var bad_route = contract.duplicate(true)
	bad_route.material_audio_route_ids[1] = ""
	_check(
		_has_error(bad_route.get_validation_errors(), "audio route"),
		"a missing shoreline audio handoff fails closed",
	)
	var bad_position = contract.duplicate(true)
	bad_position.shoreline_hazard_positions_body_local_m[0] = Vector3(INF, 0.0, 0.0)
	_check(
		_has_error(bad_position.get_validation_errors(), "position"),
		"a non-finite shoreline hazard position fails closed",
	)
	var detached: Dictionary = contract.get_snapshot()
	(detached.get("materials", []) as Array)[0]["id"] = &"mutated_material"
	(detached.get("shoreline_hazards", []) as Array)[0]["id"] = &"mutated_hazard"
	_check(
		(contract.get_snapshot().get("materials", []) as Array)[0].get("id") == &"aurora_water_surface"
			and (contract.get_snapshot().get("shoreline_hazards", []) as Array)[0].get("id") == &"aurora_shelf_undertow",
		"published material and hazard snapshots are detached from authored data",
	)
	_finish()


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if String(error).to_lower().contains(needle.to_lower()):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_water_surface_material_contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
