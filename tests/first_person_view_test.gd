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
	await _test_focused_gameplay_camera_input()
	await _test_gamepad_camera_look()
	await _test_ultrawide_policy_reaches_the_on_foot_rig()
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
	# Re-baseline after the frame above. What this check proves is that the
	# rejected call changes nothing, so the comparison has to be against the
	# state immediately before that call. Reusing the pre-`await` baseline made
	# it a claim that no frame had elapsed, which is not true and not the point:
	# `get_camera_view_report()` publishes the spring arm's live `spring_length`,
	# and that eases toward its target every frame, so under a loaded matrix run
	# the extra frame moved it and this assertion failed for the wrong reason.
	var queued_rejection_containment := player.get_cabin_containment_report()
	var queued_rejection_view := player.get_camera_view_report()
	_check(
		not player.set_cabin_containment(queued_frame, bounds, player.global_transform)
		and player.get_cabin_containment_report() == queued_rejection_containment
		and player.get_camera_view_report() == queued_rejection_view,
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
	for kind: StringName in [&"tutorial", &"activity_tutorial"]:
		hud.set_runtime_status_card(kind, {
			"title": "Camera input regression",
			"actions": [{"id": &"continue", "label": "Continue"}],
		})
		var tutorial_action := hud.find_child("RuntimeStatusContinueButton", true, false) as Control
		_check(tutorial_action != null and tutorial_action.is_in_group(&"gameplay_input_passthrough"),
			"%s actions explicitly preserve captured gameplay input" % kind)
		hud.clear_runtime_status_card(kind)
	await _test_help_keeps_focus_over_tutorial_updates(hud)
	hud.queue_free()
	await process_frame


func _test_help_keeps_focus_over_tutorial_updates(hud: Node) -> void:
	var restore_mouse_mode := Input.mouse_mode
	var begin_binding: InputEventKey
	var help_binding: InputEventKey
	var camera_binding: InputEventJoypadButton
	for binding: InputEvent in InputMap.action_get_events(&"interact"):
		if binding is InputEventKey:
			begin_binding = binding as InputEventKey
	for binding: InputEvent in InputMap.action_get_events(&"toggle_controls_overlay"):
		if binding is InputEventKey:
			help_binding = binding as InputEventKey
	for binding: InputEvent in InputMap.action_get_events(&"toggle_first_person"):
		if binding is InputEventJoypadButton:
			camera_binding = binding as InputEventJoypadButton
	_check(begin_binding != null and help_binding != null and camera_binding != null,
		"help focus regression uses current native Begin, Help and camera bindings")
	if begin_binding == null or help_binding == null or camera_binding == null:
		return
	await _tap_camera_binding(begin_binding)
	await create_timer(GameHUD.INTRO_FADE_SECONDS + 0.1).timeout
	var player := await _spawn_player()
	var help_panel := hud.get("_help_panel") as Control
	var close := hud.find_child("HelpCloseButton", true, false) as Control
	_check(help_panel.visible, "ordinary Begin retains the authored default controls card")
	hud.set_runtime_status_card(&"tutorial", {
		"title": "Tutorial over the passive default controls card",
		"actions": [{"id": &"continue", "label": "Continue"}],
	})
	await process_frame
	var default_action := hud.find_child("RuntimeStatusContinueButton", true, false) as Control
	_check(default_action != null and default_action.has_focus(),
		"tutorial publication claims its real action focus while the default controls card is passive")
	hud.clear_runtime_status_card(&"tutorial")
	for kind: StringName in [&"tutorial", &"activity_tutorial"]:
		# The previous native D-pad check may navigate to another control.
		# Reopen through the real binding so each publication starts from the
		# same Help-owned focus, rather than assuming focus cannot move.
		if help_panel.visible:
			await _tap_camera_binding(help_binding)
		await _tap_camera_binding(help_binding)
		_check(help_panel.visible and close != null and close.has_focus(),
			"native Help opening focuses its real Close control before %s" % kind)
		hud.set_runtime_status_card(kind, {
			"title": "Updated tutorial while Help is open",
			"actions": [{"id": &"continue", "label": "Updated continue"}],
		})
		await process_frame
		_check(close != null and close.has_focus(),
			"changed %s publication retains visible Help focus" % kind)
		var original_mode: int = player.get_camera_view_mode()
		await _tap_camera_binding(camera_binding)
		_check(player.get_camera_view_mode() == original_mode,
			"visible Help navigation prevents %s from claiming the gameplay camera" % kind)
		hud.clear_runtime_status_card(kind)
	player.queue_free()
	Input.mouse_mode = restore_mouse_mode
	await process_frame


## D-pad Right is both GUI navigation and the authored camera binding. Native
## input must reach the Player once during captured play, while real GUI entry
## retains normal navigation. Headless cannot establish OS cursor capture, so
## that positive case requires a silent private X11 display.
func _test_focused_gameplay_camera_input() -> void:
	var player := await _spawn_player()
	var restore_mouse_mode := Input.mouse_mode
	var pad_binding: InputEventJoypadButton
	var key_binding: InputEventKey
	for binding: InputEvent in InputMap.action_get_events(&"toggle_first_person"):
		if binding is InputEventJoypadButton:
			pad_binding = binding as InputEventJoypadButton
		elif binding is InputEventKey:
			key_binding = binding as InputEventKey
	_check(pad_binding != null and key_binding != null, "focused camera regression uses the current native InputMap bindings")
	if pad_binding == null or key_binding == null:
		player.queue_free()
		await process_frame
		return
	var panel := HBoxContainer.new()
	var passive := Button.new()
	passive.text = "Tutorial continue"
	passive.add_to_group(&"gameplay_input_passthrough")
	panel.add_child(passive)
	var ordinary := Button.new()
	ordinary.text = "Menu action"
	panel.add_child(ordinary)
	var entry := LineEdit.new()
	panel.add_child(entry)
	root.add_child(panel)
	passive.focus_neighbor_right = passive.get_path_to(ordinary)
	ordinary.focus_neighbor_right = ordinary.get_path_to(entry)
	await process_frame
	var original_mode: int = player.get_camera_view_mode()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "private rendered camera regression establishes cursor capture")
		passive.grab_focus()
		await _tap_camera_binding(pad_binding)
		_check(player.get_camera_view_mode() != original_mode and passive.has_focus(),
			"current native gamepad camera binding switches once over passive tutorial focus")
		await _tap_camera_binding(key_binding)
		_check(player.get_camera_view_mode() == original_mode and passive.has_focus(),
			"native keyboard camera binding switches back once over passive tutorial focus")
	else:
		print("CAPTURED_GAMEPAD_CAMERA_NOT_RUN_HEADLESS: requires private rendered X11")
	ordinary.grab_focus()
	var ordinary_mode: int = player.get_camera_view_mode()
	await _tap_camera_binding(pad_binding)
	_check(player.get_camera_view_mode() == ordinary_mode,
		"ordinary menu focus keeps its native gamepad navigation")
	entry.grab_focus()
	# D-pad navigation deliberately focuses a LineEdit without editing it.
	# Enter its real edit mode through the current native submit binding.
	if not entry.is_editing():
		var submit_binding: InputEventKey
		for binding: InputEvent in InputMap.action_get_events(&"ui_text_submit"):
			if binding is InputEventKey:
				submit_binding = binding as InputEventKey
				break
		_check(submit_binding != null, "text entry has a native submit binding to begin editing")
		if submit_binding != null:
			await _tap_camera_binding(submit_binding)
	var entry_mode: int = player.get_camera_view_mode()
	_check(entry.has_focus() and entry.is_editing(),
		"text entry establishes focus and editing before camera key (focus=%s editing=%s mode=%d text=%s)" % [
			str(root.gui_get_focus_owner()), str(entry.is_editing()), entry_mode, entry.text,
		])
	await _tap_camera_binding(key_binding)
	_check(player.get_camera_view_mode() == entry_mode,
		"text entry keeps camera unchanged (before=%d after=%d focus=%s editing=%s text=%s)" % [
			entry_mode, player.get_camera_view_mode(), str(root.gui_get_focus_owner()),
			str(entry.is_editing()), entry.text,
		])
	_check(not entry.text.is_empty(),
		"text entry accepts camera character (focus=%s editing=%s text=%s keycode=%d physical=%d unicode=%d)" % [
			str(root.gui_get_focus_owner()), str(entry.is_editing()), entry.text,
			key_binding.keycode, key_binding.physical_keycode, key_binding.unicode,
		])
	passive.grab_focus()
	paused = true
	var paused_mode: int = player.get_camera_view_mode()
	await _tap_camera_binding(pad_binding)
	_check(player.get_camera_view_mode() == paused_mode, "paused tutorial focus cannot change the player camera")
	paused = false
	player.set_control_enabled(false)
	passive.grab_focus()
	var disabled_mode: int = player.get_camera_view_mode()
	await _tap_camera_binding(pad_binding)
	_check(player.get_camera_view_mode() == disabled_mode, "disabled player control cannot claim a focused camera binding")
	player.set_control_enabled(true)
	player.set_camera_active(false)
	passive.grab_focus()
	var inactive_mode: int = player.get_camera_view_mode()
	await _tap_camera_binding(pad_binding)
	_check(player.get_camera_view_mode() == inactive_mode, "inactive player camera cannot claim a focused camera binding")
	player.set_camera_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	passive.grab_focus()
	var released_mode: int = player.get_camera_view_mode()
	await _tap_camera_binding(pad_binding)
	_check(player.get_camera_view_mode() == released_mode, "released cursor preserves tutorial GUI navigation")
	panel.queue_free()
	player.queue_free()
	Input.mouse_mode = restore_mouse_mode
	await process_frame


