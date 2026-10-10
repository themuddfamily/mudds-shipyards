extends SceneTree

## test-matrix-display: input-only

## Focused production route for the Phase 6 dockside kit loop. It uses the live
## Main station console, production Player, production Jovian, public crew-role
## admission, and the craft's existing RepairAuthority; no alternate inventory
## or damage owner is introduced.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CrewAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const ServiceConsoleType := preload("res://scripts/interaction/ship_service_console.gd")

var _failures := PackedStringArray()
var _assertions := 0
var _engineer_sequence := 4


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()

	var console := game.world.call(&"get_ship_service_console") as Area3D
	var player := game.player as PlayerController
	var jovian := game.get_node_or_null(^"JovianLightFreighter") as HeroShip
	_check(
		console != null and player != null and jovian != null,
		"production Main exposes the physical service console, Player, and Jovian"
	)
	if console == null or player == null or jovian == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var authority = _build_jovian_authority()
	_check(
		bool(jovian.call(&"attach_crew_role_authority", authority).get("accepted", false)),
		"the production Jovian admits its existing engineer-role authority"
	)
	var model := jovian.get_component_damage()
	var damage_accepted := true
	for _hit in 4:
		damage_accepted = damage_accepted and bool(
			model.record_damage(70.0, Vector3.INF).get("accepted", false)
		)
	_check(
		damage_accepted,
		"the production component owner supplies a deeply damaged service fixture"
	)
	var component_id := _most_damaged_component(model)
	jovian.set("_landed", true)
	var started: Dictionary = jovian.call(
		&"submit_crew_intent",
		1,
		77,
		&"service_test_engineer",
		CrewAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		2
	) as Dictionary
	_check(
		bool(started.get("accepted", false)) and bool(started.get("consumed", false)),
		"the public engineer route starts one real repair before dockside service"
	)
	for _frame in 60:
		if StringName(
			(jovian.call(&"get_engineer_repair_state") as Dictionary).get("status", &"")
		) == &"completed":
			break
		await physics_frame
	var spent := jovian.call(&"get_engineer_repair_state") as Dictionary
	_check(
		StringName(spent.get("status", &"")) == &"completed"
			and int(spent.get("resource_units", -1)) == 5,
		"the production repair spends one of the finite six kits (status=%s reason=%s units=%d)"
			% [spent.get("status", &""), spent.get("reason", &""), int(spent.get("resource_units", -1))]
	)
	var released: Dictionary = jovian.call(
		&"release_crew_role",
		1, 77, &"service_test_engineer", &"passenger_port_01", 3
	) as Dictionary
	_check(bool(released.get("accepted", false)), "the engineer exits before on-foot service")
	await physics_frame

	# This test injects only the coordinator's already-public active-craft choice;
	# the physical interaction, resource mutation, and component state remain the
	# production instances exercised by the player route.
	game.active_ship = jovian
	var approach := console.global_position + Vector3(0.0, 0.0, -1.05)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), approach))
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(
		game.station_interaction_candidate == console
			and str(console.call(&"get_interaction_prompt")).contains("RESTOCK ACTIVE SHIP"),
		"facing ConsoleBay03 selects the service prompt through ordinary on-foot discovery"
	)
	var integrity_before := model.get_component_integrity(component_id)
	var generation_before := model.get_ledger_generation()
	var service_before := jovian.call(&"get_engineer_repair_state") as Dictionary
	var cooldown_before := float(service_before.get("cooldown_remaining", 0.0))
	game.call(&"_on_interact_requested")
	var restocked := jovian.call(&"get_engineer_repair_state") as Dictionary
	var presented := console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		int(restocked.get("resource_units", -1)) == 6
			and str(presented.get("status_text", "")).contains("RESTOCKED")
			and str(presented.get("status_text", "")).contains("KITS 6/6"),
		"one physical E press restocks the active Jovian and repaints the workstation (units=%d text=%s)"
			% [int(restocked.get("resource_units", -1)), presented.get("status_text", "")]
	)
	_check(
		is_equal_approx(model.get_component_integrity(component_id), integrity_before)
			and model.get_ledger_generation() == generation_before
			and is_equal_approx(
				float(restocked.get("cooldown_remaining", -1.0)), cooldown_before
			),
		"dockside service changes no damage, component generation, or cooldown state"
	)
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
			and player.is_control_enabled() and not player.is_seated(),
		"service leaves the player embodied and the normal shipyard loop active"
	)

	game.call(&"_on_interact_requested")
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		str(presented.get("status_text", "")).begins_with("FULL")
			and int(
				(jovian.call(&"get_engineer_repair_state") as Dictionary).get(
					"resource_units", -1
				)
			) == 6,
		"repeating the physical service on a full locker is a visible no-op"
	)

	var torrent := game.get_node_or_null(^"TorrentInterceptor") as HeroShip
	game.active_ship = torrent
	game.call(&"_on_interact_requested")
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		str(presented.get("status_text", "")).contains("JOVIAN // HALYARD // BULWARK")
			and int(
				(jovian.call(&"get_engineer_repair_state") as Dictionary).get(
					"resource_units", -1
				)
			) == 6,
		"an unsupported active craft receives guidance and cannot mutate another locker"
	)

	await _test_fabrication_service(game, console, jovian, authority)

	var connections_before := console.get_signal_connection_list(&"service_requested").size()
	var retained_annex := game.world.call(&"get_fabrication_ship_service_console") as Area3D
	var detached_before := retained_annex.call(&"get_presentation_snapshot") as Dictionary
	var units_before_detach := _kit_units(jovian)
	root.remove_child(game)
	retained_annex.emit_signal(&"service_requested", player)
	_check(_kit_units(jovian) == units_before_detach
			and (retained_annex.call(&"get_presentation_snapshot") as Dictionary) == detached_before,
		"a detached Main revokes both source bindings without a resource or presentation mutation")
	await process_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	var rebound := game.world.call(&"get_ship_service_console") as Area3D
	_check(
		rebound == console
			and rebound.get_signal_connection_list(&"service_requested").size() \
				== connections_before,
		"whole-Main re-entry retains one console identity and one service binding"
	)
	var annex_console := game.world.call(&"get_fabrication_ship_service_console") as Area3D
	_check(
		is_instance_valid(annex_console)
			and annex_console.get_signal_connection_list(&"service_requested").size() == 1,
		"whole-Main re-entry restores exactly one annex service binding"
	)

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_fabrication_service(game: GameFlow, aft: Area3D, jovian: HeroShip,
		authority: CrewSeatRoleAuthority) -> void:
	var console := game.world.call(&"get_fabrication_ship_service_console") as Area3D
	var annex := game.world.get_node_or_null(^"FabricationAnnex") as Node3D
	var player := game.player as PlayerController
	_check(console != null and annex != null, "the world owns one physical annex service control")
	if console == null or annex == null:
		return
	var authored_transform := console.transform
	var header := console.get_node_or_null(^"ShipServiceReadability/ShipServiceHeader") as MeshInstance3D
	_check(
		header != null and annex.to_local(header.global_position).distance_to(
			Vector3(5.14, 1.48, 7.55)) < 0.01,
		"service readability sits on the authored fabricator control, outside its face"
	)
	_check(int((console.call(&"get_presentation_snapshot") as Dictionary).presentation_sequence) == 0,
		"the existing Aft route never repaints the annex origin")
	game.active_ship = jovian
	await _spend_one_kit(jovian, authority)
	# Initial staging is at the connector mouth. Everything from here to the
	# control uses ordinary held walking and mouse look, with no jumps or relocation.
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(50.0, 0.38, 28.0)))
	await physics_frame
	await physics_frame
	var walked := true
	for destination: Vector3 in [
		Vector3(68.5, 0.38, 28.0), Vector3(68.5, 0.38, 38.0),
		Vector3(72.0, 0.53, 38.0),
		annex.to_global(Vector3(0.0, 0.15, 4.8)),
		annex.to_global(Vector3(4.5, 0.15, 4.8)),
		annex.to_global(Vector3(4.5, 0.15, 7.55)),
	]:
		walked = await _walk_to(player, destination) and walked
	_check(walked and player.is_on_floor(), "ordinary walking reaches the control through the connector and bench aisle on real floors")
	_look_towards(player, annex.to_global(Vector3(5.24, 1.25, 7.55)))
	await physics_frame
	await process_frame
	_check(
		game.station_interaction_candidate == console
			and str(console.call(&"get_interaction_prompt")).contains("RESTOCK ACTIVE SHIP"),
		"ordinary look selects the annex restock prompt without an injected candidate"
	)
	var aft_before := aft.call(&"get_presentation_snapshot") as Dictionary
	var annex_before := console.call(&"get_presentation_snapshot") as Dictionary
	await _press_interact()
	var presented := console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		_kit_units(jovian) == 6 and str(presented.status_text).contains("RESTOCKED")
			and str(presented.status_text).contains(jovian.get_display_name().to_upper())
			and str(presented.status_text).contains("KITS 6/6")
			and int(presented.presentation_sequence) == int(annex_before.presentation_sequence) + 1
			and (aft.call(&"get_presentation_snapshot") as Dictionary) == aft_before,
		"one ordinary annex E restocks the selected craft and paints only its origin once"
	)
	await _press_interact()
	_check(_kit_units(jovian) == 6 and str((console.call(&"get_presentation_snapshot") as Dictionary).status_text).begins_with("FULL"),
		"repeated annex E stays at the existing six-kit cap with visible FULL status")
	game.active_ship = game.get_node_or_null(^"TorrentInterceptor") as HeroShip
	await _press_interact()
	_check(_kit_units(jovian) == 6 and str((console.call(&"get_presentation_snapshot") as Dictionary).status_text).contains("JOVIAN // HALYARD // BULWARK"),
		"the annex explains unsupported craft without touching another locker")
	game.active_ship = jovian
	jovian.set("_landed", false)
	await _press_interact()
	_check(_kit_units(jovian) == 6 and StringName(((console.call(&"get_presentation_snapshot") as Dictionary).last_result as Dictionary).get("reason", &"")) == &"ship_not_landed",
		"the existing craft authority refuses annex service for a non-landed craft")
	jovian.set("_landed", true)

	await _spend_one_kit(jovian, authority)
	var before := console.call(&"get_presentation_snapshot") as Dictionary
	# A forged actor must not enter the candidate refresh against a detached Player.
	var player_parent := player.get_parent()
	player_parent.remove_child(player)
	console.emit_signal(&"service_requested", player)
	_check(_kit_units(jovian) == 5 and (console.call(&"get_presentation_snapshot") as Dictionary) == before,
		"a detached production Player cannot restock or repaint through a forged signal")
	player_parent.add_child(player)
	await physics_frame
	await process_frame
	var foreign := ServiceConsoleType.new()
	foreign.name = &"ForeignServiceConsole"
	game.world.add_child(foreign)
	game.station_interaction_candidate = foreign
	foreign.emit_signal(&"service_requested", player)
	_check(_kit_units(jovian) == 5, "a foreign world console has no restock authority")
	foreign.queue_free()
	# Replace the accessor-owned source while Aft remains valid. The old bound
	# source cannot authorize a request even if a stale candidate is retained.
	game.world.remove_child(console)
	var replacement := ServiceConsoleType.new()
	replacement.name = &"FabricationShipServiceConsole"
	replacement.transform = console.transform
	game.world.add_child(replacement)
	game.station_interaction_candidate = console
	console.emit_signal(&"service_requested", player)
	game.call(&"_bind_ship_service_console")
	game.call(&"_bind_ship_service_console")
	_check(_kit_units(jovian) == 5
			and console.get_signal_connection_list(&"service_requested").is_empty()
			and replacement.get_signal_connection_list(&"service_requested").size() == 1,
		"replacement binding revokes the detached source and binds the annex once while Aft stays valid")
	console.free()
	await physics_frame
	await process_frame
	_check(game.station_interaction_candidate == replacement, "the replacement is rediscovered physically at the same control")
	var replacement_before := replacement.get_presentation_snapshot()
	var toast_before := int(game.hud.get("_toast_serial"))
	var retained: Array[Area3D] = [replacement]
	var mutation_observer := func(_snapshot: Dictionary) -> void:
		# Restock emits synchronously. Replacement occurs after the real kit
		# mutation and before GameFlow is allowed to paint its result.
		game.world.remove_child(replacement)
		var next := ServiceConsoleType.new()
		next.name = &"FabricationShipServiceConsole"
		next.transform = replacement.transform
		game.world.add_child(next)
		retained.append(next)
	jovian.connect(&"engineer_repair_state_changed", mutation_observer, CONNECT_ONE_SHOT)
	await _press_interact()
	var newest := retained[1] if retained.size() == 2 else null
	_check(_kit_units(jovian) == 6 and newest != null
			and replacement.get_presentation_snapshot() == replacement_before
			and int(newest.call(&"get_presentation_snapshot").get("presentation_sequence", -1)) == 0
			and int(game.hud.get("_toast_serial")) == toast_before,
		"synchronous source replacement preserves the real restock but paints no stale console, replacement, or HUD")
	game.call(&"_bind_ship_service_console")
	replacement.free()
	if newest != null:
		await _spend_one_kit(jovian, authority)
		var ship_parent := jovian.get_parent()
		ship_parent.remove_child(jovian)
		await _press_interact()
		_check(_kit_units(jovian) == 5 and StringName(((newest.call(&"get_presentation_snapshot") as Dictionary).last_result as Dictionary).get("reason", &"")) == &"active_ship_unavailable",
			"a detached active craft receives refusal rather than a restock")
		ship_parent.add_child(jovian)
		game.station_interaction_candidate = newest
		var newest_before := newest.call(&"get_presentation_snapshot") as Dictionary
		newest.queue_free()
		newest.emit_signal(&"service_requested", player)
		_check(_kit_units(jovian) == 5 and (newest.call(&"get_presentation_snapshot") as Dictionary) == newest_before,
			"a queued accessor source cannot restock or repaint")
		await process_frame
	var final_console := ServiceConsoleType.new()
	final_console.name = &"FabricationShipServiceConsole"
	final_console.transform = authored_transform
	game.world.add_child(final_console)
	game.call(&"_bind_ship_service_console")


