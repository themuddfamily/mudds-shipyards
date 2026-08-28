extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const BindingType := preload("res://scripts/world/nearby_sector_activity_binding.gd")
const ConvoyHostType := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const ScanActivityType := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")

class BindingProbe extends Node3D:
	var starts: Array[StringName] = []
	var resets: Array[StringName] = []
	var patrol_actor_instance_id := 0
	var patrol_state := {
		"state_id": &"idle",
		"phase_id": &"idle",
		"generation": 0,
		"next_checkpoint_index": 0,
		"completed_checkpoint_count": 0,
		"checkpoint_count": 5,
	}

	func get_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"activity_id": &"nearby",
			"host": {"activity": {"state_id": &"available"}},
			"patrol": patrol_state.duplicate(true),
			"generation": 3,
		}

	func start_race() -> Dictionary:
		starts.append(&"cinder_reach_checkpoint_route")
		return {"accepted": true, "reason": &"started", "snapshot": get_snapshot()}

	func reset_race() -> Dictionary:
		resets.append(&"cinder_reach_checkpoint_route")
		return {"accepted": true, "reason": &"reset", "snapshot": get_snapshot()}

	func start_patrol(patrol_actor: Variant = null) -> Dictionary:
		starts.append(&"cinder_relay_patrol")
		patrol_actor_instance_id = (
			patrol_actor.get_instance_id() if patrol_actor is Node3D else 0
		)
		patrol_state.merge({
			"state_id": &"active",
			"phase_id": &"travel",
			"generation": int(patrol_state.get("generation", 0)) + 1,
		}, true)
		return {"accepted": true, "reason": &"started", "snapshot": get_snapshot()}

	func reset_patrol() -> Dictionary:
		resets.append(&"cinder_relay_patrol")
		patrol_state.merge({
			"state_id": &"idle",
			"phase_id": &"idle",
			"generation": int(patrol_state.get("generation", 0)) + 1,
		}, true)
		return {"accepted": true, "reason": &"reset", "snapshot": get_snapshot()}


class ClusterProbe extends Node3D:
	func _init() -> void:
		var binding := BindingProbe.new()
		binding.name = "ActivityBinding"
		add_child(binding)


class WorldProbe extends Node3D:
	var cluster := ClusterProbe.new()

	func _init() -> void:
		add_child(cluster)

	func get_nearby_sector_cluster() -> Node3D:
		return cluster


class ProductionWorldProbe extends Node3D:
	var cluster := Node3D.new()

	func _init(binding: NearbySectorActivityBinding) -> void:
		cluster.name = "NearbySectorCluster"
		binding.name = "ActivityBinding"
		cluster.add_child(binding)
		add_child(cluster)

	func get_nearby_sector_cluster() -> Node3D:
		return cluster


class ShipProbe extends HeroShip:
	func _ready() -> void:
		pass


class HudProbe extends CanvasLayer:
	var snapshots: Array[Dictionary] = []
	var cleared := 0

	func set_nearby_activity_snapshot(snapshot: Dictionary) -> void:
		snapshots.append(snapshot.duplicate(true))

	func clear_nearby_activity_snapshot() -> void:
		cleared += 1


