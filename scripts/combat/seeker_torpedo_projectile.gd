class_name SeekerTorpedoProjectile
extends Node3D

## Bounded pool of slow, telegraphed seeker torpedoes that the player can dodge
## or shoot down.
##
## What this component owns:
##   * a fixed, preallocated pool of torpedo bodies (hurtbox, hull, seeker lamp,
##     trail, light, intercept burst per slot)
##   * each live torpedo's world position, heading and elapsed flight
##   * the seeker: a bounded turn rate toward its target, a short straight run
##     off the rail before it starts to steer, and a lock that breaks for good
##     once the target is far enough off its nose (the dodge)
##   * a cheap, non-committing detection sweep and proximity fuse that nominate
##     *where* the torpedo ended
##   * its own small Damageable, so a player shot can destroy it in flight
##   * its TorpedoRunAudio bank: launch, flight loop, intercept and detonation
##     cues, plus the launcher's lock pips forwarded through
##     [method present_lock_cue] (presentation only)
##
## What it deliberately does not own:
##   * damage, range, speed, lifetime, radius or faction of the *warhead*. Those
##     come back on the authority-issued flight ticket from
##     `LiveCombatAuthority.launch_projectile()`, exactly as a travelling bolt's.
##   * the hit decision. The terminal segment is re-swept and committed by
##     `LiveCombatAuthority.resolve_projectile_arrival()` on the one resolver.
##   * the kill of the torpedo itself. A player's shot at it resolves through the
##     same resolver against the torpedo's Damageable; when that Damageable is
##     destroyed the open flight is abandoned, so a destroyed torpedo can never
##     deliver its warhead.
##
## A torpedo curves, so its terminal segment is not on its launch line. The
## resolver measures a flight against its launch origin (the terminal point must
## lie within the registered range), and this pool caps the *path length* at that
## range; displacement never exceeds path length, so the envelope still holds.
##
## Steady-state allocation: none. Every node, material and mesh is built once.
##
## Evidence status: modern_interpretation. No original Keth Shipyards weapon,
## craft or effect is authenticated or claimed here.

signal torpedo_launched(record: Dictionary)
signal torpedo_resolved(record: Dictionary, result: Dictionary)
signal torpedo_intercepted(record: Dictionary)
signal torpedo_abandoned(record: Dictionary, reason: StringName)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"seeker-torpedo-projectile"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

const PhysicsLayerContract := preload("res://scripts/core/physics_layers.gd")
const TorpedoRunAudioScript := preload("res://scripts/combat/torpedo_run_audio.gd")

const DEFAULT_POOL_CAPACITY := 2
const MAX_POOL_CAPACITY := 4
## Seeker tuning. 42 deg/s at the authored 34 m/s is a ~46 m turning circle, so a
## craft breaking hard across the torpedo's nose out-turns it, and a torpedo that
## has overshot cannot come back for a second pass.
const DEFAULT_TURN_RATE_DEGREES := 42.0
const MAX_TURN_RATE_DEGREES := 180.0
## The torpedo flies straight off the rail for this long before it steers, which
## is what makes the launch itself readable as a commitment.
const SEEKER_ARMING_SECONDS := 0.45
## Once the target sits this far off the torpedo's nose the seeker has lost it
## for good and the torpedo runs straight until it expires.
const LOCK_BREAK_ANGLE_DEGREES := 80.0
## The warhead fuses inside this distance of the target's hull centre.
const PROXIMITY_FUSE_METERS := 3.2
## Generous on purpose: this is an arcade intercept, not a sniping exercise.
const HURTBOX_RADIUS_METERS := 1.9
## One hit from any fleet weapon destroys a torpedo (the weakest fleet gun deals
## 18 per shot).
const TORPEDO_HEALTH := 14.0
const TERMINAL_OVERSHOOT_METERS := 0.2
const INTERCEPT_BURST_SECONDS := 0.55

const BODY_LENGTH_METERS := 2.6
const BODY_RADIUS_METERS := 0.34
const TRAIL_LENGTH_METERS := 7.0
const REDUCED_FLASH_TRAIL_LENGTH_METERS := 3.0
const LIGHT_ENERGY := 2.6
const LIGHT_RANGE_METERS := 9.0
const SEEKER_EMISSION_ENERGY := 5.0
const REDUCED_FLASH_SEEKER_EMISSION_ENERGY := 1.5
const TRAIL_EMISSION_ENERGY := 2.2
const REDUCED_FLASH_TRAIL_EMISSION_ENERGY := 0.8
const BURST_EMISSION_ENERGY := 4.0
const REDUCED_FLASH_BURST_EMISSION_ENERGY := 1.2
const BURST_MAX_SCALE := 4.2
const REDUCED_FLASH_BURST_MAX_SCALE := 2.6

## Lime seeker head and a warm exhaust: deliberately unlike the picket's magenta
## lance, the raider's red pulse and every amber opponent pulse, so "that one is
## hunting me" is its own read.
const HULL_COLOR := Color("2d3530")
const SEEKER_COLOR := Color("d4ff3a")
const TRAIL_COLOR := Color("ff9a3c")

const NODES_PER_SLOT := 7

@export_range(1, MAX_POOL_CAPACITY, 1) var pool_capacity := DEFAULT_POOL_CAPACITY
@export_range(1.0, MAX_TURN_RATE_DEGREES, 1.0) var turn_rate_degrees := DEFAULT_TURN_RATE_DEGREES
## Faction of the torpedo *bodies*. The owner's faction, so its own side's fire
## is blocked as friendly while a player shot can destroy it.
@export var faction_id: StringName = &"range_defence"

var _built := false
var _reduced_flash := false
var _slots: Array[Dictionary] = []
var _materials: Dictionary = {}
var _launched_count := 0
var _resolved_count := 0
var _intercepted_count := 0
var _abandoned_count := 0
var _rejected_count := 0
var _detection_query := PhysicsRayQueryParameters3D.new()
var _authority: LiveCombatAuthority
var _audio: TorpedoRunAudio


func _ready() -> void:
	_build_pool()
	set_physics_process(false)


func _exit_tree() -> void:
	abandon_all(&"tree_exit")
	for slot_index in _slots.size():
		_clear_burst(slot_index)


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	step(delta)


## Advances every live torpedo and every intercept burst by one tick. Public so
## an owner stepping on its own clock can drive it deterministically.
func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for slot_index in _slots.size():
		_advance_slot(slot_index, delta)
		_advance_burst(slot_index, delta)
	_refresh_processing()


# --------------------------------------------------------------- binding ----

func bind_authority(authority: LiveCombatAuthority) -> void:
	_authority = authority


func get_bound_authority() -> LiveCombatAuthority:
	return _authority if is_instance_valid(_authority) and not _authority.is_queued_for_deletion() else null


# ------------------------------------------------------------- lifecycle ----

## Asks the authority for one flight and, only if accepted, occupies one slot
## with the ticket's own envelope. `target` is what the seeker steers toward;
## it grants the torpedo nothing — the resolver still decides what it hits.
func launch(
		source_entity: Node3D,
		weapon_id: StringName,
		origin: Vector3,
		direction: Vector3,
		target: Node3D
	) -> Dictionary:
	if not _built:
		_build_pool()
	var authority := get_bound_authority()
	if authority == null:
		_rejected_count += 1
		return {"accepted": false, "status": &"authority_unavailable", "flight_id": 0}.duplicate(true)
	if not is_inside_tree():
		_rejected_count += 1
		return {"accepted": false, "status": &"pool_detached", "flight_id": 0}.duplicate(true)
	var slot_index := _find_free_slot()
	if slot_index < 0:
		_rejected_count += 1
		return {"accepted": false, "status": &"pool_saturated", "flight_id": 0}.duplicate(true)
	var ticket := authority.launch_projectile(source_entity, weapon_id, origin, direction)
	if not bool(ticket.get("accepted", false)):
		_rejected_count += 1
		return ticket
	var slot: Dictionary = _slots[slot_index]
	slot["active"] = true
	slot["generation"] = int(slot.get("generation", 0)) + 1
	slot["flight_id"] = int(ticket.get("flight_id", 0))
	slot["source"] = weakref(source_entity)
	slot["target"] = weakref(target) if is_instance_valid(target) else null
	slot["target_shape"] = _find_aim_shape(target)
	slot["weapon_id"] = weapon_id
	slot["origin"] = origin
	slot["direction"] = (ticket.get("launch_direction", direction.normalized()) as Vector3).normalized()
	slot["position"] = origin
	slot["previous_position"] = origin
	slot["speed"] = float(ticket.get("speed", 0.0))
	slot["lifetime"] = float(ticket.get("lifetime", 0.0))
	slot["radius"] = float(ticket.get("radius", 0.0))
	slot["range"] = float(ticket.get("range", 0.0))
	slot["elapsed"] = 0.0
	slot["travelled"] = 0.0
	slot["lock_broken"] = false
	var exclusions := slot.get("exclusions") as Array[RID]
	exclusions.clear()
	_append_collision_rids(source_entity, exclusions)
	for other: Dictionary in _slots:
		var other_hurtbox := other.get("hurtbox") as Area3D
		if is_instance_valid(other_hurtbox):
			var rid := other_hurtbox.get_rid()
			if rid.is_valid() and not exclusions.has(rid):
				exclusions.append(rid)
	var damageable := slot.get("damageable") as Damageable
	if is_instance_valid(damageable):
		damageable.faction_id = faction_id
		damageable.damage_enabled = true
		damageable.reset_health(TORPEDO_HEALTH)
	var hurtbox := slot.get("hurtbox") as Area3D
	if is_instance_valid(hurtbox):
		hurtbox.collision_layer = PhysicsLayerContract.DAMAGEABLE_TARGET_AREA_LAYER
	_launched_count += 1
	_refresh_slot_visual(slot_index)
	_refresh_processing()
	var record := _slot_record(slot)
	if is_instance_valid(_audio):
		_audio.present_launch(record)
	torpedo_launched.emit(record)
	return {
		"accepted": true,
		"status": &"launched",
		"flight_id": int(slot.flight_id),
		"slot_index": slot_index,
		"record": record,
	}.duplicate(true)


## Retires every live torpedo without inventing a resolver event.
func abandon_all(reason: StringName = &"abandoned") -> int:
	var abandoned := 0
	for slot_index in _slots.size():
		if _abandon_slot(slot_index, reason, false):
			abandoned += 1
	return abandoned


## Retires the torpedoes fired by one source, with a small fizzle where each was.
func abandon_source_torpedoes(source_entity: Node, reason: StringName = &"source_retired") -> int:
	var abandoned := 0
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if not bool(slot.get("active", false)):
			continue
		var source_reference := slot.get("source") as WeakRef
		if source_reference == null or source_reference.get_ref() != source_entity:
			continue
		if _abandon_slot(slot_index, reason, true):
			abandoned += 1
	return abandoned


# ---------------------------------------------------------- presentation ----

## Reduced flash keeps every torpedo fully readable — the player has to see it
## coming — but drops the dynamic light, most of the trail and the punch of the
## seeker head and intercept burst. Nothing here flickers at any setting.
func set_reduced_flash_enabled(enabled: bool) -> Dictionary:
	_reduced_flash = enabled
	for slot_index in _slots.size():
		_refresh_slot_visual(slot_index)
	return get_presentation_profile_snapshot()


## Forwards the launcher's lock posture to the audio bank. Presentation only:
## the launcher derives the posture from state it already owns.
func present_lock_cue(
		posture: StringName,
		lock_step: int,
		world_position: Vector3,
		activation_generation: int
	) -> void:
	if is_instance_valid(_audio):
		_audio.present_lock_posture(posture, lock_step, world_position, activation_generation)


func get_audio() -> TorpedoRunAudio:
	return _audio if is_instance_valid(_audio) else null


func is_reduced_flash_enabled() -> bool:
	return _reduced_flash


func get_presentation_profile_snapshot() -> Dictionary:
	return {
		"reduced_flash": _reduced_flash,
		"reduced_flash_policy": &"readable_torpedo_no_dynamic_light_short_trail",
		"trail_length_meters": (
			REDUCED_FLASH_TRAIL_LENGTH_METERS if _reduced_flash else TRAIL_LENGTH_METERS
		),
		"seeker_emission_energy": (
			REDUCED_FLASH_SEEKER_EMISSION_ENERGY if _reduced_flash else SEEKER_EMISSION_ENERGY
		),
		"burst_emission_energy": (
			REDUCED_FLASH_BURST_EMISSION_ENERGY if _reduced_flash else BURST_EMISSION_ENERGY
		),
		"dynamic_light_enabled": not _reduced_flash,
		"flicker": false,
	}.duplicate(true)


# ------------------------------------------------------------- accessors ----

func get_component_id() -> StringName:
	return COMPONENT_ID


func get_pool_capacity() -> int:
	return _slots.size()


func get_active_torpedo_count() -> int:
	var active := 0
	for slot: Dictionary in _slots:
		if bool(slot.get("active", false)):
			active += 1
	return active


func get_active_torpedo_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		if bool(slot.get("active", false)):
			records.append(_slot_record(slot))
	return records


## The live hurtbox of one slot, for callers and suites that need to aim at it.
func get_torpedo_hurtbox(slot_index: int) -> Area3D:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index].get("hurtbox") as Area3D


func get_torpedo_damageable(slot_index: int) -> Damageable:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index].get("damageable") as Damageable


func get_active_burst_count() -> int:
	var count := 0
	for slot: Dictionary in _slots:
		if float(slot.get("burst_remaining", 0.0)) > 0.0:
			count += 1
	return count


func get_statistics() -> Dictionary:
	return {
		"launched": _launched_count,
		"resolved": _resolved_count,
		"intercepted": _intercepted_count,
		"abandoned": _abandoned_count,
		"rejected": _rejected_count,
		"active": get_active_torpedo_count(),
		"capacity": _slots.size(),
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _built:
		errors.append("torpedo pool has not been built")
	if _slots.size() < 1 or _slots.size() > MAX_POOL_CAPACITY:
		errors.append("torpedo pool capacity is outside the fixed bound")
	for slot: Dictionary in _slots:
		var holder := slot.get("holder") as Node3D
		if not is_instance_valid(holder):
			errors.append("a torpedo slot lost its retained presentation node")
			continue
		var hurtbox := slot.get("hurtbox") as Area3D
		if bool(slot.get("active", false)):
			if int(slot.get("flight_id", 0)) <= 0:
				errors.append("an active torpedo has no authority flight ticket")
			if float(slot.get("speed", 0.0)) <= 0.0 or float(slot.get("lifetime", 0.0)) <= 0.0:
				errors.append("an active torpedo has no authored travel envelope")
			if float(slot.get("travelled", 0.0)) > float(slot.get("range", 0.0)) + 0.001:
				errors.append("an active torpedo has flown past its registered range")
		elif is_instance_valid(hurtbox) and hurtbox.collision_layer != 0:
			errors.append("an idle torpedo slot still exposes a hurtbox")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"valid": errors.is_empty(),
		"errors": errors,
		"statistics": get_statistics(),
		"presentation": get_presentation_profile_snapshot(),
		"turn_rate_degrees": turn_rate_degrees,
		"authority": {
			"damage": false,
			"raycast_commit": false,
			"faction_policy": false,
			"replay_sequence": false,
			"travel": true,
			"presentation": true,
		},
	}.duplicate(true)


# -------------------------------------------------------------- internals ----

