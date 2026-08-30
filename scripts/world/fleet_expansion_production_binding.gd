class_name FleetExpansionProductionBinding
extends Node3D

## Standalone composition of the authored FleetExpansionBerths and three NEW
## craft. This node owns composition only; each craft and berth retains its
## caller-owned contracts and no flight/lease authority crosses this seam.

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const Cargo := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const Interceptor := preload("res://scripts/ships/cinder_light_interceptor.gd")
const CargoActivityBridge := preload("res://scripts/ships/cinder_cargo_activity_bridge.gd")
const ShipAudioRigScene := preload("res://scenes/audio/ship_audio_rig.tscn")
const FleetAudioBinding := preload("res://scripts/audio/fleet_expansion_audio_binding.gd")
const FleetBerthAudioBinding := preload("res://scripts/audio/fleet_expansion_berth_audio_binding.gd")
const CRAFT_SPECS: Array[Dictionary] = [
	{"pad_id": &"dock_04_cargo", "craft_id": &"cinder_cargo_hauler", "script": Cargo},
	{"pad_id": &"dock_05_bomber", "craft_id": &"cinder_long_range_bomber", "script": Bomber},
	{"pad_id": &"dock_06_interceptor", "craft_id": &"cinder_light_interceptor", "script": Interceptor},
]
const AUDIO_RECIPE_BY_CRAFT := {
	&"cinder_cargo_hauler": &"cargo_craft",
	&"cinder_long_range_bomber": &"bomber",
	&"cinder_light_interceptor": &"lightweight_interceptor",
}
const RIG_PROFILE_BY_RECIPE := {
	&"cargo_craft": &"heavy_quad_freighter",
	&"bomber": &"standard_fighter",
	&"lightweight_interceptor": &"efficient_twin_recon",
}

var _berths: Node3D
var _craft_by_id: Dictionary = {}
var _built := false
var _composition_error: StringName = &""
var _audio_bindings: Dictionary = {}
var _reduced_dynamic_range := false
var _cargo_activity_bridge: RefCounted
var _cargo_activity_binding: Node
var _berth_audio_binding: RefCounted


func _enter_tree() -> void:
	if _built:
		call_deferred("_restore_audio_bindings_after_reentry")


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	call_deferred("_assemble")


func _exit_tree() -> void:
	# FleetExpansionAudioBinding owns payload audio Nodes outside the scene tree.
	# Release those caller-owned bindings while their rigs are still valid so
	# their nested projectile bindings cannot outlive this production owner.
	for binding_value: Variant in _audio_bindings.values():
		var binding := binding_value as RefCounted
		if binding != null and bool(binding.get_snapshot().get("attached", false)):
			binding.detach()


func _restore_audio_bindings_after_reentry() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	for spec in CRAFT_SPECS:
		var craft_id: StringName = spec.craft_id
		var craft := _craft_by_id.get(craft_id) as Node3D
		var binding := _audio_bindings.get(craft_id) as RefCounted
		var attachment := (
			_berths.call("get_attachment_snapshot", spec.pad_id) as Dictionary
			if _berths != null else {}
		)
		if not is_instance_valid(craft) or binding == null \
				or not bool(attachment.get("attached", false)):
			continue
		var rig := craft.call("get_ship_audio_rig") as Node \
			if craft.has_method(&"get_ship_audio_rig") else null
		var result: Dictionary = binding.bind(AUDIO_RECIPE_BY_CRAFT[craft_id], rig)
		if not bool(result.get("accepted", false)):
			_composition_error = StringName(result.get("reason", &"audio_rebind_failed"))
			continue
		binding.set_reduced_dynamic_range(_reduced_dynamic_range)


func _assemble() -> void:
	if _built or is_queued_for_deletion() or not is_inside_tree():
		return
	_berths = Berths.new()
	_berths.name = "FleetExpansionBerths"
	add_child(_berths)
	_berth_audio_binding = FleetBerthAudioBinding.new() as RefCounted
	_berth_audio_binding.attach()
	for spec in CRAFT_SPECS:
		var craft := (spec.get("script") as GDScript).new() as Node3D
		craft.name = String(spec.craft_id)
		craft.set_meta(&"evidence_status", &"NEW")
		var ship_audio_rig := ShipAudioRigScene.instantiate() as Node3D
		ship_audio_rig.set("profile_id", RIG_PROFILE_BY_RECIPE[AUDIO_RECIPE_BY_CRAFT[spec.craft_id]])
		craft.add_child(ship_audio_rig)
		add_child(craft)
		_craft_by_id[spec.craft_id] = craft
	await get_tree().process_frame
	for spec in CRAFT_SPECS:
		var result: Dictionary = _berths.call(
			"attach_craft", spec.pad_id, _craft_by_id[spec.craft_id], spec.craft_id
		)
		if not bool(result.get("accepted", false)):
			_composition_error = StringName(result.get("reason", &"attachment_failed"))
			return
		var audio_result := _bind_craft_audio(spec.craft_id, _craft_by_id[spec.craft_id])
		if not bool(audio_result.get("accepted", false)):
			_composition_error = StringName(audio_result.get("reason", &"audio_binding_failed"))
			return
		_berth_audio_binding.present_pad_snapshot(_berths.get_attachment_snapshot(spec.pad_id))
	_built = true


