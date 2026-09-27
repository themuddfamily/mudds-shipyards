extends SceneTree

## Adaptive combat music layer: calm -> engaged -> victory -> calm, the subdued
## failure stinger, the quiet release, reduced dynamic range, mute, and
## whole-subtree detach/re-entry teardown. Also witnesses that production Main
## composes the layer and routes it to the Music bus.
##
## Every check is structural. Whether the combat stems sound good is an
## outstanding human listening pass and is not claimed here.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LayerScript := preload("res://scripts/audio/combat_music_layer.gd")
const ObserverScript := preload("res://scripts/audio/combat_music_observer.gd")

var _failures: Array[String] = []
var _test_root: Node
var _stingers: Array[StringName] = []


## Stands in for a real backend under Dummy so the attach path runs.
class AcceptingLayer extends CombatMusicLayer:
	func _backend_supports_playback() -> bool:
		return true

	func _request_playback(_player: AudioStreamPlayer) -> bool:
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node.new()
	_test_root.name = "CombatMusicLayerTestRoot"
	root.add_child(_test_root)

	_test_observer_edges()
	await _test_calm_engaged_victory_calm()
	await _test_failure_stinger()
	await _test_release_without_outcome()
	await _test_reduced_dynamic_range()
	await _test_mute()
	await _test_detach_reentry_teardown()
	await _test_production_main_composes_layer()

	_test_root.queue_free()
	await process_frame
	await process_frame
	_finish()


func _make_layer(label: String) -> CombatMusicLayer:
	var layer := AcceptingLayer.new()
	layer.name = label
	layer.set_process(false)
	_test_root.add_child(layer)
	layer.stinger_started.connect(func(stinger_id: StringName) -> void: _stingers.append(stinger_id))
	return layer


func _advance(layer: CombatMusicLayer, seconds: float) -> void:
	var step := 1.0 / 60.0
	for _index in roundi(seconds * 60.0):
		layer.advance(step)


func _release(layer: CombatMusicLayer) -> void:
	if is_instance_valid(layer):
		layer.release_audio_resources()
		layer.queue_free()


func _engaged(hostiles: int) -> Dictionary:
	return {"engaged": true, "hostile_count": hostiles, "outcome": &"", "outcome_serial": 0}


func _gain(layer: CombatMusicLayer, stem: StringName) -> float:
	return float((layer.get_snapshot()["stem_gains"] as Dictionary)[stem])


func _test_observer_edges() -> void:
	var observer := ObserverScript.new()
	var idle := observer.observe({"encounter": {"state": &"concluded", "generation": 3, "outcome": &"cleared"}})
	_check(
		not bool(idle["engaged"]) and StringName(idle["outcome"]) == &"",
		"a concluded encounter the observer never saw running fires no stinger"
	)
	var running := observer.observe({"encounter": {"state": &"running", "generation": 4, "hostile_count": 2}})
	_check(bool(running["engaged"]) and int(running["hostile_count"]) == 2, "a running encounter is engaged with its roster")
	var cleared := observer.observe({"encounter": {"state": &"concluded", "generation": 4, "outcome": &"cleared"}})
	_check(StringName(cleared["outcome"]) == &"victory", "running -> cleared reads as victory")
	var repeat := observer.observe({"encounter": {"state": &"concluded", "generation": 4, "outcome": &"cleared"}})
	_check(
		StringName(repeat["outcome"]) == &"" and int(repeat["outcome_serial"]) == int(cleared["outcome_serial"]),
		"a repeated concluded snapshot does not fire a second outcome"
	)
	observer.observe({"station_defense": {"state_id": "active", "generation": 9, "wave_active": true, "remaining_hostile_count": 3}})
	var failed := observer.observe({"station_defense": {"state_id": "failed", "generation": 9}})
	_check(StringName(failed["outcome"]) == &"failure", "an active station defence that fails reads as failure")
	observer.observe({"encounter": {"state": &"running", "generation": 5}})
	var withdrawn := observer.observe({"encounter": {"state": &"concluded", "generation": 5, "outcome": &"withdrawn"}})
	_check(StringName(withdrawn["outcome"]) == &"" and not bool(withdrawn["engaged"]), "a withdrawal is a quiet release")
	observer.observe({"convoy_threat": {"active": true, "attacker_alive": true, "generation": 2, "tender_health": 50.0, "tender_maximum_health": 100.0}})
	var picket_down := observer.observe({"convoy_threat": {"active": true, "attacker_alive": false, "generation": 2, "tender_health": 50.0, "tender_maximum_health": 100.0}})
	_check(StringName(picket_down["outcome"]) == &"victory", "destroying the convoy attacker reads as victory")
	_check(bool(observer.observe({"legacy_engaged": true})["engaged"]), "the legacy interceptor engagement counts as combat")


