extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const TORPEDO_BOAT_SCENE := preload("res://scenes/ships/torpedo_boat_opponent.tscn")

class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	var reject_writes := false
	var reject_reads := false
	var reject_paid_ack_once := false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_directory(path: String) -> Error:
		if reject_paid_ack_once and files.has(path):
			var document: Dictionary = JSON.parse_string((files[path] as PackedByteArray).get_string_from_utf8())
			var payload: Dictionary = document.get("payload", {})
			if payload.has(HeavyBreachActivityBoard.SESSION_SLOT) and payload.heavy_breach_session.session.completion.reward_granted:
				reject_paid_ack_once = false
				return ERR_CANT_CREATE
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if reject_reads:
			return {"error": ERR_CANT_OPEN, "bytes": PackedByteArray()}
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_writes:
			return ERR_CANT_CREATE
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _recovery_filesystem: MemoryFilesystem
var _recovery_store: UserDataStore
var _recovery_authority: GameFlowRewardAuthority

var _assertions := 0
var _failures: Array[String] = []
var _reward_requests: Array[Dictionary] = []
var _rejected_reward_requests: Array[Dictionary] = []
var _reject_next_reward := false


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
	# 7680a0cd0 made the board rotate to Torpedo Run after a concluded sortie,
	# so the production harness carries the torpedo boat Main places.
	var torpedo_boat := TORPEDO_BOAT_SCENE.instantiate() as TorpedoBoatOpponent
	torpedo_boat.name = "TorpedoBoat"
	_wire(torpedo_boat)
	host.add_child(torpedo_boat)
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
			and board.global_position == Vector3(8.0, 1.0, -26.0)
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
	var board_pedestal := board.get_node(
		^"CollisionBackedConsole/Pedestal"
	) as MeshInstance3D
	var pedestal_collision := board.get_node(
		^"CollisionBackedConsole/Collision"
	) as CollisionShape3D
	var board_header := board.get_node(
		^"CollisionBackedConsole/ActivityBoardSilhouette"
	) as MeshInstance3D
	var board_label := board.get_node(^"ActivityLabel") as Label3D
	var interaction_collision := board.get_node(^"InteractionCollision") as CollisionShape3D
	var objective_marker := objective.get_node(^"ProtectedObjectiveMarker") as MeshInstance3D
	var objective_label := objective.get_node(^"ProtectedObjectiveLabel") as Label3D
	var objective_mesh := objective_marker.mesh as CylinderMesh
	_check(
		_has_housing_chamfer(board_pedestal.mesh, Vector3(1.4, 1.0, 2.2), 0.08)
			and _has_housing_chamfer(board_console.mesh, Vector3(0.75, 1.35, 1.8), 0.08)
			and board_pedestal.position == Vector3(0.0, -0.5, 0.0)
			and board_console.position == Vector3(0.0, 0.62, 0.0)
			and board_pedestal.material_override == null
			and (pedestal_collision.shape as BoxShape3D).size == Vector3(1.4, 1.0, 2.2)
			and pedestal_collision.position == board_pedestal.position
			and board.find_children("*", "CollisionShape3D", true, false).size() == 2,
		"board pedestal and console have fixed-width chamfers with exact bounds, materials, and collision placement"
	)
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
	_recovery_filesystem = MemoryFilesystem.new()
	_recovery_store = UserDataStore.new("memory://heavy-breach-recovery.json", _recovery_filesystem)
	_check(_recovery_store.load().accepted and _recovery_store.commit({"settings": {"ui_scale": 1.2}}, 0, "seed-settings").accepted,
		"terminal recovery uses the real atomic store with unrelated settings")
	_recovery_authority = GameFlowRewardAuthority.new()
	_check(_recovery_authority.configure(_recovery_store).accepted and board.configure_session_persistence(_recovery_store)
		and board.load_session().accepted, "production board binds terminal persistence without inventing a legacy completion")
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
	var picket_dispatch := picket.get_audit_report().lifecycle as Dictionary
	_check(
		started
			and started_snapshot.director.scenario == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH
			and int(started_snapshot.director.roster.size()) == 2
			and bool(receipt.get("accepted", false))
			and int(receipt.get("protected_objective_instance_id", 0)) == objective.get_instance_id()
			and picket.is_active()
			and picket.escort_enabled
			and bool(picket_dispatch.get("escort_fire_authorized", false))
			and int(picket_dispatch.get("dispatch_owner_instance_id", 0))
				== director.get_instance_id()
			and int(picket_dispatch.get("dispatch_owner_generation", 0))
				== director.get_scenario_generation()
			and screen.is_active()
			and director.get_member_tactic_intent(picket).action
				== EncounterScenarioDirector.TACTIC_BREACH
			and director.get_member_tactic_intent(screen).action
				== EncounterScenarioDirector.TACTIC_SCREEN_GUARD,
		"board admission launches the default escort-mode picket with explicit director authority and one screen"
	)
	# The reward authority rejects the first clear, as it does when the save
	# store cannot commit. The earned credit must stay owed, not vanish.
	_reject_next_reward = true
	picket.apply_damage(picket.maximum_health, picket.global_position)
	for _frame in 8:
		await physics_frame
		await process_frame
	var cleared_generation := int(started_snapshot.active_director_generation)
	_check(
		director.is_concluded()
			and director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED
			and _rejected_reward_requests.size() == 1
			and int(_rejected_reward_requests[0].activity_generation) == cleared_generation
			and _reward_requests.is_empty()
			and int(board.get_reward_handoff_snapshot().highest_reward_generation) == 0
			and int(board.get_reward_handoff_snapshot().get("pending_reward_generation", -1))
			== cleared_generation,
		"picket destruction clears the contract and keeps a rejected reward owed for retry"
	)
	_check("INTERACT TO RETRY" in board.get_interaction_prompt()
		and "REWARD SAVE PENDING" in board_label.text,
		"the physical board explains the earned reward save retry")
	var completed_generation := generation
	var reset: Dictionary = board.abort_and_reset(target, generation)
	var next_generation := int(reset.get("generation", 0))
	_check(
		bool(reset.get("accepted", false))
			and next_generation > completed_generation
			and not board.interact(target, completed_generation)
			and _reward_requests.is_empty(),
		"reset advances the board generation and fences stale callers without paying the owed reward"
	)
	await _test_fresh_debt_recovery(host, objective, director, authority, target, cleared_generation)
	target.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var active_again: bool = board.interact(target, next_generation)
	var active_director_generation := director.get_scenario_generation()
	_check(
		active_again
			and director.is_running()
			and director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_TORPEDO_RUN
			and board.get_snapshot().active_scenario == EncounterScenarioDirector.SCENARIO_TORPEDO_RUN,
		"a fresh board generation admits the rotated Torpedo Run contract"
	)
	_check(
		_reward_requests.size() == 1
			and int(_reward_requests[0].activity_generation) == cleared_generation
			and int(board.get_reward_handoff_snapshot().highest_reward_generation)
			== cleared_generation
			and int(board.get_reward_handoff_snapshot().get("pending_reward_generation", -1)) == 0,
		"the next board interaction retries the owed Heavy Breach reward exactly once"
	)
	var board_id: int = board.get_instance_id()
	host.remove_child(world)
	await process_frame
	_check(
		director.is_concluded()
			and director.get_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN
			and director.get_roster().is_empty()
			and _reward_requests.size() == 1,
		"world detach withdraws the live board sortie roster without producing a reward"
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
	# A real later clear uses a new reward epoch without restoring director state.
	target.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var later_started: bool = board.interact(target, board.get_generation())
	_recovery_filesystem.reject_paid_ack_once = true
	picket.apply_damage(picket.maximum_health, picket.global_position)
	for _frame in 8:
		await physics_frame
		await process_frame
	_check(later_started and _reward_requests.size() == 2 and int(_reward_requests.back().activity_generation) > cleared_generation
		and _recovery_store.get_snapshot().heavy_breach_session.session.completion.reward_granted,
		"a later genuine breach pays once despite a postpublication acknowledgement failure")
	var torpedo_started: bool = board.interact(target, board.get_generation())
	torpedo_boat.apply_damage(torpedo_boat.maximum_health, torpedo_boat.global_position)
	for _frame in 8:
		await physics_frame
		await process_frame
	_check(torpedo_started and _reward_requests.size() == 3 and _reward_requests.back().activity_id == HeavyBreachActivityBoard.TORPEDO_RUN_ACTIVITY_ID
		and _recovery_store.get_snapshot().heavy_breach_session.session.completion.reward_granted,
		"a genuinely cleared rotated Torpedo Run shares terminal recovery with its distinct reward identity")
	await _test_legacy_paid_floor(host)
	_test_refused_documents(host)
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


func _has_housing_chamfer(mesh: Mesh, size: Vector3, width: float) -> bool:
	if not mesh is ArrayMesh or mesh.get_surface_count() != 1:
		return false
	var half := size * 0.5
	if not mesh.get_aabb().is_equal_approx(AABB(-half, size)):
		return false
	var vertices := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	for vertex in vertices:
		if is_equal_approx(absf(vertex.x), half.x - width) \
				and is_equal_approx(absf(vertex.y), half.y) \
				and is_equal_approx(absf(vertex.z), half.z - width):
			return true
	return false


func _accept_reward_request(request: Dictionary) -> Dictionary:
	if _reject_next_reward:
		_reject_next_reward = false
		_recovery_filesystem.reject_writes = true
		var rejected := _recovery_authority.commit(request)
		_recovery_filesystem.reject_writes = false
		_rejected_reward_requests.append(request.duplicate(true))
		return rejected
	var committed := _recovery_authority.commit(request)
	if committed.accepted:
		_reward_requests.append(request.duplicate(true))
	elif committed.get("store_result", {}).get("published", false):
		_recovery_store.load()
		_reward_requests.append(request.duplicate(true))
	return committed


func _test_legacy_paid_floor(host: Node3D) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = _recovery_filesystem.files.duplicate(true)
	var store := UserDataStore.new("memory://heavy-breach-recovery.json", filesystem)
	store.load()
	var legacy := store.get_snapshot()
	var paid_receipt: Dictionary = legacy.game_flow_reward_store.last_receipt.duplicate(true)
	legacy.erase(HeavyBreachActivityBoard.SESSION_SLOT)
	_check(store.commit(legacy, store.get_generation(), "legacy-paid-without-terminal-slot").accepted,
		"legacy fixture retains the genuinely paid receipt without a terminal session")
	var owner := GameFlowRewardAuthority.new()
	_check(owner.configure(store).accepted, "the existing authority strictly validates the legacy paid receipt")
	var floor_generation := owner.get_heavy_breach_paid_generation_floor()
	var fresh := Node3D.new()
	host.add_child(fresh)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	fresh.add_child(authority)
	var activity := ActivityDirector.new()
	activity.name = "ActivityDirector"
	fresh.add_child(activity)
	var director := EncounterScenarioDirector.new()
	director.name = "EncounterScenarios"
	director.encounter_host_path = NodePath("..")
	director.hud_path = NodePath("../MissingHud")
	fresh.add_child(director)
	var coordinator := WingCoordinator.new()
	coordinator.name = "WingCoordinator"
	director.add_child(coordinator)
	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	picket.name = "StandoffPicket"
	_wire(picket)
	fresh.add_child(picket)
	picket.set("_siege_lance_audio_binding", null)
	var screen := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	screen.name = "WingSkirmisherLead"
	_wire(screen)
	fresh.add_child(screen)
	var objective := Node3D.new()
	objective.name = "HeavyBreachProtectedObjective"
	fresh.add_child(objective)
	var actor := Node3D.new()
	fresh.add_child(actor)
	var board := HeavyBreachActivityBoard.new()
	fresh.add_child(board)
	board.configure_external_owners(objective, director, authority)
	board.configure_reward_handoff(owner.commit)
	board.configure_session_persistence(store, floor_generation)
	_check(board.load_session().accepted and int(board.get_reward_handoff_snapshot().pending_reward_generation) == 0
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE
		and store.get_snapshot().game_flow_reward_store.last_receipt == paid_receipt,
		"safe legacy adoption preserves the receipt and restores only its known paid generation floor")
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	_check(board.interact(actor, board.get_generation()) and director.get_scenario_generation() <= floor_generation,
		"a genuinely new director sortie may restart below the known paid reward epoch")
	picket.apply_damage(picket.maximum_health, picket.global_position)
	for _frame in 8:
		await physics_frame
		await process_frame
	_check(director.get_outcome() == EncounterScenarioDirector.OUTCOME_CLEARED
		and int(store.get_snapshot().game_flow_reward_store.last_receipt.activity_generation) > floor_generation
		and int(store.get_snapshot().game_flow_reward_store.total_receipts) == int(legacy.game_flow_reward_store.total_receipts) + 1,
		"a genuinely cleared fresh sortie pays a distinct later generation after a legacy paid receipt")
	var invalid_payload := store.get_snapshot()
	invalid_payload.game_flow_reward_store.last_receipt.activity_generation = 1.5
	_check(store.commit(invalid_payload, store.get_generation(), "invalid-legacy-receipt").accepted,
		"the store can retain an invalid activity receipt without granting its generation")
	var invalid_owner := GameFlowRewardAuthority.new()
	_check(not invalid_owner.configure(store).accepted and invalid_owner.get_heavy_breach_paid_generation_floor() == 0,
		"a corrupt legacy receipt cannot supply a paid generation floor")
	fresh.queue_free()
	await process_frame


func _test_backup_rollback_refusal(host: Node3D) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = _recovery_filesystem.files.duplicate(true)
	filesystem.files["memory://heavy-breach-recovery.json"] = "corrupt newer paid primary".to_utf8_buffer()
	var store := UserDataStore.new("memory://heavy-breach-recovery.json", filesystem)
	_check(store.load().accepted and store.get_loaded_source() == &"backup"
		and not store.get_snapshot().heavy_breach_session.session.completion.reward_granted,
		"corrupting a genuinely paid primary exposes its older genuine unpaid backup")
	var retained := filesystem.files.duplicate(true)
	var owner := GameFlowRewardAuthority.new()
	owner.configure(store)
	var refused := owner.commit(_reward_requests[0])
	var board := HeavyBreachActivityBoard.new()
	host.add_child(board)
	board.configure_session_persistence(store)
	_check(not refused.accepted and refused.reason == &"reward_store_recovery_required"
		and owner.get_heavy_breach_paid_generation_floor() == 0
		and not board.load_session().accepted
		and int(board.get_reward_handoff_snapshot().pending_reward_generation) == 0
		and filesystem.files == retained,
		"backup-selected unpaid debt cannot restore, pay or overwrite a possibly newer paid receipt")
	_check("SAVE RECOVERY REQUIRED" in board.get_interaction_prompt()
		and "SAVE RECOVERY REQUIRED" in (board.get_node(^"ActivityLabel") as Label3D).text,
		"the physical board explains required save recovery instead of offering automatic payment")
	board.queue_free()


func _test_refused_documents(host: Node3D) -> void:
	var filesystem := MemoryFilesystem.new()
	filesystem.files = _recovery_filesystem.files.duplicate(true)
	var store := UserDataStore.new("memory://heavy-breach-recovery.json", filesystem)
	store.load()
	var payload := store.get_snapshot()
	payload.heavy_breach_session.schema_version = 2
	_check(store.commit(payload, store.get_generation(), "newer-heavy-breach-slot").accepted, "a newer terminal slot can exist in a readable current store")
	var before := filesystem.files.duplicate(true)
	var board := HeavyBreachActivityBoard.new()
	host.add_child(board)
	board.configure_session_persistence(store)
	_check(not board.load_session().accepted and filesystem.files == before
		and int(board.get_reward_handoff_snapshot().pending_reward_generation) == 0,
		"a newer terminal slot is retained without invented unpaid entitlement")
	board.queue_free()
	filesystem.reject_reads = true
	var unreadable := UserDataStore.new("memory://heavy-breach-recovery.json", filesystem)
	var blocked := HeavyBreachActivityBoard.new()
	host.add_child(blocked)
	blocked.configure_session_persistence(unreadable)
	_check(not blocked.load_session().accepted and filesystem.files == before,
		"read failure refuses recovery without replacing either authority document")
	blocked.queue_free()


func _fresh_recovery_board(host: Node3D, objective: Node3D, director: EncounterScenarioDirector, authority: LiveCombatAuthority) -> HeavyBreachActivityBoard:
	_recovery_store = UserDataStore.new("memory://heavy-breach-recovery.json", _recovery_filesystem)
	_check(_recovery_store.load().accepted, "a fresh store reads the retained terminal document")
	_recovery_authority = GameFlowRewardAuthority.new()
	_check(_recovery_authority.configure(_recovery_store).accepted, "a fresh reward owner reads the existing durable receipt ledger")
	var board := HeavyBreachActivityBoard.new()
	host.add_child(board)
	board.configure_external_owners(objective, director, authority)
	board.configure_reward_handoff(Callable(self, "_accept_reward_request"))
	board.configure_session_persistence(_recovery_store)
	_check(board.load_session().accepted, "a fresh board loads only its terminal reward debt and floor")
	return board


func _test_fresh_debt_recovery(host: Node3D, objective: Node3D, director: EncounterScenarioDirector, authority: LiveCombatAuthority, actor: Node3D, generation: int) -> void:
	var original_store := _recovery_store
	var original_authority := _recovery_authority
	var staged: Dictionary = _recovery_store.get_snapshot().heavy_breach_session.session
	var wire_record: Dictionary = _recovery_store.get_snapshot().heavy_breach_session.duplicate(true)
	_check(wire_record.session.offered_index is float
		and HeavyBreachActivityBoard.validate_session_record(wire_record),
		"the genuine persisted JSON-number offer validates before fresh debt recovery")
	for index: int in [0, 1]:
		wire_record.session.offered_index = float(index)
		_check(HeavyBreachActivityBoard.validate_session_record(wire_record),
			"the supported JSON offer %d retains the exact terminal contract" % index)
	for index: float in [0.5, 1.5, -1.0, 2.0]:
		wire_record.session.offered_index = index
		_check(not HeavyBreachActivityBoard.validate_session_record(wire_record),
			"fractional or unsupported JSON offer %s cannot restore a terminal contract" % index)
	_check(staged.component_id is String and staged.completion.activity_id is String
		and staged.completion.state_id is String and staged.completion.outcome is String
		and staged.completion.scenario is String and staged.completion.protected_objective is String,
		"the genuinely earned terminal persists JSON string identities through the unchanged store validator")
	_check(not staged.completion.reward_granted and int(staged.completion.generation) == generation
		and not _recovery_store.get_snapshot().has(String(GameFlowRewardAuthority.SLOT_ID)),
		"earned terminal write succeeds while actual rejected payment creates no receipt")
	var fresh := _fresh_recovery_board(host, objective, director, authority)
	actor.global_position = fresh.global_position + Vector3(1.5, 0.0, 0.0)
	_check(int(fresh.get_snapshot().active_director_generation) == 0 and not director.is_running()
		and int(fresh.get_reward_handoff_snapshot().pending_reward_generation) == generation,
		"fresh debt adoption recreates no encounter or combat grant")
	_check(fresh.arm_sortie(actor, fresh.get_generation()).accepted and _reward_requests.size() == 1
		and _recovery_store.get_snapshot().heavy_breach_session.session.completion.reward_granted
		and _recovery_store.get_snapshot().settings.ui_scale == 1.2,
		"ordinary board admission pays recovered debt with an atomic paid acknowledgement and preserves settings")
	_test_backup_rollback_refusal(host)
	fresh.queue_free()
	await process_frame
	var other := NearbyActivityRewardAdapter.new()
	other.configure(_recovery_authority.commit, GameFlowRewardAuthority.CINDER_ASTEROID_RUN_ACTIVITY_ID, GameFlowRewardAuthority.CINDER_ASTEROID_RUN_REWARD_ID)
	_check(other.consume({"activity_id": GameFlowRewardAuthority.CINDER_ASTEROID_RUN_ACTIVITY_ID, "generation": 1, "state_id": &"completed", "outcome": &"cleared"}, 1).accepted,
		"an unrelated activity can replace last receipt without erasing the paid acknowledgement")
	var second := _fresh_recovery_board(host, objective, director, authority)
	actor.global_position = second.global_position + Vector3(1.5, 0.0, 0.0)
	var before := int(_recovery_authority.get_snapshot().record.total_receipts)
	_check(second.arm_sortie(actor, second.get_generation()).accepted and _reward_requests.size() == 1
		and int(_recovery_authority.get_snapshot().record.total_receipts) == before
		and int(second.get_reward_handoff_snapshot().pending_reward_generation) == 0,
		"second fresh load and ordinary admission cannot duplicate an already paid debt after intervening rewards")
	second.queue_free()
	await process_frame
	_check(not is_instance_valid(fresh) and not is_instance_valid(second),
		"temporary fresh recovery boards retire before restoring the original callback owner")
	# The original live board retains original_store for its later genuine clears.
	# Restore its callback owner after the fresh boards have left the tree.
	_recovery_store = original_store
	_recovery_authority = original_authority



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
