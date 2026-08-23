extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const AudioDirectorType := preload("res://scripts/audio/audio_director.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const HostType := preload("res://scripts/world/ember_surface_loop_host.gd")
const ProductionType := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

class FlowProbe:
	extends GameFlowType
	func _ready() -> void:
		pass

var _assertions := 0
var _failures: PackedStringArray = []
var _cues: Array[StringName] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := FlowProbe.new()
	var director := AudioDirectorType.new()
	var hud := HudType.new()
	var host := HostType.new()
	var production := ProductionType.new()
	director.name = "AudioDirector"
	hud.name = "HUD"
	host.name = "EmberSurfaceLoopHost"
	production.name = "EmberSurfaceLoopProductionBinding"
	flow.add_child(director)
	flow.add_child(hud)
	flow.add_child(host)
	flow.add_child(production)
	flow.set("audio", director)
	flow.set("hud", hud)
	flow.set("ember_surface_loop_host", host)
	flow.set("ember_surface_loop_production_binding", production)
	host.set("_attached", true)
	host.set("_generation", 1)
	host.set("_attachment_generation", 1)
	production.set("_configured", true)
	production.set("_generation", 1)
	production.set("_host", host)
	root.add_child(flow)
	production.set_physics_process(false)
	await process_frame
	await process_frame
	director.semantic_cue_emitted.connect(_on_semantic_cue)

	hud.update_surface_route_status({
		"title": "ORDINARY ROUTE",
		"message": "EXTERNAL FALLBACK",
		"waypoints": [{"id": &"ordinary", "label": "ORDINARY", "distance_m": 12.0}],
		"hazard": {"state": &"clear", "exposure": 0.0, "recovery_available": false},
	})
	var detail := hud.get("_runtime_status_detail") as Label
	var ordinary_detail := detail.text
	var attached := flow.call("_ensure_ember_surface_presentations") as Dictionary
	_check(bool(attached.get("accepted", false)), "GameFlow composes the bound production Host")
	_check(detail != null and not ordinary_detail.is_empty() and detail.text == ordinary_detail, "idle Ember observation leaves ordinary route fallback external")
	var audio_composition := flow.get("_ember_surface_loop_audio_composition") as Node
	var status_binding := flow.get("_ember_surface_return_status_binding") as RefCounted
	var hud_adapter := flow.get("_ember_surface_return_hud_adapter") as RefCounted
	var identities := [audio_composition.get_instance_id(), status_binding.get_instance_id(), hud_adapter.get_instance_id()]
	_check(director.get_semantic_audio_binding_count() == 1, "one planetary semantic source is registered")
	_check((flow.call("_ensure_ember_surface_presentations") as Dictionary).reason == &"already_attached" and director.get_semantic_audio_binding_count() == 1, "repeated ensure cannot duplicate the planetary source")

	host.set("_phase", HostType.Phase.DESCENT)
	production.state_changed.emit(production.get_snapshot())
	_check(detail.text.contains("EMBER RETURN // DESCENT"), "surface descent overrides the existing route row")
	_check(_cues.count(&"ember_surface_descent_exterior") == 1, "surface descent reaches AudioDirector once")
	hud.update_surface_route_status({
		"title": "ORDINARY ROUTE",
		"message": "EXTERNAL FALLBACK RESTORED",
		"waypoints": [{"id": &"ordinary", "label": "ORDINARY", "distance_m": 8.0}],
		"hazard": {"state": &"clear", "exposure": 0.0, "recovery_available": false},
	})
	var restored_ordinary_detail := detail.text
	flow.call("_ensure_ember_surface_presentations")
	_check(not restored_ordinary_detail.is_empty() and detail.text == restored_ordinary_detail, "idempotent composition does not seize ordinary route fallback")

	root.remove_child(flow)
	_check(director.get_semantic_audio_binding_count() == 0, "detach targets and releases the Ember semantic source")
	_check(not bool((status_binding.call("get_snapshot") as Dictionary).attached) and not bool((hud_adapter.call("get_snapshot") as Dictionary).attached), "detach fences both retained HUD observers")
	root.add_child(flow)
	production.set_physics_process(false)
	await process_frame
	await process_frame
	# The retained Host owner, not GameFlow presentation, re-establishes its live
	# attachment before presentation is eligible to return.
	host.set("_attached", true)
	host.set("_phase", HostType.Phase.IDLE)
	host.set("_generation", 2)
	host.set("_attachment_generation", 2)
	var reattached := flow.call("_ensure_ember_surface_presentations") as Dictionary
	_check(bool(reattached.get("accepted", false)), "re-entry restores the production presentation composition")
	_check([audio_composition.get_instance_id(), status_binding.get_instance_id(), hud_adapter.get_instance_id()] == identities, "re-entry preserves all three exact presentation identities")
	_check(director.get_semantic_audio_binding_count() == 1, "re-entry restores exactly one planetary semantic source")
	host.set("_phase", HostType.Phase.ASCENT)
	production.state_changed.emit(production.get_snapshot())
	_check(detail.text.contains("EMBER RETURN // ASCENT"), "fresh re-entry updates the surface HUD once")
	_check(_cues.count(&"ember_surface_ascent_exterior") == 1, "fresh re-entry reaches AudioDirector once")

	flow.queue_free()
	await process_frame
	_finish()


func _on_semantic_cue(
	_source_id: StringName, cue_id: StringName, _intensity: float, _position: Vector3
) -> void:
	_cues.append(cue_id)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_EMBER_SURFACE_PRESENTATION_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
