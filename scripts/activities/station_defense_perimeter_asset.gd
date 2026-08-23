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
const PRESENTATION_SAFE_THRESHOLD := 0.65
const PRESENTATION_CRITICAL_THRESHOLD := 0.30
const PRESENTATION_RING_SCALE_SAFE := 1.0
const PRESENTATION_RING_SCALE_DANGER := 1.12
const PRESENTATION_RING_SCALE_CRITICAL := 1.28
const PRESENTATION_LIGHT_ENERGY_SAFE := 2.4
const PRESENTATION_LIGHT_ENERGY_DANGER := 3.1
const PRESENTATION_LIGHT_ENERGY_CRITICAL := 4.2
const PRESENTATION_CORE_BASE_POSITION := Vector3(0.0, 2.65, 0.0)
const PRESENTATION_BEARING_OFFSET := 0.85

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
var _has_entered_live_tree := false
var _presentation_root: Node3D
var _signal_ring: MeshInstance3D
var _signal_core: MeshInstance3D
var _signal_light: OmniLight3D
var _presentation_state: StringName = &"safe"
var _presentation_source_snapshot: Dictionary = {}
var _wave_presentation_state: StringName = &"idle"
var _wave_presentation_source_snapshot: Dictionary = {}
var _effective_presentation_state: StringName = &"idle"
var _hostile_bearing_active := false
var _hostile_bearing_local := Vector3.ZERO
var _hostile_bearing_source_snapshot: Dictionary = {}


func _ready() -> void:
	_has_entered_live_tree = true
	_damageable = get_node_or_null(^"AuthoritativeDamageable") as Damageable
	_resolve_presentation_nodes()
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


## Applies only detached, caller-supplied authority state to the existing fixed
## presentation roster. Health, collision, objective, reward and generation are
## never mutated here; invalid or stale snapshots leave the visible state exact.
func apply_authority_presentation_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _presentation_nodes_valid():
		return _result(false, &"presentation_unavailable")
	if (
		StringName(snapshot.get("component_id", &"")) != COMPONENT_ID
		or not snapshot.get("asset_handle") is Dictionary
	):
		return _result(false, &"invalid_presentation_snapshot")
	var handle := snapshot.get("asset_handle") as Dictionary
	if (
		StringName(handle.get("asset_id", &"")) != ASSET_ID
		or int(handle.get("generation", -1)) != handle_generation
	):
		return _result(false, &"stale_presentation_snapshot")
	var health_value: Variant = snapshot.get("health", null)
	var maximum_value: Variant = snapshot.get("maximum_health", null)
	var destroyed_value: Variant = snapshot.get("destroyed", null)
	if (
		not (health_value is float or health_value is int)
		or not (maximum_value is float or maximum_value is int)
		or not destroyed_value is bool
	):
		return _result(false, &"invalid_presentation_snapshot")
	var health := float(health_value)
	var maximum := float(maximum_value)
	if (
		not is_finite(health)
		or not is_finite(maximum)
		or maximum <= 0.0
		or health < 0.0
		or health > maximum
	):
		return _result(false, &"invalid_presentation_snapshot")

	var ratio := clampf(health / maximum, 0.0, 1.0)
	var next_state: StringName = &"safe"
	if bool(destroyed_value) or health <= 0.0:
		next_state = &"destroyed"
	elif ratio <= PRESENTATION_CRITICAL_THRESHOLD:
		next_state = &"critical"
	elif ratio <= PRESENTATION_SAFE_THRESHOLD:
		next_state = &"danger"
	_presentation_state = next_state
	_apply_composed_presentation_state()
	_presentation_source_snapshot = {
		"asset_handle": handle.duplicate(true),
		"health": health,
		"maximum_health": maximum,
		"health_ratio": ratio,
		"destroyed": bool(destroyed_value),
		"damage_event_count": int(snapshot.get("damage_event_count", 0)),
	}.duplicate(true)
	return {
		"accepted": true,
		"reason": &"presentation_snapshot_applied",
		"presentation": get_protected_asset_presentation_snapshot(),
	}.duplicate(true)


