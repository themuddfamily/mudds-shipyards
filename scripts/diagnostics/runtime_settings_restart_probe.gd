extends Node

## Opt-in embedded release caller for the one shared Reduced flash preference
## sequence. Settings and lifecycle authority remain with Boot's actual Main.
## Raw keyboard events exercise real GUI controls; the damage cue is explicitly
## staged through the real HUD component, not a combat/gameplay qualification.
var stage: String = ""
var private_root: String = ""
var _started := false
var _failed := false
var _raw_events := 0
var _observations: Array[Dictionary] = []
var _game: GameFlow
var _hud: GameHUD
var _defaults: Dictionary
var _startup_payload: Dictionary
var _guard: Dictionary


func on_startup_completed(main: Node) -> void:
	if _started or not main is GameFlow or get_parent().call("get_main") != main:
		_fail("accept Boot's actual Main exactly once")
		return
	_started = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = main as GameFlow
	_begin.call_deferred()


func _private_launch() -> bool:
	var owned := private_root.simplify_path()
	if not owned.is_absolute_path() or owned == "/" or owned != private_root \
			or OS.get_environment("MUDDS_PRIVATE_SETTINGS_RESTART_ROOT") != owned:
		return false
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		if not OS.get_environment(variable).simplify_path().begins_with(owned + "/"):
			return false
	return OS.get_user_data_dir().simplify_path().begins_with(owned + "/") \
		and AudioServer.get_driver_name() == "Dummy" and DisplayServer.get_name() == "headless" \
		and stage in ["writer", "reader", "reset-reader"]


