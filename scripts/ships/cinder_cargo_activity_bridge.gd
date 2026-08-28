class_name CinderCargoActivityBridge
extends RefCounted

## Caller-owned bridge from a flyable Cinder cargo craft to the authored cargo
## run. It validates identity, generation, anchors, and item IDs, then forwards
## intents to NearbySectorActivityBinding without owning movement, inventory,
## rewards, or the activity lifecycle.

const CRAFT_SCRIPT := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const CARGO_AUDIO_BINDING := preload("res://scripts/audio/cinder_cargo_transfer_audio_binding.gd")
const COMPONENT_ID: StringName = &"cinder_cargo_hauler"
const EXPECTED_CARGO_ID: StringName = &"cinder_supply_crates"
const CARGO_STATE_IDLE := 0
const CARGO_STATE_ACTIVE := 1
const CARGO_STATE_COMPLETED := 2
const CARGO_STATE_FAILED := 3
const CARGO_STATE_EXPIRED := 4

var _craft: Node
var _binding: Node
var _craft_instance_id := 0
var _binding_instance_id := 0
var _binding_generation := -1
var _bound := false
var _audio_binding: RefCounted


func bind(craft: Node, binding: Node) -> Dictionary:
	if _bound:
		return _result(false, &"already_bound")
	if not craft is CRAFT_SCRIPT or not is_instance_valid(craft) or not craft.is_inside_tree():
		return _result(false, &"invalid_cargo_craft")
	if not is_instance_valid(binding) or not binding.is_inside_tree():
		return _result(false, &"invalid_activity_binding")
	for method_name in [&"start_cargo_run", &"submit_cargo_phase", &"reset_cargo_run", &"get_snapshot"]:
		if not binding.has_method(method_name):
			return _result(false, &"incomplete_activity_binding")
	var candidate: Node = craft
	if StringName(candidate.get_meta(&"component_id", &"")) != COMPONENT_ID:
		return _result(false, &"craft_identity_mismatch")
	if StringName(candidate.get_meta(&"evidence_status", &"")) != &"NEW":
		return _result(false, &"craft_evidence_rejected")
	var anchors: Array = candidate.call("get_cargo_transfer_anchors")
	if anchors.size() != int(candidate.call("get_cargo_capacity")):
		return _result(false, &"anchor_contract_invalid")
	var snapshot: Dictionary = binding.call("get_snapshot")
	var cargo: Dictionary = snapshot.get("cargo", {}) as Dictionary
	var contract: Dictionary = cargo.get("contract", {}) as Dictionary
	if StringName(contract.get("item_id", &"")) != EXPECTED_CARGO_ID:
		return _result(false, &"cargo_item_mismatch")
	_craft = candidate
	_binding = binding
	_craft_instance_id = candidate.get_instance_id()
	_binding_instance_id = binding.get_instance_id()
	_binding_generation = int(cargo.get("generation", -1))
	_audio_binding = CARGO_AUDIO_BINDING.new()
	var audio_result: Dictionary = _audio_binding.attach(0)
	if not bool(audio_result.get("accepted", false)):
		_audio_binding = null
		return _result(false, &"audio_binding_failed")
	_sync_audio_generation(_binding_generation)
	_bound = true
	return _result(true, &"bound")


func start(anchor_id: StringName, cargo_id: StringName = EXPECTED_CARGO_ID) -> Dictionary:
	var validation := _validate_intent(anchor_id, cargo_id)
	if not bool(validation.get("accepted", false)):
		return validation
	var result: Dictionary = _binding.call("start_cargo_run")
	if bool(result.get("accepted", false)):
		_binding_generation = int(result.get("generation", _binding_generation))
		_sync_audio_generation(_binding_generation)
	return _decorate(result, anchor_id)


func submit_phase(phase_id: StringName, anchor_id: StringName, cargo_id: StringName = EXPECTED_CARGO_ID) -> Dictionary:
	var validation := _validate_intent(anchor_id, cargo_id)
	if not bool(validation.get("accepted", false)):
		return validation
	var result: Dictionary = _binding.call("submit_cargo_phase", phase_id)
	return _decorate(result, anchor_id)