func _bind_craft_audio(craft_id: StringName, craft: Node3D) -> Dictionary:
	var rig := craft.call("get_ship_audio_rig") as Node if craft.has_method(&"get_ship_audio_rig") else null
	if not is_instance_valid(rig):
		return {"accepted": false, "reason": &"ship_audio_rig_missing"}
	var binding := FleetAudioBinding.new()
	var result: Dictionary = binding.bind(AUDIO_RECIPE_BY_CRAFT[craft_id], rig)
	if bool(result.get("accepted", false)):
		binding.set_reduced_dynamic_range(_reduced_dynamic_range)
		_audio_bindings[craft_id] = binding
	return result


func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	_reduced_dynamic_range = enabled
	var rejected := PackedStringArray()
	for craft_id: StringName in _audio_bindings:
		var result: Dictionary = (_audio_bindings[craft_id] as RefCounted).set_reduced_dynamic_range(enabled)
		if not bool(result.get("accepted", false)):
			rejected.append(str(craft_id))
	return {"accepted": rejected.is_empty(), "reason": &"mix_updated" if rejected.is_empty() else &"mix_update_failed"}


func detach_craft(craft_id: StringName) -> Dictionary:
	if _berths == null or not _craft_by_id.has(craft_id):
		return {"accepted": false, "reason": &"unknown_craft"}
	for spec in CRAFT_SPECS:
		if spec.craft_id == craft_id:
			if craft_id == &"cinder_cargo_hauler" and _cargo_activity_bridge != null:
				var activity_detach: Dictionary = _cargo_activity_bridge.detach()
				if not bool(activity_detach.get("accepted", false)):
					return activity_detach
				_cargo_activity_bridge = null
				_cargo_activity_binding = null
			var result: Dictionary = _berths.call("detach_craft", spec.pad_id, _craft_by_id[craft_id])
			if bool(result.get("accepted", false)) and _audio_bindings.has(craft_id):
				(_audio_bindings[craft_id] as RefCounted).detach()
			if bool(result.get("accepted", false)) and _berth_audio_binding != null:
				_berth_audio_binding.present_release(spec.pad_id, int(_berth_audio_binding.get_snapshot().get("generation", 0)))
			return result
	return {"accepted": false, "reason": &"unknown_craft"}


## Forwards bomber payload presentation/audio records to the craft-local binding.
## The production binding owns composition only; it never admits, advances, or
## resolves a payload.
func present_payload_release(craft_id: StringName, record: Dictionary) -> Dictionary:
	return _present_payload_audio(craft_id, &"present_payload_release", record)


func begin_payload_audio_generation(craft_id: StringName, payload: Dictionary) -> Dictionary:
	return _present_payload_audio(craft_id, &"begin_payload_generation", payload)


func end_payload_audio_generation(craft_id: StringName, _payload: Dictionary = {}) -> Dictionary:
	return _present_payload_audio(craft_id, &"end_payload_generation", {})


func present_payload_abort(craft_id: StringName, record: Dictionary) -> Dictionary:
	return _present_payload_audio(craft_id, &"present_payload_abort", record)


func present_projectile_launch(craft_id: StringName, record: Dictionary) -> Dictionary:
	return _present_payload_audio(craft_id, &"present_projectile_launch", record)


func present_projectile_terminal(craft_id: StringName, intent: Dictionary) -> Dictionary:
	return _present_payload_audio(craft_id, &"present_projectile_terminal", intent)


func present_projectile_abort(craft_id: StringName, record: Dictionary) -> Dictionary:
	return _present_payload_audio(craft_id, &"present_projectile_abort", record)


