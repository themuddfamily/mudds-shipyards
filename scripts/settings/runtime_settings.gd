class_name RuntimeSettings
extends Resource

## Persisted, side-effect-free local preferences for a Keth Shipyards client.
##
## Constructing, loading, changing, or resetting this resource never changes
## AudioServer, DisplayServer, InputMap, or ProjectSettings. Runtime systems opt
## into the two global side effects through [method apply_audio_settings] and
## [method apply_window_mode]. Other values are intended to be consumed by the
## player, ship, camera, and visual-quality controllers.

signal setting_changed(setting: StringName, value: Variant)
signal settings_changed(settings: PackedStringArray)

enum GraphicsProfile {
	LOW,
	MEDIUM,
	HIGH,
}

enum WindowMode {
	WINDOWED,
	BORDERLESS,
	FULLSCREEN,
}

enum ControlPreset {
	MODERN,
	CLASSIC,
}

## Colour-vision presets for HUD state signalling. NONE keeps the authored
## cyan/amber/red set; the remaining entries select palettes whose separation
## under the matching dichromacy simulation is verified by
## `tests/accessibility_presets_test.gd`, not merely asserted.
enum ColorblindPalette {
	NONE,
	DEUTERANOPIA,
	PROTANOPIA,
	TRITANOPIA,
}

## Written by every save. Files stamped with any version in
## [constant MINIMUM_SUPPORTED_SCHEMA_VERSION]..[constant SCHEMA_VERSION] load
## and are upgraded in memory; keys a older writer never stored fall back to
## their authored defaults. Anything outside that range still fails closed.
const SCHEMA_VERSION := 3
const MINIMUM_SUPPORTED_SCHEMA_VERSION := 1
const DEFAULT_CONFIG_PATH := "user://settings.cfg"
const _STAGING_SUFFIX := ".tmp"
const _BACKUP_SUFFIX := ".bak"

const MIN_SHIP_MOUSE_SENSITIVITY := 0.0002
const MAX_SHIP_MOUSE_SENSITIVITY := 0.02
const DEFAULT_SHIP_MOUSE_SENSITIVITY := 0.0022

const MIN_ON_FOOT_MOUSE_SENSITIVITY := 0.0005
const MAX_ON_FOOT_MOUSE_SENSITIVITY := 0.02
const DEFAULT_ON_FOOT_MOUSE_SENSITIVITY := 0.0025

const MIN_CAMERA_FOV := 55.0
const MAX_CAMERA_FOV := 110.0
const DEFAULT_CAMERA_FOV := 72.0

const MIN_VOLUME := 0.0
const MAX_VOLUME := 1.0
const SILENCE_DB := -80.0
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_AMBIENCE_VOLUME := 1.0
const DEFAULT_ENGINE_VOLUME := 1.0
const DEFAULT_WEAPONS_VOLUME := 1.0
const DEFAULT_UI_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0

const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.6
const DEFAULT_UI_SCALE := 1.0

const DEFAULT_GRAPHICS_PROFILE := GraphicsProfile.HIGH
const DEFAULT_WINDOW_MODE := WindowMode.WINDOWED
const DEFAULT_CONTROL_PRESET := ControlPreset.MODERN
const DEFAULT_COLORBLIND_PALETTE := ColorblindPalette.NONE
const DEFAULT_REDUCED_MOTION := false
const DEFAULT_CAPTIONS_ENABLED := false

const _SECTION_META := "meta"
const _SECTION_CONTROLS := "controls"
const _SECTION_CAMERA := "camera"
const _SECTION_AUDIO := "audio"
const _SECTION_GRAPHICS := "graphics"
const _SECTION_DISPLAY := "display"
const _SECTION_ACCESSIBILITY := "accessibility"

const _COLORBLIND_PALETTE_IDS := {
	ColorblindPalette.NONE: &"none",
	ColorblindPalette.DEUTERANOPIA: &"deuteranopia",
	ColorblindPalette.PROTANOPIA: &"protanopia",
	ColorblindPalette.TRITANOPIA: &"tritanopia",
}

const _AUDIO_BUS_PROPERTIES := {
	&"Master": &"master_volume",
	&"Ambience": &"ambience_volume",
	&"Engines": &"engine_volume",
	&"Weapons": &"weapons_volume",
	&"UI": &"ui_volume",
	&"Music": &"music_volume",
}