func _tap_camera_binding(binding: InputEvent) -> void:
	for pressed: bool in [true, false]:
		var event := binding.duplicate() as InputEvent
		if event is InputEventJoypadButton:
			(event as InputEventJoypadButton).device = 0
			(event as InputEventJoypadButton).pressed = pressed
		elif event is InputEventKey:
			(event as InputEventKey).pressed = pressed
			if (event as InputEventKey).keycode == 0:
				(event as InputEventKey).keycode = (event as InputEventKey).physical_keycode
			var codepoint := int((event as InputEventKey).physical_keycode)
			(event as InputEventKey).unicode = codepoint if codepoint <= 0x10ffff else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
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


## The on-foot rig is the third camera the `camera_fov` setting drives, and it is
## the same `KEEP_HEIGHT` policy as the two hero rigs, so the ultrawide cap has
## to reach it as well. A 32:9 player walking the station would otherwise keep
## the 137.7 degree horizontal sweep the hero rigs no longer use.
##
## Measured on the live player rig after a real window resize: exact equality at
## 16:9 and 21:9 (the cap must be invisible there), the 21:9 horizontal ceiling
## held at 32:9 with the cap on, and the uncapped angle restored with it off.
func _test_ultrawide_policy_reaches_the_on_foot_rig() -> void:
	var restore_size := root.size
	var restore_content_size := root.content_scale_size
	var restore_aspect := root.content_scale_aspect
	var player := await _spawn_player()
	var camera := player.get_camera() as Camera3D
	_check(
		camera != null and camera.keep_aspect == Camera3D.KEEP_HEIGHT,
		"the on-foot rig is on the same vertical-FOV policy as the hero rigs"
	)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await process_frame
	player.set_camera_fov(72.0, true)
	await process_frame
	_check(camera.fov == 72.0, "16:9 keeps the authored on-foot angle exactly")
	root.content_scale_size = Vector2i(3440, 1440)
	root.size = Vector2i(3440, 1440)
	await process_frame
	await process_frame
	_check(camera.fov == 72.0, "21:9 keeps the authored on-foot angle exactly")
	root.content_scale_size = Vector2i(5120, 1440)
	root.size = Vector2i(5120, 1440)
	await process_frame
	await process_frame
	_check(
		is_equal_approx(snappedf(camera.fov, 0.001), 52.038),
		"32:9 narrows the on-foot vertical angle to the capped 52.038 degrees (%.3f)"
			% camera.fov
	)
	_check(
		is_equal_approx(
			snappedf(
				UltrawideFovPolicy.horizontal_fov_degrees(camera.fov, 32.0 / 9.0), 0.001
			),
			120.102
		),
		"32:9 holds the on-foot horizontal angle at the 21:9 ceiling"
	)
	_check(
		is_equal_approx(player.get_authored_camera_fov(), 72.0),
		"the capped rig still reports the player's own authored 72 degrees"
	)
	player.set_camera_fov(72.0, false)
	await process_frame
	_check(
		camera.fov == 72.0,
		"opting out of the cap restores the uncapped 32:9 angle exactly"
	)
	player.queue_free()
	await process_frame
	root.content_scale_aspect = restore_aspect
	root.content_scale_size = restore_content_size
	root.size = restore_size
	await process_frame


