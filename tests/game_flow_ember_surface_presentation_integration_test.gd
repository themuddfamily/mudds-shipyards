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

class StatusBindingProbe:
	extends RefCounted
	var snapshot: Dictionary = {}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

class PlanetaryCompositionProbe:
	extends Node
	var snapshot: Dictionary = {}
	var expedition_intent_sink := Callable()
	var started: Array[StringName] = []
	var abandoned: Array[StringName] = []
	var reject_next := false
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)
	func get_authored_hazard_presentation_snapshot() -> Dictionary:
		return {}
	func configure_caldera_expedition_intent_sink(sink: Callable) -> Dictionary:
		expedition_intent_sink = sink
		return {"accepted": true, "reason": &"caldera_expedition_intent_sink_configured"}
	func start_caldera_expedition(activity_id: StringName) -> Dictionary:
		if reject_next:
			return {"accepted": false, "reason": &"caldera_expedition_unavailable"}
		started.append(activity_id)
		return {"accepted": true, "reason": &"activity_started"}
	func abandon_caldera_expedition(
			activity_id: StringName, reason: StringName = &"player_abandoned"
		) -> Dictionary:
		abandoned.append(activity_id)
		return {"accepted": true, "reason": reason}
	func get_caldera_expedition_snapshot() -> Dictionary:
		return {"world_id": &"ember_moon", "activities": {}}

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
	var planetary := PlanetaryCompositionProbe.new()
	var ship_identity := Node.new()
	var player_identity := Node.new()
	director.name = "AudioDirector"
	hud.name = "HUD"
	host.name = "EmberSurfaceLoopHost"
	production.name = "EmberSurfaceLoopProductionBinding"
	planetary.name = "PlanetaryCompositionProbe"
	ship_identity.name = "ShipIdentityProbe"
	player_identity.name = "PlayerIdentityProbe"
	flow.add_child(director)
	flow.add_child(hud)
	flow.add_child(host)
	flow.add_child(production)
	production.add_child(planetary)
	flow.add_child(ship_identity)
	flow.add_child(player_identity)
	flow.set("audio", director)
	flow.set("hud", hud)
	flow.set("ember_surface_loop_host", host)
	flow.set("ember_surface_loop_production_binding", production)
	host.set("_attached", true)
	host.set("_generation", 1)
	host.set("_attachment_generation", 1)
	host.set("_ship_instance_id", ship_identity.get_instance_id())
	host.set("_player_instance_id", player_identity.get_instance_id())
	production.set("_configured", true)
	production.set("_generation", 1)
	production.set("_host", host)
	production.set("_host_instance_id", host.get_instance_id())
	production.set("_ship_instance_id", ship_identity.get_instance_id())
	production.set("_player_instance_id", player_identity.get_instance_id())
	production.set("_planetary_composition", planetary)
	planetary.snapshot = {
		"state": &"bound",
		"host_generation": 1,
		"attachment_generation": 1,
	}
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
	_check(
		bool(attached.get("accepted", false))
		and attached.get("reason", &"") == &"attached",
		"GameFlow composes the authenticated idle Host without seizing the route row",
	)
	_check(detail != null and not ordinary_detail.is_empty() and detail.text == ordinary_detail, "idle Ember observation leaves ordinary route fallback external")
	var audio_composition := flow.get("_ember_surface_loop_audio_composition") as Node
	var status_binding := flow.get("_ember_surface_return_status_binding") as RefCounted
	var hud_adapter := flow.get("_ember_surface_return_hud_adapter") as RefCounted
	var identities := [audio_composition.get_instance_id(), status_binding.get_instance_id(), hud_adapter.get_instance_id()]
	_check(director.get_semantic_audio_binding_count() == 1, "one planetary semantic source is registered")
	_check((flow.call("_ensure_ember_surface_presentations") as Dictionary).reason == &"already_attached" and director.get_semantic_audio_binding_count() == 1, "repeated ensure cannot duplicate the planetary source")

	host.set("_phase", HostType.Phase.DESCENT)
	production._finish_late_signal(&"integration_phase_changed")
	_check(detail.text.contains("DESCENT // ENTERING"), "surface descent overrides the existing route row")
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
	production.set("_generation", 2)
	planetary.snapshot.host_generation = 2
	planetary.snapshot.attachment_generation = 2
	var reattached := flow.call("_ensure_ember_surface_presentations") as Dictionary
	_check(bool(reattached.get("accepted", false)), "re-entry restores the production presentation composition")
	_check([audio_composition.get_instance_id(), status_binding.get_instance_id(), hud_adapter.get_instance_id()] == identities, "re-entry preserves all three exact presentation identities")
	_check(director.get_semantic_audio_binding_count() == 1, "re-entry restores exactly one planetary semantic source")
	host.set("_phase", HostType.Phase.ASCENT)
	production._finish_late_signal(&"integration_phase_changed")
	_check(detail.text.contains("EMBER RETURN // ASCENT"), "fresh re-entry updates the surface HUD once")
	_check(_cues.count(&"ember_surface_ascent_exterior") == 1, "fresh re-entry reaches AudioDirector once")
	_test_in_range_minimap_markers()
	_test_caldera_expedition_intent_seam(flow, production, planetary)

	flow.queue_free()
	await process_frame
	_finish()


func _on_semantic_cue(
	_source_id: StringName, cue_id: StringName, _intensity: float, _position: Vector3
) -> void:
	_cues.append(cue_id)


