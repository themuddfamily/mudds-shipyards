class_name ShipBerthFeedback
extends Node3D

## Modern, non-authoritative visual feedback for one physical ShipBerth.
##
## The direct parent remains the sole reservation/occupancy authority. This
## component only renders that existing state and deliberately owns no collision,
## navigation, audio, timers, tweens, particles, or random behaviour.
##
## Colour-vision readability. Lease state used to be signalled by colour alone,
## in cyan / amber / green. Measured with `tests/fleet_colour_metrics.gd` (the one
## shared sRGB -> Viénot -> CIE L*a*b* -> CIEDE2000 chain), the released/occupied
## pair scored only 27.72 in normal vision, 22.63 under protanopia, 18.38 under
## deuteranopia and **2.77 under tritanopia** — at or below the practical
## just-noticeable difference, so a tritanope could not tell an open berth from an
## occupied one at all, and a deuteranope could not reliably separate approach
## from occupied. Two things changed, both frozen by
## `tests/ship_berth_feedback_test.gd`:
##
## 1. The cue triad moved onto a lightness ladder as well as a hue ladder, since
##    lightness is the one channel every dichromacy model preserves. Pale cyan
##    (L* 90) / orange (L* 66) / blue (L* 40) now measure at worst 41.94 across
##    all four vision models.
## 2. A second, non-colour channel was added: a deck glyph whose *shape* encodes
##    the state — a broken gate for released, a chevron for approach, one solid
##    unbroken bar for secured. It is static geometry, not motion, so it degrades
##    gracefully under the reduced-motion accessibility preset and it survives a
##    fully desaturated frame.
##
## The palette is safe by default rather than gated behind
## `RuntimeSettings.colorblind_palette`. An accessibility option a player has to
## discover helps fewer people than a design that works unconfigured, and gating
## it would give this deliberately dependency-free presentation component a live
## settings dependency it does not otherwise have. The HUD presets in
## `scripts/ui/hud_palette.gd` remain the right mechanism for the HUD, whose
## authored set has other constraints; nothing here reads or overrides them.

signal state_changed(state: StringName)

const ShipBerthAudioBindingType := preload("res://scripts/audio/ship_berth_audio_binding.gd")

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"ship_berth_feedback"
const STATE_RELEASED: StringName = &"released"
const STATE_APPROACH: StringName = &"approach"
const STATE_OCCUPIED: StringName = &"occupied"
const VALID_STATES := [STATE_RELEASED, STATE_APPROACH, STATE_OCCUPIED]
# Re-frozen 11 -> 16: the five added meshes are the shape-coded state glyph (two
# gate marks, two chevron arms, one secured bar), which is the non-colour channel
# described above. The later performance seam below changes only retained
# material resources; the mesh/submission budget and zero-authority prohibitions
# remain unchanged.
const MESH_COUNT := 16
const MESH_RESOURCE_COUNT_BEFORE_SHARING := 16
const MESH_RESOURCE_COUNT_BEFORE_UNIT_SCALING := 7
const MESH_RESOURCE_COUNT := 1
const MESH_RESOURCE_COPY_ROSTER := [16]
const MATERIAL_RESOURCE_COUNT_BEFORE_STATE_SHARING := 4
const MATERIAL_COUNT := 2
const RENDER_MIN_Y := 0.14
const RENDER_MAX_Y := 0.22

## Stable IDs for the shape channel, published in the state snapshot so an audit
## can prove the non-colour cue exists and differs per state without inspecting
## geometry.
const GLYPH_GATE_OPEN: StringName = &"gate_open"
const GLYPH_APPROACH_CHEVRON: StringName = &"approach_chevron"
const GLYPH_SECURED_BAR: StringName = &"secured_bar"
const GLYPH_NONE: StringName = &""

# Authored cue palette. Re-frozen openly; old -> new, with the reason recorded in
# the class header and the measured separations frozen in the test suite.
#   released albedo   Color(0.08,  0.38,  0.44 ) -> #57848c
#   released emission Color(0.20,  0.94,  1.0  ) -> #9ff0ff   (energy 1.15, unchanged)
#   approach albedo   Color(0.40,  0.23,  0.055) -> #8c4304
#   approach emission Color(1.0,   0.55,  0.12 ) -> #ff7a08   (energy 1.25 -> 1.30)
#   occupied albedo   Color(0.075, 0.30,  0.22 ) -> #1a2d70
#   occupied emission Color(0.28,  1.0,   0.65 ) -> #2f52cc   (energy 1.00 -> 1.45)
#   inactive albedo   Color(0.055, 0.10,  0.12 ) -> #12141a
#   inactive emission Color(0.08,  0.22,  0.25 ) -> #2a2d36   (energy 0.18, unchanged)
# The occupied emission is the one that carries the semantic cost: "secured" used
# to be green. Green cannot be held apart from the released cyan by anyone with a
# tritan deficiency, and the released cue must stay the bright inviting one, so
# secured moved to the far end of the lightness ladder instead. Its emission
# energy rose to 1.45 so the darker authored blue still reads as a lit deck cue;
# even after the shader clips that product the triad still measures 31.23 at
# worst across the four vision models. The inactive boundary tone was neutralised
# off teal so a dimmed boundary can never be misread as the released cue.
const ALBEDO_RELEASED := Color("57848c")
const ALBEDO_APPROACH := Color("8c4304")
const ALBEDO_OCCUPIED := Color("1a2d70")
const ALBEDO_INACTIVE := Color("12141a")
const EMISSION_RELEASED := Color("9ff0ff")
const EMISSION_APPROACH := Color("ff7a08")
const EMISSION_OCCUPIED := Color("2f52cc")
const EMISSION_INACTIVE := Color("2a2d36")
const EMISSION_ENERGY_RELEASED := 1.15
const EMISSION_ENERGY_APPROACH := 1.30
const EMISSION_ENERGY_OCCUPIED := 1.45
const EMISSION_ENERGY_INACTIVE := 0.18

