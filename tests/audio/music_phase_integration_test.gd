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


func _finish() -> void:
	print("music_phase_integration_test: %d assertions passed" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error(message)
