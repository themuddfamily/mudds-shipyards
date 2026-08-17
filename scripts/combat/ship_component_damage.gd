class_name ShipComponentDamage
extends Node

## Observational component-integrity model for a crewed craft.
##
## `modern_interpretation`: no registered source authenticates any damage model,
## component roster, integrity curve, or repair rate in this file. Every number
## here is a revisable modern gameplay reading.
##
## Authority boundary
## ------------------
## The owning ship remains the only owner of hull, destruction, respawn and
## handling. This node never adds or removes hull, never resolves a ray, never
## registers a combat source, never allocates a receipt, and never writes to the
## ship. It *reads* damage that the single live damage path has already resolved
## -- `CombatResolver` -> `LifecycleDamageableAdapter` -> `HeroShip.apply_damage()`,
## plus the ship's own collision damage, which funnel through that one method --
## and attributes it to a deterministic ship-local component layout so the craft
## can express *where* it was hurt rather than only *how much*.
##
## Determinism
## -----------
## The layout is derived from the ship's own collision envelope
## (`HeroShip.get_landing_collision_report().local_bounds`), so it follows each
## craft's authored collision variant instead of a second hand-written hull
## table. Attribution is a closed-form distance falloff: there is no RNG, no
## wall-clock read, and no frame-order dependence. Repair advances on the caller's
## simulation delta only.

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

## Roster order is fixed and is the order every report and state array uses.
const COMPONENT_ORDER: Array[StringName] = [
	COMPONENT_FORWARD_HULL,
	COMPONENT_PORT_WING,
	COMPONENT_STARBOARD_WING,
	COMPONENT_CORE_SYSTEMS,
	COMPONENT_ENGINE_BAY,
]

## A component is impaired at or below this integrity and failed at or below the
## lower bound. Both are inclusive so a boundary value has exactly one reading.
const IMPAIRED_THRESHOLD := 0.62
const FAILED_THRESHOLD := 0.24

## Hull fraction -> component integrity gain. A hit that removes the whole hull
## would drive its nearest component through failure several times over; an
## ordinary defence-cannon hit costs its nearest component roughly a quarter of
## its integrity, so a craft shows a failed section well before its hull stage
## reaches critical.
const ATTRIBUTION_GAIN := 4.0
## Splash reach as a multiple of a component radius. Neighbouring sections take a
## normalized share so a single hit never reads as surgically isolated.
const SPLASH_SCALE := 2.0
const MINIMUM_COMPONENT_RADIUS := 0.35

signal component_state_changed(component_id: StringName, state: int, integrity: float)
signal components_restored()

## Full integrity restored per second while the caller reports the craft as
## berthed. At the default rate a completely failed section is nominal again in
## under two seconds of parked time, and nothing in the game gates on it, so
## crash recovery and craft regeneration keep their existing latency.
@export_range(0.05, 8.0, 0.01) var repair_rate_per_second := 0.62

var _configured := false
var _maximum_hull := 0.0
var _local_bounds := AABB()
var _components: Dictionary = {}
## Bumped on every observable change so an owner can push presentation state
## without comparing dictionaries every physics frame.
var _revision := 0
## The owning Hero claims one opaque object identity after initial configuration.
## This component retains only a weak comparison reference; the capability is
## never published again and survives ordinary detach/re-entry with its owner.
var _owner_mutation_capability: WeakRef
var _owner_mutation_capability_claimed := false
var _owner_mutation_transaction_active := false


## Builds the deterministic roster from a ship-local collision envelope.
##
## Returns false and leaves any previous configuration untouched when the
## envelope or hull value cannot describe a craft. Re-configuring a live model
## with the same envelope is idempotent and preserves current integrity, so a
## re-entered or re-measured ship never gains a duplicate roster.
func configure(local_bounds: AABB, maximum_hull: float) -> bool:
	if _owner_mutation_transaction_active:
		return false
	if not _is_usable_bounds(local_bounds) or not is_finite(maximum_hull) or maximum_hull <= 0.0:
		return false
	var layout := _derive_layout(local_bounds)
	if layout.is_empty():
		return false
	var preserved: Dictionary = {}
	if _configured:
		for component_id: StringName in COMPONENT_ORDER:
			var existing: Dictionary = _components.get(component_id, {})
			if not existing.is_empty():
				preserved[component_id] = {
					"integrity": float(existing.get("integrity", 1.0)),
					"state": int(existing.get("state", ComponentState.NOMINAL)),
				}
	_components.clear()
	for component_id: StringName in COMPONENT_ORDER:
		var placement: Dictionary = layout[component_id]
		var carried: Dictionary = preserved.get(component_id, {})
		var integrity := clampf(float(carried.get("integrity", 1.0)), 0.0, 1.0)
		_components[component_id] = {
			"id": component_id,
			"integrity": integrity,
			"state": state_for_integrity(integrity),
			"local_position": placement.local_position as Vector3,
			"local_radius": float(placement.local_radius),
		}
	_local_bounds = local_bounds
	_maximum_hull = maximum_hull
	_configured = true
	_revision += 1
	return true


