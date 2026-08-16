extends SceneTree

## Production integration for the component damage/repair/cleanup system.
##
## Everything below runs against the real `res://scenes/main.tscn`: the real
## `GameFlow`, the real `LiveCombatAuthority`/`CombatResolver`, the real defender
## and its own physics-driven fire, and the real hero craft. No parallel damage
## path, fixture ship, or stand-in resolver is constructed anywhere in this file.
##
## `modern_interpretation`: the roster, integrity curve and repair rate are a
## revisable modern reading; no source authenticates them.
##
## Determinism: fixed arena transforms, fixed damage amounts, and bounded
## physics-frame budgets over explicit conditions. Nothing here waits on the wall
## clock or on a fixed number of seconds.

const ARENA_ORIGIN := Vector3(600.0, 90.0, -900.0)
const OPPONENT_ARENA_OFFSET := Vector3(0.0, 0.0, 60.0)
## Bounded budgets. Each loop below exits on its condition; the budget only caps
## a failure so the suite terminates instead of hanging.
const LIVE_FIRE_PHYSICS_FRAMES := 480
const NO_REPAIR_PHYSICS_FRAMES := 90
## Two seconds at 60 Hz plus slack. Berth repair must finish well inside this.
const BERTH_REPAIR_PHYSICS_FRAMES := 180
## Bounded drain for the authored one-shot explosion voice at teardown.
const AUDIO_DRAIN_FRAME_BUDGET := 900

var _failures: Array[String] = []
var _game: GameFlow
var _hero: HeroShip
var _opponent: CharacterBody3D
var _component_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene loads for the component damage integration test")
		_finish()
		return
	_game = packed.instantiate() as GameFlow
	root.add_child(_game)
	await process_frame
	await physics_frame

	_hero = _game.get_node("TorrentInterceptor") as HeroShip
	_opponent = _game.get_node("RangeOpponent") as CharacterBody3D
	var picket := _game.get_node_or_null("StandoffPicket")
	if picket != null:
		# bugs.md SANDBOX-002: the picket is a second live combat source with its
		# own escort dispatch. It is held dormant here so the assertions observe
		# only the defender seam, exactly as the encounter authority gate test does.
		# This suite neither fixes nor depends on that open item.
		picket.set("escort_enabled", false)
		picket.call("deactivate")

	_test_production_roster()
	_test_hull_authority_is_untouched()
	_test_difficulty_neutrality()
	await _test_live_encounter()
	await _test_no_repair_in_flight()
	await _test_whole_main_reentry()
	_test_respawn_recovery_is_immediate()
	await _test_berth_repair()

	await _clean_up()
	_finish()


# -------------------------------------------------------- production roster --


func _test_production_roster() -> void:
	var craft_names := [
		"TorrentInterceptor",
		"ArrowReconShip",
		"JovianLightFreighter",
		"ZenithInterceptor",
	]
	var configured := 0
	var duplicates := 0
	for craft_name: String in craft_names:
		var craft := _game.get_node_or_null(craft_name) as HeroShip
		if craft == null:
			_fail("production craft %s is present for the component roster check" % craft_name)
			continue
		var models := craft.find_children("*", "ShipComponentDamage", true, false)
		if models.size() != 1:
			duplicates += 1
		var report: Dictionary = craft.get_component_damage_report()
		if (
			bool(report.get("configured", false))
			and int(report.get("component_count", 0))
				== ShipComponentDamage.COMPONENT_ORDER.size()
			and is_equal_approx(float(report.get("worst_integrity", 0.0)), 1.0)
			and report.get("interpretation") == ShipComponentDamage.INTERPRETATION
		):
			configured += 1
	_check(
		configured == craft_names.size(),
		"every production craft boots with one configured, fully nominal component roster"
	)
	_check(
		duplicates == 0,
		"no production craft carries a duplicate component model node"
	)

	# The roster is derived from each craft's own live collision envelope rather
	# than a second hand-authored hull table. The production fleet currently shares
	# one `_build_collision()`, so this asserts the derivation itself: every
	# section must sit inside the envelope the craft actually reports, with the
	# forward and aft sections at opposite ends of it.
	var torrent_report: Dictionary = _hero.get_component_damage_report()
	var envelope: AABB = _hero.get_landing_collision_report().get("local_bounds", AABB())
	var reported_bounds: AABB = torrent_report.get("local_bounds", AABB())
	_check(
		reported_bounds.position.is_equal_approx(envelope.position)
		and reported_bounds.size.is_equal_approx(envelope.size),
		"the roster records the exact collision envelope the craft measured for itself"
	)
	var inside := true
	for entry: Dictionary in torrent_report.get("components", []) as Array:
		if not envelope.has_point(entry.get("local_position", Vector3.INF) as Vector3):
			inside = false
	_check(inside, "every derived section sits inside the craft's own collision envelope")
	var nose := _local_component_position(torrent_report, ShipComponentDamage.COMPONENT_FORWARD_HULL)
	var tail := _local_component_position(torrent_report, ShipComponentDamage.COMPONENT_ENGINE_BAY)
	var port := _local_component_position(torrent_report, ShipComponentDamage.COMPONENT_PORT_WING)
	var starboard := _local_component_position(
		torrent_report, ShipComponentDamage.COMPONENT_STARBOARD_WING
	)
	_check(
		nose.z < envelope.get_center().z and tail.z > envelope.get_center().z
		and port.x < envelope.get_center().x and starboard.x > envelope.get_center().x,
		"the derived layout puts the forward hull, engine bay and wings on the airframe's real axes"
	)
	_check(
		float(torrent_report.get("maximum_hull", 0.0)) > 0.0
		and is_equal_approx(
			float(torrent_report.get("maximum_hull", 0.0)),
			float(_hero.get_telemetry().get("maximum_hull", -1.0))
		),
		"the roster normalizes against the craft's own authoritative maximum hull"
	)


