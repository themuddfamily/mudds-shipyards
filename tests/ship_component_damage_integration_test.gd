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
const ShipCommandType := preload("res://scripts/control/ship_command.gd")
const OPPONENT_ARENA_OFFSET := Vector3(0.0, 0.0, 60.0)
## Bounded budgets. Each loop below exits on its condition; the budget only caps
## a failure so the suite terminates instead of hanging.
const LIVE_FIRE_PHYSICS_FRAMES := 480
const NO_REPAIR_PHYSICS_FRAMES := 90
## Two seconds at 60 Hz plus slack. Berth repair must finish well inside this.
const BERTH_REPAIR_PHYSICS_FRAMES := 180
## Bounded drain for the authored one-shot explosion voice at teardown.
const AUDIO_DRAIN_FRAME_BUDGET := 900
const FLEET_CRAFT_NAMES := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]
const EXPECTED_MAXIMUM_HULL := {
	"TorrentInterceptor": 100.0,
	"ArrowReconShip": 82.0,
	"JovianLightFreighter": 260.0,
	"ZenithInterceptor": 68.0,
	"HalyardCrewTransport": 190.0,
}

var _failures: Array[String] = []
var _game: GameFlow
var _hero: HeroShip
var _opponent: CharacterBody3D
var _component_events: Array[Dictionary] = []
var _initial_fleet_geometry: Dictionary = {}
var _initial_component_model_ids: Dictionary = {}


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
	_test_fleet_reset_geometry_stability()
	_test_hull_authority_is_untouched()
	_test_operational_control_modifiers()
	await _test_live_encounter()
	await _test_no_repair_in_flight()
	await _test_whole_main_reentry()
	_test_respawn_recovery_is_immediate()
	await _test_berth_repair()
	await _test_direct_component_currentness()

	await _clean_up()
	_finish()


# -------------------------------------------------------- production roster --


func _test_production_roster() -> void:
	var configured := 0
	var duplicates := 0
	var exact_live_bounds := 0
	var exact_layouts := 0
	var exact_maxima := 0
	var exact_capture_revisions := 0
	var single_connections := 0
	var active_generic_ledgers := 0
	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := _game.get_node_or_null(craft_name) as HeroShip
		if craft == null:
			_fail("production craft %s is present for the component roster check" % craft_name)
			continue
		var models := craft.find_children("*", "ShipComponentDamage", true, false)
		if models.size() != 1:
			duplicates += 1
		var report: Dictionary = craft.get_component_damage_report()
		var collision_report := craft.get_landing_collision_report()
		var live_bounds: AABB = collision_report.get("local_bounds", AABB())
		if (
			bool(report.get("configured", false))
			and int(report.get("component_count", 0))
				== ShipComponentDamage.COMPONENT_ORDER.size()
			and is_equal_approx(float(report.get("worst_integrity", 0.0)), 1.0)
			and report.get("interpretation") == ShipComponentDamage.INTERPRETATION
		):
			configured += 1
		if bool(collision_report.get("valid", false)) \
			and (report.get("local_bounds", AABB()) as AABB) == live_bounds:
			exact_live_bounds += 1
		if _layout_matches_bounds(report, live_bounds):
			exact_layouts += 1
		if is_equal_approx(
			float(report.get("maximum_hull", -1.0)),
			float(EXPECTED_MAXIMUM_HULL.get(craft_name, -2.0))
		):
			exact_maxima += 1
		var expected_revision := 1 if craft_name == "TorrentInterceptor" else 2
		if int(report.get("revision", -1)) == expected_revision:
			exact_capture_revisions += 1
		var model := craft.get_component_damage()
		if model != null \
			and model.get_signal_connection_list(&"component_state_changed").size() == 1:
			single_connections += 1
		if model != null:
			var ledger := model.get_ledger_snapshot()
			if bool(ledger.get("active", false)) \
					and int(ledger.get("generation", 0)) == 1 \
					and ledger.get("component_order", []) == ShipComponentDamage.COMPONENT_ORDER:
				active_generic_ledgers += 1
		if model != null:
			_initial_component_model_ids[craft_name] = model.get_instance_id()
		_initial_fleet_geometry[craft_name] = _component_geometry_snapshot(report)
	_check(
		configured == FLEET_CRAFT_NAMES.size(),
		"every production craft boots with one configured, fully nominal component roster"
	)
	_check(
		duplicates == 0,
		"no production craft carries a duplicate component model node"
	)
	_check(
		exact_live_bounds == FLEET_CRAFT_NAMES.size()
			and exact_layouts == FLEET_CRAFT_NAMES.size(),
		"every roster captures its final live root-collision bounds and exact derived anchors"
	)
	_check(
		exact_maxima == FLEET_CRAFT_NAMES.size(),
		"component normalization preserves exact fleet maxima 100, 82, 260, 68, and 190"
	)
	_check(
		exact_capture_revisions == FLEET_CRAFT_NAMES.size(),
		"Torrent configures once while each collision-replacing variant performs exactly one final capture"
	)
	_check(
		single_connections == FLEET_CRAFT_NAMES.size(),
		"final geometry capture retains exactly one component-state signal connection per craft"
	)
	_check(
		active_generic_ledgers == FLEET_CRAFT_NAMES.size(),
		"every fleet adapter exposes one active generic ledger behind the legacy scene node"
	)

	# The roster is derived from each craft's final live collision envelope rather
	# than the temporary Torrent collision the four variants replace during ready.
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

	var distinct_variant_bounds := 0
	var distinct_variant_layouts := 0
	var torrent_geometry := _initial_fleet_geometry.get("TorrentInterceptor", {}) as Dictionary
	for craft_name: String in FLEET_CRAFT_NAMES.slice(1):
		var geometry := _initial_fleet_geometry.get(craft_name, {}) as Dictionary
		if not _bounds_equal(
			geometry.get("local_bounds", AABB()) as AABB,
			torrent_geometry.get("local_bounds", AABB()) as AABB
		):
			distinct_variant_bounds += 1
		if _count_distinct_component_anchors(geometry, torrent_geometry) \
			== ShipComponentDamage.COMPONENT_ORDER.size():
			distinct_variant_layouts += 1
	_check(
		distinct_variant_bounds == 4 and distinct_variant_layouts == 4,
		"Arrow, Jovian, Zenith, and Halyard each reject the stale Torrent bounds and all five Torrent anchors"
	)

	var idempotent_variants := 0
	for craft_name: String in FLEET_CRAFT_NAMES.slice(1):
		var craft := _game.get_node(craft_name) as HeroShip
		var before := craft.get_component_damage_report()
		var model_id := craft.get_component_damage().get_instance_id()
		var accepted := bool(craft.call("_reconfigure_component_damage_from_final_root_collision"))
		var after := craft.get_component_damage_report()
		if accepted and before == after \
			and craft.get_component_damage().get_instance_id() == model_id:
			idempotent_variants += 1
	_check(
		idempotent_variants == 4,
		"a repeated protected variant capture is idempotent and retains model identity and revision"
	)
	var torrent_before := _hero.get_component_damage_report()
	var torrent_late := bool(
		_hero.call("_reconfigure_component_damage_from_final_root_collision")
	)
	_check(
		not torrent_late and _hero.get_component_damage_report() == torrent_before,
		"Torrent rejects a late variant-only capture and remains exactly unchanged"
	)


func _test_fleet_reset_geometry_stability() -> void:
	var stable := 0
	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := _game.get_node(craft_name) as HeroShip
		var model_id := craft.get_component_damage().get_instance_id()
		var before_revision := int(craft.get_component_damage_report().get("revision", -1))
		var before_ledger_generation := craft.get_component_damage().get_ledger_generation()
		var spawn_transform := craft.global_transform
		var reset_result := craft.reset_for_reuse(spawn_transform)
		var reset_report := craft.get_component_damage_report()
		var reset_geometry := _component_geometry_snapshot(reset_report)
		var reset_revision := int(reset_report.get("revision", -1))
		var reset_ledger_generation := craft.get_component_damage().get_ledger_generation()
		var cached_capture := bool(
			craft.call("_reconfigure_component_damage_from_final_root_collision")
		)
		var post_capture_report := craft.get_component_damage_report()
		var expected_capture := craft_name != "TorrentInterceptor"
		if bool(reset_result.get("accepted", false)) \
			and reset_result.get("reason") == &"reset_committed" \
			and int(reset_result.get("component_instance_id", 0)) == model_id \
			and int(reset_result.get("component_revision", -1)) == before_revision \
			and reset_geometry == _initial_fleet_geometry.get(craft_name, {}) \
			and _component_geometry_snapshot(post_capture_report) == reset_geometry \
			and reset_revision == before_revision + 1 \
			and int(post_capture_report.get("revision", -2)) == reset_revision \
			and craft.get_component_damage().get_instance_id() == model_id \
			and reset_ledger_generation == before_ledger_generation + 1 \
			and cached_capture == expected_capture:
			stable += 1
	_check(
		stable == FLEET_CRAFT_NAMES.size(),
		"reset restores integrity without recapturing geometry or replacing any fleet component model"
	)


# -------------------------------------------------------- authority boundary --


func _test_hull_authority_is_untouched() -> void:
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var presentation := _hero.get_damage_presentation()
	var positionless_hull_before := float(_hero.get_telemetry().get("hull", 0.0))
	var positionless_effects_before := presentation.get_live_world_effect_count()
	_hero.apply_damage(1.0)
	_check(
		is_equal_approx(
			float(_hero.get_telemetry().get("hull", 0.0)),
			positionless_hull_before - 1.0
		)
		and presentation.get_live_world_effect_count() == positionless_effects_before,
		"position-less damage changes hull without creating a non-finite impact effect"
	)
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var hull_before := float(_hero.get_telemetry().get("hull", 0.0))
	var engine_position := _world_component_position(_hero, ShipComponentDamage.COMPONENT_ENGINE_BAY)
	var expected_radial_normal := (engine_position - _hero.global_position).normalized()
	var finite_effects_before := presentation.get_live_world_effect_count()
	_hero.call("apply_damage", 20.0, engine_position, Vector3.ZERO, -1, false)
	var hull_after := float(_hero.get_telemetry().get("hull", 0.0))
	var impact_root := root.get_node_or_null("HeroDamageImpact") as Node3D
	var impact_sparks := (
		impact_root.get_node_or_null("ImpactSparks") as CPUParticles3D
		if impact_root != null
		else null
	)
	_check(
		presentation.get_live_world_effect_count() == finite_effects_before + 1
		and impact_root != null
		and impact_root.global_position.is_equal_approx(engine_position)
		and impact_sparks != null
		and impact_sparks.direction.is_equal_approx(expected_radial_normal),
		"finite positioned damage preserves its exact impact position and derived normal"
	)
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


