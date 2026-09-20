extends SceneTree

## Production integration for the varied encounter scenarios through the real
## `res://scenes/main.tscn` combat path.
##
## The suite drives the coordinator's own interceptor engagement, lets
## `EncounterScenarioDirector` dispatch its first scenario, fires one real
## courier shot through the single live `CombatResolver`, triggers the distress
## broadcast and the escort wing, and then does the thing that matters most:
## **ends the phase out from under a running scenario** and proves the whole
## scenario stands down inside it.
##
## That last step is the production form of SANDBOX-002. The recorded defect is
## that the picket's withdrawal is keyed to the defender's activity and
## evaluated in the picket's own physics pass, so a charge committed on the
## frame the defender dies can still land during `RETURN_TO_YARD`. Everything
## this slice adds is gated the other way round — the encounter's authorization
## is re-asked on the frame a shot is dispatched — and this suite proves it
## against the real coordinator, with the real phase transition, rather than
## against a fixture.
##
## Every wait is a bounded frame budget on the fixed physics step; nothing here
## reads a wall clock.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const DISPATCH_FRAME_BUDGET := 420
const SETTLE_FRAME_BUDGET := 240
const PRODUCTION_START_DELAY := 4.5
const TEST_START_DELAY := 0.35
const COURIER_TEST_DISTANCE := 70.0

var _failures: Array[String] = []
var _assertion_count := 0
var _conclusions: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	await _test_production_encounter()
	await _test_paired_wing_scatter_scenario()
	await _test_opponent_role_tactics()
	await _test_station_defense_multi_stage_encounter()
	_check(
		root.get_child_count() == original_root_child_count,
		"the production encounter fixture cleans up without leaving scene nodes"
	)
	_finish()


func _test_paired_wing_scatter_scenario() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var target := game.get_node("TorrentInterceptor") as HeroShip
	var director := game.get_node("EncounterScenarios") as EncounterScenarioDirector
	var coordinator := game.get_node("EncounterScenarios/WingCoordinator") as WingCoordinator
	var pulse := game.get_node("PulseWeaponPresentation") as PulseWeaponPresentation
	var resolver := game.get_combat_resolver()
	director.start_delay = 999.0
	director.suppression_lead_time = 0.0
	game.destroyed_targets = game.total_targets
	game.call("_begin_interceptor_engagement")
	await process_frame
	_check(
		director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, target),
		"the production paired_wing scenario admits its scatter slice"
	)
	await _advance_physics(2)
	var anchor := coordinator.get_anchor() as FlankingSkirmisherOpponent
	var flanker: FlankingSkirmisherOpponent = null
	for member: FlankingSkirmisherOpponent in [
		game.get_node("WingSkirmisherLead") as FlankingSkirmisherOpponent,
		game.get_node("WingSkirmisherWing") as FlankingSkirmisherOpponent,
	]:
		if member != anchor:
			flanker = member
			break
	_check(
		director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_PAIRED_WING
		and flanker != null and flanker.is_active(),
		"paired_wing dispatches one live flanker under the coordinator"
	)
	if flanker == null:
		await _free_game(game)
		return
	var picket := game.get_node("StandoffPicket") as StandoffPicketOpponent
	var picket_launched := await _advance_until(
		func() -> bool: return picket.is_active(), SETTLE_FRAME_BUDGET
	)
	_check(
		picket_launched and resolver.get_registered_source_count() == 15
		and bool(game.get_live_combat_source_roster_audit().valid),
		"the paired wing and picket compose exactly fifteen audited live sources"
	)
	root.remove_child(game)
	await process_frame
	_check(
		resolver.get_registered_source_count() == 0,
		"whole-Main detach unregisters the active paired wing and picket"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		director.is_running() and coordinator.get_active_member_count() == 2
		and resolver.get_registered_source_count() == 15
		and bool(game.get_live_combat_source_roster_audit().valid),
		"whole-Main reentry restores the running pair and picket with fifteen exact sources"
	)
	flanker.acceleration = 0.0
	flanker.velocity = Vector3.ZERO
	var rear_origin := target.global_position + target.global_basis.z * 48.0
	flanker.global_transform = Transform3D(
		Basis.looking_at(
			(target.global_position - rear_origin).normalized(), Vector3.UP
		).orthonormalized(),
		rear_origin
	)
	flanker.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	flanker.set_target(target)
	await _advance_physics(1)
	var presented_before := int(pulse.get_statistics().presented)
	var sequence_before := resolver.get_last_sequence(flanker, flanker.source_id)
	flanker.set("_cooldown_remaining", 0.0)
	flanker.call("_fire_at_target", target.global_position)
	var result := flanker.get_last_shot_result()
	var source_snapshots := 0
	var all_scatter_amber := true
	for snapshot: Dictionary in pulse.get_active_shot_snapshots():
		if int(snapshot.get("source_instance_id", 0)) != flanker.get_instance_id():
			continue
		source_snapshots += 1
		all_scatter_amber = (
			all_scatter_amber
			and snapshot.get("style_id", &"") == PulseWeaponPresentation.STYLE_AMBER
			and snapshot.get("profile_id", &"") == PulseWeaponPresentation.PROFILE_REPEATER
		)
	_check(
		bool(result.get("accepted", false)) and bool(result.get("resolved", false))
		and (result.get("pellets", []) as Array).size() == 3
		and resolver.get_last_sequence(flanker, flanker.source_id) == sequence_before + 3,
		"paired_wing fires three resolver-authoritative pellets as one trigger"
	)
	_check(
		int(pulse.get_statistics().presented) == presented_before + 3
		and source_snapshots == 3 and all_scatter_amber,
		"paired_wing visibly launches a bounded three-ray amber scatter fan"
	)
	director.abort()
	await _advance_physics(1)
	_check(
		flanker.get_pending_shot_receipt_count() == 0
		and not _pulse_has_source(pulse, flanker.get_instance_id()),
		"paired_wing abort retires its complete scatter presentation transaction"
	)
	await _free_game(game)


## The defender's authored cadence (0.62 s telegraph + 1.55 s cooldown), the
## burst that cadence buys against its 22-per-shot / 100-ceiling gun, and the
## forced vent that follows. All four numbers are authored in
## `assets/weapons/range_defence_pulse.tres`.
const DEFENDER_SHOT_PERIOD_SECONDS := 2.17
const DEFENDER_SHOTS_BEFORE_LOCKOUT := 7
const DEFENDER_LOCKOUT_SECONDS := 2.5


