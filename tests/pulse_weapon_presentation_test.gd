extends SceneTree

const PRESENTATION_SCENE := preload("res://scenes/effects/pulse_weapon_presentation.tscn")
const FINISHED_REENTRY_ORIGIN := Vector3(31.0, 7.0, -9.0)
const FINISHED_REENTRY_END := Vector3(31.0, 7.0, -89.0)
const IMPACT_REENTRY_ORIGIN := Vector3(-27.0, 11.0, 8.0)
const IMPACT_REENTRY_END := Vector3(16.0, 13.0, -72.0)
const ADVANCE_CUTOFF_REENTRY_ORIGIN := Vector3(42.0, 3.0, 17.0)
const ADVANCE_CUTOFF_REENTRY_END := Vector3(42.0, 3.0, 16.0)
const RECYCLE_ORDER_REENTRY_ORIGIN := Vector3(-36.0, 8.0, 14.0)
const RECYCLE_ORDER_REENTRY_END := Vector3(-36.0, 8.0, 13.0)

var _assertions := 0
var _failures: Array[String] = []
var _shot_events: Array[Dictionary] = []
var _finished_shot_ids: Array[int] = []
var _impact_events: Array[Dictionary] = []
var _recycle_events: Array[Vector2i] = []
var _clear_events := 0
var _finished_reentry_armed := false
var _finished_reentry_attempted := false
var _finished_reentry_accepted := false
var _finished_reentry_signal_ids: Array[int] = []
var _impact_reentry_armed := false
var _impact_reentry_attempted := false
var _impact_reentry_accepted := false
var _impact_reentry_signal_ids: Array[int] = []
var _advance_cutoff_reentry_armed := false
var _advance_cutoff_reentry_attempted := false
var _advance_cutoff_reentry_accepted := false
var _advance_cutoff_reentry_events: Array[String] = []
var _recycle_order_reentry_armed := false
var _recycle_order_reentry_attempted := false
var _recycle_order_reentry_accepted := false
var _recycle_order_reentry_events: Array[String] = []
var _aborted_receipt_ids: Array[int] = []
var _abort_reentry_armed := false
var _abort_reentry_attempted := false
var _abort_reentry_accepted := false
var _abort_reentry_presentation: PulseWeaponPresentation


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var host := Node3D.new()
	host.name = "PulseWeaponPresentationTestWorld"
	host.transform = Transform3D(
		Basis(Vector3.UP, 0.38).scaled(Vector3(1.35, 0.82, 1.12)),
		Vector3(14.0, 6.0, -23.0)
	)
	root.add_child(host)

	var presentation := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	_check(presentation != null, "typed pulse presentation scene instantiates")
	if presentation == null:
		await _clean_up(host)
		_finish()
		return
	presentation.set_auto_advance_enabled(false)
	_check(
		not presentation.present_shot(Vector3.ZERO, Vector3.FORWARD * 10.0),
		"pre-tree presentation requests are rejected without allocating"
	)
	presentation.shot_presented.connect(_on_shot_presented)
	presentation.shot_finished.connect(_on_shot_finished)
	presentation.impact_started.connect(_on_impact_started)
	presentation.impact_receipt_aborted.connect(_on_impact_receipt_aborted)
	presentation.shot_recycled.connect(_on_shot_recycled)
	presentation.effects_cleared.connect(_on_effects_cleared)
	host.add_child(presentation)
	await process_frame

	_check(
		presentation.is_in_group(&"pulse_weapon_presentation")
		and get_nodes_in_group(&"pulse_weapon_presentation").has(presentation),
		"scene exposes stable discovery-group membership"
	)
	_check(not presentation.is_processing(), "idle manually advanced pool performs no frame work")
	var audit := presentation.get_audit_report()
	_check(bool(audit.valid), "fresh component passes lifecycle, structure, resource, and budget audit")
	_check(audit.component_id == &"pulse-weapon-presentation", "audit publishes a stable component identifier")
	_check(audit.evidence_status == &"modern_interpretation", "weapon visuals are explicitly a modern interpretation")
	var evidence := audit.evidence as Dictionary
	_check(bool(evidence.source_bounded), "evidence metadata is explicitly source bounded")
	_check(not bool(evidence.historically_supported), "presentation makes no unsupported historical claim")
	_check(not bool(evidence.authenticated_original_weapon_effect), "presentation rejects authenticated-effect status")
	_check(
		(evidence.modern_interpretations as PackedStringArray).size() >= 5,
		"evidence inventories each major modern presentation choice"
	)
	_check(
		str(presentation.get_meta("modern_interpretation", "")) == "pulse_weapon_visual_presentation"
		and bool(presentation.get_meta("presentation_only", false))
		and not bool(presentation.get_meta("gameplay_authority", true)),
		"root metadata marks the component modern and non-authoritative"
	)

	var integration := presentation.get_integration_contract()
	_check(integration.coordinate_space == &"world_space", "integration contract accepts world-space endpoints")
	_check(
		integration.authority_policy == &"external_hitscan_authority_presentation_only"
		and integration.hit_policy == &"caller_supplied_boolean_no_collision_query",
		"integration contract leaves hitscan and hit authority with the caller"
	)
	_check(
		integration.audio_policy == &"none_voice_free_caller_owned"
		and integration.particle_policy == &"none_deterministic_mesh_sparks",
		"integration contract is voice-free and deterministic"
	)
	_check(
		integration.pool_policy == &"fixed_preallocated_oldest_visual_recycled_when_saturated"
		and int(integration.pool_capacity) == 6,
		"default component declares a fixed six-shot oldest-recycle pool"
	)
	_check(
		integration.allocation_policy == &"no_node_or_resource_allocation_during_present_or_advance",
		"hot-path allocation policy is explicit"
	)
	var styles := presentation.get_supported_style_ids()
	_check(
		styles == [&"cyan", &"amber", &"magenta"],
		"component exposes three stable presentation style IDs"
	)
	styles.clear()
	_check(presentation.get_supported_style_ids().size() == 3, "supported-style arrays are detached from component state")

	var performance := presentation.get_performance_audit()
	var counts := performance.counts as Dictionary
	var budgets := performance.budgets as Dictionary
	print("PULSE_WEAPON_PRESENTATION_PERFORMANCE: ", performance)
	_check(bool(performance.within_budget), "fresh pool remains within every strict effect budget")
	_check(int(counts.node_count) == 86 and int(budgets.node_count) == 86, "six slots allocate exactly eighty-six total nodes")
	_check(int(counts.mesh_instances) == 66 and int(counts.lights) == 12, "pool has exact immutable mesh and light counts")
	_check(
		int(counts.collision_nodes) == 0 and int(counts.physics_query_nodes) == 0,
		"component contains no collision bodies, shapes, raycasts, or shapecasts"
	)
	_check(
		int(counts.audio_nodes) == 0
		and int(counts.particle_emitters) == 0
		and int(counts.animation_players) == 0,
		"component contains no audio, particle, or animation authority"
	)
	_check(
		int(performance.resident_mesh_resources) == 2
		and int(performance.resident_style_materials) == 9
		and not bool(performance.runtime_node_allocation)
		and not bool(performance.runtime_resource_allocation),
		"all visuals share two meshes plus three core and six atlas materials"
	)
	_check(
		bool(performance.uses_external_assets)
		and performance.external_asset_path == "res://assets/effects/mudds-combat-vfx-atlas-v1.png"
		and performance.external_asset_sha256 == "e748314a287112a11f809b417fa262b184199715f029b0915b63ca8ccecd3aac",
		"audit pins the exact project-original combat VFX atlas"
	)
	_check(_all_generated_nodes_are_presentational(presentation), "every generated child carries presentation-only metadata")

	# Invalid geometry, unsupported styles, and disabled lifecycle fail closed.
	var rejected_before := int(presentation.get_statistics().rejected)
	_check(
		not presentation.present_shot(Vector3.ZERO, Vector3.ZERO),
		"zero-length geometry is rejected"
	)
	_check(
		not presentation.present_shot(Vector3(NAN, 0.0, 0.0), Vector3.FORWARD),
		"non-finite origin is rejected"
	)
	_check(
		not presentation.present_shot(Vector3.ZERO, Vector3(INF, 0.0, 0.0)),
		"non-finite endpoint is rejected"
	)
	_check(
		not presentation.present_shot(Vector3.ZERO, Vector3.RIGHT * 2501.0),
		"geometry beyond the bounded maximum is rejected"
	)
	_check(
		not presentation.present_shot(Vector3.ZERO, Vector3.FORWARD * 12.0, &"unsupported"),
		"unknown style IDs are rejected rather than silently remapped"
	)
	_check(
		int(presentation.get_statistics().rejected) == rejected_before + 5
		and presentation.get_active_effect_count() == 0,
		"invalid requests affect only rejection telemetry"
	)
	_check(
		not presentation.advance_simulation(0.0)
		and not presentation.advance_simulation(-0.1)
		and not presentation.advance_simulation(NAN),
		"invalid simulation deltas fail closed"
	)

	# A miss begins with a visible muzzle flash, moving pulse, and short dashes.
	var source := Node3D.new()
	source.name = "WeaponSourceFixture"
	host.add_child(source)
	var source_id := source.get_instance_id()
	var miss_origin := Vector3(-8.0, 4.5, 13.0)
	var miss_end := Vector3(19.0, 7.0, -41.0)
	_check(
		presentation.present_shot(miss_origin, miss_end, &"cyan", source, false),
		"valid miss request enters the pool"
	)
	_check(_shot_events.size() == 1, "accepted request emits one presentation event")
	if not _shot_events.is_empty():
		var event := _shot_events[0]
		_check(
			event.style_id == &"cyan"
			and int(event.source_instance_id) == source_id
			and not bool(event.hit),
			"presentation event reports style, optional source ID, and miss state"
		)
	var snapshots := presentation.get_active_shot_snapshots()
	_check(snapshots.size() == 1, "one accepted request owns one active pooled effect")
	var miss_state := snapshots[0] if not snapshots.is_empty() else {}
	_check(
		(miss_state.get("origin", Vector3.ZERO) as Vector3).is_equal_approx(miss_origin)
		and (miss_state.get("end", Vector3.ZERO) as Vector3).is_equal_approx(miss_end),
		"snapshot preserves exact authoritative world endpoints"
	)
	_check(
		bool(miss_state.get("pulse_visible", false))
		and int(miss_state.get("visible_beam_segments", 0)) >= 1
		and _count_visible_named(presentation, "MuzzleFlash") == 1,
		"shot begins with a visible muzzle flash, pulse, and bounded beam dash"
	)
	_check(
		_count_visible_named(presentation, "ImpactFlare") == 0
		and _count_visible_named(presentation, "ImpactBackwash") == 0
		and _count_visible_prefix(presentation, "ImpactSpark") == 0,
		"miss request never shows premature impact visuals"
	)
	var pulse_position_before_host_motion := miss_state.get("pulse_position", Vector3.ZERO) as Vector3
	host.position += Vector3(70.0, -11.0, 36.0)
	miss_state = presentation.get_active_shot_snapshots()[0]
	_check(
		(miss_state.pulse_position as Vector3).is_equal_approx(pulse_position_before_host_motion),
		"top-level pooled visual remains at submitted world geometry when its owner moves"
	)
	_check(presentation.advance_simulation(0.04), "manual clock advances a live miss")
	miss_state = presentation.get_active_shot_snapshots()[0]
	_check(
		float(miss_state.travel_progress) > 0.0
		and not (miss_state.pulse_position as Vector3).is_equal_approx(pulse_position_before_host_motion),
		"travelling pulse advances along the hitscan rather than spanning it"
	)
	_check(
		int(miss_state.visible_beam_segments) <= 3,
		"travelling beam never exceeds three short allocated segments"
	)
	source.queue_free()
	await process_frame
	_check(
		int(presentation.get_active_shot_snapshots()[0].source_instance_id) == source_id
		and bool(presentation.get_audit_report().valid),
		"source destruction is safe because only its non-authoritative ID is retained"
	)

	var clear_before := _clear_events
	presentation.clear_effects()
	_check(
		presentation.get_active_effect_count() == 0
		and _count_visible_effect_nodes(presentation) == 0
		and not presentation.is_processing(),
		"explicit cleanup synchronously hides the entire reusable pool"
	)
	_check(_clear_events == clear_before + 1, "explicit cleanup emits a completion event")

	# A hit changes presentation only after the travelling pulse reaches the end.
	var hit_origin := Vector3(2.0, 3.0, 4.0)
	var hit_end := Vector3(2.0, 3.0, -20.0)
	_check(
		presentation.present_shot(hit_origin, hit_end, &"amber", null, true),
		"valid hit request enters the same pool without a source entity"
	)
	var hit_state := presentation.get_active_shot_snapshots()[0]
	var travel_duration := float(hit_state.travel_duration)
	_check(not bool(hit_state.impact_visible), "impact remains hidden during pulse travel")
	var impacts_before := _impact_events.size()
	presentation.advance_simulation(travel_duration + 0.01)
	hit_state = presentation.get_active_shot_snapshots()[0]
	_check(
		not bool(hit_state.pulse_visible) and bool(hit_state.impact_visible),
		"hit swaps travelling pulse for endpoint impact after travel"
	)
	_check(
		_impact_events.size() == impacts_before + 1
		and (_impact_events.back() as Dictionary).position == hit_end,
		"hit emits one endpoint impact event exactly when the travelling pulse arrives"
	)
	presentation.advance_simulation(0.01)
	_check(_impact_events.size() == impacts_before + 1, "visible impact continuation never repeats its one-shot event")
	_check(
		_count_visible_named(presentation, "ImpactFlare") == 1
		and _count_visible_named(presentation, "ImpactBackwash") == 1
		and _count_visible_prefix(presentation, "ImpactSpark") == 4,
		"hit exposes one flare, one directional backwash, and four deterministic mesh sparks"
	)
	var backwash := presentation.get_node_or_null(
		"PoolRoot/ShotSlot01/ImpactBackwash"
	) as MeshInstance3D
	_check(
		bool(hit_state.get("impact_backwash_visible", false))
		and backwash != null
		and backwash.global_position.z > hit_end.z
		and backwash.transparency >= 0.0
		and backwash.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"impact backwash points from the endpoint toward the incoming shot and remains shadowless"
	)
	performance = presentation.get_performance_audit()
	counts = performance.counts as Dictionary
	_check(
		int(counts.visible_meshes) <= 6 and int(counts.visible_lights) <= 1,
		"single hit remains inside its strict simultaneous visible-effect budget"
	)
	_check(presentation.advance_simulation(0.3), "large finite step advances and expires a hit safely")
	_check(
		presentation.get_active_effect_count() == 0 and _count_visible_effect_nodes(presentation) == 0,
		"hit flare and sparks self-clean after their fixed lifetime"
	)
	_check(not _finished_shot_ids.is_empty(), "natural and explicit slot retirement reports finished shot IDs")

	# A single hitch that crosses the whole effect must still publish the accepted
	# endpoint before completion. Visual loss cannot silently suppress audio or a
	# deferred target-presentation receipt.
	var hitch_impacts_before := _impact_events.size()
	var hitch_finished_before := _finished_shot_ids.size()
	_check(
		presentation.present_shot(Vector3.ZERO, Vector3.FORWARD, &"cyan", null, true),
		"hitch regression accepts a minimum-duration hit"
	)
	var hitch_state := presentation.get_active_shot_snapshots()[0]
	_check(
		presentation.advance_simulation(float(hitch_state.total_lifetime) + 0.05),
		"one oversized frame safely crosses arrival and retirement"
	)
	_check(
		_impact_events.size() == hitch_impacts_before + 1
		and _finished_shot_ids.size() == hitch_finished_before + 1
		and presentation.get_active_effect_count() == 0,
		"oversized frame emits impact before completion exactly once"
	)

	# Equal total time produces equal state regardless of frame subdivision.
	var deterministic_a := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	var deterministic_b := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	deterministic_a.set_auto_advance_enabled(false)
	deterministic_b.set_auto_advance_enabled(false)
	host.add_child(deterministic_a)
	host.add_child(deterministic_b)
	await process_frame
	var deterministic_origin := Vector3(-4.0, 10.0, 6.0)
	var deterministic_end := Vector3(17.0, -2.0, -34.0)
	_check(
		deterministic_a.present_shot(deterministic_origin, deterministic_end, &"magenta", null, true)
		and deterministic_b.present_shot(deterministic_origin, deterministic_end, &"magenta", null, true),
		"determinism fixtures accept identical hit geometry"
	)
	deterministic_a.advance_simulation(0.02)
	deterministic_a.advance_simulation(0.03)
	deterministic_b.advance_simulation(0.05)
	var deterministic_state_a := deterministic_a.get_active_shot_snapshots()[0]
	var deterministic_state_b := deterministic_b.get_active_shot_snapshots()[0]
	_check(
		_shot_states_match(deterministic_state_a, deterministic_state_b),
		"animation state depends on total age rather than frame subdivision"
	)
	_check(
		deterministic_a.get_determinism_fingerprint() == deterministic_b.get_determinism_fingerprint(),
		"equivalent builds publish the same deterministic resource fingerprint"
	)

	# Three independent component instances retain their own pool and lifecycle
	# state while binding the same immutable two-mesh/nine-material catalog.
	var catalog_components: Array[PulseWeaponPresentation] = [
		presentation,
		deterministic_a,
		deterministic_b,
	]
	var catalog_audits: Array[Dictionary] = []
	var unique_catalog_resource_ids := {}
	var aggregate_node_count := 0
	var aggregate_mesh_instance_nodes := 0
	var aggregate_light_nodes := 0
	var aggregate_submission_ceiling := 0
	for catalog_component in catalog_components:
		var catalog_audit := catalog_component.get_resource_catalog_audit()
		catalog_audits.append(catalog_audit)
		for resource_id: int in (catalog_audit.identity_contracts as Dictionary).values():
			unique_catalog_resource_ids[resource_id] = true
		var component_performance := catalog_component.get_performance_audit()
		var component_counts := component_performance.counts as Dictionary
		aggregate_node_count += int(component_counts.node_count)
		aggregate_mesh_instance_nodes += int(component_counts.mesh_instances)
		aggregate_light_nodes += int(component_counts.lights)
		aggregate_submission_ceiling += int(
			catalog_audit.maximum_visible_mesh_submissions_per_component
		)
	var legacy_resource_allocations := (
		catalog_components.size() * int(catalog_audits[0].legacy_resources_per_component)
	)
	var catalog_sharing_evidence := {
		"component_instances": catalog_components.size(),
		"resource_allocations_old": legacy_resource_allocations,
		"resource_allocations_new": unique_catalog_resource_ids.size(),
		"allocated_nodes_old": aggregate_node_count,
		"allocated_nodes_new": aggregate_node_count,
		"mesh_instance_nodes_old": aggregate_mesh_instance_nodes,
		"mesh_instance_nodes_new": aggregate_mesh_instance_nodes,
		"maximum_visible_mesh_submissions_old": aggregate_submission_ceiling,
		"maximum_visible_mesh_submissions_new": aggregate_submission_ceiling,
		"light_nodes_old": aggregate_light_nodes,
		"light_nodes_new": aggregate_light_nodes,
	}
	print("PULSE_WEAPON_PRESENTATION_CATALOG_SHARING: ", catalog_sharing_evidence)
	_check(
		catalog_audits[0].scope == &"process_wide_immutable_resource_catalog"
		and catalog_audits[0].mapping_state_scope == &"component_instance"
		and int(catalog_audits[0].catalog_build_count) == 1,
		"catalog is built once process-wide while component mapping state stays instance-owned"
	)
	_check(
		(catalog_audits[0].identity_contracts as Dictionary)
			== (catalog_audits[1].identity_contracts as Dictionary)
		and (catalog_audits[0].identity_contracts as Dictionary)
			== (catalog_audits[2].identity_contracts as Dictionary),
		"three live components bind identical mesh and material Resource identities"
	)
	_check(
		(catalog_audits[0].content_contracts as Dictionary)
			== (catalog_audits[1].content_contracts as Dictionary)
		and (catalog_audits[0].content_contracts as Dictionary)
			== (catalog_audits[2].content_contracts as Dictionary)
		and (catalog_audits[0].content_contracts as Dictionary).size() == 11,
		"shared catalog preserves the complete visible mesh/material roster and parameter contracts"
	)
	_check(
		legacy_resource_allocations == 33
		and unique_catalog_resource_ids.size() == 11,
		"three components reduce immutable Resource allocations from 33 to 11"
	)
	_check(
		aggregate_node_count == 258
		and aggregate_mesh_instance_nodes == 198
		and aggregate_light_nodes == 36
		and aggregate_submission_ceiling == 108,
		"sharing preserves 258 nodes, 198 semantic mesh nodes, 36 lights, and the 108-submission ceiling"
	)
	var detached_catalog_audit := presentation.get_resource_catalog_audit()
	(detached_catalog_audit.identity_contracts as Dictionary).clear()
	(detached_catalog_audit.content_contracts as Dictionary).clear()
	_check(
		(presentation.get_resource_catalog_audit().identity_contracts as Dictionary).size() == 11
		and (presentation.get_resource_catalog_audit().content_contracts as Dictionary).size() == 11,
		"catalog audit maps are detached and cannot mutate live Resource mappings"
	)

	# Saturation deterministically retires the oldest visual without growing nodes.
	presentation.clear_effects()
	var node_count_before_stress := int(presentation.get_performance_audit().counts.node_count)
	var recycled_before := int(presentation.get_statistics().recycled)
	var recycle_events_before := _recycle_events.size()
	for shot_index in presentation.get_pool_capacity() + 2:
		_check(
			presentation.present_shot(
				Vector3(-10.0, float(shot_index) * 0.1, 20.0),
				Vector3(70.0, float(shot_index) * 0.1, -120.0),
				&"cyan" if shot_index % 2 == 0 else &"amber",
				null,
				shot_index % 3 == 0
			),
			"stress shot %d is accepted into bounded pool" % shot_index
		)
	_check(
		presentation.get_active_effect_count() == presentation.get_pool_capacity(),
		"active effect count never exceeds pool capacity"
	)
	_check(
		int(presentation.get_statistics().recycled) == recycled_before + 2
		and _recycle_events.size() == recycle_events_before + 2,
		"two saturated requests deterministically recycle two oldest visuals"
	)
	_check(
		int(presentation.get_performance_audit().counts.node_count) == node_count_before_stress,
		"rapid-fire saturation allocates no additional scene nodes"
	)
	_check(
		bool(presentation.get_audit_report().valid),
		"fully saturated mixed-style pool still passes immutable resource audit"
	)

	# A receipt released by oldest-slot recycling is published only after the
	# replacement is fully installed. Its synchronous handler may present again
	# without being overwritten or corrupting the bounded pool counts.
	var abort_reentry := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	abort_reentry.pool_capacity = 1
	abort_reentry.set_auto_advance_enabled(false)
	abort_reentry.impact_receipt_aborted.connect(_on_impact_receipt_aborted)
	host.add_child(abort_reentry)
	await process_frame
	_abort_reentry_presentation = abort_reentry
	_check(
		abort_reentry.present_shot(Vector3.ZERO, Vector3.FORWARD * 48.0, &"cyan", null, true, 701),
		"abort reentry fixture accepts its receipt-owned hit"
	)
	_abort_reentry_armed = true
	_check(
		abort_reentry.present_shot(Vector3.RIGHT, Vector3.RIGHT + Vector3.FORWARD * 52.0, &"amber"),
		"saturated replacement releases the retired receipt after installation"
	)
	_abort_reentry_armed = false
	_check(
		_aborted_receipt_ids.has(701)
		and _abort_reentry_attempted
		and _abort_reentry_accepted,
		"abort receipt handler can synchronously present a nested replacement"
	)
	var abort_snapshots := abort_reentry.get_active_shot_snapshots()
	_check(
		abort_reentry.get_active_effect_count() == 1
		and abort_snapshots.size() == 1
		and (abort_snapshots[0].origin as Vector3).is_equal_approx(Vector3(7.0, 2.0, -4.0)),
		"abort reentry leaves only the nested shot live with coherent pool counts"
	)
	_check(bool(abort_reentry.get_audit_report().valid), "abort reentry preserves the immutable pool audit")
	abort_reentry.clear_effects()
	_check(
		abort_reentry.present_shot(Vector3.ZERO, Vector3.FORWARD * 44.0, &"cyan", null, true, 702),
		"reset abort fixture accepts one receipt-owned hit"
	)
	_abort_reentry_attempted = false
	_abort_reentry_accepted = false
	_abort_reentry_armed = true
	abort_reentry.reset_for_reuse()
	_abort_reentry_armed = false
	_check(
		_aborted_receipt_ids.has(702)
		and _abort_reentry_attempted
		and not _abort_reentry_accepted
		and abort_reentry.get_active_effect_count() == 0
		and int(abort_reentry.get_statistics().presented) == 0,
		"reset publishes its receipt only after telemetry reset and rejects callback reentry"
	)
	_check(
		abort_reentry.present_shot(Vector3.UP, Vector3.UP + Vector3.FORWARD * 44.0, &"cyan", null, true, 703),
		"tree-exit abort fixture accepts one receipt-owned hit"
	)
	_abort_reentry_attempted = false
	_abort_reentry_accepted = false
	_abort_reentry_armed = true
	abort_reentry.get_parent().remove_child(abort_reentry)
	_abort_reentry_armed = false
	_check(
		_aborted_receipt_ids.has(703)
		and _abort_reentry_attempted
		and not _abort_reentry_accepted
		and abort_reentry.get_active_effect_count() == 0,
		"tree exit clears the receipt before publishing and rejects callback reentry"
	)
	host.add_child(abort_reentry)
	await process_frame
	_check(bool(abort_reentry.get_audit_report().valid), "aborted tree-exit fixture re-enters cleanly")
	_abort_reentry_presentation = null

	# Synchronous lifecycle callbacks observe an atomic pool mutation. A nested
	# presentation from shot_finished must not claim the outer replacement's slot.
	var finished_reentry := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	finished_reentry.pool_capacity = 2
	finished_reentry.set_auto_advance_enabled(false)
	finished_reentry.shot_finished.connect(
		_on_saturated_reentry_shot_finished.bind(finished_reentry)
	)
	host.add_child(finished_reentry)
	await process_frame
	_check(
		finished_reentry.present_shot(Vector3(-8.0, 1.0, 3.0), Vector3(-8.0, 1.0, -53.0))
		and finished_reentry.present_shot(Vector3(4.0, 2.0, 6.0), Vector3(4.0, 2.0, -64.0)),
		"shot-finished reentry fixture reaches its exact two-slot capacity"
	)
	_finished_reentry_armed = true
	var outer_replacement_origin := Vector3(13.0, 5.0, 2.0)
	var outer_replacement_end := Vector3(13.0, 5.0, -75.0)
	_check(
		finished_reentry.present_shot(
			outer_replacement_origin,
			outer_replacement_end,
			&"amber"
		),
		"saturated outer replacement completes while shot-finished callback reenters"
	)
	_finished_reentry_armed = false
	var finished_reentry_stats := finished_reentry.get_statistics()
	var finished_reentry_snapshots := finished_reentry.get_active_shot_snapshots()
	_check(
		_finished_reentry_attempted
		and _finished_reentry_accepted
		and _finished_reentry_signal_ids == [1, 2],
		"both saturated retirements emit synchronously and nested presentation is accepted"
	)
	_check(
		finished_reentry.get_active_effect_count() == 2
		and int(finished_reentry_stats.active) == 2
		and int(finished_reentry_stats.presented) == 4
		and int(finished_reentry_stats.finished) == 2
		and int(finished_reentry_stats.recycled) == 2,
		"shot-finished reentry preserves exact active and lifecycle counts"
	)
	_check(
		finished_reentry_snapshots.size() == 2
		and int(finished_reentry_snapshots[0].shot_id) == 3
		and (finished_reentry_snapshots[0].origin as Vector3).is_equal_approx(outer_replacement_origin)
		and (finished_reentry_snapshots[0].end as Vector3).is_equal_approx(outer_replacement_end)
		and finished_reentry_snapshots[0].style_id == &"amber"
		and int(finished_reentry_snapshots[1].shot_id) == 4
		and (finished_reentry_snapshots[1].origin as Vector3).is_equal_approx(FINISHED_REENTRY_ORIGIN)
		and (finished_reentry_snapshots[1].end as Vector3).is_equal_approx(FINISHED_REENTRY_END)
		and finished_reentry_snapshots[1].style_id == &"magenta",
		"outer and nested saturated shots retain distinct live snapshot ownership"
	)
	var finished_reentry_audit := finished_reentry.get_audit_report()
	_check(
		bool(finished_reentry_audit.valid)
		and int(finished_reentry_audit.lifecycle.active_effects) == 2
		and int(finished_reentry_audit.statistics.active) == 2,
		"shot-finished reentry leaves audit, lifecycle, and live pool counts aligned"
	)

	# Impact callbacks may synchronously recycle the slot that raised the event.
	# The completed outer update must never paint over that replacement visual.
	var impact_reentry := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	impact_reentry.pool_capacity = 1
	impact_reentry.set_auto_advance_enabled(false)
	impact_reentry.impact_started.connect(_on_reentrant_impact_started.bind(impact_reentry))
	host.add_child(impact_reentry)
	await process_frame
	_check(
		impact_reentry.present_shot(
			Vector3(2.0, 4.0, 9.0),
			Vector3(2.0, 4.0, -39.0),
			&"cyan",
			null,
			true
		),
		"impact reentry fixture accepts its initial hit"
	)
	var impact_travel_duration := float(
		impact_reentry.get_active_shot_snapshots()[0].travel_duration
	)
	_impact_reentry_armed = true
	_check(
		impact_reentry.advance_simulation(impact_travel_duration + 0.01),
		"impact arrival completes while its synchronous callback recycles the slot"
	)
	_impact_reentry_armed = false
	var impact_reentry_stats := impact_reentry.get_statistics()
	var impact_reentry_snapshots := impact_reentry.get_active_shot_snapshots()
	_check(
		_impact_reentry_attempted
		and _impact_reentry_accepted
		and _impact_reentry_signal_ids == [1],
		"impact event remains one-shot while its callback presents a replacement"
	)
	_check(
		impact_reentry.get_active_effect_count() == 1
		and int(impact_reentry_stats.active) == 1
		and int(impact_reentry_stats.presented) == 2
		and int(impact_reentry_stats.finished) == 1
		and int(impact_reentry_stats.recycled) == 1,
		"impact reentry preserves exact single-slot recycle counts"
	)
	_check(
		impact_reentry_snapshots.size() == 1
		and int(impact_reentry_snapshots[0].shot_id) == 2
		and (impact_reentry_snapshots[0].origin as Vector3).is_equal_approx(IMPACT_REENTRY_ORIGIN)
		and (impact_reentry_snapshots[0].end as Vector3).is_equal_approx(IMPACT_REENTRY_END)
		and impact_reentry_snapshots[0].style_id == &"magenta"
		and not bool(impact_reentry_snapshots[0].hit)
		and is_zero_approx(float(impact_reentry_snapshots[0].age))
		and bool(impact_reentry_snapshots[0].pulse_visible)
		and not bool(impact_reentry_snapshots[0].impact_visible),
		"stale impact update cannot paint or age the callback's replacement snapshot"
	)
	var impact_reentry_audit := impact_reentry.get_audit_report()
	_check(
		bool(impact_reentry_audit.valid)
		and int(impact_reentry_audit.lifecycle.active_effects) == 1
		and int(impact_reentry_audit.statistics.active) == 1
		and _count_visible_named(impact_reentry, "MuzzleFlash") == 1
		and _count_visible_named(impact_reentry, "ImpactFlare") == 0
		and _count_visible_named(impact_reentry, "ImpactBackwash") == 0
		and _count_visible_prefix(impact_reentry, "ImpactSpark") == 0,
		"impact reentry leaves audit counts and replacement-only visuals coherent"
	)

	# A callback-created activation in a later free slot must not receive the
	# delta that triggered its creation. The advance transaction is bounded to
	# activations that existed when the call began.
	var advance_cutoff_reentry := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	advance_cutoff_reentry.pool_capacity = 2
	advance_cutoff_reentry.set_auto_advance_enabled(false)
	advance_cutoff_reentry.impact_started.connect(
		_on_advance_cutoff_impact_started.bind(advance_cutoff_reentry)
	)
	advance_cutoff_reentry.shot_presented.connect(_on_advance_cutoff_shot_presented)
	advance_cutoff_reentry.shot_recycled.connect(_on_advance_cutoff_shot_recycled)
	advance_cutoff_reentry.shot_finished.connect(_on_advance_cutoff_shot_finished)
	host.add_child(advance_cutoff_reentry)
	await process_frame
	_check(
		advance_cutoff_reentry.present_shot(
			Vector3(7.0, 2.0, 5.0),
			Vector3(7.0, 2.0, 4.0),
			&"cyan",
			null,
			true
		),
		"advance-cutoff fixture accepts its initial hit in the first of two slots"
	)
	var advance_cutoff_initial := advance_cutoff_reentry.get_active_shot_snapshots()
	var advance_cutoff_travel := (
		float(advance_cutoff_initial[0].travel_duration)
		if not advance_cutoff_initial.is_empty()
		else 0.055
	)
	_advance_cutoff_reentry_events.clear()
	_advance_cutoff_reentry_armed = true
	_check(
		advance_cutoff_reentry.advance_simulation(advance_cutoff_travel + 0.01),
		"impact callback accepts a shot into a later slot during an advance transaction"
	)
	_advance_cutoff_reentry_armed = false
	var advance_cutoff_stats := advance_cutoff_reentry.get_statistics()
	var advance_cutoff_snapshots := advance_cutoff_reentry.get_active_shot_snapshots()
	var advance_cutoff_outer := (
		advance_cutoff_snapshots[0] if advance_cutoff_snapshots.size() > 0 else {}
	)
	var advance_cutoff_nested := (
		advance_cutoff_snapshots[1] if advance_cutoff_snapshots.size() > 1 else {}
	)
	_check(
		_advance_cutoff_reentry_attempted
		and _advance_cutoff_reentry_accepted
		and _advance_cutoff_reentry_events == ["I1", "P2"],
		"later-slot callback emits only impact then presentation during the outer advance"
	)
	_check(
		int(advance_cutoff_stats.presented) == 2
		and int(advance_cutoff_stats.finished) == 0
		and int(advance_cutoff_stats.recycled) == 0
		and int(advance_cutoff_stats.rejected) == 0
		and int(advance_cutoff_stats.active) == 2
		and int(advance_cutoff_stats.capacity) == 2,
		"later-slot callback preserves exact accepted, unfinished, and active counts"
	)
	_check(
		advance_cutoff_snapshots.size() == 2
		and int(advance_cutoff_outer.get("shot_id", 0)) == 1
		and bool(advance_cutoff_outer.get("impact_visible", false))
		and int(advance_cutoff_nested.get("shot_id", 0)) == 2
		and (advance_cutoff_nested.get("origin", Vector3.ZERO) as Vector3).is_equal_approx(
			ADVANCE_CUTOFF_REENTRY_ORIGIN
		)
		and (advance_cutoff_nested.get("end", Vector3.ZERO) as Vector3).is_equal_approx(
			ADVANCE_CUTOFF_REENTRY_END
		)
		and advance_cutoff_nested.get("style_id", &"") == &"magenta"
		and is_zero_approx(float(advance_cutoff_nested.get("age", -1.0)))
		and bool(advance_cutoff_nested.get("pulse_visible", false))
		and not bool(advance_cutoff_nested.get("impact_visible", true)),
		"callback-created later-slot shot remains live and exactly age zero"
	)
	var advance_cutoff_audit := advance_cutoff_reentry.get_audit_report()
	_check(
		bool(advance_cutoff_audit.valid)
		and int(advance_cutoff_audit.lifecycle.active_effects) == 2
		and int(advance_cutoff_audit.statistics.active) == 2,
		"advance cutoff leaves the two-slot pool and audit exactly aligned"
	)
	_check(
		advance_cutoff_reentry.advance_simulation(0.01),
		"the callback-created activation advances on the next explicit transaction"
	)
	advance_cutoff_snapshots = advance_cutoff_reentry.get_active_shot_snapshots()
	advance_cutoff_nested = (
		advance_cutoff_snapshots[1] if advance_cutoff_snapshots.size() > 1 else {}
	)
	_check(
		is_equal_approx(float(advance_cutoff_nested.get("age", -1.0)), 0.01),
		"later-slot activation receives exactly the next advance delta"
	)

	# A recycle observer may synchronously saturate the same one-slot pool again.
	# Every accepted replacement must publish presentation before any callback can
	# publish its completion, while the signal tail performs no state writes.
	var recycle_order_reentry := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	recycle_order_reentry.pool_capacity = 1
	recycle_order_reentry.set_auto_advance_enabled(false)
	recycle_order_reentry.shot_presented.connect(_on_recycle_order_shot_presented)
	recycle_order_reentry.shot_recycled.connect(
		_on_recycle_order_shot_recycled.bind(recycle_order_reentry)
	)
	recycle_order_reentry.shot_finished.connect(_on_recycle_order_shot_finished)
	host.add_child(recycle_order_reentry)
	await process_frame
	_check(
		recycle_order_reentry.present_shot(Vector3.ZERO, Vector3.FORWARD),
		"recycle-order fixture fills its single slot"
	)
	_recycle_order_reentry_events.clear()
	_recycle_order_reentry_armed = true
	_check(
		recycle_order_reentry.present_shot(
			Vector3.RIGHT,
			Vector3.RIGHT + Vector3.FORWARD,
			&"amber"
		),
		"outer saturated replacement completes while recycle callback reenters"
	)
	_recycle_order_reentry_armed = false
	var recycle_order_stats := recycle_order_reentry.get_statistics()
	var recycle_order_snapshots := recycle_order_reentry.get_active_shot_snapshots()
	var recycle_order_snapshot := (
		recycle_order_snapshots[0] if not recycle_order_snapshots.is_empty() else {}
	)
	_check(
		_recycle_order_reentry_attempted
		and _recycle_order_reentry_accepted
		and _recycle_order_reentry_events == [
			"P2", "R1>2", "P3", "R2>3", "F2", "F1"
		],
		"nested recycle signals preserve exact P-R-P-R-F-F lifecycle order"
	)
	_check(
		int(recycle_order_stats.presented) == 3
		and int(recycle_order_stats.finished) == 2
		and int(recycle_order_stats.recycled) == 2
		and int(recycle_order_stats.rejected) == 0
		and int(recycle_order_stats.active) == 1
		and int(recycle_order_stats.capacity) == 1,
		"nested recycle preserves exact presentation, retirement, and pool counts"
	)
	_check(
		recycle_order_snapshots.size() == 1
		and int(recycle_order_snapshot.get("shot_id", 0)) == 3
		and (recycle_order_snapshot.get("origin", Vector3.ZERO) as Vector3).is_equal_approx(
			RECYCLE_ORDER_REENTRY_ORIGIN
		)
		and (recycle_order_snapshot.get("end", Vector3.ZERO) as Vector3).is_equal_approx(
			RECYCLE_ORDER_REENTRY_END
		)
		and recycle_order_snapshot.get("style_id", &"") == &"magenta"
		and is_zero_approx(float(recycle_order_snapshot.get("age", -1.0)))
		and bool(recycle_order_snapshot.get("pulse_visible", false)),
		"nested recycle leaves only its accepted replacement live at age zero"
	)
	var recycle_order_audit := recycle_order_reentry.get_audit_report()
	_check(
		bool(recycle_order_audit.valid)
		and int(recycle_order_audit.lifecycle.active_effects) == 1
		and int(recycle_order_audit.statistics.active) == 1,
		"nested recycle leaves audit, statistics, and live pool state aligned"
	)

	# Disable, automatic processing, tree re-entry, and reset are all explicit.
	presentation.set_presentation_enabled(false)
	_check(
		not presentation.is_presentation_enabled()
		and presentation.get_active_effect_count() == 0
		and not presentation.present_shot(Vector3.ZERO, Vector3.FORWARD * 10.0),
		"disabled lifecycle clears active visuals and rejects new work"
	)
	presentation.set_presentation_enabled(true)
	presentation.set_auto_advance_enabled(true)
	_check(
		presentation.present_shot(Vector3(1.0, 2.0, 3.0), Vector3(-4.0, 5.0, -60.0))
		and presentation.is_processing(),
		"automatic mode processes only while at least one effect is active"
	)
	presentation.set_auto_advance_enabled(false)
	_check(not presentation.is_processing(), "disabling automatic advance immediately removes frame work")
	host.remove_child(presentation)
	_check(
		presentation.get_active_effect_count() == 0
		and not presentation.is_processing()
		and bool(presentation.get_audit_report().valid),
		"tree exit synchronously clears effects and preserves a valid reusable pool"
	)
	host.add_child(presentation)
	await process_frame
	_check(
		presentation.present_shot(Vector3(-2.0, 1.0, 9.0), Vector3(6.0, 2.0, -18.0), &"magenta")
		and presentation.get_active_effect_count() == 1,
		"same component accepts fresh work after child remove and re-add"
	)
	presentation.reset_for_reuse()
	var reset_stats := presentation.get_statistics()
	_check(
		presentation.is_presentation_enabled()
		and presentation.get_active_effect_count() == 0
		and int(reset_stats.presented) == 0
		and int(reset_stats.finished) == 0
		and int(reset_stats.recycled) == 0
		and int(reset_stats.rejected) == 0,
		"explicit reuse reset clears effects and telemetry without rebuilding"
	)
	_check(bool(presentation.get_audit_report().valid), "reset pool retains a valid immutable build")

	var queued_presentation := PRESENTATION_SCENE.instantiate() as PulseWeaponPresentation
	host.add_child(queued_presentation)
	await process_frame
	queued_presentation.set_auto_advance_enabled(false)
	var queued_signal_events: Array[StringName] = []
	queued_presentation.shot_presented.connect(
		func(_shot_id: int, _style_id: StringName, _source_instance_id: int, _hit: bool) -> void:
			queued_signal_events.append(&"presented")
	)
	queued_presentation.shot_finished.connect(
		func(_shot_id: int) -> void:
			queued_signal_events.append(&"finished")
	)
	queued_presentation.effects_cleared.connect(
		func() -> void:
			queued_signal_events.append(&"cleared")
	)
	queued_presentation.presentation_enabled_changed.connect(
		func(_enabled: bool) -> void:
			queued_signal_events.append(&"enabled")
	)
	_check(
		queued_presentation.present_shot(Vector3(2.0, 1.0, 4.0), Vector3(2.0, 1.0, -24.0), &"amber", null, true),
		"queued-currentness fixture starts with one live hit pulse"
	)
	queued_presentation.queue_free()
	var queued_snapshots := queued_presentation.get_active_shot_snapshots()
	var queued_statistics := queued_presentation.get_statistics()
	var queued_enabled := queued_presentation.is_presentation_enabled()
	var queued_auto_advance := queued_presentation.is_auto_advance_enabled()
	var queued_process := queued_presentation.is_processing()
	var queued_signal_count := queued_signal_events.size()
	queued_presentation.set_presentation_enabled(false)
	queued_presentation.set_auto_advance_enabled(true)
	queued_presentation.clear_effects()
	queued_presentation.reset_for_reuse()
	_check(
		queued_presentation.is_inside_tree()
		and queued_presentation.is_queued_for_deletion()
		and not queued_presentation.advance_simulation(1.0)
		and not queued_presentation.present_shot(Vector3.ZERO, Vector3.FORWARD * 10.0)
		and queued_presentation.get_active_shot_snapshots() == queued_snapshots
		and queued_presentation.get_statistics() == queued_statistics
		and queued_presentation.is_presentation_enabled() == queued_enabled
		and queued_presentation.is_auto_advance_enabled() == queued_auto_advance
		and queued_presentation.is_processing() == queued_process
		and queued_signal_events.size() == queued_signal_count,
		"queued presentation rejects every direct mutator without pool, telemetry, lifecycle, or signal drift"
	)

	# Audits fail red for forbidden authority or shared-resource mutation and recover.
	var pool_root := presentation.get_node("PoolRoot") as Node3D
	var forbidden_area := Area3D.new()
	forbidden_area.name = "ForbiddenGameplayAuthority"
	pool_root.add_child(forbidden_area)
	var forbidden_audit := presentation.get_audit_report()
	_check(
		not bool(forbidden_audit.valid)
		and int((forbidden_audit.performance as Dictionary).counts.collision_nodes) == 1,
		"audit rejects an injected collision-authority node"
	)
	pool_root.remove_child(forbidden_area)
	forbidden_area.free()
	_check(bool(presentation.get_audit_report().valid), "removing forbidden authority restores the audit")

	var first_segment := presentation.get_node("PoolRoot/ShotSlot01/BeamSegment01") as MeshInstance3D
	var shared_dash := first_segment.mesh as BoxMesh
	var original_dash_size := shared_dash.size
	shared_dash.size = Vector3(2.0, 0.5, 3.0)
	_check(not bool(presentation.get_audit_report().valid), "audit rejects in-place shared beam resource drift")
	shared_dash.size = original_dash_size
	_check(bool(presentation.get_audit_report().valid), "restoring shared beam resource restores the audit")

	var detached_report := presentation.get_audit_report()
	(detached_report.evidence as Dictionary).clear()
	(detached_report.performance as Dictionary).clear()
	_check(
		not presentation.get_evidence_metadata().is_empty()
		and not presentation.get_performance_audit().is_empty(),
		"audit and evidence dictionaries are deeply detached"
	)

	await _clean_up(host)
	_check(root.get_child_count() == original_root_child_count, "all presentation fixtures clean up without orphan nodes")
	_finish()


