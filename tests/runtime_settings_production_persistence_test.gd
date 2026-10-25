extends SceneTree

## Focused production composition test for the atomic RuntimeSettings store.
## Default mode injects an in-memory UserDataStore into every Main instance.
## Opt-in --fire-restart-writer / --fire-restart-reader modes use the production
## disk store only inside --fire-restart-private-root=<absolute private root>.
## Run each mode in a separate headless/Dummy process with the SAME private
## XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME beneath that root. Example:
## env XDG_DATA_HOME="$CASE/data" XDG_CONFIG_HOME="$CASE/config" \
##   XDG_CACHE_HOME="$CASE/cache" timeout 300s godot --headless \
##   --audio-driver Dummy --path "$WORKTREE" --script \
##   res://tests/runtime_settings_production_persistence_test.gd -- \
##   --fire-restart-writer --fire-restart-private-root="$CASE"
## Interact uses --interact-restart-writer, --interact-restart-reader, then
## --interact-reset-reader, all with --interact-restart-private-root="$CASE".
## Require each unique INTERACT_*_OK marker, actual OS exit 0 through HUD Exit,
## and external verification of the durable orderly-shutdown marker. The reader
## resets Interact through its per-action Reset and Apply + Save before exiting.
## Sprint uses --sprint-restart-writer, --sprint-restart-reader, then
## --sprint-reset-reader with --sprint-restart-private-root="$CASE". Require
## SPRINT_RESTART_WRITER_OK / SPRINT_RESTART_READER_OK / SPRINT_RESET_READER_OK,
## actual OS exit 0 and orderly shutdown for each separate process.
## Colour uses --colour-restart-writer, --colour-restart-reader, then
## --colour-reset-reader with --colour-restart-private-root="$CASE". Require
## COLOUR_RESTART_WRITER_OK / COLOUR_RESTART_READER_OK / COLOUR_RESET_READER_OK,
## actual HUD Exit / OS0 and external clean markers in three separate processes.
## This proves source composition, synthetic raw walking and actual palette
## consumers; rendered readability/device input/original Gate C remain NOT_RUN.
## Reap writer (exit 0 + FIRE_RESTART_WRITER_OK), then repeat with reader flag;
## require exit 0 + FIRE_RESTART_READER_OK. Never run these modes in parallel.
## Raw key/mouse events and the reader's focus-in lifecycle notification are
## synthetic. Physical devices, native focus, flight/combat: NOT_RUN.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")

const STORE_PATH := "memory://runtime-settings-production.json"
const LEGACY_PATH := "memory://runtime-settings-production-legacy.cfg"

var _assertions := 0
var _failures: Array[String] = []


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var fail_write_once := false
	var fail_reads := false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		if fail_reads:
			return {"error": ERR_FILE_CANT_READ, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if fail_write_once:
			fail_write_once = false
			files[path] = bytes.slice(0, maxi(1, bytes.size() / 2))
			return ERR_FILE_CANT_WRITE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


class MutableInputProvider:
	extends RefCounted

	var strengths := {}
	var pressed := {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))

	func set_action(action: StringName, strength: float, is_pressed: bool) -> void:
		strengths[action] = strength
		pressed[action] = is_pressed


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--colour-restart-writer") or args.has("--colour-restart-reader") or args.has("--colour-reset-reader"):
		_run_colour_restart(args)
		return
	if args.has("--sprint-restart-writer") or args.has("--sprint-restart-reader") or args.has("--sprint-reset-reader"):
		_run_sprint_restart(args)
		return
	if args.has("--interact-restart-writer") or args.has("--interact-restart-reader") or args.has("--interact-reset-reader"):
		_run_interact_restart(args)
		return
	if args.has("--settings-corrupt-writer") or args.has("--settings-corrupt-reader"):
		_run_settings_corrupt(args)
		return
	if args.has("--settings-migration-writer") or args.has("--settings-migration-reader"):
		_run_settings_migration(args)
		return
	if args.has("--fire-restart-writer") or args.has("--fire-restart-reader"):
		_run_fire_restart(args)
		return
	_run()


func _run() -> void:
	await _test_production_startup_transactions_and_reentry()
	_test_empty_corrupt_newer_and_failed_loads()
	_test_existing_missing_settings_initialization()
	_test_process_lifetime_recreation_identity()
	_restore_project_input_defaults()
	_finish()


# These opt-in modes deliberately avoid every fake used by the default suite.
# The sentinel contains unrelated fixture data only, never a settings profile.
const FIRE_RESTART_SENTINEL := "fire_restart_fixture"
var _fire_restart_game: GameFlow


func _run_fire_restart(args: PackedStringArray) -> void:
	var writer := args.has("--fire-restart-writer")
	var reader := args.has("--fire-restart-reader")
	print("FIRE_RESTART_BEGIN pid=%d argv=%s user_argv=%s" % [
		OS.get_process_id(), JSON.stringify(OS.get_cmdline_args()), JSON.stringify(args),
	])
	var private_root := ""
	for arg: String in args:
		if arg.begins_with("--fire-restart-private-root="):
			private_root = arg.trim_prefix("--fire-restart-private-root=").simplify_path()
	var isolated := private_root.is_absolute_path() and private_root != "/"
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		isolated = isolated and OS.get_environment(variable).simplify_path().begins_with(private_root + "/")
	isolated = isolated and OS.get_user_data_dir().simplify_path().begins_with(private_root + "/")
	_check(writer != reader and isolated, "exactly one restart mode and all user data are inside the explicit private root")
	if _failures.is_empty():
		print("FIRE_RESTART_STORE path=%s physical_hardware=NOT_RUN synthetic_focus=true" %
			ProjectSettings.globalize_path(Adapter.DEFAULT_STORE_PATH))
		await _fire_restart_stage(writer)
	# Release every synthetic event even on an assertion failure; never leave
	# cursor capture or paused state behind while tearing Main down.
	_fire_restart_key(KEY_F13, false)
	_fire_restart_key(KEY_F, false)
	_fire_restart_mouse(false)
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_fire_restart_game):
		_fire_restart_game.queue_free()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _failures.is_empty():
		var disk := Store.new(Adapter.DEFAULT_STORE_PATH)
		_check(bool(disk.load().accepted), "production file remains readable after Main exits")
		if _failures.is_empty():
			print("FIRE_RESTART_%s_OK pid=%d generation=%d sha256=%s assertions=%d" % [
				"WRITER" if writer else "READER", OS.get_process_id(), disk.get_generation(),
				FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH), _assertions,
			])
	_finish()


func _fire_restart_stage(writer: bool) -> void:
	# Match the existing Settings UI fixture's declared headless layout before
	# Main constructs its HUD; visibility still requires the original row check.
	root.content_scale_size = Vector2i(1280, 720)
	_check(root.content_scale_size == Vector2i(1280, 720),
		"restart fixture declares the existing 1280 by 720 Settings UI viewport precondition")
	if not _failures.is_empty():
		return
	var disk := Store.new(Adapter.DEFAULT_STORE_PATH)
	var opened := disk.load()
	_check(bool(opened.accepted), "private production disk store opens")
	if not _failures.is_empty():
		return
	if writer:
		_check(disk.get_generation() == 0 and disk.get_snapshot().is_empty()
			and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH),
			"writer requires a fresh private store; no existing settings are overwritten")
		if not _failures.is_empty():
			return
		var seeded := disk.commit({FIRE_RESTART_SENTINEL: {
			"writer_pid": OS.get_process_id(), "unrelated_data": {"keep_me": "fire-restart", "progress": 42},
		}}, 0, "fire-restart-unrelated-seed")
		_check(bool(seeded.accepted), "writer seeds unrelated disk data without a settings/profile payload")
	else:
		var sentinel := disk.get_snapshot().get(FIRE_RESTART_SENTINEL, {}) as Dictionary
		_check(int(sentinel.get("writer_pid", 0)) > 0
			and int(sentinel.get("writer_pid", 0)) != OS.get_process_id(),
			"reader is a distinct real process from the writer")
	if not _failures.is_empty():
		return
	var sentinel_before := disk.get_snapshot().get(FIRE_RESTART_SENTINEL, {}) as Dictionary
	var game := MAIN_SCENE.instantiate() as GameFlow
	_fire_restart_game = game
	# No configure_runtime_settings_persistence: ordinary Main owns its ordinary
	# UserDataFilesystem, store, adapter and user:// path in this fresh process.
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var report := game.get_runtime_settings_persistence_report()
	_check(not bool(report.injected_authority) and report.identity_scope == &"process_lifetime"
		and int(report.load_attempt_count) == 1 and bool(report.load_status.accepted)
		and bool(report.load_before_first_apply)
		and (writer or report.load_status.reason == &"loaded"),
		"normal Main loads one real production authority before applying settings")
	if not _failures.is_empty():
		return
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	_check(hud != null and not game.get_flyable_ships().is_empty(), "real Main provides HUD and production fleet")
	if not _failures.is_empty():
		return
	hud.set_paused(true)
	hud._show_settings_page()
	await process_frame
	await process_frame
	var buttons := hud.get("_binding_buttons") as Dictionary
	var fire_button := buttons.get(&"fire") as Button
	_check(fire_button != null and fire_button.is_visible_in_tree(), "Fire binding row is on the visible Settings page")
	if not _failures.is_empty():
		return
	fire_button.grab_focus()
	await process_frame
	await process_frame
	var scroll := (hud.get("_settings_page") as Control).find_child("SettingsScroll", true, false) as ScrollContainer
	var focus_owner := root.gui_get_focus_owner()
	print("FIRE_RESTART_LAYOUT viewport=%s window_size=%s content_scale_size=%s focus_owner=%s fire_rect=%s scroll_rect=%s" % [
		str(root.get_visible_rect()), str(root.size), str(root.content_scale_size),
		str(focus_owner.get_path()) if focus_owner != null else "NONE",
		str(fire_button.get_global_rect()), str(scroll.get_global_rect()) if scroll != null else "MISSING",
	])
	_check(scroll != null and scroll.get_global_rect().intersects(fire_button.get_global_rect()),
		"focused Fire row is scrolled into the visible Settings viewport")
	var expected_pads := _fire_restart_gamepads(game.get_runtime_settings().get_project_input_binding_defaults())
	_check(expected_pads != "[]", "authored Fire gamepad bindings provide a nonempty preservation witness")
	if not _failures.is_empty():
		return
	if writer:
		_check(_input_map_has_key(&"fire", KEY_F) and not _input_map_has_key(&"fire", KEY_F13),
			"writer begins with the authored former keyboard binding")
		if not _failures.is_empty():
			return
		_check(hud.begin_input_binding_capture(&"fire"), "visible Fire row enters ordinary raw-event capture")
		if not _failures.is_empty():
			return
		_fire_restart_key(KEY_F13, true)
		await process_frame
		_fire_restart_key(KEY_F13, false)
		await process_frame
	_check(fire_button.text.contains("F13") and _input_map_has_key(&"fire", KEY_F13)
		and not _input_map_has_key(&"fire", KEY_F)
		and _fire_restart_gamepads(game.get_runtime_settings().get_input_binding_profile()) == expected_pads,
		"visible Fire row, InputMap and retained gamepad bindings agree on F13")
	if not _failures.is_empty():
		return
	if writer:
		var save := hud.find_child("SettingsSaveButton", true, false) as Button
		_check(save != null and save.is_visible_in_tree(), "ordinary Apply + Save button is available")
		if not _failures.is_empty():
			return
		var saves_before := int(game.get_runtime_settings_persistence_report().save_success_count)
		save.pressed.emit()
		var saved := game.get_runtime_settings_persistence_report()
		_check(int(saved.save_success_count) == saves_before + 1
			and bool(saved.last_save_status.accepted) and not bool(saved.unsaved_changes),
			"ordinary production Apply + Save commits the captured binding")
	else:
		hud.set_paused(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var source := game.get_flyable_ships()[0].get_local_input_source()
		# Headless has no native focused Window. Deliver the existing lifecycle
		# notification; do not mutate a focus field or replace its Input provider.
		source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		var audit := source.get_input_integration_audit()
		_check(bool(audit.production_input_profile_active)
			and audit.production_input_strength_domain == &"input_map_resolved"
			and source.get_input_binding_profile().to_dictionary()
				== game.get_runtime_settings().get_input_binding_profile().to_dictionary(),
			"retained production local source samples the normally loaded profile through InputMap")
		if not _failures.is_empty():
			return
		# Observe the production sampler directly: no boarding, authority override,
		# source enabling, command-provider injection or combat claim is needed.
		if not _fire_restart_sample(source, false, "released baseline"):
			return
		_fire_restart_key(KEY_F13, true)
		if not _fire_restart_sample(source, true, "raw F13 press"):
			return
		_fire_restart_key(KEY_F13, false)
		if not _fire_restart_sample(source, false, "raw F13 release"):
			return
		_fire_restart_key(KEY_F, true)
		if not _fire_restart_sample(source, false, "former F press"):
			return
		_fire_restart_key(KEY_F, false)
		_fire_restart_mouse(true)
		if not _fire_restart_sample(source, false, "former left-mouse press"):
			return
		_fire_restart_mouse(false)
		if not _fire_restart_sample(source, false, "all former controls released"):
			return
	if not _failures.is_empty():
		return
	var verified := Store.new(Adapter.DEFAULT_STORE_PATH)
	_check(bool(verified.load().accepted)
		and verified.get_snapshot().get(FIRE_RESTART_SENTINEL, {}) == sentinel_before,
		"normal startup and settings save preserve exact unrelated seeded disk data")


# Sprint option qualification: three separate real-file processes; natural
# Player physics and synthetic raw S/Shift only, never physical-device proof.
# COMFORT-COLOUR: opt-in distinct-process qualification of the existing runtime.
# No settings/pose/provider seeding; only the unrelated writer sentinel is seeded.
const COLOUR_RESTART_SENTINEL := "colour_restart_fixture"


func _run_colour_restart(args: PackedStringArray) -> void:
	var modes := ["--colour-restart-writer", "--colour-restart-reader", "--colour-reset-reader"]
	var selected := PackedStringArray()
	var private_root := ""
	var root_count := 0
	var other_mode := false
	for arg: String in args:
		if arg in modes:
			selected.append(arg)
		elif arg.begins_with("--colour-restart-private-root="):
			root_count += 1
			private_root = arg.trim_prefix("--colour-restart-private-root=").simplify_path()
		elif arg.begins_with("--colour-") or arg.begins_with("--sprint-") or arg.begins_with("--interact-") or arg.begins_with("--fire-restart-") or arg.begins_with("--settings-migration-") or arg.begins_with("--settings-corrupt-"):
			other_mode = true
	var isolated := private_root.is_absolute_path() and private_root != "/"
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		isolated = isolated and OS.get_environment(variable).simplify_path().begins_with(private_root + "/")
	isolated = isolated and OS.get_user_data_dir().simplify_path().begins_with(private_root + "/")
	print("COLOUR_RESTART_LAUNCH ", JSON.stringify({"selected": selected, "private_root": private_root,
		"isolated": isolated, "other_mode": other_mode, "pid": OS.get_process_id(),
		"audio_driver": AudioServer.get_driver_name(), "display_driver": DisplayServer.get_name(),
		"user_data_dir": OS.get_user_data_dir(), "engine_argv": OS.get_cmdline_args(), "user_argv": args}))
	if _migration_check(selected.size() == 1 and root_count == 1 and not other_mode and isolated
			and AudioServer.get_driver_name() == "Dummy" and DisplayServer.get_name() == "headless",
			"one exclusive Colour worker owns actual Dummy/headless and explicit private user data"):
		await _colour_restart_stage(selected[0])
	if _interact_exit_requested:
		return
	_sprint_release_keys()
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_interact_restart_game):
		_interact_restart_game.queue_free()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_finish()


