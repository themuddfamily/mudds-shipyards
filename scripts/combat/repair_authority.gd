class_name RepairAuthority
extends RefCounted

## Generation-scoped authorization for one component repair action.
##
## This contract owns neither the component ledger nor tool presentation.  It
## validates the actor's current seat/range/resource envelope, reserves one
## repair token, and commits exactly one operation into ComponentDamageModel.
## A caller must drive `advance()` from its physics owner; no wall clock or
## scene-tree state is read here.

const ComponentDamageModelType := preload("res://scripts/combat/component_damage_model.gd")

const SCHEMA_VERSION := 1
const MAX_ID_LENGTH := 64
const MAX_RANGE_METERS := 100.0
const MAX_COOLDOWN_SECONDS := 60.0
const MAX_REPAIR_AMOUNT := 1_000_000_000.0
const MAX_RESOURCE_UNITS := 1_000_000
const MAX_REQUEST_SEQUENCE := 9_007_199_254_740_991
const ADMISSION_SERVICE_TERMINAL: StringName = &"service_terminal"
const DAMAGE_KIND_COMBAT: StringName = &"combat"
const DAMAGE_KIND_COLLISION: StringName = &"collision"

signal repair_started(receipt: Dictionary)
signal repair_committed(receipt: Dictionary)
signal repair_interrupted(receipt: Dictionary)

var _actor_id: StringName
var _target_id: StringName
var _resource_id: StringName
var _max_range_meters := 0.0
var _cooldown_seconds := 0.0
var _repair_amount := 0.0
var _initial_resource_units := 0
var _resource_units := 0
var _generation := 0
var _cooldown_remaining := 0.0
var _next_token := 1
var _active: Dictionary = {}
var _configuration_errors := PackedStringArray()
var _service_terminal_id: StringName
var _service_terminal_generation := 0
var _service_actor_range_meters := 0.0
var _last_service_request_sequence := 0
## Revision fence injected by the owning HeroShip immediately before it routes
## a combat/collision observation into ShipComponentDamage. RepairAuthority
## never reads or mutates damage health; it only decides whether the resulting
## accepted receipt is new enough to interrupt its currently reserved token.
var _observed_component_damage_revision := -1


func _init(
	p_actor_id: StringName = &"",
	p_target_id: StringName = &"",
	p_resource_id: StringName = &"repair_kit",
	p_max_range_meters: float = 3.0,
	p_cooldown_seconds: float = 1.0,
	p_repair_amount: float = 1.0,
	p_resource_units: int = 1,
	p_service_terminal_id: StringName = &"",
	p_service_terminal_generation: int = 0,
	p_service_actor_range_meters: float = 0.0
	) -> void:
	_actor_id = p_actor_id
	_target_id = p_target_id
	_resource_id = p_resource_id
	_max_range_meters = p_max_range_meters
	_cooldown_seconds = p_cooldown_seconds
	_repair_amount = p_repair_amount
	_initial_resource_units = p_resource_units
	_resource_units = p_resource_units
	_service_terminal_id = p_service_terminal_id
	_service_terminal_generation = p_service_terminal_generation
	_service_actor_range_meters = p_service_actor_range_meters
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func get_generation() -> int:
	return _generation


func get_resource_units() -> int:
	return _resource_units


func get_resource_capacity() -> int:
	return _initial_resource_units


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func has_active_repair() -> bool:
	return not _active.is_empty()


## Starts a fresh lifecycle generation and clears stale action/cooldown state.
## Resource charges are restored from the authored generation envelope exactly
## once; duplicate or stale generation starts cannot refill them.
func begin_generation(generation: int) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if generation <= 0:
		return _result(false, &"invalid_generation")
	if generation <= _generation:
		return _result(false, &"stale_generation")
	if not _active.is_empty():
		_emit_interruption(&"generation_changed")
	_generation = generation
	_resource_units = _initial_resource_units
	_cooldown_remaining = 0.0
	_active.clear()
	return _result(true, &"generation_started")


