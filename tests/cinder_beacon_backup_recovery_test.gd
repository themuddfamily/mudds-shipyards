extends "res://tests/game_flow_beacon_durable_recovery_test.gd"


func _run() -> void:
	await _backup_trust_reproduction()
	_finish()
	# Reuse the genuine route fixture and its original bounds and failure exit.
	print("CINDER_BEACON_BACKUP_RECOVERY_TEST_OK: %d assertions" % _checks)
