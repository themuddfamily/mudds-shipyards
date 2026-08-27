extends SceneTree

const BOARD_SCRIPT := preload("res://scripts/activities/station_defense_activity_board.gd")
const CONTENT_SCENE := preload("res://scenes/activities/station_defense_encounter.tscn")
const PHYSICS_LAYERS := preload("res://scripts/core/physics_layers.gd")
const TEST_WEAPON: StringName = &"board_readability_cannon"
const TEST_SOURCE_ID := 9901

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var authority := LiveCombatAuthority.new()
	fixture.add_child(authority)
	var director := ActivityDirector.new()
	fixture.add_child(director)
	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	fixture.add_child(content)
	var board := BOARD_SCRIPT.new() as Area3D
	fixture.add_child(board)
	var actor := Node3D.new()
	fixture.add_child(actor)
	await process_frame
	await physics_frame
	var configured: Dictionary = board.configure_external_owners(content, authority, director)
	await process_frame
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)

	var console_body := board.get_node_or_null(^"CollisionBackedConsole") as StaticBody3D
	var console_collision := (
		console_body.get_node_or_null(^"Collision") as CollisionShape3D
		if console_body != null else null
	)
	var interaction_collision := board.get_node_or_null(^"InteractionCollision") as CollisionShape3D
	var identity_label := board.get_node_or_null(^"ActivityLabel") as Label3D
	var status_label := board.get_node_or_null(^"StatusLabel") as Label3D
	var board_snapshot: Dictionary = board.get_snapshot()
	_check(
		bool(configured.get("accepted", false))
		and content.is_content_ready()
		and content.snapshot_changed.is_connected(Callable(board, "_on_content_snapshot_changed"))
		and int(board_snapshot.content_instance_id) == content.get_instance_id()
		and int(board_snapshot.combat_authority_instance_id) == authority.get_instance_id()
		and int(board_snapshot.activity_director_instance_id) == director.get_instance_id()
		and not bool(board_snapshot.combat_authority)
		and not bool(board_snapshot.activity_authority)
		and not bool(board_snapshot.health_authority)
		and not bool(board_snapshot.reward_authority),
		"board observes the live content signal and exact external owners without acquiring authority"
	)
	_check(
		console_body != null
		and console_collision != null and not console_collision.disabled
		and interaction_collision != null and not interaction_collision.disabled
		and identity_label != null and "STATION DEFENSE" in identity_label.text
		and status_label != null
		and board.collision_layer == PHYSICS_LAYERS.INTERACTABLE_AREA_LAYER,
		"readability display preserves the physical identity and both collision seams"
	)
	_check_status(board, status_label, &"idle", 0, "[ ] READY\nDEPLOY AVAILABLE", "live idle snapshot is deployment-ready without colour")
	var waves := (content.get_snapshot().get("contract", {}) as Dictionary).get("waves", []) as Array
	_check(
		waves.size() == 3
		and (waves[0].get("hostile_handles", []) as Array).size() == 1
		and (waves[1].get("hostile_handles", []) as Array).size() == 2
		and (waves[2].get("hostile_handles", []) as Array).size() == 1,
		"checked-in public contract freezes the exact reachable wave roster at [1, 2, 1]"
	)
	var visual_test_source := FileAccess.get_file_as_string(
		"res://tests/station_defense_activity_board_visual_test.gd"
	)
	var private_callback_injection := "call(" + "\"_on_content_snapshot_changed\""
	var signal_fixture_injection := "snapshot_changed" + ".emit("
	var fabricated_snapshot_helper := "func " + "_snapshot("
	_check(
		not visual_test_source.contains(private_callback_injection)
		and not visual_test_source.contains(signal_fixture_injection)
		and not visual_test_source.contains(fabricated_snapshot_helper),
		"visual coverage rejects private callback and fabricated snapshot injection"
	)

	var attacker := Node3D.new()
	fixture.add_child(attacker)
	var registered := authority.register_source(
		attacker,
		TEST_SOURCE_ID,
		&"station_allies",
		{TEST_WEAPON: {"range": 200.0, "damage": 100.0, "origin_tolerance": 8.0}}
	)
	var actor_started: bool = board.interact(actor)
	var started: Dictionary = board.get_last_result()
	var generation := content.get_generation()
	await process_frame
	_check(
		registered and actor_started and bool(started.get("accepted", false))
		and _status_text(board) == ">> WAVE 1 / 3\nROSTER 0 / 1"
		and status_label.text == _status_text(board),
		"public board interaction presents wave 1 with its single authored hostile"
	)

	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var picket := roster.get_node(^"PerimeterHeavyPicket") as RangeOpponent
	var alpha_terminal := await _destroy(authority, attacker, alpha)
	var inter_wave_activity := content.get_snapshot().host.activity as Dictionary
	_check_status(
		board, status_label, &"active", generation,
		"[~] NEXT WAVE 2 / 3\nDEPLOY IN 0.5 S",
		"settled public wave transition presents the positive-delay wave 2 countdown"
	)
	_check(
		bool(alpha_terminal.get("destroyed", false))
		and int(inter_wave_activity.get("wave_number", 0)) == 2
		and not bool(inter_wave_activity.get("wave_active", true))
		and is_equal_approx(float(inter_wave_activity.get("wave_delay_remaining_seconds", 0.0)), 0.5)
		and int(inter_wave_activity.get("current_wave_hostile_count", 0)) == 2
		and int(inter_wave_activity.get("current_wave_destroyed_count", -1)) == 0,
		"inter-wave board copy comes from the settled public activity snapshot, never a cleared wave-1 fixture"
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
		bool(alpha_terminal.get("destroyed", false))
		and bool(beta_terminal.get("destroyed", false))
		and bool(gamma_terminal.get("destroyed", false))
		and bool(picket_terminal.get("destroyed", false))
		and content.get_snapshot().host.activity.state_id == &"completed",
		"live resolver results reach the authoritative completed state"
	)
	_check_status(
		board, status_label, &"completed", generation,
		"[=] COMPLETE // RESET REQUIRED",
		"completed signal truthfully requires an external reset"
	)
	var completed_interaction: bool = board.interact(actor)
	_check(
		not completed_interaction
		and content.get_generation() == generation
		and content.get_snapshot().host.activity.state_id == &"completed",
		"direct completed-board interaction preserves terminal state and cannot imply repeat"
	)

	var completed_reset: Dictionary = content.reset(generation)
	var idle_generation := int((completed_reset.get("activity", {}) as Dictionary).get("generation", -1))
	await process_frame
	_check_status(board, status_label, &"idle", idle_generation, "[ ] READY\nDEPLOY AVAILABLE", "completion reset clears terminal copy for redeployment")

	var failed_started: bool = board.interact(actor)
	var failed_generation := content.get_generation()
	var failed := content.fail(&"readability_test_failure", failed_generation)
	await process_frame
	_check(
		failed_started and bool(failed.get("accepted", false)),
		"public start and fail APIs reach the authoritative failed terminal"
	)
	_check_status(
		board, status_label, &"failed", failed_generation,
		"[X] FAILED // RESET REQUIRED",
		"failed signal truthfully requires an external reset"
	)
	var failed_interaction: bool = board.interact(actor)
	_check(
		not failed_interaction
		and content.get_generation() == failed_generation
		and content.get_snapshot().host.activity.state_id == &"failed",
		"direct failed-board interaction preserves terminal state and cannot imply recovery"
	)

	board_snapshot = board.get_snapshot()
	_check(
		bool(board.get_presentation_snapshot().steady)
		and int(board_snapshot.process_loops) == 0
		and board.find_children("*", "Timer", true, false).is_empty(),
		"all branches remain steady without timers, flashing, or a process owner"
	)

	fixture.queue_free()
	for _frame in 4:
		await process_frame
	_finish()


