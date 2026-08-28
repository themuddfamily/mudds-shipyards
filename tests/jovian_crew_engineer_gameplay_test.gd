extends SceneTree

## Focused Jovian multicrew coverage. An authority-admitted engineer receipt
## selects a damaged ship component and delegates one bounded repair pulse to
## ShipComponentDamage; no second health, movement, combat, or seat ledger exists.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := JOVIAN_SCENE.instantiate() as HeroShip
	_check(craft != null, "production Jovian instantiates for optional engineer gameplay")
	if craft == null:
		_finish()
		return
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var authority = _build_authority()
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"Jovian accepts the sealed pilot/engineer role roster"
	)
	_check(craft.get_pilot_seat_anchor() != null, "pilot remains immediately available")
	_check(craft.get_engineer_seat_anchor() != null, "engineer maps to a physical passenger-cabin seat")
	_check(
		craft.get_engineer_status_text() == "IDLE // REPAIR READY\nKITS // 6/6",
		"the physical cabin panel boots with a text-readable finite repair stock"
	)
	var console_boot: Dictionary = craft.get_engineer_console_presentation_snapshot()
	_check(
		bool(console_boot.get("attached", false))
			and StringName(console_boot.get("state", &"")) == &"idle"
			and not bool((console_boot.get("authority", {}) as Dictionary).get("repair", true)),
		"the physical console is attached as presentation only"
	)

	var selected := [0]
	var cleared := [0]
	var selected_generation := [0]
	var clear_reason := [StringName(&"")]
	craft.engineer_component_selected.connect(
		func(_component_id: StringName, generation: int, _receipt: Dictionary) -> void:
			selected[0] += 1
			selected_generation[0] = generation
	)
	craft.engineer_component_cleared.connect(
		func(_component_id: StringName, _generation: int, reason: StringName) -> void:
			cleared[0] += 1
			clear_reason[0] = reason
	)

	var model := craft.get_component_damage()
	# An unlocated hit distributes damage across the roster, giving the live
	# engineer consumer both a selected target and an adjacent damaged system.
	var damaged := model.record_damage(70.0, Vector3.INF)
	_check(bool(damaged.get("accepted", false)), "existing Jovian component owner accepts live damage")
	var component_id := _first_damaged_component(model)
	var adjacent_component_id := _other_damaged_component(model, component_id)
	var integrity_before := model.get_component_integrity(component_id)
	var adjacent_integrity_before := model.get_component_integrity(adjacent_component_id)
	_check(integrity_before >= 0.0 and integrity_before < 1.0, "engineer has a damaged component target")
	_check(
		adjacent_integrity_before >= 0.0 and adjacent_integrity_before < 1.0,
		"engineer repair scenario retains a second damaged component"
	)
	craft.set("_landed", true)

	var foreign = craft.submit_crew_intent(
		1,
		77,
		&"jovian_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": &"foreign_reactor", "repair": 0.0, "system_generation": 1},
		2
	)
	_check(
		bool(foreign.get("accepted", false))
			and not bool(foreign.get("consumed", false))
			and (foreign.get("effect", {}) as Dictionary).get("status", &"") == &"foreign_component",
		"foreign component identities fail closed before repair routing"
	)

	var consumed = craft.submit_crew_intent(
		1,
		77,
		&"jovian_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		3
	)
	var effect := consumed.get("effect", {}) as Dictionary
	_check(
		bool(consumed.get("accepted", false))
			and bool(consumed.get("consumed", false))
			and consumed.get("status", &"") == &"intent_consumed"
			and effect.get("status", &"") == &"repair_started",
		"admitted engineer receipt reserves one shared-authority repair action"
	)
	_check(
		is_equal_approx(model.get_component_integrity(component_id), integrity_before)
			and is_equal_approx(
				model.get_component_integrity(adjacent_component_id),
				adjacent_integrity_before
			)
			and craft.get_engineer_status_text().contains("REPAIRING //")
			and craft.get_engineer_status_text().contains("PROGRESS // 0%"),
		"pending work mutates no component and is visible on the physical cabin panel"
	)
	await physics_frame
	await physics_frame
	var integrity_at_departure := model.get_component_integrity(component_id)
	_check(
		integrity_at_departure > integrity_before,
		"passive berth repair continues while engineer work is pending"
	)
	craft.set("_landed", false)
	await physics_frame
	var interrupted: Dictionary = craft.get_engineer_repair_state()
	_check(
		StringName(interrupted.get("status", &"")) == &"interrupted"
			and StringName(interrupted.get("reason", &"")) == &"left_berth"
			and is_equal_approx(
				model.get_component_integrity(component_id), integrity_at_departure
			)
			and is_zero_approx(float(interrupted.get("cooldown_remaining", -1.0)))
			and craft.get_engineer_status_text().contains("ABORTED // LEFT BERTH"),
		"departing the berth visibly interrupts without repair commit or cooldown"
	)
	craft.set("_landed", true)
	_check(
		bool(model.record_damage(70.0, Vector3.INF).get("accepted", false)),
		"the interrupted Jovian systems can receive fresh damage before retry"
	)
	var restart_before := model.get_component_integrity(component_id)
	var adjacent_restart_before := model.get_component_integrity(adjacent_component_id)
	var restarted = craft.submit_crew_intent(
		1,
		77,
		&"jovian_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		4
	)
	_check(
		bool(restarted.get("consumed", false))
			and (restarted.get("effect", {}) as Dictionary).get("status", &"") == &"repair_started",
		"interruption preserves the resource so the engineer can retry"
	)
	for _frame in 60:
		if StringName(craft.get_engineer_repair_state().get("status", &"")) == &"completed":
			break
		await physics_frame
	var completed: Dictionary = craft.get_engineer_repair_state()
	var completion_receipt := completed.get("receipt", {}) as Dictionary
	var completion_operation := completion_receipt.get("operation", {}) as Dictionary
	var selected_gain := model.get_component_integrity(component_id) - restart_before
	var adjacent_gain := (
		model.get_component_integrity(adjacent_component_id) - adjacent_restart_before
	)
	_check(
		StringName(completed.get("status", &"")) == &"completed"
			and int(completion_operation.get("repaired_components", 0)) == 1
			and selected_gain > adjacent_gain
			and float(completed.get("cooldown_remaining", 0.0)) > 0.0
			and int(completed.get("resource_units", -1)) == 5
			and int(completed.get("resource_capacity", -1)) == 6
			and craft.get_engineer_status_text().contains("COMPLETED //")
			and craft.get_engineer_status_text().contains("KITS // 5/6"),
		"completion targets one component and visibly spends one finite repair kit"
	)
	_check(selected[0] == 2 and selected_generation[0] == 1, "repair retry retains the generation-fenced target")
	model.record_damage(20.0, Vector3.INF)
	var cooldown_attempt = craft.submit_crew_intent(
		1,
		77,
		&"jovian_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		5
	)
	_check(
		bool(cooldown_attempt.get("accepted", false))
			and not bool(cooldown_attempt.get("consumed", false))
			and (cooldown_attempt.get("effect", {}) as Dictionary).get("status", &"") == &"cooldown",
		"a second Jovian repair is rejected until the visible cooldown expires"
	)

	var replay = craft.submit_crew_intent(
		1,
		77,
		&"jovian_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.2, "system_generation": 1},
		5
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"replayed engineer receipt cannot repair twice"
	)

	var handoff = craft.handoff_crew_role(
		1,
		77,
		&"jovian_engineer",
		&"passenger_port_01",
		6,
		99,
		&"replacement_engineer",
		Authority.ROLE_ENGINEER,
		7
	)
	_check(
		bool(handoff.get("accepted", false))
			and cleared[0] == 1
			and clear_reason[0] == &"role_handoff"
			and int(craft.get_engineer_repair_state().get("resource_units", -1)) == 5,
		"engineer handoff clears selection without refilling the ship's repair kits"
	)
	var refreshed_damage := model.record_damage(20.0, Vector3.ZERO)
	_check(bool(refreshed_damage.get("accepted", false)), "the existing component owner can expose a fresh damaged generation")

	var stale = craft.submit_crew_intent(
		1,
		99,
		&"replacement_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.0, "system_generation": 1},
		8
	)
	_check(
		bool(stale.get("accepted", false))
			and not bool(stale.get("consumed", false))
			and (stale.get("effect", {}) as Dictionary).get("status", &"") == &"stale_component_generation",
		"old component generation cannot be reused after handoff"
	)

	var fresh = craft.submit_crew_intent(
		1,
		99,
		&"replacement_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.0, "system_generation": 2},
		9
	)
	_check(
		bool(fresh.get("accepted", false))
			and bool(fresh.get("consumed", false))
			and selected[0] == 3
			and selected_generation[0] == 2,
		"replacement engineer selects against the fresh component generation"
	)

	var released = craft.release_crew_role(
		1,
		99,
		&"replacement_engineer",
		&"passenger_port_01",
		10
	)
	_check(bool(released.get("accepted", false)), "replacement engineer releases through the same authority")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_released", "detach clears replacement selection")
	var released_console: Dictionary = craft.get_engineer_console_presentation_snapshot()
	_check(
		StringName(released_console.get("state", &"")) == &"idle"
			and int(released_console.get("last_sequence", -2)) >= 0
			and craft.get_engineer_status_text() == "IDLE // REPAIR READY\nKITS // 5/6",
		"role release clears stale work while preserving the visible remaining stock"
	)

	var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, 6.0)))
	_check(bool(reset.get("accepted", false)), "Jovian reuse transaction remains available after role cleanup")
	var state: Dictionary = craft.get_engineer_gameplay_state()
	_check(
		(state.get("selection", {}) as Dictionary).is_empty()
			and int(state.get("component_generation", 0)) == 1
			and StringName((state.get("repair", {}) as Dictionary).get("status", &"")) == &"idle"
			and int((state.get("repair", {}) as Dictionary).get("resource_units", -1)) == 6
			and craft.get_engineer_status_text() == "IDLE // REPAIR READY\nKITS // 6/6",
		"reuse resets selection and restores the authored repair-kit budget"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _build_authority():
	var authority := Authority.new(1)
	for seat in [
		[&"pilot_station", Authority.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"passenger_port_01", Authority.ROLE_ENGINEER, &"passenger_port_01"],
		[&"co_pilot_station", Authority.ROLE_PASSENGER, &"co_pilot_station"],
		[&"passenger_port_00", Authority.ROLE_PASSENGER, &"passenger_port_00"],
		[&"freight_defense_slot", Authority.ROLE_GUNNER, &""],
	]:
		var result := authority.register_seat(
			seat[0],
			&"jovian_provisional",
			seat[1],
			&"jovian_walkable_interior",
			1,
			seat[2]
		)
		_check(bool(result.get("accepted", false)), "Jovian role seat registers: %s" % seat[0])
	var sealed := authority.seal_roster()
	_check(bool(sealed.get("accepted", false)), "Jovian role roster seals before claims")
	_check(
		bool(authority.claim(1, 77, &"jovian_engineer", &"passenger_port_01", Authority.ROLE_ENGINEER, 1).get("accepted", false)),
		"server admits the optional engineer at the physical seat"
	)
	return authority


func _first_damaged_component(model: ShipComponentDamage) -> StringName:
	for component_id: StringName in ShipComponentDamageType.COMPONENT_ORDER:
		if model.get_component_integrity(component_id) < 1.0:
			return component_id
	return ShipComponentDamageType.COMPONENT_FORWARD_HULL


func _other_damaged_component(
	model: ShipComponentDamage,
	selected_component_id: StringName
) -> StringName:
	for component_id: StringName in ShipComponentDamageType.COMPONENT_ORDER:
		if component_id != selected_component_id \
				and model.get_component_integrity(component_id) < 1.0:
			return component_id
	return &""


func _finish() -> void:
	print("JOVIAN_CREW_ENGINEER_GAMEPLAY: %d checks, %d failures" % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
