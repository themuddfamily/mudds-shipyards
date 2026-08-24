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
	await process_frame
	await physics_frame
	var configured: Dictionary = board.configure_external_owners(content, authority, director)
	await process_frame

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
	_check_status(board, status_label, &"idle", 0, "READY\nINTERACT TO DEPLOY", "live idle snapshot is deployment-ready")

	var attacker := Node3D.new()
	fixture.add_child(attacker)
	var registered := authority.register_source(
		attacker,
		TEST_SOURCE_ID,
		&"station_allies",
		{TEST_WEAPON: {"range": 200.0, "damage": 100.0, "origin_tolerance": 8.0}}
	)
	var started: Dictionary = content.start(0)
	var generation := int((started.get("activity", {}) as Dictionary).get("generation", -1))
	await process_frame
	_check(
		registered and bool(started.get("accepted", false))
		and _status_text(board) == "WAVE 1 / 3\nTHREATS 4"
		and status_label.text == _status_text(board),
		"live start signal presents exact wave position and total remaining threats"
	)

	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var picket := roster.get_node(^"PerimeterHeavyPicket") as RangeOpponent
	var alpha_terminal := await _destroy(authority, attacker, alpha)
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
	_check_status(board, status_label, &"completed", generation, "PERIMETER SECURE\nRECOVERY AVAILABLE", "completed signal presents secure recovery guidance")

	var completed_reset: Dictionary = content.reset(generation)
	var idle_generation := int((completed_reset.get("activity", {}) as Dictionary).get("generation", -1))
	await process_frame
	_check_status(board, status_label, &"idle", idle_generation, "READY\nINTERACT TO DEPLOY", "completion reset clears terminal copy for redeployment")

	var abort_start: Dictionary = content.start(idle_generation)
	var abort_generation := int((abort_start.get("activity", {}) as Dictionary).get("generation", -1))
	var actor := Node3D.new()
	fixture.add_child(actor)
	var actor_ref: WeakRef = weakref(actor)
	actor.queue_free()
	await process_frame
	var aborted: Dictionary = content.abort(abort_generation)
	await process_frame
	_check(actor_ref.get_ref() == null and bool(aborted.get("accepted", false)), "actor loss leaves lifecycle ownership with the authoritative content")
	_check_status(board, status_label, &"aborted", abort_generation, "DEFENSE OFFLINE\nRECOVERY REQUIRED", "aborted signal presents recovery-required guidance")
	var aborted_reset: Dictionary = content.reset(abort_generation)
	var post_abort_generation := int((aborted_reset.get("activity", {}) as Dictionary).get("generation", -1))
	await process_frame
	_check_status(board, status_label, &"idle", post_abort_generation, "READY\nINTERACT TO DEPLOY", "reset after actor loss clears aborted presentation")

	var timeout_start: Dictionary = content.start(post_abort_generation)
	var timeout_generation := int((timeout_start.get("activity", {}) as Dictionary).get("generation", -1))
	var timed_out: Dictionary = content.advance_physics(16.0, timeout_generation)
	await process_frame
	_check(
		bool(timed_out.get("accepted", false))
		and timed_out.get("reason") == &"timed_out"
		and content.get_snapshot().host.activity.state_id == &"timed_out",
		"caller-owned physics produces the live authoritative timeout terminal"
	)
	_check_status(board, status_label, &"timed_out", timeout_generation, "DEFENSE OFFLINE\nRECOVERY REQUIRED", "timed-out signal presents recovery-required guidance")

	var history_before_stale := (board.get_session_persistence_snapshot().history as Dictionary).duplicate(true)
	content.snapshot_changed.emit(_snapshot(&"completed", timeout_generation - 1, 3, 3, 0))
	_check(
		StringName(board.get_presentation_snapshot().state_id) == &"timed_out"
		and board.get_session_persistence_snapshot().history == history_before_stale,
		"older signalled generation cannot replace presentation or terminal history"
	)

	var timeout_reset: Dictionary = content.reset(timeout_generation)
	var post_timeout_generation := int((timeout_reset.get("activity", {}) as Dictionary).get("generation", -1))
	await process_frame
	content.snapshot_changed.emit(_snapshot(&"unmapped_terminal", post_timeout_generation))
	_check_status(board, status_label, &"unmapped_terminal", post_timeout_generation, "STATUS UNAVAILABLE", "unknown current state has a steady explicit fallback")
	content.snapshot_changed.emit(content.get_snapshot())
	_check_status(board, status_label, &"idle", post_timeout_generation, "READY\nINTERACT TO DEPLOY", "next authoritative snapshot clears unknown fallback copy")

	var detach_start: Dictionary = content.start(post_timeout_generation)
	var detach_generation := int((detach_start.get("activity", {}) as Dictionary).get("generation", -1))
	var active_before_detach: Dictionary = board.get_presentation_snapshot()
	fixture.remove_child(content)
	await process_frame
	_check(
		board.get_presentation_snapshot() == active_before_detach
		and not bool(content.get_snapshot().host.activity.attached),
		"content detach leaves one steady retained wave readout without a local clock"
	)
	fixture.add_child(content)
	await process_frame
	await physics_frame
	content.abort(detach_generation)
	var detach_reset: Dictionary = content.reset(detach_generation)
	var final_generation := int((detach_reset.get("activity", {}) as Dictionary).get("generation", -1))
	await process_frame
	_check_status(board, status_label, &"idle", final_generation, "READY\nINTERACT TO DEPLOY", "reattach and reset clear the retained detached generation")

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


func _snapshot(state_id: StringName, generation: int, wave_number: int = 0, wave_count: int = 3, remaining: int = 4) -> Dictionary:
	return {
		"host": {
			"activity": {
				"state_id": state_id,
				"generation": generation,
				"wave_number": wave_number,
				"wave_count": wave_count,
				"remaining_hostile_count": remaining,
			}
		}
	}


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
