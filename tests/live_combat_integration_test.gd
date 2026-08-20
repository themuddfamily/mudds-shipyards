extends SceneTree

const Layers := preload("res://scripts/core/physics_layers.gd")
const ShotRequestScript := preload("res://scripts/combat/shot_request.gd")
const DamageableScript := preload("res://scripts/combat/damageable.gd")

var _failures: Array[String] = []
var _resolved_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene loads for live combat integration")
		_finish()
		return
	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame

	var world := game.get_node("ShipyardWorld") as Node3D
	var hero := game.get_node("TorrentInterceptor") as HeroShip
	var reserve := game.get_node("ArrowReconShip") as HeroShip
	var jovian := game.get_node("JovianLightFreighter") as HeroShip
	var zenith := game.get_node("ZenithInterceptor") as HeroShip
	var halyard := game.get_node("HalyardCrewTransport") as HeroShip
	var opponent := game.get_node("RangeOpponent") as CharacterBody3D
	var hud := game.get_node("HUD") as CanvasLayer
	var authority := game.call("get_combat_authority") as LiveCombatAuthority
	var resolver := game.call("get_combat_resolver") as CombatResolver
	_check(authority != null and resolver != null, "production scene owns one shared live combat authority and resolver")
	if authority == null or resolver == null:
		await _clean_up(game)
		_finish()
		return
	resolver.shot_resolved.connect(_on_shot_resolved)
	# Re-frozen 5 -> 6 when the Halyard crew transport joined the fleet as a
	# fifth player craft. It is armed, so it registers an authority identity
	# like the other four; the census is five player craft plus the defender.
	_check(resolver.get_registered_source_count() == 6, "all five player craft and the defender have registered authority identities")
	_check(authority.get_source_id(hero) == 1101, "Torrent keeps its explicit stable combat identity")
	_check(authority.get_source_id(reserve) == 1102, "Arrow owns an explicit stable combat identity")
	_check(authority.get_source_id(jovian) == 1103, "Jovian owns an explicit stable combat identity")
	_check(authority.get_source_id(zenith) == 1104, "Zenith owns its protected stable combat identity")
	_check(authority.get_source_id(halyard) == 1105, "Halyard owns its explicit stable combat identity")
	_check(authority.get_source_id(opponent) == GameFlow.OPPONENT_SOURCE_ID, "opponent source keeps its explicit stable combat identity")
	_check(authority.get_source_id(hero) != authority.get_source_id(reserve), "physical player craft never share a source ledger")
	_check(
		authority.get_source_id(jovian) != authority.get_source_id(hero)
		and authority.get_source_id(jovian) != authority.get_source_id(reserve),
		"Jovian's combat source ledger is unique within the production fleet"
	)
	var production_source_ids := {
		authority.get_source_id(hero): true,
		authority.get_source_id(reserve): true,
		authority.get_source_id(jovian): true,
		authority.get_source_id(zenith): true,
		authority.get_source_id(halyard): true,
		authority.get_source_id(opponent): true,
	}
	_check(
		production_source_ids.size() == 6,
		"all five player craft and the defender retain six distinct combat source identities"
	)
	var torrent_profile := authority.get_weapon_profile(hero, &"combat_pulse_cannon")
	var arrow_profile := authority.get_weapon_profile(reserve, &"combat_pulse_cannon")
	var jovian_profile := authority.get_weapon_profile(jovian, &"combat_pulse_cannon")
	var zenith_profile := authority.get_weapon_profile(zenith, &"combat_pulse_cannon")
	var halyard_profile := authority.get_weapon_profile(halyard, &"combat_pulse_cannon")
	_check(
		is_equal_approx(float(torrent_profile.get("range", 0.0)), 360.0)
		and is_equal_approx(float(torrent_profile.get("damage", 0.0)), 34.0),
		"Torrent retains its production combat profile"
	)
	_check(
		is_equal_approx(float(arrow_profile.get("range", 0.0)), 410.0)
		and is_equal_approx(float(arrow_profile.get("damage", 0.0)), 25.0),
		"Arrow retains its lighter long-range combat profile"
	)
	_check(
		is_equal_approx(float(jovian_profile.get("range", 0.0)), 315.0)
		and is_equal_approx(float(jovian_profile.get("damage", 0.0)), 23.0),
		"Jovian receives its distinct defensive production combat profile"
	)
	_check(
		zenith_profile.size() == 3
		and is_equal_approx(float(zenith_profile.get("range", 0.0)), 390.0)
		and is_equal_approx(float(zenith_profile.get("damage", 0.0)), 27.0)
		and is_equal_approx(float(zenith_profile.get("origin_tolerance", 0.0)), 24.0),
		"Zenith retains its exact protected production combat profile"
	)
	_check(
		halyard_profile.size() == 3
		and is_equal_approx(float(halyard_profile.get("range", 0.0)), 280.0)
		and is_equal_approx(float(halyard_profile.get("damage", 0.0)), 18.0)
		and is_equal_approx(float(halyard_profile.get("origin_tolerance", 0.0)), 30.0),
		"Halyard retains its exact self-defence production combat profile"
	)
	_check(
		hero.get_node_or_null("AuthoritativeDamageable") is DamageableScript
		and reserve.get_node_or_null("AuthoritativeDamageable") is DamageableScript
		and jovian.get_node_or_null("AuthoritativeDamageable") is DamageableScript
		and zenith.get_node_or_null("AuthoritativeDamageable") is DamageableScript
		and halyard.get_node_or_null("AuthoritativeDamageable") is DamageableScript
		and opponent.get_node_or_null("AuthoritativeDamageable") is DamageableScript,
		"production craft expose typed Damageable lifecycle proxies"
	)
	var targets := _get_live_range_targets(world)
	_check(targets.size() == int(world.call("get_target_count")), "every generated range drone is adapted into generic combat")
	for target in targets:
		_check(target.get_node_or_null("AuthoritativeDamageable") is DamageableScript, "%s has a typed Damageable adapter" % target.name)

	# Player production fire: the callback must submit through the resolver and
	# forward authoritative damage into the opponent's existing staged lifecycle.
	var arena_origin := Vector3(180.0, 54.0, -230.0)
	hero.global_transform = Transform3D(Basis.IDENTITY, arena_origin)
	reserve.global_position = arena_origin + Vector3(70.0, 0.0, 0.0)
	opponent.call("activate", Transform3D(Basis.IDENTITY, arena_origin + Vector3(0.0, 0.0, -32.0)))
	opponent.set_physics_process(false)
	game.active_ship = hero
	game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	await physics_frame
	var player_origin := hero.global_position + Vector3(0.0, 0.8, -5.5)
	var player_direction := (opponent.global_position - player_origin).normalized()
	var enemy_health_before := float(opponent.call("get_health"))
	game.call("_on_projectile_fired", player_origin, player_direction, hero)
	var player_result: Dictionary = game.call("get_last_player_shot_result")
	_check(bool(player_result.get("accepted", false)), "player production shot is accepted by the shared resolver")
	_check(bool(player_result.get("damaged", false)), "player production shot resolves generic authoritative damage")
	_check(player_result.get("target_entity") == opponent, "player resolver result identifies the live opponent lifecycle")
	_check(
		is_equal_approx(float(opponent.call("get_health")), enemy_health_before - 34.0),
		"opponent's existing health remains the only state reduced by the proxy"
	)
	var pulse_presentation := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	_check(
		pulse_presentation != null and pulse_presentation.get_active_effect_count() > 0,
		"authoritative player fire preserves its pooled pulse presentation"
	)
	var first_player_sequence := int(player_result.get("last_sequence", -1))
	game.call("_on_projectile_fired", player_origin, player_direction, hero)
	var second_player_result: Dictionary = game.call("get_last_player_shot_result")
	_check(
		int(second_player_result.get("last_sequence", -1)) == first_player_sequence + 1,
		"successive production shots use a monotonic per-source sequence"
	)

	# A real world-layer blocker must win the ray and protect a damageable behind it.
	var blocker := _make_world_blocker(
		player_origin.lerp(opponent.global_position, 0.45),
		Vector3(9.0, 9.0, 2.0)
	)
	game.add_child(blocker)
	await physics_frame
	var health_before_blocked_shot := float(opponent.call("get_health"))
	game.call("_on_projectile_fired", player_origin, player_direction, hero)
	var blocked_result: Dictionary = game.call("get_last_player_shot_result")
	_check(blocked_result.get("status") == &"world_blocked", "station/world geometry authoritatively occludes live fire")
	_check(
		is_equal_approx(float(opponent.call("get_health")), health_before_blocked_shot),
		"world-occluded production fire cannot damage the craft behind it"
	)
	blocker.queue_free()
	await physics_frame

	# Enemy production fire traverses the same resolver, reaches the hero's
	# lifecycle, and retains directional HUD/impact presentation.
	hero.global_position = arena_origin
	opponent.global_position = arena_origin + Vector3(0.0, 0.0, 34.0)
	await physics_frame
	var enemy_origin := opponent.global_position + Vector3(0.0, 0.5, -4.0)
	var enemy_direction := (hero.global_position - enemy_origin).normalized()
	var hero_hull_before := float(hero.get_telemetry().get("hull", 0.0))
	game.call("_on_opponent_projectile_fired", enemy_origin, enemy_direction)
	var enemy_result: Dictionary = game.call("get_last_opponent_shot_result")
	_check(bool(enemy_result.get("accepted", false)) and bool(enemy_result.get("damaged", false)), "opponent production shot uses the shared authority")
	_check(enemy_result.get("target_entity") == hero, "enemy resolver result identifies the active hero lifecycle")
	_check(
		is_equal_approx(float(hero.get_telemetry().get("hull", 0.0)), hero_hull_before - 11.0),
		"hero's existing hull lifecycle receives authoritative enemy damage"
	)
	var damage_direction := hud.get("_damage_direction") as Control
	_check(damage_direction != null and damage_direction.visible, "resolved enemy damage retains directional HUD feedback")
	_check(
		hero.get_damage_presentation().get_live_world_effect_count() == 0
		and hero.get_damage_presentation().get_pending_damage_presentation_count() == 1,
		"enemy health authority resolves before the travelling pulse presents its impact"
	)
	pulse_presentation.advance_simulation(0.29)
	_check(
		hero.get_damage_presentation().get_live_world_effect_count() > 0,
		"pulse arrival releases the resolved hero impact presentation"
	)

	# Range targets use the same request/resolver path, then forward lethal damage
	# to ShipyardWorld so mission counting, burst presentation, and cleanup remain.
	opponent.call("deactivate")
	var range_target := targets[0] as StaticBody3D
	hero.global_position = Vector3(230.0, 48.0, -250.0)
	range_target.global_position = hero.global_position + Vector3(0.0, 0.0, -28.0)
	range_target.set_meta("base_position", (range_target.get_parent() as Node3D).to_local(range_target.global_position))
	game.phase = GameFlow.Phase.TARGET_PRACTICE
	await physics_frame
	var range_origin := hero.global_position + Vector3(0.0, 0.0, -5.5)
	for _shot in 2:
		var range_direction := (range_target.global_position - range_origin).normalized()
		game.call("_on_projectile_fired", range_origin, range_direction, hero)
		if _shot == 1:
			_check(
				bool(range_target.get_meta("destroyed", false))
				and game.destroyed_targets == 1
				and range_target.collision_layer == 0
				and world.find_children("TargetBurst", "Node3D", true, false).is_empty(),
				"lethal target collision and mission authority resolve before pulse-arrival art"
			)
		pulse_presentation.advance_simulation(0.2)
		await physics_frame
	_check(bool(range_target.get_meta("destroyed", false)), "authoritative range fire reaches the established target destruction lifecycle")
	_check(game.destroyed_targets == 1, "range target destruction still advances mission state exactly once")
	_check(
		game.call("get_last_player_shot_result").get("target_entity") == range_target,
		"range target resolver result remains generic rather than world-script special-casing"
	)

	# A friendly craft physically blocks the beam but cannot take damage. Reusing
	# that accepted sequence is rejected, and identity/faction spoofing fails
	# before it can consume or apply an authoritative shot.
	hero.global_position = Vector3(280.0, 64.0, -270.0)
	reserve.global_position = hero.global_position + Vector3(0.0, 0.0, -24.0)
	await physics_frame
	var hero_collision := hero.get_node_or_null("HullCollision") as CollisionShape3D
	var arrow_collision := reserve.get_node_or_null("ArrowHullCollision") as CollisionShape3D
	_check(hero_collision != null and arrow_collision != null, "both distinct craft expose their named primary hull collisions")
	if hero_collision == null or arrow_collision == null:
		await _clean_up(game)
		_finish()
		return
	var friendly_origin := hero_collision.global_position
	var friendly_direction := (
		arrow_collision.global_position - friendly_origin
	).normalized()
	var hero_source_id := authority.get_source_id(hero)
	var hero_faction := authority.get_source_faction(hero)
	var combat_profile := authority.get_weapon_profile(hero, &"combat_pulse_cannon")
	var direct_sequence := resolver.get_last_sequence(hero, hero_source_id) + 1
	var friendly_request := ShotRequestScript.new(
		hero,
		hero_source_id,
		hero_faction,
		&"combat_pulse_cannon",
		direct_sequence,
		friendly_origin,
		friendly_direction,
		float(combat_profile.get("range", 0.0)),
		float(combat_profile.get("damage", 0.0))
	)
	var reserve_hull_before := float(reserve.get_telemetry().get("hull", 0.0))
	var friendly_result := resolver.resolve_hitscan(friendly_request)
	_check(friendly_result.get("status") == &"friendly_fire_blocked", "friendly physical hits are blocked by authority faction rules")
	_check(friendly_result.get("collider") == reserve and friendly_result.get("collider") != hero, "source collision is excluded while the friendly hull still blocks the beam")
	_check(is_equal_approx(float(reserve.get_telemetry().get("hull", 0.0)), reserve_hull_before), "friendly-fire rejection preserves the target lifecycle")
	var replay_result := resolver.resolve_hitscan(friendly_request)
	_check(replay_result.get("status") == &"duplicate_sequence" and not bool(replay_result.get("accepted", true)), "replayed live source sequence is rejected")
	var identity_spoof := ShotRequestScript.new(
		reserve,
		hero_source_id,
		hero_faction,
		&"combat_pulse_cannon",
		direct_sequence + 1,
		reserve.global_position,
		Vector3.FORWARD,
		float(combat_profile.get("range", 0.0)),
		float(combat_profile.get("damage", 0.0))
	)
	var spoof_result := resolver.resolve_hitscan(identity_spoof)
	_check(spoof_result.get("status") == &"source_mismatch" and not bool(spoof_result.get("accepted", true)), "self/source identity spoof is rejected")
	var faction_spoof := ShotRequestScript.new(
		hero,
		hero_source_id,
		&"range_defence",
		&"combat_pulse_cannon",
		direct_sequence + 1,
		hero.global_position,
		Vector3.FORWARD,
		float(combat_profile.get("range", 0.0)),
		float(combat_profile.get("damage", 0.0))
	)
	var faction_result := resolver.resolve_hitscan(faction_spoof)
	_check(faction_result.get("status") == &"source_mismatch" and not bool(faction_result.get("accepted", true)), "source faction spoof is rejected")
	_check(_production_sequences_are_monotonic(hero_source_id), "captured production resolver events preserve source sequence order")

	# The integrated authored-audio + pulse-receipt contract must keep destruction
	# silent at authority time, then start exactly one positional explosion when
	# the lethal pulse reaches the captured opponent pose.
	var combat_audio := game.get_combat_audio_presentation()
	_check(combat_audio != null, "integrated lethal chronology resolves the authored positional combat bank")
	if combat_audio != null:
		pulse_presentation.clear_effects()
		pulse_presentation.set_auto_advance_enabled(false)
		hero.global_position = Vector3(420.0, 86.0, -460.0)
		reserve.global_position = hero.global_position + Vector3(90.0, 0.0, 0.0)
		jovian.global_position = hero.global_position + Vector3(-90.0, 0.0, 0.0)
		var far_target_position := hero.global_position + Vector3(0.0, 0.0, -60.0)
		var lethal_target_position := hero.global_position + Vector3(0.0, 0.0, -12.0)
		opponent.call("activate", Transform3D(Basis.IDENTITY, far_target_position))
		opponent.set_physics_process(false)
		game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
		await physics_frame
		var immediate_audio_count := int(combat_audio.get_state_snapshot().get("cue_count", 0))
		var direct_origin := hero.global_position + Vector3(0.0, 0.8, -5.5)
		var direct_result := authority.submit_hitscan(
			hero,
			GameFlow.COMBAT_WEAPON_ID,
			direct_origin,
			(opponent.global_position - direct_origin).normalized()
		)
		_check(
			bool(direct_result.get("damaged", false))
			and pulse_presentation.get_active_effect_count() == 0
			and int(combat_audio.get_state_snapshot().get("cue_count", 0)) == immediate_audio_count,
			"explicit non-deferred damage stays authority/component-only without late travelling audio"
		)
		# Reset the target, then leave two long-flight nonterminal receipts behind a
		# shorter lethal shot. The terminal record reaches first and clears the
		# target queue; later callbacks must still retire GameFlow metadata.
		opponent.call("activate", Transform3D(Basis.IDENTITY, far_target_position))
		var explosion_count_before := _combat_cue_count(
			combat_audio,
			CombatAudioPresentation.CUE_EXPLOSION
		)
		for _shot in 2:
			var lethal_origin := hero.global_position + Vector3(0.0, 0.8, -5.5)
			var lethal_direction := (opponent.global_position - lethal_origin).normalized()
			game.call("_on_projectile_fired", lethal_origin, lethal_direction, hero)
		opponent.global_position = lethal_target_position
		await physics_frame
		var lethal_origin := hero.global_position + Vector3(0.0, 0.8, -5.5)
		game.call(
			"_on_projectile_fired",
			lethal_origin,
			(opponent.global_position - lethal_origin).normalized(),
			hero
		)
		_check(
			not opponent.call("is_active")
			and int(opponent.call("get_pending_damage_presentation_count")) > 0
			and opponent.call("get_destruction_effect_root") == null
			and _combat_cue_count(combat_audio, CombatAudioPresentation.CUE_EXPLOSION)
				== explosion_count_before,
			"lethal authority disables the opponent without early explosion art or authored audio"
		)
		pulse_presentation.advance_simulation(0.07)
		var explosion_state := combat_audio.get_state_snapshot()
		_check(
			_combat_cue_count(combat_audio, CombatAudioPresentation.CUE_EXPLOSION)
				== explosion_count_before + 1
			and explosion_state.get("last_world_position") == lethal_target_position
			and opponent.call("get_destruction_effect_root") != null
			and int(opponent.call("get_pending_damage_presentation_count")) == 0,
			"lethal pulse arrival starts one authored explosion and matching art at the captured pose"
		)
		_check(
			game.get_pending_combat_presentation_receipt_count() == 2,
			"older long-flight receipt metadata remains bounded until its own terminal callbacks"
		)
		pulse_presentation.advance_simulation(0.3)
		_check(
			game.get_pending_combat_presentation_receipt_count() == 0,
			"out-of-order no-op target callbacks still retire all coordinator receipt metadata"
		)
		# Retire the detached world-space presentation before freeing Main so the
		# test also proves the production reset path releases its GPU resources.
		opponent.call("deactivate")
		pulse_presentation.clear_effects()
		await process_frame

		# Whole-Main streaming intentionally discards transient shots. Health and
		# destruction authority remain final, but neither effect nor audio is
		# resurrected after the same Main instance re-enters the tree.
		opponent.call("activate", Transform3D(Basis.IDENTITY, far_target_position))
		for _shot in 3:
			var stream_origin := hero.global_position + Vector3(0.0, 0.8, -5.5)
			game.call(
				"_on_projectile_fired",
				stream_origin,
				(opponent.global_position - stream_origin).normalized(),
				hero
			)
		var streamed_explosion_count := _combat_cue_count(
			combat_audio,
			CombatAudioPresentation.CUE_EXPLOSION
		)
		_check(
			game.get_pending_combat_presentation_receipt_count() == 3
			and not opponent.call("is_active"),
			"streaming fixture starts with terminal authority and three in-flight receipts"
		)
		root.remove_child(game)
		await process_frame
		_check(
			game.get_pending_combat_presentation_receipt_count() == 0,
			"whole-Main exit atomically discards transient receipt metadata"
		)
		root.add_child(game)
		await process_frame
		await physics_frame
		_check(
			pulse_presentation.get_active_effect_count() == 0
			and opponent.call("get_destruction_effect_root") == null
			and _combat_cue_count(combat_audio, CombatAudioPresentation.CUE_EXPLOSION)
				== streamed_explosion_count,
			"whole-Main re-entry does not resurrect discarded transient art or audio"
		)

	var queued_health: float = opponent.get_health()
	var queued_sequence := authority.get_last_submitted_sequence(hero)
	var queued_events := _resolved_events.size()
	var queued_roster := resolver.get_registered_source_count()
	authority.queue_free()
	var queued_registration := authority.register_source(hero, 9911, &"test", {})
	var queued_shot := authority.submit_hitscan(hero, GameFlow.COMBAT_WEAPON_ID, hero.global_position, Vector3.FORWARD)
	_check(
		not queued_registration and not bool(queued_shot.get("accepted", true))
		and StringName(queued_shot.get("reason", &"")) == &"authority_unavailable"
		and is_equal_approx(opponent.get_health(), queued_health)
		and authority.get_last_submitted_sequence(hero) == queued_sequence
		and _resolved_events.size() == queued_events
		and resolver.get_registered_source_count() == queued_roster,
		"a queued live combat authority rejects direct registration and damage ingress atomically"
	)

	await _clean_up(game)
	_finish()


func _get_live_range_targets(world: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			result.append(candidate as StaticBody3D)
	return result


func _make_world_blocker(world_position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CombatOcclusionFixture"
	body.position = world_position
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _production_sequences_are_monotonic(source_id: int) -> bool:
	var previous := -1
	var observed := 0
	for event in _resolved_events:
		var request := event.get("request") as ShotRequest
		var result: Dictionary = event.get("result", {})
		if request == null or request.source_id != source_id or not bool(result.get("accepted", false)):
			continue
		if request.sequence <= previous:
			return false
		previous = request.sequence
		observed += 1
	return observed >= 5


func _combat_cue_count(presentation: CombatAudioPresentation, cue_id: StringName) -> int:
	var snapshot := presentation.get_state_snapshot()
	var counts := snapshot.get("cue_counts", {}) as Dictionary
	return int(counts.get(cue_id, 0))


func _on_shot_resolved(request: ShotRequest, result: Dictionary) -> void:
	_resolved_events.append({"request": request, "result": result.duplicate(true)})


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
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
		print("LIVE_COMBAT_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print("LIVE_COMBAT_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
