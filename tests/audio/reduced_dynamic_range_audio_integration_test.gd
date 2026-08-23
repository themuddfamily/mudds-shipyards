extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Flow := preload("res://scripts/game/game_flow.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := Director.new()
	var flow := Flow.new()
	flow.audio = director
	_check(not bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "reduced range defaults off")
	_check(bool(flow.set_reduced_dynamic_range(true).accepted), "caller-owned setting applies immediately")
	_check(bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "audio director exposes reduced range")
	root.add_child(director)
	await process_frame
	director.set_on_foot(true)
	var neutral_ambience_db: float = director.get_node("Ambience").volume_db
	_check(is_equal_approx(neutral_ambience_db, -10.0), "neutral runtime ambience keeps the caller mix")
	_check(bool(flow.set_reduced_dynamic_range(true).accepted), "runtime accessibility policy updates active players")
	_check(
		is_equal_approx(director.get_node("Ambience").volume_db, neutral_ambience_db - 6.0),
		"reduced range attenuates the active director ambience voice"
	)
	root.remove_child(director)
	await process_frame
	_check(bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "policy survives audio detach")
	root.add_child(director)
	await process_frame
	_check(bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "policy survives audio re-entry")
	_check(bool(flow.set_reduced_dynamic_range(false).accepted), "caller can restore neutral range")
	_check(not bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "neutral range is applied")
	root.remove_child(director)
	director.free()
	flow.free()
	for failure in _failures:
		push_error(failure)
	print("reduced_dynamic_range_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
