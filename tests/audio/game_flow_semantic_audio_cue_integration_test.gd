extends SceneTree

class MockHud:
	extends CanvasLayer

	var calls: Array[Dictionary] = []

	func present_semantic_audio_cue(
		cue_id: StringName, source_id: StringName, intensity: float, world_position: Vector3
	) -> bool:
		calls.append({
			"cue_id": cue_id,
			"source_id": source_id,
			"intensity": intensity,
			"world_position": world_position,
		})
		return true


const Flow := preload("res://scripts/game/game_flow.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := Flow.new()
	var hud := MockHud.new()
	flow.hud = hud
	flow._on_semantic_audio_cue_emitted(
		&"ship", &"engine_critical", 0.9, Vector3(1.0, 2.0, 3.0)
	)
	_check(hud.calls.size() == 1, "GameFlow forwards one semantic audio cue")
	_check(
		hud.calls[0].cue_id == &"engine_critical"
		and hud.calls[0].source_id == &"ship"
		and is_equal_approx(float(hud.calls[0].intensity), 0.9)
		and hud.calls[0].world_position == Vector3(1.0, 2.0, 3.0),
		"GameFlow preserves cue metadata for HUD presentation"
	)
	var source := FileAccess.get_file_as_string("res://scripts/game/game_flow.gd")
	_check(
		source.contains("_connect_signal_once(audio, &\"semantic_cue_emitted\", _on_semantic_audio_cue_emitted)"),
		"runtime signal wiring uses AudioDirector's normalized stream"
	)
	hud.free()
	flow.free()
	for failure in _failures:
		push_error(failure)
	print("game_flow_semantic_audio_cue_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
