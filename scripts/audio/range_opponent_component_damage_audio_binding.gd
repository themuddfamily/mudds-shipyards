class_name RangeOpponentComponentDamageAudioBinding
extends RefCounted

## Presentation-only consumer for resolved RangeOpponent damage lifecycle.
## Damage, AI, destruction, and reuse authority remain on RangeOpponent.

signal semantic_damage_cue_emitted(cue_id: StringName, intensity: float)
signal semantic_component_impact_emitted(cue_id: StringName, intensity: float, voice_admitted: bool)
signal semantic_cue_emitted(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3)

const MAXIMUM_SIMULTANEOUS_VOICES := 2
const MAX_SAFE_SEQUENCE := 9_007_199_254_740_991
const COMPONENT_CUES := {
	&"engine": &"opponent_engine_component_impact",
	&"weapon": &"opponent_weapon_component_impact",
	&"sensor": &"opponent_sensor_component_impact",
}
const GENERIC_COMPONENT_CUE: StringName = &"opponent_component_impact"
const CUES := {
	&"degraded": &"opponent_component_degraded",
	&"critical": &"opponent_component_critical",
	&"destroyed": &"opponent_component_destroyed",
}
const PRIORITIES := {
	&"opponent_component_impact": 60,
	&"opponent_sensor_component_impact": 72,
	&"opponent_weapon_component_impact": 78,
	&"opponent_engine_component_impact": 84,
	&"opponent_component_degraded": 90,
	&"opponent_component_critical": 95,
	&"opponent_component_destroyed": 100,
}
const PREBUILT_VOICE_IDS := [&"opponent_damage_voice", &"opponent_destruction_voice"]

var _opponent: Node
var _attached := false
var _generation := 0
var _last_stage: StringName = &"nominal"
var _slots: Array[Dictionary] = []
var _seen_stages: Dictionary = {}
var _last_component_sequence := -1
var _component_health: Dictionary = {}
var _component_cue_count := 0
var _perspective: StringName = &"exterior"
var _reduced_dynamic_range := false
var _emitted_count := 0

func attach(opponent: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if opponent == null or not is_instance_valid(opponent) \
			or not opponent.has_signal(&"health_changed") \
			or not opponent.has_signal(&"destroyed"):
		return _result(false, &"invalid_opponent")
	_opponent = opponent
	_attached = true
	_last_stage = &"nominal"
	_slots.clear()
	_seen_stages.clear()
	_last_component_sequence = -1
	_component_health.clear()
	var health_callback := Callable(self, "_on_health_changed")
	var destroyed_callback := Callable(self, "_on_destroyed")
	if not opponent.is_connected(&"health_changed", health_callback):
		opponent.connect(&"health_changed", health_callback)
	if not opponent.is_connected(&"destroyed", destroyed_callback):
		opponent.connect(&"destroyed", destroyed_callback)
	return _result(true, &"attached")

func reset_for_reuse() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_generation += 1
	_last_stage = &"nominal"
	_slots.clear()
	_seen_stages.clear()
	_last_component_sequence = -1
	_component_health.clear()
	return _result(true, &"reset")

func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if is_instance_valid(_opponent):
		var health_callback := Callable(self, "_on_health_changed")
		var destroyed_callback := Callable(self, "_on_destroyed")
		if _opponent.is_connected(&"health_changed", health_callback):
			_opponent.disconnect(&"health_changed", health_callback)
		if _opponent.is_connected(&"destroyed", destroyed_callback):
			_opponent.disconnect(&"destroyed", destroyed_callback)
	_opponent = null
	_attached = false
	_generation += 1
	_last_stage = &"nominal"
	_slots.clear()
	_seen_stages.clear()
	_last_component_sequence = -1
	_component_health.clear()
	return _result(true, &"detached")

func set_perspective(perspective: StringName) -> Dictionary:
	if perspective not in [&"cockpit", &"exterior"]:
		return _result(false, &"invalid_perspective")
	_perspective = perspective
	return _result(true, &"perspective_updated")

func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	return _result(true, &"mix_updated")

func present_damage_snapshot(health_ratio: float, stage: StringName) -> Dictionary:
	if not _attached or not is_finite(health_ratio) or health_ratio < 0.0 or health_ratio > 1.0 \
			or stage not in [&"nominal", &"degraded", &"critical", &"destroyed", &"repaired"]:
		return _result(false, &"invalid_damage_snapshot")
	var normalized_stage := &"nominal" if stage == &"repaired" else stage
	if normalized_stage == _last_stage:
		return _result(false, &"duplicate_stage")
	_last_stage = normalized_stage
	if not CUES.has(normalized_stage):
		return _result(true, &"stage_recorded")
	if _seen_stages.has(normalized_stage):
		return _result(false, &"duplicate_stage")
	_seen_stages[normalized_stage] = true
	var cue_id: StringName = CUES[normalized_stage]
	if not _admit(cue_id):
		return _result(false, &"voice_budget_rejected")
	var intensity := _intensity(normalized_stage, health_ratio)
	_emitted_count += 1
	semantic_damage_cue_emitted.emit(cue_id, intensity)
	semantic_cue_emitted.emit(&"range_opponent", cue_id, intensity, _world_position())
	return _result(true, &"cue_presented")


## Presents one already-accepted component receipt. The binding only validates
## generation/order and emits semantic presentation; it cannot apply damage.
func present_component_impact(
		component_id: StringName, generation: int, sequence: int, intensity: float
	) -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if generation != _generation:
		return _result(false, &"stale_generation")
	if sequence < 0 or sequence > MAX_SAFE_SEQUENCE:
		return _result(false, &"invalid_sequence")
	if sequence <= _last_component_sequence:
		return _result(false, &"duplicate_or_stale_sequence")
	if not is_finite(intensity):
		return _result(false, &"invalid_intensity")
	_last_component_sequence = sequence
	var cue_id: StringName = COMPONENT_CUES.get(component_id, GENERIC_COMPONENT_CUE)
	var safe_intensity := clampf(intensity, 0.0, 1.0)
	var voice_admitted := _admit(cue_id)
	_component_cue_count += 1
	_emitted_count += 1
	semantic_component_impact_emitted.emit(cue_id, safe_intensity, voice_admitted)
	# Accessibility semantics remain readable when the two audible slots are
	# saturated; this signal never starts playback or consumes another voice.
	semantic_cue_emitted.emit(_source_id(), cue_id, safe_intensity, _world_position())
	var result := _result(
		true,
		&"component_cue_presented" if voice_admitted else &"semantic_cue_presented"
	)
	result["component_id"] = component_id
	result["cue_id"] = cue_id
	result["sequence"] = sequence
	result["voice_admitted"] = voice_admitted
	return result.duplicate(true)

func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "last_stage": _last_stage, "last_component_sequence": _last_component_sequence, "component_cue_count": _component_cue_count, "emitted_cue_count": _emitted_count, "active_cue_slots": _slots.duplicate(true), "prebuilt_voice_ids": PREBUILT_VOICE_IDS.duplicate(), "maximum_simultaneous_voices": MAXIMUM_SIMULTANEOUS_VOICES, "perspective": _perspective, "reduced_dynamic_range": _reduced_dynamic_range, "authority": {"damage": false, "ai": false, "combat": false, "destruction": false, "audio_cues": true}}.duplicate(true)

