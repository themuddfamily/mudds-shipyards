extends SceneTree

## The range defender's authored weapon heat, end to end.
##
## Everything asserted here is owned by the existing authority path: the one
## `CombatResolver` charges heat on accepted triggers, refuses a request made
## during the forced vent with `weapon_heat_locked`, and vents on its own tick.
## The defender only reads that state to drive its hot-vent collars, its single
## dry-fire click, and its break-off.

const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const COMBAT_AUDIO_PRESENTATION := preload(
	"res://scenes/audio/combat_audio_presentation.tscn"
)
const CombatAuthorityScript := preload("res://scripts/combat/live_combat_authority.gd")
const WEAPON_DEFINITION := preload("res://assets/weapons/range_defence_pulse.tres")

const SOURCE_ID := 2101
const FACTION: StringName = &"range_defence"
const WEAPON_ID: StringName = &"defence_pulse_cannon"
const PLAIN_SOURCE_ID := 2199
const PLAIN_WEAPON_ID: StringName = &"plain_pulse_cannon"

## The defender's authored cadence: 0.62 s telegraph plus 1.55 s cooldown.
const SHOT_PERIOD_SECONDS := 2.17
const EXPECTED_SHOTS_BEFORE_LOCKOUT := 7
## With no cooling at all, 22 heat per shot crosses the 100 ceiling on the fifth
## trigger. The defender gets seven because its authored cadence sheds
## 3.6 * 2.17 = 7.812 heat between shots.
const UNCOOLED_SHOTS_TO_CEILING := 5

var _failures: Array[String] = []
var _assertions := 0
var _test_root: Node3D
var _dry_fire_cues: Array[StringName] = []
## GDScript lambdas capture by value, so the simulated clock the fire listener
## stamps its shots with has to live on the fixture.
var _simulated_elapsed := 0.0
var _simulated_shot_times: Array[float] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "RangeOpponentWeaponHeatTestRoot"
	root.add_child(_test_root)

	var authority := CombatAuthorityScript.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	_test_root.add_child(authority)
	var audio := COMBAT_AUDIO_PRESENTATION.instantiate() as CombatAudioPresentation
	audio.name = "CombatAudioPresentation"
	_test_root.add_child(audio)
	audio.cue_started.connect(_on_combat_cue_started)

	var target := Node3D.new()
	target.name = "HeatTestTarget"
	target.position = Vector3(0.0, 0.0, -48.0)
	_test_root.add_child(target)

	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	# The production coordinator binds this exact stable defender identity, and it
	# is the identity that owns the hot-vent collars.
	opponent.name = "RangeOpponent"
	opponent.process_mode = Node.PROCESS_MODE_DISABLED
	_test_root.add_child(opponent)
	await process_frame
	await physics_frame

	var resolver := authority.get_resolver()
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)

	_test_authored_envelope(authority, opponent)
	_test_heat_accumulates_and_locks(authority, resolver, opponent)
	_test_cooling_reopens_fire(authority, resolver, opponent)
	_test_presentation_state(authority, resolver, opponent)
	_test_lockout_withholds_fire_and_repositions(authority, resolver, opponent, target)
	_test_regeneration_resets_heat(authority, resolver, opponent)
	_test_non_heat_weapon_is_untouched(authority, resolver)
	_test_authored_cadence_burst_length(authority, resolver, opponent, target)

	opponent.deactivate()
	_test_root.queue_free()
	await process_frame
	await process_frame
	_finish()