## Transfers the same live repair inventory to a newly admitted actor without
## recreating the authority. Crew-seat authority has already validated the
## handoff; this method keeps the ship-generation resource and cooldown ledger
## intact while changing the actor fence used by the next request.
func rebind_actor(actor_id: StringName, generation: int) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if generation <= 0 or generation != _generation:
		return _result(false, &"stale_generation")
	if not _is_stable_id(actor_id):
		return _result(false, &"invalid_actor")
	if not _active.is_empty():
		return _result(false, &"repair_active")
	if actor_id == _actor_id:
		return _result(true, &"actor_unchanged")
	_actor_id = actor_id
	_observed_component_damage_revision = -1
	return _result(true, &"actor_rebound")


## Advances only the injected physics delta.  An active repair remains pending
## until its owner explicitly commits or interrupts it.
func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	return _result(true, &"advanced")


## Validates the immutable request envelope and reserves one token. The exact
## context is actor_id, target_id, component_id, generation, distance_meters,
## seated, resource_id, and interrupted. A caller may include `repair` up to
## the configured amount; omitting it retains the authored fixed pulse. Health
## is checked at commit time against authority, avoiding a stale read window.
func request_repair(context: Dictionary) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _generation <= 0:
		return _result(false, &"inactive_generation")
	if not _active.is_empty():
		return _result(false, &"already_repairing")
	if _canonical_id(_field(context, "admission_kind", &"")) == ADMISSION_SERVICE_TERMINAL:
		return _request_service_terminal_repair(context)
	if _cooldown_remaining > 0.0:
		return _result(false, &"cooldown")
	if _resource_units <= 0:
		return _result(false, &"resource_exhausted")
	var required_keys := [
		"actor_id", "target_id", "component_id", "generation",
		"distance_meters", "seated", "resource_id", "interrupted",
	]
	var requested_amount_keys := required_keys + ["repair"]
	var has_requested_amount := _has_exact_keys(context, requested_amount_keys)
	if not _has_exact_keys(context, required_keys) and not has_requested_amount:
		return _result(false, &"invalid_context")
	var actor_id := _canonical_id(_field(context, "actor_id", &""))
	var target_id := _canonical_id(_field(context, "target_id", &""))
	var component_id := _canonical_id(_field(context, "component_id", &""))
	var resource_id := _canonical_id(_field(context, "resource_id", &""))
	if actor_id != _actor_id:
		return _result(false, &"actor_mismatch")
	if target_id != _target_id:
		return _result(false, &"target_mismatch")
	if resource_id != _resource_id:
		return _result(false, &"resource_mismatch")
	if not _is_stable_id(component_id):
		return _result(false, &"invalid_component")
	var raw_generation: Variant = _field(context, "generation", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return _result(false, &"stale_generation")
	var raw_distance: Variant = _field(context, "distance_meters", null)
	if not raw_distance is int and not raw_distance is float:
		return _result(false, &"invalid_distance")
	var distance := float(raw_distance)
	if not is_finite(distance) or distance < 0.0 or distance > _max_range_meters:
		return _result(false, &"out_of_range")
	if not _field(context, "seated", false) is bool or not bool(_field(context, "seated", false)):
		return _result(false, &"seat_required")
	if not _field(context, "interrupted", false) is bool:
		return _result(false, &"invalid_interruption")
	if bool(_field(context, "interrupted", false)):
		return _result(false, &"interrupted")
	var repair := _repair_amount
	if has_requested_amount:
		var raw_repair: Variant = _field(context, "repair", NAN)
		if not (raw_repair is int or raw_repair is float) \
				or not is_finite(float(raw_repair)) \
				or float(raw_repair) <= 0.0 \
				or float(raw_repair) > _repair_amount:
			return _result(false, &"invalid_repair_amount")
		repair = float(raw_repair)

	var token := _next_token
	_next_token += 1
	_active = {
		"token": token,
		"actor_id": _actor_id,
		"target_id": _target_id,
		"component_id": component_id,
		"generation": _generation,
		"repair": repair,
	}
	_observed_component_damage_revision = -1
	var receipt := _result(true, &"requested")
	receipt["token"] = token
	receipt["component_id"] = component_id
	receipt["resource_units"] = _resource_units
	repair_started.emit(receipt.duplicate(true))
	return receipt


## Alternate admission for a physical, caller-owned service terminal. It uses
## the same reservation, resource, cooldown and component commit transaction as
## engineer-seat repair, but requires explicit on-foot/landed/ownership and
## terminal-generation evidence instead of pretending the actor is seated.
func _request_service_terminal_repair(context: Dictionary) -> Dictionary:
	var required_keys := [
		"actor_id", "target_id", "component_id", "generation",
		"distance_meters", "actor_distance_meters", "resource_id", "interrupted",
		"admission_kind", "terminal_id", "terminal_generation", "request_sequence",
		"player_on_foot", "craft_landed", "craft_owned",
	]
	var requested_amount_keys := required_keys + ["repair"]
	var has_requested_amount := _has_exact_keys(context, requested_amount_keys)
	if not _has_exact_keys(context, required_keys) and not has_requested_amount:
		return _result(false, &"invalid_service_terminal_context")
	if _service_terminal_id.is_empty() or _service_terminal_generation <= 0 \
			or not is_finite(_service_actor_range_meters) \
			or _service_actor_range_meters <= 0.0:
		return _result(false, &"service_terminal_unavailable")
	var actor_id := _canonical_id(_field(context, "actor_id", &""))
	var target_id := _canonical_id(_field(context, "target_id", &""))
	var component_id := _canonical_id(_field(context, "component_id", &""))
	var resource_id := _canonical_id(_field(context, "resource_id", &""))
	if actor_id != _actor_id:
		return _result(false, &"actor_mismatch")
	if target_id != _target_id:
		return _result(false, &"target_mismatch")
	if resource_id != _resource_id:
		return _result(false, &"resource_mismatch")
	if not _is_stable_id(component_id):
		return _result(false, &"invalid_component")
	if _canonical_id(_field(context, "terminal_id", &"")) != _service_terminal_id:
		return _result(false, &"terminal_mismatch")
	var raw_generation: Variant = _field(context, "generation", null)
	var raw_terminal_generation: Variant = _field(context, "terminal_generation", null)
	var raw_sequence: Variant = _field(context, "request_sequence", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return _result(false, &"stale_generation")
	if not raw_terminal_generation is int \
			or int(raw_terminal_generation) != _service_terminal_generation:
		return _result(false, &"stale_terminal_generation")
	if not raw_sequence is int or int(raw_sequence) <= _last_service_request_sequence \
			or int(raw_sequence) < 1 or int(raw_sequence) > MAX_REQUEST_SEQUENCE:
		return _result(false, &"stale_request_sequence")
	var raw_distance: Variant = _field(context, "distance_meters", null)
	var raw_actor_distance: Variant = _field(context, "actor_distance_meters", null)
	if (not raw_distance is int and not raw_distance is float) \
			or (not raw_actor_distance is int and not raw_actor_distance is float):
		return _result(false, &"invalid_distance")
	var distance := float(raw_distance)
	var actor_distance := float(raw_actor_distance)
	if not is_finite(distance) or distance < 0.0 or distance > _max_range_meters:
		return _result(false, &"out_of_range")
	if not is_finite(actor_distance) or actor_distance < 0.0 \
			or actor_distance > _service_actor_range_meters:
		return _result(false, &"actor_out_of_range")
	for flag in ["player_on_foot", "craft_landed", "craft_owned"]:
		if _field(context, flag, false) is not bool or not bool(_field(context, flag, false)):
			return _result(false, StringName("%s_required" % flag))
	if _field(context, "interrupted", false) is not bool:
		return _result(false, &"invalid_interruption")
	if bool(_field(context, "interrupted", false)):
		return _result(false, &"interrupted")
	if _cooldown_remaining > 0.0:
		return _result(false, &"cooldown")
	if _resource_units <= 0:
		return _result(false, &"resource_exhausted")
	var repair := _repair_amount
	if has_requested_amount:
		var raw_repair: Variant = _field(context, "repair", NAN)
		if not (raw_repair is int or raw_repair is float) \
				or not is_finite(float(raw_repair)) or float(raw_repair) <= 0.0 \
				or float(raw_repair) > _repair_amount:
			return _result(false, &"invalid_repair_amount")
		repair = float(raw_repair)
	_last_service_request_sequence = int(raw_sequence)
	var token := _next_token
	_next_token += 1
	_active = {
		"token": token,
		"actor_id": _actor_id,
		"target_id": _target_id,
		"component_id": component_id,
		"generation": _generation,
		"repair": repair,
		"admission_kind": ADMISSION_SERVICE_TERMINAL,
		"terminal_id": _service_terminal_id,
		"terminal_generation": _service_terminal_generation,
		"request_sequence": _last_service_request_sequence,
	}
	_observed_component_damage_revision = -1
	var receipt := _result(true, &"requested")
	receipt["token"] = token
	receipt["component_id"] = component_id
	receipt["resource_units"] = _resource_units
	receipt["admission_kind"] = ADMISSION_SERVICE_TERMINAL
	receipt["terminal_id"] = _service_terminal_id
	receipt["terminal_generation"] = _service_terminal_generation
	receipt["request_sequence"] = _last_service_request_sequence
	repair_started.emit(receipt.duplicate(true))
	return receipt


## Commits the reserved token into the authoritative component model once.
## Failed commits consume neither resource nor cooldown, but always clear the
## token so a stale caller cannot replay it after the model changes generation.
func commit_repair(model: ComponentDamageModel, token: int = -1) -> Dictionary:
	if _active.is_empty():
		return _result(false, &"no_active_repair")
	var active_token := int(_active.get("token", -1))
	if token < 0:
		token = active_token
	if token != active_token:
		return _result(false, &"stale_token")
	var component_id := StringName(_active.get("component_id", &""))
	var expected_generation := int(_active.get("generation", -1))
	if model == null or not is_instance_valid(model):
		_active.clear()
		return _result(false, &"model_unavailable")
	if model.get_generation() != expected_generation:
		_active.clear()
		return _result(false, &"stale_generation")
	var component := model.get_component_state(component_id)
	if component.is_empty():
		_active.clear()
		return _result(false, &"unknown_component")
	var current := float(component.get("current_health", NAN))
	var maximum := float(component.get("maximum_health", NAN))
	if not is_finite(current) or not is_finite(maximum) or current >= maximum:
		_active.clear()
		return _result(false, &"component_not_damaged")
	var repair := minf(float(_active.get("repair", 0.0)), maximum - current)
	var operation := model.apply_component_repair({
		"component_id": component_id,
		"repair": repair,
		"generation": expected_generation,
		"sequence": model.get_last_operation_sequence() + 1,
	})
	return _finish_commit(active_token, component_id, operation)


## Commits through ShipComponentDamage's component-targeted adapter instead of
## exposing its private generic ledger. The authority still owns reservation,
## generation, resource and cooldown; the adapter remains the only ship-local
## repair mutator and preserves its revision and presentation signals.
func commit_component_repair(model: Object, token: int = -1) -> Dictionary:
	if _active.is_empty():
		return _result(false, &"no_active_repair")
	var active_token := int(_active.get("token", -1))
	if token < 0:
		token = active_token
	if token != active_token:
		return _result(false, &"stale_token")
	var component_id := StringName(_active.get("component_id", &""))
	var expected_generation := int(_active.get("generation", -1))
	if model == null or not is_instance_valid(model) \
			or not model.has_method(&"get_ledger_generation") \
			or not model.has_method(&"get_component_integrity") \
			or not model.has_method(&"get_component_report") \
			or not model.has_method(&"tick_component_repair"):
		_active.clear()
		return _result(false, &"model_unavailable")
	if int(model.call(&"get_ledger_generation")) != expected_generation:
		_active.clear()
		return _result(false, &"stale_generation")
	var current := float(model.call(&"get_component_integrity", component_id))
	if not is_finite(current) or current < 0.0:
		_active.clear()
		return _result(false, &"unknown_component")
	if current >= 1.0:
		_active.clear()
		return _result(false, &"component_not_damaged")
	var report := model.call(&"get_component_report") as Dictionary
	var rate := maxf(float(report.get("repair_rate_per_second", 0.0)), 0.05)
	var repair := minf(float(_active.get("repair", 0.0)), 1.0 - current)
	var operation := model.call(
		&"tick_component_repair", component_id, repair / rate, true
	) as Dictionary
	return _finish_commit(active_token, component_id, operation)


func _finish_commit(
	active_token: int,
	component_id: StringName,
	operation: Dictionary
) -> Dictionary:
	var admission_kind := StringName(_active.get("admission_kind", &""))
	var terminal_id := StringName(_active.get("terminal_id", &""))
	var terminal_generation := int(_active.get("terminal_generation", 0))
	var request_sequence := int(_active.get("request_sequence", 0))
	_active.clear()
	if not bool(operation.get("accepted", false)):
		var rejected := _result(false, StringName(operation.get("reason", &"model_rejected")))
		rejected["operation"] = operation.duplicate(true)
		return rejected
	_resource_units -= 1
	_cooldown_remaining = _cooldown_seconds
	var receipt := _result(true, &"committed")
	receipt["token"] = active_token
	receipt["component_id"] = component_id
	receipt["resource_units"] = _resource_units
	receipt["cooldown_remaining"] = _cooldown_remaining
	receipt["operation"] = operation.duplicate(true)
	if admission_kind == ADMISSION_SERVICE_TERMINAL:
		receipt["admission_kind"] = admission_kind
		receipt["terminal_id"] = terminal_id
		receipt["terminal_generation"] = terminal_generation
		receipt["request_sequence"] = request_sequence
	repair_committed.emit(receipt.duplicate(true))
	return receipt


func interrupt(reason: StringName = &"interrupted") -> Dictionary:
	if _active.is_empty():
		return _result(false, &"no_active_repair")
	return _emit_interruption(reason)


## Captures the current component revision before HeroShip asks its existing
## damage adapter to record an already-authorized hull loss. This is an
## observation fence only: it grants no health/damage authority and deliberately
## excludes the synchronous service-terminal admission path.
func observe_component_damage_revision(context: Dictionary) -> Dictionary:
	if _active.is_empty():
		return _result(false, &"no_active_repair")
	if StringName(_active.get("admission_kind", &"")) == ADMISSION_SERVICE_TERMINAL:
		return _result(false, &"service_terminal_not_interruptible")
	if not _has_exact_keys(context, ["target_id", "generation", "revision"]):
		return _result(false, &"invalid_damage_observation")
	if _canonical_id(_field(context, "target_id", &"")) != _target_id:
		return _result(false, &"target_mismatch")
	var raw_generation: Variant = _field(context, "generation", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return _result(false, &"stale_generation")
	var raw_revision: Variant = _field(context, "revision", null)
	if not raw_revision is int or int(raw_revision) < 0:
		return _result(false, &"invalid_damage_revision")
	var revision := int(raw_revision)
	if _observed_component_damage_revision >= 0 \
			and revision < _observed_component_damage_revision:
		return _result(false, &"stale_damage_revision")
	_observed_component_damage_revision = revision
	var observed := _result(true, &"damage_revision_observed")
	observed["revision"] = revision
	return observed


## Interrupts exactly one pending engineer repair only when the owning HeroShip
## supplies the accepted component receipt immediately following the observed
## revision above. Unrelated targets, generations, rejected component damage,
## stale/replayed revisions, and non-combat semantics leave the token active.
func interrupt_for_authoritative_component_damage(context: Dictionary) -> Dictionary:
	if _active.is_empty():
		return _result(false, &"no_active_repair")
	if StringName(_active.get("admission_kind", &"")) == ADMISSION_SERVICE_TERMINAL:
		return _result(false, &"service_terminal_not_interruptible")
	var required_keys := [
		"target_id", "generation", "previous_revision", "revision",
		"accepted", "damage_kind", "component_ids",
	]
	if not _has_exact_keys(context, required_keys):
		return _result(false, &"invalid_damage_observation")
	if _canonical_id(_field(context, "target_id", &"")) != _target_id:
		return _result(false, &"target_mismatch")
	var raw_generation: Variant = _field(context, "generation", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return _result(false, &"stale_generation")
	var raw_accepted: Variant = _field(context, "accepted", null)
	if not raw_accepted is bool:
		return _result(false, &"invalid_damage_acceptance")
	if not bool(raw_accepted):
		return _result(false, &"damage_rejected")
	var damage_kind := _canonical_id(_field(context, "damage_kind", &""))
	if damage_kind != DAMAGE_KIND_COMBAT and damage_kind != DAMAGE_KIND_COLLISION:
		return _result(false, &"unsupported_damage_kind")
	var raw_previous_revision: Variant = _field(context, "previous_revision", null)
	var raw_revision: Variant = _field(context, "revision", null)
	if not raw_previous_revision is int or not raw_revision is int:
		return _result(false, &"invalid_damage_revision")
	var previous_revision := int(raw_previous_revision)
	var revision := int(raw_revision)
	if _observed_component_damage_revision < 0:
		return _result(false, &"damage_revision_unobserved")
	if previous_revision != _observed_component_damage_revision \
			or revision <= previous_revision:
		return _result(false, &"stale_damage_revision")
	# ShipComponentDamage advances its public adapter revision exactly once for
	# one accepted homogeneous damage batch. A skipped value is not the receipt
	# paired with the observation above and therefore fails closed.
	if revision != previous_revision + 1:
		return _result(false, &"unpaired_damage_revision")
	var raw_component_ids: Variant = _field(context, "component_ids", null)
	if not raw_component_ids is Array or raw_component_ids.is_empty() \
			or raw_component_ids.size() > 64:
		return _result(false, &"invalid_damage_components")
	var component_ids: Array[StringName] = []
	for raw_component_id: Variant in raw_component_ids:
		var component_id := _canonical_id(raw_component_id)
		if not _is_stable_id(component_id) or component_ids.has(component_id):
			return _result(false, &"invalid_damage_components")
		component_ids.append(component_id)
	_observed_component_damage_revision = revision
	return _emit_interruption(&"authoritative_component_damage", {
		"damage_kind": damage_kind,
		"damage_revision": revision,
		"component_ids": component_ids.duplicate(),
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"actor_id": _actor_id,
		"target_id": _target_id,
		"resource_id": _resource_id,
		"max_range_meters": _max_range_meters,
		"cooldown_seconds": _cooldown_seconds,
		"repair_amount": _repair_amount,
		"resource_capacity": _initial_resource_units,
		"resource_units": _resource_units,
		"generation": _generation,
		"cooldown_remaining": _cooldown_remaining,
		"active": not _active.is_empty(),
		"observed_component_damage_revision": _observed_component_damage_revision,
		"service_terminal": {
			"configured": not _service_terminal_id.is_empty(),
			"terminal_id": _service_terminal_id,
			"terminal_generation": _service_terminal_generation,
			"actor_range_meters": _service_actor_range_meters,
			"last_request_sequence": _last_service_request_sequence,
		},
		"configuration_errors": get_configuration_errors(),
		"authority": {
			"damage": false,
			"collision": false,
			"presentation": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	return {"valid": is_configuration_valid(), "contract": get_snapshot()}.duplicate(true)


func _emit_interruption(reason: StringName, semantics: Dictionary = {}) -> Dictionary:
	var receipt := _result(true, reason)
	receipt["token"] = int(_active.get("token", -1))
	receipt["component_id"] = StringName(_active.get("component_id", &""))
	if StringName(_active.get("admission_kind", &"")) == ADMISSION_SERVICE_TERMINAL:
		receipt["admission_kind"] = ADMISSION_SERVICE_TERMINAL
		receipt["terminal_id"] = StringName(_active.get("terminal_id", &""))
		receipt["terminal_generation"] = int(_active.get("terminal_generation", 0))
		receipt["request_sequence"] = int(_active.get("request_sequence", 0))
	for key: Variant in semantics:
		receipt[key] = semantics[key]
	_active.clear()
	repair_interrupted.emit(receipt.duplicate(true))
	return receipt


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"resource_capacity": _initial_resource_units,
		"resource_units": _resource_units,
		"cooldown_remaining": _cooldown_remaining,
	}


func _validate_configuration() -> void:
	if not _is_stable_id(_actor_id):
		_configuration_errors.append("actor_id must be a stable identifier")
	if not _is_stable_id(_target_id):
		_configuration_errors.append("target_id must be a stable identifier")
	if not _is_stable_id(_resource_id):
		_configuration_errors.append("resource_id must be a stable identifier")
	if not is_finite(_max_range_meters) or _max_range_meters <= 0.0 or _max_range_meters > MAX_RANGE_METERS:
		_configuration_errors.append("max range is outside its finite bound")
	if not is_finite(_cooldown_seconds) or _cooldown_seconds < 0.0 or _cooldown_seconds > MAX_COOLDOWN_SECONDS:
		_configuration_errors.append("cooldown is outside its finite bound")
	if not is_finite(_repair_amount) or _repair_amount <= 0.0 or _repair_amount > MAX_REPAIR_AMOUNT:
		_configuration_errors.append("repair amount is outside its finite bound")
	if _initial_resource_units < 0 or _initial_resource_units > MAX_RESOURCE_UNITS:
		_configuration_errors.append("resource units are outside their finite bound")
	var service_disabled := _service_terminal_id.is_empty() \
		and _service_terminal_generation == 0 \
		and is_zero_approx(_service_actor_range_meters)
	var service_valid := _is_stable_id(_service_terminal_id) \
		and _service_terminal_generation > 0 \
		and _service_terminal_generation <= MAX_REQUEST_SEQUENCE \
		and is_finite(_service_actor_range_meters) \
		and _service_actor_range_meters > 0.0 \
		and _service_actor_range_meters <= MAX_RANGE_METERS
	if not service_disabled and not service_valid:
		_configuration_errors.append("service terminal envelope is incomplete or invalid")


static func _is_stable_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		if index == 0 and (code < 97 or code > 122):
			return false
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	return not text.begins_with("_") and not text.ends_with("_") and not text.contains("__")


static func _canonical_id(value: Variant) -> StringName:
	return StringName(value) if value is String or value is StringName else &""


static func _field(dictionary: Dictionary, key: String, fallback: Variant) -> Variant:
	if dictionary.has(key):
		return dictionary[key]
	var named := StringName(key)
	return dictionary[named] if dictionary.has(named) else fallback


static func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key in dictionary:
		if not key is String and not key is StringName:
			return false
	for key in expected:
		if not dictionary.has(key) and not dictionary.has(StringName(key)):
			return false
	return true
