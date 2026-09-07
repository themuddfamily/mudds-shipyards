class_name ShipCabinHatch
extends Area3D

## A landed cabin's physical hatch control. The ship remains the sole owner of
## canopy animation and its matching door collider.
const MOTION_SECONDS := 0.35
const MAX_REACH := 2.5
var _ship: HeroShip
var _motion_remaining := 0.0


static func install(hatch_root: Node3D, ship: HeroShip, local_position: Vector3) -> ShipCabinHatch:
	var hatch := ShipCabinHatch.new()
	hatch.name = "CabinHatchInteraction"
	hatch._ship = ship
	hatch.position = local_position
	hatch_root.add_child(hatch)
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	collision.shape = shape
	hatch.add_child(collision)
	return hatch


func _ready() -> void:
	monitoring = false
	collision_mask = 0
	_sync_availability()


func _physics_process(delta: float) -> void:
	_motion_remaining = maxf(0.0, _motion_remaining - delta)
	_sync_availability()


func is_available() -> bool:
	return is_instance_valid(_ship) and not _ship.is_destroyed() \
		and not _ship.is_piloted() and bool(_ship.get_telemetry().get("landed", false)) \
		and _motion_remaining <= 0.0


func get_interaction_prompt() -> String:
	if not is_available():
		return ""
	return "[ E ] CLOSE CABIN HATCH" if _ship.is_canopy_open() else "[ E ] OPEN CABIN HATCH"


func interact(actor: Node = null) -> bool:
	if not is_available() or not actor is Node3D:
		return false
	var origin := (actor as Node3D).global_position
	if actor.has_method("get_interaction_origin"):
		origin = actor.call("get_interaction_origin") as Vector3
	if origin.distance_to(global_position) > MAX_REACH:
		return false
	_motion_remaining = MOTION_SECONDS
	_ship.set_canopy_open(not _ship.is_canopy_open(), MOTION_SECONDS)
	_sync_availability()
	return true


func _sync_availability() -> void:
	collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER if is_available() else 0
