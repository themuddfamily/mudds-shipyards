class_name PlanetaryDestinationConsole
extends Area3D

## Physical station access point for the retained planetary Destination Board.
##
## The terminal owns proximity and its small diegetic display only. It cannot
## select a destination, launch travel, move an actor, stream a world, or grant
## a reward; one accepted interaction asks GameFlow to open the existing HUD.

signal open_requested(actor: Node)

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER
const INTERACTION_SHAPE_SIZE := Vector3(2.2, 2.1, 1.5)
const INTERACTION_SHAPE_OFFSET := Vector3(0.0, 0.85, -1.05)
const READABILITY_ROOT_NAME := &"PlanetaryDestinationReadability"
const HEADER_TEXT := "DESTINATION BOARD"
const INITIAL_STATUS_TEXT := "NAVIGATION CATALOG OFFLINE"
const INITIAL_ROUTE_TEXT := "EMBER // ROUTE UNKNOWN"
const HEADER_POSITION := Vector3(0.0, 1.500, -0.105)
const STATUS_POSITION := Vector3(0.0, 1.485, -0.285)
const ROUTE_POSITION := Vector3(0.0, 1.463, -0.405)
const UNDERLINE_POSITION := Vector3(0.0, 1.455, -0.475)
const HEADER_SCALE := 0.105
const STATUS_SCALE := 0.052
const ROUTE_SCALE := 0.052
const UNDERLINE_SIZE := Vector3(1.18, 0.014, 0.025)
const GLYPH_RIGHT := Vector3.LEFT
const GLYPH_UP := Vector3(0.0, 0.2079117, 0.9781476)
const FACE_NORMAL := Vector3(0.0, 0.9781476, -0.2079117)
const CYAN := Color("75d7df")
const AMBER := Color("f0ae5b")
const MUTED := Color("6f8c98")
const MAX_DESTINATIONS := 16
const STATUS_IDS := [
	&"ready",
	&"queued",
	&"accelerating",
	&"cruising",
	&"braking_to_speed",
	&"braking",
	&"unavailable",
]

static var _shared_header_mesh: TextMesh
static var _shared_underline_mesh: BoxMesh

var _built := false
var _destination_count := 0
var _routed_destination_count := 0
var _ember_status_id: StringName = &"unavailable"
var _status_text := INITIAL_STATUS_TEXT
var _route_text := INITIAL_ROUTE_TEXT
var _status_mesh: TextMesh
var _route_mesh: TextMesh
var _route_label: MeshInstance3D
var _route_material: StandardMaterial3D


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
	return "[ E ]  ACCESS DESTINATION BOARD"


func interact(actor: Node = null) -> bool:
	if not _is_current() or not is_instance_valid(actor):
		return false
	open_requested.emit(actor)
	return true


## Accepts the already-resolved catalog counts and Ember public status. These
## values repaint the display only; they cannot issue or synthesize a route.
func present_catalog_status(
	destination_count: int,
	routed_destination_count: int,
	ember_status_id: StringName,
) -> bool:
	if (
		destination_count < 1
		or destination_count > MAX_DESTINATIONS
		or routed_destination_count < 0
		or routed_destination_count > destination_count
		or ember_status_id not in STATUS_IDS
	):
		return false
	_destination_count = destination_count
	_routed_destination_count = routed_destination_count
	_ember_status_id = ember_status_id
	_status_text = "%d WORLDS // %d ROUTE%s" % [
		_destination_count,
		_routed_destination_count,
		"" if _routed_destination_count == 1 else "S",
	]
	_route_text = "EMBER // %s" % _ember_status_copy(_ember_status_id)
	_apply_catalog_status()
	return true


func get_presentation_snapshot() -> Dictionary:
	return {
		"header_text": HEADER_TEXT,
		"destination_count": _destination_count,
		"routed_destination_count": _routed_destination_count,
		"ember_status_id": _ember_status_id,
		"status_text": _status_text,
		"route_text": _route_text,
		"interaction_prompt": get_interaction_prompt(),
		"presentation_only": true,
		"authority": {
			"destination_selection": false,
			"travel": false,
			"movement": false,
			"streaming": false,
			"origin_shift": false,
			"landing": false,
			"activity": false,
			"reward": false,
		},
	}.duplicate(true)


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _ember_status_copy(status_id: StringName) -> String:
	match status_id:
		&"ready":
			return "READY"
		&"queued":
			return "QUEUED"
		&"accelerating", &"cruising":
			return "EN ROUTE"
		&"braking_to_speed":
			return "FINAL APPROACH"
		&"braking":
			return "HOLDING"
		_:
			return "ROUTE LOCKED"


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
	header.name = "PlanetaryDestinationHeader"
	header.mesh = _get_shared_header_mesh()
	header.position = HEADER_POSITION
	header.basis = Basis(GLYPH_RIGHT, GLYPH_UP, FACE_NORMAL).scaled(
		Vector3.ONE * HEADER_SCALE
	)
	header.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	header.material_override = _readability_material(CYAN)
	visuals.add_child(header)

	_status_mesh = _text_mesh(_status_text)
	var status_label := MeshInstance3D.new()
	status_label.name = "PlanetaryDestinationCatalogStatus"
	status_label.mesh = _status_mesh
	status_label.position = STATUS_POSITION
	status_label.basis = Basis(GLYPH_RIGHT, GLYPH_UP, FACE_NORMAL).scaled(
		Vector3.ONE * STATUS_SCALE
	)
	status_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	status_label.material_override = _readability_material(MUTED)
	visuals.add_child(status_label)

	_route_mesh = _text_mesh(_route_text)
	_route_label = MeshInstance3D.new()
	_route_label.name = "PlanetaryDestinationEmberStatus"
	_route_label.mesh = _route_mesh
	_route_label.position = ROUTE_POSITION
	_route_label.basis = Basis(GLYPH_RIGHT, GLYPH_UP, FACE_NORMAL).scaled(
		Vector3.ONE * ROUTE_SCALE
	)
	_route_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_route_material = _readability_material(MUTED)
	_route_label.material_override = _route_material
	visuals.add_child(_route_label)

	var underline := MeshInstance3D.new()
	underline.name = "PlanetaryDestinationLocatorUnderline"
	underline.mesh = _get_shared_underline_mesh()
	underline.position = UNDERLINE_POSITION
	underline.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	underline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underline.material_override = _readability_material(AMBER)
	visuals.add_child(underline)
	_apply_catalog_status()


func _apply_catalog_status() -> void:
	if _status_mesh != null:
		_status_mesh.text = _status_text
	if _route_mesh != null:
		_route_mesh.text = _route_text
	if _route_material != null:
		_route_material.albedo_color = (
			CYAN
			if _ember_status_id == &"ready"
			else AMBER
			if _ember_status_id != &"unavailable"
			else MUTED
		)


static func _text_mesh(text: String) -> TextMesh:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font_size = 64
	mesh.pixel_size = 0.012
	mesh.depth = 0.004
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return mesh


static func _get_shared_header_mesh() -> TextMesh:
	if _shared_header_mesh == null:
		_shared_header_mesh = _text_mesh(HEADER_TEXT)
		_shared_header_mesh.depth = 0.006
	return _shared_header_mesh


static func _get_shared_underline_mesh() -> BoxMesh:
	if _shared_underline_mesh == null:
		var mesh := BoxMesh.new()
		mesh.size = UNDERLINE_SIZE
		_shared_underline_mesh = mesh
	return _shared_underline_mesh


static func _readability_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