# -------------------------------------------------------- authority boundary --


func _test_hull_authority_is_untouched() -> void:
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var hull_before := float(_hero.get_telemetry().get("hull", 0.0))
	var engine_position := _world_component_position(_hero, ShipComponentDamage.COMPONENT_ENGINE_BAY)
	_hero.call("apply_damage", 20.0, engine_position, Vector3.UP, -1, false)
	var hull_after := float(_hero.get_telemetry().get("hull", 0.0))
	_check(
		is_equal_approx(hull_after, hull_before - 20.0),
		"the component model observes a resolved hit without changing a single unit of hull"
	)
	var report: Dictionary = _hero.get_component_damage_report()
	_check(
		float(report.get("worst_integrity", 1.0)) < 1.0,
		"the resolved hit is attributed to the roster"
	)
	_check(
		_worst_component_id(report) == ShipComponentDamage.COMPONENT_ENGINE_BAY,
		"a hit placed on the engine bay costs the engine bay the most integrity"
	)
	var telemetry := _hero.get_telemetry()
	_check(
		is_equal_approx(
			float(telemetry.get("component_integrity", -1.0)),
			float(report.get("worst_integrity", 1.0))
		)
		and int(telemetry.get("components_failed", -1)) == int(report.get("failed_count", -1))
		and int(telemetry.get("components_impaired", -1)) == int(report.get("impaired_count", -1)),
		"telemetry publishes the same component reading the audit report does"
	)
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))


## The slice deliberately opens no handling channel. A failed section must not
## move speed, acceleration, or engine power, so encounter difficulty is exactly
## what it was before the component model existed.
func _test_difficulty_neutrality() -> void:
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var engine_position := _world_component_position(_hero, ShipComponentDamage.COMPONENT_ENGINE_BAY)
	var engine_power_before := float(_hero.get_telemetry().get("engine_power", -1.0))
	var guard := 0
	while (
		_hero.get_component_damage().get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY)
			!= ShipComponentDamage.ComponentState.FAILED
		and guard < 8
	):
		_hero.call("apply_damage", 11.0, engine_position, Vector3.UP, -1, false)
		guard += 1
	var telemetry := _hero.get_telemetry()
	_check(
		int(telemetry.get("components_failed", 0)) > 0,
		"a section can be driven to failure by ordinary defence-cannon damage"
	)
	_check(
		float(telemetry.get("hull", 0.0)) > float(telemetry.get("maximum_hull", 1.0)) * 0.3,
		"the section fails while the hull is still above its own critical stage"
	)
	_check(
		is_equal_approx(float(telemetry.get("engine_power", -1.0)), engine_power_before)
		and is_equal_approx(float(telemetry.get("engine_power", -1.0)), 1.0),
		"a failed section changes no handling value, so encounter difficulty is unmoved"
	)
	_check(
		telemetry.get("damage_status") == &"healthy",
		"the staged hull channel keeps its own thresholds independent of the roster"
	)
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))


# --------------------------------------------------------- live encounter --


