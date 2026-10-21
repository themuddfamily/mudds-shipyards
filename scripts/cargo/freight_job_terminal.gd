class_name FreightJobTerminal
extends Area3D

## A physical view/request adapter for the existing Jovian delivery owner.
## This fitting is never registered as a cargo owner and cannot transfer stock.
const INTERACTION_RADIUS := 2.4

var endpoint_id: StringName
var endpoint_role: StringName
var _snapshot_provider: Callable
var _selection_request: Callable
var _dispatching := false
var _last_result: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	if get_node_or_null(^"InteractionShape") == null:
		var collision := CollisionShape3D.new()
		collision.name = "InteractionShape"
		var shape := SphereShape3D.new()
		shape.radius = 0.45
		collision.shape = shape
		add_child(collision)


func configure(snapshot_provider: Callable, selection_request: Callable) -> void:
	_snapshot_provider = snapshot_provider
	_selection_request = selection_request


func get_state_snapshot() -> Dictionary:
	var state: Dictionary = _snapshot_provider.call() if _current() and _snapshot_provider.is_valid() else {}
	state["endpoint_id"] = endpoint_id
	state["endpoint_role"] = endpoint_role
	state["owns_inventory"] = false
	state["manual_transfer_authority"] = false
	state["last_result"] = _last_result.duplicate(true)
	return state.duplicate(true)


func get_interaction_prompt() -> String:
	if not _current():
		return ""
	var state := get_state_snapshot()
	return "[ E ]  FREIGHT %s // %s" % [
		"DISPATCH" if endpoint_role == &"source" else "MANIFEST",
		str(state.get("status_text", "OWNER UNAVAILABLE")),
	]


func can_interact(actor: Node) -> bool:
	return _current() and actor is PlayerController and actor.is_inside_tree() \
		and not actor.is_queued_for_deletion() \
		and (actor as PlayerController).get_interaction_origin().distance_to(global_position) <= INTERACTION_RADIUS \
		and (actor as PlayerController).get_nearby_interactables().has(self)


func interact(actor: Node = null) -> bool:
	if _dispatching or not can_interact(actor) or not _selection_request.is_valid():
		return false
	_dispatching = true
	_last_result = _selection_request.call(self, actor)
	_dispatching = false
	return bool(_last_result.get("accepted", false))


func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_visible_in_tree()