func _colour_restart_stage(mode: String) -> void:
	var writer := mode == "--colour-restart-writer"
	var reset_reader := mode == "--colour-reset-reader"
	root.content_scale_size = Vector2i(1280, 720)
	var disk := Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(disk.load().accepted), "Colour private production store opens"):
		return
	if writer:
		if not _migration_check(disk.get_generation() == 0 and disk.get_snapshot().is_empty()
				and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH), "Colour writer requires fresh unseeded settings"):
			return
		if not _migration_check(bool(disk.commit({COLOUR_RESTART_SENTINEL: {
				"writer_pid": OS.get_process_id(), "unrelated_data": {"keep_me": "colour-restart", "progress": 42},
			}}, 0, "colour-restart-unrelated-seed").accepted), "Colour seeds unrelated sentinel only"):
			return
	var sentinel: Dictionary = disk.get_snapshot().get(COLOUR_RESTART_SENTINEL, {})
	if not _migration_check(int(sentinel.get("writer_pid", 0)) > 0
			and (writer or int(sentinel.writer_pid) != OS.get_process_id()), "Colour reader has a distinct writer PID witness"):
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	_interact_restart_game = game
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var report := game.get_runtime_settings_persistence_report()
	if not _migration_check(not bool(report.injected_authority) and report.identity_scope == &"process_lifetime"
			and int(report.load_attempt_count) == 1 and bool(report.load_status.accepted)
			and bool(report.load_before_first_apply) and (writer or report.load_status.reason == &"loaded"),
			"Colour normal Main loads real disk authority once before first apply"):
		return
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	if not _migration_check(hud != null and is_instance_valid(game.player), "Colour actual Main owns HUD and Player"):
		return
	var defaults := Settings.new().to_dictionary()
	var expected := defaults.duplicate(true)
	var expected_index := 0 if writer or reset_reader else 3
	if expected_index == 3:
		expected.colorblind_palette = Settings.ColorblindPalette.TRITANOPIA
	if not _migration_check(Settings.ColorblindPalette.TRITANOPIA == 3 and Settings.ColorblindPalette.NONE == 0
			and game.get_runtime_settings().to_dictionary() == expected,
			"cold Colour full settings preserve every authored binding and unrelated option"):
		return
	hud.set_paused(true)
	hud._show_settings_page()
	await process_frame
	var control := hud.find_child("ColorblindPaletteControl", true, false) as OptionButton
	if not await _interact_visible_button(hud, control, "Colour-vision preset row"):
		return
	if not _migration_check(control.item_count == 4 and control.get_item_text(3) == "Tritanopia"
			and control.get_item_text(0) == "Off" and control.selected == expected_index,
			"cold visible Colour OptionButton agrees with exact authored preset"):
		return
	if writer:
		control.select(3)
		control.item_selected.emit(3)
		await process_frame
		expected.colorblind_palette = Settings.ColorblindPalette.TRITANOPIA
		if not _migration_check(game.get_runtime_settings().to_dictionary() == expected and control.selected == 3,
				"visible Tritanopia callback changes only the colour preset") or not await _interact_save(game, hud, "Tritanopia colour preset"):
			return
	var palette_id: StringName = &"none" if reset_reader else &"tritanopia"
	if not _colour_palette_state(game, hud, palette_id, "saved writer or cold reader"):
		return
	hud.set_paused(false)
	var begin := hud.find_child("IntroBeginShiftButton", true, false) as Button
	if not _migration_check(begin != null and begin.is_visible_in_tree() and not begin.disabled,
			"Colour normal Begin Shift is visible enabled"):
		return
	var original_player := game.player
	begin.pressed.emit()
	var deadline := Time.get_ticks_msec() + 5000
	while (game.phase != GameFlow.Phase.APPROACH_SHIP or not original_player.is_on_floor()) and Time.get_ticks_msec() < deadline:
		await physics_frame
		await process_frame
	if not _migration_check(game.phase == GameFlow.Phase.APPROACH_SHIP and game.player == original_player
			and original_player.is_on_floor() and original_player.is_control_enabled() and not original_player.is_seated(),
			"Colour normal Begin admits the same naturally supported on-foot Player"):
		return
	if not await _colour_walk(game, hud, palette_id):
		return
	if not writer and not reset_reader:
		hud.set_paused(true)
		hud._show_settings_page()
		await process_frame
		var reset := hud.find_child("SettingsResetButton", true, false) as Button
		if not await _interact_visible_button(hud, reset, "Colour Reset Defaults"):
			return
		reset.pressed.emit()
		await process_frame
		var confirm := hud.find_child("ConfirmSettingsResetButton", true, false) as Button
		if confirm != null and confirm.is_visible_in_tree():
			if not await _interact_visible_button(hud, confirm, "Confirm Colour Reset Defaults"):
				return
			confirm.pressed.emit()
			await process_frame
		expected = defaults.duplicate(true)
		if not _migration_check(game.get_runtime_settings().to_dictionary() == expected and control.selected == 0,
				"ordinary Reset Defaults restores exact full authored settings and Off") or not await _interact_save(game, hud, "Colour reset"):
			return
		hud.set_paused(false)
		await physics_frame
		await process_frame
		if not _colour_palette_state(game, hud, &"none", "after normal Reset Defaults and Save") or not _colour_live_cue(hud):
			return
	var verified := Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(verified.load().accepted) and verified.get_loaded_source() == &"primary"
			and verified.get_snapshot().get(COLOUR_RESTART_SENTINEL, {}) == sentinel
			and game.get_runtime_settings().to_dictionary() == expected
			and _migration_equal(verified.get_snapshot().get(Adapter.SETTINGS_PAYLOAD_KEY, {}), game.get_runtime_settings().to_user_data_payload()),
			"Colour actual primary retains exact sentinel and complete expected settings including all bindings"):
		return
	_sprint_release_keys()
	hud.set_paused(true)
	var exit_button := hud.find_child("ExitButton", true, false) as Button
	if not _migration_check(exit_button != null and exit_button.is_visible_in_tree() and not exit_button.disabled,
			"Colour ordinary HUD Exit is visible enabled"):
		return
	exit_button.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var marker := "COLOUR_RESET_READER_OK" if reset_reader else ("COLOUR_RESTART_WRITER_OK" if writer else "COLOUR_RESTART_READER_OK")
	print("%s pid=%d generation=%d sha256=%s assertions=%d synthetic_raw_events=true physical_input=NOT_RUN rendered_readability=NOT_RUN" % [
		marker, OS.get_process_id(), verified.get_generation(), FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH), _assertions])
	_interact_exit_requested = true
	exit_button.pressed.emit()


func _colour_palette_state(game: GameFlow, hud: GameHUD, palette_id: StringName, stage: String) -> bool:
	var palette: Dictionary = GameHUD.PaletteType.get_palette(palette_id, false)
	var minimap := hud.get("_minimap") as Minimap
	var good := game.get_runtime_settings().get_colorblind_palette_id() == palette_id 		and hud.get_hud_palette_id() == palette_id and not hud.is_high_contrast_hud() 		and minimap != null and (hud.get("_palette") as Dictionary) == palette
	if good:
		for role: String in ["nominal", "caution", "danger", "muted"]:
			good = good and minimap.get("_" + role + "_color") == palette[StringName(role)]
	print("COLOUR_RESTART_PALETTE ", JSON.stringify({"stage": stage, "pid": OS.get_process_id(),
		"settings_id": str(game.get_runtime_settings().get_colorblind_palette_id()), "hud_id": str(hud.get_hud_palette_id()),
		"enum": game.get_runtime_settings().colorblind_palette, "minimap_id": minimap.get_instance_id() if minimap != null else 0,
		"same_semantic_colours": good, "high_contrast": hud.is_high_contrast_hud()}))
	return _migration_check(good, stage + ": real settings/HUD/minimap retain the exact semantic palette")


func _colour_live_cue(hud: GameHUD) -> bool:
	var mode := hud.get("_mode_label") as Label
	var audit := hud.get_minimap_report()
	print("COLOUR_RESTART_CUE ", JSON.stringify({"pid": OS.get_process_id(),
		"text": mode.text if mode != null else "MISSING", "minimap": audit}))
	return _migration_check(mode != null and mode.is_visible_in_tree() and mode.text.begins_with("ON FOOT")
		and mode.get_theme_color("font_color") == (hud.get("_palette") as Dictionary)[&"nominal"]
		and bool(audit.get("valid", false)) and bool(audit.get("has_snapshot", false))
		and bool(audit.get("visible_in_tree", false)) and bool(audit.get("player_visible", false))
		and bool(audit.get("contact_state_has_shape_cue", false))
		and (audit.get("contact_glyphs", {}) as Dictionary).get("friendly") == &"circle_cross"
		and (audit.get("contact_glyphs", {}) as Dictionary).get("hostile") == &"diamond",
		"actual visible ON FOOT text and live minimap retain their text/shape discriminators")


func _colour_walk(game: GameFlow, hud: GameHUD, palette_id: StringName) -> bool:
	var original_player := game.player
	_sprint_origin = original_player.global_position
	_sprint_release_keys()
	_fire_restart_key(KEY_S, true)
	Input.flush_buffered_events()
	for tick in 12:
		await physics_frame
		await process_frame
		if not _migration_check(game.player == original_player and _sprint_state(game)
				and Input.is_action_pressed(&"move_back"), "Colour raw S walk retains supported original Player tick %d" % tick):
			_sprint_release_keys()
			return false
	_sprint_release_keys()
	var distance := original_player.global_position.distance_to(_sprint_origin)
	if not _migration_check(distance >= 0.25 and distance <= 3.0, "Colour raw S produces actual bounded on-foot movement"):
		return false
	for tick in 30:
		await physics_frame
		await process_frame
		if not _migration_check(game.player == original_player and _sprint_state(game), "Colour released walk keeps natural support"):
			return false
		if original_player.velocity.slide(Vector3.UP).length() <= 0.05:
			break
	if not _migration_check(not Input.is_action_pressed(&"move_back") and original_player.velocity.slide(Vector3.UP).length() <= 0.05,
			"Colour raw S release returns to neutral without a provider or manual physics step"):
		return false
	return _colour_palette_state(game, hud, palette_id, "after real raw-input walk") and _colour_live_cue(hud)


const SPRINT_RESTART_SENTINEL := "sprint_restart_fixture"
var _sprint_origin := Vector3.ZERO


func _run_sprint_restart(args: PackedStringArray) -> void:
	var selected := PackedStringArray()
	for mode: String in ["--sprint-restart-writer", "--sprint-restart-reader", "--sprint-reset-reader"]:
		if args.has(mode):
			selected.append(mode)
	var private_root := ""
	var other_mode := false
	for arg: String in args:
		if arg.begins_with("--sprint-restart-private-root="):
			private_root = arg.trim_prefix("--sprint-restart-private-root=").simplify_path()
		if arg.begins_with("--interact-") or arg.begins_with("--fire-restart-") or arg.begins_with("--settings-migration-") or arg.begins_with("--settings-corrupt-"):
			other_mode = true
	var isolated := private_root.is_absolute_path() and private_root != "/"
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		isolated = isolated and OS.get_environment(variable).simplify_path().begins_with(private_root + "/")
	isolated = isolated and OS.get_user_data_dir().simplify_path().begins_with(private_root + "/")
	print("SPRINT_RESTART_LAUNCH ", JSON.stringify({"selected": selected, "private_root": private_root,
		"isolated": isolated, "other_mode": other_mode, "pid": OS.get_process_id(),
		"audio_driver": AudioServer.get_driver_name(), "display_driver": DisplayServer.get_name(),
		"user_data_dir": OS.get_user_data_dir(), "engine_argv": OS.get_cmdline_args(), "user_argv": args}))
	if _migration_check(selected.size() == 1 and not other_mode and isolated
			and AudioServer.get_driver_name() == "Dummy" and DisplayServer.get_name() == "headless",
			"one exclusive Sprint worker owns actual Dummy/headless and private user data"):
		await _sprint_restart_stage(selected[0])
	if _interact_exit_requested:
		return
	_sprint_release_keys()
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_interact_restart_game):
		_interact_restart_game.queue_free()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_finish()


