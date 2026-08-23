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
	var physical_entry_readout := arrow.get_arrow_visual_root().get_node_or_null(
		^"CockpitInterior/InstrumentCluster/EntryDescentReadout"
	) as Label3D
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
		and normal_wash.get("thruster_visible_count") == 2
		and normal_wash.get("collision_authority") == false
		and normal_wash.get("movement_authority") == false
		and normal_wash.get("damage_authority") == false
		and normal_wash.get("atmosphere_authority") == false
		and normal_wash.get("landing_authority") == false
		and safe_cockpit.get("text") == "AIRLESS | [v] DESCENT SAFE"
		and safe_cockpit.get("symbol") == &"[v]"
		and safe_cockpit.get("color_independent") == true
		and safe_cockpit.get("collision_authority") == false
		and safe_cockpit.get("movement_authority") == false
		and safe_cockpit.get("damage_authority") == false
		and safe_cockpit.get("landing_authority") == false
		and physical_entry_readout != null
		and physical_entry_readout.text == safe_cockpit.get("text")
		and hud.get("_runtime_status_kind") == &"entry",
		"low Ember descent reaches HUD, landing wash, and the physical cockpit readout",
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
	_check(
		bool(reduced.get("accepted", false))
		and float(reduced_wash.get("intensity", 0.0)) \
			< float(normal_wash.get("intensity", 0.0))
		and reduced_wash.get("reduced_flash") == true
		and reduced_wash.get("reduced_motion") == true
		and reduced_wash.get("steady_emission") == true
		and reduced_cockpit.get("reduced_flash") == true
		and reduced_cockpit.get("reduced_motion") == true
		and reduced_cockpit.get("steady") == true,
		"reduced settings lower the wash and retain steady emission",
	)

	var high_sink_airless := production.advance_from_caller_sample(
		3, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -60.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var high_sink_cockpit := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("cockpit_readout", {}) as Dictionary
	_check(
		bool(high_sink_airless.get("accepted", false))
		and high_sink_cockpit.get("text") == "AIRLESS | [!!] HIGH SINK"
		and high_sink_cockpit.get("symbol") == &"[!!]"
		and high_sink_cockpit.get("steady") == true
		and physical_entry_readout.text == high_sink_cockpit.get("text"),
		"high sink is legible on the physical display without relying on color",
	)

	var climbing_airless := production.advance_from_caller_sample(
		4, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, 15.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var climb_zero := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	var climb_cockpit := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("cockpit_readout", {}) as Dictionary
	_check(
		bool(climbing_airless.get("accepted", false))
		and is_zero_approx(float(climb_zero.get("intensity", -1.0)))
		and climb_zero.get("dust_emitting") == false
		and climb_zero.get("last_reason") == &"climb_or_level_zero"
		and climb_cockpit.get("text") == "AIRLESS | [^] CLIMB / EXIT",
		"climb immediately clears the landing wash to exact zero",
	)

	production.set("_last_planetary_altitude_m", 500.0)
	var high_airless := production.advance_from_caller_sample(
		5, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, -20.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var high_zero := (
		production.get_snapshot().entry_presentation as Dictionary
	).get("landing_wash", {}) as Dictionary
	_check(
		bool(high_airless.get("accepted", false))
		and is_zero_approx(float(high_zero.get("intensity", -1.0)))
		and high_zero.get("last_reason") == &"high_altitude_zero",
		"high-altitude descent keeps the landing wash at exact zero",
	)

	var atmosphere := AtmosphereProbe.new()
	atmosphere.atmosphere_profile = AURORA_ATMOSPHERE
	composition.add_child(atmosphere)
	production.set("_atmosphere_composition", atmosphere)
	production.set("_last_planetary_altitude_m", 10_000.0)
	var atmospheric := production.advance_from_caller_sample(
		6, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
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
	_check(
		bool(atmospheric.get("accepted", false))
		and source.get("branch_id") == &"atmospheric"
		and is_equal_approx(float(entry.get("entry_intensity", 0.0)), 1.0)
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
			== "ATM HEAT | [!!] CRITICAL"
		and atmospheric_cockpit.get("symbol") == &"[!!]"
		and atmospheric_cockpit.get("steady") == true,
		"atmospheric altitude and Arrow speed drive visible steady reduced-flash heat guidance",
	)

	var climb := production.advance_from_caller_sample(
		7, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
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
	var entry_binding := production.get("_entry_presentation_binding") as RefCounted
	var detached := entry_binding.call(&"detach") as Dictionary
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
		and detached_cockpit.get("visible") == false
		and detached_cockpit.get("text") == "",
		"detaching the production bridge clears the wash to exact zero",
	)

	composition.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ARROW_ENTRY_PRESENTATION_PRODUCTION_CALLER_TEST_OK: 9 assertions")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
