extends SceneTree

## Machine-independent geometry census for the production scene.
##
## This tool exists because the box that usually runs it renders through
## llvmpipe, so frame time here is meaningless. Everything it reports is a
## property of the scene graph and its resources rather than of the renderer:
## triangles, mesh instances, surfaces, unique meshes, unique materials and
## shaders, lights, particle systems, texture bytes and node counts. Those
## numbers are identical on the player's Windows GPU build, so they are the only
## honest budget currency available from here.
##
## Usage:
##   godot --headless --audio-driver Dummy --script res://tools/geometry_census.gd
##
## Optional environment variables:
##   KETH_CENSUS_JSON=path   also write the census as JSON for diffing.
##   KETH_CENSUS_SETTLE=N    frames to settle before counting (default 8).

const MAIN_SCENE := preload("res://scenes/main.tscn")

const DEFAULT_SETTLE_FRAMES := 8


## Deterministic resource-graph collector used by the production census and its
## focused fixture. `bound_materials` is the exact frozen-phase render binding
## sample. `retained_materials` is the larger union reachable from the live scene
## graph, including private script dictionaries and dependencies of resources.
## Dictionaries retain the resources themselves (not booleans), and
## `_strong_resources` additionally makes the lifetime guarantee explicit while
## the graph is traversed and reported.
class MaterialResourceCensus:
	extends RefCounted

	var bound_materials: Dictionary = {}
	var retained_materials: Dictionary = {}
	var retained_shaders: Dictionary = {}
	var retained_textures: Dictionary = {}
	var bound_origins: Dictionary = {}
	var retained_origins: Dictionary = {}
	var skipped_freed_object_references := 0
	var _visited_objects: Dictionary = {}
	var _strong_resources: Array[Resource] = []


	func note_bound(material: Material, origin: String) -> void:
		if material == null:
			return
		var instance_id := material.get_instance_id()
		bound_materials[instance_id] = material
		if not bound_origins.has(instance_id):
			bound_origins[instance_id] = origin
		_note_retained_material(material, origin)


	func collect_retained(root_node: Node) -> void:
		# Bound collection primes the retained set so those resources stay alive,
		# but its first-hit origins reflect the sampled phase. Rewalk from the root
		# with fresh visitation/origin state so the retained fingerprint is derived
		# solely from the complete reachable graph.
		_visited_objects.clear()
		retained_origins.clear()
		_visit_object(root_node, "scene")
		for id_variant in retained_materials:
			if not retained_origins.has(id_variant):
				retained_origins[id_variant] = str(bound_origins.get(id_variant, "<reachable-origin-unresolved>"))


	func collect_bound(root_node: Node) -> void:
		_walk_bound_node(root_node, "scene")


	func bound_fingerprint() -> String:
		return "\n".join(bound_descriptors()).sha256_text()


	func retained_fingerprint() -> String:
		return "\n".join(retained_descriptors()).sha256_text()


	func bound_descriptors() -> PackedStringArray:
		return _descriptors(bound_materials, bound_origins)


	func retained_descriptors() -> PackedStringArray:
		return _descriptors(retained_materials, retained_origins)


	func texture_bytes_upper_bound() -> int:
		var bytes := 0
		for texture_variant in retained_textures.values():
			var texture := texture_variant as Texture2D
			if texture == null:
				continue
			var size := texture.get_size()
			bytes += int(size.x) * int(size.y) * 4
		return bytes


	func _visit_variant(value: Variant, origin: String) -> void:
		# Script arrays can legitimately retain a dead Object slot. Asking `is` of
		# that Variant raises a script error, so reject it by Variant type first and
		# report the omission rather than silently truncating traversal.
		if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
			skipped_freed_object_references += 1
			return
		if value is Material:
			_note_retained_material(value as Material, origin)
			return
		if value is Resource:
			_visit_object(value as Resource, origin)
			return
		if value is Node:
			_visit_object(value as Node, origin)
			return
		if value is Array:
			var array := value as Array
			for index in array.size():
				_visit_variant(array[index], "%s[%d]" % [origin, index])
			return
		if value is Dictionary:
			var dictionary := value as Dictionary
			var keys := dictionary.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			for key_variant in keys:
				var key_text := str(key_variant)
				_visit_variant(key_variant, "%s.key[%s]" % [origin, key_text])
				_visit_variant(dictionary[key_variant], "%s[%s]" % [origin, key_text])


	func _walk_bound_node(node: Node, origin: String) -> void:
		if node is GeometryInstance3D:
			var geometry := node as GeometryInstance3D
			note_bound(geometry.material_override, origin + ".material_override")
			note_bound(geometry.material_overlay, origin + ".material_overlay")
		if node is MultiMeshInstance3D:
			var multimesh := (node as MultiMeshInstance3D).multimesh
			if multimesh != null and multimesh.mesh != null:
				for surface in multimesh.mesh.get_surface_count():
					note_bound(multimesh.mesh.surface_get_material(surface), "%s.multimesh.surface[%d]" % [origin, surface])
		elif node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface in mesh_instance.mesh.get_surface_count():
					note_bound(mesh_instance.get_surface_override_material(surface), "%s.surface_override[%d]" % [origin, surface])
					note_bound(mesh_instance.mesh.surface_get_material(surface), "%s.mesh.surface[%d]" % [origin, surface])
		for child in node.get_children():
			_walk_bound_node(child, "%s/%s" % [origin, child.name])


	func _visit_object(object: Object, origin: String) -> void:
		if object == null:
			return
		var instance_id := object.get_instance_id()
		if _visited_objects.has(instance_id):
			return
		_visited_objects[instance_id] = true

		if object is Resource:
			_hold_resource(object as Resource)
		if object is Texture2D:
			retained_textures[instance_id] = object
		if object is Shader:
			retained_shaders[instance_id] = object
		if object is Mesh:
			var mesh := object as Mesh
			for surface in mesh.get_surface_count():
				_visit_variant(mesh.surface_get_material(surface), "%s.surface[%d]" % [origin, surface])
		if object is MultiMesh:
			_visit_variant((object as MultiMesh).mesh, origin + ".mesh")
		if object is ShaderMaterial:
			var shader_material := object as ShaderMaterial
			_visit_variant(shader_material.shader, origin + ".shader")
			if shader_material.shader != null:
				var uniforms := shader_material.shader.get_shader_uniform_list()
				uniforms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
				for uniform in uniforms:
					var uniform_name := StringName(str((uniform as Dictionary).get("name", "")))
					if uniform_name != &"":
						_visit_variant(shader_material.get_shader_parameter(uniform_name), "%s.shader_parameter[%s]" % [origin, uniform_name])

		var properties := object.get_property_list()
		properties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
		for property_variant in properties:
			var property := property_variant as Dictionary
			var usage := int(property.get("usage", 0))
			# Non-exported script variables (where component catalogues live) use
			# SCRIPT_VARIABLE without necessarily advertising STORAGE.
			if (usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE)) == 0:
				continue
			var property_name := StringName(str(property.get("name", "")))
			if property_name == &"":
				continue
			_visit_variant(object.get(property_name), "%s.%s" % [origin, property_name])

		if object is Node:
			var node := object as Node
			for child in node.get_children():
				_visit_object(child, "%s/%s" % [origin, child.name])


	func _note_retained_material(material: Material, origin: String) -> void:
		var instance_id := material.get_instance_id()
		retained_materials[instance_id] = material
		if not retained_origins.has(instance_id) or origin < str(retained_origins[instance_id]):
			retained_origins[instance_id] = origin
		_visit_object(material, origin)


	func _hold_resource(resource: Resource) -> void:
		_strong_resources.append(resource)


	func _descriptors(resources: Dictionary, origins: Dictionary) -> PackedStringArray:
		var descriptors := PackedStringArray()
		for id_variant in resources:
			var resource := resources[id_variant] as Resource
			var resource_path := resource.resource_path if resource != null else ""
			descriptors.append("%s|%s|%s" % [
				str(origins.get(id_variant, "")),
				resource.get_class() if resource != null else "<freed>",
				resource_path,
			])
		descriptors.sort()
		return descriptors