# User volumes are gain multipliers over the authored bus mix. A default 100%
# slider therefore preserves the current -3/-1/-1/-2/-6 dB balance rather than
# flattening every category to 0 dB the first time settings are applied.
const _AUDIO_BUS_BASE_DB := {
	&"Master": 0.0,
	&"Ambience": -3.0,
	&"Engines": -1.0,
	&"Weapons": -1.0,
	&"UI": -2.0,
	&"Music": -6.0,
}

const _CONTROL_PRESET_DESCRIPTORS := {
	ControlPreset.MODERN: {
		"id": &"modern",
		"label": "Modern",
		"description": "Mouse flight with keyboard pitch/roll and a partial dual-stick gamepad layout.",
		"key_hints": {
			"throttle_yaw": "W/S + A/D",
			"pitch": "Up/Down",
			"roll": "Q/R",
			"aim": "Mouse yaw/pitch",
			"fire": "Left mouse / F",
			"brake": "Right mouse / Ctrl",
			"interact": "E",
			"gamepad": "Dual sticks + triggers",
		},
		"applies_input_map": false,
	},
	ControlPreset.CLASSIC: {
		"id": &"classic",
		"label": "Classic",
		"description": "A classic-style presentation of the familiar Y, X, H, F, and G flight actions.",
		"key_hints": {
			"engine_start": "Y",
			"engine_stop": "X",
			"hover": "H",
			"fire": "F",
			"barrel_roll": "G",
		},
		"applies_input_map": false,
	},
}

var config_path: String = DEFAULT_CONFIG_PATH:
	set(value):
		config_path = value if not value.strip_edges().is_empty() else DEFAULT_CONFIG_PATH

var ship_mouse_sensitivity: float = DEFAULT_SHIP_MOUSE_SENSITIVITY:
	set(value):
		var validated := _validated_float(
			value,
			DEFAULT_SHIP_MOUSE_SENSITIVITY,
			MIN_SHIP_MOUSE_SENSITIVITY,
			MAX_SHIP_MOUSE_SENSITIVITY
		)
		if is_equal_approx(ship_mouse_sensitivity, validated):
			return
		ship_mouse_sensitivity = validated
		_queue_change(&"ship_mouse_sensitivity", validated)

var on_foot_mouse_sensitivity: float = DEFAULT_ON_FOOT_MOUSE_SENSITIVITY:
	set(value):
		var validated := _validated_float(
			value,
			DEFAULT_ON_FOOT_MOUSE_SENSITIVITY,
			MIN_ON_FOOT_MOUSE_SENSITIVITY,
			MAX_ON_FOOT_MOUSE_SENSITIVITY
		)
		if is_equal_approx(on_foot_mouse_sensitivity, validated):
			return
		on_foot_mouse_sensitivity = validated
		_queue_change(&"on_foot_mouse_sensitivity", validated)

var invert_ship_y := false:
	set(value):
		if invert_ship_y == value:
			return
		invert_ship_y = value
		_queue_change(&"invert_ship_y", value)

var invert_on_foot_y := false:
	set(value):
		if invert_on_foot_y == value:
			return
		invert_on_foot_y = value
		_queue_change(&"invert_on_foot_y", value)

var camera_fov: float = DEFAULT_CAMERA_FOV:
	set(value):
		var validated := _validated_float(value, DEFAULT_CAMERA_FOV, MIN_CAMERA_FOV, MAX_CAMERA_FOV)
		if is_equal_approx(camera_fov, validated):
			return
		camera_fov = validated
		_queue_change(&"camera_fov", validated)

var master_volume: float = DEFAULT_MASTER_VOLUME:
	set(value):
		var validated := _validated_float(value, DEFAULT_MASTER_VOLUME, MIN_VOLUME, MAX_VOLUME)
		if is_equal_approx(master_volume, validated):
			return
		master_volume = validated
		_queue_change(&"master_volume", validated)

var ambience_volume: float = DEFAULT_AMBIENCE_VOLUME:
	set(value):
		var validated := _validated_float(value, DEFAULT_AMBIENCE_VOLUME, MIN_VOLUME, MAX_VOLUME)
		if is_equal_approx(ambience_volume, validated):
			return
		ambience_volume = validated
		_queue_change(&"ambience_volume", validated)

var engine_volume: float = DEFAULT_ENGINE_VOLUME:
	set(value):
		var validated := _validated_float(value, DEFAULT_ENGINE_VOLUME, MIN_VOLUME, MAX_VOLUME)
		if is_equal_approx(engine_volume, validated):
			return
		engine_volume = validated
		_queue_change(&"engine_volume", validated)

