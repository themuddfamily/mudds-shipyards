extends SceneTree

const AuthorityScript := preload("res://scripts/combat/repair_authority.gd")
const DamageScript := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var model := DamageScript.new() as ShipComponentDamage
	root.add_child(model)
	_check(
		model.configure(AABB(Vector3(-2.0, -1.0, -3.0), Vector3(4.0, 2.0, 6.0)), 100.0),
		"the real ship-local component adapter configures"
	)
	var damaged := model.record_damage(80.0, Vector3(0.0, 0.0, 2.8))
	var component_id := _worst_component(model)
	var before := model.get_component_integrity(component_id)
	_check(bool(damaged.accepted) and before < 1.0, "one real component is damaged")

	var authority := AuthorityScript.new(
		&"ember_player_41", &"ember_craft_72", &"ember_service_charge",
		48.0, 0.0, 0.20, 2,
		&"ember_bunker_service_terminal", 7, 2.5
	) as RepairAuthority
	_check(
		authority.is_configuration_valid()
			and bool(authority.begin_generation(model.get_ledger_generation()).accepted),
		"service-terminal admission shares one valid repair generation"
	)
	var base := _request(component_id, model.get_ledger_generation(), 5)
	var seated_forgery := base.duplicate(true)
	seated_forgery.erase("player_on_foot")
	seated_forgery["seated"] = true
	_check(
		not bool(authority.request_repair(seated_forgery).accepted)
			and authority.request_repair(seated_forgery).reason \
				== &"invalid_service_terminal_context",
		"service admission cannot substitute the engineer seated flag"
	)
	var wrong_terminal := base.duplicate(true)
	wrong_terminal.terminal_id = &"foreign_terminal"
	var stale_terminal := base.duplicate(true)
	stale_terminal.terminal_generation = 6
	_check(
		authority.request_repair(wrong_terminal).reason == &"terminal_mismatch"
			and authority.request_repair(stale_terminal).reason \
				== &"stale_terminal_generation",
		"stable terminal identity and generation are exact"
	)
	var off_foot := base.duplicate(true)
	off_foot.player_on_foot = false
	var airborne := base.duplicate(true)
	airborne.craft_landed = false
	var foreign := base.duplicate(true)
	foreign.craft_owned = false
	_check(
		authority.request_repair(off_foot).reason == &"player_on_foot_required"
			and authority.request_repair(airborne).reason == &"craft_landed_required"
			and authority.request_repair(foreign).reason == &"craft_owned_required",
		"on-foot, landed, and ownership evidence all fail closed"
	)
	var far_actor := base.duplicate(true)
	far_actor.actor_distance_meters = 2.51
	var far_craft := base.duplicate(true)
	far_craft.distance_meters = 48.01
	_check(
		authority.request_repair(far_actor).reason == &"actor_out_of_range"
			and authority.request_repair(far_craft).reason == &"out_of_range",
		"player and craft proximity use their separate authored bounds"
	)
	var requested := authority.request_repair(base)
	var committed := authority.commit_component_repair(
		model, int(requested.get("token", -1))
	)
	var after := model.get_component_integrity(component_id)
	_check(
		bool(requested.accepted) and bool(committed.accepted)
			and committed.admission_kind == &"service_terminal"
			and committed.terminal_id == &"ember_bunker_service_terminal"
			and int(committed.terminal_generation) == 7
			and int(committed.request_sequence) == 5
			and after > before and after <= before + 0.200001,
		"the existing token commits one bounded pulse through the component adapter"
	)
	_check(
		authority.request_repair(base).reason == &"stale_request_sequence",
		"a committed service request sequence cannot replay"
	)
	var next := _request(component_id, model.get_ledger_generation(), 6)
	var pending := authority.request_repair(next)
	var interrupted := authority.interrupt(&"terminal_detached")
	_check(
		bool(pending.accepted) and bool(interrupted.accepted)
			and interrupted.admission_kind == &"service_terminal"
			and int(interrupted.request_sequence) == 6
			and not authority.has_active_repair(),
		"the existing interruption path clears a pending service token"
	)

	var engineer := AuthorityScript.new(
		&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 1.0, 0.2, 1
	) as RepairAuthority
	engineer.begin_generation(model.get_ledger_generation())
	var engineer_request := {
		"actor_id": &"pilot_one", "target_id": &"torrent_hull",
		"component_id": component_id, "generation": model.get_ledger_generation(),
		"distance_meters": 0.0, "seated": true,
		"resource_id": &"repair_kit", "interrupted": false,
	}
	_check(
		bool(engineer.request_repair(engineer_request).accepted),
		"the legacy engineer-seat envelope remains unchanged"
	)

	model.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("REPAIR_AUTHORITY_SERVICE_TERMINAL_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _request(component_id: StringName, generation: int, sequence: int) -> Dictionary:
	return {
		"actor_id": &"ember_player_41",
		"target_id": &"ember_craft_72",
		"component_id": component_id,
		"generation": generation,
		"distance_meters": 26.0,
		"actor_distance_meters": 0.5,
		"resource_id": &"ember_service_charge",
		"interrupted": false,
		"admission_kind": &"service_terminal",
		"terminal_id": &"ember_bunker_service_terminal",
		"terminal_generation": 7,
		"request_sequence": sequence,
		"player_on_foot": true,
		"craft_landed": true,
		"craft_owned": true,
		"repair": 0.20,
	}


func _worst_component(model: ShipComponentDamage) -> StringName:
	var selected := &""
	var integrity := 1.0
	for component in model.get_component_report().components as Array:
		if float(component.integrity) < integrity:
			selected = StringName(component.id)
			integrity = float(component.integrity)
	return selected


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