## Buckets are derived from the scene path rather than hand-listed, so a sibling
## adding a new station module or sector gets its own row without editing this
## tool. Everything under `ShipyardWorld` is split one level deeper, because the
## station is the bulk of the scene and a single `ShipyardWorld` row would hide
## the distribution that this census exists to expose.
const SPLIT_ROOTS: Array[String] = ["ShipyardWorld"]

const FALLBACK_BUCKET := "(scene root)"

var _rows: Dictionary = {}
var _unique_meshes: Dictionary = {}
var _material_census := MaterialResourceCensus.new()
var _mesh_triangle_cache: Dictionary = {}

var _text_sign_rows: Array = []
var _mesh_classes: Dictionary = {}
var _heaviest_instances: Array = []

var _total_nodes := 0
var _total_lights := 0
var _shadow_lights := 0
var _particles := 0
var _run_metadata: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var settle := DEFAULT_SETTLE_FRAMES
	var settle_override := OS.get_environment("KETH_CENSUS_SETTLE")
	if settle_override.is_valid_int():
		settle = maxi(1, settle_override.to_int())

	var game := MAIN_SCENE.instantiate()
	if game == null:
		printerr("census: main scene failed to instantiate")
		quit(1)
		return
	root.add_child(game)

	for _frame in settle:
		await process_frame
	await physics_frame
	await process_frame

	# Freeze the instantiated scene before either material view is taken. This
	# makes "bound" a declared phase rather than whichever `_process()` callback
	# happens to win while the tree is being walked.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_run_metadata = _capture_run_metadata(settle, game)
	_material_census.collect_bound(game)
	_walk(game, "")
	_material_census.collect_retained(game)

	_report()

	game.queue_free()
	await process_frame
	quit(0)


