extends SceneTree

## Focused proof for the Cinder Reach art pass: the belt's shared rock material
## with per-rock tint and roughness, readable (non-degenerate) chevrons that step
## down under reduced flash, the hulk's merged approach silhouette inside its
## budget, distance fades on the sector's small and interior renderers, the
## moonlet's procedural surface, and the streamed renderer roster staying in
## step with the authored scene.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame

	_test_belt(cluster)
	_test_hulk(cluster)
	_test_visibility_ranges(cluster)
	_test_moonlet(cluster)

	var renderers := cluster.find_children("*", "GeometryInstance3D", true, false)
	var lights := cluster.find_children("*", "Light3D", true, false)
	_check(
		renderers.size() == CinderStreamingTransitionPresentation.EXPECTED_AUTHORED_RENDERER_COUNT
		and lights.size() == CinderStreamingTransitionPresentation.EXPECTED_LIGHT_COUNT,
		"the streamed transition roster matches the authored sector (%d renderers, %d lights)"
		% [renderers.size(), lights.size()]
	)
	var shadowed := 0
	for candidate in lights:
		if (candidate as Light3D).shadow_enabled:
			shadowed += 1
	_check(shadowed == 0, "the art pass adds no shadow-casting light")
	var audit := cluster.get_cluster_audit_report()
	if not bool(audit.get("valid", false)):
		print("CLUSTER_AUDIT_ERRORS: ", audit.get("errors", []))
	_check(bool(audit.get("valid", false)), "the cluster audit stays inside its budgets")

	cluster.queue_free()
	await process_frame
	_finish()


func _test_belt(cluster: NearbySectorCluster) -> void:
	var field := cluster.get_asteroid_field()
	var shared_material := field.get_rock_material()
	var one_material := shared_material != null and shared_material.shader != null
	var colors := {}
	var roughness := {}
	var roughness_in_range := true
	var custom_matches := true
	for index in CinderAsteroidField.STOCK_SIZES.size():
		var batch := field.get_node_or_null(
			NodePath("BeltVisuals/AsteroidStock%d" % (index + 1))
		) as MultiMeshInstance3D
		if batch == null or batch.multimesh == null:
			one_material = false
			continue
		one_material = one_material and batch.material_override == shared_material \
			and batch.multimesh.use_colors and batch.multimesh.use_custom_data
		var authored_colors := batch.get_meta(&"authored_instance_colors", PackedColorArray()) as PackedColorArray
		var authored_custom := batch.get_meta(&"authored_instance_custom", PackedColorArray()) as PackedColorArray
		custom_matches = custom_matches and authored_custom.size() == authored_colors.size() \
			and authored_custom.size() == batch.multimesh.visible_instance_count
		for color in authored_colors:
			colors[color.to_html(false)] = true
		for custom in authored_custom:
			roughness[snappedf(custom.r, 0.001)] = true
			if custom.r < CinderAsteroidField.ROCK_ROUGHNESS_RANGE.x - 0.0001 \
					or custom.r > CinderAsteroidField.ROCK_ROUGHNESS_RANGE.y + 0.0001:
				roughness_in_range = false
	_check(
		one_material and custom_matches,
		"all six belt batches share one shader material fed by per-instance colour and custom data"
	)
	_check(
		colors.size() >= CinderAsteroidField.ASTEROID_COUNT - 2
		and roughness.size() >= CinderAsteroidField.ASTEROID_COUNT - 2
		and roughness_in_range,
		"each rock carries its own tint (%d distinct) and roughness (%d distinct)"
		% [colors.size(), roughness.size()]
	)

	var degenerate := false
	for path: NodePath in [^"BeltVisuals/SafeLaneChevrons", ^"BeltVisuals/ThreadingGateChevrons"]:
		var markers := field.get_node_or_null(path) as MultiMeshInstance3D
		if markers == null:
			degenerate = true
			continue
		for transform_value in markers.get_meta(&"authored_instance_transforms", []) as Array:
			var basis_value := (transform_value as Transform3D).basis
			if absf(basis_value.determinant()) < 0.05 \
					or absf(basis_value.x.normalized().dot(basis_value.y.normalized())) > 0.01 \
					or absf(basis_value.y.normalized().dot(basis_value.z.normalized())) > 0.01:
				degenerate = true
	_check(
		not degenerate,
		"every bore and gate chevron has a real tangential width instead of a collapsed basis"
	)

	var shared_cyan := cluster._materials["cyan_glow"] as StandardMaterial3D
	var shared_energy := shared_cyan.emission_energy_multiplier
	var bright := field.get_marker_emission_energies()
	cluster.set_reduced_flash_enabled(true)
	var reduced := field.get_marker_emission_energies()
	cluster.set_reduced_flash_enabled(false)
	var restored := field.get_marker_emission_energies()
	_check(
		float(bright["lane"]) > float(reduced["lane"])
		and float(bright["gate"]) > float(reduced["gate"])
		and is_equal_approx(float(reduced["lane"]), CinderAsteroidField.REDUCED_FLASH_MARKER_EMISSION)
		and is_equal_approx(float(restored["lane"]), float(bright["lane"]))
		and is_equal_approx(shared_cyan.emission_energy_multiplier, shared_energy),
		"chevrons glow brighter for cruise reads, step down under reduced flash and leave the shared glow role alone"
	)