func _shot_states_match(first: Dictionary, second: Dictionary) -> bool:
	return (
		is_equal_approx(float(first.age), float(second.age))
		and is_equal_approx(float(first.travel_progress), float(second.travel_progress))
		and (first.pulse_position as Vector3).is_equal_approx(second.pulse_position as Vector3)
		and bool(first.pulse_visible) == bool(second.pulse_visible)
		and bool(first.impact_visible) == bool(second.impact_visible)
		and int(first.visible_beam_segments) == int(second.visible_beam_segments)
	)


func _all_generated_nodes_are_presentational(presentation: Node) -> bool:
	for candidate in presentation.find_children("*", "", true, false):
		if (
			not bool(candidate.get_meta("presentation_only", false))
			or bool(candidate.get_meta("gameplay_authority", true))
			or StringName(candidate.get_meta("evidence_status", &"")) != &"modern_interpretation"
		):
			return false
	return true


func _count_visible_named(presentation: Node, exact_name: String) -> int:
	var count := 0
	for candidate in presentation.find_children(exact_name, "Node3D", true, false):
		if (candidate as Node3D).visible:
			count += 1
	return count


func _count_visible_prefix(presentation: Node, prefix: String) -> int:
	var count := 0
	for candidate in presentation.find_children(prefix + "*", "Node3D", true, false):
		if (candidate as Node3D).visible:
			count += 1
	return count


