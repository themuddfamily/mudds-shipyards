extends SceneTree

## The on-foot player's first/third person choice.
##
## This is a player preference, not a situational override, and the difference is
## the whole point of these checks: the situation may suspend it (a seat owns the
## view; a boarding arc owns the body) and the situation may cap the boom (a
## 3.25 m flight deck cannot fit a 5.2 m arm), but nothing in the world is
## allowed to *forget* what the player asked for.
##
## Three things here are measured rather than asserted from a constant:
##  - the eye, which comes off the live rig's `head` joint and its bind crown, so
##    a future change to the suit's proportions moves the camera with it instead
##    of leaving it riding at a stale height;
##  - the avatar's disappearance, which is a per-camera render-layer decision, so
##    a second observer still sees the pilot;
##  - the boom, which must return to the cabin ceiling and not to the open-deck
##    request when third person resumes inside a hull.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

## Independently authored eye evidence. The legacy blockout rig puts its visor at
## 1.740 + 0.005 m, which was authored by hand and never derived from the
## imported Blender rig. If the rig-measured eye and this disagree by more than a
## couple of centimetres then one of the two authorities has moved and the camera
## is riding the wrong head.
const AUTHORED_BLOCKOUT_VISOR_HEIGHT := 1.745
const EYE_CROSS_CHECK_TOLERANCE := 0.03

## The suit's bind bounds, from the asset contract. Used only to bracket the
## measured eye: an eye outside the body is a defect no tolerance should absorb.
const SUIT_STANDING_HEIGHT := 1.945

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_eye_comes_from_the_rig()
	await _test_toggle_moves_the_camera_to_the_eye()
	await _test_avatar_is_hidden_from_this_camera_only()
	await _test_cabin_containment_and_first_person_do_not_fight()
	await _test_cabin_containment_currentness()
	await _test_seat_suspends_and_restores_without_losing_the_choice()
	await _test_binding_is_bound_and_documented()
	await process_frame
	_finish()


## The eye is derived, not written down.
func _test_eye_comes_from_the_rig() -> void:
	var player := await _spawn_player()
	var report: Dictionary = player.get_camera_view_report()
	var eye: Vector3 = report.get("eye_pivot", Vector3.ZERO)
	_check(
		bool(report.get("eye_pivot_measured", false)),
		"the first-person eye was measured off the live rig rather than defaulted"
	)
	_check(
		eye.y > 0.0 and eye.y < SUIT_STANDING_HEIGHT,
		"the eye sits inside the suit's own standing height (%.4f m)" % eye.y
	)
	_check(
		absf(eye.y - AUTHORED_BLOCKOUT_VISOR_HEIGHT) <= EYE_CROSS_CHECK_TOLERANCE,
		"the rig-measured eye (%.4f m) agrees with the independently authored visor (%.3f m)"
			% [eye.y, AUTHORED_BLOCKOUT_VISOR_HEIGHT]
	)
	# The eye must be on the body's own vertical axis. Anything else would make a
	# yaw of the presentation mount swing the camera sideways.
	_check(
		is_zero_approx(eye.x) and is_zero_approx(eye.z),
		"the eye rides the body's own vertical axis"
	)
	var third: Vector3 = report.get("third_person_pivot", Vector3.ZERO)
	_check(
		eye.y > third.y,
		"the eye is above the authored chase pivot (%.3f m vs %.3f m)" % [eye.y, third.y]
	)
	player.queue_free()
	await process_frame


