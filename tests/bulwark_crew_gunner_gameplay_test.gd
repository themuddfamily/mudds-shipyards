extends SceneTree

## Focused Bulwark multicrew coverage. The server-owned seat authority admits
## the optional gunner, while HeroShip remains the pilot projectile request
## seam and the shared CombatResolver remains gunner damage authority.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const LiveCombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")

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
	var combat_authority := LiveCombatAuthority.new()
	combat_authority.name = "BulwarkCombatAuthority"
	root.add_child(combat_authority)
	await process_frame
	await physics_frame
	await physics_frame

	var authority = _build_authority()
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"Bulwark accepts the sealed server-owned pilot/gunner role roster"
	)
	_check(craft.get_pilot_seat_anchor() != null, "pilot seat remains immediately available")
	_check(
		bool(craft.attach_gunner_combat_authority(combat_authority).get("accepted", false)),
		"Bulwark gunner binds the shared resolver authority"
	)

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
			and effect.get("status", &"") == &"charge_started"
			and is_equal_approx(float(effect.get("charge_progress", -1.0)), 0.0),
		"admitted gunner receipt starts the bounded siege-lance charge"
	)
	_check(emitted[0] == 0, "gunner dispatch does not take over the pilot projectile seam")
	_check(selected[0] == 1 and selected_generation[0] == 1, "fire selects the bounded target generation")
	_check(
		(craft.get_gunner_gameplay_state().get("role_charges", {}) as Dictionary).size() == 1,
		"charge progress remains detached and inspectable while physics advances"
	)
	for _frame in 30:
		await physics_frame

	var resolved = craft.submit_crew_intent(
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
		3
	)
	var resolved_effect := resolved.get("effect", {}) as Dictionary
	_check(
		bool(resolved.get("accepted", false))
			and bool(resolved.get("consumed", false))
			and resolved_effect.get("status", &"") == &"siege_lance_resolved"
			and bool((resolved_effect.get("resolution", {}) as Dictionary).get("accepted", false)),
		"the charged gunner receipt reaches the shared siege-lance resolver"
	)
	_check(
		resolved_effect.get("source_id", 0) == Bulwark.COMBAT_SOURCE_ID
			and resolved_effect.get("faction_id", &"") == Bulwark.BULWARK_CREW_FACTION_ID
			and resolved_effect.get("weapon_id", &"") == Bulwark.BULWARK_CREW_WEAPON_ID,
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
		4
	)
	_check(
		bool(selection_only.get("accepted", false))
			and bool(selection_only.get("consumed", false))
			and (selection_only.get("effect", {}) as Dictionary).get("status", &"") == &"target_selected"
			and selected[0] == 3
			and emitted[0] == 0,
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
		5
	)
	_check(
		bool(cooldown.get("accepted", false))
			and not bool(cooldown.get("consumed", false))
			and (cooldown.get("effect", {}) as Dictionary).get("status", &"") == &"role_cooldown"
			and emitted[0] == 0,
		"gunner siege-lance cadence blocks a second request without affecting pilot fire"
	)

	var handoff = craft.handoff_crew_role(
		1,
		88,
		&"bulwark_gunner",
		&"gunner_station",
		6,
		99,
		&"replacement_gunner",
		Authority.ROLE_GUNNER,
		7
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
		8
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
		9
	)
	_check(
		bool(replacement.get("accepted", false))
			and bool(replacement.get("consumed", false))
			and selected_generation[0] == 2,
		"replacement gunner selects against the fresh generation"
	)

	var replacement_charge = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": true,
			"target_generation": 2,
		},
		10
	)
	var replacement_charge_effect := replacement_charge.get("effect", {}) as Dictionary
	_check(
		bool(replacement_charge.get("accepted", false))
			and bool(replacement_charge.get("consumed", false))
			and replacement_charge_effect.get("status", &"") == &"charge_started",
		"replacement gunner starts without inheriting the old charge"
	)
	for _frame in 30:
		await physics_frame
	var replacement_fire = craft.submit_crew_intent(
		1,
		99,
		&"replacement_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"range_target_02",
			"trigger": true,
			"target_generation": 2,
		},
		11
	)
	var replacement_effect := replacement_fire.get("effect", {}) as Dictionary
	_check(
		bool(replacement_fire.get("accepted", false))
			and bool(replacement_fire.get("consumed", false))
			and replacement_effect.get("status", &"") == &"siege_lance_resolved"
			and replacement_effect.get("ammunition_remaining", -1) == 1,
		"replacement gunner dispatches with fresh cooldown and ammunition state"
	)

	var released = craft.release_crew_role(
		1,
		99,
		&"replacement_gunner",
		&"gunner_station",
		12
	)
	_check(bool(released.get("accepted", false)), "replacement gunner releases through the same authority")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_released", "detach clears replacement target state")

	var component_model := craft.get_component_damage()
	_check(component_model != null and component_model.is_configured(), "Bulwark exposes the existing component damage ledger")
	component_model.record_damage(300.0)
	var failed_component := craft.get_gunner_gameplay_state().get("gunner_component", {}) as Dictionary
	_check(
		not bool(failed_component.get("available", true))
			and failed_component.get("reason", &"") == &"gunner_weapon_component_failed",
		"a failed weapon component blocks a new gunner charge with an inspectable reason"
	)
	_check(
		bool(authority.claim(1, 88, &"fresh_gunner", &"gunner_station", Authority.ROLE_GUNNER, 13).get("accepted", false)),
		"server admits a fresh gunner after the previous release"
	)
	var blocked = craft.submit_crew_intent(
		1,
		88,
		&"fresh_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"failed_target",
			"trigger": true,
			"target_generation": 3,
		},
		14
	)
	_check(
		bool(blocked.get("accepted", false))
			and not bool(blocked.get("consumed", false))
			and (blocked.get("effect", {}) as Dictionary).get("status", &"") == &"gunner_weapon_component_failed",
		"failed component rejects the authorized gunner dispatch before charge"
	)
	craft.set("_landed", true)
	var repaired_once: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": &"port_wing",
			"repair": 0.1,
			"system_generation": 1,
		},
		2
	)
	_check(
		bool(repaired_once.get("accepted", false))
			and bool(repaired_once.get("consumed", false))
			and (repaired_once.get("effect", {}) as Dictionary).get("status", &"") == &"repair_applied",
		"the authorized engineer restores the same component ledger"
	)
	var impaired_component := craft.get_gunner_gameplay_state().get("gunner_component", {}) as Dictionary
	_check(
		bool(impaired_component.get("available", false))
			and float(impaired_component.get("fire_multiplier", 1.0)) < 1.0,
		"a damaged weapon component exposes a reduced allowed cadence"
	)
	# Keep the craft in the damaged flight state while the charge/cooldown
	# evidence is observed; HeroShip's automatic berth repair remains untouched.
	craft.set("_landed", false)
	var impaired_charge: Dictionary = craft.submit_crew_intent(
		1,
		88,
		&"fresh_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"impaired_target",
			"trigger": true,
			"target_generation": 3,
		},
		15
	)
	var impaired_effect := impaired_charge.get("effect", {}) as Dictionary
	_check(
		bool(impaired_charge.get("accepted", false))
			and impaired_effect.get("status", &"") == &"charge_started"
			and float(impaired_effect.get("charge_remaining", 0.0)) > Bulwark.GUNNER_SIEGE_CHARGE_TIME,
		"impaired weapon component lengthens the siege-lance charge window"
	)
	for _frame in 100:
		await physics_frame
	var impaired_fire: Dictionary = craft.submit_crew_intent(
		1,
		88,
		&"fresh_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"impaired_target",
			"trigger": true,
			"target_generation": 3,
		},
		16
	)
	_check(
		bool(impaired_fire.get("consumed", false))
			and float((impaired_fire.get("effect", {}) as Dictionary).get("cooldown_remaining", 0.0)) > 1.0 / 0.2083333,
		"impaired weapon component lengthens the resolved siege-lance cooldown"
	)
	craft.set("_landed", true)
	var repaired_nominal: Dictionary = craft.submit_crew_intent(
		1,
		77,
		&"bulwark_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{
			"system_id": &"port_wing",
			"repair": 0.1,
			"system_generation": 1,
		},
		3
	)
	_check(bool(repaired_nominal.get("consumed", false)), "engineer repair returns the weapon component toward nominal")

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
	_check(
		bool(authority.claim(1, 77, &"bulwark_engineer", &"engineer_slot", Authority.ROLE_ENGINEER, 1).get("accepted", false)),
		"server admits the optional engineer at the systems station"
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
