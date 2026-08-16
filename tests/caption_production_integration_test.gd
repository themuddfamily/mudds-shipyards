extends SceneTree

## Focused production seam: real Main, one GameFlow-owned service, one authored
## presenter, request-only HUD routing, physics timing and whole-Main re-entry.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const ISOLATED_STORE_PATH := "memory://caption-production-integration-settings.json"

var _assertions := 0
var _failures: Array[String] = []
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
	_isolated_filesystem = MemoryFilesystem.new()
	_isolated_store = Store.new(ISOLATED_STORE_PATH, _isolated_filesystem)
	var game := MAIN_SCENE.instantiate() as GameFlow
	var configured := game.configure_runtime_settings_persistence(
		_isolated_store, "memory://caption-production-integration-legacy.cfg"
	)
	_check(configured, "caption integration injects isolated settings before startup")
	if not configured:
		game.free()
		await _finish_fixture(null)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var persistence := game.get_runtime_settings_persistence_report()
	_check(
		bool(persistence.injected_authority)
		and persistence.identity_scope == &"injected_main_lifetime"
		and int(persistence.store_instance_id) == _isolated_store.get_instance_id(),
		"caption integration retains the exact injected settings authority"
	)
	var hud := game.get_node_or_null(^"HUD") as GameHUD
	_check(hud != null, "production Main resolves the real GameHUD")
	if hud == null:
		await _finish_fixture(game)
		return

	var initial := game.get_caption_integration_report()
	var presenter_nodes := hud.find_children("*", "CaptionPresenter", true, false)
	_check(
		int(initial.service_count) == 1
		and int(initial.presenter_count) == 1
		and presenter_nodes.size() == 1
		and bool(initial.hud_request_sink_bound),
		"production owns exactly one service, one presenter and one live request binding"
	)
	var property_names := PackedStringArray()
	for property: Dictionary in hud.get_property_list():
		property_names.append(str(property.name))
	_check(
		not property_names.has("_caption_log")
		and not property_names.has("_caption_hold")
		and not property_names.has("_caption_panel"),
		"HUD retains no legacy caption history, wall-clock timer or duplicate panel state"
	)

	# Drive the authoritative settings signals used by the shipping pause panel.
	hud.setting_change_requested.emit(&"captions_enabled", true)
	hud.setting_change_requested.emit(&"reduced_motion", true)
	hud.setting_change_requested.emit(&"ui_scale", 1.6)
	hud.layout_for_viewport(Vector2(2560.0, 1440.0))
	await _settle()
	var scaled := hud.get_caption_presentation_report()
	_check(
		is_equal_approx(float(scaled.ui_scale), 1.6)
		and is_equal_approx(
			float(scaled.effective_safe_margin_bottom),
			GameHUD.CAPTION_BOTTOM_SAFE_LOGICAL * 1.6
		),
		"the production HUD passes the full supported 1.6 scale and exact reserved bottom band"
	)

	var audio := game.get_node_or_null(^"AudioDirector") as AudioDirector
	audio.play_target_destroyed()
	await _settle()
	var snapshot := game.get_caption_presentation_snapshot()
	var applied := hud.get_caption_presentation_snapshot()
	var visible_report := hud.get_caption_presentation_report()
	_check(
		bool(snapshot.visible)
		and snapshot == applied
		and snapshot.transition_policy == &"steady_no_flash"
		and snapshot.caption.category_id == &"system"
		and snapshot.caption.speaker == "Range control"
		and snapshot.caption.text == "[ range target destroyed ]",
		"a production audio cue becomes the service's validated reduced-flash presentation snapshot"
	)
	_check(
		bool(visible_report.visible)
		and str(visible_report.rendered_category) == "[ SYSTEM ]"
		and str(visible_report.rendered_speaker) == "Range control"
		and str(visible_report.rendered_text) == "[ range target destroyed ]"
		and not bool(visible_report.text_clipped),
		"HUD routes the snapshot through the speaker/category/text presenter without clipping"
	)
	(snapshot.caption as Dictionary)["text"] = "consumer mutation"
	(applied.caption as Dictionary)["speaker"] = "consumer mutation"
	_check(
		game.get_caption_presentation_snapshot().caption.text == "[ range target destroyed ]"
		and hud.get_caption_presentation_snapshot().caption.speaker == "Range control",
		"GameFlow and HUD return deeply detached caption snapshots"
	)
	var before_invalid := hud.get_caption_presentation_snapshot()
	var invalid := before_invalid.duplicate(true)
	invalid["service_id"] = &"lookalike"
	_check(
		not hud.apply_caption_presentation_snapshot(invalid)
		and hud.get_caption_presentation_snapshot() == before_invalid,
		"HUD rejects non-service lookalikes without mutating the visible presentation"
	)

	var parent := game.get_parent()
	var service_id := int(initial.service_instance_id)
	var presenter_id := int(initial.presenter_instance_id)
	var before_detach := game.get_caption_presentation_snapshot()
	parent.remove_child(game)
	await process_frame
	await process_frame
	var detached := game.get_caption_integration_report()
	_check(
		int(detached.service_instance_id) == service_id
		and int(detached.presenter_instance_id) == presenter_id
		and not bool(detached.hud_request_sink_bound)
		and game.get_caption_presentation_snapshot() == before_detach,
		"whole-Main detach freezes physics time, retains both instances and releases the HUD sink"
	)
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var reentered := game.get_caption_integration_report()
	var resumed := game.get_caption_presentation_snapshot()
	_check(
		int(reentered.service_instance_id) == service_id
		and int(reentered.presenter_instance_id) == presenter_id
		and bool(reentered.hud_request_sink_bound)
		and resumed.caption.stable_id == before_detach.caption.stable_id
		and float(resumed.caption.remaining_physics_seconds)
			<= float(before_detach.caption.remaining_physics_seconds),
		"re-entry rebinds the same service/presenter and resumes the retained active caption"
	)

	var accepted_before := int(reentered.caption_accepted_count)
	audio.play_combat_alert()
	await process_frame
	_check(
		int(game.get_caption_integration_report().caption_accepted_count) == accepted_before + 1,
		"production audio continues to enqueue through the restored binding"
	)
	hud.setting_change_requested.emit(&"captions_enabled", false)
	await process_frame
	var hidden := hud.get_caption_presentation_report()
	_check(
		not bool(game.get_caption_presentation_snapshot().visible)
		and not bool(hidden.visible)
		and bool(hidden.input_transparent),
		"disabling captions hides the presenter without exposing or duplicating service state"
	)
	var authority := game.get_caption_integration_report()
	_check(
		authority.physics_time_owner == &"game_flow"
		and authority.snapshot_boundary == &"validated_presentation_dictionary_only"
		and not bool(authority.legacy_hud_history)
		and not bool(authority.gameplay_authority)
		and not bool(authority.reward_authority)
		and not bool(authority.audio_authority)
		and not bool(authority.activity_authority)
		and not bool(authority.ship_authority)
		and not bool(authority.berth_authority),
		"caption integration remains presentation-only with GameFlow physics-time ownership"
	)
	var final_persistence := game.get_runtime_settings_persistence_report()
	_check(
		int(final_persistence.save_attempt_count) == 4
		and int(final_persistence.save_success_count) == 4
		and _isolated_filesystem.files.has(ISOLATED_STORE_PATH),
		"all four caption setting transactions commit only to the in-memory store"
	)
	_check(
		_production_store_snapshot() == _production_store_before,
		"caption integration preserves every production user-data byte"
	)

	await _finish_fixture(game)


func _settle() -> void:
	for _frame in 5:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


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


func _finish_fixture(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("CAPTION_PRODUCTION_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("CAPTION_PRODUCTION_INTEGRATION_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
