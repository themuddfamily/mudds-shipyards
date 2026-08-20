extends SceneTree

const Preset := preload("res://scripts/audio/audio_accessibility_preset.gd")
var _assertions := 0
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var preset = Preset.new()
	_check(preset.get_snapshot().subtitle_verbosity == Preset.SubtitleVerbosity.OFF, "preset starts with subtitles off")
	var applied := preset.configure({"reduced_flash": true, "reduced_motion": true, "subtitle_verbosity": Preset.SubtitleVerbosity.KEY_CUES, "bus_ceilings": {&"Weapons": -12.0, &"UI": -6.0}})
	_check(bool(applied.accepted) and int(applied.generation) == 1, "accessibility settings apply atomically and advance one generation")
	var key := preset.resolve_cue(&"impact", &"Weapons", true, 0.8, 0.6)
	_check(bool(key.accepted) and bool(key.show_subtitle) and is_zero_approx(float(key.flash_strength)) and is_zero_approx(float(key.motion_strength)), "reduced flash and motion remove visual/motion intensities while retaining key subtitles")
	_check(is_equal_approx(float(key.bus_ceiling_db), -12.0), "cue receives its configured bus ceiling")
	var non_key := preset.resolve_cue(&"engine_loop", &"Engines", false)
	_check(not bool(non_key.show_subtitle), "key-cue subtitle mode suppresses non-key subtitles")
	var all := preset.configure({"subtitle_verbosity": Preset.SubtitleVerbosity.ALL_CUES})
	_check(bool(all.accepted) and bool(preset.resolve_cue(&"engine_loop", &"Engines").show_subtitle), "all-cue subtitle mode exposes non-key subtitles")
	var before := preset.get_snapshot()
	var rejected := preset.configure({"reduced_flash": false, "bus_ceilings": {&"Weapons": 4.0}})
	_check(not bool(rejected.accepted) and int(preset.get_snapshot().generation) == int(before.generation), "invalid ceiling rejects atomically without changing the active preset")
	var snapshot := preset.get_snapshot()
	(snapshot.bus_ceilings as Dictionary)[&"Weapons"] = -80.0
	_check(is_equal_approx(float((preset.get_snapshot().bus_ceilings as Dictionary)[&"Weapons"]), -12.0), "snapshots detach bus ceiling state")
	var audit := preset.audit()
	_check(bool(audit.valid) and bool(audit.presentation_only) and not bool(audit.gameplay_authority), "audit freezes the presentation-only boundary")
	_check(not bool(preset.resolve_cue(&"bad", &"Unknown").accepted), "unknown buses fail closed")
	_finish()

func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("AUDIO_ACCESSIBILITY_PRESET_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
