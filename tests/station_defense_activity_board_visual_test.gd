extends SceneTree

const BOARD_SCRIPT := preload("res://scripts/activities/station_defense_activity_board.gd")
const CONTENT_SCENE := preload("res://scenes/activities/station_defense_encounter.tscn")
const PHYSICS_LAYERS := preload("res://scripts/core/physics_layers.gd")
const OUTPUT_PATH := "/tmp/station-defense-activity-board-readability.png"
const STATE_CAPTURE_PATHS := {
	&"ready": "/tmp/station-defense-activity-board-ready.png",
	&"active": "/tmp/station-defense-activity-board-active.png",
	&"inter_wave": "/tmp/station-defense-activity-board-inter-wave.png",
	&"completed": "/tmp/station-defense-activity-board-completed.png",
	&"failed": "/tmp/station-defense-activity-board-failed.png",
}
const TEST_WEAPON: StringName = &"board_visual_cannon"
const TEST_SOURCE_ID := 9902

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
	var authority := LiveCombatAuthority.new()
	stage.add_child(authority)
	var director := ActivityDirector.new()
	stage.add_child(director)
	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	stage.add_child(content)
	var board := BOARD_SCRIPT.new() as Area3D
	stage.add_child(board)
	var actor := Node3D.new()
	stage.add_child(actor)
	var attacker := Node3D.new()
	stage.add_child(attacker)
	await process_frame
	await physics_frame
	var configured: Dictionary = board.configure_external_owners(content, authority, director)
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var registered := authority.register_source(
		attacker,
		TEST_SOURCE_ID,
		&"station_allies",
		{TEST_WEAPON: {"range": 200.0, "damage": 100.0, "origin_tolerance": 8.0}}
	)
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
		status != null and status.text == "[ ] READY\nDEPLOY AVAILABLE"
		and board.find_children("*", "Light3D", true, false).is_empty()
		and board.find_children("*", "AnimationPlayer", true, false).is_empty(),
		"public ready binding adds no light, pulse, or local activity clock"
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
	_check(
		bool(configured.get("accepted", false)) and registered,
		"visual review uses the configured public content and combat owners"
	)
	await _capture(viewport, status, &"ready", "[ ] READY\nDEPLOY AVAILABLE")

	var started: bool = board.interact(actor)
	await process_frame
	var generation := content.get_generation()
	var activity := content.get_snapshot().host.activity as Dictionary
	_check(
		started
		and int(activity.get("wave_number", 0)) == 1
		and int(activity.get("current_wave_hostile_count", 0)) == 1,
		"public board interaction reaches the exact one-hostile first wave"
	)
	await _capture(viewport, status, &"active", ">> WAVE 1 / 3\nROSTER 0 / 1")

	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var picket := roster.get_node(^"PerimeterHeavyPicket") as RangeOpponent
	var alpha_terminal := await _destroy(authority, attacker, alpha)
	activity = content.get_snapshot().host.activity as Dictionary
	_check(
		bool(alpha_terminal.get("destroyed", false))
		and int(activity.get("wave_number", 0)) == 2
		and int(activity.get("current_wave_hostile_count", 0)) == 2
		and not bool(activity.get("wave_active", true))
		and is_equal_approx(float(activity.get("wave_delay_remaining_seconds", 0.0)), 0.5),
		"wave-1 clearance settles on the reachable positive-delay wave-2 snapshot"
	)
	await _capture(
		viewport, status, &"inter_wave", "[~] NEXT WAVE 2 / 3\nDEPLOY IN 0.5 S"
	)

	content.advance_physics(0.5, generation)
	await physics_frame
	var beta_terminal := await _destroy(authority, attacker, beta)
	var gamma_terminal := await _destroy(authority, attacker, gamma)
	content.advance_physics(1.25, generation)
	await physics_frame
	var picket_terminal := await _destroy(authority, attacker, picket, 8)
	await process_frame
	_check(
		bool(beta_terminal.get("destroyed", false))
		and bool(gamma_terminal.get("destroyed", false))
		and bool(picket_terminal.get("destroyed", false))
		and content.get_snapshot().host.activity.state_id == &"completed",
		"public combat and physics APIs reach completed state"
	)
	await _capture(
		viewport, status, &"completed", "[=] COMPLETE // RESET REQUIRED"
	)
	_check(
		not board.interact(actor)
		and content.get_generation() == generation
		and content.get_snapshot().host.activity.state_id == &"completed",
		"completed capture retains direct interaction reset-required semantics"
	)

	var reset := content.reset(generation)
	await process_frame
	var failed_started: bool = board.interact(actor)
	var failed_generation := content.get_generation()
	var failed := content.fail(&"visual_test_failure", failed_generation)
	await process_frame
	_check(
		bool(reset.get("accepted", false))
		and failed_started
		and bool(failed.get("accepted", false)),
		"public reset, start, and fail APIs reach failed state"
	)
	await _capture(
		viewport, status, &"failed", "[X] FAILED // RESET REQUIRED"
	)
	_check(
		not board.interact(actor)
		and content.get_generation() == failed_generation
		and content.get_snapshot().host.activity.state_id == &"failed",
		"failed capture retains direct interaction reset-required semantics"
	)
	var final_image := viewport.get_texture().get_image()
	var final_save_error := final_image.save_png(OUTPUT_PATH) if final_image != null and not final_image.is_empty() \
		else ERR_CANT_CREATE
	_check(final_save_error == OK, "all-state review retains the final failed-state frame")

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


func _capture(
		viewport: SubViewport,
		status: Label3D,
		capture_id: StringName,
		expected_text: String
	) -> void:
	await process_frame
	var image := viewport.get_texture().get_image()
	var capture_path := str(STATE_CAPTURE_PATHS[capture_id])
	var save_error := image.save_png(capture_path) if image != null and not image.is_empty() \
		else ERR_CANT_CREATE
	_check(
		status.text == expected_text
		and save_error == OK and image.get_width() == 960 and image.get_height() == 540,
		"%s public state has truthful text/shape status at gameplay distance" % capture_id
	)


func _destroy(
		authority: LiveCombatAuthority,
		attacker: Node3D,
		target: Node3D,
		maximum_shots: int = 4
	) -> Dictionary:
	var result: Dictionary = {}
	for _shot in maximum_shots:
		await physics_frame
		var aim_position := target.global_position
		var keel := target.get_node_or_null(^"KeelCollision") as CollisionShape3D
		if keel != null:
			aim_position = keel.global_position
		attacker.global_position = aim_position + Vector3(0.0, 0.0, 18.0)
		result = authority.submit_hitscan(
			attacker,
			TEST_WEAPON,
			attacker.global_position,
			(aim_position - attacker.global_position).normalized()
		)
		await process_frame
		if bool(result.get("destroyed", false)):
			break
	return result.duplicate(true)
