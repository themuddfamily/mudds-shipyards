extends SceneTree

const FlowScript := preload("res://scripts/game/game_flow.gd")
const RouterScript := preload("res://scripts/audio/semantic_audio_cue_router.gd")
const HalyardScene := preload("res://scenes/ships/halyard_crew_transport.tscn")

class AudioHost:
	extends Node

	var router: Node

	func bind_semantic_audio_source(source: Node, source_id: StringName) -> Dictionary:
		return router.bind_source(source, source_id)

	func detach_semantic_audio_sources() -> Dictionary:
		return router.detach()


var _events: Array[Dictionary] = []
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := FlowScript.new()
	var audio := AudioHost.new()
	audio.router = RouterScript.new()
	var halyard := HalyardScene.instantiate() as HeroShip
	root.add_child(audio)
	audio.add_child(audio.router)
	root.add_child(halyard)
	flow.audio = audio
	flow.active_ship = halyard
	audio.router.semantic_cue_emitted.connect(_on_cue)
	flow._initialize_halyard_crew_semantic_audio()
	_check(is_instance_valid(flow.get("halyard_crew_semantic_audio_binding")), "GameFlow retains crew audio binding")
	_check(audio.router.get_binding_count() == 1, "crew binding routes through semantic router")
	flow._sync_halyard_crew_semantic_audio()
	var binding: Node = flow.get("halyard_crew_semantic_audio_binding")
	_check(bool(binding.get_snapshot().attached), "real detached Halyard snapshot is accepted")
	_check(bool(binding.present_crew_snapshot({
		"occupants": [{"occupant_peer_id": 3, "avatar_id": &"crew_a", "role": &"engineer"}],
		"departure_readiness": {"ready": true},
		"power_routing": {"engineer": {"channel": &"mobility", "component_generation": 2}},
		"emergency_pilot_handoff": {},
	}).accepted), "crew state reaches the normalized router")
	_check(_has_cue(&"crew", &"crew_engineer_joined"), "role cue reaches semantic stream")
	flow._detach_halyard_crew_semantic_audio()
	_check(not bool(binding.get_snapshot().attached), "ship/session detach clears crew binding")
	_check(audio.router.get_binding_count() == 0, "detach clears semantic router source")
	flow.free()
	for node in [audio, halyard]:
		if is_instance_valid(node):
			node.free()
	for failure in _failures:
		push_error(failure)
	print("game_flow_halyard_crew_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})


func _has_cue(source_id: StringName, cue_id: StringName) -> bool:
	for event in _events:
		if event.source_id == source_id and event.cue_id == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
