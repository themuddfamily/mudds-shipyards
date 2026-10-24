## test-matrix-display: input-only
extends "res://tests/network/jovian_network_pilot_handback_test.gd"

## HELM-PITCH-HANDBACK: inherit the complete physical three-process boarding,
## departure/brake, both signed turns and fresh neutral replica checks, followed
## by ordinary pilot Interact, supported cabin walking and source retirement.
## Only synthetic Godot InputEventAction events drive the production input source.
## HeroShip rotates positive pitch about local RIGHT, unlike negative-sign yaw.
func _steering_profile() -> Dictionary:
	return {"axis": &"pitch", "actions": [&"pitch_up", &"pitch_down"], "directions": ["up", "down"],
		"command_signs": [1.0, -1.0], "rotation_axis": "right", "rotation_sign": 1.0}


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_pitch_handback_test.gd"
	return profile


func _print_peer_success() -> void:
	# The inherited coordinator alone prints after all three actual OS exits0.
	print("JOVIAN_NETWORK_PITCH_HANDBACK_OK checks=%d" % _checks)