## Consumes the detached activity snapshot already published by the encounter
## host. It selects presentation only; wave timing, progression and objectives
## remain wholly caller-owned.
func apply_activity_presentation_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _presentation_nodes_valid():
		return _result(false, &"presentation_unavailable")
	var state_id := StringName(snapshot.get("state_id", &""))
	if state_id not in [&"idle", &"active", &"completed", &"failed", &"aborted", &"timed_out"]:
		return _result(false, &"invalid_activity_presentation_snapshot")
	var wave_index_value: Variant = snapshot.get("current_wave_index", null)
	var wave_count_value: Variant = snapshot.get("wave_count", null)
	var wave_active_value: Variant = snapshot.get("wave_active", null)
	var delay_value: Variant = snapshot.get("wave_delay_remaining_seconds", null)
	if (
		not wave_index_value is int
		or not wave_count_value is int
		or not wave_active_value is bool
		or not (delay_value is float or delay_value is int)
	):
		return _result(false, &"invalid_activity_presentation_snapshot")
	var wave_index := int(wave_index_value)
	var wave_count := int(wave_count_value)
	var delay := float(delay_value)
	if wave_index < 0 or wave_count < 0 or wave_index > wave_count or not is_finite(delay) or delay < 0.0:
		return _result(false, &"invalid_activity_presentation_snapshot")

	var next_wave_state: StringName = &"idle"
	match state_id:
		&"active":
			if bool(wave_active_value):
				next_wave_state = &"active"
			elif wave_index == 0:
				next_wave_state = &"approaching"
			else:
				next_wave_state = &"recovery"
		&"completed":
			next_wave_state = &"completed"
		&"failed", &"aborted", &"timed_out":
			next_wave_state = &"recovery"
		_:
			next_wave_state = &"idle"
	_wave_presentation_state = next_wave_state
	_wave_presentation_source_snapshot = {
		"state_id": state_id,
		"current_wave_index": wave_index,
		"wave_count": wave_count,
		"wave_active": bool(wave_active_value),
		"wave_delay_remaining_seconds": delay,
	}.duplicate(true)
	_apply_composed_presentation_state()
	return {
		"accepted": true,
		"reason": &"activity_presentation_snapshot_applied",
		"presentation": get_protected_asset_presentation_snapshot(),
	}.duplicate(true)


## Reuses the existing luminous core as a horizontal approach-bearing pip.
## The caller supplies only an already-resolved world bearing and exact current
## generations; this method never discovers, targets, or advances a hostile.
func apply_hostile_bearing_presentation_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _presentation_nodes_valid():
		return _result(false, &"presentation_unavailable")
	if not snapshot.get("asset_handle") is Dictionary:
		return _result(false, &"invalid_hostile_bearing_snapshot")
	var asset_handle := snapshot.get("asset_handle") as Dictionary
	var activity_generation_value: Variant = snapshot.get("activity_generation", null)
	var active_value: Variant = snapshot.get("active", null)
	var bearing_value: Variant = snapshot.get("bearing_world", null)
	if (
		StringName(asset_handle.get("asset_id", &"")) != ASSET_ID
		or int(asset_handle.get("generation", -1)) != handle_generation
		or not activity_generation_value is int
		or int(activity_generation_value) != handle_generation
	):
		return _result(false, &"stale_hostile_bearing_snapshot")
	if not active_value is bool or not bearing_value is Vector3:
		return _result(false, &"invalid_hostile_bearing_snapshot")
	var bearing_world := bearing_value as Vector3
	if not bearing_world.is_finite():
		return _result(false, &"invalid_hostile_bearing_snapshot")
	var bearing_local := global_basis.inverse() * bearing_world
	bearing_local.y = 0.0
	if bool(active_value) and bearing_local.length_squared() <= 0.000001:
		return _result(false, &"invalid_hostile_bearing_snapshot")
	_hostile_bearing_active = bool(active_value)
	_hostile_bearing_local = bearing_local.normalized() if _hostile_bearing_active else Vector3.ZERO
	_hostile_bearing_source_snapshot = {
		"asset_handle": asset_handle.duplicate(true),
		"activity_generation": int(activity_generation_value),
		"active": _hostile_bearing_active,
		"bearing_world": bearing_world,
	}.duplicate(true)
	_apply_hostile_bearing_cue()
	return {
		"accepted": true,
		"reason": &"hostile_bearing_snapshot_applied",
		"presentation": get_protected_asset_presentation_snapshot(),
	}.duplicate(true)