## 1. The authored resource is the only place these numbers come from, and the
##    conversion carries them into the registry as explicit fields.
func _test_authored_envelope(
		authority: LiveCombatAuthority, opponent: RangeOpponent
	) -> void:
	_check(
		WEAPON_DEFINITION.is_definition_valid()
			and WEAPON_DEFINITION.heat_enabled
			and WEAPON_DEFINITION.has_heat_envelope()
			and is_equal_approx(WEAPON_DEFINITION.heat_per_shot, 22.0)
			and is_equal_approx(WEAPON_DEFINITION.heat_capacity, 100.0)
			and is_equal_approx(WEAPON_DEFINITION.heat_cooldown_per_second, 3.6)
			and is_equal_approx(WEAPON_DEFINITION.heat_lockout_seconds, 2.5),
		"the defender's authored weapon Resource carries a complete, valid heat envelope"
	)
	_check(
		authority.register_source(
			opponent, SOURCE_ID, FACTION, GameFlow.OPPONENT_WEAPON_PROFILES
		),
		"the production defender registers its authored heat profile on the live authority"
	)
	var profile := authority.get_weapon_profile(opponent, WEAPON_ID)
	_check(
		is_equal_approx(float(profile.get("heat_per_shot", 0.0)), 22.0)
			and is_equal_approx(float(profile.get("heat_capacity", 0.0)), 100.0)
			and is_equal_approx(float(profile.get("heat_cooldown_per_second", 0.0)), 3.6)
			and is_equal_approx(float(profile.get("heat_lockout_seconds", 0.0)), 2.5)
			and is_equal_approx(float(profile.get("range", 0.0)), 420.0)
			and is_equal_approx(float(profile.get("damage", 0.0)), 11.0),
		"the registered profile is the authored envelope, converted rather than reinvented"
	)
	var snapshot := opponent.get_weapon_heat_snapshot()
	_check(
		bool(snapshot.get("enabled", false))
			and is_equal_approx(float(snapshot.get("heat", -1.0)), 0.0)
			and not bool(snapshot.get("locked", true))
			and int(snapshot.get("shots_until_lockout", 0)) == UNCOOLED_SHOTS_TO_CEILING,
		"a freshly registered defender starts cold, with its whole burst still available"
	)


## 2. Heat accumulates per accepted shot, and the ceiling locks the gun out.
func _test_heat_accumulates_and_locks(
		authority: LiveCombatAuthority,
		resolver: CombatResolver,
		opponent: RangeOpponent
	) -> void:
	var accepted_shots := 0
	var heat_after_each: Array[float] = []
	var monotonic := true
	for _index in 12:
		var previous_heat := resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID)
		var result := _submit(authority, opponent)
		if StringName(result.get("status", &"")) == CombatResolver.HEAT_LOCKOUT_STATUS:
			_check(
				accepted_shots == EXPECTED_SHOTS_BEFORE_LOCKOUT,
				"the defender lands exactly %d shots before its gun locks out"
					% EXPECTED_SHOTS_BEFORE_LOCKOUT
			)
			_check(
				not bool(result.get("accepted", true))
					and not bool(result.get("resolved", true))
					and not bool(result.get("hit", true))
					and not bool(result.get("damaged", true))
					and is_equal_approx(float(result.get("applied_damage", -1.0)), 0.0),
				"a shot requested during the vent is refused with its own reason and no damage"
			)
			_check(
				int(result.get("last_sequence", -1)) >= 0
					and resolver.get_last_sequence(opponent, SOURCE_ID)
						== int(result.get("last_sequence", -1)),
				"a refused trigger still consumes its replay sequence, so it cannot be replayed later"
			)
			var held_heat := resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID)
			_check(
				is_equal_approx(held_heat, 1.0),
				"the refused trigger pays no heat of its own; the gun stays exactly at its ceiling"
			)
			return
		accepted_shots += 1
		var heat := resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID)
		heat_after_each.append(heat)
		monotonic = monotonic and heat > previous_heat
		_check(
			monotonic,
			"accepted shot %d leaves the gun hotter than it was" % accepted_shots
		)
		if resolver.get_weapon_heat_lockout_remaining(opponent, SOURCE_ID, WEAPON_ID) > 0.0:
			# The ceiling has just been crossed; the next trigger meets the vent.
			continue
		# The authority's own tick, at the defender's authored cadence.
		resolver.advance_weapon_heat(SHOT_PERIOD_SECONDS)
	_check(false, "sustained fire reaches the authored heat ceiling")


