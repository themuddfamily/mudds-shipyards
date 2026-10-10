extends "res://tests/cinder_patrol_session_save_restore_test.gd"


func _run() -> void:
	await _test_platform_patrol_fallback_refusal()
	_finish()
	# Inherited finish preserves the shared fixture's exact failure exit code.
	print("CINDER_PATROL_BACKUP_RECOVERY_TEST_OK: %d assertions" % _assertions)
