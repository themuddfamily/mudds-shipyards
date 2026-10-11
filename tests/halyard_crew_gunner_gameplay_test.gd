extends SceneTree
## test-matrix-display: input-only

## Focused Phase 7 runtime slice: an authority-admitted gunner receipt reaches
## the Halyard's existing projectile request signal. Combat resolution and
## damage remain outside this test and outside the ship role consumer.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var authority := Authority.new(1)
	_check(
		bool(authority.register_halyard_roster().get("accepted", false)),
		"the Halyard roster seals before a gunner can submit an intent"
	)
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"the real Halyard accepts the session-owned role authority"
	)
	_check(
		bool(authority.claim(
			1, 88, &"gunner_avatar", &"co_pilot_station", Authority.ROLE_GUNNER, 1
		).get("accepted", false)),
		"the gunner claim is tied to the physical co-pilot station"
	)

	var emitted := [0]
	var selected := [0]
	var cleared := [0]
	var last_origin := [Vector3.INF]
	var last_direction := [Vector3.ZERO]
	var selected_generation := [0]
	var clear_reason := [StringName(&"")]
	craft.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		emitted[0] += 1
		last_origin[0] = origin
		last_direction[0] = direction
	)
	craft.gunner_target_selected.connect(
		func(_target_id: StringName, generation: int, _receipt: Dictionary) -> void:
			selected[0] += 1
			selected_generation[0] = generation
	)
	craft.gunner_target_cleared.connect(
		func(_target_id: StringName, _generation: int, reason: StringName) -> void:
			cleared[0] += 1
			clear_reason[0] = reason
	)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	var fired := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
			"target_generation": 1,
		},
		2
	)
	var effect := fired.get("effect", {}) as Dictionary
	_check(
		bool(fired.get("accepted", false))
			and bool(fired.get("consumed", false))
			and fired.get("status", &"") == &"intent_consumed"
			and bool(effect.get("accepted", false))
			and effect.get("status", &"") == &"weapon_request_emitted",
		"the accepted gunner receipt is consumed as a weapon request"
	)
	_check(
		emitted[0] == 1 and (last_origin[0] as Vector3).is_finite() \
			and (last_direction[0] as Vector3).is_finite()
			and (last_direction[0] as Vector3).length() > 0.99,
		"the existing projectile request seam emits one normalized shot"
	)
	_check(
		selected[0] == 1 and selected_generation[0] == 1,
		"the gunner receipt selects a bounded target independently of fire cadence"
	)
	_check(
		effect.get("source_id", 0) == HalyardCrewTransport.COMBAT_SOURCE_ID
			and effect.get("faction_id", &"") == HalyardCrewTransport.HALYARD_CREW_FACTION_ID
			and effect.get("weapon_id", &"") == HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
		"the request carries the Halyard's bounded source, faction, and weapon identity"
	)

	var selection_only := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_01",
			"trigger": false,
			"target_generation": 1,
		},
		3
	)
	_check(
		bool(selection_only.get("accepted", false))
			and bool(selection_only.get("consumed", false))
			and (selection_only.get("effect", {}) as Dictionary).get("status", &"") == &"target_selected"
			and selected[0] == 2
			and emitted[0] == 1,
		"target selection remains usable when fire is not requested"
	)

	var cooldown := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_01",
			"trigger": true,
			"target_generation": 1,
		},
		4
	)
	_check(
		bool(cooldown.get("accepted", false))
			and not bool(cooldown.get("consumed", false))
			and (cooldown.get("effect", {}) as Dictionary).get("status", &"") == &"weapon_cooldown"
			and emitted[0] == 1,
		"HeroShip cadence blocks a second gunner request without emitting another shot"
	)

	var replay := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
			"target_generation": 1,
		},
		2
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"a replayed gunner receipt cannot emit a duplicate request"
	)

	var handoff := craft.handoff_crew_role(
		1,
		88,
		&"gunner_avatar",
		&"co_pilot_station",
		5,
		99,
		&"replacement_gunner",
		Authority.ROLE_GUNNER,
		6
	)
	_check(
		bool(handoff.get("accepted", false))
			and cleared[0] == 1
			and clear_reason[0] == &"role_handoff",
		"gunner handoff clears the outgoing target selection exactly once"
	)
	var stale_generation := craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": false,
			"target_generation": 1,
		},
		7
	)
	_check(
		bool(stale_generation.get("accepted", false))
			and not bool(stale_generation.get("consumed", false))
			and (stale_generation.get("effect", {}) as Dictionary).get("status", &"")
			== &"stale_target_generation",
		"a stale gunner target generation cannot select a target after handoff"
	)
	var replacement := craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": false,
			"target_generation": 2,
		},
		8
	)
	_check(
		bool(replacement.get("accepted", false))
			and bool(replacement.get("consumed", false))
			and selected_generation[0] == 2,
		"the replacement gunner selects against the fresh target generation"
	)
	var released := authority.release(1, 99, &"replacement_gunner", &"co_pilot_station", 9)
	_check(bool(released.get("accepted", false)), "the replacement gunner can be detached")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_detached", "detach clears the replacement target selection")

	craft.queue_free()
	await process_frame
	await _ordinary_gunner_route()
	if _failures.is_empty():
		print("HALYARD_CREW_GUNNER_GAMEPLAY_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


var _game: GameFlow
var _craft: HalyardCrewTransport
var _player: PlayerController

func _ordinary_gunner_route() -> void:
	_game = preload("res://scenes/main.tscn").instantiate() as GameFlow
	var path := "user://ordinary-halyard-gunner-%d.json" % OS.get_process_id()
	_check(_game.configure_runtime_settings_persistence(UserDataStore.new(path)), "ordinary Main owns private settings before startup")
	root.add_child(_game)
	await _ticks(4)
	_game.start_shift()
	await _ticks(3)
	_player = _game.player
	_craft = _game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	# Exterior staging only: all cabin approach and chair admissions use Input.
	_player.teleport_to(Transform3D(_craft.global_basis, _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(12)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_pilot_seat_anchor()) and not _game._transition_busy, 8.0), "ordinary Interact boards unchanged Halyard helm")
	if not _player.is_seated():
		_game.queue_free()
		await _ticks(3)
		return
	var berth := _craft.global_position
	Input.action_press(&"move_forward")
	_check(await _until(func(): return _craft.global_position.distance_to(berth) > 100.0, 10.0), "ordinary throttle moves actual Halyard clear of berth")
	Input.action_release(&"move_forward")
	Input.action_press(&"brake")
	for tick in 240:
		if _craft.velocity.length() < 30.0:
			break
		await physics_frame
	Input.action_release(&"brake")
	for tick in int(ceil(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS * Engine.physics_ticks_per_second)) + 4:
		if _craft.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE:
			break
		await physics_frame
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	_game._unhandled_input(event)
	_check(await _until(func(): return _player.is_control_enabled() and _player.is_cabin_containment_active() and _player.is_on_floor(), 8.0), "ordinary leave-helm restores full capsule on supported moving cabin floor")
	var carried_origin := _craft.global_position
	await _walk(_craft.to_local(_craft.get_gunner_station_role_contract().entry_transform.origin))
	_check(_player.is_on_floor() and not _player.is_seated() and _craft.global_position.distance_to(carried_origin) > 0.05, "full capsule walks actual flight deck while retained hull drifts")
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	print("HALYARD_ORDINARY_APPROACH: local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " floor=", _player.is_on_floor())
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not _game._transition_busy, 8.0), "ordinary Interact seats at existing co-pilot gunner anchor")
	if _player.is_seated_at(_craft.get_gunner_station_anchor()):
		var owner := _craft.get_crew_role_authority()
		_check(_game._solo_crew_claim_is_current() and owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).role == &"gunner", "ordinary physical gunner holds current exact role generation")
		var shots := [0]
		var last_direction := [Vector3.ZERO]
		_craft.projectile_fired.connect(func(_origin: Vector3, direction: Vector3): shots[0] += 1; last_direction[0] = direction)
		await _look(_player.get_interaction_origin() + _craft.global_basis * Vector3(0.3, 0.05, -100.0))
		var sight_direction := _player.get_interaction_direction().normalized()
		var profile := _game.runtime_settings.get_input_binding_profile()
		_check(profile.set_bindings(&"fire", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F13}]), "real runtime settings remap gunner FIRE")
		_game._on_setting_change_requested(&"input_binding_profile", profile)
		_craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _ticks(3)
		_fire_key(true)
		_check(await _until(func(): return shots[0] > 0, 3.0), "live remapped physical FIRE reaches existing Halyard projectile owner")
		_fire_key(false)
		await _ticks(3)
		_check(not _craft.is_piloted() and not _craft.get_last_ship_command().fire and _objective_text().contains("F13") and _objective_text().contains("LANCE FIRED") and (last_direction[0] as Vector3).is_normalized(), "gunner has accurate remapped acknowledgement and normalized projectile without helm")
		_check((last_direction[0] as Vector3).dot(sight_direction) > 0.99, "existing lance converges along the actual seated gunner view instead of pilot camera")
		await _press(&"interact")
		_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled() and not _game._transition_busy, 8.0), "ordinary stand restores supported moving cabin walk")
		_check(owner.get_snapshot().assignments.is_empty() and not _player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META), "ordinary stand releases exact role and existing Halyard tag")
		var stood := _craft.to_local(_player.global_position)
		await _walk(Vector3(0.0, 0.52, -8.9))
		_check(_craft.to_local(_player.global_position).distance_to(stood) > 0.6 and _player.is_on_floor(), "stood gunner walks back along real flight deck")
		await _walk(_craft.to_local(_craft.get_gunner_station_role_contract().entry_transform.origin))
		await _look(_craft.get_pilot_seat_anchor().global_position + Vector3.UP * 1.2)
		await _press(&"interact")
		_check(await _until(func(): return _player.is_seated_at(_craft.get_pilot_seat_anchor()) and _craft.is_piloted(), 8.0), "ordinary Interact returns to retained actual helm")
		# Retake the actual chair before an adversarial replacement-owner boundary.
		_game._unhandled_input(event)
		_check(await _until(func(): return not _player.is_seated() and _player.is_control_enabled() and _player.is_on_floor(), 8.0), "retained helm can return to ordinary cabin walking")
		await _walk(_craft.to_local(_craft.get_gunner_station_role_contract().entry_transform.origin))
		await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
		await _press(&"interact")
		_check(await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not _game._transition_busy, 8.0), "ordinary reseat precedes replacement cleanup without injected occupancy")
		var old_owner := _craft.get_crew_role_authority()
		if old_owner != null and _player.is_seated_at(_craft.get_gunner_station_anchor()):
			_craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			await _ticks(3)
			_fire_key(true)
			_check(await _until(func(): return bool(_player.get_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META, {}).get("weapon_power_started", false)), 3.0), "actual reseated FIRE owns only power this gunner woke")
			_fire_key(false)
			var assignment := old_owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
			var sequence := maxi(int(assignment.claim_sequence), int(old_owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))) + 1
			var released := old_owner.release(1, 1, GameFlow.SOLO_CREW_AVATAR_ID, &"co_pilot_station", sequence, int(assignment.seat_generation))
			var replacement := Authority.new(1)
			var roster := replacement.register_halyard_roster()
			var detached := _craft.detach_crew_role_authority(old_owner)
			var attached := _craft.attach_crew_role_authority(replacement)
			var foreign := replacement.claim(1, 2, &"replacement_gunner", &"co_pilot_station", Authority.ROLE_GUNNER, 1)
			_check(released.accepted and roster.accepted and detached and attached.accepted and foreign.accepted, "existing owner APIs replace the released ordinary row for a negative ownership guard")
			_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled(), 8.0), "old exact-owner cleanup restores actual supported body")
			_check(not _player.has_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META) and _craft.get_crew_role_authority() == replacement and replacement.get_assignment(2, &"replacement_gunner") == foreign.assignment and _craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE, "old cleanup preserves replacement claim and power and clears only old physical tag")
			await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
			await _press(&"interact")
			_check(not _player.is_seated() and replacement.get_assignment(2, &"replacement_gunner") == foreign.assignment, "ordinary Interact refuses a replacement-owned chair")
	for action in [&"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"brake", &"fire"]:
		Input.action_release(action)
	_fire_key(false)
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	DirAccess.remove_absolute(path)

func _objective_text() -> String:
	return str((_game.hud.get("_objective_label") as Label).text).to_upper()

func _walk(target_local: Vector3) -> void:
	print("HALYARD_GUNNER_WALK_START: local=", _craft.to_local(_player.global_position), " target=", target_local)
	for _index in 240:
		var delta := _craft.to_global(target_local) - _player.global_position
		delta = delta.slide(_craft.global_basis.y.normalized())
		if delta.length() < 0.30:
			break
		var forward := (-_player.get_camera().global_basis.z).slide(_craft.global_basis.y.normalized()).normalized()
		var right := forward.cross(_craft.global_basis.y.normalized()).normalized()
		var direction := delta.normalized()
		var axis := Vector2(direction.dot(right), -direction.dot(forward))
		# Slow an ordinary analog walk near the authored pose. At low render
		# cadence several real physics steps can run between input refreshes.
		axis *= clampf(delta.length() / 1.5, 0.6, 1.0)
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		Input.action_press(&"move_left" if axis.x < 0.0 else &"move_right", absf(axis.x))
		Input.action_press(&"move_forward" if axis.y < 0.0 else &"move_back", absf(axis.y))
		await physics_frame
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	_check(await _until(func(): return _player.is_on_floor() and _player.velocity.slide(_craft.global_basis.y.normalized()).length() < 0.1, 3.0), "ordinary gunner walk settles on actual cabin support")

func _look(target: Vector3) -> void:
	for _index in 4:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			_player._unhandled_input(click)
		var desired := _player.global_basis.inverse() * (target - _player.get_interaction_origin()).normalized()
		var current := _player.global_basis.inverse() * _player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _player.invert_mouse_y else -1.0)) / _player.mouse_sensitivity
		_player._unhandled_input(event)
		await physics_frame

func _press(action: StringName) -> void:
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(3)

func _fire_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F13
	event.pressed = pressed
	Input.parse_input_event(event)

func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await _ticks(1)
	return false

func _ticks(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame
