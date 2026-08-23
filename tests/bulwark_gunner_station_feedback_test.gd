extends SceneTree

## Focused coverage for the physical Bulwark gunner readout. The readout only
## consumes target, charge, cooldown, and component state owned by the existing
## crew and combat authorities.

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
	_check(craft != null, "production Bulwark instantiates with its physical gunner station")
	if craft == null:
		_finish()
		return
	root.add_child(craft)
	var combat_authority := LiveCombatAuthority.new()
	root.add_child(combat_authority)
	await process_frame
	await physics_frame

	var authority := Authority.new(1)
	for seat in [
		[&"pilot_station", Authority.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"gunner_station", Authority.ROLE_GUNNER, &"gunner_station_anchor"],
		[&"passenger_slot", Authority.ROLE_PASSENGER, &""],
		[&"engineer_slot", Authority.ROLE_ENGINEER, &""],
	]:
		_check(
			bool(authority.register_seat(
				seat[0], &"bulwark_heavy_gunship", seat[1], &"bulwark_flight_deck", 1, seat[2]
			).get("accepted", false)),
			"required Bulwark seat registers: %s" % seat[0]
		)
	_check(bool(authority.seal_roster().get("accepted", false)), "focused role roster seals")
	_check(
		bool(authority.claim(
			1, 88, &"bulwark_gunner", &"gunner_station", Authority.ROLE_GUNNER, 1
		).get("accepted", false)),
		"gunner occupies the physical station"
	)
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"Bulwark consumes the existing role authority"
	)
	_check(
		bool(craft.attach_gunner_combat_authority(combat_authority).get("accepted", false)),
		"Bulwark consumes the shared combat authority"
	)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)

	var readout := craft.get_node_or_null(
		"BulwarkHeavyGunshipVisual/GunnerStation/GunnerStatusReadout"
	) as Label3D
	var feedback := craft.call("get_gunner_station_feedback_snapshot") as Dictionary
	_check(
		readout != null
			and feedback.get("state", &"") == Bulwark.GUNNER_FEEDBACK_NO_TARGET
			and readout.text.contains("NO TARGET"),
		"the physical console starts with an explicit no-target cue"
	)

	var selected := _submit_gunner(craft, false, 2)
	feedback = craft.call("get_gunner_station_feedback_snapshot") as Dictionary
	_check(
		bool(selected.get("consumed", false))
			and feedback.get("state", &"") == Bulwark.GUNNER_FEEDBACK_READY
			and feedback.get("target_id", &"") == &"feedback_target"
			and readout.text.contains("LOCKED")
			and readout.text.contains("READY"),
		"target selection makes lock and fire readiness readable at the station"
	)

	var charge := _submit_gunner(craft, true, 3)
	feedback = craft.call("get_gunner_station_feedback_snapshot") as Dictionary
	_check(
		bool(charge.get("consumed", false))
			and (charge.get("effect", {}) as Dictionary).get("status", &"") == &"charge_started"
			and feedback.get("state", &"") == Bulwark.GUNNER_FEEDBACK_CHARGING
			and readout.text.contains("CHARGING"),
		"the authoritative charge exposes progress instead of appearing ready"
	)
	for _frame in 30:
		await physics_frame

	var fired := _submit_gunner(craft, true, 4)
	feedback = craft.call("get_gunner_station_feedback_snapshot") as Dictionary
	_check(
		bool(fired.get("consumed", false))
			and (fired.get("effect", {}) as Dictionary).get("status", &"") == &"siege_lance_resolved"
			and feedback.get("state", &"") == Bulwark.GUNNER_FEEDBACK_COOLDOWN
			and float(feedback.get("cooldown_remaining", 0.0)) > 0.0
			and readout.text.contains("COOLDOWN"),
		"resolved fire exposes the remaining authoritative cooldown"
	)

	craft.get_component_damage().record_damage(300.0)
	feedback = craft.call("get_gunner_station_feedback_snapshot") as Dictionary
	_check(
		feedback.get("state", &"") == Bulwark.GUNNER_FEEDBACK_DENIED
			and feedback.get("denial_reason", &"") == &"gunner_weapon_component_failed"
			and readout.text.contains("WEAPON OFFLINE"),
		"component denial replaces cooldown with an explicit weapon-offline cue"
	)

	craft.queue_free()
	combat_authority.queue_free()
	await process_frame
	_finish()


func _submit_gunner(craft: HeroShip, trigger: bool, sequence: int) -> Dictionary:
	return craft.call(
		"submit_crew_intent",
		1,
		88,
		&"bulwark_gunner",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID,
			"target_id": &"feedback_target",
			"trigger": trigger,
			"target_generation": 1,
		},
		sequence
	) as Dictionary


func _finish() -> void:
	print("BULWARK_GUNNER_STATION_FEEDBACK: %d checks, %d failures" % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
