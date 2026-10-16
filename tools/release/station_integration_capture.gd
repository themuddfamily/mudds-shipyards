extends RefCounted
## Optional station integration readback. Invoke the legacy capture flags with a
## real renderer and active render loop; the default playability suite needs only
## a display for continuous InputMap actions.

var _tree: SceneTree
var _check: Callable


func _init(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check


static func requested() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--capture-fabrication-integration") \
		or args.has("--capture-observation-integration") \
		or args.has("--capture-salvage-integration")


static func renderer_error() -> String:
	# Recognized engine flags are removed from OS.get_cmdline_args(). Query the
	# live renderer so disabled drawing is rejected even under an X11 display.
	if DisplayServer.get_name() == "headless" or not RenderingServer.is_render_loop_enabled() \
		or RenderingServer.get_current_rendering_driver_name() == "dummy":
		return "Station integration capture requires a real renderer, a display, and an active render loop; run the legacy --capture-*-integration flag directly without --headless or --disable-render-loop."
	return ""


func capture_requested(game: GameFlow, world: ShipyardWorld) -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-fabrication-integration"):
		await _capture_fabrication_integration_frame(game, world)
	if args.has("--capture-observation-integration"):
		await _capture_observation_integration_frame(game, world)
	if args.has("--capture-salvage-integration"):
		await _capture_salvage_integration_frame(game, world)


func _capture_fabrication_integration_frame(game: GameFlow, world: ShipyardWorld) -> void:
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	var connector := world.get_node_or_null(^"ExposedDockLattice/FabricationAnnexConnector") as Node3D
	_check.call(annex != null and connector != null, "integrated Forward+ frame resolves the live Annex and connector")
	if annex == null or connector == null:
		return
	var hud := game.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var camera := Camera3D.new()
	camera.name = "FabricationIntegrationEvidenceCamera"
	camera.position = Vector3(112.0, 34.0, 8.0)
	camera.look_at_from_position(camera.position, Vector3(70.0, 0.8, 38.0), Vector3.UP)
	camera.fov = 52.0
	camera.current = true
	game.add_child(camera)
	for _frame in 8:
		await _tree.process_frame
		await _tree.physics_frame
	await RenderingServer.frame_post_draw
	var image := _tree.root.get_viewport().get_texture().get_image()
	var output_path := "/tmp/fabrication-annex-integrated-forward-plus.png"
	var error := image.save_png(output_path)
	_check.call(
		error == OK and image.get_width() >= 1280 and image.get_height() >= 720,
		"exactly one normal-resolution integrated Forward+ frame is captured"
	)
	print("FABRICATION_INTEGRATED_FRAME: %s %s" % [output_path, image.get_size()])


func _capture_observation_integration_frame(game: GameFlow, world: ShipyardWorld) -> void:
	var spur := world.get_node_or_null(^"ObservationLogisticsSpur") as ObservationLogisticsSpur
	var connector := world.get_node_or_null(^"ExposedDockLattice/ObservationLogisticsConnector") as Node3D
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	_check.call(spur != null and connector != null and annex != null, "integrated Forward+ frame resolves Observation, its world connector, and Fabrication gate")
	if spur == null or connector == null or annex == null:
		return
	var hud := game.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var camera := Camera3D.new()
	camera.name = "ObservationIntegrationEvidenceCamera"
	camera.position = Vector3(154.0, 38.0, 7.0)
	camera.look_at_from_position(camera.position, Vector3(111.0, 1.0, 38.0), Vector3.UP)
	camera.fov = 55.0
	camera.current = true
	game.add_child(camera)
	for _frame in 8:
		await _tree.process_frame
		await _tree.physics_frame
	await RenderingServer.frame_post_draw
	var image := _tree.root.get_viewport().get_texture().get_image()
	var output_path := "/tmp/observation-logistics-integrated-forward-plus.png"
	var error := image.save_png(output_path)
	_check.call(
		error == OK and image.get_width() >= 1280 and image.get_height() >= 720,
		"exactly one normal-resolution integrated Observation Forward+ frame is captured"
	)
	print("OBSERVATION_INTEGRATED_FRAME: %s %s" % [output_path, image.get_size()])


func _capture_salvage_integration_frame(game: GameFlow, world: ShipyardWorld) -> void:
	var salvage := world.get_node_or_null(^"SalvageTerrace") as SalvageTerrace
	var connector := world.get_node_or_null(^"ExposedDockLattice/SalvageTerraceConnector") as Node3D
	var annex := world.get_node_or_null(^"FabricationAnnex") as FabricationAnnex
	_check.call(salvage != null and connector != null and annex != null, "integrated Forward+ frame resolves Salvage, its world connector, and Fabrication seam")
	if salvage == null or connector == null or annex == null:
		return
	var hud := game.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var camera := Camera3D.new()
	camera.name = "SalvageIntegrationEvidenceCamera"
	camera.position = Vector3(126.0, 32.0, 94.0)
	camera.look_at_from_position(camera.position, Vector3(88.0, 2.4, 58.0), Vector3.UP)
	camera.fov = 56.0
	camera.current = true
	game.add_child(camera)
	for _frame in 8:
		await _tree.process_frame
		await _tree.physics_frame
	await RenderingServer.frame_post_draw
	var image := _tree.root.get_viewport().get_texture().get_image()
	var output_path := "/tmp/salvage-terrace-integrated-forward-plus.png"
	var error := image.save_png(output_path)
	_check.call(
		error == OK and image.get_width() >= 1280 and image.get_height() >= 720,
		"exactly one normal-resolution integrated Salvage Forward+ frame is captured"
	)
	print("SALVAGE_INTEGRATED_FRAME: %s %s" % [output_path, image.get_size()])


