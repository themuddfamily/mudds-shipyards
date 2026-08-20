extends SceneTree

const Contract := preload("res://scripts/audio/music_state_transition.gd")
var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var music := Contract.new()
	_check(music.audit().valid, "contract audit is valid")
	_check(music.get_snapshot().state == &"station", "station is the initial state")
	_check(music.get_mix_plan().bus == &"Music", "all plans route through Music")
	_check(music.get_mix_plan().voice_count == 3, "music declares a three-voice ceiling")
	_check(music.transition(&"combat").accepted, "combat transition is accepted")
	_check(music.get_mix_plan().layer_gains[&"bed"] == 0.0, "combat ducks the station bed")
	_check(music.get_mix_plan().layer_gains[&"stinger"] > 0.0, "combat exposes its authored stinger layer")
	_check(music.transition(&"landing").accepted, "landing transition is accepted")
	_check(music.get_mix_plan().layer_gains[&"stinger"] > 0.0, "landing retains a bounded arrival layer")
	_check(music.transition(&"planetary").accepted, "planetary transition is accepted")
	_check(music.get_mix_plan().layer_gains[&"motif"] > 0.0, "planetary state exposes its motif layer")
	_check(music.advance(37.25), "loop clock advances")
	var position := float(music.get_snapshot().loop_position_seconds)
	_check(is_equal_approx(position, 37.25), "loop position is retained during transitions")
	var transition := music.transition(&"station")
	_check(is_equal_approx(float(transition.retained_position_seconds), position), "state transition preserves loop position")
	_check(music.transition(&"unknown").accepted == false, "unknown state is rejected")
	_check(music.restore(music.get_snapshot()), "detached snapshot restores successfully")
	var restored_position := float(music.get_snapshot().loop_position_seconds)
	_check(is_equal_approx(restored_position, position), "detach/re-entry restoration retains position")
	var muted := music.set_accessibility_muted(true)
	var muted_gains := muted.layer_gains as Dictionary
	_check(bool(muted.accessibility_muted), "accessibility mute is reported")
	_check(muted_gains.values().all(func(value): return is_equal_approx(float(value), 0.0)), "accessibility mute silences every layer")
	music.set_accessibility_muted(false)
	_check(float((music.get_mix_plan().layer_gains as Dictionary)[&"bed"]) > 0.0, "unmute restores the active state mix")
	_check(music.restore({"state": &"combat", "loop_position_seconds": 481.0, "accessibility_muted": false}), "wrapped snapshot restores")
	_check(is_equal_approx(float(music.get_snapshot().loop_position_seconds), 1.0), "restored positions wrap on the combined cycle")
	_check(music.restore({"state": &"bad", "loop_position_seconds": 1.0}) == false, "invalid restore state is rejected")
	_check(music.restore({"state": &"station", "loop_position_seconds": INF}) == false, "nonfinite restore position is rejected")
	print("music_state_transition_test: %d assertions passed" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error(message)