# Label tint. Re-frozen from Color(0.45,0.95,1.0)/Color(1.0,0.68,0.22)/
# Color(0.42,1.0,0.72): the old label triad measured 1.46 under tritanopia, the
# single worst number in the component. Every replacement stays bright because
# the label is read against the deck through a 10 px outline.
const LABEL_RELEASED := Color("c8f7ff")
const LABEL_APPROACH := Color("ffa02a")
const LABEL_OCCUPIED := Color("6f88ee")

@export_range(1.5, 40.0, 0.1) var cue_half_width := 8.2
@export_range(1.5, 50.0, 0.1) var cue_half_length := 12.5
@export var starts_auto_advance := true

var _berth: ShipBerth
var _visual_root: Node3D
var _label: Label3D
var _meshes: Array[MeshInstance3D] = []
var _boundary_meshes: Array[MeshInstance3D] = []
var _guide_meshes: Array[MeshInstance3D] = []
var _status_meshes: Array[MeshInstance3D] = []
var _glyph_meshes: Array[MeshInstance3D] = []
var _glyph_mesh_states: Array[StringName] = []
var _materials: Dictionary = {}
var _shared_box_mesh: BoxMesh
var _material_instance_ids: Dictionary = {}
var _material_contracts: Dictionary = {}
var _mesh_contracts: Dictionary = {}
var _owned_child_instance_ids: Dictionary = {}
var _base_guide_transforms: Array[Transform3D] = []
var _built_component_transform := Transform3D.IDENTITY
var _built_component_storage_contract: Dictionary = {}
var _built_cue_half_width := 0.0
var _built_cue_half_length := 0.0
var _visual_root_instance_id := 0
var _visual_root_storage_contract: Dictionary = {}
var _label_instance_id := 0
var _label_transform := Transform3D.IDENTITY
var _label_storage_contract: Dictionary = {}
var _state: StringName = STATE_RELEASED
var _elapsed := 0.0
var _feedback_enabled := true
var _feedback_paused := false
var _auto_advance := true
var _built := false
var _emitting_state := false
var _pending_state: StringName = &""
var _audio_binding: RefCounted


func _enter_tree() -> void:
	add_to_group(&"ship_berth_feedback")
	if _built:
		_bind_berth()
		_bind_audio()
		_reconcile_state(true)
		_refresh_processing()


func _ready() -> void:
	if _built:
		return
	_auto_advance = starts_auto_advance
	_built_component_transform = transform
	_built_component_storage_contract = _storage_property_snapshot(
		self,
		PackedStringArray([
			"transform", "visible", "cue_half_width", "cue_half_length", "starts_auto_advance"
		])
	)
	_built_cue_half_width = cue_half_width
	_built_cue_half_length = cue_half_length
	_build_presentation()
	_capture_integrity_contract()
	_built = true
	_bind_berth()
	_bind_audio()
	_reconcile_state(true)
	_refresh_processing()


func _exit_tree() -> void:
	_unbind_audio()
	_unbind_berth()
	set_process(false)


func _process(delta: float) -> void:
	_reconcile_state(false)
	if _feedback_enabled and not _feedback_paused and _auto_advance:
		advance_simulation(delta)


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_feedback_state() -> StringName:
	_reconcile_state(false)
	return _state

func get_audio_binding() -> RefCounted:
	return _audio_binding


func _can_mutate_feedback() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func set_feedback_enabled(enabled: bool) -> void:
	if not _can_mutate_feedback():
		return
	_feedback_enabled = enabled
	visible = enabled
	if is_instance_valid(_visual_root):
		_visual_root.visible = enabled
	if is_instance_valid(_label):
		_label.visible = enabled
	_refresh_processing()


func is_feedback_enabled() -> bool:
	return _feedback_enabled


func set_feedback_paused(paused: bool) -> void:
	if not _can_mutate_feedback():
		return
	_feedback_paused = paused
	_refresh_processing()


func is_feedback_paused() -> bool:
	return _feedback_paused


func set_auto_advance_enabled(enabled: bool) -> void:
	if not _can_mutate_feedback():
		return
	_auto_advance = enabled
	_refresh_processing()


func is_auto_advance_enabled() -> bool:
	return _auto_advance


func advance_simulation(delta: float) -> void:
	if not _can_mutate_feedback():
		return
	_reconcile_state(false)
	if not is_finite(delta) or delta < 0.0 or not _feedback_enabled or _feedback_paused:
		return
	_elapsed += delta
	_apply_animation()


func seek_simulation(time_seconds: float) -> void:
	if not _can_mutate_feedback():
		return
	if not is_finite(time_seconds) or time_seconds < 0.0:
		return
	_elapsed = time_seconds
	_apply_animation()


