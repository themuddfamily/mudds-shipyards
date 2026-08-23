extends SceneTree

const PresentationScene := preload("res://scenes/audio/combat_audio_presentation.tscn")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PresentationScene.instantiate()
	root.add_child(presentation)
	presentation.semantic_cue_emitted.connect(_on_cue)
	await process_frame
	var position := Vector3(1.0, 0.5, -2.0)
	presentation.play_dry_fire(position, 7)
	presentation.play_dry_fire(position, 7)
	_check(_readiness_events().size() == 1 and _has_cue(&"weapon_not_ready"), "dry-fire transition emits one not-ready cue")
	presentation.play_player_fire(position, 7)
	_check(_has_cue(&"weapon_ready"), "accepted fire transition emits a ready cue")
	var count := _readiness_events().size()
	presentation.play_player_fire(position, 7)
	_check(_readiness_events().size() == count, "repeated ready state does not spam")
	_check(
		_events.all(func(event): return event.cue_id is StringName and event.world_position == position and event.intensity is float),
		"weapon readiness payload remains typed"
	)
	presentation.free()
	for failure in _failures:
		push_error(failure)
	print("combat_weapon_readiness_semantic_cue_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(cue_id: StringName, world_position: Vector3, intensity: float) -> void:
	_events.append({"cue_id": cue_id, "world_position": world_position, "intensity": intensity})


func _has_cue(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false


func _readiness_events() -> Array[Dictionary]:
	var readiness: Array[Dictionary] = []
	for event in _events:
		if event.cue_id in [&"weapon_not_ready", &"weapon_ready"]:
			readiness.append(event)
	return readiness


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
