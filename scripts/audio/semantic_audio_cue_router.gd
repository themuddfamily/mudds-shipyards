class_name SemanticAudioCueRouter
extends Node

## Presentation-only bridge for typed semantic cues from audio components.
##
## The router never selects, plays, or interprets gameplay state. Callers bind
## already-authorized audio sources and consume one normalized event stream.

signal semantic_cue_emitted(
	source_id: StringName,
	cue_id: StringName,
	intensity: float,
	world_position: Vector3
)

const MAX_INTENSITY := 1.0
const SOURCE_SIGNALS := {
	&"combat": &"semantic_cue_emitted",
	&"music": &"semantic_music_cue_emitted",
	&"ship": &"semantic_engine_cue_emitted",
	&"planetary": &"semantic_surface_cue_emitted",
	&"station": &"semantic_maintenance_cue_emitted",
}

var _bindings: Array[Dictionary] = []
var _last_event_key := ""


## Binds one caller-owned audio source using its known semantic signal.
func bind_source(source: Node, source_id: StringName) -> Dictionary:
	if source == null or source_id.is_empty():
		return _result(false, &"invalid_source")
	if _is_source_bound(source):
		return _result(false, &"source_already_bound")
	if not SOURCE_SIGNALS.has(source_id):
		return _result(false, &"unknown_source")
	var signal_name: StringName = SOURCE_SIGNALS[source_id]
	if not source.has_signal(signal_name):
		return _result(false, &"missing_semantic_signal")
	var callback := Callable(self, "_on_combat_cue" if source_id == &"combat" else "_on_scalar_cue").bind(source_id)
	var error := source.connect(signal_name, callback)
	if error != OK:
		return _result(false, &"signal_connect_failed")
	_bindings.append({"source": source, "signal": signal_name, "callback": callback})
	return _result(true, &"bound")


## Disconnects all sources and clears deduplication state for a fresh lifecycle.
func detach() -> Dictionary:
	for binding in _bindings:
		var source: Node = binding.source
		if is_instance_valid(source) and source.is_connected(binding.signal, binding.callback):
			source.disconnect(binding.signal, binding.callback)
	_bindings.clear()
	_last_event_key = ""
	return _result(true, &"detached")


func get_binding_count() -> int:
	return _bindings.size()


func _on_combat_cue(cue_id: StringName, world_position: Vector3, intensity: float, source_id: StringName) -> void:
	_emit_normalized(source_id, cue_id, intensity, world_position)


func _on_scalar_cue(cue_id: StringName, intensity: float, source_id: StringName) -> void:
	_emit_normalized(source_id, cue_id, intensity, Vector3.ZERO)


func _emit_normalized(source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3) -> void:
	if cue_id.is_empty() or not is_finite(intensity):
		return
	intensity = clampf(intensity, 0.0, MAX_INTENSITY)
	var event_key := "%s|%s|%s|%s" % [source_id, cue_id, world_position, intensity]
	if event_key == _last_event_key:
		return
	_last_event_key = event_key
	semantic_cue_emitted.emit(source_id, cue_id, intensity, world_position)


func _is_source_bound(source: Node) -> bool:
	for binding in _bindings:
		if binding.source == source:
			return true
	return false


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "binding_count": _bindings.size()}
