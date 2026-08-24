extends SceneTree

## Focused production binding for repair interruption. The shared HeroShip
## damage seam is exercised on the original five-craft fleet, then a real
## authority-admitted Jovian engineer repair proves immediate semantic/network
## feedback and restartability. No GameFlow or broad gameplay matrix is loaded.

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const RepairAuthorityType := preload("res://scripts/combat/repair_authority.gd")
const RoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

const FIVE_CRAFT := [
	TORRENT_SCENE,
	ARROW_SCENE,
	JOVIAN_SCENE,
	ZENITH_SCENE,
	HALYARD_SCENE,
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for craft_scene: PackedScene in FIVE_CRAFT:
		await _test_shared_hero_binding(craft_scene)
	await _test_live_jovian_engineer_binding()
	_finish()


func _test_shared_hero_binding(craft_scene: PackedScene) -> void:
	var craft := craft_scene.instantiate() as HeroShip
	_check(craft != null, "%s instantiates through HeroShip" % craft_scene.resource_path)
	if craft == null:
		return
	root.add_child(craft)
	await process_frame
	var model := craft.get_component_damage()
	var generation := model.get_ledger_generation()
	var authority := RepairAuthorityType.new(
		&"engineer_test",
		craft.get_ship_id(),
		&"repair_kit",
		2.0,
		0.0,
		1.0,
		2
	) as RepairAuthority
	authority.begin_generation(generation)
	var requested := authority.request_repair(_repair_request(craft, generation))
	var receipts: Array[Dictionary] = []
	craft.component_repair_interrupted.connect(
		func(receipt: Dictionary) -> void: receipts.append(receipt.duplicate(true))
	)
	_check(
		bool(requested.get("accepted", false))
			and bool(craft.bind_repair_damage_interrupt_authority(authority).get("accepted", false)),
		"%s binds one active interruption observer without changing repair admission" % craft.get_ship_id()
	)
	var hull_before := float(craft.get_telemetry().get("hull", 0.0))
	var revision_before := model.get_revision()
	var hit_position := _component_world_position(craft, ComponentDamageType.COMPONENT_ENGINE_BAY)
	craft.apply_damage(1.0, hit_position, Vector3.UP)
	_check(
		not authority.has_active_repair()
			and receipts.size() == 1
			and receipts[0].get("reason", &"") == &"authoritative_component_damage"
			and receipts[0].get("damage_kind", &"") == RepairAuthorityType.DAMAGE_KIND_COMBAT
			and model.get_revision() == revision_before + 1
			and float(craft.get_telemetry().get("hull", 0.0)) < hull_before,
		"%s aborts only after its shared combat/component authorities accept the same hit" % craft.get_ship_id()
	)
	var restarted := authority.request_repair(_repair_request(craft, generation))
	_check(
		bool(restarted.get("accepted", false))
			and int(restarted.get("token", -1)) > int(requested.get("token", -1)),
		"%s can reserve a fresh repair immediately after damage interruption" % craft.get_ship_id()
	)
	authority.interrupt(&"fixture_complete")
	craft.queue_free()
	await process_frame


func _test_live_jovian_engineer_binding() -> void:
	var craft := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(craft)
	await process_frame
	var role_authority := _build_jovian_role_authority()
	_check(
		bool(craft.attach_crew_role_authority(role_authority).get("accepted", false)),
		"production Jovian attaches its existing sealed engineer-role authority"
	)
	var model := craft.get_component_damage()
	var damaged := model.record_damage(70.0, Vector3.INF)
	var component_id := _first_damaged_component(model)
	craft.set("_landed", true)
	var started := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		2
	)
	_check(
		bool(damaged.get("accepted", false))
			and bool(started.get("consumed", false))
			and StringName(craft.get_engineer_repair_state().get("status", &"")) == &"repairing",
		"authority-admitted Jovian engineer work reaches the existing active repair state"
	)
	var component_local_position := _component_local_position(craft, component_id)
	var active_presentation := craft.get_engineer_repair_presentation_snapshot()
	_check(
		bool(active_presentation.get("visible", false))
			and StringName(active_presentation.get("component_id", &"")) == component_id
			and (active_presentation.get(
				"target_local_position", Vector3.INF
			) as Vector3).is_equal_approx(component_local_position),
		"the admitted seated repair alone displays component-local work"
	)

	var integrity_before_repair := model.get_component_integrity(component_id)
	craft.call(&"_advance_engineer_repair", 0.5)
	_check(
		StringName(craft.get_engineer_repair_state().get("status", &"")) == &"completed"
			and model.get_component_integrity(component_id) > integrity_before_repair
			and not bool(craft.get_engineer_repair_presentation_snapshot().get(
				"visible", true
			)),
		"authoritative completion commits repair and immediately clears only its work cue"
	)
	craft.call(&"_advance_engineer_repair", 0.8)
	model.record_damage(70.0, Vector3.INF)
	component_id = _first_damaged_component(model)
	var before_detach := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		3
	)
	_check(
		bool(before_detach.get("consumed", false))
			and bool(craft.get_engineer_repair_presentation_snapshot().get("visible", false)),
		"fresh admitted work can return after completion cooldown"
	)
	root.remove_child(craft)
	var detached_state := craft.get_engineer_repair_state()
	var detached_presentation := craft.get_engineer_repair_presentation_snapshot()
	_check(
		StringName(detached_state.get("status", &"")) == &"interrupted"
			and StringName(detached_state.get("reason", &"")) == &"ship_detached"
			and not bool(detached_presentation.get("attached", true))
			and not bool(detached_presentation.get("visible", true)),
		"ship detach interrupts authoritative work and clears its attachment-fenced cue"
	)
	root.add_child(craft)
	await process_frame
	await process_frame
	_check(
		bool(craft.get_engineer_repair_presentation_snapshot().get("attached", false))
			and not bool(craft.get_engineer_repair_presentation_snapshot().get(
				"visible", true
			)),
		"re-entry reattaches a fresh hidden presentation generation"
	)
	var after_reentry := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		4
	)
	_check(
		bool(after_reentry.get("consumed", false))
			and bool(craft.get_engineer_repair_presentation_snapshot().get("visible", false)),
		"only a fresh post-re-entry repair receipt restores component work"
	)
	var integrity_before_hit := model.get_component_integrity(component_id)
	var hit_position := _component_world_position(craft, ComponentDamageType.COMPONENT_ENGINE_BAY)
	craft.apply_damage(2.0, hit_position, Vector3.UP)
	var interrupted := craft.get_engineer_repair_state()
	var interruption_receipt := interrupted.get("receipt", {}) as Dictionary
	var network := craft.get_engineer_repair_network_snapshot()
	var network_repair := network.get("repair", {}) as Dictionary
	_check(
		StringName(interrupted.get("status", &"")) == &"interrupted"
			and StringName(interrupted.get("reason", &"")) == &"authoritative_component_damage"
			and not bool(interrupted.get("active", true))
			and is_zero_approx(float(interrupted.get("cooldown_remaining", -1.0)))
			and StringName(interruption_receipt.get("damage_kind", &"")) == &"combat"
			and model.get_component_integrity(component_id) <= integrity_before_hit
			and StringName(network_repair.get("status", &"")) == &"interrupted"
			and StringName(network_repair.get("reason", &"")) == &"authoritative_component_damage"
			and not bool(craft.get_engineer_repair_presentation_snapshot().get(
				"visible", true
			)),
		"accepted combat damage aborts the real repair with immediate semantic and network feedback"
	)
	var restarted := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		5
	)
	_check(
		bool(restarted.get("consumed", false))
			and StringName(craft.get_engineer_repair_state().get("status", &"")) == &"repairing",
		"the same admitted engineer can start fresh work after a combat interruption"
	)
	var collision_position := _component_world_position(
		craft, ComponentDamageType.COMPONENT_PORT_WING
	)
	var collision_applied := bool(craft.call(
		&"_apply_resolved_collision_damage", 2.0, collision_position, Vector3.UP
	))
	var collision_interrupted := craft.get_engineer_repair_state()
	_check(
		collision_applied
			and StringName(collision_interrupted.get("status", &"")) == &"interrupted"
			and StringName((collision_interrupted.get("receipt", {}) as Dictionary).get(
				"damage_kind", &""
			)) == &"collision"
			and not bool(craft.get_engineer_repair_presentation_snapshot().get(
				"visible", true
			)),
		"accepted collision component damage uses the same interruption authority and semantic channel"
	)

	var before_release := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		6
	)
	var generation_before_release := int(
		craft.get_engineer_repair_presentation_snapshot().get("generation", -1)
	)
	var released := craft.release_crew_role(
		1, 77, &"repair_interrupt_engineer", &"passenger_port_01", 7
	)
	var released_presentation := craft.get_engineer_repair_presentation_snapshot()
	_check(
		bool(before_release.get("consumed", false))
			and bool(released.get("accepted", false))
			and not bool(released_presentation.get("visible", true))
			and int(released_presentation.get("generation", -1)) > generation_before_release,
		"role release clears active work and advances the presentation generation"
	)

	var reclaimed := role_authority.claim(
		1,
		77,
		&"repair_interrupt_engineer",
		&"passenger_port_01",
		RoleAuthorityType.ROLE_ENGINEER,
		8
	)
	var selected_generation := int(
		craft.get_engineer_gameplay_state().get("component_generation", 0)
	)
	var before_destruction := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{
			"system_id": component_id,
			"repair": 0.2,
			"system_generation": selected_generation,
		},
		9
	)
	_check(
		bool(reclaimed.get("accepted", false))
			and bool(before_destruction.get("consumed", false))
			and bool(craft.get_engineer_repair_presentation_snapshot().get("visible", false)),
		"the re-admitted engineer starts against the fresh role generation"
	)
	craft.apply_damage(craft.maximum_hull * 10.0, craft.global_position, Vector3.UP)
	_check(
		craft.is_destroyed()
			and not bool(craft.get_engineer_repair_presentation_snapshot().get(
				"visible", true
			)),
		"ship destruction clears active repair work without granting the cue damage authority"
	)

	var presentation_generation_before_reset := int(
		craft.get_engineer_repair_presentation_snapshot().get("generation", -1)
	)
	var reset := craft.reset_for_reuse(Transform3D.IDENTITY)
	var reset_presentation := craft.get_engineer_repair_presentation_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and not bool(reset_presentation.get("visible", true))
			and int(reset_presentation.get("generation", -1)) \
				> presentation_generation_before_reset
			and int(craft.get_engineer_gameplay_state().get(
				"component_generation", 0
			)) == 1,
		"pooled reset clears the cue and starts fresh repair/component generations"
	)
	model.record_damage(70.0, Vector3.INF)
	component_id = _first_damaged_component(model)
	craft.set("_landed", true)
	var after_reset := craft.submit_crew_intent(
		1,
		77,
		&"repair_interrupt_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		10
	)
	_check(
		bool(after_reset.get("consumed", false))
			and bool(craft.get_engineer_repair_presentation_snapshot().get("visible", false)),
		"fresh authoritative work presents normally after pooled reset"
	)
	craft.queue_free()
	await process_frame


