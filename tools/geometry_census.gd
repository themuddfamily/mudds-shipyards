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
##   KETH_CENSUS_SCENARIO=station_resident  (default)
##   KETH_CENSUS_SCENARIO=cinder_loaded

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CINDER_LOCATION := preload("res://assets/world/locations/cinder_reach.tres")

const SCHEMA_VERSION := 2
const DEFAULT_SETTLE_FRAMES := 8
const SCENARIO_STATION_RESIDENT: StringName = &"station_resident"
const SCENARIO_CINDER_LOADED: StringName = &"cinder_loaded"
const DEFAULT_SCENARIO: StringName = SCENARIO_STATION_RESIDENT
const SCENARIO_ENVIRONMENT_VARIABLE := "KETH_CENSUS_SCENARIO"
const HIGH_VISUAL_QUALITY_LEVEL := 2
const CINDER_CLEAR_APPROACH_OFFSET := Vector3(0.0, 4.0, 170.0)
const CINDER_LOAD_FRAME_BUDGET := 60


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
			_walk_bound_node(
				child,
				"%s/%s" % [origin, _stable_sibling_segment(child)]
			)


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
				_visit_object(
					child,
					"%s/%s" % [origin, _stable_sibling_segment(child)]
				)


	func _note_retained_material(material: Material, origin: String) -> void:
		var instance_id := material.get_instance_id()
		retained_materials[instance_id] = material
		if not retained_origins.has(instance_id) or origin < str(retained_origins[instance_id]):
			retained_origins[instance_id] = origin
		_visit_object(material, origin)


	func _hold_resource(resource: Resource) -> void:
		_strong_resources.append(resource)


	func _stable_sibling_segment(node: Node) -> String:
		var runtime_name := str(node.name)
		if not runtime_name.begins_with("@"):
			return runtime_name
		var parent := node.get_parent()
		if parent == null:
			return "%s[01]" % node.get_class()
		var ordinal := 0
		for sibling in parent.get_children():
			if sibling.get_class() == node.get_class() \
				and str(sibling.name).begins_with("@"):
				ordinal += 1
				if sibling == node:
					break
		return "%s[%02d]" % [node.get_class(), maxi(ordinal, 1)]


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
	var scenario := StringName(
		OS.get_environment(SCENARIO_ENVIRONMENT_VARIABLE).strip_edges()
	)
	if scenario.is_empty():
		scenario = DEFAULT_SCENARIO
	if scenario not in [SCENARIO_STATION_RESIDENT, SCENARIO_CINDER_LOADED]:
		printerr("census: unsupported scenario: %s" % scenario)
		quit(1)
		return
	var settle := DEFAULT_SETTLE_FRAMES
	var settle_override := OS.get_environment("KETH_CENSUS_SETTLE")
	if settle_override.is_valid_int():
		settle = maxi(1, settle_override.to_int())

	var game := MAIN_SCENE.instantiate() as GameFlow
	if game == null:
		printerr("census: main scene failed to instantiate")
		quit(1)
		return
	root.add_child(game)
	# Let Main finish its production settings application before overriding the
	# saved profile with the census's declared HIGH contract.
	await process_frame
	await physics_frame
	await process_frame
	if not force_high_visual_quality(game):
		printerr("census: production HIGH visual quality is unavailable")
		game.queue_free()
		await process_frame
		quit(1)
		return

	if scenario == SCENARIO_CINDER_LOADED:
		var prepared := await prepare_cinder_loaded_scenario(game)
		if not bool(prepared.get("accepted", false)):
			printerr("census: Cinder scenario preparation failed: %s" % prepared)
			game.queue_free()
			await process_frame
			quit(1)
			return
	# Give either production scenario the same declared settle phase before
	# freezing either material view.
	for _frame in settle:
		await process_frame
	await physics_frame
	await process_frame

	# Freeze the instantiated scene before either material view is taken. This
	# makes "bound" a declared phase rather than whichever `_process()` callback
	# happens to win while the tree is being walked.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var scenario_contract := inspect_production_scenario(game, scenario)
	if not bool(scenario_contract.get("valid", false)):
		printerr("census: invalid production scenario: %s" % scenario_contract)
		game.queue_free()
		await process_frame
		quit(1)
		return
	var loaded_instance_count := int(
		scenario_contract.get("loaded_instance_count", -1)
	)
	_run_metadata = _capture_run_metadata(
		settle,
		game,
		scenario,
		loaded_instance_count
	)
	_material_census.collect_bound(game)
	_walk(game, "")
	_material_census.collect_retained(game)

	_report(scenario, loaded_instance_count)

	game.queue_free()
	await process_frame
	quit(0)


## Saved local settings must not silently select a different geometry/LOD
## roster. Both scenarios freeze the production HIGH profile before settling.
static func force_high_visual_quality(game: GameFlow) -> bool:
	if not is_instance_valid(game):
		return false
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	if not is_instance_valid(world):
		return false
	world.apply_visual_quality(HIGH_VISUAL_QUALITY_LEVEL)
	return world.visual_quality_level == HIGH_VISUAL_QUALITY_LEVEL


