class_name StationDoor
extends Area3D

## Reusable, coordinator-agnostic station door.
##
## The Area3D root is the interaction target exposed on layer 8. A fixed portal
## blocker remains active for CLOSED, OPENING, and CLOSING so a doorway never
## becomes physically clear before its state is fully OPEN. The visible panel
## slides independently, allowing deterministic mid-motion reversal without a
## tween reset or a discontinuous transform jump.
##
## The scene remains the authority on the door's dimensions, materials and
## collision. The only geometry work done here is an edge treatment: each raw
## `BoxMesh` authored in the scene is rebuilt once, at exactly its authored size,
## with chamfered edges. This door is the closest a player ever gets to a station
## primitive — a 3.2 x 3.4 m leaf filling the screen at about a metre — and a
## hard 90 degree corner at eye level is the single loudest "untooled box" cue in
## the game. Every rebuilt mesh keeps the authored outer extents exactly, and no
## node name, node transform, collision shape or panel travel is touched here.
## (The scene itself does shorten the posts' render mesh where it was buried
## inside the header; their collision shapes are unchanged. See the note there.)

signal state_changed(previous_state: int, current_state: int)
signal motion_completed(final_state: int)
signal interaction_accepted(actor: Node, requested_open: bool)
signal interaction_refused(actor: Node, reason: StringName)
signal lock_changed(is_locked: bool)

enum DoorState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}

const WORLD_LAYER := 1
const INTERACTION_LAYER := 1 << 3

@export_category("Motion")
@export_range(0.0, 8.0, 0.01) var motion_duration := 0.8
@export var open_offset := Vector3(3.6, 0.0, 0.0)
@export var starts_open := false

@export_category("Interaction")
@export var interaction_label := "OPERATIONS ACCESS"
@export var locked_prompt := "ACCESS LOCKED"
@export var locked := false

@export_category("Deferred content")
@export var deferred_access := false
@export var deferred_label := "VIP ACCESS"
@export var deferred_prompt := "ACCESS DEFERRED"

@export_category("Evidence metadata")
@export var evidence_status: StringName = &"modern_interpretation"
@export_multiline var content_note := ""

## Every authored mesh in the scene, in the order a player meets them.
const PRESENTATION_MESH_PATHS: Array[NodePath] = [
	^"FrameVisuals/LeftPost",
	^"FrameVisuals/RightPost",
	^"FrameVisuals/Header",
	^"SlidingPanel/PanelMesh",
	^"SlidingPanel/LeftIndicator",
	^"SlidingPanel/RightIndicator",
]
const PANEL_MESH_PATH: NodePath = ^"SlidingPanel/PanelMesh"
const INDICATOR_MESH_PATHS: Array[NodePath] = [
	^"SlidingPanel/LeftIndicator",
	^"SlidingPanel/RightIndicator",
]
const INDICATOR_BATCH_NAME := &"IndicatorRenderBatch"
const FRAME_POST_MESH_PATHS: Array[NodePath] = [
	^"FrameVisuals/LeftPost",
	^"FrameVisuals/RightPost",
]
const FRAME_POST_BATCH_NAME := &"FramePostRenderBatch"
## Frozen station panel family scale used by the module shells these doors are
## set into, so a door frame and the wall it pierces share one grain size.
const PANEL_SURFACE_SCALE := 0.28
## Ceiling on the leaf's own emission. Four of the five production leaves are
## painted with a module accent that carries 1.15-1.45 emission energy, which was
## authored for 0.1 m route stripes and arc tiles. On an 11 m² leaf at a metre it
## clips to a flat white-cyan rectangle: it hides the leaf's own material
## response entirely and is the loudest "lit box" cue at the threshold. Damping
## the leaf copy keeps the access colour — albedo and emission hue are untouched,
## and the indicator strips, which are the element meant to glow, keep their full
## energy — while letting the leaf read as a surface again.
const MAXIMUM_PANEL_EMISSION_ENERGY := 0.35

@onready var _sliding_panel: Node3D = %SlidingPanel
@onready var _portal_blocker: StaticBody3D = %PortalBlocker