var weapons_volume: float = DEFAULT_WEAPONS_VOLUME:
	set(value):
		var validated := _validated_float(value, DEFAULT_WEAPONS_VOLUME, MIN_VOLUME, MAX_VOLUME)
		if is_equal_approx(weapons_volume, validated):
			return
		weapons_volume = validated
		_queue_change(&"weapons_volume", validated)

var ui_volume: float = DEFAULT_UI_VOLUME:
	set(value):
		var validated := _validated_float(value, DEFAULT_UI_VOLUME, MIN_VOLUME, MAX_VOLUME)
		if is_equal_approx(ui_volume, validated):
			return
		ui_volume = validated
		_queue_change(&"ui_volume", validated)

## Gain over the authored `Music` bus mix. The music/ambient bed is a separate
## category from `Ambience` on purpose: silencing station machinery must not
## silence the score, and silencing the score must not silence the station.
var music_volume: float = DEFAULT_MUSIC_VOLUME:
	set(value):
		var validated := _validated_float(value, DEFAULT_MUSIC_VOLUME, MIN_VOLUME, MAX_VOLUME)
		if is_equal_approx(music_volume, validated):
			return
		music_volume = validated
		_queue_change(&"music_volume", validated)


var graphics_profile: int = DEFAULT_GRAPHICS_PROFILE:
	set(value):
		var validated := _validated_graphics_profile(value)
		if graphics_profile == validated:
			return
		graphics_profile = validated
		_queue_change(&"graphics_profile", validated)

var window_mode: int = DEFAULT_WINDOW_MODE:
	set(value):
		var validated := _validated_window_mode(value)
		if window_mode == validated:
			return
		window_mode = validated
		_queue_change(&"window_mode", validated)

var control_preset: int = DEFAULT_CONTROL_PRESET:
	set(value):
		var validated := _validated_control_preset(value)
		if control_preset == validated:
			return
		control_preset = validated
		_queue_change(&"control_preset", validated)

var ui_scale: float = DEFAULT_UI_SCALE:
	set(value):
		var validated := _validated_float(value, DEFAULT_UI_SCALE, MIN_UI_SCALE, MAX_UI_SCALE)
		if is_equal_approx(ui_scale, validated):
			return
		ui_scale = validated
		_queue_change(&"ui_scale", validated)

var colorblind_palette: int = DEFAULT_COLORBLIND_PALETTE:
	set(value):
		var validated := _validated_colorblind_palette(value)
		if colorblind_palette == validated:
			return
		colorblind_palette = validated
		_queue_change(&"colorblind_palette", validated)

var reduced_motion := DEFAULT_REDUCED_MOTION:
	set(value):
		if reduced_motion == value:
			return
		reduced_motion = value
		_queue_change(&"reduced_motion", value)

var captions_enabled := DEFAULT_CAPTIONS_ENABLED:
	set(value):
		if captions_enabled == value:
			return
		captions_enabled = value
		_queue_change(&"captions_enabled", value)

var _batch_depth := 0
var _pending_changes: Array[StringName] = []
var _dispatching_changes := false
var _dispatch_remaining: Array[StringName] = []


func _init(path: String = DEFAULT_CONFIG_PATH) -> void:
	config_path = path


## Returns a detached value snapshot suitable for menus and integration code.
func to_dictionary() -> Dictionary:
	return {
		"ship_mouse_sensitivity": ship_mouse_sensitivity,
		"on_foot_mouse_sensitivity": on_foot_mouse_sensitivity,
		"invert_ship_y": invert_ship_y,
		"invert_on_foot_y": invert_on_foot_y,
		"camera_fov": camera_fov,
		"master_volume": master_volume,
		"ambience_volume": ambience_volume,
		"engine_volume": engine_volume,
		"weapons_volume": weapons_volume,
		"ui_volume": ui_volume,
		"music_volume": music_volume,
		"graphics_profile": graphics_profile,
		"window_mode": window_mode,
		"control_preset": control_preset,
		"ui_scale": ui_scale,
		"colorblind_palette": colorblind_palette,
		"reduced_motion": reduced_motion,
		"captions_enabled": captions_enabled,
	}


