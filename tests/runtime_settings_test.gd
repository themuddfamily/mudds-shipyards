extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")

var _failures: Array[String] = []
var _setting_events: Array[Dictionary] = []
var _batch_events: Array[PackedStringArray] = []
var _resource_changed_count := 0
var _temp_path := ""
var _reentrant_settings: RuntimeSettings
var _reentrant_callback_count := 0
var _reentrant_mutation_fired := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_temp_path = "user://runtime_settings_test_%d.cfg" % Time.get_ticks_usec()
	_cleanup_temp_files()
	_test_defaults_and_descriptors()
	_test_validation_and_signals()
	_test_reentrant_batch_signals()
	_test_round_trip_and_stable_storage()
	_test_safe_loading()
	_test_explicit_audio_application()
	_test_window_application_contract()
	_cleanup_temp_files()
	_finish()


func _test_defaults_and_descriptors() -> void:
	var settings := Settings.new(_temp_path)
	_check(settings.config_path == _temp_path, "constructor accepts an isolated config path")
	_check(is_equal_approx(settings.ship_mouse_sensitivity, 0.0022), "ship sensitivity matches the current flight default")
	_check(is_equal_approx(settings.on_foot_mouse_sensitivity, 0.0025), "on-foot sensitivity matches the current player default")
	_check(not settings.invert_ship_y and not settings.invert_on_foot_y, "vertical look is not inverted by default")
	_check(is_equal_approx(settings.camera_fov, 72.0), "camera FOV matches the current chase-camera default")
	_check(
		is_equal_approx(settings.master_volume, 1.0)
		and is_equal_approx(settings.ambience_volume, 1.0)
		and is_equal_approx(settings.engine_volume, 1.0)
		and is_equal_approx(settings.weapons_volume, 1.0)
		and is_equal_approx(settings.ui_volume, 1.0),
		"audio sliders default to neutral gain"
	)
	_check(settings.graphics_profile == Settings.GraphicsProfile.HIGH, "graphics defaults to the high profile")
	_check(settings.window_mode == Settings.WindowMode.WINDOWED, "display defaults to a resizable window")
	_check(settings.control_preset == Settings.ControlPreset.MODERN, "controls default to the modern preset")
	_check(settings.get_graphics_profile_id() == &"high", "graphics exposes a stable high ID")
	_check(settings.get_window_mode_id() == &"windowed", "window mode exposes a stable windowed ID")
	_check(settings.get_control_preset_id() == &"modern", "controls expose a stable modern ID")
	_check(is_equal_approx(settings.ui_scale, 1.0), "UI scale defaults to the authored one-to-one presentation")
	_check(settings.colorblind_palette == Settings.ColorblindPalette.NONE, "colour-vision preset defaults to the authored palette")
	_check(not settings.reduced_motion, "reduced motion is off by default")
	_check(not settings.captions_enabled, "audio cue captions are off by default")
	_check(settings.get_colorblind_palette_id() == &"none", "colour-vision preset exposes a stable off ID")
	var accessibility: Dictionary = settings.get_accessibility_descriptor()
	_check(
		accessibility == {
			"ui_scale": 1.0,
			"colorblind_palette": Settings.ColorblindPalette.NONE,
			"colorblind_palette_id": &"none",
			"reduced_motion": false,
			"captions_enabled": false,
		},
		"the accessibility descriptor exposes exactly the four presentation presets"
	)

	var modern: Dictionary = settings.get_control_preset_descriptor(Settings.ControlPreset.MODERN)
	var classic: Dictionary = settings.get_control_preset_descriptor(Settings.ControlPreset.CLASSIC)
	_check(modern.get("id") == &"modern" and modern.get("applies_input_map") == false, "modern preset is descriptive and side-effect free")
	_check(classic.get("id") == &"classic" and classic.get("applies_input_map") == false, "classic preset is descriptive and does not claim remapping")
	_check((classic.get("key_hints") as Dictionary).get("engine_start") == "Y", "classic descriptor preserves the original engine-start hint")
	_check((classic.get("key_hints") as Dictionary).get("barrel_roll") == "G", "classic descriptor preserves the original barrel-roll hint")
	_check(settings.get_control_preset_descriptor(999).is_empty(), "invalid control presets have no implicit descriptor")
	_check(settings.get_control_preset_descriptor(-2).is_empty(), "only -1 selects the active control descriptor")

	# Deep copies keep menu code from corrupting the canonical descriptors.
	(classic["key_hints"] as Dictionary)["engine_start"] = "Changed"
	classic["label"] = "Changed"
	var detached: Dictionary = settings.get_control_preset_descriptor(Settings.ControlPreset.CLASSIC)
	_check(detached.get("label") == "Classic" and (detached["key_hints"] as Dictionary)["engine_start"] == "Y", "control descriptors are detached deep copies")

	var levels: Dictionary = settings.get_audio_bus_levels_db()
	_check(is_equal_approx(float(levels[&"Master"]), 0.0), "neutral master gain retains the authored 0 dB level")
	_check(is_equal_approx(float(levels[&"Ambience"]), -3.0), "neutral ambience gain retains the authored -3 dB mix")
	_check(is_equal_approx(float(levels[&"Engines"]), -1.0), "neutral engine gain retains the authored -1 dB mix")
	_check(is_equal_approx(float(levels[&"Weapons"]), -1.0), "neutral weapons gain retains the authored -1 dB mix")
	_check(is_equal_approx(float(levels[&"UI"]), -2.0), "neutral UI gain retains the authored -2 dB mix")
	_check(is_equal_approx(float(levels[&"Music"]), -6.0), "neutral music gain retains the authored -6 dB mix")

	var fallback_path_settings := Settings.new("")
	_check(fallback_path_settings.config_path == Settings.DEFAULT_CONFIG_PATH, "empty injected paths fall back to the safe user path")