## 3. The forced vent is the authored window, and fire reopens on a cold gun.
func _test_cooling_reopens_fire(
		authority: LiveCombatAuthority,
		resolver: CombatResolver,
		opponent: RangeOpponent
	) -> void:
	var remaining := authority.get_weapon_heat_lockout_remaining(opponent, WEAPON_ID)
	_check(
		is_equal_approx(remaining, 2.5) and authority.is_weapon_heat_locked(opponent, WEAPON_ID),
		"crossing the ceiling opens the authored 2.5 s vent"
	)
	resolver.advance_weapon_heat(1.25)
	var midpoint_ratio := resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID)
	_check(
		authority.is_weapon_heat_locked(opponent, WEAPON_ID)
			and midpoint_ratio < 1.0
			and midpoint_ratio > 0.0
			and StringName(_submit(authority, opponent).get("status", &""))
				== CombatResolver.HEAT_LOCKOUT_STATUS,
		"halfway through the vent the gun is visibly cooler and still refuses fire"
	)
	resolver.advance_weapon_heat(1.25)
	_check(
		not authority.is_weapon_heat_locked(opponent, WEAPON_ID)
			and is_equal_approx(
				resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID), 0.0
			),
		"the vent ends on a cold gun, exactly when the authored lockout expires"
	)
	var reopened := _submit(authority, opponent)
	_check(
		bool(reopened.get("accepted", false)) and bool(reopened.get("resolved", false)),
		"cooling reopens fire on the same registration, with no re-registration needed"
	)


## 4. Presentation state the hot-vent glow and the accessibility clamp read.
func _test_presentation_state(
		authority: LiveCombatAuthority,
		resolver: CombatResolver,
		opponent: RangeOpponent
	) -> void:
	opponent.call("_update_presentation", 0.0)
	var warm := opponent.get_weapon_heat_presentation_state()
	_check(
		int(warm.get("vent_instance_count", 0)) == 2
			and float(warm.get("heat_ratio", 0.0)) > 0.0
			and bool(warm.get("vent_visible", false))
			and float(warm.get("vent_emission_energy", 0.0)) > 0.0
			and not bool(warm.get("locked", true))
			and not bool(warm.get("heat_authority", true))
			and not bool(warm.get("damage_authority", true)),
		"a hot gun lights the two vent collars without claiming any heat or damage authority"
	)
	var reduced := opponent.set_reduced_flash_enabled(true)
	opponent.call("_update_presentation", 0.0)
	var reduced_state := opponent.get_weapon_heat_presentation_state()
	_check(
		bool(reduced.get("accepted", false))
			and bool(reduced_state.get("reduced_flash", false))
			and float(reduced_state.get("vent_peak_emission_energy", 0.0))
				< float(warm.get("vent_peak_emission_energy", 0.0))
			and float(reduced_state.get("vent_emission_energy", 0.0))
				<= float(reduced_state.get("vent_peak_emission_energy", 0.0)) + 0.001,
		"reduced flash lowers the vent's peak emission and the current frame respects it"
	)
	opponent.set_reduced_flash_enabled(false)
	# Drive the gun back into lockout and confirm the glow saturates there.
	for _index in EXPECTED_SHOTS_BEFORE_LOCKOUT + 1:
		_submit(authority, opponent)
	opponent.call("_update_presentation", 0.0)
	var hot := opponent.get_weapon_heat_presentation_state()
	_check(
		bool(hot.get("locked", false))
			and is_equal_approx(float(hot.get("heat_ratio", 0.0)), 1.0)
			and float(hot.get("vent_emission_energy", 0.0))
				> float(warm.get("vent_emission_energy", 0.0)),
		"the vent collars are at their brightest for the length of the lockout"
	)
	resolver.advance_weapon_heat(2.5)
	opponent.call("_update_presentation", 0.0)
	var cold := opponent.get_weapon_heat_presentation_state()
	_check(
		not bool(cold.get("locked", true))
			and is_equal_approx(float(cold.get("heat_ratio", 1.0)), 0.0)
			and not bool(cold.get("vent_visible", true))
			and is_equal_approx(float(cold.get("vent_emission_energy", 1.0)), 0.0),
		"the glow fades to nothing as the gun vents, leaving no lit collar behind"
	)