## Restores authored defaults and emits one batched change notification.
func reset_to_defaults() -> void:
	_begin_batch()
	ship_mouse_sensitivity = DEFAULT_SHIP_MOUSE_SENSITIVITY
	on_foot_mouse_sensitivity = DEFAULT_ON_FOOT_MOUSE_SENSITIVITY
	invert_ship_y = false
	invert_on_foot_y = false
	camera_fov = DEFAULT_CAMERA_FOV
	master_volume = DEFAULT_MASTER_VOLUME
	ambience_volume = DEFAULT_AMBIENCE_VOLUME
	engine_volume = DEFAULT_ENGINE_VOLUME
	weapons_volume = DEFAULT_WEAPONS_VOLUME
	ui_volume = DEFAULT_UI_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	graphics_profile = DEFAULT_GRAPHICS_PROFILE
	window_mode = DEFAULT_WINDOW_MODE
	control_preset = DEFAULT_CONTROL_PRESET
	ui_scale = DEFAULT_UI_SCALE
	colorblind_palette = DEFAULT_COLORBLIND_PALETTE
	reduced_motion = DEFAULT_REDUCED_MOTION
	captions_enabled = DEFAULT_CAPTIONS_ENABLED
	_end_batch()


## Writes only allow-listed primitive values. Enums use stable textual IDs so
## their meaning survives future enum reordering. The complete file is staged
## and parsed before a recoverable same-directory replacement. The previous
## verified file remains under `.bak` until the new target has also parsed, so a
## Windows rename failure or interrupted save never deletes the only good copy.
func save_to_file(path_override: String = "") -> Error:
	var target_path := _resolve_path(path_override)
	var staging_path := target_path + _STAGING_SUFFIX
	var backup_path := target_path + _BACKUP_SUFFIX
	var absolute_staging_path := ProjectSettings.globalize_path(staging_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	var absolute_target_path := ProjectSettings.globalize_path(target_path)

	var recovery_error := _recover_interrupted_save(target_path)
	if recovery_error != OK:
		return recovery_error

	# Never mistake colliding directories for transaction files.
	if (
		DirAccess.dir_exists_absolute(absolute_staging_path)
		or DirAccess.dir_exists_absolute(absolute_backup_path)
	):
		return ERR_ALREADY_EXISTS
	if FileAccess.file_exists(staging_path):
		var cleanup_error := DirAccess.remove_absolute(absolute_staging_path)
		if cleanup_error != OK:
			return cleanup_error
	if FileAccess.file_exists(backup_path):
		var backup_cleanup_error := DirAccess.remove_absolute(absolute_backup_path)
		if backup_cleanup_error != OK:
			return backup_cleanup_error

	var config := ConfigFile.new()
	config.set_value(_SECTION_META, "schema_version", SCHEMA_VERSION)
	config.set_value(_SECTION_CONTROLS, "ship_mouse_sensitivity", ship_mouse_sensitivity)
	config.set_value(_SECTION_CONTROLS, "on_foot_mouse_sensitivity", on_foot_mouse_sensitivity)
	config.set_value(_SECTION_CONTROLS, "invert_ship_y", invert_ship_y)
	config.set_value(_SECTION_CONTROLS, "invert_on_foot_y", invert_on_foot_y)
	config.set_value(_SECTION_CONTROLS, "preset", String(_control_preset_id(control_preset)))
	config.set_value(_SECTION_CAMERA, "fov", camera_fov)
	config.set_value(_SECTION_AUDIO, "master", master_volume)
	config.set_value(_SECTION_AUDIO, "ambience", ambience_volume)
	config.set_value(_SECTION_AUDIO, "engine", engine_volume)
	config.set_value(_SECTION_AUDIO, "weapons", weapons_volume)
	config.set_value(_SECTION_AUDIO, "ui", ui_volume)
	config.set_value(_SECTION_AUDIO, "music", music_volume)
	config.set_value(_SECTION_GRAPHICS, "profile", String(_graphics_profile_id(graphics_profile)))
	config.set_value(_SECTION_DISPLAY, "window_mode", String(_window_mode_id(window_mode)))
	config.set_value(_SECTION_ACCESSIBILITY, "ui_scale", ui_scale)
	config.set_value(
		_SECTION_ACCESSIBILITY,
		"colorblind_palette",
		String(_colorblind_palette_id(colorblind_palette))
	)
	config.set_value(_SECTION_ACCESSIBILITY, "reduced_motion", reduced_motion)
	config.set_value(_SECTION_ACCESSIBILITY, "captions", captions_enabled)

	var save_error := config.save(staging_path)
	if save_error != OK:
		return save_error

	var verification := ConfigFile.new()
	var verification_error := verification.load(staging_path)
	if verification_error != OK or not _has_supported_schema(verification):
		DirAccess.remove_absolute(absolute_staging_path)
		return verification_error if verification_error != OK else ERR_INVALID_DATA

	var had_target := FileAccess.file_exists(target_path)
	if had_target:
		var backup_error := DirAccess.rename_absolute(absolute_target_path, absolute_backup_path)
		if backup_error != OK:
			# Staging is verified and intentionally retained for diagnosis/retry.
			return backup_error

	var publish_error := DirAccess.rename_absolute(absolute_staging_path, absolute_target_path)
	if publish_error != OK:
		# On every failure, retain the verified staging file. If there was a prior
		# target, restore it from the non-overwriting backup path immediately.
		if had_target and FileAccess.file_exists(backup_path) and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_target_path)
		return publish_error

	var published := ConfigFile.new()
	var published_error := published.load(target_path)
	if published_error != OK or not _has_supported_schema(published):
		# The staged file parsed before publication, so this is defensive against
		# filesystem corruption. Restore the previous verified file when possible.
		if had_target and FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(absolute_target_path)
			DirAccess.rename_absolute(absolute_backup_path, absolute_target_path)
		return published_error if published_error != OK else ERR_INVALID_DATA

	# The new target is now verified. A failed backup cleanup is harmless and is
	# recovered on the next load/save, so publishing still succeeds.
	if had_target and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	return OK