func _test_validation_and_signals() -> void:
	var settings := Settings.new(_temp_path)
	settings.setting_changed.connect(_on_setting_changed)
	settings.settings_changed.connect(_on_settings_changed)
	settings.changed.connect(_on_resource_changed)
	_clear_signal_log()

	settings.ship_mouse_sensitivity = -10.0
	settings.on_foot_mouse_sensitivity = 99.0
	settings.camera_fov = 1.0
	settings.master_volume = -1.0
	settings.ambience_volume = 2.0
	_check(is_equal_approx(settings.ship_mouse_sensitivity, Settings.MIN_SHIP_MOUSE_SENSITIVITY), "ship sensitivity clamps to its lower bound")
	_check(is_equal_approx(settings.on_foot_mouse_sensitivity, Settings.MAX_ON_FOOT_MOUSE_SENSITIVITY), "on-foot sensitivity clamps to its upper bound")
	_check(is_equal_approx(settings.camera_fov, Settings.MIN_CAMERA_FOV), "FOV clamps to its lower bound")
	_check(is_equal_approx(settings.master_volume, 0.0) and is_equal_approx(settings.ambience_volume, 1.0), "volume sliders clamp to normalized bounds")
	_check(_setting_events.size() == 4, "only effective setting changes emit individual notifications")
	_check(_batch_events.size() == 4 and _resource_changed_count == 4, "ordinary changes emit one batch and one Resource change each")

	# Reassigning effective values, including another out-of-range value that
	# clamps to the same limit, emits nothing.
	_clear_signal_log()
	settings.ship_mouse_sensitivity = -2.0
	settings.ambience_volume = 8.0
	_check(_setting_events.is_empty() and _batch_events.is_empty() and _resource_changed_count == 0, "unchanged effective values emit no notifications")

	settings.ship_mouse_sensitivity = NAN
	settings.on_foot_mouse_sensitivity = INF
	settings.camera_fov = -INF
	settings.ui_volume = NAN
	_check(is_equal_approx(settings.ship_mouse_sensitivity, Settings.DEFAULT_SHIP_MOUSE_SENSITIVITY), "NaN ship sensitivity returns to its safe default")
	_check(is_equal_approx(settings.on_foot_mouse_sensitivity, Settings.DEFAULT_ON_FOOT_MOUSE_SENSITIVITY), "infinite on-foot sensitivity returns to its safe default")
	_check(is_equal_approx(settings.camera_fov, Settings.DEFAULT_CAMERA_FOV), "infinite FOV returns to its safe default")
	_check(is_equal_approx(settings.ui_volume, Settings.DEFAULT_UI_VOLUME), "NaN volume returns to its safe default")

	settings.graphics_profile = Settings.GraphicsProfile.LOW
	settings.window_mode = Settings.WindowMode.BORDERLESS
	settings.control_preset = Settings.ControlPreset.CLASSIC
	_check(settings.get_graphics_profile_id() == &"low", "low graphics profile validates")
	_check(settings.get_window_mode_id() == &"borderless", "borderless window mode validates")
	_check(settings.get_control_preset_id() == &"classic", "classic control preset validates")
	settings.graphics_profile = 999
	settings.window_mode = -4
	settings.control_preset = 25
	_check(settings.graphics_profile == Settings.DEFAULT_GRAPHICS_PROFILE, "invalid graphics profile falls back safely")
	_check(settings.window_mode == Settings.DEFAULT_WINDOW_MODE, "invalid window mode falls back safely")
	_check(settings.control_preset == Settings.DEFAULT_CONTROL_PRESET, "invalid control preset falls back safely")

	# Reset and load use deterministic batching while retaining the canonical
	# per-setting signal with its final value.
	settings.ship_mouse_sensitivity = 0.006
	settings.invert_ship_y = true
	settings.camera_fov = 93.0
	settings.graphics_profile = Settings.GraphicsProfile.MEDIUM
	settings.control_preset = Settings.ControlPreset.CLASSIC
	_clear_signal_log()
	settings.reset_to_defaults()
	var expected_reset := PackedStringArray([
		"ship_mouse_sensitivity",
		"invert_ship_y",
		"camera_fov",
		"master_volume",
		"graphics_profile",
		"control_preset",
	])
	_check(_batch_events.size() == 1 and _batch_events[0] == expected_reset, "reset emits one canonical batched change list")
	_check(_setting_events.size() == expected_reset.size(), "reset retains one individual signal per changed value")
	_check(_resource_changed_count == 1, "reset emits one Resource change")
	_clear_signal_log()
	settings.reset_to_defaults()
	_check(_batch_events.is_empty() and _setting_events.is_empty() and _resource_changed_count == 0, "reset is idempotent")


