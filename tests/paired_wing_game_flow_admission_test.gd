extends SceneTree

## Focused actual-Main admission check. Staged setup restores the third board
## offer from the existing terminal record, places the avatar at the real board
## and Arrow, and later changes phase to exercise withdrawal. Ordinary E/input
## and actual berth movement own admission/boarding/departure. This does not
## prove player-weapon kills, safe home return, or native hardware behavior.
const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Filesystem := preload("res://scripts/persistence/user_data_filesystem.gd")
const STORE_PATH := "memory://paired-wing-admission.json"
const FRAME_BUDGET := 240

class MemoryFilesystem extends Filesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
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

var _failures: Array[String] = []
var _assertions := 0

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	_check(store.load().accepted and store.commit({
		"heavy_breach_session": {"schema_version": NearbySectorActivityPersistenceBinding.SCHEMA_VERSION,
			"payload_kind": HeavyBreachActivityBoard.SESSION_KIND,
			"slot_id": HeavyBreachActivityBoard.SESSION_SLOT,
			"session": {"component_id": String(HeavyBreachActivityBoard.COMPONENT_ID),
				"generation_floor": 0, "offered_index": 2, "completion": {}}}
	}, 0, "stage-third-offer").accepted, "staged existing terminal record restores only the third offer")
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(store), "actual Main uses an isolated memory store")
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.04
	game.start_shift()
	await process_frame
	var board := (game.world as ShipyardWorld).get_heavy_breach_activity_board() as HeavyBreachActivityBoard
	var player := game.player as PlayerController
	var hud := game.hud as GameHUD
	var arrow := game.get_node(^"ArrowReconShip") as HeroShip
	var director := game.get_node(^"EncounterScenarios") as EncounterScenarioDirector
	player.teleport_to(Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), board.global_position + Vector3(0.0, 0.0, 2.0)))
	_check(await _wait_until(func() -> bool: return game.station_interaction_candidate == board), "ordinary station sensor selects the real deck board")
	_check(board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_PAIRED_WING
		and "NO CREDIT REWARD" in board.get_interaction_prompt(), "third offer names Wing and discloses no credit")
	await _press_action(&"interact")
	var stale_sortie := int(board.get_snapshot().sortie_generation)
	_check(board.is_sortie_armed() and not director.is_running()
		and "CANCEL PAIRED WING" in board.get_interaction_prompt()
		and "PAIRED WING" in str(hud.get_activity_objective_report().get("text", "")),
		"ordinary E arms Wing on foot with accurate HUD and no opponents")
	await _press_action(&"interact")
	_check(not board.is_sortie_armed() and board.launch_armed_sortie(arrow, stale_sortie).reason == &"stale_sortie_generation",
		"ordinary E cancels and invalidates the prior admission")
	# An actual local host session exercises the production refusal boundary.
	var port_probe := PacketPeerUDP.new()
	_check(port_probe.bind(0, "127.0.0.1") == OK, "reserve a free local host port")
	var local_port := port_probe.get_local_port()
	port_probe.close()
	game.host_network_session(local_port, 1)
	_check(game.get_network_session().is_session_active() and not game.is_paired_wing_solo_available(), "actual host session closes Wing solo admission")
	await _press_action(&"interact")
	_check(not board.is_sortie_armed() and board.get_last_result().reason == &"paired_wing_solo_only"
		and not director.begin_board_paired_wing(arrow)
		and not director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, arrow),
		"host sessions refuse both board arm and new Wing scenario entry")
	game.shutdown_network_session(&"wing-admission-test")
	await process_frame
	_check(game.is_paired_wing_solo_available(), "shutdown restores solo availability")
	await _press_action(&"interact")
	_check(board.is_sortie_armed(), "the same offer can be armed again in solo")
	player.teleport_to(Transform3D(Basis.IDENTITY, arrow.get_boarding_position() + Vector3(0.0, 0.05, 0.0)))
	_check(await _wait_until(func() -> bool: return game.boarding_candidate == arrow), "actual Arrow boarding sensor selects the craft")
	await _press_action(&"interact")
	_check(await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES), "ordinary E completes Arrow seat handoff")
	_check(not director.is_running() and not game.call(&"_try_launch_armed_heavy_breach")
		and not director.begin_board_paired_wing(arrow), "berth and ordinary phase gates prevent early Wing dispatch")
	Input.action_press(&"move_forward")
	var launched := await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.FREE_FLIGHT and director.is_running())
	Input.action_release(&"move_forward")
	_check(launched and director.is_board_sortie_running()
		and director.get_active_scenario() == EncounterScenarioDirector.SCENARIO_PAIRED_WING
		and bool(game.get("_sortie_departed_berth"))
		and game.combat_authority.get_source_id(arrow) > 0, "real berth movement admits Wing only after armed authorized departure")
	var roster := director.get_roster()
	_check(roster.size() == 2 and roster.has(game.get_node(^"WingSkirmisherLead"))
		and roster.has(game.get_node(^"WingSkirmisherWing")), "actual Main dispatches its two existing Wing members")
	var suppressors := 0
	var flankers := 0
	for member in roster:
		var intent := director.get_member_tactic_intent(member)
		_check(game.combat_authority.get_source_id(member) > 0, "live Wing member has real combat registration")
		if intent.action == EncounterScenarioDirector.TACTIC_SUPPRESS and intent.fire_authorized:
			suppressors += 1
		if intent.action == EncounterScenarioDirector.TACTIC_FLANK_UNDER_COVER and not intent.fire_authorized:
			flankers += 1
	_check(suppressors == 1 and flankers == 1, "existing suppression opening assigns one firing anchor and one covered flanker")
	_check("NO CREDIT REWARD" in str(hud.get_activity_objective_report().get("text", ""))
		and "PAIRED WING" in str(hud.get("_objective_kicker").text), "running primary and activity HUD retain accurate Wing identity and no-credit disclosure")
	# Staged phase boundary verifies immediate dispatch revocation and cleanup;
	# no damage injection, kill claim or home-route completion is used here.
	game.phase = GameFlow.Phase.RETURN_TO_YARD
	for member in roster:
		_check(not director.is_fire_authorized(member), "leaving the authorized phase revokes fire synchronously")
	_check(await _wait_until(func() -> bool: return director.is_concluded()), "the ordinary director phase observer withdraws Wing")
	_check(director.get_outcome() == EncounterScenarioDirector.OUTCOME_WITHDRAWN
		and director.get_roster().is_empty() and not bool(game.get("_heavy_breach_objective_posted"))
		and board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH,
		"terminal cleanup releases objective and rotates back to Heavy Breach")
	for member in roster:
		_check(not bool(member.call(&"is_active")) and game.combat_authority.get_source_id(member) == 0,
			"withdrawal removes member activity and combat registration")
	_check(int(game.get_activity_reward_report().authority.record.total_receipts) == 0
		and int(board.get_reward_handoff_snapshot().pending_reward_generation) == 0,
		"Wing withdrawal creates neither credit receipt nor saved debt")
	board.call(&"_on_scenario_concluded", EncounterScenarioDirector.SCENARIO_PAIRED_WING, EncounterScenarioDirector.OUTCOME_CLEARED)
	_check(int(game.get_activity_reward_report().authority.record.total_receipts) == 0
		and board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH,
		"stale terminal replay cannot award credit or rotate again")
	Input.action_release(&"interact")
	Input.action_release(&"move_forward")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_paused(false)
	game.queue_free()
	for _frame in 3:
		await process_frame
	if _failures.is_empty():
		print("PAIRED_WING_GAME_FLOW_ADMISSION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		quit(1)

func _wait_until(predicate: Callable) -> bool:
	for _frame in FRAME_BUDGET:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())

func _press_action(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)
