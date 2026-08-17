extends SceneTree

## Production proof for the modern Jovian fabrication-kit delivery. Activity
## selection is driven through the same pause-menu buttons a player uses; cargo
## time, landing, inventory, and lifecycle all stay in their existing owners.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://cargo-delivery-production-settings.json"

var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
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
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://cargo-delivery-production-legacy.cfg"
		),
		"the production fixture injects isolated settings before Main startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var jovian := _find_ship(game, &"jovian_provisional")
	var torrent := _find_ship(game, &"torrent_provisional")
	var freight_berth := (
		world.get_jovian_freight_berth()
		if world != null
		else null
	)
	_check(
		hud != null and world != null and jovian != null and torrent != null
		and freight_berth != null,
		"production Main exposes the HUD, both real craft, and the real Jovian freight berth"
	)
	if (
		hud == null or world == null or jovian == null or torrent == null
		or freight_berth == null
	):
		await _clean_up(game)
		_finish()
		return

	await _test_player_selection_and_atomic_failure(game, hud, jovian)
	_test_contract_and_start_gates(game, hud, jovian, torrent, freight_berth)
	await _test_physics_reentry_and_physical_delivery(
		game, hud, world, jovian, freight_berth
	)
	_test_failure_expiry_reset_and_authority(game, hud)

	await _clean_up(game)
	_finish()


func _test_player_selection_and_atomic_failure(
	game: GameFlow,
	hud: GameHUD,
	jovian: HeroShip
	) -> void:
	# Bypass only the title splash; the pause event and every selection below use
	# the real shipping HUD controls and request signal.
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud.call("_unhandled_input", pause_event)
	var pause_overlay := hud.get("_pause") as Control
	var board_open := pause_overlay.find_child(
		"ActivityBoardButton", true, false
	) as Button
	_check(
		paused and pause_overlay.visible and board_open != null,
		"the existing pause input opens the reachable menu containing Activity Board"
	)
	board_open.emit_signal("pressed")
	var patrol_button := pause_overlay.find_child(
		"PatrolActivityButton", true, false
	) as Button
	var race_button := pause_overlay.find_child(
		"TimedRaceActivityButton", true, false
	) as Button
	var cargo_button := pause_overlay.find_child(
		"CargoDeliveryActivityButton", true, false
	) as Button
	var convoy_button := pause_overlay.find_child(
		"ConvoyEscortActivityButton", true, false
	) as Button
	var board := hud.get_activity_selection_report()
	_check(
		bool(board.get("page_visible", false))
		and patrol_button != null and race_button != null and cargo_button != null
		and convoy_button != null
		and cargo_button.focus_mode == Control.FOCUS_ALL
		and hud.get_viewport().gui_get_focus_owner() == race_button,
		"the activity page exposes all four controls and focuses the selected race button"
	)

	patrol_button.emit_signal("pressed")
	_check(
		game.get_activity_integration_report().get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_PATROL
		and hud.get_viewport().gui_get_focus_owner() == patrol_button,
		"the patrol button reaches GameFlow and validated selection moves focus to it"
	)
	race_button.emit_signal("pressed")
	var race_selected := game.get_activity_integration_report()
	_check(
		race_selected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(race_selected.get("attached_route_owner_count", 0)) == 1,
		"the race button restores exactly one Cinder route owner"
	)

	# Structured failure witness: cargo cannot attach while its real owner node is
	# detached. The rejected button transaction must retain the previous race.
	var ship_parent := jovian.get_parent()
	var ship_index := jovian.get_index()
	ship_parent.remove_child(jovian)
	await process_frame
	cargo_button.emit_signal("pressed")
	var rejected := game.get_activity_integration_report()
	var rejected_board := hud.get_activity_selection_report()
	_check(
		rejected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(rejected.get("attached_route_owner_count", 0)) == 1
		and "ACTIVITY ATTACH FAILED" in str(rejected_board.get("status", "")),
		"failed cargo preflight atomically preserves the prior selection and route owner"
	)
	ship_parent.add_child(jovian)
	ship_parent.move_child(jovian, mini(ship_index, ship_parent.get_child_count() - 1))
	await process_frame
	await process_frame
	cargo_button.emit_signal("pressed")
	var selected := game.get_activity_integration_report()
	board = hud.get_activity_selection_report()
	_check(
		selected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and int(selected.get("attached_route_owner_count", -1)) == 0
		and board.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and hud.get_viewport().gui_get_focus_owner() == cargo_button,
		"the cargo button selects the authority-backed delivery, focuses it, and releases both Cinder adapters"
	)

	# Exit by the visible menu route, leaving the tree unpaused for activity time.
	var back := pause_overlay.find_child(
		"ActivitySelectionBackButton", true, false
	) as Button
	back.emit_signal("pressed")
	_check(
		hud.get_viewport().gui_get_focus_owner() == board_open,
		"returning from Activity Board restores focus to its pause-menu entry"
	)
	var resume := pause_overlay.find_child("ResumeButton", true, false) as Button
	resume.emit_signal("pressed")
	_check(not paused and not pause_overlay.visible, "the ordinary Back/Resume route closes the board")