func _test_in_range_minimap_markers() -> void:
	var flow := FlowProbe.new()
	var binding := StatusBindingProbe.new()
	binding.snapshot = {
		"attached": true,
		"view": {
			"accepted": true,
			"attached": true,
			"presentation_only": true,
			"generation": 7,
			"route_guidance": {
				"available": true,
				"target_position": Vector3(24.0, 120000.0, -18.0),
				"navigation_authority": false,
			},
			"optional_objectives": {
				"available": true,
				"nearest_incomplete": {
					"position_body_local_m": Vector3(-17.5, 120000.0, -17.5),
				},
				"navigation_authority": false,
			},
		},
	}
	flow.set("_ember_surface_return_status_binding", binding)
	var markers := flow._get_ember_surface_minimap_markers(23)
	var route := _find_marker(markers, &"active_ember_surface_route")
	var side_task := _find_marker(markers, &"active_ember_side_task")
	_check(
		markers.size() == 2
		and (route.get("position", Vector3.INF) as Vector3) \
			.is_equal_approx(Vector3(24.0, 120000.0, -18.0))
		and (side_task.get("position", Vector3.INF) as Vector3) \
			.is_equal_approx(Vector3(-17.5, 120000.0, -17.5))
		and int(route.get("generation", -1)) == 23
		and int(side_task.get("generation", -1)) == 23,
		"authenticated in-range Ember route and nearest side task join the minimap frame",
	)
	(binding.snapshot.view.route_guidance as Dictionary).available = false
	(binding.snapshot.view.optional_objectives as Dictionary).nearest_incomplete = {}
	_check(
		flow._get_ember_surface_minimap_markers(24).is_empty(),
		"withdrawn Ember guidance cannot leave an in-range minimap target",
	)
	flow.free()


## The authored trailhead offer points can only ask; this owner answers. The
## press must land on the same public `begin_/abandon_ember_caldera_expedition`
## seams an external caller would use, and nothing else may get through.
func _test_caldera_expedition_intent_seam(
		flow: FlowProbe, production: ProductionType,
		planetary: PlanetaryCompositionProbe
	) -> void:
	_check(
		planetary.expedition_intent_sink.is_valid()
			and planetary.expedition_intent_sink.get_object() == flow
			and planetary.expedition_intent_sink.get_method() \
				== "_submit_ember_caldera_expedition_intent",
		"composing the Ember presentation installs GameFlow's own errand seam behind the offer points",
	)
	var begin_intent := {
		"action": &"begin",
		"activity_id": &"ember_lava_tube_sounding",
		"world_id": &"ember_moon",
	}
	var began: Dictionary = planetary.expedition_intent_sink.call(
		begin_intent.duplicate(true)
	)
	var abandoned: Dictionary = planetary.expedition_intent_sink.call({
		"action": &"abandon",
		"activity_id": &"ember_lava_tube_sounding",
		"world_id": &"ember_moon",
	})
	_check(
		bool(began.get("accepted", false))
			and bool(abandoned.get("accepted", false))
			and planetary.started.size() == 1
			and planetary.started[0] == &"ember_lava_tube_sounding"
			and planetary.abandoned.size() == 1
			and planetary.abandoned[0] == &"ember_lava_tube_sounding"
			and StringName(abandoned.get("reason", &"")) == &"player_abandoned",
		"one press each way reaches the retained errand owner exactly once through the public seams",
	)
	var refusals := [
		planetary.expedition_intent_sink.call("not a dictionary"),
		planetary.expedition_intent_sink.call({
			"action": &"begin", "activity_id": &"ember_beacon_survey",
			"world_id": &"ember_moon",
		}),
		planetary.expedition_intent_sink.call({
			"action": &"begin", "activity_id": &"ember_lava_tube_sounding",
			"world_id": &"cinder_reach",
		}),
		planetary.expedition_intent_sink.call({
			"action": &"complete", "activity_id": &"ember_lava_tube_sounding",
			"world_id": &"ember_moon",
		}),
	]
	var all_refused := true
	for refusal: Dictionary in refusals:
		if bool(refusal.get("accepted", true)) \
				or StringName(refusal.get("reason", &"")) \
					!= &"invalid_caldera_expedition_intent":
			all_refused = false
	_check(
		all_refused
			and planetary.started.size() == 1 and planetary.abandoned.size() == 1,
		"a malformed, foreign-world, foreign-activity or unknown-action intent starts nothing",
	)
	planetary.reject_next = true
	var refused_by_owner: Dictionary = planetary.expedition_intent_sink.call(
		begin_intent.duplicate(true)
	)
	planetary.reject_next = false
	_check(
		not bool(refused_by_owner.get("accepted", true))
			and StringName(refused_by_owner.get("reason", &"")) \
				== &"caldera_expedition_unavailable",
		"the errand owner's refusal is reported verbatim rather than being presented as a start",
	)
	planetary.expedition_intent_sink = Callable()
	flow.call("_ensure_ember_surface_presentations")
	_check(
		planetary.expedition_intent_sink.is_valid(),
		"an idempotent presentation pass restores the errand seam after re-entry",
	)
	var detached_flow := FlowProbe.new()
	_check(
		not bool(detached_flow._submit_ember_caldera_expedition_intent({
			"action": &"begin", "activity_id": &"ember_lava_tube_sounding",
			"world_id": &"ember_moon",
		}).get("accepted", true))
		and detached_flow.get_ember_caldera_expedition_report().is_empty(),
		"off Ember, with no surface binding, the same intent cannot start an errand",
	)
	detached_flow.free()
	# The probe's own counters, not GameFlow's, prove nothing was smuggled past
	# the seam while these refusals were being made.
	_check(
		production.get_caldera_expedition_snapshot().get("world_id", &"") \
			== &"ember_moon",
		"the retained production owner remains the single errand report source",
	)


func _find_marker(markers: Array[Dictionary], marker_id: StringName) -> Dictionary:
	for marker in markers:
		if StringName(marker.get("id", &"")) == marker_id:
			return marker.duplicate(true)
	return {}


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