func _test_toggle_moves_the_camera_to_the_eye() -> void:
	var player := await _spawn_player()
	_check(
		not player.is_first_person_active(),
		"the on-foot view starts in the authored third person"
	)
	player.toggle_camera_view_mode()
	_check(player.is_first_person_active(), "the toggle selects first person")
	await _settle(90)
	var report: Dictionary = player.get_camera_view_report()
	var eye: Vector3 = report.get("eye_pivot", Vector3.ZERO)
	var pivot: Vector3 = report.get("camera_pivot", Vector3.ZERO)
	_check(
		pivot.distance_to(eye) < 0.01,
		"the camera rig settles on the eye (%.4f m away)" % pivot.distance_to(eye)
	)
	_check(
		float(report.get("spring_length", 1.0)) < 0.01,
		"the chase boom collapses to nothing in first person"
	)
	# The neck, not the boom, sets the pitch range once there is no boom to clear.
	_check(
		float(report.get("pitch_minimum_degrees", 0.0)) < -80.0
		and float(report.get("pitch_maximum_degrees", 0.0)) > 80.0,
		"first person opens the pitch range a neck actually has"
	)
	player.toggle_camera_view_mode()
	_check(
		not player.is_first_person_active(),
		"the same binding returns the player to third person"
	)
	await _settle(90)
	report = player.get_camera_view_report()
	pivot = report.get("camera_pivot", Vector3.ZERO)
	var third: Vector3 = report.get("third_person_pivot", Vector3.ZERO)
	_check(
		pivot.distance_to(third) < 0.02,
		"the camera rig returns to the authored chase pivot"
	)
	_check(
		float(report.get("spring_length", 0.0)) > 4.0,
		"the chase boom grows back to the authored framing (%.2f m)"
			% float(report.get("spring_length", 0.0))
	)
	_check(
		not bool(report.get("avatar_self_culled", true)),
		"the avatar is drawn again for its own camera in third person"
	)
	player.queue_free()
	await process_frame


## The pilot disappears for this camera and for no other. If this were done with
## `visible` it would remove him from the craft's chase camera and from a second
## occupant's view too, and it would trip the suit's own integrity contract.
func _test_avatar_is_hidden_from_this_camera_only() -> void:
	var player := await _spawn_player()
	var camera: Camera3D = player.get_camera()
	var authored_mask := camera.cull_mask
	player.toggle_camera_view_mode()
	await _settle(90)
	var report: Dictionary = player.get_camera_view_report()
	var cull_layer := int(report.get("avatar_cull_layer_mask", 0))
	_check(
		bool(report.get("avatar_self_culled", false)),
		"the avatar is culled once the camera has reached the eye"
	)
	_check(
		(camera.cull_mask & cull_layer) == 0,
		"this player's own camera has stopped looking at the avatar's layer"
	)
	var visible_parts := 0
	var parts: Array = player.get_pilot_visual_parts()
	for part: MeshInstance3D in parts:
		_check(
			part.visible and part.is_visible_in_tree(),
			"%s stays visible -- hiding is per observer, never per node" % part.name
		)
		if (part.layers & cull_layer) != 0:
			visible_parts += 1
		# Any other camera in the project keeps Godot's default all-layers mask.
		_check(
			(part.layers & 0xFFFFF) != 0,
			"%s is still drawn by a default all-layers observer" % part.name
		)
	_check(
		parts.size() > 0 and visible_parts == parts.size(),
		"every visible avatar mesh moved onto the self-view layer (%d of %d)"
			% [visible_parts, parts.size()]
	)
	# A second observer standing in the same scene still sees the pilot walk.
	var observer := Camera3D.new()
	root.add_child(observer)
	await process_frame
	var observer_sees_all := true
	for part: MeshInstance3D in parts:
		if (observer.cull_mask & part.layers) == 0:
			observer_sees_all = false
	_check(
		observer_sees_all,
		"a second observer's default camera still renders the pilot"
	)
	# The suit keeps casting its shadow, so a first-person player still sees
	# himself on the deck.
	for part: MeshInstance3D in parts:
		_check(
			part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"%s keeps casting its shadow while culled" % part.name
		)
	player.toggle_camera_view_mode()
	await _settle(90)
	_check(
		camera.cull_mask == authored_mask,
		"the camera's authored cull mask is restored exactly"
	)
	for part: MeshInstance3D in parts:
		_check(
			(part.layers & cull_layer) == 0,
			"%s is back on its authored render layer" % part.name
		)
	_check(
		player.validate_pilot_motion_authority(),
		"the pilot's own integrity contract survives a full first-person round trip"
	)
	observer.queue_free()
	player.queue_free()
	await process_frame