func _sprint_restart_stage(mode: String) -> void:
	var writer := mode == "--sprint-restart-writer"
	var reset_reader := mode == "--sprint-reset-reader"
	root.content_scale_size = Vector2i(1280, 720)
	var disk := Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(disk.load().accepted), "Sprint private production store opens"):
		return
	if writer:
		if not _migration_check(disk.get_generation() == 0 and disk.get_snapshot().is_empty()
				and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH), "Sprint writer requires fresh unseeded settings"):
			return
		if not _migration_check(bool(disk.commit({SPRINT_RESTART_SENTINEL: {
				"writer_pid": OS.get_process_id(), "unrelated_data": {"keep_me": "sprint-restart", "progress": 42},
			}}, 0, "sprint-restart-unrelated-seed").accepted), "Sprint seeds unrelated sentinel only"):
			return
	var sentinel: Dictionary = disk.get_snapshot().get(SPRINT_RESTART_SENTINEL, {})
	if not _migration_check(int(sentinel.get("writer_pid", 0)) > 0
			and (writer or int(sentinel.writer_pid) != OS.get_process_id()), "Sprint reader has a distinct writer PID witness"):
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	_interact_restart_game = game
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var report := game.get_runtime_settings_persistence_report()
	if not _migration_check(not bool(report.injected_authority) and report.identity_scope == &"process_lifetime"
			and int(report.load_attempt_count) == 1 and bool(report.load_status.accepted)
			and bool(report.load_before_first_apply) and (writer or report.load_status.reason == &"loaded"),
			"Sprint normal Main loads real authority once before first apply"):
		return
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	if not _migration_check(hud != null and is_instance_valid(game.player), "Sprint actual Main owns HUD and Player"):
		return
	var defaults := Settings.new().to_dictionary()
	var expected := defaults.duplicate(true)
	if not writer and not reset_reader:
		((expected.input_binding_profile as Dictionary).action_options as Dictionary)[&"sprint_boost"]["hold_mode"] = Profile.TOGGLE
	if not _migration_check(game.get_runtime_settings().to_dictionary() == expected, "cold Sprint full settings preserve every authored binding and unrelated option"):
		return
	var begin := hud.find_child("IntroBeginShiftButton", true, false) as Button
	if not _migration_check(begin != null and begin.is_visible_in_tree() and not begin.disabled, "Sprint normal Begin Shift is visible enabled"):
		return
	begin.pressed.emit()
	var deadline := Time.get_ticks_msec() + 5000
	while game.phase != GameFlow.Phase.APPROACH_SHIP and Time.get_ticks_msec() < deadline:
		await process_frame
	await physics_frame
	await process_frame
	_sprint_origin = game.player.global_position
	if not _migration_check(game.phase == GameFlow.Phase.APPROACH_SHIP
			and _sprint_origin.distance_to(Vector3(-8.5, 0.18, 11.0)) < 1.0
			and is_equal_approx(game.player.sprint_speed, 9.2) and is_equal_approx(game.player.walk_speed, 5.8)
			and _sprint_state(game), "Sprint normal Begin admits supported original PlayerSpawn route"):
		return
	hud.set_paused(true)
	hud._show_settings_page()
	await process_frame
	var control := hud.find_child("SprintBoostHoldModeControl", true, false) as OptionButton
	if not await _interact_visible_button(hud, control, "Sprint / boost hold-mode row"):
		return
	if not _migration_check(control.selected == (0 if writer or reset_reader else 1), "cold visible Sprint mode agrees with expected HOLD/TOGGLE"):
		return
	if writer:
		control.select(1)
		control.item_selected.emit(1)
		await process_frame
		((expected.input_binding_profile as Dictionary).action_options as Dictionary)[&"sprint_boost"]["hold_mode"] = Profile.TOGGLE
		if not _migration_check(game.get_runtime_settings().to_dictionary() == expected and control.selected == 1,
				"visible Sprint callback changes only HOLD to TOGGLE") or not await _interact_save(game, hud, "Sprint option"):
			return
	else:
		hud.set_paused(false)
		if not await _sprint_consumer(game, not reset_reader):
			return
		if not reset_reader:
			hud.set_paused(true)
			hud._show_settings_page()
			await process_frame
			var reset := hud.find_child("SettingsResetButton", true, false) as Button
			if not await _interact_visible_button(hud, reset, "Reset Defaults"):
				return
			reset.pressed.emit()
			await process_frame
			var confirm := hud.find_child("ConfirmSettingsResetButton", true, false) as Button
			if confirm != null and confirm.is_visible_in_tree():
				if not await _interact_visible_button(hud, confirm, "Confirm Reset Defaults"):
					return
				confirm.pressed.emit()
				await process_frame
			expected = defaults.duplicate(true)
			if not _migration_check(game.get_runtime_settings().to_dictionary() == expected and control.selected == 0,
					"ordinary Reset Defaults restores exact authored full settings and HOLD") or not await _interact_save(game, hud, "Sprint reset"):
				return
	var verified := Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(verified.load().accepted) and verified.get_snapshot().get(SPRINT_RESTART_SENTINEL, {}) == sentinel
			and game.get_runtime_settings().to_dictionary() == expected,
			"Sprint saves preserve exact unrelated sentinel and complete expected settings"):
		return
	_sprint_release_keys()
	hud.set_paused(true)
	var exit_button := hud.find_child("ExitButton", true, false) as Button
	if not _migration_check(exit_button != null and exit_button.is_visible_in_tree() and not exit_button.disabled,
			"Sprint ordinary HUD Exit is visible enabled"):
		return
	exit_button.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var marker := "SPRINT_RESET_READER_OK" if reset_reader else ("SPRINT_RESTART_WRITER_OK" if writer else "SPRINT_RESTART_READER_OK")
	print("%s pid=%d generation=%d sha256=%s assertions=%d synthetic_raw_events=true physical_input=NOT_RUN" % [
		marker, OS.get_process_id(), verified.get_generation(), FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH), _assertions])
	_interact_exit_requested = true
	exit_button.pressed.emit()


func _sprint_release_keys() -> void:
	for code: Key in [KEY_S, KEY_W, KEY_SHIFT]:
		_fire_restart_key(code, false)
	Input.flush_buffered_events()


func _sprint_state(game: GameFlow) -> bool:
	return game.player.is_on_floor() and game.player.is_control_enabled() and not game.player.is_seated() \
		and not paused and game.player.global_position.distance_to(_sprint_origin) <= 5.0


func _sprint_wait_speed(game: GameFlow, speed: float, stage: String, retain_next_tick: bool = false) -> bool:
	var started_physics_frame := Engine.get_physics_frames()
	for tick in 30:
		await physics_frame
		await process_frame
		var elapsed_physics_frames := Engine.get_physics_frames() - started_physics_frame
		var player := game.player
		var actual := player.velocity.slide(Vector3.UP).length()
		print("SPRINT_RESTART_OBSERVATION ", JSON.stringify({"stage": stage, "sample": tick,
			"pid": OS.get_process_id(), "physics_frame": Engine.get_physics_frames(), "ticks_usec": Time.get_ticks_usec(),
			"elapsed_physics_frames": elapsed_physics_frames,
			"position": str(player.global_position), "velocity": str(player.velocity), "speed": actual, "expected_speed": speed,
			"distance_from_start": player.global_position.distance_to(_sprint_origin), "floor": player.is_on_floor(),
			"control": player.is_control_enabled(), "seated": player.is_seated(), "paused": paused,
			"move_back": Input.is_action_pressed(&"move_back"), "sprint_pressed": Input.is_action_pressed(&"sprint_boost"),
			"sprint_just_pressed": Input.is_action_just_pressed(&"sprint_boost"),
			"options": game.get_runtime_settings().get_input_binding_profile().get_action_options(&"sprint_boost")}))
		if not _migration_check(_sprint_state(game), stage + " preserves supported normal on-foot route within five metres"):
			return false
		if not _migration_check(elapsed_physics_frames <= 30, stage + " observes at most thirty actual scheduled physics steps"):
			return false
		if absf(actual - speed) < 0.01:
			return _migration_check(true, stage + " reaches authored speed within thirty scheduled physics ticks")
		if retain_next_tick:
			return _migration_check(false, stage + " must retain authored sprint speed on this scheduled tick")
	return _migration_check(false, stage + " fails authored speed within thirty scheduled physics ticks")


func _sprint_consumer(game: GameFlow, toggle: bool) -> bool:
	_sprint_release_keys()
	await physics_frame
	await process_frame
	await physics_frame
	_fire_restart_key(KEY_S, true)
	_fire_restart_key(KEY_SHIFT, true)
	Input.flush_buffered_events()
	if not await _sprint_wait_speed(game, game.player.sprint_speed, "fresh Shift press"):
		return false
	_fire_restart_key(KEY_SHIFT, false)
	Input.flush_buffered_events()
	if toggle:
		for tick in 3:
			if not await _sprint_wait_speed(game, game.player.sprint_speed, "TOGGLE release retention %d" % tick, true):
				return false
		_fire_restart_key(KEY_SHIFT, true)
		Input.flush_buffered_events()
		if not await _sprint_wait_speed(game, game.player.walk_speed, "second fresh Shift press"):
			return false
		_fire_restart_key(KEY_SHIFT, false)
		Input.flush_buffered_events()
	else:
		if not await _sprint_wait_speed(game, game.player.walk_speed, "HOLD release"):
			return false
	_sprint_release_keys()
	return await _sprint_wait_speed(game, 0.0, "neutral stop")


# Opt-in sequential Interact qualification uses the same fresh private XDG
# root, Dummy audio and headless display. Synthetic raw events are consumed by
# actual Player physics, never physical input.
const INTERACT_RESTART_SENTINEL := "interact_restart_fixture"
var _interact_restart_game: GameFlow
var _interact_requests := 0
var _interact_exit_requested := false


func _run_interact_restart(args: PackedStringArray) -> void:
	var modes := ["--interact-restart-writer", "--interact-restart-reader", "--interact-reset-reader"]
	var selected := PackedStringArray()
	for mode: String in modes:
		if args.has(mode):
			selected.append(mode)
	var private_root := ""
	for arg: String in args:
		if arg.begins_with("--interact-restart-private-root="):
			private_root = arg.trim_prefix("--interact-restart-private-root=").simplify_path()
	var isolated := private_root.is_absolute_path() and private_root != "/"
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		isolated = isolated and OS.get_environment(variable).simplify_path().begins_with(private_root + "/")
	isolated = isolated and OS.get_user_data_dir().simplify_path().begins_with(private_root + "/")
	var other_mode := false
	for arg: String in args:
		if arg.begins_with("--sprint-") or arg.begins_with("--fire-restart-") or arg.begins_with("--settings-migration-") or arg.begins_with("--settings-corrupt-"):
			other_mode = true
	# As in the existing migration worker, Godot consumes driver switches before
	# get_cmdline_args(). Check actual backends; the wrapper records explicit flags.
	var audio_driver := AudioServer.get_driver_name()
	var display_driver := DisplayServer.get_name()
	print("INTERACT_RESTART_LAUNCH ", JSON.stringify({"selected": selected,
		"other_mode": other_mode, "isolated": isolated, "private_root": private_root,
		"user_data_dir": OS.get_user_data_dir(), "audio_driver": audio_driver,
		"display_driver": display_driver, "engine_argv": OS.get_cmdline_args(),
		"user_argv": args}))
	_check(selected.size() == 1 and not other_mode and isolated
		and audio_driver == "Dummy" and display_driver == "headless",
		"one exclusive Interact worker requires actual Dummy audio, headless display, and isolated user data")
	print("INTERACT_RESTART_BEGIN pid=%d modes=%s path=%s synthetic_raw_events=true physical_input=NOT_RUN" % [
		OS.get_process_id(), str(selected), ProjectSettings.globalize_path(Adapter.DEFAULT_STORE_PATH)])
	if _failures.is_empty():
		await _interact_restart_stage(selected[0])
	if _interact_exit_requested:
		return
	# Successful workers exit through the real HUD intent inside the stage.
	# Any returned stage is a failure, so release all inputs before teardown.
	_interact_release_keys()
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_interact_restart_game):
		_interact_restart_game.queue_free()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_finish()


func _interact_restart_stage(mode: String) -> void:
	var writer := mode == "--interact-restart-writer"
	var reset_reader := mode == "--interact-reset-reader"
	root.content_scale_size = Vector2i(1280, 720)
	var disk := Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(disk.load().accepted), "Interact private production store opens"):
		return
	if writer:
		if not _migration_check(disk.get_generation() == 0 and disk.get_snapshot().is_empty()
				and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH), "Interact writer requires a fresh unseeded profile"):
			return
		if not _migration_check(bool(disk.commit({INTERACT_RESTART_SENTINEL: {
				"writer_pid": OS.get_process_id(), "unrelated_data": {"keep_me": "interact-restart", "progress": 42},
			}}, 0, "interact-restart-unrelated-seed").accepted), "Interact seeds unrelated data only"):
			return
	var sentinel: Dictionary = disk.get_snapshot().get(INTERACT_RESTART_SENTINEL, {})
	if not _migration_check(int(sentinel.get("writer_pid", 0)) > 0
			and (writer or int(sentinel.writer_pid) != OS.get_process_id()), "Interact reader has a distinct writer PID witness"):
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	_interact_restart_game = game
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var report := game.get_runtime_settings_persistence_report()
	if not _migration_check(not bool(report.injected_authority) and report.identity_scope == &"process_lifetime"
			and int(report.load_attempt_count) == 1 and bool(report.load_status.accepted)
			and bool(report.load_before_first_apply) and (writer or report.load_status.reason == &"loaded"),
			"Interact normal Main loads real production authority once before apply"):
		return
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	if not _migration_check(hud != null and is_instance_valid(game.player), "Interact normal Main supplies actual HUD and Player"):
		return
	hud.set_paused(true)
	hud._show_settings_page()
	await process_frame
	var buttons := hud.get("_binding_buttons") as Dictionary
	var interact := buttons.get(&"interact") as Button
	if not await _interact_visible_button(hud, interact, "Interact row"):
		return
	var defaults := game.get_runtime_settings().get_project_input_binding_defaults()
	var pads := _fire_restart_gamepads(defaults, &"interact")
	if not _migration_check(pads != "[]" and _interact_has_authored_x(), "authored Interact controller X is present"):
		return
	if writer:
		if not _interact_binding_state(game, interact, false, pads):
			return
		interact.pressed.emit()
		_fire_restart_key(KEY_F13, true)
		Input.flush_buffered_events()
		await process_frame
		_fire_restart_key(KEY_F13, false)
		Input.flush_buffered_events()
		await process_frame
	if not _interact_binding_state(game, interact, not reset_reader, pads):
		return
	if writer:
		var accepted: Dictionary = game.get_runtime_settings().get_input_binding_profile().to_dictionary().duplicate(true)
		var accepted_map := _interact_input_map_snapshot()
		var jump := buttons.get(&"jump") as Button
		if not await _interact_visible_button(hud, jump, "Jump conflict row"):
			return
		jump.pressed.emit()
		_fire_restart_key(KEY_F13, true)
		Input.flush_buffered_events()
		await process_frame
		_fire_restart_key(KEY_F13, false)
		Input.flush_buffered_events()
		await process_frame
		var cancel := hud.find_child("InputBindingConflictCancelButton", true, false) as Button
		if not _migration_check(bool(hud.get_input_binding_report().has_pending_conflict), "Jump F13 presents the Interact conflict"):
			return
		if not await _interact_visible_button(hud, cancel, "conflict Cancel"):
			return
		cancel.pressed.emit()
		await process_frame
		if not _migration_check(not bool(hud.get_input_binding_report().has_pending_conflict)
				and game.get_runtime_settings().get_input_binding_profile().to_dictionary() == accepted
				and _interact_input_map_snapshot() == accepted_map and _input_map_has_key(&"jump", KEY_SPACE)
				and not _input_map_has_key(&"jump", KEY_F13), "Cancel preserves the full accepted profile/InputMap and authored Jump Space"):
			return
		if not await _interact_save(game, hud):
			return
	# Leave Settings and trigger the ordinary intro action; its tween emits the
	# actual start intent and GameFlow enables the existing on-foot Player.
	hud.set_paused(false)
	var begin := hud.find_child("IntroBeginShiftButton", true, false) as Button
	if not _migration_check(begin != null and begin.is_visible_in_tree() and not begin.disabled, "ordinary Begin Shift is visible and enabled"):
		return
	begin.pressed.emit()
	var deadline := Time.get_ticks_msec() + 5000
	while game.phase != GameFlow.Phase.APPROACH_SHIP and Time.get_ticks_msec() < deadline:
		await process_frame
	await physics_frame
	await process_frame
	if not _migration_check(game.phase == GameFlow.Phase.APPROACH_SHIP and not paused
			and game.player.is_control_enabled() and not game.player.is_seated() and game.player.is_on_floor(),
			"ordinary Begin Shift admits the actual supported on-foot Player"):
		return
	game.player.interact_requested.connect(func() -> void: _interact_requests += 1)
	if not await _interact_consumer(game, not reset_reader):
		return
	if not writer and not reset_reader:
		hud.set_paused(true)
		hud._show_settings_page()
		await process_frame
		var reset := hud.find_child("InteractBindingResetButton", true, false) as Button
		if not await _interact_visible_button(hud, reset, "per-action Interact Reset"):
			return
		reset.pressed.emit()
		await process_frame
		if not _interact_binding_state(game, interact, false, pads) or not await _interact_save(game, hud):
			return
		hud.set_paused(false)
		if not await _interact_consumer(game, false):
			return
	var verified := Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(verified.load().accepted)
			and verified.get_snapshot().get(INTERACT_RESTART_SENTINEL, {}) == sentinel,
			"Interact normal startup and saves preserve the exact unrelated sentinel"):
		return
	_interact_release_keys()
	hud.set_paused(true)
	var exit_button := hud.find_child("ExitButton", true, false) as Button
	if not _migration_check(exit_button != null and exit_button.is_visible_in_tree() and not exit_button.disabled,
			"ordinary HUD Exit button is visible and enabled"):
		return
	exit_button.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var marker := "INTERACT_RESET_READER_OK" if reset_reader else ("INTERACT_RESTART_WRITER_OK" if writer else "INTERACT_RESTART_READER_OK")
	print("%s pid=%d generation=%d sha256=%s assertions=%d synthetic_raw_events=true physical_input=NOT_RUN" % [
		marker, OS.get_process_id(), verified.get_generation(), FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH), _assertions])
	# The wrapper requires actual OS exit 0 and the durable orderly marker too.
	_interact_exit_requested = true
	exit_button.pressed.emit()


