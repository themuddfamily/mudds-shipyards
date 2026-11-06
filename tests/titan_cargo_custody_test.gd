extends SceneTree

const Store := preload("res://scripts/persistence/user_data_store.gd")
const MAIN := preload("res://scenes/main.tscn")
const TITAN := preload("res://scenes/ships/titan_medium_transport.tscn")
var _failures: Array[String] = []
var _case := 0

class RefusingFilesystem extends UserDataFilesystem:
	var refuse_publication := false
	var preserve_staged := false
	func rename_path(source: String, destination: String) -> Error:
		if refuse_publication and source.ends_with(".tmp"):
			refuse_publication = false
			preserve_staged = true
			return ERR_CANT_CREATE
		return super.rename_path(source, destination)
	func remove_path(path: String) -> Error:
		if preserve_staged and path.ends_with(".tmp"):
			return ERR_CANT_CREATE
		return super.remove_path(path)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--cold-main" in OS.get_cmdline_user_args():
		await _cold_main()
	else:
		await _semantic_store()
	if _failures.is_empty():
		print("TITAN_CARGO_CUSTODY_TEST_OK")
		quit(0)
	else:
		print("TITAN_CARGO_CUSTODY_TEST_FAILED: ", _failures)
		quit(1)

func _fixture(payload: Dictionary = {}) -> Dictionary:
	_case += 1
	var path := "user://titan_actual_store_%d.json" % _case
	for suffix in ["", ".bak", ".tmp", ".bak.1", ".bak.2", ".bak.3", ".recovery"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var filesystem := RefusingFilesystem.new()
	var store := Store.new(path, filesystem)
	store.load_read_only()
	if not payload.is_empty(): store.commit(payload, 0, "fixture-seed")
	var authority := CargoTransferAuthority.new()
	root.add_child(authority)
	var ship := TITAN.instantiate() as HeroShip
	root.add_child(ship)
	var locker := Node3D.new()
	root.add_child(locker)
	var panel := Node3D.new()
	root.add_child(panel)
	var custody := TitanCargoCustody.new()
	root.add_child(custody)
	var initial_bytes := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var initialized := custody.initialize(authority, store, ship, locker,
		func(_actor: Node, _panel: Node3D, _loading: bool) -> Dictionary: return {"accepted": true})
	ship.set(&"cargo_custody_guard", Callable(custody, "is_available"))
	ship.set(&"cargo_launch_guard", Callable(custody, "can_launch"))
	return {"authority": authority, "ship": ship, "locker": locker, "panel": panel,
		"custody": custody, "store": store, "filesystem": filesystem, "path": path, "initialized": initialized, "initial_bytes": initial_bytes}

func _semantic_store() -> void:
	var f := _fixture({"unrelated": {"jovian": "preserved", "settings": 7}})
	var custody := f.custody as TitanCargoCustody
	_check(f.initialized.accepted and custody.snapshot().locker == 4 and custody.snapshot().titan == 0,
		"actual store first-use seeds exactly four parcels")
	var loaded := custody.request_transfer(f.locker, f.panel, true, 2, &"load_two")
	_check(loaded.accepted and custody.snapshot().locker == 2 and custody.snapshot().titan == 2
		and _pair_is(f.store.get_snapshot()[TitanCargoCustody.SLOT], 2, 2)
		and f.store.get_snapshot()[TitanCargoCustody.SAFE_SLOT] == TitanCargoCustody.SAFE_CONTEXT
		and str(f.store.get_snapshot().unrelated.jovian) == "preserved" and int(f.store.get_snapshot().unrelated.settings) == 7,
		"actual commit durably owns pair2/2 plus on-foot recovery, preserving unrelated payload")
	for quantity: Variant in [0, 5, -1, 1.5, "1"]:
		_check(not custody.request_transfer(f.locker, f.panel, true, quantity).accepted, "invalid whole bounded quantity refused: " + str(quantity))
	_check(not custody.request_transfer(f.locker, f.panel, true, 2, &"load_two").accepted
		and not custody.request_transfer(f.locker, f.panel, true, 3).accepted
		and not custody.request_transfer(f.locker, f.panel, true, 1, &"stale", {"wrong": 1}).accepted,
		"duplicate, insufficient source and stale endpoint refuse without mutation")
	var before: Dictionary = f.store.get_snapshot()
	_check(not custody.initialize(f.authority, f.store, f.ship, f.locker, Callable()).accepted
		and f.store.get_snapshot() == before and custody.snapshot().titan == 2,
		"repeated live initialization never reseeds or changes custody")
	# Actual on-disk refusal: a directory blocks staging, leaving primary bytes
	# and both live quantities unchanged; repairing it permits the exact retry.
	var tmp_path := ProjectSettings.globalize_path(f.path + ".tmp")
	DirAccess.make_dir_recursive_absolute(tmp_path)
	var refused := custody.request_transfer(f.locker, f.panel, false, 1)
	_check(not refused.accepted and custody.snapshot().locker == 2 and custody.snapshot().titan == 2
		and f.store.get_snapshot() == before and not custody.can_launch(),
		"actual refused store write changes neither side and blocks launch")
	DirAccess.remove_absolute(tmp_path)
	_check(custody.request_transfer(f.locker, f.panel, false, 1).accepted,
		"repaired refused write retries the unchanged committed pair")
	# Real file operations with the publication rename interrupted leave a valid
	# staged document. It must never be mistaken for success or first use.
	f.filesystem.refuse_publication = true
	var interrupted := custody.request_transfer(f.locker, f.panel, false, 1)
	_check(not interrupted.accepted and custody.snapshot().locker == 3 and custody.snapshot().titan == 1
		and FileAccess.file_exists(f.path + ".tmp") and not custody.can_launch(),
		"actual interrupted publication preserves live last pair and valid staged bytes")
	var cold_store := Store.new(f.path)
	_check(not cold_store.load_read_only().accepted, "fresh actual store refuses interrupted transaction")
	await _dispose(f)
	for bad: Dictionary in [
		{TitanCargoCustody.MARKER: true},
		{TitanCargoCustody.MARKER: true, TitanCargoCustody.SLOT: {"locker": 4, "titan": 4}},
		{TitanCargoCustody.SLOT: {"locker": 2, "titan": 2}}]:
		f = _fixture(bad)
		_check(not f.initialized.accepted and not f.custody.can_launch() and FileAccess.get_file_as_bytes(f.path) == f.initial_bytes,
			"missing initialized/invalid/markerless entry fails closed without overwriting bytes")
		await _dispose(f)
	f = _fixture()
	f.custody.request_transfer(f.locker, f.panel, true, 2)
	var corrupted := "{damaged-primary".to_utf8_buffer()
	var file := FileAccess.open(f.path, FileAccess.WRITE)
	file.store_buffer(corrupted)
	file.close()
	f.ship.request_engine_start()
	_check(not f.custody.can_launch() and StringName(f.ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
		and FileAccess.get_file_as_bytes(f.path) == corrupted,
		"invalid primary with real valid backup refuses launch and preserves corrupt primary bytes")
	_check(not f.custody.request_transfer(f.locker, f.panel, false, 1).accepted
		and f.custody.snapshot().locker == 2 and f.custody.snapshot().titan == 2,
		"backup-only transfer refuses with both live sides unchanged")
	await _dispose(f)

func _cold_main() -> void:
	var seed_path := OS.get_environment("TITAN_COLD_SEED_PATH")
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(seed_path))
	_check(payload is Dictionary and _pair_is(payload.get(TitanCargoCustody.SLOT), 2, 2),
		"fresh process starts from the ordinary physical loop's committed loaded2/2 payload")
	if not _failures.is_empty(): return
	var path := "user://titan_cold_main.json"
	if OS.get_environment("TITAN_COLD_REPEAT") != "1":
		var source_bytes := FileAccess.get_file_as_bytes(seed_path + ".envelope.json")
		_check(not source_bytes.is_empty(), "cold process has exact physical loaded commit bytes")
		for suffix in ["", ".bak", ".tmp", ".bak.1", ".bak.2", ".bak.3"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(source_bytes)
		file.close()
	var independent := Store.new(path)
	_check(independent.load_read_only().accepted, "fresh process reads exact committed physical envelope")
	var previous_endpoint: Dictionary = {}
	var previous_scope := 0
	var previous_authority: WeakRef
	var previous_service: WeakRef
	for replacement in 2:
		var game := MAIN.instantiate() as GameFlow
		_check(game.configure_runtime_settings_persistence(Store.new(path)), "cold Main uses actual independent store")
		root.add_child(game)
		await process_frame
		await physics_frame
		game.start_shift()
		for frame in 20:
			await physics_frame
			await process_frame
		var state := game.titan_cargo.snapshot()
		var craft := game.get_node("TitanMediumTransport") as HeroShip
		_check(state.available and state.locker == 4 and state.titan == 0
			and not game._piloting and not game._station_seated and not game.player.is_seated()
			and game.player.is_on_floor() and not craft.is_piloted()
			and bool(craft.get_telemetry().landed) and StringName(craft.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
			and is_equal_approx(float(craft.get_telemetry().hull), 220.0)
			and (game.player.get_node("%PlayerCamera") as Camera3D).current
			and craft.get_crew_role_authority() == null
			and _pair_is(game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT], 4, 0)
			and game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SAFE_SLOT].mode == "on_foot",
			"cold replacement%d returns existing total4 to locker with safe supported on-foot authority" % replacement)
		if replacement > 0:
			_check(previous_authority.get_ref() == null and previous_service.get_ref() == null,
				"old Main authority and custody service are retired before replacement use")
			_check(int(state.locker_handle.titan_custody_instance) != previous_scope,
				"cold replacement registers a fresh scoped endpoint")
			var frozen_before := game.titan_cargo.snapshot()
			var stale := game.titan_cargo.request_transfer(game.player, game._titan_locker_panel, true, 1, &"old_endpoint", previous_endpoint)
			_check(not stale.accepted and stale.reason == &"stale_or_wrong_endpoint" and game.titan_cargo.snapshot().locker == frozen_before.locker,
				"previous Main endpoint cannot mutate replacement custody")
		previous_authority = weakref(game.cargo_transfer_authority)
		previous_service = weakref(game.titan_cargo)
		previous_endpoint = state.locker_handle.duplicate(true)
		previous_scope = int(state.locker_handle.titan_custody_instance)
		game.release_mouse_capture()
		game.queue_free()
		_check(not game.titan_cargo.request_transfer(game.player, game._titan_locker_panel, true, 1).accepted,
			"retiring Main service cannot transfer during queued teardown")
		for frame in 4: await process_frame

func _dispose(fixture: Dictionary) -> void:
	for key in ["custody", "panel", "locker", "ship", "authority"]:
		fixture[key].queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition: _failures.append(message)

func _pair_is(value: Variant, locker: int, titan: int) -> bool:
	return value is Dictionary and int(value.get("locker", -1)) == locker and int(value.get("titan", -1)) == titan
