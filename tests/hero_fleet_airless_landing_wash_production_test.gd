extends SceneTree

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const BindingScript := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
)

var _failures := PackedStringArray()


class ProductionProbe:
	extends BindingScript

	var probe_phase := EmberSurfaceLoopHost.Phase.LANDING_APPROACH

	func prepare_early_tick(
			caller_serial: int, _delta: float, _actor_sample: Variant,
			_origin_result: Variant, _frame_generation: int,
			_location_generation: int, _expected_generation: int
		) -> Dictionary:
		set("_pending_envelope", {"caller_serial": caller_serial})
		return {"accepted": true, "reason": &"probe_prepared"}

	func get_host_phase() -> int:
		return probe_phase


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft_cases := [
		{"id": &"torrent", "scene": TORRENT_SCENE},
		{"id": &"jovian", "scene": JOVIAN_SCENE},
		{"id": &"zenith", "scene": ZENITH_SCENE},
		{"id": &"halyard", "scene": HALYARD_SCENE},
	]
	var prior_wash_instance_id := 0
	for craft_case: Dictionary in craft_cases:
		var composition := Node3D.new()
		composition.name = "%sLandingWashProductionRoot" % String(craft_case.id)
		root.add_child(composition)
		var hud := GameHUD.new()
		hud.name = "HUD"
		composition.add_child(hud)
		var scene := craft_case.scene as PackedScene
		var ship := scene.instantiate() as HeroShip
		composition.add_child(ship)
		ship.set_physics_process(false)
		await process_frame

		var production := _production_for(composition, ship)
		production.set("_last_planetary_altitude_m", 100.0)
		var partial := _advance(production, ship, 1, -12.0)
		var partial_snapshot := production.get_snapshot()
		var partial_binding := partial_snapshot.get(
			"fleet_landing_wash_presentation", {}
		) as Dictionary
		var partial_wash := partial_binding.get("wash", {}) as Dictionary
		var anchor := partial_binding.get("anchor", {}) as Dictionary
		var landing_bounds := anchor.get("landing_bounds", AABB()) as AABB
		var visual_root := ship.get_variant_visual_root()
		var wash_node := visual_root.get_node_or_null(
			^"AirlessLandingDustWashPresentation"
		) as Node3D if visual_root != null else null
		var dust := wash_node.get_node_or_null(
			^"ShipLocalDustWash"
		) as CPUParticles3D if wash_node != null else null
		var contact_y := float(anchor.get("contact_plane_y", NAN))
		var partial_opacity := float(partial_wash.get("dust_opacity", 0.0))
		var partial_scale := float(partial_wash.get("dust_scale", 0.0))
		var first_wash_instance_id := wash_node.get_instance_id() \
			if wash_node != null else 0
		var partial_anchor_ok := wash_node != null and dust != null \
			and wash_node.get_parent() == visual_root \
			and (wash_node.position + dust.position).is_equal_approx(
				Vector3(
					landing_bounds.get_center().x,
					contact_y,
					landing_bounds.get_center().z,
				)
			)
		var partial_dust_emitting := dust != null and dust.emitting
		var partial_dust_visible := dust != null and dust.visible

		production.set("_last_planetary_altitude_m", 45.0)
		var full := _advance(production, ship, 2, -60.0)
		var full_binding := production.get_snapshot().get(
			"fleet_landing_wash_presentation", {}
		) as Dictionary
		var full_wash := full_binding.get("wash", {}) as Dictionary
		hud.set_reduced_flash(true)
		hud.set_reduced_motion(true)
		var reduced := _advance(production, ship, 3, -60.0)
		var reduced_binding := production.get_snapshot().get(
			"fleet_landing_wash_presentation", {}
		) as Dictionary
		var reduced_wash := reduced_binding.get("wash", {}) as Dictionary

		production.probe_phase = EmberSurfaceLoopHost.Phase.DESCENT
		var unsupported := _advance(production, ship, 4, -60.0)
		var unsupported_binding := production.get_snapshot().get(
			"fleet_landing_wash_presentation", {}
		) as Dictionary
		var unsupported_wash := unsupported_binding.get("wash", {}) as Dictionary
		var retained := production.call(
			&"_attach_fleet_landing_wash_presentation"
		) as Dictionary
		var duplicate_count := visual_root.find_children(
			"AirlessLandingDustWashPresentation", "Node3D", false, false
		).size()
		var footprint_baseline := Vector3(
			float(unsupported_wash.get("footprint_lateral_scale", 0.0)),
			1.0,
			float(unsupported_wash.get("footprint_longitudinal_scale", 0.0)),
		)
		var unsupported_dust_scale := dust.scale \
			if dust != null else Vector3.ZERO
		var unsupported_dust_visible := dust != null and dust.visible
		var fleet_binding := production.get(
			"_fleet_landing_wash_binding"
		) as RefCounted
		var detached := fleet_binding.call(&"detach") as Dictionary
		var cleared := wash_node.call(&"get_snapshot") as Dictionary
		var cleared_dust_scale := dust.scale if dust != null else Vector3.ZERO
		var cleared_dust_visible := dust != null and dust.visible
		await process_frame
		var removed_after_detach := visual_root.get_node_or_null(
			^"AirlessLandingDustWashPresentation"
		) == null
		production.queue_free()
		await process_frame

		hud.set_reduced_flash(false)
		hud.set_reduced_motion(false)
		var reentry_production := _production_for(composition, ship)
		reentry_production.set("_last_planetary_altitude_m", 45.0)
		var reentered := _advance(reentry_production, ship, 1, -60.0)
		var reentry_binding := reentry_production.get_snapshot().get(
			"fleet_landing_wash_presentation", {}
		) as Dictionary
		var reentry_wash := reentry_binding.get("wash", {}) as Dictionary
		var reentry_node := visual_root.get_node_or_null(
			^"AirlessLandingDustWashPresentation"
		) as Node3D
		var reentry_count := visual_root.find_children(
			"AirlessLandingDustWashPresentation", "Node3D", false, false
		).size()
		var reentry_id := reentry_node.get_instance_id() \
			if reentry_node != null else 0
		var reentry_dust := reentry_node.get_node_or_null(
			^"ShipLocalDustWash"
		) as CPUParticles3D if reentry_node != null else null

		_check(
			bool(partial.get("accepted", false))
			and partial_binding.get("attached") == true
			and partial_binding.get("craft_id") == craft_case.id
			and anchor.get("collision_derived") == true
			and first_wash_instance_id > 0
			and partial_anchor_ok and partial_dust_emitting
			and partial_dust_visible
			and partial_wash.get("dust_renderer_visible") == true
			and partial_opacity > 0.0 and partial_scale > 1.0
			and bool(full.get("accepted", false))
			and is_equal_approx(float(full_wash.get(
				"presentation_load", -1.0
			)), 1.0)
			and float(full_wash.get("dust_opacity", 0.0)) > partial_opacity
			and float(full_wash.get("dust_scale", 0.0)) > partial_scale
			and bool(reduced.get("accepted", false))
			and float(reduced_wash.get("dust_opacity", 1.0)) \
				< float(full_wash.get("dust_opacity", 0.0))
			and float(reduced_wash.get("dust_opacity", 1.0)) <= 0.324
			and float(reduced_wash.get("dust_scale", 2.0)) <= 1.22
			and bool(unsupported.get("accepted", false))
			and unsupported_wash.get("last_reason") \
				== &"landing_support_unavailable"
			and is_zero_approx(float(unsupported_wash.get(
				"dust_opacity", -1.0
			)))
			and unsupported_dust_scale.is_equal_approx(footprint_baseline)
			and not unsupported_dust_visible
			and unsupported_wash.get("dust_renderer_visible") == false
			and bool(retained.get("accepted", false))
			and retained.get("reason") == &"landing_wash_retained"
			and duplicate_count == 1
			and partial_binding.get("duplicate_nodes") == 0
			and partial_binding.get("physics_authority") == false
			and partial_binding.get("movement_authority") == false
			and partial_binding.get("landing_authority") == false
			and partial_binding.get("damage_authority") == false
			and bool(detached.get("accepted", false))
			and cleared.get("last_reason") == &"detached_zero"
			and is_zero_approx(float(cleared.get("dust_opacity", -1.0)))
			and cleared_dust_scale.is_equal_approx(footprint_baseline)
			and not cleared_dust_visible
			and cleared.get("dust_renderer_visible") == false
			and removed_after_detach
			and bool(reentered.get("accepted", false))
			and reentry_node != null and reentry_count == 1
			and reentry_id != first_wash_instance_id
			and reentry_id != prior_wash_instance_id
			and float(reentry_wash.get("dust_opacity", 0.0)) > 0.0
			and reentry_wash.get("dust_renderer_visible") == true
			and reentry_dust != null and reentry_dust.visible
			and reentry_dust.emitting,
			"%s gets one anchored, bounded, lifecycle-clean production wash" \
				% String(craft_case.id),
		)
		prior_wash_instance_id = reentry_id
		reentry_production.queue_free()
		await process_frame
		_check(
			visual_root.get_node_or_null(
				^"AirlessLandingDustWashPresentation"
			) == null,
			"%s craft switch retires its retained wash" % String(craft_case.id),
		)
		composition.queue_free()
		await process_frame

	if _failures.is_empty():
		print("HERO_FLEET_AIRLESS_LANDING_WASH_PRODUCTION_TEST_OK: 8 assertions")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _production_for(composition: Node3D, ship: HeroShip) -> ProductionProbe:
	var production := ProductionProbe.new()
	composition.add_child(production)
	production.set("_composition_root", composition)
	production.set("_ship", ship)
	production.set("_ship_instance_id", ship.get_instance_id())
	return production


func _advance(
		production: ProductionProbe, ship: HeroShip, serial: int,
		vertical_speed_mps: float
	) -> Dictionary:
	return production.advance_from_caller_sample(
		serial, 1.0 / 60.0, &"ship", ship.get_instance_id(),
		ship.get_instance_id(), Vector3.ZERO,
		Vector3(0.0, vertical_speed_mps, 340.0),
		false, false, false, {}, 1, 1, 0
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