func _count_visible_effect_nodes(presentation: Node) -> int:
	var count := 0
	for candidate in presentation.find_children("*", "VisualInstance3D", true, false):
		if (candidate as VisualInstance3D).visible:
			count += 1
	return count


func _clean_up(host: Node) -> void:
	if is_instance_valid(host):
		host.queue_free()
	for _frame in 4:
		await process_frame


func _on_shot_presented(
		shot_id: int,
		style_id: StringName,
		source_instance_id: int,
		hit: bool
	) -> void:
	_shot_events.append({
		"shot_id": shot_id,
		"style_id": style_id,
		"source_instance_id": source_instance_id,
		"hit": hit,
	})


func _on_shot_finished(shot_id: int) -> void:
	_finished_shot_ids.append(shot_id)


func _on_saturated_reentry_shot_finished(
		shot_id: int,
		presentation: PulseWeaponPresentation
	) -> void:
	_finished_reentry_signal_ids.append(shot_id)
	if not _finished_reentry_armed or _finished_reentry_attempted:
		return
	_finished_reentry_attempted = true
	_finished_reentry_accepted = presentation.present_shot(
		FINISHED_REENTRY_ORIGIN,
		FINISHED_REENTRY_END,
		&"magenta"
	)


func _on_impact_started(
		shot_id: int,
		style_id: StringName,
		source_instance_id: int,
		position: Vector3
	) -> void:
	_impact_events.append({
		"shot_id": shot_id,
		"style_id": style_id,
		"source_instance_id": source_instance_id,
		"position": position,
	})


