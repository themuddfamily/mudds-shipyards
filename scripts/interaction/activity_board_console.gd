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
const READABILITY_RECEIPT_POSITION := Vector3(0.0, 1.405, -0.63)
const READABILITY_RECEIPT_SCALE := 0.058
const READABILITY_CYAN := Color("9ff5f2")
const READABILITY_AMBER := Color("ffc36a")
const READABILITY_MUTED := Color("7897a6")
const MAX_ACTIVITY_REWARD_RECEIPTS := 9_007_199_254_740_991
const ACTIVITY_REWARD_SUMMARY_KEYS := [
	"available",
	"total_receipts",
	"last_receipt_id",
	"last_reward_label",
]

var _built := false
var _receipt_status: MeshInstance3D
var _receipt_status_mesh: TextMesh
var _reward_summary := {
	"available": false,
	"total_receipts": 0,
	"last_receipt_id": 0,
	"last_reward_label": "",
}

static var _shared_readability_label_mesh: TextMesh
static var _shared_readability_underline_mesh: BoxMesh


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


## Mirrors the exact detached aggregate already published to the HUD. The
## console cannot inspect the store, grant a reward, or infer currency or
## inventory; it only repaints its existing physical screen.
func set_reward_summary(summary: Dictionary) -> bool:
	if not _valid_reward_summary(summary):
		return false
	_reward_summary = summary.duplicate(true)
	_apply_reward_summary()
	return true


func get_presentation_snapshot() -> Dictionary:
	return {
		"reward_summary": _reward_summary.duplicate(true),
		"receipt_status_text": (
			_receipt_status_mesh.text
			if _receipt_status_mesh != null else ""
		),
		"presentation_only": true,
		"activity_authority": false,
		"reward_authority": false,
		"save_authority": false,
		"currency_authority": false,
		"inventory_authority": false,
	}.duplicate(true)


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

	var label := MeshInstance3D.new()
	label.name = "ActivityBoardHeader"
	label.mesh = _get_shared_readability_label_mesh()
	label.position = READABILITY_LABEL_POSITION
	label.basis = Basis(
		READABILITY_GLYPH_RIGHT,
		READABILITY_GLYPH_UP,
		READABILITY_FACE_NORMAL
	).scaled(Vector3.ONE * READABILITY_LABEL_SCALE)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.material_override = _readability_material(READABILITY_CYAN, 1.35)
	visuals.add_child(label)

	var underline := MeshInstance3D.new()
	underline.name = "ActivityBoardLocatorUnderline"
	underline.mesh = _get_shared_readability_underline_mesh()
	underline.position = READABILITY_UNDERLINE_POSITION
	underline.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	underline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underline.material_override = _readability_material(READABILITY_AMBER, 1.05)
	visuals.add_child(underline)

	_receipt_status_mesh = TextMesh.new()
	_receipt_status_mesh.font_size = 48
	_receipt_status_mesh.pixel_size = 0.01
	_receipt_status_mesh.depth = 0.004
	_receipt_status_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_receipt_status_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_receipt_status = MeshInstance3D.new()
	_receipt_status.name = "ActivityBoardReceiptStatus"
	_receipt_status.mesh = _receipt_status_mesh
	_receipt_status.position = READABILITY_RECEIPT_POSITION
	_receipt_status.basis = Basis(
		READABILITY_GLYPH_RIGHT,
		READABILITY_GLYPH_UP,
		READABILITY_FACE_NORMAL
	).scaled(Vector3.ONE * READABILITY_RECEIPT_SCALE)
	_receipt_status.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_receipt_status.material_override = _readability_material(READABILITY_MUTED, 0.8)
	visuals.add_child(_receipt_status)
	_apply_reward_summary()


static func _get_shared_readability_label_mesh() -> TextMesh:
	if _shared_readability_label_mesh == null:
		var mesh := TextMesh.new()
		mesh.text = READABILITY_LABEL_TEXT
		mesh.font_size = 64
		mesh.pixel_size = 0.012
		mesh.depth = 0.006
		mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shared_readability_label_mesh = mesh
	return _shared_readability_label_mesh


static func _get_shared_readability_underline_mesh() -> BoxMesh:
	if _shared_readability_underline_mesh == null:
		var mesh := BoxMesh.new()
		mesh.size = READABILITY_UNDERLINE_SIZE
		_shared_readability_underline_mesh = mesh
	return _shared_readability_underline_mesh


func _readability_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.05
	material.roughness = 0.32
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material


func _valid_reward_summary(summary: Dictionary) -> bool:
	if summary.size() != ACTIVITY_REWARD_SUMMARY_KEYS.size():
		return false
	for key: String in ACTIVITY_REWARD_SUMMARY_KEYS:
		if not summary.has(key):
			return false
	var available_value: Variant = summary.get("available")
	var total_value: Variant = summary.get("total_receipts")
	var receipt_value: Variant = summary.get("last_receipt_id")
	var label_value: Variant = summary.get("last_reward_label")
	if available_value is not bool or total_value is not int \
			or receipt_value is not int or label_value is not String:
		return false
	var available := bool(available_value)
	var total_receipts := int(total_value)
	var last_receipt_id := int(receipt_value)
	var last_reward_label := str(label_value)
	if total_receipts < 0 or total_receipts > MAX_ACTIVITY_REWARD_RECEIPTS \
			or last_receipt_id < 0 \
			or last_receipt_id > MAX_ACTIVITY_REWARD_RECEIPTS:
		return false
	if not available:
		return total_receipts == 0 and last_receipt_id == 0 \
			and last_reward_label.is_empty()
	if total_receipts == 0:
		return last_receipt_id == 0 and last_reward_label.is_empty()
	return last_receipt_id == total_receipts \
		and not last_reward_label.is_empty() and last_reward_label.length() <= 96


func _apply_reward_summary() -> void:
	if _receipt_status_mesh == null or not is_instance_valid(_receipt_status):
		return
	var available := bool(_reward_summary.get("available", false))
	var total_receipts := int(_reward_summary.get("total_receipts", 0))
	var text := "BROWSE  //  RETURNS OFFLINE"
	var color := READABILITY_MUTED
	var emission_energy := 0.8
	if available and total_receipts == 0:
		text = "BROWSE  //  NO RETURNS FILED"
		color = READABILITY_CYAN
		emission_energy = 1.0
	elif available:
		text = "BROWSE  //  %d RETURNS FILED" % total_receipts
		color = READABILITY_AMBER
		emission_energy = 1.15
	_receipt_status_mesh.text = text
	var material := _receipt_status.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = emission_energy