func _bucket_for(path: String) -> String:
	if path == "":
		return FALLBACK_BUCKET
	var parts := path.split("/")
	if parts.size() >= 2 and SPLIT_ROOTS.has(parts[0]):
		return "%s/%s" % [parts[0], parts[1]]
	return parts[0]


func _row(bucket: String) -> Dictionary:
	if not _rows.has(bucket):
		_rows[bucket] = {
			"triangles": 0,
			"instances": 0,
			"surfaces": 0,
			"multimesh_instances": 0,
			"lights": 0,
			"nodes": 0,
			"text_triangles": 0,
			"text_instances": 0,
		}
	return _rows[bucket]


func _walk(node: Node, path: String) -> void:
	var here := path
	if here != "":
		here += "/"
	here += String(node.name)
	# The scene root itself is not a bucket key.
	var effective := here.substr(here.find("/") + 1) if here.contains("/") else ""

	_total_nodes += 1
	var bucket := _bucket_for(effective)
	var row := _row(bucket)
	row["nodes"] = int(row["nodes"]) + 1

	if node is Light3D:
		_total_lights += 1
		row["lights"] = int(row["lights"]) + 1
		if (node as Light3D).shadow_enabled:
			_shadow_lights += 1
	if node is GPUParticles3D or node is CPUParticles3D:
		_particles += 1
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			var per := _mesh_triangles(multi.mesh)
			var count := multi.visible_instance_count
			if count < 0:
				count = multi.instance_count
			row["triangles"] = int(row["triangles"]) + per * count
			row["instances"] = int(row["instances"]) + 1
			row["surfaces"] = int(row["surfaces"]) + multi.mesh.get_surface_count()
			row["multimesh_instances"] = int(row["multimesh_instances"]) + count
			_note_mesh(multi.mesh, per * count, count, effective)
	elif node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var mesh := instance.mesh
		if mesh != null:
			var tris := _mesh_triangles(mesh)
			row["triangles"] = int(row["triangles"]) + tris
			row["instances"] = int(row["instances"]) + 1
			row["surfaces"] = int(row["surfaces"]) + mesh.get_surface_count()
			_note_mesh(mesh, tris, 1, effective)
			if mesh is TextMesh:
				row["text_triangles"] = int(row["text_triangles"]) + tris
				row["text_instances"] = int(row["text_instances"]) + 1
				var text_mesh := mesh as TextMesh
				_text_sign_rows.append({
					"path": effective,
					"text": text_mesh.text,
					"triangles": tris,
					"font_size": text_mesh.font_size,
					"pixel_size": text_mesh.pixel_size,
					"depth": text_mesh.depth,
					"scale": instance.scale.x,
					"bucket": bucket,
				})
	elif node is Label3D:
		# Label3D is a quad plus a font atlas: two triangles, and it is listed so
		# the comparison with TextMesh is visible rather than implied.
		row["instances"] = int(row["instances"]) + 1
		row["triangles"] = int(row["triangles"]) + 2
		row["surfaces"] = int(row["surfaces"]) + 1

	for child in node.get_children():
		_walk(child, here)


