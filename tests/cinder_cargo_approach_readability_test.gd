extends SceneTree

## Focused threshold-readability contract for the embodied Cinder cabin. Static
## shape, text and one restrained light identify the real aperture without
## changing collision, authority or evidence status.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame
	await physics_frame

	var boarding := craft.get_boarding_marker()
	var visual := craft.get_variant_visual_root()
	var sign := craft.get_node_or_null(^"CinderCargoVisual/CargoAccessSign") as Label3D
	var threshold_light := craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdLight") as OmniLight3D
	_check(sign != null and threshold_light != null, "the physical port aperture has retained sign and threshold light")
	_check(
		sign != null
			and sign.text.contains("CARGO ACCESS")
			and sign.text.contains("LOADMASTER")
			and sign.get_meta("presentation_only", false)
			and sign.get_meta("color_independent", false),
		"the approach sign is readable with text and shape-independent cues"
	)
	_check(
		threshold_light != null
			and threshold_light.light_energy > 0.0
			and threshold_light.omni_range >= 4.0
			and not threshold_light.shadow_enabled
			and threshold_light.get_meta("reduced_flash_safe", false)
			and not threshold_light.get_meta("animated", true),
		"the threshold uses one static shadowless reduced-flash-safe light"
	)
	var posts := craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdPostBatch") as MultiMeshInstance3D
	var post_names := PackedStringArray(["CargoThresholdPostPort", "CargoThresholdPostStarboard"])
	var post_transforms: Array = posts.get_meta(&"authored_instance_transforms", []) as Array \
		if posts != null else []
	for index in post_names.size():
		_check(
			posts != null and boarding != null and posts.multimesh != null
				and posts.get_meta("presentation_only", false)
				and posts.get_meta("route_id", &"") == Hauler.CABIN_ROUTE_ID
				and posts.get_meta("authored_visual_names", PackedStringArray()) == post_names
				and posts.get_child_count() == 0
				and posts.multimesh.instance_count == 2
				and post_transforms.size() == 2
				and (post_transforms[index] as Transform3D).is_equal_approx(
					Transform3D(Basis.IDENTITY, Vector3(-3.41, 0.15, -2.28 if index == 0 else 2.28))
				),
			"%s retains its exact presentation-only route cue in the two-post batch" % post_names[index]
		)
	var header := craft.get_node_or_null(^"CinderCargoVisual/CargoThresholdHeader") as MeshInstance3D
	_check(
		header != null and header.get_meta("presentation_only", false)
			and header.get_meta("route_id", &"") == Hauler.CABIN_ROUTE_ID,
		"CargoThresholdHeader is a presentation-only physical route cue"
	)
	for name in ["CargoPressureCollar", "CargoPressureRim"]:
		var collar := visual.get_node_or_null(name) as MeshInstance3D
		_check(collar != null and collar.mesh is ArrayMesh
			and collar.get_meta("presentation_only", false)
			and _entry_mesh_leaves_walkway_open(collar),
			"%s frames the port opening without an opaque face across the walking route" % name)
	if boarding != null and sign != null:
		_check(
			sign.global_position.distance_to(boarding.global_position) < 2.6,
			"the sign stays at the real boarding threshold"
		)
	_check(
		visual != null
			and craft.get_in_flight_cabin_report().get("boarding_route_id", &"") == Hauler.CABIN_ROUTE_ID
			and craft.get_loadmaster_station_anchor() != null,
		"threshold cues preserve the existing cabin route and physical station"
	)
	_check(craft.get_meta("evidence_status", &"") == &"NEW", "threshold presentation preserves NEW evidence status")
	_check(craft.get_node_or_null(^"WalkableInterior/InteriorOccupantVolume") != null, "threshold presentation preserves the occupancy volume")

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_CARGO_APPROACH_READABILITY_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _entry_mesh_leaves_walkway_open(renderer: MeshInstance3D) -> bool:
	var arrays := renderer.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for height in [-0.8, 0.6]:
		for lateral in [-0.45, 0.0, 0.45]:
			var start := Vector3(-4.0, height, lateral)
			var finish := Vector3(-2.2, height, lateral)
			for index in range(0, indices.size(), 3):
				if Geometry3D.segment_intersects_triangle(start, finish,
					vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]]) != null:
					return false
	return true
