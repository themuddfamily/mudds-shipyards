extends SceneTree

const Contract := preload("res://scripts/audio/music_director.gd")
var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var director := Contract.new()
	root.add_child(director)
	_check(bool(director.get_audit_report().valid), "fresh director audit is valid")
	var station := director.observe_session_state(&"rest")
	_check(bool(station.accepted), "rest session observation is accepted")
	_check(station.state == &"station", "rest maps to station presentation")
	var landing := director.observe_phase(&"landing")
	_check(bool(landing.accepted), "landing phase observation is accepted")
	_check(landing.state == &"landing", "landing retains a distinct presentation state")
	_check(landing.session_state == &"flight", "landing maps to the bed flight vocabulary")
	_check(
		StringName(landing.bed_family) == &"station",
		"landing is still scored with the station bed it is returning to"
	)
	var planetary := director.observe_phase(&"planetary")
	_check(bool(planetary.accepted), "planetary phase observation is accepted")
	_check(planetary.state == &"planetary", "planetary retains its presentation state")
	_check(
		StringName(planetary.bed_family) == &"flight"
		and director.get_bed_family() == &"flight",
		"leaving the station selects the authored flight bed"
	)
	var surface := director.observe_phase(&"surface")
	_check(
		StringName(surface.bed_family) == &"surface" and surface.state == &"surface",
		"a surface phase selects the authored surface bed"
	)
	_check(
		StringName(director.observe_phase(&"combat").bed_family) == &"surface",
		"combat silences the bed in place rather than reselecting one"
	)
	_check(
		StringName(director.observe_session_state(&"rest").bed_family) == &"station",
		"returning to rest selects the station bed again"
	)
	_check(director.observe_phase(&"unknown").accepted == false, "unknown phase fails closed")
	_check(
		int(director.get_snapshot().observation_count) == 6,
		"rejected observations do not advance the director count"
	)
	_check(director.advance(37.25), "director loop clock advances")
	var position := float(director.get_snapshot().loop_position_seconds)
	_check(is_equal_approx(position, 37.25), "director retains the combined loop position")
	var muted := director.set_accessibility_muted(true)
	_check(bool(muted.accessibility_muted), "director forwards accessibility mute")
	_check(
		(muted.layer_gains as Dictionary).values().all(
			func(value): return is_equal_approx(float(value), 0.0)
		),
		"director mute silences every presentation layer"
	)
	_check(bool(director.get_audit_report().valid), "director remains auditable after transitions")
	_check(not bool(director.get_audit_report().gameplay_authority), "director cannot own gameplay")
	print("music_director_test: %d assertions passed" % _assertions)
	director.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error(message)
