class_name ShipServiceConsole
extends Area3D

## Physical access point for dockside repair-kit restocking.
##
## The console owns proximity, its prompt, and detached presentation only. It
## emits one request to GameFlow, while the selected HeroShip and its existing
## RepairAuthority retain lifecycle, eligibility, and resource mutation.

signal service_requested(actor: Node)

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER
const INTERACTION_SHAPE_SIZE := Vector3(2.2, 2.1, 1.5)
const INTERACTION_SHAPE_OFFSET := Vector3(0.0, 0.85, -1.05)
const READABILITY_ROOT_NAME := &"ShipServiceReadability"
const HEADER_TEXT := "SHIP SERVICES"
const INITIAL_STATUS_TEXT := "READY // LAND & EXIT ENGINEER CRAFT"
const HEADER_POSITION := Vector3(0.0, 1.500, -0.105)
const STATUS_POSITION := Vector3(0.0, 1.485, -0.285)
const UNDERLINE_POSITION := Vector3(0.0, 1.480, -0.345)
const HEADER_SCALE := 0.12
const STATUS_SCALE := 0.055
const UNDERLINE_SIZE := Vector3(1.18, 0.014, 0.025)
const GLYPH_RIGHT := Vector3.LEFT
const GLYPH_UP := Vector3(0.0, 0.2079117, 0.9781476)
const FACE_NORMAL := Vector3(0.0, 0.9781476, -0.2079117)
const CYAN := Color("0b5160")
const AMBER := Color("8d4b00")
const MAX_DISPLAY_NAME_LENGTH := 28

static var _shared_header_mesh: TextMesh
static var _shared_underline_mesh: BoxMesh

var _built := false
var _status_mesh: TextMesh
var _status_label: MeshInstance3D
var _status_text := INITIAL_STATUS_TEXT
var _presentation_sequence := 0
var _last_result: Dictionary = {}


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
	return "[ E ]  RESTOCK ACTIVE SHIP REPAIR KITS"


func interact(actor: Node = null) -> bool:
	if not _is_current() or not is_instance_valid(actor):
		return false
	service_requested.emit(actor)
	return true


## Accepts only detached result data from GameFlow. It cannot invoke a ship or
## infer eligibility from scene state, so presentation can never become a
## second resource authority.
func present_service_result(result: Dictionary) -> Dictionary:
	if not _is_current():
		return {"accepted": false, "reason": &"console_unavailable"}
	var accepted_raw: Variant = result.get("accepted", null)
	var reason_raw: Variant = result.get("reason", null)
	if not accepted_raw is bool \
			or not (reason_raw is String or reason_raw is StringName):
		return {"accepted": false, "reason": &"invalid_service_result"}
	var reason := StringName(reason_raw)
	var text := _rejection_text(reason)
	if bool(accepted_raw):
		var units_raw: Variant = result.get("resource_units", null)
		var capacity_raw: Variant = result.get("resource_capacity", null)
		var added_raw: Variant = result.get("units_added", null)
		if not units_raw is int or not capacity_raw is int or not added_raw is int \
				or int(capacity_raw) <= 0 \
				or int(units_raw) < 0 or int(units_raw) > int(capacity_raw) \
				or int(added_raw) < 0 or int(added_raw) > int(capacity_raw):
			return {"accepted": false, "reason": &"invalid_service_resources"}
		var craft_name := _display_name(str(result.get("display_name", "CRAFT")))
		text = (
			"RESTOCKED // %s // KITS %d/%d" % [
				craft_name, int(units_raw), int(capacity_raw)
			]
			if int(added_raw) > 0 else
			"FULL // %s // KITS %d/%d" % [
				craft_name, int(units_raw), int(capacity_raw)
			]
		)
	_presentation_sequence += 1
	_status_text = text
	_last_result = result.duplicate(true)
	if _status_mesh != null:
		_status_mesh.text = _status_text
	return {
		"accepted": true,
		"reason": &"service_result_presented",
		"presentation_sequence": _presentation_sequence,
		"text": _status_text,
	}.duplicate(true)


func get_presentation_snapshot() -> Dictionary:
	return {
		"header": HEADER_TEXT,
		"status_text": _status_text,
		"presentation_sequence": _presentation_sequence,
		"last_result": _last_result.duplicate(true),
		"interaction_prompt": get_interaction_prompt(),
		"authority": {
			"repair": false,
			"resource": false,
			"damage": false,
			"ship_lifecycle": false,
		},
	}.duplicate(true)


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _rejection_text(reason: StringName) -> String:
	match reason:
		&"unsupported_ship":
			return "SELECT JOVIAN // HALYARD // BULWARK"
		&"ship_not_landed":
			return "SERVICE BLOCKED // LAND CRAFT"
		&"pilot_seated":
			return "SERVICE BLOCKED // EXIT PILOT SEAT"
		&"ship_destroyed":
			return "SERVICE BLOCKED // REGENERATION ACTIVE"
		&"repair_active":
			return "SERVICE BLOCKED // REPAIR IN PROGRESS"
		&"active_ship_unavailable":
			return "NO ACTIVE CRAFT // FLY ENGINEER CRAFT"
		_:
			return "SERVICE UNAVAILABLE // %s" % _display_name(String(reason))


func _display_name(value: String) -> String:
	var normalized := value.strip_edges().replace("_", " ").to_upper()
	if normalized.is_empty():
		normalized = "CRAFT"
	return normalized.left(MAX_DISPLAY_NAME_LENGTH)


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

	var header := MeshInstance3D.new()
	header.name = "ShipServiceHeader"
	header.mesh = _get_shared_header_mesh()
	header.position = HEADER_POSITION
	header.basis = Basis(GLYPH_RIGHT, GLYPH_UP, FACE_NORMAL).scaled(
		Vector3.ONE * HEADER_SCALE
	)
	header.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	header.material_override = _readability_material(CYAN)
	visuals.add_child(header)

	_status_mesh = TextMesh.new()
	_status_mesh.text = _status_text
	_status_mesh.font_size = 64
	_status_mesh.pixel_size = 0.012
	_status_mesh.depth = 0.004
	_status_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label = MeshInstance3D.new()
	_status_label.name = "ShipServiceStatus"
	_status_label.mesh = _status_mesh
	_status_label.position = STATUS_POSITION
	_status_label.basis = Basis(GLYPH_RIGHT, GLYPH_UP, FACE_NORMAL).scaled(
		Vector3.ONE * STATUS_SCALE
	)
	_status_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var amber_material := _readability_material(AMBER)
	_status_label.material_override = amber_material
	visuals.add_child(_status_label)

	var underline := MeshInstance3D.new()
	underline.name = "ShipServiceLocatorUnderline"
	underline.mesh = _get_shared_underline_mesh()
	underline.position = UNDERLINE_POSITION
	underline.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	underline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underline.material_override = amber_material
	visuals.add_child(underline)


static func _get_shared_header_mesh() -> TextMesh:
	if _shared_header_mesh == null:
		var mesh := TextMesh.new()
		mesh.text = HEADER_TEXT
		mesh.font_size = 64
		mesh.pixel_size = 0.012
		mesh.depth = 0.006
		mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shared_header_mesh = mesh
	return _shared_header_mesh


static func _get_shared_underline_mesh() -> BoxMesh:
	if _shared_underline_mesh == null:
		var mesh := BoxMesh.new()
		mesh.size = UNDERLINE_SIZE
		_shared_underline_mesh = mesh
	return _shared_underline_mesh


func _readability_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