func _advance_slot(slot_index: int, delta: float) -> void:
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		return
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	if authority == null:
		_abandon_slot(slot_index, &"authority_unavailable", false)
		return
	# A source that dies or is retired mid-flight takes its torpedoes with it:
	# the resolver would refuse the arrival anyway, and a warhead that lingers
	# after its launcher is gone reads as a bug.
	if authority.observe_projectile(flight_id) != &"live":
		_abandon_slot(slot_index, &"source_lost", true)
		return
	var position := slot.position as Vector3
	var direction := slot.direction as Vector3
	var elapsed := float(slot.elapsed)
	var remaining_lifetime := maxf(0.0, float(slot.lifetime) - elapsed)
	var remaining_range := maxf(0.0, float(slot.range) - float(slot.travelled))
	var tick_seconds := minf(delta, remaining_lifetime)
	var target_point := _target_point(slot)

	# Proximity fuse, checked before moving so a torpedo already inside the fuse
	# radius detonates on this tick rather than passing through.
	if target_point.is_finite() and not bool(slot.lock_broken) \
			and position.distance_to(target_point) <= PROXIMITY_FUSE_METERS \
			and (slot.origin as Vector3).distance_to(target_point) <= float(slot.range):
		_terminate_slot(slot_index, position, target_point, &"proximity_fuse")
		return

	if target_point.is_finite() and not bool(slot.lock_broken) \
			and elapsed >= SEEKER_ARMING_SECONDS:
		var to_target := target_point - position
		if to_target.length_squared() > 0.000001:
			var desired := to_target.normalized()
			var angle := direction.angle_to(desired)
			if angle > deg_to_rad(LOCK_BREAK_ANGLE_DEGREES):
				# Overshot: the target broke across the nose faster than the seeker
				# could follow. The torpedo keeps its heading and never re-locks.
				slot["lock_broken"] = true
			elif angle > 0.00001:
				var max_turn := deg_to_rad(turn_rate_degrees) * tick_seconds
				direction = direction.slerp(desired, minf(1.0, max_turn / angle)).normalized()
	var advance := minf(float(slot.speed) * tick_seconds, remaining_range)
	var next_position := position + direction * advance
	slot["previous_position"] = position
	slot["position"] = next_position
	slot["direction"] = direction
	slot["elapsed"] = elapsed + tick_seconds
	slot["travelled"] = float(slot.travelled) + advance
	_refresh_slot_visual(slot_index)

	var contact := _detect_contact(slot, position, next_position, direction)
	if contact.is_finite():
		var terminal := contact + direction * TERMINAL_OVERSHOOT_METERS
		if (slot.origin as Vector3).distance_to(terminal) > float(slot.range):
			terminal = contact
		_terminate_slot(slot_index, position, terminal, &"impact")
		return
	if float(slot.elapsed) >= float(slot.lifetime) - 0.000001:
		_terminate_slot(slot_index, position, next_position, &"lifetime")
		return
	if float(slot.travelled) >= float(slot.range) - 0.000001:
		_terminate_slot(slot_index, position, next_position, &"range")


func _target_point(slot: Dictionary) -> Vector3:
	var shape_reference := slot.get("target_shape") as WeakRef
	var shape := shape_reference.get_ref() as CollisionShape3D if shape_reference != null else null
	if is_instance_valid(shape) and shape.is_inside_tree() and not shape.disabled:
		return shape.global_position
	var target_reference := slot.get("target") as WeakRef
	var target := target_reference.get_ref() as Node3D if target_reference != null else null
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return Vector3.INF
	if target.has_method(&"is_destroyed") and bool(target.call(&"is_destroyed")):
		return Vector3.INF
	return target.global_position


func _find_aim_shape(target: Node3D) -> WeakRef:
	if not is_instance_valid(target):
		return null
	for candidate in target.find_children("*", "CollisionShape3D", true, false):
		var shape := candidate as CollisionShape3D
		if shape != null and not shape.disabled and shape.shape != null:
			return weakref(shape)
	return null


func _detect_contact(
		slot: Dictionary,
		previous_position: Vector3,
		next_position: Vector3,
		direction: Vector3
	) -> Vector3:
	if not is_inside_tree() or get_world_3d() == null:
		return Vector3.INF
	var travel := next_position - previous_position
	if not travel.is_finite() or travel.length_squared() <= 0.000001:
		return Vector3.INF
	_detection_query.from = previous_position
	_detection_query.to = next_position + direction * float(slot.radius)
	_detection_query.collision_mask = PhysicsLayerContract.HITSCAN_QUERY_MASK
	_detection_query.exclude = slot.get("exclusions") as Array[RID]
	_detection_query.collide_with_areas = true
	_detection_query.collide_with_bodies = true
	_detection_query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(_detection_query)
	if hit.is_empty():
		return Vector3.INF
	var position: Variant = hit.get("position", Vector3.INF)
	if position is Vector3 and (position as Vector3).is_finite():
		return position as Vector3
	return Vector3.INF


## Every flown-out ending — impact, fuse, lifetime, range — commits through the
## one authority call, so even a torpedo that expired in open space is an
## authoritative resolved miss.
func _terminate_slot(
		slot_index: int,
		segment_start: Vector3,
		terminal_position: Vector3,
		reason: StringName
	) -> void:
	var slot: Dictionary = _slots[slot_index]
	var record := _slot_record(slot)
	record["terminal_reason"] = reason
	record["terminal_position"] = terminal_position
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	var start := segment_start
	if start.distance_to(terminal_position) <= 0.000001:
		start = terminal_position - (slot.direction as Vector3) * maxf(float(slot.radius), 0.05)
	var source_reference := slot.get("source") as WeakRef
	var source_entity := source_reference.get_ref() as Node3D if source_reference != null else null
	_release_slot(slot_index)
	if authority == null:
		_abandoned_count += 1
		if is_instance_valid(_audio):
			_audio.present_abandoned(record)
		torpedo_abandoned.emit(record, &"authority_unavailable")
		return
	var result := authority.resolve_projectile_arrival(
		source_entity, flight_id, start, terminal_position, -1
	)
	_resolved_count += 1
	if bool(result.get("damaged", false)) or reason == &"proximity_fuse":
		_start_burst(slot_index, terminal_position)
	if is_instance_valid(_audio):
		_audio.present_resolved(record, result)
	torpedo_resolved.emit(record, result)