func _spend_one_kit(jovian: HeroShip, authority: CrewSeatRoleAuthority) -> void:
	for _frame in 60:
		if float((jovian.call(&"get_engineer_repair_state") as Dictionary).get("cooldown_remaining", 0.0)) <= 0.0:
			break
		await physics_frame
	var claim := authority.claim(1, 77, &"service_test_engineer", &"passenger_port_01", CrewAuthorityType.ROLE_ENGINEER, _engineer_sequence)
	_engineer_sequence += 1
	var result := jovian.call(&"submit_crew_intent", 1, 77, &"service_test_engineer",
		CrewAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": _most_damaged_component(jovian.get_component_damage()), "repair": 0.2,
			"system_generation": int((jovian.call(&"get_engineer_gameplay_state") as Dictionary).get("component_generation", 0))},
		_engineer_sequence) as Dictionary
	_engineer_sequence += 1
	for _frame in 60:
		if StringName((jovian.call(&"get_engineer_repair_state") as Dictionary).get("status", &"")) == &"completed":
			break
		await physics_frame
	var released := jovian.call(&"release_crew_role", 1, 77, &"service_test_engineer", &"passenger_port_01", _engineer_sequence) as Dictionary
	_engineer_sequence += 1
	_check(bool(claim.get("accepted", false)) and bool(result.get("consumed", false))
			and bool(released.get("accepted", false)) and _kit_units(jovian) == 5,
		"the unchanged public engineer route spends a real kit before annex service")


