extends SceneTree

const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const Recovery := preload("res://scripts/recovery/safe_start_production_recovery.gd")
const Binding := preload("res://scripts/recovery/safe_start_audio_recovery_binding.gd")

var _assertions := 0
var _failures: Array[String] = []
var _persist_ok := true
var _persist_calls := 0


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		if not files.has(path): return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": (files[path] as PackedByteArray).duplicate()}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path): return ERR_FILE_CANT_WRITE
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _initialize() -> void:
	_run()


func _run() -> void:
	await _test_apply_restore_and_reentry()
	await _test_persistence_rejection_rolls_back()
	_finish()


func _make_ready_fixture() -> Dictionary:
	var filesystem := FakeFilesystem.new()
	var settings := Settings.new("memory://audio-binding.cfg")
	var store := Store.new("memory://audio-binding.json", filesystem)
	var adapter := Adapter.new(settings, store, "memory://audio-binding.cfg")
	var latest: Dictionary = {}
	for _attempt in 4:
		latest = adapter.load()
		var recovery := Recovery.new(settings, store, true)
		recovery.initialize(latest, Callable(self, &"_persist_settings"))
		if _attempt == 3:
			return {"filesystem": filesystem, "settings": settings, "store": store, "adapter": adapter, "recovery": recovery}
	return {}


func _persist_settings() -> Dictionary:
	_persist_calls += 1
	if not _persist_ok:
		return {"accepted": false, "reason": &"injected_failure"}
	return {"accepted": true, "reason": &"persisted"}


func _test_apply_restore_and_reentry() -> void:
	_persist_ok = true
	var fixture := _make_ready_fixture()
	var recovery := fixture["recovery"] as SafeStartProductionRecovery
	var settings := fixture["settings"] as RuntimeSettings
	var before := settings.to_user_data_payload()
	var binding := Binding.new()
	var generation := int(recovery.get_report().get("startup_generation", -1))
	_check(bool(binding.configure(recovery, Callable(self, &"_persist_settings"), generation).accepted), "binding configures with caller persistence seam")
	_check(bool(binding.get_recommendation().accepted), "third unfinished startup exposes bounded audio recommendation")
	var applied := binding.apply_fallback()
	_check(bool(applied.accepted) and applied.reason == &"audio_fallback_applied", "caller applies device-neutral audio fallback")
	_check(settings.to_user_data_payload().values.master_volume == 0.5 and settings.to_user_data_payload().values.music_volume == 0.0, "fallback applies only bounded master/music values")
	_check(not bool(binding.apply_fallback().accepted), "fallback receipt rejects replay")
	recovery.advance_physics(5.0)
	var restored := binding.restore_after_stable()
	_check(bool(restored.accepted) and restored.reason == &"prior_audio_profile_restored", "stable caller restores prior audio profile")
	_check(settings.to_user_data_payload().values == before.values, "restore preserves the complete prior audio/settings payload")
	binding.set_attached(false)
	_check(not bool(binding.restore_after_stable().accepted), "detached binding rejects recovery calls")
	binding.set_attached(true)
	_check(bool(binding.get_report().attached), "re-entry retains detached binding state without replay")


func _test_persistence_rejection_rolls_back() -> void:
	_persist_ok = false
	var fixture := _make_ready_fixture()
	var recovery := fixture["recovery"] as SafeStartProductionRecovery
	var settings := fixture["settings"] as RuntimeSettings
	var before := settings.to_user_data_payload()
	var binding := Binding.new()
	var generation := int(recovery.get_report().get("startup_generation", -1))
	binding.configure(recovery, Callable(self, &"_persist_settings"), generation)
	var rejected := binding.apply_fallback()
	_check(not bool(rejected.accepted) and rejected.reason == &"audio_fallback_save_failed", "persistence rejection fails closed")
	_check(settings.to_user_data_payload() == before, "failed persistence rolls live audio settings back atomically")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("SAFE_START_AUDIO_RECOVERY_BINDING_TEST_OK: %d assertions" % _assertions)
	else:
		push_error("SAFE_START_AUDIO_RECOVERY_BINDING_TEST_FAILED: " + "; ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
