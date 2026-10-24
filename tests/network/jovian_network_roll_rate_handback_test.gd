## test-matrix-display: input-only
extends "res://tests/network/jovian_network_pilot_handback_test.gd"

## HELM-ROLL-RATE: inherit the full physical three-process Jovian route, both
## roll-rate turns and neutral replica convergence, then ordinary pilot Interact
## handback and supported cabin walk. Synthetic InputEventAction events only;
## the shared caller retains all clocks, identities and zero barrel-roll fences.
## Measure actual up about nose, matching the accepted roll-rate turn profile.
func _steering_profile() -> Dictionary:
	return {"axis": &"roll", "actions": [&"roll_left", &"roll_right"], "directions": ["left", "right"],
		"command_signs": [-1.0, 1.0], "rotation_axis": "nose", "rotation_sign": 1.0, "measured_vector": "up"}


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_roll_rate_handback_test.gd"
	return profile


func _print_peer_success() -> void:
	# The inherited coordinator alone prints after all three actual OS exits0.
	print("JOVIAN_NETWORK_ROLL_RATE_HANDBACK_OK checks=%d" % _checks)