func _test_contract_and_start_gates(
	game: GameFlow,
	hud: GameHUD,
	jovian: HeroShip,
	torrent: HeroShip,
	freight_berth: JovianFreightBerth
	) -> void:
	var integration := game.get_activity_integration_report()
	var contract := integration.get("cargo_contract", {}) as Dictionary
	var source_handle := integration.get("cargo_source_handle", {}) as Dictionary
	var destination_handle := integration.get("cargo_destination_handle", {}) as Dictionary
	_check(
		int(integration.get("cargo_transfer_authority_count", 0)) == 1
		and integration.get("cargo_source_entity") == jovian
		and integration.get("cargo_destination_entity") == freight_berth
		and source_handle.get("entity_id", &"") == &"jovian_provisional"
		and source_handle.get("manifest_id", &"") == &"jovian_provisional_manifest"
		and destination_handle.get("entity_id", &"") == &"jovian_freight_berth"
		and destination_handle.get("manifest_id", &"") == &"jovian_freight_berth_manifest",
		"one cargo authority binds exact generation handles to the real ship and berth nodes"
	)
	_check(
		contract.get("contract_id", &"") == GameFlow.CARGO_DELIVERY_ACTIVITY_ID
		and contract.get("item_id", &"") == &"fabrication_kits"
		and int(contract.get("quantity", 0)) == 2
		and contract.get("ordered_phases", []) == [
			&"departed_shipyard", &"returned_to_shipyard"
		]
		and is_equal_approx(float(contract.get("deadline_seconds", 0.0)), 180.0),
		"the checked-in delivery contract freezes item, quantity, phases, and physics deadline"
	)
	var on_foot := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(
		not bool(on_foot.get("accepted", true))
		and on_foot.get("reason", &"") == &"not_in_free_flight"
		and not bool(game.get_activity_integration_report().get("selection_locked", true)),
		"selecting cargo cannot start it before a physical free-flight sortie"
	)
	game.active_ship = torrent
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var wrong_craft := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(
		not bool(wrong_craft.get("accepted", true))
		and wrong_craft.get("reason", &"") == &"delivery_craft_required",
		"the selected delivery cannot bind to a non-Jovian active craft"
	)
	game.active_ship = jovian
	var started := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var generation := int(started.get("session_generation", -1))
	_check(
		bool(started.get("accepted", false))
		and generation == 1
		and started.get("state_id", &"") == &"active"
		and started.get("phase_id", &"") == &"return"
		and int(started.get("completed_checkpoint_count", 0)) == 1,
		"free flight starts generation one and records physical departure exactly once"
	)
	var ui_report := hud.get_activity_selection_report()
	_check(
		bool(ui_report.get("selection_locked", false))
		and "LOCKED" in str(ui_report.get("status", "")),
		"the accepted start commits the GameFlow selection lock back into the board"
	)

	# Re-open through the real pause event and prove every alternative is disabled.
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud.call("_unhandled_input", pause_event)
	var pause_overlay := hud.get("_pause") as Control
	(pause_overlay.find_child("ActivityBoardButton", true, false) as Button).emit_signal("pressed")
	ui_report = hud.get_activity_selection_report()
	var buttons := ui_report.get("buttons", {}) as Dictionary
	_check(
		bool((buttons.get(&"timed_race", {}) as Dictionary).get("disabled", false))
		and bool((buttons.get(&"patrol", {}) as Dictionary).get("disabled", false))
		and not bool((buttons.get(&"cargo_delivery", {}) as Dictionary).get("disabled", true)),
		"a running cargo generation disables both alternative player selections"
	)
	(pause_overlay.find_child("ActivitySelectionBackButton", true, false) as Button).emit_signal("pressed")
	(pause_overlay.find_child("ResumeButton", true, false) as Button).emit_signal("pressed")