func _abandon_slot(slot_index: int, reason: StringName, fizzle: bool) -> bool:
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		return false
	var record := _slot_record(slot)
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	var position := slot.get("position", Vector3.INF) as Vector3
	_release_slot(slot_index)
	if authority != null:
		authority.abandon_projectile(flight_id)
	_abandoned_count += 1
	if fizzle and position.is_finite():
		_start_burst(slot_index, position)
	if is_instance_valid(_audio):
		_audio.present_abandoned(record)
	torpedo_abandoned.emit(record, reason)
	return true


## The torpedo's own Damageable reached zero. The flight is dropped before any
## arrival can be committed, which is what "shooting it down cancels its hit"
## means in authority terms.
func _on_torpedo_destroyed(
		_hit_position: Vector3,
		_hit_normal: Vector3,
		_source_context: Dictionary,
		slot_index: int
	) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		return
	var record := _slot_record(slot)
	record["terminal_reason"] = &"intercepted"
	var authority := get_bound_authority()
	var flight_id := int(slot.flight_id)
	var position := slot.get("position", Vector3.INF) as Vector3
	_release_slot(slot_index)
	if authority != null:
		authority.abandon_projectile(flight_id)
	_intercepted_count += 1
	if position.is_finite():
		_start_burst(slot_index, position)
	_refresh_processing()
	if is_instance_valid(_audio):
		_audio.present_intercept(record)
	torpedo_intercepted.emit(record)


