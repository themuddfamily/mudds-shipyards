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
const ShipBoardingAreaScene := preload("res://scenes/interaction/ship_boarding_area.tscn")
const FleetAudioBinding := preload("res://scripts/audio/fleet_expansion_audio_binding.gd")
const FleetBerthAudioBinding := preload("res://scripts/audio/fleet_expansion_berth_audio_binding.gd")
const CRAFT_SPECS: Array[Dictionary] = [
	{"pad_id": &"dock_04_cargo", "craft_id": &"cinder_cargo_hauler", "script": Cargo},
	{"pad_id": &"dock_05_bomber", "craft_id": &"cinder_long_range_bomber", "script": Bomber},
	{"pad_id": &"dock_06_interceptor", "craft_id": &"cinder_light_interceptor", "script": Interceptor},
]
## The Cinder hulls sit on four-metre landing anchors while their six narrow
## pedestrian surfaces remain at deck level. HeroShip's generic exit marker is
## therefore neither a safe height nor inside these pad-specific routes. Bind
## the existing boarding/exit seam to the exact collision-backed endpoint owned
## by each pad after every attachment; no parallel interaction authority is
## introduced here.
const PEDESTRIAN_HANDOFF_SUPPORTS := {
	&"dock_04_cargo": ^"AccessCirculation/CargoBoardingLeg",
	&"dock_05_bomber": ^"AccessCirculation/BomberBoardingLeg",
	&"dock_06_interceptor": ^"AccessCirculation/InterceptorBoardingToe",
}
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
# Direct instances retain deferred, two-frame composition. Only the boot world
# opts in before attachment and then drives the same construction units itself.
var _staged_construction := false
var _assembly_unit_index := 0
var _assembly_needs_settle := false
var _assembly_tree_generation := 0
var _assembly_run_active := false
var _composition_error: StringName = &""
var _audio_bindings: Dictionary = {}
var _reduced_dynamic_range := false
var _cargo_activity_bridge: RefCounted
var _cargo_activity_binding: Node
var _berth_audio_binding: RefCounted


func _enter_tree() -> void:
	if _built:
		call_deferred("_restore_audio_bindings_after_reentry")
	elif is_node_ready() and not _staged_construction:
		call_deferred("_assemble")


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _staged_construction:
		call_deferred("_assemble")


func _exit_tree() -> void:
	_assembly_tree_generation += 1
	_assembly_run_active = false
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


static func get_staged_construction_stage_count() -> int:
	return 1 + CRAFT_SPECS.size()


## Must be selected before entering the tree, so no deferred construction can
## race the startup world's explicitly awaited stages.
func prepare_staged_construction() -> void:
	if is_inside_tree() or _assembly_unit_index > 0 or _built:
		return
	_staged_construction = true


func is_composition_ready() -> bool:
	return _built and is_inside_tree() and not is_queued_for_deletion()


## The script owns the awaited driver, not the disposable scene instance. A
## queued/free binding can therefore report cancellation to its still-live
## startup owner on the next frame instead of abandoning that owner's await.
static func run_staged_construction(binding_ref: WeakRef, on_stage: Callable = Callable()) -> bool:
	return await _run_assembly(binding_ref, true, on_stage)


func _assemble() -> void:
	_run_assembly(weakref(self), false)


