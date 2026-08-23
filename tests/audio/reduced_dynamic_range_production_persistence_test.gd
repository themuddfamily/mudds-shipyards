extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Director := preload("res://scripts/audio/audio_director.gd")
const Flow := preload("res://scripts/game/game_flow.gd")
const STORE_PATH := "user://reduced_dynamic_range_production_test.json"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var authored := Settings.new("user://reduced_dynamic_range_production_legacy.cfg")
	authored.reduced_dynamic_range = true
	var adapter := Adapter.new(authored, Store.new(STORE_PATH))
	_check(bool(adapter.save("reduced-range-production").accepted), "settings store commits enabled policy")
	var restored := Settings.new("user://reduced_dynamic_range_production_legacy.cfg")
	var restored_adapter := Adapter.new(restored, Store.new(STORE_PATH))
	_check(bool(restored_adapter.load().accepted), "settings store loads enabled policy")
	_check(restored.reduced_dynamic_range, "loaded authority retains enabled policy")
	var director := Director.new()
	var flow := Flow.new()
	flow.runtime_settings = restored
	flow.audio = director
	_check(bool(flow._apply_reduced_dynamic_range_setting().accepted), "GameFlow applies loaded policy to audio")
	_check(bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "AudioDirector receives loaded policy")
	root.add_child(director)
	await process_frame
	root.remove_child(director)
	await process_frame
	root.add_child(director)
	await process_frame
	_check(bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "policy survives audio detach and re-entry")
	restored.reset_to_defaults()
	flow._on_runtime_setting_changed(&"reduced_dynamic_range", false)
	_check(not bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "reset reaches audio immediately")
	var future := authored.to_user_data_payload()
	future.schema_version = Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1
	_check(not bool(restored.apply_user_data_payload(future).accepted), "newer payload fails closed")
	_check(not restored.reduced_dynamic_range, "failed payload preserves reset authority")
	_check(not bool(director.get_dynamic_mix_plan().reduced_dynamic_range), "failed payload cannot re-enable audio policy")
	root.remove_child(director)
	director.free()
	flow.free()
	_cleanup()
	for failure in _failures:
		push_error(failure)
	print("reduced_dynamic_range_production_persistence_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _cleanup() -> void:
	for path in [STORE_PATH, STORE_PATH + ".tmp", STORE_PATH + ".bak"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
