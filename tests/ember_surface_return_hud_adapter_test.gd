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
		"identities": {"player_instance_id": 101, "ship_instance_id": 202},
	}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

class FakePlanetaryComposition:
	extends Node
	var snapshot := {
		"state": &"bound",
		"host_generation": 4,
		"attachment_generation": 2,
		"relay_survey_presentation": {
			"cue_mode": &"active_relay",
			"relay_anchor": Vector3(0.0, 120000.0, -400.0),
			"return_anchor": Vector3(-400.0, 120000.0, 0.0),
		},
	}
	var hazard_snapshot: Dictionary = {}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)
	func get_authored_hazard_presentation_snapshot() -> Dictionary:
		return hazard_snapshot.duplicate(true)

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
	production.set("_configured", true)
	production.set("_generation", 4)
	production.set("_host_instance_id", host.get_instance_id())
	production.set("_player_instance_id", 101)
	production.set("_ship_instance_id", 202)
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
	var binding_attach := binding.attach(production, host, null, true)
	_check(bool(binding_attach.get("accepted", false)), "real Ember binding attaches before HUD adapter")
	var adapter := AdapterType.new()
	_check(bool(adapter.attach(binding, hud, production).get("accepted", false)), "adapter attaches to existing HUD route and authored-hazard seam")
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
		"identities": {"player_instance_id": 101, "ship_instance_id": 202},
	}
	production.set("_generation", 5)
	planetary.snapshot.host_generation = 5
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
	production.set("_generation", 6)
	planetary.snapshot.host_generation = 6
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
	production.set("_generation", 5)
	planetary.snapshot.host_generation = 5
	production.state_changed.emit({})
	_check(detail.text == before_stale, "stale return generation cannot overwrite HUD")
	var hazard_session := RefCounted.new()
	host.snapshot.generation = 6
	production.set("_generation", 6)
	planetary.snapshot.host_generation = 6
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 101, hazard_session.get_instance_id(),
		2, 6, 1, &"warning", true, &"current"
	)
	production.state_changed.emit({})
	_check(
		detail.text.contains("HAZARD // EXPOSURE RISING")
			and detail.text.contains("NEXT ACTION // MOVE CLEAR OF HAZARD")
			and bool(adapter.get_snapshot().hazard_active),
		"real authored Relay Arc warning receipt overlays the public surface HUD"
	)
	var warning_detail := detail.text
	var cached_route := binding.get_presenter_snapshot()
	cached_route["text"] = str(cached_route.get("text", "")) + "\nCACHE PROBE // LATEST ROUTE"
	binding.presentation_changed.emit(cached_route)
	_check(
		detail.text == warning_detail
			and str(adapter.get_snapshot().surface_route.message).contains(
				"CACHE PROBE // LATEST ROUTE"
			),
		"an active hazard keeps the public overlay while caching a same-generation route update"
	)
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 101, hazard_session.get_instance_id(),
		2, 6, 2, &"recovery_required", true, &"current"
	)
	production.state_changed.emit({})
	var presented_hazard := (hud.get("_surface_route_presenter") as RefCounted).call(
		"get_snapshot"
	) as Dictionary
	var has_recovery_action := false
	for action: Dictionary in presented_hazard.get("actions", []) as Array:
		if action.get("id", &"") == &"request_recovery":
			has_recovery_action = true
	_check(
		detail.text.contains("HAZARD // RECOVERY REQUIRED")
			and detail.text.contains("NEXT ACTION // RETURN TO THE STAGING RELAY")
			and (presented_hazard.actions as Array).size() == 2
			and not has_recovery_action,
		"latched recovery shows the truthful staging-relay action without a no-op recovery button"
	)
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 101, hazard_session.get_instance_id(),
		2, 6, 3, &"clear", false, &"current"
	)
	production.state_changed.emit({})
	_check(
		detail.text.contains("NEXT // RETURN ROUTE")
			and detail.text.contains("CACHE PROBE // LATEST ROUTE")
			and not bool(adapter.get_snapshot().hazard_active),
		"a real clear cursor restores the latest cached route without retiring the live attachment"
	)
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 101, hazard_session.get_instance_id(),
		2, 6, 4, &"warning", true, &"current"
	)
	production.state_changed.emit({})
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 0, hazard_session.get_instance_id(),
		2, 6, 5, &"warning", false, &"source_identity_lost"
	)
	production.state_changed.emit({})
	var runtime_panel := hud.get("_runtime_status_panel") as PanelContainer
	_check(
		not runtime_panel.visible and not bool(adapter.get_snapshot().hazard_active),
		"actor loss detaches the public hazard row instead of retaining stale recovery copy"
	)
	hazard_session = RefCounted.new()
	host.snapshot.generation = 7
	host.snapshot.attachment_generation = 3
	production.set("_generation", 7)
	planetary.snapshot.host_generation = 7
	planetary.snapshot.attachment_generation = 3
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 101, hazard_session.get_instance_id(),
		3, 7, 1, &"warning", true, &"current"
	)
	production.state_changed.emit({})
	_check(
		runtime_panel.visible and detail.text.contains("HAZARD // EXPOSURE RISING")
			and int(adapter.get_snapshot().authored_hazard.attachment_generation) == 3,
		"a newer attachment and session can publish a fresh warning without replaying retired copy"
	)
	host.snapshot = {
		"attached": true,
		"generation": 7,
		"attachment_generation": 3,
		"phase_id": &"reboarded",
		"identities": {"player_instance_id": 101, "ship_instance_id": 202},
	}
	production.set("_generation", 7)
	planetary.snapshot.host_generation = 7
	planetary.snapshot.attachment_generation = 3
	planetary.hazard_snapshot = _hazard_envelope(
		host.get_instance_id(), 101, hazard_session.get_instance_id(),
		3, 7, 2, &"clear", false, &"surface_lifecycle_inactive"
	)
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
	production.set("_generation", 8)
	planetary.snapshot.host_generation = 8
	production.state_changed.emit({})
	_check(detail.text == before_stale and not bool(adapter.get_snapshot().attached), "detached adapter ignores source updates")
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter re-entry reconnects to binding")
	_check(
		detail.text.contains("ORBIT RETURN")
			and detail.text.contains("COMPLETE RETURN HANDOFF"),
		"re-entry applies current detached presenter view"
	)
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


