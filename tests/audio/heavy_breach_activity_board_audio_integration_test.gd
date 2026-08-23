extends SceneTree

const AudioBinding := preload("res://scripts/audio/heavy_breach_activity_board_audio_binding.gd")
const Board := preload("res://scripts/activities/heavy_breach_activity_board.gd")

var _events: Array[StringName] = []
var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := AudioBinding.new()
	audio.semantic_board_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach().accepted), "board audio binding attaches")
	_check(bool(audio.present_interaction({"accepted": true, "generation": 1, "reason": &"heavy_breach_started"}).accepted), "board admission is presented")
	_check(bool(audio.present_interaction({"accepted": false, "generation": 1, "reason": &"out_of_range"}).accepted), "board rejection is presented")
	_check(bool(audio.present_terminal(&"heavy_breach", &"cleared", 1).accepted), "terminal success is presented")
	_check(bool(audio.present_reward({"accepted": true}, 1).accepted), "reward confirmation is presented")
	_check(_has(&"heavy_breach_board_admitted") and _has(&"heavy_breach_board_rejected") and _has(&"heavy_breach_board_success") and _has(&"heavy_breach_board_reward_confirmed"), "board interaction, terminal, and reward cues emit")
	_check(bool(audio.present_reward({"accepted": true}, 1).accepted), "duplicate reward is safely accepted")
	_check(_events.count(&"heavy_breach_board_reward_confirmed") == 1, "reward confirmation is exactly once")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "board audio keeps two-voice ceiling")
	_check(bool(audio.detach().accepted), "board audio detaches")

	var board := Board.new()
	root.add_child(board)
	await process_frame
	_check(bool(board.get_audio_binding_snapshot().get("attached", false)), "production board composes board audio binding")
	board.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("heavy_breach_activity_board_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(cue_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)

func _has(cue_id: StringName) -> bool:
	return _events.has(cue_id)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