func _on_reentrant_impact_started(
		shot_id: int,
		_style_id: StringName,
		_source_instance_id: int,
		_position: Vector3,
		presentation: PulseWeaponPresentation
	) -> void:
	_impact_reentry_signal_ids.append(shot_id)
	if not _impact_reentry_armed or _impact_reentry_attempted:
		return
	_impact_reentry_attempted = true
	_impact_reentry_accepted = presentation.present_shot(
		IMPACT_REENTRY_ORIGIN,
		IMPACT_REENTRY_END,
		&"magenta",
		null,
		false
	)


func _on_advance_cutoff_impact_started(
		shot_id: int,
		_style_id: StringName,
		_source_instance_id: int,
		_position: Vector3,
		presentation: PulseWeaponPresentation
	) -> void:
	_advance_cutoff_reentry_events.append("I%d" % shot_id)
	if not _advance_cutoff_reentry_armed or _advance_cutoff_reentry_attempted:
		return
	_advance_cutoff_reentry_attempted = true
	_advance_cutoff_reentry_accepted = presentation.present_shot(
		ADVANCE_CUTOFF_REENTRY_ORIGIN,
		ADVANCE_CUTOFF_REENTRY_END,
		&"magenta"
	)


func _on_advance_cutoff_shot_presented(
		shot_id: int,
		_style_id: StringName,
		_source_instance_id: int,
		_hit: bool
	) -> void:
	_advance_cutoff_reentry_events.append("P%d" % shot_id)


