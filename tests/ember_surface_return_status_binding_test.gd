extends SceneTree

class FakeProduction:
	extends RefCounted
	signal state_changed(snapshot: Dictionary)
	signal completion_handback_ready(receipt: Dictionary)
	var snapshot: Dictionary = {
		"generation": 4,
		"configured": true,
		"state_id": &"running",
		"identities": {},
		"planetary_surface": {
			"state": &"bound",
			"host_generation": 4,
			"attachment_generation": 2,
			"relay_survey_presentation": {
				"state": &"completed",
				"cue_mode": &"reward_confirmed",
			},
		},
	}
	var snapshot_count := 0
	var manifest: Dictionary = {
		"issued_generation": 8,
		"activity_id": &"ember_beacon_survey",
		"destination_id": &"mudds_shipyards",
	}
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return snapshot.duplicate(true)
	func get_planetary_relay_survey_return_manifest_snapshot() -> Dictionary:
		return manifest.duplicate(true)

class FakeHost:
	extends RefCounted
	var snapshot_count := 0
	var snapshot: Dictionary = {
		"attached": true,
		"host_id": &"ember_surface_loop",
		"generation": 4,
		"attachment_generation": 2,
		"phase_id": &"on_foot",
		"identities": {"player_instance_id": 41, "ship_instance_id": 42},
	}
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return snapshot.duplicate(true)

class ObservedProduction:
	extends FakeProduction
	var observation_count := 0
	func get_return_status_snapshot() -> Dictionary:
		observation_count += 1
		return snapshot.duplicate(true)

class ObservedHost:
	extends FakeHost
	func get_generation() -> int: return int(snapshot.generation)
	func get_attachment_generation() -> int: return int(snapshot.attachment_generation)
	var observation_count := 0
	func get_return_status_snapshot() -> Dictionary:
		observation_count += 1
		return snapshot.duplicate(true)

class CountingHost:
	extends EmberSurfaceLoopHost
	var snapshot_count := 0
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return super.get_snapshot()

class CountingProduction:
	extends EmberSurfaceLoopProductionBinding
	var snapshot_count := 0
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return super.get_snapshot()

class CountingPlanetary:
	extends EmberPlanetarySurfaceProductionBinding
	var snapshot_count := 0
	func get_snapshot() -> Dictionary:
		snapshot_count += 1
		return super.get_snapshot()

class LegacyPlanetary:
	extends Node
	var snapshot := {"state": &"bound", "nested": {"value": 1}}
	func get_snapshot() -> Dictionary:
		return snapshot

class DiagnosticPresenter:
	extends EmberSurfaceReturnStatusPresenter
	var saw_diagnostics := false
	func present(snapshot: Dictionary, reduced_motion: bool = false) -> Dictionary:
		saw_diagnostics = (snapshot.host as Dictionary).has("bootstrap") \
			and (snapshot.binding as Dictionary).has("entry_presentation") \
			and (snapshot.binding.planetary_surface as Dictionary).has("weather")
		return super.present(snapshot, reduced_motion)