func _release_slot(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	slot["active"] = false
	slot["flight_id"] = 0
	slot["source"] = null
	slot["target"] = null
	slot["target_shape"] = null
	var hurtbox := slot.get("hurtbox") as Area3D
	if is_instance_valid(hurtbox):
		hurtbox.collision_layer = 0
	var damageable := slot.get("damageable") as Damageable
	if is_instance_valid(damageable):
		damageable.damage_enabled = false
	var holder := slot.get("holder") as Node3D
	if is_instance_valid(holder):
		holder.visible = false


func _slot_record(slot: Dictionary) -> Dictionary:
	return {
		"flight_id": int(slot.get("flight_id", 0)),
		"generation": int(slot.get("generation", 0)),
		"weapon_id": slot.get("weapon_id", &""),
		"origin": slot.get("origin", Vector3.INF),
		"direction": slot.get("direction", Vector3.ZERO),
		"position": slot.get("position", Vector3.INF),
		"speed": float(slot.get("speed", 0.0)),
		"lifetime": float(slot.get("lifetime", 0.0)),
		"radius": float(slot.get("radius", 0.0)),
		"range": float(slot.get("range", 0.0)),
		"elapsed": float(slot.get("elapsed", 0.0)),
		"travelled": float(slot.get("travelled", 0.0)),
		"lock_broken": bool(slot.get("lock_broken", false)),
	}.duplicate(true)


func _find_free_slot() -> int:
	for slot_index in _slots.size():
		if not bool((_slots[slot_index] as Dictionary).get("active", false)):
			return slot_index
	return -1


func _refresh_processing() -> void:
	var busy := get_active_torpedo_count() > 0 or get_active_burst_count() > 0
	if is_physics_processing() != busy:
		set_physics_process(busy)


# ------------------------------------------------------------ presentation ----

func _start_burst(slot_index: int, position: Vector3) -> void:
	var slot: Dictionary = _slots[slot_index]
	var burst := slot.get("burst") as MeshInstance3D
	if not is_instance_valid(burst) or not is_inside_tree():
		return
	slot["burst_remaining"] = INTERCEPT_BURST_SECONDS
	burst.global_position = position
	burst.material_override = (
		_materials.reduced_burst if _reduced_flash else _materials.burst
	) as Material
	burst.scale = Vector3.ONE
	burst.visible = true
	_refresh_processing()


## A steady, monotonic grow-and-shrink over the burst's short life: no strobe.
func _advance_burst(slot_index: int, delta: float) -> void:
	var slot: Dictionary = _slots[slot_index]
	var remaining := float(slot.get("burst_remaining", 0.0))
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	slot["burst_remaining"] = remaining
	var burst := slot.get("burst") as MeshInstance3D
	if not is_instance_valid(burst):
		return
	if remaining <= 0.0:
		burst.visible = false
		return
	var progress := 1.0 - remaining / INTERCEPT_BURST_SECONDS
	var peak := REDUCED_FLASH_BURST_MAX_SCALE if _reduced_flash else BURST_MAX_SCALE
	burst.scale = Vector3.ONE * lerpf(1.0, peak, sin(progress * PI))


func _clear_burst(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	slot["burst_remaining"] = 0.0
	var burst := slot.get("burst") as MeshInstance3D
	if is_instance_valid(burst):
		burst.visible = false


func _refresh_slot_visual(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	var holder := slot.get("holder") as Node3D
	if not is_instance_valid(holder):
		return
	var position := slot.get("position", Vector3.INF) as Vector3
	if not bool(slot.get("active", false)) or not position.is_finite():
		holder.visible = false
		return
	holder.visible = true
	holder.global_transform = Transform3D(_basis_for_forward(slot.direction as Vector3), position)
	if is_instance_valid(_audio):
		_audio.follow_flight(int(slot.get("flight_id", 0)), position)
	var seeker := slot.get("seeker") as MeshInstance3D
	if is_instance_valid(seeker):
		seeker.material_override = (
			_materials.reduced_seeker if _reduced_flash else _materials.seeker
		) as Material
	var trail := slot.get("trail") as MeshInstance3D
	if is_instance_valid(trail):
		var trail_length := REDUCED_FLASH_TRAIL_LENGTH_METERS if _reduced_flash else TRAIL_LENGTH_METERS
		trail.scale = Vector3(1.0, trail_length, 1.0)
		trail.position = Vector3(0.0, 0.0, BODY_LENGTH_METERS * 0.5 + trail_length * 0.5)
		trail.material_override = (
			_materials.reduced_trail if _reduced_flash else _materials.trail
		) as Material
	var light := slot.get("light") as OmniLight3D
	if is_instance_valid(light):
		light.visible = not _reduced_flash


func _build_pool() -> void:
	if _built:
		return
	_build_materials()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = BODY_RADIUS_METERS
	body_mesh.height = BODY_LENGTH_METERS
	body_mesh.radial_segments = 10
	body_mesh.rings = 3
	var seeker_mesh := SphereMesh.new()
	seeker_mesh.radius = BODY_RADIUS_METERS * 1.05
	seeker_mesh.height = BODY_RADIUS_METERS * 2.1
	seeker_mesh.radial_segments = 10
	seeker_mesh.rings = 5
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = BODY_RADIUS_METERS * 0.2
	trail_mesh.bottom_radius = BODY_RADIUS_METERS * 0.9
	trail_mesh.height = 1.0
	trail_mesh.radial_segments = 6
	trail_mesh.rings = 0
	var burst_mesh := SphereMesh.new()
	burst_mesh.radius = 0.6
	burst_mesh.height = 1.2
	burst_mesh.radial_segments = 10
	burst_mesh.rings = 5
	var hurtbox_shape := SphereShape3D.new()
	hurtbox_shape.radius = HURTBOX_RADIUS_METERS
	var capacity := clampi(pool_capacity, 1, MAX_POOL_CAPACITY)
	for slot_index in capacity:
		var holder := Node3D.new()
		holder.name = "Torpedo%d" % slot_index
		# World-space travel: a torpedo in flight belongs to the world, not to the
		# craft that launched it.
		holder.top_level = true
		holder.visible = false
		add_child(holder)
		var hurtbox := Area3D.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = 0
		hurtbox.collision_mask = PhysicsLayerContract.DAMAGEABLE_TARGET_AREA_MASK
		hurtbox.monitoring = false
		hurtbox.monitorable = true
		hurtbox.set_meta(&"presentation_only", false)
		hurtbox.set_meta(&"seeker_torpedo", true)
		holder.add_child(hurtbox)
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		shape.shape = hurtbox_shape
		hurtbox.add_child(shape)
		var damageable := Damageable.new()
		damageable.name = "Damageable"
		damageable.maximum_health = TORPEDO_HEALTH
		damageable.faction_id = faction_id
		damageable.damage_enabled = false
		hurtbox.add_child(damageable)
		damageable.destroyed.connect(_on_torpedo_destroyed.bind(slot_index))
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = body_mesh
		body.material_override = _materials.hull as Material
		# The capsule's own axis is +Y; the holder's forward is -Z.
		body.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(body)
		var seeker := MeshInstance3D.new()
		seeker.name = "SeekerHead"
		seeker.mesh = seeker_mesh
		seeker.material_override = _materials.seeker as Material
		seeker.position = Vector3(0.0, 0.0, -BODY_LENGTH_METERS * 0.5)
		seeker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(seeker)
		var trail := MeshInstance3D.new()
		trail.name = "Trail"
		trail.mesh = trail_mesh
		trail.material_override = _materials.trail as Material
		trail.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(trail)
		var light := OmniLight3D.new()
		light.name = "SeekerGlow"
		light.light_color = SEEKER_COLOR
		light.light_energy = LIGHT_ENERGY
		light.omni_range = LIGHT_RANGE_METERS
		light.shadow_enabled = false
		light.position = seeker.position
		holder.add_child(light)
		var burst := MeshInstance3D.new()
		burst.name = "InterceptBurst%d" % slot_index
		burst.mesh = burst_mesh
		burst.material_override = _materials.burst as Material
		burst.top_level = true
		burst.visible = false
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(burst)
		_slots.append({
			"active": false,
			"generation": 0,
			"flight_id": 0,
			"source": null,
			"target": null,
			"target_shape": null,
			"weapon_id": &"",
			"origin": Vector3.INF,
			"direction": Vector3.FORWARD,
			"position": Vector3.INF,
			"previous_position": Vector3.INF,
			"speed": 0.0,
			"lifetime": 0.0,
			"radius": 0.0,
			"range": 0.0,
			"elapsed": 0.0,
			"travelled": 0.0,
			"lock_broken": false,
			"exclusions": [] as Array[RID],
			"holder": holder,
			"hurtbox": hurtbox,
			"damageable": damageable,
			"body": body,
			"seeker": seeker,
			"trail": trail,
			"light": light,
			"burst": burst,
			"burst_remaining": 0.0,
		})
	# One flight voice per slot bounds the loop voices by the pool itself.
	_audio = TorpedoRunAudioScript.new() as TorpedoRunAudio
	_audio.name = "TorpedoAudio"
	_audio.flight_voice_count = capacity
	add_child(_audio)
	_built = true


func _build_materials() -> void:
	if not _materials.is_empty():
		return
	var hull := StandardMaterial3D.new()
	hull.albedo_color = HULL_COLOR
	hull.metallic = 0.6
	hull.roughness = 0.35
	_materials["hull"] = hull
	_materials["seeker"] = _emissive(SEEKER_COLOR, SEEKER_EMISSION_ENERGY, false)
	_materials["reduced_seeker"] = _emissive(SEEKER_COLOR, REDUCED_FLASH_SEEKER_EMISSION_ENERGY, false)
	_materials["trail"] = _emissive(TRAIL_COLOR, TRAIL_EMISSION_ENERGY, true)
	_materials["reduced_trail"] = _emissive(TRAIL_COLOR, REDUCED_FLASH_TRAIL_EMISSION_ENERGY, true)
	_materials["burst"] = _emissive(TRAIL_COLOR, BURST_EMISSION_ENERGY, true)
	_materials["reduced_burst"] = _emissive(TRAIL_COLOR, REDUCED_FLASH_BURST_EMISSION_ENERGY, true)


func _emissive(color: Color, energy: float, translucent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.7) if translucent else color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _basis_for_forward(forward: Vector3) -> Basis:
	var direction := forward
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.999:
		up = Vector3.RIGHT
	return Basis.looking_at(direction, up)


func _append_collision_rids(node: Node, output: Array[RID]) -> void:
	if not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not output.has(rid):
			output.append(rid)
	for child in node.get_children():
		_append_collision_rids(child, output)
