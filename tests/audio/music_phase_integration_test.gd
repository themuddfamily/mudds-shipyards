extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const MusicBedScene := preload("res://scenes/audio/station_music_bed.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Keep this focused on the production music seam without loading full Main.
	var game := GameFlowType.new()
	var bed := MusicBedScene.instantiate() as StationMusicBed
	_check(game != null and bed != null, "production GameFlow and station bed instantiate")
	if game == null or bed == null:
		if game != null:
			game.free()
		if bed != null:
			bed.free()
		_finish()
		return
	root.add_child(bed)
	await process_frame
	bed.set_process(false)
	game.music_bed = bed

	# Stage the actual retained visits at the presentation seam; this is not a
	# claim that either world's ordinary arrival route has been exercised.
	game.set("phase", GameFlowType.Phase.APPROACH_SHIP)
	game.set("_piloting", false)
	game.set("_landing_request_active", false)
	game.set("_ember_surface_journey_active", false)
	for property: StringName in [&"_aurora_expedition", &"_rime_expedition"]:
		var visit: RefCounted = game.get(property)
		visit.set("state", &"surface")
		game.call("_update_music_bed_state")
		_check(
			bed.get_presentation_state() == &"surface",
			"%s retained surface visit selects the surface music profile on foot" % property
		)
		_check(
			bed.get_bed_family() == StationMusicBed.FAMILY_SURFACE,
			"%s retained surface visit uses the authored surface bed on foot" % property
		)
		visit.set("state", &"idle")
	_check_visit_music_states(game, bed)
	_check_visit_activity_music(game, bed)
	# Restore all staged flags before the original phase assertions.
	game.set("_ember_surface_journey_active", false)
	game.set("_landing_request_active", false)
	game.set("_piloting", false)
	game.set("_transition_busy", false)
	game.set("phase", GameFlowType.Phase.APPROACH_SHIP)

	game.set("phase", GameFlowType.Phase.APPROACH_SHIP)
	game.set("_piloting", false)
	game.set("_landing_request_active", false)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"station",
		"on-foot station phase selects the station music profile"
	)

	game.set("phase", GameFlowType.Phase.FREE_FLIGHT)
	game.set("_piloting", true)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"orbit",
		"piloted free flight selects the orbit music profile"
	)

	_check(
		bed.get_bed_family() == StationMusicBed.FAMILY_FLIGHT,
		"piloted free flight scores orbit with the authored flight bed"
	)

	# The flow's own retained surface latch - the same one the session
	# diagnostics read for SURFACE - is what reaches the surface bed.
	game.set("_ember_surface_journey_active", true)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"surface",
		"an active planetary surface journey selects the surface music profile"
	)
	_check(
		bed.get_bed_family() == StationMusicBed.FAMILY_SURFACE,
		"the surface profile is scored with the authored surface bed"
	)
	game.set("_ember_surface_journey_active", false)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"orbit"
		and bed.get_bed_family() == StationMusicBed.FAMILY_FLIGHT,
		"leaving the surface returns the bed to orbit without inventing a phase"
	)

	game.set("_landing_request_active", true)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"landing",
		"an authoritative landing request reaches the landing crossfade"
	)
	_check(
		bed.get_bed_family() == StationMusicBed.FAMILY_STATION,
		"landing is already scored with the station bed it is returning to"
	)

	game.set("_landing_request_active", false)
	game.set("phase", GameFlowType.Phase.RETURN_TO_YARD)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"landing",
		"the authoritative return phase retains the landing crossfade"
	)

	game.set("phase", GameFlowType.Phase.SHUT_DOWN)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"landing",
		"docked shutdown remains in the landing profile rather than inventing a planetary surface phase"
	)

	game.set("_landing_request_active", true)
	game.set("_ember_surface_journey_active", true)
	game.set("phase", GameFlowType.Phase.INTERCEPTOR_ENGAGEMENT)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"combat",
		"combat phase takes priority over landing, surface and flight music"
	)
	_check(
		bool((bed.get_audit_report().get("music", {}) as Dictionary).get("gameplay_authority", true)) == false,
		"music bed retains no gameplay authority after phase integration"
	)
	_check(
		bool(bed.get_music_director().get_audit_report().get("valid", false)),
		"integrated music director remains auditable"
	)
	bed.set_bed_enabled(false)
	bed.release_audio_resources()
	game.free()
	bed.queue_free()
	await process_frame
	await process_frame
	_finish()