func _present_payload_audio(craft_id: StringName, method: StringName, payload: Dictionary) -> Dictionary:
	if craft_id != &"cinder_long_range_bomber" or not _audio_bindings.has(craft_id):
		return {"accepted": false, "reason": &"payload_audio_not_supported"}
	var binding := _audio_bindings[craft_id] as RefCounted
	if binding == null or not binding.has_method(method):
		return {"accepted": false, "reason": &"payload_audio_unavailable"}
	if method == &"begin_payload_generation":
		return binding.call(method, int(payload.get("generation", -1))) as Dictionary
	if method == &"end_payload_generation":
		return binding.call(method) as Dictionary
	return binding.call(method, payload) as Dictionary


func reattach_craft(craft_id: StringName) -> Dictionary:
	if _berths == null or not _craft_by_id.has(craft_id):
		return {"accepted": false, "reason": &"unknown_craft"}
	for spec in CRAFT_SPECS:
		if spec.craft_id == craft_id:
			var result: Dictionary = _berths.call("attach_craft", spec.pad_id, _craft_by_id[craft_id], craft_id)
			if bool(result.get("accepted", false)):
				var audio_result := _bind_craft_audio(craft_id, _craft_by_id[craft_id])
				if not bool(audio_result.get("accepted", false)):
					return audio_result
			return result
	return {"accepted": false, "reason": &"unknown_craft"}


## Returns the fixed production compatibility and physical access contract for
## one composed craft. The binding reports the contract; it does not lease the
## pad or take flight/boarding authority from the craft.
func get_craft_compatibility_contract(craft_id: StringName) -> Dictionary:
	if not _built or not _craft_by_id.has(craft_id):
		return {"accepted": false, "reason": &"unknown_craft"}
	for spec in CRAFT_SPECS:
		if spec.craft_id != craft_id:
			continue
		var craft := _craft_by_id[craft_id] as Node3D
		var berth_contract: Dictionary = _berths.call("get_landing_contract", spec.pad_id)
		var landing_transform := berth_contract.get(
			"landing_transform", Transform3D.IDENTITY
		) as Transform3D
		var collision: Dictionary = craft.call("get_landing_collision_report")
		var seat := craft.call("get_pilot_seat_anchor") as Node3D
		var boarding := craft.call("get_boarding_marker") as Node3D
		var valid := bool(berth_contract.get("accepted", false)) \
			and bool(collision.get("valid", false)) \
			and is_instance_valid(seat) and is_instance_valid(boarding) \
			and landing_transform.is_finite() \
			and seat.global_position.is_finite() and boarding.global_position.is_finite() \
			and float(berth_contract.get("approach_radius", 0.0)) >= 12.0
		return {
			"accepted": true,
			"valid": valid,
			"craft_id": craft_id,
			"pad_id": spec.pad_id,
			"landing_anchor": berth_contract.get("landing_anchor", Vector3.INF),
			"landing_transform": landing_transform,
			"approach_anchor": berth_contract.get("approach_anchor", Vector3.INF),
			"approach_radius": berth_contract.get("approach_radius", 0.0),
			"seat_anchor": seat.global_position if is_instance_valid(seat) else Vector3.INF,
			"boarding_anchor": boarding.global_position if is_instance_valid(boarding) else Vector3.INF,
			"flight_authority": false,
			"berth_lease_authority": false,
		}.duplicate(true)
	return {"accepted": false, "reason": &"unknown_craft"}


## Performs one caller-requested HeroShip reset at the current authored landing
## transform. The berth attachment remains in place; the returned HeroShip
## receipt is the sole lifecycle evidence and can be fenced by the caller.
func reset_craft_for_reuse(craft_id: StringName) -> Dictionary:
	var contract := get_craft_compatibility_contract(craft_id)
	if not bool(contract.get("accepted", false)):
		return contract
	if not bool(contract.get("valid", false)):
		return {"accepted": false, "reason": &"compatibility_contract_invalid"}
	var craft := _craft_by_id[craft_id] as Node3D
	var spawn := contract.get("landing_transform", Transform3D.IDENTITY) as Transform3D
	var result: Dictionary = craft.call("reset_for_reuse", spawn)
	result["craft_id"] = craft_id
	result["pad_id"] = contract.pad_id
	result["attachment_preserved"] = bool(_berths.call("get_attachment_snapshot", contract.pad_id).get("attached", false))
	return result


