class_name CinderLightInterceptor
extends HeroShip

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")

## Original-modern lightweight interceptor. No historical craft, weapon, or
## combat claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-light-interceptor"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder light interceptor"
const HULL_SIZE := Vector3(4.8, 2.5, 8.8)
const HULL_COLOR := Color("e0a43d")
const CANOPY_COLOR := Color("55d5dc")
const CANOPY_RADIUS := 1.25
const CANOPY_HEIGHT := 1.5
const CANOPY_POSITION := Vector3(0.0, 1.1, -2.1)
const WING_COLOR := Color("8b4a38")
const WEAPON_ID: StringName = &"cinder_light_repeater"
const CONSOLE_TOGGLE_VISIBLE_COPIES := 8
const CONSOLE_TOGGLE_LEGACY_SUBMISSIONS := 8
const CONSOLE_TOGGLE_BATCH_SUBMISSIONS := 1
const CONSOLE_TOGGLE_NAMES := [
	"PortConsoleToggle00",
	"PortConsoleToggle01",
	"PortConsoleToggle02",
	"PortConsoleToggle03",
	"StarboardConsoleToggle00",
	"StarboardConsoleToggle01",
	"StarboardConsoleToggle02",
	"StarboardConsoleToggle03",
]
const CONSOLE_KEY_VISIBLE_COPIES := 4
const CONSOLE_KEY_LEGACY_SUBMISSIONS := 4
const CONSOLE_KEY_BATCH_SUBMISSIONS := 1
const CONSOLE_KEY_NAMES := [
	"PortConsoleKey00",
	"PortConsoleKey02",
	"StarboardConsoleKey00",
	"StarboardConsoleKey02",
]
const CONSOLE_CENTER_KEY_VISIBLE_COPIES := 2
const CONSOLE_CENTER_KEY_LEGACY_SUBMISSIONS := 2
const CONSOLE_CENTER_KEY_BATCH_SUBMISSIONS := 1
const CONSOLE_CENTER_KEY_NAMES := [
	"PortConsoleKey01",
	"StarboardConsoleKey01",
]

# The primary hull is immutable presentation stock. Fleet composition and ship
# replacement can briefly retain multiple interceptors, so cache this exact
# recipe across copies while renderer nodes, submissions, transforms, collision,
# and all gameplay authority remain per craft.
static var _shared_hull_mesh: BoxMesh
static var _shared_hull_material: StandardMaterial3D
# The broad response wing is likewise immutable exterior presentation stock.
# Sharing its exact mesh and finish across briefly coexisting fleet copies saves
# duplicate resources without merging renderer nodes or changing submissions.
static var _shared_wing_mesh: BoxMesh
static var _shared_wing_material: StandardMaterial3D
# The canopy shell is immutable exterior presentation stock. Its renderer stays
# per craft so visibility, culling, and submissions remain unchanged, while the
# identical emissive sphere recipe is allocated once across live fleet copies.
static var _shared_canopy_mesh: SphereMesh
static var _shared_canopy_material: StandardMaterial3D

var _interceptor_boarding_marker: Marker3D
var _interceptor_built := false
var _weapon_definition: WeaponDefinition
var _ship_perspective_audio_binding: RefCounted
var _console_toggle_batch: MultiMeshInstance3D
var _console_key_batch: MultiMeshInstance3D
var _console_center_key_batch: MultiMeshInstance3D

func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_cinder_interceptor_perspective_audio")


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	_weapon_definition = _build_weapon_definition()
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Light interceptor"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_cinder_interceptor_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not _interceptor_built:
		_interceptor_built = rebuild_variant_presentation(_build_interceptor_variant)

func _exit_tree() -> void:
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_cinder_interceptor_camera_view_changed):
			camera_view_changed.disconnect(_on_cinder_interceptor_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	super._exit_tree()

func _rebind_cinder_interceptor_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null or _ship_audio_rig == null:
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) and not camera_view_changed.is_connected(_on_cinder_interceptor_camera_view_changed):
		camera_view_changed.connect(_on_cinder_interceptor_camera_view_changed)

func _on_cinder_interceptor_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)

func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() if _ship_perspective_audio_binding != null else {"attached": false}