## Resolved component state is consumed by Hero's existing control authorities;
## the component model itself still owns no motion, projectile, or aim query.
func _test_operational_control_modifiers() -> void:
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_hero.set("_engine_state", HeroShip.ENGINE_ONLINE)
	_hero.set("_piloted", true)
	_hero.set("_landed", false)
	var control := ShipCommandType.new(1, 0, 1, 1.0, 1.0) as ShipCommand
	_hero.velocity = Vector3.ZERO
	_hero.call("_update_flight", 0.1, control, true)
	var nominal_response := _hero.velocity.length()

	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_degrade_hero_component_to_impaired(ShipComponentDamage.COMPONENT_ENGINE_BAY)
	_hero.set("_engine_state", HeroShip.ENGINE_ONLINE)
	_hero.set("_piloted", true)
	_hero.set("_landed", false)
	_hero.velocity = Vector3.ZERO
	_hero.call("_update_flight", 0.1, control, true)
	var degraded_response := _hero.velocity.length()
	var telemetry := _hero.get_telemetry()
	_check(
		is_equal_approx(float(telemetry.get("engine_power", -1.0)), 0.62)
		and degraded_response < nominal_response
		and nominal_response > 0.0,
		"engine-bay damage reduces real Hero thrust and handling response"
	)

	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	_degrade_hero_component_to_impaired(ShipComponentDamage.COMPONENT_PORT_WING)
	_hero.set("_engine_state", HeroShip.ENGINE_ONLINE)
	_hero.set("_weapon_timer", 0.0)
	_hero.call("_fire_weapon")
	var degraded_cooldown := float(_hero.get("_weapon_timer"))
	var weapon_power := float(_hero.get_telemetry().get("weapon_power", -1.0))
	_check(
		is_equal_approx(weapon_power, 0.62)
		and is_equal_approx(degraded_cooldown, _hero.weapon_cooldown / weapon_power)
		and degraded_cooldown > _hero.weapon_cooldown,
		"weapon-wing damage lengthens the real Hero projectile dispatch cadence"
	)

	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var nominal_targeting_distance := float(_hero.call("_get_weapon_targeting_distance"))
	_degrade_hero_component_to_impaired(ShipComponentDamage.COMPONENT_CORE_SYSTEMS)
	var degraded_targeting_distance := float(_hero.call("_get_weapon_targeting_distance"))
	_check(
		is_equal_approx(float(_hero.get_telemetry().get("targeting_power", -1.0)), 0.62)
		and degraded_targeting_distance < nominal_targeting_distance,
		"core-systems damage shortens the real reticle convergence query"
	)
	_check(
		_hero.get_telemetry().get("damage_status") == &"healthy",
		"component control degradation remains independent of the hull presentation stage"
	)
	_hero.reset_for_reuse(Transform3D(Basis.IDENTITY, ARENA_ORIGIN))
	var restored := _hero.get_operational_modifiers()
	_check(
		is_equal_approx(float(restored.mobility_multiplier), 1.0)
		and is_equal_approx(float(restored.fire_multiplier), 1.0)
		and is_equal_approx(float(restored.targeting_multiplier), 1.0),
		"reuse restores all Hero control modifiers through the single component ledger"
	)


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
	var fleet_revisions: Dictionary = {}
	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := _game.get_node(craft_name) as HeroShip
		fleet_revisions[craft_name] = int(craft.get_component_damage_report().get("revision", -1))
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
	var stable_fleet_geometry := 0
	for craft_name: String in FLEET_CRAFT_NAMES:
		var craft := _game.get_node(craft_name) as HeroShip
		if _component_geometry_snapshot(craft.get_component_damage_report()) \
			== _initial_fleet_geometry.get(craft_name, {}) \
			and craft.get_component_damage().get_instance_id() \
				== int(_initial_component_model_ids.get(craft_name, 0)) \
			and int(craft.get_component_damage_report().get("revision", -1)) \
				== int(fleet_revisions.get(craft_name, -2)):
			stable_fleet_geometry += 1
	_check(
		stable_fleet_geometry == FLEET_CRAFT_NAMES.size(),
		"whole-Main detach/re-entry preserves every final fleet geometry, model identity, and revision"
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


func _test_direct_component_currentness() -> void:
	var model := _hero.get_component_damage()
	if model == null:
		_fail("the live Torrent component model exists for currentness coverage")
		return
	var events: Array[StringName] = []
	model.component_state_changed.connect(
		func(_id: StringName, _state: int, _integrity: float) -> void:
			events.append(&"stage")
	)
	model.components_restored.connect(func() -> void: events.append(&"restored"))
	var parent := _hero.get_parent()
	var detached_before := model.get_component_report()
	if parent != null:
		parent.remove_child(_hero)
	var detached_damage := model.record_damage(5.0)
	var detached_repair := model.tick_repair(1.0, true)
	_check(
		not _hero.is_inside_tree()
			and not bool(detached_damage.get("accepted", true))
			and detached_damage.get("reason", &"") == &"component_detached"
			and not bool(detached_repair.get("accepted", true))
			and detached_repair.get("reason", &"") == &"component_detached"
			and model.get_component_report() == detached_before
			and events.is_empty(),
		"a detached live component model rejects direct damage and repair atomically"
	)
	if parent != null:
		parent.add_child(_hero)
	await process_frame
	var live_damage := model.record_damage(1.0)
	_check(
		_hero.is_inside_tree()
			and bool(live_damage.get("accepted", false))
			and int(model.get_component_report().get("revision", -1))
				> int(detached_before.get("revision", -1)),
		"a re-entered live component model still accepts a fresh direct damage mutation"
	)
	var queued_before := model.get_component_report()
	var queued_events_before := events.size()
	model.queue_free()
	var queued_damage := model.record_damage(5.0)
	var queued_repair := model.tick_repair(1.0, true)
	_check(
		model.is_inside_tree()
			and model.is_queued_for_deletion()
			and not bool(queued_damage.get("accepted", true))
			and queued_damage.get("reason", &"") == &"component_detached"
			and not bool(queued_repair.get("accepted", true))
			and queued_repair.get("reason", &"") == &"component_detached"
			and model.get_component_report() == queued_before
			and events.size() == queued_events_before,
		"a queued live component model rejects direct damage and repair atomically"
	)


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
	_check(
		float(_hero.get_operational_modifiers().get("fire_multiplier", 1.0)) < 1.0,
		"the damaged berthed weapon wing starts with degraded fire capability"
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
		is_equal_approx(
			float(_hero.get_operational_modifiers().get("fire_multiplier", 0.0)),
			1.0
		),
		"authorized berth repair restores the consumed weapon modifier"
	)
	_check(
		bool(_hero.get_telemetry().get("landed", false))
		and not bool(_hero.get_telemetry().get("landing_active", true)),
		"nothing about the repair holds the craft in a landing or busy state"
	)


# ---------------------------------------------------------------- helpers --


func _layout_matches_bounds(report: Dictionary, bounds: AABB) -> bool:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		return false
	var centre := bounds.get_center()
	var extents := bounds.size * 0.5
	var longitudinal_radius := maxf(
		extents.z * 0.55,
		ShipComponentDamage.MINIMUM_COMPONENT_RADIUS
	)
	var lateral_radius := maxf(
		extents.x * 0.55,
		ShipComponentDamage.MINIMUM_COMPONENT_RADIUS
	)
	var core_radius := maxf(
		(extents.x + extents.z) * 0.28,
		ShipComponentDamage.MINIMUM_COMPONENT_RADIUS
	)
	var expected := {
		ShipComponentDamage.COMPONENT_FORWARD_HULL: {
			"position": centre + Vector3(0.0, extents.y * 0.22, -extents.z * 0.70),
			"radius": longitudinal_radius,
		},
		ShipComponentDamage.COMPONENT_PORT_WING: {
			"position": centre + Vector3(-extents.x * 0.78, extents.y * 0.12, 0.0),
			"radius": lateral_radius,
		},
		ShipComponentDamage.COMPONENT_STARBOARD_WING: {
			"position": centre + Vector3(extents.x * 0.78, extents.y * 0.12, 0.0),
			"radius": lateral_radius,
		},
		ShipComponentDamage.COMPONENT_CORE_SYSTEMS: {
			"position": centre + Vector3(0.0, extents.y * 0.42, 0.0),
			"radius": core_radius,
		},
		ShipComponentDamage.COMPONENT_ENGINE_BAY: {
			"position": centre + Vector3(0.0, extents.y * 0.20, extents.z * 0.74),
			"radius": longitudinal_radius,
		},
	}
	var components := report.get("components", []) as Array
	if components.size() != ShipComponentDamage.COMPONENT_ORDER.size():
		return false
	for entry: Dictionary in components:
		var component_id := StringName(entry.get("id", &""))
		if not expected.has(component_id):
			return false
		var expected_entry := expected[component_id] as Dictionary
		var position := entry.get("local_position", Vector3.INF) as Vector3
		if not position.is_equal_approx(expected_entry.position as Vector3) \
			or not is_equal_approx(
				float(entry.get("local_radius", -1.0)),
				float(expected_entry.radius)
			) \
			or not bounds.has_point(position):
			return false
	return true


func _component_geometry_snapshot(report: Dictionary) -> Dictionary:
	var components: Array[Dictionary] = []
	for entry: Dictionary in report.get("components", []) as Array:
		components.append({
			"id": StringName(entry.get("id", &"")),
			"local_position": entry.get("local_position", Vector3.INF) as Vector3,
			"local_radius": float(entry.get("local_radius", -1.0)),
		})
	return {
		"maximum_hull": float(report.get("maximum_hull", -1.0)),
		"local_bounds": report.get("local_bounds", AABB()) as AABB,
		"components": components,
	}.duplicate(true)


func _bounds_equal(left: AABB, right: AABB) -> bool:
	return left.position.is_equal_approx(right.position) \
		and left.size.is_equal_approx(right.size)


func _count_distinct_component_anchors(left: Dictionary, right: Dictionary) -> int:
	var right_positions: Dictionary = {}
	for entry: Dictionary in right.get("components", []) as Array:
		right_positions[StringName(entry.get("id", &""))] = (
			entry.get("local_position", Vector3.INF) as Vector3
		)
	var distinct := 0
	for entry: Dictionary in left.get("components", []) as Array:
		var component_id := StringName(entry.get("id", &""))
		var position := entry.get("local_position", Vector3.INF) as Vector3
		var other := right_positions.get(component_id, Vector3.INF) as Vector3
		if not position.is_equal_approx(other):
			distinct += 1
	return distinct


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


func _degrade_hero_component_to_impaired(component_id: StringName) -> void:
	for _hit in 8:
		if _hero.get_component_damage().get_component_state(component_id) \
				!= ShipComponentDamage.ComponentState.NOMINAL:
			return
		_hero.call(
			"apply_damage",
			3.0,
			_world_component_position(_hero, component_id),
			Vector3.UP,
			-1,
			false
		)


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
