extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "default authored route validates")
	var audit := contract.get_audit_report()
	_check(bool(audit.valid), "audit reports a valid contract")
	_check(
		(audit.snapshot as Dictionary).audio_catalog_id == PlanetarySurfaceAudioCatalog.CATALOG_ID,
		"route records the existing strict audio catalog identity"
	)
	_check(
		(audit.authority as Dictionary).navigation == false
			and (audit.authority as Dictionary).audio == false,
		"contract owns neither navigation execution nor audio playback"
	)
	_check(
		(contract.get_snapshot().nodes as Array).size() == 3
			and (contract.get_snapshot().edges as Array).size() == 2,
		"snapshot publishes the bounded node and edge roster"
	)

	var disconnected := contract.duplicate()
	disconnected.node_ids = PackedStringArray([
		"pad_alpha_egress", "surface_staging_gate", "caldera_overlook",
	])
	disconnected.edge_to_ids = PackedStringArray([
		"surface_staging_gate", "missing_landmark",
	])
	_check(
		_not_empty(disconnected.get_validation_errors(), "unknown"),
		"unknown route endpoints are rejected"
	)
	var unreachable := contract.duplicate()
	unreachable.edge_from_ids = PackedStringArray(["pad_alpha_egress"])
	unreachable.edge_to_ids = PackedStringArray(["surface_staging_gate"])
	_check(
		_not_empty(unreachable.get_validation_errors(), "unreachable"),
		"unreachable authored landmarks are rejected"
	)

	var too_far := contract.duplicate()
	too_far.maximum_segment_length_m = 10.0
	_check(
		_not_empty(too_far.get_validation_errors(), "exceeds maximum segment length"),
		"route edges respect the authored segment bound"
	)

	var bad_audio := contract.duplicate()
	bad_audio.node_audio_profile_ids[1] = "unregistered_surface_loop"
	_check(
		_not_empty(bad_audio.get_validation_errors(), "audio profile"),
		"surface nodes fail closed on unknown opaque audio IDs"
	)

	var duplicate := contract.duplicate()
	duplicate.node_ids[2] = duplicate.node_ids[1]
	_check(
		_not_empty(duplicate.get_validation_errors(), "unique"),
		"duplicate landmark IDs are rejected"
	)

	var detached := contract.get_snapshot()
	(detached.nodes as Array)[0].node_id = &"mutated"
	_check(
		(contract.get_snapshot().nodes as Array)[0].node_id == &"pad_alpha_egress",
		"published snapshots are detached"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _not_empty(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if String(error).to_lower().contains(needle.to_lower()):
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_surface_navigation_contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
