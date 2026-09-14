class_name CombatResolver
extends Node3D

const PhysicsLayerContract := preload("res://scripts/core/physics_layers.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const DamageableType := preload("res://scripts/combat/damageable.gd")
const SCATTER_PELLET_COUNT := 3
const MAX_SPREAD_DEGREES := 45.0
const PROJECTILE_PROFILE_KEYS := [
	"projectile_speed", "projectile_lifetime", "projectile_radius",
]
## Optional authored heat envelope. A profile either declares all four keys or
## none of them; a weapon without heat registers the dictionary it always did
## and never touches a single line of the heat ledger below.
const HEAT_PROFILE_KEYS := [
	"heat_per_shot", "heat_capacity", "heat_cooldown_per_second", "heat_lockout_seconds",
]
const MAX_HEAT_UNITS := 1_000_000.0
const MAX_HEAT_LOCKOUT_SECONDS := 60.0
const HEAT_LOCKOUT_STATUS: StringName = &"weapon_heat_locked"
const MAX_PROJECTILE_SPEED := 10_000.0
const MAX_PROJECTILE_LIFETIME := 600.0
const MAX_PROJECTILE_RADIUS := 100.0
const MAX_ACTIVE_PROJECTILE_FLIGHTS := 32
const PROJECTILE_RANGE_EPSILON := 0.01
const MAX_PROJECTILE_FLIGHT_ID: int = 9223372036854775807

## Node-scoped authority service for deterministic hitscan resolution. The
## sequence ledger intentionally lives on this node so a future multiplayer
## authority can own one resolver per world/session without global state.

signal shot_resolved(request: ShotRequest, result: Dictionary)

@export var allow_friendly_fire := false
@export var enforce_multiplayer_authority := true
@export var require_registered_sources := true

var _last_sequence_by_source: Dictionary = {}
var _source_registry: Dictionary = {}
var _source_key_by_instance_id: Dictionary = {}
var _history_owner_by_source: Dictionary = {}
## Open projectile flights keyed by monotonic flight ID. Bounded and pruned with
## the same cadence as the source registry; no flight outlives its source.
var _projectile_flights: Dictionary = {}
var _next_projectile_flight_id: int = 1


func _process(delta: float) -> void:
	_prune_invalid_sources()
	_prune_invalid_history()
	_prune_projectile_flights()
	advance_weapon_heat(delta)


## Registers the authority-owned identity, collision root, faction, and weapon
## envelope used to validate future requests. `weapon_profiles` is keyed by
## weapon id; every value must define positive finite `range` and `damage`, and
## may define a positive `origin_tolerance` around the source root. The one
## bounded spread case additionally carries a three-pellet trigger budget and
## finite angular envelope; all other profiles retain the original shape.
func register_source(
	source_id: int,
	source_entity: Node3D,
	faction_id: StringName,
	weapon_profiles: Dictionary
	) -> bool:
	if (
		source_id < 0
		or not is_instance_valid(source_entity)
		or not source_entity.is_inside_tree()
		or source_entity.is_queued_for_deletion()
		or faction_id.is_empty()
	):
		return false
	var source_key := _source_key(source_entity, source_id)
	if source_key.is_empty():
		return false
	_prune_invalid_history()
	var instance_id := source_entity.get_instance_id()
	var previous_key := String(_source_key_by_instance_id.get(instance_id, ""))
	if not previous_key.is_empty() and previous_key != source_key:
		return false
	var retained_owner: Dictionary = _history_owner_by_source.get(source_key, {})
	var retained_reference: WeakRef = retained_owner.get("entity") as WeakRef
	var retained_entity: Node = (
		retained_reference.get_ref() as Node if retained_reference != null else null
	)
	if is_instance_valid(retained_entity) and retained_entity != source_entity:
		# A detached live source still owns its stable identity. A different object
		# cannot take over the ID merely because the registration is temporarily out
		# of the physics tree.
		return false
	var normalized_profiles := _normalize_weapon_profiles(weapon_profiles)
	if normalized_profiles.is_empty() or normalized_profiles.size() != weapon_profiles.size():
		return false
	_remove_source_registration(source_key)
	_source_registry[source_key] = {
		"entity": weakref(source_entity),
		"instance_id": instance_id,
		"source_id": source_id,
		"faction_id": faction_id,
		"weapons": normalized_profiles,
		# Server-owned weapon heat lives inside the registration it describes, so a
		# re-registration, a retirement, a streamed detach, an explicit forget and
		# ordinary pruning all discard it by construction. There is no second
		# ledger that could outlive the identity or leak across a regenerated epoch.
		"heat": _make_heat_ledger(normalized_profiles),
	}
	_source_key_by_instance_id[instance_id] = source_key
	_remember_history_owner(source_key, source_entity, source_id)
	if not source_entity.tree_exiting.is_connected(_on_registered_source_exiting):
		source_entity.tree_exiting.connect(
			_on_registered_source_exiting.bind(source_key, instance_id),
			CONNECT_ONE_SHOT
		)
	return true


func resolve_hitscan(request: ShotRequestType) -> Dictionary:
	return _resolve_request(request)


## Resolves the one supported spread case as a single trigger containing three
## independently authoritative hitscan rays. The caller supplies only the
## centreline and preallocated presentation receipts; this resolver owns the
## deterministic fan directions, per-pellet damage split, ray queries, faction
## policy, damage commits, and replay sequence consumption.
func resolve_hitscan_fan(
		trigger_request: ShotRequestType,
		presentation_receipt_ids: PackedInt64Array
	) -> Dictionary:
	var aggregate := _make_fan_result(trigger_request)
	if trigger_request == null:
		return _reject_fan(aggregate, &"invalid_request", "request is null")
	var validation_errors := trigger_request.get_validation_errors()
	if not validation_errors.is_empty():
		return _reject_fan(
			aggregate, &"invalid_request", "; ".join(validation_errors)
		)
	if enforce_multiplayer_authority:
		if not is_inside_tree():
			return _reject_fan(aggregate, &"not_in_tree", "resolver is not in a scene tree")
		if not is_multiplayer_authority():
			return _reject_fan(aggregate, &"not_authority", "resolver is not multiplayer authority")

	var authority_context := _resolve_authority_context(trigger_request, true)
	if not bool(authority_context.get("valid", false)):
		return _reject_fan(
			aggregate,
			authority_context.get("status", &"unregistered_source"),
			str(authority_context.get("reason", "source is not registered"))
		)
	var pellet_count := int(authority_context.get("pellet_count", 0))
	if pellet_count != SCATTER_PELLET_COUNT:
		return _reject_fan(
			aggregate, &"weapon_not_scatter", "registered weapon is not the bounded scatter case"
		)
	if presentation_receipt_ids.size() != pellet_count:
		return _reject_fan(
			aggregate,
			&"invalid_presentation_receipts",
			"scatter requires one presentation receipt per pellet"
		)
	var unique_receipts := {}
	for receipt_id: int in presentation_receipt_ids:
		if receipt_id < 0 or unique_receipts.has(receipt_id):
			return _reject_fan(
				aggregate,
				&"invalid_presentation_receipts",
				"scatter presentation receipts must be unique and non-negative"
			)
		unique_receipts[receipt_id] = true
	if trigger_request.sequence > 9223372036854775807 - pellet_count:
		return _reject_fan(
			aggregate, &"invalid_request", "scatter sequence range would overflow"
		)
	var previous_sequence := get_last_sequence(
		authority_context.source_entity, int(authority_context.source_id)
	)
	if trigger_request.sequence <= previous_sequence:
		return _reject_fan(
			aggregate,
			&"duplicate_sequence"
				if trigger_request.sequence == previous_sequence
				else &"out_of_order_sequence",
			"scatter trigger sequence is not newer than the source ledger"
		)

	var directions := build_deterministic_fan_directions(
		trigger_request.get_normalized_direction(),
		float(authority_context.get("spread_degrees", 0.0)),
		pellet_count
	)
	if directions.size() != pellet_count:
		return _reject_fan(
			aggregate, &"invalid_spread_profile", "scatter direction envelope is invalid"
		)

	if _weapon_heat_is_locked(
		String(authority_context.source_key), trigger_request.weapon_id
	):
		return _reject_fan(
			aggregate,
			HEAT_LOCKOUT_STATUS,
			"registered weapon is in its authored heat lockout"
		)

	var pellet_results: Array[Dictionary] = []
	var applied_damage := 0.0
	var all_accepted := true
	var all_resolved := true
	for pellet_index in pellet_count:
		var pellet_request := ShotRequestType.new(
			authority_context.source_entity,
			int(authority_context.source_id),
			authority_context.faction_id,
			trigger_request.weapon_id,
			trigger_request.sequence + pellet_index,
			trigger_request.origin,
			directions[pellet_index],
			float(authority_context.range),
			float(authority_context.damage),
			int(presentation_receipt_ids[pellet_index])
		) as ShotRequestType
		# One trigger, one heat charge: the first pellet pays for the whole fan.
		var pellet_result := _resolve_request(
			pellet_request, Vector3.INF, false, pellet_index == 0
		)
		pellet_result["pellet_index"] = pellet_index
		pellet_result["pellet_count"] = pellet_count
		pellet_results.append(pellet_result)
		applied_damage += float(pellet_result.get("applied_damage", 0.0))
		all_accepted = all_accepted and bool(pellet_result.get("accepted", false))
		all_resolved = all_resolved and bool(pellet_result.get("resolved", false))
		if bool(pellet_result.get("hit", false)) and not bool(aggregate.hit):
			_copy_fan_contact(aggregate, pellet_result)
		if bool(pellet_result.get("damaged", false)):
			aggregate["damaged"] = true
			aggregate["target_entity"] = pellet_result.get("target_entity")
		if bool(pellet_result.get("destroyed", false)):
			aggregate["destroyed"] = true

	aggregate["accepted"] = all_accepted
	aggregate["resolved"] = all_resolved
	aggregate["status"] = &"fan_resolved" if all_accepted and all_resolved else &"fan_rejected"
	aggregate["pellets"] = pellet_results
	aggregate["pellet_directions"] = directions
	aggregate["pellet_count"] = pellet_count
	aggregate["trigger_damage"] = float(authority_context.trigger_damage)
	aggregate["applied_damage"] = minf(
		applied_damage, float(authority_context.trigger_damage)
	)
	aggregate["last_sequence"] = get_last_sequence(
		authority_context.source_entity, int(authority_context.source_id)
	)
	aggregate["source_entity"] = authority_context.source_entity
	aggregate["source_id"] = int(authority_context.source_id)
	aggregate["source_faction_id"] = authority_context.faction_id
	return aggregate


static func build_deterministic_fan_directions(
		center_direction: Vector3,
		spread_degrees: float,
		pellet_count: int = SCATTER_PELLET_COUNT
	) -> PackedVector3Array:
	if (
		not center_direction.is_finite()
		or center_direction.length_squared() <= 0.000001
		or not is_finite(spread_degrees)
		or spread_degrees <= 0.0
		or spread_degrees > MAX_SPREAD_DEGREES
		or pellet_count != SCATTER_PELLET_COUNT
	):
		return PackedVector3Array()
	var center := center_direction.normalized()
	var lateral := center.cross(Vector3.UP)
	if lateral.length_squared() <= 0.000001:
		lateral = center.cross(Vector3.RIGHT)
	lateral = lateral.normalized()
	var fan_axis := center.cross(lateral).normalized()
	var spread_radians := deg_to_rad(spread_degrees)
	return PackedVector3Array([
		center.rotated(fan_axis, -spread_radians).normalized(),
		center,
		center.rotated(fan_axis, spread_radians).normalized(),
	])


## Resolves one caller-provided projectile endpoint through the same registered
## source, world-occlusion, faction, and Damageable chain as hitscan. The
## endpoint narrows the ray to the projectile's actual travel path; it cannot
## extend a registered weapon profile's authoritative range.
func resolve_projectile_impact(
		source_entity: Node3D,
		source_id: int,
		faction_id: StringName,
		weapon_id: StringName,
		sequence: int,
		origin: Vector3,
		terminal_position: Vector3
	) -> Dictionary:
	var profile := get_registered_weapon_profile(source_entity, source_id, weapon_id)
	var request_range := float(profile.get("range", 1.0))
	var request_damage := float(profile.get("damage", 1.0))
	var direction := terminal_position - origin
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var request := ShotRequestType.new(
		source_entity,
		source_id,
		faction_id,
		weapon_id,
		sequence,
		origin,
		direction,
		request_range,
		request_damage
	) as ShotRequestType
	# A terminal impact is not a trigger pull; the launch already paid its heat.
	return _resolve_request(request, terminal_position, false, false)


## ------------------------------------------------------ projectile flights ----
##
## A travelling bolt is a two-phase, server-owned transaction on this one
## resolver. `open_projectile_flight()` validates the source, its registration,
## its travel envelope and its muzzle origin-tolerance exactly once, at launch,
## and returns a detached flight ticket. `close_projectile_flight()` then sweeps
## only the short terminal segment through the same world-occlusion, faction and
## Damageable chain as hitscan, and consumes exactly one replay sequence.
##
## The travelling object owns no damage, no range, no speed and no faction: it
## advances a position, reports where it got to, and asks this resolver to judge
## it. Because only the terminal segment is swept, a target that was on the
## firing line at launch and has since moved is genuinely missed rather than
## retroactively hit by the path it used to occupy.


## Opens one flight. Returns `{accepted, status, flight_id, ...envelope}`.
func open_projectile_flight(
		source_entity: Node3D,
		source_id: int,
		faction_id: StringName,
		weapon_id: StringName,
		launch_origin: Vector3,
		launch_direction: Vector3
	) -> Dictionary:
	if enforce_multiplayer_authority \
			and (not is_inside_tree() or not is_multiplayer_authority()):
		return _reject_flight(&"not_authority", "resolver is not multiplayer authority")
	if not is_instance_valid(source_entity) or not source_entity.is_inside_tree() \
			or source_entity.is_queued_for_deletion():
		return _reject_flight(&"source_unavailable", "source is not live in the scene tree")
	if not launch_origin.is_finite() or not launch_direction.is_finite() \
			or launch_direction.length_squared() <= 0.000001:
		return _reject_flight(&"invalid_request", "launch origin or direction is not finite")
	var source_key := _source_key(source_entity, source_id)
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		return _reject_flight(&"unregistered_source", "source has no authority registration")
	var registered_faction: StringName = registration.get("faction_id", &"")
	if not faction_id.is_empty() and faction_id != registered_faction:
		return _reject_flight(&"source_mismatch", "request faction does not match registered source")
	var profiles: Dictionary = registration.get("weapons", {})
	var profile: Dictionary = profiles.get(weapon_id, {})
	if profile.is_empty():
		return _reject_flight(&"weapon_not_authorized", "weapon is not registered for source")
	if not profile_is_projectile(profile):
		return _reject_flight(&"weapon_not_projectile", "registered weapon has no travel envelope")
	if float(source_entity.global_position.distance_to(launch_origin)) \
			> float(profile.origin_tolerance):
		return _reject_flight(
			&"origin_out_of_bounds", "launch origin lies outside the registered source envelope"
		)
	if _source_lifecycle_is_destroyed(source_entity):
		return _reject_flight(
			&"source_destroyed", "registered source belongs to a destroyed lifecycle epoch"
		)
	if _weapon_heat_is_locked(source_key, weapon_id):
		# Launching a bolt is the trigger pull for a travelling weapon, so the heat
		# gate belongs here rather than on arrival.
		return _reject_flight(
			HEAT_LOCKOUT_STATUS, "registered weapon is in its authored heat lockout"
		)
	if _projectile_flights.size() >= MAX_ACTIVE_PROJECTILE_FLIGHTS:
		return _reject_flight(&"flight_capacity", "active projectile flights are saturated")
	if _next_projectile_flight_id <= 0 \
			or _next_projectile_flight_id >= MAX_PROJECTILE_FLIGHT_ID:
		_next_projectile_flight_id = -1
		return _reject_flight(&"flight_id_exhausted", "projectile flight IDs are saturated")
	var flight_id := _next_projectile_flight_id
	_next_projectile_flight_id += 1
	_projectile_flights[flight_id] = {
		"flight_id": flight_id,
		"source": weakref(source_entity),
		"source_instance_id": source_entity.get_instance_id(),
		"source_key": source_key,
		"source_id": source_id,
		"faction_id": registered_faction,
		"weapon_id": weapon_id,
		"launch_origin": launch_origin,
		"launch_direction": launch_direction.normalized(),
		"range": float(profile.range),
		"damage": float(profile.damage),
		"speed": float(profile.projectile_speed),
		"lifetime": float(profile.projectile_lifetime),
		"radius": float(profile.projectile_radius),
		"quarantined": false,
		"quarantine_reason": &"",
	}
	var heat_state := _charge_weapon_heat(source_key, weapon_id)
	var ticket := (_projectile_flights[flight_id] as Dictionary).duplicate(true)
	ticket.erase("source")
	if not heat_state.is_empty():
		ticket["weapon_heat"] = heat_state
	ticket["accepted"] = true
	ticket["status"] = &"flight_opened"
	ticket["reason"] = ""
	return ticket


## Re-asks the lifecycle question the resolver would ask on arrival. Once a
## flight has seen its source destroyed, unregistered, or replaced, the
## quarantine latches: a source that dies and is regenerated mid-flight can
## never have the in-flight bolt resolved against its new healthy epoch.
func observe_projectile_flight(flight_id: int) -> StringName:
	var flight: Dictionary = _projectile_flights.get(flight_id, {})
	if flight.is_empty():
		return &"unknown_flight"
	if bool(flight.get("quarantined", false)):
		return &"quarantined"
	var reason := _projectile_flight_quarantine_reason(flight)
	if reason.is_empty():
		return &"live"
	flight["quarantined"] = true
	flight["quarantine_reason"] = reason
	return &"quarantined"


## Closes one flight by sweeping its terminal segment. Consumes exactly one
## replay sequence whether the segment hits or misses.
func close_projectile_flight(
		flight_id: int,
		sequence: int,
		segment_start: Vector3,
		segment_end: Vector3,
		presentation_receipt_id: int = -1
	) -> Dictionary:
	var flight: Dictionary = _projectile_flights.get(flight_id, {})
	if flight.is_empty():
		return _reject_flight(&"unknown_flight", "projectile flight is not open")
	_projectile_flights.erase(flight_id)
	var source_reference: WeakRef = flight.get("source") as WeakRef
	var source_entity := source_reference.get_ref() as Node3D if source_reference != null else null
	var segment_direction := flight.launch_direction as Vector3
	if segment_start.is_finite() and segment_end.is_finite() \
			and (segment_end - segment_start).length_squared() > 0.000001:
		segment_direction = (segment_end - segment_start).normalized()
	var request := ShotRequestType.new(
		source_entity,
		int(flight.source_id),
		flight.faction_id,
		flight.weapon_id,
		sequence,
		segment_start if segment_start.is_finite() else Vector3.ZERO,
		segment_direction,
		float(flight.range),
		float(flight.damage),
		presentation_receipt_id
	) as ShotRequestType
	if bool(flight.get("quarantined", false)):
		return _reject(
			_make_result(request),
			&"source_destroyed",
			"projectile flight was quarantined in flight: %s" % flight.get("quarantine_reason", &""),
			request
		)
	var live_reason := _projectile_flight_quarantine_reason(flight)
	if not live_reason.is_empty():
		return _reject(
			_make_result(request),
			live_reason,
			"projectile flight is no longer backed by its launch epoch",
			request
		)
	if not segment_start.is_finite() or not segment_end.is_finite() \
			or (segment_end - segment_start).length_squared() <= 0.000001:
		return _reject(
			_make_result(request),
			&"invalid_projectile_endpoint",
			"projectile terminal segment is not a finite displacement",
			request
		)
	var launch_origin: Vector3 = flight.launch_origin
	# One centimetre of slack absorbs single-precision rounding on a bolt that
	# flew the authored range exactly; it cannot widen the envelope in any way a
	# player or a caller could exploit.
	if launch_origin.distance_to(segment_end) > float(flight.range) + PROJECTILE_RANGE_EPSILON:
		return _reject(
			_make_result(request),
			&"projectile_out_of_range",
			"projectile terminal point exceeds the registered weapon range",
			request
		)
	# The muzzle envelope was already proven at launch against the source's own
	# position; by arrival the source has legitimately moved, so the tolerance
	# check is deliberately not re-applied to the terminal segment.
	return _resolve_request(request, segment_end, true, false)


func abandon_projectile_flight(flight_id: int) -> bool:
	return _projectile_flights.erase(flight_id)


func get_active_projectile_flight_count() -> int:
	_prune_projectile_flights()
	return _projectile_flights.size()


func get_projectile_flight_snapshot(flight_id: int) -> Dictionary:
	var flight: Dictionary = _projectile_flights.get(flight_id, {})
	if flight.is_empty():
		return {}
	var snapshot := flight.duplicate(true)
	snapshot.erase("source")
	return snapshot


## ------------------------------------------------------------ weapon heat ----
##
## An authored heat envelope turns sustained fire into a resource the firing
## craft spends and the player can read. The rules are deliberately small:
##
##   * every accepted trigger pull adds `heat_per_shot`;
##   * between pulls the gun sheds `heat_cooldown_per_second`, so a burst that
##     is paced slowly never overheats at all;
##   * the instant accumulated heat reaches `heat_capacity` the weapon enters a
##     forced `heat_lockout_seconds` vent during which every request is refused
##     with `weapon_heat_locked` and no damage is applied;
##   * the vent drains the gun from the ceiling to exactly zero across that
##     span, so `heat_capacity / heat_lockout_seconds` is both the recovery rate
##     and the rate a hot-vent glow fades at.
##
## The ledger is server-owned and lives inside the source registration, so it is
## reset by the same events that already reset registration: re-registration,
## retirement, streamed detach, explicit forget, and a destroyed lifecycle epoch.


## Advances every registered heat weapon. Called from this node's existing
## `_process` tick; it mutates the ledger dictionaries in place and allocates
## nothing per frame. Exposed so a headless fixture can drive it deterministically.
func advance_weapon_heat(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for source_key: String in _source_registry:
		var registration: Dictionary = _source_registry[source_key]
		var ledger: Dictionary = registration.get("heat", {})
		if ledger.is_empty():
			continue
		var profiles: Dictionary = registration.get("weapons", {})
		for weapon_id: StringName in ledger:
			_advance_weapon_heat_entry(
				ledger[weapon_id] as Dictionary,
				profiles.get(weapon_id, {}) as Dictionary,
				delta
			)


## Detached read of one registered weapon's heat. An empty `weapon_id` returns
## the source's single heat weapon when it owns exactly one, which is what a
## presentation layer wants without duplicating the weapon-id authority.
func get_weapon_heat_snapshot(
		source_entity: Node,
		source_id: int = 0,
		weapon_id: StringName = &""
	) -> Dictionary:
	var source_key := _source_key(source_entity, source_id)
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		return {}
	var ledger: Dictionary = registration.get("heat", {})
	var resolved_weapon_id := _resolved_heat_weapon_id(ledger, weapon_id)
	if resolved_weapon_id.is_empty():
		return {}
	var state: Dictionary = ledger[resolved_weapon_id]
	var profile: Dictionary = (registration.get("weapons", {}) as Dictionary).get(
		resolved_weapon_id, {}
	)
	var capacity := float(profile.get("heat_capacity", 0.0))
	var per_shot := float(profile.get("heat_per_shot", 0.0))
	var heat := float(state.get("heat", 0.0))
	var lockout_remaining := float(state.get("lockout_remaining", 0.0))
	return {
		"enabled": true,
		"weapon_id": resolved_weapon_id,
		"heat": heat,
		"capacity": capacity,
		"ratio": clampf(heat / maxf(capacity, 0.001), 0.0, 1.0),
		"locked": lockout_remaining > 0.0,
		"lockout_remaining": lockout_remaining,
		"lockout_seconds": float(profile.get("heat_lockout_seconds", 0.0)),
		"heat_per_shot": per_shot,
		"cooldown_per_second": float(profile.get("heat_cooldown_per_second", 0.0)),
		"shots_until_lockout": (
			0
			if lockout_remaining > 0.0
			else maxi(0, int(ceil((capacity - heat) / maxf(per_shot, 0.001))))
		),
	}.duplicate(true)


## True when the registered weapon is currently refusing fire.
func is_weapon_heat_locked(
		source_entity: Node,
		source_id: int = 0,
		weapon_id: StringName = &""
	) -> bool:
	return get_weapon_heat_lockout_remaining(source_entity, source_id, weapon_id) > 0.0


## Allocation-free per-frame reads for a presentation layer. A glow that fades as
## the gun vents is drawn every frame; building a whole snapshot dictionary for it
## would be the one heat cost the player could actually measure.
func get_weapon_heat_ratio(
		source_entity: Node,
		source_id: int = 0,
		weapon_id: StringName = &""
	) -> float:
	var registration: Dictionary = _source_registry.get(
		_source_key(source_entity, source_id), {}
	)
	if registration.is_empty():
		return 0.0
	var ledger: Dictionary = registration.get("heat", {})
	var resolved_weapon_id := _resolved_heat_weapon_id(ledger, weapon_id)
	if resolved_weapon_id.is_empty():
		return 0.0
	var profile: Dictionary = (registration.get("weapons", {}) as Dictionary).get(
		resolved_weapon_id, {}
	)
	return clampf(
		float((ledger[resolved_weapon_id] as Dictionary).get("heat", 0.0))
			/ maxf(float(profile.get("heat_capacity", 0.0)), 0.001),
		0.0,
		1.0
	)


func get_weapon_heat_lockout_remaining(
		source_entity: Node,
		source_id: int = 0,
		weapon_id: StringName = &""
	) -> float:
	var registration: Dictionary = _source_registry.get(
		_source_key(source_entity, source_id), {}
	)
	if registration.is_empty():
		return 0.0
	var ledger: Dictionary = registration.get("heat", {})
	var resolved_weapon_id := _resolved_heat_weapon_id(ledger, weapon_id)
	if resolved_weapon_id.is_empty():
		return 0.0
	return maxf(
		float((ledger[resolved_weapon_id] as Dictionary).get("lockout_remaining", 0.0)), 0.0
	)


## An empty request resolves to the source's single heat weapon. A source that
## mounts more than one must name the weapon, because guessing which barrel a
## presentation meant is exactly the kind of silent authority this seam refuses.
func _resolved_heat_weapon_id(ledger: Dictionary, weapon_id: StringName) -> StringName:
	if weapon_id.is_empty():
		return StringName(ledger.keys()[0]) if ledger.size() == 1 else &""
	return weapon_id if ledger.has(weapon_id) else &""


## Vents every heat weapon on one source back to a cold, unlocked gun. This is
## the regeneration/reuse hook: a craft that is made healthy again starts its new
## epoch cold, exactly as a freshly registered one does.
func reset_weapon_heat(source_entity: Node = null, source_id: int = 0) -> bool:
	return _reset_weapon_heat_for_key(_source_key(source_entity, source_id))


## True when a registered profile carries a complete, normalized heat envelope.
static func profile_is_heat(profile: Dictionary) -> bool:
	for key: String in HEAT_PROFILE_KEYS:
		if not profile.has(key):
			return false
	return true


func _make_heat_ledger(normalized_profiles: Dictionary) -> Dictionary:
	var ledger := {}
	for weapon_id: StringName in normalized_profiles:
		if profile_is_heat(normalized_profiles[weapon_id] as Dictionary):
			ledger[weapon_id] = {"heat": 0.0, "lockout_remaining": 0.0}
	return ledger


func _weapon_heat_state(source_key: String, weapon_id: StringName) -> Dictionary:
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		return {}
	var ledger: Dictionary = registration.get("heat", {})
	return ledger.get(weapon_id, {}) as Dictionary


func _weapon_heat_is_locked(source_key: String, weapon_id: StringName) -> bool:
	var state := _weapon_heat_state(source_key, weapon_id)
	return not state.is_empty() and float(state.get("lockout_remaining", 0.0)) > 0.0


## Adds one trigger pull's heat and, if that reaches the authored ceiling, opens
## the forced vent. Returns a detached snapshot for the caller's presentation, or
## an empty dictionary for a weapon that authored no heat at all.
func _charge_weapon_heat(source_key: String, weapon_id: StringName) -> Dictionary:
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		return {}
	var ledger: Dictionary = registration.get("heat", {})
	if not ledger.has(weapon_id):
		return {}
	var state: Dictionary = ledger[weapon_id]
	var profile: Dictionary = (registration.get("weapons", {}) as Dictionary).get(weapon_id, {})
	var capacity := float(profile.get("heat_capacity", 0.0))
	var heat := minf(
		float(state.get("heat", 0.0)) + float(profile.get("heat_per_shot", 0.0)), capacity
	)
	state["heat"] = heat
	if heat >= capacity:
		state["lockout_remaining"] = float(profile.get("heat_lockout_seconds", 0.0))
	var source_reference: WeakRef = registration.get("entity") as WeakRef
	return get_weapon_heat_snapshot(
		source_reference.get_ref() as Node if source_reference != null else null,
		int(registration.get("source_id", 0)),
		weapon_id
	)


func _advance_weapon_heat_entry(
		state: Dictionary,
		profile: Dictionary,
		delta: float
	) -> void:
	var capacity := float(profile.get("heat_capacity", 0.0))
	if capacity <= 0.0:
		return
	var lockout_remaining := float(state.get("lockout_remaining", 0.0))
	if lockout_remaining > 0.0:
		# The forced vent is the authored window, so heat tracks it exactly rather
		# than trickling: the gun reaches cold on the frame fire reopens.
		lockout_remaining = maxf(0.0, lockout_remaining - delta)
		state["lockout_remaining"] = lockout_remaining
		var lockout_seconds := maxf(float(profile.get("heat_lockout_seconds", 0.0)), 0.001)
		state["heat"] = (
			0.0
			if lockout_remaining <= 0.0
			else capacity * (lockout_remaining / lockout_seconds)
		)
		return
	state["heat"] = maxf(
		0.0,
		float(state.get("heat", 0.0))
			- float(profile.get("heat_cooldown_per_second", 0.0)) * delta
	)


func _reset_weapon_heat_for_key(source_key: String) -> bool:
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		return false
	var ledger: Dictionary = registration.get("heat", {})
	if ledger.is_empty():
		return false
	for weapon_id: StringName in ledger:
		var state: Dictionary = ledger[weapon_id]
		state["heat"] = 0.0
		state["lockout_remaining"] = 0.0
	return true


## True when a registered profile carries a complete, normalized travel envelope.
static func profile_is_projectile(profile: Dictionary) -> bool:
	for key: String in PROJECTILE_PROFILE_KEYS:
		if not profile.has(key):
			return false
	return true


## Public read of the lifecycle quarantine the resolver already applies to every
## request.
func is_source_lifecycle_destroyed(source_entity: Node) -> bool:
	return _source_lifecycle_is_destroyed(source_entity)


func _projectile_flight_quarantine_reason(flight: Dictionary) -> StringName:
	var source_reference: WeakRef = flight.get("source") as WeakRef
	var source_entity := source_reference.get_ref() as Node3D if source_reference != null else null
	if not is_instance_valid(source_entity) or not source_entity.is_inside_tree() \
			or source_entity.is_queued_for_deletion():
		return &"source_unavailable"
	if _source_lifecycle_is_destroyed(source_entity):
		return &"source_destroyed"
	var registration: Dictionary = _source_registry.get(String(flight.source_key), {})
	if registration.is_empty():
		return &"unregistered_source"
	if int(registration.get("instance_id", 0)) != int(flight.source_instance_id):
		return &"source_mismatch"
	var profiles: Dictionary = registration.get("weapons", {})
	if (profiles.get(flight.weapon_id, {}) as Dictionary).is_empty():
		return &"weapon_not_authorized"
	return &""


func _prune_projectile_flights() -> void:
	for untyped_flight_id: Variant in _projectile_flights.keys():
		var flight: Dictionary = _projectile_flights[untyped_flight_id]
		var source_reference: WeakRef = flight.get("source") as WeakRef
		if source_reference == null or not is_instance_valid(source_reference.get_ref()):
			_projectile_flights.erase(untyped_flight_id)


func _reject_flight(status: StringName, reason: String) -> Dictionary:
	return {
		"accepted": false,
		"status": status,
		"reason": reason,
		"flight_id": 0,
	}.duplicate(true)


## Detached profile read used by adapters that need to construct a typed
## request without copying weapon range or damage authority into their ledger.
func get_registered_weapon_profile(
		source_entity: Node3D,
		source_id: int,
		weapon_id: StringName
	) -> Dictionary:
	var source_key := _source_key(source_entity, source_id)
	var registration: Dictionary = _source_registry.get(source_key, {})
	var profiles: Dictionary = registration.get("weapons", {})
	return (profiles.get(weapon_id, {}) as Dictionary).duplicate(true)


## `charge_heat` marks the one call that is a *trigger pull*. Only a trigger pull
## is gated by, and pays into, the weapon heat ledger; a travelling bolt's
## terminal segment already paid at launch, and the second and third pellets of
## one scatter trigger are part of the same pull as the first.
func _resolve_request(
		request: ShotRequestType,
		endpoint_override: Vector3 = Vector3.INF,
		skip_origin_tolerance: bool = false,
		charge_heat: bool = true
	) -> Dictionary:
	var result := _make_result(request)
	if request == null:
		return _reject(result, &"invalid_request", "request is null", request)

	var validation_errors := request.get_validation_errors()
	if not validation_errors.is_empty():
		return _reject(
			result,
			&"invalid_request",
			"; ".join(validation_errors),
			request
		)
	if enforce_multiplayer_authority:
		if not is_inside_tree():
			return _reject(
				result,
				&"not_in_tree",
				"resolver is not in a scene tree",
				request
			)
		if not is_multiplayer_authority():
			return _reject(result, &"not_authority", "resolver is not multiplayer authority", request)

	var authority_context := _resolve_authority_context(request, false, skip_origin_tolerance)
	if not bool(authority_context.get("valid", false)):
		return _reject(
			result,
			authority_context.get("status", &"unregistered_source"),
			str(authority_context.get("reason", "source is not registered")),
			request
		)
	var source_key: String = authority_context.source_key
	result["source_entity"] = authority_context.source_entity
	result["source_id"] = authority_context.source_id
	result["source_faction_id"] = authority_context.faction_id
	var previous_sequence := int(_last_sequence_by_source.get(source_key, -1))
	if request.sequence <= previous_sequence:
		var replay_status := (
			&"duplicate_sequence"
			if request.sequence == previous_sequence
			else &"out_of_order_sequence"
		)
		result["last_sequence"] = previous_sequence
		return _reject(
			result,
			replay_status,
			"sequence %d is not newer than %d" % [request.sequence, previous_sequence],
			request
		)

	# A reusable craft retains its stable source identity while its destroyed hull
	# waits for regeneration. Registration continuity must not also grant that dead
	# physical epoch live firing authority. Consume a fresh sequence before
	# rejecting it: otherwise the rejected request could be captured, then replayed
	# after reset_for_reuse() makes the same object healthy again.
	var authoritative_entity: Node3D = authority_context.source_entity
	if _source_lifecycle_is_destroyed(authoritative_entity):
		# A dead epoch keeps no heat. Whatever the hull was carrying when it died is
		# discarded here, so a craft that is later regenerated on the same stable
		# identity can never inherit a lockout it did not earn.
		_reset_weapon_heat_for_key(source_key)
		_last_sequence_by_source[source_key] = request.sequence
		_remember_history_owner(
			source_key,
			authoritative_entity,
			int(authority_context.source_id)
		)
		result["last_sequence"] = request.sequence
		return _reject(
			result,
			&"source_destroyed",
			"registered source belongs to a destroyed lifecycle epoch",
			request
		)

	# The heat gate sits after the replay and lifecycle gates and before the world
	# query, so a locked-out trigger still consumes its sequence: a request that was
	# captured while the gun was venting can never be replayed once it reopens. It
	# applies no damage, runs no ray, and emits no contact.
	if charge_heat and _weapon_heat_is_locked(source_key, request.weapon_id):
		_last_sequence_by_source[source_key] = request.sequence
		_remember_history_owner(
			source_key,
			authoritative_entity,
			int(authority_context.source_id)
		)
		result["last_sequence"] = request.sequence
		return _reject(
			result,
			HEAT_LOCKOUT_STATUS,
			"registered weapon is in its authored heat lockout",
			request
		)

	if not is_inside_tree() or get_world_3d() == null:
		return _reject(result, &"no_physics_world", "resolver is not in a 3D world", request)

	# Valid authority requests consume their sequence even when they miss or are
	# blocked. Re-sending an already-fired shot can therefore never apply damage.
	_last_sequence_by_source[source_key] = request.sequence
	_remember_history_owner(
		source_key,
		authority_context.source_entity,
		int(authority_context.source_id)
	)
	result["accepted"] = true
	result["resolved"] = true
	result["last_sequence"] = request.sequence
	# An accepted trigger pays its heat before the ray is cast, so a shot that
	# misses heats the gun exactly as much as one that hits. A weapon that
	# authored no heat gets no key, so its result dictionary is unchanged.
	if charge_heat:
		var charged_heat := _charge_weapon_heat(source_key, request.weapon_id)
		if not charged_heat.is_empty():
			result["weapon_heat"] = charged_heat

	var authoritative_range: float = authority_context.range
	var authoritative_damage: float = authority_context.damage
	var authoritative_faction: StringName = authority_context.faction_id
	var ray_direction := request.get_normalized_direction()
	var ray_endpoint := request.origin + ray_direction * authoritative_range
	if endpoint_override.is_finite():
		var endpoint_delta := endpoint_override - request.origin
		if not endpoint_delta.is_finite() or endpoint_delta.length_squared() <= 0.000001:
			return _reject(result, &"invalid_projectile_endpoint", "projectile endpoint is not a finite displacement", request)
		if endpoint_delta.length() > authoritative_range + 0.0001:
			return _reject(result, &"projectile_out_of_range", "projectile endpoint exceeds the registered weapon range", request)
		ray_direction = endpoint_delta.normalized()
		ray_endpoint = endpoint_override
	var query := PhysicsRayQueryParameters3D.create(
		request.origin,
		ray_endpoint,
		PhysicsLayerContract.HITSCAN_QUERY_MASK,
		_collect_source_exclusions(authoritative_entity)
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		result["status"] = &"miss"
		_emit_result(request, result)
		return result

	var collider: Object = hit.get("collider")
	var hit_position: Vector3 = hit.get("position", request.origin + ray_direction * request.range)
	var hit_normal: Vector3 = hit.get("normal", -ray_direction)
	result["hit"] = true
	result["collider"] = collider
	result["position"] = hit_position
	result["normal"] = hit_normal
	result["distance"] = request.origin.distance_to(hit_position)

	var damageable: Damageable = _find_damageable(collider)
	if damageable == null:
		result["status"] = (
			&"world_blocked" if _collider_is_world(collider) else &"non_damageable_blocked"
		)
		_emit_result(request, result)
		return result

	result["damageable"] = damageable
	result["target_entity"] = damageable.get_target_entity()
	result["target_faction_id"] = damageable.get_faction_id()
	if not allow_friendly_fire and _same_faction(authoritative_faction, damageable.get_faction_id()):
		result["status"] = &"friendly_fire_blocked"
		_emit_result(request, result)
		return result

	var damage_result := damageable.apply_damage(
		authoritative_damage,
		hit_position,
		hit_normal,
		_make_authoritative_source_context(request, authority_context)
	)
	result["damage_result"] = damage_result
	result["damaged"] = bool(damage_result.get("accepted", false))
	result["applied_damage"] = float(damage_result.get("applied_damage", 0.0))
	result["remaining_health"] = float(damage_result.get("health", damageable.get_health()))
	result["destroyed"] = bool(damage_result.get("destroyed", damageable.is_destroyed()))
	if result["damaged"]:
		result["status"] = &"destroyed" if result["destroyed"] else &"damaged"
	else:
		result["status"] = damage_result.get("reason", &"damage_rejected")
	_emit_result(request, result)
	return result


func get_last_sequence(source_entity: Node = null, source_id: int = 0) -> int:
	_prune_invalid_history()
	var key := _source_key(source_entity, source_id)
	return int(_last_sequence_by_source.get(key, -1))


func forget_source(source_entity: Node = null, source_id: int = 0) -> void:
	var key := _source_key(source_entity, source_id)
	if not key.is_empty():
		_remove_source_registration(key)
		_forget_history(key)


## Retires only the live collision/weapon registration while the stable source
## identity keeps its replay high-water mark. This is the in-tree equivalent of
## the automatic `tree_exiting` retirement: a source that leaves play but is
## still the same physical object (a dormant encounter craft, a pooled opponent)
## must not be able to make a captured pre-retirement request current again by
## re-registering. Use `forget_source()` only to genuinely dispose of an identity.
func retire_source_registration(source_entity: Node = null, source_id: int = 0) -> bool:
	var key := _source_key(source_entity, source_id)
	if key.is_empty() or not _source_registry.has(key):
		return false
	var registration: Dictionary = _source_registry[key]
	var source_reference: WeakRef = registration.get("entity") as WeakRef
	var registered_entity := source_reference.get_ref() as Node if source_reference != null else null
	_remove_source_registration(key)
	# A retired identity is only worth remembering while its physical owner is
	# still alive; a freed owner can never submit again and its ledger entry is
	# reclaimed by the ordinary pruning path.
	if is_instance_valid(registered_entity):
		_remember_history_owner(key, registered_entity, int(registration.get("source_id", source_id)))
	else:
		_forget_history(key)
	return true


func reset_sequence_history() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_last_sequence_by_source.clear()
	_history_owner_by_source.clear()


func get_tracked_source_count() -> int:
	_prune_invalid_history()
	return _last_sequence_by_source.size()


func get_registered_source_count() -> int:
	_prune_invalid_sources()
	return _source_registry.size()


func _make_result(request: ShotRequestType) -> Dictionary:
	return {
		"accepted": false,
		"resolved": false,
		"hit": false,
		"damaged": false,
		"destroyed": false,
		"status": &"unresolved",
		"reason": "",
		"request": request,
		"collider": null,
		"damageable": null,
		"target_entity": null,
		"position": Vector3.INF,
		"normal": Vector3.ZERO,
		"distance": 0.0,
		"applied_damage": 0.0,
		"remaining_health": -1.0,
		"last_sequence": -1,
		"source_entity": null,
		"source_id": 0,
		"source_faction_id": &"",
		"target_faction_id": &"",
		"damage_result": {},
	}


func _make_fan_result(request: ShotRequestType) -> Dictionary:
	var result := _make_result(request)
	result["pellets"] = []
	result["pellet_directions"] = PackedVector3Array()
	result["pellet_count"] = 0
	result["trigger_damage"] = 0.0
	return result


func _reject_fan(result: Dictionary, status: StringName, reason: String) -> Dictionary:
	result["status"] = status
	result["reason"] = reason
	return result


func _copy_fan_contact(aggregate: Dictionary, pellet_result: Dictionary) -> void:
	for key: String in [
		"hit", "collider", "damageable", "target_entity", "position", "normal",
		"distance", "remaining_health", "target_faction_id", "damage_result",
	]:
		aggregate[key] = pellet_result.get(key, aggregate.get(key))


func _reject(
	result: Dictionary,
	status: StringName,
	reason: String,
	request: ShotRequestType
	) -> Dictionary:
	result["status"] = status
	result["reason"] = reason
	_emit_result(request, result)
	return result


func _emit_result(request: ShotRequestType, result: Dictionary) -> void:
	shot_resolved.emit(request, result.duplicate(true))


func _resolve_authority_context(
		request: ShotRequestType,
		expect_trigger_damage: bool = false,
		skip_origin_tolerance: bool = false
	) -> Dictionary:
	var source_key := request.get_source_key()
	var registration: Dictionary = _source_registry.get(source_key, {})
	if registration.is_empty():
		if require_registered_sources:
			return {
				"valid": false,
				"status": &"unregistered_source",
				"reason": "source has no authority registration",
			}
		return _trusted_local_context(request, source_key)
	var source_reference: WeakRef = registration.get("entity") as WeakRef
	var source_entity := source_reference.get_ref() as Node3D if source_reference != null else null
	if (
		not is_instance_valid(source_entity)
		or not source_entity.is_inside_tree()
		or source_entity.is_queued_for_deletion()
	):
		_remove_source_registration(source_key)
		return {
			"valid": false,
			"status": &"source_unavailable",
			"reason": "registered source is not live in the scene tree",
		}
	if is_instance_valid(request.source_entity) and request.source_entity != source_entity:
		return {
			"valid": false,
			"status": &"source_mismatch",
			"reason": "request entity does not match registered source",
		}
	var authoritative_faction: StringName = registration.get("faction_id", &"")
	if not request.faction_id.is_empty() and request.faction_id != authoritative_faction:
		return {
			"valid": false,
			"status": &"source_mismatch",
			"reason": "request faction does not match registered source",
		}
	var profiles: Dictionary = registration.get("weapons", {})
	var profile: Dictionary = profiles.get(request.weapon_id, {})
	if profile.is_empty():
		return {
			"valid": false,
			"status": &"weapon_not_authorized",
			"reason": "weapon is not registered for source",
		}
	var authoritative_range := float(profile.range)
	var authoritative_damage := float(profile.damage)
	var trigger_damage := float(profile.get("trigger_damage", authoritative_damage))
	var pellet_count := int(profile.get("pellet_count", 1))
	var spread_degrees := float(profile.get("spread_degrees", 0.0))
	if expect_trigger_damage and pellet_count <= 1:
		return {
			"valid": false,
			"status": &"weapon_not_scatter",
			"reason": "registered weapon has no scatter envelope",
		}
	var expected_damage := trigger_damage if expect_trigger_damage else authoritative_damage
	if not is_equal_approx(request.range, authoritative_range) \
		or not is_equal_approx(request.damage, expected_damage):
		return {
			"valid": false,
			"status": &"weapon_data_mismatch",
			"reason": "request range or damage differs from authority profile",
		}
	var origin_tolerance := float(profile.origin_tolerance)
	# Hitscan measures the muzzle envelope on the frame it is submitted. A
	# travelling projectile had that same envelope proven against this source at
	# `open_projectile_flight()`; its terminal segment starts wherever the bolt
	# reached, which is intentionally nowhere near the hull by then.
	if not skip_origin_tolerance \
			and source_entity.global_position.distance_to(request.origin) > origin_tolerance:
		return {
			"valid": false,
			"status": &"origin_out_of_bounds",
			"reason": "request origin lies outside the registered source envelope",
		}
	return {
		"valid": true,
		"source_key": source_key,
		"source_entity": source_entity,
		"source_id": int(registration.get("source_id", 0)),
		"faction_id": authoritative_faction,
		"range": authoritative_range,
		"damage": authoritative_damage,
		"trigger_damage": trigger_damage,
		"pellet_count": pellet_count,
		"spread_degrees": spread_degrees,
	}


func _trusted_local_context(request: ShotRequestType, source_key: String) -> Dictionary:
	if (
		not is_instance_valid(request.source_entity)
		or not request.source_entity is Node3D
		or not (request.source_entity as Node3D).is_inside_tree()
		or (request.source_entity as Node3D).is_queued_for_deletion()
	):
		return {
			"valid": false,
			"status": &"source_unavailable",
			"reason": "unregistered local request requires an in-tree Node3D source",
		}
	return {
		"valid": true,
		"source_key": source_key,
		"source_entity": request.source_entity,
		"source_id": request.source_id,
		"faction_id": request.faction_id,
		"range": request.range,
		"damage": request.damage,
	}


func _make_authoritative_source_context(
	request: ShotRequestType,
	authority_context: Dictionary
	) -> Dictionary:
	return {
		"source_entity": authority_context.source_entity,
		"source_id": authority_context.source_id,
		"faction_id": authority_context.faction_id,
		"weapon_id": request.weapon_id,
		"sequence": request.sequence,
		"presentation_receipt_id": request.presentation_receipt_id,
	}


func _normalize_weapon_profiles(profiles: Dictionary) -> Dictionary:
	var normalized := {}
	for untyped_weapon_id: Variant in profiles:
		var weapon_id := StringName(untyped_weapon_id)
		var raw_profile: Variant = profiles[untyped_weapon_id]
		if weapon_id.is_empty() or not raw_profile is Dictionary:
			continue
		var profile := raw_profile as Dictionary
		var weapon_range := float(profile.get("range", 0.0))
		var weapon_damage := float(profile.get("damage", 0.0))
		var origin_tolerance := float(profile.get("origin_tolerance", 12.0))
		var pellet_count := int(profile.get("pellet_count", 1))
		var spread_degrees := float(profile.get("spread_degrees", 0.0))
		var trigger_damage := float(profile.get("trigger_damage", weapon_damage))
		if not is_finite(weapon_range) or weapon_range <= 0.0 \
			or not is_finite(weapon_damage) or weapon_damage <= 0.0 \
			or not is_finite(origin_tolerance) or origin_tolerance <= 0.0 \
			or pellet_count < 1 or pellet_count > SCATTER_PELLET_COUNT \
			or not is_finite(spread_degrees) \
			or spread_degrees < 0.0 or spread_degrees > MAX_SPREAD_DEGREES \
			or not is_finite(trigger_damage) or trigger_damage <= 0.0:
			continue
		if pellet_count == 1 and (spread_degrees != 0.0 or trigger_damage != weapon_damage):
			continue
		if pellet_count != 1 and (
			pellet_count != SCATTER_PELLET_COUNT
			or spread_degrees <= 0.0
			or not is_equal_approx(trigger_damage, weapon_damage * float(pellet_count))
		):
			continue
		var heat_per_shot := float(profile.get("heat_per_shot", 0.0))
		var heat_capacity := float(profile.get("heat_capacity", 0.0))
		var heat_cooldown := float(profile.get("heat_cooldown_per_second", 0.0))
		var heat_lockout := float(profile.get("heat_lockout_seconds", 0.0))
		var declared_heat_keys := 0
		for heat_key: String in HEAT_PROFILE_KEYS:
			if profile.has(heat_key):
				declared_heat_keys += 1
		if declared_heat_keys != 0:
			# A heat envelope is all-or-nothing for the same reason the travel
			# envelope is: a reader that took the fields it recognised and guessed
			# the rest would silently register a gun that never has to stop firing.
			if declared_heat_keys != HEAT_PROFILE_KEYS.size() \
				or not is_finite(heat_per_shot) or heat_per_shot <= 0.0 \
				or heat_per_shot > MAX_HEAT_UNITS \
				or not is_finite(heat_capacity) or heat_capacity <= 0.0 \
				or heat_capacity > MAX_HEAT_UNITS \
				or heat_per_shot > heat_capacity \
				or not is_finite(heat_cooldown) or heat_cooldown <= 0.0 \
				or heat_cooldown > MAX_HEAT_UNITS \
				or not is_finite(heat_lockout) or heat_lockout <= 0.0 \
				or heat_lockout > MAX_HEAT_LOCKOUT_SECONDS:
				continue
		var projectile_speed := float(profile.get("projectile_speed", 0.0))
		var projectile_lifetime := float(profile.get("projectile_lifetime", 0.0))
		var projectile_radius := float(profile.get("projectile_radius", 0.0))
		var declared_projectile_keys := 0
		for projectile_key: String in PROJECTILE_PROFILE_KEYS:
			if profile.has(projectile_key):
				declared_projectile_keys += 1
		if declared_projectile_keys != 0:
			# A travel envelope is all-or-nothing and never mixes with the bounded
			# scatter fan. A partial or out-of-bounds envelope drops the whole
			# weapon rather than silently registering it as hitscan.
			if declared_projectile_keys != PROJECTILE_PROFILE_KEYS.size() \
				or pellet_count != 1 \
				or not is_finite(projectile_speed) or projectile_speed <= 0.0 \
				or projectile_speed > MAX_PROJECTILE_SPEED \
				or not is_finite(projectile_lifetime) or projectile_lifetime <= 0.0 \
				or projectile_lifetime > MAX_PROJECTILE_LIFETIME \
				or not is_finite(projectile_radius) or projectile_radius <= 0.0 \
				or projectile_radius > MAX_PROJECTILE_RADIUS \
				or projectile_speed * projectile_lifetime < weapon_range:
				continue
		normalized[weapon_id] = {
			"range": weapon_range,
			"damage": weapon_damage,
			"origin_tolerance": origin_tolerance,
		}
		if declared_heat_keys == HEAT_PROFILE_KEYS.size():
			normalized[weapon_id]["heat_per_shot"] = heat_per_shot
			normalized[weapon_id]["heat_capacity"] = heat_capacity
			normalized[weapon_id]["heat_cooldown_per_second"] = heat_cooldown
			normalized[weapon_id]["heat_lockout_seconds"] = heat_lockout
		if declared_projectile_keys == PROJECTILE_PROFILE_KEYS.size():
			normalized[weapon_id]["projectile_speed"] = projectile_speed
			normalized[weapon_id]["projectile_lifetime"] = projectile_lifetime
			normalized[weapon_id]["projectile_radius"] = projectile_radius
		if pellet_count > 1:
			normalized[weapon_id]["trigger_damage"] = trigger_damage
			normalized[weapon_id]["spread_degrees"] = spread_degrees
			normalized[weapon_id]["pellet_count"] = pellet_count
	return normalized


func _on_registered_source_exiting(source_key: String, instance_id: int) -> void:
	var registration: Dictionary = _source_registry.get(source_key, {})
	if int(registration.get("instance_id", 0)) == instance_id:
		var source_reference := registration.get("entity") as WeakRef
		var source_entity := (
			source_reference.get_ref() as Node
			if source_reference != null and is_instance_valid(source_reference.get_ref())
			else null
		)
		# An ordinary remove/re-add streams the same physical source out of the tree.
		# Drop only its live collision registration; the stable source-ID replay
		# ledger must survive so a captured pre-detach request remains stale.
		_remove_source_registration(source_key)
		# Once the physical owner is genuinely queued for deletion, its identity is
		# retired and the replay entry can be reclaimed. A live node removed for
		# streaming retains it until re-registration or explicit `forget_source()`.
		if source_entity == null or source_entity.is_queued_for_deletion():
			_forget_history(source_key)


func _remove_source_registration(source_key: String) -> void:
	var registration: Dictionary = _source_registry.get(source_key, {})
	var instance_id := int(registration.get("instance_id", 0))
	# Godot ObjectIDs are signed and may be negative; zero alone means absent.
	if instance_id != 0 and String(_source_key_by_instance_id.get(instance_id, "")) == source_key:
		_source_key_by_instance_id.erase(instance_id)
	_source_registry.erase(source_key)


func _prune_invalid_sources() -> void:
	for source_key: String in _source_registry.keys():
		var registration: Dictionary = _source_registry[source_key]
		var source_reference: WeakRef = registration.get("entity") as WeakRef
		if source_reference == null or not is_instance_valid(source_reference.get_ref()):
			_remove_source_registration(source_key)


func _remember_history_owner(source_key: String, source_entity: Node, source_id: int) -> void:
	if source_key.is_empty() or not is_instance_valid(source_entity):
		return
	_history_owner_by_source[source_key] = {
		"entity": weakref(source_entity),
		"source_id": source_id,
	}


func _forget_history(source_key: String) -> void:
	_last_sequence_by_source.erase(source_key)
	_history_owner_by_source.erase(source_key)


func _prune_invalid_history() -> void:
	for source_key: String in _history_owner_by_source.keys():
		var owner: Dictionary = _history_owner_by_source[source_key]
		var source_reference: WeakRef = owner.get("entity") as WeakRef
		if source_reference == null or not is_instance_valid(source_reference.get_ref()):
			_forget_history(source_key)


func _collect_source_exclusions(source_entity: Node) -> Array[RID]:
	var exclusions: Array[RID] = []
	if not is_instance_valid(source_entity):
		return exclusions
	_append_collision_rids(source_entity, exclusions)
	var ancestor := source_entity.get_parent()
	while ancestor != null:
		if ancestor is CollisionObject3D:
			_append_unique_rid(exclusions, (ancestor as CollisionObject3D).get_rid())
			break
		ancestor = ancestor.get_parent()
	return exclusions


func _append_collision_rids(node: Node, output: Array[RID]) -> void:
	if node is CollisionObject3D:
		_append_unique_rid(output, (node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_append_collision_rids(child, output)


func _append_unique_rid(output: Array[RID], candidate: RID) -> void:
	if candidate.is_valid() and not output.has(candidate):
		output.append(candidate)


func _find_damageable(collider: Object) -> Damageable:
	if not collider is Node:
		return null
	var candidate := collider as Node
	while candidate != null:
		var component := _damageable_on_node(candidate)
		if component != null:
			return component
		candidate = candidate.get_parent()
	return null


func _damageable_on_node(node: Node) -> Damageable:
	if node is DamageableType:
		return node as Damageable
	for method_name: StringName in [&"get_damageable_component", &"get_damageable"]:
		if node.has_method(method_name) and _method_accepts_no_arguments(node, method_name):
			var provided: Variant = node.call(method_name)
			if provided is DamageableType and is_instance_valid(provided):
				return provided as Damageable
	for metadata_name: StringName in [&"damageable_component", &"damageable"]:
		if node.has_meta(metadata_name):
			var tagged: Variant = node.get_meta(metadata_name)
			if tagged is DamageableType:
				return tagged as Damageable
	for child in node.get_children():
		if child is DamageableType:
			return child as Damageable
	return null


func _method_accepts_no_arguments(node: Node, method_name: StringName) -> bool:
	for method_info: Dictionary in node.get_method_list():
		if StringName(method_info.get("name", &"")) != method_name:
			continue
		var arguments: Array = method_info.get("args", [])
		var defaults: Array = method_info.get("default_args", [])
		return arguments.size() - defaults.size() <= 0
	return false


## Queries only lifecycle state already owned by the registered physical source
## or its attached Damageable adapter. A merely inactive but healthy pooled craft
## is not classified as destroyed; its encounter coordinator continues to own
## ordinary activation/deactivation authorization.
func _source_lifecycle_is_destroyed(source_entity: Node) -> bool:
	if not is_instance_valid(source_entity):
		return true
	if (
		source_entity.has_method(&"is_destroyed")
		and _method_accepts_no_arguments(source_entity, &"is_destroyed")
		and bool(source_entity.call(&"is_destroyed"))
	):
		return true
	var damageable := _damageable_on_node(source_entity)
	return (
		damageable != null
		and damageable.get_target_entity() == source_entity
		and damageable.is_destroyed()
	)


func _collider_is_world(collider: Object) -> bool:
	return (
		collider is CollisionObject3D
		and ((collider as CollisionObject3D).collision_layer & PhysicsLayerContract.WORLD) != 0
	)


func _same_faction(source_faction: StringName, target_faction: StringName) -> bool:
	return not source_faction.is_empty() and source_faction == target_faction


func _source_key(source_entity: Node, source_id: int) -> String:
	if source_id > 0:
		return "source_id:%d" % source_id
	if is_instance_valid(source_entity):
		return "instance_id:%d" % source_entity.get_instance_id()
	return ""
