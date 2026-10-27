extends SceneTree
## Small component fixture: only ammo, cooldown and engine state are staged.
## Actual authority admission, charge physics, resolver and console remain live.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const CombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const AVATAR: StringName = &"bulwark_gunner"
const ACTOR: StringName = &"88:bulwark_gunner"

var _checks := 0
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var craft := BULWARK_SCENE.instantiate() as BulwarkHeavyGunship
	var combat := CombatAuthority.new()
	var target := Node3D.new()
	target.name = "UntouchedEmptyMagazineTarget"
	target.set_meta("health", 100.0)
	root.add_child(craft)
	root.add_child(combat)
	root.add_child(target)
	await process_frame
	await physics_frame
	var authority := Authority.new(1)
	_check(bool(authority.register_bulwark_roster().get("accepted", false)), "FIXTURE_ROSTER")
	_check(bool(authority.claim(1, 88, AVATAR, &"gunner_station", Authority.ROLE_GUNNER, 1).get("accepted", false)), "FIXTURE_CURRENT_GUNNER")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "FIXTURE_ROLE_OWNER")
	_check(bool(craft.attach_gunner_combat_authority(combat).get("accepted", false)), "FIXTURE_COMBAT_OWNER")
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	var submissions := [0]
	combat.authoritative_shot_submitted.connect(func(_request, _resolution: Dictionary) -> void: submissions[0] += 1)
	var charged := _fire(craft, 2)
	_check(bool(charged.get("consumed", false)) and charged.get("effect", {}).get("status", &"") == &"charge_started", "POSITIVE_AMMO_STARTS_CHARGE")
	var retained_charge: Dictionary = craft.get_gunner_gameplay_state().role_charges
	var stale := _fire(craft, 2)
	_check(not bool(stale.get("accepted", true)) and craft.get_gunner_gameplay_state().role_charges == retained_charge, "STALE_REQUEST_PRESERVES_CHARGE")
	for _tick in 30:
		await physics_frame
	var discharged := _fire(craft, 3)
	_check(bool(discharged.get("consumed", false)) and discharged.get("effect", {}).get("status", &"") == &"siege_lance_resolved" and submissions[0] == 1, "POSITIVE_CHARGE_REACHES_RESOLVER")
	var cooldown := _fire(craft, 4)
	_check(cooldown.get("effect", {}).get("status", &"") == &"role_cooldown" and submissions[0] == 1, "ORIGINAL_COOLDOWN_BLOCKS_RESUBMISSION")
	# Explicit staged depletion isolates the consumer/UI regression. The full
	# native member independently earns zero ammo through two real damage hits.
	craft.set("_gunner_role_ammunition", {ACTOR: 0})
	craft.set("_gunner_role_cooldowns", {})
	_fire(craft, 5)
	for _tick in 30:
		await physics_frame
	var refused := _fire(craft, 6)
	var state := craft.get_gunner_gameplay_state()
	var feedback := craft.get_gunner_station_feedback_snapshot()
	var readout := craft.get_node("BulwarkHeavyGunshipVisual/GunnerStation/GunnerStatusReadout") as Label3D
	print("BULWARK_EMPTY_MAGAZINE_STATE: " + JSON.stringify({
		"charges": state.role_charges, "ammunition": state.role_ammunition,
		"feedback_state": str(feedback.get("state", &"")), "denial_reason": str(feedback.get("denial_reason", &"")),
		"readout": readout.text, "effect_status": str(refused.get("effect", {}).get("status", &"")),
		"submissions": submissions[0], "target_health": float(target.get_meta("health")),
		"positive_effect_status": str(discharged.get("effect", {}).get("status", &"")),
		"cooldown_effect_status": str(cooldown.get("effect", {}).get("status", &"")),
	}))
	_check(not bool(refused.get("consumed", true)) and refused.get("effect", {}).get("status", &"") == &"ammunition_depleted", "EMPTY_MAGAZINE_CONSUMER_REFUSED")
	_check((state.role_charges as Dictionary).is_empty(), "EMPTY_MAGAZINE_NO_LINGERING_CHARGE")
	_check(feedback.get("state", &"") == &"denied" and feedback.get("denial_reason", &"") == &"ammunition_depleted", "EMPTY_MAGAZINE_FEEDBACK_DENIED")
	_check(readout.text.contains("! AMMUNITION EMPTY"), "EMPTY_MAGAZINE_READOUT_VISIBLE")
	_check(int(state.role_ammunition.get(ACTOR, -1)) == 0 and submissions[0] == 1 and float(target.get_meta("health")) == 100.0, "EMPTY_MAGAZINE_NO_DISPATCH_OR_DAMAGE")
	craft.queue_free()
	combat.queue_free()
	target.queue_free()
	await process_frame
	for label in _failures:
		print("FAIL: ", label)
	print("BULWARK_EMPTY_MAGAZINE_FEEDBACK: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("BULWARK_EMPTY_MAGAZINE_FEEDBACK_TEST_OK")
	quit(0 if _failures.is_empty() else 1)

func _fire(craft: BulwarkHeavyGunship, sequence: int) -> Dictionary:
	return craft.submit_crew_intent(1, 88, AVATAR, Authority.ACTION_GUNNER_FIRE, {
		"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID, "target_id": &"range_target_00",
		"target_generation": int(craft.get_gunner_gameplay_state().target_generation), "trigger": true,
	}, sequence)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