## Cabin containment caps the boom because a 3.25 m flight deck cannot hold a
## 5.2 m arm. First person is shorter still, so it wins -- but it must win by
## being shortest, not by overwriting the cap. Switching back inside the cabin
## has to land on the cabin ceiling, not on the open-deck request.
func _test_cabin_containment_and_first_person_do_not_fight() -> void:
	var player := await _spawn_player()
	var frame := Node3D.new()
	root.add_child(frame)
	await process_frame
	player.set_cabin_containment(frame, AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8)), player.global_transform)
	await _settle(90)
	var interior_distance: float = player.get_target_camera_distance()
	_check(
		interior_distance < player.get_requested_camera_distance(),
		"cabin containment still shortens the boom (%.2f m under a %.2f m request)"
			% [interior_distance, player.get_requested_camera_distance()]
	)
	player.toggle_camera_view_mode()
	await _settle(90)
	var report: Dictionary = player.get_camera_view_report()
	_check(
		is_zero_approx(float(report.get("target_camera_distance", 1.0))),
		"first person is shorter than the cabin ceiling and takes the boom to zero"
	)
	_check(
		is_equal_approx(float(report.get("camera_distance_ceiling", 0.0)), interior_distance)
		and is_equal_approx(
			float(report.get("requested_camera_distance", 0.0)),
			player.get_requested_camera_distance()
		),
		"neither the cabin ceiling nor the player's zoom request was overwritten"
	)
	_check(
		player.is_cabin_containment_active(),
		"containment itself is untouched by the view mode"
	)
	player.toggle_camera_view_mode()
	await _settle(90)
	_check(
		is_equal_approx(player.get_target_camera_distance(), interior_distance),
		"third person inside the cabin returns to the cabin ceiling, not the open-deck request"
	)
	player.clear_cabin_containment()
	await _settle(90)
	_check(
		player.get_target_camera_distance() > interior_distance,
		"leaving the cabin still restores the player's own framing"
	)
	frame.queue_free()
	player.queue_free()
	await process_frame


func _test_cabin_containment_currentness() -> void:
	var player := await _spawn_player() as PlayerController
	var frame := Node3D.new()
	root.add_child(frame)
	await process_frame
	var bounds := AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8))
	_check(
		player.set_cabin_containment(frame, bounds, player.global_transform),
		"currentness fixture accepts attached cabin containment"
	)
	var parent := player.get_parent()
	parent.remove_child(player)
	await process_frame
	var detached_containment := player.get_cabin_containment_report()
	var detached_view := player.get_camera_view_report()
	player.clear_cabin_containment()
	_check(
		not player.set_cabin_containment(frame, AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)), Transform3D.IDENTITY)
		and not player.is_inside_tree()
		and not bool(detached_containment.active)
		and not bool(detached_containment.contained)
		and player.get_cabin_containment_report() == detached_containment
		and player.get_camera_view_report() == detached_view,
		"detached player rejects stale cabin changes without containment or camera drift"
	)
	parent.add_child(player)
	await process_frame
	var detached_frame := Node3D.new()
	root.add_child(detached_frame)
	await process_frame
	root.remove_child(detached_frame)
	await process_frame
	var frame_rejection_containment := player.get_cabin_containment_report()
	var frame_rejection_view := player.get_camera_view_report()
	_check(
		not player.set_cabin_containment(detached_frame, bounds, player.global_transform)
		and player.get_cabin_containment_report() == frame_rejection_containment
		and player.get_camera_view_report() == frame_rejection_view,
		"attached player rejects a detached cabin frame without containment or camera drift"
	)
	var queued_frame := Node3D.new()
	root.add_child(queued_frame)
	await process_frame
	queued_frame.queue_free()
	_check(
		not player.set_cabin_containment(queued_frame, bounds, player.global_transform)
		and player.get_cabin_containment_report() == frame_rejection_containment
		and player.get_camera_view_report() == frame_rejection_view,
		"attached player rejects a queued cabin frame without containment or camera drift"
	)
	detached_frame.queue_free()
	await process_frame
	player.clear_cabin_containment()
	_check(
		not player.is_cabin_containment_active()
		and player.set_cabin_containment(frame, bounds, player.global_transform),
		"re-added player accepts fresh cabin clear and set requests"
	)
	player.queue_free()
	var queued_containment := player.get_cabin_containment_report()
	var queued_view := player.get_camera_view_report()
	player.clear_cabin_containment()
	_check(
		player.is_inside_tree()
		and player.is_queued_for_deletion()
		and not player.set_cabin_containment(frame, AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)), Transform3D.IDENTITY)
		and not bool(queued_containment.active)
		and not bool(queued_containment.contained)
		and player.get_cabin_containment_report() == queued_containment
		and player.get_camera_view_report() == queued_view,
		"queued player rejects stale cabin changes without containment or camera drift"
	)
	await process_frame
	_check(not is_instance_valid(player), "queued cabin-currentness fixture frees normally")
	frame.queue_free()
	await process_frame


