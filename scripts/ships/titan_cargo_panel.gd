class_name TitanCargoPanel
extends Area3D

## Compact physical presentation only; custody and all quantities stay in the
## Titan adapter / CargoTransferAuthority, never in this panel.
const MAX_REACH := 2.35
var custody: TitanCargoCustody
var loading := false
var _label: Label3D
var _solid_collision: CollisionShape3D

func _ready() -> void:
	monitoring = false
	collision_mask = 0
	collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	shape.shape = sphere
	add_child(shape)
	var screen := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.52, 0.72) if not loading else Vector3(0.72, 0.52, 0.12)
	screen.mesh = box
	_solid_collision = CollisionShape3D.new()
	_solid_collision.name = "TitanHoldPanelSolid" if not loading else "LockerScreenCollision"
	var solid := BoxShape3D.new()
	solid.size = box.size
	_solid_collision.shape = solid
	# The moving hold screen is real HeroShip-owned hull collision. Keeping it
	# on that body also lets inherited hull preflight exclude its own geometry.
	if get_parent() is HeroShip and not loading:
		_solid_collision.transform = transform
		get_parent().add_child(_solid_collision)
	else:
		var body := StaticBody3D.new()
		body.name = "LockerScreenBody"
		body.collision_layer = PhysicsLayers.WORLD
		body.collision_mask = 0
		add_child(body)
		body.add_child(_solid_collision)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("233d49")
	material.emission_enabled = true
	material.emission = Color("315463")
	screen.material_override = material
	add_child(screen)
	_label = Label3D.new()
	_label.font_size = 28
	_label.pixel_size = 0.003
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.09, 0.38, 0)
	_label.no_depth_test = false
	add_child(_label)

func _process(_delta: float) -> void:
	if not is_instance_valid(custody):
		return
	var state := custody.snapshot()
	_label.text = ("TITAN SUPPLY LOCKER" if loading else "TITAN PARCEL HOLD") + "\nSealed repair kit\nLOCKER %d / 4    TITAN %d / 4\n%s" % [state.locker, state.titan, state.status]

func get_interaction_prompt() -> String:
	if not is_instance_valid(custody):
		return "Cargo custody unavailable"
	var state := custody.snapshot()
	if not bool(state.available):
		return str(state.status)
	return "[ E ] %s ONE SEALED REPAIR KIT  |  LOCKER %d/4  TITAN %d/4\n%s" % ["LOAD" if loading else "RETURN", state.locker, state.titan, state.status]

func interact(actor: Node = null) -> bool:
	return bool(custody.request_transfer(actor, self, loading).get("accepted", false)) if is_instance_valid(custody) else false
