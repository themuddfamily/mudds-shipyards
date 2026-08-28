extends SceneTree

## Focused production route for the Phase 6 dockside kit loop. It uses the live
## Main station console, production Player, production Jovian, public crew-role
## admission, and the craft's existing RepairAuthority; no alternate inventory
## or damage owner is introduced.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CrewAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _failures := PackedStringArray()
var _assertions := 0


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

	var connections_before := console.get_signal_connection_list(&"service_requested").size()
	root.remove_child(game)
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

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


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
	if _failures.is_empty():
		print("SHIP_SERVICE_CONSOLE_PRODUCTION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
