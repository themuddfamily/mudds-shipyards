extends SceneTree

const PresenterScript := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := PresenterScript.new()
	var cues := [
		[&"crew_engineer_joined", "Engineer joined crew"],
		[&"crew_engineer_left", "Engineer left crew"],
		[&"crew_engineer_route_changed", "Engineer power route changed"],
		[&"crew_departure_ready", "Crew departure ready"],
		[&"crew_emergency_pilot_handoff", "Emergency pilot handoff"],
	]
	for cue: Array in cues:
		var presentation := presenter.present_cue(cue[0], &"Crew status", 0.75, Vector3.ZERO)
		_check(bool(presentation.accepted), "%s is registered" % cue[0])
		_check(str(presentation.caption) == cue[1], "%s has a concise caller-facing label" % cue[0])
		_check(presentation.world_position == Vector3.ZERO and presentation.source is StringName, "%s stays typed and color-independent" % cue[0])
	_check(not presenter.present_cue(&"crew_emergency_pilot_handoff", &"Crew status", 0.75, Vector3.ZERO).accepted, "repeated crew caption is deduplicated")
	for failure in _failures:
		push_error(failure)
	print("halyard_crew_caption_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