func _test_physics_reentry_and_physical_delivery(
	game: GameFlow,
	hud: GameHUD,
	world: ShipyardWorld,
	jovian: HeroShip,
	freight_berth: JovianFreightBerth
	) -> void:
	game.set_physics_process(false)
	var initial_report := game.get_activity_integration_report()
	var race_samples := int(initial_report.get("position_sample_count", -1))
	game.call("_physics_process", 0.0)
	game.call("_physics_process", 0.5)
	var advanced := game.get_active_activity_snapshot()
	_check(
		is_equal_approx(float(advanced.get("elapsed_seconds", -1.0)), 0.5)
		and is_equal_approx(float(advanced.get("deadline_remaining_seconds", -1.0)), 179.5)
		and int(game.get_activity_integration_report().get("cargo_physics_step_count", 0)) == 1
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== race_samples,
		"only nonzero caller physics delta advances the cargo clock; no Cinder position sample runs"
	)
	_check(
		"DELIVERY  RETURN  1/2" in str(hud.get_activity_objective_report().get("text", ""))
		and "LEFT" in str(hud.get_activity_objective_report().get("text", "")),
		"the HUD publishes return-phase progress and remaining physics time"
	)

	var before_reentry := game.get_active_activity_snapshot()
	var integration_before := game.get_activity_integration_report()
	var authority_id := int(integration_before.get("cargo_transfer_authority_instance_id", 0))
	var activity_id := int(integration_before.get("cargo_delivery_activity_instance_id", 0))
	root.remove_child(game)
	await process_frame
	await process_frame
	var detached := game.get_activity_integration_report()
	_check(
		not bool((detached.get("cargo_source_manifest", {}) as Dictionary).get("attached", true))
		and not bool((detached.get("cargo_destination_manifest", {}) as Dictionary).get("attached", true))
		and game.get_active_activity_snapshot() == before_reentry,
		"whole-Main detach freezes the delivery and marks both real manifest owners detached"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	var reentered := game.get_activity_integration_report()
	_check(
		int(reentered.get("cargo_transfer_authority_instance_id", 0)) == authority_id
		and int(reentered.get("cargo_delivery_activity_instance_id", 0)) == activity_id
		and bool((reentered.get("cargo_source_manifest", {}) as Dictionary).get("attached", false))
		and bool((reentered.get("cargo_destination_manifest", {}) as Dictionary).get("attached", false))
		and game.get_active_activity_snapshot() == before_reentry,
		"re-entry reattaches exact nodes/handles without identity, generation, time, or quantity churn"
	)

	# Stage inside the real berth's capture volume, then let the production berth
	# reservation and HeroShip landing assist perform the physical return.
	var dock_transform := world.get_berth_transform(&"jovian_freight_berth")
	jovian.global_transform = Transform3D(
		dock_transform.basis,
		dock_transform.origin + Vector3.UP * 3.0
	)
	jovian.velocity = Vector3.ZERO
	jovian.set("_landed", false)
	game.call("_mark_sortie_departed")
	game.call("_try_request_landing")
	_check(
		bool(game.get("_landing_request_active")) and jovian.is_landing_active(),
		"the real Jovian acquires its physical freight-berth landing contract"
	)
	var landed := await _wait_until(
		func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN,
		720
	)
	var completed := game.get_active_activity_snapshot()
	var receipt := completed.get("accepted_receipt", {}) as Dictionary
	_check(
		landed and bool(jovian.get_telemetry().get("landed", false))
		and jovian.global_transform.is_equal_approx(dock_transform)
		and completed.get("state_id", &"") == &"completed"
		and completed.get("phase_id", &"") == &"complete",
		"physical landing submits return and completes the typed delivery at the exact berth transform"
	)
	var inventory := game.get_activity_integration_report()
	_check(
		_manifest_quantity(inventory.get("cargo_source_manifest", {}) as Dictionary) == 4
		and _manifest_quantity(inventory.get("cargo_destination_manifest", {}) as Dictionary) == 2
		and receipt.get("transfer_id", &"") == &"jovian_fabrication_kit_delivery_g1"
		and int(receipt.get("quantity", 0)) == 2,
		"CargoTransferAuthority conserves quantity and returns the exact generation-one receipt"
	)
	_check(
		"DELIVERY  COMPLETE  2 FABRICATION KITS"
		in str(hud.get_activity_objective_report().get("text", ""))
		and "REWARD" not in str(hud.get_activity_objective_report().get("text", "")).to_upper(),
		"completion publishes exact delivered cargo without reward language"
	)
	_check(
		freight_berth.get_berth_id() == &"jovian_freight_berth",
		"delivery destination identity remains the module's published berth ID"
	)


func _test_failure_expiry_reset_and_authority(game: GameFlow, hud: GameHUD) -> void:
	var activity := game.get_activity_integration_report().get(
		"cargo_delivery_activity"
	) as CargoDeliveryActivity
	var completed_generation := activity.get_generation()
	_check(game.reset_active_activity(), "completed delivery resets explicitly")
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var restarted := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var failure_generation := int(restarted.get("session_generation", -1))
	var stale := activity.fail(&"stale_destruction", completed_generation)
	_check(
		not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation"
		and failure_generation == completed_generation + 2,
		"reset and restart advance generations so an old destruction cannot fail the replacement"
	)
	_check(
		game.call("_fail_active_activity", &"ship_destroyed")
		and game.get_active_activity_snapshot().get("failure_reason", &"") == &"ship_destroyed"
		and "DELIVERY  FAILED — SHIP DESTROYED"
		in str(hud.get_activity_objective_report().get("text", "")),
		"current-generation destruction fails cargo and publishes its typed reason"
	)
	_check(game.reset_active_activity(), "failed delivery resets for a final timeout witness")
	var timeout_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	game.call("_physics_process", 179.5)
	game.call("_physics_process", 0.5)
	var expired := game.get_active_activity_snapshot()
	var final_inventory := game.get_activity_integration_report()
	_check(
		int(timeout_start.get("session_generation", -1)) == failure_generation + 2
		and expired.get("state_id", &"") == &"expired"
		and expired.get("failure_reason", &"") == &"deadline_expired"
		and is_equal_approx(float(expired.get("elapsed_seconds", -1.0)), 180.0)
		and "DELIVERY  EXPIRED — DEADLINE EXPIRED"
		in str(hud.get_activity_objective_report().get("text", "")),
		"the exact 180-second caller-physics boundary expires once with typed HUD copy"
	)
	_check(
		_manifest_quantity(final_inventory.get("cargo_source_manifest", {}) as Dictionary) == 4
		and _manifest_quantity(final_inventory.get("cargo_destination_manifest", {}) as Dictionary) == 2,
		"reset, destruction, and expiry never refill or transfer cargo"
	)
	var audit := final_inventory.get("cargo_authority_audit", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and int(audit.get("committed_transfer_count", -1)) == 1
		and final_inventory.get("inventory_authority")
		== final_inventory.get("cargo_transfer_authority")
		and not bool(final_inventory.get("owns_inventory", true))
		and not bool(final_inventory.get("grants_rewards", true))
		and not bool(final_inventory.get("combat_authority", true))
		and not bool(final_inventory.get("ship_authority", true))
		and not bool(final_inventory.get("berth_authority", true))
		and final_inventory.get("cargo_evidence_status", &"") == &"modern_interpretation"
		and not bool(final_inventory.get("cargo_source_bounded", true))
		and not bool(final_inventory.get("cargo_historical_authenticity_claim", true)),
		"GameFlow/HUD retain zero adjacent authority and label the delivery as modern interpretation"
	)


func _find_ship(game: GameFlow, ship_id: StringName) -> HeroShip:
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == ship_id:
			return candidate
	return null


func _manifest_quantity(manifest: Dictionary) -> int:
	for raw_entry: Variant in manifest.get("entries", []) as Array:
		var entry := raw_entry as Dictionary
		if entry.get("item_id", &"") == &"fabrication_kits":
			return int(entry.get("quantity", 0))
	return 0


func _wait_until(predicate: Callable, maximum_physics_frames: int) -> bool:
	for _frame in maximum_physics_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return bool(predicate.call())


func _clean_up(game: GameFlow) -> void:
	paused = false
	game.set("_piloting", false)
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CARGO_DELIVERY_PRODUCTION_INTEGRATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CARGO_DELIVERY_PRODUCTION_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print(
			"CARGO_DELIVERY_PRODUCTION_INTEGRATION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
