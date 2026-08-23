extends SceneTree

const RigScene := preload("res://scenes/audio/ship_audio_rig.tscn")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := RigScene.instantiate()
	root.add_child(rig)
	await process_frame
	rig.set("_active_cues_by_voice", {
		&"engine_cue_voice": &"landing",
		&"combat_cue_voice": &"impact",
	})
	_check(rig.set_damage_alarm_active(true), "damage alarm accepts caller state")
	var audit: Dictionary = rig.get_priority_audit()
	_check(audit.reason == &"critical_preemption", "damage alarm records critical preemption")
	_check(audit.preempted_voice_id == &"engine_cue_voice", "lowest-priority voice is selected deterministically")
	_check(audit.preempted_cue_id == &"landing", "lowest-priority cue is identified in the audit")
	var active: Dictionary = rig.get_state_snapshot().active_cues_by_voice
	_check(not active.has(&"engine_cue_voice"), "preempted voice is detached")
	var contract: Dictionary = rig.get_cue_contract()
	_check(
		int(contract.critical_destruction_priority) > int(contract.damage_alarm_priority),
		"destruction remains above the damage alarm priority"
	)
	_check(
		int(rig.get_performance_report().maximum_simultaneous_voices) == 6,
		"priority arbitration preserves the six-voice ceiling"
	)
	for failure in _failures:
		push_error(failure)
	print("ship_audio_priority_preemption_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
