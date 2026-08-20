extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_destination_content_contract.gd")
const CONTENT_PATH := "res://assets/world/planets/ember_moon_content.tres"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = load(CONTENT_PATH)
	_check(content != null, "authored Ember content manifest loads")
	if content == null:
		_finish()
		return
	_check(content.is_definition_valid(), "authored destination content validates")
	var snapshot: Dictionary = content.get_snapshot()
	var identity := snapshot.identity as Dictionary
	var authored := snapshot.authored_content as Dictionary
	var handoffs := snapshot.handoffs as Dictionary
	_check(
		identity.world_id == &"ember_moon"
			and identity.orbital_silhouette_id == &"ember_moon_airless_caldera"
			and identity.return_target_id == &"mudds_shipyards",
		"content names a recognisable orbital silhouette and the station return target",
	)
	_check(
		(authored.landing_region_ids as PackedStringArray) == PackedStringArray(["ember_caldera"])
			and float(authored.substantial_landing_area_m2) >= 9_216.0,
		"content names one substantial authored landing region",
	)
	_check(
		(authored.orbital_landmark_ids as PackedStringArray).size() >= 3
			and (authored.surface_landmark_ids as PackedStringArray).size() >= 3
			and (authored.surface_route_ids as PackedStringArray).size() >= 1,
		"content publishes multiple fixed orbital/surface landmarks and a route",
	)
	_check(
		(handoffs.activity_ids as PackedStringArray).has("caldera_relay_scan")
			and (handoffs.reward_ids as PackedStringArray).has("ember_relay_data")
			and (handoffs.failure_recovery_ids as PackedStringArray).size() == 2
			and handoffs.activity_authority_id == &"activity_director"
			and handoffs.reward_authority_id == &"game_flow_reward_authority",
		"content binds activity, reward, and recoverable failure keys to existing authorities",
	)
	_check(
		(snapshot.authority as Dictionary).activity == false
			and (snapshot.authority as Dictionary).reward == false
			and (snapshot.authority as Dictionary).streaming == false,
		"manifest owns no gameplay, reward, or streaming authority",
	)

	var too_few_landmarks = content.duplicate(true)
	too_few_landmarks.surface_landmark_ids = PackedStringArray(["one_landmark"])
	_check(
		_has_error(too_few_landmarks.get_validation_errors(), "surface_landmark_ids"),
		"a destination without a meaningful landmark roster fails closed",
	)
	var no_return = content.duplicate(true)
	no_return.return_target_id = &""
	_check(
		_has_error(no_return.get_validation_errors(), "return_target_id"),
		"a destination without a station return target fails closed",
	)
	var duplicate_reward = content.duplicate(true)
	duplicate_reward.reward_ids = PackedStringArray(["ember_relay_data", "ember_relay_data"])
	_check(
		_has_error(duplicate_reward.get_validation_errors(), "duplicate"),
		"duplicate reward keys are rejected before authority handoff",
	)
	var detached: Dictionary = content.get_snapshot()
	(authored.surface_landmark_ids as PackedStringArray)[0] = "mutated"
	_check(
		(content.get_snapshot().authored_content.surface_landmark_ids as PackedStringArray)[0]
			== "ember_pad_guidance_port",
		"published snapshots are detached from authored arrays",
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
		print("PASS: planetary_destination_content_contract (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