func _repair_request(craft: HeroShip, generation: int) -> Dictionary:
	return {
		"actor_id": &"engineer_test",
		"target_id": craft.get_ship_id(),
		"component_id": ComponentDamageType.COMPONENT_ENGINE_BAY,
		"generation": generation,
		"distance_meters": 0.0,
		"seated": true,
		"resource_id": &"repair_kit",
		"interrupted": false,
		"repair": 0.2,
	}


func _component_world_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for state: Dictionary in craft.get_component_damage().get_component_states():
		if StringName(state.get("id", &"")) == component_id:
			return craft.to_global(state.get("local_position", Vector3.ZERO) as Vector3)
	return craft.global_position


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for state: Dictionary in craft.get_component_damage().get_component_states():
		if StringName(state.get("id", &"")) == component_id:
			return state.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _build_jovian_role_authority() -> CrewSeatRoleAuthority:
	var authority := RoleAuthorityType.new(1) as CrewSeatRoleAuthority
	for seat: Array in [
		[&"pilot_station", RoleAuthorityType.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"passenger_port_01", RoleAuthorityType.ROLE_ENGINEER, &"passenger_port_01"],
		[&"co_pilot_station", RoleAuthorityType.ROLE_PASSENGER, &"co_pilot_station"],
		[&"passenger_port_00", RoleAuthorityType.ROLE_PASSENGER, &"passenger_port_00"],
		[&"freight_defense_slot", RoleAuthorityType.ROLE_GUNNER, &""],
	]:
		authority.register_seat(
			seat[0],
			&"jovian_provisional",
			seat[1],
			&"jovian_walkable_interior",
			1,
			seat[2]
		)
	authority.seal_roster()
	authority.claim(
		1,
		77,
		&"repair_interrupt_engineer",
		&"passenger_port_01",
		RoleAuthorityType.ROLE_ENGINEER,
		1
	)
	return authority


func _first_damaged_component(model: ShipComponentDamage) -> StringName:
	for component_id: StringName in ComponentDamageType.COMPONENT_ORDER:
		if model.get_component_integrity(component_id) < 1.0:
			return component_id
	return ComponentDamageType.COMPONENT_FORWARD_HULL


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: hero repair damage interruption (", _checks, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
