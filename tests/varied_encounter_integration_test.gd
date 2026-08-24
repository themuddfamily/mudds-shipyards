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
	# Re-frozen 5 -> 6 when the Halyard crew transport joined the fleet. The
	# assertion's intent is unchanged: the two NEW OPPONENT archetypes must not
	# alter the pre-encounter census. The Halyard raises the baseline because it
	# is a fifth armed player craft, not because a scenario craft registered early.
	_check(
		baseline_sources == 6,
		"the new craft leave the coordinator's six-source census exactly as it was (%d)"
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
		resolver.get_registered_source_count() >= baseline_sources + 3,
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
		resolver.get_registered_source_count() <= baseline_sources + 1,
		"the withdrawn scenario returns the source census to the fleet, the defender and the picket (%d)"
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
	root.remove_child(game)
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
