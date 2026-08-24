extends SceneTree

const CRAFT := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const BRIDGE := preload("res://scripts/ships/cinder_cargo_activity_bridge.gd")


class CargoBindingFixture extends Node:
	var activity: CargoDeliveryActivity

	func _init(candidate: CargoDeliveryActivity) -> void:
		activity = candidate

	func get_snapshot() -> Dictionary:
		return {"cargo": activity.get_snapshot()}.duplicate(true)

	func start_cargo_run() -> Dictionary:
		return activity.start(activity.get_generation())

	func submit_cargo_phase(phase_id: StringName) -> Dictionary:
		return activity.submit_phase(phase_id, activity.get_generation())

	func reset_cargo_run() -> Dictionary:
		return activity.reset(activity.get_generation())

	func abort_cargo_run(expected_generation: int) -> Dictionary:
		return activity.fail(&"embodied_transfer_aborted", expected_generation)


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _build_fixture()
	var binding := CargoBindingFixture.new(fixture.activity)
	root.add_child(binding)
	var craft := CRAFT.new()
	root.add_child(craft)
	await process_frame
	var bridge := BRIDGE.new()
	var bound: Dictionary = bridge.bind(craft, binding)
	_check(bool(bound.get("accepted", false)), "bridge binds the flyable cargo craft to the authored activity")
	var anchor := StringName(craft.get_cargo_transfer_anchors()[0].name)
	var started: Dictionary = bridge.start(anchor)
	_check(bool(started.get("accepted", false)), "bridge forwards a validated cargo-run start intent")
	var rejected_anchor: Dictionary = bridge.submit_phase(&"load_crate", &"foreign_anchor")
	_check(not bool(rejected_anchor.get("accepted", true)) and rejected_anchor.get("reason", &"") == &"unknown_transfer_anchor", "foreign transfer anchors fail closed")
	var phase: Dictionary = bridge.submit_phase(&"load_crate", anchor)
	_check(bool(phase.get("accepted", false)), "bridge forwards a validated phase receipt")
	var interrupted: Dictionary = binding.abort_cargo_run(int(started.get("generation", -1)))
	_check(bool(interrupted.get("accepted", false)), "fixture interrupts the active transfer through existing cargo authority")
	var detached: Dictionary = bridge.detach()
	_check(
		bool(detached.get("accepted", false)) and detached.get("reason", &"") == &"reset",
		"detach resets an interrupted transfer before releasing the bridge"
	)
	_check(not bool(bridge.get_snapshot().get("bound", true)), "detach clears craft and binding identity")
	var rebound: Dictionary = bridge.bind(craft, binding)
	var restarted: Dictionary = bridge.start(anchor)
	var rebound_audio := bridge.get_snapshot().get("audio", {}) as Dictionary
	_check(
		bool(rebound.get("accepted", false)) and bool(restarted.get("accepted", false))
		and bool(rebound_audio.get("attached", false))
		and int(rebound_audio.get("generation", -1)) == int(restarted.get("generation", -2)),
		"re-entry starts a fresh cargo generation with matching receipt presentation"
	)
	bridge.detach()
	craft.queue_free()
	binding.queue_free()
	(fixture.authority as Node).queue_free()
	if _failures.is_empty():
		print("PASS cinder_cargo_activity_bridge_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_fixture() -> Dictionary:
	var authority := CargoTransferAuthority.new()
	root.add_child(authority)
	var item := CargoItemDefinition.new()
	item.item_id = &"cinder_supply_crates"
	item.display_name = "Cinder supply crates"
	item.unit_capacity = 1
	authority.register_item(item)
	var source := Node.new()
	var destination := Node.new()
	authority.add_child(source)
	authority.add_child(destination)
	var source_handle := authority.register_entity(
		source, &"source", &"source_manifest", 4, {&"cinder_supply_crates": 2}
	).handle as Dictionary
	var destination_handle := authority.register_entity(
		destination, &"destination", &"destination_manifest", 4
	).handle as Dictionary
	var contract := CargoDeliveryContract.new(
		&"cinder_platform_supply_run", source_handle, destination_handle,
		&"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0
	)
	return {
		"authority": authority,
		"activity": CargoDeliveryActivity.new(authority, contract),
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