func _test_live_encounter() -> void:
	_arm_encounter()
	_component_events.clear()
	_hero.component_damage_changed.connect(_record_component_event)
	var presentation := _hero.get_damage_presentation()
	var frames := 0
	while frames < LIVE_FIRE_PHYSICS_FRAMES:
		_hold_firing_solution()
		await physics_frame
		frames += 1
		if presentation.get_active_component_effect_count() > 0:
			break
	_hero.component_damage_changed.disconnect(_record_component_event)

	_check(
		float(_hero.get_telemetry().get("hull", 0.0))
			< float(_hero.get_telemetry().get("maximum_hull", 1.0)),
		"the defender's own physics resolves real damage onto the pilot through the shared resolver"
	)
	var report: Dictionary = _hero.get_component_damage_report()
	_check(
		float(report.get("worst_integrity", 1.0)) < 1.0,
		"live encounter damage is attributed to the hero's component roster"
	)
	_check(
		not _component_events.is_empty(),
		"the craft republishes a component grade change during a live encounter"
	)
	_check(
		presentation.get_active_component_effect_count() > 0,
		"a damaged section is expressed as a live localized rig on the production craft"
	)
	var rig_ids := presentation.get_component_effect_ids()
	var all_known := true
	for rig_id: StringName in rig_ids:
		if not ShipComponentDamage.COMPONENT_ORDER.has(rig_id):
			all_known = false
	_check(
		all_known and rig_ids.size() <= ShipComponentDamage.COMPONENT_ORDER.size(),
		"every live rig names a declared roster section and the channel stays bounded"
	)


## While the craft is flying, its damage must stay readable. Repair is only
## authorized at rest, so no section may quietly heal mid-engagement.
func _test_no_repair_in_flight() -> void:
	_arm_encounter()
	_hero.set("_landed", false)
	_hero.set("_docked_latch", false)
	var engine_position := _world_component_position(_hero, ShipComponentDamage.COMPONENT_ENGINE_BAY)
	_hero.call("apply_damage", 33.0, engine_position, Vector3.UP, -1, false)
	var integrity_before := _hero.get_component_damage().get_component_integrity(
		ShipComponentDamage.COMPONENT_ENGINE_BAY
	)
	var recovered := false
	for _frame in NO_REPAIR_PHYSICS_FRAMES:
		# Keep the defender out of the fight so only repair could move integrity.
		_opponent.call("deactivate")
		await physics_frame
		if _hero.get_component_damage().get_component_integrity(
			ShipComponentDamage.COMPONENT_ENGINE_BAY
		) > integrity_before + 0.0001:
			recovered = true
			break
	_check(
		not recovered,
		"a section damaged in flight does not heal itself while the craft is airborne"
	)


# -------------------------------------------------------- whole-Main re-entry --


func _test_whole_main_reentry() -> void:
	var presentation := _hero.get_damage_presentation()
	var report_before: Dictionary = _hero.get_component_damage_report()
	var rigs_before := presentation.get_component_effect_ids()
	_check(
		float(report_before.get("worst_integrity", 1.0)) < 1.0 and not rigs_before.is_empty(),
		"the craft carries real component damage and live rigs into the detach"
	)

	root.remove_child(_game)
	await process_frame
	root.add_child(_game)
	await process_frame
	await physics_frame

	var models := _hero.find_children("*", "ShipComponentDamage", true, false)
	_check(
		models.size() == 1,
		"a whole-Main re-entry never adds a second component model to the same craft"
	)
	var report_after: Dictionary = _hero.get_component_damage_report()
	_check(
		is_equal_approx(
			float(report_after.get("worst_integrity", -1.0)),
			float(report_before.get("worst_integrity", 1.0))
		)
		and int(report_after.get("failed_count", -1)) == int(report_before.get("failed_count", -2))
		and int(report_after.get("impaired_count", -1))
			== int(report_before.get("impaired_count", -2)),
		"the same physical craft keeps exactly the component state it left with"
	)
	_check(
		presentation.get_component_effect_ids() == rigs_before,
		"re-entry restores the same localized rig roster without duplicating or dropping one"
	)
	var emitting := true
	for rig_id: StringName in rigs_before:
		var rig := presentation.get_node_or_null("ComponentDamage_%s" % String(rig_id)) as Node3D
		if rig == null:
			emitting = false
			continue
		var sparks := rig.get_node_or_null("ComponentSparks") as CPUParticles3D
		if sparks == null or not sparks.emitting:
			emitting = false
	_check(emitting, "every re-entered rig resumes emitting rather than sitting silent")


# ----------------------------------------------------------- fast recovery --


## Crash recovery must not become something the player waits on. `reset_for_reuse()`
## restores the entire roster and clears every rig inside the same call -- no
## frames, no timers, no repair progress to run down first.
func _test_respawn_recovery_is_immediate() -> void:
	var presentation := _hero.get_damage_presentation()
	_hero.call("apply_damage", 10000.0, _hero.global_position, Vector3.UP, -1, false)
	_check(
		bool(_hero.get_telemetry().get("destroyed", false)),
		"the craft is genuinely destroyed before recovery is measured"
	)
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var report: Dictionary = _hero.get_component_damage_report()
	_check(
		is_equal_approx(float(report.get("worst_integrity", 0.0)), 1.0)
		and int(report.get("failed_count", -1)) == 0
		and int(report.get("impaired_count", -1)) == 0,
		"respawn restores the whole roster in the same call, with no frames of recovery latency"
	)
	_check(
		presentation.get_active_component_effect_count() == 0,
		"respawn clears every localized rig in the same call"
	)
	_check(
		is_equal_approx(
			float(_hero.get_telemetry().get("hull", 0.0)),
			float(_hero.get_telemetry().get("maximum_hull", 0.0))
		)
		and not bool(_hero.get_telemetry().get("destroyed", true)),
		"the existing hull respawn contract is unchanged by the component system"
	)


