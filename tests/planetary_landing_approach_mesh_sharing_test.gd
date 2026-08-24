extends SceneTree

const LandingApproach := preload("res://scripts/world/planetary_landing_approach_presentation.gd")
const MARKER_COUNT := 4
const MARKER_COLOR := Color(1.0, 0.5, 0.12, 1.0)

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var presentations: Array = []
	for index in MARKER_COUNT:
		var presentation: Variant = LandingApproach.new()
		root.add_child(presentation)
		var anchor := Vector3(float(index) * 12.0, 1.5, -40.0 - float(index) * 8.0)
		var configured: Dictionary = presentation.configure(
			StringName("landing-approach-sharing-%d" % index), anchor
		)
		_check(bool(configured.accepted), "marker %d accepts its authored anchor" % index)
		presentations.append(presentation)
	await process_frame

	var mesh_ids := {}
	var material_ids := {}
	var marker_recipe_preserved := true
	for index in presentations.size():
		var presentation: Variant = presentations[index]
		var marker := _marker(presentation)
		var expected_anchor := Vector3(float(index) * 12.0, 1.5, -40.0 - float(index) * 8.0)
		marker_recipe_preserved = marker_recipe_preserved \
			and marker != null and marker.mesh is BoxMesh \
			and (marker.mesh as BoxMesh).size.is_equal_approx(LandingApproach.MARKER_SIZE) \
			and marker.mesh.get_surface_count() == 1 \
			and marker.mesh.surface_get_material(0) == null \
			and not marker.mesh.resource_local_to_scene \
			and marker.transform.is_equal_approx(Transform3D.IDENTITY) \
			and presentation.position.is_equal_approx(expected_anchor) \
			and marker.material_override is StandardMaterial3D \
			and not marker.visible \
			and not presentation.is_processing() \
			and not presentation.is_physics_processing()
		if marker != null and marker.mesh != null:
			mesh_ids[marker.mesh.get_instance_id()] = true
		if marker != null and marker.material_override != null:
			material_ids[marker.material_override.get_instance_id()] = true
	_check(
		marker_recipe_preserved and mesh_ids.size() == 1 and material_ids.size() == MARKER_COUNT,
		"unconfigured markers stay hidden while four markers share one immutable pad mesh and retain recipe-local materials"
	)

	var first: Variant = presentations[0]
	var second: Variant = presentations[1]
	var first_receipt: Dictionary = first.apply_presentation_recipe(
		{"sun_elevation_sine": -1.0}, {"shelter_scalar": 1.0}
	)
	var second_receipt: Dictionary = second.apply_presentation_recipe(
		{"sun_elevation_sine": 0.5}, {"shelter_scalar": 0.0}
	)
	second.apply_graphics_profile(&"low")
	var first_marker := _marker(first)
	var second_marker := _marker(second)
	var first_material := first_marker.material_override as StandardMaterial3D
	var second_material := second_marker.material_override as StandardMaterial3D
	_check(
		bool(first_receipt.accepted) and bool(second_receipt.accepted)
			and first_marker.mesh == second_marker.mesh
			and first_material != second_material
			and first_material.emission.is_equal_approx(MARKER_COLOR)
			and second_material.emission.is_equal_approx(MARKER_COLOR)
			and is_equal_approx(first_material.emission_energy_multiplier, 1.1)
			and is_equal_approx(second_material.emission_energy_multiplier, 0.3),
		"shared geometry preserves independent weather, color, readability, and reduced-motion profile recipes"
	)

	var detached: Dictionary = first.detach()
	var detached_identity := first_marker.mesh
	var reentered: Dictionary = first.reenter()
	var authority := first.get_snapshot().authority as Dictionary
	_check(
		bool(detached.accepted) and bool(reentered.accepted)
			and first_marker.visible and first_marker.mesh == detached_identity
			and not bool(authority.landing) and not bool(authority.navigation)
			and not bool(authority.movement) and not bool(authority.clock)
			and first.find_children("*", "CollisionObject3D", true, false).is_empty()
			and first.find_children("*", "NavigationRegion3D", true, false).is_empty(),
		"detach and re-entry preserve mesh identity, visibility, and presentation-only authority"
	)

	for presentation in presentations:
		presentation.queue_free()
	await process_frame
	_check(
		presentations.all(func(presentation: Variant) -> bool:
			return not is_instance_valid(presentation)),
		"all presentation copies leave the scene lifecycle cleanly"
	)

	if _failures.is_empty():
		print("PLANETARY_LANDING_APPROACH_MESH_SHARING: meshes 4->1 materials 4->4 nodes 4->4 submissions 4->4")
		print("PASS planetary_landing_approach_mesh_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _marker(presentation: Node) -> MeshInstance3D:
	return presentation.get_node_or_null(^"OwnedLandingApproachMarker") as MeshInstance3D


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