func get_state_snapshot() -> Dictionary:
	_reconcile_state(false)
	var owner := _berth.get_reservation_owner() if is_instance_valid(_berth) else null
	var occupant := _berth.get_occupant() if is_instance_valid(_berth) else null
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"state": _state,
		"berth_id": _berth.get_berth_id() if is_instance_valid(_berth) else &"",
		"reservation_owner_instance_id": owner.get_instance_id() if is_instance_valid(owner) else 0,
		"occupant_instance_id": occupant.get_instance_id() if is_instance_valid(occupant) else 0,
		"elapsed": _elapsed,
		"phase": fposmod(_elapsed, 1.0),
		"enabled": _feedback_enabled,
		"paused": _feedback_paused,
		"auto_advance": _auto_advance,
		"label": _label.text if is_instance_valid(_label) else "",
		# The non-colour channel, published so an audit can prove it exists and
		# differs per state without reaching into the geometry itself.
		"cue_glyph": get_state_glyph_id(_state),
		"cue_glyph_mesh_names": _visible_glyph_mesh_names(),
		"cue_glyph_footprint": _visible_glyph_footprint(),
	}.duplicate(true)


## Names of the glyph meshes rendered in the live state, sorted so the value is a
## stable signature rather than a build-order artefact.
func _visible_glyph_mesh_names() -> PackedStringArray:
	var names := PackedStringArray()
	for index in _glyph_meshes.size():
		var glyph := _glyph_meshes[index]
		if is_instance_valid(glyph) and _glyph_mesh_states[index] == _state:
			names.append(String(glyph.name))
	names.sort()
	return names


## Deck area the live state's glyph covers, in square metres. Ink coverage is the
## part of the shape channel that survives distance and desaturation, so it is
## published as evidence rather than left implicit in the mesh sizes.
func _visible_glyph_footprint() -> float:
	var area := 0.0
	for index in _glyph_meshes.size():
		var glyph := _glyph_meshes[index]
		if not is_instance_valid(glyph) or _glyph_mesh_states[index] != _state:
			continue
		if glyph.mesh is BoxMesh:
			# Every cue uses the component's unit box; its node scale retains the
			# authored dimensions without allocating another mesh resource.
			area += absf(glyph.scale.x * glyph.scale.z)
	return area


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": 1,
		"evidence_status": &"modern_interpretation",
		"historically_supported": false,
		"authenticated_original_docking_feedback": false,
		"presentation_only": true,
		"authority_owner": &"direct_parent_ship_berth",
		"claim_scope": &"modern_lease_state_visualization",
	}.duplicate(true)


