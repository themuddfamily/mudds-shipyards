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
const MAX_ROWS := 15
const PAGE_FIELDS := [
	["maximum_speed", "maximum_hull", "boost_speed", "thrust_acceleration"],
	["yaw_speed_degrees", "roll_speed_degrees", "brake_acceleration", "passive_drag"],
	["boost_multiplier", "landing_maximum_speed", "engine_start_time", "weapon_cooldown"],
	["throttle_response", "flight_assist_strength", "visual_bank_degrees", "maximum_mouse_turn_degrees"],
]
const PAGE_HEADERS := [
	"RATED 1/4 RAW/IDX 0..1 | SPEED m/s HULL pt BOOST m/s THRUST m/s2 | INTERACT:NEXT",
	"RATED 2/4 RAW/IDX 0..1 | YAW deg/s ROLL deg/s BRAKE m/s2 DRAG m/s2 | INTERACT:NEXT",
	"RATED 3/4 RAW/IDX 0..1 | THRUSTx LAND m/s SPOOL s RATED COOLDOWN s | INTERACT:NEXT",
	"RATED 4/4 THROTTLE 1/s RAW/IDX 0..1 | FEEL RAW: ASSIST 1/s BANK deg MOUSE deg | INTERACT:NEXT",
]

var _rated_page := -1

var _built := false
var _presentation_sequence := 0
var _last_snapshot: Dictionary = {}
# The nearby HUD prompt supplies the live binding; the physical screen must
# also remain accurate for remapped keys and controller input.
var _screen_text := "FLEET STATUS\nINTERACT TO REFRESH"
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
func present_fleet_snapshot(snapshot: Dictionary, advance_page: bool = false) -> Dictionary:
	if not _is_current():
		return {"accepted": false, "reason": &"console_unavailable"}
	if _contains_live_reference(snapshot):
		return {"accepted": false, "reason": &"registry_snapshot_not_detached"}
	var rows_raw: Variant = snapshot.get("rows", null)
	if not rows_raw is Array or (rows_raw as Array).size() > MAX_ROWS:
		return {"accepted": false, "reason": &"invalid_registry_rows"}
	var rated_rows := 0
	for row_raw: Variant in rows_raw as Array:
		if row_raw is Dictionary and row_raw.has("rated_budget"):
			rated_rows += 1
	if rated_rows != 0 and rated_rows != rows_raw.size():
		return {"accepted": false, "reason": &"incomplete_rated_budget_rows"}
	var rated := rated_rows > 0
	var proposed_page := maxi(_rated_page, 0)
	if rated and advance_page and _rated_page >= 0:
		proposed_page = (_rated_page + 1) % PAGE_FIELDS.size()
	var lines := PackedStringArray([PAGE_HEADERS[proposed_page] if rated else "FLEET STATUS // LIVE"])
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
		var line := "%-18s  %s" % [_display_name(String(display_name_raw)), String(state).to_upper()]
		if rated:
			var budget: Variant = row.get("rated_budget")
			if not _valid_rated_budget(budget, String(ship_id_raw)):
				return {"accepted": false, "reason": &"invalid_rated_budget"}
			var fields: Dictionary = budget.fields
			var cells := PackedStringArray()
			for axis: String in PAGE_FIELDS[proposed_page]:
				var field: Dictionary = fields[axis]
				cells.append(str(field.raw) if field.direction == "undirected" else "%s/%.3f" % [str(field.raw), field.normalized])
			line = "%-18s %-12s %s" % [_display_name(String(display_name_raw)), String(state).to_upper(), "  ".join(cells)]
		lines.append(line)
	if rated:
		_rated_page = proposed_page
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
		"rated_page": _rated_page,
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


func _valid_rated_budget(value: Variant, ship_id: String) -> bool:
	if not value is Dictionary:
		return false
	var budget: Dictionary = value
	if not budget.get("valid") is bool or not budget.valid:
		return false
	for key: String in ["ship_id", "qualification"]:
		if not (budget.get(key) is String or budget.get(key) is StringName):
			return false
	if str(budget.ship_id) != ship_id or str(budget.qualification) != "NOT_QUALIFIED":
		return false
	var missing: Variant = budget.get("missing_dimensions")
	if not missing is Array or missing != FleetRatedBudget.MISSING_DIMENSIONS:
		return false
	var fields: Variant = budget.get("fields")
	if not fields is Dictionary or fields.size() != FleetRatedBudget.FIELD_SPECS.size():
		return false
	for axis: String in FleetRatedBudget.FIELD_SPECS:
		var spec: Array = FleetRatedBudget.FIELD_SPECS[axis]
		var field: Variant = fields.get(axis)
		if not field is Dictionary or field.size() != (5 if spec[1] == "undirected" else 6):
			return false
		for key: String in ["unit", "direction", "source"]:
			if not field.get(key) is String:
				return false
		if field.unit != spec[0] or field.direction != spec[1] \
				or field.source != "ShipDefinition.get_%s_profile.%s" % [spec[2], axis]:
			return false
		for key: String in ["raw", "unit_scale"]:
			var number: Variant = field.get(key)
			if not (number is float or number is int) or not is_finite(float(number)):
				return false
		var raw := float(field.raw)
		if raw < 0.0 or float(field.unit_scale) != 1.0:
			return false
		if spec[1] == "undirected":
			if field.has("normalized"):
				return false
		else:
			var normalized: Variant = field.get("normalized")
			if not (normalized is float or normalized is int) or not is_finite(float(normalized)):
				return false
			var expected := raw / (1.0 + raw) if spec[1] == "benefit" else 1.0 / (1.0 + raw)
			if absf(float(normalized) - expected) > 0.000000000001:
				return false
	return true


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
	# Sixteen production lines (header plus fifteen retained craft) fit the
	# terminal's 1.46 m screen with a readable top/bottom margin.
	_status_label.pixel_size = 0.0016
	_status_label.modulate = Color("071217")
	_status_label.outline_size = 0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.set_meta("presentation_only", true)
	add_child(_status_label)