## Entering a vehicle in first person and coming back out again.
func _test_seat_suspends_and_restores_without_losing_the_choice() -> void:
	var player := await _spawn_player()
	player.toggle_camera_view_mode()
	await _settle(90)
	_check(player.is_first_person_active(), "the player boards in first person")

	var seat := Node3D.new()
	root.add_child(seat)
	seat.global_position = Vector3(0.0, 0.6, -3.0)
	await process_frame
	_check(
		player.begin_boarding(player.global_transform, seat, 0.0),
		"the first-person player can still board"
	)
	await player.boarding_completed
	await _settle(90)
	var report: Dictionary = player.get_camera_view_report()
	_check(
		bool(report.get("suspended", false)) and not player.is_first_person_active(),
		"a seated pilot's view belongs to the craft, so first person is suspended"
	)
	_check(
		bool(report.get("first_person_chosen", false)),
		"the player's choice is suspended, never forgotten"
	)
	_check(
		not bool(report.get("avatar_self_culled", true)),
		"the seated pilot is drawn again -- a craft may carry more than one occupant"
	)

	var exit_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	_check(player.begin_disembark(exit_transform, 0.0), "the player can hop back out")
	await player.disembarking_completed
	await _settle(90)
	report = player.get_camera_view_report()
	_check(
		player.is_first_person_active() and not bool(report.get("suspended", true)),
		"standing back up resumes first person by itself"
	)
	var eye: Vector3 = report.get("eye_pivot", Vector3.ZERO)
	_check(
		Vector3(report.get("camera_pivot", Vector3.ZERO)).distance_to(eye) < 0.01,
		"the resumed view is back on the eye rather than stuck between the two"
	)
	_check(
		bool(report.get("avatar_self_culled", false)),
		"the avatar is culled again for its own camera"
	)
	seat.queue_free()
	player.queue_free()
	await process_frame


## A binding a player cannot find is the same defect as no binding at all.
func _test_binding_is_bound_and_documented() -> void:
	_check(
		InputMap.has_action(&"toggle_first_person"),
		"the view toggle is a real InputMap action rather than a raw key read"
	)
	var has_key := false
	var has_pad := false
	for event: InputEvent in InputMap.action_get_events(&"toggle_first_person"):
		if event is InputEventKey:
			has_key = true
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			has_pad = true
	_check(has_key, "the view toggle has a keyboard binding")
	_check(has_pad, "the view toggle is reachable from the gamepad")

	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	var hud: Node = hud_script.new()
	root.add_child(hud)
	await process_frame
	hud.set_mode("on foot")
	await process_frame
	var documented := false
	for label: Label in _labels(hud):
		if label.text.contains("1ST / 3RD PERSON"):
			documented = true
	_check(documented, "the on-foot controls card documents the view toggle")
	hud.queue_free()
	await process_frame


func _spawn_player() -> Node3D:
	var scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Node3D = scene.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	return player


## Runs enough frames for the camera eases to converge. The eases are
## exponential rather than timed, so this is a convergence budget, not a
## duration: 90 frames leaves both the boom and the pivot inside a millimetre.
func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node as Label)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		print("FAIL: ", description)


func _finish() -> void:
	print("first person view assertions: ", _assertions)
	if _failures.is_empty():
		print("FIRST_PERSON_VIEW_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("FIRST_PERSON_VIEW_TEST_FAILURE: ", failure)
	print("FIRST_PERSON_VIEW_TEST_FAILED: ", _failures.size())
	quit(1)