var _assertions := 0
var _failures: PackedStringArray = []
var _scan_reward_accept := false
var _scan_reward_requests: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var flow := GameFlowType.new()
	var world := WorldProbe.new()
	var hud := HudProbe.new()
	flow.world = world
	flow.hud = hud
	flow._sync_nearby_activity_hud()
	_check(hud.snapshots.size() == 1 and hud.snapshots[0].activity_id == &"nearby", "binding snapshot reaches retained HUD")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"start_requested", "activity_id": &"cinder_reach_checkpoint_route"})
	var binding := world.cluster.get_node(^"ActivityBinding") as BindingProbe
	_check(binding.starts == [&"cinder_reach_checkpoint_route"], "start intent routes through binding authority")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"reset_requested", "activity_id": &"cinder_reach_checkpoint_route"})
	_check(binding.resets == [&"cinder_reach_checkpoint_route"], "reset intent routes through binding authority")
	flow._on_hud_nearby_activity_intent_requested({"reason": &"start_requested", "activity_id": &"unknown"})
	_check(binding.starts.size() == 1, "unknown activity cannot invoke a binding method")
	flow.world = null
	flow._sync_nearby_activity_hud()
	_check(
		hud.cleared == 0
			and not bool(hud.snapshots[-1].get("binding_available", true)),
		"an unloaded cluster replaces stale progress with the retained out-of-range snapshot",
	)

	var retained_hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(retained_hud)
	var active_ship := ShipProbe.new()
	root.add_child(active_ship)
	await process_frame
	flow.world = world
	flow.hud = retained_hud
	flow.active_ship = active_ship
	retained_hud.nearby_activity_intent_requested.connect(
		flow._on_hud_nearby_activity_intent_requested
	)
	flow._sync_nearby_activity_hud()
	var patrol_row := _activity_row(retained_hud, &"cinder_relay_patrol")
	var start_button := patrol_row.get_child(2) as Button if patrol_row != null else null
	_check(
		patrol_row != null
			and start_button != null
			and _activity_text(patrol_row).contains("AVAILABLE")
			and _activity_text(patrol_row).contains("PATROL READY"),
		"the retained HUD exposes the public AVAILABLE patrol action",
	)
	if start_button != null:
		start_button.emit_signal(&"pressed")
	patrol_row = _activity_row(retained_hud, &"cinder_relay_patrol")
	_check(
		binding.starts == [&"cinder_reach_checkpoint_route", &"cinder_relay_patrol"]
			and binding.patrol_actor_instance_id == active_ship.get_instance_id()
			and StringName(binding.patrol_state.get("state_id", &"")) == &"active"
			and StringName(binding.patrol_state.get("phase_id", &"")) == &"travel"
			and _activity_text(patrol_row).contains("ACTIVE")
			and _activity_text(patrol_row).contains("APPROACH BEACON 1/5"),
		"the real retained START button routes through GameFlow to ACTIVE/TRAVEL",
	)
	var reset_button := patrol_row.get_child(3) as Button if patrol_row != null else null
	if reset_button != null:
		reset_button.emit_signal(&"pressed")
	_check(
		reset_button != null
			and reset_button.text == "CONFIRM RESET"
			and binding.resets == [&"cinder_reach_checkpoint_route"],
		"the first retained RESET press preserves the active patrol for confirmation",
	)
	if reset_button != null:
		reset_button.emit_signal(&"pressed")
	patrol_row = _activity_row(retained_hud, &"cinder_relay_patrol")
	_check(
		binding.resets == [&"cinder_reach_checkpoint_route", &"cinder_relay_patrol"]
			and StringName(binding.patrol_state.get("state_id", &"")) == &"idle"
			and _activity_text(patrol_row).contains("AVAILABLE")
			and _activity_text(patrol_row).contains("PATROL READY"),
		"the confirmed retained RESET routes through GameFlow back to AVAILABLE",
	)

	var production_binding := BindingType.new() as NearbySectorActivityBinding
	production_binding.add_child(ConvoyHostType.new())
	var production_world := ProductionWorldProbe.new(production_binding)
	root.add_child(production_world)
	var production_convoy_host := ConvoyHostType.new() as CinderConvoyEscortHost
	root.add_child(production_convoy_host)
	await process_frame
	var scan_reward_handoff := production_binding.configure_structure_scan_reward_handoff(
		Callable(self, &"_commit_scan_reward")
	)
	_check(
		bool(scan_reward_handoff.get("accepted", false)),
		"the streamed scan accepts one caller-owned production reward handoff",
	)
	flow.world = production_world
	flow.cinder_convoy_host = production_convoy_host
	active_ship.global_position = Vector3.ZERO
	flow._sync_nearby_activity_hud()
	var scan_row := _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var scan_start := scan_row.get_child(2) as Button if scan_row != null else null
	_check(
		scan_start != null
			and _activity_text(scan_row).contains("SCAN READY")
			and _activity_text(scan_row).contains("APPROACH DERELICT DATUM"),
		"the real retained scan row begins with its public approach state",
	)
	if scan_start != null:
		scan_start.emit_signal(&"pressed")
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var rejected_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		StringName(rejected_scan.get("presentation_reason", &"")) \
				== &"outside_scan_approach"
			and _activity_text(scan_row).contains(
				"WRONG POSITION  //  MOVE TO DERELICT SCAN MARKER"
			),
		"a rejected real START refreshes the retained row with recovery guidance",
	)

	active_ship.global_position = ScanActivityType.APPROACH_ANCHOR
	scan_start = scan_row.get_child(2) as Button if scan_row != null else null
	if scan_start != null:
		scan_start.emit_signal(&"pressed")
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var active_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		int(active_scan.get("state", -1)) == 1
			and StringName(active_scan.get("presentation_reason", &"stale")).is_empty()
			and _activity_text(scan_row).contains("SCANNING STRUCTURE  //  0%"),
		"a subsequent valid real START clears rejection feedback and reaches SCANNING",
	)

	active_ship.global_position = (
		ScanActivityType.APPROACH_ANCHOR
		+ Vector3(ScanActivityType.INTERACTION_RADIUS + 1.0, 0.0, 0.0)
	)
	var paused_step := flow._advance_cinder_structure_scan(
		1.0, _ship_sample(active_ship)
	)
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var paused_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		not bool(paused_step.get("accepted", true))
			and paused_step.get("reason", &"") == &"outside_scan_approach"
			and is_zero_approx(float(paused_scan.get("elapsed_seconds", -1.0)))
			and _activity_text(scan_row).contains("MOVE TO DERELICT SCAN MARKER")
			and "PAUSED — RETURN TO MARKER" in str(
				retained_hud.get_activity_objective_report().get("text", "")
			),
		"leaving the authored hold sphere pauses progress and updates both HUD surfaces",
	)

	active_ship.global_position = ScanActivityType.APPROACH_ANCHOR
	var half_step := flow._advance_cinder_structure_scan(
		2.0, _ship_sample(active_ship)
	)
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var half_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		bool(half_step.get("accepted", false))
			and is_equal_approx(float(half_scan.get("elapsed_seconds", 0.0)), 2.0)
			and _activity_text(scan_row).contains("SCANNING STRUCTURE  //  50%")
			and "DERELICT SCAN  50%  HOLD 2.0s" in str(
				retained_hud.get_activity_objective_report().get("text", "")
			),
		"returning to the marker resumes the exact hold and publishes live progress",
	)

	var completed_step := flow._advance_cinder_structure_scan(
		2.0, _ship_sample(active_ship)
	)
	var rejected_reward := completed_step.get("reward_result", {}) as Dictionary
	var completed_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		bool(completed_step.get("accepted", false))
			and completed_step.get("reason", &"") == &"complete"
			and not bool(rejected_reward.get("accepted", true))
			and rejected_reward.get("reason", &"") \
				== &"structure_scan_reward_handoff_rejected"
			and not bool(completed_scan.get("reward_requested", true))
			and "COMPLETE — CLAIM SAMPLE" in str(
				retained_hud.get_activity_objective_report().get("text", "")
			),
		"a rejected receipt leaves the completed scan unconsumed and visibly retryable",
	)
	_check(
		_scan_reward_requests.size() == 1
			and _scan_reward_requests[0].size() == 5
			and _scan_reward_requests[0].activity_id \
				== &"cinder_derelict_structure_scan"
			and int(_scan_reward_requests[0].activity_generation) == 1
			and _scan_reward_requests[0].reward_id == &"derelict_material_sample"
			and not bool(_scan_reward_requests[0].reward_authority)
			and not bool(_scan_reward_requests[0].granted),
		"completion emits the exact compact non-authoritative reward request",
	)

	_scan_reward_accept = true
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	scan_start = scan_row.get_child(2) as Button if scan_row != null else null
	if scan_start != null:
		scan_start.emit_signal(&"pressed")
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var rewarded_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		scan_start != null
			and _scan_reward_requests.size() == 2
			and bool(rewarded_scan.get("reward_requested", false))
			and bool(rewarded_scan.get("reward_committed", false))
			and not bool(rewarded_scan.get("reward_pending", true))
			and _activity_text(scan_row).contains("MATERIAL SAMPLE RECEIPT SAVED")
			and not bool(
				retained_hud.get_activity_objective_report().get("visible", true)
			),
		"the same public Start action retries once, records the sample, and clears stale flight HUD",
	)

	var scan_reset := scan_row.get_child(3) as Button if scan_row != null else null
	if scan_reset != null:
		scan_reset.emit_signal(&"pressed")
	_check(
		scan_reset != null and scan_reset.text == "RESET",
		"the completed recorded scan resets without an unnecessary confirmation",
	)
	scan_row = _activity_row(retained_hud, &"cinder_derelict_structure_scan")
	var reset_scan := (
		production_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true)
	_check(
		int(reset_scan.get("state", -1)) == 3
			and StringName(reset_scan.get("presentation_reason", &"stale")).is_empty()
			and _activity_text(scan_row).contains("INTERRUPTED  //  PROGRESS RESET"),
		"the confirmed real RESET clears feedback and reaches the normal reset state",
	)

	flow.hud = null
	flow.active_ship = null
	flow.world = null
	flow.cinder_convoy_host = null
	retained_hud.queue_free()
	active_ship.queue_free()
	production_world.queue_free()
	production_convoy_host.queue_free()
	hud.free()
	world.free()
	flow.free()
	for _frame in 3:
		await process_frame
	if _failures.is_empty():
		print("NEARBY_ACTIVITY_GAME_FLOW_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _commit_scan_reward(request: Dictionary) -> Dictionary:
	_scan_reward_requests.append(request.duplicate(true))
	if not _scan_reward_accept:
		return {"accepted": false, "reason": &"simulated_store_rejection"}
	return {
		"accepted": true,
		"reason": &"reward_receipt_committed",
		"granted": true,
		"receipt": {
			"receipt_id": _scan_reward_requests.size(),
			"reward_label": "Derelict material sample recorded",
		},
	}.duplicate(true)


func _ship_sample(ship: HeroShip) -> Dictionary:
	return {
		"available": true,
		"actor_kind": &"ship",
		"actor_instance_id": ship.get_instance_id(),
		"position": ship.global_position,
	}.duplicate(true)


func _activity_row(hud: GameHUD, activity_id: StringName) -> Control:
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	for candidate in rows.get_children() if rows != null else []:
		if StringName(candidate.get_meta(&"activity_id", &"")) == activity_id:
			return candidate as Control
	return null


func _activity_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""
