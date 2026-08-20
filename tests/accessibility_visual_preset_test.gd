extends SceneTree

## Focused contract checks for the detached visual accessibility policy.

const Preset := preload("res://scripts/ui/accessibility_visual_preset.gd")
var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var preset := Preset.new()
	_check(preset.get_snapshot().generation == 0, "a new preset starts at generation zero")
	_check(preset.audit().valid and preset.audit().presentation_only, "the contract publishes finite contrast and presentation-only boundaries")
	var applied := preset.configure({
		"reduced_flash": true,
		"reduced_motion": true,
		"colour_safe_cues": true,
		"contrast_mode": Preset.ContrastMode.HIGH,
		"ui_scale": 1.35,
	})
	_check(bool(applied.accepted) and int(applied.generation) == 1, "the complete visual preset applies as one generation")
	var cue := preset.resolve_cue(&"reactor_warning", &"danger", false, true, true, 7.0)
	_check(
		bool(cue.accepted)
		and is_zero_approx(float(cue.flash_strength))
		and is_zero_approx(float(cue.motion_strength))
		and cue.shape_cue != &"none"
		and not bool(cue.colour_channel_allowed)
		and cue.contrast_mode == Preset.ContrastMode.HIGH,
		"reduced flash/motion and colour-safe shape cues are emitted together"
	)
	_check(bool(cue.show_caption) and cue.caption_reason == &"audio_fallback", "an inaudible key cue requests a subtitle fallback")
	_check(not bool(cue.gameplay_authority) and not bool(cue.audio_authority) and not bool(cue.caption_authority), "visual decisions cannot grant gameplay, audio or caption authority")
	var before := preset.get_snapshot()
	var rejected := preset.configure({"reduced_flash": "yes", "ui_scale": 9.0})
	_check(not bool(rejected.accepted) and preset.get_snapshot() == before, "malformed combined requests reject atomically without partial accessibility changes")
	var invalid_cue := preset.resolve_cue(&"", &"danger", true, true)
	_check(not bool(invalid_cue.accepted) and invalid_cue.reason == &"invalid_cue", "empty or unknown cues reject without presentation output")
	var invalid_contrast := preset.resolve_cue(&"info", &"info", true, false, false, 2.9)
	_check(not bool(invalid_contrast.accepted) and invalid_contrast.reason == &"insufficient_contrast", "below-large-text contrast rejects rather than claiming legibility")
	var detached := preset.get_snapshot()
	detached["reduced_flash"] = false
	_check(bool(preset.get_snapshot().reduced_flash), "returned snapshots are detached from policy state")
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ACCESSIBILITY_VISUAL_PRESET_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("ACCESSIBILITY_VISUAL_PRESET_TEST_FAIL: %d/%d failed" % [_failures.size(), _assertions])
		quit(1)
