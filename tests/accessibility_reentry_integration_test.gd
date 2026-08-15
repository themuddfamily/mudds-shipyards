extends SceneTree

## Production integration for the accessibility presets and the settings surface
## they live in. Everything runs through real `res://scenes/main.tscn`: the HUD's
## own change signals, GameFlow's settings owner, the real ConfigFile transaction,
## a simulated restart, and a whole-Main detach/re-entry.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Palette := preload("res://scripts/ui/hud_palette.gd")

## Flight-authority values a presentation preset must never touch.
const FLIGHT_PROPERTIES: Array[StringName] = [
	&"maximum_speed",
	&"thrust_acceleration",
	&"brake_acceleration",
	&"passive_drag",
	&"throttle_response",
	&"boost_speed",
	&"boost_multiplier",
	&"yaw_speed_degrees",
	&"roll_speed_degrees",
	&"mouse_sensitivity",
	&"flight_assist_strength",
	&"maximum_mouse_turn_degrees",
	&"weapon_cooldown",
	&"landing_maximum_speed",
]

var _failures: Array[String] = []
var _temp_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_temp_path = "user://accessibility_integration_%d.cfg" % Time.get_ticks_usec()
	_cleanup()

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the accessibility integration")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var hud := game.get_node_or_null("HUD") as GameHUD
	var audio := game.get_node_or_null("AudioDirector") as AudioDirector
	var combat_audio := game.get_combat_audio_presentation()
	var settings := game.get_runtime_settings()
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(
		hud != null and audio != null and combat_audio != null and settings != null and fleet.size() == 4,
		"the production fixture exposes the HUD, both audio owners, the settings resource, and the full fleet"
	)
	if hud == null or audio == null or combat_audio == null or settings == null or fleet.is_empty():
		await _clean_up(game)
		_finish()
		return

	# Isolate this run from the developer's real settings file, then start from
	# authored defaults so nothing below depends on the host machine.
	settings.config_path = _temp_path
	settings.reset_to_defaults()
	await process_frame

	# Each hull authors its own boom lag (4.0 / 6.0 / 8.0 degrees), so the reset
	# leg must restore per-ship values rather than one shared number.
	var authored_lag := {}
	for fleet_ship in fleet:
		authored_lag[fleet_ship.ship_id] = fleet_ship.maximum_chase_camera_rotation_lag_degrees
	var flight_before := _flight_snapshot(fleet)

	await _test_live_application(game, hud, fleet, authored_lag)
	_test_flight_authority_untouched(fleet, flight_before)
	await _test_captions_through_production_audio(hud, audio, combat_audio, fleet)
	_test_invalid_values_rejected(game, hud, settings)
	_test_persistence_across_restart(settings)
	await _test_whole_main_reentry(game, hud, fleet)
	await _test_reset_restores_defaults(game, hud, fleet, authored_lag)

	await _clean_up(game)
	_cleanup()
	_finish()


func _test_live_application(
	game: GameFlow,
	hud: GameHUD,
	fleet: Array[HeroShip],
	authored_lag: Dictionary
) -> void:
	var report := hud.get_accessibility_report()
	_check(
		hud.get_hud_palette_id() == Palette.MODE_NONE
		and is_equal_approx(float(report["ui_scale"]), 1.0)
		and not bool(report["reduced_motion"])
		and not bool(report["captions_enabled"]),
		"a defaulted shift presents the authored HUD with no preset applied"
	)

	# Drive every preset through the real pause-panel signal, not the resource.
	hud.setting_change_requested.emit(&"ui_scale", 1.35)
	hud.setting_change_requested.emit(&"colorblind_palette", Settings.ColorblindPalette.DEUTERANOPIA)
	hud.setting_change_requested.emit(&"reduced_motion", true)
	hud.setting_change_requested.emit(&"captions_enabled", true)
	await process_frame

	var applied := hud.get_accessibility_report()
	_check(is_equal_approx(float(applied["ui_scale"]), 1.35), "a UI-scale request from the pause panel reaches the live HUD")
	_check(
		is_equal_approx(float(applied["scaled_layer_scale"]), float(applied["effective_ui_scale"])),
		"the scaled HUD layer physically adopts the effective factor"
	)
	_check(
		float(applied["effective_ui_scale"]) > 1.0
		and float(applied["effective_ui_scale"]) <= 1.35,
		"the request enlarges the HUD up to this viewport's non-overlapping layout ceiling"
	)
	_check(hud.get_hud_palette_id() == Palette.MODE_DEUTERANOPIA, "a colour-vision request from the pause panel retints the live HUD")
	_check(
		Color(applied["danger_color"]) == Palette.get_role_color(Palette.MODE_DEUTERANOPIA, Palette.ROLE_DANGER),
		"the live HUD danger role matches the verified preset colour"
	)
	_check(bool(applied["reduced_motion"]) and bool(applied["captions_enabled"]), "the motion and caption presets latch on")
	_check(
		is_equal_approx(float(applied["damage_flash_alpha"]), GameHUD.REDUCED_DAMAGE_FLASH_ALPHA),
		"reduced motion damps the live full-screen damage flash"
	)

	var damped := true
	for fleet_ship in fleet:
		if not is_zero_approx(fleet_ship.maximum_chase_camera_rotation_lag_degrees):
			damped = false
	_check(damped, "reduced motion snaps every chase boom to the physical hull instead of letting it lag")
	var authored_lags_present := not authored_lag.is_empty()
	for value: float in authored_lag.values():
		if value <= 0.0:
			authored_lags_present = false
	_check(authored_lags_present, "every authored chase boom really does lag, so damping it is a visible change")
	_check(game.get_runtime_settings().reduced_motion, "the settings owner records the applied preset")