## Loads one real Cinder generation through Main's production streaming
## bootstrap/binding pair. The guided ship occupies the authored clear approach
## lane only to supply the production distance sample; the census takes no
## streaming or gameplay authority itself.
static func prepare_cinder_loaded_scenario(game: GameFlow) -> Dictionary:
	if not is_instance_valid(game) or not game.is_inside_tree():
		return {"accepted": false, "reason": &"invalid_main"}
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var ship := game.get_guided_ship()
	if not is_instance_valid(bootstrap) \
		or not is_instance_valid(binding) \
		or not is_instance_valid(ship):
		return {"accepted": false, "reason": &"production_streaming_unavailable"}
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = CINDER_LOCATION.get_anchor_position() \
		+ CINDER_CLEAR_APPROACH_OFFSET
	var tree := game.get_tree()
	for _frame in CINDER_LOAD_FRAME_BUDGET:
		await tree.physics_frame
		await tree.process_frame
		var loaded := bootstrap.get_loaded_instance()
		if is_instance_valid(loaded) and int(
			binding.get_snapshot().get("quality_synced_instance_id", 0)
		) == loaded.get_instance_id():
			return {
				"accepted": true,
				"reason": &"loaded",
				"loaded_instance_count": game.find_children(
					"*", "NearbySectorCluster", true, false
				).size(),
				"generation": int(loaded.get_meta(
					&"world_location_generation", -1
				)),
			}.duplicate(true)
	return {"accepted": false, "reason": &"load_timeout"}


## Rejects accidental mixed baselines: resident means no Cinder generation;
## loaded means the sole instance is the coordinator-owned committed one.
static func inspect_production_scenario(
		scene_root: Node,
		scenario: StringName
	) -> Dictionary:
	var errors := PackedStringArray()
	var loaded_instances := scene_root.find_children(
		"*", "NearbySectorCluster", true, false
	) if is_instance_valid(scene_root) else []
	var loaded_instance_count := loaded_instances.size()
	var bootstrap := scene_root.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap if is_instance_valid(scene_root) else null
	var coordinator_loaded := bootstrap.get_loaded_instance() \
		if is_instance_valid(bootstrap) else null
	if scenario == SCENARIO_STATION_RESIDENT:
		if loaded_instance_count != 0 or is_instance_valid(coordinator_loaded):
			errors.append(
				"station-resident scenario requires zero loaded Cinder instances"
			)
	elif scenario == SCENARIO_CINDER_LOADED:
		if loaded_instance_count != 1:
			errors.append("Cinder-loaded scenario requires exactly one loaded instance")
		elif not is_instance_valid(coordinator_loaded) \
			or coordinator_loaded != loaded_instances[0]:
			errors.append(
				"loaded Cinder instance must be the coordinator-owned generation"
			)
	else:
		errors.append("unsupported production scenario: %s" % scenario)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scenario": scenario,
		"loaded_instance_count": loaded_instance_count,
	}.duplicate(true)


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
	here += _stable_sibling_segment(node)
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


static func _stable_sibling_segment(node: Node) -> String:
	var runtime_name := str(node.name)
	if not runtime_name.begins_with("@"):
		return runtime_name
	var parent := node.get_parent()
	if parent == null:
		return "%s[01]" % node.get_class()
	var ordinal := 0
	for sibling in parent.get_children():
		if sibling.get_class() == node.get_class() \
			and str(sibling.name).begins_with("@"):
			ordinal += 1
			if sibling == node:
				break
	return "%s[%02d]" % [node.get_class(), maxi(ordinal, 1)]


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


## Public focused-test seam. The caller owns lifecycle/settling and must pass a
## disabled production root plus an already-validated scenario contract.
func measure_frozen_scene(
		scene_root: Node,
		scenario: StringName,
		loaded_instance_count: int
	) -> Dictionary:
	_reset_measurement()
	_material_census.collect_bound(scene_root)
	_walk(scene_root, "")
	_material_census.collect_retained(scene_root)
	return _build_payload(scenario, loaded_instance_count)


func _reset_measurement() -> void:
	_rows = {}
	_unique_meshes = {}
	_material_census = MaterialResourceCensus.new()
	_mesh_triangle_cache = {}
	_text_sign_rows = []
	_mesh_classes = {}
	_heaviest_instances = []
	_total_nodes = 0
	_total_lights = 0
	_shadow_lights = 0
	_particles = 0


func _capture_run_metadata(
		settle_frames: int,
		game: Node,
		scenario: StringName,
		loaded_instance_count: int
	) -> Dictionary:
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
		"scenario": scenario,
		"loaded_instance_count": loaded_instance_count,
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
			"initialization_idle_frames_before_quality": 1,
			"initialization_physics_frames_before_quality": 1,
			"initialization_final_idle_frames_before_quality": 1,
			"idle_frames_before_freeze": settle_frames,
			"physics_frames_before_freeze": 1,
			"final_idle_frames_before_freeze": 1,
			"freeze": "production scene root process_mode set to PROCESS_MODE_DISABLED before synchronous census",
		},
		"frozen_phase": "after configured idle settle, one physics frame, and one final idle frame",
	}


