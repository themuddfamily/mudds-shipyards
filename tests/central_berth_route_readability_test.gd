extends SceneTree

## Direct presentation-only check for the Central/Torrent berth route polish.
## The authored GuidanceCyan route gains a static threshold handoff from the
## regeneration deck; authority, collision, berth and lifecycle stay elsewhere.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates for berth route readability")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var presentation := world.get_central_berth_hero_presentation() \
		if world != null else null
	var torrent := game.get_node_or_null(^"TorrentInterceptor") as HeroShip
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(
		presentation != null and torrent != null and player != null,
		"live central presentation, landed Torrent, and production Player resolve",
	)
	if presentation == null or torrent == null or player == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var audit := presentation.get_asset_audit_report()
	_check(
		bool(audit.get("valid", false)),
		"route polish preserves the authored presentation contract: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("runtime_mesh_count", 0)) == 8
		and int(audit.get("runtime_surface_count", 0)) == 8
		and int(audit.get("total_render_mesh_count", 0)) == 9
		and int(audit.get("total_render_surface_count", 0)) == 9
		and int(audit.get("forbidden_authority_node_count", -1)) == 0
		and bool(audit.get("presentation_only", false))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("walking_surface_authority", true)),
		"authored eight-batch shell stays unchanged beside one bounded route draw"
	)

	var guidance := presentation.get_runtime_material(&"GuidanceCyan")
	_check(
		guidance != null
		and guidance.albedo_color.is_equal_approx(CentralBerthHeroPresentation.GUIDANCE_ALBEDO)
		and guidance.emission_enabled
		and guidance.emission.is_equal_approx(CentralBerthHeroPresentation.GUIDANCE_EMISSION)
		and is_equal_approx(
			guidance.emission_energy_multiplier,
			CentralBerthHeroPresentation.GUIDANCE_EMISSION_ENERGY
		),
		"authored route strips use the brighter high-separation cyan treatment"
	)

	var service_root := presentation.get_semantic_root(&"service_channels")
	var guidance_batches: Array[MeshInstance3D] = []
	if service_root != null:
		for candidate in service_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if StringName(mesh_instance.get_meta("central_berth_material_role", &"")) == &"GuidanceCyan" \
					and not mesh_instance.has_meta(&"central_berth_route_handoff"):
				guidance_batches.append(mesh_instance)
	_check(
		guidance_batches.size() == 1
		and guidance_batches[0].material_override == guidance
		and guidance_batches[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"one existing service-channel batch carries the route treatment without extra geometry"
	)

	var handoff := service_root.get_node_or_null(^"RegenerationDeckHandoff") as MeshInstance3D \
		if service_root != null else null
	_check(
		handoff != null
		and handoff.mesh != null
		and handoff.mesh.resource_name == String(CentralBerthHeroPresentation.ROUTE_HANDOFF_FAMILY_ID)
		and handoff.mesh.get_surface_count() == 1
		and handoff.mesh.get_aabb().is_equal_approx(CentralBerthHeroPresentation.ROUTE_HANDOFF_BOUNDS)
		and handoff.material_override == guidance
		and handoff.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and int(audit.get("route_handoff_member_count", 0)) == 8
		and int(audit.get("route_handoff_triangle_count", 0)) == 864,
		"one static batched pair of deck-seated handoff blades frames the real berth route; bounds=%s triangles=%d" % [
			handoff.mesh.get_aabb() if handoff != null and handoff.mesh != null else AABB(),
			presentation._mesh_triangle_count(handoff.mesh) if handoff != null and handoff.mesh != null else -1,
		]
	)
	var live_boarding_anchor := presentation.to_local(torrent.get_boarding_position())
	var heads := audit.get("route_handoff_heads", []) as Array
	var directions: Array[Vector3] = []
	var heads_aim_at_boarding := heads.size() == 2 \
		and live_boarding_anchor.is_equal_approx(
			CentralBerthHeroPresentation.ROUTE_HANDOFF_BOARDING_ANCHOR
		)
	for head_value: Variant in heads:
		var head := head_value as Dictionary
		var origin := head.get("origin", Vector3.INF) as Vector3
		var direction := head.get("direction", Vector3.ZERO) as Vector3
		var tip := head.get("tip", Vector3.INF) as Vector3
		var expected_direction := live_boarding_anchor - origin
		expected_direction.y = 0.0
		expected_direction = expected_direction.normalized()
		directions.append(direction)
		heads_aim_at_boarding = heads_aim_at_boarding \
			and direction.dot(expected_direction) >= 0.9999 \
			and (tip - origin).normalized().dot(expected_direction) >= 0.9999 \
			and tip.distance_to(live_boarding_anchor) < origin.distance_to(live_boarding_anchor)
	_check(
		heads_aim_at_boarding
		and directions.size() == 2
		and directions[0].x > 0.0
		and directions[1].x < 0.0
		and directions[0].dot(directions[1]) < 0.95,
		"side-specific chevron dots and endpoints aim at the live port boarding anchor %s" % live_boarding_anchor,
	)

	var capsule_contract := player.get_step_up_assist_audit()
	var capsule_radius := float(capsule_contract.get("capsule_radius", 0.0))
	var capsule_height := float(capsule_contract.get("capsule_height", 0.0))
	var jump_apex := player.jump_velocity * player.jump_velocity \
		/ (2.0 * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) \
			* player.gravity_multiplier)
	var spawn := world.get_node_or_null(^"%PlayerSpawn") as Marker3D
	var spawn_position := spawn.global_position if spawn != null else Vector3.INF
	var route := PackedVector3Array([
		Vector3(spawn_position.x, 0.095, spawn_position.z),
		Vector3(-8.0, 0.095, 7.0),
		Vector3(-7.0, 0.095, 3.0),
		Vector3(-5.0, 0.095, -2.0),
		Vector3(live_boarding_anchor.x, 0.095, live_boarding_anchor.z),
	])
	var assembly_bounds := _split_handoff_assembly_bounds(handoff.mesh)
	var standing_clear := assembly_bounds.size() == 2
	var jump_clear := assembly_bounds.size() == 2
	for bounds: AABB in assembly_bounds:
		standing_clear = standing_clear and _capsule_route_sweep_clear(
			route, bounds, capsule_radius, 0.095, 0.095 + capsule_height
		)
		jump_clear = jump_clear and _capsule_route_sweep_clear(
			route, bounds, capsule_radius, 0.095, 0.095 + capsule_height + jump_apex
		)
	_check(
		spawn_position.is_equal_approx(Vector3(-8.5, 0.18, 11.0))
		and is_equal_approx(capsule_radius, 0.38)
		and is_equal_approx(capsule_height, 1.94)
		and standing_clear
		and jump_clear,
		"both assemblies clear exact live 0.38 x 1.94 m standing and jump sweeps from PlayerSpawn through (-8, 7), (-7, 3), and boarding",
	)
	_check(
		is_equal_approx(
			(audit.get("route_handoff_bounds", AABB()) as AABB).position.y,
			CentralBerthHeroPresentation.EXPECTED_MAXIMUM.y,
		)
		and not handoff.has_method("_process")
		and not handoff.has_method("_physics_process")
		and handoff.find_children("*", "CollisionShape3D", true, false).is_empty()
		and handoff.find_children("*", "Light3D", true, false).is_empty(),
		"handoff is physically seated, non-coplanar, and non-authoritative"
	)

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