func is_configured() -> bool:
	return _configured


func get_revision() -> int:
	return _revision


func get_component_count() -> int:
	return _components.size()


## Attributes one already-resolved damage event to the roster.
##
## [param amount] is the hull damage the owning ship has accepted; this node does
## not decide whether it applies. [param local_hit_position] is in the ship's own
## local space. A non-finite position is a legitimate unlocated hit (a scripted
## or lifecycle kill with no contact point) and is spread evenly across the
## roster rather than rejected.
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
	if not _configured:
		report["reason"] = &"not_configured"
		return report
	if not is_finite(amount) or amount <= 0.0:
		report["reason"] = &"invalid_damage"
		return report

	var normalized := clampf(amount / _maximum_hull, 0.0, 1.0)
	var located := local_hit_position.is_finite()
	var weights := (
		_attribution_weights(local_hit_position)
		if located
		else _uniform_weights()
	)
	var deltas: Dictionary = {}
	for component_id: StringName in COMPONENT_ORDER:
		var weight := float(weights.get(component_id, 0.0))
		if weight <= 0.0:
			continue
		var component: Dictionary = _components[component_id]
		var before := float(component.integrity)
		if before <= 0.0:
			continue
		var after := clampf(before - normalized * weight * ATTRIBUTION_GAIN, 0.0, 1.0)
		if is_equal_approx(after, before):
			continue
		component["integrity"] = after
		deltas[component_id] = before - after
		_apply_state(component_id, component)
	if deltas.is_empty():
		report["reason"] = &"no_component_effect"
		report["located"] = located
		report["normalized_damage"] = normalized
		return report

	_revision += 1
	report["accepted"] = true
	report["located"] = located
	report["normalized_damage"] = normalized
	report["revision"] = _revision
	report["components"] = deltas
	return report


## Advances repair by one simulation step.
##
## [param repairing] is the owner's berthed/parked reading. Repair never runs on
## its own timer and never reads the wall clock, so a headless test and a live
## frame advance it identically.
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
	if not _configured:
		report["reason"] = &"not_configured"
		return report
	if not is_finite(delta) or delta <= 0.0:
		report["reason"] = &"invalid_delta"
		return report
	if not repairing:
		report["reason"] = &"repair_not_authorized"
		return report

	var step := repair_rate_per_second * delta
	var repaired := 0
	for component_id: StringName in COMPONENT_ORDER:
		var component: Dictionary = _components[component_id]
		var before := float(component.integrity)
		if before >= 1.0:
			continue
		component["integrity"] = clampf(before + step, 0.0, 1.0)
		_apply_state(component_id, component)
		repaired += 1
	if repaired == 0:
		report["reason"] = &"already_nominal"
		return report
	_revision += 1
	report["accepted"] = true
	report["repaired_components"] = repaired
	report["revision"] = _revision
	return report


## Instantly restores the whole roster. This is the respawn/regeneration path:
## the owning craft's own `reset_for_reuse()` calls it, so a recovered craft is
## never held back by an in-progress repair. The name deliberately matches the
## lifecycle verb every other recyclable component in this project uses.
func reset_for_reuse() -> void:
	if _owner_mutation_transaction_active:
		return
	_reset_for_reuse_unchecked()


## One-time owner claim. An opaque RefCounted identity is deliberately used
## instead of an instance ID or integer token that a synchronous callback could
## guess or reconstruct. Duplicate and pre-configuration claims fail closed.
func claim_owner_mutation_capability() -> RefCounted:
	if _owner_mutation_capability_claimed or not _configured:
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


## Starts the guard before Hero emits any reset-adjacent signal. Only the exact
## one-time capability can start or end it; nested, stale, and foreign attempts
## leave the current transaction untouched.
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


## The sole mutation permitted while the owner guard is active. Capability and
## active-transaction identity are checked before the first integrity change;
## signal callbacks cannot reuse this path without the Hero-retained object.
func reset_for_reuse_as_owner(capability: RefCounted) -> bool:
	if not _owner_mutation_transaction_active \
			or not is_owner_mutation_capability_current(capability):
		return false
	_reset_for_reuse_unchecked()
	return true


func _reset_for_reuse_unchecked() -> void:
	if not _configured:
		return
	for component_id: StringName in COMPONENT_ORDER:
		var component: Dictionary = _components[component_id]
		component["integrity"] = 1.0
		_apply_state(component_id, component)
	_revision += 1
	components_restored.emit()


func get_component_integrity(component_id: StringName) -> float:
	var component: Dictionary = _components.get(component_id, {})
	if component.is_empty():
		return -1.0
	return float(component.integrity)


func get_component_state(component_id: StringName) -> int:
	var component: Dictionary = _components.get(component_id, {})
	if component.is_empty():
		return -1
	return int(component.state)


