extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")

var _assertions := 0
var _failures: Array[String] = []
var _caption_requests: Array[Dictionary] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var settings := RuntimeSettingsType.new()
	settings.captions_enabled = true
	hud.set_accessibility(settings.get_accessibility_descriptor())
	hud.bind_caption_event_submitter(Callable(self, &"_capture_caption_request"))

	# The non-critical separation transition remains visual-only.
	hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(4, 3.0)}})
	_check(_caption_requests.is_empty(), "ordinary separation does not flood the caption seam")

	hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(4, 0.8)}})
	_check(
		_caption_requests.size() == 1
		and str(_caption_requests[0].get("text", "")).contains("Critical convoy separation")
		and int(_caption_requests[0].get("priority", 0)) == 95,
		"critical separation produces one high-priority retained-HUD caption",
	)
	hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(4, 0.8)}})
	_check(_caption_requests.size() == 1, "an identical critical snapshot is consumed exactly once")

	var failed := _convoy(4, 0.0)
	failed.state_id = &"failed"
	failed.terminal_reason = &"escort_separation_exceeded"
	hud.set_nearby_activity_snapshot({"host": {"activity": failed}})
	_check(
		_caption_requests.size() == 2
		and str(_caption_requests[1].get("text", "")).contains("Convoy lost"),
		"the authoritative loss transition produces one terminal warning caption",
	)
	hud.set_nearby_activity_snapshot({"host": {"activity": failed}})
	_check(_caption_requests.size() == 2, "an identical terminal snapshot is consumed exactly once")

	settings.captions_enabled = false
	hud.set_accessibility(settings.get_accessibility_descriptor())
	hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(7, 0.5)}})
	_check(
		_caption_requests.size() == 2,
		"RuntimeSettings captions-off suppresses a fresh critical transition",
	)

	settings.captions_enabled = true
	hud.set_accessibility(settings.get_accessibility_descriptor())
	hud.set_nearby_activity_snapshot({"host": {"activity": _convoy(8, 0.5)}})
	_check(
		_caption_requests.size() == 3,
		"a later authoritative generation can produce the same critical cue once",
	)

	hud.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_CONVOY_CAPTION_TRANSITION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _convoy(generation: int, separation_remaining: float) -> Dictionary:
	return {
		"activity_id": &"cinder_reach_emberline_convoy",
		"state_id": &"active",
		"generation": generation,
		"has_entity_sample": true,
		"escort_distance": 148.0,
		"escort_proximity_radius": 120.0,
		"escort_within_proximity": false,
		"maximum_separation_seconds": 8.0,
		"separation_remaining_seconds": separation_remaining,
		"completed_leg_count": 1,
		"leg_count": 4,
	}.duplicate(true)


func _capture_caption_request(request: Dictionary) -> bool:
	_caption_requests.append(request.duplicate(true))
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures.append(message)