func _on_advance_cutoff_shot_recycled(retired_shot_id: int, replacement_shot_id: int) -> void:
	_advance_cutoff_reentry_events.append("R%d>%d" % [retired_shot_id, replacement_shot_id])


func _on_advance_cutoff_shot_finished(shot_id: int) -> void:
	_advance_cutoff_reentry_events.append("F%d" % shot_id)


func _on_recycle_order_shot_presented(
		shot_id: int,
		_style_id: StringName,
		_source_instance_id: int,
		_hit: bool
	) -> void:
	_recycle_order_reentry_events.append("P%d" % shot_id)


func _on_recycle_order_shot_recycled(
		retired_shot_id: int,
		replacement_shot_id: int,
		presentation: PulseWeaponPresentation
	) -> void:
	_recycle_order_reentry_events.append(
		"R%d>%d" % [retired_shot_id, replacement_shot_id]
	)
	if not _recycle_order_reentry_armed or _recycle_order_reentry_attempted:
		return
	_recycle_order_reentry_attempted = true
	_recycle_order_reentry_accepted = presentation.present_shot(
		RECYCLE_ORDER_REENTRY_ORIGIN,
		RECYCLE_ORDER_REENTRY_END,
		&"magenta"
	)


func _on_recycle_order_shot_finished(shot_id: int) -> void:
	_recycle_order_reentry_events.append("F%d" % shot_id)


func _on_shot_recycled(retired_shot_id: int, replacement_shot_id: int) -> void:
	_recycle_events.append(Vector2i(retired_shot_id, replacement_shot_id))


func _on_effects_cleared() -> void:
	_clear_events += 1


func _on_impact_receipt_aborted(receipt_id: int) -> void:
	_aborted_receipt_ids.append(receipt_id)
	if not _abort_reentry_armed or _abort_reentry_attempted:
		return
	_abort_reentry_attempted = true
	_abort_reentry_accepted = _abort_reentry_presentation.present_shot(
		Vector3(7.0, 2.0, -4.0),
		Vector3(7.0, 2.0, -64.0),
		&"magenta"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PULSE_WEAPON_PRESENTATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("PULSE_WEAPON_PRESENTATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
