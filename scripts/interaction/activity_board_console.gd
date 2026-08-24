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

## The Aft Operations console is one of three visually similar workstations. Its
## interaction prompt identifies it only after the player has already aimed at
## the correct screen, so the physical display also needs an at-a-glance label.
## These presentation-only elements sit just above the existing angled glass;
## they neither mirror nor own activity selection, lifecycle, or reward state.
const READABILITY_ROOT_NAME := &"ActivityBoardReadability"
const READABILITY_LABEL_TEXT := "ACTIVITY BOARD"
const READABILITY_LABEL_POSITION := Vector3(0.0, 1.478, -0.355)
const READABILITY_LABEL_SCALE := 0.12
## TextMesh faces local +Z and reads upward along local +Y. From the interaction
## side (local -Z), its screen-right axis is local -X; freezing all three axes
## avoids the easy-to-miss 180-degree roll produced by the old Euler rotation.
const READABILITY_GLYPH_RIGHT := Vector3.LEFT
const READABILITY_GLYPH_UP := Vector3(0.0, 0.2079117, 0.9781476)
const READABILITY_FACE_NORMAL := Vector3(0.0, 0.9781476, -0.2079117)
const READABILITY_UNDERLINE_POSITION := Vector3(0.0, 1.455, -0.465)
const READABILITY_UNDERLINE_SIZE := Vector3(1.18, 0.014, 0.025)
const READABILITY_CYAN := Color("9ff5f2")
const READABILITY_AMBER := Color("ffc36a")

var _built := false


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = INTERACTABLE_LAYER
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	if not _built:
		_built = true
		_build_readability_visuals()
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


func _build_readability_visuals() -> void:
	var visuals := Node3D.new()
	visuals.name = READABILITY_ROOT_NAME
	visuals.set_meta("presentation_only", true)
	add_child(visuals)

	var label_mesh := TextMesh.new()
	label_mesh.text = READABILITY_LABEL_TEXT
	label_mesh.font_size = 64
	label_mesh.pixel_size = 0.012
	label_mesh.depth = 0.006
	label_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label := MeshInstance3D.new()
	label.name = "ActivityBoardHeader"
	label.mesh = label_mesh
	label.position = READABILITY_LABEL_POSITION
	label.basis = Basis(
		READABILITY_GLYPH_RIGHT,
		READABILITY_GLYPH_UP,
		READABILITY_FACE_NORMAL
	).scaled(Vector3.ONE * READABILITY_LABEL_SCALE)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.material_override = _readability_material(READABILITY_CYAN, 1.35)
	visuals.add_child(label)

	var underline_mesh := BoxMesh.new()
	underline_mesh.size = READABILITY_UNDERLINE_SIZE
	var underline := MeshInstance3D.new()
	underline.name = "ActivityBoardLocatorUnderline"
	underline.mesh = underline_mesh
	underline.position = READABILITY_UNDERLINE_POSITION
	underline.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	underline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underline.material_override = _readability_material(READABILITY_AMBER, 1.05)
	visuals.add_child(underline)


func _readability_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.05
	material.roughness = 0.32
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material
