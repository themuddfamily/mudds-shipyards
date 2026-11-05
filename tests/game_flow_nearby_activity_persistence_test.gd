extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")

class StoreProbe extends RefCounted:
	var payload: Dictionary = {}
	var fail_commit := false

	func commit(next_payload: Dictionary, _generation: int, _commit_id: String) -> Dictionary:
		if fail_commit:
			return {"accepted": false, "reason": &"store_commit_failed", "store_reason": &"temp_write_failed"}
		payload = next_payload.duplicate(true)
		return {"accepted": true, "reason": &"committed", "payload": payload.duplicate(true)}

	func load() -> Dictionary:
		return {"accepted": true, "reason": &"loaded", "payload": payload.duplicate(true)}


class BindingProbe extends Node:
	var snapshot := {"generation": 0, "state": "idle"}
	var store: RefCounted

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func configure_activity_persistence(candidate: RefCounted, _slot: StringName) -> bool:
		store = candidate
		return true

	func save_activity_session(generation: int, commit_id: String) -> Dictionary:
		var result: Dictionary = store.commit(snapshot, generation, commit_id)
		if bool(result.get("accepted", false)):
			snapshot["generation"] = generation
		result["status"] = &"saved" if bool(result.get("accepted", false)) else &"failed"
		return result

	func load_activity_session() -> Dictionary:
		var result: Dictionary = store.load()
		result["status"] = &"loaded"
		return result


class WorldProbe extends Node3D:
	var cluster: Node

	func get_nearby_sector_cluster() -> Node:
		return cluster


class HudProbe extends "res://scripts/ui/hud.gd":
	var persistence_results: Array[Dictionary] = []

	func apply_nearby_activity_persistence_result(result: Dictionary) -> Dictionary:
		persistence_results.append(result.duplicate(true))
		return super.apply_nearby_activity_persistence_result(result)


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var cluster := Node.new()
	var binding := BindingProbe.new()
	binding.name = "ActivityBinding"
	cluster.add_child(binding)
	root.add_child(cluster)
	await process_frame
	var world := WorldProbe.new()
	world.cluster = cluster
	root.add_child(world)
	var flow := GameFlowType.new()
	var hud := HudProbe.new()
	var store := StoreProbe.new()
	root.add_child(hud)
	await process_frame
	hud.nearby_activity_intent_requested.connect(flow._on_hud_nearby_activity_intent_requested)
	flow.world = world
	flow.hud = hud
	_check(flow.configure_nearby_activity_persistence(store, &"nearby_slot"), "GameFlow configures the caller-owned activity persistence seam")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"save_progress", "expected_generation": 0})
	_check(hud.persistence_results.size() == 1 and bool(hud.persistence_results[0].accepted), "HUD save intent reaches the validated binding API")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"load_progress"})
	_check(hud.persistence_results.size() == 2 and bool(hud.persistence_results[1].accepted), "HUD load intent applies the validated restore result")
	var before := binding.get_snapshot()
	store.fail_commit = true
	flow._on_hud_nearby_activity_intent_requested({"reason": &"save_progress", "expected_generation": 1})
	var after := binding.get_snapshot()
	_check(hud.persistence_results.size() == 3 and not bool(hud.persistence_results[2].accepted), "failed writes return normalized failure feedback")
	_check(after == before, "failed writes preserve activity authority state")
	store.fail_commit = false
	hud.set_nearby_activity_snapshot({"binding_available": true})
	hud.show_nearby_activity_page()
	var save := hud.find_child("NearbyActivitySaveButton", true, false) as Button
	var load := hud.find_child("NearbyActivityLoadButton", true, false) as Button
	save.pressed.emit()
	load.pressed.emit()
	_check(hud.persistence_results.size() == 5
		and bool(hud.persistence_results[3].accepted) and bool(hud.persistence_results[4].accepted),
		"actual Cinder Save and Load button emissions dispatch their existing persistence owners")
	_check((hud.get("_nearby_activity_feedback") as Label).text == "Progress restored.",
		"actual Cinder button dispatch publishes normal Load feedback")
	cluster.queue_free()
	world.queue_free()
	flow.free()
	hud.free()
	if _failures.is_empty():
		print("GAME_FLOW_NEARBY_ACTIVITY_PERSISTENCE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
