extends SceneTree

## Exactly one normal-resolution Forward+ frame of the production Main/HUD
## caption seam. Visual evidence only; this is not a performance benchmark.

const OUTPUT_PATH := "/tmp/caption-production-forward-plus.png"
const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const ISOLATED_STORE_PATH := "memory://caption-production-forward-settings.json"
const CHECK_ONLY_FLAG := "--check-only"

var _production_store_before: Dictionary = {}
var _isolated_filesystem: MemoryFilesystem
var _isolated_store: UserDataStore


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
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


func _initialize() -> void:
	_run()


func _run() -> void:
	_production_store_before = _production_store_snapshot()
	var game := await _find_production_main()
	if game != null:
		var existing_report := game.get_runtime_settings_persistence_report()
		if not bool(existing_report.injected_authority):
			_fail_closed("existing production Main has non-injected settings authority")
			return
	else:
		_isolated_filesystem = MemoryFilesystem.new()
		_isolated_store = Store.new(ISOLATED_STORE_PATH, _isolated_filesystem)
		game = MAIN_SCENE.instantiate() as GameFlow
		if not game.configure_runtime_settings_persistence(
			_isolated_store, "memory://caption-production-forward-legacy.cfg"
		):
			game.free()
			_fail_closed("isolated settings authority was rejected before startup")
			return
		root.add_child(game)
		await process_frame
		await physics_frame
		await process_frame
	var persistence_before := game.get_runtime_settings_persistence_report()
	if (
		not bool(persistence_before.injected_authority)
		or persistence_before.identity_scope != &"injected_main_lifetime"
		or int(persistence_before.store_instance_id) == 0
		or int(persistence_before.adapter_instance_id) == 0
	):
		_fail_closed(
			"caption capture did not retain one injected settings authority: %s"
			% str(persistence_before)
		)
		return
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var audio := game.get_node_or_null(^"AudioDirector") as AudioDirector
	if hud == null or audio == null:
		push_error("CAPTION_PRODUCTION_FORWARD_RENDER_FAILED: HUD/audio unavailable")
		quit(1)
		return

	# Force a deterministic empty caption queue before start_shift's UI-confirm
	# audio. The visual cue below is then the first and active service event.
	var runtime_settings := game.get_runtime_settings()
	var expected_save_delta := 0
	if runtime_settings.captions_enabled:
		expected_save_delta += 1
	hud.setting_change_requested.emit(&"captions_enabled", false)
	if runtime_settings.reduced_motion:
		expected_save_delta += 1
	hud.setting_change_requested.emit(&"reduced_motion", false)
	game.start_shift()
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set("_started", true)
	hud.set_ship_identity("Torrent-class Interceptor", "Interceptor")
	hud.set_mode("piloting")
	hud.set_objective("Destroy the 3 marked range drones outside the yard")
	hud.set_target_count(1, 3)
	hud.set_interaction("Hold course through the launch aperture", true)
	hud.set_enemy_status("Mudds range defence interceptor", 68.0, 100.0, true)
	hud.update_ship_telemetry({
		"speed": 118.0,
		"altitude": 142.0,
		"throttle": 0.72,
		"hull": 84.0,
		"maximum_hull": 100.0,
		"damage_status": "light damage",
		"engine_power": 0.86,
		"engine_state": "ONLINE",
	})
	if not is_equal_approx(runtime_settings.ui_scale, 1.15):
		expected_save_delta += 1
	hud.setting_change_requested.emit(&"ui_scale", 1.15)
	expected_save_delta += 1
	hud.setting_change_requested.emit(&"reduced_motion", true)
	expected_save_delta += 1
	hud.setting_change_requested.emit(&"captions_enabled", true)
	hud.toast("Hostile contact", "Range defence interceptor is engaging", 20.0)
	audio.play_combat_alert()
	if _check_only():
		await process_frame
		if not _verify_isolation(game, persistence_before, expected_save_delta):
			return
		print(
			"CAPTION_PRODUCTION_FORWARD_RENDER_CHECK_OK store_instance_id=",
			int(game.get_runtime_settings_persistence_report().store_instance_id),
			" production_bytes_preserved=true"
		)
		quit(0)
		return
	for _frame in 10:
		await process_frame
		await physics_frame
	if not _verify_isolation(game, persistence_before, expected_save_delta):
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUTPUT_PATH) != OK:
		push_error("CAPTION_PRODUCTION_FORWARD_RENDER_FAILED: image save")
		quit(1)
		return
	print(
		"CAPTION_PRODUCTION_FORWARD_RENDER_OK renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", image.get_size(),
		" caption=", hud.get_caption_presentation_report(),
		" panels=", hud.get_hud_panel_rects(),
		" path=", OUTPUT_PATH
	)
	quit(0)


func _find_production_main() -> GameFlow:
	for _attempt in 3:
		for child in root.get_children():
			if child is GameFlow:
				return child as GameFlow
		await process_frame
	return null


func _verify_isolation(game: GameFlow, before: Dictionary, expected_save_delta: int) -> bool:
	var after := game.get_runtime_settings_persistence_report()
	var save_attempt_delta := int(after.save_attempt_count) - int(before.save_attempt_count)
	var save_success_delta := int(after.save_success_count) - int(before.save_success_count)
	if (
		not bool(after.injected_authority)
		or int(after.store_instance_id) != int(before.store_instance_id)
		or int(after.adapter_instance_id) != int(before.adapter_instance_id)
		or save_success_delta != expected_save_delta
		or save_attempt_delta != save_success_delta
	):
		_fail_closed("caption capture settings transactions escaped or failed isolation")
		return false
	if _production_store_snapshot() != _production_store_before:
		_fail_closed("caption capture changed production user-data bytes")
		return false
	if _isolated_filesystem != null and not _isolated_filesystem.files.has(ISOLATED_STORE_PATH):
		_fail_closed("caption capture did not commit its isolated settings document")
		return false
	return true


func _production_store_snapshot() -> Dictionary:
	var snapshot := {}
	for path in [
		Adapter.DEFAULT_STORE_PATH,
		Adapter.DEFAULT_STORE_PATH + ".tmp",
		Adapter.DEFAULT_STORE_PATH + ".bak",
	]:
		var exists := FileAccess.file_exists(path)
		snapshot[path] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
		}
	return snapshot


func _check_only() -> bool:
	return CHECK_ONLY_FLAG in OS.get_cmdline_user_args()


func _fail_closed(reason: String) -> void:
	push_error("CAPTION_PRODUCTION_FORWARD_RENDER_FAILED: %s" % reason)
	quit(1)
