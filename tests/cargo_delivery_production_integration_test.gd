extends SceneTree

## Production proof for the modern Jovian fabrication-kit delivery. Activity
## selection is driven through the same pause-menu buttons a player uses; cargo
## time, landing, inventory, and lifecycle all stay in their existing owners.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "user://cargo-delivery-production-settings.json"

var _assertions := 0
var _failures: Array[String] = []
var _filesystem: MemoryFilesystem


class MemoryFilesystem extends UserDataFilesystem:
	var reject_writes := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		return ERR_CANT_CREATE if reject_writes else super.write_bytes_and_flush(path, bytes)


class InterruptedRewardFilesystem extends UserDataFilesystem:
	var stopped := false
	var interrupt_rewards := true
	var reward_rejected := false
	var reject_writes := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if stopped or reject_writes:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if interrupt_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			reward_rejected = true
			stopped = true
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if stopped or reject_writes else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		return ERR_UNAVAILABLE if stopped or reject_writes else super.rename_path(from_path, to_path)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_filesystem = MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, _filesystem) as UserDataStore
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

	await _test_player_selection_and_atomic_failure(
		game, hud, jovian, freight_berth
	)
	_test_contract_and_start_gates(game, hud, jovian, torrent, freight_berth)
	await _test_physics_reentry_and_physical_delivery(
		game, hud, world, jovian, freight_berth
	)
	_test_failure_expiry_reset_and_authority(game, hud)

	var saved_generation := game.cargo_delivery_activity.get_generation()
	await _clean_up(game)
	await _test_saved_cargo_reentry(saved_generation)
	await _test_interrupted_cargo_recovery()
	await _test_unsaved_cargo_reset_recovery()
	_finish()


