extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_landing_site_content_contract.gd")
var assertions := 0
var failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "authored landing site validates")
	var snapshot: Dictionary = contract.get_snapshot()
	_check(snapshot.identity.site_id == &"ember_caldera", "snapshot preserves site identity")
	_check((snapshot.content.landmark_ids as PackedStringArray).size() >= 3, "snapshot carries landmark roster")
	_check(snapshot.authority.movement == false and snapshot.authority.streaming == false, "manifest owns no runtime authority")
	var duplicate := contract.duplicate(true)
	duplicate.landmark_ids = PackedStringArray(["one", "one", "three"])
	_check(_has_error(duplicate.get_validation_errors(), "duplicate"), "duplicate landmarks fail closed")
	var undersized := contract.duplicate(true)
	undersized.landing_area_m2 = 1.0
	_check(_has_error(undersized.get_validation_errors(), "landing_area"), "insubstantial landing area fails closed")
	var detached: PackedStringArray = snapshot.content.landmark_ids
	detached[0] = "mutated"
	_check((contract.get_snapshot().content.landmark_ids as PackedStringArray)[0] == "ember_pad_guidance_port", "snapshot arrays are detached")
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
		print("PLANETARY_LANDING_SITE_CONTENT_CONTRACT_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		printerr("PLANETARY_LANDING_SITE_CONTENT_CONTRACT_TEST_FAIL: " + "; ".join(failures))
		quit(1)