func _test_reentrant_batch_signals() -> void:
	_reentrant_settings = Settings.new(_temp_path)
	_reentrant_settings.ship_mouse_sensitivity = 0.006
	_reentrant_settings.invert_ship_y = true
	_reentrant_settings.setting_changed.connect(_on_setting_changed)
	_reentrant_settings.setting_changed.connect(_on_reentrant_setting_changed)
	_reentrant_settings.settings_changed.connect(_on_settings_changed)
	_reentrant_settings.changed.connect(_on_resource_changed)
	_reentrant_callback_count = 0
	_clear_signal_log()

	# The first callback synchronously invokes another (idempotent) batched reset.
	# Shared pending state must already be clear, or this recursively re-emits the
	# original batch until the stack overflows.
	_reentrant_settings.reset_to_defaults()
	_check(_reentrant_callback_count == 2, "re-entrant reset receives each outer setting exactly once")
	_check(_setting_events.size() == 2, "re-entrant callbacks do not duplicate individual signals")
	_check(_batch_events.size() == 1 and _batch_events[0] == PackedStringArray(["ship_mouse_sensitivity", "invert_ship_y"]), "re-entrant callbacks preserve one outer batch")
	_check(_resource_changed_count == 1, "re-entrant callbacks preserve one Resource change")
	_reentrant_settings = null

	# A callback may alter both a later member of the active batch and a property
	# whose callback already ran. The former must emit its latest value once; the
	# latter belongs to one deterministic follow-up batch.
	_reentrant_settings = Settings.new(_temp_path)
	_reentrant_settings.ship_mouse_sensitivity = 0.006
	_reentrant_settings.invert_ship_y = true
	_reentrant_settings.setting_changed.connect(_on_setting_changed)
	_reentrant_settings.setting_changed.connect(_on_reentrant_mutation_changed)
	_reentrant_settings.settings_changed.connect(_on_settings_changed)
	_reentrant_settings.changed.connect(_on_resource_changed)
	_reentrant_mutation_fired = false
	_clear_signal_log()
	_reentrant_settings.reset_to_defaults()
	_check(
		_setting_events.size() == 3
		and _setting_events[0]["setting"] == &"ship_mouse_sensitivity"
		and is_equal_approx(float(_setting_events[0]["value"]), Settings.DEFAULT_SHIP_MOUSE_SENSITIVITY)
		and _setting_events[1] == {"setting": &"invert_ship_y", "value": true}
		and _setting_events[2]["setting"] == &"ship_mouse_sensitivity"
		and is_equal_approx(float(_setting_events[2]["value"]), 0.004),
		"re-entrant mutations emit current values without stale or duplicate callbacks"
	)
	_check(
		_batch_events == [
			PackedStringArray(["ship_mouse_sensitivity", "invert_ship_y"]),
			PackedStringArray(["ship_mouse_sensitivity"]),
		],
		"re-entrant mutations are ordered into one follow-up batch"
	)
	_check(_resource_changed_count == 2, "each effective re-entrant batch emits one Resource change")
	_reentrant_settings = null