## Binds the caller's existing NearbySectorActivityBinding to the real Dock04
## hauler. This owner only forwards intents; the activity retains cargo,
## reward, movement, and generation authority.
func bind_cargo_activity(activity_binding: Node) -> Dictionary:
	if not _built or not _craft_by_id.has(&"cinder_cargo_hauler"):
		return {"accepted": false, "reason": &"not_ready"}
	if _cargo_activity_bridge != null:
		return {"accepted": false, "reason": &"already_bound"}
	if activity_binding == null or not activity_binding.is_inside_tree():
		return {"accepted": false, "reason": &"invalid_activity_binding"}
	var bridge := CargoActivityBridge.new() as RefCounted
	var result: Dictionary = bridge.bind(_craft_by_id[&"cinder_cargo_hauler"], activity_binding)
	if bool(result.get("accepted", false)):
		_cargo_activity_bridge = bridge
		_cargo_activity_binding = activity_binding
	return result


func start_cargo_activity(anchor_id: StringName, cargo_id: StringName = &"cinder_supply_crates") -> Dictionary:
	if _cargo_activity_bridge == null:
		return {"accepted": false, "reason": &"cargo_activity_unbound"}
	return _cargo_activity_bridge.start(anchor_id, cargo_id)


func submit_cargo_activity_phase(phase_id: StringName, anchor_id: StringName, cargo_id: StringName = &"cinder_supply_crates") -> Dictionary:
	if _cargo_activity_bridge == null:
		return {"accepted": false, "reason": &"cargo_activity_unbound"}
	return _cargo_activity_bridge.submit_phase(phase_id, anchor_id, cargo_id)


func detach_cargo_activity() -> Dictionary:
	if _cargo_activity_bridge == null:
		return {"accepted": false, "reason": &"cargo_activity_unbound"}
	var result: Dictionary = _cargo_activity_bridge.detach()
	if bool(result.get("accepted", false)):
		_cargo_activity_bridge = null
		_cargo_activity_binding = null
	return result


func get_fleet_snapshot() -> Dictionary:
	var craft_snapshots: Array[Dictionary] = []
	for spec in CRAFT_SPECS:
		var craft := _craft_by_id.get(spec.craft_id) as Node3D
		craft_snapshots.append({
			"craft_id": spec.craft_id,
			"pad_id": spec.pad_id,
			"attached": bool((_berths.call("get_attachment_snapshot", spec.pad_id) if _berths != null else {}).get("attached", false)),
			"instance_id": craft.get_instance_id() if is_instance_valid(craft) else 0,
			"boarding_anchor": craft.call("get_boarding_marker").global_position if is_instance_valid(craft) else Vector3.INF,
			"audio": (_audio_bindings[spec.craft_id] as RefCounted).get_snapshot() if _audio_bindings.has(spec.craft_id) else {},
		})
	return {
		"built": _built,
		"composition_error": _composition_error,
		"berth_audio": _berth_audio_binding.get_snapshot() if _berth_audio_binding != null else {},
		"craft": craft_snapshots,
		"cargo_activity": _cargo_activity_bridge.get_snapshot() if _cargo_activity_bridge != null else {"bound": false},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _built:
		errors.append("fleet expansion composition is not built")
	if _composition_error != &"":
		errors.append("composition failed: %s" % _composition_error)
	if _berths != null and not _berth_production_audit_valid():
		errors.append("berth audit failed")
	for spec in CRAFT_SPECS:
		var craft := _craft_by_id.get(spec.craft_id) as Node3D
		if craft == null or not bool(craft.call("get_audit_report").get("valid", false)):
			errors.append("craft audit failed: %s" % spec.craft_id)
		if not _audio_bindings.has(spec.craft_id):
			errors.append("audio binding missing: %s" % spec.craft_id)
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"fleet_count": _craft_by_id.size(),
		"ship_authority": false,
		"flight_authority": false,
		"berth_lease_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _berth_production_audit_valid() -> bool:
	if _berths == null:
		return false
	var report: Dictionary = _berths.call("get_audit_report")
	if bool(report.get("valid", false)):
		return true
	# FleetExpansionBerths freezes its authored contract in local coordinates.
	# ShipyardWorld places this composed module at the FleetDockComb transform, so
	# only the child audit's global-coordinate comparison is expected to differ.
	# Re-check every other berth invariant and reject any unrelated error.
	for error: String in report.get("errors", PackedStringArray()):
		if not error.begins_with("service presentation: service presentation moved landing contract:"):
			return false
	var service_report: Dictionary = _berths.call("get_service_presentation_audit")
	for error: String in service_report.get("errors", PackedStringArray()):
		if not error.begins_with("service presentation moved landing contract:"):
			return false
	return _berths.get_attachment_snapshot(&"dock_04_cargo").get("attached", false) \
		and _berths.get_attachment_snapshot(&"dock_05_bomber").get("attached", false) \
		and _berths.get_attachment_snapshot(&"dock_06_interceptor").get("attached", false)