## Loads a validated snapshot. A missing or unparsable file and an unsupported
## schema leave the current resource untouched. Missing or wrongly typed values
## in a valid file fall back to authored defaults; numeric values are clamped.
func load_from_file(path_override: String = "") -> Error:
	var target_path := _resolve_path(path_override)
	var recovery_error := _recover_interrupted_save(target_path)
	if recovery_error != OK:
		return recovery_error
	var config := ConfigFile.new()
	var load_error := config.load(target_path)
	if load_error != OK:
		return load_error

	if not _has_supported_schema(config):
		return ERR_INVALID_DATA

	var loaded_ship_sensitivity := _read_number(
		config,
		_SECTION_CONTROLS,
		"ship_mouse_sensitivity",
		DEFAULT_SHIP_MOUSE_SENSITIVITY
	)
	var loaded_on_foot_sensitivity := _read_number(
		config,
		_SECTION_CONTROLS,
		"on_foot_mouse_sensitivity",
		DEFAULT_ON_FOOT_MOUSE_SENSITIVITY
	)
	var loaded_camera_fov := _read_number(config, _SECTION_CAMERA, "fov", DEFAULT_CAMERA_FOV)
	var loaded_master := _read_number(config, _SECTION_AUDIO, "master", DEFAULT_MASTER_VOLUME)
	var loaded_ambience := _read_number(config, _SECTION_AUDIO, "ambience", DEFAULT_AMBIENCE_VOLUME)
	var loaded_engine := _read_number(config, _SECTION_AUDIO, "engine", DEFAULT_ENGINE_VOLUME)
	var loaded_weapons := _read_number(config, _SECTION_AUDIO, "weapons", DEFAULT_WEAPONS_VOLUME)
	var loaded_ui := _read_number(config, _SECTION_AUDIO, "ui", DEFAULT_UI_VOLUME)
	var loaded_music := _read_number(config, _SECTION_AUDIO, "music", DEFAULT_MUSIC_VOLUME)
	var loaded_ui_scale := _read_number(
		config, _SECTION_ACCESSIBILITY, "ui_scale", DEFAULT_UI_SCALE
	)

	_begin_batch()
	ship_mouse_sensitivity = loaded_ship_sensitivity
	on_foot_mouse_sensitivity = loaded_on_foot_sensitivity
	invert_ship_y = _read_bool(config, _SECTION_CONTROLS, "invert_ship_y", false)
	invert_on_foot_y = _read_bool(config, _SECTION_CONTROLS, "invert_on_foot_y", false)
	control_preset = _parse_control_preset(
		config.get_value(_SECTION_CONTROLS, "preset", _control_preset_id(DEFAULT_CONTROL_PRESET))
	)
	camera_fov = loaded_camera_fov
	master_volume = loaded_master
	ambience_volume = loaded_ambience
	engine_volume = loaded_engine
	weapons_volume = loaded_weapons
	ui_volume = loaded_ui
	music_volume = loaded_music
	graphics_profile = _parse_graphics_profile(
		config.get_value(_SECTION_GRAPHICS, "profile", _graphics_profile_id(DEFAULT_GRAPHICS_PROFILE))
	)
	window_mode = _parse_window_mode(
		config.get_value(_SECTION_DISPLAY, "window_mode", _window_mode_id(DEFAULT_WINDOW_MODE))
	)
	ui_scale = loaded_ui_scale
	colorblind_palette = _parse_colorblind_palette(
		config.get_value(
			_SECTION_ACCESSIBILITY,
			"colorblind_palette",
			_colorblind_palette_id(DEFAULT_COLORBLIND_PALETTE)
		)
	)
	reduced_motion = _read_bool(
		config, _SECTION_ACCESSIBILITY, "reduced_motion", DEFAULT_REDUCED_MOTION
	)
	captions_enabled = _read_bool(
		config, _SECTION_ACCESSIBILITY, "captions", DEFAULT_CAPTIONS_ENABLED
	)
	_end_batch()
	return OK


