extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_wildlife_boundary_contract.gd")
var assertions := 0
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "default deliberate no-wildlife boundary validates")
	var snapshot: Dictionary = contract.get_snapshot()
	var wildlife: Dictionary = snapshot["wildlife"]
	_check(wildlife["policy"] == &"none_authored", "wildlife policy explicitly records no wildlife")
	_check(wildlife["deliberately_authored"] == false, "no-wildlife choice is deliberate and explicit")
	_check(wildlife["entries"].is_empty(), "no-wildlife boundary has no implicit entries")
	_check(wildlife["procedural_spawning"] == false, "wildlife procedural spawning is disabled")
	_check(snapshot["evidence"]["procedural_generation"] == false, "evidence rejects procedural generation")
	_check(snapshot["authority"]["wildlife_spawn"] == false and snapshot["authority"]["wildlife_simulation"] == false, "contract owns no wildlife runtime authority")
	var hazards: Array = snapshot["hazards"]
	_check(hazards.size() >= 2, "hazard handoffs remain authored")
	for hazard in hazards:
		_check(not String(hazard["recovery_id"]).is_empty(), "hazard has an explicit recovery handoff")
		_check(not String(hazard["route_id"]).is_empty(), "hazard has an explicit route handoff")
	_check(snapshot["handoffs"]["recovery_authority_id"] == &"planetary_landing_return_contract", "hazards point at recovery authority")
	var procedural := contract.duplicate(true)
	procedural.procedural_spawning = true
	_check(_has_error(procedural.get_validation_errors(), "procedural_spawning"), "procedural spawning fails closed")
	var implicit := contract.duplicate(true)
	implicit.wildlife_ids = PackedStringArray(["ember_creature"])
	_check(_has_error(implicit.get_validation_errors(), "none_authored"), "implicit wildlife under no-wildlife policy fails closed")
	var authored := contract.duplicate(true)
	authored.wildlife_policy = &"authored_fixed"
	authored.deliberately_authored = true
	authored.wildlife_ids = PackedStringArray(["ember_sand_runner"])
	authored.wildlife_display_names = PackedStringArray(["Sand Runner"])
	authored.wildlife_kind_ids = PackedStringArray(["ground_fauna"])
	authored.wildlife_positions_body_local_m = PackedVector3Array([Vector3(240.0, 120001.0, -30.0)])
	_check(authored.is_definition_valid(), "fixed wildlife can be explicitly authored")
	_check(authored.get_snapshot()["wildlife"]["entries"].size() == 1, "fixed wildlife snapshot carries authored entry")
	_finish()


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if String(error).to_lower().contains(needle.to_lower()):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PLANETARY_WILDLIFE_BOUNDARY_CONTRACT_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		printerr("PLANETARY_WILDLIFE_BOUNDARY_CONTRACT_TEST_FAIL: " + "; ".join(failures))
		quit(1)
