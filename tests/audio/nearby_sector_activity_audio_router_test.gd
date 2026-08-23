extends SceneTree

const RouterScript := preload("res://scripts/audio/semantic_audio_cue_router.gd")
const BindingScript := preload("res://scripts/audio/nearby_sector_activity_audio_binding.gd")
var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var router := RouterScript.new()
	var source := BindingScript.new()
	root.add_child(router)
	root.add_child(source)
	router.semantic_cue_emitted.connect(_on_cue)
	_check(bool(source.attach().accepted), "activity source attaches")
	_check(bool(router.bind_source(source, &"activity").accepted), "activity source binds to the normalized router")
	var snapshot := {
		"activity_id": &"race_caldera",
		"state": &"active",
		"progress_unitless": 0.25,
		"checkpoint_id": &"checkpoint_alpha",
		"reward_pending": false,
		"reset_serial": 0,
	}
	_check(bool(source.present_activity_snapshot(snapshot).accepted), "activity snapshot reaches the router")
	var count := _events.size()
	_check(bool(source.present_activity_snapshot(snapshot).accepted), "repeated activity state is accepted")
	_check(_events.size() == count, "router and source jointly deduplicate repeated cues")
	_check(_has_source_cue(&"activity", &"activity_started"), "normalized activity start cue is emitted")
	_check(_has_source_cue(&"activity", &"activity_checkpoint"), "normalized checkpoint cue is emitted")
	_check(bool(router.detach().accepted), "router detach clears source bindings and dedupe")
	_check(bool(router.bind_source(source, &"activity").accepted), "activity source rebinds after detach")
	_check(bool(source.present_activity_snapshot({
		"activity_id": &"race_caldera", "state": &"complete", "progress_unitless": 1.0,
		"checkpoint_id": &"checkpoint_beta", "reward_pending": true, "reset_serial": 0,
	}).accepted), "re-entry snapshot is accepted")
	_check(_has_source_cue(&"activity", &"activity_complete"), "normalized completion cue is emitted")
	_check(
		_events.all(func(event): return event.source_id is StringName and event.cue_id is StringName \
			and event.intensity is float and event.position == Vector3.ZERO),
		"normalized activity payload stays bounded and typed"
	)
	for failure in _failures:
		push_error(failure)
	print("nearby_sector_activity_audio_router_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})


func _has_source_cue(source_id: StringName, cue_id: StringName) -> bool:
	for event in _events:
		if event.source_id == source_id and event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
