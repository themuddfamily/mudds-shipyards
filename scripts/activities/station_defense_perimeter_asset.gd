class_name StationDefensePerimeterAsset
extends StaticBody3D

## Dedicated renewable protected object for the modern station-defense content.
##
## The existing Damageable child named `AuthoritativeDamageable` is the only
## health store and damage authority. This wrapper owns only the protected-object
## generation, bounded observation identity, collision/presentation lifecycle,
## and detached primitive snapshot consumed by StationDefenseEncounterContent.

signal asset_damaged(asset_handle: Dictionary, event_handle: Dictionary)
signal asset_destroyed(asset_handle: Dictionary, event_handle: Dictionary)
signal asset_renewed(asset_handle: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station_defense_perimeter_asset"
const ASSET_ID: StringName = &"station_perimeter_core"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_DAMAGE_EVENTS_PER_GENERATION := 1024

const _AUTHORITY_EXCLUSIONS := {
	"combat_resolution": false,
	"damage_calculation": false,
	"rewards": false,
	"ships": false,
	"berths": false,
	"world_geometry": false,
	"hud": false,
	"game_flow": false,
	"main": false,
	"save": false,
	"network": false,
}

@export_range(1, StationDefenseContract.MAX_SAFE_INTEGER, 1) var handle_generation := 1

var _event_sequence := 0
var _observation_active := false
var _pending_terminal_event: Dictionary = {}
var _last_event_handle: Dictionary = {}
var _damageable: Damageable


func _ready() -> void:
	_damageable = get_node_or_null(^"AuthoritativeDamageable") as Damageable
	_connect_damageable()
	_apply_live_state()


func get_damageable_component() -> Damageable:
	return _damageable if is_instance_valid(_damageable) else null


func get_asset_handle() -> Dictionary:
	return {
		"asset_id": ASSET_ID,
		"generation": handle_generation,
	}.duplicate(true)


func get_next_asset_handle() -> Dictionary:
	if handle_generation >= StationDefenseContract.MAX_SAFE_INTEGER:
		return {}
	return {
		"asset_id": ASSET_ID,
		"generation": handle_generation + 1,
	}.duplicate(true)


## Read-only guard used before activity/host commit. It mirrors every condition
## that can reject physical renewal and changes no generation, health, or signal.
func preflight_renew(expected_generation: int) -> Dictionary:
	if _observation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != handle_generation:
		return _result(false, &"stale_asset_generation")
	if handle_generation >= StationDefenseContract.MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	if not is_instance_valid(_damageable):
		return _result(false, &"damageable_unavailable")
	return _result(true, &"renewal_preflight_ready")


## Renews this exact physical object after the activity has accepted the same
## old->new handle. Health is reset only through the existing Damageable API.
func renew(expected_generation: int) -> Dictionary:
	var preflight := preflight_renew(expected_generation)
	if not bool(preflight.get("accepted", false)):
		return preflight

	handle_generation += 1
	_event_sequence = 0
	_pending_terminal_event.clear()
	_last_event_handle.clear()
	_damageable.reset_health()
	_apply_live_state()
	_observation_active = true
	asset_renewed.emit(get_asset_handle())
	_observation_active = false
	return _result(true, &"renewed")


func get_snapshot() -> Dictionary:
	var health := _damageable.get_health() if is_instance_valid(_damageable) else 0.0
	var maximum := _damageable.get_maximum_health() if is_instance_valid(_damageable) else 0.0
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"asset_handle": get_asset_handle(),
		"health": health,
		"maximum_health": maximum,
		"destroyed": (
			_damageable.is_destroyed() if is_instance_valid(_damageable) else true
		),
		"damage_event_count": _event_sequence,
		"last_event_handle": _last_event_handle.duplicate(true),
		"target_collision_enabled": collision_layer == PhysicsLayers.TARGET,
		"renewable_generation": true,
		"health_authority": &"AuthoritativeDamageable",
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not StationDefenseContract.is_stable_id(ASSET_ID):
		errors.append("asset id is not stable")
	if handle_generation <= 0 or handle_generation > StationDefenseContract.MAX_SAFE_INTEGER:
		errors.append("asset generation is outside its exact bound")
	if not is_instance_valid(_damageable) or _damageable.name != &"AuthoritativeDamageable":
		errors.append("one existing Damageable named AuthoritativeDamageable is required")
	elif _damageable.get_target_entity() != self:
		errors.append("AuthoritativeDamageable must target the perimeter asset root")
	if _event_sequence < 0 or _event_sequence > MAX_DAMAGE_EVENTS_PER_GENERATION:
		errors.append("damage event sequence exceeds its generation bound")
	if get_meta(&"evidence_status", &"") != EVIDENCE_STATUS \
		or bool(get_meta(&"historically_supported", true)):
		errors.append("asset evidence metadata is not explicit modern interpretation")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"limits": {
			"maximum_damage_events_per_generation": MAX_DAMAGE_EVENTS_PER_GENERATION,
			"maximum_generation": StationDefenseContract.MAX_SAFE_INTEGER,
		},
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func _connect_damageable() -> void:
	if not is_instance_valid(_damageable):
		return
	if not _damageable.damage_applied.is_connected(_on_damage_applied):
		_damageable.damage_applied.connect(_on_damage_applied)
	if not _damageable.destroyed.is_connected(_on_destroyed):
		_damageable.destroyed.connect(_on_destroyed)


func _on_damage_applied(
	_amount: float,
	current: float,
	_maximum: float,
	_hit_position: Vector3,
	_hit_normal: Vector3,
	_source_context: Dictionary
	) -> void:
	if _observation_active or _event_sequence >= MAX_DAMAGE_EVENTS_PER_GENERATION:
		return
	_observation_active = true
	_event_sequence += 1
	var event_handle := _make_event_handle(_event_sequence)
	_last_event_handle = event_handle.duplicate(true)
	if current <= 0.0:
		_pending_terminal_event = event_handle.duplicate(true)
	else:
		asset_damaged.emit(get_asset_handle(), event_handle.duplicate(true))
	_observation_active = false


func _on_destroyed(
	_hit_position: Vector3,
	_hit_normal: Vector3,
	_source_context: Dictionary
	) -> void:
	if _observation_active:
		return
	_observation_active = true
	collision_layer = PhysicsLayers.NONE
	collision_mask = PhysicsLayers.NONE
	var event_handle := _pending_terminal_event.duplicate(true)
	if event_handle.is_empty() and _event_sequence < MAX_DAMAGE_EVENTS_PER_GENERATION:
		_event_sequence += 1
		event_handle = _make_event_handle(_event_sequence)
		_last_event_handle = event_handle.duplicate(true)
	_pending_terminal_event.clear()
	if not event_handle.is_empty():
		asset_destroyed.emit(get_asset_handle(), event_handle.duplicate(true))
	_observation_active = false


func _make_event_handle(sequence: int) -> Dictionary:
	return {
		"event_id": StringName("perimeter_hit_%04d" % sequence),
		"generation": handle_generation,
	}


func _apply_live_state() -> void:
	collision_layer = PhysicsLayers.TARGET
	collision_mask = PhysicsLayers.NONE
	visible = true


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)