func _test_round_trip_and_stable_storage() -> void:
	var original := Settings.new(_temp_path)
	original.ship_mouse_sensitivity = 0.0073
	original.on_foot_mouse_sensitivity = 0.0081
	original.invert_ship_y = true
	original.invert_on_foot_y = true
	original.camera_fov = 101.0
	original.master_volume = 0.75
	original.ambience_volume = 0.42
	original.engine_volume = 0.67
	original.weapons_volume = 0.81
	original.ui_volume = 0.29
	original.music_volume = 0.53
	original.graphics_profile = Settings.GraphicsProfile.MEDIUM
	original.window_mode = Settings.WindowMode.FULLSCREEN
	original.control_preset = Settings.ControlPreset.CLASSIC
	original.ui_scale = 1.35
	original.colorblind_palette = Settings.ColorblindPalette.PROTANOPIA
	original.reduced_motion = true
	original.captions_enabled = true
	var expected: Dictionary = original.to_dictionary()

	var actions_before := _snapshot_input_map()
	var project_renderer: Variant = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	var audio_before := _snapshot_audio_buses()
	_check(original.save_to_file() == OK, "settings save succeeds at the injected path")
	_check(_snapshot_audio_buses() == audio_before, "save does not apply audio settings")
	_check(_snapshot_input_map() == actions_before, "save does not mutate InputMap")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == project_renderer, "save does not mutate ProjectSettings")

	var stored := ConfigFile.new()
	_check(stored.load(_temp_path) == OK, "saved settings are valid ConfigFile data")
	_check(int(stored.get_value("meta", "schema_version", -1)) == Settings.SCHEMA_VERSION, "save writes a schema version")
	_check(is_equal_approx(float(stored.get_value("audio", "music", 0.0)), 0.53), "the music volume persists in the audio section")
	_check(typeof(stored.get_value("graphics", "profile", null)) == TYPE_STRING and stored.get_value("graphics", "profile") == "medium", "graphics persists as a stable plain-string ID")
	_check(typeof(stored.get_value("display", "window_mode", null)) == TYPE_STRING and stored.get_value("display", "window_mode") == "fullscreen", "window mode persists as a stable plain-string ID")
	_check(typeof(stored.get_value("controls", "preset", null)) == TYPE_STRING and stored.get_value("controls", "preset") == "classic", "control preset persists as a stable plain-string ID")
	_check(
		typeof(stored.get_value("accessibility", "colorblind_palette", null)) == TYPE_STRING
		and stored.get_value("accessibility", "colorblind_palette") == "protanopia",
		"colour-vision preset persists as a stable plain-string ID"
	)
	_check(
		is_equal_approx(float(stored.get_value("accessibility", "ui_scale", 0.0)), 1.35)
		and stored.get_value("accessibility", "reduced_motion") == true
		and stored.get_value("accessibility", "captions") == true,
		"every accessibility preset is written to its own section"
	)

	var restored := Settings.new(_temp_path)
	var audio_before_load := _snapshot_audio_buses()
	restored.setting_changed.connect(_on_setting_changed)
	restored.settings_changed.connect(_on_settings_changed)
	restored.changed.connect(_on_resource_changed)
	_clear_signal_log()
	_check(restored.load_from_file() == OK, "a fresh settings resource loads the injected path")
	_check(restored.to_dictionary() == expected, "every persisted setting round-trips exactly")
	var expected_load_order := PackedStringArray([
		"ship_mouse_sensitivity",
		"on_foot_mouse_sensitivity",
		"invert_ship_y",
		"invert_on_foot_y",
		"control_preset",
		"camera_fov",
		"master_volume",
		"ambience_volume",
		"engine_volume",
		"weapons_volume",
		"ui_volume",
		"music_volume",
		"graphics_profile",
		"window_mode",
		"ui_scale",
		"colorblind_palette",
		"reduced_motion",
		"captions_enabled",
	])
	_check(_batch_events.size() == 1 and _batch_events[0] == expected_load_order, "load emits one deterministic batched change list")
	_check(_setting_events.size() == expected_load_order.size() and _resource_changed_count == 1, "load emits one individual signal per effective change and one Resource change")
	_check(_snapshot_audio_buses() == audio_before_load, "load does not apply audio settings")
	_check(_snapshot_input_map() == actions_before, "load does not mutate InputMap")

	# Overrides are per-call and do not replace the resource's configured path.
	var override_path := _temp_path + ".override"
	_check(restored.save_to_file(override_path) == OK and FileAccess.file_exists(override_path), "save supports a one-shot path override")
	_check(restored.config_path == _temp_path, "path overrides do not mutate the configured path")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(override_path))

	# A colliding staging directory deterministically rejects the staged write.
	# The already-saved target must remain byte-for-byte intact.
	var known_good_text := FileAccess.get_file_as_string(_temp_path)
	restored.camera_fov = 88.0
	var staging_path := _temp_path + ".tmp"
	var absolute_staging_path := ProjectSettings.globalize_path(staging_path)
	_check(DirAccess.make_dir_absolute(absolute_staging_path) == OK, "failed-save staging collision fixture is created")
	_check(restored.save_to_file() == ERR_ALREADY_EXISTS, "staging collisions fail before replacing the target")
	_check(FileAccess.get_file_as_string(_temp_path) == known_good_text, "failed staged saves preserve the last-known-good file exactly")
	_check(DirAccess.remove_absolute(absolute_staging_path) == OK, "staging collision fixture is cleaned")
	_check(restored.save_to_file() == OK, "recoverable replacement succeeds after the collision is removed")
	var atomically_replaced := ConfigFile.new()
	_check(atomically_replaced.load(_temp_path) == OK and is_equal_approx(float(atomically_replaced.get_value("camera", "fov", 0.0)), 88.0), "successful replacement publishes the complete new configuration")
	_check(not FileAccess.file_exists(staging_path), "successful replacement leaves no staging file")

	# Simulate interruption after the live target was moved aside but before the
	# staged successor was published. Loading must restore the verified backup.
	var backup_path := _temp_path + ".bak"
	_check(
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(_temp_path),
			ProjectSettings.globalize_path(backup_path)
		) == OK,
		"interrupted-save backup fixture moves the verified target aside"
	)
	var recovered := Settings.new(_temp_path)
	_check(recovered.load_from_file() == OK, "load recovers an interrupted save from the verified backup")
	_check(FileAccess.file_exists(_temp_path) and not FileAccess.file_exists(backup_path), "backup recovery republishes one canonical target")

	# A file cannot also be used as a parent directory, giving a deterministic
	# write failure without relying on filesystem permissions.
	_check(restored.save_to_file(_temp_path + "/child.cfg") != OK, "save propagates destination errors")


