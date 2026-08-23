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
	var damaged := model.record_damage(70.0, Vector3.ZERO)
	_check(bool(damaged.get("accepted", false)), "the existing Halyard component owner accepts a live damage observation")
	var system_id := _first_damaged_system(model)
	var integrity_before := model.get_component_integrity(system_id)
	_check(integrity_before >= 0.0 and integrity_before < 1.0, "the engineer has a damaged system to repair")

	craft.set("_landed", true)
	var consumed := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.5},
		2
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

	var replay := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.5},
		2
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"a replayed receipt cannot mutate the Halyard twice"
	)

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
