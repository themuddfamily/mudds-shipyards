class_name RuntimeSettings
extends Resource

## Persisted, side-effect-free local preferences for a Keth Shipyards client.
##
## Constructing, loading, changing, or resetting this resource never changes
## AudioServer, DisplayServer, InputMap, or ProjectSettings. Runtime systems opt
## into global side effects through [method apply_audio_settings],
## [method apply_window_mode], and [method apply_input_bindings]. Other values
## are intended to be consumed by the player, ship, camera, and visual-quality
## controllers.

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

enum VSyncMode {
	OFF,
	ON,
	ADAPTIVE,
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
const SCHEMA_VERSION := 6
const MINIMUM_SUPPORTED_SCHEMA_VERSION := 1
## Version of the typed RuntimeSettings section stored inside UserDataStore's
## independently versioned envelope. This starts at one because ConfigFile
## schema versions describe a different wire format and migration history.
const USER_DATA_PAYLOAD_SCHEMA_VERSION := 8
const _MAX_SAFE_JSON_INTEGER := 9_007_199_254_740_991
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
const DEFAULT_DISPLAY_RESOLUTION_ID := "1920x1080"
const DEFAULT_VSYNC_MODE := VSyncMode.ON
const SUPPORTED_DISPLAY_RESOLUTION_IDS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
const DEFAULT_CONTROL_PRESET := ControlPreset.MODERN
const DEFAULT_COLORBLIND_PALETTE := ColorblindPalette.NONE
const DEFAULT_REDUCED_MOTION := false
const DEFAULT_CAPTIONS_ENABLED := false
const DEFAULT_REDUCED_DYNAMIC_RANGE := false
const DEFAULT_REDUCED_FLASH := false
const MIN_PAYLOAD_VISUAL_INTENSITY := 0
const MAX_PAYLOAD_VISUAL_INTENSITY := 2
const DEFAULT_PAYLOAD_VISUAL_INTENSITY := 2
const DEFAULT_SHOW_TUTORIALS := true
const MIN_MULTIPLAYER_DISPLAY_NAME_LENGTH := 1
const MAX_MULTIPLAYER_DISPLAY_NAME_LENGTH := 32
const DEFAULT_MULTIPLAYER_DISPLAY_NAME := "Pilot"
const MIN_NETWORK_DEFAULT_PORT := 1
const MAX_NETWORK_DEFAULT_PORT := 65535
const DEFAULT_NETWORK_DEFAULT_PORT := 27101
const MIN_MULTIPLAYER_MAX_PLAYERS := 1
const MAX_MULTIPLAYER_MAX_PLAYERS := 32
const DEFAULT_MULTIPLAYER_MAX_PLAYERS := 8

const _SECTION_META := "meta"
const _SECTION_CONTROLS := "controls"
const _SECTION_INPUT_BINDINGS := "input_bindings"
const _SECTION_CAMERA := "camera"
const _SECTION_AUDIO := "audio"
const _SECTION_GRAPHICS := "graphics"
const _SECTION_DISPLAY := "display"
const _SECTION_ACCESSIBILITY := "accessibility"
const _SECTION_NETWORK := "network"

const _USER_DATA_SECTION_KEYS := ["schema_version", "values"]
const _USER_DATA_VALUE_KEYS := [
	"ship_mouse_sensitivity",
	"on_foot_mouse_sensitivity",
	"invert_ship_y",
	"invert_on_foot_y",
	"camera_fov",
	"master_volume",
	"ambience_volume",
	"engine_volume",
	"weapons_volume",
	"ui_volume",
	"music_volume",
	"graphics_profile",
	"window_mode",
	"display_resolution",
	"vsync_mode",
	"control_preset",
	"ui_scale",
	"colorblind_palette",
	"reduced_motion",
	"captions_enabled",
	"reduced_dynamic_range",
	"reduced_flash",
	"payload_visual_intensity",
	"show_tutorials",
	"multiplayer_display_name",
	"network_default_port",
	"multiplayer_max_players",
	"input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V5 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"reduced_dynamic_range", "show_tutorials", "multiplayer_display_name",
	"network_default_port", "multiplayer_max_players", "input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V6 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"reduced_dynamic_range", "reduced_flash", "show_tutorials", "multiplayer_display_name",
	"network_default_port", "multiplayer_max_players", "input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V7 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"reduced_dynamic_range", "reduced_flash", "payload_visual_intensity",
	"show_tutorials", "multiplayer_display_name", "network_default_port",
	"multiplayer_max_players", "input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V4 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"reduced_dynamic_range", "show_tutorials", "multiplayer_display_name",
	"network_default_port", "input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V3 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"reduced_dynamic_range", "show_tutorials", "input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V2 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"reduced_dynamic_range",
	"input_binding_profile",
]
const _USER_DATA_VALUE_KEYS_V1 := [
	"ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
	"invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
	"engine_volume", "weapons_volume", "ui_volume", "music_volume",
	"graphics_profile", "window_mode", "control_preset", "ui_scale",
	"colorblind_palette", "reduced_motion", "captions_enabled",
	"input_binding_profile",
]

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
		"description": "A classic-style presentation of the familiar H, F, and G flight actions with automatic propulsion.",
		"key_hints": {
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

var display_resolution: String = DEFAULT_DISPLAY_RESOLUTION_ID:
	set(value):
		var validated := _validated_display_resolution(value)
		if display_resolution == validated:
			return
		display_resolution = validated
		_queue_change(&"display_resolution", validated)

var vsync_mode: int = DEFAULT_VSYNC_MODE:
	set(value):
		var validated := _validated_vsync_mode(value)
		if vsync_mode == validated:
			return
		vsync_mode = validated
		_queue_change(&"vsync_mode", validated)

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

var reduced_dynamic_range := DEFAULT_REDUCED_DYNAMIC_RANGE:
	set(value):
		var validated := bool(value)
		if reduced_dynamic_range == validated:
			return
		reduced_dynamic_range = validated
		_queue_change(&"reduced_dynamic_range", validated)

var reduced_flash := DEFAULT_REDUCED_FLASH:
	set(value):
		var validated := bool(value)
		if reduced_flash == validated:
			return
		reduced_flash = validated
		_queue_change(&"reduced_flash", validated)

var payload_visual_intensity := DEFAULT_PAYLOAD_VISUAL_INTENSITY:
	set(value):
		var validated := clampi(int(value), MIN_PAYLOAD_VISUAL_INTENSITY, MAX_PAYLOAD_VISUAL_INTENSITY)
		if payload_visual_intensity == validated:
			return
		payload_visual_intensity = validated
		_queue_change(&"payload_visual_intensity", validated)

var show_tutorials := DEFAULT_SHOW_TUTORIALS:
	set(value):
		var validated := bool(value)
		if show_tutorials == validated:
			return
		show_tutorials = validated
		_queue_change(&"show_tutorials", validated)

var multiplayer_display_name := DEFAULT_MULTIPLAYER_DISPLAY_NAME:
	set(value):
		var validated := _validated_multiplayer_display_name(value)
		if multiplayer_display_name == validated:
			return
		multiplayer_display_name = validated
		_queue_change(&"multiplayer_display_name", validated)

var network_default_port := DEFAULT_NETWORK_DEFAULT_PORT:
	set(value):
		var validated := clampi(int(value), MIN_NETWORK_DEFAULT_PORT, MAX_NETWORK_DEFAULT_PORT)
		if network_default_port == validated:
			return
		network_default_port = validated
		_queue_change(&"network_default_port", validated)

var multiplayer_max_players := DEFAULT_MULTIPLAYER_MAX_PLAYERS:
	set(value):
		var validated := clampi(int(value), MIN_MULTIPLAYER_MAX_PLAYERS, MAX_MULTIPLAYER_MAX_PLAYERS)
		if multiplayer_max_players == validated:
			return
		multiplayer_max_players = validated
		_queue_change(&"multiplayer_max_players", validated)

## Detached on read and validated on write. Callers cannot mutate the canonical
## profile through an aliased Resource; use [method set_input_binding_profile]
## and then explicitly call [method apply_input_bindings].
var input_binding_profile: InputBindingProfile:
	get:
		return get_input_binding_profile()
	set(value):
		set_input_binding_profile(value)

var _batch_depth := 0
var _pending_changes: Array[StringName] = []
var _dispatching_changes := false
var _dispatch_remaining: Array[StringName] = []
var _input_rebind_service: InputRebindService
var _input_binding_profile: InputBindingProfile

static var _captured_project_input_defaults: InputBindingProfile


func _init(path: String = DEFAULT_CONFIG_PATH) -> void:
	config_path = path
	# The first RuntimeSettings owner starts before stored settings are applied and
	# captures the authored project map. Reusing that detached process snapshot is
	# essential: a fresh RuntimeSettings created after a remap must still reset to
	# project defaults, not mistake the currently applied map for authored data.
	if _captured_project_input_defaults == null:
		_captured_project_input_defaults = InputRebindService.new().get_defaults()
	_input_rebind_service = InputRebindService.new(_captured_project_input_defaults)
	_input_binding_profile = _input_rebind_service.get_defaults()


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
		"display_resolution": display_resolution,
		"vsync_mode": vsync_mode,
		"control_preset": control_preset,
		"ui_scale": ui_scale,
		"colorblind_palette": colorblind_palette,
		"reduced_motion": reduced_motion,
		"captions_enabled": captions_enabled,
		"reduced_dynamic_range": reduced_dynamic_range,
		"reduced_flash": reduced_flash,
		"payload_visual_intensity": payload_visual_intensity,
		"show_tutorials": show_tutorials,
		"multiplayer_display_name": multiplayer_display_name,
		"network_default_port": network_default_port,
		"multiplayer_max_players": multiplayer_max_players,
		"input_binding_profile": _input_binding_profile.to_dictionary(),
	}


## Produces the strict JSON-safe RuntimeSettings section embedded by
## RuntimeSettingsStoreAdapter in UserDataStore.payload. StringName values and
## keys are converted deliberately rather than relying on JSON.stringify's
## implicit coercion.
func to_user_data_payload() -> Dictionary:
	return {
		"schema_version": USER_DATA_PAYLOAD_SCHEMA_VERSION,
		"values": {
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
			"graphics_profile": String(get_graphics_profile_id()),
			"window_mode": String(get_window_mode_id()),
			"display_resolution": display_resolution,
			"vsync_mode": String(get_vsync_mode_id()),
			"control_preset": String(get_control_preset_id()),
			"ui_scale": ui_scale,
			"colorblind_palette": String(get_colorblind_palette_id()),
			"reduced_motion": reduced_motion,
			"captions_enabled": captions_enabled,
			"reduced_dynamic_range": reduced_dynamic_range,
			"reduced_flash": reduced_flash,
			"payload_visual_intensity": payload_visual_intensity,
			"show_tutorials": show_tutorials,
			"multiplayer_display_name": multiplayer_display_name,
			"network_default_port": network_default_port,
			"multiplayer_max_players": multiplayer_max_players,
			"input_binding_profile": _input_profile_to_json_dictionary(
				_input_binding_profile
			),
		},
	}


## Validates a complete atomic-store section without mutating this Resource.
## The returned reason distinguishes a newer schema so an older build can
## preserve it byte-for-byte instead of treating it as replaceable corruption.
func validate_user_data_payload(candidate: Variant) -> Dictionary:
	var decoded := _decode_user_data_payload(candidate)
	return {
		"accepted": bool(decoded.accepted),
		"reason": decoded.reason,
	}


## Atomically installs a complete typed section after every scalar, stable enum
## ID, and binding descriptor has validated. Rejected input emits no changes and
## leaves the prior live snapshot intact.
func apply_user_data_payload(candidate: Variant) -> Dictionary:
	var decoded := _decode_user_data_payload(candidate)
	if not bool(decoded.accepted):
		return {"accepted": false, "reason": decoded.reason}
	var values := decoded.values as Dictionary
	var profile := decoded.input_binding_profile as InputBindingProfile
	_begin_batch()
	ship_mouse_sensitivity = float(values.ship_mouse_sensitivity)
	on_foot_mouse_sensitivity = float(values.on_foot_mouse_sensitivity)
	invert_ship_y = bool(values.invert_ship_y)
	invert_on_foot_y = bool(values.invert_on_foot_y)
	camera_fov = float(values.camera_fov)
	master_volume = float(values.master_volume)
	ambience_volume = float(values.ambience_volume)
	engine_volume = float(values.engine_volume)
	weapons_volume = float(values.weapons_volume)
	ui_volume = float(values.ui_volume)
	music_volume = float(values.music_volume)
	graphics_profile = int(values.graphics_profile)
	window_mode = int(values.window_mode)
	display_resolution = String(values.display_resolution)
	vsync_mode = int(values.vsync_mode)
	control_preset = int(values.control_preset)
	ui_scale = float(values.ui_scale)
	colorblind_palette = int(values.colorblind_palette)
	reduced_motion = bool(values.reduced_motion)
	captions_enabled = bool(values.captions_enabled)
	reduced_dynamic_range = bool(values.reduced_dynamic_range)
	reduced_flash = bool(values.reduced_flash)
	payload_visual_intensity = int(values.payload_visual_intensity)
	show_tutorials = bool(values.show_tutorials)
	multiplayer_display_name = String(values.multiplayer_display_name)
	network_default_port = int(values.network_default_port)
	multiplayer_max_players = int(values.multiplayer_max_players)
	# Compatibility was proven by the decoder against this same service.
	set_input_binding_profile(profile)
	_end_batch()
	return {"accepted": true, "reason": &"applied"}


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
	display_resolution = DEFAULT_DISPLAY_RESOLUTION_ID
	vsync_mode = DEFAULT_VSYNC_MODE
	control_preset = DEFAULT_CONTROL_PRESET
	ui_scale = DEFAULT_UI_SCALE
	colorblind_palette = DEFAULT_COLORBLIND_PALETTE
	reduced_motion = DEFAULT_REDUCED_MOTION
	captions_enabled = DEFAULT_CAPTIONS_ENABLED
	reduced_dynamic_range = DEFAULT_REDUCED_DYNAMIC_RANGE
	reduced_flash = DEFAULT_REDUCED_FLASH
	payload_visual_intensity = DEFAULT_PAYLOAD_VISUAL_INTENSITY
	show_tutorials = DEFAULT_SHOW_TUTORIALS
	multiplayer_display_name = DEFAULT_MULTIPLAYER_DISPLAY_NAME
	network_default_port = DEFAULT_NETWORK_DEFAULT_PORT
	multiplayer_max_players = DEFAULT_MULTIPLAYER_MAX_PLAYERS
	input_binding_profile = _input_rebind_service.reset_to_defaults()
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
	config.set_value(
		_SECTION_INPUT_BINDINGS,
		"profile",
		_input_binding_profile.to_dictionary()
	)
	config.set_value(_SECTION_CAMERA, "fov", camera_fov)
	config.set_value(_SECTION_AUDIO, "master", master_volume)
	config.set_value(_SECTION_AUDIO, "ambience", ambience_volume)
	config.set_value(_SECTION_AUDIO, "engine", engine_volume)
	config.set_value(_SECTION_AUDIO, "weapons", weapons_volume)
	config.set_value(_SECTION_AUDIO, "ui", ui_volume)
	config.set_value(_SECTION_AUDIO, "music", music_volume)
	config.set_value(_SECTION_GRAPHICS, "profile", String(_graphics_profile_id(graphics_profile)))
	config.set_value(_SECTION_DISPLAY, "window_mode", String(_window_mode_id(window_mode)))
	config.set_value(_SECTION_DISPLAY, "resolution", display_resolution)
	config.set_value(_SECTION_DISPLAY, "vsync", String(_vsync_mode_id(vsync_mode)))
	config.set_value(_SECTION_ACCESSIBILITY, "ui_scale", ui_scale)
	config.set_value(
		_SECTION_ACCESSIBILITY,
		"colorblind_palette",
		String(_colorblind_palette_id(colorblind_palette))
	)
	config.set_value(_SECTION_ACCESSIBILITY, "reduced_motion", reduced_motion)
	config.set_value(_SECTION_ACCESSIBILITY, "captions", captions_enabled)
	config.set_value(_SECTION_ACCESSIBILITY, "reduced_dynamic_range", reduced_dynamic_range)
	config.set_value(_SECTION_ACCESSIBILITY, "reduced_flash", reduced_flash)
	config.set_value(_SECTION_ACCESSIBILITY, "payload_visual_intensity", payload_visual_intensity)
	config.set_value(_SECTION_ACCESSIBILITY, "show_tutorials", show_tutorials)
	config.set_value(_SECTION_NETWORK, "multiplayer_display_name", multiplayer_display_name)
	config.set_value(_SECTION_NETWORK, "default_port", network_default_port)
	config.set_value(_SECTION_NETWORK, "max_players", multiplayer_max_players)

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
## A malformed, incomplete, or newly conflicting input profile likewise falls
## back as one unit to the captured project bindings and is never applied here.
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
	var loaded_input_profile := _read_input_binding_profile(config)
	var loaded_display_name := _read_multiplayer_display_name(
		config.get_value(_SECTION_NETWORK, "multiplayer_display_name", DEFAULT_MULTIPLAYER_DISPLAY_NAME)
	)
	var loaded_default_port := _read_int_bounded(
		config, _SECTION_NETWORK, "default_port", DEFAULT_NETWORK_DEFAULT_PORT,
		MIN_NETWORK_DEFAULT_PORT, MAX_NETWORK_DEFAULT_PORT
	)
	var loaded_max_players := _read_int_bounded(
		config, _SECTION_NETWORK, "max_players", DEFAULT_MULTIPLAYER_MAX_PLAYERS,
		MIN_MULTIPLAYER_MAX_PLAYERS, MAX_MULTIPLAYER_MAX_PLAYERS
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
	display_resolution = _parse_display_resolution(
		config.get_value(_SECTION_DISPLAY, "resolution", DEFAULT_DISPLAY_RESOLUTION_ID)
	)
	vsync_mode = _parse_vsync_mode(
		config.get_value(_SECTION_DISPLAY, "vsync", _vsync_mode_id(DEFAULT_VSYNC_MODE))
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
	reduced_dynamic_range = _read_bool(
		config,
		_SECTION_ACCESSIBILITY,
		"reduced_dynamic_range",
		DEFAULT_REDUCED_DYNAMIC_RANGE
	)
	reduced_flash = _read_bool(config, _SECTION_ACCESSIBILITY, "reduced_flash", DEFAULT_REDUCED_FLASH)
	payload_visual_intensity = _read_int_bounded(
		config, _SECTION_ACCESSIBILITY, "payload_visual_intensity",
		DEFAULT_PAYLOAD_VISUAL_INTENSITY, MIN_PAYLOAD_VISUAL_INTENSITY,
		MAX_PAYLOAD_VISUAL_INTENSITY
	)
	show_tutorials = _read_bool(
		config, _SECTION_ACCESSIBILITY, "show_tutorials", DEFAULT_SHOW_TUTORIALS
	)
	multiplayer_display_name = loaded_display_name
	network_default_port = loaded_default_port
	multiplayer_max_players = loaded_max_players
	input_binding_profile = loaded_input_profile
	_end_batch()
	return OK


## Returns a detached, display-ready descriptor. Preset labels remain separate
## from the versioned binding profile and never mutate InputMap implicitly.
func get_control_preset_descriptor(preset: int = -1) -> Dictionary:
	var requested := control_preset if preset == -1 else preset
	if not _CONTROL_PRESET_DESCRIPTORS.has(requested):
		return {}
	return (_CONTROL_PRESET_DESCRIPTORS[requested] as Dictionary).duplicate(true)


func get_graphics_profile_id() -> StringName:
	return _graphics_profile_id(graphics_profile)


func get_window_mode_id() -> StringName:
	return _window_mode_id(window_mode)


func get_vsync_mode_id() -> StringName:
	return _vsync_mode_id(vsync_mode)


func get_display_resolution_descriptor() -> Dictionary:
	var parts := display_resolution.split("x")
	return {
		"id": StringName(display_resolution),
		"width": int(parts[0]),
		"height": int(parts[1]),
		"supported_ids": PackedStringArray(SUPPORTED_DISPLAY_RESOLUTION_IDS),
	}


func get_vsync_descriptor() -> Dictionary:
	return {
		"id": get_vsync_mode_id(),
		"supported_ids": PackedStringArray(["off", "on", "adaptive"]),
		"backend_mode": _vsync_backend_mode(vsync_mode),
	}


func get_control_preset_id() -> StringName:
	return _control_preset_id(control_preset)


## Returns a deep copy suitable for menu editing. Assigning the returned
## Resource directly never changes the canonical settings snapshot.
func get_input_binding_profile() -> InputBindingProfile:
	return _input_binding_profile.duplicate_profile()


## Returns the process-stable authored InputMap snapshot captured before any
## persisted profile was applied. A newly recreated Main/HUD must use this
## detached profile for reset controls instead of recapturing the live custom map.
func get_project_input_binding_defaults() -> InputBindingProfile:
	return _captured_project_input_defaults.duplicate_profile()


## Replaces the complete profile only when it is schema-valid, covers the
## captured project action inventory, and introduces no non-authored conflict.
## Invalid input leaves the prior profile untouched.
func set_input_binding_profile(profile: InputBindingProfile) -> bool:
	if not _input_rebind_service.is_profile_compatible_with_defaults(profile):
		return false
	var detached := profile.duplicate_profile()
	if detached.to_dictionary() == _input_binding_profile.to_dictionary():
		return true
	_input_binding_profile = detached
	_queue_change(&"input_binding_profile", detached)
	return true


## Explicitly applies the validated snapshot to InputMap. Loading, setting,
## saving, and resetting remain side-effect free; startup and Main re-entry own
## the call site just as they already do for audio and window state.
func apply_input_bindings() -> Dictionary:
	var action_count := _input_binding_profile.bindings.size()
	var applied := _input_rebind_service.apply_profile(_input_binding_profile)
	return {
		"applied": applied,
		"complete": applied,
		"action_count": action_count if applied else 0,
		"profile_schema_version": _input_binding_profile.schema_version,
	}


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
		"reduced_dynamic_range": reduced_dynamic_range,
		"reduced_flash": reduced_flash,
		"payload_visual_intensity": payload_visual_intensity,
		"show_tutorials": show_tutorials,
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


func apply_display_settings(window_id: int = DisplayServer.MAIN_WINDOW_ID) -> Dictionary:
	var resolution := get_display_resolution_descriptor()
	var vsync := get_vsync_descriptor()
	var report := {
		"applied": false,
		"reason": &"",
		"resolution": resolution,
		"vsync": vsync,
	}
	if DisplayServer.get_name() == "headless":
		report.reason = &"headless"
		return report
	DisplayServer.window_set_size(Vector2i(int(resolution.width), int(resolution.height)), window_id)
	DisplayServer.window_set_vsync_mode(int(vsync.backend_mode), window_id)
	report.applied = true
	return report


func _decode_user_data_payload(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"payload_not_dictionary"}
	var section := candidate as Dictionary
	if not _has_exact_string_keys(section, _USER_DATA_SECTION_KEYS):
		return {"accepted": false, "reason": &"payload_fields_invalid"}
	var raw_schema: Variant = section.schema_version
	if not _is_integral_json_number(raw_schema):
		return {"accepted": false, "reason": &"schema_invalid"}
	var schema := int(raw_schema)
	if schema > USER_DATA_PAYLOAD_SCHEMA_VERSION:
		return {"accepted": false, "reason": &"newer_schema"}
	if schema < 1:
		return {"accepted": false, "reason": &"unsupported_schema"}
	if not section.values is Dictionary:
		return {"accepted": false, "reason": &"values_not_dictionary"}
	var raw_values := section.values as Dictionary
	var expected_value_keys := _USER_DATA_VALUE_KEYS
	if schema == 7:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V7
	elif schema == 6:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V6
	elif schema == 5:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V5
	elif schema == 4:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V4
	elif schema == 3:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V3
	elif schema == 2:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V2
	elif schema == 1:
		expected_value_keys = _USER_DATA_VALUE_KEYS_V1
	if not _has_exact_string_keys(raw_values, expected_value_keys):
		return {"accepted": false, "reason": &"value_fields_invalid"}
	if schema == 1:
		raw_values = raw_values.duplicate()
		raw_values["reduced_dynamic_range"] = DEFAULT_REDUCED_DYNAMIC_RANGE
	if schema <= 2:
		raw_values = raw_values.duplicate()
		raw_values["show_tutorials"] = DEFAULT_SHOW_TUTORIALS
	if schema <= 4:
		raw_values = raw_values.duplicate()
		if schema <= 3:
			raw_values["multiplayer_display_name"] = DEFAULT_MULTIPLAYER_DISPLAY_NAME
			raw_values["network_default_port"] = DEFAULT_NETWORK_DEFAULT_PORT
			raw_values["multiplayer_max_players"] = DEFAULT_MULTIPLAYER_MAX_PLAYERS
	if schema <= 5:
		raw_values = raw_values.duplicate()
		raw_values["reduced_flash"] = DEFAULT_REDUCED_FLASH
	if schema <= 6:
		raw_values = raw_values.duplicate()
		raw_values["payload_visual_intensity"] = DEFAULT_PAYLOAD_VISUAL_INTENSITY
	if schema <= 7:
		raw_values = raw_values.duplicate()
		raw_values["display_resolution"] = DEFAULT_DISPLAY_RESOLUTION_ID
		raw_values["vsync_mode"] = String(_vsync_mode_id(DEFAULT_VSYNC_MODE))

	var decoded := {}
	var bounded_numbers := {
		"ship_mouse_sensitivity": [MIN_SHIP_MOUSE_SENSITIVITY, MAX_SHIP_MOUSE_SENSITIVITY],
		"on_foot_mouse_sensitivity": [MIN_ON_FOOT_MOUSE_SENSITIVITY, MAX_ON_FOOT_MOUSE_SENSITIVITY],
		"camera_fov": [MIN_CAMERA_FOV, MAX_CAMERA_FOV],
		"master_volume": [MIN_VOLUME, MAX_VOLUME],
		"ambience_volume": [MIN_VOLUME, MAX_VOLUME],
		"engine_volume": [MIN_VOLUME, MAX_VOLUME],
		"weapons_volume": [MIN_VOLUME, MAX_VOLUME],
		"ui_volume": [MIN_VOLUME, MAX_VOLUME],
		"music_volume": [MIN_VOLUME, MAX_VOLUME],
		"ui_scale": [MIN_UI_SCALE, MAX_UI_SCALE],
	}
	for key: String in bounded_numbers:
		var bounds := bounded_numbers[key] as Array
		var raw_value: Variant = raw_values[key]
		if not _is_bounded_number(raw_value, float(bounds[0]), float(bounds[1])):
			return {"accepted": false, "reason": StringName("invalid_%s" % key)}
		decoded[key] = float(raw_value)
	if not raw_values.multiplayer_display_name is String:
		return {"accepted": false, "reason": &"invalid_multiplayer_display_name"}
	var decoded_name := _validated_multiplayer_display_name(raw_values.multiplayer_display_name)
	if decoded_name != String(raw_values.multiplayer_display_name).strip_edges():
		return {"accepted": false, "reason": &"invalid_multiplayer_display_name"}
	decoded["multiplayer_display_name"] = decoded_name
	if not _is_integral_json_number(raw_values.network_default_port):
		return {"accepted": false, "reason": &"invalid_network_default_port"}
	var decoded_port := int(raw_values.network_default_port)
	if decoded_port < MIN_NETWORK_DEFAULT_PORT or decoded_port > MAX_NETWORK_DEFAULT_PORT:
		return {"accepted": false, "reason": &"invalid_network_default_port"}
	decoded["network_default_port"] = decoded_port
	if not _is_integral_json_number(raw_values.multiplayer_max_players):
		return {"accepted": false, "reason": &"invalid_multiplayer_max_players"}
	var decoded_max_players := int(raw_values.multiplayer_max_players)
	if decoded_max_players < MIN_MULTIPLAYER_MAX_PLAYERS or decoded_max_players > MAX_MULTIPLAYER_MAX_PLAYERS:
		return {"accepted": false, "reason": &"invalid_multiplayer_max_players"}
	decoded["multiplayer_max_players"] = decoded_max_players
	for key: String in [
		"invert_ship_y",
		"invert_on_foot_y",
		"reduced_motion",
		"captions_enabled",
		"reduced_dynamic_range",
		"reduced_flash",
		"show_tutorials",
	]:
		if not raw_values[key] is bool:
			return {"accepted": false, "reason": StringName("invalid_%s" % key)}
		decoded[key] = bool(raw_values[key])
	if not _is_integral_json_number(raw_values.payload_visual_intensity):
		return {"accepted": false, "reason": &"invalid_payload_visual_intensity"}
	var decoded_payload_intensity := int(raw_values.payload_visual_intensity)
	if decoded_payload_intensity < MIN_PAYLOAD_VISUAL_INTENSITY or decoded_payload_intensity > MAX_PAYLOAD_VISUAL_INTENSITY:
		return {"accepted": false, "reason": &"invalid_payload_visual_intensity"}
	decoded["payload_visual_intensity"] = decoded_payload_intensity

	var stable_ids := {
		"graphics_profile": {
			"low": GraphicsProfile.LOW,
			"medium": GraphicsProfile.MEDIUM,
			"high": GraphicsProfile.HIGH,
		},
		"window_mode": {
			"windowed": WindowMode.WINDOWED,
			"borderless": WindowMode.BORDERLESS,
			"fullscreen": WindowMode.FULLSCREEN,
		},
		"vsync_mode": {
			"off": VSyncMode.OFF,
			"on": VSyncMode.ON,
			"adaptive": VSyncMode.ADAPTIVE,
		},
		"control_preset": {
			"modern": ControlPreset.MODERN,
			"classic": ControlPreset.CLASSIC,
		},
		"colorblind_palette": {
			"none": ColorblindPalette.NONE,
			"deuteranopia": ColorblindPalette.DEUTERANOPIA,
			"protanopia": ColorblindPalette.PROTANOPIA,
			"tritanopia": ColorblindPalette.TRITANOPIA,
		},
	}
	for key: String in stable_ids:
		var raw_id: Variant = raw_values[key]
		var choices := stable_ids[key] as Dictionary
		if not raw_id is String or not choices.has(raw_id):
			return {"accepted": false, "reason": StringName("invalid_%s" % key)}
		decoded[key] = int(choices[raw_id])
	if not raw_values.display_resolution is String or not SUPPORTED_DISPLAY_RESOLUTION_IDS.has(raw_values.display_resolution):
		return {"accepted": false, "reason": &"invalid_display_resolution"}
	decoded["display_resolution"] = String(raw_values.display_resolution)

	var profile_result := _decode_input_profile_json(raw_values.input_binding_profile)
	if not bool(profile_result.accepted):
		return {
			"accepted": false,
			"reason": (
				&"newer_input_binding_profile"
				if profile_result.get("reason") == &"newer_schema"
				else &"invalid_input_binding_profile"
			),
		}
	return {
		"accepted": true,
		"reason": &"valid",
		"values": decoded,
		"input_binding_profile": profile_result.profile,
	}


func _decode_input_profile_json(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false}
	var raw_profile := (candidate as Dictionary).duplicate(true)
	if not _has_exact_string_keys(
		raw_profile, ["schema_version", "bindings", "action_options"]
	):
		return {"accepted": false}
	if not _is_integral_json_number(raw_profile.schema_version):
		return {"accepted": false}
	var profile_schema := int(raw_profile.schema_version)
	if profile_schema > InputBindingProfile.SCHEMA_VERSION:
		return {"accepted": false, "reason": &"newer_schema"}
	if profile_schema < InputBindingProfile.MINIMUM_SUPPORTED_SCHEMA_VERSION:
		return {"accepted": false}
	raw_profile.schema_version = profile_schema
	if not raw_profile.bindings is Dictionary or not raw_profile.action_options is Dictionary:
		return {"accepted": false}
	var raw_bindings := raw_profile.bindings as Dictionary
	var raw_options := raw_profile.action_options as Dictionary
	for raw_action: Variant in raw_bindings:
		if not raw_action is String or (raw_action as String).is_empty():
			return {"accepted": false}
		if not raw_bindings[raw_action] is Array:
			return {"accepted": false}
		for raw_binding: Variant in raw_bindings[raw_action] as Array:
			if not raw_binding is Dictionary:
				return {"accepted": false}
			var binding := raw_binding as Dictionary
			# Godot's JSON parser promotes all descriptor integers to floats.
			# Restore only the known integral fields before domain validation;
			# canonical comparison below still rejects unknown or extra fields.
			for integer_key: String in ["physical_keycode", "button_index", "axis"]:
				if not binding.has(integer_key):
					continue
				if not _is_integral_json_number(binding[integer_key]):
					return {"accepted": false}
				binding[integer_key] = int(binding[integer_key])
	for raw_action: Variant in raw_options:
		if not raw_action is String or (raw_action as String).is_empty():
			return {"accepted": false}

	var profile := InputBindingProfile.from_dictionary(raw_profile)
	if not _input_rebind_service.is_profile_compatible_with_defaults(profile):
		return {"accepted": false}
	if _input_profile_to_json_dictionary(profile) != raw_profile:
		return {"accepted": false}
	return {"accepted": true, "profile": profile}


static func _input_profile_to_json_dictionary(profile: InputBindingProfile) -> Dictionary:
	var encoded_bindings := {}
	var encoded_options := {}
	for action: StringName in profile.bindings:
		var encoded_action_bindings: Array[Dictionary] = []
		for binding: Dictionary in profile.get_bindings(action):
			var encoded := {}
			for key: Variant in binding:
				var value: Variant = binding[key]
				encoded[String(key)] = String(value) if value is StringName else value
			encoded_action_bindings.append(encoded)
		encoded_bindings[String(action)] = encoded_action_bindings
		var options := profile.get_action_options(action)
		encoded_options[String(action)] = {
			"deadzone": float(options.deadzone),
			"curve": String(options.curve),
			"hold_mode": String(options.hold_mode),
		}
	return {
		"schema_version": profile.schema_version,
		"bindings": encoded_bindings,
		"action_options": encoded_options,
	}


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	for key: String in expected:
		if not candidate.has(key):
			return false
	return true


static func _is_bounded_number(value: Variant, minimum: float, maximum: float) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number >= minimum and number <= maximum


static func _is_integral_json_number(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) \
		and number == floor(number) and absf(number) <= _MAX_SAFE_JSON_INTEGER


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


static func _validated_display_resolution(value: String) -> String:
	return value if SUPPORTED_DISPLAY_RESOLUTION_IDS.has(value) else DEFAULT_DISPLAY_RESOLUTION_ID


static func _validated_vsync_mode(value: int) -> int:
	return value if value in [VSyncMode.OFF, VSyncMode.ON, VSyncMode.ADAPTIVE] else DEFAULT_VSYNC_MODE


static func _validated_control_preset(value: int) -> int:
	return value if value in [ControlPreset.MODERN, ControlPreset.CLASSIC] else DEFAULT_CONTROL_PRESET


static func _validated_colorblind_palette(value: int) -> int:
	return value if _COLORBLIND_PALETTE_IDS.has(value) else DEFAULT_COLORBLIND_PALETTE


static func _validated_multiplayer_display_name(value: Variant) -> String:
	if not value is String:
		return DEFAULT_MULTIPLAYER_DISPLAY_NAME
	var normalized := (value as String).strip_edges()
	if normalized.length() < MIN_MULTIPLAYER_DISPLAY_NAME_LENGTH:
		return DEFAULT_MULTIPLAYER_DISPLAY_NAME
	if normalized.length() > MAX_MULTIPLAYER_DISPLAY_NAME_LENGTH:
		return normalized.substr(0, MAX_MULTIPLAYER_DISPLAY_NAME_LENGTH)
	return normalized


func _read_input_binding_profile(config: ConfigFile) -> InputBindingProfile:
	var defaults := _input_rebind_service.get_defaults()
	if not config.has_section_key(_SECTION_INPUT_BINDINGS, "profile"):
		return defaults
	var parsed := InputBindingProfile.from_dictionary(
		config.get_value(_SECTION_INPUT_BINDINGS, "profile", null)
	)
	if not _input_rebind_service.is_profile_compatible_with_defaults(parsed):
		return defaults
	return parsed


static func _read_number(config: ConfigFile, section: String, key: String, default_value: float) -> float:
	var value: Variant = config.get_value(section, key, default_value)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default_value
	var number := float(value)
	return default_value if is_nan(number) or is_inf(number) else number


static func _read_bool(config: ConfigFile, section: String, key: String, default_value: bool) -> bool:
	var value: Variant = config.get_value(section, key, default_value)
	return bool(value) if typeof(value) == TYPE_BOOL else default_value


static func _read_multiplayer_display_name(value: Variant) -> String:
	if not value is String:
		return DEFAULT_MULTIPLAYER_DISPLAY_NAME
	var normalized := (value as String).strip_edges()
	if normalized.length() < MIN_MULTIPLAYER_DISPLAY_NAME_LENGTH or normalized.length() > MAX_MULTIPLAYER_DISPLAY_NAME_LENGTH:
		return DEFAULT_MULTIPLAYER_DISPLAY_NAME
	return normalized


static func _read_int_bounded(
	config: ConfigFile, section: String, key: String, default_value: int, minimum: int, maximum: int
) -> int:
	var value: Variant = config.get_value(section, key, default_value)
	if typeof(value) != TYPE_INT:
		return default_value
	return clampi(int(value), minimum, maximum)


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


static func _vsync_mode_id(value: int) -> StringName:
	match value:
		VSyncMode.OFF:
			return &"off"
		VSyncMode.ADAPTIVE:
			return &"adaptive"
	return &"on"


static func _vsync_backend_mode(value: int) -> int:
	match value:
		VSyncMode.OFF:
			return DisplayServer.VSYNC_DISABLED
		VSyncMode.ADAPTIVE:
			return DisplayServer.VSYNC_ADAPTIVE
	return DisplayServer.VSYNC_ENABLED


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


static func _parse_display_resolution(value: Variant) -> String:
	return _validated_display_resolution(String(value)) if value is String else DEFAULT_DISPLAY_RESOLUTION_ID


static func _parse_vsync_mode(value: Variant) -> int:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return DEFAULT_VSYNC_MODE
	match String(value).to_lower():
		"off":
			return VSyncMode.OFF
		"adaptive":
			return VSyncMode.ADAPTIVE
	return DEFAULT_VSYNC_MODE


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