func _test_calm_engaged_victory_calm() -> void:
	var layer := _make_layer("VictoryLayer")
	await process_frame
	_stingers.clear()
	_check(layer.get_state() == CombatMusicLayer.STATE_CALM, "a new layer starts calm")
	_check(not layer.is_holding_bed(), "a calm layer does not hold the bed")
	for player in layer.find_children("*", "AudioStreamPlayer", true, false):
		_check((player as AudioStreamPlayer).bus == &"Music", "layer voice %s routes to the Music bus" % player.name)
	_check(layer.find_children("*", "AudioStreamPlayer", true, false).size() == 4, "the layer owns three stems and one stinger voice")

	layer.observe(_engaged(1))
	_check(layer.get_state() == CombatMusicLayer.STATE_ENGAGED, "calm -> engaged on a live encounter")
	_check(layer.is_holding_bed(), "an engaged layer asks the calm bed to yield")
	_advance(layer, 2.0)
	_check(is_equal_approx(_gain(layer, &"floor"), 1.0), "the floor stem fades fully in while engaged")
	_check(is_equal_approx(_gain(layer, &"lead"), 0.0), "the lead stem stays out against a single hostile")
	var snapshot := layer.get_snapshot()
	_check(bool((snapshot["stem_players"] as Dictionary)[&"floor"]["attached"]), "an engaged layer attaches its stem stream")
	layer.observe(_engaged(3))
	_advance(layer, 2.0)
	_check(is_equal_approx(_gain(layer, &"lead"), 1.0), "the lead stem joins against several hostiles")

	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"victory", "outcome_serial": 1})
	_check(layer.get_state() == CombatMusicLayer.STATE_VICTORY, "engaged -> victory when the encounter is cleared")
	_check(_stingers.size() == 1 and _stingers[0] == &"victory", "the victory stinger starts exactly once")
	_check(bool(layer.get_snapshot()["stinger_attached"]), "the victory stinger attaches to its voice")
	_check(not layer.is_holding_bed(), "the bed is released to return under the stinger")
	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"victory", "outcome_serial": 1})
	_check(_stingers.size() == 1, "re-observing the same outcome serial does not replay the stinger")
	_advance(layer, 1.0)
	_check(_gain(layer, &"floor") < 0.01, "stems duck quickly under the stinger")
	_advance(layer, CombatMusicLayer.VICTORY_HOLD_SECONDS)
	_check(layer.get_state() == CombatMusicLayer.STATE_CALM, "victory -> calm after the hold")
	var calm := layer.get_snapshot()
	_check(not bool(calm["stems_playing"]) and not bool(calm["stinger_attached"]), "a calm layer holds no voice")
	_release(layer)
	await process_frame


func _test_failure_stinger() -> void:
	var layer := _make_layer("FailureLayer")
	await process_frame
	_stingers.clear()
	layer.observe(_engaged(2))
	_advance(layer, 1.0)
	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"failure", "outcome_serial": 1})
	_check(layer.get_state() == CombatMusicLayer.STATE_FAILURE, "engaged -> failure when the encounter is lost")
	_check(_stingers.size() == 1 and _stingers[0] == &"failure", "the failure stinger plays once")
	var failure_volume := float(layer.get_snapshot()["stinger_volume_db"])
	_advance(layer, CombatMusicLayer.FAILURE_HOLD_SECONDS + 0.1)
	_check(layer.get_state() == CombatMusicLayer.STATE_CALM, "failure -> calm after its hold")
	_check(
		failure_volume <= CombatMusicLayer.STINGER_VOLUME_DB,
		"the failure stinger never plays above the stinger trim (its asset is authored 6 dB under victory)"
	)
	_release(layer)
	await process_frame


func _test_release_without_outcome() -> void:
	var layer := _make_layer("ReleaseLayer")
	await process_frame
	_stingers.clear()
	layer.observe(_engaged(1))
	_advance(layer, 2.0)
	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"", "outcome_serial": 0})
	_check(layer.get_state() == CombatMusicLayer.STATE_RELEASE, "an outcome-less end is a quiet release")
	_check(_stingers.is_empty(), "a release plays no stinger")
	_advance(layer, CombatMusicLayer.RELEASE_HOLD_SECONDS + 0.1)
	_check(layer.get_state() == CombatMusicLayer.STATE_CALM, "release -> calm after its hold")
	_release(layer)
	await process_frame


func _test_reduced_dynamic_range() -> void:
	var layer := _make_layer("ReducedRangeLayer")
	await process_frame
	layer.set_reduced_dynamic_range(true)
	layer.observe(_engaged(4))
	_advance(layer, 3.0)
	_check(
		_gain(layer, &"lead") <= CombatMusicLayer.REDUCED_RANGE_LEAD_CAP + 0.001,
		"reduced dynamic range caps the lead stem"
	)
	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"victory", "outcome_serial": 1})
	_check(
		is_equal_approx(
			float(layer.get_snapshot()["stinger_volume_db"]),
			CombatMusicLayer.STINGER_VOLUME_DB + CombatMusicLayer.REDUCED_RANGE_STINGER_TRIM_DB
		),
		"reduced dynamic range trims the stinger"
	)
	_release(layer)
	await process_frame


