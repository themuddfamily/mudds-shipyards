## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_yaw_test.gd"

## HELM-PITCH turn/release source qualification through synthetic Godot
## InputEventAction events sampled by production LocalShipInputSource, not
## OS/hardware input or provider injection. Inherit the original three-process
## boarding, 5m departure/brake and all unchanged host-owned deadlines/identities.
## HeroShip rotates positive pitch about local RIGHT, unlike negative-sign yaw.
## Shared handback remains PARKED and is not a prerequisite or qualified here.
func _steering_profile() -> Dictionary:
	return {"axis": &"pitch", "actions": [&"pitch_up", &"pitch_down"], "directions": ["up", "down"],
		"command_signs": [1.0, -1.0], "rotation_axis": "right", "rotation_sign": 1.0}


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_pitch_test.gd"
	return profile


func _print_peer_success() -> void:
	# The inherited coordinator alone prints after all three actual OS exits0.
	print("JOVIAN_NETWORK_TWO_CLIENT_PITCH_OK checks=%d" % _checks)
