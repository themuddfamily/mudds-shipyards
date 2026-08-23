extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Composition := preload("res://scripts/audio/cinder_navigator_ping_audio_composition.gd")
const Bridge := preload("res://scripts/network/network_cinder_navigator_ping_bridge.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

class BridgeAdapter:
	var migration_generation := 1
	func get_migration_snapshot() -> Dictionary: return {"migration_generation": migration_generation}
	func publish_crew_snapshot(_snapshot: Array) -> Dictionary: return {"accepted": true}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	var composition := Composition.new()
	var cinder := Cinder.new()
	root.add_child(director)
	root.add_child(composition)
	root.add_child(cinder)
	await process_frame
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(composition.attach(director, 1).accepted), "navigator composition binds to AudioDirector")
	_check(director.get_semantic_audio_binding_count() == 1, "one targeted crew source is registered")

	var bridge := Bridge.new()
	var bridge_adapter := BridgeAdapter.new()
	_check(bool(bridge.attach(bridge_adapter, cinder).accepted), "real Cinder navigator bridge attaches")
	var rejected := bridge.submit_ping(7, 1, &"navigator", 1, 1, {}, 2, 1)
	_check(StringName(rejected.get("status", &"")) == &"authority_unavailable", "bridge rejects without navigator authority")
	_check(bool(composition.present_bridge_result(rejected).accepted), "bridge rejection becomes bounded semantic cue")
	var receipt := {
		"action": &"passenger_ping", "peer_id": 7, "peer_generation": 1,
		"avatar_id": &"navigator", "seat_generation": 1, "request_sequence": 2,
		"server_tick": 3, "migration_generation": 1
	}
	_check(bool(composition._binding.present_receipt(receipt).accepted), "accepted bridge receipt emits typed ping cue")
	_check(not composition._binding.present_receipt(receipt).accepted, "replayed receipt is deduplicated")
	var tombstone := receipt.duplicate(true)
	tombstone.action = &"passenger_ping_clear"
	tombstone.request_sequence = 3
	tombstone.server_tick = 4
	_check(bool(composition._binding.present_receipt_clear(tombstone).accepted), "bridge clear tombstone emits clear cue")
	_check(_has(&"crew_passenger_joined") and _has(&"crew_passenger_left"), "router receives accepted/rejected-or-cleared crew cues")
	_check(bool(composition.detach().accepted), "targeted detach clears navigator source")
	_check(director.get_semantic_audio_binding_count() == 0, "detach removes only navigator source")
	bridge.detach()
	for failure in _failures: push_error(failure)
	print("CINDER_NAVIGATOR_PING_AUDIO_TEST: %d assertions" % (_failures.size() + 9))
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id: return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
