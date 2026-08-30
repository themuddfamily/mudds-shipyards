extends SceneTree

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const BindingScript := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
)
const AURORA_ATMOSPHERE := preload(
	"res://assets/world/planets/aurora_temperate_atmosphere.tres"
)

var _failures := PackedStringArray()


class ProductionProbe:
	extends BindingScript

	var probe_phase := EmberSurfaceLoopHost.Phase.DESCENT

	func prepare_early_tick(
			caller_serial: int, _delta: float, _actor_sample: Variant,
			_origin_result: Variant, _frame_generation: int,
			_location_generation: int, _expected_generation: int
		) -> Dictionary:
		set("_pending_envelope", {"caller_serial": caller_serial})
		return {"accepted": true, "reason": &"probe_prepared"}

	func get_host_phase() -> int:
		return probe_phase


class AtmosphereProbe:
	extends Node
	var atmosphere_profile: PlanetaryAtmosphereProfile


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var composition := Node3D.new()
	composition.name = "EntryPresentationProductionRoot"
	root.add_child(composition)
	var hud := GameHUD.new()
	hud.name = "HUD"
	composition.add_child(hud)
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	composition.add_child(arrow)
	arrow.set_physics_process(false)
	await process_frame

	var production := ProductionProbe.new()
	composition.add_child(production)
	production.set("_composition_root", composition)
	production.set("_ship", arrow)
	production.set("_ship_instance_id", arrow.get_instance_id())
	production.probe_phase = EmberSurfaceLoopHost.Phase.LANDING_APPROACH
	production.set("_last_planetary_altitude_m", 100.0)
	var airless := production.advance_from_caller_sample(
		1, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -12.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var airless_snapshot := production.get_snapshot()
	var airless_entry := airless_snapshot.last_entry_presentation_result as Dictionary
	var airless_source := airless_entry.get("source", {}) as Dictionary
	var normal_wash := (airless_snapshot.entry_presentation as Dictionary).get(
		"landing_wash", {}
	) as Dictionary
	var safe_cockpit := (airless_snapshot.entry_presentation as Dictionary).get(
		"cockpit_readout", {}
	) as Dictionary
	var safe_exterior := (airless_snapshot.entry_presentation as Dictionary).get(
		"exterior_envelope", {}
	) as Dictionary
	var physical_wash := arrow.get_arrow_visual_root().get_node_or_null(
		^"ArrowLandingDustWashPresentation"
	) as Node3D
	var physical_wash_id := physical_wash.get_instance_id() \
		if physical_wash != null else 0
	var physical_dust := physical_wash.get_node_or_null(
		^"ShipLocalDustWash"
	) as CPUParticles3D if physical_wash != null else null
	var physical_thruster := physical_wash.get_node_or_null(
		^"PortLandingThruster"
	) as MeshInstance3D if physical_wash != null else null
	var physical_thruster_material := (
		physical_thruster.mesh.material as StandardMaterial3D
	) if physical_thruster != null else null
	var normal_dust_scale := physical_dust.scale.x \
		if physical_dust != null else 0.0
	var normal_thruster_scale := physical_thruster.scale.y \
		if physical_thruster != null else 0.0
	var physical_entry_readout := arrow.get_arrow_visual_root().get_node_or_null(
		^"CockpitInterior/InstrumentCluster/EntryDescentReadout"
	) as Label3D
	var physical_exterior := arrow.get_arrow_visual_root().get_node_or_null(
		^"ArrowEntryExteriorEnvelope"
	) as Node3D
	var physical_segments := physical_exterior.get_node_or_null(
		^"EnvelopeSegments"
	) as MultiMeshInstance3D if physical_exterior != null else null
	var physical_segment_material := (
		physical_segments.multimesh.mesh.material as StandardMaterial3D
	) if physical_segments != null else null
	var physical_recovery_ring := physical_exterior.get_node_or_null(
		^"RecoveryRing"
	) as MeshInstance3D if physical_exterior != null else null
	var physical_exterior_marker := physical_exterior.get_node_or_null(
		^"EnvelopeMarker"
	) as Label3D if physical_exterior != null else null
	var chase_camera := arrow.get_node_or_null(
		^"CameraRig/CameraCollisionArm/CameraBoundaryMount/ShipCamera"
	) as Camera3D
	var entry_presenter := hud.get("_entry_guidance_presenter") as RefCounted
	var safe_presentation := entry_presenter.call(&"get_snapshot") as Dictionary
	_check(
		bool(airless.get("accepted", false))
		and airless_source.get("branch_id") == &"airless"
		and is_zero_approx(float(airless_source.get("entry_intensity", -1.0)))
		and airless_source.get("vertical_speed_mps") == -12.0
		and safe_presentation.get("descent_advisory_id") == &"safe_descent"
		and float(normal_wash.get("intensity", 0.0)) > 0.0
		and normal_wash.get("dust_emitting") == true
		and normal_wash.get("dust_renderer_visible") == true
		and normal_wash.get("thruster_visible_count") == 2
		and normal_wash.get("landing_supported") == true
		and float(normal_wash.get("support_clearance_factor", 0.0)) > 0.0
		and float(normal_wash.get("descent_factor", 0.0)) > 0.0
		and float(normal_wash.get("presentation_load", 0.0)) > 0.0
		and normal_wash.get("continuous_clearance_descent_response") == true
		and physical_wash != null
		and physical_dust != null and physical_dust.emitting
		and physical_dust.visible
		and is_equal_approx(
			physical_dust.color.a, float(normal_wash.get("dust_opacity", -1.0))
		)
		and physical_thruster != null and physical_thruster.visible
		and physical_thruster_material != null
		and is_equal_approx(
			physical_thruster_material.albedo_color.a,
			float(normal_wash.get("thruster_opacity", -1.0))
		)
		and (normal_wash.get("node_budget", {}) as Dictionary).get(
			"total_nodes"
		) == 4
		and normal_wash.get("collision_authority") == false
		and normal_wash.get("movement_authority") == false
		and normal_wash.get("damage_authority") == false
		and normal_wash.get("atmosphere_authority") == false
		and normal_wash.get("landing_authority") == false
		and safe_cockpit.get("text") \
			== "AIRLESS | [v] DESCENT SAFE | E[#----] 1/5"
		and safe_cockpit.get("symbol") == &"[v]"
		and (safe_cockpit.get("envelope_gauge", {}) as Dictionary).get(
			"ascii_silhouette"
		) == "[#----]"
		and (safe_cockpit.get("envelope_gauge", {}) as Dictionary).get(
			"bounded"
		) == true
		and safe_cockpit.get("color_independent") == true
		and safe_cockpit.get("collision_authority") == false
		and safe_cockpit.get("movement_authority") == false
		and safe_cockpit.get("damage_authority") == false
		and safe_cockpit.get("landing_authority") == false
		and physical_entry_readout != null
		and physical_entry_readout.text == safe_cockpit.get("text")
		and safe_exterior.get("visible_segment_count") == 0
		and is_zero_approx(float(safe_exterior.get(
			"atmospheric_intensity", -1.0
		)))
		and is_zero_approx(float(safe_exterior.get("effect_opacity", -1.0)))
		and is_equal_approx(float(safe_exterior.get("effect_scale", 0.0)), 1.0)
		and safe_exterior.get("airless_zero") == true
		and safe_exterior.get("marker_text") == ""
		and safe_exterior.get("color_independent") == true
		and physical_exterior != null and not physical_exterior.visible
		and physical_segments != null
		and physical_segment_material != null
		and physical_segments.multimesh.visible_instance_count == 0
		and physical_segments.scale.is_equal_approx(Vector3.ONE)
		and physical_exterior_marker != null
		and physical_exterior_marker.text == ""
		and not physical_exterior_marker.visible
		and physical_exterior_marker.billboard \
			== BaseMaterial3D.BILLBOARD_ENABLED
		and chase_camera != null
		and (safe_exterior.get("node_budget", {}) as Dictionary).get(
			"total_nodes"
		) == 4
		and (safe_exterior.get("node_budget", {}) as Dictionary).get(
			"particle_nodes"
		) == 0
		and hud.get("_runtime_status_kind") == &"entry",
		"low Ember descent reaches the HUD, cockpit, and wash with exact-zero exterior heat",
	)

	hud.set_reduced_flash(true)
	hud.set_reduced_motion(true)
	var reduced := production.advance_from_caller_sample(
		2, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -12.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var reduced_wash := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	var reduced_cockpit := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("cockpit_readout", {}) as Dictionary
	var reduced_exterior := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("exterior_envelope", {}) as Dictionary
	_check(
		bool(reduced.get("accepted", false))
		and float(reduced_wash.get("intensity", 0.0)) \
			< float(normal_wash.get("intensity", 0.0))
		and reduced_wash.get("reduced_flash") == true
		and reduced_wash.get("reduced_motion") == true
		and reduced_wash.get("steady_emission") == true
		and is_equal_approx(
			float(reduced_wash.get("presentation_load", -1.0)),
			float(normal_wash.get("presentation_load", -2.0))
		)
		and float(reduced_wash.get("dust_opacity", 0.0)) \
			< float(normal_wash.get("dust_opacity", 0.0))
		and float(reduced_wash.get("dust_scale", 0.0)) \
			< float(normal_wash.get("dust_scale", 0.0))
		and float(reduced_wash.get("thruster_scale", 0.0)) \
			< float(normal_wash.get("thruster_scale", 0.0))
		and physical_dust.scale.x < normal_dust_scale
		and physical_thruster.scale.y < normal_thruster_scale
		and reduced_cockpit.get("reduced_flash") == true
		and reduced_cockpit.get("reduced_motion") == true
		and reduced_cockpit.get("steady") == true
		and reduced_cockpit.get("color_independent") == true
		and str(reduced_cockpit.get("text", "")).contains("E[#----] 1/5")
		and reduced_exterior.get("reduced_flash") == true
		and reduced_exterior.get("reduced_motion") == true
		and reduced_exterior.get("steady") == true
		and reduced_exterior.get("visible_segment_count") == 0
		and is_zero_approx(float(reduced_exterior.get(
			"visual_intensity_scale", -1.0
		)))
		and is_zero_approx(float(reduced_exterior.get(
			"effect_emission", -1.0
		))),
		"reduced settings lower the wash while airless exterior heat remains zero",
	)

	production.set("_last_planetary_altitude_m", 45.0)
	var high_sink_airless := production.advance_from_caller_sample(
		3, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -60.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var high_sink_cockpit := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("cockpit_readout", {}) as Dictionary
	var high_sink_wash := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	var high_sink_exterior := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("exterior_envelope", {}) as Dictionary
	_check(
		bool(high_sink_airless.get("accepted", false))
		and high_sink_cockpit.get("text") \
			== "AIRLESS | [!!] HIGH SINK | E[####-] 4/5"
		and high_sink_cockpit.get("symbol") == &"[!!]"
		and (high_sink_cockpit.get("envelope_gauge", {}) as Dictionary).get(
			"filled_segments"
		) == 4
		and high_sink_cockpit.get("steady") == true
		and is_equal_approx(float(high_sink_wash.get(
			"presentation_load", -1.0
		)), 1.0)
		and float(high_sink_wash.get("dust_opacity", 0.0)) \
			> float(reduced_wash.get("dust_opacity", 0.0))
		and float(high_sink_wash.get("dust_scale", 0.0)) \
			> float(reduced_wash.get("dust_scale", 0.0))
		and float(high_sink_wash.get("dust_opacity", 1.0)) <= 0.324
		and float(high_sink_wash.get("dust_scale", 2.0)) <= 1.22
		and float(high_sink_wash.get("thruster_scale", 2.0)) <= 1.15
		and is_equal_approx(
			physical_dust.scale.x, float(high_sink_wash.get("dust_scale", 0.0))
		)
		and is_equal_approx(
			physical_thruster.scale.y,
			float(high_sink_wash.get("thruster_scale", 0.0))
		)
		and physical_entry_readout.text == high_sink_cockpit.get("text")
		and high_sink_exterior.get("visible_segment_count") == 0
		and high_sink_exterior.get("airless_zero") == true
		and is_zero_approx(float(high_sink_exterior.get(
			"effect_opacity", -1.0
		)))
		and physical_segments.multimesh.visible_instance_count == 0,
		"high sink remains legible in the cockpit without inventing airless heat",
	)

	production.probe_phase = EmberSurfaceLoopHost.Phase.DESCENT
	var unsupported := production.advance_from_caller_sample(
		4, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -60.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var unsupported_wash := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	_check(
		bool(unsupported.get("accepted", false))
		and unsupported_wash.get("last_reason") \
			== &"landing_support_unavailable"
		and unsupported_wash.get("landing_supported") == false
		and is_zero_approx(float(unsupported_wash.get("intensity", -1.0)))
		and is_zero_approx(float(unsupported_wash.get(
			"presentation_load", -1.0
		)))
		and not physical_dust.emitting
		and not physical_dust.visible
		and unsupported_wash.get("dust_renderer_visible") == false
		and physical_dust.scale.is_equal_approx(Vector3.ONE)
		and not physical_thruster.visible
		and physical_thruster.scale.is_equal_approx(Vector3.ONE),
		"wash requires the caller-accepted landing support phase",
	)

	production.probe_phase = EmberSurfaceLoopHost.Phase.LANDING_APPROACH
	var climbing_airless := production.advance_from_caller_sample(
		5, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, 15.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var climb_zero := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	var climb_cockpit := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("cockpit_readout", {}) as Dictionary
	var climb_exterior := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("exterior_envelope", {}) as Dictionary
	_check(
		bool(climbing_airless.get("accepted", false))
		and is_zero_approx(float(climb_zero.get("intensity", -1.0)))
		and climb_zero.get("dust_emitting") == false
		and climb_zero.get("dust_renderer_visible") == false
		and not physical_dust.visible
		and climb_zero.get("last_reason") == &"climb_or_level_zero"
		and climb_cockpit.get("text") \
			== "AIRLESS | [^] CLIMB / EXIT | E[-----] 0/5 RECOVER"
		and (climb_cockpit.get("envelope_gauge", {}) as Dictionary).get(
			"recovery"
		) == true
		and climb_exterior.get("visible_segment_count") == 0
		and climb_exterior.get("recovery") == false
		and climb_exterior.get("recovery_ring_visible") == false
		and climb_exterior.get("marker_text") == ""
		and physical_recovery_ring != null and not physical_recovery_ring.visible
		and physical_exterior_marker.text == "",
		"airless climb clears both wash and atmosphere-only exterior effects",
	)

	production.set("_last_planetary_altitude_m", 500.0)
	var high_airless := production.advance_from_caller_sample(
		6, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -20.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var high_zero := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	_check(
		bool(high_airless.get("accepted", false))
		and is_zero_approx(float(high_zero.get("intensity", -1.0)))
		and high_zero.get("dust_renderer_visible") == false
		and not physical_dust.visible
		and high_zero.get("last_reason") == &"high_altitude_zero",
		"high-altitude descent keeps the landing wash at exact zero",
	)

	var atmosphere := AtmosphereProbe.new()
	atmosphere.atmosphere_profile = AURORA_ATMOSPHERE
	composition.add_child(atmosphere)
	production.set("_atmosphere_composition", atmosphere)
	production.set("_last_planetary_altitude_m", 14_000.0)
	var atmospheric_midpoint := production.advance_from_caller_sample(
		7, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -60.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var midpoint_entry := (
		production.get_snapshot().last_entry_presentation_result as Dictionary
	)
	var midpoint_exterior := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("exterior_envelope", {}) as Dictionary
	var midpoint_physical_scale := physical_segments.scale.x
	production.set("_last_planetary_altitude_m", 10_000.0)
	var atmospheric := production.advance_from_caller_sample(
		8, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -60.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var snapshot := production.get_snapshot()
	var entry := snapshot.last_entry_presentation_result as Dictionary
	var source := entry.get("source", {}) as Dictionary
	var bridge := snapshot.entry_presentation as Dictionary
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	var high_sink_presentation := entry_presenter.call(&"get_snapshot") as Dictionary
	var atmospheric_cockpit := bridge.get("cockpit_readout", {}) as Dictionary
	var atmospheric_exterior := bridge.get("exterior_envelope", {}) as Dictionary
	var atmospheric_wash := bridge.get("landing_wash", {}) as Dictionary
	_check(
		bool(atmospheric.get("accepted", false))
		and source.get("branch_id") == &"atmospheric"
		and bool(atmospheric_midpoint.get("accepted", false))
		and is_equal_approx(float(midpoint_entry.get(
			"entry_intensity", -1.0
		)), 0.5)
		and is_equal_approx(float(midpoint_exterior.get(
			"atmospheric_intensity", -1.0
		)), 0.5)
		and is_equal_approx(float(entry.get("entry_intensity", 0.0)), 1.0)
		and atmospheric_wash.get("last_reason") == &"atmospheric_branch_zero"
		and is_zero_approx(float(atmospheric_wash.get("dust_opacity", -1.0)))
		and is_equal_approx(float(atmospheric_wash.get(
			"dust_scale", 0.0
		)), 1.0)
		and not physical_dust.emitting
		and physical_dust.scale.is_equal_approx(Vector3.ONE)
		and not physical_thruster.visible
		and physical_thruster.scale.is_equal_approx(Vector3.ONE)
		and is_zero_approx(physical_thruster_material.albedo_color.a)
		and title != null and title.text == "Critical Atmospheric Entry"
		and detail != null and detail.text.begins_with(
			"[ STEADY ENTRY LOAD CRITICAL ]"
		)
		and high_sink_presentation.get("descent_advisory_id") \
			== &"high_sink_rate"
		and high_sink_presentation.get("transition_policy") == &"static"
		and high_sink_presentation.get(
			"descent_advisory_color_independent"
		) == true
		and detail.text.contains("[ HIGH SINK RATE // 60 M/S DOWN")
		and atmospheric_cockpit.get("text") \
			== "ATM HEAT | [!!] CRITICAL | E[#####] 5/5"
		and atmospheric_cockpit.get("symbol") == &"[!!]"
		and (atmospheric_cockpit.get(
			"envelope_gauge", {}
		) as Dictionary).get("severity_id") == &"critical"
		and atmospheric_cockpit.get("steady") == true
		and atmospheric_exterior.get("visible_segment_count") == 5
		and atmospheric_exterior.get("marker_text") == "ATM ENTRY 100% 5/5"
		and atmospheric_exterior.get("recovery_ring_visible") == false
		and atmospheric_exterior.get("continuous_intensity_response") == true
		and float(midpoint_exterior.get("effect_opacity", -1.0)) > 0.0
		and float(midpoint_exterior.get("effect_opacity", 1.0)) \
			< float(atmospheric_exterior.get("effect_opacity", 0.0))
		and float(atmospheric_exterior.get("effect_opacity", 1.0)) <= 0.42
		and float(midpoint_exterior.get("effect_emission", 1.0)) \
			< float(atmospheric_exterior.get("effect_emission", 0.0))
		and float(atmospheric_exterior.get("effect_emission", 1.0)) <= 0.95
		and midpoint_physical_scale > 1.0
		and midpoint_physical_scale < physical_segments.scale.x
		and physical_segments.scale.x <= 1.06
		and physical_segments.multimesh.visible_instance_count == 5,
		"accepted intensity continuously increases bounded steady reduced-flash heat opacity and scale",
	)

	var climb := production.advance_from_caller_sample(
		9, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, 15.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var climb_presentation := entry_presenter.call(&"get_snapshot") as Dictionary
	_check(
		bool(climb.get("accepted", false))
		and climb_presentation.get("descent_advisory_id") == &"climb_exit"
		and str(climb_presentation.get("descent_advisory_copy", "")) \
			== "[ CLIMB / EXIT // 15 M/S UP // ALT 10000 M ]",
		"the same production sample visibly distinguishes climb or exit",
	)
	_check(
		bridge.get("physics_authority") == false
		and bridge.get("movement_authority") == false
		and bridge.get("damage_authority") == false
		and bridge.get("landing_authority") == false,
		"the production bridge reports presentation-only authority",
	)
	var cockpit_before_fence := physical_entry_readout.call(
		&"get_snapshot"
	) as Dictionary
	var cockpit_generation := int(physical_entry_readout.call(&"get_generation"))
	var physical_readout_id := physical_entry_readout.get_instance_id()
	var last_cockpit_serial := int(cockpit_before_fence.get(
		"last_observation_serial", -1
	))
	var stale_generation := physical_entry_readout.call(
		&"present_source", source, last_cockpit_serial + 1,
		cockpit_generation - 1
	) as Dictionary
	var replayed_observation := physical_entry_readout.call(
		&"present_source", source, last_cockpit_serial, cockpit_generation
	) as Dictionary
	var cockpit_after_fence := physical_entry_readout.call(
		&"get_snapshot"
	) as Dictionary
	var exterior_before_fence := physical_exterior.call(
		&"get_snapshot"
	) as Dictionary
	var exterior_generation := int(physical_exterior.call(&"get_generation"))
	var physical_exterior_id := physical_exterior.get_instance_id()
	var last_exterior_serial := int(exterior_before_fence.get(
		"last_observation_serial", -1
	))
	var stale_exterior := physical_exterior.call(
		&"present_envelope", atmospheric_cockpit, &"atmospheric", 1.0,
		true, true,
		last_exterior_serial + 1, exterior_generation - 1
	) as Dictionary
	var replayed_exterior := physical_exterior.call(
		&"present_envelope", atmospheric_cockpit, &"atmospheric", 1.0,
		true, true,
		last_exterior_serial, exterior_generation
	) as Dictionary
	var exterior_after_fence := physical_exterior.call(
		&"get_snapshot"
	) as Dictionary
	_check(
		not bool(stale_generation.get("accepted", true))
		and stale_generation.get("reason") == &"stale_generation"
		and not bool(replayed_observation.get("accepted", true))
		and replayed_observation.get("reason") \
			== &"observation_serial_replayed"
		and cockpit_after_fence.get("text") == cockpit_before_fence.get("text")
		and cockpit_after_fence.get("envelope_gauge") \
			== cockpit_before_fence.get("envelope_gauge")
		and not bool(stale_exterior.get("accepted", true))
		and stale_exterior.get("reason") == &"stale_generation"
		and not bool(replayed_exterior.get("accepted", true))
		and replayed_exterior.get("reason") \
			== &"observation_serial_replayed"
		and exterior_after_fence.get("marker_text") \
			== exterior_before_fence.get("marker_text")
		and exterior_after_fence.get("visible_segment_count") \
			== exterior_before_fence.get("visible_segment_count"),
		"stale generations and replays cannot mutate either retained envelope",
	)
	var entry_binding := production.get("_entry_presentation_binding") as RefCounted
	var detached := entry_binding.call(&"detach") as Dictionary
	var cleared_wash := physical_wash.call(&"get_snapshot") as Dictionary
	var cleared_physical := physical_entry_readout.call(&"get_snapshot") as Dictionary
	var cleared_exterior := physical_exterior.call(&"get_snapshot") as Dictionary
	var detached_wash := entry_binding.call(&"get_snapshot").get(
		"landing_wash", {}
	) as Dictionary
	var detached_cockpit := entry_binding.call(&"get_snapshot").get(
		"cockpit_readout", {}
	) as Dictionary
	_check(
		bool(detached.get("accepted", false))
		and is_zero_approx(float(detached_wash.get("intensity", -1.0)))
		and detached_wash.get("visible") == false
		and detached_wash.get("last_reason") == &"detached_zero"
		and cleared_wash.get("last_reason") == &"detached_zero"
		and is_zero_approx(float(cleared_wash.get("dust_opacity", -1.0)))
		and is_equal_approx(float(cleared_wash.get("dust_scale", 0.0)), 1.0)
		and is_zero_approx(float(cleared_wash.get(
			"thruster_opacity", -1.0
		)))
		and is_equal_approx(float(cleared_wash.get(
			"thruster_scale", 0.0
		)), 1.0)
		and cleared_wash.get("landing_supported") == false
		and not physical_dust.emitting
		and is_zero_approx(physical_dust.color.a)
		and physical_dust.scale.is_equal_approx(Vector3.ONE)
		and not physical_thruster.visible
		and physical_thruster.scale.is_equal_approx(Vector3.ONE)
		and is_zero_approx(physical_thruster_material.albedo_color.a)
		and detached_cockpit.get("visible") == false
		and detached_cockpit.get("text") == ""
		and cleared_physical.get("visible") == false
		and cleared_physical.get("text") == ""
		and int(cleared_physical.get("generation", -1)) \
			== cockpit_generation + 1
		and int((cleared_physical.get(
			"envelope_gauge", {}
		) as Dictionary).get("filled_segments", -1)) == 0
		and cleared_exterior.get("visible") == false
		and cleared_exterior.get("visible_segment_count") == 0
		and is_zero_approx(float(cleared_exterior.get(
			"atmospheric_intensity", -1.0
		)))
		and is_zero_approx(float(cleared_exterior.get(
			"effect_opacity", -1.0
		)))
		and is_equal_approx(float(cleared_exterior.get(
			"effect_scale", 0.0
		)), 1.0)
		and cleared_exterior.get("recovery_ring_visible") == false
		and physical_segments.scale.is_equal_approx(Vector3.ONE)
		and is_zero_approx(physical_segment_material.albedo_color.a)
		and is_zero_approx(
			physical_segment_material.emission_energy_multiplier
		)
		and is_zero_approx(float(
			arrow.get_entry_heat_target().get_material().get_shader_parameter(
				&"entry_effect_intensity_unitless"
			)
		))
		and int(cleared_exterior.get("generation", -1)) \
			== exterior_generation + 1,
		"detach clears wash and both generation-fenced physical envelopes",
	)
	await process_frame
	var reattached := entry_binding.call(&"attach", arrow, hud) as Dictionary
	var reentered := entry_binding.call(
		&"present_observation", 100.0, 340.0, -12.0, false
	) as Dictionary
	var reentry_readout := arrow.get_arrow_visual_root().get_node_or_null(
		^"CockpitInterior/InstrumentCluster/EntryDescentReadout"
	) as Label3D
	var reentry_snapshot := reentry_readout.call(&"get_snapshot") as Dictionary \
		if reentry_readout != null else {}
	var reentry_exterior := arrow.get_arrow_visual_root().get_node_or_null(
		^"ArrowEntryExteriorEnvelope"
	) as Node3D
	var reentry_exterior_snapshot := reentry_exterior.call(
		&"get_snapshot"
	) as Dictionary if reentry_exterior != null else {}
	var reentry_wash := arrow.get_arrow_visual_root().get_node_or_null(
		^"ArrowLandingDustWashPresentation"
	) as Node3D
	var reentry_wash_snapshot := reentry_wash.call(
		&"get_snapshot"
	) as Dictionary if reentry_wash != null else {}
	var reentry_dust := reentry_wash.get_node_or_null(
		^"ShipLocalDustWash"
	) as CPUParticles3D if reentry_wash != null else null
	_check(
		bool(reattached.get("accepted", false))
		and bool(reentered.get("accepted", false))
		and reentry_wash != null
		and reentry_wash.get_instance_id() != physical_wash_id
		and is_zero_approx(float(reentry_wash_snapshot.get(
			"dust_opacity", -1.0
		)))
		and is_equal_approx(float(reentry_wash_snapshot.get(
			"dust_scale", 0.0
		)), 1.0)
		and reentry_wash_snapshot.get("dust_renderer_visible") == false
		and reentry_dust != null and not reentry_dust.visible
		and not reentry_dust.emitting
		and reentry_wash_snapshot.get("landing_supported") == false
		and reentry_readout != null
		and reentry_readout.get_instance_id() != physical_readout_id
		and reentry_snapshot.get("text") \
			== "ATM HEAT | [!!] CRITICAL | E[#####] 5/5"
		and (reentry_snapshot.get("envelope_gauge", {}) as Dictionary).get(
			"recovery"
		) == false
		and int(reentry_snapshot.get("generation", -1)) == 1
		and reentry_exterior != null
		and reentry_exterior.get_instance_id() != physical_exterior_id
		and reentry_exterior_snapshot.get("visible_segment_count") == 5
		and is_equal_approx(float(reentry_exterior_snapshot.get(
			"atmospheric_intensity", -1.0
		)), 1.0)
		and float(reentry_exterior_snapshot.get("effect_opacity", 0.0)) > 0.0
		and reentry_exterior_snapshot.get("recovery") == false
		and int(reentry_exterior_snapshot.get("generation", -1)) == 1,
		"re-entry creates a clean envelope generation without inherited recovery",
	)
	entry_binding.call(&"detach")

	composition.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ARROW_ENTRY_PRESENTATION_PRODUCTION_CALLER_TEST_OK: 12 assertions")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
