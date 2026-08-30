extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")


class IsolatedFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes,
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
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var filesystem := IsolatedFilesystem.new()
	var store := Store.new("memory://fleet-switching.json", filesystem)
	var settings := Settings.new("memory://fleet-switching.cfg")
	_check(bool(store.load().get("accepted", false)), "isolated settings store opens empty")
	_check(
		bool(store.commit({Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "fixture").get("accepted", false)),
		"isolated settings fixture publishes a validated payload"
	)
	var flow := MAIN_SCENE.instantiate() as GameFlow
	_check(
		flow.configure_runtime_settings_persistence(store, "memory://fleet-switching.cfg"),
		"GameFlow accepts isolated settings before startup"
	)
	root.add_child(flow)
	await process_frame
	await process_frame
	await process_frame
	var registered := flow.get_flyable_ships()
	_check(registered.size() >= 8, "baseline and nested production craft share the flyable registry")
	_check(
		registered.any(func(candidate: HeroShip) -> bool:
			return candidate.get_ship_id() == &"torrent_provisional"
	),
		"baseline Torrent remains registered"
	)
	var world := flow.get_node(^"ShipyardWorld") as ShipyardWorld
	var binding := world.get_fleet_expansion_production_binding()
	for craft_id: StringName in [
		&"cinder_cargo_hauler",
		&"cinder_long_range_bomber",
		&"cinder_light_interceptor",
	]:
		var contract := binding.get_craft_compatibility_contract(craft_id)
		_check(bool(contract.get("valid", false)), "%s keeps its physical switching contract" % craft_id)
		var reset := binding.reset_craft_for_reuse(craft_id)
		_check(bool(reset.get("accepted", false)) and bool(reset.get("attachment_preserved", false)), "%s accepts safe reuse" % craft_id)
		var detached := binding.detach_craft(craft_id)
		_check(bool(detached.get("accepted", false)), "%s detaches for safe switching" % craft_id)
		var reattached := binding.reattach_craft(craft_id)
		_check(bool(reattached.get("accepted", false)), "%s reattaches after switching" % craft_id)
	var expansion_ids := [
		&"cinder_cargo_hauler",
		&"cinder_long_range_bomber",
		&"cinder_light_interceptor",
	]
	var registered_expansion := flow.get_flyable_ships().filter(func(candidate: HeroShip) -> bool:
		return candidate.get_ship_id() in expansion_ids
	)
	_check(
		registered_expansion.size() == 3,
		"all three production craft remain registered after reuse cycles"
	)

	# GameFlow owns destruction/regeneration for every registered flyable. The
	# Cinder pads are not legacy ShipBerths, so this proves that recovery consumes
	# the expansion binding's authored landing transform instead of falling back to
	# the station's generic ship spawn.
	var recovery_craft := flow.get_flyable_ships().filter(func(candidate: HeroShip) -> bool:
		return candidate.get_ship_id() == &"cinder_light_interceptor"
	).front() as HeroShip
	var recovery_contract := binding.get_craft_compatibility_contract(recovery_craft.get_ship_id())
	var recovery_transform := recovery_contract.get(
		"landing_transform", Transform3D.IDENTITY
	) as Transform3D
	var recovery_instance_id := recovery_craft.get_instance_id()
	# A real loss can occur at any flight attitude. Recovery must restore the
	# authored pad basis as well as its position, not park a rolled hull through
	# the deck.
	recovery_craft.global_basis = Basis(Vector3.UP, 0.42) * Basis(Vector3.RIGHT, -0.18)
	recovery_craft.apply_damage(
		recovery_craft.maximum_hull + 1.0,
		recovery_craft.global_position,
		Vector3.UP
	)
	var pending := flow.get("_regeneration_pending") as Dictionary
	_check(
		recovery_craft.is_destroyed() and pending.has(recovery_instance_id),
		"destroyed Cinder craft enters GameFlow's same-instance regeneration queue"
	)
	var pending_entry := pending.get(recovery_instance_id, {}) as Dictionary
	pending_entry["ready_at_msec"] = 0
	pending[recovery_instance_id] = pending_entry
	flow.set("_regeneration_pending", pending)
	flow.call("_update_pending_regeneration", 0.0)
	var recovered_attachment := (
		binding.get_fleet_snapshot().get("craft", []) as Array
	).filter(func(row: Dictionary) -> bool:
		return StringName(row.get("craft_id", &"")) == recovery_craft.get_ship_id()
	).front() as Dictionary
	_check(
		not recovery_craft.is_destroyed()
		and recovery_craft.get_instance_id() == recovery_instance_id
		and recovery_craft.global_transform.is_equal_approx(recovery_transform)
		and bool(recovered_attachment.get("attached", false)),
		"GameFlow regenerates Cinder at its authored occupied expansion pad without replacing it"
	)
	flow.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS game_flow_fleet_expansion_switching_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