func _test_production_encounter() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the varied encounter")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var defender := game.get_node_or_null("RangeOpponent") as RangeOpponent
	var director := game.get_node_or_null("EncounterScenarios") as EncounterScenarioDirector
	var coordinator := game.get_node_or_null("EncounterScenarios/WingCoordinator") as WingCoordinator
	var courier := game.get_node_or_null("CourierRunner") as CourierRunnerOpponent
	var lead := game.get_node_or_null("WingSkirmisherLead") as FlankingSkirmisherOpponent
	var wing := game.get_node_or_null("WingSkirmisherWing") as FlankingSkirmisherOpponent
	var authority := game.get_combat_authority()
	var resolver := game.get_combat_resolver()
	var pulse := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	_check(
		torrent != null and defender != null and director != null and coordinator != null
		and courier != null and lead != null and wing != null
		and authority != null and resolver != null and pulse != null,
		"the production scene stages the fleet, the defender, the scenario director and its craft"
	)
	if (
		director == null or coordinator == null or courier == null or lead == null
		or wing == null or resolver == null or torrent == null or defender == null
	):
		await _free_game(game)
		return
	director.scenario_concluded.connect(_on_scenario_concluded)

	# ---------------------------------------------------- dormant baseline ----
	var baseline_sources := resolver.get_registered_source_count()
	_check(
		is_equal_approx(director.start_delay, PRODUCTION_START_DELAY) and director.enabled,
		"the production director ships enabled with its authored start delay"
	)
	_check(
		director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and director.get_roster().is_empty(),
		"the director is idle and holds no roster before the encounter"
	)
	for craft in [courier, lead, wing]:
		_check(
			not craft.is_active() and not craft.visible
			and craft.collision_layer == 0 and craft.collision_mask == 0
			and not craft.is_combat_source_registered(),
			"%s is dormant, hidden, non-colliding and unregistered before the encounter"
				% craft.name
		)
		_check(
			bool(craft.call(&"get_audit_report").valid),
			"%s audits clean at boot: %s" % [craft.name, craft.call(&"get_validation_errors")]
		)
	# The settled production fleet and defence roster has twelve sources.
	# Dormant scenario opponents must add none until admitted by the director.
	_check(
		baseline_sources == 12 and bool(game.get_live_combat_source_roster_audit().valid),
		"the new craft leave the coordinator's twelve-source census exactly as it was (%d)"
			% baseline_sources
	)

	# A live defender alone must not arm a scenario: the phase is the gate.
	defender.activate(Transform3D(Basis.IDENTITY, Vector3(320.0, 90.0, -400.0)))
	var armed_without_phase := await _advance_until(
		func() -> bool: return director.is_running(),
		SETTLE_FRAME_BUDGET
	)
	_check(
		not armed_without_phase and game.phase != GameFlow.Phase.INTERCEPTOR_ENGAGEMENT,
		"a scenario refuses to arm outside the coordinator's interceptor engagement"
	)
	defender.deactivate()
	await _advance_physics(2)

	# ------------------------------------------- real coordinator encounter ----
	director.start_delay = TEST_START_DELAY
	game.destroyed_targets = game.total_targets
	game.call("_begin_interceptor_engagement")
	await process_frame
	_check(
		game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT and defender.is_active(),
		"the coordinator's own encounter path launches the live defender"
	)
	_check(
		not director.is_running(),
		"the scenario does not arm in the same instant the defender launches"
	)

	var armed := await _advance_until(
		func() -> bool: return director.is_running(),
		DISPATCH_FRAME_BUDGET
	)
	_check(armed, "the director arms its first scenario inside the live engagement")
	_check(
		director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_COURIER_INTERCEPT,
		"the first sortie runs the intercept scenario, not the pair (%s)"
			% director.get_active_scenario()
	)
	_check(
		courier.is_active() and courier.visible and courier.collision_layer != 0
		and is_equal_approx(courier.get_health(), courier.maximum_health),
		"the runner is dispatched visible, collidable and at full hull"
	)
	_check(
		courier.get("_target") == game.get_active_ship(),
		"the runner acquires the coordinator's active craft as its target"
	)
	_check(
		courier.get_escape_heading().is_normalized()
		and is_equal_approx(courier.escape_distance, director.escape_distance),
		"the runner and the director measure the same boundary run"
	)
	_check(
		resolver.get_registered_source_count() == baseline_sources + 1
		and bool(game.get_live_combat_source_roster_audit().valid)
		and courier.is_combat_source_registered()
		and authority.get_source_id(courier) == courier.source_id
		and authority.get_source_id(defender) == GameFlow.OPPONENT_SOURCE_ID
		and authority.get_source_id(torrent) == 1101,
		"dispatch adds exactly one authority identity beside the untouched fleet and defender"
	)
	_check(
		courier.get_node_or_null("AuthoritativeDamageable") is LifecycleDamageableAdapter,
		"the runner is damageable through the shared lifecycle adapter, not a private health store"
	)
	_check(
		not lead.is_active() and not wing.is_active(),
		"the escort wing stays dormant until the runner actually calls for it"
	)

	# ---------------------------------------------- one real courier shot ----
	# Evidence control: the craft is pinned so the shot under test is the
	# production weapon path rather than a navigation race. Attitude, arc gate,
	# cooldown, resolution and presentation all remain production code.
	courier.acceleration = 0.0
	courier.velocity = Vector3.ZERO
	# The tail turret only covers the cone behind the runner, so the runner is
	# placed ahead of the player and pointed away from him: the exact geometry a
	# stern chase produces.
	var courier_origin := torrent.global_position + Vector3(0.0, 26.0, COURIER_TEST_DISTANCE)
	var to_player := (torrent.global_position - courier_origin).normalized()
	courier.global_transform = Transform3D(
		Basis.looking_at(-to_player, Vector3.UP).orthonormalized(),
		courier_origin
	)
	courier.set_target(torrent)
	await _advance_physics(2)

	var hull_before := float(torrent.get_telemetry().get("hull", 0.0))
	var sequence_before := resolver.get_last_sequence(courier, courier.source_id)
	var presented_before := int(pulse.get_statistics().presented)
	courier.set("_cooldown_remaining", 0.0)
	courier.call("_fire_at_target", torrent.global_position)
	var shot: Dictionary = courier.get_last_shot_result()
	_check(
		bool(shot.get("accepted", false)) and bool(shot.get("resolved", false))
		and StringName(shot.get("source_faction_id", &"")) == GameFlow.OPPONENT_FACTION,
		"the tail turret resolves on the production resolver under the defence faction"
	)
	_check(
		bool(shot.get("damaged", false)) and shot.get("target_entity") == torrent
		and is_equal_approx(float(shot.get("applied_damage", 0.0)), courier.weapon_damage),
		"one tail-turret shot applies exactly one authoritative hull commit to the player craft"
	)
	_check(
		is_equal_approx(
			float(torrent.get_telemetry().get("hull", 0.0)),
			hull_before - courier.weapon_damage
		),
		"the player craft loses exactly the turret damage and nothing more"
	)
	_check(
		resolver.get_last_sequence(courier, courier.source_id) == sequence_before + 1,
		"the shot consumes exactly one monotonic sequence on the shared replay ledger"
	)
	_check(
		int(pulse.get_statistics().presented) == presented_before + 1,
		"the shot consumes exactly one slot of the shared fixed pulse pool"
	)

	# The forward arc is genuinely closed, not merely disfavoured: turned to face
	# the player, the same turret cannot dispatch a shot at all.
	var withheld_before := courier.get_shots_withheld()
	var fired_before := courier.get_shots_fired()
	courier.global_transform = Transform3D(
		Basis.looking_at(to_player, Vector3.UP).orthonormalized(),
		courier_origin
	)
	await _advance_physics(1)
	courier.set("_cooldown_remaining", 0.0)
	courier.call("_fire_at_target", torrent.global_position)
	_check(
		courier.get_shots_withheld() == withheld_before + 1
		and courier.get_shots_fired() == fired_before,
		"the runner cannot fire forward: the tail arc withholds the shot outright"
	)

	# ------------------------------------- distress broadcast and the wing ----
	courier.apply_damage(courier.maximum_health * 0.35, courier.global_position)
	var broadcast := await _advance_until(
		func() -> bool: return director.is_distress_broadcast(),
		SETTLE_FRAME_BUDGET
	)
	_check(broadcast, "hurting the runner triggers its distress broadcast")
	_check(
		courier.is_distress_broadcast(),
		"the runner itself lights its distress beacon when the broadcast starts"
	)
	var escorted := await _advance_until(
		func() -> bool: return director.is_escort_launched(),
		SETTLE_FRAME_BUDGET
	)
	_check(escorted, "the distress call brings the escort wing in after its response delay")
	_check(
		lead.is_active() and wing.is_active()
		and lead.is_combat_source_registered() and wing.is_combat_source_registered(),
		"both escorts launch and register their own combat identities"
	)
	_check(
		resolver.get_registered_source_count() >= baseline_sources + 3
		and bool(game.get_live_combat_source_roster_audit().valid),
		"the escort adds its own identities without displacing any existing source"
	)
	await _advance_physics(2)
	_check(
		coordinator.get_active_member_count() == 2 and coordinator.get_anchor() != null,
		"the escort pair is enlisted and holds exactly one anchor"
	)
	var anchor := coordinator.get_anchor() as FlankingSkirmisherOpponent
	var flanker := wing if anchor == lead else lead
	_check(
		coordinator.get_role(flanker) == WingCoordinator.ROLE_FLANKER,
		"the escort's second craft takes the flanking role"
	)
	_check(
		coordinator.get_validation_errors().is_empty(),
		"the live wing passes its own audit: %s" % [coordinator.get_validation_errors()]
	)

	# The flanker's gun is hard-safed in the player's forward arc. Parked dead
	# ahead of the Torrent, it cannot dispatch a shot at all.
	flanker.acceleration = 0.0
	flanker.velocity = Vector3.ZERO
	flanker.global_transform = Transform3D(
		Basis.looking_at(torrent.global_basis.z, Vector3.UP).orthonormalized(),
		torrent.global_position - torrent.global_basis.z * 55.0
	)
	flanker.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	flanker.set_target(torrent)
	await _advance_physics(1)
	var flanker_withheld := flanker.get_shots_withheld()
	var flanker_fired := flanker.get_shots_fired()
	flanker.set("_cooldown_remaining", 0.0)
	flanker.call("_fire_at_target", torrent.global_position)
	_check(
		flanker.get_shots_withheld() == flanker_withheld + 1
		and flanker.get_shots_fired() == flanker_fired,
		"a flanker in the player's forward arc withholds its shot instead of taking it"
	)
	_check(
		flanker.is_weapon_safed() or flanker.get_wing_role() == WingCoordinator.ROLE_ANCHOR,
		"the flanker's own safing latch agrees with the refused shot"
	)

	# Park the same craft in the open rear arc and resolve its production scatter
	# trigger. The resolver, not the opponent script, supplies the three fan rays.
	var rear_origin := torrent.global_position + torrent.global_basis.z * 55.0
	var rear_to_player := (torrent.global_position - rear_origin).normalized()
	flanker.global_transform = Transform3D(
		Basis.looking_at(rear_to_player, Vector3.UP).orthonormalized(),
		rear_origin
	)
	flanker.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	flanker.set_target(torrent)
	await _advance_physics(1)
	var scatter_hull_before := float(torrent.get_telemetry().get("hull", 0.0))
	var scatter_sequence_before := resolver.get_last_sequence(flanker, flanker.source_id)
	var scatter_presented_before := int(pulse.get_statistics().presented)
	flanker.set("_cooldown_remaining", 0.0)
	flanker.call("_fire_at_target", torrent.global_position)
	var scatter := flanker.get_last_shot_result()
	var scatter_pellets := scatter.get("pellets", []) as Array
	var scatter_directions := scatter.get(
		"pellet_directions", PackedVector3Array()
	) as PackedVector3Array
	_check(
		bool(scatter.get("accepted", false))
		and bool(scatter.get("resolved", false))
		and scatter_pellets.size() == 3
		and scatter_directions.size() == 3,
		"an open rear arc dispatches one production three-pellet scatter trigger"
	)
	var pellets_authoritative := true
	var receipt_ids := {}
	for raw_pellet: Variant in scatter_pellets:
		var pellet := raw_pellet as Dictionary
		var pellet_request := pellet.get("request") as ShotRequest
		pellets_authoritative = (
			pellets_authoritative
			and bool(pellet.get("accepted", false))
			and bool(pellet.get("resolved", false))
			and StringName(pellet.get("source_faction_id", &"")) == GameFlow.OPPONENT_FACTION
			and pellet_request != null
			and pellet_request.source_entity == flanker
			and pellet_request.weapon_id == FlankingSkirmisherOpponent.SKIRMISHER_WEAPON_ID
		)
		if pellet_request != null:
			receipt_ids[pellet_request.presentation_receipt_id] = true
	_check(
		pellets_authoritative
		and receipt_ids.size() == 3
		and resolver.get_last_sequence(flanker, flanker.source_id)
			== scatter_sequence_before + 3,
		"every fan pellet owns a unique receipt and resolver sequence under the flanker identity"
	)
	var scatter_applied := float(scatter.get("applied_damage", 0.0))
	_check(
		scatter_applied > 0.0
		and scatter_applied <= 14.0
		and is_equal_approx(
			float(torrent.get_telemetry().get("hull", 0.0)),
			scatter_hull_before - scatter_applied
		),
		"the complete fan commits damage once per pellet without exceeding its 14-point trigger cap"
	)
	_check(
		is_equal_approx(rad_to_deg(scatter_directions[0].angle_to(scatter_directions[1])), 5.0)
		and is_equal_approx(rad_to_deg(scatter_directions[1].angle_to(scatter_directions[2])), 5.0)
		and int(pulse.get_statistics().presented) == scatter_presented_before + 3,
		"the player receives a deterministic pooled amber centre plus/minus five-degree fan"
	)

	# ------------------------------- the phase ends under a live scenario ----
	# This is the SANDBOX-002 shape in production. The defender dies, the
	# coordinator moves to RETURN_TO_YARD, and every scenario craft must stop —
	# including one that already has a charge committed.
	_check(director.is_running(), "the scenario is still live when the defender dies")
	lead.set("_telegraph_remaining", 0.0001)
	wing.set("_telegraph_remaining", 0.0001)
	courier.set("_telegraph_remaining", 0.0001)
	var shots_before := (
		courier.get_shots_fired() + lead.get_shots_fired() + wing.get_shots_fired()
	)
	defender.apply_damage(defender.get_health(), defender.global_position)
	await _advance_physics(1)
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD,
		"destroying the defender still moves the coordinator to its return phase"
	)
	var concluded := await _advance_until(
		func() -> bool: return director.is_concluded(),
		SETTLE_FRAME_BUDGET
	)
	_check(concluded, "the phase change concludes the running scenario")
	_check(
		director.get_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN,
		"the phase change withdraws the scenario (%s)" % director.get_outcome()
	)
	_check(
		_last_conclusion_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN,
		"the withdrawal is announced on the scenario_concluded signal"
	)
	var shots_after := (
		courier.get_shots_fired() + lead.get_shots_fired() + wing.get_shots_fired()
	)
	_check(
		shots_after == shots_before,
		"no committed charge lands after the phase ended (%d -> %d)"
			% [shots_before, shots_after]
	)
	for craft in [courier, lead, wing]:
		_check(
			not craft.is_active() and not craft.is_combat_source_registered(),
			"%s is stood down and unregistered once the scenario withdraws" % craft.name
		)
	_check(
		flanker.get_pending_shot_receipt_count() == 0
		and not _pulse_has_source(pulse, flanker.get_instance_id()),
		"scenario withdrawal clears every pending scatter receipt and in-flight fan visual"
	)
	_check(
		director.get_roster().is_empty() and coordinator.get_member_count() == 0,
		"the withdrawn scenario releases its roster and empties the wing"
	)
	_check(
		resolver.get_registered_source_count() == baseline_sources
		and bool(game.get_live_combat_source_roster_audit().valid),
		"the withdrawn scenario returns the source census to the twelve baseline sources (%d)"
			% resolver.get_registered_source_count()
	)
	_check(
		director.get_validation_errors().is_empty(),
		"the withdrawn director passes its own audit: %s" % [director.get_validation_errors()]
	)

	# Nothing re-arms after the phase has moved on, however long the loop runs.
	var rearmed := await _advance_until(
		func() -> bool: return director.is_running(),
		SETTLE_FRAME_BUDGET
	)
	_check(
		not rearmed and not courier.is_active(),
		"no scenario re-arms once the coordinator has left the engagement"
	)

	# ------------------------------------------ the defender's gun overheats ----
	# The production defender is the first shipped opponent that has to stop
	# firing. Everything below runs through the coordinator's own signal handler
	# and the one live authority; nothing is simulated.
	_check(
		WeaponDefinitionResolverProfile.profile_is_heat(
			authority.get_weapon_profile(defender, GameFlow.OPPONENT_WEAPON_ID)
		),
		"the production defender ships registered with an authored heat envelope"
	)
	defender.activate(Transform3D(Basis.IDENTITY, Vector3(320.0, 90.0, -400.0)))
	_check(
		is_equal_approx(
			authority.get_weapon_heat_ratio(defender, GameFlow.OPPONENT_WEAPON_ID), 0.0
		),
		"a launched defender starts the engagement with a cold gun"
	)
	var defender_direction := -defender.global_basis.z
	var defender_muzzle := defender.global_position + defender_direction * 6.0
	var defender_shots := 0
	var defender_lockout := {}
	for _index in 12:
		defender.projectile_fired.emit(defender_muzzle, defender_direction)
		var defender_shot := game.get("_last_opponent_shot_result") as Dictionary
		if StringName(defender_shot.get("status", &"")) == CombatResolver.HEAT_LOCKOUT_STATUS:
			defender_lockout = defender_shot
			break
		defender_shots += 1
		if authority.is_weapon_heat_locked(defender, GameFlow.OPPONENT_WEAPON_ID):
			continue
		resolver.advance_weapon_heat(DEFENDER_SHOT_PERIOD_SECONDS)
	_check(
		defender_shots == DEFENDER_SHOTS_BEFORE_LOCKOUT and not defender_lockout.is_empty(),
		"the production defender lands %d shots at its authored cadence, then its gun refuses (%d)"
			% [DEFENDER_SHOTS_BEFORE_LOCKOUT, defender_shots]
	)
	_check(
		not bool(defender_lockout.get("accepted", true))
		and not bool(defender_lockout.get("damaged", true))
		and is_equal_approx(float(defender_lockout.get("applied_damage", -1.0)), 0.0)
		and is_equal_approx(
			authority.get_weapon_heat_lockout_remaining(
				defender, GameFlow.OPPONENT_WEAPON_ID
			),
			DEFENDER_LOCKOUT_SECONDS
		),
		"the refused shot costs the player nothing and opens the authored %.1f s window"
			% DEFENDER_LOCKOUT_SECONDS
	)
	defender.call("_update_presentation", 0.0)
	var vent_state := defender.get_weapon_heat_presentation_state()
	# The accessibility hand-off is asserted against the validated setting as it
	# ships. Nothing here writes a setting: RuntimeSettings persists to the real
	# user-data file, and a test that toggled it would leak into every later run.
	var settings := game.get("runtime_settings") as RuntimeSettings
	game.call("_apply_opponent_weapon_heat_presentation_profile")
	defender.call("_update_presentation", 0.0)
	vent_state = defender.get_weapon_heat_presentation_state()
	_check(
		settings != null
		and bool(vent_state.get("reduced_flash", not settings.reduced_flash))
			== settings.reduced_flash
		# The material stores single-precision emission, so the ceiling is compared
		# with one float32 step of slack rather than exactly.
		and float(vent_state.get("vent_emission_energy", 0.0))
			<= float(vent_state.get("vent_peak_emission_energy", 0.0)) + 0.001,
		"the coordinator hands the defender the validated reduced-flash ceiling for its vent"
	)
	_check(
		int(vent_state.get("vent_instance_count", 0)) == 2
		and bool(vent_state.get("locked", false))
		and bool(vent_state.get("vent_visible", false))
		and float(vent_state.get("vent_emission_energy", 0.0)) > 0.0
		and is_equal_approx(float(vent_state.get("heat_ratio", 0.0)), 1.0),
		"the production defender shows the player a hot vent for the whole lockout"
	)
	resolver.advance_weapon_heat(DEFENDER_LOCKOUT_SECONDS)
	defender.call("_update_presentation", 0.0)
	var cooled_state := defender.get_weapon_heat_presentation_state()
	defender.projectile_fired.emit(defender_muzzle, -defender.global_basis.z)
	var reopened_shot := game.get("_last_opponent_shot_result") as Dictionary
	_check(
		not bool(cooled_state.get("locked", true))
		and is_equal_approx(float(cooled_state.get("heat_ratio", 1.0)), 0.0)
		and not bool(cooled_state.get("vent_visible", true))
		and bool(reopened_shot.get("accepted", false)),
		"the window closes on a cold, dark vent and the defender fires again"
	)
	defender.deactivate()
	await _advance_physics(2)

	await _free_game(game)