func get_performance_report() -> Dictionary:
	var visible_meshes := 0
	var live_meshes := find_children("*", "MeshInstance3D", true, false)
	var live_labels := find_children("*", "Label3D", true, false)
	var mesh_resource_copy_counts: Dictionary = {}
	for mesh in live_meshes:
		if not is_instance_valid(mesh):
			continue
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.is_visible_in_tree():
			visible_meshes += 1
		if mesh_instance.mesh != null:
			var mesh_id := mesh_instance.mesh.get_instance_id()
			mesh_resource_copy_counts[mesh_id] = int(
				mesh_resource_copy_counts.get(mesh_id, 0)
			) + 1
	var mesh_resource_copy_roster: Array[int] = []
	for copy_count in mesh_resource_copy_counts.values():
		mesh_resource_copy_roster.append(int(copy_count))
	mesh_resource_copy_roster.sort()
	var mesh_sharing_exact := (
		mesh_resource_copy_counts.size() == MESH_RESOURCE_COUNT
		and mesh_resource_copy_roster == MESH_RESOURCE_COPY_ROSTER
		and is_instance_valid(_shared_box_mesh)
		and mesh_resource_copy_counts.has(_shared_box_mesh.get_instance_id())
	)
	var owned_node_count := 1 + find_children("*", "", true, false).size()
	return {
		"schema_version": 1,
		"within_budget": (
			live_meshes.size() == MESH_COUNT
			and _materials.size() == MATERIAL_COUNT
			and mesh_sharing_exact
		),
		"owned_nodes": owned_node_count,
		"mesh_instances": live_meshes.size(),
		"drawn_copies": live_meshes.size(),
		"render_submissions": live_meshes.size(),
		"visible_submissions": visible_meshes,
		"visible_meshes": visible_meshes,
		"mesh_budget": MESH_COUNT,
		"mesh_resources_before_sharing": MESH_RESOURCE_COUNT_BEFORE_SHARING,
		"mesh_resources_before_unit_scaling": MESH_RESOURCE_COUNT_BEFORE_UNIT_SCALING,
		"mesh_resources": mesh_resource_copy_counts.size(),
		"mesh_resource_budget": MESH_RESOURCE_COUNT,
		"mesh_resource_savings": (
			MESH_RESOURCE_COUNT_BEFORE_SHARING - mesh_resource_copy_counts.size()
		),
		"mesh_resource_unit_scaling_savings": (
			MESH_RESOURCE_COUNT_BEFORE_UNIT_SCALING - mesh_resource_copy_counts.size()
		),
		"mesh_resource_copy_roster": mesh_resource_copy_roster,
		"mesh_sharing_exact": mesh_sharing_exact,
		"mesh_sharing_policy": &"component_local_unit_box_mesh",
		"material_resources": _materials.size(),
		"material_resources_before_state_sharing": MATERIAL_RESOURCE_COUNT_BEFORE_STATE_SHARING,
		"material_resource_savings": MATERIAL_RESOURCE_COUNT_BEFORE_STATE_SHARING - _materials.size(),
		"material_sharing_policy": &"component_local_state_material",
		"material_budget": MATERIAL_COUNT,
		"labels": live_labels.size(),
		"collision_nodes": find_children("*", "CollisionObject3D", true, false).size(),
		"physics_query_nodes": find_children("*", "RayCast3D", true, false).size() \
			+ find_children("*", "ShapeCast3D", true, false).size(),
		"lights": find_children("*", "Light3D", true, false).size(),
		"audio_nodes": find_children("*", "AudioStreamPlayer3D", true, false).size(),
		"particle_emitters": find_children("*", "GPUParticles3D", true, false).size() \
			+ find_children("*", "CPUParticles3D", true, false).size(),
		"timers": find_children("*", "Timer", true, false).size(),
		"tweens_owned": 0,
		"runtime_node_allocation": false,
		"runtime_resource_allocation": false,
		"deterministic_manual_clock": true,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	_reconcile_state(false)
	var errors := PackedStringArray()
	if not _built:
		errors.append("presentation_not_built")
	if not is_instance_valid(_berth) or get_parent() != _berth:
		errors.append("direct_parent_ship_berth_missing")
	if not transform.is_equal_approx(_built_component_transform):
		errors.append("component_transform_changed_after_build")
	if not _storage_properties_match(
		self,
		_built_component_storage_contract,
		PackedStringArray([
			"transform", "visible", "cue_half_width", "cue_half_length", "starts_auto_advance"
		])
	):
		errors.append("component_node_contract_changed")
	if not is_finite(cue_half_width) or cue_half_width < 1.5:
		errors.append("cue_half_width_invalid")
	elif not is_equal_approx(cue_half_width, _built_cue_half_width):
		errors.append("cue_half_width_changed_after_build")
	if not is_finite(cue_half_length) or cue_half_length < 1.5:
		errors.append("cue_half_length_invalid")
	elif not is_equal_approx(cue_half_length, _built_cue_half_length):
		errors.append("cue_half_length_changed_after_build")
	if not VALID_STATES.has(_state):
		errors.append("feedback_state_invalid")
	var live_meshes := find_children("*", "MeshInstance3D", true, false)
	var live_labels := find_children("*", "Label3D", true, false)
	var live_visuals := find_children("*", "VisualInstance3D", true, false)
	var live_descendants := find_children("*", "", true, false)
	if _meshes.size() != MESH_COUNT or live_meshes.size() != MESH_COUNT:
		errors.append("mesh_count_changed")
	if live_labels.size() != 1 or live_visuals.size() != MESH_COUNT + 1:
		errors.append("visual_descendant_count_changed")
	# One owned Node3D root plus eleven meshes and one Label3D.
	if live_descendants.size() != MESH_COUNT + 2:
		errors.append("node_hierarchy_count_changed")
	if _materials.size() != MATERIAL_COUNT:
		errors.append("material_count_changed")
	for material_id: StringName in _materials:
		var material := _materials.get(material_id) as StandardMaterial3D
		if not is_instance_valid(material) \
				or material.get_instance_id() != int(_material_instance_ids.get(material_id, 0)):
			errors.append("material_identity_changed_%s" % material_id)
		elif not _material_matches_contract(
			material,
			_material_contracts.get(material_id, {}) as Dictionary,
			material_id
		):
			errors.append("material_content_changed_%s" % material_id)
	if not is_instance_valid(_visual_root) \
			or _visual_root.get_instance_id() != _visual_root_instance_id \
			or get_node_or_null("FeedbackVisual") != _visual_root \
			or _visual_root.get_parent() != self \
			or not _visual_root.transform.is_equal_approx(Transform3D.IDENTITY) \
			or not _storage_properties_match(
				_visual_root,
				_visual_root_storage_contract,
				PackedStringArray(["transform", "visible"])
			):
		errors.append("visual_root_identity_or_transform_changed")
	elif not _owned_children_match_live_hierarchy():
		errors.append("visual_hierarchy_changed")
	for mesh in _meshes:
		if not is_instance_valid(mesh) \
				or not is_instance_valid(_visual_root) \
				or not _visual_root.is_ancestor_of(mesh):
			errors.append("owned_mesh_detached")
			continue
		var mesh_contract := _mesh_contracts.get(mesh.get_instance_id(), {}) as Dictionary
		if mesh_contract.is_empty() or not _mesh_matches_contract(mesh, mesh_contract):
			errors.append("owned_mesh_contract_changed_%s" % mesh.name)
	if not _label_matches_contract():
		errors.append("label_contract_changed")
	var performance := get_performance_report()
	if not bool(performance.get("mesh_sharing_exact", false)):
		errors.append("mesh_resource_sharing_contract_changed")
	for key in ["collision_nodes", "physics_query_nodes", "lights", "audio_nodes", "particle_emitters", "timers"]:
		if int(performance.get(key, 0)) != 0:
			errors.append("prohibited_%s_present" % key)
	var expected_state := _derive_state()
	if _state != expected_state:
		errors.append("rendered_state_diverges_from_berth")
	if visible != _feedback_enabled \
			or (is_instance_valid(_visual_root) and _visual_root.visible != _feedback_enabled):
		errors.append("enabled_visibility_diverged")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_id": COMPONENT_ID,
		"state": _state,
		"berth_id": _berth.get_berth_id() if is_instance_valid(_berth) else &"",
		"evidence": get_evidence_metadata(),
		"performance": performance,
		"material_instance_ids": _material_instance_ids.duplicate(true),
		"render_local_aabb": _compute_live_render_aabb(),
	}.duplicate(true)


