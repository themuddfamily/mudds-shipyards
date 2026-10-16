extends RefCounted

## Optional Forward+ capture used by cinder_cargo_access_test.gd -- --capture.
## The default input journey has no image dependency; this helper retains the
## existing capture setup and runs only through the explicit capture dispatch.
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")


static func capture(tree: SceneTree) -> void:
	var root := tree.root
	root.size = Vector2i(1400, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	stage.add_child(cluster)
	await tree.process_frame
	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	if access == null or terminal == null:
		print("CINDER_CARGO_ACCESS_CAPTURE_FAILED")
		tree.quit(1)
		return
	var ship := JOVIAN_SCENE.instantiate() as HeroShip
	stage.add_child(ship)
	await tree.process_frame
	ship.global_transform = access.get_berth().get_dock_transform()
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("03080c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91aeb8")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color("d8edf2")
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 58.0
	stage.add_child(camera)
	camera.global_position = access.to_global(Vector3(-48.0, 17.0, 39.0))
	camera.look_at(access.to_global(Vector3(-15.0, 3.3, 11.0)), Vector3.UP)
	for _frame in 10:
		await tree.process_frame
		# HeroShip owns its gameplay camera each process tick. Evidence ownership is
		# deliberately reassigned after that tick so the capture cannot silently
		# become a cockpit/ship-camera frame.
		camera.current = true
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/cinder-cargo-access-forward-plus.png")
	print("CINDER_CARGO_ACCESS_CAPTURE_OK" if error == OK else "CINDER_CARGO_ACCESS_CAPTURE_FAILED")
	tree.quit(0 if error == OK else 1)