func _note_mesh(mesh: Mesh, triangles: int, instances: int, path: String) -> void:
	_unique_meshes[mesh.get_instance_id()] = true
	var mesh_class := mesh.get_class()
	if not _mesh_classes.has(mesh_class):
		_mesh_classes[mesh_class] = {"instances": 0, "triangles": 0}
	var entry: Dictionary = _mesh_classes[mesh_class]
	entry["instances"] = int(entry["instances"]) + instances
	entry["triangles"] = int(entry["triangles"]) + triangles
	_heaviest_instances.append({"path": path, "class": mesh_class, "triangles": triangles})


func _mesh_triangles(mesh: Mesh) -> int:
	var key := mesh.get_instance_id()
	if _mesh_triangle_cache.has(key):
		return int(_mesh_triangle_cache[key])
	var total := 0
	var array_mesh := mesh as ArrayMesh
	for surface in mesh.get_surface_count():
		# Only `ArrayMesh` exposes a primitive type; every `PrimitiveMesh` the
		# project builds is triangles.
		if array_mesh != null and array_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			total += indices.size() / 3
		else:
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			if vertices != null:
				total += vertices.size() / 3
	_mesh_triangle_cache[key] = total
	return total


func _texture_bytes() -> int:
	return _material_census.texture_bytes_upper_bound()


func _capture_run_metadata(settle_frames: int, game: Node) -> Dictionary:
	var revision_output: Array = []
	var revision_exit := OS.execute("git", ["rev-parse", "HEAD"], revision_output, true)
	var status_output: Array = []
	var status_exit := OS.execute("git", ["status", "--porcelain=v1"], status_output, true)
	var command_line := PackedStringArray(OS.get_cmdline_args())
	var version := Engine.get_version_info()
	var world := game.get_node_or_null("ShipyardWorld")
	var visual_quality_level := -1
	var visual_quality_report := {}
	if world != null:
		visual_quality_level = int(world.get("visual_quality_level"))
		if world.has_method("get_visual_quality_report"):
			visual_quality_report = world.call("get_visual_quality_report") as Dictionary
	return {
		"engine_version": str(version.get("string", Engine.get_version_info())),
		"source_commit": str(revision_output[0]).strip_edges() if revision_exit == 0 and not revision_output.is_empty() else "unknown",
		"source_tree_dirty": status_exit != 0 or (not status_output.is_empty() and not str(status_output[0]).strip_edges().is_empty()),
		"rendering_method_project_setting": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"rendering_method_runtime": RenderingServer.get_current_rendering_method(),
		"display_driver": DisplayServer.get_name(),
		"audio_driver": AudioServer.get_driver_name(),
		"visual_quality_level": visual_quality_level,
		"visual_quality_report": visual_quality_report,
		"command_line": command_line,
		"settle_strategy": {
			"idle_frames_before_freeze": settle_frames,
			"physics_frames_before_freeze": 1,
			"final_idle_frames_before_freeze": 1,
			"freeze": "production scene root process_mode set to PROCESS_MODE_DISABLED before synchronous census",
		},
		"frozen_phase": "after configured idle settle, one physics frame, and one final idle frame",
	}