func _test_mute() -> void:
	var layer := _make_layer("MutedLayer")
	await process_frame
	_stingers.clear()
	layer.set_muted(true)
	layer.observe(_engaged(3))
	_advance(layer, 2.0)
	_check(layer.get_state() == CombatMusicLayer.STATE_ENGAGED, "a muted layer still follows the fight")
	var muted := layer.get_snapshot()
	_check(_gain(layer, &"floor") == 0.0 and not bool(muted["stems_playing"]), "a muted layer holds every stem silent")
	for player in layer.find_children("*", "AudioStreamPlayer", true, false):
		_check((player as AudioStreamPlayer).stream == null, "muted voice %s has no stream attached" % player.name)
	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"victory", "outcome_serial": 1})
	_check(layer.get_state() == CombatMusicLayer.STATE_VICTORY, "a muted layer still records the outcome")
	_check(not bool(layer.get_snapshot()["stinger_attached"]), "a muted layer plays no stinger")
	layer.set_muted(false)
	layer.observe(_engaged(1))
	_advance(layer, 2.0)
	_check(_gain(layer, &"floor") > 0.9, "unmuting lets the stems return")
	layer.observe(_engaged(1))
	layer.set_muted(true)
	_check(not bool(layer.get_snapshot()["stems_playing"]), "muting mid-fight stops the stems at once")
	_release(layer)
	await process_frame


func _test_detach_reentry_teardown() -> void:
	var holder := Node.new()
	holder.name = "MainStandIn"
	_test_root.add_child(holder)
	var layer := AcceptingLayer.new()
	layer.name = "ReentryLayer"
	layer.set_process(false)
	holder.add_child(layer)
	await process_frame
	layer.observe(_engaged(2))
	_advance(layer, 2.0)
	layer.observe({"engaged": false, "hostile_count": 0, "outcome": &"victory", "outcome_serial": 1})
	_check(bool(layer.get_snapshot()["stinger_attached"]), "the stinger is sounding before the detach")

	_test_root.remove_child(holder)
	var detached := layer.get_snapshot()
	_check(StringName(detached["state"]) == CombatMusicLayer.STATE_CALM, "a detached layer drops to calm")
	_check(not bool(detached["stems_playing"]) and not bool(detached["stinger_attached"]), "a detached layer holds no voice")
	for player in layer.find_children("*", "AudioStreamPlayer", true, false):
		_check((player as AudioStreamPlayer).stream == null, "detached voice %s releases its stream" % player.name)
	var rejected := layer.observe(_engaged(1))
	_check(not bool(rejected["accepted"]), "a detached layer ignores observations")

	_test_root.add_child(holder)
	await process_frame
	_check(layer.find_children("*", "AudioStreamPlayer", true, false).size() == 4, "re-entry does not duplicate the voices")
	_check(layer.get_state() == CombatMusicLayer.STATE_CALM, "re-entry does not resume a stale stinger or fight")
	layer.observe(_engaged(1))
	_check(layer.get_state() == CombatMusicLayer.STATE_ENGAGED, "a re-entered layer re-engages from the live observation")
	_check(float(layer.get_snapshot()["loop_position_seconds"]) == 0.0, "re-engagement starts the stems on the downbeat")
	layer.release_audio_resources()
	holder.queue_free()
	await process_frame


func _test_production_main_composes_layer() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null:
		return
	root.add_child(game)
	# GameFlow composes the layer from its first initialized _process frame.
	var layer: CombatMusicLayer = null
	for _frame in 120:
		await process_frame
		layer = game.get_combat_music_layer()
		if layer != null:
			break
	_check(layer != null, "GameFlow composes the combat music layer beside the calm bed")
	if layer != null:
		_check(layer.get_state() == CombatMusicLayer.STATE_CALM, "the station at rest is calm")
		_check(not bool(layer.get_snapshot()["gameplay_authority"]), "the layer claims no gameplay authority")
		_check(
			game.get_music_bed().find_children("*", "AudioStreamPlayer", true, false).size() == 3,
			"the calm bed keeps its exact three-voice roster"
		)
		var parent := game.get_parent()
		parent.remove_child(game)
		_check(not bool(layer.get_snapshot()["stems_playing"]), "a detached Main leaves no combat voice")
		parent.add_child(game)
		for _frame in 3:
			await process_frame
		_check(
			root.find_children("CombatMusicLayer", "", true, false).size() == 1,
			"whole-Main re-entry does not duplicate the combat music layer"
		)
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_MUSIC_LAYER_TEST_OK")
		quit(0)
	else:
		print("COMBAT_MUSIC_LAYER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
