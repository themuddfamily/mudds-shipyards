class_name SalvageInspectionInteractable
extends Area3D

## Passive proximity adapter for world-owned inspection state. No inventory,
## pickup, reward, audio, or save authority lives on a component's visual node.

const REACH_METRES := 2.35

var _target_id: StringName
var _request: Callable
var _prompt: Callable


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.0, 0.8)
	collision.shape = shape
	add_child(collision)
	set_meta("station_interactable", true)


func configure(target_id: StringName, request: Callable, prompt: Callable) -> void:
	_target_id = target_id
	_request = request
	_prompt = prompt


func get_interaction_prompt() -> String:
	if not _is_current() or not _prompt.is_valid():
		return ""
	return str(_prompt.call(_target_id))


func can_interact(actor: Node) -> bool:
	if not _is_current() or not _request.is_valid() \
			or not is_instance_valid(actor) or not actor is Node3D \
			or not actor.is_inside_tree() or actor.is_queued_for_deletion() \
			or not actor.has_method("get_interaction_origin") \
			or not actor.has_method("get_nearby_interactables"):
		return false
	var origin: Vector3 = actor.call("get_interaction_origin")
	var nearby: Variant = actor.call("get_nearby_interactables")
	return origin.is_finite() and origin.distance_to(global_position) <= REACH_METRES \
		and nearby is Array and nearby.has(self)


func interact(actor: Node = null) -> bool:
	if not can_interact(actor):
		return false
	var result: Dictionary = _request.call(_target_id, actor)
	return bool(result.get("accepted", false))


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()
