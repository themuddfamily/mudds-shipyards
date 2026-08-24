extends SceneTree

const EmberScene := preload("res://scenes/world/planets/ember_moon.tscn")
const EXPECTED_OXIDE := Color("c66a3d")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := EmberScene.instantiate() as EmberMoonAuthoredScene
	root.add_child(scene)
	await process_frame
	var rack := scene.get_node(
		^"LandingRegion/SurfaceLandmarks/SampleRack"
	) as StaticBody3D
	var rack_visual := rack.get_node(^"RackVisual") as MeshInstance3D
	var rack_collision := rack.get_node(^"CollisionShape3D") as CollisionShape3D
	var vane := rack.get_node(^"IdentityVaneVisuals") as MultiMeshInstance3D
	var authored := vane.get_meta("authored_transforms", []) as Array
	var snapshot := scene.get_snapshot() as Dictionary
	var identity := snapshot.geometry.sample_rack_identity_vane as Dictionary
	var material := vane.material_override as StandardMaterial3D

	_check(
		bool(scene.audit().valid)
			and vane.multimesh.instance_count == 9
			and authored.size() == 9
			and vane.multimesh.custom_aabb.is_equal_approx(
				AABB(Vector3(-1.62, 0.0, -1.62), Vector3(3.24, 4.02, 3.24))
			),
		"the production rack owns one bounded nine-bar identity batch",
	)
	_check(
		identity.silhouette == &"crossed_open_diamonds_over_low_rack"
			and int(identity.instance_count) == 9
			and is_equal_approx(float(identity.maximum_height_region_local_m), 4.4)
			and float(identity.gameplay_readability_distance_m) == 36.0
			and bool(identity.color_independent)
			and not bool(identity.collision_changed),
		"the crossed diamonds publish their exact gameplay-distance presentation contract",
	)
	var diamond_extents := _diamond_extents(authored)
	var angular_height_degrees := rad_to_deg(
		2.0 * atan(float(diamond_extents.size.y) / (2.0 * 36.0))
	)
	_check(
		diamond_extents.position.x <= -1.5
			and diamond_extents.end.x >= 1.5
			and diamond_extents.position.y <= 1.3
			and diamond_extents.end.y >= 3.9
			and angular_height_degrees > 4.0,
		"the diamond remains a broad silhouette at its declared 36 m walked distance",
	)
	_check(
		material != null
			and material.albedo_color.is_equal_approx(EXPECTED_OXIDE)
			and not material.emission_enabled
			and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
			and vane.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and vane.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
		"the vane reuses the fully lit, non-emissive oxide landmark finish",
	)
	_check(
		rack.position == Vector3(28.0, 0.5, -7.0)
			and (rack_visual.mesh as BoxMesh).size == Vector3(4.0, 1.0, 1.4)
			and (rack_collision.shape as BoxShape3D).size == Vector3(4.0, 1.0, 1.4)
			and rack_collision.position == Vector3.ZERO
			and rack.collision_layer == PhysicsLayers.WORLD_BODY_LAYER
			and rack.collision_mask == PhysicsLayers.WORLD_BODY_MASK,
		"the existing solid rack and its exact World collision remain unchanged",
	)
	_check(
		vane.get_meta("collision_role", &"") \
				== &"passive_noninteractive_identity_vane"
			and vane.get_meta("landmark_id", &"") == &"ember_sample_rack"
			and vane.get_meta("readable_axes", PackedStringArray()) \
				== PackedStringArray(["walked_route_x", "rack_access_z"])
			and _forbidden_authority_node_count(vane) == 0
			and not vane.is_processing() and not vane.is_physics_processing(),
		"the identity batch adds no collision, light, activity, navigation, or loop authority",
	)
	var drifted_buffer := vane.multimesh.buffer
	drifted_buffer[3] += 0.25
	vane.multimesh.buffer = drifted_buffer
	var drift_audit := scene.audit() as Dictionary
	_check(
		not bool(drift_audit.valid)
			and (drift_audit.error_codes as PackedStringArray).has(
				&"sample_rack_identity_vane_drift"
			),
		"live identity-vane transform drift turns the authored component red",
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_SAMPLE_RACK_IDENTITY_VANE_PRODUCTION_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _diamond_extents(authored: Array) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for index in 4:
		var transform := authored[index] as Transform3D
		var half_x := transform.basis.x.length() * 0.5
		var half_y := transform.basis.y.length() * 0.5
		minimum.x = minf(minimum.x, transform.origin.x - half_x - half_y)
		minimum.y = minf(minimum.y, transform.origin.y - half_x - half_y)
		maximum.x = maxf(maximum.x, transform.origin.x + half_x + half_y)
		maximum.y = maxf(maximum.y, transform.origin.y + half_x + half_y)
	return Rect2(minimum, maximum - minimum)


func _forbidden_authority_node_count(node: Node) -> int:
	var count := 0
	for child in node.find_children("*", "Node", true, false):
		if child is CollisionObject3D or child is Light3D or child is Area3D \
				or child is NavigationRegion3D or child is AnimationPlayer \
				or child is Timer or child is AudioStreamPlayer3D:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