func _test_flight_authority_untouched(fleet: Array[HeroShip], before: Dictionary) -> void:
	var after := _flight_snapshot(fleet)
	_check(
		after == before,
		"no accessibility preset changes any flight-handling value, deadzone, or weapon timing"
	)


func _test_captions_through_production_audio(
	hud: GameHUD,
	audio: AudioDirector,
	combat_audio: CombatAudioPresentation,
	fleet: Array[HeroShip]
) -> void:
	audio.play_target_destroyed()
	await process_frame
	var log := hud.get_caption_log()
	_check(
		log.size() >= 1 and log[log.size() - 1] == "[ range target destroyed ]",
		"a production flow cue reaches the caption channel"
	)

	combat_audio.play_explosion(fleet[0].global_position, fleet[0].get_instance_id())
	await process_frame
	log = hud.get_caption_log()
	_check(
		log[log.size() - 1] == "[ ship explosion ]",
		"a production combat cue reaches the caption channel through the real presentation component"
	)

	# Footsteps are the highest-rate cue in the build and must never caption.
	var before := hud.get_caption_log().size()
	for index in 8:
		audio.play_footstep(1.0)
	await process_frame
	_check(hud.get_caption_log().size() == before, "footsteps never enter the caption channel")


func _test_invalid_values_rejected(game: GameFlow, hud: GameHUD, settings: RuntimeSettings) -> void:
	hud.setting_change_requested.emit(&"ui_scale", 12.0)
	_check(is_equal_approx(settings.ui_scale, Settings.MAX_UI_SCALE), "an out-of-range UI scale clamps at the settings owner")
	hud.setting_change_requested.emit(&"ui_scale", NAN)
	_check(is_equal_approx(settings.ui_scale, Settings.DEFAULT_UI_SCALE), "a non-finite UI scale returns to the authored default")
	hud.setting_change_requested.emit(&"colorblind_palette", 97)
	_check(
		settings.colorblind_palette == Settings.ColorblindPalette.NONE
		and hud.get_hud_palette_id() == Palette.MODE_NONE,
		"an unknown colour-vision index falls back to the authored palette everywhere"
	)
	hud.setting_change_requested.emit(&"not_a_setting", true)
	_check(
		game.get_runtime_settings() == settings,
		"an unknown setting key is ignored rather than injected into the settings resource"
	)

	# Restore a fully applied preset for the persistence and re-entry legs.
	hud.setting_change_requested.emit(&"ui_scale", 1.35)
	hud.setting_change_requested.emit(&"colorblind_palette", Settings.ColorblindPalette.TRITANOPIA)


func _test_persistence_across_restart(settings: RuntimeSettings) -> void:
	_check(settings.save_to_file() == OK, "the applied presets save through the real settings transaction")
	var stored := ConfigFile.new()
	_check(stored.load(_temp_path) == OK, "the saved settings file parses")
	_check(
		int(stored.get_value("meta", "schema_version", -1)) == Settings.SCHEMA_VERSION,
		"the saved file carries the current schema version"
	)

	# A restart is a fresh resource reading the same file.
	var restarted := Settings.new(_temp_path)
	_check(restarted.load_from_file() == OK, "a restarted client loads the saved settings")
	_check(
		is_equal_approx(restarted.ui_scale, 1.35)
		and restarted.colorblind_palette == Settings.ColorblindPalette.TRITANOPIA
		and restarted.reduced_motion
		and restarted.captions_enabled,
		"every accessibility preset survives a save/restart cycle"
	)
	_check(
		restarted.get_accessibility_descriptor() == settings.get_accessibility_descriptor(),
		"the restarted descriptor is identical to the live one"
	)

	# A settings file written by the previous schema must still load, upgrading
	# the keys it never knew about to their authored defaults.
	var legacy_path := _temp_path + ".legacy"
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "schema_version", Settings.MINIMUM_SUPPORTED_SCHEMA_VERSION)
	legacy.set_value("camera", "fov", 95.0)
	legacy.set_value("graphics", "profile", "medium")
	_check(legacy.save(legacy_path) == OK, "a previous-schema settings fixture saves")
	var migrated := Settings.new(legacy_path)
	_check(migrated.load_from_file() == OK, "a previous-schema settings file still loads instead of being discarded")
	_check(
		is_equal_approx(migrated.camera_fov, 95.0)
		and migrated.graphics_profile == Settings.GraphicsProfile.MEDIUM,
		"migration preserves the values the older writer did store"
	)
	_check(
		is_equal_approx(migrated.ui_scale, Settings.DEFAULT_UI_SCALE)
		and migrated.colorblind_palette == Settings.ColorblindPalette.NONE
		and not migrated.reduced_motion
		and not migrated.captions_enabled,
		"keys the older writer never stored migrate to their authored accessibility defaults"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

	# A corrupt file must not overwrite the live, already-applied presets.
	var corrupt_path := _temp_path + ".corrupt"
	var corrupt := ConfigFile.new()
	corrupt.set_value("meta", "schema_version", Settings.SCHEMA_VERSION + 4)
	corrupt.set_value("accessibility", "ui_scale", 0.1)
	_check(corrupt.save(corrupt_path) == OK, "an unsupported-schema fixture saves")
	var live_before: Dictionary = settings.get_accessibility_descriptor()
	_check(settings.load_from_file(corrupt_path) == ERR_INVALID_DATA, "an unsupported schema fails closed")
	_check(
		settings.get_accessibility_descriptor() == live_before,
		"a rejected settings file leaves every live preset exactly as it was"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))


