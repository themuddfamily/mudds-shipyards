class_name ActivityBoardConsole
extends Area3D

## Embodied access point for the existing sortie-selection UI.
##
## This component intentionally owns no activity state.  It only makes one
## authored station console discoverable through the common on-foot interaction
## path, then asks its coordinator to open the already-owned Activity Board.

signal open_requested(actor: Node)

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER
const INTERACTION_SHAPE_SIZE := Vector3(2.2, 2.1, 1.5)
const INTERACTION_SHAPE_OFFSET := Vector3(0.0, 0.85, -1.05)

var _built := false


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = INTERACTABLE_LAYER
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	if not _built:
		_built = true
		_build_interaction_shape()


func get_interaction_prompt() -> String:
	if not _is_current():
		return ""
	return "[ E ]  ACCESS ACTIVITY BOARD"


func interact(actor: Node = null) -> bool:
	if not _is_current() or not is_instance_valid(actor):
		return false
	open_requested.emit(actor)
	return true


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _build_interaction_shape() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var shape := BoxShape3D.new()
	shape.size = INTERACTION_SHAPE_SIZE
	collision.shape = shape
	collision.position = INTERACTION_SHAPE_OFFSET
	add_child(collision)
