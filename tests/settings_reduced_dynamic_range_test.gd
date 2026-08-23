extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := Settings.new("user://reduced_dynamic_range_settings_test.cfg")
	_check(not settings.reduced_dynamic_range, "reduced dynamic range defaults off")
	settings.reduced_dynamic_range = true
	_check(settings.reduced_dynamic_range, "reduced dynamic range accepts a validated change")
	var payload := settings.to_user_data_payload()
	_check(bool((payload.values as Dictionary).reduced_dynamic_range), "payload round-trips the new field")
	var restored := Settings.new("user://reduced_dynamic_range_settings_test.cfg")
	_check(bool(restored.apply_user_data_payload(payload).accepted), "current payload applies atomically")
	_check(restored.reduced_dynamic_range, "current payload restores enabled state")
	var legacy := payload.duplicate(true)
	legacy.schema_version = 1
	(legacy.values as Dictionary).erase("reduced_dynamic_range")
	var migrated := Settings.new("user://reduced_dynamic_range_settings_test.cfg")
	_check(bool(migrated.apply_user_data_payload(legacy).accepted), "legacy payload migrates successfully")
	_check(not migrated.reduced_dynamic_range, "legacy payload uses the default-off migration")
	restored.reset_to_defaults()
	_check(not restored.reduced_dynamic_range, "reset restores the default-off policy")
	var future := payload.duplicate(true)
	future.schema_version = Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION + 1
	_check(not bool(restored.apply_user_data_payload(future).accepted), "newer payload schemas fail closed")
	_check(not restored.reduced_dynamic_range, "rejected newer payload preserves live state")
	for failure in _failures:
		push_error(failure)
	print("settings_reduced_dynamic_range_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