func _test_berth_repair() -> void:
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_game.set("_piloting", false)
	var wing_position := _world_component_position(_hero, ShipComponentDamage.COMPONENT_PORT_WING)
	for _hit in 4:
		_hero.call("apply_damage", 11.0, wing_position, Vector3.UP, -1, false)
	_check(
		_hero.get_component_damage().get_worst_integrity() < 1.0,
		"the berthed craft starts the repair measurement with real component damage"
	)
	var presentation := _hero.get_damage_presentation()
	var frames := 0
	while frames < BERTH_REPAIR_PHYSICS_FRAMES:
		await physics_frame
		frames += 1
		if _hero.get_component_damage().get_worst_integrity() >= 1.0:
			break
	_check(
		_hero.get_component_damage().get_worst_integrity() >= 1.0
		and frames < BERTH_REPAIR_PHYSICS_FRAMES,
		"a berthed craft repairs every section inside a bounded, short physics budget"
	)
	_check(
		presentation.get_active_component_effect_count() == 0,
		"berth repair retires the localized rigs as the sections return to nominal"
	)
	_check(
		bool(_hero.get_telemetry().get("landed", false))
		and not bool(_hero.get_telemetry().get("landing_active", true)),
		"nothing about the repair holds the craft in a landing or busy state"
	)


# ---------------------------------------------------------------- helpers --


func _arm_encounter() -> void:
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_game.active_ship = _hero
	_game.set("_piloting", true)
	_game.set("_recovering", false)
	_game.set("_transition_busy", false)
	_game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	_opponent.global_position = ARENA_ORIGIN + OPPONENT_ARENA_OFFSET
	_opponent.call("activate", Transform3D(Basis.IDENTITY, ARENA_ORIGIN + OPPONENT_ARENA_OFFSET))
	_opponent.call("set_target", _hero)
	_opponent.look_at(_hero.global_position, Vector3.UP)


func _hold_firing_solution() -> void:
	if not is_instance_valid(_opponent) or not is_instance_valid(_hero):
		return
	_opponent.global_position = _hero.global_position + OPPONENT_ARENA_OFFSET
	_opponent.look_at(_hero.global_position, Vector3.UP)
	_opponent.set("_cooldown_remaining", 0.0)


func _local_component_position(report: Dictionary, component_id: StringName) -> Vector3:
	for entry: Dictionary in report.get("components", []) as Array:
		if StringName(entry.get("id", &"")) == component_id:
			return entry.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.INF


func _world_component_position(craft: HeroShip, component_id: StringName) -> Vector3:
	var local := _local_component_position(craft.get_component_damage_report(), component_id)
	if not local.is_finite():
		return craft.global_position
	return craft.to_global(local)


func _worst_component_id(report: Dictionary) -> StringName:
	var worst_id: StringName = &""
	var worst := INF
	for entry: Dictionary in report.get("components", []) as Array:
		var integrity := float(entry.get("integrity", 1.0))
		if integrity < worst:
			worst = integrity
			worst_id = StringName(entry.get("id", &""))
	return worst_id


func _record_component_event(component_id: StringName, state: int, integrity: float) -> void:
	_component_events.append({"id": component_id, "state": state, "integrity": integrity})


## This suite destroys the hero to measure respawn recovery, which starts an
## authored one-shot explosion voice in Main's pooled combat audio. Tearing the
## scene down while that voice is still mixing strands its stream, so the drain
## below waits on the pool's own published state with a bounded frame budget --
## a condition wait, never a fixed sleep.
func _drain_combat_audio() -> void:
	var audio := _game.get_node_or_null("CombatAudioPresentation") if is_instance_valid(_game) else null
	if audio == null or not audio.has_method("get_state_snapshot"):
		return
	for _frame in AUDIO_DRAIN_FRAME_BUDGET:
		var snapshot: Dictionary = audio.call("get_state_snapshot")
		if (snapshot.get("active_voice_names", PackedStringArray()) as PackedStringArray).is_empty():
			return
		await process_frame


func _clean_up() -> void:
	await _drain_combat_audio()
	if is_instance_valid(_game):
		_game.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_COMPONENT_DAMAGE_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("SHIP_COMPONENT_DAMAGE_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
