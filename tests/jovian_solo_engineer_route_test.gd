## test-matrix-display: input-only
extends SceneTree

## Ordinary engineer admission, repair and lifetime regression in actual Main.
## Each independent route stages only at the exterior cargo ramp; subsequent
## cabin entry, chair/helm handoffs and walking use ordinary Player input.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates")
	if game == null:
		_finish()
		return
	var path := "user://jovian-engineer-route-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(path)
	store.load()
	_check(bool(store.commit({"cargo": {"sealed_manifest": ["retained freight"]}}, 0, &"fixture_cargo").accepted), "real shared file retains unrelated cargo namespace")
	_check(game.configure_runtime_settings_persistence(store), "Main uses real private shared store")
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node_or_null(^"Player") as PlayerController
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var jovian := game.get_node_or_null(^"JovianLightFreighter") as JovianLightFreighter
	_check(player != null and world != null and jovian != null,
		"production player, world and Jovian are live")
	if player == null or world == null or jovian == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var berth := world.get_berth_node(jovian.get_home_berth_id())
	_check(
		berth != null
		and berth.get_occupant() == jovian
		and jovian.global_transform.is_equal_approx(
			world.get_berth_transform(jovian.get_home_berth_id())
		),
		"the walk uses the Jovian at its occupied production freight berth"
	)
	var access := jovian.get_interior_access_marker()
	var boarding_area := jovian.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(
		access != null
		and boarding_area != null
		and boarding_area.get_ship() == jovian
		and access.global_position.distance_to(jovian.get_boarding_position()) > 10.0,
		"cargo-ramp access remains distinct from the exterior pilot-hatch authority"
	)

	game.start_shift()
	await process_frame
	player.teleport_to(Transform3D(
		jovian.global_basis.orthonormalized(),
		access.global_position + jovian.global_basis.y.normalized() * 0.01
	))
	for _index in 10:
		await physics_frame
	var start_local := jovian.to_local(player.global_position)
	_check(
		start_local.distance_to(access.position) < 0.03 and player.is_on_floor(),
		"the real player begins grounded at the exterior ramp marker"
	)

	var grounded_frames := 0
	var walked_frames := 0
	var checkpoints: Array[Vector3] = [start_local]
	# Ramp, aperture/cargo deck, aisle centring, passenger cabin, cockpit approach,
	# then one deliberate push against the visible pilot chair.
	var route := [
		[&"move_right", 50],
		[&"move_right", 72],
		[&"move_left", 22],
		[&"move_forward", 90],
		[&"move_left", 24],
	]
	for leg in route:
		Input.action_press(leg[0])
		for _index in int(leg[1]):
			await physics_frame
			walked_frames += 1
			if player.is_on_floor():
				grounded_frames += 1
		Input.action_release(leg[0])
		for _index in 3:
			await physics_frame
		checkpoints.append(jovian.to_local(player.global_position))

	var anchor := jovian.get_engineer_seat_anchor()
	_check(anchor != null and player.is_on_floor(), "ordinary full-capsule walk reaches engineer aisle")
	print("JOVIAN_ENGINEER_ROUTE: checkpoints=", checkpoints, " anchor=", jovian.to_local(anchor.global_position))
	await _look_toward(player, anchor.global_position + Vector3.UP * 1.2)
	await _press_interact()
	for tick in 70:
		await physics_frame
		await process_frame
	var status := game.get_solo_crew_seat_status()
	_check(bool(status.get("seated", false)) and player.is_seated_at(anchor)
		and (status.get("assignment", {}) as Dictionary).get("role") == &"engineer",
		"ordinary Interact claims actual Jovian engineer chair and existing role")
	print("JOVIAN_ENGINEER_DISCOVERY: candidate=", game.station_interaction_candidate, " pose=", jovian.to_local(player.global_position), " status=", status)
	if bool(status.get("seated", false)):
		var source := jovian.get_local_input_source()
		var profile := game.runtime_settings.get_input_binding_profile()
		_check(profile.set_bindings(&"fire", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F13}])
			and profile.set_bindings(&"camera_distance_out", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F14}])
			and game.runtime_settings.set_input_binding_profile(profile), "ordinary settings remap repair and component-selection controls")
		_check(bool((game.call("_persist_runtime_settings") as Dictionary).accepted), "existing Main settings owner persists remap without replacing cargo")
		source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _settle(3)
		var model := jovian.get_component_damage()
		var component: Dictionary = model.get_component_states()[1]
		var target_id := StringName(component.id)
		jovian.apply_damage(jovian.maximum_hull * 0.15, jovian.to_global(component.local_position))
		jovian.apply_damage(jovian.maximum_hull * 0.15, jovian.to_global((model.get_component_states()[4] as Dictionary).local_position))
		await _settle(2)
		var state := jovian.get_engineer_gameplay_state()
		var selected := StringName((state.selection as Dictionary).get("component_id", &""))
		_check(not selected.is_empty() and model.get_component_integrity(selected) < 1.0, "actual damaged ship component becomes engineer target under normal berth ticks")
		await _key(KEY_F14, true)
		var held_target: Variant = (jovian.get_engineer_gameplay_state().selection as Dictionary).get("component_id")
		await _settle(4)
		_check((jovian.get_engineer_gameplay_state().selection as Dictionary).get("component_id") == held_target, "held selector emits one edge without per-tick cycling")
		await _key(KEY_F14, false)
		var cycled := StringName((jovian.get_engineer_gameplay_state().selection as Dictionary).get("component_id", &""))
		_check(cycled != selected, "remapped ordinary selection advances exactly one damaged component")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		Input.parse_input_event(wheel)
		await _settle(2)
		wheel.pressed = false
		Input.parse_input_event(wheel)
		await _settle(2)
		_check((jovian.get_engineer_gameplay_state().selection as Dictionary).get("component_id") == selected, "one ordinary wheel click returns one component without duplicate step replay")
		source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _key(KEY_F13, true)
		_check(not bool(jovian.get_engineer_repair_state().active) and int(jovian.get_engineer_repair_state().resource_units) == 6, "unfocused remapped FIRE cannot repair or spend kits")
		await _key(KEY_F13, false)
		source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _settle(3)
		# Selection/focus exercise permits ordinary passive healing. A fresh
		# real localized hull hit creates the positive timed-work boundary now.
		for target: Dictionary in model.get_component_states():
			if target.id == selected:
				jovian.apply_damage(jovian.maximum_hull * 0.35, jovian.to_global(target.local_position))
				break
		var before := model.get_component_integrity(selected)
		await _key(KEY_F13, true)
		await _settle(2)
		var repair := jovian.get_engineer_repair_state()
		_check(bool(repair.active) and int(repair.resource_units) == 6 and float(repair.progress) < 1.0,
			"transformed ordinary FIRE starts timed repair without early kit spending")
		await _key(KEY_F13, false)
		await _settle(30)
		repair = jovian.get_engineer_repair_state()
		_check(repair.get("reason") == &"repair_committed" and int(repair.resource_units) == 5
			and model.get_component_integrity(selected) > before,
			"normal Main ticks commit real component improvement and exactly one finite kit")
		print("JOVIAN_ENGINEER_REPAIR: target=", selected, " target_fixture=", target_id, " before=", before, " after=", model.get_component_integrity(selected), " repair=", repair, " HUD=", game.hud.get("_objective_source_text"))
		_check(String(game.hud.get("_objective_source_text")).contains("Select component")
			and String(game.hud.get("_objective_source_text")).contains("KITS 5/6"), "live HUD names component selection, kit budget and repair controls")
		await _wait_until(func() -> bool: return bool(jovian.get_engineer_repair_state().cooldown_ready), 2.0)
		await _wait_until(func() -> bool: return model.get_component_integrity(&"core_systems") >= 1.0 and model.get_component_integrity(&"engine_bay") >= 1.0, 2.0)
		jovian.apply_damage(jovian.maximum_hull * 0.02, jovian.to_global((model.get_component_states()[3] as Dictionary).local_position))
		jovian.apply_damage(jovian.maximum_hull * 0.15, jovian.to_global((model.get_component_states()[4] as Dictionary).local_position))
		_send_key(KEY_F14, true)
		_send_key(KEY_F13, true)
		await physics_frame
		await physics_frame
		_send_key(KEY_F14, false)
		_send_key(KEY_F13, false)
		var active_component: Variant = (jovian.get_engineer_gameplay_state().selection as Dictionary).get("component_id")
		await _settle(32)
		_check(active_component == &"core_systems" and jovian.get_engineer_repair_state().reason == &"berth_repair_completed"
			and int(jovian.get_engineer_repair_state().resource_units) == 5,
			"real passive berth ticks may finish light current target without auto-selection interrupt or kit spending")
		print("JOVIAN_PASSIVE_REPAIR: component=", active_component, " repair=", jovian.get_engineer_repair_state(), " selection=", jovian.get_engineer_gameplay_state().selection)
		var old_owner := jovian.get_crew_role_authority()
		await _press_interact()
		await _settle(55)
		_check(not player.is_seated() and player.is_on_floor() and player.is_control_enabled()
			and old_owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty()
			and not player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META), "ordinary stand leaves supported awake player and retires only engineer claim")
		await _walk_toward(player, jovian, Vector3(0.0, 0.60, -5.25))
		await _walk_toward(player, jovian, Vector3(0.0, 0.60, -6.70))
		await _look_toward(player, jovian.get_pilot_seat_anchor().global_position + Vector3.UP * 1.2)
		await _press_interact()
		await _settle(70)
		_check(player.is_seated_at(jovian.get_pilot_seat_anchor()) and jovian.is_piloted()
			and not bool(game.get_solo_crew_seat_status().get("seated", false)), "normal cabin walk and Interact return to legitimate pilot helm")
		# A normal pilot input takes the same craft away from its berth; its
		# real floor, not a staged interior pose, supports the second admission.
		source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _settle(3)
		var origin := jovian.global_position
		Input.action_press(&"move_forward")
		await _wait_until(func() -> bool: return jovian.global_position.distance_to(origin) > 110.0, 6.0)
		Input.action_release(&"move_forward")
		Input.action_press(&"brake")
		await _wait_until(func() -> bool: return jovian.velocity.length() < 20.0, 4.0)
		Input.action_release(&"brake")
		var idle_ready := await _wait_until(func() -> bool: return jovian.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE, 3.0)
		print("JOVIAN_LEAVE_BEFORE: idle_ready=", idle_ready, " engine=", jovian.get_telemetry().engine_state,
			" phase=", game.phase, " piloted=", jovian.is_piloted(), " seated=", player.is_seated(), " control=", player.is_control_enabled())
		await _press_interact()
		var cabin_ready := func() -> bool:
			return game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and not jovian.is_piloted() \
				and not player.is_seated() and player.is_control_enabled() and player.is_on_floor()
		var leave_ready := await _wait_until(cabin_ready, 3.0)
		print("JOVIAN_LEAVE_AFTER: leave_ready=", leave_ready, " local=", jovian.to_local(player.global_position),
			" phase=", game.phase, " piloted=", jovian.is_piloted(), " seated=", player.is_seated(),
			" control=", player.is_control_enabled(), " floor=", player.is_on_floor())
		_check(idle_ready and leave_ready and game.phase == GameFlow.Phase.IN_FLIGHT_CABIN
			and not jovian.is_piloted() and not player.is_seated() and player.is_control_enabled()
			and not bool(jovian.get_telemetry().landed) and player.is_on_floor()
			and jovian.get_moving_interior_component().is_occupant_registered(player), "normal flight and pilot leave preserve full standing body on actual moving cabin floor")
		await _walk_toward(player, jovian, Vector3(-1.35, 0.60, -5.25))
		await _look_toward(player, anchor.global_position + jovian.global_basis.y * 1.2)
		await _press_interact()
		await _wait_until(func() -> bool: return bool(game.get_solo_crew_seat_status().seated), 3.0)
		print("JOVIAN_MOVING_ADMISSION: local=", jovian.to_local(player.global_position), " velocity=", jovian.velocity, " floor=", player.is_on_floor(), " phase=", game.phase, " control=", player.is_control_enabled(), " candidate=", game.station_interaction_candidate)
		_check(player.is_seated_at(anchor) and not jovian.is_piloted(), "ordinary moving-cabin walk and Interact reacquire actual engineer role")
		await _key(KEY_F13, true)
		await _key(KEY_F13, false)
		_check(not bool(jovian.get_engineer_repair_state().active) and int(jovian.get_engineer_repair_state().resource_units) == 5, "airborne engineer FIRE preserves berth-only policy and finite kit budget")
		var context: Dictionary = store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
		_check(context.get("mode") == "crew" and context.get("craft_id") == String(jovian.get_ship_id()) and context.size() == 4, "actual engineer saves only existing safe crew/craft/home preference")
		var settings_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).get("payload", {}).get("runtime_settings", {})
		_check(not settings_before.is_empty(), "settings preservation baseline is actual nonempty disk namespace")
		game.queue_free()
		await _settle(3)
		var fresh := MAIN_SCENE.instantiate() as GameFlow
		var fresh_store := UserDataStore.new(path)
		_check(fresh.configure_runtime_settings_persistence(fresh_store), "fresh Main reloads same real private file")
		root.add_child(fresh)
		await _settle(3)
		var pending := fresh.get_recovery_available_snapshot()
		_check(not pending.is_empty() and fresh.get_session_recovery_save_summary().contains("awake"), "fresh Main offers awake engineer cabin recovery")
		if not pending.is_empty():
			var resume := (fresh.hud.get("_session_recovery_action_buttons") as Dictionary).get(&"continue") as Button
			_check(resume != null, "ordinary HUD Resume is available")
			if resume != null:
				resume.pressed.emit()
				await _settle(3)
				fresh.start_shift()
				await _settle(12)
			var craft := fresh.get_node("JovianLightFreighter") as JovianLightFreighter
			_check(fresh.active_ship == craft and fresh.player.is_on_floor() and fresh.player.is_control_enabled()
				and not fresh.player.is_seated() and not craft.is_piloted() and craft.get_crew_role_authority() == null
				and not fresh.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META), "ordinary real-file Resume returns awake home cabin without engineer or helm replay")
			_check(JSON.parse_string(FileAccess.get_file_as_string(path)).get("payload", {}).get("runtime_settings", {}) == settings_before
				and fresh_store.get_snapshot().get("cargo", {}) == {"sealed_manifest": ["retained freight"]}, "engineer recovery preserves unrelated settings and cargo namespaces")
			await _walk_toward(fresh.player, craft, Vector3(-1.35, 0.60, -5.25))
			await _look_toward(fresh.player, craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
			await _press_interact()
			await _wait_until(func() -> bool: return bool(fresh.get_solo_crew_seat_status().seated), 3.0)
			var owner := craft.get_crew_role_authority()
			_check(owner != null and fresh.player.is_seated_at(craft.get_engineer_seat_anchor()), "recovered awake player can ordinarily claim fresh engineer chair")
			if owner != null:
				craft.get_local_input_source().notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
				await _settle(3)
				var fresh_model := craft.get_component_damage()
				craft.apply_damage(craft.maximum_hull * 0.65, craft.to_global((fresh_model.get_component_states()[1] as Dictionary).local_position))
				await _key(KEY_F13, true)
				_check(bool(craft.get_engineer_repair_state().active), "fresh ordinary FIRE begins actual repair before stand interruption")
				await _key(KEY_F13, false)
				await _press_interact()
				await _settle(55)
				_check(not fresh.player.is_seated() and fresh.player.is_on_floor() and fresh.player.is_control_enabled()
					and int(craft.get_engineer_repair_state().resource_units) == 6 and owner.get_snapshot().assignments.is_empty(),
					"ordinary midrepair stand cancels owned work before .4s commit without consuming a kit")
				await _look_toward(fresh.player, craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
				await _press_interact()
				await _wait_until(func() -> bool: return bool(fresh.get_solo_crew_seat_status().seated), 3.0)
				owner = craft.get_crew_role_authority()
				if owner != null:
					var assignment := owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
					var cursor := maxi(int(assignment.claim_sequence), int(owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))) + 1
					_check(bool(owner.release(1, 1, GameFlow.SOLO_CREW_AVATAR_ID, craft.ENGINEER_SEAT_ID, cursor, int(assignment.seat_generation)).accepted)
						and craft.detach_crew_role_authority(owner), "exact empty old ledger detaches without replenishing kits")
					var replacement := CrewSeatRoleAuthority.new(1)
					replacement.register_jovian_roster()
					craft.attach_crew_role_authority(replacement)
					var foreign := replacement.claim(1, 2, &"foreign_engineer", craft.ENGINEER_SEAT_ID, &"engineer", 1)
					_check(bool(foreign.accepted), "replacement owner's negative competing engineer claim is genuine")
					await _settle(12)
					await _key(KEY_F13, true)
					await _key(KEY_F13, false)
					_check(not fresh.player.is_seated() and fresh.player.is_on_floor() and fresh.player.is_control_enabled()
						and replacement.get_assignment(2, &"foreign_engineer") == foreign.assignment
						and replacement.get_last_intent(2, &"foreign_engineer").is_empty()
						and not bool(craft.get_engineer_repair_state().active), "retiring local Player cleanup and held FIRE cannot claim or repair through replacement owner")
					replacement.release(1, 2, &"foreign_engineer", craft.ENGINEER_SEAT_ID, 2, 1)
					craft.detach_crew_role_authority(replacement)
					await _look_toward(fresh.player, craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
					await _press_interact()
					await _wait_until(func() -> bool: return bool(fresh.get_solo_crew_seat_status().seated), 3.0)
					owner = craft.get_crew_role_authority()
					_check(owner != null and fresh.player.is_seated_at(craft.get_engineer_seat_anchor()), "replacement handback permits fresh ordinary engineer admission")
					if owner != null:
						var probe := UDPServer.new()
						var listened := probe.listen(0, "127.0.0.1")
						var port := probe.get_local_port() if listened == OK else 0
						probe.stop()
						_check(port > 0, "real session handback uses available loopback port")
						if port > 0:
							var hosted := fresh.host_network_session(port)
							await _settle(12)
							_check(bool(hosted.accepted) and not fresh.player.is_seated() and fresh.player.is_on_floor()
								and fresh.player.is_control_enabled() and owner.get_snapshot().assignments.is_empty(), "real host handback releases exact engineer claim to usable awake cabin")
							await _look_toward(fresh.player, craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
							await _press_interact()
							var host_chair_ready := await _wait_until(func() -> bool: return fresh.player.is_seated_at(craft.get_engineer_seat_anchor()) and not bool(fresh.get("_transition_busy")), 4.0)
							var network_owner := craft.get_crew_role_authority()
							var network_binding: Object = fresh.get("_network_engineer_binding")
							var host_assignment := network_owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID) if network_owner != null else {}
							_check(host_chair_ready and network_owner != null and network_owner != owner
								and network_binding != null and network_binding.get("authority") == network_owner
								and host_assignment.get("role") == &"engineer" and host_assignment.get("seat_id") == craft.ENGINEER_SEAT_ID
								and fresh.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and not craft.is_piloted(), "network-live ordinary Interact claims exact shared host engineer owner without helm ownership")
							await _press_interact()
							_check(await _wait_until(func() -> bool: return not fresh.player.is_seated() and fresh.player.is_control_enabled() and fresh.player.is_on_floor(), 4.0)
								and network_owner != null and network_owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty()
								and not craft.is_piloted(), "ordinary network engineer stand releases exact claim to supported usable host Player")
							var unsupported_seat: ShipCrewSeat
							for candidate in fresh.find_children("*", "Area3D", true, false):
								if candidate is ShipCrewSeat and candidate.get_ship() is HalyardCrewTransport and candidate.get_role() != &"engineer":
									unsupported_seat = candidate
									break
							# Exercise the guard with real installed furniture; no role
							# assignment is injected into this negative request.
							if unsupported_seat != null:
								fresh.call("_sit_in_solo_crew_seat", unsupported_seat)
							await _settle(8)
							_check(unsupported_seat != null and not fresh.player.is_seated() and fresh.player.is_on_floor()
								and fresh.player.is_control_enabled() and not bool(fresh.get("_transition_busy"))
								and network_owner != null and network_owner.get_snapshot().assignments.is_empty()
								and not fresh.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META), "network-live unsupported crew role remains refused without a chair or helm claim")
							fresh.shutdown_network_session()
							await _settle(8)
							await _walk_from_ramp(fresh.player, craft)
							await _look_toward(fresh.player, craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
							print("JOVIAN_SESSION_HANDBACK: phase=", fresh.phase, " pose=", craft.to_local(fresh.player.global_position), " floor=", fresh.player.is_on_floor(), " control=", fresh.player.is_control_enabled(), " ledger=", craft.get_crew_role_authority(), " candidate=", fresh.station_interaction_candidate)
							await _press_interact()
							await _wait_until(func() -> bool: return bool(fresh.get_solo_crew_seat_status().seated), 3.0)
							owner = craft.get_crew_role_authority()
							_check(owner != null and fresh.player.is_seated_at(craft.get_engineer_seat_anchor()), "real session shutdown permits ordinary solo engineer re-entry")
					if owner != null:
						craft.queue_free()
						await _settle(15)
						_check(typeof(fresh.active_ship) == TYPE_NIL and not fresh.player.is_seated() and fresh.player.is_control_enabled()
							and fresh.player.is_on_floor() and owner.get_snapshot().assignments.is_empty(), "actual seated craft free restores supported awake Player and exact empty old ledger")
		game = fresh
	game.queue_free()
	await process_frame
	await _settle(3)
	var destroy_game := MAIN_SCENE.instantiate() as GameFlow
	destroy_game.configure_runtime_settings_persistence(UserDataStore.new("user://jovian-engineer-destroy-%d.json" % OS.get_process_id()))
	root.add_child(destroy_game)
	await _settle(3)
	destroy_game.start_shift()
	var destroyed_craft := destroy_game.get_node("JovianLightFreighter") as JovianLightFreighter
	await _walk_from_ramp(destroy_game.player, destroyed_craft)
	await _look_toward(destroy_game.player, destroyed_craft.get_engineer_seat_anchor().global_position + Vector3.UP * 1.2)
	await _press_interact()
	await _wait_until(func() -> bool: return bool(destroy_game.get_solo_crew_seat_status().seated), 3.0)
	var destroyed_owner := destroyed_craft.get_crew_role_authority()
	_check(destroyed_owner != null and destroy_game.player.is_seated_at(destroyed_craft.get_engineer_seat_anchor()), "actual hull-loss case starts from ordinary engineer admission")
	if destroyed_owner != null:
		destroyed_craft.apply_damage(destroyed_craft.maximum_hull + 1.0, destroyed_craft.global_position, Vector3.UP)
		await _settle(15)
		_check(destroyed_craft.is_destroyed() and not destroy_game.player.is_seated()
			and destroy_game.player.is_on_floor() and destroy_game.player.is_control_enabled()
			and not destroy_game.player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
			and destroyed_owner.get_snapshot().assignments.is_empty(), "actual hull destruction retires engineer claim and leaves supported usable awake Player")
	destroy_game.queue_free()
	await _settle(3)
	_finish()


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	for action in [&"move_right", &"move_left", &"move_forward", &"fire", &"interact", &"brake", &"camera_distance_in", &"camera_distance_out"]:
		Input.action_release(action)
	for code in [KEY_F13, KEY_F14]:
		var released := InputEventKey.new()
		released.physical_keycode = code
		released.pressed = false
		Input.parse_input_event(released)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _failures.is_empty():
		print("JOVIAN_SOLO_ENGINEER_ROUTE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("JOVIAN_SOLO_ENGINEER_ROUTE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _look_toward(actor: PlayerController, target: Vector3) -> void:
	for tick in 4:
		_apply_mouse_look(actor, target)
		await physics_frame
		await process_frame


func _apply_mouse_look(actor: PlayerController, target: Vector3) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		actor._unhandled_input(click)
	var desired := actor.global_basis.inverse() * (target - actor.get_camera().global_position).normalized()
	var current := actor.global_basis.inverse() * actor.get_interaction_direction().normalized()
	var yaw_delta := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
	var pitch_delta := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-yaw_delta, pitch_delta * (1.0 if actor.invert_mouse_y else -1.0)) / actor.mouse_sensitivity
	actor._unhandled_input(motion)


func _press_interact() -> void:
	Input.action_press(&"interact")
	await _physics_ticks(2)
	Input.action_release(&"interact")
	await _physics_ticks(2)


func _settle(ticks: int) -> void:
	for tick in ticks:
		await physics_frame
		await process_frame


func _walk_toward(actor: PlayerController, craft: HeroShip, target_local: Vector3) -> void:
	var target := craft.to_global(target_local)
	await _look_toward(actor, Vector3(target.x, actor.get_camera().global_position.y, target.z))
	Input.action_press(&"move_forward")
	for tick in 160:
		var flat := craft.to_local(actor.global_position) - target_local
		flat.y = 0.0
		if flat.length() < 0.12:
			break
		target = craft.to_global(target_local)
		_apply_mouse_look(actor, Vector3(target.x, actor.get_camera().global_position.y, target.z))
		await physics_frame
	Input.action_release(&"move_forward")
	await _physics_ticks(4)


func _key(code: Key, pressed: bool) -> void:
	_send_key(code, pressed)
	await _physics_ticks(2)


func _wait_until(predicate: Callable, seconds: float) -> bool:
	for tick in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if predicate.call():
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _walk_from_ramp(actor: PlayerController, craft: JovianLightFreighter) -> void:
	actor.teleport_to(Transform3D(craft.global_basis.orthonormalized(), craft.get_interior_access_marker().global_position + craft.global_basis.y * 0.01))
	await _settle(10)
	await _look_toward(actor, actor.global_position - craft.global_basis.z * 20.0 + craft.global_basis.y * 1.5)
	for leg in [[&"move_right", 50], [&"move_right", 72], [&"move_left", 22], [&"move_forward", 90], [&"move_left", 24]]:
		Input.action_press(leg[0])
		for tick in int(leg[1]):
			await physics_frame
		Input.action_release(leg[0])
		await _settle(3)


func _physics_ticks(ticks: int) -> void:
	for tick in ticks:
		await physics_frame