func _build_presentation() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "FeedbackVisual"
	_visual_root.set_meta(&"presentation_only", true)
	_visual_root.set_meta(&"evidence_status", &"modern_interpretation")
	add_child(_visual_root)
	_build_materials()

	var edge_length := maxf(0.9, minf(cue_half_width * 0.42, 3.2))
	var edge_depth := maxf(0.9, minf(cue_half_length * 0.16, 2.4))
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var boundary := _add_box(
				"Boundary_%s_%s" % ["Port" if side < 0.0 else "Starboard", "Forward" if end < 0.0 else "Aft"],
				Vector3(side * (cue_half_width - edge_length * 0.5), 0.18, end * (cue_half_length - 0.18)),
				Vector3(edge_length, 0.08, 0.16),
				_materials.active
			)
			_boundary_meshes.append(boundary)

	for index in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var row := -1.0 if index < 2 else 1.0
		var guide := _add_box(
			"ApproachGuide%02d" % (index + 1),
			Vector3(side * cue_half_width * 0.38, 0.18, row * cue_half_length * 0.33),
			Vector3(minf(1.25, cue_half_width * 0.18), 0.08, 0.18),
			_materials.active
		)
		guide.rotation.y = deg_to_rad(-28.0 * side * row)
		_guide_meshes.append(guide)
		_base_guide_transforms.append(guide.transform)

	var center := _add_box(
		"LeaseStatePlate",
		Vector3(0.0, 0.18, 0.0),
		Vector3(minf(2.4, cue_half_width * 0.32), 0.08, minf(0.72, cue_half_length * 0.08)),
		_materials.active
	)
	_status_meshes.append(center)
	for side in [-1.0, 1.0]:
		var status := _add_box(
			"Status_%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(side * cue_half_width * 0.72, 0.18, 0.0),
			Vector3(minf(0.65, cue_half_width * 0.09), 0.08, minf(1.4, cue_half_length * 0.12)),
			_materials.active
		)
		_status_meshes.append(status)

	_build_state_glyph()

	_label = Label3D.new()
	_label.name = "LeaseStateLabel"
	_label.position = Vector3(0.0, 0.34, -minf(2.2, cue_half_length * 0.18))
	_label.rotation_degrees.x = -90.0
	_label.font_size = 48
	_label.pixel_size = 0.004
	_label.outline_size = 10
	_label.modulate = LABEL_RELEASED
	_label.no_depth_test = false
	# The label faces deck-up only. A one-sided face avoids mirrored text when a
	# camera looks back through the station lattice from below the berth.
	_label.double_sided = false
	_label.text = "BERTH OPEN"
	_label.set_meta(&"presentation_only", true)
	_visual_root.add_child(_label)
	_apply_visual_state()


## Builds the shape channel: one deck glyph per lease state, of which exactly one
## is ever visible. Shape, not colour, carries the distinction — two separated
## gate marks for an open berth, a chevron pointing down the approach for a
## reserved one, and a single unbroken bar for a secured one. Ink coverage rises
## monotonically across the three, so the states remain separable in a fully
## desaturated frame and at a distance where the Label3D copy is unreadable.
##
## This is static geometry with no clock of its own, so it is unaffected by the
## reduced-motion preset; the only animated element in the component remains the
## approach guides, which were already a state-exclusive channel.
func _build_state_glyph() -> void:
	var half_span := maxf(0.55, minf(3.4, cue_half_width * 0.42))
	# Placed across the forward mouth of the berth rather than at its centre. The
	# first render put the glyph beside the lease plate, where a parked hull
	# occluded most of it and the two elements read as one smudge; at the mouth it
	# is unobstructed in every state and it is where a gate/chevron/barrier
	# metaphor belongs. It stays well inside the boundary rectangle, so the
	# component's render AABB — which the evidence camera frames on — is unchanged.
	var glyph_z := -cue_half_length * 0.62
	var bar_depth := 0.34

	# Released: two lateral marks with a wide open gap between them.
	var gate_length := half_span * 0.55
	for side in [-1.0, 1.0]:
		var gate := _add_box(
			"GlyphGate%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(side * (half_span - gate_length * 0.5), 0.18, glyph_z),
			Vector3(gate_length, 0.08, bar_depth),
			_materials.active
		)
		_register_glyph(gate, STATE_RELEASED)

	# Approach: a chevron whose apex points forward, down the approach axis.
	var arm_length := half_span * 0.9
	var arm_angle := deg_to_rad(32.0)
	for side in [-1.0, 1.0]:
		var arm := _add_box(
			"GlyphChevron%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(side * arm_length * cos(arm_angle) * 0.5, 0.18, glyph_z),
			Vector3(arm_length, 0.08, bar_depth),
			_materials.active
		)
		arm.rotation.y = -side * arm_angle
		_register_glyph(arm, STATE_APPROACH)

	# Occupied: one solid unbroken bar closing the same mouth the gate left open.
	var secured := _add_box(
		"GlyphSecuredBar",
		Vector3(0.0, 0.18, glyph_z),
		Vector3(half_span * 2.0, 0.08, bar_depth * 1.55),
		_materials.active
	)
	_register_glyph(secured, STATE_OCCUPIED)


func _register_glyph(mesh: MeshInstance3D, state: StringName) -> void:
	_glyph_meshes.append(mesh)
	_glyph_mesh_states.append(state)


## Stable ID of the shape shown for `state`. Published in the state snapshot so a
## test can prove the non-colour channel exists and differs per state.
static func get_state_glyph_id(state: StringName) -> StringName:
	if state == STATE_APPROACH:
		return GLYPH_APPROACH_CHEVRON
	if state == STATE_OCCUPIED:
		return GLYPH_SECURED_BAR
	if state == STATE_RELEASED:
		return GLYPH_GATE_OPEN
	return GLYPH_NONE


