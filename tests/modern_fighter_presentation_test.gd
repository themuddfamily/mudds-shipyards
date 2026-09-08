extends SceneTree

## The modern fighter shells must survive the existing reuse transaction while
## their art never adds collision or blocks the Arrow pilot's physical view.
var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for ship_name in ["arrow_recon_ship", "zenith_interceptor"]:
		var ship := load("res://scenes/ships/" + ship_name + ".tscn").instantiate() as HeroShip
		root.add_child(ship)
		await process_frame
		ship.set_physics_process(false)
		var colliders := ship.find_children("*", "CollisionShape3D", true, false)
		var collider_ids: Array[int] = []
		for collider in colliders:
			collider_ids.append(collider.get_instance_id())
		var art: Node3D
		if ship is ArrowReconShip:
			art = (ship as ArrowReconShip).get_arrow_visual_root()
			_check(art.has_node("PortShoulderFairing") and art.has_node("StarboardShoulderFairing"), "Arrow has paired manufactured shoulders")
			var glass := art.get_node("CanopyHinge/CanopyGlass") as MeshInstance3D
			var camera := art.find_child("CockpitCamera", true, false) as Camera3D
			_check(glass.layers == 1 << 18 and not camera.get_cull_mask_value(19), "Arrow reflective canopy remains outside the pilot's sight layer")
			ship.set_canopy_open(false, 0.0)
			var hood := art.find_child("InstrumentHood", true, false) as MeshInstance3D
			var glazing_bounds := glass.mesh.get_aabb()
			_check(glazing_bounds.has_point(glass.to_local(camera.global_position)) and glazing_bounds.has_point(glass.to_local(hood.global_position)), "Arrow closed glazing spans the pilot eye and forward instruments")
			_check((ship as ArrowReconShip).get_escape_pod_count() == 2, "Arrow retains both independent escape pods")
		else:
			art = (ship as ZenithInterceptor).get_zenith_visual_root().get_node("ModernManufacturedAirframe")
			_check(art.find_children("*", "CollisionObject3D", true, false).is_empty() and art.find_children("*", "CollisionShape3D", true, false).is_empty(), "Zenith modern shells have no collision authority")
			_check(art.has_node("BlendedPressureHull") and art.has_node("PortBlendedDeltaWing"), "Zenith uses its manufactured pressure hull and delta wings")
		var art_id := art.get_instance_id()
		ship.set_canopy_open(true, 0.0)
		ship.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)))
		await process_frame
		_check(is_instance_valid(art) and art.get_instance_id() == art_id and art.is_visible_in_tree(), ship_name + " retains the same modern art through reuse")
		var after := ship.find_children("*", "CollisionShape3D", true, false)
		var after_ids: Array[int] = []
		for collider in after:
			after_ids.append(collider.get_instance_id())
		_check(collider_ids == after_ids, ship_name + " retains collision identities through reuse")
		ship.queue_free()
		await process_frame
	if failures.is_empty():
		print("MODERN_FIGHTER_PRESENTATION_TEST_OK")
		quit(0)
	else:
		push_error("MODERN_FIGHTER_PRESENTATION_TEST_FAILED: " + "; ".join(failures))
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
