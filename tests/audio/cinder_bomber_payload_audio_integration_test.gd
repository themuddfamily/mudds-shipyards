extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const ShipAudioRigScene := preload("res://scenes/audio/ship_audio_rig.tscn")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var bomber := Bomber.new()
	bomber.add_child(ShipAudioRigScene.instantiate())
	root.add_child(bomber)
	await process_frame
	await process_frame
	var binding: Node = bomber.get_payload_audio_binding()
	var cues: Array[StringName] = []
	var semantic_cues: Array[StringName] = []
	binding.payload_audio_cue_emitted.connect(func(cue_id: StringName, _payload_id: StringName, _intensity: float) -> void: cues.append(cue_id))
	binding.semantic_engine_cue_emitted.connect(func(cue_id: StringName, _intensity: float) -> void: semantic_cues.append(cue_id))
	_check(binding != null and bool(binding.get_snapshot().attached), "Cinder production bomber composes attached payload audio")
	_check(int(binding.get_snapshot().maximum_simultaneous_voices) == 2, "payload audio preserves the two-voice ceiling")
	_check(bool(bomber.begin_payload_generation(1).accepted), "payload authority generation attaches through the production seam")
	bomber.advance_payload_cooldown(1.0)
	var release := bomber.request_payload_release(1, &"pilot", 1, 1, 0, Vector3(0.0, 0.0, -20.0))
	_check(bool(release.get("accepted", false)) and cues == [&"bomber_payload_release"], "accepted production release emits one payload cue")
	var record := release.get("record", {}) as Dictionary
	var terminal := record.duplicate(true)
	terminal["kind"] = &"impact"
	terminal["terminal_sequence"] = 1
	terminal["position"] = Vector3(0.0, 0.0, -30.0)
	terminal["velocity"] = Vector3.ZERO
	terminal["normal"] = Vector3.UP
	terminal["resolver_ready"] = true
	var terminal_result := bomber.present_payload_terminal_record(terminal)
	_check(bool(terminal_result.get("accepted", false)) and semantic_cues == [&"bomber_payload_release", &"bomber_payload_projectile_impact"], "accepted resolver terminal record emits one impact cue")
	_check(not bool(bomber.present_payload_terminal_record(terminal).get("accepted", false)), "replayed terminal record is rejected by production presentation")
	var reset := bomber.reset_for_reuse(Transform3D.IDENTITY)
	var reset_audio: Dictionary = binding.get_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and not bool(bomber.get_payload_authority_snapshot().get("active", true))
			and not bool(reset_audio.get("attached", true))
			and (reset_audio.get("active_cue_slots", []) as Array).is_empty()
			and (reset_audio.get("last_snapshot", {}) as Dictionary).is_empty()
			and (reset_audio.get("projectile_audio", {}) as Dictionary).is_empty(),
		"HeroShip reuse retires payload authority and every old-generation audio slot",
	)
	_check(
		binding.present_release_record(record).get("reason", &"") == &"not_attached",
		"the reused craft rejects an old release while payload audio is offline",
	)
	_check(
		bool(bomber.reset_payload_for_reuse(2).get("accepted", false))
			and bool(binding.get_snapshot().get("attached", false))
			and int(binding.get_snapshot().get("generation", -1)) == 2,
		"the next payload generation reattaches one clean audio lifecycle",
	)
	_check(
		binding.present_release_record(record).get("reason", &"") == &"stale_generation",
		"the reattached audio lifecycle rejects a record from before reuse",
	)
	bomber.detach_payload_authority()
	_check(not bool(binding.get_snapshot().attached), "payload detach clears the production audio binding")
	bomber.queue_free()
	for failure in _failures:
		push_error(failure)
	print("CINDER_BOMBER_PAYLOAD_AUDIO_INTEGRATION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
