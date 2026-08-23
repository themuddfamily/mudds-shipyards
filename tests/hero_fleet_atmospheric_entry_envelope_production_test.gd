extends SceneTree

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const AURORA_ATMOSPHERE := preload(
	"res://assets/world/planets/aurora_temperate_atmosphere.tres"
)
const BindingScript := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
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
	var craft_cases := [
		{"id": &"torrent", "scene": TORRENT_SCENE},
		{"id": &"jovian", "scene": JOVIAN_SCENE},
		{"id": &"zenith", "scene": ZENITH_SCENE},
		{"id": &"halyard", "scene": HALYARD_SCENE},
	]
	var prior_envelope_instance_id := 0
	for craft_case: Dictionary in craft_cases:
		var composition := Node3D.new()
		composition.name = "%sEntryEnvelopeProductionRoot" % String(
			craft_case.id
		)
		root.add_child(composition)
		var hud := GameHUD.new()
		hud.name = "HUD"
		composition.add_child(hud)
		var scene := craft_case.scene as PackedScene
		var ship := scene.instantiate() as HeroShip
		composition.add_child(ship)
		ship.set_physics_process(false)
		var atmosphere := AtmosphereProbe.new()
		atmosphere.atmosphere_profile = AURORA_ATMOSPHERE
		composition.add_child(atmosphere)
		await process_frame

		var production := _production_for(composition, ship, atmosphere)
		production.set("_last_planetary_altitude_m", 14_000.0)
		var midpoint := _advance(production, ship, 1)
		var midpoint_binding := production.get_snapshot().get(
			"fleet_entry_envelope_presentation", {}
		) as Dictionary
		var midpoint_envelope := midpoint_binding.get("envelope", {}) \
			as Dictionary
		var anchor := midpoint_binding.get("anchor", {}) as Dictionary
		var visual_root := ship.get_variant_visual_root()
		var envelope_node := visual_root.get_node_or_null(
			^"AtmosphericEntryExteriorEnvelope"
		) as Node3D if visual_root != null else null
		var first_envelope_id := envelope_node.get_instance_id() \
			if envelope_node != null else 0
		var expected_center := anchor.get(
			"silhouette_center", Vector3.INF
		) as Vector3
		var silhouette_scale := anchor.get(
			"silhouette_scale", Vector3.ZERO
		) as Vector3
		var rendered_center := envelope_node.position + Vector3(
			0.0,
			4.25 * envelope_node.scale.y,
			4.75,
		) if envelope_node != null else Vector3.ZERO
		var ship_local_anchor_ok := envelope_node != null \
			and envelope_node.get_parent() == visual_root \
			and rendered_center.is_equal_approx(expected_center)
		var midpoint_opacity := float(midpoint_envelope.get(
			"effect_opacity", 0.0
		))
		var midpoint_scale := float(midpoint_envelope.get(
			"effect_scale", 1.0
		))

		production.set("_last_planetary_altitude_m", 10_000.0)
		var full := _advance(production, ship, 2)
		var full_binding := production.get_snapshot().get(
			"fleet_entry_envelope_presentation", {}
		) as Dictionary
		var full_envelope := full_binding.get("envelope", {}) as Dictionary
		hud.set_reduced_flash(true)
		hud.set_reduced_motion(true)
		var reduced := _advance(production, ship, 3)
		var reduced_binding := production.get_snapshot().get(
			"fleet_entry_envelope_presentation", {}
		) as Dictionary
		var reduced_envelope := reduced_binding.get("envelope", {}) as Dictionary

		production.set("_atmosphere_composition", null)
		var airless := _advance(production, ship, 4)
		var airless_binding := production.get_snapshot().get(
			"fleet_entry_envelope_presentation", {}
		) as Dictionary
		var airless_envelope := airless_binding.get("envelope", {}) as Dictionary
		var retained := production.call(
			&"_attach_fleet_entry_envelope_presentation"
		) as Dictionary
		var duplicate_count := visual_root.find_children(
			"AtmosphericEntryExteriorEnvelope", "Node3D", false, false
		).size()
		var fleet_binding := production.get(
			"_fleet_entry_envelope_binding"
		) as RefCounted
		var detached := fleet_binding.call(&"detach") as Dictionary
		var cleared := envelope_node.call(&"get_snapshot") as Dictionary
		production.set("_fleet_entry_envelope_binding", null)
		await process_frame
		var removed_after_detach := visual_root.get_node_or_null(
			^"AtmosphericEntryExteriorEnvelope"
		) == null
		production.queue_free()
		await process_frame

		hud.set_reduced_flash(false)
		hud.set_reduced_motion(false)
		var reentry_production := _production_for(composition, ship, atmosphere)
		reentry_production.set("_last_planetary_altitude_m", 10_000.0)
		var reentered := _advance(reentry_production, ship, 1)
		var reentry_binding := reentry_production.get_snapshot().get(
			"fleet_entry_envelope_presentation", {}
		) as Dictionary
		var reentry_envelope := reentry_binding.get("envelope", {}) as Dictionary
		var reentry_node := visual_root.get_node_or_null(
			^"AtmosphericEntryExteriorEnvelope"
		) as Node3D
		var reentry_count := visual_root.find_children(
			"AtmosphericEntryExteriorEnvelope", "Node3D", false, false
		).size()
		var reentry_id := reentry_node.get_instance_id() \
			if reentry_node != null else 0
		_check(
			bool(midpoint.get("accepted", false))
			and midpoint_binding.get("attached") == true
			and midpoint_binding.get("craft_id") == craft_case.id
			and anchor.get("collision_derived") == true
			and ship_local_anchor_ok
			and first_envelope_id > 0
			and silhouette_scale.x >= 0.75 and silhouette_scale.x <= 2.5
			and silhouette_scale.y >= 0.75 and silhouette_scale.y <= 2.0
			and is_equal_approx(float(midpoint_envelope.get(
				"atmospheric_intensity", -1.0
			)), 0.5)
			and midpoint_opacity > 0.0 and midpoint_scale > 1.0
			and bool(full.get("accepted", false))
			and is_equal_approx(float(full_envelope.get(
				"atmospheric_intensity", -1.0
			)), 1.0)
			and float(full_envelope.get("effect_opacity", 0.0)) \
				> midpoint_opacity
			and float(full_envelope.get("effect_scale", 1.0)) \
				> midpoint_scale
			and bool(reduced.get("accepted", false))
			and float(reduced_envelope.get("effect_opacity", 1.0)) \
				< float(full_envelope.get("effect_opacity", 0.0))
			and float(reduced_envelope.get("effect_opacity", 1.0)) <= 0.42
			and float(reduced_envelope.get("effect_scale", 2.0)) <= 1.06
			and bool(airless.get("accepted", false))
			and not bool(airless_envelope.get("visible", true))
			and is_zero_approx(float(airless_envelope.get(
				"atmospheric_intensity", -1.0
			)))
			and is_zero_approx(float(airless_envelope.get(
				"effect_opacity", -1.0
			)))
			and airless_envelope.get("airless_zero") == true
			and bool(retained.get("accepted", false))
			and retained.get("reason") == &"entry_envelope_retained"
			and duplicate_count == 1
			and midpoint_binding.get("duplicate_nodes") == 0
			and midpoint_binding.get("physics_authority") == false
			and midpoint_binding.get("movement_authority") == false
			and midpoint_binding.get("heat_authority") == false
			and midpoint_binding.get("atmosphere_authority") == false
			and midpoint_binding.get("damage_authority") == false
			and bool(detached.get("accepted", false))
			and cleared.get("reason") == &"detached"
			and not bool(cleared.get("visible", true))
			and is_zero_approx(float(cleared.get("effect_opacity", -1.0)))
			and removed_after_detach
			and bool(reentered.get("accepted", false))
			and reentry_node != null and reentry_count == 1
			and reentry_id != first_envelope_id
			and reentry_id != prior_envelope_instance_id
			and float(reentry_envelope.get("effect_opacity", 0.0)) > 0.0,
			"%s gets one anchored, bounded, lifecycle-clean production envelope" \
				% String(craft_case.id),
		)
		prior_envelope_instance_id = reentry_id
		reentry_production.queue_free()
		await process_frame
		_check(
			visual_root.get_node_or_null(
				^"AtmosphericEntryExteriorEnvelope"
			) == null,
			"%s craft switch retires its retained envelope" % String(
				craft_case.id
			),
		)
		composition.queue_free()
		await process_frame

	if _failures.is_empty():
		print(
			"HERO_FLEET_ATMOSPHERIC_ENTRY_ENVELOPE_PRODUCTION_TEST_OK: "
			+ "8 assertions"
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _production_for(
		composition: Node3D, ship: HeroShip, atmosphere: Node
	) -> ProductionProbe:
	var production := ProductionProbe.new()
	composition.add_child(production)
	production.set("_composition_root", composition)
	production.set("_ship", ship)
	production.set("_ship_instance_id", ship.get_instance_id())
	production.set("_atmosphere_composition", atmosphere)
	return production


func _advance(
		production: ProductionProbe, ship: HeroShip, serial: int
	) -> Dictionary:
	return production.advance_from_caller_sample(
		serial, 1.0 / 60.0, &"ship", ship.get_instance_id(),
		ship.get_instance_id(), Vector3.ZERO,
		Vector3(0.0, -60.0, 340.0),
		false, false, false, {}, 1, 1, 0
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
