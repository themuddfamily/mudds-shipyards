## test-matrix-display: input-only
extends "res://tests/network/halyard_network_passenger_route_test.gd"

## The ordinary matrix runs the same real-peer shared journey harness.
func _run() -> void:
	_shared_cruise = true
	await super._run()


func _orchestrate() -> void:
	await super._orchestrate()
	if _failures.is_empty():
		print("HALYARD_NETWORK_SHARED_PLANETARY_CRUISE_TEST_OK")