func _interact_visible_button(hud: GameHUD, button: Button, label: String) -> bool:
	if not _migration_check(button != null and button.is_visible_in_tree() and not button.disabled
			and button.focus_mode != Control.FOCUS_NONE, label + " is visible enabled and focusable"):
		return false
	button.grab_focus()
	await process_frame
	await process_frame
	var scroll := (hud.get("_settings_page") as Control).find_child("SettingsScroll", true, false) as ScrollContainer
	var visible_rect := root.get_visible_rect()
	if scroll != null and scroll.is_ancestor_of(button):
		visible_rect = scroll.get_global_rect()
	return _migration_check(button.has_focus() and visible_rect.intersects(button.get_global_rect()),
		label + " is focused inside its visible Settings viewport")


func _interact_has_authored_x() -> bool:
	var pads := 0
	var has_x := false
	for event: InputEvent in InputMap.action_get_events(&"interact"):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			pads += 1
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
			has_x = true
	return has_x and pads == 1


func _interact_binding_state(game: GameFlow, button: Button, remapped: bool, pads: String) -> bool:
	return _migration_check(button.text.contains("F13" if remapped else "E")
		and _input_map_has_key(&"interact", KEY_F13) == remapped
		and _input_map_has_key(&"interact", KEY_E) != remapped and _interact_has_authored_x()
		and _fire_restart_gamepads(game.get_runtime_settings().get_input_binding_profile(), &"interact") == pads,
		"Interact visible label/InputMap/profile agree on %s with exact authored controller X" % ("F13" if remapped else "E"))


func _interact_input_map_snapshot() -> Dictionary:
	var result := {}
	for action: StringName in InputMap.get_actions():
		result[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": var_to_str(InputMap.action_get_events(action))}
	return result


func _interact_save(game: GameFlow, hud: GameHUD, subject: String = "Interact binding") -> bool:
	var save := hud.find_child("SettingsSaveButton", true, false) as Button
	if not await _interact_visible_button(hud, save, "Apply + Save"):
		return false
	var before := int(game.get_runtime_settings_persistence_report().save_success_count)
	save.pressed.emit()
	var report := game.get_runtime_settings_persistence_report()
	return _migration_check(int(report.save_success_count) == before + 1 and bool(report.last_save_status.accepted)
		and not bool(report.unsaved_changes), "ordinary Apply + Save commits the " + subject)


func _interact_release_keys() -> void:
	for code: Key in [KEY_E, KEY_F13, KEY_SPACE]:
		_fire_restart_key(code, false)
	Input.flush_buffered_events()


func _interact_consumer(game: GameFlow, remapped: bool) -> bool:
	for code: Key in [KEY_E, KEY_F13]:
		var before := _interact_requests
		var expected := 1 if (code == KEY_F13) == remapped else 0
		var player_properties: Dictionary = {}
		for property: Dictionary in game.player.get_property_list():
			player_properties[StringName(property.name)] = true
		var observe := func(stage: String) -> void:
			print("INTERACT_RESTART_OBSERVATION ", JSON.stringify({
				"stage": stage, "key": OS.get_keycode_string(code), "remapped": remapped,
				"pid": OS.get_process_id(), "ticks_usec": Time.get_ticks_usec(),
				"ticks_msec": Time.get_ticks_msec(), "physics_frame": Engine.get_physics_frames(),
				"pressed": Input.is_action_pressed(&"interact"),
				"just_pressed": Input.is_action_just_pressed(&"interact"),
				"counter": _interact_requests, "before": before, "delta": _interact_requests - before,
				"control_enabled": game.player.is_control_enabled(),
				"seated": game.player.is_seated(), "paused": paused,
				"handoff_blocked": game.player.get("_interact_handoff_blocked") if player_properties.has(&"_interact_handoff_blocked") else null,
				"handoff_released": game.player.get("_interact_handoff_released") if player_properties.has(&"_interact_handoff_released") else null,
			}))
		# Observe an entire next physics step after delivering the raw edge.
		await physics_frame
		observe.call("before_press")
		_fire_restart_key(code, true)
		Input.flush_buffered_events()
		observe.call("after_press")
		await physics_frame
		await process_frame
		observe.call("after_observation")
		if not _migration_check(_interact_requests == before + expected,
				"actual Player physics emits %d request for synthetic %s press" % [expected, OS.get_keycode_string(code)]):
			return false
		for held_frame: int in range(3):
			await physics_frame
			await process_frame
			if not _migration_check(_interact_requests == before + expected, "held synthetic Interact key adds no physics request"):
				return false
		await physics_frame
		observe.call("before_release")
		_fire_restart_key(code, false)
		Input.flush_buffered_events()
		observe.call("after_release")
		await process_frame
		observe.call("after_release_observation")
		if not _migration_check(_interact_requests == before + expected and game.player.is_control_enabled()
				and not game.player.is_seated() and not paused, "release adds no interaction request and the actual Player remains on foot"):
			return false
		print("INTERACT_RESTART_SAMPLE key=%s remapped=%s delta=%d physics_frame=%d" % [
			OS.get_keycode_string(code), str(remapped), _interact_requests - before, Engine.get_physics_frames()])
	return true


# SAVE-CORRUPT: run these two opt-in modes sequentially, each under the original
# 300-second external cap, with Dummy audio and isolated X11/private XDG roots.
# This qualifies fallback presentation and walking, never backup promotion.
const SETTINGS_CORRUPT_BYTES := "{corrupt"
var _corrupt_expected_artifacts: Dictionary = {}


func _run_settings_corrupt(args: PackedStringArray) -> void:
	var writer: bool = args.has("--settings-corrupt-writer")
	var reader: bool = args.has("--settings-corrupt-reader")
	var private_root: String = ""
	for arg: String in args:
		if arg.begins_with("--settings-corrupt-private-root="):
			private_root = arg.trim_prefix("--settings-corrupt-private-root=").simplify_path()
	var isolated: bool = private_root.is_absolute_path() and private_root != "/"
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		isolated = isolated and OS.get_environment(variable).simplify_path().begins_with(private_root + "/")
	isolated = isolated and OS.get_user_data_dir().simplify_path().begins_with(private_root + "/")
	print("SETTINGS_CORRUPT_LAUNCH ", JSON.stringify({"writer": writer, "reader": reader,
		"private_root": private_root, "isolated": isolated, "pid": OS.get_process_id(),
		"user_data_dir": OS.get_user_data_dir(), "audio_driver": AudioServer.get_driver_name(),
		"display_driver": DisplayServer.get_name()}))
	if _migration_check(writer != reader and isolated and AudioServer.get_driver_name() == "Dummy"
			and DisplayServer.get_name() == "X11", "corrupt owns silent isolated X11 and private user data"):
		if _migration_fixture():
			await _corrupt_stage(writer, private_root)
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused = false
	if is_instance_valid(_migration_game):
		_migration_game.queue_free()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _failures.is_empty():
		_corrupt_boundary("retired Main")
	if _failures.is_empty():
		print("SETTINGS_CORRUPT_%s_OK pid=%d primary_sha256=%s backup_sha256=%s" % [
			"WRITER" if writer else "READER", OS.get_process_id(),
			FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH),
			FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH + ".bak")])
	_finish()


func _corrupt_artifacts() -> Dictionary:
	var result: Dictionary = {}
	var directory: DirAccess = DirAccess.open(OS.get_user_data_dir())
	if directory == null:
		return {"unreadable_directory": true}
	var basename: String = Adapter.DEFAULT_STORE_PATH.get_file()
	for filename: String in directory.get_files():
		if filename.begins_with(basename):
			var path: String = OS.get_user_data_dir().path_join(filename)
			result[filename] = {"bytes_hex": FileAccess.get_file_as_bytes(path).hex_encode(),
				"mode": FileAccess.get_unix_permissions(path), "sha256": FileAccess.get_sha256(path)}
	for dirname: String in directory.get_directories():
		if dirname.begins_with(basename):
			result[dirname] = {"unexpected_directory": true}
	return result


func _corrupt_boundary(label: String) -> bool:
	var artifacts: Dictionary = _corrupt_artifacts()
	var backup_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(Adapter.DEFAULT_STORE_PATH + ".bak"))
	if not _migration_check(_migration_equal(artifacts, _corrupt_expected_artifacts)
			and not FileAccess.file_exists(Adapter.DEFAULT_STORE_PATH + ".tmp")
			and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH)
			and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH + ".tmp")
			and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH + ".bak")
			and backup_value is Dictionary, label + ": exact artifact names bytes and modes; no staged or legacy file"):
		return false
	var expected_payload: Dictionary = _migration_paid.duplicate(true)
	expected_payload[Adapter.SETTINGS_PAYLOAD_KEY] = _migration_current.duplicate(true)
	var backup: Dictionary = backup_value as Dictionary
	if not _migration_check(Store.validate_envelope(backup).is_empty() and int(backup.generation) == 1
			and _migration_equal(backup.payload, expected_payload),
			label + ": valid generation1 backup protects exact settings11 and authentic paid Race/reward"):
		return false
	print("SETTINGS_CORRUPT_BOUNDARY ", JSON.stringify({"label": label, "pid": OS.get_process_id(),
		"artifacts": artifacts}, "", true, true))
	return true


