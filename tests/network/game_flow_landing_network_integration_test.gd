extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const Ship := preload("res://scripts/ships/hero_ship.gd")
const ShipDefinition := preload("res://assets/ships/torrent_provisional.tres")
const Berth := preload("res://scripts/world/ship_berth.gd")

var _assertions := 0
var _failures := PackedStringArray()


class LandingAdapterProbe extends Adapter:
	var fail_release := false
	var fail_abort := false
	var fail_landed_publication := false
	var fail_flying_publication := false
	var abort_call_count := 0

	func release_server_landing(
		entity_id: StringName,
		entity_generation: int,
		lease_id: StringName,
	) -> Dictionary:
		if fail_release:
			return {"accepted": false, "status": &"injected_retirement_failure"}
		return super.release_server_landing(entity_id, entity_generation, lease_id)

	func abort_server_landing(
		entity_id: StringName,
		entity_generation: int,
		lease_id: StringName,
	) -> Dictionary:
		abort_call_count += 1
		if fail_abort:
			return {"accepted": false, "status": &"injected_abort_failure"}
		return super.abort_server_landing(entity_id, entity_generation, lease_id)

	func publish_landing_snapshot(
		entity_id: StringName,
		entity_generation: int,
		position: Vector3,
		state: StringName,
		recipients: Array = [],
		server_tick: int = 0,
	) -> Dictionary:
		if fail_landed_publication and state == &"landed":
			return {"accepted": false, "status": &"injected_landed_publication_failure"}
		if fail_flying_publication and state == &"flying":
			return {"accepted": false, "status": &"injected_flying_publication_failure"}
		return super.publish_landing_snapshot(
			entity_id, entity_generation, position, state, recipients, server_tick
		)


class LandingFlowProbe extends GameFlow:
	var planetary_completion_calls := 0

	func _complete_planetary_return_physical_arrival(
		berth: ShipBerth,
		landing_report: Dictionary,
	) -> Dictionary:
		planetary_completion_calls += 1
		_planetary_return_physical_arrival_required = false
		_landing_request_active = false
		_active_landing_berth_id = &""
		return {
			"accepted": is_instance_valid(berth)
				and bool(landing_report.get("strict_dock_acceptance", false)),
			"reason": &"injected_planetary_completion",
		}


class HudProbe extends CanvasLayer:
	var objective := ""
	var toast_title := ""

	func set_interaction(_text: String, _available: bool = true) -> void:
		pass

	func set_objective(text: String, _eyebrow: String = "") -> void:
		objective = text

	func toast(title: String, _detail: String = "", _duration: float = 0.0) -> void:
		toast_title = title