func _split_handoff_assembly_bounds(mesh: Mesh) -> Array[AABB]:
	var minima := [Vector3.INF, Vector3.INF]
	var maxima := [-Vector3.INF, -Vector3.INF]
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var index := 0 if vertex.x < 0.0 else 1
			minima[index] = (minima[index] as Vector3).min(vertex)
			maxima[index] = (maxima[index] as Vector3).max(vertex)
	return [
		AABB(minima[0] as Vector3, (maxima[0] as Vector3) - (minima[0] as Vector3)),
		AABB(minima[1] as Vector3, (maxima[1] as Vector3) - (minima[1] as Vector3)),
	]


func _capsule_route_sweep_clear(
		route: PackedVector3Array,
		bounds: AABB,
		radius: float,
		sweep_bottom: float,
		sweep_top: float
	) -> bool:
	if sweep_top < bounds.position.y or sweep_bottom > bounds.end.y:
		return true
	for route_index in range(1, route.size()):
		if _segment_intersects_expanded_xz_bounds(
			route[route_index - 1], route[route_index], bounds, radius
		):
			return false
	return true


func _segment_intersects_expanded_xz_bounds(
		from: Vector3,
		to: Vector3,
		bounds: AABB,
		radius: float
	) -> bool:
	var minimum := Vector2(bounds.position.x - radius, bounds.position.z - radius)
	var maximum := Vector2(bounds.end.x + radius, bounds.end.z + radius)
	var start := Vector2(from.x, from.z)
	var delta := Vector2(to.x - from.x, to.z - from.z)
	var t_min := 0.0
	var t_max := 1.0
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if start[axis] < minimum[axis] or start[axis] > maximum[axis]:
				return false
			continue
		var t_1 := (minimum[axis] - start[axis]) / delta[axis]
		var t_2 := (maximum[axis] - start[axis]) / delta[axis]
		if t_1 > t_2:
			var swap := t_1
			t_1 = t_2
			t_2 = swap
		t_min = maxf(t_min, t_1)
		t_max = minf(t_max, t_2)
		if t_min > t_max:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if _failures.is_empty():
		print("Central berth route readability test passed")
		quit(0)
	else:
		push_error("Central berth route readability test failed: %s" % [_failures])
		quit(1)
