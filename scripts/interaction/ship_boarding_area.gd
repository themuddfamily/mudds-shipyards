class_name ShipBoardingArea
extends Area3D

## Physical interaction point for boarding any compatible spacecraft.
##
## Place this area at the ship's boarding step and leave [member ship_path] at
## its default when the ship is the direct parent. A compatible ship is any
## Node3D exposing both `get_boarding_entry_transform()` and
## `get_pilot_seat_anchor()`. If it additionally exposes `is_boardable()`, that
## result participates in availability without coupling this component to one
## concrete ship class.

signal availability_changed(available: bool)
signal reservation_changed(reserved: bool, token: Variant)

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER

@export var interaction_id: StringName = &"board_ship"
@export_multiline var prompt_text := "[ E ]  BOARD SPACECRAFT"
@export var ship_path := NodePath("..")
@export var boarding_enabled := true:
	set(value):
		if boarding_enabled == value:
			return
		boarding_enabled = value
		if not boarding_enabled:
			clear_reservation()
		_apply_enabled_state()
		_emit_availability_if_changed()

var _has_reservation := false
var _reservation_token: Variant = null
var _last_reported_availability := false


func _ready() -> void:
	_apply_enabled_state()
	_last_reported_availability = is_available()


## Resolves the spacecraft that owns this interaction point. The return value is
## deliberately Node3D rather than HeroShip so future craft controllers can use
## the same physical interaction contract.
func get_ship() -> Node3D:
	if ship_path.is_empty():
		return null
	var candidate := get_node_or_null(ship_path) as Node3D
	if candidate == null:
		return null
	if not candidate.has_method("get_boarding_entry_transform"):
		return null
	if not candidate.has_method("get_pilot_seat_anchor"):
		return null
	return candidate


func get_interaction_id() -> StringName:
	return interaction_id


func get_prompt() -> String:
	return prompt_text


## True only when an operational owner exists, boarding is enabled, the owner
## permits boarding, and no player currently holds the seat reservation.
func is_available() -> bool:
	_clear_stale_reservation()
	return _base_availability() and not _has_reservation


## Allows a reservation owner to continue the boarding handoff while denying
## every other contender. An unreserved area is usable by any non-null token.
func is_available_for(token: Variant) -> bool:
	_clear_stale_reservation()
	if token == null or not _base_availability():
		return false
	return not _has_reservation or _tokens_match(_reservation_token, token)


## Atomically claims the boarding point. Repeating the request with the same
## token is idempotent; a different token cannot steal an occupied seat.
func try_reserve(token: Variant) -> bool:
	if not is_available_for(token):
		return false
	if _has_reservation:
		return true
	_has_reservation = true
	_reservation_token = token
	reservation_changed.emit(true, token)
	_emit_availability_if_changed()
	return true


## Releases the seat only for the token that reserved it.
func release_reservation(token: Variant) -> bool:
	_clear_stale_reservation()
	if not _has_reservation or not _tokens_match(_reservation_token, token):
		return false
	_clear_reservation_internal(true)
	return true


## Administrative release used when a ship is disabled, destroyed, or reset.
func clear_reservation() -> void:
	_clear_stale_reservation()
	if _has_reservation:
		_clear_reservation_internal(true)


func is_reserved() -> bool:
	_clear_stale_reservation()
	return _has_reservation


func get_reservation_token() -> Variant:
	_clear_stale_reservation()
	return _reservation_token if _has_reservation else null


## Explicit method form for coordinators that should not assign exported fields.
## Disabling also releases any reservation and removes the area from physics
## discovery, preventing a stale prompt during destruction or recycling.
func set_boarding_enabled(enabled: bool) -> void:
	boarding_enabled = enabled


func _base_availability() -> bool:
	if not boarding_enabled:
		return false
	var ship := get_ship()
	if ship == null:
		return false
	if ship.has_method("is_boardable") and not bool(ship.call("is_boardable")):
		return false
	return true


func _apply_enabled_state() -> void:
	collision_layer = INTERACTABLE_LAYER if boarding_enabled else 0
	collision_mask = 0
	monitoring = false
	monitorable = boarding_enabled
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not boarding_enabled)


func _clear_stale_reservation() -> void:
	if (
		_has_reservation
		and typeof(_reservation_token) == TYPE_OBJECT
		and not is_instance_valid(_reservation_token)
	):
		_clear_reservation_internal(true)


func _clear_reservation_internal(emit_signal: bool) -> void:
	var released_token: Variant = _reservation_token
	_has_reservation = false
	_reservation_token = null
	if emit_signal:
		reservation_changed.emit(false, released_token)
	_emit_availability_if_changed()


func _tokens_match(first: Variant, second: Variant) -> bool:
	if typeof(first) == TYPE_OBJECT or typeof(second) == TYPE_OBJECT:
		return is_instance_valid(first) and is_instance_valid(second) and first == second
	return first == second


func _emit_availability_if_changed() -> void:
	var available := _base_availability() and not _has_reservation
	if available == _last_reported_availability:
		return
	_last_reported_availability = available
	availability_changed.emit(available)
