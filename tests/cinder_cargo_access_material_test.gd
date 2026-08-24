extends SceneTree

const ACCESS_SCENE := preload("res://scenes/world/components/cinder_cargo_access.tscn")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var access := ACCESS_SCENE.instantiate() as CinderCargoAccess
	root.add_child(access)
	await process_frame
	var materials := access.get("_materials") as Dictionary
	_check(
		_panel_finish(materials.get("route"), StationSurfaceKit.WALKED_CLEARCOAT,
			StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS)
		and _panel_finish(materials.get("deck"), StationSurfaceKit.WALKED_CLEARCOAT,
			StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS)
		and _panel_finish(materials.get("grip"), StationSurfaceKit.WALKED_CLEARCOAT,
			StationSurfaceKit.WALKED_CLEARCOAT_ROUGHNESS),
		"walked route, deck, and grip use the registered walked-deck finish"
	)
	_check(
		_panel_finish(materials.get("frame"), StationSurfaceKit.STRUCTURAL_CLEARCOAT,
			StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS)
		and _panel_finish(materials.get("service"), StationSurfaceKit.STRUCTURAL_CLEARCOAT,
			StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS),
		"route frame and service supports use the structural-alloy finish"
	)
	_check(
		(materials.cargo as StandardMaterial3D).albedo_color.is_equal_approx(
			CinderCargoAccess.DECK_COLOR)
		and (materials.grip as StandardMaterial3D).albedo_color.is_equal_approx(
			CinderCargoAccess.STEP_COLOR)
		and (materials.frame as StandardMaterial3D).albedo_color.is_equal_approx(
			CinderCargoAccess.RAIL_COLOR),
		"cargo deck, grip, and frame retain the authored Cinder palette"
	)
	_check(
		_surface(access, ^"Structure/LandingDeck") == materials.cargo
		and _surface(access, ^"Structure/CrossCatwalk") == materials.route
		and _surface(access, ^"Structure/ConnectorStep1") == materials.grip
		and _surface(access, ^"Structure/TerminalApproachPlatform") == materials.deck
		and (access.get_node(^"Rails/CrossRailBatch") as MultiMeshInstance3D)
			.material_override == materials.frame
		and (access.get_node(^"Structure/TerminalApproachSupportBatch") as MultiMeshInstance3D)
			.material_override == materials.service,
		"live cargo, route, grip, deck, frame, and service geometry uses its physical role"
	)
	var cue := access.get_node(^"VisualRouteCues/RouteCueCyanBatch") as MultiMeshInstance3D
	var hazard := access.get_node(^"VisualRouteCues/RouteCueHazardBatch") as MultiMeshInstance3D
	_check(
		cue.material_override == materials.cue and hazard.material_override == materials.hazard
		and (materials.cue as StandardMaterial3D).albedo_texture == null
		and (materials.hazard as StandardMaterial3D).albedo_texture == null
		and bool(access.audit().valid),
		"cargo state emissives and the exact component geometry/render contract remain intact"
	)
	access.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER CARGO ACCESS MATERIAL TEST PASS" if _failures.is_empty() else "CINDER CARGO ACCESS MATERIAL TEST FAIL")
	quit(0 if _failures.is_empty() else 1)


func _surface(access: Node, body_path: NodePath) -> Material:
	var body := access.get_node_or_null(body_path) as StaticBody3D
	var mesh := body.get_node_or_null(^"Mesh") as MeshInstance3D if body != null else null
	return mesh.material_override if mesh != null else null


func _panel_finish(value: Variant, clearcoat: float, clearcoat_roughness: float) -> bool:
	var material := value as StandardMaterial3D
	return material != null \
		and material.albedo_texture != null \
		and material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH \
		and material.normal_enabled and material.normal_texture != null \
		and material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH \
		and material.roughness_texture != null \
		and material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH \
		and material.uv1_triplanar and material.uv1_world_triplanar \
		and material.uv1_scale.is_equal_approx(Vector3.ONE * CinderCargoAccess.PANEL_SURFACE_SCALE) \
		and material.clearcoat_enabled and is_equal_approx(material.clearcoat, clearcoat) \
		and is_equal_approx(material.clearcoat_roughness, clearcoat_roughness)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
