extends SceneTree

const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const ContractScript := preload("res://scripts/world/planetary_save_session_contract.gd")
const AdapterScript := preload("res://scripts/world/planetary_return_persistence_adapter.gd")
const BindingScript := preload(
	"res://scripts/persistence/ember_relay_survey_persistence_binding.gd"
)
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

const STORE_PATH := "memory://ember-active-journey.json"
const SLOT: StringName = &"ember_relay_survey_completion"
const WORLD_ID: StringName = &"ember_moon"
const FRAME_ID: StringName = &"nearby_sector"


class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
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
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var filesystem := MemoryFilesystem.new()
	var first_store = StoreScript.new(STORE_PATH, filesystem)
	_check(bool(first_store.load().accepted), "the caller-owned atomic store loads")
	var first_binding = BindingScript.new()
	_check(
		bool(first_binding.configure(first_store, SLOT).accepted),
		"the Ember binding adopts the existing store and slot",
	)

	var source_frame = _frame()
	var source = ContractScript.new(WORLD_ID, source_frame)
	_check(
		bool(source.begin_session(&"ember_expedition_17", 4, 1).accepted),
		"the caller starts one identified Ember expedition",
	)
	var route := _route_identity()
	_check(
		first_binding.save_interrupted_journey(
			source, route, "active-before-detach"
		).reason == &"interrupted_journey_not_detached",
		"a live attachment cannot be persisted as passive recovery",
	)
	var tangent := Vector3(18.0, 6.0, -11.0)
	var body_local: Dictionary = source_frame.surface_tangent_to_body_local(tangent, 1)
	var orbital: Dictionary = source_frame.body_local_to_orbital_position(
		body_local.position as Vector3, 1
	)
	var checkpoint: Dictionary = source.save_surface_checkpoint(
		4, 1, 920, orbital.coordinate as Dictionary, tangent,
		{
			"activity_id": "ember_beacon_survey",
			"journey_phase_id": "surface_relay_return_leg",
			"route_checkpoint_index": 1,
		}
	)
	_check(
		bool(checkpoint.accepted) and bool(source.detach_session(4, 1).accepted),
		"surface position and route phase are frozen before persistence",
	)
	var saved: Dictionary = first_binding.save_interrupted_journey(
		source, route, "ember-active-journey-0001"
	)
	_check(
		bool(saved.get("accepted", false))
			and saved.binding_reason == &"active_journey_saved"
			and int(first_store.get_generation()) == 1
			and (first_store.get_snapshot().get(String(SLOT), {}) as Dictionary)
				.get("payload_kind", "") == "ember_relay_survey_active_journey",
		"the detached recovery replaces only the established Ember slot atomically",
	)
	_check(
		first_binding.load().reason == &"survey_persistence_active_journey_present",
		"terminal-completion restore cannot misread active recovery as a reward receipt",
	)

	var second_store = StoreScript.new(STORE_PATH, filesystem)
	var second_binding = BindingScript.new()
	second_binding.configure(second_store, SLOT)
	var loaded: Dictionary = second_binding.load_interrupted_journey()
	var recovery := loaded.get("recovery", {}) as Dictionary
	var restored_route := recovery.get("route_identity", {}) as Dictionary
	_check(
		bool(loaded.get("accepted", false))
			and loaded.reason == &"survey_active_journey_loaded"
			and recovery.session_id == &"ember_expedition_17"
			and recovery.phase_id == &"surface"
			and recovery.journey_phase_id == &"surface_relay_return_leg"
			and int(recovery.checkpoint_generation) == 1
			and int(restored_route.get("next_checkpoint_index", -1)) == 1
			and restored_route.next_objective_id == "ember_return_beacon"
			and not bool(recovery.movement_replay_allowed)
			and not bool(recovery.reward_replay_allowed),
		"restart loads the exact expedition, surface phase, and return-leg route without authority",
	)
	_check(
		second_binding.load_interrupted_journey().reason \
			== &"survey_active_journey_already_loaded",
		"one binding exposes an interrupted receipt only once before retirement",
	)

	var receiving = ContractScript.new(WORLD_ID, _frame())
	var reentered: Dictionary = receiving.restore_detached_snapshot(
		recovery.get("detached_session", {}) as Dictionary, 5, 1
	)
	var resumed: Dictionary = receiving.get_snapshot()
	_check(
		bool(reentered.accepted)
			and resumed.state == "active"
			and resumed.session_id == "ember_expedition_17"
			and resumed.checkpoint.phase == "surface"
			and int(resumed.checkpoint.payload.route_checkpoint_index) == 1
			and resumed.checkpoint.payload.journey_phase_id \
				== "surface_relay_return_leg",
		"the caller can re-enter the exact detached contract with its fresh attachment generation",
	)

	var retired: Dictionary = second_binding.retire_interrupted_journey(
		int(loaded.get("store_generation", -1)),
		str(recovery.get("receipt_sha256", "")),
		"ember-active-journey-retire-0001"
	)
	_check(
		bool(retired.get("accepted", false))
			and retired.binding_reason == &"active_journey_retired"
			and int(second_store.get_generation()) == 2,
		"successful caller adoption retires only the exact observed receipt",
	)
	var final_store = StoreScript.new(STORE_PATH, filesystem)
	var final_binding = BindingScript.new()
	final_binding.configure(final_store, SLOT)
	_check(
		final_binding.load_interrupted_journey().reason \
			== &"survey_active_journey_not_found",
		"a retired recovery cannot replay after another restart",
	)

	var captured := AdapterScript.new().capture_interrupted_journey(source, route)
	var tampered := captured.duplicate(true)
	tampered.route_identity.next_checkpoint_index = 0
	tampered.route_identity.next_objective_id = "ember_relay_tower"
	_check(
		AdapterScript.new().restore_interrupted_journey(tampered).reason \
			== &"interrupted_journey_identity_mismatch",
		"route changes fail checkpoint correlation even when individually valid",
	)
	var authority_route := route.duplicate(true)
	authority_route.authority.movement = true
	_check(
		AdapterScript.new().capture_interrupted_journey(
			source, authority_route
		).reason == &"interrupted_journey_route_invalid",
		"movement authority cannot enter an interrupted route receipt",
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_ACTIVE_JOURNEY_PERSISTENCE_ROUNDTRIP_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _frame():
	var frame = FrameScript.new()
	var origin := _origin_coordinate()
	var configured: Dictionary = frame.configure(
		WORLD_ID, 1_000.0, FRAME_ID, 10_000.0, origin,
		Vector3.BACK, Vector3.UP, 5_000.0, origin
	)
	if not bool(configured.accepted):
		_failures.append("planetary frame fixture failed: %s" % configured)
	return frame


func _origin_coordinate() -> Dictionary:
	return {
		"schema_version": FrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": FRAME_ID,
		"cell_x": 81,
		"cell_y": -22,
		"cell_z": 7,
		"offset_meters": Vector3.ZERO,
	}


func _route_identity() -> Dictionary:
	return {
		"source": &"activity_director_checkpoint_result",
		"activity_id": &"ember_beacon_survey",
		"activity_generation": 17,
		"next_checkpoint_index": 1,
		"checkpoint_count": 2,
		"next_objective_id": &"ember_return_beacon",
		"complete": false,
		"authority": {"navigation": false, "movement": false, "reward": false},
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
