extends SceneTree

## Focused exterior-readability contract for the production Cinder hauler.
## The freight shoulders are visual-only and remain inside established physics.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame

	var shoulders := craft.get_node_or_null(
		^"CinderCargoVisual/CargoShoulderBatch"
	) as MultiMeshInstance3D
	var multi := shoulders.multimesh if shoulders != null else null
	var mesh := multi.mesh as BoxMesh if multi != null else null
	_check(
		shoulders != null
			and multi != null
			and multi.instance_count == 4
			and mesh != null
			and mesh.size.is_equal_approx(Hauler.CARGO_SHOULDER_SIZE)
			and shoulders.visible
			and shoulders.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"one visible four-piece batch gives the hauler its split freight shoulders"
	)
	_check(
		shoulders != null
			and shoulders.get_meta(&"presentation_only", false)
			and shoulders.get_meta(&"color_independent", false)
			and shoulders.get_meta(&"silhouette_role", &"") == &"cargo_shoulders"
			and shoulders.get_meta(&"authored_visual_names", PackedStringArray()).size() == 4
			and shoulders.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the shoulders communicate cargo by shape without adding collision or authority"
	)
	if multi != null and mesh != null:
		var authored_transforms: Array = shoulders.get_meta(
			&"authored_instance_transforms", []
		) as Array
		var inside_collision_envelope := true
		var clears_port_aperture := true
		var port_count := 0
		var starboard_count := 0
		var forward_count := 0
		var aft_count := 0
		for transform_variant in authored_transforms:
			var transform := transform_variant as Transform3D
			inside_collision_envelope = inside_collision_envelope \
				and absf(transform.origin.x) + mesh.size.x * 0.5 <= 3.401 \
				and absf(transform.origin.z) + mesh.size.z * 0.5 <= 6.001
			clears_port_aperture = clears_port_aperture \
				and absf(transform.origin.z) - mesh.size.z * 0.5 >= 2.299
			port_count += 1 if transform.origin.x < 0.0 else 0
			starboard_count += 1 if transform.origin.x > 0.0 else 0
			forward_count += 1 if transform.origin.z < 0.0 else 0
			aft_count += 1 if transform.origin.z > 0.0 else 0
		_check(
			inside_collision_envelope
				and clears_port_aperture
				and port_count == 2
				and starboard_count == 2
				and forward_count == 2
				and aft_count == 2,
			"balanced silhouette bounds invalid: inside=%s clear=%s port=%d starboard=%d forward=%d aft=%d"
				% [inside_collision_envelope, clears_port_aperture, port_count, starboard_count, forward_count, aft_count]
		)
	_check(
		craft.get_boarding_marker() != null
			and craft.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and bool(craft.get_landing_collision_report().get("valid", false))
			and not bool(craft.get_audit_report().get("network_authority", true))
			and not bool(craft.get_audit_report().get("cargo_transfer_authority", true)),
		"silhouette polish preserves boarding, manifest anchors, collision and authority seams"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_cargo_hauler_silhouette_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