var _state: int = DoorState.CLOSED
var _motion_progress := 0.0
var _closed_panel_transform := Transform3D.IDENTITY
## The chamfer builder emits geometry only: every colour/finish remains on the
## individual MeshInstance3D as a material override. All production doors use
## the same four authored sizes, so keeping that immutable stock at class scope
## avoids rebuilding four ArrayMeshes for every additional door instance.
static var _shared_rounded_box_mesh_cache: Dictionary = {}
var _panel_grain_materials: Array[StandardMaterial3D] = []
var _panel_grain_scales: Array[Vector3] = []
var _ready_completed := false


func _ready() -> void:
	_apply_manufactured_edges()
	_batch_frame_post_renderers()
	_batch_indicator_renderers()
	_closed_panel_transform = _sliding_panel.transform
	_motion_progress = 1.0 if starts_open else 0.0
	_state = DoorState.OPEN if starts_open else DoorState.CLOSED
	_apply_panel_transform()
	_set_portal_blocked(_state != DoorState.OPEN)
	_update_metadata()
	# Every production host recolours this door's leaf from its own `_ready`,
	# which runs after this one, so the leaf material present here is not the one
	# the player sees. Deferring the leaf's surface binding to the end of the
	# frame keeps colour authority with the module — access colour-coding is the
	# module's language — while the finish stays with the door.
	_bind_panel_surface_family.call_deferred()
	_ready_completed = true


func _enter_tree() -> void:
	if _ready_completed:
		_bind_panel_surface_family.call_deferred()


func _physics_process(delta: float) -> void:
	if _state != DoorState.OPENING and _state != DoorState.CLOSING:
		return

	if motion_duration <= 0.0:
		_complete_motion(_state == DoorState.OPENING)
		return

	var direction := 1.0 if _state == DoorState.OPENING else -1.0
	_motion_progress = clampf(
		_motion_progress + direction * delta / motion_duration,
		0.0,
		1.0
	)
	_apply_panel_transform()
	if _state == DoorState.OPENING and is_equal_approx(_motion_progress, 1.0):
		_complete_motion(true)
	elif _state == DoorState.CLOSING and is_equal_approx(_motion_progress, 0.0):
		_complete_motion(false)


## Returns a state-aware prompt without depending on a HUD implementation.
func get_interaction_prompt() -> String:
	if not _is_interaction_current():
		return ""
	var label := _get_effective_label()
	if deferred_access:
		return "[ DEFERRED ]  %s  //  %s" % [label, deferred_prompt]
	if locked:
		return "[ LOCKED ]  %s  //  %s" % [label, locked_prompt]
	var action := "OPEN" if _state == DoorState.CLOSED or _state == DoorState.CLOSING else "CLOSE"
	return "[ E ]  %s %s" % [action, label]


## Actor is deliberately optional: access policy can be extended later without
## coupling this component to a specific player class.
func can_interact(_actor: Node = null) -> bool:
	return _is_interaction_current() and not locked and not deferred_access


## Toggles the requested destination. Interacting during motion reverses from
## the exact current progress rather than restarting from an endpoint.
func interact(actor: Node = null) -> bool:
	if not _is_interaction_current():
		return false
	if deferred_access:
		interaction_refused.emit(actor, &"deferred")
		return false
	if locked:
		interaction_refused.emit(actor, &"locked")
		return false

	var requested_open := _state == DoorState.CLOSED or _state == DoorState.CLOSING
	if not _begin_motion(requested_open):
		interaction_refused.emit(actor, &"already_at_destination")
		return false
	interaction_accepted.emit(actor, requested_open)
	return true


func _is_interaction_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_state() -> int:
	return _state


func get_state_name() -> StringName:
	match _state:
		DoorState.CLOSED:
			return &"CLOSED"
		DoorState.OPENING:
			return &"OPENING"
		DoorState.OPEN:
			return &"OPEN"
		DoorState.CLOSING:
			return &"CLOSING"
	return &"UNKNOWN"


func is_open() -> bool:
	return _state == DoorState.OPEN


func is_portal_blocked() -> bool:
	return _portal_blocker != null and _portal_blocker.collision_layer == WORLD_LAYER