func _destroy(authority: LiveCombatAuthority, attacker: Node3D, target: Node3D, maximum_shots: int = 4) -> Dictionary:
	var result: Dictionary = {}
	for _shot in maximum_shots:
		await physics_frame
		var aim_position := target.global_position
		var keel := target.get_node_or_null(^"KeelCollision") as CollisionShape3D
		if keel != null:
			aim_position = keel.global_position
		attacker.global_position = aim_position + Vector3(0.0, 0.0, 18.0)
		result = authority.submit_hitscan(attacker, TEST_WEAPON, attacker.global_position, (aim_position - attacker.global_position).normalized())
		await process_frame
		if bool(result.get("destroyed", false)):
			break
	return result.duplicate(true)


func _check_status(board: Area3D, status_label: Label3D, state_id: StringName, generation: int, expected_text: String, description: String) -> void:
	var presentation: Dictionary = board.get_presentation_snapshot()
	_check(
		StringName(presentation.get("state_id", &"")) == state_id
		and int(presentation.get("generation", -1)) == generation
		and str(presentation.get("text", "")) == expected_text
		and status_label.text == expected_text,
		description
	)


func _status_text(board: Area3D) -> String:
	return str(board.get_presentation_snapshot().get("text", ""))


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DEFENSE_ACTIVITY_BOARD_READABILITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("STATION_DEFENSE_ACTIVITY_BOARD_READABILITY_TEST_FAILED: ", "; ".join(_failures))
	quit(1)