func _hazard_envelope(
		host_instance_id: int, actor_instance_id: int, session_instance_id: int,
		attachment_generation: int, generation: int, revision: int,
		state: StringName, visible: bool, reason: StringName
	) -> Dictionary:
	var recovery_required := state == &"recovery_required"
	return {
		"attached": actor_instance_id != 0 and reason == &"current",
		"reason": reason,
		"host_instance_id": host_instance_id,
		"actor_instance_id": actor_instance_id,
		"session_instance_id": session_instance_id,
		"attachment_generation": attachment_generation,
		"generation": generation,
		"revision": revision,
		"title": "EMBER SURFACE HAZARD",
		"message": "RELAY ARC EXPOSURE",
		"waypoints": [{
			"id": &"ember_staging_relay", "label": "Staging Relay",
			"distance_m": 4.0,
		}],
		"hazard": {
			"visible": visible,
			"state": state,
			"hazard_id": &"ember_relay_arc",
			"status_text": "Return to the staging relay" if recovery_required \
				else ("Electrical discharge zone" if state == &"warning" else "Clear"),
			"recovery_id": &"safe_recovery_at_staging_relay",
			"exposure_unitless": 0.86 if recovery_required \
				else (0.46 if state == &"warning" else 0.0),
			"recovery_request": {
				"requested": recovery_required, "movement_mutation": false,
			},
		},
		"presentation_only": true,
		"hazard_authority": false,
		"recovery_authority": false,
		"movement_authority": false,
		"input_authority": false,
	}.duplicate(true)