func _check_visit_music_states(game: GameFlow, bed: StationMusicBed) -> void:
	# Frozen expectations are independent of the production projection. Every
	# case stages retained state only, without travel, streaming or actor input.
	var phases := {
		&"landed": &"surface", &"opening_exit": &"surface",
		&"disembarking": &"surface", &"surface": &"surface",
		&"opening_boarding": &"surface", &"boarding": &"surface",
		&"landing": &"landing", &"outbound": &"orbit",
		&"corridor": &"orbit", &"return_cruise": &"orbit",
		&"idle": &"station", &"restoring": &"station",
		&"retiring": &"station", &"unknown_future_state": &"station",
	}
	for property: StringName in [&"_aurora_expedition", &"_rime_expedition"]:
		var visit: RefCounted = game.get(property)
		for state: StringName in phases:
			visit.set("state", state)
			game.set("_transition_busy", state in [
				&"opening_exit", &"disembarking", &"opening_boarding", &"boarding",
			])
			var expected: StringName = phases[state]
			_observe_unchanged(game, bed, expected, _family_for_phase(expected),
				"%s frozen %s mapping with local piloting false" % [property, state])
		game.set("_transition_busy", false)
		game.set("_piloting", true)
		for state: StringName in [&"surface", &"idle", &"restoring", &"retiring"]:
			visit.set("state", state)
			var expected: StringName = &"surface" if state == &"surface" else &"orbit"
			_observe_unchanged(game, bed, expected, _family_for_phase(expected),
				"%s %s respects actual piloted context" % [property, state])
		game.set("_piloting", false)
		visit.set("state", &"surface")
		game.set("_landing_request_active", true)
		_observe_unchanged(game, bed, &"landing", StationMusicBed.FAMILY_STATION,
			"%s surface cannot replace authoritative landing request" % property)
		game.set("phase", GameFlowType.Phase.INTERCEPTOR_ENGAGEMENT)
		for state: StringName in [&"surface", &"landing"]:
			visit.set("state", state)
			_observe_unchanged(game, bed, &"combat", StationMusicBed.FAMILY_STATION,
				"%s visit %s and landing request cannot replace combat" % [property, state])
		game.set("_landing_request_active", false)
		visit.set("state", &"surface")
		for phase: int in [GameFlowType.Phase.RETURN_TO_YARD, GameFlowType.Phase.SHUT_DOWN]:
			game.set("phase", phase)
			_observe_unchanged(game, bed, &"landing", StationMusicBed.FAMILY_STATION,
				"%s surface cannot replace return or shutdown phase %d" % [property, phase])
		game.set("phase", GameFlowType.Phase.APPROACH_SHIP)
		visit.set("state", &"return_cruise")
		_observe_unchanged(game, bed, &"orbit", StationMusicBed.FAMILY_FLIGHT,
			"%s departing surface restores flight even for a passenger" % property)
		visit.set("state", &"idle")
		_observe_unchanged(game, bed, &"station", StationMusicBed.FAMILY_STATION,
			"%s completed return restores actual on-foot station context" % property)


func _check_visit_activity_music(game: GameFlow, bed: StationMusicBed) -> void:
	game.call("_initialize_nearby_activity_audio")
	var generation := 1
	for property: StringName in [&"_aurora_expedition", &"_rime_expedition"]:
		var visit: RefCounted = game.get(property)
		visit.set("state", &"surface")
		game.call("_update_music_bed_state")
		_sync_activity(game, &"active", generation)
		_observe_unchanged(game, bed, &"activity_active", StationMusicBed.FAMILY_SURFACE,
			"%s current active activity uses actual surface family" % property)
		visit.set("state", &"return_cruise")
		_observe_unchanged(game, bed, &"activity_active", StationMusicBed.FAMILY_FLIGHT,
			"%s current activity follows return flight family" % property)
		visit.set("state", &"landing")
		_observe_unchanged(game, bed, &"landing", StationMusicBed.FAMILY_STATION,
			"%s visit landing suppresses current activity" % property)
		visit.set("state", &"surface")
		_observe_unchanged(game, bed, &"activity_active", StationMusicBed.FAMILY_SURFACE,
			"%s landing release resumes current activity over surface" % property)
		_sync_activity(game, &"complete", generation)
		_observe_unchanged(game, bed, &"activity_complete", StationMusicBed.FAMILY_SURFACE,
			"%s same-run completion retains current surface family" % property)
		visit.set("state", &"return_cruise")
		_observe_unchanged(game, bed, &"activity_complete", StationMusicBed.FAMILY_FLIGHT,
			"%s current completion follows return flight family" % property)
		visit.set("state", &"idle")
		_observe_unchanged(game, bed, &"activity_complete", StationMusicBed.FAMILY_STATION,
			"%s idle visit leaves completion over actual station context" % property)
		_sync_activity(game, &"idle", generation)
		_observe_unchanged(game, bed, &"station", StationMusicBed.FAMILY_STATION,
			"%s clearing activity restores actual station context" % property)
		generation += 1
	game.call("_detach_nearby_activity_audio")
	bed.set_bed_enabled(true)


func _sync_activity(game: GameFlow, state: StringName, generation: int) -> void:
	game.call("_sync_nearby_activity_audio", {
		"activity_id": &"cinder_reach_emberline_convoy",
		"host": {"activity": {"state_id": state, "generation": generation}},
	})


func _family_for_phase(phase: StringName) -> StringName:
	if phase == &"surface":
		return StationMusicBed.FAMILY_SURFACE
	if phase == &"orbit":
		return StationMusicBed.FAMILY_FLIGHT
	return StationMusicBed.FAMILY_STATION


func _observe_unchanged(game: GameFlow, bed: StationMusicBed, expected: StringName,
		family: StringName, message: String) -> void:
	var before := _gameplay_snapshot(game)
	game.call("_update_music_bed_state")
	_check(bed.get_presentation_state() == expected and bed.get_bed_family() == family,
		message)
	_check(_gameplay_snapshot(game) == before, message + " leaves visit/gameplay state unchanged")


func _gameplay_snapshot(game: GameFlow) -> Dictionary:
	return {
		"aurora": game.get("_aurora_expedition").get_visit_snapshot(),
		"rime": game.get("_rime_expedition").get_visit_snapshot(),
		"phase": game.get("phase"), "piloting": game.get("_piloting"),
		"landing": game.get("_landing_request_active"),
		"ember": game.get("_ember_surface_journey_active"),
		"transition_busy": game.get("_transition_busy"),
		"ship": game.active_ship, "player": game.player, "opponent": game.opponent,
	}


func _finish() -> void:
	print("music_phase_integration_test: %d assertions passed" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error(message)
