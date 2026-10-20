## test-matrix-display: input-only
extends "res://tests/network/jovian_network_two_client_yaw_test.gd"

## HELM-ROLL-RATE turn/release through synthetic Godot InputEventAction events
## sampled by production LocalShipInputSource, not OS/hardware input or provider
## injection. Inherit original three-process boarding, 5m departure/brake and all
## unchanged host-owned deadlines/identities. This holds roll rate, not G barrel roll.
## HeroShip rotates positive roll about FORWARD (-Z): measure actual up about nose.
## Shared handback remains PARKED and is neither retried nor qualified here.
func _steering_profile() -> Dictionary:
	return {"axis": &"roll", "actions": [&"roll_left", &"roll_right"], "directions": ["left", "right"],
		"command_signs": [-1.0, 1.0], "rotation_axis": "nose", "rotation_sign": 1.0, "measured_vector": "up"}


func _peer_profile() -> Dictionary:
	var profile := super._peer_profile()
	profile["script"] = "res://tests/network/jovian_network_two_client_roll_rate_test.gd"
	return profile


func _print_peer_success() -> void:
	# The inherited coordinator alone prints after all three actual OS exits0.
	print("JOVIAN_NETWORK_TWO_CLIENT_ROLL_RATE_OK checks=%d" % _checks)
