extends "res://tests/game_flow_scan_durable_recovery_test.gd"


func _run() -> void:
	await _backup_trust_reproduction()
	_finish()
	# Shared fixture retains the same failure exit and original route bounds.
	print("CINDER_SCAN_BACKUP_RECOVERY_TEST_OK: %d assertions" % _checks)