func _test_hulk(cluster: NearbySectorCluster) -> void:
	var hulk := cluster.get_station_hulk()
	var detail := hulk.get_silhouette_detail() if hulk != null else null
	_check(
		detail != null and detail.mesh != null
		and detail.mesh.get_surface_count() == AbandonedStationHulk.SILHOUETTE_SURFACE_ROLES.size()
		and not (detail.get_parent() is CollisionObject3D)
		and detail.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the hulk carries one presentation-only silhouette renderer with a surface per finish"
	)
	var triangles := hulk.get_silhouette_triangle_count() if hulk != null else 0
	_check(
		triangles > 400 and triangles <= AbandonedStationHulk.SILHOUETTE_TRIANGLE_BUDGET,
		"the silhouette pass costs %d triangles, inside its %d budget"
		% [triangles, AbandonedStationHulk.SILHOUETTE_TRIANGLE_BUDGET]
	)
	var counts := hulk.count_live_nodes() if hulk != null else {}
	var report := hulk.get_audit_report() if hulk != null else {}
	_check(
		int(counts.get("omni_lights", -1)) == AbandonedStationHulk.LIGHT_BUDGET
		and int(counts.get("shadow_casting_lights", -1)) == 0
		and int(counts.get("mesh_instances", -1))
			== int(AbandonedStationHulk.PERFORMANCE_BUDGET["mesh_instances"])
		and bool(report.get("valid", false)),
		"the silhouette adds one renderer and no light, and the hulk audit stays valid"
	)
	var pool := detail.mesh.surface_get_material(4) if detail != null and detail.mesh != null else null
	_check(
		pool is ShaderMaterial and detail.mesh.surface_get_material(3) is StandardMaterial3D
		and (detail.mesh.surface_get_material(3) as StandardMaterial3D).emission_enabled,
		"the warm dock-shelf pool is emissive geometry, readable after the practicals fade"
	)


func _test_visibility_ranges(cluster: NearbySectorCluster) -> void:
	var hulk := cluster.get_station_hulk()
	var interior_ok := true
	var interior_count := 0
	for holder_path: NodePath in [^"Interior", ^"Fittings"]:
		var holder := hulk.get_node_or_null(holder_path)
		if holder == null:
			interior_ok = false
			continue
		for candidate in holder.find_children("*", "GeometryInstance3D", true, false):
			var renderer := candidate as GeometryInstance3D
			interior_count += 1
			interior_ok = interior_ok \
				and is_equal_approx(renderer.visibility_range_end, AbandonedStationHulk.INTERIOR_VISIBILITY_END) \
				and renderer.visibility_range_end_margin > 0.0 \
				and renderer.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_check(
		interior_ok and interior_count > 0,
		"the hulk's %d interior renderers fade out beyond %.0f m" % [
			interior_count, AbandonedStationHulk.INTERIOR_VISIBILITY_END
		]
	)
	var report := cluster.get_far_visibility_range_report()
	var fades := true
	for entry: Dictionary in report["ranged"]:
		fades = fades and float(entry["end_margin"]) > 0.0 \
			and int(entry["fade_mode"]) == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_check(
		int(report["ranged_count"]) > interior_count and fades,
		"%d small or interior sector renderers carry a faded visibility range" % int(report["ranged_count"])
	)
	var landmarks_unranged := true
	for path: NodePath in [
		^"Landmarks/ReachMoonlet/Mesh",
		^"Landmarks/MoonletRings/InnerRing",
		^"AsteroidField/BeltVisuals/SafeLaneChevrons",
		^"AsteroidField/BeltVisuals/ThreadingGateChevrons",
		^"AsteroidField/BeltVisuals/AsteroidStock1",
	]:
		var renderer := cluster.get_node_or_null(path) as GeometryInstance3D
		landmarks_unranged = landmarks_unranged and renderer != null \
			and is_zero_approx(renderer.visibility_range_end)
	var silhouette := hulk.get_silhouette_detail()
	_check(
		landmarks_unranged and silhouette != null and is_zero_approx(silhouette.visibility_range_end),
		"landmarks, belt batches, chevrons and the hulk silhouette are never range-culled"
	)


func _test_moonlet(cluster: NearbySectorCluster) -> void:
	var view := cluster.get_node_or_null(^"Landmarks/ReachMoonlet/Mesh") as MeshInstance3D
	var inner := cluster.get_node_or_null(^"Landmarks/MoonletRings/InnerRing") as MeshInstance3D
	var outer := cluster.get_node_or_null(^"Landmarks/MoonletRings/OuterRing") as MeshInstance3D
	var surface := view.material_override as ShaderMaterial if view != null else null
	_check(
		surface != null and surface.shader == NearbySectorCluster.MOONLET_SURFACE_SHADER
		and is_equal_approx(float(surface.get_shader_parameter(&"body_radius")), NearbySectorCluster.MOONLET_RADIUS),
		"the moonlet is shaded with the procedural crater surface at its real radius"
	)
	var inner_material := inner.material_override as ShaderMaterial if inner != null else null
	var outer_material := outer.material_override as ShaderMaterial if outer != null else null
	_check(
		inner_material != null and outer_material != null
		and inner_material.shader == NearbySectorCluster.MOONLET_RING_SHADER
		and outer_material.shader == NearbySectorCluster.MOONLET_RING_SHADER
		and inner_material != outer_material,
		"both moonlet rings take the banded dust shading with their own radii"
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_SECTOR_ART_PASS_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_SECTOR_ART_PASS_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_SECTOR_ART_PASS_TEST_FAILURE: ", failure)
	quit(1)
