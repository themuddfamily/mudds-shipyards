extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_surface_hazard_content_contract.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = ContractScript.new()
	_check(content.is_definition_valid(), "authored Ember surface content validates")
	var snapshot: Dictionary = content.get_snapshot()
	var identity := snapshot.get("identity", {}) as Dictionary
	var landmarks := snapshot.get("landmarks", []) as Array
	var hazards := snapshot.get("hazards", []) as Array
	var handoffs := snapshot.get("handoffs", {}) as Dictionary
	var evidence := snapshot.get("evidence", {}) as Dictionary
	_check(
		identity.get("world_id") == &"ember_moon"
			and identity.get("landing_region_id") == &"ember_caldera",
		"content is scoped to the authored Ember landing region",
	)
	_check(
		landmarks.size() >= 3
			and landmarks[0].get("id") == &"ember_pad_guidance_port"
			and landmarks[1].get("id") == &"ember_sample_rack"
			and landmarks[2].get("id") == &"ember_staging_relay",
		"content publishes multiple fixed recognisable landmarks",
	)
	_check(
		_all_landmarks_valid(landmarks),
		"each landmark is tied to an authored route and body-local position",
	)
	_check(
		hazards.size() >= 2
			and hazards[0].get("kind") == &"unstable_terrain"
			and hazards[1].get("kind") == &"exposed_reactor",
		"content publishes multiple authored hazard kinds",
	)
	_check(
		_all_hazards_valid(hazards),
		"every hazard has a recoverable route and opaque recovery handoff",
	)
	_check(
		(handoffs.get("activity_ids", PackedStringArray()) as PackedStringArray).has("caldera_relay_scan")
			and (handoffs.get("reward_ids", PackedStringArray()) as PackedStringArray).has("ember_relay_data")
			and handoffs.get("activity_authority_id") == &"activity_director"
			and handoffs.get("reward_authority_id") == &"game_flow_reward_authority",
		"activities and rewards hand off to existing authority keys",
	)
	_check(
		evidence.get("procedural_generation") == false
			and (snapshot.get("authority", {}) as Dictionary).get("hazard_resolution") == false,
		"contract explicitly rejects procedural emptiness and owns no hazard authority",
	)

	var too_few_landmarks = content.duplicate(true)
	too_few_landmarks.landmark_ids = PackedStringArray(["only_landmark"])
	_check(
		_has_error(too_few_landmarks.get_validation_errors(), "landmark_ids"),
		"a surface without a meaningful authored landmark roster fails closed",
	)
	var missing_recovery = content.duplicate(true)
	missing_recovery.hazard_recovery_ids = PackedStringArray(["", "safe_recovery_at_staging_relay", "abort_to_orbit_return"])
	_check(
		_has_error(missing_recovery.get_validation_errors(), "recovery"),
		"a hazard without a recovery handoff fails closed",
	)
	var unsupported_kind = content.duplicate(true)
	unsupported_kind.hazard_kind_ids[0] = "procedural_noise"
	_check(
		_has_error(unsupported_kind.get_validation_errors(), "hazard kind"),
		"an un-authored procedural hazard kind fails closed",
	)
	var misaligned = content.duplicate(true)
	misaligned.hazard_route_ids = PackedStringArray(["one_route"])
	_check(
		_has_error(misaligned.get_validation_errors(), "parallel"),
		"hazard route references must stay aligned with hazard entries",
	)
	var detached: Dictionary = content.get_snapshot()
	(detached.get("landmarks", []) as Array)[0]["id"] = &"mutated_landmark"
	_check(
		(content.get_snapshot().get("landmarks", []) as Array)[0].get("id") == &"ember_pad_guidance_port",
		"published landmark snapshots are detached from authored data",
	)
	_finish()


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if String(error).to_lower().contains(needle.to_lower()):
			return true
	return false


func _all_landmarks_valid(landmarks: Array) -> bool:
	for item in landmarks:
		if not item is Dictionary:
			return false
		if item.get("route_id", &"") == &"" or item.get("kind", &"") == &"":
			return false
		if not item.get("position_body_local_m", Vector3.INF) is Vector3:
			return false
	return true


func _all_hazards_valid(hazards: Array) -> bool:
	for item in hazards:
		if not item is Dictionary:
			return false
		if item.get("recovery_id", &"") == &"" or item.get("route_id", &"") == &"":
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: planetary_surface_hazard_content_contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