func _test_whole_main_reentry(game: GameFlow, hud: GameHUD, fleet: Array[HeroShip]) -> void:
	var before := hud.get_accessibility_report()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	await process_frame
	await process_frame

	var after := hud.get_accessibility_report()
	_check(
		hud.get_hud_palette_id() == Palette.MODE_TRITANOPIA,
		"a whole-Main detach and re-entry preserves the applied colour-vision preset"
	)
	_check(
		is_equal_approx(float(after["ui_scale"]), float(before["ui_scale"]))
		and is_equal_approx(float(after["scaled_layer_scale"]), float(before["scaled_layer_scale"])),
		"UI scale survives a whole-Main detach and re-entry"
	)
	_check(
		bool(after["reduced_motion"]) and bool(after["captions_enabled"]),
		"the motion and caption presets survive a whole-Main detach and re-entry"
	)
	_check(
		Color(after["danger_color"]) == Color(before["danger_color"]),
		"every retinted role is identical after re-entry"
	)
	var still_damped := true
	for fleet_ship in fleet:
		if not is_zero_approx(fleet_ship.maximum_chase_camera_rotation_lag_degrees):
			still_damped = false
	_check(still_damped, "reduced motion is reapplied to every chase boom after re-entry")

	# The caption channel must survive re-entry as a working channel, not just as
	# a remembered flag.
	var log_before := hud.get_caption_log().size()
	(game.get_node_or_null("AudioDirector") as AudioDirector).play_combat_alert()
	await process_frame
	_check(
		hud.get_caption_log().size() > log_before or log_before == GameHUD.CAPTION_HISTORY_LIMIT,
		"the caption channel still receives production cues after re-entry"
	)
	_check(
		hud.get_caption_log()[hud.get_caption_log().size() - 1] == "[ combat alert ]",
		"the post-re-entry caption reports the cue that actually fired"
	)


func _test_reset_restores_defaults(
	game: GameFlow,
	hud: GameHUD,
	fleet: Array[HeroShip],
	authored_lag: Dictionary
) -> void:
	hud.settings_reset_requested.emit()
	await process_frame

	var settings := game.get_runtime_settings()
	_check(
		is_equal_approx(settings.ui_scale, Settings.DEFAULT_UI_SCALE)
		and settings.colorblind_palette == Settings.ColorblindPalette.NONE
		and not settings.reduced_motion
		and not settings.captions_enabled,
		"Reset Defaults clears every accessibility preset in the settings owner"
	)
	var report := hud.get_accessibility_report()
	_check(
		hud.get_hud_palette_id() == Palette.MODE_NONE
		and is_equal_approx(float(report["ui_scale"]), 1.0)
		and is_equal_approx(float(report["scaled_layer_scale"]), 1.0)
		and not bool(report["reduced_motion"])
		and not bool(report["captions_enabled"]),
		"Reset Defaults returns the live HUD to the authored presentation"
	)
	_check(
		Color(report["danger_color"]) == Palette.get_role_color(Palette.MODE_NONE, Palette.ROLE_DANGER),
		"a reset HUD is bit-identical to the authored palette"
	)
	var restored := true
	for fleet_ship in fleet:
		var expected := float(authored_lag.get(fleet_ship.ship_id, -1.0))
		if not is_equal_approx(fleet_ship.maximum_chase_camera_rotation_lag_degrees, expected):
			restored = false
	_check(restored, "Reset Defaults restores the exact authored chase-boom lag rather than leaving it snapped")


func _flight_snapshot(fleet: Array[HeroShip]) -> Dictionary:
	var snapshot := {}
	for fleet_ship in fleet:
		var values := {}
		for property in FLIGHT_PROPERTIES:
			values[property] = fleet_ship.get(property)
		snapshot[fleet_ship.ship_id] = values
	return snapshot


func _clean_up(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".legacy", ".corrupt"]:
		var absolute := ProjectSettings.globalize_path(_temp_path + suffix)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
		elif DirAccess.dir_exists_absolute(absolute):
			DirAccess.remove_absolute(absolute)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("ACCESSIBILITY_REENTRY_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("ACCESSIBILITY_REENTRY_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