func _begin() -> void:
	# No preference mutation or file write before checking the owned namespace.
	if not _check(_private_launch(), "private headless/Dummy production files"):
		return
	await get_tree().process_frame
	_hud = _game.get_node_or_null(^"HUD") as GameHUD
	var report := _game.get_runtime_settings_persistence_report()
	if not _check(_hud != null and is_instance_valid(_game.player)
			and not bool(report.injected_authority) and report.identity_scope == &"process_lifetime"
			and int(report.load_attempt_count) == 1 and bool(report.load_before_first_apply)
			and bool(report.load_status.accepted), "normal Boot Main loaded production authority before apply"):
		return
	_defaults = RuntimeSettings.new().to_dictionary()
	# Boot has already initialized the real store and authored settings. This
	# unrelated namespace exercises preservation without seeding preferences or
	# replacing the production persistence authority.
	var store := _game.get("_runtime_settings_user_data_store") as UserDataStore
	if not _check(store != null, "Boot's actual production store owns the unrelated guard"):
		return
	if stage == "writer":
		var payload := store.get_snapshot()
		if not _check(not payload.has("settings_restart_probe_guard"), "writer starts without an earlier guard"):
			return
		payload["settings_restart_probe_guard"] = {"writer_pid": OS.get_process_id(),
			"unrelated": {"progress": 42, "keep": "flash-restart"}}
		var committed := store.commit(payload, store.get_generation(), "settings-restart-unrelated-guard")
		if not _check(bool(committed.accepted), "real production store commits only the unrelated guard after Boot"):
			return
	_guard = _document().get("payload", {}).get("settings_restart_probe_guard", {})
	if not _check(_guard.get("unrelated", {}) == JSON.parse_string(JSON.stringify({"progress": 42, "keep": "flash-restart"}))
			and int(_guard.get("writer_pid", 0)) > 0
			and (int(_guard.writer_pid) == OS.get_process_id() if stage == "writer" else int(_guard.writer_pid) != OS.get_process_id()),
			"exact unrelated guard and distinct cold-reader writer PID"):
		return
	_startup_payload = _document().get("payload", {}).duplicate(true)
	var cold_on := stage == "reader"
	if not _state(cold_on, "cold runtime"):
		return
	if not await _activate("IntroBeginShiftButton"):
		return
	var deadline := Time.get_ticks_msec() + 5000
	while (_game.phase != GameFlow.Phase.APPROACH_SHIP or not _game.player.is_on_floor()) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if not _check(_game.phase == GameFlow.Phase.APPROACH_SHIP and _game.player.is_on_floor()
			and _game.player.is_control_enabled() and not _game.player.is_seated(), "normal Begin Shift enters supported gameplay"):
		return
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	if not _check(get_tree().paused, "raw Escape pauses the actual SceneTree") \
			or not await _activate("SettingsOpenButton") or not await _focus("ReducedFlashControl"):
		return
	if not _state(cold_on, "cold visible checkbox") or not _new_cue(cold_on, "cold new staged HUD cue"):
		return
	if stage == "writer":
		# Navigation is complete before staging this transient. All three raw
		# control activations and synchronous observations share one engine frame;
		# neither this probe nor the settings transaction steps/pauses its tween.
		var cue := _hud.get("_damage_tween") as Tween
		var elapsed := cue.get_total_elapsed_time()
		for enabled: bool in [true, false, true]:
			_key(KEY_SPACE)
			if not _state(enabled, "raw ReducedFlashControl toggle") \
					or not _current_cue(cue, elapsed, "OFF ON OFF ON current cue"):
				return
		if not _new_cue(true, "new ON staged HUD cue"):
			return
		var saves := int(_game.get_runtime_settings_persistence_report().save_success_count)
		if not await _activate("SettingsSaveButton") or not _feedback("SETTINGS SAVED", saves + 1) \
				or not _state(true, "Apply + Save durable ON"):
			return
	elif stage == "reader":
		if not await _focus("SettingsResetButton"):
			return
		if not _new_cue(true, "pre-reset staged ON cue"):
			return
		var cue := _hud.get("_damage_tween") as Tween
		var elapsed := cue.get_total_elapsed_time()
		var saves := int(_game.get_runtime_settings_persistence_report().save_success_count)
		_key(KEY_SPACE)
		var confirm := _hud.find_child("ConfirmSettingsResetButton", true, false) as Button
		if confirm != null and confirm.is_visible_in_tree():
			if not _check(confirm.has_focus(), "ordinary dirty-reset prompt owns confirmation focus"):
				return
			_key(KEY_SPACE)
		if not _feedback("DEFAULTS RESTORED + SAVED", saves + 1) or not _state(false, "whole Reset Defaults durable OFF") \
				or not _current_cue(cue, elapsed, "Reset does not relight current ON cue") \
				or not _new_cue(false, "new reset OFF staged HUD cue"):
			return
	var final_on := stage == "writer"
	if not _state(final_on, "pre-quit complete settings"):
		return
	var before_quit := _document()
	if not await _activate("SettingsBackButton") or not await _focus("ExitButton"):
		return
	_release_keys()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("SETTINGS_RESTART_READY: ", JSON.stringify({
		"stage": stage, "pid": OS.get_process_id(), "main_id": _game.get_instance_id(),
		"boot_main": get_parent().call("get_main") == _game, "private_root": private_root,
		"user_data_dir": OS.get_user_data_dir(), "audio_driver": AudioServer.get_driver_name(),
		"display_driver": DisplayServer.get_name(), "raw_event_count": _raw_events,
		"engine_argv": OS.get_cmdline_args(), "startup_payload": _startup_payload,
		"before_quit_document": before_quit, "settings": _game.get_runtime_settings().to_user_data_payload(),
		"authored_defaults": _defaults, "observations": _observations,
		"cue_trigger": "staged_real_HUD_flash_damage_component", "physical_input": "NOT_RUN",
		"native_gpu": "NOT_RUN", "rendered_readability": "NOT_RUN", "ordinary_combat": "NOT_RUN",
		"quit_owner": "focused_normal_HUD_ExitButton_raw_Space"}))
	# Only the ordinary GUI handler invokes Main's orderly shutdown and quit.
	_key(KEY_SPACE)


func _state(enabled: bool, label: String) -> bool:
	var expected := _defaults.duplicate(true)
	expected.reduced_flash = enabled
	var control := _hud.find_child("ReducedFlashControl", true, false) as CheckButton
	var document := _document()
	var disk: Dictionary = document.get("payload", {}).get("runtime_settings", {})
	return _check(_game.get_runtime_settings().to_dictionary() == expected
		and not _game.get_runtime_settings().reduced_motion
		and _game.get_runtime_settings().payload_visual_intensity == 2
		and control != null and control.button_pressed == enabled
		and document.get("payload", {}).get("settings_restart_probe_guard", {}) == _guard
		and disk == JSON.parse_string(JSON.stringify(_game.get_runtime_settings().to_user_data_payload())), label + ": full defaults except selected Reduced flash and real primary agree")


func _feedback(text: String, successes: int) -> bool:
	var label := _hud.get("_settings_status_label") as Label
	var report := _game.get_runtime_settings_persistence_report()
	return _check(label != null and label.is_visible_in_tree() and label.text == text
		and not _hud.has_unsaved_settings() and not bool(report.unsaved_changes)
		and int(report.save_success_count) == successes and bool(report.last_save_status.accepted),
		"actual successful " + text + " feedback and cleared dirty state")


