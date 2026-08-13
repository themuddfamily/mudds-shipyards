extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with authored combat audio")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var presentation := game.get_combat_audio_presentation()
	var authority := game.get_combat_authority()
	var hero := game.get_guided_ship()
	var opponent := game.get_node_or_null("RangeOpponent") as Node3D
	_check(
		presentation != null and authority != null and hero != null and opponent != null,
		"production combat fixture exposes presentation, authority, hero, and defender"
	)
	if presentation == null or authority == null or hero == null or opponent == null:
		await _clean_up(game)
		_finish()
		return

	var audit := presentation.get_audit_report()
	_check(bool(audit.get("valid", false)), "authored positional combat-audio audit is green")
	_check(
		int(audit.get("stream_count", 0)) == 7
		and int(audit.get("voice_count", 0)) == 10
		and int(audit.get("maximum_simultaneous_voices", 0)) == 10,
		"production scene owns seven authored cues across ten fixed positional voices"
	)
	_check(
		bool(audit.get("presentation_only", false))
		and not bool(audit.get("gameplay_authority", true))
		and presentation.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"combat audio has no collision or gameplay authority"
	)
	var fire_voice := presentation.get_node_or_null("FireVoice0") as AudioStreamPlayer3D
	_check(fire_voice != null, "adversarial audit fixture resolves a production voice")
	if fire_voice != null:
		var original_bus := fire_voice.bus
		fire_voice.bus = &"Master"
		_check(
			not bool(presentation.get_audit_report().get("valid", true)),
			"spatial bus drift makes the runtime combat-audio audit fail closed"
		)
		fire_voice.bus = original_bus
		var injection := GDScript.new()
		injection.source_code = "extends AudioStreamPlayer3D\nfunc _process(_delta):\n\tpass\n"
		_check(injection.reload() == OK, "adversarial voice script compiles")
		fire_voice.set_script(injection)
		_check(
			not bool(presentation.get_audit_report().get("valid", true)),
			"an injected processing script on a trusted voice fails closed"
		)
		fire_voice.set_script(null)
	var rogue_camera := Camera3D.new()
	rogue_camera.name = "InjectedAuthorityCamera"
	presentation.add_child(rogue_camera)
	_check(
		not bool(presentation.get_audit_report().get("valid", true)),
		"an injected descendant makes the exact presentation roster fail closed"
	)
	rogue_camera.free()
	_check(bool(presentation.get_audit_report().get("valid", false)), "restored exact runtime roster audits green")
	var streams := presentation.get("_streams") as Dictionary
	var player_stream := streams.get(CombatAudioPresentation.CUE_PLAYER_FIRE) as AudioStreamWAV
	_check(player_stream != null, "adversarial resource fixture resolves the authored player-fire PCM")
	if player_stream != null:
		var original_data := player_stream.data.duplicate()
		var corrupted_data := original_data.duplicate()
		corrupted_data[mini(128, corrupted_data.size() - 1)] ^= 0x01
		player_stream.data = corrupted_data
		_check(
			not bool(presentation.get_audit_report().get("valid", true))
			and not presentation.play_player_fire(Vector3.ZERO, hero.get_instance_id()),
			"mutated live PCM content fails audit and cannot be played"
		)
		player_stream.data = original_data
	_check(bool(presentation.get_audit_report().get("valid", false)), "restored frozen PCM content audits green")

	# Local safing is deliberately not submitted. It gets a restrained click and
	# can never masquerade as an accepted pulse shot.
	game.active_ship = hero
	game.phase = GameFlow.Phase.INTRO
	game.set("_guided_activity_complete", false)
	var origin := hero.global_position + Vector3(0.0, 0.5, -4.0)
	var before := presentation.get_state_snapshot()
	var sequence_before := authority.get_last_submitted_sequence(hero)
	game.call("_on_projectile_fired", origin, Vector3.FORWARD, hero)
	var after_safed := presentation.get_state_snapshot()
	_check(
		_cue_count(after_safed, CombatAudioPresentation.CUE_DRY_FIRE)
		== _cue_count(before, CombatAudioPresentation.CUE_DRY_FIRE) + 1
		and _cue_count(after_safed, CombatAudioPresentation.CUE_PLAYER_FIRE)
		== _cue_count(before, CombatAudioPresentation.CUE_PLAYER_FIRE)
		and authority.get_last_submitted_sequence(hero) == sequence_before,
		"safed trigger produces one dry click, zero fire cues, and no authority sequence"
	)

	# A real accepted miss still fired a weapon and therefore owns exactly one cue.
	hero.global_position = Vector3(480.0, 220.0, -520.0)
	game.phase = GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	var accepted_origin := hero.global_position + Vector3.UP
	var before_accepted := presentation.get_state_snapshot()
	game.call("_on_projectile_fired", accepted_origin, Vector3.UP, hero)
	var accepted_result := game.get_last_player_shot_result()
	var after_accepted := presentation.get_state_snapshot()
	_check(
		bool(accepted_result.get("accepted", false))
		and bool(accepted_result.get("resolved", false))
		and _cue_count(after_accepted, CombatAudioPresentation.CUE_PLAYER_FIRE)
		== _cue_count(before_accepted, CombatAudioPresentation.CUE_PLAYER_FIRE) + 1
		and after_accepted.get("last_world_position") == accepted_origin,
		"accepted player miss starts exactly one authored fire cue at the request origin"
	)

	# A rejected callback is presentation-inert even if it contains a plausible
	# request. This protects replay/invalid/not-authority paths from fake gunfire.
	var rejected_request := ShotRequestType.new(
		hero, 1101, &"shipyard_flight_test", &"combat_pulse_cannon", 999,
		accepted_origin, Vector3.UP, 360.0, 34.0
	)
	var before_rejected := presentation.get_state_snapshot()
	game.call("_on_authoritative_shot_submitted", rejected_request, {
		"accepted": false, "resolved": false, "status": &"duplicate_sequence",
	})
	_check(
		int(presentation.get_state_snapshot().get("cue_count", -1))
		== int(before_rejected.get("cue_count", -2)),
		"rejected authoritative replay cannot start any combat cue"
	)

	# Defender requests share authority but use a distinct authored signature.
	var defender_origin := opponent.global_position + Vector3.UP
	var before_defender := presentation.get_state_snapshot()
	var defender_result := authority.submit_hitscan(
		opponent, GameFlow.OPPONENT_WEAPON_ID, defender_origin, Vector3.UP
	)
	var after_defender := presentation.get_state_snapshot()
	_check(
		bool(defender_result.get("accepted", false))
		and _cue_count(after_defender, CombatAudioPresentation.CUE_DEFENDER_FIRE)
		== _cue_count(before_defender, CombatAudioPresentation.CUE_DEFENDER_FIRE) + 1
		and after_defender.get("last_world_position") == defender_origin,
		"accepted defender request starts exactly one distinct positional fire cue"
	)

	# Impact timing is owned by the pulse endpoint, and explosion has an independent
	# pool so the two event families never steal each other's voice.
	var impact_position := Vector3(31.0, 12.0, -88.0)
	var before_impact := presentation.get_state_snapshot()
	game.call("_on_pulse_impact_started", 17, &"cyan", hero.get_instance_id(), impact_position)
	var after_impact := presentation.get_state_snapshot()
	_check(
		_cue_count(after_impact, CombatAudioPresentation.CUE_IMPACT_MEDIUM)
		== _cue_count(before_impact, CombatAudioPresentation.CUE_IMPACT_MEDIUM) + 1
		and after_impact.get("last_world_position") == impact_position,
		"pulse endpoint starts one medium impact at the exact immutable world position"
	)
	var explosion_position := Vector3(-18.0, 8.0, -140.0)
	var impact_count_before_explosion := _impact_count(after_impact)
	var explosion_before := _cue_count(after_impact, CombatAudioPresentation.CUE_EXPLOSION)
	presentation.play_explosion(explosion_position, opponent.get_instance_id())
	var after_explosion := presentation.get_state_snapshot()
	_check(
		_cue_count(after_explosion, CombatAudioPresentation.CUE_EXPLOSION) == explosion_before + 1
		and _impact_count(after_explosion) == impact_count_before_explosion
		and after_explosion.get("last_world_position") == explosion_position,
		"explosion uses its own pool and cannot erase the accepted impact count"
	)

	# Temporary streaming stops playback but retains the exact authored node and
	# resource contract without replaying a cue on re-entry.
	var parent := presentation.get_parent()
	var presentation_id := presentation.get_instance_id()
	var cue_total_before_reentry := int(after_explosion.get("cue_count", -1))
	parent.remove_child(presentation)
	await process_frame
	parent.add_child(presentation)
	await process_frame
	await process_frame
	_check(
		presentation.get_instance_id() == presentation_id
		and bool(presentation.get_audit_report().get("valid", false))
		and int(presentation.get_state_snapshot().get("cue_count", -2)) == cue_total_before_reentry
		and (presentation.get_state_snapshot().get("active_voice_names") as PackedStringArray).is_empty(),
		"detach/re-entry preserves identity and counters while stopping every transient"
	)

	await _clean_up(game)
	_finish()


func _cue_count(snapshot: Dictionary, cue_id: StringName) -> int:
	var counts := snapshot.get("cue_counts", {}) as Dictionary
	return int(counts.get(cue_id, 0))


func _impact_count(snapshot: Dictionary) -> int:
	return (
		_cue_count(snapshot, CombatAudioPresentation.CUE_IMPACT_LIGHT)
		+ _cue_count(snapshot, CombatAudioPresentation.CUE_IMPACT_MEDIUM)
		+ _cue_count(snapshot, CombatAudioPresentation.CUE_IMPACT_HEAVY)
	)


func _clean_up(game: Node) -> void:
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_AUDIO_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("COMBAT_AUDIO_INTEGRATION_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)