func _corrupt_stage(writer: bool, private_root: String) -> void:
	await process_frame
	root.content_scale_size = Vector2i(1280, 720)
	var handoff_path: String = private_root.path_join("settings-corrupt-writer.json")
	if writer:
		var disk: UserDataStore = Store.new(Adapter.DEFAULT_STORE_PATH)
		if not _migration_check(bool(disk.load().accepted) and disk.get_generation() == 0
				and disk.get_snapshot().is_empty() and _corrupt_artifacts().is_empty()
				and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH)
				and not FileAccess.file_exists(handoff_path), "corrupt writer requires untouched private authority"):
			return
		var seed: Dictionary = _migration_paid.duplicate(true)
		seed[Adapter.SETTINGS_PAYLOAD_KEY] = _migration_current.duplicate(true)
		if not _migration_check(bool(disk.commit(seed, 0, "settings-corrupt-good-save").accepted),
				"corrupt publishes authentic generation1 settings96 and paid namespaces"):
			return
		var successor: Dictionary = seed.duplicate(true)
		successor[Adapter.SETTINGS_PAYLOAD_KEY].values.camera_fov = 83.0
		if not _migration_check(bool(disk.commit(successor, 1, "settings-corrupt-latest-save").accepted)
				and disk.get_generation() == 2, "corrupt publishes generation2 settings83 and verified backup1"):
			return
		# From here until normal Main, never load through Store or an adapter.
		var damaged: FileAccess = FileAccess.open(Adapter.DEFAULT_STORE_PATH, FileAccess.WRITE)
		if not _migration_check(damaged != null, "corrupt opens only the owned primary"):
			return
		damaged.store_buffer(SETTINGS_CORRUPT_BYTES.to_utf8_buffer())
		damaged.flush()
		var damage_error: Error = damaged.get_error()
		damaged.close()
		if not _migration_check(damage_error == OK, "corrupt flushes exact eight-byte damaged primary"):
			return
		_corrupt_expected_artifacts = _corrupt_artifacts()
		var basename: String = Adapter.DEFAULT_STORE_PATH.get_file()
		if not _migration_check(_corrupt_expected_artifacts.size() == 2
				and _corrupt_expected_artifacts.has(basename) and _corrupt_expected_artifacts.has(basename + ".bak")
				and FileAccess.get_file_as_bytes(Adapter.DEFAULT_STORE_PATH) == SETTINGS_CORRUPT_BYTES.to_utf8_buffer()
				and FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH) == 384
				and FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH + ".bak") == 384,
				"corrupt starts with exactly primary and backup at mode0600; no recovery exists"):
			return
	else:
		var handoff_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(handoff_path))
		if not _migration_check(handoff_value is Dictionary, "corrupt reader has writer process handoff"):
			return
		var handoff: Dictionary = handoff_value as Dictionary
		if not _migration_check(int(handoff.get("writer_pid", 0)) > 0
				and int(handoff.writer_pid) != OS.get_process_id()
				and handoff.get("artifacts") is Dictionary,
				"corrupt reader is a distinct process retaining exact writer artifact handoff"):
			return
		_corrupt_expected_artifacts = (handoff.artifacts as Dictionary).duplicate(true)
	if not _corrupt_boundary("before normal Main"):
		return
	if writer:
		# This is the only permitted startup addition. Main owns its creation.
		_corrupt_expected_artifacts[Adapter.DEFAULT_STORE_PATH.get_file() + ".recovery"] = \
			(_corrupt_expected_artifacts[Adapter.DEFAULT_STORE_PATH.get_file()] as Dictionary).duplicate(true)
	_migration_game = MAIN_SCENE.instantiate() as GameFlow
	root.add_child(_migration_game)
	if not _migration_game.is_node_ready():
		await _migration_game.ready
	var report: Dictionary = _migration_game.get_runtime_settings_persistence_report()
	var load_status: Dictionary = report.load_status as Dictionary
	print("SETTINGS_CORRUPT_LOAD_REPORT ", JSON.stringify(report, "", true, true))
	if not _migration_check(not bool(report.injected_authority) and report.identity_scope == &"process_lifetime"
			and int(report.load_attempt_count) == 1 and bool(report.load_before_first_apply)
			and bool(load_status.accepted) and bool(load_status.applied) and load_status.reason == &"loaded"
			and load_status.store_reason == &"primary_invalid_backup_loaded" and int(load_status.generation) == 1
			and load_status.store_status.source == &"backup"
			and _migration_equal(_migration_game.get_runtime_settings().to_user_data_payload(), _migration_current),
			"normal Main applies exact backup settings96/profile once before first apply"):
		return
	if not _migration_input_map() or not _migration_check(_input_map_has_key(&"fire", KEY_F13)
			and not _input_map_has_key(&"fire", KEY_F), "corrupt backup retains F13 and removes former F"):
		return
	if not _corrupt_live_owners() or not _corrupt_boundary("normal Main loaded"):
		return
	var hud: GameHUD = _migration_game.get_node_or_null(^"HUD") as GameHUD
	if not _migration_check(hud != null, "corrupt normal Main owns authored HUD"):
		return
	# Begin Shift precedes pause Settings, so Back/Resume return to the same
	# actual gameplay phase instead of manufacturing an intro/pause transition.
	if not await _migration_begin_and_walk(hud):
		return
	if not _corrupt_boundary("normal Begin Shift and supported walking"):
		return
	if not await _corrupt_settings_save(hud):
		return
	if not _corrupt_live_owners() or not _corrupt_boundary("ordinary Settings Save refusal and Resume"):
		return
	var closed: Dictionary = _migration_game.mark_orderly_shutdown()
	print("SETTINGS_CORRUPT_ORDERLY_CLOSE ", JSON.stringify(closed, "", true, true))
	if not _migration_check(not bool(closed.accepted)
			and not bool(closed.safe_start.accepted) and closed.safe_start.reason == &"store_recovery_required",
			"ordinary close preserves backup write blocking without claiming a durable clean shutdown"):
		return
	if not _corrupt_boundary("ordinary close refused"):
		return
	if writer:
		var handoff_file: FileAccess = FileAccess.open(handoff_path, FileAccess.WRITE)
		if not _migration_check(handoff_file != null, "corrupt opens private writer handoff"):
			return
		handoff_file.store_string(JSON.stringify({"writer_pid": OS.get_process_id(),
			"artifacts": _corrupt_expected_artifacts}, "", true, true))
		handoff_file.flush()
		var handoff_error: Error = handoff_file.get_error()
		handoff_file.close()
		_migration_check(handoff_error == OK, "corrupt flushes exact artifact/SHA writer handoff")


func _corrupt_live_owners() -> bool:
	var race: Dictionary = _migration_game.get_cinder_race_session_persistence_report()
	var reward: Dictionary = _migration_game.get_activity_reward_report()
	var safe_start: Dictionary = _migration_game.get_safe_start_recovery_report()
	print("SETTINGS_CORRUPT_OWNERS ", JSON.stringify({"race": race, "reward": reward,
		"safe_start": safe_start}, "", true, true))
	return _migration_check(bool(race.restore_attempted) and not bool(race.restore_status.accepted)
		and race.restore_status.reason == &"race_session_store_recovery_required"
		and _migration_game.cinder_race_session != null
		and _migration_game.cinder_race_session.get_presentation_snapshot().state_id == &"idle"
		and _migration_equal(reward.authority.record, _migration_paid.game_flow_reward_store)
		and not bool(safe_start.begin_status.accepted) and safe_start.begin_status.reason == &"store_recovery_required"
		and int(safe_start.transition_success_count) == 0
		and _migration_equal(_migration_game.get_runtime_settings().to_user_data_payload(), _migration_current),
		"backup paid ledger stays exact with one receipt; Race restore and startup writes remain blocked")


func _corrupt_settings_save(hud: GameHUD) -> bool:
	var original_player: PlayerController = _migration_game.player
	hud.set_paused(true)
	var open: Button = hud.find_child("SettingsOpenButton", true, false) as Button
	if not _migration_check(open != null and open.is_visible_in_tree(), "ordinary paused Settings control is visible"):
		return false
	open.pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 5000
	var save: Button = hud.find_child("SettingsSaveButton", true, false) as Button
	while (save == null or not save.is_visible_in_tree()) and Time.get_ticks_msec() < deadline:
		await process_frame
		save = hud.find_child("SettingsSaveButton", true, false) as Button
	var title: Label = hud.find_child("SettingsRepairTitle", true, false) as Label
	var confirm: Button = hud.find_child("SettingsRepairConfirmButton", true, false) as Button
	if not _migration_check(save != null and save.is_visible_in_tree() and title != null
			and title.is_visible_in_tree() and title.text == "SETTINGS BACKUP RECOVERY AVAILABLE"
			and confirm != null and confirm.is_visible_in_tree() and not confirm.disabled,
			"Settings shows existing backup recovery and explicit confirmation without activating repair"):
		return false
	var before: Dictionary = _migration_game.get_runtime_settings_persistence_report()
	save.pressed.emit()
	var after: Dictionary = _migration_game.get_runtime_settings_persistence_report()
	var status: Label = hud.get("_settings_status_label") as Label
	if not _migration_check(int(after.save_attempt_count) == int(before.save_attempt_count) + 1
			and int(after.save_success_count) == int(before.save_success_count)
			and not bool(after.last_save_status.accepted) and after.last_save_status.reason == &"store_recovery_required"
			and status != null and status.is_visible_in_tree() and status.text == "UNSAVED  //  STORE_RECOVERY_REQUIRED",
			"actual visible Settings Save refuses backup writes with the existing UNSAVED feedback"):
		return false
	if not _corrupt_boundary("actual Settings Save refused"):
		return false
	var back: Button = hud.find_child("SettingsBackButton", true, false) as Button
	if not _migration_check(back != null and back.is_visible_in_tree(), "ordinary Settings Back is visible"):
		return false
	back.pressed.emit()
	var resume: Button = hud.find_child("ResumeButton", true, false) as Button
	if not _migration_check(resume != null and resume.is_visible_in_tree(), "Back returns to ordinary pause Resume"):
		return false
	resume.pressed.emit()
	await physics_frame
	await process_frame
	return _migration_check(not paused and _migration_game.phase == GameFlow.Phase.APPROACH_SHIP
		and _migration_game.player == original_player and not original_player.is_seated()
		and _migration_game.player.is_on_floor() and _migration_game.player.is_control_enabled(),
		"ordinary Resume returns to supported gameplay after the refused Save")


# SAVE-MIGRATION: run writer then reader in separate processes with the same
# guarded private XDG roots, --audio-driver Dummy and isolated --display-driver
# x11. The external process owner retains the existing 300-second cap per mode.
# --settings-migration-writer / --settings-migration-reader
# --settings-migration-private-root=<absolute private root>
# This is a fresh three-namespace fixture, not a modified historical profile.
# The two literal paid namespaces below come from accepted 7997b2b37:
# case-records.tar.gz/results/ordinary-route-tutorial/orderly-close.json,
# original member SHA256 e9ca95cb8f42a93afe7845bf37d669cbfb14068b765b4f0425f85f181a417c59.
const SETTINGS_MIGRATION_PAID_JSON := '''{"cinder_timed_race_session":{"activities":[{"activity_id":"cinder_reach_checkpoint_route","generation":1.0,"progress":{"activity_id":"cinder_reach_checkpoint_route","generation":1.0,"session_state":{"activity_id":"cinder_reach_checkpoint_route","activity_state":{"activity_id":"cinder_reach_checkpoint_route","failure_reason":"","generation":1.0,"next_checkpoint_index":5.0,"schema_version":1.0,"state":2.0},"configured_countdown_seconds":2.0,"configured_laps":1.0,"configured_timeout_seconds":120.0,"presentation_reason":"","race_state":{"activity_id":"cinder_reach_checkpoint_route","best_time_seconds":16.116666666667,"countdown_remaining_seconds":0.0,"current_lap":1.0,"failure_reason":"","generation":1.0,"lap_count":1.0,"lap_started_at_seconds":16.116666666667,"last_time_seconds":16.116666666667,"next_checkpoint_index":0.0,"penalty_seconds":0.0,"race_elapsed_seconds":16.116666666667,"schema_version":1.0,"state":3.0},"schema_version":1.0,"session_generation":1.0,"session_started_once":true},"state":3.0},"reward_granted":true,"reward_requested":true,"state":3.0}],"schema_version":1.0},"game_flow_reward_store":{"authority_id":"game_flow_reward_authority","last_receipt":{"activity_generation":1.0,"activity_id":"cinder_reach_checkpoint_route","granted":true,"receipt_id":1.0,"replay_allowed":false,"reward_id":"return_race_record_to_shipyard","reward_label":"Race record accepted"},"payload_kind":"game_flow_reward_store","receipt_serial":1.0,"reward_counts":{"return_race_record_to_shipyard":1.0},"schema_version":1.0,"store_id":"game_flow_reward_store","total_receipts":1.0}}'''
var _migration_game: GameFlow
var _migration_current: Dictionary = {}
var _migration_old: Dictionary = {}
var _migration_paid: Dictionary = {}


func _run_settings_migration(args: PackedStringArray) -> void:
	var writer: bool = args.has("--settings-migration-writer")
	var reader: bool = args.has("--settings-migration-reader")
	var private_root: String = ""
	for arg: String in args:
		if arg.begins_with("--settings-migration-private-root="):
			private_root = arg.trim_prefix("--settings-migration-private-root=").simplify_path()
	var isolated: bool = private_root.is_absolute_path() and private_root != "/"
	for variable: String in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		isolated = isolated and OS.get_environment(variable).simplify_path().begins_with(private_root + "/")
	isolated = isolated and OS.get_user_data_dir().simplify_path().begins_with(private_root + "/")
	# Godot consumes driver switches before exposing get_cmdline_args(). Check
	# the actual backends; the external launch still records explicit switches.
	var audio_driver: String = AudioServer.get_driver_name()
	var display_driver: String = DisplayServer.get_name()
	print("SETTINGS_MIGRATION_LAUNCH ", JSON.stringify({"writer": writer,
		"reader": reader, "private_root": private_root, "isolated": isolated,
		"user_data_dir": OS.get_user_data_dir(), "audio_driver": audio_driver,
		"display_driver": display_driver}))
	if _migration_check(writer != reader and isolated and audio_driver == "Dummy"
			and display_driver == "X11",
			"migration owns private user data and an explicitly silent isolated X11 run"):
		if _migration_fixture():
			await _migration_stage(writer, private_root)
	# Cleanup is unconditional, including the first failed assertion. Do not
	# publish a clean marker for a failed stage or mutate the failed evidence.
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused = false
	if is_instance_valid(_migration_game):
		_migration_game.queue_free()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _failures.is_empty():
		_migration_boundary(11, "retired Main")
	if _failures.is_empty():
		print("SETTINGS_MIGRATION_%s_OK pid=%d generation=%d sha256=%s" % [
			"WRITER" if writer else "READER", OS.get_process_id(),
			int(_migration_document().get("generation", -1)),
			FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH)])
	_finish()


func _migration_fixture() -> bool:
	# Expected schema11 is fixed before calling any old-section migrator.
	# Values/profile are the existing production fixture at lines344ff; schema10
	# removes exactly the two keys from runtime_settings_test's supported case.
	var settings: RuntimeSettings = Settings.new(Settings.DEFAULT_CONFIG_PATH)
	settings.ship_mouse_sensitivity = 0.0067
	settings.on_foot_mouse_sensitivity = 0.0071
	settings.camera_fov = 96.0
	settings.limit_ultrawide_fov = false
	settings.captions_enabled = true
	settings.high_contrast_hud = false
	settings.reticle_style = &"standard"
	var profile: InputBindingProfile = settings.get_input_binding_profile()
	var fire: Array[Dictionary] = []
	for binding: Dictionary in profile.get_bindings(&"fire"):
		if binding.device == Profile.DEVICE_GAMEPAD:
			fire.append(binding.duplicate(true))
	fire.append({"device": Profile.DEVICE_KEYBOARD, "type": &"key", "physical_keycode": KEY_F13})
	if not _migration_check(profile.set_bindings(&"fire", fire)
			and profile.set_action_options(&"move_forward", {"deadzone": 0.31,
				"curve": Profile.CURVE_SQUARED, "hold_mode": Profile.HOLD})
			and profile.set_action_options(&"sprint_boost", {"deadzone": 0.0,
				"curve": Profile.CURVE_LINEAR, "hold_mode": Profile.TOGGLE})
			and settings.set_input_binding_profile(profile), "migration freezes the complete valid custom profile"):
		return false
	_migration_current = settings.to_user_data_payload()
	_migration_old = _migration_current.duplicate(true)
	_migration_old.schema_version = 10
	(_migration_old.values as Dictionary).erase("high_contrast_hud")
	(_migration_old.values as Dictionary).erase("reticle_style")
	_migration_paid = JSON.parse_string(SETTINGS_MIGRATION_PAID_JSON) as Dictionary
	return _migration_check(int(_migration_current.schema_version) == 11
		and _migration_paid.size() == 2, "migration freezes exactly supported schema10 to11 and two paid namespaces")


