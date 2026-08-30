class_name FleetRegistryConsole
extends Area3D

## Read-only physical adapter for the retained fleet registry.
##
## This node owns proximity, its prompt, and a screen made exclusively from a
## detached GameFlow snapshot. It cannot see a ShipBerth, HeroShip, or
## regeneration queue and therefore cannot acquire any of their authority.

signal snapshot_requested(actor: Node)

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER
const INTERACTION_SHAPE_SIZE := Vector3(4.8, 2.8, 2.0)
const INTERACTION_SHAPE_OFFSET := Vector3(0.0, 0.0, -1.35)
const SCREEN_POSITION := Vector3(0.0, 0.38, -1.085)
const SCREEN_SIZE := Vector3(3.76, 1.46, 0.018)
const TEXT_POSITION := Vector3(0.0, 0.38, -1.105)
const VALID_STATES: Array[StringName] = [
	&"available", &"occupied", &"destroyed", &"regenerating",
]
const MAX_ROWS := 12

var _built := false
var _presentation_sequence := 0
var _last_snapshot: Dictionary = {}
var _screen_text := "FLEET STATUS\nPRESS E TO REFRESH"
var _status_label: Label3D


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = INTERACTABLE_LAYER
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	if not _built:
		_built = true
		_build_screen()
		_build_interaction_shape()


func get_interaction_prompt() -> String:
	return "[ E ]  VIEW FLEET REGISTRY" if _is_current() else ""


func interact(actor: Node = null) -> bool:
	if not _is_current() or not is_instance_valid(actor):
		return false
	snapshot_requested.emit(actor)
	return true


## Accept only detached scalar/collection data. Object-bearing rows are refused
## before presentation so this component cannot accidentally retain live craft
## or berth authority across a request.
func present_fleet_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _is_current():
		return {"accepted": false, "reason": &"console_unavailable"}
	if _contains_live_reference(snapshot):
		return {"accepted": false, "reason": &"registry_snapshot_not_detached"}
	var rows_raw: Variant = snapshot.get("rows", null)
	if not rows_raw is Array or (rows_raw as Array).size() > MAX_ROWS:
		return {"accepted": false, "reason": &"invalid_registry_rows"}
	var lines := PackedStringArray(["FLEET STATUS // LIVE"])
	for row_raw: Variant in rows_raw as Array:
		if not row_raw is Dictionary:
			return {"accepted": false, "reason": &"invalid_registry_row"}
		var row := row_raw as Dictionary
		var ship_id_raw: Variant = row.get("ship_id", null)
		var display_name_raw: Variant = row.get("display_name", null)
		var berth_id_raw: Variant = row.get("berth_id", null)
		var state_raw: Variant = row.get("state", null)
		if not (ship_id_raw is String or ship_id_raw is StringName) \
				or not (display_name_raw is String or display_name_raw is StringName) \
				or not (berth_id_raw is String or berth_id_raw is StringName) \
				or not (state_raw is String or state_raw is StringName):
			return {"accepted": false, "reason": &"invalid_registry_row"}
		var state := StringName(state_raw)
		if state not in VALID_STATES:
			return {"accepted": false, "reason": &"invalid_registry_state"}
		lines.append("%-18s  %s" % [
			_display_name(String(display_name_raw)), String(state).to_upper(),
		])
	_presentation_sequence += 1
	_last_snapshot = snapshot.duplicate(true)
	_screen_text = "\n".join(lines)
	if is_instance_valid(_status_label):
		_status_label.text = _screen_text
	return {
		"accepted": true,
		"reason": &"fleet_snapshot_presented",
		"presentation_sequence": _presentation_sequence,
		"row_count": (rows_raw as Array).size(),
	}.duplicate(true)


func get_presentation_snapshot() -> Dictionary:
	return {
		"screen_text": _screen_text,
		"presentation_sequence": _presentation_sequence,
		"last_snapshot": _last_snapshot.duplicate(true),
		"interaction_prompt": get_interaction_prompt(),
		"authority": {
			"berth": false,
			"regeneration": false,
			"ship_lifecycle": false,
			"fleet_membership": false,
		},
	}.duplicate(true)


func _display_name(value: String) -> String:
	var normalized := value.strip_edges().replace("_", " ").to_upper()
	return (normalized if not normalized.is_empty() else "CRAFT").left(18)


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _contains_live_reference(value: Variant) -> bool:
	# Callables and Signals can retain an Object even though Variant does not
	# classify either value as TYPE_OBJECT. RIDs likewise name live engine-side
	# state. None is detached presentation data, so reject all four categories
	# recursively before retaining the snapshot.
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if _contains_live_reference(key) \
					or _contains_live_reference((value as Dictionary).get(key)):
				return true
	elif value is Array:
		for item: Variant in value as Array:
			if _contains_live_reference(item):
				return true
	return false


func _build_interaction_shape() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var shape := BoxShape3D.new()
	shape.size = INTERACTION_SHAPE_SIZE
	collision.shape = shape
	collision.position = INTERACTION_SHAPE_OFFSET
	add_child(collision)


func _build_screen() -> void:
	var cover := MeshInstance3D.new()
	cover.name = "FleetRegistryLiveScreen"
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = SCREEN_SIZE
	cover.mesh = cover_mesh
	cover.position = SCREEN_POSITION
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_color = Color("86e7eb")
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cover.material_override = screen_material
	cover.set_meta("presentation_only", true)
	add_child(cover)

	_status_label = Label3D.new()
	_status_label.name = "FleetRegistryLiveRows"
	_status_label.text = _screen_text
	_status_label.position = TEXT_POSITION
	_status_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_status_label.font_size = 40
	# Ten production lines (header plus nine retained craft) need to fit the
	# terminal's 1.46 m screen with a readable top/bottom margin. The former
	# 0.0032 scale visibly lost the header and last row at the normal approach.
	_status_label.pixel_size = 0.0022
	_status_label.modulate = Color("071217")
	_status_label.outline_size = 0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.set_meta("presentation_only", true)
	add_child(_status_label)
