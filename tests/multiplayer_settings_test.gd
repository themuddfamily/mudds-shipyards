extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")

var _failures: PackedStringArray = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := Settings.new("user://multiplayer_settings_test.cfg")
	_check(settings.multiplayer_display_name == "Pilot", "display name has a bounded default")
	_check(settings.network_default_port == 27101, "default host/join port is stable")
	_check(settings.multiplayer_max_players == 8, "host capacity has a bounded default")
	settings.multiplayer_display_name = "  Survey Team  "
	settings.network_default_port = 65535
	settings.multiplayer_max_players = 32
	_check(settings.multiplayer_display_name == "Survey Team", "display name trims presentation whitespace")
	_check(settings.network_default_port == 65535, "port accepts the upper bound")
	_check(settings.multiplayer_max_players == 32, "host capacity accepts the upper bound")
	settings.multiplayer_display_name = ""
	settings.network_default_port = 99999
	settings.multiplayer_max_players = 99
	_check(settings.multiplayer_display_name == "Pilot", "empty display names fall back safely")
	_check(settings.network_default_port == 65535, "port setter clamps to its upper bound")
	_check(settings.multiplayer_max_players == 32, "host capacity clamps to its upper bound")
	var payload := settings.to_user_data_payload()
	_check(int(payload.schema_version) == Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION, "payload advertises current schema")
	var roundtrip := Settings.new("user://multiplayer_settings_roundtrip.cfg")
	var result := roundtrip.apply_user_data_payload(payload)
	_check(bool(result.accepted), "current payload applies atomically")
	_check(roundtrip.to_dictionary().get("network_default_port") == 65535, "server-browser defaults are exposed in snapshots")
	var legacy := payload.duplicate(true)
	legacy.schema_version = 3
	(legacy.values as Dictionary).erase("multiplayer_display_name")
	(legacy.values as Dictionary).erase("network_default_port")
	(legacy.values as Dictionary).erase("multiplayer_max_players")
	var migrated := Settings.new("user://multiplayer_settings_migrated.cfg")
	var migration := migrated.apply_user_data_payload(legacy)
	_check(bool(migration.accepted), "schema 3 payload migrates without network fields")
	_check(migrated.multiplayer_display_name == "Pilot" and migrated.network_default_port == 27101, "migration uses authored network defaults")
	_check(migrated.multiplayer_max_players == 8, "schema 4 migration uses authored host capacity")
	settings.multiplayer_display_name = "Dockmaster"
	settings.network_default_port = 28001
	settings.multiplayer_max_players = 12
	var save_path := "user://multiplayer_settings_persisted.cfg"
	_check(settings.save_to_file(save_path) == OK, "network defaults save through the transactional settings boundary")
	var loaded := Settings.new(save_path)
	_check(loaded.load_from_file() == OK, "network defaults load from the settings file")
	_check(loaded.multiplayer_display_name == "Dockmaster" and loaded.network_default_port == 28001 and loaded.multiplayer_max_players == 12, "network defaults persist exactly")
	migrated.reset_to_defaults()
	_check(migrated.multiplayer_display_name == "Pilot" and migrated.network_default_port == 27101, "reset restores network defaults")
	if _failures.is_empty():
		print("MULTIPLAYER_SETTINGS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
