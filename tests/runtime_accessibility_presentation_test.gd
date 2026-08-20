extends SceneTree

const Contract := preload("res://scripts/ui/runtime_accessibility_presentation.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var contract := Contract.new()
	_check(bool(contract.audit().valid), "composed accessibility policies start valid")
	_check(bool(contract.audit().presentation_only), "runtime adapter publishes a presentation-only boundary")
	var configured := contract.configure({
		"visual": {"colour_safe_cues": true, "reduced_flash": true, "reduced_motion": true, "ui_scale": 1.25},
		"captions": {"verbosity": &"all", "high_contrast": true},
		"audio": {"subtitle_verbosity": 2},
	})
	_check(bool(configured.accepted) and int(configured.revision) == 1, "visual, caption and audio policies apply atomically")
	var cue := contract.resolve_cue({
		"cue_id": &"reactor_warning",
		"visual_category": &"danger",
		"caption_category": &"system",
		"audible": false,
		"key_cue": true,
		"priority": 90,
		"text": "",
		"bus": &"UI",
	})
	_check(bool(cue.accepted), "an observed cue produces a composed presentation result")
	_check(bool(cue.visual.shape_cue != &"none") and is_zero_approx(float(cue.visual.flash_strength)) and is_zero_approx(float(cue.visual.motion_strength)), "visual reduced-motion and colour-safe alternatives survive composition")
	_check(bool(cue.caption.accepted) and bool(cue.caption.inaudible_fallback) and cue.caption.text == "[inaudible]", "inaudible cues receive a textual caption fallback")
	_check(not bool(cue.gameplay_authority) and not bool(cue.audio_authority) and not bool(cue.caption_authority), "composed decisions grant no runtime authority")
	var fitted := contract.fit_prompt(Vector2(5120, 1440), Vector2(520, 88), &"bottom_center")
	_check(bool(fitted.valid) and not bool(fitted.clipped) and fitted.safe_rect.encloses(fitted.rect), "32:9 prompts fit the shared scaled safe area")
	var prompts := contract.get_server_browser_prompts()
	_check(prompts.refresh == "Refresh server list" and prompts.join_hint is String and not str(prompts.empty_results).is_empty(), "server-browser prompts remain textual and actionable")
	var before := contract.get_snapshot()
	var rejected := contract.configure({"visual": {"ui_scale": 99.0}, "audio": {"bus_ceilings": {&"NotABus": 0.0}}})
	_check(not bool(rejected.accepted) and int(contract.get_snapshot().revision) == int(before.revision), "malformed cross-policy changes reject without advancing the runtime revision")
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RUNTIME_ACCESSIBILITY_PRESENTATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("RUNTIME_ACCESSIBILITY_PRESENTATION_TEST_FAILED: %d/%d failed" % [_failures.size(), _assertions])
		quit(1)