## Returns a detached, display-ready descriptor. This intentionally describes
## presets without mutating InputMap; actual remapping belongs to a later input
## settings integration.
func get_control_preset_descriptor(preset: int = -1) -> Dictionary:
	var requested := control_preset if preset == -1 else preset
	if not _CONTROL_PRESET_DESCRIPTORS.has(requested):
		return {}
	return (_CONTROL_PRESET_DESCRIPTORS[requested] as Dictionary).duplicate(true)


func get_graphics_profile_id() -> StringName:
	return _graphics_profile_id(graphics_profile)


func get_window_mode_id() -> StringName:
	return _window_mode_id(window_mode)


func get_control_preset_id() -> StringName:
	return _control_preset_id(control_preset)


## Stable textual ID of the active colour-vision preset. This is the only seam
## the HUD uses, so the palette tables never depend on enum ordering.
func get_colorblind_palette_id() -> StringName:
	return _colorblind_palette_id(colorblind_palette)


## Detached, side-effect-free snapshot of every accessibility preference. HUD and
## presentation owners consume this instead of reading individual properties, so
## a partially applied preset is impossible.
func get_accessibility_descriptor() -> Dictionary:
	return {
		"ui_scale": ui_scale,
		"colorblind_palette": colorblind_palette,
		"colorblind_palette_id": get_colorblind_palette_id(),
		"reduced_motion": reduced_motion,
		"captions_enabled": captions_enabled,
	}


## Converts normalized audio preferences to bus decibels without changing the
## AudioServer. This is also the preview seam for settings menus and tests.
func get_audio_bus_levels_db() -> Dictionary:
	var levels := {}
	for bus_name: StringName in _AUDIO_BUS_PROPERTIES:
		var property_name: StringName = _AUDIO_BUS_PROPERTIES[bus_name]
		var linear_volume := float(get(property_name))
		levels[bus_name] = (
			SILENCE_DB
			if linear_volume <= 0.0
			else float(_AUDIO_BUS_BASE_DB[bus_name]) + linear_to_db(linear_volume)
		)
	return levels


## Explicitly applies normalized volume preferences to the project's named
## buses. Missing buses are reported and safely skipped.
func apply_audio_settings() -> Dictionary:
	var levels := get_audio_bus_levels_db()
	var applied := PackedStringArray()
	var missing := PackedStringArray()
	for bus_name: StringName in levels:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			missing.append(String(bus_name))
			continue
		AudioServer.set_bus_volume_db(bus_index, float(levels[bus_name]))
		applied.append(String(bus_name))
	return {
		"applied": not applied.is_empty(),
		"complete": missing.is_empty(),
		"applied_buses": applied,
		"missing_buses": missing,
	}


## Describes the requested DisplayServer calls without applying them.
## BORDERLESS means a borderless window at its current position and size; it is
## deliberately distinct from fullscreen and does not resize to fill a monitor.
func get_window_mode_descriptor() -> Dictionary:
	match window_mode:
		WindowMode.WINDOWED:
			return {"id": &"windowed", "display_mode": DisplayServer.WINDOW_MODE_WINDOWED, "borderless": false}
		WindowMode.BORDERLESS:
			return {"id": &"borderless", "display_mode": DisplayServer.WINDOW_MODE_WINDOWED, "borderless": true}
		WindowMode.FULLSCREEN:
			return {"id": &"fullscreen", "display_mode": DisplayServer.WINDOW_MODE_FULLSCREEN, "borderless": false}
	return {}


