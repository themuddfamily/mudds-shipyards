extends SceneTree

## Renders the station's wayfinding lettering at reading distance and at
## distance, so a triangle saving can be checked against the only thing that
## actually matters about a sign: whether it can still be read.
##
## This runner is deliberately not a `_test.gd` suite. It produces pictures for
## a human (or an agent with eyes) to look at; it asserts nothing about them,
## because "legible" is not a number.
##
## Usage:
##   godot --headless --audio-driver Dummy --script res://tests/capture_sign_legibility.gd
##
## Optional environment variables:
##   KETH_SIGN_CAPTURE_DIR=res://path   output directory (default below).
##   KETH_SIGN_CAPTURE_TAG=before       filename prefix (default "shot").

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")

const DEFAULT_OUTPUT_DIR := "res://artifacts/sign_legibility"
const CAPTURE_RESOLUTION := Vector2i(1920, 1080)

## Each entry names a live sign and the two distances it is judged at. The
## "reading" distance is roughly where a walking player stops in front of it;
## the "far" distance is where it still has to resolve as wayfinding rather than
## as a smudge. Distances are metres along the sign's own readable axis.
const SUBJECTS: Array = [
	{
		"key": "junction_board",
		"node": "ShipyardWorld/ExposedDockLattice/Sign_MUDDS__--__REGENERATION_DECK",
		"reading": 7.0,
		"far": 34.0,
		"note": "the station's most prominent navigation board",
	},
	{
		"key": "registry_dense",
		"node": "ShipyardWorld/ModernFleetRegistry/Sign_KATANA__PARADOX__PREDATOR__DYNAMIC",
		"reading": 2.2,
		# 5.0 m rather than something longer: the registry terminal stands inside
		# a roofed pod, and a camera further back is looking at the pod's ceiling
		# slab instead of at the sign.
		"far": 5.0,
		"note": "the smallest, densest lettering in the game: worst case",
	},
	{
		"key": "dock_operations",
		"node": "ShipyardWorld/UpperOperations/Sign_DOCK_OPERATIONS",
		"reading": 6.0,
		"far": 26.0,
		"note": "berth identity legend on the operations pod",
	},
	{
		"key": "cinder_gate",
		"node": "CinderStreamingBootstrap/WorldStreamingCoordinator/WorldLocation_CinderReach/ExtractionPlatform/CinderReachPlatform/Sign_CINDER_REACH_DOCK_GATE",
		"reading": 40.0,
		"far": 190.0,
		"note": "sector wayfinding, read from a moving craft",
	},
]

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var output_dir := OS.get_environment("KETH_SIGN_CAPTURE_DIR")
	if output_dir == "":
		output_dir = DEFAULT_OUTPUT_DIR
	var tag := OS.get_environment("KETH_SIGN_CAPTURE_TAG")
	if tag == "":
		tag = "shot"

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	var window := root
	window.size = CAPTURE_RESOLUTION
	window.content_scale_size = CAPTURE_RESOLUTION

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	await physics_frame
	if not await _load_cinder_through_production_binding(game):
		_failures.append("production binding did not stream Cinder for its capture subject")

	# The production main scene opens on its title layer. These are pictures of
	# geometry, so every CanvasLayer is switched off rather than dismissed, and
	# nothing capture-only is added to the world in its place.
	for candidate in game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED

	var camera := Camera3D.new()
	camera.name = "SignLegibilityCamera"
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 4000.0
	camera.current = true
	root.add_child(camera)

	for subject in SUBJECTS:
		var node := game.get_node_or_null(NodePath(String(subject["node"]))) as MeshInstance3D
		if node == null:
			_failures.append("missing sign: %s" % String(subject["node"]))
			continue
		var mesh := node.mesh
		var extent := Vector3.ZERO
		var triangles := 0
		if mesh != null:
			extent = mesh.get_aabb().size * node.global_basis.get_scale()
			triangles = _triangles(mesh)
		print("%-16s %7d tris  %.2f x %.2f m  %s" % [
			String(subject["key"]), triangles, extent.x, extent.y, String(subject["note"]),
		])
		# The third shot is from behind. Flattening a sign removes its back face,
		# so this is the one place the saving could show up as a visible change,
		# and it is photographed rather than reasoned about.
		var shots := [
			["read", float(subject["reading"])],
			["far", float(subject["far"])],
			["back", -float(subject["reading"])],
		]
		for shot in shots:
			_aim(camera, node, float(shot[1]))
			for _frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := get_root().get_texture().get_image()
			var path := "%s/%s_%s_%s.png" % [output_dir, tag, String(subject["key"]), String(shot[0])]
			var error := image.save_png(path)
			if error != OK:
				_failures.append("could not write %s (%d)" % [path, error])

	camera.queue_free()
	game.queue_free()
	await process_frame

	if _failures.is_empty():
		print("sign legibility captures written to %s (tag %s)" % [output_dir, tag])
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)


func _load_cinder_through_production_binding(game: Node) -> bool:
	var flow := game as GameFlow
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var ship := flow.get_guided_ship() if flow != null else null
	if flow == null or ship == null or bootstrap == null:
		return false
	# The on-foot Player would trigger GameFlow's below-deck recall at Cinder's
	# y=-70 anchor. Hold the legitimate production ship/provider in the authored
	# clear approach lane instead: it remains within the load radius without
	# embedding the live hull in the platform's collidable CoreDrum.
	flow.active_ship = ship
	ship.set_piloted(true)
	ship.velocity = Vector3.ZERO
	ship.global_position = LOCATION.get_anchor_position() + Vector3(
		0.0,
		NearbySectorCluster.GANTRY_CENTER_Y,
		170.0
	)
	for _frame in 60:
		await physics_frame
		await process_frame
		if bootstrap.get_loaded_instance() != null:
			return true
	return false


## `TextMesh` presents its readable face toward local +Z, so the reader stands
## on that side. Framing is anchored on the mesh AABB centre rather than the
## node origin, because vertical alignment can offset the glyph block.
func _aim(camera: Camera3D, sign_node: MeshInstance3D, distance: float) -> void:
	var centre := sign_node.global_transform * sign_node.mesh.get_aabb().get_center()
	var forward := sign_node.global_basis.z.normalized()
	camera.global_position = centre + forward * distance
	camera.look_at(centre, Vector3.UP)
	# The production scene owns player and cockpit cameras that claim the
	# viewport as the game flow advances; reclaim it for every shot.
	camera.make_current()


func _triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
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
	return total