func _build_payload(
		scenario: StringName,
		loaded_instance_count: int
	) -> Dictionary:
	var total_triangles := 0
	var total_instances := 0
	var total_surfaces := 0
	var total_text_triangles := 0
	var total_text_instances := 0
	for row_variant in _rows.values():
		var row := row_variant as Dictionary
		total_triangles += int(row.get("triangles", 0))
		total_instances += int(row.get("instances", 0))
		total_surfaces += int(row.get("surfaces", 0))
		total_text_triangles += int(row.get("text_triangles", 0))
		total_text_instances += int(row.get("text_instances", 0))
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"scenario": scenario,
		"loaded_instance_count": loaded_instance_count,
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
		"buckets": _rows.duplicate(true),
		"signs": _text_sign_rows.duplicate(true),
		"run_metadata": _run_metadata.duplicate(true),
	}
	payload["measurement_fingerprint"] = build_measurement_fingerprint(payload)
	return payload.duplicate(true)


func _report(scenario: StringName, loaded_instance_count: int) -> void:
	var payload := _build_payload(scenario, loaded_instance_count)
	var buckets := _rows.keys()
	buckets.sort_custom(func(a, b): return int(_rows[a]["triangles"]) > int(_rows[b]["triangles"]))

	var total_triangles := int(payload.total_triangles)
	var total_instances := int(payload.total_mesh_instances)
	var total_surfaces := int(payload.total_surfaces)
	var total_text_triangles := int(payload.text_triangles)
	var total_text_instances := int(payload.text_instances)

	print("")
	print("=== GEOMETRY CENSUS: scenes/main.tscn ===")
	print("(counts are renderer-independent; this box has no usable GPU timing)")
	print("scenario: %s / loaded Cinder instances: %d" % [
		str(scenario), loaded_instance_count,
	])
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

	print("Measurement fingerprint: %s" % payload.measurement_fingerprint)
	print("")

	var json_path := OS.get_environment("KETH_CENSUS_JSON")
	if json_path != "":
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(payload, "\t"))
			file.close()
			print("census JSON written to %s" % json_path)


## Hashes the deterministic measurement contract, deliberately excluding run
## provenance such as Git dirty state and command-line paths. Scenario identity
## and loaded count are first-class inputs even if every numeric count is held
## constant by a mutation fixture.
static func build_measurement_fingerprint(report: Dictionary) -> String:
	var descriptors := PackedStringArray([
		"scenario|id=%s|loaded_instances=%d" % [
			str(report.get("scenario", &"")),
			int(report.get("loaded_instance_count", -1)),
		],
		"geometry|triangles=%d|instances=%d|surfaces=%d|unique_meshes=%d" % [
			int(report.get("total_triangles", 0)),
			int(report.get("total_mesh_instances", 0)),
			int(report.get("total_surfaces", 0)),
			int(report.get("unique_meshes", 0)),
		],
		"text|triangles=%d|instances=%d" % [
			int(report.get("text_triangles", 0)),
			int(report.get("text_instances", 0)),
		],
		"materials|bound=%d|retained=%d" % [
			int(report.get("bound_phase_unique_materials", 0)),
			int(report.get("retained_reachable_unique_materials", 0)),
		],
		"resources|shaders=%d|textures=%d|texture_bytes=%d" % [
			int(report.get("unique_shaders", 0)),
			int(report.get("unique_textures", 0)),
			int(report.get("texture_bytes", 0)),
		],
		"scene|lights=%d|shadow_lights=%d|particles=%d|nodes=%d" % [
			int(report.get("lights", 0)),
			int(report.get("shadow_lights", 0)),
			int(report.get("particle_systems", 0)),
			int(report.get("nodes", 0)),
		],
	])
	var buckets := report.get("buckets", {}) as Dictionary
	var bucket_names := PackedStringArray()
	for bucket_variant in buckets:
		bucket_names.append(str(bucket_variant))
	bucket_names.sort()
	for bucket_name in bucket_names:
		var row := buckets.get(bucket_name, {}) as Dictionary
		descriptors.append(
			"bucket|%s|triangles=%d|instances=%d|surfaces=%d|multi_copies=%d|lights=%d|nodes=%d|text_triangles=%d|text_instances=%d"
			% [
				bucket_name,
				int(row.get("triangles", 0)),
				int(row.get("instances", 0)),
				int(row.get("surfaces", 0)),
				int(row.get("multimesh_instances", 0)),
				int(row.get("lights", 0)),
				int(row.get("nodes", 0)),
				int(row.get("text_triangles", 0)),
				int(row.get("text_instances", 0)),
			]
		)
	descriptors.sort()
	return "\n".join(descriptors).sha256_text()
