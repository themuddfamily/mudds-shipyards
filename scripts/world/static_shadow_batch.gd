extends RefCounted
## Opaque shadow geometry for an explicitly supplied, immutable assembly.
## The caller owns the source roster and must share its visibility/lifetime with
## the parent. Unsupported inputs leave every source shadow untouched.
##
## By default the merge is exact: every source's own triangles, transformed.
##
## A caller may instead supply one `proxies` mesh per source, which is merged in
## that source's place at that source's transform. This exists because a shadow
## pass consumes only a silhouette — it never shades the surface, never samples
## its UVs and never sees its material — so surface tessellation that was chosen
## to hold a specular highlight is pure cost once `SHADOWS_ONLY` is set. Every
## acceptance gate below still runs against the real source, so a proxy can never
## be used to smuggle in geometry whose colour twin would have been rejected, and
## each proxy is additionally required to stay inside its source's own bounding
## volume so a substitution can only ever shrink a silhouette, never grow one
## into somewhere the assembly does not physically reach.

## Absolute slack on that bounding-volume gate.
##
## An inscribed polygon's axis-aligned bound is not a property of the circle it
## stands for: an `n`-gon with a vertex on an axis reaches the full radius on that
## axis, and one without reaches only `r * cos(PI / n)` of it. So two different
## tessellations of the *same* round stock can differ in stored AABB by up to
## `r * (1 - cos(PI / n))`, which for the largest radius this is used on is under
## a centimetre. Two centimetres of slack absorbs that without letting a proxy be
## a materially different shape from the part it stands in for.
const PROXY_BOUNDS_MARGIN_METRES := 0.02

static func build(
		parent: Node3D,
		sources: Array[MeshInstance3D],
		proxies: Array[ArrayMesh] = []
	) -> MeshInstance3D:
	if parent == null or sources.is_empty():
		return null
	if not proxies.is_empty() and proxies.size() != sources.size():
		return null
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var material: StandardMaterial3D
	var seen := {}
	for source_index in sources.size():
		var source := sources[source_index]
		if not is_instance_valid(source) or source.get_parent() != parent \
				or seen.has(source.get_instance_id()) or source.get_script() != null \
				or not source.visible or source.mesh == null or source.skin != null \
				or source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or source.layers != 1 or source.material_overlay != null \
				or not is_zero_approx(source.transparency) \
				or not is_zero_approx(source.visibility_range_begin) \
				or not is_zero_approx(source.visibility_range_end) \
				or source.transform.basis.determinant() <= 0.0 \
				or not source.mesh is ArrayMesh \
				or source.mesh.get_surface_count() != 1 \
				or source.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			return null
		if (source.mesh as ArrayMesh).get_blend_shape_count() != 0 \
				or (source.mesh as ArrayMesh).shadow_mesh != null:
			return null
		var candidate := source.get_active_material(0) as StandardMaterial3D
		if candidate == null or candidate.next_pass != null \
				or candidate.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or candidate.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
				or candidate.grow or candidate.fixed_size or candidate.proximity_fade_enabled \
				or candidate.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
			return null
		if material == null:
			material = candidate
		elif candidate.cull_mode != material.cull_mode \
				or candidate.depth_draw_mode != material.depth_draw_mode \
				or candidate.no_depth_test != material.no_depth_test:
			return null
		# Every gate above has now passed against the real colour source. Only the
		# triangles that get merged may come from the proxy, and only when the
		# proxy is itself an ordinary single-surface triangle mesh that fits
		# inside the volume the source already occupies.
		var merged: ArrayMesh = source.mesh
		if not proxies.is_empty():
			var proxy := proxies[source_index]
			# A null entry means this source has no proven stand-in; its own
			# triangles are merged exactly, as they would be without proxies.
			if proxy != null and (proxy.get_surface_count() != 1 \
					or proxy.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES \
					or proxy.get_blend_shape_count() != 0 or proxy.shadow_mesh != null \
					or not source.mesh.get_aabb().grow(PROXY_BOUNDS_MARGIN_METRES).encloses(proxy.get_aabb())):
				return null
			if proxy != null:
				merged = proxy
		var arrays := merged.surface_get_arrays(0)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array \
				or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array \
				or (arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array):
			return null
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if source_vertices.is_empty() or source_normals.size() != source_vertices.size():
			return null
		var offset := vertices.size()
		var normal_basis := source.transform.basis.inverse().transposed()
		for index in source_vertices.size():
			vertices.append(source.transform * source_vertices[index])
			normals.append((normal_basis * source_normals[index]).normalized())
		var source_indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			if source_vertices.size() % 3 != 0:
				return null
			for index in source_vertices.size():
				indices.append(offset + index)
		else:
			if source_indices.size() % 3 != 0:
				return null
			for index in source_indices:
				if index < 0 or index >= source_vertices.size():
					return null
				indices.append(offset + index)
		seen[source.get_instance_id()] = true
	var merged_arrays := []
	merged_arrays.resize(Mesh.ARRAY_MAX)
	merged_arrays[Mesh.ARRAY_VERTEX] = vertices
	merged_arrays[Mesh.ARRAY_NORMAL] = normals
	merged_arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged_arrays)
	if mesh.get_surface_count() != 1:
		return null
	var batch := MeshInstance3D.new()
	batch.name = "OpaqueEnvelopeShadowBatch"
	batch.mesh = mesh
	# Reuse one source's opaque material: no additional material allocation and
	# identical culling/depth semantics. Colour/UVs do not enter its shadow pass.
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(batch)
	for source in sources:
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return batch
