extends SceneTree

## Production integration for the standoff picket lance through the real
## `res://scenes/main.tscn` encounter path.
##
## The suite drives the coordinator's own interceptor engagement, lets the
## picket dispatch itself as the defender's second wave, fires one real lance
## through the single live `CombatResolver`, and proves the guided Torrent
## activity, the existing defender, and the coordinator's combat-source census
## are all unchanged. Every wait is a bounded frame budget on the fixed physics
## step; nothing here reads a wall clock.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const DISPATCH_FRAME_BUDGET := 420
const SETTLE_FRAME_BUDGET := 240
const PRODUCTION_ESCORT_DELAY := 3.0
const TEST_ESCORT_DELAY := 0.4
const LANCE_TEST_DISTANCE := 110.0

var _failures: Array[String] = []
var _assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	await _test_production_encounter()
	_check(
		root.get_child_count() == original_root_child_count,
		"the production encounter fixture cleans up without leaving scene nodes"
	)
	_finish()


func _test_production_encounter() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the picket encounter")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var defender := game.get_node_or_null("RangeOpponent") as RangeOpponent
	var picket := game.get_node_or_null("StandoffPicket") as StandoffPicketOpponent
	var authority := game.get_combat_authority()
	var resolver := game.get_combat_resolver()
	var pulse := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	_check(
		torrent != null and defender != null and picket != null
		and authority != null and resolver != null and pulse != null,
		"the production scene stages the fleet, the defender, the picket and live combat"
	)
	if picket == null or resolver == null or torrent == null or defender == null:
		await _free_game(game)
		return

	# ---------------------------------------------------- dormant baseline ----
	_check(
		is_equal_approx(picket.escort_launch_delay, PRODUCTION_ESCORT_DELAY)
		and picket.escort_enabled
		and picket.source_id == StandoffPicketOpponent.DEFAULT_SOURCE_ID
		and picket.faction_id == GameFlow.OPPONENT_FACTION,
		"the production picket ships escort-enabled, on the defence faction, with its own stable source ID"
	)
	_check(
		picket.source_id != GameFlow.OPPONENT_SOURCE_ID
		and not GameFlow.PLAYER_SOURCE_IDS.values().has(picket.source_id),
		"the picket source ID collides with no fleet or defender identity"
	)
	_check(
		not picket.is_active() and not picket.visible
		and picket.collision_layer == 0 and picket.collision_mask == 0,
		"the picket is dormant, hidden and non-colliding before the encounter"
	)
	_check(
		resolver.get_registered_source_count() == 6
		and not picket.is_combat_source_registered(),
		"a dormant picket leaves the coordinator's six-source census exactly as it was"
	)
	_check(
		bool(picket.get_audit_report().valid),
		"the production picket audits clean at boot: %s" % [picket.get_validation_errors()]
	)

	# --- boundary: a live defender alone does not authorize a picket dispatch ---
	# The budget is comfortably longer than the production escort launch delay.
	defender.activate(Transform3D(Basis.IDENTITY, Vector3(320.0, 90.0, -400.0)))
	var dispatched_without_encounter := await _advance_until(
		func() -> bool: return picket.is_active(),
		DISPATCH_FRAME_BUDGET
	)
	_check(
		not dispatched_without_encounter and game.phase != GameFlow.Phase.INTERCEPTOR_ENGAGEMENT,
		"the picket refuses to dispatch outside the coordinator's interceptor engagement"
	)
	defender.deactivate()
	await _advance_physics(2)

	# ------------------------------------------- real coordinator encounter ----
	picket.escort_launch_delay = TEST_ESCORT_DELAY
	game.destroyed_targets = game.total_targets
	game.call("_begin_interceptor_engagement")
	await process_frame
	_check(
		game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT and defender.is_active(),
		"the coordinator's own encounter path launches the live defender"
	)
	_check(
		not picket.is_active(),
		"the picket does not launch in the same instant as the defender it escorts"
	)

	var dispatched := await _advance_until(
		func() -> bool: return picket.is_active(),
		DISPATCH_FRAME_BUDGET
	)
	_check(dispatched, "the picket dispatches itself as the defender's second wave")
	_check(
		picket.visible
		and picket.collision_layer != 0
		and is_equal_approx(picket.get_health(), picket.maximum_health),
		"the dispatched picket is visible, collidable and at full hull"
	)
	_check(
		picket.get("_target") == game.get_active_ship(),
		"the picket acquires the coordinator's active craft as its target"
	)
	_check(
		resolver.get_registered_source_count() == 7
		and picket.is_combat_source_registered()
		and authority.get_source_id(picket) == picket.source_id
		and authority.get_source_id(defender) == GameFlow.OPPONENT_SOURCE_ID
		and authority.get_source_id(torrent) == 1101,
		"dispatch adds exactly one authority identity beside the untouched fleet and defender"
	)
	_check(
		picket.get_node_or_null("AuthoritativeDamageable") is LifecycleDamageableAdapter,
		"the picket is damageable through the shared lifecycle adapter, not a private health store"
	)

	# ------------------------------------------------- one real lance shot ----
	# Evidence control: the craft is pinned so the shot under test is the
	# production weapon path rather than a navigation race. Attitude, telegraph,
	# cooldown, resolution and presentation all remain production code.
	picket.acceleration = 0.0
	picket.velocity = Vector3.ZERO
	var lance_origin := torrent.global_position + Vector3(0.0, 26.0, LANCE_TEST_DISTANCE)
	picket.global_transform = Transform3D(
		Basis.looking_at(
			(torrent.global_position - lance_origin).normalized(),
			Vector3.UP
		).orthonormalized(),
		lance_origin
	)
	await _advance_physics(2)

	var hull_before := float(torrent.get_telemetry().get("hull", 0.0))
	var defender_health_before := defender.get_health()
	var player_result_before: Dictionary = game.get_last_player_shot_result()
	var opponent_result_before: Dictionary = game.get_last_opponent_shot_result()
	var pulse_presented_before := int(pulse.get_statistics().presented)
	var lance_sequence_before := resolver.get_last_sequence(picket, picket.source_id)

	picket.set_target(torrent)
	picket._cooldown_remaining = 0.0
	picket._fire_at_target(torrent.global_position)
	var lance_result: Dictionary = picket.get_last_shot_result()
	_check(
		bool(lance_result.get("accepted", false))
		and bool(lance_result.get("resolved", false))
		and StringName(lance_result.get("source_faction_id", &"")) == GameFlow.OPPONENT_FACTION,
		"the lance resolves on the production resolver under the defence faction"
	)
	_check(
		bool(lance_result.get("damaged", false))
		and lance_result.get("target_entity") == torrent
		and is_equal_approx(float(lance_result.get("applied_damage", 0.0)), picket.lance_damage),
		"one lance shot applies exactly one authoritative hull commit to the player craft"
	)
	_check(
		is_equal_approx(float(torrent.get_telemetry().get("hull", 0.0)), hull_before - picket.lance_damage),
		"the player craft loses exactly the lance damage and nothing more"
	)
	_check(
		resolver.get_last_sequence(picket, picket.source_id) == lance_sequence_before + 1,
		"the lance consumes exactly one monotonic sequence on the shared replay ledger"
	)
	_check(
		int(pulse.get_statistics().presented) == pulse_presented_before + 1,
		"the lance consumes exactly one slot of the shared fixed pulse pool"
	)
	var lance_snapshot := _find_snapshot_for_source(pulse, picket.get_instance_id())
	_check(
		not lance_snapshot.is_empty()
		and StringName(lance_snapshot.get("style_id", &"")) == &"magenta",
		"the lance reads on screen in magenta rather than the player's cyan or the defender's amber"
	)
	_check(
		game.get_last_player_shot_result() == player_result_before
		and game.get_last_opponent_shot_result() == opponent_result_before,
		"an opponent lance never rewrites the coordinator's player or defender shot records"
	)
	_check(
		is_equal_approx(defender.get_health(), defender_health_before)
		and defender.is_active()
		and game.phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT,
		"the existing defender encounter is completely unaffected by the picket's fire"
	)
	_check(
		picket.get_pending_lance_receipt_count() == 1
		and torrent.get_pending_damage_presentation_count() >= 1,
		"the damaged player craft holds the deferred presentation until the pulse lands"
	)
	var pending_hero_before := torrent.get_pending_damage_presentation_count()
	pulse.advance_simulation(0.6)
	_check(
		picket.get_pending_lance_receipt_count() == 0
		and torrent.get_pending_damage_presentation_count() == pending_hero_before - 1,
		"the deferred hull presentation is committed exactly once at pulse arrival"
	)

	# ------------------------- the picket is a real target on the player path --
	var picket_health_before := picket.get_health()
	var shot_origin := picket.global_position + Vector3(0.0, 0.0, 40.0)
	torrent.global_position = shot_origin
	await _advance_physics(2)
	var player_shot: Dictionary = authority.submit_hitscan(
		torrent,
		GameFlow.COMBAT_WEAPON_ID,
		torrent.global_position,
		(picket.global_position - torrent.global_position).normalized()
	)
	_check(
		bool(player_shot.get("damaged", false))
		and player_shot.get("target_entity") == picket
		and picket.get_health() < picket_health_before,
		"the player's own registered weapon damages the picket through the unmodified authority path"
	)

	# --------------------------------- whole-Main detach / re-entry safety ----
	picket._cooldown_remaining = 0.0
	picket.set_target(torrent)
	picket._fire_at_target(picket.global_position + Vector3(0.0, 0.0, 200.0))
	var receipts_before_detach := picket.get_pending_lance_receipt_count()
	var registered_before_detach := resolver.get_registered_source_count()
	root.remove_child(game)
	await process_frame
	_check(
		picket.get_pending_lance_receipt_count() == 0,
		"a whole-Main detach strands no lance presentation receipt (%d before detach)"
			% receipts_before_detach
	)
	_check(
		not picket.is_combat_source_registered()
		and resolver.get_registered_source_count() == 0,
		"a detached picket claims no live registration (%d before detach)"
			% registered_before_detach
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		resolver.get_registered_source_count() == 7
		and picket.is_combat_source_registered()
		and authority.get_source_id(picket) == picket.source_id,
		"re-entry restores exactly one picket registration beside the six coordinator sources"
	)
	_check(
		bool(picket.get_audit_report().valid),
		"the picket audits clean after whole-Main re-entry: %s" % [picket.get_validation_errors()]
	)

	# --------------------------------- withdrawal keeps the guide winnable ----
	defender.apply_damage(defender.maximum_health + 1.0, defender.global_position)
	await process_frame
	_check(
		game.phase == GameFlow.Phase.RETURN_TO_YARD,
		"destroying the defender still completes the guided combat beat with the picket in play"
	)
	var withdrawn := await _advance_until(
		func() -> bool: return not picket.is_active(),
		SETTLE_FRAME_BUDGET
	)
	_check(withdrawn, "the picket withdraws with the defender wave it escorts")
	_check(
		not picket.is_combat_source_registered()
		and resolver.get_registered_source_count() == 6
		and picket.get_pending_lance_receipt_count() == 0,
		"withdrawal restores the coordinator's six-source census and strands no receipt"
	)
	_check(
		resolver.get_last_sequence(picket, picket.source_id) >= 0,
		"withdrawal retires the registration without discarding the identity's replay ledger"
	)
	_check(
		bool(picket.get_audit_report().valid),
		"the withdrawn picket audits clean: %s" % [picket.get_validation_errors()]
	)

	await _free_game(game)


# ---------------------------------------------------------------- helpers ----

func _find_snapshot_for_source(pulse: PulseWeaponPresentation, instance_id: int) -> Dictionary:
	for snapshot in pulse.get_active_shot_snapshots():
		if int((snapshot as Dictionary).get("source_instance_id", 0)) == instance_id:
			return snapshot as Dictionary
	return {}


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
	if is_instance_valid(game):
		var audio := game.get_node_or_null("CombatAudioPresentation")
		if is_instance_valid(audio) and audio.get_parent() != null:
			audio.get_parent().remove_child(audio)
			audio.queue_free()
			await process_frame
		if game.get_parent() != null:
			root.remove_child(game)
		game.queue_free()
	for _index in 10:
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("STANDOFF_PICKET_ENCOUNTER_INTEGRATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"STANDOFF_PICKET_ENCOUNTER_INTEGRATION_TEST_FAILED: %d of %d assertions failed: %s"
				% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