func detach() -> Dictionary:
	if not _bound:
		return _result(false, &"not_bound")
	var snapshot: Dictionary = _binding.call("get_snapshot")
	var cargo: Dictionary = snapshot.get("cargo", {}) as Dictionary
	if int(cargo.get("generation", -1)) != _binding_generation:
		return _result(false, &"stale_generation")
	var cleanup := _detach_cargo_cleanup(cargo)
	if not bool(cleanup.get("accepted", false)):
		return cleanup
	if _audio_binding != null:
		_audio_binding.unregister_audio_director()
		_audio_binding.detach()
	_audio_binding = null
	_bound = false
	_craft = null
	_binding = null
	_craft_instance_id = 0
	_binding_instance_id = 0
	_binding_generation = -1
	return cleanup


## Interrupted transfers leave CargoDeliveryActivity in a terminal failed or
## expired state. Reset those authoritative states before release so a later
## re-entry can start a new generation. Completed receipts deliberately remain
## untouched for the reward/persistence handoff.
func _detach_cargo_cleanup(cargo: Dictionary) -> Dictionary:
	match int(cargo.get("state", -1)):
		CARGO_STATE_IDLE:
			return _result(true, &"already_idle")
		CARGO_STATE_ACTIVE, CARGO_STATE_FAILED, CARGO_STATE_EXPIRED:
			return _binding.call("reset_cargo_run") as Dictionary
		CARGO_STATE_COMPLETED:
			return _result(true, &"completion_retained")
		_:
			return _result(false, &"unknown_cargo_state")


func get_snapshot() -> Dictionary:
	return {
		"bound": _bound,
		"craft_instance_id": _craft_instance_id,
		"binding_instance_id": _binding_instance_id,
		"binding_generation": _binding_generation,
		"cargo_item_id": EXPECTED_CARGO_ID,
		"movement_authority": false,
		"inventory_authority": false,
		"reward_authority": false,
		"flight_authority": false,
		"audio": _audio_binding.get_snapshot() if _audio_binding != null else {"attached": false},
	}.duplicate(true)


## Forwards one caller-validated cargo receipt to presentation only. The
## bridge never manufactures transfer authority or reward outcomes.
func present_audio_receipt(receipt: Dictionary) -> Dictionary:
	if _audio_binding == null:
		return _result(false, &"audio_binding_unavailable")
	return _audio_binding.present_transfer_receipt(receipt)

func register_audio_director(audio_director: Node) -> Dictionary:
	if _audio_binding == null:
		return _result(false, &"audio_binding_unavailable")
	return _audio_binding.register_audio_director(audio_director)

func unregister_audio_director() -> Dictionary:
	if _audio_binding == null:
		return _result(true, &"already_unregistered")
	return _audio_binding.unregister_audio_director()


func _sync_audio_generation(target_generation: int) -> void:
	if _audio_binding == null or target_generation < 0:
		return
	var audio_snapshot := _audio_binding.get_snapshot() as Dictionary
	var current := int(audio_snapshot.get("generation", -1))
	while current < target_generation:
		if bool(audio_snapshot.get("attached", false)):
			_audio_binding.detach()
		else:
			_audio_binding.attach(current)
		audio_snapshot = _audio_binding.get_snapshot() as Dictionary
		current = int(audio_snapshot.get("generation", -1))
	if current == target_generation and not bool(audio_snapshot.get("attached", false)):
		_audio_binding.attach(current)


func _validate_intent(anchor_id: StringName, cargo_id: StringName) -> Dictionary:
	if not _bound or not is_instance_valid(_craft) or not is_instance_valid(_binding):
		return _result(false, &"not_bound")
	if _craft.get_instance_id() != _craft_instance_id or _binding.get_instance_id() != _binding_instance_id:
		return _result(false, &"binding_identity_changed")
	if not _craft.is_inside_tree() or not _binding.is_inside_tree():
		return _result(false, &"binding_detached")
	if cargo_id != EXPECTED_CARGO_ID:
		return _result(false, &"cargo_item_mismatch")
	for anchor in _craft.call("get_cargo_transfer_anchors") as Array:
		if StringName(anchor.name) == anchor_id and StringName(anchor.get_meta(&"transfer_owner", &"")) == COMPONENT_ID:
			return {"accepted": true, "reason": &"intent_valid"}
	return _result(false, &"unknown_transfer_anchor")


func _decorate(result: Dictionary, anchor_id: StringName) -> Dictionary:
	var decorated := result.duplicate(true)
	decorated["bridge"] = {"anchor_id": anchor_id, "cargo_item_id": EXPECTED_CARGO_ID}
	return decorated


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