func _test_player_selection_and_atomic_failure(
	game: GameFlow,
	hud: GameHUD,
	jovian: HeroShip,
	freight_berth: JovianFreightBerth
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

	# Structured reentrant failure witness: both cargo owners return detached, then
	# an observer of the source's reattach removes the destination synchronously.
	# The pair transaction must roll back both manifests as well as preserve the
	# previous race owner and rejected board state.
	var ship_parent := jovian.get_parent()
	var ship_index := jovian.get_index()
	var berth_parent := freight_berth.get_parent()
	var berth_index := freight_berth.get_index()
	ship_parent.remove_child(jovian)
	berth_parent.remove_child(freight_berth)
	await process_frame
	ship_parent.add_child(jovian)
	ship_parent.move_child(jovian, mini(ship_index, ship_parent.get_child_count() - 1))
	berth_parent.add_child(freight_berth)
	berth_parent.move_child(
		freight_berth,
		mini(berth_index, berth_parent.get_child_count() - 1)
	)
	await process_frame
	var cargo_before_rejection := game.get_activity_integration_report()
	var source_before_rejection := (
		cargo_before_rejection.get("cargo_source_manifest", {}) as Dictionary
	).duplicate(true)
	var destination_before_rejection := (
		cargo_before_rejection.get("cargo_destination_manifest", {}) as Dictionary
	).duplicate(true)
	var cargo_authority := cargo_before_rejection.get(
		"cargo_transfer_authority"
	) as CargoTransferAuthority
	var observer_attack := {"triggered": false}
	var lifecycle_events: Array[StringName] = []
	cargo_authority.manifest_reattached.connect(
		func(handle: Dictionary) -> void:
			lifecycle_events.append(StringName("reattached:%s" % handle.manifest_id))
	)
	cargo_authority.manifest_detached.connect(
		func(handle: Dictionary) -> void:
			lifecycle_events.append(StringName("detached:%s" % handle.manifest_id))
	)
	cargo_authority.manifest_reattached.connect(
		func(handle: Dictionary) -> void:
			if handle.get("manifest_id", &"") != &"jovian_provisional_manifest":
				return
			observer_attack["triggered"] = true
			berth_parent.remove_child(freight_berth),
		CONNECT_ONE_SHOT
	)
	cargo_button.emit_signal("pressed")
	var rejected := game.get_activity_integration_report()
	var rejected_board := hud.get_activity_selection_report()
	_check(
		rejected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(rejected.get("attached_route_owner_count", 0)) == 1
		and bool(observer_attack.get("triggered", false))
		and lifecycle_events == [
			&"reattached:jovian_provisional_manifest",
			&"detached:jovian_freight_berth_manifest",
			&"detached:jovian_provisional_manifest",
		]
		and rejected.get("cargo_source_manifest", {}) == source_before_rejection
		and rejected.get("cargo_destination_manifest", {}) == destination_before_rejection
		and not bool(source_before_rejection.get("attached", true))
		and not bool(destination_before_rejection.get("attached", true))
		and "ACTIVITY ATTACH FAILED" in str(rejected_board.get("status", "")),
		"reentrant cargo attach failure preserves both detached manifests, the prior selection, and its route owner"
	)
	if freight_berth.get_parent() == null:
		berth_parent.add_child(freight_berth)
		berth_parent.move_child(
			freight_berth,
			mini(berth_index, berth_parent.get_child_count() - 1)
		)
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
	var return_marker := _find_minimap_marker(
		game.get_minimap_snapshot().get("objective_markers", []) as Array,
		&"active_jovian_delivery_return",
	)
	_check(
		(return_marker.get("position", Vector3.INF) as Vector3).is_equal_approx(
			game.world.get_berth_transform(&"jovian_freight_berth").origin
		)
			and int(return_marker.get("generation", 0)) == generation,
		"the active delivery publishes the exact physical return berth on the minimap"
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
	# The save store cannot write while the delivery lands, so its reward
	# receipt is rejected and must stay owed rather than being lost.
	_filesystem.reject_writes = true
	game.call("_try_request_landing")
	_check(
		bool(game.get("_landing_request_active")) and jovian.is_landing_active(),
		"the real Jovian acquires its physical freight-berth landing contract"
	)
	var landed := await _wait_until(
		func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN,
		720
	)
	_filesystem.reject_writes = false
	# The same landing call completes the delivery and then docks; the routine
	# docking toast must not erase the delivery's reward-failure toast.
	var landed_toast_title := (hud.get("_toast_title") as Label).text
	var landed_toast_detail := (hud.get("_toast_detail") as Label).text
	_check(
		landed_toast_title == "FABRICATION KITS DELIVERED"
		and "reward receipt could not be saved" in landed_toast_detail,
		"the delivery reward-failure toast survives the same-frame docking toast (got %s: %s)"
		% [landed_toast_title, landed_toast_detail]
	)
	var docking_toast_follows := false
	for _frame in 600:
		if (hud.get("_toast_title") as Label).text == "LANDING COMPLETE" \
				and (hud.get("_toast_panel") as Control).visible:
			docking_toast_follows = true
			break
		await process_frame
	_check(docking_toast_follows, "the held docking toast is shown once the reward toast finishes")
	var completed := game.get_active_activity_snapshot()
	var receipt := completed.get("accepted_receipt", {}) as Dictionary
	_check(
		landed and bool(jovian.get_telemetry().get("landed", false))
		and jovian.global_transform.is_equal_approx(dock_transform)
		and completed.get("state_id", &"") == &"completed"
		and completed.get("phase_id", &"") == &"complete",
		"physical landing submits return and completes the typed delivery at the exact berth transform"
	)
	_check(
		_find_minimap_marker(
			game.get_minimap_snapshot().get("objective_markers", []) as Array,
			&"active_jovian_delivery_return",
		).is_empty(),
		"physical completion withdraws the delivery marker without a stale berth target"
	)
	var inventory := game.get_activity_integration_report()
	_check(
		_manifest_quantity(inventory.get("cargo_source_manifest", {}) as Dictionary) == 4
		and _manifest_quantity(inventory.get("cargo_destination_manifest", {}) as Dictionary) == 2
		and receipt.get("transfer_id", &"") == &"jovian_fabrication_kit_delivery_g1"
		and int(receipt.get("quantity", 0)) == 2,
		"CargoTransferAuthority conserves quantity and returns the exact generation-one receipt"
	)
	var reward_record := (
		(game.get_activity_reward_report().get("authority", {}) as Dictionary).get(
			"record", {}
		) as Dictionary
	)
	var reward_receipt := reward_record.get("last_receipt", {}) as Dictionary
	_check(
		int(reward_record.get("total_receipts", -1)) == 0
			and reward_receipt.is_empty(),
		"a landed delivery whose receipt the store rejects records no receipt yet"
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
	var reset_accepted := game.reset_active_activity()
	_check(reset_accepted, "completed delivery resets explicitly (%s)" % (game.get("_jovian_cargo_session_save_status") as Dictionary).get("reason", ""))
	var reward_record := (
		(game.get_activity_reward_report().get("authority", {}) as Dictionary).get(
			"record", {}
		) as Dictionary
	)
	var reward_receipt := reward_record.get("last_receipt", {}) as Dictionary
	_check(
		int(reward_record.get("total_receipts", 0)) == 1
			and reward_receipt.get("activity_id", "") \
				== "jovian_fabrication_kit_delivery"
			and int(reward_receipt.get("activity_generation", 0)) == completed_generation
			and reward_receipt.get("reward_id", "") \
				== "return_fabrication_kits_to_shipyard"
			and bool(reward_receipt.get("granted", false))
			and not bool(reward_receipt.get("replay_allowed", true)),
		"the next reset pays the owed delivery as one non-replayable fabrication-kit receipt"
	)
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
	# Every run moves two of the Jovian's six kits. Drain the hold through two
	# more real deliveries; the next departure must not start a run whose
	# landing transfer can only be rejected.
	for run in 2:
		_check(game.reset_active_activity(), "terminal delivery resets for another run")
		game.phase = GameFlow.Phase.FREE_FLIGHT
		var run_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		_check(
			bool(run_start.get("accepted", false))
			and bool(game.call("_complete_cargo_delivery_on_return")),
			"a later delivery in the same session starts and delivers"
		)
	var drained := game.get_activity_integration_report()
	_check(
		_manifest_quantity(drained.get("cargo_source_manifest", {}) as Dictionary) == 0
		and _manifest_quantity(drained.get("cargo_destination_manifest", {}) as Dictionary) == 6,
		"three deliveries move all six kits to the freight berth"
	)
	var final_reset := game.reset_active_activity()
	_check(final_reset, "the drained delivery resets")
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var empty_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(
		not bool(empty_start.get("accepted", true))
		and empty_start.get("reason", &"") == &"insufficient_source_quantity"
		and game.get_active_activity_snapshot().get("state_id", &"") == &"idle",
		"an empty Jovian hold refuses the run at departure instead of failing it on landing"
	)
	_check(final_reset and game.get_active_activity_snapshot().get("state_id") == &"idle",
		"the actual completed cargo run retains IDLE after its accepted ordinary reset")
	var race_button := (hud.get("_activity_selection_buttons") as Dictionary).get(GameFlow.ACTIVITY_KIND_TIMED_RACE) as Button
	_check(race_button != null and not race_button.disabled,
		"the ordinary HUD enables Race after a successful cargo reset")
	race_button.pressed.emit()
	_check(game.get_activity_integration_report().get("selected_activity_kind") == GameFlow.ACTIVITY_KIND_TIMED_RACE,
		"the actual HUD Race button selects its family after a successful cargo reset")
	var cargo_owner := game.cargo_delivery_activity
	var cargo_generation := cargo_owner.get_generation()
	for kind: StringName in [GameFlow.ACTIVITY_KIND_PATROL, GameFlow.ACTIVITY_KIND_CARGO_DELIVERY,
			GameFlow.ACTIVITY_KIND_CONVOY_ESCORT, GameFlow.ACTIVITY_KIND_TIMED_RACE]:
		var button := (hud.get("_activity_selection_buttons") as Dictionary).get(kind) as Button
		_check(button != null and not button.disabled, "safe reset exposes the ordinary %s HUD choice" % kind)
		button.pressed.emit()
		var chosen := game.get_activity_integration_report()
		_check(chosen.selected_activity_kind == kind and int(chosen.attached_route_owner_count) <= 1
			and game.cargo_delivery_activity == cargo_owner and cargo_owner.get_generation() == cargo_generation
			and _manifest_quantity(chosen.cargo_source_manifest) == 0
			and _manifest_quantity(chosen.cargo_destination_manifest) == 6,
			"ordinary %s HUD adoption preserves depleted cargo, generation and one route owner" % kind)



func _test_saved_cargo_reentry(saved_generation: int) -> void:
	var fresh := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	fresh.configure_runtime_settings_persistence(store, "user://cargo-delivery-production-legacy.cfg")
	root.add_child(fresh)
	await process_frame
	await physics_frame
	await process_frame
	fresh.set_physics_process(false)
	var report := fresh.get_activity_integration_report()
	_check(bool((fresh.get("_jovian_cargo_session_restore_status") as Dictionary).get("accepted", false))
		and fresh.cargo_delivery_activity.get_generation() == saved_generation
		and fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
		and _manifest_quantity(report.cargo_source_manifest) == 0
		and _manifest_quantity(report.cargo_destination_manifest) == 6,
		"fresh Main restores the actual reset generation and depleted conserved freight pair without refilling")
	var before := fresh.cargo_delivery_activity.capture_persistence_state()
	var malformed := {"schema_version": 1, "activities": [{"activity_id": "jovian_fabrication_kit_delivery",
		"reward_requested": false, "reward_granted": false, "progress": {}, "wrong_generation": 1, "wrong_state": 0}]}
	var rejected := (fresh.get("_jovian_cargo_session_persistence") as JovianCargoSessionPersistence).validate_record(
		malformed, fresh.cargo_delivery_activity, fresh.cargo_transfer_authority)
	_check(not bool(rejected.accepted) and fresh.cargo_delivery_activity.capture_persistence_state() == before,
		"a wrong-shape six-key saved cargo row is rejected without script errors or owner mutation")
	var hud := fresh.get_node("HUD") as GameHUD
	var cargo_button := (hud.get("_activity_selection_buttons") as Dictionary).get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button
	cargo_button.pressed.emit()
	_check(fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and fresh.cargo_delivery_activity.get_generation() == saved_generation,
		"fresh Main ordinary Cargo button adopts its exact saved IDLE owner")
	await _clean_up(fresh)


func _make_disk_game(path: String, filesystem: UserDataFilesystem) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(Store.new(path, filesystem), "user://jovian-crash-legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	return game


func _cargo_receipts(game: GameFlow) -> int:
	return int((game.get_activity_reward_report().authority.record.get("reward_counts", {}) as Dictionary).get("return_fabrication_kits_to_shipyard", 0))


func _prepare_cargo_sortie(game: GameFlow) -> void:
	game.active_ship = _find_ship(game, &"jovian_provisional")
	game.active_ship.set_piloted(true)
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT


func _commit_unrelated_transfer(game: GameFlow, suffix: String) -> bool:
	var source := Node.new()
	var destination := Node.new()
	game.add_child(source)
	game.add_child(destination)
	var authority := game.cargo_transfer_authority
	var source_record := authority.register_entity(source, StringName("aux_source_" + suffix), StringName("aux_source_manifest_" + suffix), 4,
		{GameFlow.CARGO_DELIVERY_ITEM_ID: 1})
	var destination_record := authority.register_entity(destination, StringName("aux_destination_" + suffix), StringName("aux_destination_manifest_" + suffix), 4)
	var receipt := authority.transfer(StringName("aux_transfer_" + suffix), source_record.handle, destination_record.handle, GameFlow.CARGO_DELIVERY_ITEM_ID, 1)
	return bool(receipt.accepted) and authority.get_quantity(destination_record.handle, GameFlow.CARGO_DELIVERY_ITEM_ID) == 1


func _test_interrupted_cargo_recovery() -> void:
	const path := "user://jovian-interrupted-session.json"
	var first_filesystem := InterruptedRewardFilesystem.new()
	var first := await _make_disk_game(path, first_filesystem)
	var first_hud := first.get_node("HUD") as GameHUD
	first.active_ship = first.get_flyable_ships()[1]
	first.active_ship.set_piloted(true)
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var earlier_race := first.request_activity_start(GameFlow.DEFAULT_FREE_FLIGHT_ACTIVITY_ID)
	_check(bool(earlier_race.accepted) and first.reset_active_activity()
		and first.get_cinder_race_session_persistence_report().last_save_status.accepted,
		"a genuine earlier Main race reset leaves an admissible saved IDLE route before cargo starts")
	(first_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
	_prepare_cargo_sortie(first)
	_check(_commit_unrelated_transfer(first, "prior"), "an unrelated actual cargo transfer precedes the saved Main contract")
	var started := first.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var generation := first.cargo_delivery_activity.get_generation()
	first.cargo_delivery_activity.advance_physics(0.75, generation)
	var saved := first.save_jovian_cargo_session()
	var active_capture := first.cargo_delivery_activity.capture_persistence_state()
	var active_primary := FileAccess.get_file_as_bytes(path)
	_check(bool(started.accepted) and bool(saved.accepted) and int(active_capture.next_phase_index) == 1,
		"actual departed Jovian cargo saves its live phase, clock and generation to real disk (%s)" % saved.get("reason", ""))
	if not bool(saved.accepted):
		await _clean_up(first)
		return
	first_filesystem.stopped = true
	await _clean_up(first)

	var completion_filesystem := InterruptedRewardFilesystem.new()
	var resumed := await _make_disk_game(path, completion_filesystem)
	var resumed_report := resumed.get_activity_integration_report()
	_check(resumed.cargo_delivery_activity.capture_persistence_state() == active_capture
		and resumed_report.selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and resumed.get_cinder_race_session_persistence_report().restore_status.reason == &"jovian_cargo_session_has_priority"
		and _manifest_quantity(resumed_report.cargo_source_manifest) == 6
		and _manifest_quantity(resumed_report.cargo_destination_manifest) == 0,
		"fresh Main restores exact mid-ACTIVE cargo phase/time/identity and conserved untransferred inventory")
	_prepare_cargo_sortie(resumed)
	_check(_commit_unrelated_transfer(resumed, "current"), "current unrelated containers and receipts remain independently authority-owned after cargo startup restore")
	var completed := bool(resumed.call("_complete_cargo_delivery_on_return"))
	var resumed_store := resumed.get("_runtime_settings_user_data_store") as UserDataStore
	var terminal := resumed_store.get_snapshot().get("jovian_cargo_session", {}) as Dictionary
	_check(completed and completion_filesystem.reward_rejected and completion_filesystem.stopped
		and _cargo_receipts(resumed) == 0 and int(terminal.activities[0].state) == CargoDeliveryActivity.State.COMPLETED
		and bool(terminal.activities[0].reward_requested) and not bool(terminal.activities[0].reward_granted),
		"genuine transfer publishes durable unpaid completion before its real reward write is rejected")
	await _clean_up(resumed)

	var retry_filesystem := InterruptedRewardFilesystem.new()
	var fresh := await _make_disk_game(path, retry_filesystem)
	var pending := fresh.get_activity_integration_report()
	_check(fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.COMPLETED
		and fresh.cargo_delivery_activity.get_generation() == generation and _cargo_receipts(fresh) == 0
		and _manifest_quantity(pending.cargo_source_manifest) == 4 and _manifest_quantity(pending.cargo_destination_manifest) == 2
		and retry_filesystem.reward_rejected and not fresh.reset_active_activity(),
		"fresh Main keeps the exact owed delivery and transferred pair while failed retries block reset")
	var pending_hud := fresh.get_node("HUD") as GameHUD
	var race_button := pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_TIMED_RACE) as Button
	race_button.pressed.emit()
	_check(race_button.disabled and fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY,
		"an unpaid cargo owner cannot be replaced through the ordinary Race HUD request")
	retry_filesystem.interrupt_rewards = false
	retry_filesystem.stopped = false
	fresh.call("_retry_owed_game_flow_activity_rewards")
	var fresh_store := fresh.get("_runtime_settings_user_data_store") as UserDataStore
	_check(_cargo_receipts(fresh) == 1 and fresh_store.get_snapshot().jovian_cargo_session.activities[0].reward_granted,
		"retry atomically acknowledges the exact completed delivery with one saved reward receipt")
	var paid_primary := FileAccess.get_file_as_bytes(path)
	var unpaid_backup := FileAccess.get_file_as_bytes(path + ".bak")
	var owner := fresh.cargo_delivery_activity
	var before := owner.capture_persistence_state()
	var before_inventory := fresh.cargo_transfer_authority.to_dictionary()
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var reset_events := {"count": 0}
	owner.activity_reset.connect(func(_snapshot: Dictionary) -> void: reset_events.count += 1)
	retry_filesystem.reject_writes = true
	_check(not fresh.reset_active_activity() and fresh.cargo_delivery_activity == owner
		and owner.capture_persistence_state() == before and fresh.cargo_transfer_authority.to_dictionary() == before_inventory
		and FileAccess.get_file_as_bytes(path) == before_bytes and int(reset_events.count) == 0,
		"rejected cargo reset commit retains exact owner, quantities, ledger, disk bytes and unpublished lifecycle")
	retry_filesystem.reject_writes = false
	_check(fresh.reset_active_activity() and int(reset_events.count) == 1 and owner.get_generation() == generation + 1,
		"accepted cargo reset durably publishes one typed IDLE generation")
	var idle_bytes := FileAccess.get_file_as_bytes(path)
	retry_filesystem.reject_writes = true
	_prepare_cargo_sortie(fresh)
	var next_start := fresh.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(bool(next_start.accepted) and owner.get_generation() == generation + 2
		and bool(fresh.call("_complete_cargo_delivery_on_return")) and _cargo_receipts(fresh) == 1
		and FileAccess.get_file_as_bytes(path) == idle_bytes,
		"a genuine next delivery completes its transfer while every start, phase and terminal write fails after saved IDLE")
	var interrupted_inventory := fresh.get_activity_integration_report()
	_check(owner.get_state() == CargoDeliveryActivity.State.COMPLETED
		and _manifest_quantity(interrupted_inventory.cargo_source_manifest) == 2
		and _manifest_quantity(interrupted_inventory.cargo_destination_manifest) == 4
		and not fresh.reset_active_activity()
		and not bool(fresh.select_activity_kind(GameFlow.ACTIVITY_KIND_TIMED_RACE).accepted),
		"the unpaid live transfer conserves remaining kits and cannot reset or switch away during the write failure")
	retry_filesystem.reject_writes = false
	var unpaid_capture := owner.capture_persistence_state()
	var unpaid_reset := owner.reset_with_persistence(owner.get_generation(), fresh.save_jovian_cargo_session)
	_check(not bool(unpaid_reset.accepted) and owner.capture_persistence_state() == unpaid_capture
		and FileAccess.get_file_as_bytes(path) == idle_bytes and _cargo_receipts(fresh) == 1,
		"the codec refuses an unpaid completed source even inside a genuine staged reset after writes recover")
	fresh.call("_retry_owed_game_flow_activity_rewards")
	var recovered := fresh_store.get_snapshot().jovian_cargo_session.activities[0] as Dictionary
	_check(_cargo_receipts(fresh) == 2 and int(recovered.generation) == owner.get_generation()
		and int(recovered.state) == CargoDeliveryActivity.State.COMPLETED
		and bool(recovered.reward_requested) and bool(recovered.reward_granted),
		"ordinary retry recovers the actual next-generation completion and credits it once after writes recover (%s)" %
		(fresh.get("_jovian_cargo_session_save_status") as Dictionary).get("reason", ""))
	if _cargo_receipts(fresh) != 2:
		await _clean_up(fresh)
		return
	fresh.call("_retry_owed_game_flow_activity_rewards")
	_check(_cargo_receipts(fresh) == 2,
		"repeated retry does not replay the recovered transfer reward")
	var paid_snapshot := owner.get_snapshot()
	_check(fresh.reset_active_activity(), "second paid cargo resets before changing board family")
	var cargo_idle_generation := owner.get_generation()
	var patrol_button := pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_PATROL) as Button
	patrol_button.pressed.emit()
	fresh.active_ship = fresh.get_flyable_ships()[1]
	fresh.active_ship.set_piloted(true)
	fresh.phase = GameFlow.Phase.FREE_FLIGHT
	var patrol_start := fresh.request_activity_start(GameFlow.DEFAULT_FREE_FLIGHT_ACTIVITY_ID)
	var route := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
	for checkpoint in route.get_checkpoint_count():
		fresh.active_ship.global_position = route.get_checkpoint_position(checkpoint)
		fresh.call("_physics_process", 0.0)
		fresh.call("_physics_process", fresh.patrol_activity.dwell_seconds)
	_check(bool(patrol_start.accepted) and fresh.get_activity_reward_report().authority.record.last_receipt.activity_id == GameFlow.CINDER_PATROL_REWARD_ACTIVITY_ID,
		"a genuine later patrol owns the unrelated latest reward receipt")
	_check(fresh.reset_active_activity(), "the genuine patrol resets before cargo adoption")
	var cargo_button := pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button
	cargo_button.pressed.emit()
	fresh.call("_on_cargo_delivery_owner_completed", paid_snapshot, paid_snapshot.accepted_receipt, owner.get_instance_id())
	_check(fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and owner.get_generation() == cargo_idle_generation and _cargo_receipts(fresh) == 2,
		"ordinary cargo adoption and stale inactive completion preserve acknowledged credit after a different latest receipt")
	await _clean_up(fresh)

	var last_filesystem := InterruptedRewardFilesystem.new()
	last_filesystem.interrupt_rewards = false
	var last := await _make_disk_game(path, last_filesystem)
	var last_report := last.get_activity_integration_report()
	_check(last.cargo_delivery_activity.get_generation() == cargo_idle_generation
		and last.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
		and _manifest_quantity(last_report.cargo_source_manifest) == 2 and _manifest_quantity(last_report.cargo_destination_manifest) == 4
		and _cargo_receipts(last) == 2,
		"fresh Main retains the accepted cargo reset floor and remaining conserved kits after unrelated receipts")
	# Startup retains the validated patrol owner too; its saved IDLE may be selected.
	(last.get_node("HUD").get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
	_prepare_cargo_sortie(last)
	var last_start := last.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(bool(last_start.accepted) and last.cargo_delivery_activity.get_generation() == cargo_idle_generation + 1
		and bool(last.call("_complete_cargo_delivery_on_return")) and _cargo_receipts(last) == 3,
		"restart then ordinary next delivery transfers the final actual kits and grants its new generation once")
	await _clean_up(last)
	await _test_cargo_fallback_refusal(active_primary, unpaid_backup, paid_primary, generation)


func _test_cargo_fallback_refusal(active: PackedByteArray, unpaid: PackedByteArray,
		paid: PackedByteArray, generation: int) -> void:
	for kind: String in ["active", "unpaid"]:
		var path := "user://jovian-fallback-%s-%d.json" % [kind, Time.get_ticks_usec()]
		var fallback := active if kind == "active" else unpaid
		var older: Dictionary = JSON.parse_string(fallback.get_string_from_utf8()).payload.jovian_cargo_session.activities[0]
		var newer: Dictionary = JSON.parse_string(paid.get_string_from_utf8()).payload.jovian_cargo_session.activities[0]
		_check(int(older.state) == (CargoDeliveryActivity.State.ACTIVE if kind == "active" else CargoDeliveryActivity.State.COMPLETED)
			and not older.reward_granted and newer.reward_granted and int(newer.generation) == generation,
			"fallback fixture retains genuine older %s and newer paid cargo documents" % kind)
		var writer := FileAccess.open(path + ".paid-witness", FileAccess.WRITE)
		writer.store_buffer(paid)
		writer.close()
		writer = FileAccess.open(path, FileAccess.WRITE)
		writer.store_string("corrupt newer paid Jovian primary")
		writer.close()
		writer = FileAccess.open(path + ".bak", FileAccess.WRITE)
		writer.store_buffer(fallback)
		writer.close()
		var preflight := Store.new(path) as UserDataStore
		_check(preflight.load().accepted and preflight.get_loaded_source() == &"backup",
			"the existing store selects and quarantines the genuinely corrupt cargo primary")
		var artifacts := _cargo_recovery_artifacts(path)
		_check(artifacts.get(path + ".recovery") == "corrupt newer paid Jovian primary".to_utf8_buffer(),
			"the original corrupt primary remains an exact recovery witness")
		for attempt in 2:
			var game := await _make_disk_game(path, UserDataFilesystem.new())
			var report := game.get_activity_integration_report()
			var shared := game.get("_runtime_settings_user_data_store") as UserDataStore
			_check(game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
				and game.cargo_delivery_activity.get_generation() == 0
				and _manifest_quantity(report.cargo_source_manifest) == 6
				and _manifest_quantity(report.cargo_destination_manifest) == 0
				and (game.get("_owed_game_flow_activity_rewards") as Array).is_empty(),
				"fresh Main refuses %s fallback lifecycle, inventory and earned-debt adoption" % kind)
			var before := game.cargo_delivery_activity.capture_persistence_state()
			var before_receipts := _cargo_receipts(game)
			var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY)
			var started := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
			var reset := game.reset_active_activity()
			var after_selection := game.get_activity_integration_report()
			_check(not bool(selected.accepted) and selected.reason == &"outgoing_family_save_rejected"
				and after_selection.selected_activity_kind == report.selected_activity_kind
				and after_selection.active_activity_id == report.active_activity_id
				and not bool(started.accepted) and started.reason == &"unsupported_activity" and not reset
				and game.cargo_delivery_activity.capture_persistence_state() == before
				and after_selection.cargo_source_manifest == report.cargo_source_manifest
				and after_selection.cargo_destination_manifest == report.cargo_destination_manifest
				and (game.get("_owed_game_flow_activity_rewards") as Array).is_empty()
				and _cargo_recovery_artifacts(path) == artifacts,
				"ordinary cargo selection, Start and Reset cannot adopt fallback progress or publish a reset")
			var authority := game.get("_game_flow_reward_authority") as GameFlowRewardAuthority
			var payment := authority.commit({"activity_id": GameFlow.CARGO_DELIVERY_ACTIVITY_ID,
				"activity_generation": generation, "reward_id": GameFlowRewardAuthority.CARGO_REWARD_ID,
				"reward_authority": false, "granted": false})
			print("JOVIAN_FALLBACK_REFUSAL ", {"kind": kind, "attempt": attempt,
				"restored_state": game.cargo_delivery_activity.get_state(),
				"restore": game.get("_jovian_cargo_session_restore_status"),
				"selection": selected, "start": started, "reset": reset, "payment": payment, "source": shared.get_loaded_source()})
			_check(not payment.accepted and payment.reason == &"reward_store_recovery_required"
				and game.cargo_delivery_activity.capture_persistence_state() == before
				and _cargo_receipts(game) == before_receipts and shared.get_loaded_source() == &"backup"
				and _cargo_recovery_artifacts(path) == artifacts,
				"direct cargo payment refuses %s fallback across fresh Main without changing artifacts" % kind)
			await _clean_up(game)
			_check(_cargo_recovery_artifacts(path) == artifacts,
				"cargo owner teardown preserves fallback and quarantine bytes for explicit recovery")


func _cargo_recovery_artifacts(path: String) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".bak.1", ".bak.2", ".bak.3", ".recovery", ".tmp", ".paid-witness"]:
		if FileAccess.file_exists(path + suffix):
			result[path + suffix] = FileAccess.get_file_as_bytes(path + suffix)
	return result


func _test_unsaved_cargo_reset_recovery() -> void:
	for terminal_kind: String in ["failed", "expired", "active_abort"]:
		var path := "user://jovian-unsaved-%s-session.json" % terminal_kind
		var filesystem := InterruptedRewardFilesystem.new()
		filesystem.interrupt_rewards = false
		var game := await _make_disk_game(path, filesystem)
		(game.get_node("HUD").get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
		_prepare_cargo_sortie(game)
		var paid_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		_check(bool(paid_start.accepted) and bool(game.call("_complete_cargo_delivery_on_return"))
			and _cargo_receipts(game) == 1 and game.reset_active_activity(),
			"a genuine paid cargo run saves reset IDLE before the unsaved %s run" % terminal_kind)
		var owner := game.cargo_delivery_activity
		var idle_generation := owner.get_generation()
		var idle_bytes := FileAccess.get_file_as_bytes(path)
		filesystem.reject_writes = true
		_prepare_cargo_sortie(game)
		var next_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		if terminal_kind == "failed":
			game.call("_fail_active_activity", &"ship_destroyed")
		elif terminal_kind == "expired":
			owner.advance_physics(180.0, owner.get_generation())
		var before := owner.capture_persistence_state()
		var before_inventory := game.cargo_transfer_authority.to_dictionary()
		var reset_events := {"count": 0}
		owner.activity_reset.connect(func(_snapshot: Dictionary) -> void: reset_events.count += 1)
		var expected_state := CargoDeliveryActivity.State.ACTIVE
		if terminal_kind == "failed":
			expected_state = CargoDeliveryActivity.State.FAILED
		elif terminal_kind == "expired":
			expected_state = CargoDeliveryActivity.State.EXPIRED
		_check(bool(next_start.accepted) and owner.get_generation() == idle_generation + 1
			and owner.get_state() == expected_state
			and not game.reset_active_activity() and game.cargo_delivery_activity == owner
			and owner.capture_persistence_state() == before and game.cargo_transfer_authority.to_dictionary() == before_inventory
			and FileAccess.get_file_as_bytes(path) == idle_bytes and int(reset_events.count) == 0 and _cargo_receipts(game) == 1,
			"rejected unsaved %s reset retains exact live owner, conserved inventory, bytes and lifecycle" % terminal_kind)
		filesystem.reject_writes = false
		if terminal_kind == "active_abort":
			var discarded := {"candidate": null}
			owner.reset_with_persistence(owner.get_generation(), func(candidate: CargoDeliveryActivity) -> Dictionary:
				discarded.candidate = candidate
				return {"accepted": false, "reason": &"reset_discarded"})
			var replay := (game.get("_jovian_cargo_session_persistence") as JovianCargoSessionPersistence).save(
				discarded.candidate, game.cargo_transfer_authority, "jovian-discarded-reset", owner)
			_check(not bool(replay.accepted) and replay.reason == &"unproven_jovian_generation"
				and owner.capture_persistence_state() == before and int(reset_events.count) == 0
				and FileAccess.get_file_as_bytes(path) == idle_bytes,
				"a genuine discarded scratch cannot replay a generation jump outside its owner handoff")
		var reset := game.reset_active_activity()
		_check(reset and owner.get_state() == CargoDeliveryActivity.State.IDLE and owner.get_generation() == idle_generation + 2
			and int(reset_events.count) == 1 and _cargo_receipts(game) == 1,
			"ordinary reset recovers the actual unsaved %s run without skipping owner generations (%s)" % [terminal_kind,
			(game.get("_jovian_cargo_session_save_status") as Dictionary).get("reason", "")])
		await _clean_up(game)
		if not reset:
			continue
		var fresh_filesystem := InterruptedRewardFilesystem.new()
		fresh_filesystem.interrupt_rewards = false
		var fresh := await _make_disk_game(path, fresh_filesystem)
		var restored := fresh.get_activity_integration_report()
		_check(fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
			and fresh.cargo_delivery_activity.get_generation() == idle_generation + 2
			and _manifest_quantity(restored.cargo_source_manifest) == 4 and _manifest_quantity(restored.cargo_destination_manifest) == 2
			and _cargo_receipts(fresh) == 1,
			"fresh Main retains the recovered %s reset generation and untransferred kits" % terminal_kind)
		(fresh.get_node("HUD").get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
		_prepare_cargo_sortie(fresh)
		var restarted := fresh.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		_check(bool(restarted.accepted) and fresh.cargo_delivery_activity.get_generation() == idle_generation + 3
			and bool(fresh.call("_complete_cargo_delivery_on_return")) and _cargo_receipts(fresh) == 2,
			"the next genuine delivery after recovered %s reset transfers remaining kits and pays its distinct identity once" % terminal_kind)
		await _clean_up(fresh)


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


func _find_minimap_marker(markers: Array, marker_id: StringName) -> Dictionary:
	for marker_variant in markers:
		if marker_variant is Dictionary \
				and marker_variant.get("id", &"") == marker_id:
			return (marker_variant as Dictionary).duplicate(true)
	return {}


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