func _build_materials() -> void:
	# The three lease colours are mutually exclusive. One component-local active
	# material follows authoritative state instead of retaining three immutable
	# resources that can never be rendered together. The dim boundary remains a
	# second resource because it is visible beside amber guides during approach.
	_materials = {
		"dim": _make_material(ALBEDO_INACTIVE, EMISSION_INACTIVE, EMISSION_ENERGY_INACTIVE),
		"active": _make_material(ALBEDO_RELEASED, EMISSION_RELEASED, EMISSION_ENERGY_RELEASED),
	}
	_material_instance_ids.clear()
	for material_id: StringName in _materials:
		_material_instance_ids[material_id] = (_materials[material_id] as Material).get_instance_id()


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.12
	material.roughness = 0.46
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _capture_integrity_contract() -> void:
	_visual_root_instance_id = _visual_root.get_instance_id()
	_visual_root_storage_contract = _storage_property_snapshot(
		_visual_root,
		PackedStringArray(["transform", "visible"])
	)
	_label_instance_id = _label.get_instance_id()
	_label_transform = _label.transform
	_label_storage_contract = _storage_property_snapshot(
		_label,
		PackedStringArray(["transform", "text", "visible", "modulate"])
	)
	_material_contracts.clear()
	for material_id: StringName in _materials:
		_material_contracts[material_id] = _material_snapshot(
			_materials.get(material_id) as StandardMaterial3D
		)
	_mesh_contracts.clear()
	_owned_child_instance_ids.clear()
	for child in _visual_root.get_children():
		_owned_child_instance_ids[child.get_instance_id()] = true
	for mesh in _meshes:
		_mesh_contracts[mesh.get_instance_id()] = {
			"path": get_path_to(mesh),
			"transform": mesh.transform,
			"mesh_instance_id": mesh.mesh.get_instance_id(),
			"mesh_size": (mesh.mesh as BoxMesh).size,
			"cast_shadow": mesh.cast_shadow,
			"layers": mesh.layers,
			"transparency": mesh.transparency,
			"material_instance_id": mesh.material_override.get_instance_id(),
			"node_properties": _storage_property_snapshot(
				mesh,
				PackedStringArray(["transform", "visible", "material_override"])
			),
			"mesh_properties": _storage_property_snapshot(mesh.mesh),
		}


func _material_snapshot(material: StandardMaterial3D) -> Dictionary:
	return {
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"transparency": material.transparency,
		"cull_mode": material.cull_mode,
		"shading_mode": material.shading_mode,
		"storage_properties": _storage_property_snapshot(
			material,
			PackedStringArray(["albedo_color", "emission", "emission_energy_multiplier"])
		),
	}


func _material_matches_contract(
	material: StandardMaterial3D,
	contract: Dictionary,
	material_id: StringName
	) -> bool:
	var expected_albedo := contract.get("albedo_color") as Color
	var expected_emission := contract.get("emission") as Color
	var expected_energy := float(contract.get("emission_energy", -1.0))
	if material_id == &"active":
		var palette := _active_material_palette()
		expected_albedo = palette.albedo as Color
		expected_emission = palette.emission as Color
		expected_energy = float(palette.energy)
	return not contract.is_empty() \
		and material.albedo_color == expected_albedo \
		and is_equal_approx(material.metallic, float(contract.get("metallic", -1.0))) \
		and is_equal_approx(material.roughness, float(contract.get("roughness", -1.0))) \
		and material.emission_enabled == bool(contract.get("emission_enabled", false)) \
		and material.emission == expected_emission \
		and is_equal_approx(material.emission_energy_multiplier, expected_energy) \
		and material.transparency == contract.get("transparency") \
		and material.cull_mode == contract.get("cull_mode") \
		and material.shading_mode == contract.get("shading_mode") \
		and _storage_properties_match(
			material,
			contract.get("storage_properties", {}) as Dictionary,
			PackedStringArray(["albedo_color", "emission", "emission_energy_multiplier"])
		)


func _mesh_matches_contract(mesh: MeshInstance3D, contract: Dictionary) -> bool:
	if mesh.mesh == null or not mesh.mesh is BoxMesh or mesh.material_override == null:
		return false
	var expected_transform := contract.get("transform", Transform3D.IDENTITY) as Transform3D
	# Approach guides have a deterministic phase translation; compare against the
	# exact state-derived pose rather than the static build pose.
	if _guide_meshes.has(mesh):
		var guide_index := _guide_meshes.find(mesh)
		expected_transform = _base_guide_transforms[guide_index]
		if _state == STATE_APPROACH:
			var phase := fposmod(_elapsed, 1.0)
			var direction := -signf(expected_transform.origin.z)
			expected_transform.origin.z += direction * phase * minf(0.85, _built_cue_half_length * 0.07)
	var expected_visible := _expected_visibility_for_mesh(mesh)
	var expected_material := _expected_material_for_mesh(mesh)
	return get_node_or_null(contract.get("path", NodePath())) == mesh \
		and mesh.transform.is_equal_approx(expected_transform) \
		and mesh.mesh.get_instance_id() == int(contract.get("mesh_instance_id", 0)) \
		and (mesh.mesh as BoxMesh).size.is_equal_approx(contract.get("mesh_size", Vector3.ZERO) as Vector3) \
		and mesh.cast_shadow == contract.get("cast_shadow") \
		and mesh.layers == int(contract.get("layers", 0)) \
		and is_equal_approx(mesh.transparency, float(contract.get("transparency", -1.0))) \
		and mesh.visible == expected_visible \
		and mesh.material_override == expected_material \
		and _storage_properties_match(
			mesh,
			contract.get("node_properties", {}) as Dictionary,
			PackedStringArray(["transform", "visible", "material_override"])
		) \
		and _storage_properties_match(
			mesh.mesh,
			contract.get("mesh_properties", {}) as Dictionary
		)