## Synthetic standard right-stick events feed the real owner; only the clock is
## manual, so response is measured against authored radians rather than wall time.
func _test_gamepad_camera_look() -> void:
	var player := await _spawn_player()
	player.set_physics_process(false)
	player.set_process(false)
	player.set_control_enabled(true)
	player.set_camera_active(true)
	var yaw := player.get_node("%CameraYaw") as Node3D
	var pitch := player.get_node("%CameraPitch") as Node3D
	var camera := player.get_camera() as Camera3D
	var before_basis := camera.global_basis
	var start_yaw := yaw.rotation.y
	_gamepad_look_axes(Vector2.RIGHT)
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, start_yaw - 0.25)
		and not camera.global_basis.is_equal_approx(before_basis),
		"GAMEPAD_LOOK_PLAYER: right stick rotates the actual camera at 2.5 rad/s")
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, start_yaw - 0.5),
		"GAMEPAD_LOOK_PLAYER: held stick continues without another motion event")
	_gamepad_look_axes(Vector2.ZERO)
	var stopped := yaw.rotation.y
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, stopped), "GAMEPAD_LOOK_PLAYER: released stick stops look")
	_gamepad_look_axes(Vector2.RIGHT)
	player._physics_process(0.05)
	player._physics_process(0.05)
	_check(is_equal_approx(yaw.rotation.y, stopped - 0.25),
		"GAMEPAD_LOOK_PLAYER: split physics delta preserves angular speed")
	_gamepad_look_axes(Vector2(0.1, 0.1))
	var deadzone_pose := Vector2(yaw.rotation.y, pitch.rotation.x)
	player._physics_process(0.1)
	_check(Vector2(yaw.rotation.y, pitch.rotation.x).is_equal_approx(deadzone_pose),
		"GAMEPAD_LOOK_PLAYER: radial deadzone suppresses small diagonal drift")
	_gamepad_look_axes(Vector2.ONE)
	var diagonal_pose := Vector2(yaw.rotation.y, pitch.rotation.x)
	player._physics_process(0.1)
	_check(is_equal_approx(Vector2(yaw.rotation.y, pitch.rotation.x).distance_to(diagonal_pose), 0.25),
		"GAMEPAD_LOOK_PLAYER: diagonal look has normalized total angular speed")
	_gamepad_look_axes(Vector2.DOWN)
	var before_pitch := pitch.rotation.x
	player._physics_process(0.1)
	_check(is_equal_approx(pitch.rotation.x, before_pitch - 0.25),
		"GAMEPAD_LOOK_PLAYER: default stick pitch follows existing mouse direction")
	player.invert_mouse_y = true
	before_pitch = pitch.rotation.x
	player._physics_process(0.1)
	_check(is_equal_approx(pitch.rotation.x, before_pitch + 0.25),
		"GAMEPAD_LOOK_PLAYER: existing on-foot inversion reverses stick pitch")
	player.invert_mouse_y = false
	_gamepad_look_axes(Vector2.LEFT)
	yaw.rotation.y = PI - 0.01
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, -PI + 0.24),
		"GAMEPAD_LOOK_PLAYER: stick yaw wraps at the existing boundary")
	_gamepad_look_axes(Vector2.DOWN)
	player._physics_process(2.0)
	_check(is_equal_approx(pitch.rotation.x, deg_to_rad(player.minimum_pitch_degrees)),
		"GAMEPAD_LOOK_PLAYER: third-person stick pitch respects the existing clamp")
	player.toggle_camera_view_mode()
	player._physics_process(2.0)
	_check(is_equal_approx(pitch.rotation.x, deg_to_rad(-85.0)),
		"GAMEPAD_LOOK_PLAYER: first-person stick pitch uses the existing wider clamp")
	_gamepad_look_axes(Vector2.UP)
	player._physics_process(2.0)
	_check(is_equal_approx(pitch.rotation.x, deg_to_rad(85.0)),
		"GAMEPAD_LOOK_PLAYER: first-person upper pitch remains clamped")
	# Every loss is tested as a loss-and-return without a fresh stick event.
	_gamepad_look_axes(Vector2.RIGHT)
	player.set_control_enabled(false)
	player.set_control_enabled(true)
	_gamepad_player_stays_still(player, yaw, "control handoff clears held look")
	_gamepad_look_axes(Vector2.RIGHT)
	player.set_camera_active(false)
	player.set_camera_active(true)
	_gamepad_player_stays_still(player, yaw, "camera handoff clears held look")
	_gamepad_look_axes(Vector2.RIGHT)
	camera.clear_current()
	player._physics_process(0.1)
	camera.make_current()
	_gamepad_player_stays_still(player, yaw, "external current-camera loss clears held look")
	_gamepad_look_axes(Vector2.RIGHT)
	paused = true
	paused = false
	_gamepad_player_stays_still(player, yaw, "pause and resume clear held look")
	_gamepad_look_axes(Vector2.RIGHT)
	player.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player._physics_process(0.1)
	player.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_gamepad_player_stays_still(player, yaw, "application focus loss clears held look")
	_gamepad_look_axes(Vector2.RIGHT)
	Input.joy_connection_changed.emit(0, false)
	_gamepad_player_stays_still(player, yaw, "active pad disconnect clears held look")
	var menu := Button.new()
	root.add_child(menu)
	_gamepad_look_axes(Vector2.RIGHT)
	menu.grab_focus()
	var menu_yaw := yaw.rotation.y
	player._physics_process(0.1)
	menu.release_focus()
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, menu_yaw),
		"GAMEPAD_LOOK_PLAYER: focused modal UI clears held look before and after closing")
	menu.queue_free()
	_gamepad_look_axes(Vector2.RIGHT)
	player.set_remote_drive_enabled(true)
	player.set_remote_drive_enabled(false)
	player.set_control_enabled(true)
	player.set_camera_active(true)
	_gamepad_player_stays_still(player, yaw, "remote handoff clears local held look")
	_gamepad_look_axes(Vector2.RIGHT)
	root.remove_child(player)
	root.add_child(player)
	player.set_camera_active(true)
	_gamepad_player_stays_still(player, yaw, "tree exit clears held look")
	var seat := Node3D.new()
	root.add_child(seat)
	player.begin_boarding(player.global_transform, seat, 0.0)
	player.set_station_seated_context(true)
	player.set_control_enabled(true)
	_gamepad_look_axes(Vector2.RIGHT)
	var seated_yaw := yaw.rotation.y
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, wrapf(seated_yaw - 0.25, -PI, PI)),
		"GAMEPAD_LOOK_PLAYER: awake local station seating retains camera look")
	_gamepad_look_axes(Vector2.RIGHT)
	player.set_sleeping_context(true)
	var sleeping_yaw := yaw.rotation.y
	player._physics_process(0.1)
	player.set_sleeping_context(false)
	player.set_station_seated_context(true)
	player.set_control_enabled(true)
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, sleeping_yaw),
		"GAMEPAD_LOOK_PLAYER: resting clears held look through wake handoff")
	seat.queue_free()
	# A new pad's first axis must not borrow the previous pad's other axis.
	_gamepad_look_axes(Vector2.RIGHT, 0)
	var start_device_yaw := yaw.rotation.y
	_gamepad_look_axis(JOY_AXIS_RIGHT_Y, -1.0, 1)
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, start_device_yaw),
		"GAMEPAD_LOOK_PLAYER: switching devices never mixes right-stick axes")
	_gamepad_look_axes(Vector2.ZERO, 1)
	player.queue_free()
	await process_frame


func _gamepad_player_stays_still(player: Node3D, yaw: Node3D, description: String) -> void:
	var before := yaw.rotation.y
	player._physics_process(0.1)
	_check(is_equal_approx(yaw.rotation.y, before), "GAMEPAD_LOOK_PLAYER: " + description)


func _gamepad_look_axes(axes: Vector2, device: int = 0) -> void:
	_gamepad_look_axis(JOY_AXIS_RIGHT_X, axes.x, device)
	_gamepad_look_axis(JOY_AXIS_RIGHT_Y, axes.y, device)


func _gamepad_look_axis(axis: JoyAxis, value: float, device: int) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
