extends SceneTree

## Focused Phase 7 runtime slice: an authority-admitted gunner receipt reaches
## the Halyard's existing projectile request signal. Combat resolution and
## damage remain outside this test and outside the ship role consumer.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

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
	_check(
		bool(authority.register_halyard_roster().get("accepted", false)),
		"the Halyard roster seals before a gunner can submit an intent"
	)
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"the real Halyard accepts the session-owned role authority"
	)
	_check(
		bool(authority.claim(
			1, 88, &"gunner_avatar", &"co_pilot_station", Authority.ROLE_GUNNER, 1
		).get("accepted", false)),
		"the gunner claim is tied to the physical co-pilot station"
	)

	var emitted := [0]
	var last_origin := [Vector3.INF]
	var last_direction := [Vector3.ZERO]
	craft.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		emitted[0] += 1
		last_origin[0] = origin
		last_direction[0] = direction
	)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	var fired := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
		},
		2
	)
	var effect := fired.get("effect", {}) as Dictionary
	_check(
		bool(fired.get("accepted", false))
			and bool(fired.get("consumed", false))
			and fired.get("status", &"") == &"intent_consumed"
			and bool(effect.get("accepted", false))
			and effect.get("status", &"") == &"weapon_request_emitted",
		"the accepted gunner receipt is consumed as a weapon request"
	)
	_check(
		emitted[0] == 1 and (last_origin[0] as Vector3).is_finite() \
			and (last_direction[0] as Vector3).is_finite()
			and (last_direction[0] as Vector3).length() > 0.99,
		"the existing projectile request seam emits one normalized shot"
	)
	_check(
		effect.get("source_id", 0) == HalyardCrewTransport.COMBAT_SOURCE_ID
			and effect.get("faction_id", &"") == HalyardCrewTransport.HALYARD_CREW_FACTION_ID
			and effect.get("weapon_id", &"") == HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
		"the request carries the Halyard's bounded source, faction, and weapon identity"
	)

	var cooldown := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
		},
		3
	)
	_check(
		bool(cooldown.get("accepted", false))
			and not bool(cooldown.get("consumed", false))
			and (cooldown.get("effect", {}) as Dictionary).get("status", &"") == &"weapon_cooldown"
			and emitted[0] == 1,
		"HeroShip cadence blocks a second gunner request without emitting another shot"
	)

	var replay := craft.submit_crew_intent(
		1,
		88,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"range_target_00",
			"trigger": true,
		},
		2
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"a replayed gunner receipt cannot emit a duplicate request"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_CREW_GUNNER_GAMEPLAY_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