func get_protected_asset_presentation_snapshot() -> Dictionary:
	return {
		"state_id": _presentation_state,
		"source": _presentation_source_snapshot.duplicate(true),
		"wave_state_id": _wave_presentation_state,
		"wave_source": _wave_presentation_source_snapshot.duplicate(true),
		"effective_state_id": _effective_presentation_state,
		"hostile_bearing_active": _hostile_bearing_active,
		"hostile_bearing_local": _hostile_bearing_local,
		"hostile_bearing_source": _hostile_bearing_source_snapshot.duplicate(true),
		"core_position": _signal_core.position if is_instance_valid(_signal_core) else Vector3.INF,
		"ring_visible": _signal_ring.visible if is_instance_valid(_signal_ring) else false,
		"ring_scale": _signal_ring.scale.x if is_instance_valid(_signal_ring) else 0.0,
		"core_visible": _signal_core.visible if is_instance_valid(_signal_core) else false,
		"core_scale": _signal_core.scale.x if is_instance_valid(_signal_core) else 0.0,
		"light_visible": _signal_light.visible if is_instance_valid(_signal_light) else false,
		"light_color": _signal_light.light_color if is_instance_valid(_signal_light) else Color.TRANSPARENT,
		"light_energy": _signal_light.light_energy if is_instance_valid(_signal_light) else 0.0,
		"light_range": _signal_light.omni_range if is_instance_valid(_signal_light) else 0.0,
		"budget": {
			"presentation_nodes": 4,
			"mesh_instances": 2,
			"lights": 1,
			"runtime_node_allocation": false,
			"runtime_resource_allocation": false,
			"process_callbacks": 0,
		},
		"authority": {
			"health": false,
			"damage": false,
			"collision": false,
			"targeting": false,
			"objective": false,
			"rewards": false,
		},
	}.duplicate(true)


## Read-only guard used before activity/host commit. It mirrors every condition
## that can reject physical renewal and changes no generation, health, or signal.
func preflight_renew(expected_generation: int) -> Dictionary:
	if _has_entered_live_tree and (is_queued_for_deletion() or not is_inside_tree()):
		return _result(false, &"asset_detached")
	if _observation_active:
		return _result(false, &"reentrant_call")
	if expected_generation != handle_generation:
		return _result(false, &"stale_asset_generation")
	if handle_generation >= StationDefenseContract.MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")
	if not is_instance_valid(_damageable):
		return _result(false, &"damageable_unavailable")
	return _result(true, &"renewal_preflight_ready")


func preflight_pristine_generation_restore(target_generation: int) -> Dictionary:
	if not is_instance_valid(_damageable) or not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"asset_unavailable")
	if (
		target_generation < handle_generation
		or target_generation > StationDefenseContract.MAX_SAFE_INTEGER
		or _event_sequence != 0
		or not _last_event_handle.is_empty()
		or not _pending_terminal_event.is_empty()
		or _damageable.is_destroyed()
		or not is_equal_approx(_damageable.get_health(), _damageable.get_maximum_health())
	):
		return _result(false, &"pristine_asset_required")
	return _result(true, &"pristine_generation_restore_ready")


func restore_pristine_generation(target_generation: int) -> Dictionary:
	var preflight := preflight_pristine_generation_restore(target_generation)
	if not bool(preflight.get("accepted", false)):
		return preflight
	handle_generation = target_generation
	_apply_live_state()
	return _result(true, &"pristine_generation_restored")


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
		"presentation": get_protected_asset_presentation_snapshot(),
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
	if not _presentation_nodes_valid():
		errors.append("fixed protected-asset presentation roster is incomplete")
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


