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

## Buckets are derived from the scene path rather than hand-listed, so a sibling
## adding a new station module or sector gets its own row without editing this
## tool. Everything under `ShipyardWorld` is split one level deeper, because the
## station is the bulk of the scene and a single `ShipyardWorld` row would hide
## the distribution that this census exists to expose.
const SPLIT_ROOTS: Array[String] = ["ShipyardWorld"]

const FALLBACK_BUCKET := "(scene root)"

var _rows: Dictionary = {}
var _unique_meshes: Dictionary = {}
var _unique_materials: Dictionary = {}
var _unique_shaders: Dictionary = {}
var _unique_textures: Dictionary = {}
var _mesh_triangle_cache: Dictionary = {}

var _text_sign_rows: Array = []
var _mesh_classes: Dictionary = {}
var _heaviest_instances: Array = []

var _total_nodes := 0
var _total_lights := 0
var _shadow_lights := 0
var _particles := 0


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

	_walk(game, "")

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
			_note_material((node as MultiMeshInstance3D).material_override)
	elif node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var mesh := instance.mesh
		if mesh != null:
			var tris := _mesh_triangles(mesh)
			row["triangles"] = int(row["triangles"]) + tris
			row["instances"] = int(row["instances"]) + 1
			row["surfaces"] = int(row["surfaces"]) + mesh.get_surface_count()
			_note_mesh(mesh, tris, 1, effective)
			_note_material(instance.material_override)
			for surface in mesh.get_surface_count():
				_note_material(instance.get_surface_override_material(surface))
				_note_material(mesh.surface_get_material(surface))
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


func _note_material(material: Material) -> void:
	if material == null:
		return
	_unique_materials[material.get_instance_id()] = true
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		if shader != null:
			_unique_shaders[shader.get_instance_id()] = true
	elif material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		for slot in [
			BaseMaterial3D.TEXTURE_ALBEDO,
			BaseMaterial3D.TEXTURE_NORMAL,
			BaseMaterial3D.TEXTURE_ROUGHNESS,
			BaseMaterial3D.TEXTURE_METALLIC,
			BaseMaterial3D.TEXTURE_EMISSION,
			BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION,
		]:
			var texture := base.get_texture(slot)
			if texture != null:
				_unique_textures[texture.get_instance_id()] = texture


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
	var bytes := 0
	for id in _unique_textures:
		var texture: Texture2D = _unique_textures[id]
		var size := texture.get_size()
		# Four bytes per texel is the honest uncompressed upper bound; the
		# project imports these losslessly.
		bytes += int(size.x) * int(size.y) * 4
	return bytes


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
	print("Unique materials:        %d" % _unique_materials.size())
	print("Unique shaders:          %d" % _unique_shaders.size())
	print("Unique textures:         %d (%.2f MiB uncompressed upper bound)" % [
		_unique_textures.size(), float(_texture_bytes()) / 1048576.0,
	])
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
			"unique_materials": _unique_materials.size(),
			"unique_shaders": _unique_shaders.size(),
			"unique_textures": _unique_textures.size(),
			"texture_bytes": _texture_bytes(),
			"lights": _total_lights,
			"shadow_lights": _shadow_lights,
			"particle_systems": _particles,
			"nodes": _total_nodes,
			"buckets": _rows,
			"signs": _text_sign_rows,
		}
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(payload, "\t"))
			file.close()
			print("census JSON written to %s" % json_path)