## Explicitly applies the selected mode to one window. Headless execution is a
## safe no-op so test runners and dedicated servers never fabricate a window.
func apply_window_mode(window_id: int = DisplayServer.MAIN_WINDOW_ID) -> Dictionary:
	var descriptor := get_window_mode_descriptor()
	if DisplayServer.get_name() == "headless":
		return {"applied": false, "reason": &"headless", "window_mode": descriptor.get("id", &"invalid")}
	if descriptor.is_empty():
		return {"applied": false, "reason": &"invalid_window_mode", "window_mode": &"invalid"}

	# Leaving borderless first avoids carrying that flag into fullscreen, while
	# entering borderless first ensures the target is a normal desktop window.
	if bool(descriptor["borderless"]):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, window_id)
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false, window_id)
		DisplayServer.window_set_mode(int(descriptor["display_mode"]), window_id)
	return {"applied": true, "reason": &"", "window_mode": descriptor["id"]}


func _resolve_path(path_override: String) -> String:
	return config_path if path_override.strip_edges().is_empty() else path_override


func _begin_batch() -> void:
	_batch_depth += 1


func _end_batch() -> void:
	_batch_depth = maxi(_batch_depth - 1, 0)
	if _batch_depth > 0:
		return
	_dispatch_pending_changes()


func _queue_change(setting_name: StringName, _value: Variant) -> void:
	# If this property is still due in the active batch, its eventual callback
	# reads the latest effective value. Re-queue only properties whose callback
	# already ran, keeping re-entrant mutations ordered without stale duplicates.
	if _dispatching_changes and _dispatch_remaining.has(setting_name):
		return
	if not _pending_changes.has(setting_name):
		_pending_changes.append(setting_name)
	if _batch_depth == 0 and not _dispatching_changes:
		_dispatch_pending_changes()


func _dispatch_pending_changes() -> void:
	if _dispatching_changes or _batch_depth > 0 or _pending_changes.is_empty():
		return
	_dispatching_changes = true
	while not _pending_changes.is_empty():
		var batch: Array[StringName] = _pending_changes.duplicate()
		_pending_changes.clear()
		_dispatch_remaining = batch.duplicate()
		var names := PackedStringArray()
		for setting_name: StringName in batch:
			_dispatch_remaining.erase(setting_name)
			names.append(String(setting_name))
			setting_changed.emit(setting_name, get(setting_name))
		settings_changed.emit(names)
		emit_changed()
	_dispatch_remaining.clear()
	_dispatching_changes = false