func _resolve_presentation_nodes() -> void:
	_presentation_root = get_node_or_null(^"Presentation") as Node3D
	_signal_ring = get_node_or_null(^"Presentation/SignalRing") as MeshInstance3D
	_signal_core = get_node_or_null(^"Presentation/Core") as MeshInstance3D
	_signal_light = get_node_or_null(^"Presentation/SignalLight") as OmniLight3D


func _presentation_nodes_valid() -> bool:
	return (
		is_instance_valid(_presentation_root)
		and is_instance_valid(_signal_ring)
		and is_instance_valid(_signal_core)
		and is_instance_valid(_signal_light)
		and _signal_ring.get_parent() == _presentation_root
		and _signal_core.get_parent() == _presentation_root
		and _signal_light.get_parent() == _presentation_root
	)


func _apply_composed_presentation_state() -> void:
	var state_id := _wave_presentation_state
	if _presentation_state in [&"danger", &"critical", &"destroyed"]:
		state_id = _presentation_state
	_effective_presentation_state = state_id
	_signal_ring.visible = state_id != &"destroyed"
	_signal_core.visible = state_id != &"destroyed"
	_signal_light.visible = state_id != &"destroyed"
	match state_id:
		&"danger":
			_signal_ring.scale = Vector3.ONE * PRESENTATION_RING_SCALE_DANGER
			_signal_core.scale = Vector3.ONE * 0.92
			_signal_light.light_color = Color("ffb14e")
			_signal_light.light_energy = PRESENTATION_LIGHT_ENERGY_DANGER
			_signal_light.omni_range = 9.5
		&"critical":
			_signal_ring.scale = Vector3.ONE * PRESENTATION_RING_SCALE_CRITICAL
			_signal_core.scale = Vector3.ONE * 0.78
			_signal_light.light_color = Color("ff3b35")
			_signal_light.light_energy = PRESENTATION_LIGHT_ENERGY_CRITICAL
			_signal_light.omni_range = 10.0
		&"destroyed":
			_signal_ring.scale = Vector3.ONE * PRESENTATION_RING_SCALE_CRITICAL
			_signal_core.scale = Vector3.ONE * 0.7
			_signal_light.light_color = Color("ff3b35")
			_signal_light.light_energy = 0.0
			_signal_light.omni_range = 0.0
		&"approaching":
			_signal_ring.scale = Vector3.ONE * 0.86
			_signal_core.scale = Vector3.ONE * 1.08
			_signal_light.light_color = Color("6ba9ff")
			_signal_light.light_energy = 1.8
			_signal_light.omni_range = 8.0
		&"active":
			_signal_ring.scale = Vector3.ONE * 1.18
			_signal_core.scale = Vector3.ONE
			_signal_light.light_color = Color("9beeff")
			_signal_light.light_energy = 3.0
			_signal_light.omni_range = 9.5
		&"recovery":
			_signal_ring.scale = Vector3.ONE * 0.94
			_signal_core.scale = Vector3.ONE * 0.86
			_signal_light.light_color = Color("4fb9a7")
			_signal_light.light_energy = 1.4
			_signal_light.omni_range = 7.5
		&"completed":
			_signal_ring.scale = Vector3.ONE * 1.32
			_signal_core.scale = Vector3.ONE * 1.16
			_signal_light.light_color = Color("77e69a")
			_signal_light.light_energy = 3.4
			_signal_light.omni_range = 10.0
		_:
			_signal_ring.scale = Vector3.ONE * PRESENTATION_RING_SCALE_SAFE
			_signal_core.scale = Vector3.ONE
			_signal_light.light_color = Color(0.282, 0.859, 0.886, 1.0)
			_signal_light.light_energy = PRESENTATION_LIGHT_ENERGY_SAFE
			_signal_light.omni_range = 9.0
	_apply_hostile_bearing_cue()


func _apply_hostile_bearing_cue() -> void:
	if not is_instance_valid(_signal_core):
		return
	_signal_core.position = PRESENTATION_CORE_BASE_POSITION
	if _hostile_bearing_active:
		_signal_core.position += _hostile_bearing_local * PRESENTATION_BEARING_OFFSET


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