## 5. The tactical consequence: one dry click, no shot, and a break-off.
func _test_lockout_withholds_fire_and_repositions(
		authority: LiveCombatAuthority,
		resolver: CombatResolver,
		opponent: RangeOpponent,
		target: Node3D
	) -> void:
	for _index in EXPECTED_SHOTS_BEFORE_LOCKOUT:
		_submit(authority, opponent)
	_check(
		authority.is_weapon_heat_locked(opponent, WEAPON_ID),
		"the defender's gun is locked out before it next tries to fire"
	)
	var shots: Array[Dictionary] = []
	var shot_listener := func(origin: Vector3, direction: Vector3) -> void:
		shots.append({"origin": origin, "direction": direction})
	opponent.projectile_fired.connect(shot_listener)
	_dry_fire_cues.clear()
	opponent.set("_cooldown_remaining", 0.0)
	opponent.set("_telegraph_remaining", 0.0)
	opponent.set("_pressure_turn_state", &"idle")
	var direction := (target.global_position - opponent.global_position).normalized()
	var distance := opponent.global_position.distance_to(target.global_position)
	opponent.call("_update_weapon", target.global_position, direction, distance, 0.0)
	var first_attempt_turn := opponent.get_pressure_turn_snapshot()
	var lockout_remaining := authority.get_weapon_heat_lockout_remaining(opponent, WEAPON_ID)
	_check(
		shots.is_empty()
			and is_equal_approx(float(opponent.get("_telegraph_remaining")), 0.0)
			and float(opponent.get("_cooldown_remaining")) >= lockout_remaining
			and lockout_remaining > 0.0,
		"a locked gun withholds the charge entirely and waits out exactly the authored vent"
	)
	_check(
		_dry_fire_cues.size() == 1
			and _dry_fire_cues[0] == CombatAudioPresentation.CUE_DRY_FIRE
			and int(
				opponent.get_weapon_heat_presentation_state().get("dry_fire_count", 0)
			) == 1,
		"the refused trigger is voiced once with the existing dry-fire click"
	)
	_check(
		StringName(first_attempt_turn.get("state_id", &"")) == &"active"
			and bool(first_attempt_turn.get("uses_existing_movement_authority", false)),
		"the defender breaks off through its existing pressure-turn movement authority"
	)
	# A second attempt inside the same lockout must not spam the cue.
	opponent.set("_cooldown_remaining", 0.0)
	opponent.call("_update_weapon", target.global_position, direction, distance, 0.0)
	_check(
		_dry_fire_cues.size() == 1 and shots.is_empty(),
		"one lockout produces exactly one dry click, not one per frame"
	)
	opponent.projectile_fired.disconnect(shot_listener)
	resolver.advance_weapon_heat(2.5)
	opponent.call("_update_presentation", 0.0)
	_check(
		int(opponent.get_weapon_heat_presentation_state().get("dry_fire_announced", 1)) == 0,
		"the dry-fire latch reopens with the gun, so the next lockout is announced again"
	)


## 6. Regeneration and re-registration both start a cold epoch.
func _test_regeneration_resets_heat(
		authority: LiveCombatAuthority,
		resolver: CombatResolver,
		opponent: RangeOpponent
	) -> void:
	for _index in 3:
		_submit(authority, opponent)
	_check(
		resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID) > 0.0,
		"the defender is carrying heat going into its regeneration"
	)
	opponent.activate(Transform3D.IDENTITY)
	_check(
		is_equal_approx(resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID), 0.0)
			and not authority.is_weapon_heat_locked(opponent, WEAPON_ID),
		"regenerating the hull vents the gun; a new epoch never inherits the old one's heat"
	)
	for _index in EXPECTED_SHOTS_BEFORE_LOCKOUT + 1:
		_submit(authority, opponent)
	_check(
		authority.is_weapon_heat_locked(opponent, WEAPON_ID),
		"the regenerated defender earns its own lockout on its own burst"
	)
	_check(
		authority.register_source(
			opponent, SOURCE_ID, FACTION, GameFlow.OPPONENT_WEAPON_PROFILES
		)
			and is_equal_approx(
				resolver.get_weapon_heat_ratio(opponent, SOURCE_ID, WEAPON_ID), 0.0
			)
			and not authority.is_weapon_heat_locked(opponent, WEAPON_ID),
		"re-registration rebuilds the ledger cold, exactly as the quarantine rules require"
	)