func _new_cue(enabled: bool, label: String) -> bool:
	_hud.flash_damage(1.0, Vector2.RIGHT)
	var flash := _hud.get("_damage_flash") as ColorRect
	var direction := _hud.get("_damage_direction") as Control
	var cue := _hud.get("_damage_tween") as Tween
	var alpha := flash.color.a * flash.modulate.a
	_observations.append({"label": label, "reduced_flash": enabled, "alpha": alpha,
		"tween_id": cue.get_instance_id(), "elapsed": cue.get_total_elapsed_time(),
		"remaining_flash_seconds": GameHUD.DAMAGE_FLASH_FADE_SECONDS - cue.get_total_elapsed_time(),
		"direction_visible": direction.is_visible_in_tree(), "scene_tree_paused": get_tree().paused})
	return _check(flash.is_visible_in_tree() and direction.is_visible_in_tree() and cue.is_valid()
		and is_equal_approx(alpha, GameHUD.REDUCED_DAMAGE_FLASH_ALPHA if enabled else GameHUD.DAMAGE_FLASH_ALPHA)
		and cue.get_total_elapsed_time() < GameHUD.DAMAGE_FLASH_FADE_SECONDS, label)


func _current_cue(cue: Tween, elapsed: float, label: String) -> bool:
	var flash := _hud.get("_damage_flash") as ColorRect
	var direction := _hud.get("_damage_direction") as Control
	var alpha := flash.color.a * flash.modulate.a
	var retained: bool = _hud.get("_damage_tween") == cue and cue.is_valid()
	var now := cue.get_total_elapsed_time() if retained else -1.0
	_observations.append({"label": label, "reduced_flash": _game.get_runtime_settings().reduced_flash,
		"alpha": alpha, "retained_tween": retained, "elapsed": now,
		"remaining_flash_seconds": GameHUD.DAMAGE_FLASH_FADE_SECONDS - now,
		"baseline_elapsed": elapsed, "direction_visible": direction.is_visible_in_tree(),
		"cue_duration": _hud.get("_damage_cue_duration"),
		"expected_duration": GameHUD.DAMAGE_DIRECTION_FADE_SECONDS})
	return _check(retained and direction.is_visible_in_tree() and alpha > 0.0
		and alpha <= GameHUD.REDUCED_DAMAGE_FLASH_ALPHA + 0.000001 and now >= elapsed
		and now < GameHUD.DAMAGE_FLASH_FADE_SECONDS
		and is_equal_approx(float(_hud.get("_damage_cue_duration")), GameHUD.DAMAGE_DIRECTION_FADE_SECONDS), label)


func _focus(name: String) -> bool:
	var control := _hud.find_child(name, true, false) as BaseButton
	if not _check(control != null and control.is_visible_in_tree() and not control.disabled, "available control " + name):
		return false
	for step in 160:
		if control.has_focus():
			await get_tree().process_frame
			await get_tree().process_frame
			var visible := control.get_global_rect().intersection(get_viewport().get_visible_rect())
			var ancestor := control.get_parent()
			while ancestor is Control:
				if (ancestor as Control).clip_contents:
					visible = visible.intersection((ancestor as Control).get_global_rect())
				ancestor = ancestor.get_parent()
			return _check(visible.size.x > 1.0 and visible.size.y >= control.size.y - 1.0,
				"raw Tab navigation reaches fully visible " + name)
		_key(KEY_TAB)
		await get_tree().process_frame
	return _check(false, "bounded raw Tab navigation reaches " + name)


func _activate(name: String) -> bool:
	if not await _focus(name):
		return false
	_key(KEY_SPACE)
	await get_tree().process_frame
	return not _failed


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		_raw_events += 1
		Input.flush_buffered_events()


func _release_keys() -> void:
	for code: Key in [KEY_TAB, KEY_SPACE, KEY_ESCAPE]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _document() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://mudds_user_data.json"))
	return parsed if parsed is Dictionary else {}


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_fail(description)
	return condition


func _fail(description: String) -> void:
	_failed = true
	_release_keys()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("SETTINGS_RESTART_FAILED: ", description)
	print("SETTINGS_RESTART_FAILURE_OBSERVATIONS: ", JSON.stringify(_observations))
	get_tree().quit(1)


func _exit_tree() -> void:
	_release_keys()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