func _on_health_changed(current: float, maximum: float) -> void:
	if not is_finite(maximum) or maximum <= 0.0:
		return
	_present_component_snapshot()
	var ratio := clampf(current / maximum, 0.0, 1.0)
	var stage: StringName = &"nominal"
	if ratio <= 0.0:
		stage = &"destroyed"
	elif ratio <= 0.34:
		stage = &"critical"
	elif ratio <= 0.67:
		stage = &"degraded"
	present_damage_snapshot(ratio, stage)


func _present_component_snapshot() -> void:
	if not is_instance_valid(_opponent) or not _opponent.has_method(&"get_component_damage_snapshot"):
		return
	var snapshot := _opponent.call(&"get_component_damage_snapshot") as Dictionary
	var model := snapshot.get("model", {}) as Dictionary
	var generation := int(model.get("generation", -1))
	var last_sequence := int(model.get("last_damage_sequence", -1))
	var components := model.get("components", []) as Array
	if generation != _generation or components.is_empty():
		return
	var next_health: Dictionary = {}
	var changed: Array[Dictionary] = []
	for component_variant in components:
		if not component_variant is Dictionary:
			continue
		var component := component_variant as Dictionary
		var component_id := StringName(component.get("component_id", &""))
		var current_health := float(component.get("current_health", NAN))
		var maximum_health := float(component.get("maximum_health", NAN))
		if component_id == &"" or not is_finite(current_health) or not is_finite(maximum_health) \
				or maximum_health <= 0.0:
			continue
		next_health[component_id] = current_health
		if _component_health.has(component_id) \
				and current_health < float(_component_health[component_id]):
			changed.append({
				"component_id": component_id,
				"intensity": clampf(
					(float(_component_health[component_id]) - current_health) / maximum_health,
					0.0,
					1.0
				),
			})
	_component_health = next_health
	if changed.is_empty() or last_sequence < 0:
		return
	var first_sequence := last_sequence - changed.size() + 1
	for index in changed.size():
		var record := changed[index] as Dictionary
		present_component_impact(
			StringName(record.component_id), generation, first_sequence + index, float(record.intensity)
		)

func _on_destroyed(_position: Vector3) -> void:
	present_damage_snapshot(0.0, &"destroyed")

func _intensity(stage: StringName, health_ratio: float) -> float:
	var value := 1.0 if stage in [&"critical", &"destroyed"] else clampf(1.0 - health_ratio, 0.0, 1.0)
	if _perspective == &"cockpit":
		value *= 0.75
	if _reduced_dynamic_range:
		value *= 0.75
	return clampf(value, 0.0, 1.0)

func _admit(cue_id: StringName) -> bool:
	var priority := int(PRIORITIES.get(cue_id, 0))
	if _slots.size() < MAXIMUM_SIMULTANEOUS_VOICES:
		_slots.append({"cue_id": cue_id, "priority": priority})
		return true
	var lowest := 0
	for index in range(1, _slots.size()):
		if int(_slots[index].priority) < int(_slots[lowest].priority):
			lowest = index
	if priority < int(_slots[lowest].priority):
		return false
	_slots[lowest] = {"cue_id": cue_id, "priority": priority}
	return true

func _world_position() -> Vector3:
	return _opponent.global_position if _opponent is Node3D else Vector3.ZERO


func _source_id() -> StringName:
	if is_instance_valid(_opponent) and "source_id" in _opponent:
		var raw_value: Variant = _opponent.get("source_id")
		if raw_value is StringName and raw_value != &"":
			return raw_value as StringName
		if raw_value is String and not str(raw_value).is_empty():
			return StringName(raw_value as String)
	return &"range_opponent"

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