const BindingType := preload("res://scripts/ui/ember_surface_return_status_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var legacy_production := FakeProduction.new()
	var legacy_host := FakeHost.new()
	var legacy_views := _run_contract(legacy_production, legacy_host)
	var observed_production := ObservedProduction.new()
	var observed_host := ObservedHost.new()
	var observed_views := _run_contract(observed_production, observed_host)
	_check(observed_views == legacy_views, "fresh observations preserve every full view across lifecycle and rejection cases")
	_check(legacy_production.snapshot_count > 0 and legacy_host.snapshot_count > 0, "legacy sources retain full snapshot fallback")
	_check(observed_production.snapshot_count == 0 and observed_host.snapshot_count == 0 \
		and observed_production.observation_count > 0 and observed_host.observation_count > 0,
		"status callbacks and receipt authentication skip full source diagnostics")
	_test_production_observations()
	_test_owner_notifications()
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _run_contract(production: FakeProduction, host: FakeHost) -> Array:
	var views: Array = []
	production.snapshot.identities = {
		"host_instance_id": host.get_instance_id(),
		"player_instance_id": 41,
		"ship_instance_id": 42,
	}
	var binding = BindingType.new()
	binding.presentation_changed.connect(func(view: Dictionary) -> void: views.append(view.duplicate(true)))
	_check(
		bool(binding.attach(production, host, null, true).get("accepted", false)),
		"binding accepts one exact live Host/production identity tuple",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	_sync(production, host, 5, &"surface_outbound", 2)
	_check_no_stage(
		binding,
		"pre-on-foot surface outbound does not claim survey completion",
	)
	_sync(production, host, 6, &"on_foot", 2)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	var missing_attachment := _manifest_receipt(8, 2)
	(missing_attachment.manifest as Dictionary).erase("attachment_generation")
	_check_rejection(
		binding.apply_return_manifest_receipt(missing_attachment),
		&"receipt_attachment_generation_missing",
		"manifest receipt without attachment scope is rejected",
	)
	_check_rejection(
		binding.apply_return_manifest_receipt(_manifest_receipt(99, 2)),
		&"foreign_receipt_activity_generation",
		"foreign activity generation cannot borrow the current attachment",
	)
	_check_rejection(
		binding.apply_return_manifest_receipt(_manifest_receipt(8, 1)),
		&"stale_receipt_generation",
		"foreign attachment generation cannot enter the return status",
	)
	_check(
		bool(binding.apply_return_manifest_receipt(
			_manifest_receipt(8, 2), true
		).get("accepted", false)),
		"exact activity and attachment receipt is accepted",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	production.snapshot.identities.host_instance_id = host.get_instance_id() + 1
	production.state_changed.emit({})
	_check_cleared(binding, "HOST INSTANCE MISMATCH", "wrong Host ID fails closed")
	production.snapshot.identities.host_instance_id = host.get_instance_id()
	production.state_changed.emit({})
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)
	production.snapshot.identities.player_instance_id = 99
	production.state_changed.emit({})
	_check_cleared(binding, "ACTOR IDENTITY MISMATCH", "wrong Player ID fails closed")
	production.snapshot.identities.player_instance_id = 41
	production.state_changed.emit({})
	production.snapshot.identities.ship_instance_id = 100
	production.state_changed.emit({})
	_check_cleared(binding, "ACTOR IDENTITY MISMATCH", "wrong ship ID fails closed")
	production.snapshot.identities.ship_instance_id = 42
	production.state_changed.emit({})
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	host.snapshot.generation = 7
	production.state_changed.emit({})
	_check_cleared(
		binding, "HOST PRODUCTION GENERATION MISMATCH",
		"independently advanced Host generation fails closed",
	)
	_sync(production, host, 7, &"on_foot", 2)
	(production.snapshot.planetary_surface as Dictionary).attachment_generation = 1
	production.state_changed.emit({})
	_check_cleared(
		binding, "PLANETARY ATTACHMENT GENERATION MISMATCH",
		"production surface attachment must pair with the Host attachment",
	)
	(production.snapshot.planetary_surface as Dictionary).attachment_generation = 2
	production.state_changed.emit({})
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	# Reuse carries deliberately stale survey and manifest snapshots. The exact
	# source tuple is current, but no return stage may survive without a fresh,
	# attachment-scoped and newly issued receipt.
	_sync(production, host, 8, &"on_foot", 3)
	_check_no_stage(
		binding,
		"attachment reuse clears retained survey and manifest stage evidence",
	)
	_check(
		(binding.get_snapshot().last_result as Dictionary).is_empty(),
		"attachment reuse clears the retained receipt",
	)
	_check_rejection(
		binding.apply_return_manifest_receipt(_manifest_receipt(8, 3)),
		&"replayed_receipt_activity_generation",
		"reuse rejects a re-scoped copy of the prior activity receipt",
	)
	production.manifest.issued_generation = 9
	_check(
		bool(binding.apply_return_manifest_receipt(
			_manifest_receipt(9, 3), true
		).get("accepted", false)),
		"reuse accepts a newly issued exact receipt for the current attachment",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	_sync(production, host, 9, &"boarding", 3)
	_check_stage(
		binding, &"reboard", 2, "COMPLETE REBOARD",
		"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED",
	)
	_sync(production, host, 10, &"reboarded", 3)
	_check_stage(
		binding, &"reboard", 2, "TAKE OFF",
		"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED",
	)
	_sync(production, host, 11, &"takeoff", 3)
	_check_stage(
		binding, &"takeoff", 3, "BEGIN ASCENT",
		"REMAIN SEATED WHILE TAKEOFF STATUS RECOVERS",
	)
	_sync(production, host, 12, &"ascent", 3)
	_check_stage(
		binding, &"ascent", 4, "REACH ORBIT",
		"CONTINUE THE STEADY CLIMB IF GUIDANCE IS INTERRUPTED",
	)
	_sync(production, host, 13, &"orbit_return", 3)
	_check_stage(
		binding, &"orbit", 5, "COMPLETE RETURN HANDOFF",
		"HOLD ORBIT WHILE THE MUDDS HANDOFF RECOVERS",
	)
	var before_stale := binding.get_presenter_snapshot()
	_sync(production, host, 12, &"takeoff", 3)
	_check(
		binding.get_presenter_snapshot() == before_stale,
		"coherent but stale source generations cannot overwrite orbit status",
	)

	_sync(production, host, 14, &"completed", 3)
	_check_no_stage(
		binding,
		"unmatched completed phase cannot claim terminal Mudds return",
	)
	var completion := {
		"reason": &"runtime_ownership_returned",
		"host_id": &"ember_surface_loop",
		"generation": 14,
		"retired_attachment_generation": 3,
		"current_attachment_generation": 4,
		"player_instance_id": 41,
		"ship_instance_id": 42,
		"host_attached": false,
		"command_source_restored": true,
		"boarding_reservation_retained": true,
		"player_seated": true,
		"ship_piloted": true,
	}
	host.snapshot.attached = false
	host.snapshot.attachment_generation = 4
	production.snapshot.state_id = &"handoff_pending"
	production.snapshot.completion_handback_pending = true
	var unmatched_handback := completion.duplicate(true)
	unmatched_handback.player_instance_id = 99
	production.snapshot.completion_handback = unmatched_handback
	# The planetary composition retains the exact retired attachment until the
	# caller consumes this handback.
	(production.snapshot.planetary_surface as Dictionary).attachment_generation = 3
	production.state_changed.emit({})
	_check_cleared(
		binding, "PLANETARY ATTACHMENT GENERATION MISMATCH",
		"detached completed phase with an unmatched handback fails closed",
	)
	production.snapshot.completion_handback = completion.duplicate(true)
	production.state_changed.emit({})
	_check_stage(
		binding, &"mudds_return", 6, "RETURN TO MUDDS SHIPYARDS",
		"MUDDS SHIPYARDS REMAINS THE MANIFEST DESTINATION",
	)
	_check(
		not bool(binding.get_presenter_snapshot().attached)
			and bool(binding.get_presenter_snapshot().completion_observed),
		"only the exact stored handback exposes terminal Mudds return",
	)

	production.completion_handback_ready.emit(unmatched_handback)
	_check((binding.get_snapshot().last_result as Dictionary).is_empty(),
		"forged completion signal cannot replace the stored exact handback")
	production.completion_handback_ready.emit(completion)
	_check(binding.get_snapshot().last_result == completion,
		"completion signal observes the exact fresh authenticated handback")
	completion.player_instance_id = 123
	_check(binding.get_snapshot().last_result.player_instance_id == 41,
		"accepted completion receipt is detached from the signal dictionary")

	binding.detach()
	_check(
		not bool(binding.get_snapshot().attached)
			and binding.get_presenter_snapshot().is_empty(),
		"detach clears all status evidence",
	)
	return views

func _test_production_observations() -> void:
	var production := CountingProduction.new()
	var host := CountingHost.new()
	var planetary := CountingPlanetary.new()
	production.set("_configured", true)
	production.set("_generation", 4)
	production.set("_host_instance_id", host.get_instance_id())
	production.set("_player_instance_id", 41)
	production.set("_ship_instance_id", 42)
	production.set("_planetary_composition", planetary)
	host.set("_generation", 4)
	host.set("_attachment_generation", 2)
	host.set("_attached", true)
	host.set("_phase", EmberSurfaceLoopHost.Phase.ON_FOOT)
	host.set("_player_instance_id", 41)
	host.set("_ship_instance_id", 42)
	planetary.set("_state", EmberPlanetarySurfaceProductionBinding.State.BOUND)
	planetary.set("_host_generation", 4)
	planetary.set("_attachment_generation", 2)
	var status := BindingType.new()
	_check(status.attach(production, host).accepted, "actual production observation methods authenticate the built-in status binding")
	var initial_view := status.get_presenter_snapshot()
	_check(not production.state_changed.has_connections() and production.state_invalidated.has_connections(),
		"built-in status uses only lightweight invalidation")
	for index in range(5):
		production._finish_late_signal(&"test_observation")
	_check(status.get_presenter_snapshot() == initial_view, "forged signal payloads cannot replace fresh production observations")
	_check(production.snapshot_count == 0 and host.snapshot_count == 0 and planetary.snapshot_count == 0,
		"six built-in UI publications construct zero full production, Host or planetary diagnostics")
	print("RETURN_STATUS_DIAGNOSTICS publications=6 production=0 host=0 planetary=0")
	var production_full := production.get_snapshot()
	var host_full := host.get_snapshot()
	_check_projection(production.get_return_status_snapshot(), production_full, "production")
	_check_projection(production.get_audio_presentation_snapshot(), production_full, "audio")
	_check_projection(host.get_return_status_snapshot(), host_full, "Host")
	var observed := production.get_return_status_snapshot()
	observed.identities.player_instance_id = -1
	observed.planetary_surface.state = &"tampered"
	_check(production.get_return_status_snapshot().identities.player_instance_id == 41 \
		and production.get_return_status_snapshot().planetary_surface.state == &"bound",
		"fresh observations are detached from authoritative state")
	var custom := DiagnosticPresenter.new()
	var legacy_status := BindingType.new()
	_check(legacy_status.attach(production, host, custom).accepted and custom.saw_diagnostics,
		"custom presenter subclasses retain complete production and Host diagnostics")
	_check(legacy_status.get_presenter_snapshot() == initial_view,
		"actual narrow-source presentation equals the full diagnostic presentation")
	legacy_status.detach()
	_check(legacy_status.attach(production, host, EmberSurfaceReturnStatusPresenter.new()).accepted,
		"explicitly injected built-in presenter retains the full-report contract")
	var diagnostics_before := production.snapshot_count
	production.state_changed.emit({})
	_check(production.snapshot_count == diagnostics_before + 1,
		"only the explicitly injected presenter constructs a full report on the shared signal")
	legacy_status.detach()
	status.detach()
	_check(not production.state_invalidated.has_connections() and not production.state_changed.has_connections(),
		"detach releases both notification routes")
	var legacy_planetary := LegacyPlanetary.new()
	production.set("_planetary_composition", legacy_planetary)
	var legacy_observation := production.get_return_status_snapshot()
	legacy_observation.planetary_surface.nested.value = -1
	_check(legacy_planetary.snapshot.nested.value == 1,
		"legacy composition fallback preserves detached nested data")
	legacy_planetary.free()
	production.set("_planetary_composition", null)
	production.free()
	host.free()
	planetary.free()

func _test_owner_notifications() -> void:
	var production := CountingProduction.new()
	var planetary := CountingPlanetary.new()
	var host := ObservedHost.new()
	var bunker := EmberSurveyBunkerInteractionBinding.new()
	var rack := EmberSampleRackInteractionBinding.new()
	var bunker_marker := MeshInstance3D.new()
	var rack_marker := Label3D.new()
	var response_body := StaticBody3D.new()
	bunker.add_child(bunker_marker)
	bunker.add_child(response_body)
	rack.add_child(rack_marker)
	for interaction: Node in [bunker, rack]:
		interaction.set("_configured", true)
		interaction.set("_attached", true)
		interaction.set("_host", host)
		interaction.set("_host_generation", 4)
		interaction.set("_attachment_generation", 2)
	bunker.set("_marker", bunker_marker)
	bunker.set("_response_body", response_body)
	bunker.set("_completed", true)
	rack.set("_marker", rack_marker)
	rack.set("_activity_generation", 1)
	rack.set("_activity_state_source", func(generation: int) -> bool: return generation == 1)
	planetary.set("_survey_interaction", bunker)
	planetary.set("_sample_rack_interaction", rack)
	production.set("_planetary_composition", planetary)
	production._finish_late_signal(&"host_advanced")
	_check(bunker.collision_layer == bunker.INTERACTION_LAYER and bunker_marker.visible \
		and response_body.collision_layer == bunker.WORLD_LAYER \
		and rack.collision_layer == rack.INTERACTION_LAYER and rack_marker.visible,
		"unobserved late boundary activates current bunker, alcove and rack physical presentation")
	host.snapshot.phase_id = &"reboarded"
	production._finish_late_signal(&"host_advanced")
	_check(bunker.collision_layer == 0 and not bunker_marker.visible \
		and response_body.collision_layer == 0 and rack.collision_layer == 0 and not rack_marker.visible,
		"unobserved phase exit clears marker and collision state before any diagnostic read")
	_check(production.snapshot_count == 0 and planetary.snapshot_count == 0,
		"owner physical refresh constructs no full binding or composition diagnostics")
	var nested: Array = []
	var invalidated := func() -> void:
		nested.append(production.queue_disembark_intent(1, production.get_generation()))
	production.state_invalidated.connect(invalidated)
	production._fail_late(&"test_failure")
	_check(nested.size() == 1 and nested[0].reason == &"reentrant_call" \
		and nested[0].state_id == &"failed",
		"failure invalidation rejects nested mutation under the original dispatch guard")
	production.state_invalidated.disconnect(invalidated)
	var reports: Array = []
	var listener := func(report: Dictionary) -> void: reports.append(report)
	production.state_changed.connect(listener)
	var full_before := production.snapshot_count
	production._finish_late_signal(&"test_observed")
	_check(production.snapshot_count == full_before + 1 and reports.size() == 1 \
		and reports[0].has("entry_presentation") and reports[0].planetary_surface.has("weather"),
		"actual full-report listener receives one complete diagnostic payload")
	reports[0].pending_envelope["tampered"] = true
	_check((production.get("_pending_envelope") as Dictionary).is_empty(),
		"observed signal dictionary remains detached from live state")
	production.state_changed.disconnect(listener)
	production.free()
	planetary.free()
	bunker.free()
	rack.free()

func _check_projection(observed: Dictionary, full: Dictionary, label: String) -> void:
	for key: Variant in observed:
		_check(full.has(key), label + " retains " + str(key))
		if observed[key] is Dictionary and full.get(key) is Dictionary:
			_check_projection(observed[key], full[key], label + "." + str(key))
		else:
			_check(observed[key] == full.get(key), label + "." + str(key) + " matches full diagnostics")

func _manifest_receipt(activity_generation: int, attachment_generation: int) -> Dictionary:
	return {
		"accepted": true,
		"reason": &"return_manifest_ready",
		"manifest": {
			"activity_id": &"ember_beacon_survey",
			"activity_generation": activity_generation,
			"attachment_generation": attachment_generation,
			"destination_id": &"mudds_shipyards",
		},
	}.duplicate(true)

func _sync(
		production: FakeProduction, host: FakeHost, generation: int,
		phase: StringName, attachment_generation: int
	) -> void:
	host.snapshot.attached = true
	host.snapshot.generation = generation
	host.snapshot.attachment_generation = attachment_generation
	host.snapshot.phase_id = phase
	production.snapshot.generation = generation
	production.snapshot.state_id = &"running"
	production.snapshot.completion_handback_pending = false
	production.snapshot.completion_handback = {}
	var planetary := production.snapshot.planetary_surface as Dictionary
	planetary.host_generation = generation
	planetary.attachment_generation = attachment_generation
	production.state_changed.emit({})

func _check_stage(
		binding: RefCounted, stage: StringName, step: int,
		next_action: String, recovery: String
	) -> void:
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	var status := view.get("return_status", {}) as Dictionary
	var action := view.get("next_action", {}) as Dictionary
	var visible_title := str(view.get("visible_title", ""))
	_check(
		visible_title.begins_with("EMBER [")
			and visible_title.length() <= 40
			and str(view.get("text", "")).begins_with(visible_title + "\n"),
		"%s keeps its complete state meaning in the retained title line" % stage,
	)
	_check(
		status.get("stage", &"") == stage
			and int(status.get("step", 0)) == step
			and int(status.get("step_count", 0)) == 6
			and status.get("next_action", "") == next_action
			and status.get("recovery", "") == recovery,
		"%s has a stable numbered next-action and recovery meaning" % stage,
	)
	_check(
		view.text.contains("RETURN STEP  //  %d OF 6" % step)
			and view.text.contains("NEXT ACTION  //  " + next_action)
			and view.text.contains("RECOVERY  //  " + recovery)
			and bool(status.get("steady", false))
			and bool(status.get("color_independent", false))
			and bool(view.get("reduced_flash_safe", false))
			and not bool(view.get("flash_requested", true)),
		"%s remains readable without colour, motion, or flashing" % stage,
	)
	_check(
		not bool(action.get("input_authority", true))
			and not bool(action.get("travel_authority", true))
			and not bool(action.get("boarding_authority", true))
			and not bool(action.get("reward_authority", true))
			and not bool(view.get("input_authority", true))
			and not bool(view.get("travel_authority", true))
			and not bool(view.get("boarding_authority", true))
			and not bool(view.get("reward_authority", true)),
		"%s presentation cannot advance the return loop" % stage,
	)

func _check_no_stage(binding: RefCounted, message: String) -> void:
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	_check(
		(view.get("return_status", {}) as Dictionary).is_empty()
			and not str(view.get("text", "")).contains("RETURN STEP  //"),
		message,
	)

func _check_cleared(binding: RefCounted, reason: String, message: String) -> void:
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	_check(
		view.get("state", &"") == &"rejected"
			and view.get("visible_title", "") == "EMBER [---] DETACHED: WAIT SESSION"
			and not str(view.get("visible_title", "")).contains("REJECTED")
			and (view.get("return_status", {}) as Dictionary).is_empty()
			and str(view.get("text", "")).contains(reason),
		message,
	)

func _check_rejection(result: Dictionary, reason: StringName, message: String) -> void:
	_check(
		not bool(result.get("accepted", true))
			and StringName(result.get("reason", &"")) == reason,
		message,
	)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)
