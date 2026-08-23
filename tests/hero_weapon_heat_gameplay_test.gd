extends SceneTree

## Focused production coverage for Torrent's pulse-cannon heat loop. The test
## drives the existing HeroShip fire gate and observes its existing projectile
## signal, physical cockpit readout, telemetry, and reuse lifecycle.

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ship := TORRENT_SCENE.instantiate() as HeroShip
	_check(ship != null, "production Torrent instantiates for weapon heat gameplay")
	if ship == null:
		_finish()
		return
	root.add_child(ship)
	await process_frame
	await physics_frame
	ship.set("_engine_state", HeroShip.ENGINE_ONLINE)

	var shots := [0]
	ship.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		shots[0] += 1
	)
	var initial := ship.get_telemetry()
	_check(
		bool(initial.get("weapon_ready", false))
			and initial.get("weapon_status", &"") == &"ready"
			and initial.get("weapon_unavailable_reason", &"sentinel") == &""
			and is_zero_approx(float(initial.get("weapon_heat", -1.0))),
		"online Torrent starts ready with explicit zero-heat telemetry"
	)

	ship.call("_fire_weapon")
	var after_first := ship.get_telemetry()
	_check(
		shots[0] == 1
			and after_first.get("weapon_status", &"") == &"cooldown"
			and after_first.get("weapon_unavailable_reason", &"") == &"weapon_cooldown"
			and float(after_first.get("weapon_heat", 0.0)) > 0.0,
		"an accepted pulse adds heat while preserving the existing cadence gate"
	)

	var frames_to_overheat := 0
	while not bool(ship.get_telemetry().get("weapon_overheated", false)) \
			and frames_to_overheat < 240:
		ship.call("_fire_weapon")
		await physics_frame
		frames_to_overheat += 1
	var overheated := ship.get_telemetry()
	_check(
		bool(overheated.get("weapon_overheated", false))
			and overheated.get("weapon_status", &"") == &"overheated"
			and overheated.get("weapon_unavailable_reason", &"") == &"weapon_overheated"
			and float(overheated.get("weapon_recovery_remaining", 0.0)) > 0.0
			and float(overheated.get("weapon_recovery_remaining", 0.0))
				<= HeroShip.WEAPON_OVERHEAT_DURATION,
		"a sustained production-rate burst enters a bounded explicit overheat"
	)
	_check(
		shots[0] >= 5 and shots[0] <= 10,
		"arcade heat allows a useful burst before its short lockout"
	)

	var shots_before_rejection := int(shots[0])
	ship.call("_fire_weapon")
	_check(
		shots[0] == shots_before_rejection,
		"overheat rejects fire before the existing projectile authority signal"
	)
	await physics_frame
	var readout := ship.find_child("FlightDataReadout", true, false) as Label3D
	_check(
		readout != null
			and readout.text.contains("WPN OVERHEAT")
			and readout.text.contains("s"),
		"the physical Torrent cockpit shows overheat and remaining recovery time"
	)

	var paused_recovery := float(ship.get_telemetry().get("weapon_recovery_remaining", 0.0))
	root.remove_child(ship)
	for _frame in 5:
		await physics_frame
	_check(
		is_equal_approx(
			float(ship.get_telemetry().get("weapon_recovery_remaining", -1.0)),
			paused_recovery
		),
		"detachment cannot consume the physics-time recovery window"
	)
	root.add_child(ship)
	await process_frame
	var recovery_frames := 0
	while not bool(ship.get_telemetry().get("weapon_ready", false)) and recovery_frames < 120:
		await physics_frame
		recovery_frames += 1
	var recovered := ship.get_telemetry()
	_check(
		bool(recovered.get("weapon_ready", false))
			and recovered.get("weapon_status", &"") == &"ready"
			and not bool(recovered.get("weapon_overheated", true))
			and float(recovered.get("weapon_heat", 1.0)) <= HeroShip.WEAPON_RECOVERY_HEAT,
		"re-entry resumes the same short recovery and returns fire readiness"
	)
	_check(
		readout.text.contains("WPN READY") and readout.text.contains("HEAT"),
		"the cockpit readout visibly returns from overheat to ready"
	)

	# Re-enter overheat once more so reuse proves it clears transient weapon state
	# instead of leaking a denial into the regenerated craft.
	var second_burst_frames := 0
	while not bool(ship.get_telemetry().get("weapon_overheated", false)) \
			and second_burst_frames < 240:
		ship.call("_fire_weapon")
		await physics_frame
		second_burst_frames += 1
	_check(bool(ship.get_telemetry().get("weapon_overheated", false)), "second burst reaches overheat before reuse")
	var reset := ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, -8.0)))
	var reset_telemetry := ship.get_telemetry()
	_check(
		bool(reset.get("accepted", false))
			and not bool(reset_telemetry.get("weapon_overheated", true))
			and is_zero_approx(float(reset_telemetry.get("weapon_heat", -1.0)))
			and is_zero_approx(float(reset_telemetry.get("weapon_recovery_remaining", -1.0)))
			and reset_telemetry.get("weapon_unavailable_reason", &"") == &"engine_not_online",
		"reuse clears heat and recovery while honestly reporting the offline engine gate"
	)
	ship.set("_engine_state", HeroShip.ENGINE_ONLINE)
	_check(
		bool(ship.get_telemetry().get("weapon_ready", false)),
		"the regenerated craft can regain weapon readiness without hidden heat state"
	)

	ship.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("HERO_WEAPON_HEAT_GAMEPLAY: %d checks, %d failures" % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)