func set_locked(value: bool) -> void:
	if not _is_interaction_current():
		return
	if locked == value:
		return
	locked = value
	_update_metadata()
	lock_changed.emit(locked)


func set_deferred_access(value: bool) -> void:
	if not _is_interaction_current():
		return
	if deferred_access == value:
		return
	deferred_access = value
	_update_metadata()


func _begin_motion(requested_open: bool) -> bool:
	if requested_open:
		if _state == DoorState.OPEN or _state == DoorState.OPENING:
			return false
		_set_portal_blocked(true)
		_change_state(DoorState.OPENING)
	else:
		if _state == DoorState.CLOSED or _state == DoorState.CLOSING:
			return false
		# Closing blocks immediately; OPEN is the only clear state.
		_set_portal_blocked(true)
		_change_state(DoorState.CLOSING)

	if motion_duration <= 0.0:
		_complete_motion(requested_open)
	return true


func _complete_motion(opened: bool) -> void:
	_motion_progress = 1.0 if opened else 0.0
	_apply_panel_transform()
	var final_state := DoorState.OPEN if opened else DoorState.CLOSED
	var previous_state := _state
	_state = final_state
	# Publish a coherent state: listeners observing OPEN also see a clear portal.
	_set_portal_blocked(not opened)
	state_changed.emit(previous_state, _state)
	motion_completed.emit(_state)


func _change_state(next_state: int) -> void:
	if _state == next_state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)


func _apply_panel_transform() -> void:
	# Smoothstep supplies gentle acceleration while remaining a pure function of
	# progress, so reversing direction cannot introduce a positional discontinuity.
	var eased_progress := _motion_progress * _motion_progress * (3.0 - 2.0 * _motion_progress)
	var panel_transform := _closed_panel_transform
	var local_travel := open_offset * eased_progress
	panel_transform.origin = _closed_panel_transform.origin + local_travel
	_sliding_panel.transform = panel_transform
	_pin_panel_grain(local_travel)


## The station panel family samples world position, which is exactly right for
## fixed structure and exactly wrong for the one part that moves: an uncorrected
## leaf drags a full tile of grain across its own face during its 3.6 m travel.
## Cancelling the travel out of the UV phase keeps the grain welded to the leaf
## while every static surface keeps the shared world-metric phase.
func _pin_panel_grain(local_travel: Vector3) -> void:
	# A deferred panel-family bind can still be unwinding while an ancestor tears
	# this door out of the world. Do not sample a world transform or advance the
	# leaf's UV phase unless this is the current live door.
	if is_queued_for_deletion() or not is_inside_tree() or _panel_grain_materials.is_empty():
		return
	var world_travel := global_transform.basis * local_travel
	for material_index in _panel_grain_materials.size():
		var scale_value := _panel_grain_scales[material_index]
		_panel_grain_materials[material_index].uv1_offset = Vector3(
			-world_travel.x * scale_value.x,
			-world_travel.y * scale_value.y,
			-world_travel.z * scale_value.z
		)


## Rebuilds every authored `BoxMesh` at its exact authored size with chamfered
## edges. The scene keeps ownership of dimensions, materials and collision: this
## reads the authored size back out and never writes one.
func _apply_manufactured_edges() -> void:
	for mesh_path in PRESENTATION_MESH_PATHS:
		var mesh_instance := get_node_or_null(mesh_path) as MeshInstance3D
		if mesh_instance == null:
			continue
		var authored_box := mesh_instance.mesh as BoxMesh
		if authored_box == null:
			continue
		# An ArrayMesh carries no surface material of its own, so the authored
		# material moves onto the instance as the mesh is replaced.
		mesh_instance.material_override = authored_box.material
		mesh_instance.mesh = StationSurfaceKit.rounded_box_mesh_cached(
			authored_box.size,
			_shared_rounded_box_mesh_cache
		)