## Whether `mesh` is rendered in the live state. Guides are approach-exclusive,
## and each state glyph is exclusive to the one state whose shape it draws.
func _expected_visibility_for_mesh(mesh: MeshInstance3D) -> bool:
	if _guide_meshes.has(mesh):
		return _state == STATE_APPROACH
	var glyph_index := _glyph_meshes.find(mesh)
	if glyph_index >= 0:
		return _glyph_mesh_states[glyph_index] == _state
	return true


func _expected_material_for_mesh(mesh: MeshInstance3D) -> Material:
	if _guide_meshes.has(mesh):
		return _materials.get("active") as Material
	if _glyph_meshes.has(mesh):
		return _active_state_material()
	if _boundary_meshes.has(mesh):
		return (
			_materials.get("dim") as Material
			if _state == STATE_APPROACH
			else _active_state_material()
		)
	return _active_state_material()


func _active_state_material() -> Material:
	return _materials.get("active") as Material


func _active_material_palette() -> Dictionary:
	if _state == STATE_APPROACH:
		return {"albedo": ALBEDO_APPROACH, "emission": EMISSION_APPROACH, "energy": EMISSION_ENERGY_APPROACH}
	if _state == STATE_OCCUPIED:
		return {"albedo": ALBEDO_OCCUPIED, "emission": EMISSION_OCCUPIED, "energy": EMISSION_ENERGY_OCCUPIED}
	return {"albedo": ALBEDO_RELEASED, "emission": EMISSION_RELEASED, "energy": EMISSION_ENERGY_RELEASED}


func _label_matches_contract() -> bool:
	if not is_instance_valid(_label) \
			or _label.get_instance_id() != _label_instance_id \
			or not is_instance_valid(_visual_root) \
			or _label.get_parent() != _visual_root \
			or get_node_or_null("FeedbackVisual/LeaseStateLabel") != _label:
		return false
	var expected := _state_label_contract()
	return _label.transform.is_equal_approx(_label_transform) \
		and _label.text == str(expected.text) \
		and _label.visible == _feedback_enabled \
		and not _label.double_sided \
		and not _label.no_depth_test \
		and _label.font_size == 48 \
		and is_equal_approx(_label.pixel_size, 0.004) \
		and _label.outline_size == 10 \
		and _label.modulate.is_equal_approx(expected.modulate as Color) \
		and _storage_properties_match(
			_label,
			_label_storage_contract,
			PackedStringArray(["transform", "text", "visible", "modulate"])
		)


func _owned_children_match_live_hierarchy() -> bool:
	if not is_instance_valid(_visual_root) \
			or _visual_root.get_child_count() != MESH_COUNT + 1 \
			or _owned_child_instance_ids.size() != MESH_COUNT + 1:
		return false
	var live_ids: Dictionary = {}
	for child in _visual_root.get_children():
		if not is_instance_valid(child) \
				or (not child is MeshInstance3D and not child is Label3D):
			return false
		live_ids[child.get_instance_id()] = true
	return live_ids == _owned_child_instance_ids


