extends SceneTree

## One HUD-free Forward+ gameplay-distance frame of the production Central
## Berth readiness board. The harness adds only a camera: the board, assigned
## pins, deferred pin and batched sockets all come from the complete main scene.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_PATH := "res://artifacts/central_berth_service_board/board_batched_sockets.png"
const CAPTURE_RESOLUTION := Vector2i(1920, 1080)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a live Forward+ rendering device"
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "complete production main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	for _frame in 12:
		await process_frame
	await physics_frame

	for candidate in game.find_children("*", "CanvasLayer", true, false):
		(candidate as CanvasLayer).visible = false
	var player := game.get_node_or_null(^"Player") as Node3D
	if player != null:
		player.visible = false

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var board := world.get_node_or_null(
		^"CentralBerthServiceLine/PortFlank/BerthReadinessBoard"
	) as Node3D if world != null else null
	var sockets := board.get_node_or_null(^"BayPinSockets") as MultiMeshInstance3D \
		if board != null else null
	_check(world != null and board != null and sockets != null, "production service board and socket batch resolve")
	if world == null or board == null or sockets == null or sockets.multimesh == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var render_contract := world.get_central_berth_service_line_render_contract()
	_check(
		bool(world.get_central_berth_service_line_report().get("valid", false))
		and bool(render_contract.get("exact_counts", false))
		and sockets.multimesh.instance_count == ShipyardWorld.SERVICE_LINE_BAY_PIN_SOCKET_COPY_COUNT,
		"production service-line and three-copy batch contracts are green"
	)
	var state_roster := _board_state_roster(board)
	_check(
		int(state_roster.get("seated", 0)) == 2
		and int(state_roster.get("withdrawn", 0)) == 1
		and int(state_roster.get("former_socket_nodes", 0)) == 0,
		"two assigned pins and one deferred pin remain independent above the batch"
	)

	var camera := Camera3D.new()
	camera.name = "CentralBerthServiceBoardCaptureCamera"
	camera.near = 0.06
	camera.far = 300.0
	camera.fov = 31.0
	game.add_child(camera)
	camera.global_position = board.to_global(Vector3(0.0, 1.52, 4.0))
	camera.look_at(board.to_global(Vector3(0.0, 1.44, 0.10)), Vector3.UP)
	camera.current = true
	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_RESOLUTION,
		"gameplay-distance board frame renders at the requested resolution"
	)
	if image != null and not image.is_empty():
		var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "capture saves successfully")
		print("CENTRAL_BERTH_SERVICE_BOARD_CAPTURE: ", absolute)

	game.queue_free()
	await process_frame
	_finish()


func _board_state_roster(board: Node3D) -> Dictionary:
	var seated := 0
	var withdrawn := 0
	var former_socket_nodes := 0
	for candidate in board.find_children("*", "", true, false):
		if candidate.name.begins_with("BaySeatedPin"):
			seated += 1
		elif candidate.name.begins_with("WithdrawnPin") \
				and not candidate.name.begins_with("WithdrawnPinClip"):
			withdrawn += 1
		elif candidate.name.begins_with("BayPinSocket") \
				and candidate.name != &"BayPinSockets":
			former_socket_nodes += 1
	return {
		"seated": seated,
		"withdrawn": withdrawn,
		"former_socket_nodes": former_socket_nodes,
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CENTRAL_BERTH_SERVICE_BOARD_CAPTURE_OK")
		quit(0)
		return
	print("CENTRAL_BERTH_SERVICE_BOARD_CAPTURE_FAILED: ", "; ".join(_failures))
	quit(1)
