extends SceneTree

const ContractScript := preload("res://scripts/ui/caption_accessibility_contract.gd")
var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	var contract := ContractScript.new()
	_check(bool(contract.resolve_cue(_cue(&"radio", 10, true, "Message" )).accepted), "default profile presents an audible cue")
	var fallback := contract.resolve_cue(_cue(&"system", 70, false, ""))
	_check(bool(fallback.accepted) and bool(fallback.inaudible_fallback) and fallback.text == "[inaudible]", "inaudible empty cue receives a stable textual fallback")
	_check(contract.configure({"verbosity": &"dialogue_only"}).accepted, "verbosity profile accepts a bounded dialogue-only mode")
	_check(contract.resolve_cue(_cue(&"system", 70, true, "System")).reason == &"verbosity_filtered", "dialogue-only verbosity filters non-dialogue cues")
	_check(bool(contract.resolve_cue(_cue(&"dialogue", 1, true, "Dialogue")).accepted), "dialogue-only verbosity retains dialogue")
	_check(contract.configure({"verbosity": &"important_only", "high_contrast": true, "reduced_motion": true, "reduced_flash": true}).accepted, "visual accessibility flags configure atomically")
	var visual := contract.get_visual_policy()
	_check(bool(visual.high_contrast) and bool(visual.reduced_motion) and bool(visual.reduced_flash) and float(visual.contrast_ratio_minimum) >= 7.0, "visual policy freezes contrast and reduced-motion/flash guarantees")
	var important := contract.resolve_cue(_cue(&"radio", 50, false, "Radio"))
	_check(bool(important.accepted) and important.visual_policy.transition_policy == &"steady_no_motion" and important.visual_policy.flash_policy == &"steady_no_flash", "accepted cue carries steady visual policy without animation authority")
	_check(contract.configure({"verbosity": &"off"}).accepted and contract.resolve_cue(_cue(&"dialogue", 100, true, "Off")).reason == &"captions_disabled", "off verbosity disables presentation without touching cue observation")
	_check(not bool(contract.configure({"verbosity": &"bogus"}).accepted), "unknown verbosity fails closed")
	var audit := contract.audit()
	_check(bool(audit.valid) and not bool(audit.audio_authority) and not bool(audit.audio_playback) and not bool(audit.caption_queue_authority) and not bool(audit.settings_authority), "audit explicitly grants no audio/playback, queue, or settings authority")
	_check(not bool(contract.resolve_cue({"stable_id": &"bad", "category": &"dialogue", "audible": "yes", "priority": 1}).accepted), "malformed audibility observation fails closed")
	if _failures.is_empty():
		print("CAPTION_ACCESSIBILITY_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("CAPTION_ACCESSIBILITY_CONTRACT_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)

func _cue(category: StringName, priority: int, audible: bool, text: String) -> Dictionary:
	return {"stable_id": StringName("cue_%s_%d" % [str(category), _assertions]), "category": category, "priority": priority, "audible": audible, "speaker": "Speaker", "text": text}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)