func _migration_stage(writer: bool, private_root: String) -> void:
	# SceneTree._initialize precedes attachment of the root. Enter the ordinary
	# main loop before adding Main so its real ready/startup callbacks can run.
	await process_frame
	root.content_scale_size = Vector2i(1280, 720)
	var handoff_path: String = private_root.path_join("settings-migration-writer.json")
	var disk: UserDataStore = Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(disk.load().accepted), "migration opens real private atomic authority"):
		return
	if writer:
		if not _migration_check(disk.get_generation() == 0 and disk.get_snapshot().is_empty()
				and not FileAccess.file_exists(Settings.DEFAULT_CONFIG_PATH)
				and not FileAccess.file_exists(handoff_path), "migration writer requires untouched private authority"):
			return
		var seed: Dictionary = _migration_paid.duplicate(true)
		seed[Adapter.SETTINGS_PAYLOAD_KEY] = _migration_old.duplicate(true)
		var seeded: Dictionary = disk.commit(seed, 0, "settings-migration-schema10-seed")
		if not _migration_check(bool(seeded.accepted) and disk.get_generation() == 1
				and _migration_equal(disk.get_snapshot(), seed), "fresh v1 generation1 contains exactly settings10 and authentic paid race/reward"):
			return
	else:
		var handoff_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(handoff_path))
		if not _migration_check(handoff_value is Dictionary, "reader has the writer's private process handoff"):
			return
		var handoff: Dictionary = handoff_value as Dictionary
		if not _migration_check(int(handoff.get("writer_pid", 0)) > 0
				and int(handoff.get("writer_pid", 0)) != OS.get_process_id()
				and handoff.get("sha256", "") == FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH)
				and int(handoff.get("generation", -1)) == disk.get_generation(),
				"distinct reader starts from the exact reaped writer's clean disk document"):
			return
		if not _migration_boundary(11, "reader before Main"):
			return
	_migration_game = MAIN_SCENE.instantiate() as GameFlow
	# Ordinary production composition; no authority injection or fake provider.
	root.add_child(_migration_game)
	if not _migration_game.is_node_ready():
		await _migration_game.ready
	var report: Dictionary = _migration_game.get_runtime_settings_persistence_report()
	var current_settings: RuntimeSettings = _migration_game.get_runtime_settings()
	var current_payload: Dictionary = current_settings.to_user_data_payload() if current_settings != null else {}
	# Record each detached predicate input before the compound assertion. These
	# full-precision snapshots distinguish readiness, load and migration failures.
	print("SETTINGS_MIGRATION_LOAD_REPORT ", JSON.stringify(report, "", true, true))
	print("SETTINGS_MIGRATION_CURRENT_SETTINGS ", JSON.stringify(current_payload, "", true, true))
	print("SETTINGS_MIGRATION_EXPECTED_SETTINGS ", JSON.stringify(_migration_current, "", true, true))
	if not _migration_check(not bool(report.injected_authority)
			and report.identity_scope == &"process_lifetime" and int(report.load_attempt_count) == 1
			and bool(report.load_before_first_apply) and bool(report.load_status.accepted)
			and current_settings != null and _migration_equal(current_payload, _migration_current),
			"normal Main loads once before apply and upgrades only the two absent settings defaults"):
		return
	if not _migration_safe_start("starting", 1 if writer else 2, 1 if writer else 4):
		return
	if not _migration_boundary(10 if writer else 11, "ordinary STARTING"):
		return
	# Let normal engine physics cross the existing five-second STABLE window.
	while float(_migration_game.get_safe_start_recovery_report().physics_elapsed_seconds) < 5.0:
		await physics_frame
	await process_frame
	if not _migration_safe_start("stable", 1 if writer else 2, 2 if writer else 5):
		return
	if not _migration_boundary(10 if writer else 11, "ordinary STABLE"):
		return
	if not _migration_input_map():
		return
	if not _migration_check(_input_map_has_key(&"fire", KEY_F13)
			and not _input_map_has_key(&"fire", KEY_F)
			and _migration_equal(_migration_game.get_runtime_settings().to_user_data_payload(), _migration_current)
			and int((_migration_game.get_activity_reward_report().authority.record.reward_counts as Dictionary)
				.get("return_race_record_to_shipyard", 0)) == 1
			and _migration_game.cinder_race_session != null
			and _migration_equal(_migration_game.cinder_race_session.capture_persistence_state(),
				_migration_paid.cinder_timed_race_session.activities[0].progress.session_state),
			"loaded production profile/InputMap and actual paid race/reward owner match the protected fixture"):
		return
	var hud: GameHUD = _migration_game.get_node_or_null(^"HUD") as GameHUD
	if not _migration_check(hud != null, "normal migration Main owns its HUD"):
		return
	if writer:
		hud.set_paused(true)
		hud._show_settings_page()
		var ui_deadline: int = Time.get_ticks_msec() + 5000
		var save: Button = hud.find_child("SettingsSaveButton", true, false) as Button
		while (save == null or not save.is_visible_in_tree()) and Time.get_ticks_msec() < ui_deadline:
			await process_frame
			save = hud.find_child("SettingsSaveButton", true, false) as Button
		if not _migration_check(save != null and save.is_visible_in_tree(), "ordinary Settings Save visible within original five-second UI cap"):
			return
		var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(Adapter.DEFAULT_STORE_PATH)
		var before: Dictionary = _migration_document()
		var before_mode: int = FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH)
		var expected_payload: Dictionary = (before.payload as Dictionary).duplicate(true)
		expected_payload[Adapter.SETTINGS_PAYLOAD_KEY] = _migration_current.duplicate(true)
		var successes: int = int(_migration_game.get_runtime_settings_persistence_report().save_success_count)
		# No yield across this exact synchronous production transaction.
		save.pressed.emit()
		var after: Dictionary = _migration_document()
		var saved: Dictionary = _migration_game.get_runtime_settings_persistence_report()
		if not _migration_check(int(saved.save_success_count) == successes + 1
				and bool(saved.last_save_status.accepted) and not bool(saved.unsaved_changes)
				and int(after.generation) == int(before.generation) + 1
				and int(after.commit.parent_generation) == int(before.generation)
				and after.commit.parent_id == before.commit.id
				and after.commit.id == "runtime-settings-%010d" % int(after.generation)
				and _migration_equal(after.payload, expected_payload)
				and FileAccess.get_file_as_bytes(Adapter.DEFAULT_STORE_PATH + ".bak") == before_bytes
				and FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH) == before_mode
				and FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH + ".bak") == before_mode,
				"one visible Save publishes exact schema11 full payload, next generation/parent and exact prior backup bytes"):
			return
		if not _migration_boundary(11, "explicit Settings Save"):
			return
		hud.set_paused(false)
	else:
		if not await _migration_begin_and_walk(hud):
			return
		if not _migration_boundary(11, "ordinary reader walk"):
			return
	var closed: Dictionary = _migration_game.mark_orderly_shutdown()
	if not _migration_check(bool(closed.accepted), "ordinary owner explicitly records clean shutdown"):
		return
	if not _migration_safe_start("clean_shutdown", 1 if writer else 2, 3 if writer else 6):
		return
	if not _migration_boundary(11, "explicit orderly close"):
		return
	if writer:
		var handoff_file: FileAccess = FileAccess.open(handoff_path, FileAccess.WRITE)
		if not _migration_check(handoff_file != null, "writer opens its private process handoff"):
			return
		handoff_file.store_string(JSON.stringify({"writer_pid": OS.get_process_id(),
			"generation": int(_migration_document().generation),
			"sha256": FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH)}))
		handoff_file.flush()
		var handoff_error: Error = handoff_file.get_error()
		handoff_file.close()
		_migration_check(handoff_error == OK, "writer flushes the exact clean process handoff")


func _migration_begin_and_walk(hud: GameHUD) -> bool:
	var begin: Button = hud.find_child("IntroBeginShiftButton", true, false) as Button
	if not _migration_check(begin != null and begin.is_visible_in_tree(), "reader exposes ordinary Begin Shift"):
		return false
	var original_player: PlayerController = _migration_game.player
	var intro: Control = hud.get("_intro") as Control
	var entry_started: int = Time.get_ticks_msec()
	var entry_deadline: int = entry_started + 5000
	print("SETTINGS_MIGRATION_ENTRY_BEFORE ", JSON.stringify({
		"phase": int(_migration_game.phase), "player_id": original_player.get_instance_id(),
		"control_enabled": original_player.is_control_enabled(), "on_floor": original_player.is_on_floor(),
		"seated": original_player.is_seated(), "intro_visible": intro != null and intro.is_visible_in_tree(),
		"begin_visible": begin.is_visible_in_tree(), "ticks_msec": entry_started,
		"physics_frame": Engine.get_physics_frames()}))
	# The ordinary HUD begins with its authored transition tween. Observe its
	# real start_requested/phase completion within the existing UI cap.
	begin.pressed.emit()
	while _migration_game.phase != GameFlow.Phase.APPROACH_SHIP and Time.get_ticks_msec() < entry_deadline:
		await process_frame
	var entry_completed: int = Time.get_ticks_msec()
	var entry_in_cap: bool = _migration_game.phase == GameFlow.Phase.APPROACH_SHIP and entry_completed <= entry_deadline
	# physics_frame precedes the step; process_frame observes its completion.
	await physics_frame
	await process_frame
	print("SETTINGS_MIGRATION_ENTRY_AFTER ", JSON.stringify({
		"phase": int(_migration_game.phase), "player_id": _migration_game.player.get_instance_id(),
		"same_player": _migration_game.player == original_player,
		"control_enabled": original_player.is_control_enabled(), "on_floor": original_player.is_on_floor(),
		"seated": original_player.is_seated(), "intro_visible": intro != null and intro.is_visible_in_tree(),
		"entry_completed_within_cap": entry_in_cap, "entry_elapsed_msec": entry_completed - entry_started,
		"observed_elapsed_msec": Time.get_ticks_msec() - entry_started,
		"physics_frame": Engine.get_physics_frames()}))
	if not _migration_check(entry_in_cap and _migration_game.phase == GameFlow.Phase.APPROACH_SHIP
			and _migration_game.player == original_player and original_player.is_control_enabled()
			and not original_player.is_seated() and original_player.is_on_floor(),
			"ordinary Begin Shift admits the same supported on-foot Player"):
		return false
	var origin: Vector3 = original_player.global_position
	var walk_deadline: int = Time.get_ticks_msec() + 5000
	Input.action_press(&"move_forward")
	while original_player.global_position.distance_to(origin) < 1.0 and Time.get_ticks_msec() < walk_deadline:
		await physics_frame
		if not _migration_walk_owner(original_player):
			Input.action_release(&"move_forward")
			return false
	Input.action_release(&"move_forward")
	if not _migration_check(original_player.global_position.distance_to(origin) >= 1.0,
			"same supported Player walks at least one metre within the original five-second cap"):
		return false
	var settle_deadline: int = Time.get_ticks_msec() + 5000
	while original_player.velocity.length() > 0.05 and Time.get_ticks_msec() < settle_deadline:
		await physics_frame
		if not _migration_walk_owner(original_player):
			return false
	if not _migration_check(original_player.velocity.length() <= 0.05,
			"released ordinary walk settles within the original five-second cap"):
		return false
	var neutral_origin: Vector3 = original_player.global_position
	for _tick: int in 12:
		await physics_frame
		if not _migration_walk_owner(original_player):
			return false
		if not _migration_check(not Input.is_action_pressed(&"move_forward")
				and original_player.velocity.length() <= 0.05
				and original_player.global_position.distance_to(neutral_origin) <= 0.02,
				"reader remains supported and neutral without drift at tick %d" % (_tick + 1)):
			return false
	return true


func _migration_walk_owner(original_player: PlayerController) -> bool:
	return _migration_check(_migration_game.player == original_player
		and _migration_game.phase == GameFlow.Phase.APPROACH_SHIP
		and original_player.is_on_floor() and original_player.is_control_enabled()
		and not original_player.is_seated() and not original_player.is_sleeping(),
		"ordinary walk retains the same supported controllable on-foot Player")


func _migration_equal(left: Variant, right: Variant) -> bool:
	# JSON normalizes integral types/StringNames without rounding stored doubles.
	return JSON.parse_string(JSON.stringify(left, "", true, true)) \
		== JSON.parse_string(JSON.stringify(right, "", true, true))


func _migration_document() -> Dictionary:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(Adapter.DEFAULT_STORE_PATH))
	return decoded as Dictionary if decoded is Dictionary else {}


func _migration_boundary(schema: int, label: String) -> bool:
	var disk: UserDataStore = Store.new(Adapter.DEFAULT_STORE_PATH)
	if not _migration_check(bool(disk.load().accepted) and disk.get_loaded_source() == &"primary",
			label + ": healthy primary loads without repair"):
		return false
	if disk.get_generation() > 1:
		var backup_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(Adapter.DEFAULT_STORE_PATH + ".bak"))
		if not _migration_check(backup_value is Dictionary and Store.validate_envelope(backup_value).is_empty(),
				label + ": existing backup envelope and payload checksum are valid"):
			return false
		var backup: Dictionary = backup_value as Dictionary
		var commit: Dictionary = disk.get_commit_metadata()
		if not _migration_check(int(commit.parent_generation) == int(backup.generation)
				and commit.parent_id == backup.commit.id
				and int(backup.generation) == disk.get_generation() - 1,
				label + ": existing backup is the exact immediate generation and ID predecessor"):
			return false
	var payload: Dictionary = disk.get_snapshot()
	var expected_settings: Dictionary = _migration_old if schema == 10 else _migration_current
	if not _migration_check(_migration_equal(payload.get(Adapter.SETTINGS_PAYLOAD_KEY, {}), expected_settings)
			and _migration_equal(payload.get("cinder_timed_race_session", {}), _migration_paid.cinder_timed_race_session)
			and _migration_equal(payload.get("game_flow_reward_store", {}), _migration_paid.game_flow_reward_store),
			label + ": complete settings/profile and both exact authentic paid namespaces remain protected"):
		return false
	for key: String in payload:
		if not _migration_check(key in [Adapter.SETTINGS_PAYLOAD_KEY, "cinder_timed_race_session",
				"game_flow_reward_store", "safe_start_recovery", "crash_recovery",
				"session_diagnostics", "solo_safe_recovery", "tutorial_prompts_seen"],
				label + ": only source-owned ordinary metadata namespace " + key):
			return false
	print("SETTINGS_MIGRATION_BOUNDARY ", JSON.stringify({"label": label,
		"pid": OS.get_process_id(), "generation": disk.get_generation(),
		"commit": disk.get_commit_metadata(), "schema": schema,
		"primary_sha256": FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH),
		"backup_sha256": FileAccess.get_sha256(Adapter.DEFAULT_STORE_PATH + ".bak"),
		"primary_mode": FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH),
		"backup_mode": FileAccess.get_unix_permissions(Adapter.DEFAULT_STORE_PATH + ".bak")}))
	return true