func _test_safe_loading() -> void:
	var settings := Settings.new(_temp_path)
	settings.ship_mouse_sensitivity = 0.0064
	settings.invert_ship_y = true
	var before_failed_load: Dictionary = settings.to_dictionary()
	var missing_path := _temp_path + ".missing"
	_check(settings.load_from_file(missing_path) == ERR_FILE_NOT_FOUND, "missing files return the underlying error")
	_check(settings.to_dictionary() == before_failed_load, "missing-file loads preserve live state")

	var missing_schema_path := _temp_path + ".missing_schema"
	var missing_schema := ConfigFile.new()
	missing_schema.set_value("controls", "ship_mouse_sensitivity", 0.01)
	_check(missing_schema.save(missing_schema_path) == OK, "missing-schema fixture saves")
	_check(settings.load_from_file(missing_schema_path) == ERR_INVALID_DATA, "versioned settings reject missing schema metadata")
	_check(settings.to_dictionary() == before_failed_load, "missing-schema loads preserve live state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_schema_path))

	var malformed_path := _temp_path + ".malformed"
	var malformed := ConfigFile.new()
	malformed.set_value("meta", "schema_version", "one")
	malformed.set_value("controls", "ship_mouse_sensitivity", 0.01)
	_check(malformed.save(malformed_path) == OK, "malformed-settings fixture saves")
	_check(settings.load_from_file(malformed_path) == ERR_INVALID_DATA, "malformed schema types fail closed")
	_check(settings.to_dictionary() == before_failed_load, "malformed settings preserve live state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(malformed_path))

	var future_path := _temp_path + ".future"
	var future := ConfigFile.new()
	future.set_value("meta", "schema_version", Settings.SCHEMA_VERSION + 1)
	future.set_value("controls", "ship_mouse_sensitivity", 0.01)
	_check(future.save(future_path) == OK, "future-schema fixture saves")
	_check(settings.load_from_file(future_path) == ERR_INVALID_DATA, "unsupported future schemas fail closed")
	_check(settings.to_dictionary() == before_failed_load, "future-schema loads preserve live state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(future_path))

	# Sparse files start from authored defaults, not from the object's history.
	var sparse := ConfigFile.new()
	sparse.set_value("meta", "schema_version", Settings.SCHEMA_VERSION)
	sparse.set_value("controls", "ship_mouse_sensitivity", 1.0)
	sparse.set_value("controls", "on_foot_mouse_sensitivity", "fast")
	sparse.set_value("controls", "invert_ship_y", "yes")
	sparse.set_value("controls", "invert_on_foot_y", true)
	sparse.set_value("controls", "preset", "CLASSIC")
	sparse.set_value("camera", "fov", 999)
	sparse.set_value("audio", "master", true)
	sparse.set_value("audio", "ambience", -2.0)
	sparse.set_value("audio", "engine", 4.0)
	sparse.set_value("audio", "weapons", "loud")
	sparse.set_value("audio", "ui", 0.4)
	sparse.set_value("graphics", "profile", "ultra")
	sparse.set_value("display", "window_mode", "BORDERLESS")
	sparse.set_value("unknown", "ignored_object", Vector3.ONE)
	_check(sparse.save(_temp_path) == OK, "sparse validation fixture saves")

	settings.master_volume = 0.2
	settings.weapons_volume = 0.3
	settings.graphics_profile = Settings.GraphicsProfile.LOW
	settings.window_mode = Settings.WindowMode.FULLSCREEN
	var audio_before := _snapshot_audio_buses()
	_check(settings.load_from_file() == OK, "sparse configuration loads")
	_check(is_equal_approx(settings.ship_mouse_sensitivity, Settings.MAX_SHIP_MOUSE_SENSITIVITY), "finite loaded sensitivity clamps")
	_check(is_equal_approx(settings.on_foot_mouse_sensitivity, Settings.DEFAULT_ON_FOOT_MOUSE_SENSITIVITY), "wrong sensitivity type falls back to default")
	_check(not settings.invert_ship_y and settings.invert_on_foot_y, "boolean loads require real bool values")
	_check(settings.control_preset == Settings.ControlPreset.CLASSIC, "known IDs load case-insensitively")
	_check(is_equal_approx(settings.camera_fov, Settings.MAX_CAMERA_FOV), "loaded FOV clamps")
	_check(is_equal_approx(settings.master_volume, 1.0), "boolean numeric impostor falls back to the volume default")
	_check(is_equal_approx(settings.ambience_volume, 0.0) and is_equal_approx(settings.engine_volume, 1.0), "loaded volumes clamp at both bounds")
	_check(is_equal_approx(settings.weapons_volume, 1.0) and is_equal_approx(settings.ui_volume, 0.4), "missing/wrong and valid volume values resolve independently")
	_check(settings.graphics_profile == Settings.GraphicsProfile.HIGH, "unknown graphics IDs fall back to high")
	_check(settings.window_mode == Settings.WindowMode.BORDERLESS, "known window IDs load case-insensitively")
	_check(_snapshot_audio_buses() == audio_before, "validated load still has no AudioServer side effect")


func _test_explicit_audio_application() -> void:
	var settings := Settings.new(_temp_path)
	var before := _snapshot_audio_buses()
	settings.master_volume = 0.5
	settings.ambience_volume = 0.25
	settings.engine_volume = 0.75
	settings.weapons_volume = 0.0
	settings.ui_volume = 0.6
	_check(_snapshot_audio_buses() == before, "audio property setters do not touch AudioServer")

	var expected: Dictionary = settings.get_audio_bus_levels_db()
	_check(is_equal_approx(float(expected[&"Weapons"]), Settings.SILENCE_DB), "zero volume maps to a finite silence floor")
	var report: Dictionary = settings.apply_audio_settings()
	var all_buses_present := true
	for bus_name: StringName in expected:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			all_buses_present = false
			continue
		_check(is_equal_approx(AudioServer.get_bus_volume_db(bus_index), float(expected[bus_name])), "explicit audio application updates %s" % bus_name)
	_check(bool(report["applied"]), "audio application reports at least one applied bus")
	_check(bool(report["complete"]) == all_buses_present, "audio report identifies whether every named bus exists")

	var ui_bus_index := AudioServer.get_bus_index(&"UI")
	if ui_bus_index >= 0:
		AudioServer.set_bus_name(ui_bus_index, &"RuntimeSettingsTestHiddenUI")
		var missing_report: Dictionary = settings.apply_audio_settings()
		_check(not bool(missing_report["complete"]), "audio application reports an incomplete named-bus set")
		_check((missing_report["missing_buses"] as PackedStringArray).has("UI"), "audio application identifies the exact missing bus")
		AudioServer.set_bus_name(ui_bus_index, &"UI")
	else:
		_check((report["missing_buses"] as PackedStringArray).has("UI"), "pre-existing missing UI bus is reported")

	# Restore the shared runner state so this test has no lasting audio effect.
	for bus_name: StringName in before:
		var restore_index := AudioServer.get_bus_index(bus_name)
		if restore_index >= 0:
			AudioServer.set_bus_volume_db(restore_index, float(before[bus_name]))
	_check(_snapshot_audio_buses() == before, "audio test restores every shared bus level")


func _test_window_application_contract() -> void:
	var settings := Settings.new(_temp_path)
	var input_before := _snapshot_input_map()
	var descriptors := {
		Settings.WindowMode.WINDOWED: [&"windowed", DisplayServer.WINDOW_MODE_WINDOWED, false],
		Settings.WindowMode.BORDERLESS: [&"borderless", DisplayServer.WINDOW_MODE_WINDOWED, true],
		Settings.WindowMode.FULLSCREEN: [&"fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN, false],
	}
	for mode: int in descriptors:
		settings.window_mode = mode
		var descriptor: Dictionary = settings.get_window_mode_descriptor()
		var expected: Array = descriptors[mode]
		_check(descriptor.get("id") == expected[0], "%s window mode exposes its stable ID" % expected[0])
		_check(descriptor.get("display_mode") == expected[1] and descriptor.get("borderless") == expected[2], "%s maps to explicit DisplayServer state" % expected[0])
	_check(_snapshot_input_map() == input_before, "window and preset state never mutate InputMap")

	if DisplayServer.get_name() == "headless":
		settings.window_mode = Settings.WindowMode.FULLSCREEN
		var report: Dictionary = settings.apply_window_mode()
		_check(not bool(report["applied"]) and report["reason"] == &"headless", "window application is an explicit headless no-op")
	else:
		var original_mode := DisplayServer.window_get_mode()
		var original_borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

		settings.window_mode = Settings.WindowMode.WINDOWED
		var windowed_report: Dictionary = settings.apply_window_mode()
		_check(bool(windowed_report["applied"]) and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "explicit windowed application changes the runtime window")
		_check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "windowed application clears a sticky borderless flag")

		settings.window_mode = Settings.WindowMode.BORDERLESS
		var borderless_report: Dictionary = settings.apply_window_mode()
		_check(bool(borderless_report["applied"]) and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "borderless remains a window rather than masquerading as fullscreen")
		_check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "explicit borderless application sets the runtime flag")

		settings.window_mode = Settings.WindowMode.FULLSCREEN
		var fullscreen_report: Dictionary = settings.apply_window_mode()
		_check(bool(fullscreen_report["applied"]) and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "explicit fullscreen application changes the runtime window")
		_check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "fullscreen application clears the separate borderless flag")

		# Restore the runner's complete window state so even graphical tests are
		# isolated from the developer's session.
		if original_borderless:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		else:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(original_mode)
		_check(
			DisplayServer.window_get_mode() == original_mode
			and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) == original_borderless,
			"graphical window test restores the runner's original state"
		)


