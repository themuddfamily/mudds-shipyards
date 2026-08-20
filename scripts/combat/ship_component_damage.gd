class_name ShipComponentDamage
extends Node

## Ship-local geometry and legacy-presentation adapter over one detached
## ComponentDamageModel ledger. The adapter owns no health dictionary: it keeps
## only collision-derived anchors, the legacy report/signal shape, and the Hero
## reset capability fence. Hull, destruction, repair authorization, combat, and
## presentation authority remain with the existing callers.

const ComponentDamageModelType := preload("res://scripts/combat/component_damage_model.gd")

const SCHEMA_VERSION := 1
const INTERPRETATION: StringName = &"modern_interpretation"

enum ComponentState {
	NOMINAL,
	IMPAIRED,
	FAILED,
}

const STATE_ID_NOMINAL: StringName = &"nominal"
const STATE_ID_IMPAIRED: StringName = &"impaired"
const STATE_ID_FAILED: StringName = &"failed"

const COMPONENT_FORWARD_HULL: StringName = &"forward_hull"
const COMPONENT_PORT_WING: StringName = &"port_wing"
const COMPONENT_STARBOARD_WING: StringName = &"starboard_wing"
const COMPONENT_CORE_SYSTEMS: StringName = &"core_systems"
const COMPONENT_ENGINE_BAY: StringName = &"engine_bay"

const COMPONENT_ORDER: Array[StringName] = [
	COMPONENT_FORWARD_HULL,
	COMPONENT_PORT_WING,
	COMPONENT_STARBOARD_WING,
	COMPONENT_CORE_SYSTEMS,
	COMPONENT_ENGINE_BAY,
]

const IMPAIRED_THRESHOLD := 0.62
const FAILED_THRESHOLD := 0.24
const ATTRIBUTION_GAIN := 4.0
const SPLASH_SCALE := 2.0
const MINIMUM_COMPONENT_RADIUS := 0.35