func get_worst_integrity() -> float:
	if not _configured:
		return 1.0
	var worst := 1.0
	for component_id: StringName in COMPONENT_ORDER:
		worst = minf(worst, float((_components[component_id] as Dictionary).integrity))
	return worst


func get_failed_component_count() -> int:
	return _count_state(ComponentState.FAILED)


func get_impaired_component_count() -> int:
	return _count_state(ComponentState.IMPAIRED)


## Presentation feed. Returns a fresh array of value copies in roster order so a
## consumer can never mutate model state through it.
func get_component_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if not _configured:
		return states
	for component_id: StringName in COMPONENT_ORDER:
		var component: Dictionary = _components[component_id]
		states.append({
			"id": component_id,
			"state": int(component.state),
			"state_id": state_id_for(int(component.state)),
			"integrity": float(component.integrity),
			"local_position": component.local_position as Vector3,
			"local_radius": float(component.local_radius),
		})
	return states


## Auditable report. Deep-copied, so callers cannot reach model state.
func get_component_report() -> Dictionary:
	var components: Array[Dictionary] = get_component_states()
	return {
		"schema_version": SCHEMA_VERSION,
		"interpretation": INTERPRETATION,
		"configured": _configured,
		"maximum_hull": _maximum_hull,
		"local_bounds": _local_bounds,
		"revision": _revision,
		"component_count": components.size(),
		"failed_count": get_failed_component_count(),
		"impaired_count": get_impaired_component_count(),
		"worst_integrity": get_worst_integrity(),
		"repair_rate_per_second": repair_rate_per_second,
		"components": components,
		"component_order": COMPONENT_ORDER.duplicate(),
	}


static func state_id_for(state: int) -> StringName:
	match state:
		ComponentState.IMPAIRED:
			return STATE_ID_IMPAIRED
		ComponentState.FAILED:
			return STATE_ID_FAILED
		ComponentState.NOMINAL:
			return STATE_ID_NOMINAL
	return &"invalid"


func _count_state(state: int) -> int:
	var total := 0
	for component_id: StringName in COMPONENT_ORDER:
		var component: Dictionary = _components.get(component_id, {})
		if not component.is_empty() and int(component.state) == state:
			total += 1
	return total


func _apply_state(component_id: StringName, component: Dictionary) -> void:
	var next_state := state_for_integrity(float(component.integrity))
	if int(component.state) == next_state:
		return
	component["state"] = next_state
	component_state_changed.emit(component_id, next_state, float(component.integrity))


## The whole classification rule, exposed so a consumer and a boundary test read
## the same function the model uses. Both thresholds are inclusive downwards.
static func state_for_integrity(integrity: float) -> int:
	if not is_finite(integrity):
		return ComponentState.FAILED
	if integrity <= FAILED_THRESHOLD:
		return ComponentState.FAILED
	if integrity <= IMPAIRED_THRESHOLD:
		return ComponentState.IMPAIRED
	return ComponentState.NOMINAL


func _uniform_weights() -> Dictionary:
	var share := 1.0 / float(COMPONENT_ORDER.size())
	var weights: Dictionary = {}
	for component_id: StringName in COMPONENT_ORDER:
		weights[component_id] = share
	return weights


## Closed-form squared-falloff attribution, normalized to a total share of one so
## the model can never spend more integrity than the hit is worth. A hit outside
## every splash radius is credited entirely to the nearest section.
func _attribution_weights(local_hit_position: Vector3) -> Dictionary:
	var raw: Dictionary = {}
	var total := 0.0
	var nearest_id: StringName = COMPONENT_ORDER[0]
	var nearest_distance := INF
	for component_id: StringName in COMPONENT_ORDER:
		var component: Dictionary = _components[component_id]
		var distance := (component.local_position as Vector3).distance_to(local_hit_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = component_id
		var reach := float(component.local_radius) * SPLASH_SCALE
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


## Ship-local placement. Forward is -Z and starboard is +X, matching the flight
## code's `-global_basis.z` forward convention.
func _derive_layout(local_bounds: AABB) -> Dictionary:
	var centre := local_bounds.get_center()
	var extents := local_bounds.size * 0.5
	if not centre.is_finite() or not extents.is_finite():
		return {}
	var longitudinal_radius := maxf(extents.z * 0.55, MINIMUM_COMPONENT_RADIUS)
	var lateral_radius := maxf(extents.x * 0.55, MINIMUM_COMPONENT_RADIUS)
	var core_radius := maxf((extents.x + extents.z) * 0.28, MINIMUM_COMPONENT_RADIUS)
	# Each anchor is lifted towards the upper hull so a venting section emits into
	# clear space instead of inside the airframe it belongs to. Every anchor still
	# lies inside the craft's own collision envelope.
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
	if not size.is_finite() or not position.is_finite():
		return false
	return size.x > 0.0 and size.y > 0.0 and size.z > 0.0
