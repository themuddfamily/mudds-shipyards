extends SceneTree

## Focused Phase 7 runtime slice: an authority-admitted engineer receipt is
## consumed by the real Halyard and delegated to its existing component owner.
## No test here claims network transport, avatar control, or human sign-off.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

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
	var registered := authority.register_halyard_roster()
	_check(bool(registered.get("accepted", false)), "the Halyard roster seals in the session authority")
	var attached := craft.attach_crew_role_authority(authority)
	_check(bool(attached.get("accepted", false)), "the real Halyard accepts the sealed session authority")

	var claimed := authority.claim(
		1, 77, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1
	)
	_check(bool(claimed.get("accepted", false)), "the engineer claim is admitted for the physical systems seat")

	var model := craft.get_component_damage()
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
	var damaged := model.record_damage(70.0, Vector3.ZERO)
	_check(bool(damaged.get("accepted", false)), "the existing Halyard component owner accepts a live damage observation")
	model.tick_repair(10.0, true)
	var targeted_damage := model.record_damage(70.0, Vector3(0.0, 2.88, 0.325))
	_check(bool(targeted_damage.get("accepted", false)), "the component owner can isolate one damaged systems target")
	var system_id := _first_damaged_system(model)
	var integrity_before := model.get_component_integrity(system_id)
	_check(integrity_before >= 0.0 and integrity_before < 1.0, "the engineer has a damaged system to repair")
	var foreign := craft.submit_crew_intent(
		1, 77, &"engineer_avatar", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": &"foreign_reactor", "repair": 0.0, "system_generation": 1}, 2
	)
	_check(
		bool(foreign.get("accepted", false))
			and not bool(foreign.get("consumed", false))
			and (foreign.get("effect", {}) as Dictionary).get("status", &"") == &"foreign_component",
		"a foreign component identity is rejected before repair routing"
	)
	craft.set("_landed", true)
	var consumed := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.5, "system_generation": 1},
		3
	)
	var effect := consumed.get("effect", {}) as Dictionary
	_check(
		bool(consumed.get("accepted", false))
			and bool(consumed.get("consumed", false))
			and consumed.get("status", &"") == &"intent_consumed"
			and bool(effect.get("accepted", false)),
		"the Halyard consumes the authoritative engineer receipt exactly once"
	)
	_check(
		model.get_component_integrity(system_id) > integrity_before,
		"the consumed engineer receipt delegates a bounded repair pulse to the component owner"
	)
	_check(selected[0] == 1 and selected_generation[0] == 1, "the repair receipt selects its component target")
	var healthy := craft.submit_crew_intent(
		1, 77, &"engineer_avatar", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.0, "system_generation": 1}, 4
	)
	_check(
		bool(healthy.get("accepted", false))
			and not bool(healthy.get("consumed", false))
			and (healthy.get("effect", {}) as Dictionary).get("status", &"") == &"healthy_component",
		"a healthy component cannot be selected as a repair target"
	)

	var replay := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
			{"system_id": system_id, "repair": 0.5, "system_generation": 1},
		4
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"a replayed receipt cannot mutate the Halyard twice"
	)

	var handoff := craft.handoff_crew_role(
		1,
		77,
		&"engineer_avatar",
		&"crew_port_01",
		5,
		78,
		&"replacement_engineer",
		Authority.ROLE_ENGINEER,
		6
	)
	_check(
		bool(handoff.get("accepted", false))
			and cleared[0] == 1
			and clear_reason[0] == &"role_handoff",
		"engineer handoff clears the outgoing component selection"
	)
	var replacement_system_id := _first_damaged_system(model)
	var stale_generation := craft.submit_crew_intent(
		1,
		78,
		&"replacement_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": replacement_system_id, "repair": 0.0, "system_generation": 1},
		7
	)
	_check(
		bool(stale_generation.get("accepted", false))
			and not bool(stale_generation.get("consumed", false))
			and (stale_generation.get("effect", {}) as Dictionary).get("status", &"")
			== &"stale_component_generation",
		"a stale component generation cannot route a replacement repair"
	)
	var replacement := craft.submit_crew_intent(
		1,
		78,
		&"replacement_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": replacement_system_id, "repair": 0.0, "system_generation": 2},
		8
	)
	_check(
		bool(replacement.get("accepted", false))
			and bool(replacement.get("consumed", false))
			and selected[0] == 2
			and selected_generation[0] == 2,
		"the replacement engineer selects the fresh component generation"
	)
	var released := authority.release(1, 78, &"replacement_engineer", &"crew_port_01", 9)
	_check(bool(released.get("accepted", false)), "the replacement engineer can be detached")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_detached", "detach clears the replacement component selection")

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_CREW_ROLE_GAMEPLAY_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _first_damaged_system(model: ShipComponentDamage) -> StringName:
	for component_id: StringName in ShipComponentDamageType.COMPONENT_ORDER:
		if model.get_component_integrity(component_id) < 1.0:
			return component_id
	return ShipComponentDamageType.COMPONENT_FORWARD_HULL


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