func _snapshot_audio_buses() -> Dictionary:
	var snapshot := {}
	for bus_name: StringName in [&"Master", &"Ambience", &"Engines", &"Weapons", &"UI", &"Music"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			snapshot[bus_name] = AudioServer.get_bus_volume_db(index)
	return snapshot


func _snapshot_input_map() -> Dictionary:
	var snapshot := {}
	for action: StringName in InputMap.get_actions():
		var events := PackedStringArray()
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event.as_text())
		snapshot[action] = events
	return snapshot


func _on_setting_changed(setting: StringName, value: Variant) -> void:
	_setting_events.append({"setting": setting, "value": value})


func _on_settings_changed(settings: PackedStringArray) -> void:
	_batch_events.append(settings.duplicate())


func _on_resource_changed() -> void:
	_resource_changed_count += 1


func _on_reentrant_setting_changed(_setting: StringName, _value: Variant) -> void:
	_reentrant_callback_count += 1
	if _reentrant_callback_count == 1:
		_reentrant_settings.reset_to_defaults()


func _on_reentrant_mutation_changed(setting: StringName, _value: Variant) -> void:
	if _reentrant_mutation_fired or setting != &"ship_mouse_sensitivity":
		return
	_reentrant_mutation_fired = true
	_reentrant_settings.invert_ship_y = true
	_reentrant_settings.ship_mouse_sensitivity = 0.004


func _clear_signal_log() -> void:
	_setting_events.clear()
	_batch_events.clear()
	_resource_changed_count = 0


func _cleanup_temp_files() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".override", ".override.tmp", ".override.bak", ".missing", ".missing_schema", ".malformed", ".future"]:
		var absolute_path := ProjectSettings.globalize_path(_temp_path + suffix)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
		elif DirAccess.dir_exists_absolute(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("RUNTIME_SETTINGS_TEST_OK")
		quit(0)
	else:
		print("RUNTIME_SETTINGS_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
