extends SceneTree

const Observer := preload("res://scripts/diagnostics/native_sortie_observer.gd")
var _failures := 0
var _assertions := 0

func _init() -> void:
	call_deferred(&"_run")

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	# These are detached diagnostic inputs, never damage/phase changes to a game.
	var craft := Node3D.new()
	var lead := Node3D.new()
	var wing := Node3D.new()
	var other := Node3D.new()
	var request := ShotRequest.new(craft, 1101, &"player", &"torrent_compact_pulse_cannon",
		12, Vector3.ZERO, Vector3.FORWARD, 2000.0, 20.0, 44)
	var result := {"request": request, "accepted": true, "resolved": true, "hit": true,
		"damaged": true, "source_entity": craft, "source_id": 1101, "target_entity": lead,
		"last_sequence": 12, "applied_damage": 20.0, "remaining_health": 0.0, "destroyed": true}
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_basis = Basis(Vector3.UP, 0.3)
	var aim := Observer.wing_aim_record(camera, result)
	_check(aim.camera_right == [camera.global_basis.x.x, camera.global_basis.x.y, camera.global_basis.x.z]
		and aim.camera_back == [camera.global_basis.z.x, camera.global_basis.z.y, camera.global_basis.z.z]
		and aim.request_origin == [0.0, 0.0, 0.0] and aim.request_direction == [0.0, 0.0, -1.0],
		"aim serialization copies actual optical axes and retained emitted shot request")
	camera.global_basis = Basis.IDENTITY
	_check(aim.camera_back != [0.0, 0.0, 1.0]
		and Observer.wing_aim_record(camera, {}).request_origin.is_empty()
		and Observer.wing_aim_record(camera, {}).request_direction.is_empty(),
		"aim record stays detached and absent requests never invent emitted rays")
	camera.free()
	var shot := Observer.wing_shot_record(result)
	shot["submitted_sequence"] = 12
	var members := [lead.get_instance_id(), wing.get_instance_id()]
	_check(shot.source_entity_id == craft.get_instance_id() and shot.target_entity_id == lead.get_instance_id()
		and shot.sequence == 12 and shot.presentation_receipt_id == 44 and shot.weapon_id == "torrent_compact_pulse_cannon"
		and shot.applied_damage == 20.0 and shot.remaining_health == 0.0 and shot.destroyed,
		"shot serialization preserves actual request/result identities and terminal damage")
	_check(Observer.wing_fresh_hit(shot, craft.get_instance_id(), 1101, members, 11, {}),
		"fresh target-specific positive registered player hit qualifies")
	_check(not Observer.wing_fresh_hit(shot, craft.get_instance_id(), 1101, members, 12, {}),
		"cached result at baseline cannot qualify again")
	_check(not Observer.wing_fresh_hit(shot, craft.get_instance_id(), 1101, members, 11, {44: true}),
		"duplicate presentation receipt cannot qualify")
	for mutation: Dictionary in [
		{"target_entity_id": other.get_instance_id()}, {"source_entity_id": other.get_instance_id()},
		{"request_source_entity_id": other.get_instance_id()}, {"source_id": 1102}, {"request_source_id": 1102},
		{"last_sequence": 13}, {"submitted_sequence": 13}, {"presentation_receipt_id": -1},
		{"weapon_id": ""}, {"applied_damage": 0.0}, {"hit": false}, {"damaged": false},
		{"accepted": false}, {"resolved": false}]:
		var changed := shot.duplicate(true)
		changed.merge(mutation, true)
		_check(not Observer.wing_fresh_hit(changed, craft.get_instance_id(), 1101, members, 11, {}),
			"foreign/stale/missing/undamaged receipt rejected: " + str(mutation))
	var second := shot.duplicate(true)
	second.merge({"target_entity_id": wing.get_instance_id(), "sequence": 13,
		"last_sequence": 13, "submitted_sequence": 13, "presentation_receipt_id": 45}, true)
	_check(Observer.wing_fresh_hit(second, craft.get_instance_id(), 1101, members, 12, {44: true}),
		"second actual member requires its own fresh source sequence and receipt")
	_check(not Observer.wing_fresh_hit(shot, craft.get_instance_id(), 0, members, 11, {}),
		"unregistered player cannot qualify a hit")
	craft.free()
	lead.free()
	wing.free()
	other.free()
	if _failures == 0:
		print("NATIVE_SORTIE_WING_OBSERVATION_TEST_OK (%d assertions)" % _assertions)
	quit(0 if _failures == 0 else 1)
