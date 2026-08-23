extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const MusicBedScene := preload("res://scenes/audio/station_music_bed.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Keep this focused on the owned production seam. A full Main composition
	# currently depends on unrelated dirty HUD work, so do not load or mutate it.
	var game := GameFlowType.new()
	var bed := MusicBedScene.instantiate() as StationMusicBed
	_check(game != null and bed != null, "production GameFlow and station bed instantiate")
	if game == null or bed == null:
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

	game.set("_landing_request_active", true)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"landing",
		"an authoritative landing request reaches the landing crossfade"
	)

	game.set("_landing_request_active", false)
	game.set("phase", GameFlowType.Phase.SHUT_DOWN)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"surface",
		"the authoritative shutdown phase selects the surface music profile"
	)

	game.set("phase", GameFlowType.Phase.INTERCEPTOR_ENGAGEMENT)
	game.call("_update_music_bed_state")
	_check(
		bed.get_presentation_state() == &"combat",
		"combat phase takes priority over landing and flight music"
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
