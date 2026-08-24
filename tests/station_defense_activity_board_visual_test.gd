extends SceneTree

const BOARD_SCRIPT := preload("res://scripts/activities/station_defense_activity_board.gd")
const PHYSICS_LAYERS := preload("res://scripts/core/physics_layers.gd")
const OUTPUT_PATH := "/tmp/station-defense-activity-board-readability.png"

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "StationDefenseBoardReadabilityReview"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	root.add_child(viewport)

	var stage := Node3D.new()
	viewport.add_child(stage)
	var board := BOARD_SCRIPT.new() as Area3D
	stage.add_child(board)
	await process_frame

	var body := board.get_node_or_null(^"CollisionBackedConsole") as StaticBody3D
	var body_collision := body.get_node_or_null(^"Collision") as CollisionShape3D \
		if body != null else null
	var interaction := board.get_node_or_null(^"InteractionCollision") as CollisionShape3D
	var readability := body.get_node_or_null(^"StationDefenseReadability") as Node3D \
		if body != null else null
	var backing := body.get_node_or_null(
		^"StationDefenseReadability/DefenseActivityLocator"
	) as MeshInstance3D if body != null else null
	var port := body.get_node_or_null(
		^"StationDefenseReadability/LocatorBracketPort"
	) as MeshInstance3D if body != null else null
	var starboard := body.get_node_or_null(
		^"StationDefenseReadability/LocatorBracketStarboard"
	) as MeshInstance3D if body != null else null
	var underline := body.get_node_or_null(
		^"StationDefenseReadability/ActivityBoardLocatorUnderline"
	) as MeshInstance3D if body != null else null
	var title := board.get_node_or_null(^"ActivityLabel") as Label3D
	var status := board.get_node_or_null(^"StatusLabel") as Label3D

	_check(
		readability != null
		and bool(readability.get_meta("presentation_only", false))
		and readability.get_child_count() == 4,
		"board owns one bounded presentation-only locator group"
	)
	_check(
		backing != null and backing.mesh is BoxMesh
		and (backing.mesh as BoxMesh).size == Vector3(1.58, 0.70, 0.08)
		and port != null and starboard != null
		and port.position.x < backing.position.x
		and starboard.position.x > backing.position.x
		and not is_equal_approx(port.rotation.z, starboard.rotation.z),
		"wide backing and opposed cyan brackets form a distinct approach silhouette"
	)
	_check(
		title != null
		and title.text == "STATION DEFENSE\nACTIVITY BOARD"
		and title.font_size == 18
		and title.outline_size == 7
		and title.get_aabb().size.x <= 0.75
		and underline != null
		and underline.mesh is BoxMesh
		and (underline.mesh as BoxMesh).size == Vector3(1.28, 0.025, 0.025),
		"literal two-line title and amber underline fit inside the widened locator face"
	)
	_check(
		status != null and status.text == "AWAITING LINK"
		and board.find_children("*", "Light3D", true, false).is_empty()
		and board.find_children("*", "AnimationPlayer", true, false).is_empty(),
		"static readability treatment adds no light, pulse, or local activity clock"
	)
	_check(
		body_collision != null
		and (body_collision.shape as BoxShape3D).size == Vector3(1.4, 1.0, 2.2)
		and body_collision.position == Vector3(1.25, -0.5, 0.0)
		and interaction != null
		and (interaction.shape as BoxShape3D).size == Vector3(2.4, 2.2, 1.8)
		and interaction.position == Vector3(1.25, 0.25, 0.45)
		and board.collision_layer == PHYSICS_LAYERS.INTERACTABLE_AREA_LAYER,
		"presentation leaves body collision, interaction envelope, and layer unchanged"
	)
	var snapshot: Dictionary = board.get_snapshot()
	_check(
		not bool(snapshot.combat_authority)
		and not bool(snapshot.activity_authority)
		and not bool(snapshot.health_authority)
		and not bool(snapshot.reward_authority)
		and int(snapshot.process_loops) == 0
		and int(snapshot.presentation.readability_geometry_nodes) == 4
		and int(snapshot.presentation.lights) == 0,
		"visual locator remains presentation-only in the public board snapshot"
	)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("07131d")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("9cb6c7")
	environment_resource.ambient_light_energy = 0.55
	environment.environment = environment_resource
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	key.light_energy = 1.2
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.position = Vector3(1.25, 1.35, 5.8)
	camera.fov = 42.0
	stage.add_child(camera)
	camera.look_at(Vector3(1.25, 0.75, 0.25))
	camera.current = true
	for _frame in 5:
		await process_frame
	var image := viewport.get_texture().get_image()
	var save_error := image.save_png(OUTPUT_PATH) if image != null and not image.is_empty() \
		else ERR_CANT_CREATE
	_check(
		save_error == OK and image.get_width() == 960 and image.get_height() == 540,
		"focused gameplay-distance review capture saves at the requested frame size"
	)

	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STATION_DEFENSE_ACTIVITY_BOARD_VISUAL_TEST_OK %s" % OUTPUT_PATH)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("FAIL: " + message)