func _build_interceptor_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderInterceptorVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_batch_console_toggles(visual)
	_batch_console_keys(visual)
	_batch_console_center_keys(visual)
	_build_hull(visual)
	_build_boarding_marker(visual)
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _interceptor_boarding_marker


## Returns a defensive copy of the interceptor's explicit modern combat role.
## Shared combat resolution remains outside this presentation/flight component.
func get_weapon_definition() -> WeaponDefinition:
	return _weapon_definition.duplicate(true) as WeaponDefinition if _weapon_definition != null else null


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _interceptor_built:
		errors.append("interceptor has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_interceptor_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if not bool(get_landing_collision_report().get("valid", false)):
		errors.append("interceptor requires HeroShip root collision")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"combat_authority": false,
		"weapon_authority": false,
		"weapon_definition_valid": _weapon_definition != null and _weapon_definition.is_definition_valid(),
		"weapon_id": WEAPON_ID,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_weapon_definition() -> WeaponDefinition:
	var definition := WeaponDefinitionType.new() as WeaponDefinition
	definition.weapon_id = WEAPON_ID
	definition.display_name = "Cinder light repeater"
	definition.resolution_mode = WeaponDefinition.ResolutionMode.HITSCAN
	definition.evidence_status = WeaponDefinition.EvidenceStatus.NEW
	definition.evidence_notes = "Original-modern lightweight interceptor tuning; not a recovered historical weapon specification."
	definition.range_meters = 320.0
	definition.damage_per_hit = 18.0
	definition.cadence_shots_per_second = 6.0
	definition.presentation_id = &"cinder_light_repeater"
	definition.fire_audio_id = &"cinder_light_repeater_fire"
	definition.impact_audio_id = &"cinder_light_repeater_impact"
	definition.dry_fire_audio_id = &"cinder_light_repeater_dry_fire"
	return definition


func _build_collision() -> void:
	_add_box_collision_shape("InterceptorHullCollision", Vector3.ZERO, HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "HighVisibilityHull"
	if _shared_hull_mesh == null:
		_shared_hull_mesh = BoxMesh.new()
		_shared_hull_mesh.size = HULL_SIZE
		_shared_hull_mesh.resource_local_to_scene = false
	if _shared_hull_material == null:
		_shared_hull_material = _material(HULL_COLOR, 0.62, 0.36)
		_shared_hull_material.resource_local_to_scene = false
	hull.mesh = _shared_hull_mesh
	hull.material_override = _shared_hull_material
	visual.add_child(hull)
	var wing := MeshInstance3D.new()
	wing.name = "RapidResponseWing"
	if _shared_wing_mesh == null:
		_shared_wing_mesh = BoxMesh.new()
		_shared_wing_mesh.size = Vector3(12.0, 0.45, 2.4)
		_shared_wing_mesh.resource_local_to_scene = false
	if _shared_wing_material == null:
		_shared_wing_material = _material(WING_COLOR, 0.5, 0.36)
		_shared_wing_material.resource_local_to_scene = false
	wing.mesh = _shared_wing_mesh
	wing.position = Vector3(0.0, -0.15, 0.8)
	wing.material_override = _shared_wing_material
	visual.add_child(wing)
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	if _shared_canopy_mesh == null:
		_shared_canopy_mesh = SphereMesh.new()
		_shared_canopy_mesh.radius = CANOPY_RADIUS
		_shared_canopy_mesh.height = CANOPY_HEIGHT
		_shared_canopy_mesh.resource_local_to_scene = false
	if _shared_canopy_material == null:
		_shared_canopy_material = _material(CANOPY_COLOR, 0.15, 0.36, CANOPY_COLOR, 2.0)
		_shared_canopy_material.resource_local_to_scene = false
	canopy.mesh = _shared_canopy_mesh
	canopy.position = CANOPY_POSITION
	canopy.material_override = _shared_canopy_material
	visual.add_child(canopy)


## The inherited cockpit's eight toggles are childless visual dressing. Their
## authored names and local transforms remain inspectable on the one batch;
## functional cockpit, command, canopy, weapon, and damage nodes are untouched.
func _batch_console_toggles(visual: Node3D) -> void:
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit == null:
		return
	var toggles: Array[MeshInstance3D] = []
	for toggle_name in CONSOLE_TOGGLE_NAMES:
		var toggle := cockpit.get_node_or_null(toggle_name) as MeshInstance3D
		if toggle == null or toggle.get_child_count() != 0 or toggle.mesh == null:
			return
		toggles.append(toggle)
	var source := toggles[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for toggle in toggles:
		if (
			toggle.mesh.get_class() != source_mesh.get_class()
			or toggle.mesh.get_aabb() != source_mesh.get_aabb()
			or toggle.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(toggle) != source_material
			or toggle.cast_shadow != source.cast_shadow
			or toggle.layers != source.layers
			or toggle.extra_cull_margin != source.extra_cull_margin
			or toggle.visibility_range_begin != source.visibility_range_begin
			or toggle.visibility_range_end != source.visibility_range_end
			or toggle.visibility_range_begin_margin != source.visibility_range_begin_margin
			or toggle.visibility_range_end_margin != source.visibility_range_end_margin
			or toggle.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for toggle in toggles:
		transforms.append(toggle.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_console_toggle_batch = MultiMeshInstance3D.new()
	_console_toggle_batch.name = "CinderConsoleToggleBatch"
	_console_toggle_batch.multimesh = multi
	_console_toggle_batch.material_override = source.material_override
	_console_toggle_batch.cast_shadow = source.cast_shadow
	_console_toggle_batch.layers = source.layers
	_console_toggle_batch.extra_cull_margin = source.extra_cull_margin
	_console_toggle_batch.visibility_range_begin = source.visibility_range_begin
	_console_toggle_batch.visibility_range_end = source.visibility_range_end
	_console_toggle_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_console_toggle_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_console_toggle_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_console_toggle_batch.set_meta(&"visual_detail_only", true)
	_console_toggle_batch.set_meta(&"authored_visual_names", PackedStringArray(CONSOLE_TOGGLE_NAMES))
	_console_toggle_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for toggle in toggles:
		toggle.free()
	cockpit.add_child(_console_toggle_batch)


## Four cyan console keys are childless visual dressing. The two gold centre
## keys and every functional cockpit/command node remain individually authored.
func _batch_console_keys(visual: Node3D) -> void:
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit == null:
		return
	var keys: Array[MeshInstance3D] = []
	for key_name in CONSOLE_KEY_NAMES:
		var key := cockpit.get_node_or_null(key_name) as MeshInstance3D
		if (
			key == null
			or key.get_child_count() != 0
			or key.mesh == null
			or key.get_script() != null
			or not key.get_groups().is_empty()
			or not key.get_meta_list().is_empty()
		):
			return
		keys.append(key)
	var source := keys[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for key in keys:
		if (
			key.mesh.get_class() != source_mesh.get_class()
			or key.mesh.get_aabb() != source_mesh.get_aabb()
			or key.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(key) != source_material
			or key.material_overlay != source.material_overlay
			or key.visible != source.visible
			or key.cast_shadow != source.cast_shadow
			or key.layers != source.layers
			or key.extra_cull_margin != source.extra_cull_margin
			or key.ignore_occlusion_culling != source.ignore_occlusion_culling
			or key.lod_bias != source.lod_bias
			or key.visibility_range_begin != source.visibility_range_begin
			or key.visibility_range_end != source.visibility_range_end
			or key.visibility_range_begin_margin != source.visibility_range_begin_margin
			or key.visibility_range_end_margin != source.visibility_range_end_margin
			or key.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for key in keys:
		transforms.append(key.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_console_key_batch = MultiMeshInstance3D.new()
	_console_key_batch.name = "CinderConsoleKeyBatch"
	_console_key_batch.multimesh = multi
	_console_key_batch.material_override = source.material_override
	_console_key_batch.material_overlay = source.material_overlay
	_console_key_batch.visible = source.visible
	_console_key_batch.cast_shadow = source.cast_shadow
	_console_key_batch.layers = source.layers
	_console_key_batch.extra_cull_margin = source.extra_cull_margin
	_console_key_batch.ignore_occlusion_culling = source.ignore_occlusion_culling
	_console_key_batch.lod_bias = source.lod_bias
	_console_key_batch.visibility_range_begin = source.visibility_range_begin
	_console_key_batch.visibility_range_end = source.visibility_range_end
	_console_key_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_console_key_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_console_key_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_console_key_batch.set_meta(&"visual_detail_only", true)
	_console_key_batch.set_meta(&"authored_visual_names", PackedStringArray(CONSOLE_KEY_NAMES))
	_console_key_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for key in keys:
		key.free()
	cockpit.add_child(_console_key_batch)


## The two gold centre console keys are likewise childless, immutable visual
## dressing. They retain their authored identities/transforms on one batch;
## controls, cockpit authority, and all non-gold keys remain independently
## authored.
func _batch_console_center_keys(visual: Node3D) -> void:
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit == null:
		return
	var keys: Array[MeshInstance3D] = []
	for key_name in CONSOLE_CENTER_KEY_NAMES:
		var key := cockpit.get_node_or_null(key_name) as MeshInstance3D
		if (
			key == null
			or key.get_child_count() != 0
			or key.mesh == null
			or key.get_script() != null
			or not key.get_groups().is_empty()
			or not key.get_meta_list().is_empty()
		):
			return
		keys.append(key)
	var source := keys[0]
	var source_mesh := source.mesh
	var source_material := _renderer_material(source)
	for key in keys:
		if (
			key.mesh.get_class() != source_mesh.get_class()
			or key.mesh.get_aabb() != source_mesh.get_aabb()
			or key.mesh.get_surface_count() != source_mesh.get_surface_count()
			or _renderer_material(key) != source_material
			or key.material_overlay != source.material_overlay
			or key.visible != source.visible
			or key.cast_shadow != source.cast_shadow
			or key.layers != source.layers
			or key.extra_cull_margin != source.extra_cull_margin
			or key.ignore_occlusion_culling != source.ignore_occlusion_culling
			or key.lod_bias != source.lod_bias
			or key.visibility_range_begin != source.visibility_range_begin
			or key.visibility_range_end != source.visibility_range_end
			or key.visibility_range_begin_margin != source.visibility_range_begin_margin
			or key.visibility_range_end_margin != source.visibility_range_end_margin
			or key.visibility_range_fade_mode != source.visibility_range_fade_mode
		):
			return
	var transforms: Array[Transform3D] = []
	for key in keys:
		transforms.append(key.transform)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _encode_visual_transforms(transforms)
	multi.custom_aabb = _visual_bounds(source_mesh.get_aabb(), transforms)
	_console_center_key_batch = MultiMeshInstance3D.new()
	_console_center_key_batch.name = "CinderConsoleCenterKeyBatch"
	_console_center_key_batch.multimesh = multi
	_console_center_key_batch.material_override = source.material_override
	_console_center_key_batch.material_overlay = source.material_overlay
	_console_center_key_batch.visible = source.visible
	_console_center_key_batch.cast_shadow = source.cast_shadow
	_console_center_key_batch.layers = source.layers
	_console_center_key_batch.extra_cull_margin = source.extra_cull_margin
	_console_center_key_batch.ignore_occlusion_culling = source.ignore_occlusion_culling
	_console_center_key_batch.lod_bias = source.lod_bias
	_console_center_key_batch.visibility_range_begin = source.visibility_range_begin
	_console_center_key_batch.visibility_range_end = source.visibility_range_end
	_console_center_key_batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	_console_center_key_batch.visibility_range_end_margin = source.visibility_range_end_margin
	_console_center_key_batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	_console_center_key_batch.set_meta(&"visual_detail_only", true)
	_console_center_key_batch.set_meta(&"authored_visual_names", PackedStringArray(CONSOLE_CENTER_KEY_NAMES))
	_console_center_key_batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	for key in keys:
		key.free()
	cockpit.add_child(_console_center_key_batch)


static func _renderer_material(instance: MeshInstance3D) -> Material:
	if instance.material_override != null:
		return instance.material_override
	return instance.mesh.surface_get_material(0) if instance.mesh.get_surface_count() > 0 else null


static func _encode_visual_transforms(
	transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


static func _visual_bounds(
	mesh_bounds: AABB,
	transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	for index in transforms.size():
		var transformed := (transforms[index] * mesh_bounds).abs()
		result = transformed if index == 0 else result.merge(transformed)
	return result


func _build_boarding_marker(visual: Node3D) -> void:
	_interceptor_boarding_marker = Marker3D.new()
	_interceptor_boarding_marker.name = "BoardingMarker"
	_interceptor_boarding_marker.position = Vector3(-2.7, -0.85, 0.0)
	_interceptor_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_interceptor_boarding_marker)
