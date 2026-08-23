extends SceneTree

## Focused Bulwark multicrew coverage. The server-owned seat authority admits
## the optional gunner, while HeroShip remains the sole projectile request
## seam; target identity is only a bounded receipt and damage is not mutated.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := BULWARK_SCENE.instantiate() as HeroShip
	_check(craft != null, "production Bulwark instantiates for optional gunner gameplay")
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
		"Bulwark accepts the sealed server-owned pilot/gunner role roster"
	)
	_check(craft.get_pilot_seat_anchor() != null, "pilot seat remains immediately available")

	var emitted := [0]
	var selected := [0]
	var cleared := [0]
	var selected_generation := [0]
	var clear_reason := [StringName(&"")]
	craft.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		emitted[0] += 1
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

	var fired = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
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
			and effect.get("status", &"") == &"weapon_request_emitted",
		"admitted gunner receipt reaches HeroShip's existing weapon request"
	)
	_check(emitted[0] == 1, "exactly one projectile request is emitted")
	_check(selected[0] == 1 and selected_generation[0] == 1, "fire selects the bounded target generation")
	_check(
		effect.get("source_id", 0) == Bulwark.COMBAT_SOURCE_ID
			and effect.get("faction_id", &"") == Bulwark.BULWARK_CREW_FACTION_ID
			and effect.get("weapon_id", &"") == Bulwark.BULWARK_CREW_WEAPON_ID,
		"request carries Bulwark source, faction, and weapon identity"
	)

	var selection_only = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
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
		"target selection is consumable independently of fire cadence"
	)

	var cooldown = craft.submit_crew_intent(
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
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
		"HeroShip cadence blocks a second gunner request"
	)

	var handoff = craft.handoff_crew_role(
		1,
		88,
		&"bulwark_gunner",
		&"gunner_station",
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
		"gunner handoff clears the outgoing target exactly once"
	)

	var stale = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": false,
			"target_generation": 1,
		},
		7
	)
	_check(
		bool(stale.get("accepted", false))
			and not bool(stale.get("consumed", false))
			and (stale.get("effect", {}) as Dictionary).get("status", &"") == &"stale_target_generation",
		"old target generation cannot be reused after handoff"
	)

	var replacement = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
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
		"replacement gunner selects against the fresh generation"
	)

	var released = craft.release_crew_role(
		1,
		99,
		&"replacement_gunner",
		&"gunner_station",
		9
	)
	_check(bool(released.get("accepted", false)), "replacement gunner releases through the same authority")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_released", "detach clears replacement target state")

	craft.queue_free()
	await process_frame
	_finish()


func _build_authority():
	var authority := Authority.new(1)
	for seat in [
		[&"pilot_station", Authority.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"gunner_station", Authority.ROLE_GUNNER, &"gunner_station_anchor"],
		[&"passenger_slot", Authority.ROLE_PASSENGER, &""],
		[&"engineer_slot", Authority.ROLE_ENGINEER, &""],
	]:
		var result := authority.register_seat(
			seat[0],
			&"bulwark_heavy_gunship",
			seat[1],
			&"bulwark_flight_deck",
			1,
			seat[2]
		)
		_check(bool(result.get("accepted", false)), "Bulwark role seat registers: %s" % seat[0])
	var sealed := authority.seal_roster()
	_check(bool(sealed.get("accepted", false)), "Bulwark role roster seals before claims")
	_check(
		bool(authority.claim(1, 88, &"bulwark_gunner", &"gunner_station", Authority.ROLE_GUNNER, 1).get("accepted", false)),
		"server admits the optional gunner at the physical station"
	)
	return authority


func _finish() -> void:
	print("BULWARK_CREW_GUNNER_GAMEPLAY: %d checks, %d failures" % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