func _walk_to(player: PlayerController, destination: Vector3) -> bool:
	var reached := false
	Input.action_press(&"move_forward")
	for _frame in 240:
		_look_towards(player, destination)
		await physics_frame
		await process_frame
		var offset := destination - player.global_position
		offset.y = 0.0
		if offset.length() <= 0.20:
			reached = true
			break
	Input.action_release(&"move_forward")
	for _frame in 4:
		await physics_frame
	if not reached or not player.is_on_floor():
		print("FABRICATION_SERVICE_WALK_FAILED: ", {"target": destination,
			"actual": player.global_position, "floor": player.is_on_floor(), "velocity": player.velocity})
	return reached and player.is_on_floor()


func _look_towards(player: PlayerController, destination: Vector3) -> void:
	var direction := destination - player.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var camera_yaw := player.get_node(^"%CameraYaw") as Node3D
	var current_forward := -camera_yaw.global_basis.z
	var turn := current_forward.signed_angle_to(direction.normalized(), Vector3.UP)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-turn / player.mouse_sensitivity, 0.0)
	root.push_input(mouse)


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	await physics_frame
	await process_frame


func _kit_units(jovian: HeroShip) -> int:
	return int((jovian.call(&"get_engineer_repair_state") as Dictionary).get("resource_units", -1))


