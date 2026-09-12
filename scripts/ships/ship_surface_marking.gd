extends Decal

## Godot 4.7 Compatibility cannot draw Decal. Copy only the receiving triangles
## inside its shallow volume, retaining their shape and normals. Deferred setup
## sees both caller adjustments and late hull cuts; there is no per-frame scan.
## Patches belong to the receiving mesh so doors, wings and visibility follow it.
const SURFACE_OFFSET := 0.002

var _ink: StandardMaterial3D
var _patches: Array[MeshInstance3D] = []

func _enter_tree() -> void:
	if not visibility_changed.is_connected(_sync_visibility):
		visibility_changed.connect(_sync_visibility)
	_build_patches.call_deferred()


func _build_patches() -> void:
	if not is_inside_tree() or not _patches.is_empty():
		return
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return
		ancestor = ancestor.get_parent()
	var receivers: Array[MeshInstance3D] = []
	# Native decals also reach sibling access skins above a mesh parent.
	var receiver_root := get_parent().get_parent() if get_parent() is MeshInstance3D else get_parent()
	_collect_receivers(receiver_root, receivers)
	for receiver in receivers:
		_project_receiver(receiver)


func _collect_receivers(node: Node, receivers: Array[MeshInstance3D]) -> void:
	if node is Decal or node.has_meta("surface_marking_patch"):
		return
	if node is MeshInstance3D and node.mesh != null and (node.layers & cull_mask) != 0 and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		receivers.append(node)
	for child in node.get_children():
		_collect_receivers(child, receivers)


func _project_receiver(receiver: MeshInstance3D) -> void:
	var receiver_to_projector := global_transform.affine_inverse() * receiver.global_transform
	var volume := AABB(-size * 0.5, size)
	if not volume.intersects(receiver_to_projector * receiver.mesh.get_aabb()):
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for surface in receiver.mesh.get_surface_count():
		if receiver.mesh is ArrayMesh and receiver.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var material := receiver.get_active_material(surface)
		# Dedicated glass layers are the primary receiver contract; transparent
		# materials also exclude panes that share an otherwise opaque layer.
		if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var arrays := receiver.mesh.surface_get_arrays(surface)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else source_vertices.size()
		var normal_basis := receiver_to_projector.basis.inverse().transposed()
		for triangle in range(0, count, 3):
			var polygon: Array[Vector3] = []
			var polygon_normals: Array[Vector3] = []
			for corner in 3:
				var index := indices[triangle + corner] if not indices.is_empty() else triangle + corner
				polygon.append(receiver_to_projector * source_vertices[index])
				polygon_normals.append((normal_basis * source_normals[index]).normalized() if not source_normals.is_empty() else Vector3.ZERO)
			# Godot's clockwise front faces have the opposite cross-product normal.
			var face_normal := (polygon[2] - polygon[0]).cross(polygon[1] - polygon[0]).normalized()
			if source_normals.is_empty():
				polygon_normals.assign([face_normal, face_normal, face_normal])
			# Use authored normals: mirrored receiver transforms reverse winding,
			# while inverse-transpose normals still identify the receiving side.
			if (polygon_normals[0] + polygon_normals[1] + polygon_normals[2]).normalized().y <= 0.25:
				continue
			var bounds := AABB(polygon[0], Vector3.ZERO).expand(polygon[1]).expand(polygon[2])
			if not volume.intersects(bounds):
				continue
			for axis in 3:
				for sign_value in [-1.0, 1.0]:
					var clipped := _clip(polygon, polygon_normals, axis, sign_value, size[axis] * 0.5)
					polygon = clipped[0]
					polygon_normals = clipped[1]
					if polygon.is_empty():
						break
				if polygon.is_empty():
					break
			for fan in range(1, polygon.size() - 1):
				for corner in [0, fan, fan + 1]:
					var point := polygon[corner]
					var smooth_normal := polygon_normals[corner].normalized()
					vertices.append(point + smooth_normal * SURFACE_OFFSET)
					normals.append(smooth_normal)
					uvs.append(Vector2(point.x / size.x + 0.5, point.z / size.z + 0.5))
					colors.append(Color(1, 1, 1, smoothstep(0.25, 0.60, smooth_normal.y)))
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var patch := MeshInstance3D.new()
	patch.name = str(name) + "SurfaceInk"
	patch.set_meta("surface_marking_patch", true)
	patch.set_meta("surface_marking_owner", get_instance_id())
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	patch.mesh = mesh
	if _ink == null:
		_ink = StandardMaterial3D.new()
		_ink.albedo_texture = texture_albedo
		_ink.albedo_color = modulate
		_ink.vertex_color_use_as_albedo = true
		_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ink.roughness = 0.72
		if distance_fade_enabled:
			_ink.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
			_ink.distance_fade_min_distance = distance_fade_begin + distance_fade_length
			_ink.distance_fade_max_distance = distance_fade_begin
		_ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Inverse-transpose normals select the front side even on mirrors.
		_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	patch.material_override = _ink
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.layers = receiver.layers
	patch.visibility_range_begin = receiver.visibility_range_begin
	patch.visibility_range_end = distance_fade_begin + distance_fade_length if distance_fade_enabled else 0.0
	if receiver.visibility_range_end > 0.0:
		patch.visibility_range_end = minf(patch.visibility_range_end, receiver.visibility_range_end) if patch.visibility_range_end > 0.0 else receiver.visibility_range_end
	receiver.add_child(patch)
	patch.transform = receiver_to_projector.affine_inverse()
	patch.visible = visible
	_patches.append(patch)


## Sutherland-Hodgman clipping preserves receiver triangles at the six volume
## boundaries; interpolated normals retain smooth curved-surface lighting.
func _clip(points: Array[Vector3], normals: Array[Vector3], axis: int, sign_value: float, extent: float) -> Array:
	var clipped: Array[Vector3] = []
	var clipped_normals: Array[Vector3] = []
	if points.is_empty():
		return [clipped, clipped_normals]
	var previous := points.size() - 1
	for current in points.size():
		var previous_distance := points[previous][axis] * sign_value - extent
		var current_distance := points[current][axis] * sign_value - extent
		if (previous_distance <= 0.0) != (current_distance <= 0.0):
			var weight := previous_distance / (previous_distance - current_distance)
			clipped.append(points[previous].lerp(points[current], weight))
			clipped_normals.append(normals[previous].lerp(normals[current], weight))
		if current_distance <= 0.0:
			clipped.append(points[current])
			clipped_normals.append(normals[current])
		previous = current
	return [clipped, clipped_normals]


func _sync_visibility() -> void:
	for patch in _patches:
		if is_instance_valid(patch):
			patch.visible = visible


func _exit_tree() -> void:
	for patch in _patches:
		if is_instance_valid(patch) and not patch.is_queued_for_deletion():
			patch.queue_free()
	_patches.clear()
	_ink = null


func owns_patch(node: Node) -> bool:
	return _patches.has(node) and node.get_parent() is MeshInstance3D and node.get_script() == null and node.get_child_count() == 0 and not node.is_processing() and not node.is_physics_processing()