func _storage_property_snapshot(
	object: Object,
	excluded := PackedStringArray()
	) -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(object):
		return result
	for descriptor in object.get_property_list():
		if int(descriptor.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name := String(descriptor.get("name", ""))
		if property_name.is_empty() or excluded.has(property_name):
			continue
		result[property_name] = _stable_contract_value(object.get(property_name))
	return result


func _storage_properties_match(
	object: Object,
	contract: Dictionary,
	excluded := PackedStringArray()
	) -> bool:
	return not contract.is_empty() \
		and _storage_property_snapshot(object, excluded) == contract


func _stable_contract_value(value: Variant) -> Variant:
	if value is Object:
		return (value as Object).get_instance_id() if is_instance_valid(value) else 0
	if value is Array:
		var array_result: Array = []
		for entry in value:
			array_result.append(_stable_contract_value(entry))
		return array_result
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key in value:
			dictionary_result[_stable_contract_value(key)] = _stable_contract_value(value[key])
		return dictionary_result
	return value


func _state_label_contract() -> Dictionary:
	var text_value := "BERTH OPEN"
	var color := LABEL_RELEASED
	if _state == STATE_APPROACH:
		text_value = "APPROACH VECTOR"
		color = LABEL_APPROACH
	elif _state == STATE_OCCUPIED:
		text_value = "BERTH SECURED"
		color = LABEL_OCCUPIED
	color.a = 1.0 if _state == STATE_OCCUPIED else 0.88 + 0.12 * sin(_elapsed * TAU)
	return {"text": text_value, "modulate": color}


func _compute_live_render_aabb() -> AABB:
	var found := false
	var result := AABB()
	if not is_instance_valid(_visual_root):
		return result
	for visual in _visual_root.find_children("*", "VisualInstance3D", true, false):
		var instance := visual as VisualInstance3D
		if not is_instance_valid(instance):
			continue
		var box := _transformed_aabb(instance.transform, instance.get_aabb())
		result = box if not found else result.merge(box)
		found = true
	return result


static func _transformed_aabb(transform_value: Transform3D, box: AABB) -> AABB:
	var first := transform_value * box.position
	var result := AABB(first, Vector3.ZERO)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				result = result.expand(transform_value * Vector3(x, y, z))
	return result


func _add_box(
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material
	) -> MeshInstance3D:
	# Every cue remains its own named/stateful MeshInstance and therefore its own
	# submission. A single build-frozen unit box supplies all geometry; node scale
	# retains each cue's exact authored dimensions. The resource remains local to
	# this component so an integrity mutation cannot bleed into another berth.
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3.ONE
		_shared_box_mesh.resource_name = "BerthFeedbackUnitBox"
		_shared_box_mesh.set_meta(&"visual_resource_family", &"ship_berth_feedback_unit_box")
		_shared_box_mesh.set_meta(&"component_local_shared", true)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.scale = size
	mesh_instance.mesh = _shared_box_mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta(&"presentation_only", true)
	mesh_instance.set_meta(&"evidence_status", &"modern_interpretation")
	_visual_root.add_child(mesh_instance)
	_meshes.append(mesh_instance)
	return mesh_instance


func _bind_berth() -> void:
	_unbind_berth()
	_berth = get_parent() as ShipBerth
	if not is_instance_valid(_berth):
		return
	if not _berth.reservation_changed.is_connected(_on_berth_state_signal):
		_berth.reservation_changed.connect(_on_berth_state_signal)
	if not _berth.occupancy_changed.is_connected(_on_berth_state_signal):
		_berth.occupancy_changed.connect(_on_berth_state_signal)


func _bind_audio() -> void:
	_unbind_audio()
	_audio_binding = ShipBerthAudioBindingType.new()
	_audio_binding.attach(self)


func _unbind_audio() -> void:
	if _audio_binding != null:
		_audio_binding.detach()
	_audio_binding = null


func _unbind_berth() -> void:
	if not is_instance_valid(_berth):
		_berth = null
		return
	if _berth.reservation_changed.is_connected(_on_berth_state_signal):
		_berth.reservation_changed.disconnect(_on_berth_state_signal)
	if _berth.occupancy_changed.is_connected(_on_berth_state_signal):
		_berth.occupancy_changed.disconnect(_on_berth_state_signal)
	_berth = null


func _on_berth_state_signal(_first: Variant = null, _second: Variant = null) -> void:
	_reconcile_state(false)


func _derive_state() -> StringName:
	if not is_instance_valid(_berth):
		return STATE_RELEASED
	# This accessor intentionally runs cleanup before reading the weak references.
	_berth.get_reserved_ship_id()
	if is_instance_valid(_berth.get_occupant()):
		return STATE_OCCUPIED
	if is_instance_valid(_berth.get_reservation_owner()):
		return STATE_APPROACH
	return STATE_RELEASED


func _reconcile_state(force: bool) -> void:
	var next_state := _derive_state()
	if _emitting_state:
		# Always retain the newest authoritative result. A synchronous listener may
		# move approach -> occupied -> released -> approach while the first approach
		# event is still being delivered; conditional assignment would preserve a
		# stale intermediate state when the chain ends back at the emitted state.
		_pending_state = next_state
		return
	if next_state == _state:
		if force:
			_apply_visual_state()
		return
	var transition := next_state
	while transition != _state:
		_state = transition
		_apply_visual_state()
		_emitting_state = true
		# Capture the exact transition value. Nested berth signals queue their newer
		# state, so every listener observes this state consistently.
		state_changed.emit(transition)
		_emitting_state = false
		transition = _pending_state
		_pending_state = &""
		if transition.is_empty():
			break


func _apply_visual_state() -> void:
	if not is_instance_valid(_visual_root):
		return
	var active_material := _materials.get("active") as StandardMaterial3D
	var palette := _active_material_palette()
	active_material.albedo_color = palette.albedo as Color
	active_material.emission = palette.emission as Color
	active_material.emission_energy_multiplier = float(palette.energy)
	var label_text := "BERTH OPEN"
	var label_color := LABEL_RELEASED
	if _state == STATE_APPROACH:
		label_text = "APPROACH VECTOR"
		label_color = LABEL_APPROACH
	elif _state == STATE_OCCUPIED:
		label_text = "BERTH SECURED"
		label_color = LABEL_OCCUPIED
	for mesh in _boundary_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = active_material if _state != STATE_APPROACH else _materials.dim
	for mesh in _guide_meshes:
		if is_instance_valid(mesh):
			mesh.visible = _state == STATE_APPROACH
			mesh.material_override = active_material
	for mesh in _status_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = active_material
	# The shape channel. Exactly one glyph is ever rendered, and which one is
	# decided by the state alone, so a viewer who cannot separate the three cue
	# hues still reads three unmistakably different silhouettes.
	for index in _glyph_meshes.size():
		var glyph := _glyph_meshes[index]
		if not is_instance_valid(glyph):
			continue
		glyph.visible = _glyph_mesh_states[index] == _state
		glyph.material_override = active_material
	if is_instance_valid(_label):
		_label.text = label_text
		_label.modulate = label_color
	_apply_animation()


func _apply_animation() -> void:
	if not _built or not is_instance_valid(_visual_root):
		return
	var phase := fposmod(_elapsed, 1.0)
	for index in _guide_meshes.size():
		var guide := _guide_meshes[index]
		if not is_instance_valid(guide) or index >= _base_guide_transforms.size():
			continue
		guide.transform = _base_guide_transforms[index]
		if _state == STATE_APPROACH:
			var direction := -signf(guide.position.z)
			guide.position.z += direction * phase * minf(0.85, _built_cue_half_length * 0.07)
	var pulse := 0.88 + 0.12 * sin(_elapsed * TAU)
	if is_instance_valid(_label):
		_label.modulate.a = pulse if _state != STATE_OCCUPIED else 1.0


func _refresh_processing() -> void:
	# Reconciliation is independent of animation. ShipBerth weak-owner cleanup does
	# not emit a signal, so a cheap poll must remain active while the component is
	# enabled even in paused/manual-clock modes.
	set_process(is_inside_tree() and _feedback_enabled)