## 7. A weapon without an authored heat envelope is byte-for-byte unchanged.
func _test_non_heat_weapon_is_untouched(
		authority: LiveCombatAuthority,
		resolver: CombatResolver
	) -> void:
	var plain_source := CharacterBody3D.new()
	plain_source.name = "PlainHitscanSource"
	plain_source.position = Vector3(140.0, 0.0, 0.0)
	_test_root.add_child(plain_source)
	var plain_profiles := {
		PLAIN_WEAPON_ID: {
			"range": 300.0,
			"damage": 9.0,
			"origin_tolerance": 12.0,
		},
	}
	_check(
		authority.register_source(plain_source, PLAIN_SOURCE_ID, FACTION, plain_profiles),
		"a weapon with no authored heat registers exactly as it always did"
	)
	var registered := resolver.get_registered_weapon_profile(
		plain_source, PLAIN_SOURCE_ID, PLAIN_WEAPON_ID
	)
	_check(
		registered.size() == 3
			and not CombatResolver.profile_is_heat(registered)
			and not registered.has("heat_per_shot")
			and not registered.has("heat_capacity")
			and not registered.has("heat_cooldown_per_second")
			and not registered.has("heat_lockout_seconds"),
		"no heat key reaches a profile that never authored one"
	)
	var accepted := 0
	for _index in EXPECTED_SHOTS_BEFORE_LOCKOUT + 6:
		var result := authority.submit_hitscan(
			plain_source,
			PLAIN_WEAPON_ID,
			plain_source.global_position + Vector3(0.0, 0.0, -1.0),
			Vector3(0.0, 0.0, -1.0)
		)
		if bool(result.get("accepted", false)):
			accepted += 1
	_check(
		accepted == EXPECTED_SHOTS_BEFORE_LOCKOUT + 6
			and resolver.get_weapon_heat_snapshot(
				plain_source, PLAIN_SOURCE_ID, PLAIN_WEAPON_ID
			).is_empty()
			and not authority.is_weapon_heat_locked(plain_source, PLAIN_WEAPON_ID),
		"a non-heat weapon never locks out, never accumulates heat, and reports no heat state"
	)
	resolver.advance_weapon_heat(4.0)
	_check(
		bool(
			authority.submit_hitscan(
				plain_source,
				PLAIN_WEAPON_ID,
				plain_source.global_position + Vector3(0.0, 0.0, -1.0),
				Vector3(0.0, 0.0, -1.0)
			).get("accepted", false)
		),
		"ticking the heat ledger leaves a non-heat weapon completely untouched"
	)