static func _run_assembly(binding_ref: WeakRef, staged: bool, on_stage: Callable = Callable()) -> bool:
	var binding := binding_ref.get_ref() as FleetExpansionProductionBinding
	if not is_instance_valid(binding):
		return false
	if binding._built:
		return binding.is_composition_ready()
	if binding._assembly_run_active or binding.is_queued_for_deletion() or not binding.is_inside_tree() \
			or staged != binding._staged_construction or binding._composition_error != &"":
		return false
	var generation := binding._assembly_tree_generation
	var tree := binding.get_tree()
	binding._assembly_run_active = true
	while binding._assembly_unit_index < get_staged_construction_stage_count() or binding._assembly_needs_settle:
		if not _is_assembly_current(binding, generation):
			return false
		# Keep the pending settle across cancellation, including detachment from
		# the final craft's progress callback before it ever reaches this await.
		if binding._assembly_needs_settle and (staged or binding._assembly_unit_index == get_staged_construction_stage_count()):
			binding = null
			await tree.process_frame
			binding = binding_ref.get_ref() as FleetExpansionProductionBinding
			if not _is_assembly_current(binding, generation):
				return false
			binding._assembly_needs_settle = false
			continue
		var unit := binding._assembly_unit_index
		binding._assembly_unit_index += 1
		binding._assembly_needs_settle = true
		binding._build_assembly_unit(unit)
		if not _is_assembly_current(binding, generation):
			return false
		if staged and on_stage.is_valid():
			on_stage.call(
				"Preparing Cinder fleet berths" if unit == 0
				else "Preparing %s" % String(CRAFT_SPECS[unit - 1].craft_id).capitalize()
			)
		if not _is_assembly_current(binding, generation):
			return false
	var accepted := binding._finish_assembly()
	if _is_assembly_current(binding, generation):
		binding._assembly_run_active = false
	return accepted and _is_assembly_current(binding, generation)


static func _is_assembly_current(binding: FleetExpansionProductionBinding, generation: int) -> bool:
	return is_instance_valid(binding) and generation == binding._assembly_tree_generation \
		and binding.is_inside_tree() and not binding.is_queued_for_deletion()


func _build_assembly_unit(unit: int) -> void:
	if unit == 0:
		_berths = Berths.new()
		_berths.name = "FleetExpansionBerths"
		add_child(_berths)
		_berth_audio_binding = FleetBerthAudioBinding.new() as RefCounted
		_berth_audio_binding.attach()
		return
	var spec := CRAFT_SPECS[unit - 1]
	var craft := (spec.get("script") as GDScript).new() as Node3D
	craft.name = String(spec.craft_id)
	craft.set_meta(&"evidence_status", &"NEW")
	var ship_audio_rig := ShipAudioRigScene.instantiate() as Node3D
	ship_audio_rig.set("profile_id", RIG_PROFILE_BY_RECIPE[AUDIO_RECIPE_BY_CRAFT[spec.craft_id]])
	craft.add_child(ship_audio_rig)
	_craft_by_id[spec.craft_id] = craft
	add_child(craft)


func _finish_assembly() -> bool:
	for spec in CRAFT_SPECS:
		var result: Dictionary = _berths.call(
			"attach_craft", spec.pad_id, _craft_by_id[spec.craft_id], spec.craft_id
		)
		if not bool(result.get("accepted", false)):
			_composition_error = StringName(result.get("reason", &"attachment_failed"))
			return false
		var handoff_result := _bind_pedestrian_handoff(
			spec.craft_id, spec.pad_id, _craft_by_id[spec.craft_id]
		)
		if not bool(handoff_result.get("accepted", false)):
			_composition_error = StringName(
				handoff_result.get("reason", &"pedestrian_handoff_failed")
			)
			return false
		var audio_result := _bind_craft_audio(spec.craft_id, _craft_by_id[spec.craft_id])
		if not bool(audio_result.get("accepted", false)):
			_composition_error = StringName(audio_result.get("reason", &"audio_binding_failed"))
			return false
		_berth_audio_binding.present_pad_snapshot(_berths.get_attachment_snapshot(spec.pad_id))
	_built = true
	return true


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
				var handoff_result := _bind_pedestrian_handoff(
					craft_id, spec.pad_id, _craft_by_id[craft_id]
				)
				if not bool(handoff_result.get("accepted", false)):
					return handoff_result
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
	if bool(result.get("accepted", false)):
		var handoff_result := _bind_pedestrian_handoff(
			craft_id, StringName(contract.pad_id), craft
		)
		if not bool(handoff_result.get("accepted", false)):
			return handoff_result
	result["craft_id"] = craft_id
	result["pad_id"] = contract.pad_id
	result["attachment_preserved"] = bool(_berths.call("get_attachment_snapshot", contract.pad_id).get("attached", false))
	return result