## The two static frame posts are identical visual-only stock under the same
## parent. Their authored mesh paths remain addressable, and their separate
## collision shapes under FrameBody retain full authority over door physics.
func _batch_frame_post_renderers() -> void:
	var frame_visuals := get_node_or_null(^"FrameVisuals") as Node3D
	if frame_visuals == null:
		return
	var sources: Array[MeshInstance3D] = []
	for source_path in FRAME_POST_MESH_PATHS:
		var source := get_node_or_null(source_path) as MeshInstance3D
		if source == null or source.mesh == null or source.get_parent() != frame_visuals:
			return
		sources.append(source)
	var reference := sources[0]
	for source in sources:
		if source.mesh != reference.mesh \
				or source.material_override != reference.material_override \
				or source.cast_shadow != reference.cast_shadow \
				or source.layers != reference.layers \
				or not is_equal_approx(source.extra_cull_margin, reference.extra_cull_margin) \
				or source.ignore_occlusion_culling != reference.ignore_occlusion_culling \
				or source.gi_mode != reference.gi_mode \
				or source.visibility_range_begin != reference.visibility_range_begin \
				or source.visibility_range_end != reference.visibility_range_end \
				or source.visibility_range_begin_margin != reference.visibility_range_begin_margin \
				or source.visibility_range_end_margin != reference.visibility_range_end_margin \
				or source.visibility_range_fade_mode != reference.visibility_range_fade_mode:
			return

	var transforms: Array[Transform3D] = []
	var bounds := AABB()
	var mesh_bounds := reference.mesh.get_aabb()
	for source_index in sources.size():
		var source_transform := sources[source_index].transform
		transforms.append(source_transform)
		var source_bounds := (source_transform * mesh_bounds).abs()
		bounds = source_bounds if source_index == 0 else bounds.merge(source_bounds)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = reference.mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = -1
	for transform_index in transforms.size():
		multi.set_instance_transform(transform_index, transforms[transform_index])
	multi.custom_aabb = bounds

	var batch := MultiMeshInstance3D.new()
	batch.name = FRAME_POST_BATCH_NAME
	batch.multimesh = multi
	batch.material_override = reference.material_override
	batch.cast_shadow = reference.cast_shadow
	batch.layers = reference.layers
	batch.extra_cull_margin = reference.extra_cull_margin
	batch.ignore_occlusion_culling = reference.ignore_occlusion_culling
	batch.gi_mode = reference.gi_mode
	batch.visibility_range_begin = reference.visibility_range_begin
	batch.visibility_range_end = reference.visibility_range_end
	batch.visibility_range_begin_margin = reference.visibility_range_begin_margin
	batch.visibility_range_end_margin = reference.visibility_range_end_margin
	batch.visibility_range_fade_mode = reference.visibility_range_fade_mode
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"authored_visual_paths", FRAME_POST_MESH_PATHS.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	frame_visuals.add_child(batch)
	for source in sources:
		# Preserve the authored semantic nodes while suppressing only their
		# duplicate renderer submissions.
		source.layers = 0


