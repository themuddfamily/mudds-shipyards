extends SceneTree

const PresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := PresenterType.new()
	var position := Vector3(4.0, 2.0, -8.0)
	var accepted := presenter.present_cue(&"hull_impact_heavy", &"defender", 0.9, position)
	_check(bool(accepted.get("accepted", false)), "registered cue is accepted")
	_check(accepted.get("caption") == "Heavy hull impact", "cue maps to concise caption")
	_check(accepted.get("severity_marker") == "!", "severity has a non-colour shape marker")
	_check(accepted.get("world_position") == position, "world position is preserved for caller layout")
	var duplicate := presenter.present_cue(&"hull_impact_heavy", &"defender", 0.9, position)
	_check(duplicate.get("reason") == &"duplicate_cue", "identical cue is deduplicated")
	for cue_id in [
		&"station_defense_wave_started", &"station_defense_asset_danger", &"station_defense_asset_critical",
		&"station_defense_completed", &"station_defense_aborted", &"cargo_transfer_pickup_accepted",
		&"cargo_transfer_destination_delivered", &"cargo_transfer_rejected", &"cargo_transfer_activity_completed",
		&"cargo_transfer_aborted", &"planetary_orbit_approach", &"planetary_atmospheric_entry",
		&"planetary_landed", &"planetary_takeoff", &"planetary_ascent", &"planetary_orbit_return",
		&"planetary_returned_to_station"
	]:
		_check(cue_id in presenter.get_registered_cue_ids(), "%s is registered for captions" % cue_id)
	var metadata_cue := presenter.present_cue(
		&"cargo_transfer_rejected", &"cargo", 0.8, position,
		{"direction": "from port", "priority": 83}
	)
	_check(metadata_cue.get("direction") == "from port", "caller direction metadata is preserved")
	_check(metadata_cue.get("priority") == 83, "caller priority metadata is preserved")
	var no_metadata := presenter.present_cue(&"planetary_takeoff", &"flight", 0.5, position)
	_check(not no_metadata.has("direction") and not no_metadata.has("priority"), "unsupplied metadata stays absent")
	var hud := HudType.new()
	var requests: Array[Dictionary] = []
	hud.set_captions_enabled(true)
	hud.bind_caption_event_submitter(Callable(self, "_capture_request").bind(requests))
	_check(
		hud.present_semantic_audio_cue(
			&"station_defense_asset_critical", &"station", 0.9, position,
			{"direction": "from port", "priority": 88}
		),
		"HUD submits a new station-defense cue with caller metadata"
	)
	_check(str(requests[0].get("text", "")).ends_with("// from port"), "direction is readable in caption text")
	_check(int(requests[0].get("priority", 0)) == 88, "caller priority controls caption priority")
	hud.free()
	var unknown := presenter.present_cue(&"untrusted_cue", &"defender", 1.0, position)
	_check(unknown.get("reason") == &"unregistered_cue", "unregistered cue is rejected")
	if _failures.is_empty():
		print("SEMANTIC_AUDIO_CUE_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


func _capture_request(request: Dictionary, requests: Array[Dictionary]) -> bool:
	requests.append(request.duplicate(true))
	return true