const _LEDGER_STAGES := [
	{
		"stage_id": STATE_ID_NOMINAL,
		"health_ratio_at_or_below": 1.0,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STATE_ID_IMPAIRED,
		"health_ratio_at_or_below": IMPAIRED_THRESHOLD,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STATE_ID_FAILED,
		"health_ratio_at_or_below": FAILED_THRESHOLD,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
	{
		"stage_id": &"destroyed",
		"health_ratio_at_or_below": 0.0,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
]

signal component_state_changed(component_id: StringName, state: int, integrity: float)
signal components_restored()

@export_range(0.05, 8.0, 0.01) var repair_rate_per_second := 0.62

var _configured := false
var _maximum_hull := 0.0
var _local_bounds := AABB()
## Geometry only. Component health, stage, operation order, and generation live
## exclusively in `_ledger`.
var _layout: Dictionary = {}
var _ledger: ComponentDamageModel
var _next_operation_sequence := 0
var _ledger_dispatch_active := false
## This remains the legacy observable revision: geometry capture and every
## accepted generic-ledger commit each advance it exactly once.
var _revision := 0
var _owner_mutation_capability: WeakRef
var _owner_mutation_capability_claimed := false
var _owner_mutation_transaction_active := false


func configure(local_bounds: AABB, maximum_hull: float) -> bool:
	if _owner_mutation_transaction_active or _ledger_dispatch_active:
		return false
	if not _is_usable_bounds(local_bounds) or not is_finite(maximum_hull) or maximum_hull <= 0.0:
		return false
	var layout := _derive_layout(local_bounds)
	if layout.is_empty():
		return false
	if _ledger == null:
		var candidate := ComponentDamageModelType.new(_ledger_definitions()) as ComponentDamageModel
		if candidate == null or not candidate.is_configuration_valid():
			return false
		# The first generic generation establishes the same fully nominal state that
		# the former configure path exposed, before external listeners are connected.
		if not bool(candidate.reset_for_reuse(0).get("accepted", false)):
			return false
		_ledger = candidate
		_ledger.component_stage_changed.connect(_on_ledger_stage_changed)
		_next_operation_sequence = 0
	_layout = layout
	_local_bounds = local_bounds
	_maximum_hull = maximum_hull
	_configured = true
	_revision += 1
	return true


func is_configured() -> bool:
	return _configured and _ledger != null and _ledger.get_generation() > 0


func get_revision() -> int:
	return _revision


func get_component_count() -> int:
	return COMPONENT_ORDER.size() if is_configured() else 0


## Detached audit only; the mutable generic ledger object is deliberately never
## returned, so callers cannot bypass the adapter's owner transaction fence.
func get_ledger_snapshot() -> Dictionary:
	return _ledger.get_snapshot() if _ledger != null else {}


func get_ledger_generation() -> int:
	return _ledger.get_generation() if _ledger != null else 0


## Hero uses this during reset preflight. A generic generation exhaustion must
## reject before Hero changes transform, hull, berth, or presentation state.
func is_reset_for_reuse_available() -> bool:
	return is_configured() \
		and not _ledger_dispatch_active \
		and _ledger.is_configuration_valid() \
		and _ledger.get_generation() < ComponentDamageModel.MAX_SAFE_INTEGER


func record_damage(amount: float, local_hit_position: Vector3 = Vector3.INF) -> Dictionary:
	var report := {
		"accepted": false,
		"reason": &"",
		"located": false,
		"normalized_damage": 0.0,
		"revision": _revision,
		"components": {},
	}
	if _owner_mutation_transaction_active:
		report["reason"] = &"owner_transaction_active"
		return report
	if _ledger_dispatch_active:
		report["reason"] = &"reentrant_call"
		return report
	if not _can_mutate_live_components():
		report["reason"] = &"component_detached"
		return report
	if not is_configured():
		report["reason"] = &"not_configured"
		return report
	if not is_finite(amount) or amount <= 0.0:
		report["reason"] = &"invalid_damage"
		return report

	var normalized := clampf(amount / _maximum_hull, 0.0, 1.0)
	var located := local_hit_position.is_finite()
	var weights := _attribution_weights(local_hit_position) if located else _uniform_weights()
	var contexts: Array[Dictionary] = []
	for component_id: StringName in COMPONENT_ORDER:
		var weight := float(weights.get(component_id, 0.0))
		if weight <= 0.0:
			continue
		var before := get_component_integrity(component_id)
		var requested := minf(normalized * weight * ATTRIBUTION_GAIN, before)
		if before <= 0.0 or requested <= 0.0 or is_equal_approx(before - requested, before):
			continue
		contexts.append({
			"component_id": component_id,
			"damage": requested,
			"generation": _ledger.get_generation(),
			"sequence": _next_operation_sequence + contexts.size(),
		})
	if contexts.is_empty():
		report["reason"] = &"no_component_effect"
		report["located"] = located
		report["normalized_damage"] = normalized
		return report

	_ledger_dispatch_active = true
	var result := _ledger.apply_component_damage_batch(contexts)
	_ledger_dispatch_active = false
	if not bool(result.get("accepted", false)):
		report["reason"] = StringName(result.get("reason", &"ledger_rejected"))
		return report
	var deltas: Dictionary = {}
	for operation: Dictionary in result.get("operations", []) as Array:
		deltas[StringName(operation.get("component_id", &""))] = float(
			operation.get("applied_damage", 0.0)
		)
	_next_operation_sequence = int(result.get("last_sequence", -1)) + 1
	_revision += 1
	report["accepted"] = true
	report["located"] = located
	report["normalized_damage"] = normalized
	report["revision"] = _revision
	report["components"] = deltas
	return report


func tick_repair(delta: float, repairing: bool) -> Dictionary:
	var report := {
		"accepted": false,
		"reason": &"",
		"repaired_components": 0,
		"revision": _revision,
	}
	if _owner_mutation_transaction_active:
		report["reason"] = &"owner_transaction_active"
		return report
	if _ledger_dispatch_active:
		report["reason"] = &"reentrant_call"
		return report
	if not _can_mutate_live_components():
		report["reason"] = &"component_detached"
		return report
	if not is_configured():
		report["reason"] = &"not_configured"
		return report
	if not is_finite(delta) or delta <= 0.0:
		report["reason"] = &"invalid_delta"
		return report
	if not repairing:
		report["reason"] = &"repair_not_authorized"
		return report

	var step := repair_rate_per_second * delta
	var contexts: Array[Dictionary] = []
	for component_id: StringName in COMPONENT_ORDER:
		var before := get_component_integrity(component_id)
		var requested := minf(step, 1.0 - before)
		if before >= 1.0 or requested <= 0.0 or is_equal_approx(before + requested, before):
			continue
		contexts.append({
			"component_id": component_id,
			"repair": requested,
			"generation": _ledger.get_generation(),
			"sequence": _next_operation_sequence + contexts.size(),
		})
	if contexts.is_empty():
		report["reason"] = &"already_nominal"
		return report

	_ledger_dispatch_active = true
	var result := _ledger.apply_component_repair_batch(contexts)
	_ledger_dispatch_active = false
	if not bool(result.get("accepted", false)):
		report["reason"] = StringName(result.get("reason", &"ledger_rejected"))
		return report
	_next_operation_sequence = int(result.get("last_sequence", -1)) + 1
	_revision += 1
	report["accepted"] = true
	report["repaired_components"] = contexts.size()
	report["revision"] = _revision
	return report


func reset_for_reuse() -> void:
	if _owner_mutation_transaction_active or _ledger_dispatch_active:
		return
	_reset_for_reuse_unchecked()


func _can_mutate_live_components() -> bool:
	if is_queued_for_deletion():
		return false
	# Unowned fixtures are intentionally usable while detached: the adapter's
	# focused contract is also exercised as a data-only observer. Once a Hero
	# claims the capability, detachment is a lifecycle boundary and mutations
	# must come from the live scene-tree instance.
	return is_inside_tree() or not _owner_mutation_capability_claimed


func claim_owner_mutation_capability() -> RefCounted:
	if _owner_mutation_capability_claimed or not is_configured():
		return null
	var capability := RefCounted.new()
	_owner_mutation_capability = weakref(capability)
	_owner_mutation_capability_claimed = true
	return capability


func is_owner_mutation_capability_current(capability: RefCounted) -> bool:
	return _owner_mutation_capability_claimed \
		and capability != null \
		and is_instance_valid(capability) \
		and _owner_mutation_capability != null \
		and _owner_mutation_capability.get_ref() == capability


func begin_owner_mutation_transaction(capability: RefCounted) -> bool:
	if _owner_mutation_transaction_active \
			or not is_owner_mutation_capability_current(capability):
		return false
	_owner_mutation_transaction_active = true
	return true


func end_owner_mutation_transaction(capability: RefCounted) -> bool:
	if not _owner_mutation_transaction_active \
			or not is_owner_mutation_capability_current(capability):
		return false
	_owner_mutation_transaction_active = false
	return true


func reset_for_reuse_as_owner(capability: RefCounted) -> bool:
	if not _owner_mutation_transaction_active \
			or not is_owner_mutation_capability_current(capability):
		return false
	return _reset_for_reuse_unchecked()


func _reset_for_reuse_unchecked() -> bool:
	if _ledger_dispatch_active or not is_reset_for_reuse_available():
		return false
	var previous_states := _legacy_states_by_id()
	_ledger_dispatch_active = true
	var result := _ledger.reset_for_reuse(_ledger.get_generation())
	_ledger_dispatch_active = false
	if not bool(result.get("accepted", false)):
		return false
	_next_operation_sequence = 0
	_revision += 1
	for component_id: StringName in COMPONENT_ORDER:
		if int(previous_states.get(component_id, ComponentState.NOMINAL)) != ComponentState.NOMINAL:
			component_state_changed.emit(component_id, ComponentState.NOMINAL, 1.0)
	components_restored.emit()
	return true


func get_component_integrity(component_id: StringName) -> float:
	if not is_configured():
		return -1.0
	var component := _ledger.get_component_state(component_id)
	return float(component.get("health_ratio", -1.0)) if not component.is_empty() else -1.0


func get_component_state(component_id: StringName) -> int:
	var integrity := get_component_integrity(component_id)
	return state_for_integrity(integrity) if integrity >= 0.0 else -1


func get_worst_integrity() -> float:
	if not is_configured():
		return 1.0
	var worst := 1.0
	for component_id: StringName in COMPONENT_ORDER:
		worst = minf(worst, get_component_integrity(component_id))
	return worst


func get_failed_component_count() -> int:
	return _count_state(ComponentState.FAILED)


func get_impaired_component_count() -> int:
	return _count_state(ComponentState.IMPAIRED)


func get_component_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if not is_configured():
		return states
	for component_id: StringName in COMPONENT_ORDER:
		var placement := _layout.get(component_id, {}) as Dictionary
		var integrity := get_component_integrity(component_id)
		var state := state_for_integrity(integrity)
		states.append({
			"id": component_id,
			"state": state,
			"state_id": state_id_for(state),
			"integrity": integrity,
			"local_position": placement.get("local_position", Vector3.ZERO) as Vector3,
			"local_radius": float(placement.get("local_radius", 0.0)),
		})
	return states


func get_component_report() -> Dictionary:
	var components: Array[Dictionary] = get_component_states()
	return {
		"schema_version": SCHEMA_VERSION,
		"interpretation": INTERPRETATION,
		"configured": is_configured(),
		"maximum_hull": _maximum_hull,
		"local_bounds": _local_bounds,
		"revision": _revision,
		"ledger_generation": get_ledger_generation(),
		"ledger_revision": _ledger.get_revision() if _ledger != null else 0,
		"component_count": components.size(),
		"failed_count": get_failed_component_count(),
		"impaired_count": get_impaired_component_count(),
		"worst_integrity": get_worst_integrity(),
		"repair_rate_per_second": repair_rate_per_second,
		"components": components,
		"component_order": COMPONENT_ORDER.duplicate(),
	}.duplicate(true)


static func state_id_for(state: int) -> StringName:
	match state:
		ComponentState.IMPAIRED:
			return STATE_ID_IMPAIRED
		ComponentState.FAILED:
			return STATE_ID_FAILED
		ComponentState.NOMINAL:
			return STATE_ID_NOMINAL
	return &"invalid"


static func state_for_integrity(integrity: float) -> int:
	if not is_finite(integrity):
		return ComponentState.FAILED
	if integrity <= FAILED_THRESHOLD:
		return ComponentState.FAILED
	if integrity <= IMPAIRED_THRESHOLD:
		return ComponentState.IMPAIRED
	return ComponentState.NOMINAL


func _on_ledger_stage_changed(result: Dictionary) -> void:
	var maximum := float(result.get("maximum_health", 0.0))
	if maximum <= 0.0:
		return
	var previous := state_for_integrity(float(result.get("previous_health", 0.0)) / maximum)
	var current_integrity := float(result.get("current_health", 0.0)) / maximum
	var current := state_for_integrity(current_integrity)
	if previous != current:
		component_state_changed.emit(
			StringName(result.get("component_id", &"")), current, current_integrity
		)


func _legacy_states_by_id() -> Dictionary:
	var states: Dictionary = {}
	for component_id: StringName in COMPONENT_ORDER:
		states[component_id] = get_component_state(component_id)
	return states


func _count_state(state: int) -> int:
	var total := 0
	for component_id: StringName in COMPONENT_ORDER:
		if get_component_state(component_id) == state:
			total += 1
	return total


func _ledger_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for component_id: StringName in COMPONENT_ORDER:
		definitions.append({
			"component_id": component_id,
			"maximum_health": 1.0,
			"damage_stages": _LEDGER_STAGES.duplicate(true),
		})
	return definitions


func _uniform_weights() -> Dictionary:
	var share := 1.0 / float(COMPONENT_ORDER.size())
	var weights: Dictionary = {}
	for component_id: StringName in COMPONENT_ORDER:
		weights[component_id] = share
	return weights


func _attribution_weights(local_hit_position: Vector3) -> Dictionary:
	var raw: Dictionary = {}
	var total := 0.0
	var nearest_id: StringName = COMPONENT_ORDER[0]
	var nearest_distance := INF
	for component_id: StringName in COMPONENT_ORDER:
		var placement := _layout.get(component_id, {}) as Dictionary
		var distance := (placement.get("local_position", Vector3.ZERO) as Vector3).distance_to(
			local_hit_position
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = component_id
		var reach := float(placement.get("local_radius", 0.0)) * SPLASH_SCALE
		var falloff := clampf(1.0 - distance / maxf(reach, 0.0001), 0.0, 1.0)
		var weight := falloff * falloff
		raw[component_id] = weight
		total += weight
	if total <= 0.0:
		var fallback: Dictionary = {}
		for component_id: StringName in COMPONENT_ORDER:
			fallback[component_id] = 0.0
		fallback[nearest_id] = 1.0
		return fallback
	for component_id: StringName in COMPONENT_ORDER:
		raw[component_id] = float(raw[component_id]) / total
	return raw


func _derive_layout(local_bounds: AABB) -> Dictionary:
	var centre := local_bounds.get_center()
	var extents := local_bounds.size * 0.5
	if not centre.is_finite() or not extents.is_finite():
		return {}
	var longitudinal_radius := maxf(extents.z * 0.55, MINIMUM_COMPONENT_RADIUS)
	var lateral_radius := maxf(extents.x * 0.55, MINIMUM_COMPONENT_RADIUS)
	var core_radius := maxf((extents.x + extents.z) * 0.28, MINIMUM_COMPONENT_RADIUS)
	return {
		COMPONENT_FORWARD_HULL: {
			"local_position": centre + Vector3(0.0, extents.y * 0.22, -extents.z * 0.70),
			"local_radius": longitudinal_radius,
		},
		COMPONENT_PORT_WING: {
			"local_position": centre + Vector3(-extents.x * 0.78, extents.y * 0.12, 0.0),
			"local_radius": lateral_radius,
		},
		COMPONENT_STARBOARD_WING: {
			"local_position": centre + Vector3(extents.x * 0.78, extents.y * 0.12, 0.0),
			"local_radius": lateral_radius,
		},
		COMPONENT_CORE_SYSTEMS: {
			"local_position": centre + Vector3(0.0, extents.y * 0.42, 0.0),
			"local_radius": core_radius,
		},
		COMPONENT_ENGINE_BAY: {
			"local_position": centre + Vector3(0.0, extents.y * 0.20, extents.z * 0.74),
			"local_radius": longitudinal_radius,
		},
	}


static func _is_usable_bounds(local_bounds: AABB) -> bool:
	var size := local_bounds.size
	var position := local_bounds.position
	return size.is_finite() and position.is_finite() \
		and size.x > 0.0 and size.y > 0.0 and size.z > 0.0