func _migration_input_map() -> bool:
	var profile: InputBindingProfile = _migration_game.get_runtime_settings().get_input_binding_profile()
	var captured: InputBindingProfile = InputRebindService.new().capture_input_map()
	if not _migration_check(captured != null and captured.bindings == profile.bindings,
			"every loaded keyboard, mouse and gamepad binding reaches the real InputMap"):
		return false
	for action: StringName in profile.bindings:
		if not _migration_check(is_equal_approx(InputMap.action_get_deadzone(action),
				float(profile.get_action_options(action).deadzone)),
				"loaded InputMap deadzone matches the protected profile: " + String(action)):
			return false
	return true


func _migration_safe_start(state: String, startup: int, record_generation: int) -> bool:
	var report: Dictionary = _migration_game.get_safe_start_recovery_report()
	var snapshot: Dictionary = report.policy_snapshot as Dictionary
	var expected: Dictionary = {"schema_version": 1, "record_generation": record_generation,
		"state": state, "startup_generation": startup, "consecutive_failure_count": 0,
		"safe_settings_recommended": false}
	var stored: Dictionary = _migration_document().get("payload", {}) as Dictionary
	return _migration_check(_migration_equal(stored.get("safe_start_recovery", {}), expected)
		and snapshot.state == state and int(snapshot.startup_generation) == startup
		and int(snapshot.record_generation) == record_generation
		and int(snapshot.consecutive_failure_count) == 0 and not bool(snapshot.safe_settings_recommended),
		"ordinary safe-start state/counters remain exact: " + state)


func _migration_check(condition: bool, label: String) -> bool:
	_check(condition, label)
	return condition


func _fire_restart_gamepads(profile: InputBindingProfile, action: StringName = &"fire") -> String:
	var bindings: Array[Dictionary] = []
	for binding: Dictionary in profile.get_bindings(action):
		if binding.device == Profile.DEVICE_GAMEPAD:
			bindings.append(binding)
	return JSON.stringify(bindings)


func _fire_restart_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _fire_restart_mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _fire_restart_sample(source: LocalShipInputSource, expected: bool, stage: String) -> bool:
	# Godot queues raw events until its native flush; deliver them before sampling.
	Input.flush_buffered_events()
	var values := source._sample_controls()
	var agrees := not values.is_empty() and values.has("fire") \
		and bool(values.fire) == expected and Input.is_action_pressed(&"fire") == expected
	_check(agrees, "production sampler agrees with InputMap after %s" % stage)
	print("FIRE_RESTART_SAMPLE stage=%s fire=%s input_map=%s" % [
		stage, str(values.get("fire", "MISSING")), str(Input.is_action_pressed(&"fire")),
	])
	return agrees


func _test_production_startup_transactions_and_reentry() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	var seeded_settings := Settings.new(LEGACY_PATH)
	seeded_settings.ship_mouse_sensitivity = 0.0067
	seeded_settings.on_foot_mouse_sensitivity = 0.0071
	seeded_settings.camera_fov = 96.0
	# Seeded OFF specifically because the shipping default is ON: a persisted
	# opt-out that silently reverts to the default on the next launch is the
	# failure this proves cannot happen.
	seeded_settings.limit_ultrawide_fov = false
	seeded_settings.captions_enabled = true
	var seeded_profile := seeded_settings.get_input_binding_profile()
	var fire_bindings: Array[Dictionary] = []
	for binding: Dictionary in seeded_profile.get_bindings(&"fire"):
		if binding.device == Profile.DEVICE_GAMEPAD:
			fire_bindings.append(binding)
	fire_bindings.append({
		"device": Profile.DEVICE_KEYBOARD,
		"type": &"key",
		"physical_keycode": KEY_F13,
	})
	_check(
		seeded_profile.set_bindings(&"fire", fire_bindings)
		and seeded_profile.set_action_options(&"move_forward", {
			"deadzone": 0.31,
			"curve": Profile.CURVE_SQUARED,
			"hold_mode": Profile.HOLD,
		})
		and seeded_profile.set_action_options(&"sprint_boost", {
			"deadzone": 0.0,
			"curve": Profile.CURVE_LINEAR,
			"hold_mode": Profile.TOGGLE,
		})
		and seeded_settings.set_input_binding_profile(seeded_profile),
		"fixture creates one complete validated custom binding and processing profile"
	)
	_check(bool(store.load().accepted), "fixture opens the injected empty store")
	_check(
		bool(store.commit({
			"diagnostics": {"last_session": "keep-me"},
			"save_slots": {"slot_a": {"progress": 42}},
			Adapter.SETTINGS_PAYLOAD_KEY: seeded_settings.to_user_data_payload(),
		}, 0, "fixture-generation-1").accepted),
		"fixture publishes settings beside unrelated diagnostic and save namespaces"
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(
		game.configure_runtime_settings_persistence(store, LEGACY_PATH),
		"production Main accepts one injected persistence authority before startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var player := game.get_node_or_null(^"Player") as PlayerController
	var settings := game.get_runtime_settings()
	var startup := game.get_runtime_settings_persistence_report()
	# RuntimeSettings shares the UserDataStore with startup/session systems. Their
	# independent commits can advance the canonical generation without being a
	# settings transaction, so settings IDs continue from the greater authority.
	var settings_commit_baseline := maxi(
		int(startup.commit_serial),
		store.get_generation(),
	)
	_check(
		int(startup.store_count) == 1
		and int(startup.adapter_count) == 1
		and int(startup.store_instance_id) == store.get_instance_id()
		and int(startup.adapter_instance_id) != 0
		and int(startup.load_attempt_count) == 1
		and bool(startup.load_status.accepted)
		and startup.load_status.reason == &"loaded"
		and bool(startup.load_before_first_apply),
		"startup owns one retained store/adapter and completes exactly one load before first apply"
	)
	_check(
		settings != null
		and hud != null
		and player != null
		and is_equal_approx(settings.camera_fov, 96.0)
		and is_equal_approx(player.mouse_sensitivity, 0.0071)
		and game.get_flyable_ships().size() == 9,
		"validated loaded settings reach the real Player and complete nine-ship fleet"
	)
	var ships_match := true
	for fleet_ship: HeroShip in game.get_flyable_ships():
		ships_match = ships_match \
			and is_equal_approx(fleet_ship.mouse_sensitivity, 0.0067) \
			and is_equal_approx(fleet_ship.get_camera_fov(), 96.0)
	_check(ships_match, "every ship consumes the loaded snapshot before production play begins")
	var ultrawide_opt_out_reached_rigs := not settings.limit_ultrawide_fov \
		and not player.is_ultrawide_fov_limited()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		ultrawide_opt_out_reached_rigs = ultrawide_opt_out_reached_rigs \
			and not fleet_ship.is_ultrawide_fov_limited() \
			and is_equal_approx(fleet_ship.get_authored_camera_fov(), 96.0)
	_check(
		ultrawide_opt_out_reached_rigs,
		"the persisted ultrawide field-of-view opt-out reaches every camera rig at startup"
	)
	var startup_profile_matches := true
	var startup_generations := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		var source := fleet_ship.get_command_source() as LocalShipInputSource
		startup_profile_matches = startup_profile_matches \
			and source != null \
			and source.get_input_binding_profile().to_dictionary() \
				== settings.get_input_binding_profile().to_dictionary()
		startup_generations.append(source.get_input_profile_generation() if source != null else -1)
	_check(
		startup_profile_matches and startup_generations == PackedInt64Array([
			3, 3, 3, 3, 3, 3, 3, 3, 3,
		]),
		"startup atomically installs the persisted options into all nine production transform banks"
	)
	var curve_source := game.get_flyable_ships()[1].get_local_input_source()
	Input.action_press(&"move_forward", 0.6)
	var curved_command := curve_source.next_command(900)
	Input.action_release(&"move_forward")
	var curve_audit := curve_source.get_input_integration_audit()
	_check(
		is_equal_approx(curved_command.throttle, 0.36)
		and bool(curve_audit.production_input_profile_active)
		and curve_audit.production_input_strength_domain == &"input_map_resolved",
		"production input executes the stored squared curve without applying InputMap's deadzone response twice"
	)
	var hud_binding_report := hud.get_input_binding_report()
	_check(
		_input_map_has_key(&"fire", KEY_F13)
		and not _input_map_has_key(&"fire", KEY_F)
		and int(hud_binding_report.action_count) == 22
		and (hud_binding_report.bindings as Dictionary)[&"fire"]
			== settings.get_input_binding_profile().get_bindings(&"fire"),
		"the complete persisted binding profile reaches InputMap and HUD before input consumers"
	)

	var local_source_ids := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		var source := fleet_ship.get_local_input_source()
		local_source_ids.append(source.get_instance_id())
	var probed_source := game.get_flyable_ships()[0].get_local_input_source()
	var provider := MutableInputProvider.new()
	probed_source.set_input_provider(provider)
	probed_source.next_command(1000)
	provider.set_action(&"sprint_boost", 1.0, true)
	var generations_before_profile_change := _fleet_input_generations(game)
	var live_profile := settings.get_input_binding_profile()
	_check(
		live_profile.set_action_options(&"move_forward", {
			"deadzone": 0.42,
			"curve": Profile.CURVE_SQUARED,
			"hold_mode": Profile.HOLD,
		})
		and settings.set_input_binding_profile(live_profile),
		"RuntimeSettings accepts one live complete processing-profile replacement"
	)
	var live_profiles_match := true
	var live_generations := PackedInt64Array()
	var banks_own_no_input_map := true
	for fleet_ship: HeroShip in game.get_flyable_ships():
		var source := fleet_ship.get_local_input_source()
		live_profiles_match = live_profiles_match \
			and source.get_input_binding_profile().to_dictionary() \
				== settings.get_input_binding_profile().to_dictionary()
		live_generations.append(source.get_input_profile_generation())
		banks_own_no_input_map = banks_own_no_input_map \
			and not bool(source.get_input_integration_audit().bank.mutates_input_map)
	var primed_toggle := probed_source.next_command(1001)
	provider.set_action(&"sprint_boost", 0.0, false)
	probed_source.next_command(1002)
	provider.set_action(&"sprint_boost", 1.0, true)
	var repressed_toggle := probed_source.next_command(1003)
	_check(
		live_profiles_match
		and _generations_advanced(generations_before_profile_change, live_generations, 1)
		and _fleet_local_source_ids(game) == local_source_ids
		and is_equal_approx(InputMap.action_get_deadzone(&"move_forward"), 0.42)
		and banks_own_no_input_map,
		"one live RuntimeSettings change advances all nine banks exactly once while RuntimeSettings alone mutates InputMap"
	)
	_check(
		not primed_toggle.boost and repressed_toggle.boost,
		"live profile replacement primes a held toggle without synthesizing flight intent"
	)
	var incomplete := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {&"fire": []},
		"action_options": {&"fire": Profile.default_action_options()},
	})
	var generations_before_rejection := live_generations.duplicate()
	_check(
		not settings.set_input_binding_profile(incomplete)
		and _fleet_input_generations(game) == generations_before_rejection
		and is_equal_approx(InputMap.action_get_deadzone(&"move_forward"), 0.42),
		"an incomplete live roster changes neither any bank generation nor InputMap"
	)
	_check(
		not game.configure_runtime_settings_persistence(
			Store.new("memory://late-authority.json", FakeFilesystem.new()),
			"memory://late-legacy.cfg"
		),
		"startup permanently closes the persistence-authority injection seam"
	)

	# Returned status is detached all the way through nested store evidence.
	var detached := game.get_runtime_settings_persistence_report()
	detached.load_status["reason"] = &"consumer_mutation"
	(detached.load_status.store_status as Dictionary)["payload"] = {"tampered": true}
	_check(
		game.get_runtime_settings_persistence_report().load_status.reason == &"loaded"
		and not (
			game.get_runtime_settings_persistence_report().load_status.store_status.payload
			as Dictionary
		).has("tampered"),
		"load and save diagnostics are deeply detached from persistence authority"
	)

	var commit_ids := PackedStringArray()
	hud.setting_change_requested.emit(&"camera_fov", 88.0)
	var changed := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(changed.last_commit_id))
	_check(
		is_equal_approx(settings.camera_fov, 88.0)
		and int(changed.save_attempt_count) == 1
		and int(changed.save_success_count) == 1
		and int(changed.accepted_transaction_count) == 1
		and not bool(changed.unsaved_changes)
		and changed.last_save_status.reason == &"saved"
		and changed.last_commit_id == _runtime_settings_commit_id(
			settings_commit_baseline + 1
		),
		"an accepted live change commits once with the first deterministic monotonic ID"
	)
	var attempts_before_noop := int(changed.save_attempt_count)
	hud.setting_change_requested.emit(&"camera_fov", 88.0)
	hud.setting_change_requested.emit(&"not_a_setting", true)
	_check(
		int(game.get_runtime_settings_persistence_report().save_attempt_count)
			== attempts_before_noop,
		"an unchanged value and unknown key create no settings transaction or disk write"
	)

	# A synchronous setting signal tries both public transaction entries. The
	# outer HUD transaction remains the only writer and commits after signals end.
	var signal_reentry := func(_setting: StringName, _value: Variant) -> void:
		game._on_settings_save_requested()
		game._on_setting_change_requested(&"ui_scale", 1.3)
	settings.setting_changed.connect(signal_reentry, CONNECT_ONE_SHOT)
	hud.setting_change_requested.emit(&"master_volume", 0.45)
	var after_reentry := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(after_reentry.last_commit_id))
	_check(
		int(after_reentry.save_attempt_count) == 2
		and int(after_reentry.reentrant_rejection_count) == 2
		and is_equal_approx(settings.master_volume, 0.45)
		and is_equal_approx(settings.ui_scale, Settings.DEFAULT_UI_SCALE),
		"settings signals cannot recur into save or a nested settings transaction"
	)

	var disk_before_failure := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	filesystem.fail_write_once = true
	hud.setting_change_requested.emit(&"camera_fov", 91.0)
	var failed := game.get_runtime_settings_persistence_report()
	var failed_candidate_id := str(failed.last_save_status.commit_id)
	var live_failure_applied := is_equal_approx(settings.camera_fov, 91.0)
	for fleet_ship: HeroShip in game.get_flyable_ships():
		live_failure_applied = live_failure_applied \
			and is_equal_approx(fleet_ship.get_camera_fov(), 91.0)
	_check(
		live_failure_applied
		and bool(failed.unsaved_changes)
		and not bool(failed.last_save_status.accepted)
		and failed.last_save_status.reason == &"store_commit_failed"
		and failed.last_save_status.store_reason == &"temp_write_failed"
		and failed.last_commit_id == _runtime_settings_commit_id(
			settings_commit_baseline + 2
		)
		and int(failed.commit_serial) == settings_commit_baseline + 2
		and failed_candidate_id == _runtime_settings_commit_id(
			settings_commit_baseline + 3
		)
		and filesystem.files[STORE_PATH] == disk_before_failure
		and not filesystem.files.has(STORE_PATH + ".tmp"),
		"failed save keeps the accepted live change, marks it unsaved and preserves canonical disk"
	)
	hud.setting_change_requested.emit(&"camera_fov", 92.0)
	var retried := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(retried.last_commit_id))
	_check(
		not bool(retried.unsaved_changes)
		and bool(retried.last_save_status.accepted)
		and failed_candidate_id == str(retried.last_commit_id)
		and is_equal_approx(settings.camera_fov, 92.0),
		"a retry reuses the unconsumed deterministic ID, publishes live state and clears unsaved state"
	)

	hud.settings_reset_requested.emit()
	var reset := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(reset.last_commit_id))
	_check(
		settings.to_dictionary() == Settings.new(LEGACY_PATH).to_dictionary()
		and bool(reset.last_save_status.accepted)
		and not bool(reset.unsaved_changes),
		"Reset Defaults applies and persists as exactly one atomic transaction"
	)
	hud.settings_save_requested.emit()
	var explicit := game.get_runtime_settings_persistence_report()
	commit_ids.append(str(explicit.last_commit_id))
	var expected_commit_ids := PackedStringArray()
	for offset in range(1, 6):
		expected_commit_ids.append(
			_runtime_settings_commit_id(settings_commit_baseline + offset)
		)
	_check(
		bool(explicit.last_save_status.accepted)
		and int(explicit.accepted_transaction_count) == 6
		and commit_ids == expected_commit_ids,
		"every committed change, reset and explicit-save ID is bounded, deterministic and monotonic"
	)
	var composed := store.get_snapshot()
	_check(
		(composed.diagnostics as Dictionary).last_session == "keep-me"
		and int((composed.save_slots.slot_a as Dictionary).progress) == 42
		and composed.has(Adapter.SETTINGS_PAYLOAD_KEY),
		"every settings commit preserves unrelated diagnostic and save namespaces"
	)

	var before_detach := game.get_runtime_settings_persistence_report()
	var source_ids_before_detach := _fleet_local_source_ids(game)
	var generations_before_detach := _fleet_input_generations(game)
	var profile_before_detach := settings.get_input_binding_profile().to_dictionary()
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	var while_detached := game.get_runtime_settings_persistence_report()
	parent.add_child(game)
	await process_frame
	await process_frame
	var after_detach := game.get_runtime_settings_persistence_report()
	_check(
		int(while_detached.store_instance_id) == int(before_detach.store_instance_id)
		and int(while_detached.adapter_instance_id) == int(before_detach.adapter_instance_id)
		and int(after_detach.store_instance_id) == int(before_detach.store_instance_id)
		and int(after_detach.adapter_instance_id) == int(before_detach.adapter_instance_id)
		and int(after_detach.load_attempt_count) == 1
		and int(after_detach.save_attempt_count) == int(before_detach.save_attempt_count)
		and _fleet_local_source_ids(game) == source_ids_before_detach
		and _generations_advanced(
			generations_before_detach,
			_fleet_input_generations(game),
			2,
		)
		and _fleet_profiles_match(game, profile_before_detach),
		"whole-Main detach/re-entry retains settings and all nine source/profile identities with only the two lifecycle generation fences"
	)

	game.queue_free()
	await process_frame
	await process_frame


