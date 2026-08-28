extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []
var _reward_accept := true

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	var fixture := _build_fixture()
	var activity := fixture.activity as CargoDeliveryActivity
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	binding.set("_cargo_activity", activity)

	var started := binding.start_cargo_run()
	var view := hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var row := _cargo_row(hud)
	var retained_id := row.get_instance_id() if row != null else 0
	_check(bool(started.accepted) and _cargo_text(row).contains("TIME NORMAL: 120.0s LEFT")
		and StringName((_cargo_card(view).cargo_progress as Dictionary).deadline_state) == &"normal",
		"active pickup begins with an explicit color-independent normal deadline")

	binding.advance_cargo_run(90.0)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	row = _cargo_row(hud)
	_check(row != null and row.get_instance_id() == retained_id
		and _cargo_text(row).contains("TIME WARNING: 30.0s LEFT")
		and StringName((_cargo_card(view).cargo_progress as Dictionary).deadline_state) == &"warning",
		"the authoritative 25 percent boundary updates the same row to warning")
	binding.advance_cargo_run(18.0)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(_cargo_text(_cargo_row(hud)).contains("TIME CRITICAL: 12.0s LEFT")
		and StringName((_cargo_card(view).cargo_progress as Dictionary).deadline_state) == &"critical",
		"the authoritative 10 percent boundary is readable without relying on color")

	binding.submit_cargo_phase(&"load_crate")
	var generation := int((binding.get_snapshot().cargo as Dictionary).generation)
	binding.abort_cargo_run(generation)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(_cargo_text(_cargo_row(hud)).contains(
		"LOST 2/3: CARGO RUN LOST DURING TRANSIT  //  RECOVER LOST CARGO: RETURN TO THE CINDER BERTH"
	) and str(_cargo_card(view).recovery_text).contains("RETURN TO THE CINDER BERTH"),
		"lost cargo names the interrupted transit phase and its recovery point")

	binding.reset_cargo_run()
	binding.start_cargo_run()
	binding.submit_cargo_phase(&"load_crate")
	binding.submit_cargo_phase(&"clear_gate")
	binding.advance_cargo_run(120.0)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(_cargo_text(_cargo_row(hud)).contains(
		"EXPIRED 3/3: DEADLINE EXPIRED DURING DELIVERY  //  RECOVER EXPIRED RUN: RESET AT THE PLATFORM TERMINAL"
	) and StringName((_cargo_card(view).cargo_progress as Dictionary).deadline_state) == &"expired",
		"expiry retains the delivery phase and directs recovery to the terminal")

	binding.reset_cargo_run()
	_complete(binding)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	_check(_cargo_text(_cargo_row(hud)).contains("DELIVERED 3/3: CARGO TRANSFER CONFIRMED  //  DELIVERY CONFIRMED")
		and not bool(_cargo_card(view).reward_pending),
		"delivered cargo remains confirmed when no reward request exists")

	binding.reset_cargo_run()
	var configured := binding.configure_cargo_reward_handoff(Callable(self, &"_accept_reward"))
	_complete(binding)
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	var pending_text := _cargo_text(_cargo_row(hud))
	var pending := _cargo_card(view).cargo_progress as Dictionary
	_check(bool(configured.accepted) and pending_text.contains(
		"DELIVERED 3/3: AWAIT CARGO REWARD HANDOFF  //  REWARD PENDING"
	) and pending_text.count("REWARD PENDING") == 1 and bool(pending.reward_pending)
		and not bool(pending.activity_authority) and not bool(pending.inventory_authority)
		and not bool(pending.reward_authority),
		"matching completion handoff presents one pending cue without new authority")

	binding.reset_cargo_run()
	_reward_accept = false
	_complete(binding)
	var retryable := binding.get_snapshot().cargo as Dictionary
	view = hud.set_nearby_activity_snapshot(binding.get_snapshot())
	hud.set_activity_objective("Platform supply run", retryable)
	_check(
		bool(retryable.get("reward_retry_available", false))
			and _cargo_text(_cargo_row(hud)).contains(
				"REWARD SAVE FAILED — START TO RETRY  //  SAVE FAILED — START TO RETRY"
			)
			and "START TO RETRY REWARD" in str(
				hud.get_activity_objective_report().get("text", "")
			)
			and bool((_cargo_card(view).cargo_progress as Dictionary).reward_pending),
		"a rejected reward receipt is visibly retryable on both retained and flight HUD surfaces"
	)

	hud.queue_free(); cluster.queue_free(); (fixture.authority as Node).queue_free()
	for _frame in 4: await process_frame
	for failure in _failures: push_error(failure)
	if _failures.is_empty(): print("CINDER_CARGO_URGENCY_RETAINED_FEEDBACK_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _build_fixture() -> Dictionary:
	var authority := CargoTransferAuthority.new()
	root.add_child(authority)
	var item := CargoItemDefinition.new()
	item.item_id = &"cinder_supply_crates"; item.display_name = "Cinder supply crates"; item.unit_capacity = 1
	authority.register_item(item)
	var source := Node.new(); var destination := Node.new()
	authority.add_child(source); authority.add_child(destination)
	var source_handle := authority.register_entity(source, &"source", &"source_manifest", 8,
		{&"cinder_supply_crates": 6}).handle as Dictionary
	var destination_handle := authority.register_entity(destination, &"destination", &"destination_manifest", 8).handle as Dictionary
	var contract := CargoDeliveryContract.new(&"cinder_platform_supply_run", source_handle,
		destination_handle, &"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0)
	return {"authority": authority, "activity": CargoDeliveryActivity.new(authority, contract)}

func _complete(binding: NearbySectorActivityBinding) -> void:
	binding.start_cargo_run()
	for phase_id: StringName in [&"load_crate", &"clear_gate", &"dock_platform"]:
		binding.submit_cargo_phase(phase_id)
	var activity := binding.get("_cargo_activity") as CargoDeliveryActivity
	activity.submit_transfer(activity.get_generation())

func _accept_reward(_request: Dictionary) -> Dictionary:
	return {"accepted": _reward_accept}

func _cargo_card(view: Dictionary) -> Dictionary:
	for candidate in view.get("cards", []) as Array:
		var card := candidate as Dictionary
		if StringName(card.get("activity_id", &"")) == &"cinder_platform_supply_run": return card
	return {}

func _cargo_row(hud: GameHUD) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_platform_supply_run" in str(candidate.name): return candidate as Control
	return null

func _cargo_text(row: Control) -> String: return str((row.get_child(0) as Label).text) if row != null else ""

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
