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
	var airless := production.advance_from_caller_sample(
		1, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, 0.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var airless_snapshot := production.get_snapshot()
	var airless_entry := airless_snapshot.last_entry_presentation_result as Dictionary
	var airless_source := airless_entry.get("source", {}) as Dictionary
	_check(
		bool(airless.get("accepted", false))
		and airless_source.get("branch_id") == &"airless"
		and is_zero_approx(float(airless_source.get("entry_intensity", -1.0)))
		and hud.get("_runtime_status_kind") == &"entry",
		"the real caller sample presents Ember's airless zero-heat descent on HUD",
	)

	var atmosphere := AtmosphereProbe.new()
	atmosphere.atmosphere_profile = AURORA_ATMOSPHERE
	composition.add_child(atmosphere)
	production.set("_atmosphere_composition", atmosphere)
	production.set("_last_planetary_altitude_m", 10_000.0)
	hud.set_reduced_flash(true)
	hud.set_reduced_motion(true)
	var atmospheric := production.advance_from_caller_sample(
		2, 1.0 / 60.0, &"ship", arrow.get_instance_id(),
		arrow.get_instance_id(), Vector3.ZERO, Vector3(0.0, 0.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)
	var snapshot := production.get_snapshot()
	var entry := snapshot.last_entry_presentation_result as Dictionary
	var source := entry.get("source", {}) as Dictionary
	var bridge := snapshot.entry_presentation as Dictionary
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	_check(
		bool(atmospheric.get("accepted", false))
		and source.get("branch_id") == &"atmospheric"
		and is_equal_approx(float(entry.get("entry_intensity", 0.0)), 1.0)
		and title != null and title.text == "Critical Atmospheric Entry"
		and detail != null and detail.text.begins_with(
			"[ STEADY ENTRY LOAD CRITICAL ]"
		),
		"atmospheric altitude and Arrow speed drive visible steady reduced-flash heat guidance",
	)
	_check(
		bridge.get("physics_authority") == false
		and bridge.get("movement_authority") == false
		and bridge.get("damage_authority") == false
		and bridge.get("landing_authority") == false,
		"the production bridge reports presentation-only authority",
	)

	composition.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ARROW_ENTRY_PRESENTATION_PRODUCTION_CALLER_TEST_OK: 3 assertions")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