func _build_jovian_authority():
	var authority := CrewAuthorityType.new(1)
	for seat in [
		[&"pilot_station", CrewAuthorityType.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"passenger_port_01", CrewAuthorityType.ROLE_ENGINEER, &"passenger_port_01"],
		[&"co_pilot_station", CrewAuthorityType.ROLE_PASSENGER, &"co_pilot_station"],
		[&"passenger_port_00", CrewAuthorityType.ROLE_PASSENGER, &"passenger_port_00"],
		[&"freight_defense_slot", CrewAuthorityType.ROLE_GUNNER, &""],
	]:
		authority.register_seat(
			seat[0], &"jovian_provisional", seat[1], &"jovian_walkable_interior", 1, seat[2]
		)
	authority.seal_roster()
	authority.claim(
		1, 77, &"service_test_engineer", &"passenger_port_01",
		CrewAuthorityType.ROLE_ENGINEER, 1
	)
	return authority


func _most_damaged_component(model: ShipComponentDamage) -> StringName:
	var selected: StringName = &""
	var lowest_integrity := INF
	for component_id: StringName in ShipComponentDamageType.COMPONENT_ORDER:
		var integrity := model.get_component_integrity(component_id)
		if integrity < lowest_integrity:
			lowest_integrity = integrity
			selected = component_id
	return selected


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _finish() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _failures.is_empty():
		print("SHIP_SERVICE_CONSOLE_PRODUCTION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
