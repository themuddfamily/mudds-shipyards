extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []
var _reward_requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "HeavyBreachProductionRoot"
	root.add_child(host)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var activity_director := ActivityDirector.new()
	activity_director.name = "ActivityDirector"
	host.add_child(activity_director)
	var director := EncounterScenarioDirector.new()
	director.name = "EncounterScenarios"
	director.encounter_host_path = NodePath("..")
	director.hud_path = NodePath("../MissingHud")
	director.scenario_time_limit = 60.0
	director.disengage_radius = 2000.0
	host.add_child(director)
	var coordinator := WingCoordinator.new()
	coordinator.name = "WingCoordinator"
	director.add_child(coordinator)
	var target := Node3D.new()
	target.name = "HeavyBreachCaller"
	host.add_child(target)
	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	picket.name = "StandoffPicket"
	picket.escort_enabled = false
	_wire(picket)
	host.add_child(picket)
	var screen := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	screen.name = "WingSkirmisherLead"
	screen.source_id = 2103
	_wire(screen)
	host.add_child(screen)
	var second_screen := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	second_screen.name = "WingSkirmisherWing"
	second_screen.source_id = 2104
	_wire(second_screen)
	host.add_child(second_screen)
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	host.add_child(world)
	await process_frame
	await process_frame
	await physics_frame
	# The focused production harness has no audio bank; the encounter's
	# gameplay lifecycle remains the subject of this test.
	picket.set("_siege_lance_audio_binding", null)

	var board: Variant = world.get_heavy_breach_activity_board()
	var objective := world.get_heavy_breach_protected_objective()
	_check(
		board != null
			and objective != null
			and board.name == "HeavyBreachActivityBoard"
			and objective.name == "HeavyBreachProtectedObjective"
			and board.global_position == Vector3(17.0, 1.0, -26.0)
			and objective.global_position == Vector3(24.0, 1.0, -26.0),
		"ShipyardWorld places one physical heavy-breach board and caller-owned protected objective"
	)
	if board == null or objective == null:
		host.queue_free()
		await process_frame
		_finish()
		return
	var board_console := board.get_node(
		^"CollisionBackedConsole/ActivityBoardConsole"
	) as MeshInstance3D
	var board_header := board.get_node(
		^"CollisionBackedConsole/ActivityBoardSilhouette"
	) as MeshInstance3D
	var board_label := board.get_node(^"ActivityLabel") as Label3D
	var interaction_collision := board.get_node(^"InteractionCollision") as CollisionShape3D
	var objective_marker := objective.get_node(^"ProtectedObjectiveMarker") as MeshInstance3D
	var objective_label := objective.get_node(^"ProtectedObjectiveLabel") as Label3D
	var objective_mesh := objective_marker.mesh as CylinderMesh
	_check(
		(board_header.mesh as BoxMesh).size == Vector3(1.25, 1.25, 0.10)
			and is_equal_approx(board_header.rotation.z, PI * 0.25)
			and board_header.material_override == board_console.material_override
			and board_label.text == "HEAVY BREACH\nACTIVITY BOARD"
			and objective_mesh.radial_segments == 6
			and is_equal_approx(objective_mesh.top_radius, 1.35)
			and is_equal_approx(objective_marker.rotation.x, PI * 0.5)
			and objective_label.text == "BREACH\nPROTECTED ASSET",
		"board diamond and protected hex shield remain distinct shape-first approach silhouettes"
	)
	var board_presentation: Dictionary = board.get_snapshot().presentation
	_check(
		(interaction_collision.shape as BoxShape3D).size == Vector3(2.4, 2.2, 1.8)
			and interaction_collision.position == Vector3(0.0, 0.25, 0.45)
			and objective.find_children("*", "CollisionShape3D", true, false).is_empty()
			and board.find_children("*", "Light3D", true, false).is_empty()
			and objective.find_children("*", "Light3D", true, false).is_empty()
			and board.find_children("*", "AnimationPlayer", true, false).is_empty()
			and board_presentation.geometry_nodes == 3
			and board_presentation.custom_materials == 1
			and board_presentation.lights == 0
			and not bool(board_presentation.pulsing)
			and is_equal_approx(float(board_presentation.interaction_radius), 2.8),
		"visual upgrade preserves the exact interaction envelope and zero-light, no-pulse, collision-free objective budget"
	)
	var configured := world.configure_heavy_breach_reward_handoff(
		Callable(self, "_accept_reward_request")
	)
	var board_snapshot: Dictionary = board.get_snapshot()
	_check(
		bool(configured.get("accepted", false))
			and bool(board_snapshot.configured)
			and int(board_snapshot.director_instance_id) == director.get_instance_id()
			and not bool(board_snapshot.authority.combat)
			and not bool(board_snapshot.authority.damage)
			and int(board_snapshot.process_loops) == 0,
		"board binds the external scenario/direct combat seam without taking combat authority"
	)

	var generation := int(board.get_generation())
	target.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var stale: Dictionary = board.get_interaction_snapshot(target, generation + 1)
	target.global_position = Vector3.ZERO
	var distant: Dictionary = board.get_interaction_snapshot(target, generation)
	_check(
		stale.reason == &"stale_generation"
			and distant.reason == &"out_of_range"
			and not board.interact(target, generation),
		"stale and out-of-range board requests reject before director mutation"
	)
	target.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var started: bool = board.interact(target, generation)
	var started_snapshot: Dictionary = board.get_snapshot()
	var receipt := director.get_heavy_breach_receipt(director.get_scenario_generation())
	_check(
		started
			and started_snapshot.director.scenario == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH
			and int(started_snapshot.director.roster.size()) == 2
			and bool(receipt.get("accepted", false))
			and int(receipt.get("protected_objective_instance_id", 0)) == objective.get_instance_id()
			and picket.is_active()
			and screen.is_active()
			and director.get_member_tactic_intent(picket).action
				== EncounterScenarioDirector.TACTIC_BREACH
			and director.get_member_tactic_intent(screen).action
				== EncounterScenarioDirector.TACTIC_SCREEN_GUARD,
		"board admission launches the real Standoff picket and one screening wing member"
	)
	picket.apply_damage(picket.maximum_health, picket.global_position)
	for _frame in 8:
		await physics_frame
		await process_frame
	_check(
		director.is_concluded()
			and director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED
			and _reward_requests.size() == 1
			and int(_reward_requests[0].activity_generation)
			== int(started_snapshot.active_director_generation)
			and int(board.get_reward_handoff_snapshot().highest_reward_generation)
			== int(started_snapshot.active_director_generation),
		"picket destruction clears the production contract and submits exactly one reward request"
	)
	var completed_generation := generation
	var reset: Dictionary = board.abort_and_reset(target, generation)
	var next_generation := int(reset.get("generation", 0))
	_check(
		bool(reset.get("accepted", false))
			and next_generation > completed_generation
			and not board.interact(target, completed_generation)
			and _reward_requests.size() == 1,
		"reset advances the board generation and fences stale retries without duplicating reward"
	)
	target.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var active_again: bool = board.interact(target, next_generation)
	var active_director_generation := director.get_scenario_generation()
	_check(active_again and director.is_running(), "a fresh board generation admits a new breach")
	var board_id: int = board.get_instance_id()
	host.remove_child(world)
	await process_frame
	_check(
		director.is_concluded()
			and director.get_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN
			and director.get_roster().is_empty()
			and _reward_requests.size() == 1,
		"world detach withdraws the live breach roster without producing a reward"
	)
	host.add_child(world)
	await process_frame
	await process_frame
	await physics_frame
	var reentered_board: Variant = world.get_heavy_breach_activity_board()
	_check(
		is_instance_valid(reentered_board)
			and reentered_board.get_instance_id() == board_id
			and int(reentered_board.get_generation()) > next_generation
			and int(reentered_board.get_snapshot().active_director_generation) == 0
			and reentered_board.get_snapshot().director.state
			== EncounterScenarioDirector.STATE_CONCLUDED,
		"world re-entry preserves the board identity while clearing its active contract"
	)
	host.queue_free()
	for _frame in 8:
		await process_frame
	_finish()


func _wire(craft: Node) -> void:
	craft.set("combat_authority_path", NodePath("../CombatAuthority"))
	craft.set("pulse_presentation_path", NodePath("../MissingPulse"))
	craft.set("combat_audio_path", NodePath("../MissingAudio"))
	craft.set("hud_path", NodePath("../MissingHud"))
	craft.set("encounter_host_path", NodePath(".."))
	if craft is ResolverBackedOpponent:
		craft.set("scenario_director_path", NodePath("../EncounterScenarios"))


func _accept_reward_request(request: Dictionary) -> Dictionary:
	_reward_requests.append(request.duplicate(true))
	return {"accepted": true, "count": _reward_requests.size()}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("HEAVY_BREACH_ACTIVITY_BOARD_PRODUCTION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("HEAVY_BREACH_ACTIVITY_BOARD_PRODUCTION_TEST_FAILED: ", "; ".join(_failures))
	quit(1)