func _recover_interrupted_save(target_path: String) -> Error:
	var staging_path := target_path + _STAGING_SUFFIX
	var backup_path := target_path + _BACKUP_SUFFIX
	var absolute_target_path := ProjectSettings.globalize_path(target_path)
	var absolute_staging_path := ProjectSettings.globalize_path(staging_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	if (
		DirAccess.dir_exists_absolute(absolute_staging_path)
		or DirAccess.dir_exists_absolute(absolute_backup_path)
	):
		return ERR_ALREADY_EXISTS

	var target_valid := _is_supported_config_file(target_path)
	if target_valid:
		# A valid target means publication completed. Transaction remnants can be
		# discarded without risking the only verified copy.
		if FileAccess.file_exists(backup_path):
			var backup_cleanup := DirAccess.remove_absolute(absolute_backup_path)
			if backup_cleanup != OK:
				return backup_cleanup
		if FileAccess.file_exists(staging_path):
			var staging_cleanup := DirAccess.remove_absolute(absolute_staging_path)
			if staging_cleanup != OK:
				return staging_cleanup
		return OK

	# Prefer the last-known-good backup, then a fully verified staged successor.
	var recovery_path := ""
	var absolute_recovery_path := ""
	if _is_supported_config_file(backup_path):
		recovery_path = backup_path
		absolute_recovery_path = absolute_backup_path
	elif _is_supported_config_file(staging_path):
		recovery_path = staging_path
		absolute_recovery_path = absolute_staging_path
	if recovery_path.is_empty():
		return OK

	if FileAccess.file_exists(target_path):
		var remove_invalid_error := DirAccess.remove_absolute(absolute_target_path)
		if remove_invalid_error != OK:
			return remove_invalid_error
	var restore_error := DirAccess.rename_absolute(absolute_recovery_path, absolute_target_path)
	if restore_error != OK:
		return restore_error
	if not _is_supported_config_file(target_path):
		return ERR_INVALID_DATA
	return OK


func _is_supported_config_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var config := ConfigFile.new()
	return config.load(path) == OK and _has_supported_schema(config)


static func _validated_float(value: float, default_value: float, minimum: float, maximum: float) -> float:
	if is_nan(value) or is_inf(value):
		return default_value
	return clampf(value, minimum, maximum)


static func _validated_graphics_profile(value: int) -> int:
	return value if value in [GraphicsProfile.LOW, GraphicsProfile.MEDIUM, GraphicsProfile.HIGH] else DEFAULT_GRAPHICS_PROFILE


static func _validated_window_mode(value: int) -> int:
	return value if value in [WindowMode.WINDOWED, WindowMode.BORDERLESS, WindowMode.FULLSCREEN] else DEFAULT_WINDOW_MODE


static func _validated_control_preset(value: int) -> int:
	return value if value in [ControlPreset.MODERN, ControlPreset.CLASSIC] else DEFAULT_CONTROL_PRESET


static func _validated_colorblind_palette(value: int) -> int:
	return value if _COLORBLIND_PALETTE_IDS.has(value) else DEFAULT_COLORBLIND_PALETTE


static func _read_number(config: ConfigFile, section: String, key: String, default_value: float) -> float:
	var value: Variant = config.get_value(section, key, default_value)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default_value
	var number := float(value)
	return default_value if is_nan(number) or is_inf(number) else number


static func _read_bool(config: ConfigFile, section: String, key: String, default_value: bool) -> bool:
	var value: Variant = config.get_value(section, key, default_value)
	return bool(value) if typeof(value) == TYPE_BOOL else default_value


static func _has_supported_schema(config: ConfigFile) -> bool:
	if not config.has_section_key(_SECTION_META, "schema_version"):
		return false
	var schema: Variant = config.get_value(_SECTION_META, "schema_version", null)
	if typeof(schema) != TYPE_INT:
		return false
	var version := int(schema)
	return version >= MINIMUM_SUPPORTED_SCHEMA_VERSION and version <= SCHEMA_VERSION


static func _graphics_profile_id(value: int) -> StringName:
	match value:
		GraphicsProfile.LOW:
			return &"low"
		GraphicsProfile.MEDIUM:
			return &"medium"
	return &"high"


static func _window_mode_id(value: int) -> StringName:
	match value:
		WindowMode.BORDERLESS:
			return &"borderless"
		WindowMode.FULLSCREEN:
			return &"fullscreen"
	return &"windowed"


static func _control_preset_id(value: int) -> StringName:
	return &"classic" if value == ControlPreset.CLASSIC else &"modern"


static func _parse_graphics_profile(value: Variant) -> int:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return DEFAULT_GRAPHICS_PROFILE
	match String(value).to_lower():
		"low":
			return GraphicsProfile.LOW
		"medium":
			return GraphicsProfile.MEDIUM
		"high":
			return GraphicsProfile.HIGH
	return DEFAULT_GRAPHICS_PROFILE


static func _parse_window_mode(value: Variant) -> int:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return DEFAULT_WINDOW_MODE
	match String(value).to_lower():
		"windowed":
			return WindowMode.WINDOWED
		"borderless":
			return WindowMode.BORDERLESS
		"fullscreen":
			return WindowMode.FULLSCREEN
	return DEFAULT_WINDOW_MODE


static func _parse_control_preset(value: Variant) -> int:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return DEFAULT_CONTROL_PRESET
	return ControlPreset.CLASSIC if String(value).to_lower() == "classic" else DEFAULT_CONTROL_PRESET


static func _colorblind_palette_id(value: int) -> StringName:
	return _COLORBLIND_PALETTE_IDS.get(value, _COLORBLIND_PALETTE_IDS[DEFAULT_COLORBLIND_PALETTE])


static func _parse_colorblind_palette(value: Variant) -> int:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return DEFAULT_COLORBLIND_PALETTE
	var wanted := StringName(String(value).to_lower())
	for palette: int in _COLORBLIND_PALETTE_IDS:
		if _COLORBLIND_PALETTE_IDS[palette] == wanted:
			return palette
	return DEFAULT_COLORBLIND_PALETTE
