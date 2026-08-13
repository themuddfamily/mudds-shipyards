class_name StationDoor
extends Area3D

## Reusable, coordinator-agnostic station door.
##
## The Area3D root is the interaction target exposed on layer 8. A fixed portal
## blocker remains active for CLOSED, OPENING, and CLOSING so a doorway never
## becomes physically clear before its state is fully OPEN. The visible panel
## slides independently, allowing deterministic mid-motion reversal without a
## tween reset or a discontinuous transform jump.

signal state_changed(previous_state: int, current_state: int)
signal motion_completed(final_state: int)
signal interaction_accepted(actor: Node, requested_open: bool)
signal interaction_refused(actor: Node, reason: StringName)
signal lock_changed(is_locked: bool)

enum DoorState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}

const WORLD_LAYER := 1
const INTERACTION_LAYER := 1 << 3

@export_category("Motion")
@export_range(0.0, 8.0, 0.01) var motion_duration := 0.8
@export var open_offset := Vector3(3.6, 0.0, 0.0)
@export var starts_open := false

@export_category("Interaction")
@export var interaction_label := "OPERATIONS ACCESS"
@export var locked_prompt := "ACCESS LOCKED"
@export var locked := false

@export_category("Deferred content")
@export var deferred_access := false
@export var deferred_label := "VIP ACCESS"
@export var deferred_prompt := "ACCESS DEFERRED"

@export_category("Evidence metadata")
@export var evidence_status: StringName = &"modern_interpretation"
@export_multiline var content_note := ""

@onready var _sliding_panel: Node3D = %SlidingPanel
@onready var _portal_blocker: StaticBody3D = %PortalBlocker

var _state: int = DoorState.CLOSED
var _motion_progress := 0.0
var _closed_panel_transform := Transform3D.IDENTITY


func _ready() -> void:
	_closed_panel_transform = _sliding_panel.transform
	_motion_progress = 1.0 if starts_open else 0.0
	_state = DoorState.OPEN if starts_open else DoorState.CLOSED
	_apply_panel_transform()
	_set_portal_blocked(_state != DoorState.OPEN)
	_update_metadata()


func _physics_process(delta: float) -> void:
	if _state != DoorState.OPENING and _state != DoorState.CLOSING:
		return

	if motion_duration <= 0.0:
		_complete_motion(_state == DoorState.OPENING)
		return

	var direction := 1.0 if _state == DoorState.OPENING else -1.0
	_motion_progress = clampf(
		_motion_progress + direction * delta / motion_duration,
		0.0,
		1.0
	)
	_apply_panel_transform()
	if _state == DoorState.OPENING and is_equal_approx(_motion_progress, 1.0):
		_complete_motion(true)
	elif _state == DoorState.CLOSING and is_equal_approx(_motion_progress, 0.0):
		_complete_motion(false)


## Returns a state-aware prompt without depending on a HUD implementation.
func get_interaction_prompt() -> String:
	var label := _get_effective_label()
	if deferred_access:
		return "[ DEFERRED ]  %s  //  %s" % [label, deferred_prompt]
	if locked:
		return "[ LOCKED ]  %s  //  %s" % [label, locked_prompt]
	var action := "OPEN" if _state == DoorState.CLOSED or _state == DoorState.CLOSING else "CLOSE"
	return "[ E ]  %s %s" % [action, label]


## Actor is deliberately optional: access policy can be extended later without
## coupling this component to a specific player class.
func can_interact(_actor: Node = null) -> bool:
	return not locked and not deferred_access


## Toggles the requested destination. Interacting during motion reverses from
## the exact current progress rather than restarting from an endpoint.
func interact(actor: Node = null) -> bool:
	if deferred_access:
		interaction_refused.emit(actor, &"deferred")
		return false
	if locked:
		interaction_refused.emit(actor, &"locked")
		return false

	var requested_open := _state == DoorState.CLOSED or _state == DoorState.CLOSING
	if not _begin_motion(requested_open):
		interaction_refused.emit(actor, &"already_at_destination")
		return false
	interaction_accepted.emit(actor, requested_open)
	return true


func get_state() -> int:
	return _state


func get_state_name() -> StringName:
	match _state:
		DoorState.CLOSED:
			return &"CLOSED"
		DoorState.OPENING:
			return &"OPENING"
		DoorState.OPEN:
			return &"OPEN"
		DoorState.CLOSING:
			return &"CLOSING"
	return &"UNKNOWN"


func is_open() -> bool:
	return _state == DoorState.OPEN


func is_portal_blocked() -> bool:
	return _portal_blocker != null and _portal_blocker.collision_layer == WORLD_LAYER


func set_locked(value: bool) -> void:
	if locked == value:
		return
	locked = value
	_update_metadata()
	lock_changed.emit(locked)


func set_deferred_access(value: bool) -> void:
	if deferred_access == value:
		return
	deferred_access = value
	_update_metadata()


func _begin_motion(requested_open: bool) -> bool:
	if requested_open:
		if _state == DoorState.OPEN or _state == DoorState.OPENING:
			return false
		_set_portal_blocked(true)
		_change_state(DoorState.OPENING)
	else:
		if _state == DoorState.CLOSED or _state == DoorState.CLOSING:
			return false
		# Closing blocks immediately; OPEN is the only clear state.
		_set_portal_blocked(true)
		_change_state(DoorState.CLOSING)

	if motion_duration <= 0.0:
		_complete_motion(requested_open)
	return true


func _complete_motion(opened: bool) -> void:
	_motion_progress = 1.0 if opened else 0.0
	_apply_panel_transform()
	var final_state := DoorState.OPEN if opened else DoorState.CLOSED
	var previous_state := _state
	_state = final_state
	# Publish a coherent state: listeners observing OPEN also see a clear portal.
	_set_portal_blocked(not opened)
	state_changed.emit(previous_state, _state)
	motion_completed.emit(_state)


func _change_state(next_state: int) -> void:
	if _state == next_state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)


func _apply_panel_transform() -> void:
	# Smoothstep supplies gentle acceleration while remaining a pure function of
	# progress, so reversing direction cannot introduce a positional discontinuity.
	var eased_progress := _motion_progress * _motion_progress * (3.0 - 2.0 * _motion_progress)
	var panel_transform := _closed_panel_transform
	panel_transform.origin = _closed_panel_transform.origin + open_offset * eased_progress
	_sliding_panel.transform = panel_transform


func _set_portal_blocked(blocked: bool) -> void:
	if _portal_blocker == null:
		return
	_portal_blocker.collision_layer = WORLD_LAYER if blocked else 0
	_portal_blocker.collision_mask = 0


func _get_effective_label() -> String:
	if deferred_access and not deferred_label.strip_edges().is_empty():
		return deferred_label.strip_edges()
	var cleaned_label := interaction_label.strip_edges()
	return cleaned_label if not cleaned_label.is_empty() else "STATION DOOR"


func _update_metadata() -> void:
	set_meta("station_interactable", true)
	set_meta("station_door", true)
	set_meta("interaction_layer", INTERACTION_LAYER)
	set_meta("access_label", _get_effective_label())
	set_meta("locked", locked)
	set_meta("deferred_access", deferred_access)
	set_meta("evidence_status", evidence_status)
	set_meta("content_note", content_note)
