extends SceneTree

const BedScene := preload("res://scenes/audio/station_music_bed.tscn")
const AdapterScript := preload("res://scripts/audio/nearby_sector_activity_music_adapter.gd")
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bed := BedScene.instantiate() as StationMusicBed
	var adapter := AdapterScript.new()
	root.add_child(bed)
	root.add_child(adapter)
	await process_frame
	bed.set_process(false)
	_check(bool(adapter.configure(bed).accepted), "adapter configures against the music bed")
	_check(bool(adapter.attach().accepted), "adapter attaches")
	var active := {"generation": 1, "activity_kind": &"patrol", "activity_state": &"active"}
	_check(bool(adapter.present_activity_snapshot(active).accepted), "activity snapshot reaches music")
	_check(bed.get_presentation_state() == &"activity_active", "active activity profile is selected")
	_check(adapter.present_activity_snapshot(active).reason == &"stale_activity_generation", "duplicate generation is rejected")
	_check(bool(adapter.present_activity_snapshot({
		"generation": 2, "activity_kind": &"patrol", "activity_state": &"complete",
	}).accepted), "completion reaches music")
	_check(bed.get_presentation_state() == &"activity_complete", "completion profile is selected")
	_check(bool(bed.notify_music_phase(&"combat")), "combat presentation is accepted")
	_check(adapter.present_activity_snapshot({
		"generation": 3, "activity_kind": &"patrol", "activity_state": &"active",
	}).reason == &"music_state_rejected", "combat preempts activity music")
	_check(bool(adapter.detach().accepted), "detach clears adapter and disables its bed")
	_check(not bool(adapter.get_snapshot().attached), "adapter reports detached lifecycle")
	_check(adapter.present_activity_snapshot(active).reason == &"not_attached", "detached adapter rejects snapshots")
	_check(adapter.attach(0).reason == &"stale_generation", "old adapter generation cannot reattach")
	_check(bool(bed.notify_music_phase(&"orbit")), "orbit releases combat preemption")
	_check(bool(adapter.attach(1).accepted), "next adapter generation reattaches")
	_check(bool(adapter.present_activity_snapshot(active).accepted), "reattached adapter accepts retained activity stream")
	for failure in _failures:
		push_error(failure)
	print("nearby_sector_activity_music_adapter_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
