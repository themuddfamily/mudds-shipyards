extends "res://tests/cinder_mining_durable_recovery_test.gd"


func _run() -> void:
	# Reuse the genuine route fixture, its original bounds and failure exit.
	await _backup_trust_reproduction()
	for failure in _failures: push_error(failure)
	print("CINDER_MINING_BACKUP_RECOVERY_TEST_%s: %d assertions" % ["OK" if _failures.is_empty() else "FAILED", _assertions])
	quit(0 if _failures.is_empty() else 1)