## The two indicator strips are identical visual-only stock under the same
## moving parent. Keep their authored nodes as stable semantic paths, but submit
## their exact local transforms through one tightly bounded renderer instance.
func _batch_indicator_renderers() -> void:
	var sources: Array[MeshInstance3D] = []
	for source_path in INDICATOR_MESH_PATHS:
		var source := get_node_or_null(source_path) as MeshInstance3D
		if source == null or source.mesh == null or source.get_parent() != _sliding_panel:
			return
		sources.append(source)
	var reference := sources[0]
	for source in sources:
		if source.mesh != reference.mesh \
				or source.material_override != reference.material_override \
				or source.cast_shadow != reference.cast_shadow \
				or source.layers != reference.layers \
				or not is_equal_approx(source.extra_cull_margin, reference.extra_cull_margin) \
				or source.ignore_occlusion_culling != reference.ignore_occlusion_culling \
				or source.gi_mode != reference.gi_mode \
				or source.visibility_range_begin != reference.visibility_range_begin \
				or source.visibility_range_end != reference.visibility_range_end \
				or source.visibility_range_begin_margin != reference.visibility_range_begin_margin \
				or source.visibility_range_end_margin != reference.visibility_range_end_margin \
				or source.visibility_range_fade_mode != reference.visibility_range_fade_mode:
			return

	var transforms: Array[Transform3D] = []
	var bounds := AABB()
	var mesh_bounds := reference.mesh.get_aabb()
	for source_index in sources.size():
		var source_transform := sources[source_index].transform
		transforms.append(source_transform)
		var source_bounds := (source_transform * mesh_bounds).abs()
		bounds = source_bounds if source_index == 0 else bounds.merge(source_bounds)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = reference.mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = -1
	for transform_index in transforms.size():
		multi.set_instance_transform(transform_index, transforms[transform_index])
	multi.custom_aabb = bounds

	var batch := MultiMeshInstance3D.new()
	batch.name = INDICATOR_BATCH_NAME
	batch.multimesh = multi
	batch.material_override = reference.material_override
	batch.cast_shadow = reference.cast_shadow
	batch.layers = reference.layers
	batch.extra_cull_margin = reference.extra_cull_margin
	batch.ignore_occlusion_culling = reference.ignore_occlusion_culling
	batch.gi_mode = reference.gi_mode
	batch.visibility_range_begin = reference.visibility_range_begin
	batch.visibility_range_end = reference.visibility_range_end
	batch.visibility_range_begin_margin = reference.visibility_range_begin_margin
	batch.visibility_range_end_margin = reference.visibility_range_end_margin
	batch.visibility_range_fade_mode = reference.visibility_range_fade_mode
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"authored_visual_paths", INDICATOR_MESH_PATHS.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	_sliding_panel.add_child(batch)
	for source in sources:
		# The authored nodes remain visible and addressable; an empty renderer-layer
		# mask suppresses only their duplicate submissions.
		source.layers = 0


## Binds the station panel family onto whichever leaf material survived host
## styling, on a copy so a module accent shared with fixtures elsewhere in the
## module never acquires a door's finish, and so each door owns the UV phase it
## has to correct while it moves.
func _bind_panel_surface_family() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	var panel_mesh := get_node_or_null(PANEL_MESH_PATH) as MeshInstance3D
	if panel_mesh == null:
		return
	var live_material := panel_mesh.material_override as StandardMaterial3D
	if live_material == null:
		return
	var leaf_material := live_material.duplicate() as StandardMaterial3D
	StationSurfaceKit.apply_panel_triplanar(leaf_material, PANEL_SURFACE_SCALE)
	if leaf_material.emission_enabled:
		leaf_material.emission_energy_multiplier = minf(
			leaf_material.emission_energy_multiplier,
			MAXIMUM_PANEL_EMISSION_ENERGY
		)
	panel_mesh.material_override = leaf_material
	_refresh_panel_grain_materials()
	_apply_panel_transform()


## Collects the world-triplanar materials that travel with the leaf, so their UV
## phase can be corrected for the leaf's own motion.
func _refresh_panel_grain_materials() -> void:
	_panel_grain_materials.clear()
	_panel_grain_scales.clear()
	if _sliding_panel == null:
		return
	for candidate in _sliding_panel.find_children("*", "MeshInstance3D", true, false):
		var material := (candidate as MeshInstance3D).material_override as StandardMaterial3D
		if material == null or not material.uv1_world_triplanar:
			continue
		if _panel_grain_materials.has(material):
			continue
		_panel_grain_materials.append(material)
		_panel_grain_scales.append(material.uv1_scale)


func _set_portal_blocked(blocked: bool) -> void:
	if _portal_blocker == null:
		return
	_portal_blocker.collision_layer = WORLD_LAYER if blocked else 0
	_portal_blocker.collision_mask = 0


func _get_effective_label() -> String:
	if deferred_access and not deferred_label.strip_edges().is_empty():
		return deferred_label.strip_edges()
	var cleaned_label := interaction_label.strip_edges()
	return cleaned_label if not cleaned_label.is_empty() else "STATION DOOR"


func _update_metadata() -> void:
	set_meta("station_interactable", true)
	set_meta("station_door", true)
	set_meta("interaction_layer", INTERACTION_LAYER)
	set_meta("access_label", _get_effective_label())
	set_meta("locked", locked)
	set_meta("deferred_access", deferred_access)
	set_meta("evidence_status", evidence_status)
	set_meta("content_note", content_note)