func _bind_pedestrian_handoff(
	craft_id: StringName, pad_id: StringName, craft: Node3D
	) -> Dictionary:
	if not is_instance_valid(craft) or not PEDESTRIAN_HANDOFF_SUPPORTS.has(pad_id):
		return {"accepted": false, "reason": &"pedestrian_handoff_owner_missing"}
	var support := _berths.get_node_or_null(
		PEDESTRIAN_HANDOFF_SUPPORTS[pad_id]
	) as StaticBody3D if _berths != null else null
	var support_bounds := _box_support_bounds(support)
	var authored_marker := craft.call("get_boarding_marker") as Node3D \
		if craft.has_method(&"get_boarding_marker") else null
	var boarding_point := craft.get_node_or_null(^"BoardingPoint") as Marker3D
	var exit_point := craft.get_node_or_null(^"ExitPoint") as Marker3D
	if support_bounds.size == Vector3.ZERO or not is_instance_valid(authored_marker) \
			or boarding_point == null or exit_point == null:
		return {"accepted": false, "reason": &"pedestrian_handoff_node_missing"}
	var deck_position := Vector3(
		authored_marker.global_position.x,
		support_bounds.end.y,
		authored_marker.global_position.z
	)
	if not _support_contains_xz(support_bounds, deck_position):
		return {"accepted": false, "reason": &"pedestrian_handoff_off_support"}
	authored_marker.global_position = deck_position
	boarding_point.global_position = deck_position
	exit_point.global_position = deck_position
	var boarding_area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	# Script-built fighters and bombers need the same reservation-backed physical
	# interaction as scene-built ships. Reuse the cargo craft's existing area and
	# retain every area's identity across subsequent berth attachments.
	if boarding_area == null:
		if craft.has_node(^"ShipBoardingArea"):
			return {"accepted": false, "reason": &"pedestrian_boarding_authority_invalid"}
		boarding_area = ShipBoardingAreaScene.instantiate() as ShipBoardingArea
		craft.add_child(boarding_area)
	boarding_area.global_position = deck_position
	return {
		"accepted": true,
		"reason": &"pedestrian_handoff_bound",
		"craft_id": craft_id,
		"pad_id": pad_id,
		"position": deck_position,
		"support_path": support.get_path(),
	}.duplicate(true)


func _box_support_bounds(body: StaticBody3D) -> AABB:
	var collision := body.get_node_or_null(^"Collision") as CollisionShape3D \
		if body != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	return (collision.global_transform * AABB(-shape.size * 0.5, shape.size)).abs() \
		if shape != null else AABB()


func _support_contains_xz(bounds: AABB, point: Vector3) -> bool:
	return point.x >= bounds.position.x - 0.001 \
		and point.x <= bounds.end.x + 0.001 \
		and point.z >= bounds.position.z - 0.001 \
		and point.z <= bounds.end.z + 0.001


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


## Fresh identity and attachment state for registry/boarding consumers. Audio
## and cargo diagnostics belong to the full snapshot and are not prerequisites
## for finding a craft; compatibility is still validated separately.
func get_fleet_registration_snapshot() -> Dictionary:
	var craft_snapshots: Array[Dictionary] = []
	for spec in CRAFT_SPECS:
		craft_snapshots.append(_get_craft_registration_row(spec))
	return {
		"built": _built,
		"composition_error": _composition_error,
		"craft": craft_snapshots,
	}


func _get_craft_registration_row(spec: Dictionary) -> Dictionary:
	var craft := _craft_by_id.get(spec.craft_id) as Node3D
	return {
		"craft_id": spec.craft_id,
		"pad_id": spec.pad_id,
		"attached": bool((_berths.call("get_attachment_snapshot", spec.pad_id) if _berths != null else {}).get("attached", false)),
		"instance_id": craft.get_instance_id() if is_instance_valid(craft) else 0,
	}


func get_fleet_snapshot() -> Dictionary:
	var craft_snapshots: Array[Dictionary] = []
	for spec in CRAFT_SPECS:
		var craft := _craft_by_id.get(spec.craft_id) as Node3D
		var row := _get_craft_registration_row(spec)
		row["boarding_anchor"] = craft.call("get_boarding_marker").global_position if is_instance_valid(craft) else Vector3.INF
		row["audio"] = (_audio_bindings[spec.craft_id] as RefCounted).get_snapshot() if _audio_bindings.has(spec.craft_id) else {}
		craft_snapshots.append(row)
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
