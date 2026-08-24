extends SceneTree

class FakeHost:
	extends RefCounted
	var snapshot: Dictionary = {
		"attached": true,
		"generation": 4,
		"attachment_generation": 2,
		"phase_id": &"descent",
		"actor_state": {
			"ship_position": Vector3(0.0, 120050.0, 0.0),
			"player_position": Vector3.ZERO,
		},
		"surface_route": {
			"egress_anchor": Vector3(300.0, 120000.0, 0.0),
			"staging_anchor": Vector3(-250.0, 120000.0, 0.0),
		},
	}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

class FakePlanetaryComposition:
	extends Node
	var snapshot := {
		"relay_survey_presentation": {
			"cue_mode": &"active_relay",
			"relay_anchor": Vector3(0.0, 120000.0, -400.0),
			"return_anchor": Vector3(-400.0, 120000.0, 0.0),
		},
	}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

const ProductionType := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const BindingType := preload("res://scripts/ui/ember_surface_return_status_binding.gd")
const AdapterType := preload("res://scripts/ui/ember_surface_return_hud_adapter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var production := ProductionType.new()
	var host := FakeHost.new()
	var planetary := FakePlanetaryComposition.new()
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	await process_frame
	root.add_child(production)
	production.add_child(planetary)
	production.set("_planetary_composition", planetary)
	await process_frame
	_check(hud.update_minimap({
		"schema_version": 1,
		"range_meters": 100.0,
		"center_position": Vector2.ZERO,
		"heading_radians": 0.0,
		"player_position": Vector2.ZERO,
		"topology_nodes": [],
		"topology_edges": [],
		"contacts": [],
	}), "real retained minimap accepts the caller-owned surface frame")
	var binding := BindingType.new()
	_check(bool(binding.attach(production, host, null, true).get("accepted", false)), "real Ember binding attaches before HUD adapter")
	var adapter := AdapterType.new()
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter attaches to existing HUD route seam")
	var detail := hud.get("_runtime_status_detail") as Label
	var landing_marker := hud.get_offscreen_route_marker()
	_check(
		detail != null and detail.text.contains("NEXT // LANDING PAD")
			and detail.text.contains("304.1 M")
			and str(adapter.get_snapshot().surface_route.message).contains("TRANSITION  //  STATIC")
			and landing_marker.route_kind == &"landing"
			and (landing_marker.direction as Vector2).is_equal_approx(Vector2.RIGHT)
			and bool(landing_marker.reduced_motion),
		"descent shows static landing-pad distance and off-screen direction in the retained HUD/minimap",
	)
	host.snapshot = {
		"attached": true,
		"generation": 5,
		"attachment_generation": 2,
		"phase_id": &"on_foot",
		"actor_state": {
			"ship_position": Vector3(300.0, 120000.0, 0.0),
			"player_position": Vector3(0.0, 120000.0, 0.0),
		},
		"surface_route": {
			"egress_anchor": Vector3(300.0, 120000.0, 0.0),
			"staging_anchor": Vector3(-250.0, 120000.0, 0.0),
		},
	}
	production.state_changed.emit({})
	var relay_marker := hud.get_offscreen_route_marker()
	_check(
		detail.text.contains("NEXT // RELAY // 400.0 M")
			and relay_marker.route_kind == &"surface_route"
			and (relay_marker.direction as Vector2).is_equal_approx(Vector2.UP)
			and not bool((adapter.get_snapshot().surface_route.route_guidance as Dictionary).navigation_authority),
		"on-foot phase derives relay distance and north-up direction from detached authoritative snapshots",
	)
	planetary.snapshot.relay_survey_presentation.cue_mode = &"return"
	host.snapshot.generation = 6
	production.state_changed.emit({})
	var return_marker := hud.get_offscreen_route_marker()
	_check(
		detail.text.contains("NEXT // RETURN ROUTE // 400.0 M")
			and (return_marker.direction as Vector2).is_equal_approx(Vector2.LEFT)
			and not bool(adapter.get_snapshot().surface_route.get("navigation_authority", true))
			and bool(adapter.get_snapshot().surface_route.get("reduced_flash_safe", false)),
		"survey return switches the retained marker without gaining navigation or flash authority",
	)
	var before_stale := detail.text
	host.snapshot.generation = 5
	production.state_changed.emit({})
	_check(detail.text == before_stale, "stale return generation cannot overwrite HUD")
	host.snapshot = {
		"attached": true,
		"generation": 7,
		"attachment_generation": 3,
		"phase_id": &"reboarded",
	}
	production.state_changed.emit({})
	var takeoff_cue := adapter.get_snapshot().surface_route.get("next_action", {}) as Dictionary
	_check(
		detail.text.contains("NEXT // TAKE OFF // EMBER RETURN // REBOARDED")
			and takeoff_cue.get("id", &"") == &"takeoff"
			and bool(takeoff_cue.get("focusable", false))
			and not bool(takeoff_cue.get("input_authority", true))
			and not bool(takeoff_cue.get("travel_authority", true)),
		"reboarded state gives controller players a focus-safe take-off cue without gaining input or travel authority",
	)
	before_stale = detail.text
	adapter.detach()
	_check(hud.get_offscreen_route_marker().is_empty(), "detach clears retained surface guidance")
	host.snapshot.generation = 8
	host.snapshot.attachment_generation = 3
	host.snapshot.phase_id = &"orbit_return"
	production.state_changed.emit({})
	_check(detail.text == before_stale and not bool(adapter.get_snapshot().attached), "detached adapter ignores source updates")
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter re-entry reconnects to binding")
	_check(detail.text.contains("NEXT // EMBER RETURN // ORBIT RETURN"), "re-entry applies current detached presenter view")
	adapter.detach()
	binding.detach()
	production.queue_free()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_HUD_ADAPTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)
