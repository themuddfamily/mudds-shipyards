extends SceneTree

const Binding := preload("res://scripts/audio/hero_fleet_audio_binding.gd")
const HeroScene := preload("res://scenes/ships/torrent_interceptor.tscn")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroScene.instantiate() as Node
	root.add_child(hero)
	await process_frame
	await process_frame
	var rig := hero.get_node("ShipAudioRig") as Node
	var automatic: Dictionary = rig.get_hero_fleet_audio_snapshot()
	_check(bool(automatic.attached), "scene rig auto-binds valid hero parent")
	_check((automatic.authority as Dictionary).ship == false, "automatic binding owns no ship authority")
	hero.component_damage_changed.emit(&"engine_bay", 0, 1.0)
	_check(is_zero_approx(float(rig.get_engine_degradation())), "nominal parent signal leaves engine baseline unchanged")
	var binding := Binding.new()
	_check(bool(binding.bind(&"torrent_interceptor", rig).accepted), "baseline hero rig binds")
	rig.semantic_engine_cue_emitted.connect(_on_cue)
	_check(bool(binding.present_component_damage({"stage": &"degraded", "health_ratio": 0.65}).accepted), "degraded state reaches hero rig")
	_check(bool(binding.present_component_damage({"stage": &"critical", "health_ratio": 0.2}).accepted), "critical state reaches hero rig")
	_check(_events.has(&"engine_critical"), "hero rig emits critical engine cue")
	_check(bool(binding.present_component_damage({"stage": &"repaired", "health_ratio": 1.0}).accepted), "repair reset reaches hero rig")
	_check(_events.has(&"engine_recovered"), "hero rig emits recovery cue")
	_check(binding.bind(&"second", rig).reason == &"already_bound", "active binding cannot be replaced")
	_check(bool(binding.detach().accepted), "hero audio binding detaches")
	_check(binding.get_snapshot().generation == 1, "detach advances generation")
	_check((binding.get_snapshot().component_damage as Dictionary).is_empty(), "detach clears damage bridge")
	_check(bool(binding.bind(&"torrent_interceptor", rig).accepted), "hero audio binding re-enters")
	_check(bool((binding.get_snapshot().component_damage as Dictionary).attached), "re-entry restores damage bridge")
	_check(bool(binding.detach().accepted), "re-entry detaches cleanly")
	await _test_whole_hero_reentry(hero, rig)
	hero.queue_free()
	for failure in _failures:
		push_error(failure)
	print("hero_fleet_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _test_whole_hero_reentry(hero: Node, rig: Node) -> void:
	var damage: ShipComponentDamage = hero.get_component_damage()
	var engine_position := Vector3.INF
	for component: Dictionary in damage.get_component_states():
		if component.get("id", &"") == &"engine_bay":
			engine_position = component.get("local_position", Vector3.INF) as Vector3
	_check(engine_position.is_finite(), "production ledger supplies the engine damage location")
	if not engine_position.is_finite():
		return
	_events.clear()
	for cycle in range(2):
		var label := "whole hero re-entry %d: " % (cycle + 1)
		var retired := rig.get("_hero_fleet_audio_binding") as RefCounted
		var ledger_before := damage.get_ledger_snapshot()
		var events_before := _events.size()
		var degradation_before := float(rig.get_engine_degradation())
		root.remove_child(hero)
		_check(_damage_callback_count(hero, rig) == 0, label + "exit disconnects the parent callback")
		_check(not bool(rig.get_hero_fleet_audio_snapshot().attached), label + "exit detaches automatic binding")
		if retired != null:
			_check(not bool(retired.get_snapshot().attached), label + "retired binding is detached")
		var detached_damage := damage.record_collision_damage(hero.maximum_hull * 0.12, engine_position)
		_check(not bool(detached_damage.accepted) and detached_damage.reason == &"component_detached",
			label + "detached production damage is rejected by its owner")
		_check(_events.size() == events_before and is_equal_approx(float(rig.get_engine_degradation()), degradation_before),
			label + "detached damage produces no stale presentation")
		root.add_child(hero)
		await process_frame
		await process_frame
		_check(hero.get_node("ShipAudioRig") == rig, label + "same retained rig returns")
		_check(_damage_callback_count(hero, rig) == 1, label + "exactly one current parent callback returns")
		var automatic: Dictionary = rig.get_hero_fleet_audio_snapshot()
		_check(bool(automatic.attached), label + "automatic binding returns")
		var authority: Dictionary = automatic.get("authority", {})
		_check(authority == {"ship": false, "damage": false, "repair": false, "audio_playback": false},
			label + "binding gains no production authority")
		_check(damage.get_ledger_snapshot() == ledger_before,
			label + "audio detach and re-entry preserve the authoritative ledger")
		_check(_events.size() == events_before, label + "nominal re-entry adds no semantic cue")
		var degraded_before := _events.count(&"engine_degraded")
		var critical_before := _events.count(&"engine_critical")
		var recovered_before := _events.count(&"engine_recovered")
		# The actual component owner resolves located collision damage. Its
		# production signal must traverse the newly restored automatic binding.
		_check(bool(damage.record_collision_damage(hero.maximum_hull * 0.12, engine_position).accepted),
			label + "production damage commits the impaired engine edge")
		_check(damage.get_component_state(&"engine_bay") == ShipComponentDamage.ComponentState.IMPAIRED
			and float(rig.get_engine_degradation()) >= 0.25
			and _events.count(&"engine_degraded") == degraded_before + 1,
			label + "real impaired edge degrades the current rig exactly once")
		_check(bool(damage.record_collision_damage(hero.maximum_hull * 0.01, engine_position).accepted),
			label + "further production damage commits within the impaired band")
		_check(_events.count(&"engine_degraded") == degraded_before + 1,
			label + "damage within the same band does not repeat its cue")
		_check(bool(damage.record_collision_damage(hero.maximum_hull * 0.10, engine_position).accepted),
			label + "production damage commits the failed engine edge")
		_check(damage.get_component_state(&"engine_bay") == ShipComponentDamage.ComponentState.FAILED
			and float(rig.get_engine_degradation()) >= 0.75
			and _events.count(&"engine_critical") == critical_before + 1,
			label + "real failed edge reaches the current rig exactly once")
		if retired != null:
			var current_degradation := float(rig.get_engine_degradation())
			var current_events := _events.size()
			_check(not bool(retired.detach().accepted)
				and not bool(retired.present_parent_damage(&"engine_bay", 0, 1.0).accepted),
				label + "retired binding cannot detach or present again")
			_check(is_equal_approx(float(rig.get_engine_degradation()), current_degradation)
				and _events.size() == current_events,
				label + "retired binding cannot reset current damage or emit stale cues")
		_check(bool(damage.tick_repair(10.0, true).accepted), label + "production owner commits engine repair")
		_check(damage.get_component_state(&"engine_bay") == ShipComponentDamage.ComponentState.NOMINAL
			and is_zero_approx(float(rig.get_engine_degradation()))
			and _events.count(&"engine_recovered") == recovered_before + 1,
			label + "real repair restores the current rig exactly once")
		_check(_events.count(&"engine_degraded") == degraded_before + 1
			and _events.count(&"engine_critical") == critical_before + 1,
			label + "the whole damage and repair sequence has no duplicate edge cues")


func _damage_callback_count(hero: Node, rig: Node) -> int:
	var count := 0
	for connection: Dictionary in hero.get_signal_connection_list(&"component_damage_changed"):
		var callback: Callable = connection.get("callable", Callable())
		if callback.get_object() == rig and callback.get_method() == &"_on_hero_component_damage_changed":
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _on_cue(cue_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)
