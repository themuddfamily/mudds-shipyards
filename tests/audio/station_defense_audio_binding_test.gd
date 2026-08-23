extends SceneTree

const Binding := preload("res://scripts/audio/station_defense_audio_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	host.add_user_signal("snapshot_changed")
	root.add_child(host)
	var binding := Binding.new()
	binding.semantic_activity_cue_emitted.connect(_on_cue)
	_check(bool(binding.attach(host).accepted), "station-defense host snapshot binding attaches")
	var base := _snapshot(&"idle", 0, false, [])
	_check(bool(binding.present_snapshot(base).accepted), "idle snapshot is accepted")
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [])).accepted), "wave start snapshot is accepted")
	_check(_events.has(&"station_defense_wave_started"), "wave start emits a typed cue")
	var safe_asset := {"handle": {"asset_id": &"berth_safe"}, "damage_event_count": 0, "destroyed": false}
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [safe_asset])).accepted), "safe asset snapshot is accepted")
	_check(_events.has(&"station_defense_asset_safe"), "safe asset emits a readiness cue")
	var danger_asset := {"handle": {"asset_id": &"berth_core"}, "damage_event_count": 1, "destroyed": false}
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [danger_asset])).accepted), "asset danger snapshot is accepted")
	_check(_events.has(&"station_defense_asset_danger"), "asset damage emits danger cue")
	var count := _events.size()
	binding.present_snapshot(_snapshot(&"active", 0, true, [danger_asset]))
	_check(_events.size() == count, "duplicate asset damage is suppressed")
	var critical_asset := danger_asset.duplicate(true)
	critical_asset.destroyed = true
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [critical_asset])).accepted), "asset critical snapshot is accepted")
	_check(_events.has(&"station_defense_asset_critical"), "asset destruction emits critical cue")
	_check(_events.has(&"station_defense_asset_destroyed"), "asset destruction emits destroyed cue")
	var recovered_asset := danger_asset.duplicate(true)
	recovered_asset.destroyed = false
	recovered_asset.damage_event_count = 0
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [recovered_asset])).accepted), "asset recovery snapshot is accepted")
	_check(_events.has(&"station_defense_asset_recovered"), "asset recovery emits recovered cue")
	_check(bool(binding.present_snapshot(_snapshot(&"completed", 1, false, [critical_asset])).accepted), "completion snapshot is accepted")
	_check(_events.has(&"station_defense_completed"), "completion emits a typed cue")
	_check(bool(binding.present_snapshot(_snapshot(&"aborted", 1, false, [critical_asset])).accepted), "abort snapshot is accepted")
	_check(_events.has(&"station_defense_aborted"), "abort emits a typed cue")
	_check(int(binding.get_snapshot().maximum_simultaneous_voices) == 2, "station-defense cues retain a two-voice ceiling")
	_check(bool(binding.detach().accepted), "detach clears station-defense binding")
	_check(binding.present_snapshot(base).reason == &"not_attached", "detached binding rejects stale snapshots")
	_check(int(binding.get_snapshot().generation) == 1, "detach advances station-defense generation")
	host.free()
	for failure in _failures:
		push_error(failure)
	print("station_defense_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(state: StringName, wave_index: int, wave_active: bool, assets: Array) -> Dictionary:
	return {"activity_id": &"station_defense_alpha", "state_id": state, "current_wave_index": wave_index, "wave_active": wave_active, "protected_assets": assets}


func _on_cue(cue_id: StringName, _activity_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