func _report() -> void:
	var buckets := _rows.keys()
	buckets.sort_custom(func(a, b): return int(_rows[a]["triangles"]) > int(_rows[b]["triangles"]))

	var total_triangles := 0
	var total_instances := 0
	var total_surfaces := 0
	var total_text_triangles := 0
	var total_text_instances := 0
	for bucket in buckets:
		total_triangles += int(_rows[bucket]["triangles"])
		total_instances += int(_rows[bucket]["instances"])
		total_surfaces += int(_rows[bucket]["surfaces"])
		total_text_triangles += int(_rows[bucket]["text_triangles"])
		total_text_instances += int(_rows[bucket]["text_instances"])

	print("")
	print("=== GEOMETRY CENSUS: scenes/main.tscn ===")
	print("(counts are renderer-independent; this box has no usable GPU timing)")
	print("engine: %s" % str(_run_metadata.get("engine_version", "unknown")))
	print("source: %s%s" % [
		str(_run_metadata.get("source_commit", "unknown")),
		" (dirty)" if bool(_run_metadata.get("source_tree_dirty", true)) else " (clean)",
	])
	print("profile/display: %s / %s / %s" % [
		str(_run_metadata.get("rendering_method_runtime", "unknown")),
		str(_run_metadata.get("display_driver", "unknown")),
		str(_run_metadata.get("audio_driver", "unknown")),
	])
	print("visual quality: level %d / %s" % [
		int(_run_metadata.get("visual_quality_level", -1)),
		str((_run_metadata.get("visual_quality_report", {}) as Dictionary).get("quality_name", "unknown")),
	])
	print("settle/freeze: %s" % JSON.stringify(_run_metadata.get("settle_strategy", {})))
	print("")
	print("%-34s %10s %8s %8s %9s %6s" % ["bucket", "triangles", "share", "meshes", "surfaces", "lights"])
	for bucket in buckets:
		var row: Dictionary = _rows[bucket]
		var share := 0.0
		if total_triangles > 0:
			share = 100.0 * float(row["triangles"]) / float(total_triangles)
		print("%-34s %10d %7.1f%% %8d %9d %6d" % [
			bucket, int(row["triangles"]), share, int(row["instances"]),
			int(row["surfaces"]), int(row["lights"]),
		])
	print("%-34s %10d %7.1f%% %8d %9d %6d" % [
		"TOTAL", total_triangles, 100.0, total_instances, total_surfaces, _total_lights,
	])
	print("")
	print("TextMesh lettering:      %d triangles across %d signs (%.1f%% of scene)" % [
		total_text_triangles, total_text_instances,
		0.0 if total_triangles == 0 else 100.0 * float(total_text_triangles) / float(total_triangles),
	])
	print("Unique meshes:           %d" % _unique_meshes.size())
	print("Bound materials (phase): %d  fingerprint %s" % [
		_material_census.bound_materials.size(), _material_census.bound_fingerprint(),
	])
	print("Retained materials:      %d  fingerprint %s" % [
		_material_census.retained_materials.size(), _material_census.retained_fingerprint(),
	])
	print("Unique shaders:          %d" % _material_census.retained_shaders.size())
	print("Unique textures:         %d (%.2f MiB uncompressed upper bound)" % [
		_material_census.retained_textures.size(), float(_texture_bytes()) / 1048576.0,
	])
	print("Freed object refs skipped: %d" % _material_census.skipped_freed_object_references)
	print("Light3D nodes:           %d (%d casting shadows)" % [_total_lights, _shadow_lights])
	print("Particle systems:        %d" % _particles)
	print("Scene tree nodes:        %d" % _total_nodes)
	print("")

	var mesh_class_names := _mesh_classes.keys()
	mesh_class_names.sort_custom(func(a, b): return int(_mesh_classes[a]["triangles"]) > int(_mesh_classes[b]["triangles"]))
	print("--- triangles by mesh kind ---")
	print("%-22s %10s %8s %10s %10s" % ["mesh kind", "triangles", "share", "instances", "tris/inst"])
	for mesh_class in mesh_class_names:
		var entry: Dictionary = _mesh_classes[mesh_class]
		var count := int(entry["instances"])
		var share := 0.0
		if total_triangles > 0:
			share = 100.0 * float(entry["triangles"]) / float(total_triangles)
		print("%-22s %10d %7.1f%% %10d %10d" % [
			mesh_class, int(entry["triangles"]), share, count,
			0 if count == 0 else int(entry["triangles"]) / count,
		])
	print("")

	_heaviest_instances.sort_custom(func(a, b): return int(a["triangles"]) > int(b["triangles"]))
	print("--- 20 heaviest single mesh instances ---")
	for index in mini(20, _heaviest_instances.size()):
		var heavy: Dictionary = _heaviest_instances[index]
		print("%9d  %-18s %s" % [int(heavy["triangles"]), String(heavy["class"]), String(heavy["path"])])
	print("")

	if not _text_sign_rows.is_empty():
		_text_sign_rows.sort_custom(func(a, b): return int(a["triangles"]) > int(b["triangles"]))
		print("--- every live TextMesh, most expensive first ---")
		print("%9s  %5s %7s %6s %6s  %s" % ["triangles", "font", "pixel", "depth", "scale", "text"])
		for sign_row in _text_sign_rows:
			print("%9d  %5d %7.4f %6.3f %6.2f  %s" % [
				int(sign_row["triangles"]), int(sign_row["font_size"]),
				float(sign_row["pixel_size"]), float(sign_row["depth"]),
				float(sign_row["scale"]), String(sign_row["text"]),
			])
		print("")

	var json_path := OS.get_environment("KETH_CENSUS_JSON")
	if json_path != "":
		var payload := {
			"total_triangles": total_triangles,
			"total_mesh_instances": total_instances,
			"total_surfaces": total_surfaces,
			"text_triangles": total_text_triangles,
			"text_instances": total_text_instances,
			"unique_meshes": _unique_meshes.size(),
			# Compatibility alias now resolves to the honest budget currency: the
			# retained/reachable union, not the phase sample.
			"unique_materials": _material_census.retained_materials.size(),
			"bound_phase_unique_materials": _material_census.bound_materials.size(),
			"retained_reachable_unique_materials": _material_census.retained_materials.size(),
			"bound_material_fingerprint": _material_census.bound_fingerprint(),
			"retained_material_fingerprint": _material_census.retained_fingerprint(),
			"bound_material_descriptors": _material_census.bound_descriptors(),
			"retained_material_descriptors": _material_census.retained_descriptors(),
			"unique_shaders": _material_census.retained_shaders.size(),
			"unique_textures": _material_census.retained_textures.size(),
			"texture_bytes": _texture_bytes(),
			"retained_traversal_skipped_freed_object_references": _material_census.skipped_freed_object_references,
			"lights": _total_lights,
			"shadow_lights": _shadow_lights,
			"particle_systems": _particles,
			"nodes": _total_nodes,
			"buckets": _rows,
			"signs": _text_sign_rows,
			"run_metadata": _run_metadata,
		}
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(payload, "\t"))
			file.close()
			print("census JSON written to %s" % json_path)