func _test_empty_corrupt_newer_and_failed_loads() -> void:
	var empty_filesystem := FakeFilesystem.new()
	var empty := _initialize_flow(Store.new(STORE_PATH, empty_filesystem), "empty")
	_check(
		bool(empty.report.load_status.accepted)
		and empty.report.load_status.reason == &"defaults_initialized"
		and int(empty.report.load_status.generation) == 1
		and int(empty.report.save_success_count) == 1
		and (empty.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and (empty.flow as GameFlow).get_safe_start_recovery_report()
			.policy_snapshot.state == "starting"
		and empty_filesystem.files.has(STORE_PATH),
		"fresh startup commits authored settings as generation one before recovery writes other keys"
	)
	var reopened := Store.new(STORE_PATH, empty_filesystem)
	var readonly := Settings.new(LEGACY_PATH)
	var before_preview := empty_filesystem.files.duplicate(true)
	var loaded := Adapter.new(readonly, reopened, LEGACY_PATH).load_read_only()
	_check(bool(loaded.accepted) and loaded.reason == &"loaded"
		and readonly.to_dictionary() == Settings.new(LEGACY_PATH).to_dictionary()
		and empty_filesystem.files == before_preview,
		"repeated startup reads initialized default preferences without read-only writes")
	var repeated := _initialize_flow(reopened, "empty-repeated")
	_check(repeated.report.load_status.reason == &"loaded"
		and int(repeated.report.save_attempt_count) == 0,
		"a new gameplay owner restores defaults without repeating their initialization transaction")
	(repeated.flow as GameFlow).free()
	(empty.flow as GameFlow).free()

	var failed_defaults_filesystem := FakeFilesystem.new()
	failed_defaults_filesystem.fail_write_once = true
	var failed_defaults := _initialize_flow(Store.new(STORE_PATH, failed_defaults_filesystem), "failed-defaults")
	_check(not bool(failed_defaults.report.load_status.accepted)
		and failed_defaults.report.load_status.reason == &"store_commit_failed"
		and failed_defaults.report.load_status.store_reason == &"temp_write_failed"
		and bool(failed_defaults.report.unsaved_changes)
		and (failed_defaults.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and failed_defaults_filesystem.files.is_empty(),
		"failed first defaults commit retains live defaults, reports unsaved state and prevents recovery from creating a settings-less document")
	(failed_defaults.flow as GameFlow).free()

	var corrupt_filesystem := FakeFilesystem.new()
	corrupt_filesystem.files[STORE_PATH] = "{corrupt".to_utf8_buffer()
	var corrupt_bytes := (corrupt_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var corrupt := _initialize_flow(Store.new(STORE_PATH, corrupt_filesystem), "corrupt")
	(corrupt.flow as GameFlow)._on_setting_change_requested(&"camera_fov", 87.0)
	var corrupt_after := (corrupt.flow as GameFlow).get_runtime_settings_persistence_report()
	_check(
		not bool(corrupt.report.load_status.accepted)
		and corrupt.report.load_status.reason == &"store_load_failed"
		and corrupt.report.load_status.store_reason == &"no_valid_document"
		and is_equal_approx((corrupt.flow as GameFlow).get_runtime_settings().camera_fov, 87.0)
		and bool(corrupt_after.unsaved_changes)
		and corrupt_filesystem.files[STORE_PATH] == corrupt_bytes,
		"corrupt authority keeps defaults, rejects overwrite and leaves later live changes unsaved"
	)
	(corrupt.flow as GameFlow).free()

	var newer_filesystem := FakeFilesystem.new()
	var newer_store := Store.new(STORE_PATH, newer_filesystem)
	newer_store.load()
	newer_store.commit({
		Adapter.SETTINGS_PAYLOAD_KEY: {
			"schema_version": Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1,
			"values": {},
		},
	}, 0, "future-settings")
	var newer_bytes := (newer_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var newer := _initialize_flow(Store.new(STORE_PATH, newer_filesystem), "newer")
	_check(
		not bool(newer.report.load_status.accepted)
		and newer.report.load_status.reason == &"settings_payload_newer"
		and (newer.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and newer_filesystem.files[STORE_PATH] == newer_bytes,
		"newer typed settings remain authoritative bytes while this build runs defaults"
	)
	(newer.flow as GameFlow).free()

	var failed_filesystem := FakeFilesystem.new()
	failed_filesystem.files[STORE_PATH] = "unreadable-authority".to_utf8_buffer()
	failed_filesystem.fail_reads = true
	var failed_bytes := (failed_filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var failed_load := _initialize_flow(Store.new(STORE_PATH, failed_filesystem), "failed")
	_check(
		not bool(failed_load.report.load_status.accepted)
		and failed_load.report.load_status.reason == &"store_load_failed"
		and failed_load.report.load_status.store_reason == &"no_valid_document"
		and (failed_load.flow as GameFlow).get_runtime_settings().to_dictionary()
			== Settings.new(LEGACY_PATH).to_dictionary()
		and failed_filesystem.files[STORE_PATH] == failed_bytes,
		"filesystem load failure keeps defaults live and never rewrites unreadable authority"
	)
	(failed_load.flow as GameFlow).free()


func _test_existing_missing_settings_initialization() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	store.load()
	var foreign := {"career": {"credits": 73}, "archive": {"keep": "keep-me"}}
	store.commit(foreign, 0, "shipped-without-preferences")
	foreign = store.get_snapshot()
	var prior_bytes := (filesystem.files[STORE_PATH] as PackedByteArray).duplicate()
	var initialized := _initialize_flow(store, "old-profile")
	var payload := store.get_snapshot()
	_check(bool(initialized.report.load_status.accepted)
		and initialized.report.load_status.reason == &"defaults_initialized"
		and int(initialized.report.load_status.generation) == 2,
		"healthy shipped profiles explicitly initialize defaults at the next atomic generation")
	_check(payload.career == foreign.career and payload.archive == foreign.archive,
		"initializing missing preferences preserves every unrelated payload namespace")
	var restored := Settings.new(LEGACY_PATH)
	_check(bool(restored.apply_user_data_payload(payload[Adapter.SETTINGS_PAYLOAD_KEY]).accepted)
		and restored.to_dictionary() == Settings.new(LEGACY_PATH).to_dictionary(),
		"the initialized durable settings section reconstructs exact authored defaults")
	_check(filesystem.files[STORE_PATH + ".bak.1"] == prior_bytes,
		"settings initialization and recovery retain the earlier atomic generation in rotated backup history")
	(initialized.flow as GameFlow).free()


func _initialize_flow(store: UserDataStore, suffix: String) -> Dictionary:
	var flow := GameFlow.new()
	_check(
		flow.configure_runtime_settings_persistence(
			store,
			"memory://runtime-settings-%s-legacy.cfg" % suffix
		),
		"%s fixture injects its isolated store" % suffix
	)
	flow._initialize_runtime_settings()
	return {
		"flow": flow,
		"report": flow.get_runtime_settings_persistence_report(),
	}


func _test_process_lifetime_recreation_identity() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new("memory://process-lifetime-settings.json", filesystem)
	var seeded := Settings.new("memory://process-lifetime-legacy.cfg")
	seeded.camera_fov = 83.0
	store.load()
	store.commit(
		{Adapter.SETTINGS_PAYLOAD_KEY: seeded.to_user_data_payload()},
		0,
		"process-fixture"
	)
	# This direct pre-start assignment exercises the default production branch
	# without ever letting it construct the real user:// store. Unlike the public
	# injected seam, it deliberately allows the static process composition root.
	var first := GameFlow.new()
	first.set("_runtime_settings_user_data_store", store)
	first.set("_runtime_settings_legacy_path", "memory://process-lifetime-legacy.cfg")
	first._initialize_runtime_settings()
	var first_report := first.get_runtime_settings_persistence_report()
	var settings_id := first.get_runtime_settings().get_instance_id()
	first.free()

	var recreated := GameFlow.new()
	recreated._initialize_runtime_settings()
	var recreated_report := recreated.get_runtime_settings_persistence_report()
	_check(
		first_report.identity_scope == &"process_lifetime"
		and recreated_report.identity_scope == &"process_lifetime"
		and int(recreated_report.store_instance_id) == int(first_report.store_instance_id)
		and int(recreated_report.adapter_instance_id) == int(first_report.adapter_instance_id)
		and recreated.get_runtime_settings().get_instance_id() == settings_id
		and int(recreated_report.load_attempt_count) == 1
		and is_equal_approx(recreated.get_runtime_settings().camera_fov, 83.0),
		"a destroyed and recreated production GameFlow adopts one process-lifetime settings/store/adapter without reloading"
	)
	recreated.free()


func _runtime_settings_commit_id(serial: int) -> String:
	return "runtime-settings-%010d" % serial


func _input_map_has_key(action: StringName, code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == code:
			return true
	return false


func _fleet_local_source_ids(game: GameFlow) -> PackedInt64Array:
	var result := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		result.append(fleet_ship.get_local_input_source().get_instance_id())
	return result


func _fleet_input_generations(game: GameFlow) -> PackedInt64Array:
	var result := PackedInt64Array()
	for fleet_ship: HeroShip in game.get_flyable_ships():
		result.append(fleet_ship.get_local_input_source().get_input_profile_generation())
	return result


func _fleet_profiles_match(game: GameFlow, expected: Dictionary) -> bool:
	for fleet_ship: HeroShip in game.get_flyable_ships():
		if fleet_ship.get_local_input_source().get_input_binding_profile().to_dictionary() != expected:
			return false
	return true


func _generations_advanced(
		before: PackedInt64Array,
		after: PackedInt64Array,
		expected_delta: int,
	) -> bool:
	if before.size() != after.size():
		return false
	for index: int in range(before.size()):
		if after[index] != before[index] + expected_delta:
			return false
	return true


func _restore_project_input_defaults() -> void:
	var settings := Settings.new(LEGACY_PATH)
	settings.reset_to_defaults()
	settings.apply_input_bindings()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("RUNTIME_SETTINGS_PRODUCTION_PERSISTENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr(
		"RUNTIME_SETTINGS_PRODUCTION_PERSISTENCE_TEST_FAILED: %s"
		% "; ".join(_failures)
	)
	quit(1)