class LandingWorld extends Node3D:
	var berth: Node

	func get_berth_node(berth_id: StringName) -> Node:
		if berth != null and berth.call(&"get_berth_id") == berth_id:
			return berth
		return null


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := LandingAdapterProbe.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	var world := LandingWorld.new()
	var berth := Berth.new()
	berth.berth_id = &"network_landing_test_berth"
	world.berth = berth
	world.add_child(berth)
	root.add_child(world)
	var bomber := Ship.new()
	bomber.ship_definition = ShipDefinition
	root.add_child(bomber)
	await process_frame
	var hud := HudProbe.new()
	root.add_child(hud)
	var flow := LandingFlowProbe.new()
	flow.network_session = server
	flow._network_session_mode = &"server"
	flow.world = world
	flow.active_ship = bomber
	flow.hud = hud
	_check(flow._reserve_berth_for_ship(bomber, berth.get_berth_id(), false),
		"the real physical berth owns the pending lease before networking")
	var reserved := flow._begin_network_landing_handoff(bomber, berth)
	var pending_packet := (reserved.get("publication", {}) as Dictionary).get("packet", {}) as Dictionary
	var pending_entity := server.get_landing_entity(bomber.get_ship_id())
	_check(bool(reserved.get("accepted", false))
		and pending_entity.get("state") == &"landing_pending"
		and not StringName(pending_entity.get("lease_id", &"")).is_empty(),
		"GameFlow hands the exact physical reservation to server landing authority")
	_check((pending_packet.get("landing", {}) as Dictionary).get("state") == &"landing_pending",
		"pending presentation publishes only after the server reservation")
	var client := Adapter.new()
	var pending_applied := client.consume_landing_snapshot(pending_packet)
	_check(bool(pending_applied.get("accepted", false)),
		"client consumes the pending state as presentation only")
	_check(int(client.get_presentation_cursor_audit().get("landing_count", 0)) == 1,
		"client retains one landing presentation cursor")
	_check(client.commit_server_landing(
		bomber.get_ship_id(), 1, StringName(pending_entity.get("lease_id", &""))
	).get("status") == &"authority_required",
		"client cannot commit physical occupancy from its presentation cursor")
	var premature_commit := flow._commit_network_landing_handoff(bomber, berth)
	_check(premature_commit.get("status") == &"physical_berth_occupancy_mismatch"
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landing_pending",
		"server cannot publish landed before the physical berth is occupied")
	_check(berth.occupy(
		bomber, StringName(flow._berth_tokens.get(bomber.get_instance_id(), &""))
	), "physical berth commits occupancy before the network lifecycle")
	var committed := flow._commit_network_landing_handoff(bomber, berth)
	var landed_packet := (committed.get("publication", {}) as Dictionary).get("packet", {}) as Dictionary
	_check(bool(committed.get("accepted", false))
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landed"
		and (landed_packet.get("landing", {}) as Dictionary).get("state") == &"landed",
		"server commits and publishes landed only after exact physical occupancy")
	_check(bool(client.consume_landing_snapshot(landed_packet).get("accepted", false))
		and int(client.get_presentation_cursor_audit().get("landing_count", 0)) == 1,
		"client applies landed without acquiring berth or landing authority")
	server.fail_release = true
	var failed_departure := flow._mark_sortie_departed()
	_check(not bool(failed_departure.get("accepted", false))
		and failed_departure.get("status") == &"injected_retirement_failure"
		and berth.is_occupied() and berth.is_reserved()
		and not flow._sortie_departed_berth,
		"retirement failure keeps the physical berth occupied and departure retryable")
	_check((flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"landed"
		and hud.objective.contains("berth retained"),
		"failed retirement retains the committed handoff and exposes retry state")
	server.fail_release = false
	var departed := flow._mark_sortie_departed()
	var released := departed.get("network_release", {}) as Dictionary
	var flying_packet := (released.get("publication", {}) as Dictionary).get("packet", {}) as Dictionary
	var released_entity := server.get_landing_entity(bomber.get_ship_id())
	_check(bool(departed.get("accepted", false))
		and bool(released.get("accepted", false))
		and int(released.get("entity_generation", 0)) == 2
		and released_entity.get("state") == &"flying"
		and int(released_entity.get("entity_generation", 0)) == 2
		and not berth.is_occupied() and not berth.is_reserved(),
		"successful retry retires network occupancy before freeing the physical berth")
	_check(bool(client.consume_landing_snapshot(flying_packet).get("accepted", false))
		and int((flying_packet.get("landing", {}) as Dictionary).get("entity_generation", 0)) == 2,
		"client receives the newer flying generation as presentation only")
	_check(flow._reserve_berth_for_ship(bomber, berth.get_berth_id(), false)
		and bool(flow._begin_network_landing_handoff(bomber, berth).get("accepted", false)),
		"released target can admit a fresh physical reservation on the newer generation")
	flow._landing_request_active = true
	flow._active_landing_berth_id = berth.get_berth_id()
	server.fail_abort = true
	flow._on_landing_aborted(&"injected_abort", bomber)
	_check(flow._landing_request_active
		and flow._active_landing_berth_id == berth.get_berth_id()
		and berth.is_reserved()
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landing_pending",
		"rejected server abort retains landing flags and the physical reservation")
	_check((flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"landing_pending"
		and not bool(flow._last_network_landing_handoff_result.get("mutation_committed", true))
		and bool(flow._last_network_landing_handoff_result.get("retryable", false)),
		"rejected abort retains a retryable uncommitted network handoff")
	server.fail_abort = false
	server.fail_flying_publication = true
	flow._on_landing_aborted(&"injected_abort", bomber)
	_check(flow._landing_request_active and berth.is_reserved()
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"flying"
		and (flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"abort_pending_publication",
		"failed abort publication retains physical state and a resumable committed handoff")
	_check(server.abort_call_count == 2
		and bool(flow._last_network_landing_handoff_result.get("mutation_committed", false))
		and flow._last_network_landing_handoff_result.get("status") == &"network_landing_abort_publication_failed",
		"abort publication failure records committed mutation without clearing local state")
	server.fail_flying_publication = false
	flow._on_landing_aborted(&"injected_abort", bomber)
	_check(server.abort_call_count == 2
		and not flow._landing_request_active
		and flow._active_landing_berth_id.is_empty()
		and not berth.is_reserved()
		and not flow._network_landing_handoffs.has(bomber.get_ship_id()),
		"abort retry publishes flying without repeating mutation, then releases physical state")
	_check(flow._reserve_berth_for_ship(bomber, berth.get_berth_id(), false)
		and berth.occupy(
			bomber,
			StringName(flow._berth_tokens.get(bomber.get_instance_id(), &"")),
		), "planetary completion starts with exact physical occupancy and no network handoff")
	flow._landing_request_active = true
	flow._active_landing_berth_id = berth.get_berth_id()
	flow._planetary_return_physical_arrival_required = true
	flow.phase = GameFlow.Phase.RETURN_TO_YARD
	bomber._landing_berth_id = berth.get_berth_id()
	bomber._landing_contract = {
		"contract_accepted": true,
		"strict_dock_acceptance": true,
	}
	server.fail_landed_publication = true
	flow._on_landing_completed(bomber)
	var planetary_failure := flow._last_network_landing_handoff_result
	_check(not bool(planetary_failure.get("accepted", false))
		and bool(planetary_failure.get("mutation_committed", false))
		and bool(planetary_failure.get("retryable", false))
		and planetary_failure.get("status") == &"network_landing_commit_publication_failed",
		"planetary completion observes landed publication failure as retryable")
	_check(berth.is_occupied() and flow._landing_request_active
		and flow.planetary_completion_calls == 0
		and (flow._network_landing_handoffs.get(bomber.get_ship_id(), {}) as Dictionary).get("state") == &"landed",
		"planetary bypass begins the shared handoff and retains physical occupancy before terminal completion")
	server.fail_landed_publication = false
	flow._on_landing_completed(bomber)
	_check(flow.planetary_completion_calls == 1
		and bool(flow._last_network_landing_handoff_result.get("accepted", false))
		and server.get_landing_entity(bomber.get_ship_id()).get("state") == &"landed"
		and berth.is_occupied(),
		"planetary retry republishes the committed handoff then completes exactly once")
	_check(bool(flow._release_network_landing_handoff(bomber, berth).get("accepted", false)),
		"planetary test cleanup retires the committed network landing")
	flow._release_ship_berth(bomber)
	server.free()
	client.free()
	flow.free()
	hud.queue_free()
	bomber.queue_free()
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK: GameFlow landing network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