## 8. The tuning claim itself, driven through the defender's own fire loop at
##    its authored cadence rather than through hand-placed triggers.
func _test_authored_cadence_burst_length(
		authority: LiveCombatAuthority,
		resolver: CombatResolver,
		opponent: RangeOpponent,
		target: Node3D
	) -> void:
	authority.reset_weapon_heat(opponent)
	opponent.set("_cooldown_remaining", 0.0)
	opponent.set("_telegraph_remaining", 0.0)
	opponent.set("_pressure_turn_state", &"idle")
	_dry_fire_cues.clear()
	_simulated_elapsed = 0.0
	_simulated_shot_times.clear()
	var fire_listener := func(_origin: Vector3, direction: Vector3) -> void:
		_simulated_shot_times.append(_simulated_elapsed)
		authority.submit_hitscan(
			opponent, WEAPON_ID, opponent.global_position + direction * 6.0, direction
		)
	opponent.projectile_fired.connect(fire_listener)
	var direction := (target.global_position - opponent.global_position).normalized()
	var distance := opponent.global_position.distance_to(target.global_position)
	var step := 1.0 / 60.0
	var overheating_shot_time := -1.0
	var lock_cleared_time := -1.0
	var dry_fire_time := -1.0
	var dry_fire_lock_remaining := 0.0
	# Twenty-five seconds of continuous, in-range, unobstructed engagement: long
	# enough to land the whole burst, sit out the vent, and fire again.
	var was_locked := false
	for _frame in 1500:
		opponent.set(
			"_cooldown_remaining", maxf(0.0, float(opponent.get("_cooldown_remaining")) - step)
		)
		var clicks_before := _dry_fire_cues.size()
		var frame_start := _simulated_elapsed
		opponent.call("_update_weapon", target.global_position, direction, distance, step)
		if _dry_fire_cues.size() > clicks_before and dry_fire_time < 0.0:
			dry_fire_time = frame_start
			dry_fire_lock_remaining = authority.get_weapon_heat_lockout_remaining(
				opponent, WEAPON_ID
			)
		resolver.advance_weapon_heat(step)
		_simulated_elapsed += step
		var locked_now := authority.is_weapon_heat_locked(opponent, WEAPON_ID)
		if locked_now and not was_locked:
			overheating_shot_time = frame_start
		elif was_locked and not locked_now:
			lock_cleared_time = _simulated_elapsed
		was_locked = locked_now
		if lock_cleared_time > 0.0 and _simulated_shot_times.size() > 7:
			break
	opponent.projectile_fired.disconnect(fire_listener)

	var burst_length := 0
	for shot_time: float in _simulated_shot_times:
		if overheating_shot_time >= 0.0 and shot_time > overheating_shot_time:
			break
		burst_length += 1
	var cadence := 0.0
	if burst_length >= 2:
		cadence = (
			(_simulated_shot_times[burst_length - 1] - _simulated_shot_times[0])
			/ float(burst_length - 1)
		)
	_check(
		burst_length >= 6 and burst_length <= 8,
		"the defender's own fire loop lands %d shots before its gun stops it (want 6-8)"
			% burst_length
	)
	_check(
		burst_length == EXPECTED_SHOTS_BEFORE_LOCKOUT
			and absf(cadence - SHOT_PERIOD_SECONDS) < 0.05,
		"it fires at its authored %.2f s cadence (measured %.2f s across the burst)"
			% [SHOT_PERIOD_SECONDS, cadence]
	)
	_check(
		overheating_shot_time > 0.0
			and lock_cleared_time > overheating_shot_time
			and absf((lock_cleared_time - overheating_shot_time) - 2.5) < 0.1,
		"the gun is locked out for the whole authored 2.5 s from the shot that overheats it (%.2f s)"
			% (lock_cleared_time - overheating_shot_time)
	)
	_check(
		_dry_fire_cues.size() == 1
			and dry_fire_time > overheating_shot_time
			and dry_fire_lock_remaining > 0.0,
		"the defender dry-fires exactly once, mid-vent, when it next tries to shoot"
	)
	var gap := 0.0
	if _simulated_shot_times.size() > burst_length:
		gap = _simulated_shot_times[burst_length] - _simulated_shot_times[burst_length - 1]
	_check(
		_simulated_shot_times.size() > burst_length
			and gap > SHOT_PERIOD_SECONDS * 1.35
			and absf(gap - (2.5 + opponent.telegraph_time)) < 0.1,
		"the shot the player is waiting out arrives %.2f s later instead of the usual %.2f s"
			% [gap, SHOT_PERIOD_SECONDS]
	)


func _submit(authority: LiveCombatAuthority, opponent: RangeOpponent) -> Dictionary:
	return authority.submit_hitscan(
		opponent,
		WEAPON_ID,
		opponent.global_position + Vector3(0.0, 0.0, -6.0),
		Vector3(0.0, 0.0, -1.0)
	)


func _on_combat_cue_started(
		cue_id: StringName,
		_voice_name: StringName,
		_world_position: Vector3,
		_source_instance_id: int
	) -> void:
	if cue_id == CombatAudioPresentation.CUE_DRY_FIRE:
		_dry_fire_cues.append(cue_id)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("RANGE_OPPONENT_WEAPON_HEAT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("RANGE_OPPONENT_WEAPON_HEAT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