# ------------------------------------------------------------- helpers ----

func _last_conclusion_outcome() -> StringName:
	if _conclusions.is_empty():
		return &""
	return _conclusions[_conclusions.size() - 1].get("outcome", &"")


func _on_scenario_concluded(scenario_id: StringName, outcome: StringName) -> void:
	_conclusions.append({"scenario": scenario_id, "outcome": outcome})


func _pulse_has_source(pulse: PulseWeaponPresentation, source_instance_id: int) -> bool:
	for snapshot: Dictionary in pulse.get_active_shot_snapshots():
		if int(snapshot.get("source_instance_id", 0)) == source_instance_id:
			return true
	return false


func _advance_physics(frames: int) -> void:
	for _index in frames:
		await physics_frame
		await process_frame


func _advance_until(condition: Callable, frame_budget: int) -> bool:
	for _index in frame_budget:
		if bool(condition.call()):
			return true
		await physics_frame
		await process_frame
	return bool(condition.call())


func _free_game(game: GameFlow) -> void:
	if not is_instance_valid(game):
		return
	# Retire the shared positional voices first: the component's own exit
	# transaction stops and detaches every pooled voice, so no cue outlives the
	# fixture that raised it.
	var audio := game.get_node_or_null("CombatAudioPresentation")
	if is_instance_valid(audio) and audio.get_parent() != null:
		audio.get_parent().remove_child(audio)
		audio.queue_free()
		await process_frame
	var director := game.get_node_or_null("EncounterScenarios") as EncounterScenarioDirector
	root.remove_child(game)
	if director != null:
		_check(is_zero_approx(director.get_escape_progress()),
			"detached encounter reports no world-space escape progress")
	game.queue_free()
	for _index in 12:
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		print("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("VARIED_ENCOUNTER_INTEGRATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("VARIED_ENCOUNTER_INTEGRATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


# ------------------------------------------------- opponent role tactics ----
#
# Three postures the base defender family can be put into, each proven here
# against the production `RangeOpponent` in the production scene, with the
# player's own craft as the thing being fought. Every one of them is observed
# *and* countered, because a tactic the player cannot answer is not a tactic.

## Far enough from the yard that nothing on the world collision layer is in
## the arena, so the only cover in it is the slab this suite puts there.
const TACTIC_ARENA_ORIGIN := Vector3(2600.0, 1400.0, 2600.0)
const TACTIC_ARENA_CLEARANCE_METRES := 300.0
const TACTIC_FRAME_BUDGET := 420
const COVER_SLAB_SIZE := Vector3(60.0, 60.0, 3.0)


func _test_opponent_role_tactics() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var defender := game.get_node_or_null("RangeOpponent") as RangeOpponent
	var authority := game.get_combat_authority()
	if torrent == null or defender == null or authority == null:
		_check(false, "the production scene stages the defender and the player craft")
		await _free_game(game)
		return

	var hold := TACTIC_ARENA_ORIGIN
	var cover_origin := hold + Vector3(0.0, 0.0, 80.0)
	var slab_origin := hold + Vector3(0.0, 0.0, 40.0)
	var arena_clear := true
	for probe: Vector3 in [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN,
		Vector3.FORWARD, Vector3.BACK,
	]:
		arena_clear = arena_clear and _world_ray_clear(
			game, hold, hold + probe * TACTIC_ARENA_CLEARANCE_METRES
		)
	_check(
		arena_clear and _world_ray_clear(game, hold, cover_origin)
		and _world_ray_clear(game, cover_origin, cover_origin + Vector3(0.0, 0.0, 40.0)),
		"the tactic arena is open space in every direction before any cover is placed in it"
	)

	# ------------------------------------------------------- cover_peek ----
	var slab := _add_cover_slab(game, slab_origin)
	defender.activate(Transform3D(Basis.IDENTITY, cover_origin))
	defender.set_target(torrent)
	await _advance_tactic_physics(1, torrent, hold)
	var cover_armed := defender.configure_role_tactic(
		RangeOpponent.ROLE_TACTIC_COVER_PEEK
	)
	var armed_posture := defender.get_role_tactic_snapshot()
	_check(
		bool(cover_armed.get("accepted", false))
		and armed_posture.tactic_id == RangeOpponent.ROLE_TACTIC_COVER_PEEK
		and armed_posture.state_id == &"seeking_cover"
		and armed_posture.pre_discharge_telegraph_id == RangeOpponent.COVER_TELEGRAPH_ID
		and bool(armed_posture.suppresses_fire)
		and not bool(armed_posture.adds_hud_element),
		"the cover posture arms on the production defender and goes quiet while it looks for an occluder"
	)
	var took_cover := await _advance_tactic_until(
		func() -> bool:
			return defender.get_role_tactic_snapshot().state_id == &"in_cover",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var hidden := defender.get_role_tactic_snapshot()
	var hidden_multipliers := hidden.pre_discharge_scale_multipliers as PackedFloat32Array
	_check(
		took_cover and bool((hidden.cover as Dictionary).anchor_valid)
		and bool(hidden.suppresses_fire) and bool(hidden.telegraphing)
		and hidden_multipliers.size() == 2
		and is_equal_approx(hidden_multipliers[0], 0.5)
		and is_equal_approx(hidden_multipliers[1], 0.5)
		and not _world_ray_clear(game, defender.global_position, torrent.global_position),
		"the defender puts real world geometry between itself and the player and holds both lenses shut"
	)
	var leaned_out := await _advance_tactic_until(
		func() -> bool: return defender.get_role_tactic_snapshot().state_id == &"peek",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var peeking := defender.get_role_tactic_snapshot()
	var peek_multipliers := peeking.pre_discharge_scale_multipliers as PackedFloat32Array
	_check(
		leaned_out
		and peeking.pre_discharge_telegraph_id == RangeOpponent.COVER_PEEK_TELEGRAPH_ID
		and not bool(peeking.suppresses_fire)
		and peek_multipliers.size() == 2
		and not is_equal_approx(peek_multipliers[0], peek_multipliers[1])
		and int((peeking.cover as Dictionary).peek_count) >= 1,
		"it leans out of cover to shoot and shows the player which side it is coming from"
	)
	# The counter: take the occluder away, the way flanking does, and the craft
	# has to fight in the open.
	slab.get_parent().remove_child(slab)
	slab.queue_free()
	await process_frame
	var exposed := await _advance_tactic_until(
		func() -> bool: return defender.get_role_tactic_snapshot().state_id == &"exposed",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var open_posture := defender.get_role_tactic_snapshot()
	_check(
		exposed and bool(open_posture.countered)
		and open_posture.counter_reason == &"no_cover_available"
		and not bool(open_posture.suppresses_fire)
		and not bool((open_posture.cover as Dictionary).anchor_valid),
		"denying it cover counters the posture and forces it to fight in the open"
	)
	defender.deactivate()
	await _advance_tactic_physics(2, torrent, hold)

	# --------------------------------------------------- bracket_squeeze ----
	var port_half := RangeOpponent.new()
	port_half.name = "BracketPortHalf"
	var starboard_half := RangeOpponent.new()
	starboard_half.name = "BracketStarboardHalf"
	game.add_child(port_half)
	game.add_child(starboard_half)
	await process_frame
	port_half.activate(Transform3D(Basis.IDENTITY, hold + Vector3(-52.0, 0.0, 6.0)))
	starboard_half.activate(Transform3D(Basis.IDENTITY, hold + Vector3(52.0, 0.0, -6.0)))
	port_half.set_target(torrent)
	starboard_half.set_target(torrent)
	await _advance_tactic_physics(1, torrent, hold)
	var port_armed := port_half.configure_role_tactic(
		RangeOpponent.ROLE_TACTIC_BRACKET_SQUEEZE,
		{"side_sign": -1.0, "partner": starboard_half}
	)
	var starboard_armed := starboard_half.configure_role_tactic(
		RangeOpponent.ROLE_TACTIC_BRACKET_SQUEEZE,
		{"side_sign": 1.0, "partner": port_half}
	)
	var port_lean := port_half.get_role_tactic_snapshot()
	var starboard_lean := starboard_half.get_role_tactic_snapshot()
	var port_lean_scales := port_lean.pre_discharge_scale_multipliers as PackedFloat32Array
	var starboard_lean_scales := (
		starboard_lean.pre_discharge_scale_multipliers as PackedFloat32Array
	)
	_check(
		bool(port_armed.get("accepted", false))
		and bool(starboard_armed.get("accepted", false))
		and port_lean.state_id == &"closing" and starboard_lean.state_id == &"closing"
		and port_lean.pre_discharge_telegraph_id \
			== RangeOpponent.BRACKET_CLOSING_TELEGRAPH_ID
		and bool((port_lean.bracket as Dictionary).partner_engaged)
		and bool((starboard_lean.bracket as Dictionary).partner_engaged)
		and port_lean_scales.size() == 2 and starboard_lean_scales.size() == 2
		and is_equal_approx(port_lean_scales[0], starboard_lean_scales[1])
		and is_equal_approx(port_lean_scales[1], starboard_lean_scales[0])
		and not is_equal_approx(port_lean_scales[0], port_lean_scales[1]),
		"the pair takes opposite flanks and each half leans its charge pair to its own side"
	)
	var squeezed := await _advance_tactic_until(
		func() -> bool:
			return (
				port_half.get_role_tactic_snapshot().state_id == &"squeeze"
				and starboard_half.get_role_tactic_snapshot().state_id == &"squeeze"
			),
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var port_squeeze := port_half.get_role_tactic_snapshot()
	var squeeze_scales := port_squeeze.pre_discharge_scale_multipliers as PackedFloat32Array
	var starboard_squeeze_id := StringName(
		starboard_half.get_role_tactic_snapshot().pre_discharge_telegraph_id
	)
	_check(
		squeezed
		and port_squeeze.pre_discharge_telegraph_id \
			== RangeOpponent.BRACKET_SQUEEZE_TELEGRAPH_ID
		and starboard_squeeze_id == RangeOpponent.BRACKET_SQUEEZE_TELEGRAPH_ID
		and squeeze_scales.size() == 2
		and is_equal_approx(squeeze_scales[0], squeeze_scales[1])
		and squeeze_scales[0] < 1.0
		and int((port_squeeze.bracket as Dictionary).squeeze_count) >= 1,
		"both halves commit at the same moment behind one tightened, side-neutral cue"
	)
	# The commit is a turn, not a teleport: the pair has to haul its orbit round
	# before the player feels it. What matters is that the envelope actually
	# shrinks while the cue is up.
	var port_entry_range := port_half.global_position.distance_to(torrent.global_position)
	var starboard_entry_range := starboard_half.global_position.distance_to(
		torrent.global_position
	)
	await _advance_tactic_until(
		func() -> bool:
			return port_half.get_role_tactic_snapshot().state_id != &"squeeze",
		int(RangeOpponent.BRACKET_SQUEEZE_DURATION_SECONDS * 62.0), torrent, hold
	)
	var port_exit_range := port_half.global_position.distance_to(torrent.global_position)
	var starboard_exit_range := starboard_half.global_position.distance_to(
		torrent.global_position
	)
	_check(
		port_exit_range < port_entry_range - 5.0
		and starboard_exit_range < starboard_entry_range - 5.0,
		"the squeeze closes the bracket around the player from both sides at once"
			+ " (%.1f->%.1f / %.1f->%.1f)" % [
				port_entry_range, port_exit_range,
				starboard_entry_range, starboard_exit_range,
			]
	)
	# Counter one: break out. Leaving the bracket's envelope drops it for good.
	var escape := hold + Vector3(0.0, 0.0, 400.0)
	var broke_out := await _advance_tactic_until(
		func() -> bool:
			return port_half.get_role_tactic_snapshot().state_id == &"broken",
		TACTIC_FRAME_BUDGET, torrent, escape
	)
	var broken := port_half.get_role_tactic_snapshot()
	_check(
		broke_out and bool(broken.countered)
		and broken.counter_reason == &"player_broke_out",
		"flying out past the release range breaks the bracket and it stays broken"
	)
	# Counter two: kill one half. The survivor cannot bracket on its own.
	port_half.configure_role_tactic(RangeOpponent.ROLE_TACTIC_NONE)
	port_half.configure_role_tactic(
		RangeOpponent.ROLE_TACTIC_BRACKET_SQUEEZE,
		{"side_sign": -1.0, "partner": starboard_half}
	)
	starboard_half.deactivate()
	var lost_partner := await _advance_tactic_until(
		func() -> bool:
			return port_half.get_role_tactic_snapshot().state_id == &"broken",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var orphaned := port_half.get_role_tactic_snapshot()
	_check(
		lost_partner and bool(orphaned.countered)
		and orphaned.counter_reason == &"bracket_partner_lost"
		and not bool((orphaned.bracket as Dictionary).partner_engaged),
		"taking either half out of the fight ends the bracket for the survivor"
	)
	port_half.deactivate()
	game.remove_child(port_half)
	game.remove_child(starboard_half)
	port_half.queue_free()
	starboard_half.queue_free()
	await process_frame

	# --------------------------------------------------- withdraw_repair ----
	var repair_origin := hold + Vector3(0.0, 0.0, 46.0)
	defender.activate(Transform3D(Basis.IDENTITY, repair_origin))
	defender.set_target(torrent)
	await _advance_tactic_physics(1, torrent, hold)
	var repair_armed := defender.configure_role_tactic(
		RangeOpponent.ROLE_TACTIC_WITHDRAW_REPAIR
	)
	_check(
		bool(repair_armed.get("accepted", false))
		and defender.get_role_tactic_snapshot().state_id == &"engaged"
		and not bool(defender.get_role_tactic_snapshot().suppresses_fire),
		"the withdrawal posture arms without changing how the defender fights while it is healthy"
	)
	var trigger_health := defender.get_maximum_health() \
		* RangeOpponent.WITHDRAW_REPAIR_TRIGGER_HEALTH_RATIO
	defender.apply_damage(defender.get_health() - trigger_health + 0.5, defender.global_position)
	var hurt_health := defender.get_health()
	var broke_off := await _advance_tactic_until(
		func() -> bool:
			return defender.get_role_tactic_snapshot().state_id == &"withdrawing",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	await _advance_tactic_physics(20, torrent, hold)
	var withdrawing := defender.get_role_tactic_snapshot()
	var withdraw_scales := withdrawing.pre_discharge_scale_multipliers as PackedFloat32Array
	_check(
		broke_off
		and withdrawing.pre_discharge_telegraph_id == RangeOpponent.WITHDRAW_TELEGRAPH_ID
		and bool(withdrawing.suppresses_fire)
		and withdraw_scales.size() == 2
		and is_equal_approx(withdraw_scales[0], 1.5)
		and is_equal_approx(withdraw_scales[1], 1.5)
		and defender.velocity.dot(
			(defender.global_position - torrent.global_position).normalized()
		) > 0.5,
		"a badly hurt defender breaks off, stops shooting, and opens both lenses wide on the way out"
			+ " (%s %.2f)" % [
				withdrawing.state_id,
				defender.velocity.dot(
					(defender.global_position - torrent.global_position).normalized()
				),
			]
	)
	var repairing := await _advance_tactic_until(
		func() -> bool:
			return defender.get_role_tactic_snapshot().state_id == &"repairing",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var patching := defender.get_role_tactic_snapshot()
	var patch_scales := patching.pre_discharge_scale_multipliers as PackedFloat32Array
	_check(
		repairing and bool(patching.holds_station) and bool(patching.suppresses_fire)
		and patching.pre_discharge_telegraph_id \
			== RangeOpponent.WITHDRAW_REPAIR_TELEGRAPH_ID
		and patch_scales.size() == 2
		and not is_equal_approx(patch_scales[0], patch_scales[1])
		and defender.global_position.distance_to(torrent.global_position) \
			> RangeOpponent.WITHDRAW_REPAIR_INTERRUPT_RANGE,
		"it stands off out of reach, holds station and shows one lens split open while it patches"
	)
	var returned := await _advance_tactic_until(
		func() -> bool:
			return defender.get_role_tactic_snapshot().state_id \
				in [&"returning", &"returned"],
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var comeback := defender.get_role_tactic_snapshot()
	var repair_report := comeback.withdraw_repair as Dictionary
	_check(
		returned and float(repair_report.restored_health) > 0.0
		and defender.get_health() > hurt_health
		and defender.get_health() <= defender.get_maximum_health() \
			* RangeOpponent.WITHDRAW_REPAIR_HEALTH_CEILING_RATIO + 0.001
		and defender.get_health() < defender.get_maximum_health()
		and bool(repair_report.returned_damaged)
		and not bool(repair_report.interrupted),
		"it comes back with a patched but permanently damaged hull, never a fresh one"
	)
	# The counter: get on top of it while it works and it comes back with nothing.
	defender.deactivate()
	await _advance_tactic_physics(2, torrent, hold)
	defender.activate(Transform3D(Basis.IDENTITY, repair_origin))
	defender.set_target(torrent)
	await _advance_tactic_physics(1, torrent, hold)
	defender.configure_role_tactic(RangeOpponent.ROLE_TACTIC_WITHDRAW_REPAIR)
	defender.apply_damage(defender.get_health() - trigger_health + 0.5, defender.global_position)
	var second_patch := await _advance_tactic_until(
		func() -> bool:
			return defender.get_role_tactic_snapshot().state_id == &"repairing",
		TACTIC_FRAME_BUDGET, torrent, hold
	)
	var chased_health := defender.get_health()
	var interrupted := await _advance_tactic_until(
		func() -> bool:
			return bool(
				(defender.get_role_tactic_snapshot().withdraw_repair as Dictionary).interrupted
			),
		TACTIC_FRAME_BUDGET,
		torrent,
		defender.global_position + Vector3(0.0, 0.0, 8.0)
	)
	var denied := defender.get_role_tactic_snapshot()
	_check(
		second_patch and interrupted
		and bool((denied.withdraw_repair as Dictionary).interrupted)
		and denied.counter_reason == &"repair_interrupted"
		and is_equal_approx(
			float((denied.withdraw_repair as Dictionary).restored_health), 0.0
		)
		and is_equal_approx(defender.get_health(), chased_health),
		"chasing it down inside the repair window denies the patch entirely"
	)
	defender.deactivate()
	await _advance_tactic_physics(2, torrent, hold)
	await _free_game(game)


# ------------------------------------ multi-stage station defense sortie ----


func _test_station_defense_multi_stage_encounter() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var world := game.get("world") as Node3D
	if not is_instance_valid(world) \
		or not world.has_method(&"get_station_defense_content"):
		_check(false, "the production world stages the station defense encounter")
		await _free_game(game)
		return
	var content := world.call(&"get_station_defense_content") as StationDefenseEncounterContent
	var board := world.call(&"get_station_defense_activity_board") as Area3D
	var authority := game.get_combat_authority()
	var resolver := game.get_combat_resolver()
	var player := game.get("player") as Node3D
	if (
		not is_instance_valid(content) or not is_instance_valid(board)
		or authority == null or resolver == null or not is_instance_valid(player)
	):
		_check(false, "the defense board, its content and the live combat seam are all present")
		await _free_game(game)
		return

	var bindings_ready := await _advance_until(
		func() -> bool:
			return bool(game.get_station_defense_encounter_status().bindings_ready),
		SETTLE_FRAME_BUDGET
	)
	var status := game.get_station_defense_encounter_status()
	_check(
		bindings_ready and bool(status.bindings_ready)
		and bool((status.reward_configuration as Dictionary).get("accepted", false))
		and bool(board.call(&"get_reward_handoff_snapshot").get("configured", false)),
		"the coordinator binds the defense board to its one reward authority at boot"
	)

	var contract := content.get_snapshot().get("contract", {}) as Dictionary
	var waves := contract.get("waves", []) as Array
	_check(
		waves.size() == 3
		and (waves[0].hostile_handles as Array).size() == 1
		and (waves[1].hostile_handles as Array).size() == 2
		and (waves[2].hostile_handles as Array).size() == 1
		and int(waves[0].mode) == StationDefenseContract.WaveMode.ORDERED
		and int(waves[1].mode) == StationDefenseContract.WaveMode.SIMULTANEOUS
		and int(waves[2].mode) == StationDefenseContract.WaveMode.ORDERED
		and float(waves[2].delay_seconds) >= StationDefenseActivity.LULL_MINIMUM_SECONDS,
		"the sortie is three waves of different composition with a berth-length lull before the last"
	)

	var attacker := Node3D.new()
	attacker.name = "DefenseSortieTestGun"
	root.add_child(attacker)
	_check(
		authority.register_source(attacker, DEFENSE_TEST_SOURCE_ID, &"station_allies", {
			DEFENSE_TEST_WEAPON: {
				"range": 600.0,
				"damage": 4000.0,
				"origin_tolerance": 60.0,
			},
		}),
		"a live session source shares the production resolver with the encounter"
	)

	player.global_position = board.global_position + Vector3(0.0, 0.0, 1.2)
	await _advance_physics(2)
	var start_result := game.call(&"_start_physical_station_defense_board") as Dictionary
	await _advance_physics(2)
	var generation := content.get_generation()
	var activity := _defense_activity(content)
	_check(
		bool(start_result.get("accepted", false))
		and activity.state_id == &"active"
		and int(activity.wave_number) == 1
		and int(activity.wave_count) == 3,
		"a player standing at the board starts the multi-stage sortie from the board itself"
	)

	# GameFlow, not the test, is what gives this encounter its time.
	var elapsed_before := float(activity.elapsed_seconds)
	await _advance_physics(8)
	_check(
		float(_defense_activity(content).elapsed_seconds) > elapsed_before,
		"the coordinator's own physics step advances the running sortie"
	)

	var role_tactics := content.get_snapshot().get("wave_role_tactics", {}) as Dictionary
	var alpha_posture := (role_tactics.get("tactics", {}) as Dictionary).get(
		String(StationDefenseEncounterContent.APPROACH_HOSTILE_ID), {}
	) as Dictionary
	_check(
		bool(role_tactics.get("applied", false))
		and alpha_posture.get("tactic_id", &"") == RangeOpponent.ROLE_TACTIC_COVER_PEEK
		and not bool(role_tactics.get("adds_hud_element", true)),
		"wave one's raider works the dockside under the cover posture"
	)

	# ---- wave one cleared, the relief pair brackets the beacon it guards ----
	var alpha := _defense_entity(content, StationDefenseEncounterContent.APPROACH_HOSTILE_ID)
	_check(alpha != null and alpha.is_active(), "wave one puts exactly one raider in the air")
	if alpha != null:
		await _defense_kill(authority, attacker, alpha)
	await _defense_advance(content, 2.6)
	var relief := _defense_activity(content)
	_check(
		relief.state_id == &"active" and int(relief.wave_number) == 2
		and bool(relief.wave_active)
		and (relief.active_hostile_handles as Array).size() == 2,
		"clearing wave one brings the two-craft relief wave in together"
	)

	# --------- save and whole-Main re-entry with the sortie still running ----
	var session_snapshot := board.call(
		&"get_session_persistence_snapshot"
	) as Dictionary
	_check(
		not bool(session_snapshot.get("active_runtime_state_persisted", true))
		and not bool(session_snapshot.get("combat_sources_persisted", true))
		and not bool(session_snapshot.get("asset_damage_persisted", true))
		and not bool(session_snapshot.get("reward_replayable", true)),
		"a save taken mid-sortie writes no live roster, damage or replayable reward"
	)
	authority.forget_source(attacker)
	await _advance_physics(1)
	var sources_before := resolver.get_registered_source_count()
	var kills_before := int(relief.current_wave_destroyed_count)
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var reentered := _defense_activity(content)
	_check(
		reentered.state_id == &"active"
		and int(reentered.generation) == generation
		and int(reentered.wave_number) == 2
		and int(reentered.current_wave_destroyed_count) == kills_before
		and resolver.get_registered_source_count() == sources_before
		and int(board.call(&"get_reward_handoff_snapshot").highest_reward_generation) == 0
		and not bool(
			(board.call(&"get_session_persistence_snapshot").get("reward_replayable", true))
		),
		"a save taken mid-sortie survives a whole-Main re-entry without replaying a reward"
	)
	authority.register_source(attacker, DEFENSE_TEST_SOURCE_ID, &"station_allies", {
		DEFENSE_TEST_WEAPON: {
			"range": 600.0,
			"damage": 4000.0,
			"origin_tolerance": 60.0,
		},
	})
	await _advance_physics(1)

	for hostile_id in [
		StationDefenseEncounterContent.PINCER_CLOSE_HOSTILE_ID,
		StationDefenseEncounterContent.PINCER_OUTER_HOSTILE_ID,
	]:
		var raider := _defense_entity(content, hostile_id)
		if raider != null and raider.is_active():
			await _defense_kill(authority, attacker, raider)
		await _defense_advance(content, 0.1)

	# ------------------------------------------------ the berth-run lull ----
	var lull := _defense_activity(content)
	await _defense_advance(content, 2.0)
	var mid_lull := _defense_activity(content)
	var board_text := str(board.call(&"get_presentation_snapshot").text)
	_check(
		bool(lull.in_lull) and bool(lull.lull_is_berth_window)
		and float(lull.wave_delay_seconds) >= StationDefenseActivity.LULL_MINIMUM_SECONDS
		and float(mid_lull.wave_delay_remaining_seconds) < float(
			lull.wave_delay_remaining_seconds
		)
		and (mid_lull.active_hostile_handles as Array).is_empty()
		and board_text.contains("BERTH RUN OPEN"),
		"the lull is quiet, counts down on the board, and says the berth run is open"
	)
	# The budget is authored to survive its own lulls, so spending the window
	# on a repair run still leaves a fight to come back to.
	_check(
		float(mid_lull.timeout_remaining_seconds)
			> StationDefenseEncounterDefinition.MINIMUM_FIGHTING_SECONDS * 0.5
		and float(mid_lull.timeout_seconds) >= float(mid_lull.wave_delay_seconds)
			+ StationDefenseEncounterDefinition.MINIMUM_FIGHTING_SECONDS,
		"taking the whole berth window still leaves the player a fight to return to"
	)

	# ------------------------------- a failure the player can come back from ----
	var lost := content.fail(&"perimeter_overrun", content.get_generation())
	await _advance_physics(2)
	var failed := _defense_activity(content)
	_check(
		bool(lost.get("accepted", false)) and failed.state_id == &"failed"
		and bool(failed.recovery_available)
		and int(failed.recovery_count) == 0
		and str(board.call(&"get_presentation_snapshot").text).contains("RESUME AT WAVE"),
		"losing the sortie leaves a recoverable failure rather than a dead end"
	)
	player.global_position = board.global_position + Vector3(0.0, 0.0, 1.2)
	await _advance_physics(1)
	var recovered := board.call(
		&"recover", player, content.get_generation()
	) as Dictionary
	await _advance_physics(2)
	var resumed := _defense_activity(content)
	_check(
		bool(recovered.get("accepted", false))
		and resumed.state_id == &"active"
		and int(resumed.generation) == int(failed.generation) + 1
		and int(resumed.wave_number) == 3
		and int(resumed.remaining_hostile_count) == 1
		and int(resumed.recovery_count) == 1
		and not bool(resumed.recovery_available),
		"the recovery resumes the same fight at wave three with the earlier kills kept"
	)

	# ----------------------------------------------- wave three and reward ----
	await _defense_advance(content, 8.5)
	var final_wave := _defense_activity(content)
	var picket := _defense_entity(
		content, StationDefenseEncounterContent.HEAVY_PICKET_HOSTILE_ID
	)
	_check(
		int(final_wave.wave_number) == 3 and bool(final_wave.wave_active)
		and picket != null and picket.is_active(),
		"the lull ends and the heavy picket arrives as the third and last composition"
	)
	if picket != null:
		await _defense_kill(authority, attacker, picket)
	await _advance_physics(2)
	var cleared := _defense_activity(content)
	var reward := board.call(&"get_reward_handoff_snapshot") as Dictionary
	_check(
		cleared.state_id == &"completed"
		and bool((reward.last_result as Dictionary).get("accepted", false))
		and int(reward.highest_reward_generation) == int(cleared.generation),
		"clearing every wave grants the sortie reward through the coordinator's reward authority"
			+ " (%s g%d r%d %s)" % [
				cleared.state_id,
				int(cleared.generation),
				int(reward.highest_reward_generation),
				str(game.get("_last_game_flow_reward_result")),
			]
	)
	board.call(&"_on_content_snapshot_changed", content.get_snapshot())
	var replayed := board.call(&"get_reward_handoff_snapshot") as Dictionary
	var direct_replay := game.call(&"_commit_game_flow_activity_reward", {
		"activity_id": StationDefenseActivityBoard.ACTIVITY_ID,
		"activity_generation": int(cleared.generation),
		"reward_id": &"return_defense_report_to_shipyard",
		"reward_authority": false,
		"granted": false,
	}) as Dictionary
	_check(
		int(replayed.highest_reward_generation) == int(cleared.generation)
		and not bool(direct_replay.get("accepted", true))
		and StringName(direct_replay.get("reason", &"")) \
			== &"reward_generation_already_committed",
		"neither a replayed completion snapshot nor a direct re-commit grants the reward twice"
			+ " (%s)" % [str(direct_replay.get("reason", &""))]
	)

	# ------------------------------------------------------ abandonment ----
	player.global_position = board.global_position + Vector3(0.0, 0.0, 1.2)
	await _advance_physics(1)
	var reset_after_clear := board.call(
		&"abort_and_reset", player, content.get_generation()
	) as Dictionary
	await _advance_physics(2)
	var restart := game.call(&"_start_physical_station_defense_board") as Dictionary
	await _defense_advance(content, 0.2)
	player.global_position = board.global_position + Vector3(0.0, 0.0, 1.2)
	await _advance_physics(1)
	var abandoned := board.call(
		&"abort_and_reset", player, content.get_generation()
	) as Dictionary
	await _advance_physics(2)
	var idle := _defense_activity(content)
	var idle_tactics := (
		content.get_snapshot().get("wave_role_tactics", {}) as Dictionary
	).get("tactics", {}) as Dictionary
	var every_posture_cleared := true
	var any_hostile_live := false
	for hostile_key: String in idle_tactics:
		var posture := idle_tactics[hostile_key] as Dictionary
		every_posture_cleared = (
			every_posture_cleared
			and posture.get("tactic_id", &"") == RangeOpponent.ROLE_TACTIC_NONE
		)
		any_hostile_live = any_hostile_live or bool(posture.get("active", false))
	_check(
		bool(reset_after_clear.get("accepted", false))
		and bool(restart.get("accepted", false))
		and bool(abandoned.get("accepted", false))
		and idle.state_id == &"idle"
		and every_posture_cleared and not any_hostile_live
		and resolver.get_registered_source_count() == sources_before + 1,
		"abandoning the sortie retires every craft, clears every posture and leaves the roster as it was"
	)

	authority.forget_source(attacker)
	root.remove_child(attacker)
	attacker.queue_free()
	await process_frame
	await _free_game(game)


# ------------------------------------------- role-tactic sortie helpers ----

const DEFENSE_TEST_SOURCE_ID := 91101
const DEFENSE_TEST_WEAPON: StringName = &"defense_sortie_test_gun"
const DEFENSE_TEST_FIRING_OFFSETS := [
	Vector3(0.0, 0.0, 22.0),
	Vector3(0.0, 22.0, 0.0),
	Vector3(22.0, 0.0, 0.0),
	Vector3(0.0, 0.0, -22.0),
	Vector3(-22.0, 0.0, 0.0),
	Vector3(0.0, -22.0, 0.0),
	Vector3(16.0, 16.0, 16.0),
	Vector3(-16.0, 16.0, -16.0),
]


func _defense_activity(content: StationDefenseEncounterContent) -> Dictionary:
	return (
		(content.get_snapshot().get("host", {}) as Dictionary).get("activity", {})
		as Dictionary
	)


func _defense_entity(
	content: StationDefenseEncounterContent,
	hostile_id: StringName
	) -> RangeOpponent:
	for child in content.find_children("*", "RangeOpponent", true, false):
		var entity := child as RangeOpponent
		if entity != null and StringName(entity.get_meta("hostile_id", &"")) == hostile_id:
			return entity
	return null


func _defense_advance(content: StationDefenseEncounterContent, seconds: float) -> void:
	content.advance_physics(seconds, content.get_generation())
	await physics_frame
	await process_frame


func _defense_kill(
	authority: LiveCombatAuthority,
	attacker: Node3D,
	target: RangeOpponent
	) -> void:
	for offset: Vector3 in DEFENSE_TEST_FIRING_OFFSETS:
		if not target.is_active():
			return
		await physics_frame
		await process_frame
		var aim_position := target.global_position
		var keel := target.get_node_or_null(^"KeelCollision") as CollisionShape3D
		if keel != null:
			aim_position = keel.global_position
		attacker.global_position = aim_position + offset
		authority.submit_hitscan(
			attacker,
			DEFENSE_TEST_WEAPON,
			attacker.global_position,
			(aim_position - attacker.global_position).normalized()
		)
		await process_frame


func _world_ray_clear(host: Node3D, from_position: Vector3, to_position: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		from_position, to_position, PhysicsLayers.WORLD
	)
	return host.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _add_cover_slab(game: GameFlow, origin: Vector3) -> StaticBody3D:
	var slab := StaticBody3D.new()
	slab.name = "TacticCoverSlab"
	slab.collision_layer = PhysicsLayers.WORLD
	slab.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = COVER_SLAB_SIZE
	shape.shape = box
	slab.add_child(shape)
	game.add_child(slab)
	slab.global_position = origin
	return slab


func _advance_tactic_physics(frames: int, held: Node3D, hold_position: Vector3) -> void:
	for _index in frames:
		if is_instance_valid(held):
			held.global_position = hold_position
			if held is CharacterBody3D:
				(held as CharacterBody3D).velocity = Vector3.ZERO
		await physics_frame
		await process_frame


func _advance_tactic_until(
	condition: Callable,
	frame_budget: int,
	held: Node3D,
	hold_position: Vector3
	) -> bool:
	for _index in frame_budget:
		if bool(condition.call()):
			return true
		if is_instance_valid(held):
			held.global_position = hold_position
			if held is CharacterBody3D:
				(held as CharacterBody3D).velocity = Vector3.ZERO
		await physics_frame
		await process_frame
	return bool(condition.call())

