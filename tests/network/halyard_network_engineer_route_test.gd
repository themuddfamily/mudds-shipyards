## test-matrix-display: input-only
extends "jovian_network_engineer_route_test.gd"

## The recursive matrix runs the existing real-peer engineer route for Halyard.
## Relative inheritance also resolves the external test fixture beside this
## wrapper when production res:// resources belong to an actual exported pack.
func _run() -> void:
	_halyard = true
	await super._run()


func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var args := super._peer_arguments(role, display)
	# Source peers enter the same wrapper. Packed peers retain the external
	# wrapper selected by the base harness, together with the Halyard flag.
	if _package_under_test.is_empty():
		var script_index := args.find("--script")
		args[script_index + 1] = "res://tests/network/halyard_network_engineer_route_test.gd"
	return args


func _orchestrate() -> void:
	await super._orchestrate()
	if _failures.is_empty():
		print("HALYARD_NETWORK_ENGINEER_ROUTE_TEST_OK")
