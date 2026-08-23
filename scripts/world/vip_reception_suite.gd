class_name VipReceptionSuite
extends Node3D

## Modern-interpretation VIP reception interior behind the Aft Junction's red door.
##
## EVIDENCE BOUNDARY, READ FIRST. Nothing in this file reproduces anything. The
## surviving material gives two disconnected VIP fragments: B3 shows a red VIP
## landmark as a *sightline* from the spawn deck, and C1 — a later recording
## whose build provenance is not established — shows a red VIP *area* whose
## interior is never described. No source joins them, no source describes a plan,
## a fitting, a material or a single object inside any VIP room, and this module
## therefore claims none. It is authored fiction standing behind a landmark: the
## element label is `new`, the evidence status is `modern_interpretation`, and
## the source confidence is `none`. The one thing it must never do is make the
## ledger's "unknown" quieter, so `get_evidence_metadata()` publishes the two
## fragments as unknowns rather than as references, and the room says so on a
## plinth at its own threshold where a player reads it before the view.
##
## What the door used to be is recorded rather than erased: it was a locked,
## deferred landmark with `INTERIOR NOT YET AUTHENTICATED` on it, and the
## interior behind it was deliberately absent. Opening it does not upgrade any
## evidence. It only means the project now shows an invented room *as* an
## invented room instead of showing a sealed plate.
##
## STRUCTURE. The suite is a cable-stayed pod cantilevered off the Aft Junction's
## upper deck, and it is drawn that way rather than asserted: two keel girders run
## the length of the floor and lap the aft deck's own underside, a collar frame
## laps the landmark facade, a mast stands on the roof over the joint, and four
## stays run from the mast head to the outer roof corners and back down to the
## facade header. Every piece intersects the piece that carries it — the station
## has been bitten repeatedly by geometry that hovered a few centimetres off its
## own support, so the module publishes its load path as a roster and its own
## suite measures it.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"vip-reception-suite"

## Confidence-graded interpretation labels. These three fields are the whole
## point of the module: they are what keeps an invented room honest.
##
##   `element_label`   — the topology document's vocabulary: observed, inferred,
##                       fixed-era-inspired, or new. This is `new`.
##   `evidence_status` — `modern_interpretation`, with no qualifying prefix,
##                       because nothing bounds it.
##   `confidence`      — `none`. Not "low": no registered anchor describes any
##                       VIP interior at all, so there is nothing to be a little
##                       confident about.
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const INTERPRETATION_LABEL: StringName = &"new"
const SOURCE_CONFIDENCE: StringName = &"none"

const WORLD_LAYER := PhysicsLayers.WORLD

## Registered panel recipe, one triplanar scale per material role.
##
## The number is `uv1_scale` on a world-space triplanar map, so it is repeats per
## metre and *smaller values give broader plates* — the working modules' 0.28-0.30
## puts a plate roughly every half metre. Both directions of that were rendered
## here before these values were frozen. The first build used 0.22 for everything
## on the theory that a finer module reads as a more expensive one, and
## photographed as a riveted tile grid; the correction overshot to 1.05 and
## photographed as bathroom mosaic. What actually separates a finished room from a
## working one is broad, quiet plate on the shell with the fine grain kept for the
## metal, which is this table: roughly metre-wide plate on the pearl shell, down
## through the floor and the lacquer, and only the small bronze and graphite
## pieces at anything like the station's working grain.
const PANEL_SURFACE_SCALES := {
	"pearl": 0.12,
	"pearl_deep": 0.14,
	"pearl_floor": 0.16,
	"lacquer": 0.2,
	"stone": 0.26,
	"graphite": 0.3,
	"bronze_panel": 0.4,
}

## Distance fade for every fixture practical here, matching the two habitat
## interiors so no seam between modules changes the fade distance.
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0

# --- Plan. Local origin is the threshold floor on the door axis; +Z runs
# --- outboard, away from the station.
const FLOOR_ELEVATION := 0.0
const THRESHOLD_CLEAR_HALF_WIDTH := 2.25
const THRESHOLD_DEPTH := 3.0
const THRESHOLD_CEILING := 3.54
const ROOM_X_MIN := -6.9
const ROOM_X_MAX := 4.3
const ROOM_Z_MIN := 3.0
const ROOM_Z_MAX := 14.0
const ROOM_CEILING := 4.6
const LANTERN_CEILING := 6.1
const WALL_THICKNESS := 0.4
const FLOOR_PLATE_THICKNESS := 0.64

## The sunken conversation well. A 0.45 m drop in two 0.225 m risers, which is
## less than half the production capsule's measured no-jump step, so the well can
## never become a place a player falls into and cannot leave.
const WELL_FLOOR := -0.45
const WELL_STEP_RISE := 0.225
const WELL_X_MIN := -4.6
const WELL_X_MAX := 1.4
const WELL_Z_MIN := 5.9
const WELL_Z_MAX := 11.3

## Seven banquette segments, four armchairs, three servery stools and the window
## bench. Counted, not estimated: `get_validation_errors()` fails if the built
## roster drifts.
const SEAT_COUNT := 15
const GLAZING_PANE_COUNT := 11
const PRACTICAL_LIGHT_COUNT := 18

## Three named servery-stool foot rings retain their individual nodes and the
## existing bronze binding. Only their identical one-surface torus mesh is
## shared; this is not batching or a seating/collision change.
const SERVERY_STOOL_FOOT_RING_COPY_COUNT := 3
const SERVERY_STOOL_FOOT_RING_INNER_RADIUS := 0.18
const SERVERY_STOOL_FOOT_RING_OUTER_RADIUS := 0.22
const SERVERY_STOOL_FOOT_RING_RINGS := 32
const SERVERY_STOOL_FOOT_RING_SEGMENTS := 12

## Exact post-batch presentation census. Fourteen childless lacquer joint blocks
## and five childless exterior roof cassettes still draw, but two MultiMeshes own
## their submissions instead of nineteen individual MeshInstance3D nodes.
const BANQUETTE_JOINT_COPY_COUNT := 14
const ROOF_CASSETTE_COPY_COUNT := 5
const BASELINE_RENDER_DESCENDANT_COUNT := 468
const BASELINE_RENDER_MESH_INSTANCE_COUNT := 264
const BASELINE_RENDER_MULTIMESH_BATCH_COUNT := 1
const BASELINE_RENDER_DRAWN_COPY_COUNT := 278
const BASELINE_RENDER_GEOMETRY_SUBMISSION_COUNT := 265
const RENDER_DESCENDANT_COUNT := 464
const RENDER_MESH_INSTANCE_COUNT := 259
const RENDER_MULTIMESH_BATCH_COUNT := 2
const RENDER_DRAWN_COPY_COUNT := 278
const RENDER_GEOMETRY_SUBMISSION_COUNT := 261

const FOOTPRINT_MIN := Vector3(-7.6, -1.6, -0.6)
const FOOTPRINT_MAX := Vector3(4.9, 8.6, 14.7)

## Deliberately not `EVIDENCE_REFERENCES`. These are the two fragments the ledger
## holds, recorded so a reader can see exactly how little they support, and
## neither is cited as a reference for anything built here.
const UNJOINED_SOURCE_FRAGMENTS := [
	"RESEARCH.md:B3@00:04-00:52 / a red VIP landmark is visible from the spawn deck as a sightline only",
	"RESEARCH.md:C1@03:20 / a red VIP area appears in a later recording of unverified build provenance",
	"docs/research/STATION_TOPOLOGY.md / no source joins the observed sightline to the later-source area",
]

const CONTENT_NOTE := (
	"Every part of this interior is modern design: its existence, plan, volume, "
	+ "glazing, finishes, furniture, lighting, signage and structure. No source "
	+ "describes the inside of any VIP room, so nothing here reproduces anything "
	+ "and no adjacency, era or original geometry is claimed. The red landmark it "
	+ "stands behind remains the only VIP element with any observational basis, "
	+ "and that basis is a sightline, not a room."
)

@onready var _threshold_anchor: Marker3D = %ThresholdAnchor
@onready var _reception_anchor: Marker3D = %ReceptionAnchor
@onready var _view_anchor: Marker3D = %ViewAnchor

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _servery_stool_foot_ring_mesh: TorusMesh
var _seat_nodes: Array[Node3D] = []
var _glazing_panes: Array[Node3D] = []
var _support_members: Array[Node3D] = []
var _practical_lights: Array[OmniLight3D] = []
var _banquette_joint_transforms: Array[Transform3D] = []
var _banquette_joint_batch: MultiMeshInstance3D = null
var _roof_cassette_transforms: Array[Transform3D] = []
var _roof_cassette_batch: MultiMeshInstance3D = null
var _built := false
var _module_enabled := true


func _ready() -> void:
	if not _built:
		_built = true
		_create_materials()
		_create_servery_stool_foot_ring_mesh()
		_build_structure()
		_apply_metadata()
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_threshold_marker() -> Marker3D:
	return _threshold_anchor


func get_reception_marker() -> Marker3D:
	return _reception_anchor


func get_view_marker() -> Marker3D:
	return _view_anchor


func get_room_ids() -> Array[StringName]:
	return [&"vip-threshold", &"vip-reception"]


func has_room(room_id: StringName) -> bool:
	return get_room_ids().has(room_id)


func get_room_volume(room_id: StringName) -> Dictionary:
	var local_center := Vector3.ZERO
	var half_extents := Vector3.ZERO
	var room_class: StringName = &"unknown"
	match room_id:
		&"vip-threshold":
			local_center = Vector3(0.0, THRESHOLD_CEILING * 0.5, THRESHOLD_DEPTH * 0.5)
			half_extents = Vector3(THRESHOLD_CLEAR_HALF_WIDTH, THRESHOLD_CEILING * 0.5, THRESHOLD_DEPTH * 0.5)
			room_class = &"receiving-threshold"
		&"vip-reception":
			local_center = Vector3(
				(ROOM_X_MIN + ROOM_X_MAX) * 0.5,
				ROOM_CEILING * 0.5,
				(ROOM_Z_MIN + ROOM_Z_MAX) * 0.5
			)
			half_extents = Vector3(
				(ROOM_X_MAX - ROOM_X_MIN) * 0.5,
				ROOM_CEILING * 0.5,
				(ROOM_Z_MAX - ROOM_Z_MIN) * 0.5
			)
			room_class = &"reception-lounge"
	if room_class == &"unknown":
		return {}
	return {
		"room_id": room_id,
		"room_class": room_class,
		"local_center": local_center,
		"half_extents": half_extents,
		"evidence_status": EVIDENCE_STATUS,
		"interpretation_label": INTERPRETATION_LABEL,
		"source_confidence": SOURCE_CONFIDENCE,
		"world_transform": global_transform * Transform3D(Basis.IDENTITY, local_center),
	}


func get_room_volumes() -> Dictionary:
	var result := {}
	for room_id in get_room_ids():
		result[room_id] = get_room_volume(room_id)
	return result


func contains_room(room_id: StringName, world_position: Vector3) -> bool:
	var volume := get_room_volume(room_id)
	if volume.is_empty():
		return false
	var relative := to_local(world_position) - (volume.local_center as Vector3)
	var half_extents := volume.half_extents as Vector3
	return absf(relative.x) <= half_extents.x \
		and absf(relative.y) <= half_extents.y \
		and absf(relative.z) <= half_extents.z


func get_seat_count() -> int:
	return _seat_nodes.size()


func get_glazing_pane_count() -> int:
	return _glazing_panes.size()


func get_practical_light_count() -> int:
	return _practical_lights.size()


## Renderer-independent allocation audit for the three named servery-stool foot
## rings. Each renderer/submission and every seating/collision owner remains
## distinct; the mesh identity is the sole shared resource.
func get_servery_stool_foot_ring_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var paths := [
		^"Structure/Fitout/ServeryStool01/FootRing",
		^"Structure/Fitout/ServeryStool02/FootRing",
		^"Structure/Fitout/ServeryStool03/FootRing",
	]
	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	var submissions := 0
	var child_node_count := 0
	var stool_seat_count := 0
	var foot_collision_body_count := 0
	for path: NodePath in paths:
		var ring := get_node_or_null(path) as MeshInstance3D
		if ring == null:
			errors.append("servery_stool_foot_ring_missing:%s" % String(path))
			continue
		if ring.mesh != _servery_stool_foot_ring_mesh:
			errors.append("servery_stool_foot_ring_mesh_identity_not_shared:%s" % String(path))
		if ring.position != Vector3(0.0, 0.26, 0.0) \
				or ring.rotation_degrees != Vector3.ZERO \
				or ring.material_override != _materials.get("bronze"):
			errors.append("servery_stool_foot_ring_renderer_drift:%s" % String(path))
		var stool := ring.get_parent() as Node3D
		if stool != null \
				and bool(stool.get_meta("station_seat", false)) \
				and StringName(stool.get_meta("seat_class", &"")) == &"stool":
			stool_seat_count += 1
		else:
			errors.append("servery_stool_foot_ring_seat_contract_drift:%s" % String(path))
		if stool != null and stool.get_node_or_null(^"Foot") is StaticBody3D:
			foot_collision_body_count += 1
		else:
			errors.append("servery_stool_foot_ring_collision_contract_drift:%s" % String(path))
		var mesh := ring.mesh as TorusMesh
		if mesh != null:
			mesh_ids[mesh.get_instance_id()] = true
			submissions += mesh.get_surface_count()
		if ring.material_override != null:
			material_ids[ring.material_override.get_instance_id()] = true
		child_node_count += ring.get_child_count()
	var mesh := _servery_stool_foot_ring_mesh
	if mesh == null \
			or not is_equal_approx(mesh.inner_radius, SERVERY_STOOL_FOOT_RING_INNER_RADIUS) \
			or not is_equal_approx(mesh.outer_radius, SERVERY_STOOL_FOOT_RING_OUTER_RADIUS) \
			or mesh.rings != SERVERY_STOOL_FOOT_RING_RINGS \
			or mesh.ring_segments != SERVERY_STOOL_FOOT_RING_SEGMENTS \
			or mesh.get_surface_count() != 1:
		errors.append("servery_stool_foot_ring_recipe_drift")
	if mesh_ids.size() != 1:
		errors.append("servery_stool_foot_ring_mesh_identity_count_drift")
	if material_ids.size() != 1:
		errors.append("servery_stool_foot_ring_material_identity_drift")
	if submissions != SERVERY_STOOL_FOOT_RING_COPY_COUNT:
		errors.append("servery_stool_foot_ring_submission_count_drift")
	if child_node_count != 0:
		errors.append("servery_stool_foot_ring_authority_drift")
	if stool_seat_count != SERVERY_STOOL_FOOT_RING_COPY_COUNT \
			or foot_collision_body_count != SERVERY_STOOL_FOOT_RING_COPY_COUNT:
		errors.append("servery_stool_foot_ring_owner_roster_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"vip_reception_servery_stool_foot_rings",
		"node_count": paths.size(),
		"structural_submission_count": submissions,
		"mesh_resource_identity_count_before": SERVERY_STOOL_FOOT_RING_COPY_COUNT,
		"mesh_resource_identity_count_after": mesh_ids.size(),
		"mesh_resource_identity_delta": mesh_ids.size() - SERVERY_STOOL_FOOT_RING_COPY_COUNT,
		"material_resource_identity_count": material_ids.size(),
		"child_node_count": child_node_count,
		"stool_seat_count": stool_seat_count,
		"foot_collision_body_count": foot_collision_body_count,
		"batched": false,
		"material_sharing": false,
		"seat_authority": false,
		"collision_authority": false,
		"route_authority": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
	}.duplicate(true)


func get_clearance_profile() -> Dictionary:
	return {
		"floor_elevation": FLOOR_ELEVATION,
		"threshold_clear_width": THRESHOLD_CLEAR_HALF_WIDTH * 2.0,
		"threshold_head_clearance": THRESHOLD_CEILING,
		"reception_head_clearance": ROOM_CEILING,
		"lantern_head_clearance": LANTERN_CEILING,
		"well_drop": absf(WELL_FLOOR),
		"well_step_rise": WELL_STEP_RISE,
		"player_capsule_reference_diameter": 0.76,
		"player_capsule_reference_height": 1.94,
	}


func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": global_transform,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
	}


## The published load path. Each entry is a member and the piece it laps, so the
## "nothing floats" rule is a contract this module can be measured against rather
## than a claim in a comment.
func get_support_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for member in _support_members:
		roster.append({
			"member": member.name,
			"carries": StringName(str(member.get_meta("support_carries", &"unknown"))),
			"laps": StringName(str(member.get_meta("support_laps", &"unknown"))),
		})
	return roster


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"interpretation_label": INTERPRETATION_LABEL,
		"source_confidence": SOURCE_CONFIDENCE,
		"source_bounded": false,
		"authenticated_original_geometry": false,
		"reproduces_observed_interior": false,
		"registered_evidence_anchors": PackedStringArray(),
		"unjoined_source_fragments": PackedStringArray(UNJOINED_SOURCE_FRAGMENTS),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"a red VIP landmark existed as something a player could see from the deck",
		]),
		"modern_interpretations": PackedStringArray([
			"the existence of any VIP interior behind the landmark",
			"the suite's plan, volume, elevation and cantilevered structure",
			"the sunken conversation well, banquette, host desk and servery",
			"the outboard glazing, the raised lantern and every fitting and finish",
			"the reception function itself, including that the station received guests at all",
		]),
		"explicit_unknowns": PackedStringArray([
			"whether the original VIP area had any interior a player could enter",
			"its plan, contents, materials, lighting, scale and elevation",
			"whether B3's observed sightline and C1's later area are the same place",
			"which build or era either fragment belongs to",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if EVIDENCE_STATUS != &"modern_interpretation":
		errors.append("an invented interior may publish no status other than modern_interpretation")
	if SOURCE_CONFIDENCE != &"none":
		errors.append("no VIP interior anchor exists, so published confidence must stay none")
	if _seat_nodes.size() != SEAT_COUNT:
		errors.append("the reception seating roster is incomplete")
	if _glazing_panes.size() < GLAZING_PANE_COUNT:
		errors.append("the outboard view requires at least %d independent panes" % GLAZING_PANE_COUNT)
	if _support_members.size() < 8:
		errors.append("the cantilever load path is not fully published")
	if _practical_lights.size() != PRACTICAL_LIGHT_COUNT:
		errors.append("the considered-lighting practical roster drifted")
	var clearance := get_clearance_profile()
	if float(clearance.threshold_clear_width) < 3.0:
		errors.append("threshold circulation is not player-clear")
	if float(clearance.threshold_head_clearance) < 2.4 or float(clearance.reception_head_clearance) < 2.4:
		errors.append("published head clearance is below avatar height")
	if float(clearance.well_step_rise) > 0.32:
		errors.append("the sunken well cannot be entered and left without a jump")
	var collision := get_collision_contract()
	if not bool(collision.all_layers_match_lifecycle):
		errors.append("static body collision layers differ from the current lifecycle state")
	if not bool(collision.all_masks_zero):
		errors.append("station structure must not query collision through a mask")
	if not bool(collision.all_shapes_present_and_enabled):
		errors.append("a walkable surface is missing an enabled collision shape")
	if not bool(get_performance_contract().within_budget):
		errors.append("component counts exceed the declared quality budget")
	var rendering := get_render_batch_contract()
	if not bool(rendering.exact_counts):
		errors.append("VIP renderer node, batch, copy, or submission counts drifted")
	if not bool(rendering.banquette_renderer_buffer_matches_authored):
		errors.append("VIP banquette-joint renderer buffer drifted from its authored roster")
	if not bool(rendering.banquette_bounds_match_authored):
		errors.append("VIP banquette-joint batch bounds drifted from its authored copies")
	if not bool(rendering.roof_cassette_renderer_buffer_matches_authored):
		errors.append("VIP roof-cassette renderer buffer drifted from its authored roster")
	if not bool(rendering.roof_cassette_bounds_match_authored):
		errors.append("VIP roof-cassette batch bounds drifted from its authored copies")
	return errors


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"evidence": get_evidence_metadata(),
		"room_ids": get_room_ids(),
		"room_volumes": get_room_volumes(),
		"clearance": get_clearance_profile(),
		"seat_count": get_seat_count(),
		"glazing_pane_count": get_glazing_pane_count(),
		"practical_light_count": get_practical_light_count(),
		"render_batches": get_render_batch_contract(),
		"support_roster": get_support_roster(),
		"footprint": get_integration_footprint(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["seat_count"] = get_seat_count()
	roster["glazing_pane_count"] = get_glazing_pane_count()
	roster["render_batches"] = get_render_batch_contract()
	return roster


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(self, WORLD_LAYER, _module_enabled)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_performance_contract() -> Dictionary:
	# This module's own declared regression ceilings, measured against the built
	# suite with headroom, not hardware evidence. The light ceiling is the one
	# worth arguing about: 18 is a lot for a 123 m² room and it is deliberate —
	# the whole brief for this space is that it is lit rather than illuminated —
	# but every one of them is shadowless, steeply attenuated and distance-faded,
	# and 19 against the scene's 240-light budget is what the room costs. Frozen at
	# the exact built count rather than left with headroom.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 340,
		"static_bodies": 130,
		"collision_shapes": 150,
		"labels": 8,
		"lights": 19,
		"process_loops": 0,
		"physics_process_loops": 0,
	})
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_render_batch_contract() -> Dictionary:
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var batch_nodes := find_children("*", "MultiMeshInstance3D", true, false)
	var drawn_copies := 0
	var submissions := 0
	for raw_node in mesh_nodes:
		var instance := raw_node as MeshInstance3D
		if instance.mesh == null:
			continue
		drawn_copies += 1
		submissions += instance.mesh.get_surface_count()
	for raw_node in batch_nodes:
		var batch := raw_node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var visible_copies := batch.multimesh.visible_instance_count
		if visible_copies < 0:
			visible_copies = batch.multimesh.instance_count
		drawn_copies += visible_copies
		submissions += batch.multimesh.mesh.get_surface_count()

	var expected_joint_buffer := _encode_multimesh_transforms(_banquette_joint_transforms)
	var joint_renderer_buffer_matches := (
		is_instance_valid(_banquette_joint_batch)
		and _banquette_joint_batch.multimesh != null
		and _banquette_joint_batch.multimesh.buffer == expected_joint_buffer
	)
	var joint_bounds_match := false
	if is_instance_valid(_banquette_joint_batch) and _banquette_joint_batch.multimesh != null:
		var expected_bounds := _transformed_mesh_bounds(
			_banquette_joint_batch.multimesh.mesh.get_aabb(),
			_banquette_joint_transforms
		)
		# The transforms are uploaded as a raw renderer buffer, so Godot does not
		# rebuild MultiMesh.get_aabb() on the CPU in headless validation. The
		# explicit custom AABB is the culling contract used by the renderer.
		joint_bounds_match = _banquette_joint_batch.multimesh.custom_aabb.is_equal_approx(expected_bounds)
	var expected_roof_buffer := _encode_multimesh_transforms(_roof_cassette_transforms)
	var roof_renderer_buffer_matches := (
		is_instance_valid(_roof_cassette_batch)
		and _roof_cassette_batch.multimesh != null
		and _roof_cassette_batch.multimesh.buffer == expected_roof_buffer
	)
	var roof_bounds_match := false
	if is_instance_valid(_roof_cassette_batch) and _roof_cassette_batch.multimesh != null:
		var expected_roof_bounds := _transformed_mesh_bounds(
			_roof_cassette_batch.multimesh.mesh.get_aabb(),
			_roof_cassette_transforms
		)
		roof_bounds_match = _roof_cassette_batch.multimesh.custom_aabb.is_equal_approx(
			expected_roof_bounds
		)
	var descendant_count := _render_descendant_count()
	var exact_counts := (
		descendant_count == RENDER_DESCENDANT_COUNT
		and mesh_nodes.size() == RENDER_MESH_INSTANCE_COUNT
		and batch_nodes.size() == RENDER_MULTIMESH_BATCH_COUNT
		and drawn_copies == RENDER_DRAWN_COPY_COUNT
		and submissions == RENDER_GEOMETRY_SUBMISSION_COUNT
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"baseline_descendant_nodes": BASELINE_RENDER_DESCENDANT_COUNT,
		"descendant_nodes": descendant_count,
		"baseline_mesh_instances": BASELINE_RENDER_MESH_INSTANCE_COUNT,
		"mesh_instances": mesh_nodes.size(),
		"baseline_multimesh_batches": BASELINE_RENDER_MULTIMESH_BATCH_COUNT,
		"multimesh_batches": batch_nodes.size(),
		"baseline_drawn_copies": BASELINE_RENDER_DRAWN_COPY_COUNT,
		"drawn_copies": drawn_copies,
		"baseline_geometry_submissions": BASELINE_RENDER_GEOMETRY_SUBMISSION_COUNT,
		"geometry_submissions": submissions,
		"banquette_joint_copies": _banquette_joint_transforms.size(),
		"roof_cassette_copies": _roof_cassette_transforms.size(),
		"banquette_renderer_buffer_floats": (
			_banquette_joint_batch.multimesh.buffer.size()
			if is_instance_valid(_banquette_joint_batch) and _banquette_joint_batch.multimesh != null
			else 0
		),
		"roof_cassette_renderer_buffer_floats": (
			_roof_cassette_batch.multimesh.buffer.size()
			if is_instance_valid(_roof_cassette_batch) and _roof_cassette_batch.multimesh != null
			else 0
		),
		"renderer_buffer_floats": (
			(_banquette_joint_batch.multimesh.buffer.size()
				if is_instance_valid(_banquette_joint_batch) and _banquette_joint_batch.multimesh != null
				else 0)
			+ (_roof_cassette_batch.multimesh.buffer.size()
				if is_instance_valid(_roof_cassette_batch) and _roof_cassette_batch.multimesh != null
				else 0)
		),
		"banquette_renderer_buffer_matches_authored": joint_renderer_buffer_matches,
		"banquette_bounds_match_authored": joint_bounds_match,
		"roof_cassette_renderer_buffer_matches_authored": roof_renderer_buffer_matches,
		"roof_cassette_bounds_match_authored": roof_bounds_match,
		"renderer_buffer_matches_authored": (
			joint_renderer_buffer_matches and roof_renderer_buffer_matches
		),
		"bounds_match_authored": joint_bounds_match and roof_bounds_match,
		"roof_cassette_baseline_mesh_instances": ROOF_CASSETTE_COPY_COUNT,
		"roof_cassette_mesh_instances": 0,
		"roof_cassette_baseline_multimesh_resources": 0,
		"roof_cassette_multimesh_resources": 1 if is_instance_valid(_roof_cassette_batch) else 0,
		"roof_cassette_baseline_mesh_resources": 1,
		"roof_cassette_mesh_resources": (
			1
			if is_instance_valid(_roof_cassette_batch)
			and _roof_cassette_batch.multimesh != null
			and _roof_cassette_batch.multimesh.mesh != null
			else 0
		),
		"roof_cassette_material_resources": (
			1
			if is_instance_valid(_roof_cassette_batch)
			and _roof_cassette_batch.material_override != null
			else 0
		),
		"roof_cassette_baseline_submissions": ROOF_CASSETTE_COPY_COUNT,
		"roof_cassette_submissions": (
			_roof_cassette_batch.multimesh.mesh.get_surface_count()
			if is_instance_valid(_roof_cassette_batch)
			and _roof_cassette_batch.multimesh != null
			and _roof_cassette_batch.multimesh.mesh != null
			else 0
		),
		"exact_counts": exact_counts,
		"authored_joint_transforms": _banquette_joint_transforms.duplicate(),
		"authored_roof_cassette_transforms": _roof_cassette_transforms.duplicate(),
	}


func _render_descendant_count() -> int:
	var count := 0
	for candidate in find_children("*", "Node", true, false):
		var cursor := candidate as Node
		var interaction_owned := false
		while cursor != null and cursor != self:
			if cursor is StationSeat:
				interaction_owned = true
				break
			cursor = cursor.get_parent()
		if not interaction_owned:
			count += 1
	return count


func set_module_enabled(enabled: bool) -> void:
	if not _is_current():
		return
	_module_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _module_enabled


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_lifecycle_contract() -> Dictionary:
	var contract := StationModuleContract.build_lifecycle_contract(self, WORLD_LAYER, _module_enabled, self)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built
	return contract


func _apply_enabled_state() -> void:
	StationModuleContract.apply_enabled_state(
		StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _module_enabled, self
	)
	for seat in find_children("*", "StationSeat", true, false):
		(seat as StationSeat).set_enabled(_module_enabled)


func _apply_metadata() -> void:
	set_meta("station_interior", true)
	set_meta("module_id", MODULE_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("interpretation_label", INTERPRETATION_LABEL)
	set_meta("source_confidence", SOURCE_CONFIDENCE)
	set_meta("source_bounded", false)
	set_meta("authenticated_original_geometry", false)
	set_meta("content_note", CONTENT_NOTE)
	set_meta("integration_footprint_min", FOOTPRINT_MIN)
	set_meta("integration_footprint_max", FOOTPRINT_MAX)
	add_to_group("station_interpretation_interiors")


# --- Materials -------------------------------------------------------------


## The palette is the station's own grammar at a better grade, not a different
## game: the same pressed panel family, the same chamfered builders, the same
## triplanar plate. What changes is finish quality — a warm pearl shell instead
## of utility grey, lacquered graphite instead of hull dark, solid bronze where
## the working modules use painted brass, and fabric that is upholstery rather
## than mattress ticking.
func _create_materials() -> void:
	_materials["pearl"] = _material(Color("e6e0d5"), 0.26, 0.30)
	_materials["pearl_floor"] = _material(Color("d8d1c5"), 0.16, 0.46)
	_materials["pearl_deep"] = _material(Color("c3bbae"), 0.22, 0.38)
	# Lacquer: dark, tight, low roughness. The working station has nothing this
	# reflective, which is most of why the room reads as a different grade of
	# space through the same doorway.
	_materials["lacquer"] = _material(Color("161c22"), 0.58, 0.18)
	_materials["graphite"] = _material(Color("222a30"), 0.44, 0.34)
	# Real metal, not painted metal: metallic 0.95 at roughness 0.16. Reserved for
	# fillets, rails, reveals and the table ring, all of them small.
	_materials["bronze"] = _material(Color("c08a4c"), 0.95, 0.16)
	_materials["bronze_panel"] = _material(Color("a5763f"), 0.9, 0.28)
	_materials["stone"] = _material(Color("2b3136"), 0.3, 0.22)
	_materials["carpet"] = _matte_material(Color("2c4353"), 0.0, 0.96)
	_materials["upholstery"] = _matte_material(Color("8d6544"), 0.02, 0.55)
	_materials["upholstery_dark"] = _matte_material(Color("3c2f27"), 0.02, 0.62)
	_materials["view_glass"] = _transparent_material(Color(0.32, 0.62, 0.70, 0.13), 0.05, 0.06)
	_materials["smoked_glass"] = _transparent_material(Color(0.08, 0.11, 0.14, 0.55), 0.2, 0.12)
	# Emissive families. Energies are deliberately modest: the habitat pass
	# recorded that a 2.3-energy lens clips past the AgX shoulder and blooms while
	# lighting nothing, so every strip here is a low-energy lens with a real
	# practical behind it.
	_materials["cove_lens"] = _material(Color("f6ead6"), 0.02, 0.2, Color("ffdfb4"), 1.15)
	# Emission 0.95 -> 0.42. Photographed, the table inlay was a clipped white disc
	# in the middle of the one framing this room exists for — the same bimodal
	# defect the habitat's common-room display was fixed for. Its practical carries
	# the table now; the lens only has to read as on.
	_materials["inlay"] = _material(Color("bfe6e4"), 0.08, 0.24, Color("6fd0d6"), 0.22)
	_materials["signal"] = _material(Color("d8b06a"), 0.3, 0.3, Color("d99a3c"), 0.9)
	# The landmark's own red, carried exactly one element deep into the room so
	# the door's colour has somewhere to land.
	_materials["landmark_red"] = _material(Color("d84d47"), 0.2, 0.39, Color("a9252c"), 1.05)
	for key: String in PANEL_SURFACE_SCALES.keys():
		StationSurfaceKit.apply_panel_triplanar(
			_materials[key] as StandardMaterial3D, float(PANEL_SURFACE_SCALES[key])
		)


func _create_servery_stool_foot_ring_mesh() -> void:
	_servery_stool_foot_ring_mesh = TorusMesh.new()
	_servery_stool_foot_ring_mesh.inner_radius = SERVERY_STOOL_FOOT_RING_INNER_RADIUS
	_servery_stool_foot_ring_mesh.outer_radius = SERVERY_STOOL_FOOT_RING_OUTER_RADIUS
	_servery_stool_foot_ring_mesh.rings = SERVERY_STOOL_FOOT_RING_RINGS
	_servery_stool_foot_ring_mesh.ring_segments = SERVERY_STOOL_FOOT_RING_SEGMENTS


# --- Build -----------------------------------------------------------------


func _build_structure() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	_build_cantilever_frame(structure)
	_build_threshold(structure)
	_build_reception_shell(structure)
	_build_outboard_glazing(structure)
	_build_reception_furnishing(structure)
	_build_reception_lighting(structure)
	_build_exterior_dressing(structure)


## The load path, drawn. Two keel girders lap both the suite's own floor plates
## and the Aft Junction upper deck's underside; a collar frame laps the landmark
## facade around the doorway; a mast stands on the roof over that joint and four
## stays run from its head to the outer roof corners and back to the facade
## header. Nothing here is decorative and nothing here hangs in space.
func _build_cantilever_frame(structure: Node3D) -> void:
	var frame := Node3D.new()
	frame.name = "CantileverFrame"
	structure.add_child(frame)

	for side in [-1.0, 1.0]:
		var keel_x := -1.3 + float(side) * 3.3
		var keel := _box(
			frame,
			"KeelGirder%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(keel_x, -1.03, 6.95),
			Vector3(0.55, 0.86, 14.7),
			_materials["graphite"],
			false
		)
		_register_support(keel, &"floor plates", &"aft upper deck underside")
		# Diagonal web between the keel and the floor plate above it, in the
		# station's existing under-deck idiom.
		for web_index in 6:
			var web_z := 0.6 + float(web_index) * 2.2
			_beam_between(
				frame,
				"KeelWeb%02d" % web_index,
				Vector3(keel_x, -1.35, web_z),
				Vector3(keel_x, -0.62, web_z + 1.5),
				0.075,
				_materials["bronze_panel"],
				false
			)
	var cross := _box(frame, "KeelCrossTie", Vector3(-1.3, -1.03, 13.9), Vector3(7.15, 0.6, 0.5), _materials["graphite"], false)
	_register_support(cross, &"keel girders", &"port and starboard keel girders")

	# Collar frame: laps the landmark facade around the door opening, which is how
	# the suite is tied to the module rather than merely touching it.
	for side in [-1.0, 1.0]:
		var jamb_x := float(side) * 2.7
		var jamb := _box(
			frame,
			"CollarJamb%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(jamb_x, 1.7, 0.16),
			Vector3(0.6, 4.8, 0.52),
			_materials["bronze_panel"],
			false
		)
		_register_support(jamb, &"threshold shell", &"VIP landmark facade")
	var collar_header := _box(frame, "CollarHeader", Vector3(0.0, 4.24, 0.16), Vector3(6.0, 0.56, 0.52), _materials["bronze_panel"], false)
	_register_support(collar_header, &"threshold roof", &"VIP landmark facade header")

	# Mast and stays. The mast stands on the roof slab over the joint; the stays
	# reach the outer roof corners and return to the facade header, so the outer
	# end of a 14 m cantilever is visibly held rather than left to hover.
	var mast := _cylinder(frame, "StayMast", Vector3(0.0, 6.85, 4.3), 0.16, 3.0, _materials["bronze"], false)
	_register_support(mast, &"outboard stays", &"forward roof slab")
	_torus(frame, "StayMastCollar", Vector3(0.0, 5.5, 4.3), 0.17, 0.3, _materials["bronze"])
	_cylinder(frame, "StayMastHead", Vector3(0.0, 8.28, 4.3), 0.22, 0.24, _materials["bronze"], false)
	for side in [-1.0, 1.0]:
		var corner_x := -1.3 + float(side) * 5.4
		var outboard := _beam_between(
			frame,
			"OutboardStay%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(0.0, 8.24, 4.3),
			Vector3(corner_x, 5.3, 13.9),
			0.075,
			_materials["bronze"],
			false
		)
		_register_support(outboard, &"outer roof corner", &"stay mast head")
		var back_stay := _beam_between(
			frame,
			"BackStay%s" % ("Port" if side < 0.0 else "Starboard"),
			Vector3(0.0, 8.24, 4.3),
			Vector3(float(side) * 3.1, 3.9, 0.1),
			0.075,
			_materials["bronze"],
			false
		)
		_register_support(back_stay, &"stay mast head", &"VIP landmark facade header")


## The threshold. Everything about it is a compression before a release: it is
## 4.5 m wide against the room's 11.2, its ceiling is the facade header's own
## soffit at 3.54 m against the room's 4.6 and the lantern's 6.1, its floor is
## dark stone against pale carpet, and it is lit at half the level of what is
## beyond it. A player crosses three metres of it and the room opens.
func _build_threshold(structure: Node3D) -> void:
	var threshold := Node3D.new()
	threshold.name = "Threshold"
	threshold.set_meta("station_room", true)
	threshold.set_meta("room_id", &"vip-threshold")
	threshold.set_meta("evidence_status", EVIDENCE_STATUS)
	structure.add_child(threshold)

	var plate := _box(threshold, "ThresholdFloor", Vector3(0.0, -0.32, 1.5), Vector3(5.1, FLOOR_PLATE_THICKNESS, 3.0), _materials["pearl_floor"])
	_register_support(plate, &"threshold walking surface", &"keel girders")
	_box(threshold, "ThresholdStoneInlay", Vector3(0.0, 0.025, 1.5), Vector3(4.4, 0.05, 2.9), _materials["stone"], false)
	# A single bronze thread runs from the doorway into the room and finishes at
	# the well. It is the only piece of wayfinding in the suite.
	_box(threshold, "ThresholdThread", Vector3(0.0, 0.055, 1.5), Vector3(0.14, 0.05, 2.9), _materials["bronze"], false)

	for side in [-1.0, 1.0]:
		var wall_x := float(side) * 2.4
		var hand := "Port" if side < 0.0 else "Starboard"
		_box(threshold, "ThresholdWall%s" % hand, Vector3(wall_x, 1.55, 1.5), Vector3(0.3, 4.46, 3.0), _materials["lacquer"])
		# Bronze reveal at the room end of each wall: the frame you pass through.
		_box(threshold, "ThresholdReveal%s" % hand, Vector3(wall_x, 1.77, 2.86), Vector3(0.34, 3.54, 0.14), _materials["bronze"], false)
		_box(threshold, "ThresholdCoveLens%s" % hand, Vector3(float(side) * 2.22, 3.36, 1.5), Vector3(0.06, 0.1, 2.6), _materials["cove_lens"], false)
	_box(threshold, "ThresholdCeiling", Vector3(0.0, 3.74, 1.5), Vector3(5.1, 0.4, 3.0), _materials["lacquer"])
	_box(threshold, "ThresholdRevealHead", Vector3(0.0, 3.44, 2.86), Vector3(4.8, 0.2, 0.14), _materials["bronze"], false)

	# The honest plinth. It stands where a player has crossed the doorway and has
	# not yet turned to the view, which is the only place in the room a legend of
	# this kind is read rather than skipped.
	var plinth := _box(threshold, "InterpretationPlinth", Vector3(-1.72, 0.5, 2.55), Vector3(0.9, 1.0, 0.32), _materials["lacquer"])
	_register_support(plinth, &"threshold legend", &"threshold floor")
	_box(threshold, "InterpretationPlinthCap", Vector3(-1.72, 1.02, 2.55), Vector3(0.96, 0.04, 0.38), _materials["bronze"], false)
	# Both lines sit 1 mm proud of the plinth's own face rather than hovering in
	# front of it. REGEN-DECK-002 was exactly this: two station legends floating
	# with nothing behind them, found by photographing rather than by assertion.
	_text_sign(threshold, "MODERN INTERPRETATION", Vector3(-1.72, 0.74, 2.389), Vector3(0.0, 180.0, 0.0), 0.13, _materials["bronze"])
	_text_sign(threshold, "NO SOURCE DESCRIBES THIS ROOM", Vector3(-1.72, 0.54, 2.389), Vector3(0.0, 180.0, 0.0), 0.085, _materials["pearl"])
	_box(threshold, "PlinthLegendRule", Vector3(-1.72, 0.64, 2.4), Vector3(0.78, 0.02, 0.05), _materials["landmark_red"], false)

	_fixture_practical(threshold, "ThresholdCoveSpill", Vector3(-2.0, 3.2, 1.5), Color("ffd9a8"), 0.34, 3.2)
	_fixture_practical(threshold, "ThresholdCoveSpillStarboard", Vector3(2.0, 3.2, 1.5), Color("ffd9a8"), 0.34, 3.2)
	_fixture_practical(threshold, "PlinthWash", Vector3(-1.72, 1.35, 2.4), Color("ffe0b6"), 0.26, 1.9)


## The room shell: floor ring, sunken well, walls, the stepped ceiling and the
## raised lantern. Collision is plain boxes throughout; every visible face is a
## chamfered kit mesh carrying the panel plate.
func _build_reception_shell(structure: Node3D) -> void:
	var room := Node3D.new()
	room.name = "Reception"
	room.set_meta("station_room", true)
	room.set_meta("room_id", &"vip-reception")
	room.set_meta("evidence_status", EVIDENCE_STATUS)
	structure.add_child(room)

	# Floor as a ring of four plates around the well, rather than one slab with a
	# hole: a hole is not something a box collider can express, and a player must
	# not be able to stand on an invisible lid over the well.
	var front_plate := _box(room, "FloorPlateFront", Vector3(-1.3, -0.32, 4.45), Vector3(11.2, FLOOR_PLATE_THICKNESS, 2.9), _materials["pearl_floor"])
	var rear_plate := _box(room, "FloorPlateRear", Vector3(-1.3, -0.32, 12.65), Vector3(11.2, FLOOR_PLATE_THICKNESS, 2.7), _materials["pearl_floor"])
	var port_plate := _box(room, "FloorPlatePort", Vector3(-5.75, -0.32, 8.6), Vector3(2.3, FLOOR_PLATE_THICKNESS, 5.4), _materials["pearl_floor"])
	var starboard_plate := _box(room, "FloorPlateStarboard", Vector3(2.85, -0.32, 8.6), Vector3(2.9, FLOOR_PLATE_THICKNESS, 5.4), _materials["pearl_floor"])
	for plate in [front_plate, rear_plate, port_plate, starboard_plate]:
		_register_support(plate, &"reception walking surface", &"keel girders")
	var well_pan := _box(room, "WellPan", Vector3(-1.6, -0.66, 8.6), Vector3(6.0, 0.42, 5.4), _materials["pearl_floor"])
	_register_support(well_pan, &"sunken well floor", &"keel girders")

	# Carpet. Deep, matt, and laid in three pieces so the well reads as its own
	# room within the room.
	_box(room, "CarpetFront", Vector3(-1.3, 0.025, 4.45), Vector3(10.9, 0.05, 2.8), _materials["carpet"], false)
	_box(room, "CarpetRear", Vector3(-1.3, 0.025, 12.65), Vector3(10.9, 0.05, 2.6), _materials["carpet"], false)
	_box(room, "CarpetPort", Vector3(-5.75, 0.025, 8.6), Vector3(2.2, 0.05, 5.3), _materials["carpet"], false)
	_box(room, "CarpetStarboard", Vector3(2.85, 0.025, 8.6), Vector3(2.8, 0.05, 5.3), _materials["carpet"], false)
	_box(room, "WellCarpet", Vector3(-1.6, -0.425, 8.6), Vector3(5.9, 0.05, 5.3), _materials["carpet"], false)
	# Bronze nosing around the well lip, which is also the banquette's back edge.
	for edge in [
		["WellNosingFront", Vector3(-1.6, 0.02, 5.92), Vector3(6.04, 0.06, 0.1)],
		["WellNosingRear", Vector3(-1.6, 0.02, 11.28), Vector3(6.04, 0.06, 0.1)],
		["WellNosingPort", Vector3(-4.58, 0.02, 8.6), Vector3(0.1, 0.06, 5.4)],
		["WellNosingStarboard", Vector3(1.38, 0.02, 8.6), Vector3(0.1, 0.06, 5.4)],
	]:
		_box(room, str(edge[0]), edge[1] as Vector3, edge[2] as Vector3, _materials["bronze"], false)

	# Two step runs into the well, each a single 0.225 m riser onto a broad tread
	# and a second onto the well floor. Both stand on the pan.
	for step in [
		["WellStepEntry", Vector3(-1.1, -0.5375, 6.25), Vector3(3.0, 0.625, 0.7)],
		["WellStepPort", Vector3(-4.25, -0.5375, 9.0), Vector3(0.7, 0.625, 2.4)],
	]:
		var tread := _box(room, str(step[0]), step[1] as Vector3, step[2] as Vector3, _materials["pearl_deep"])
		_register_support(tread, &"well entry step", &"well pan")

	# Walls. The port side is solid because it carries the servery and the art
	# wall; the starboard and outboard faces are glazing, built separately.
	_box(room, "PortWallForward", Vector3(-7.1, 1.955, 4.1), Vector3(WALL_THICKNESS, 5.29, 2.2), _materials["pearl"])
	_box(room, "PortWallAft", Vector3(-7.1, 1.955, 13.3), Vector3(WALL_THICKNESS, 5.29, 1.4), _materials["pearl"])
	_box(room, "PortWallLower", Vector3(-7.1, 1.105, 8.9), Vector3(WALL_THICKNESS, 3.59, 7.4), _materials["pearl"])
	_box(room, "PortWallHeader", Vector3(-7.1, 4.2, 8.9), Vector3(WALL_THICKNESS, 0.8, 7.4), _materials["pearl"])
	_box(room, "FrontWallPort", Vector3(-4.775, 1.955, 3.2), Vector3(5.05, 5.29, WALL_THICKNESS), _materials["pearl"])
	_box(room, "FrontWallStarboard", Vector3(3.475, 1.955, 3.2), Vector3(2.45, 5.29, WALL_THICKNESS), _materials["pearl"])
	_box(room, "StarboardWallForward", Vector3(4.5, 1.955, 4.0), Vector3(WALL_THICKNESS, 5.29, 2.0), _materials["pearl"])
	_box(room, "StarboardWallAft", Vector3(4.5, 1.955, 13.25), Vector3(WALL_THICKNESS, 5.29, 1.5), _materials["pearl"])

	# Wall articulation: a lacquer dado, a bronze rail at its head, and pilasters
	# on the port wall. This is what stops a 11 m pearl wall reading as one plane.
	_box(room, "PortDado", Vector3(-6.86, 0.52, 8.5), Vector3(0.09, 1.04, 10.9), _materials["lacquer"], false)
	_box(room, "PortDadoRail", Vector3(-6.84, 1.06, 8.5), Vector3(0.07, 0.05, 10.9), _materials["bronze"], false)
	var pilaster_positions := PackedFloat32Array([4.2, 6.6, 10.6, 13.0])
	for pilaster_index in pilaster_positions.size():
		var pilaster_z := pilaster_positions[pilaster_index]
		# Stopped under the clerestory sill rather than run full height, so the
		# pilasters read as carrying the glazing band instead of crossing it.
		_box(room, "PortPilaster%02d" % (pilaster_index + 1), Vector3(-6.82, 1.5, pilaster_z), Vector3(0.14, 2.86, 0.42), _materials["pearl_deep"], false)
		_box(room, "PortPilasterFillet%02d" % (pilaster_index + 1), Vector3(-6.74, 1.5, pilaster_z), Vector3(0.03, 2.86, 0.1), _materials["bronze"], false)
	_box(room, "FrontDadoPort", Vector3(-4.775, 0.52, 2.96), Vector3(5.05, 1.04, 0.09), _materials["lacquer"], false)
	_box(room, "FrontDadoStarboard", Vector3(3.475, 0.52, 2.96), Vector3(2.45, 1.04, 0.09), _materials["lacquer"], false)

	# Ceiling ring at 4.6, then the lantern upstand and cap at 6.1. The step is
	# what makes the room feel taller in the middle than at its edges without
	# raising the whole shell.
	var ceiling_front := _box(room, "CeilingFront", Vector3(-1.3, 5.0, 4.3), Vector3(12.0, 0.8, 2.6), _materials["pearl"])
	var ceiling_rear := _box(room, "CeilingRear", Vector3(-1.3, 5.0, 13.0), Vector3(12.0, 0.8, 2.8), _materials["pearl"])
	var ceiling_port := _box(room, "CeilingPort", Vector3(-6.1, 5.0, 8.6), Vector3(2.4, 0.8, 6.0), _materials["pearl"])
	var ceiling_starboard := _box(room, "CeilingStarboard", Vector3(3.2, 5.0, 8.6), Vector3(3.0, 0.8, 6.0), _materials["pearl"])
	for slab in [ceiling_front, ceiling_rear, ceiling_port, ceiling_starboard]:
		_register_support(slab, &"roof and lantern upstand", &"reception walls")
	for upstand in [
		["LanternUpstandPort", Vector3(-5.05, 5.75, 8.6), Vector3(0.3, 0.7, 6.0)],
		["LanternUpstandStarboard", Vector3(1.85, 5.75, 8.6), Vector3(0.3, 0.7, 6.0)],
		["LanternUpstandFront", Vector3(-1.6, 5.75, 5.45), Vector3(7.2, 0.7, 0.3)],
		["LanternUpstandRear", Vector3(-1.6, 5.75, 11.75), Vector3(7.2, 0.7, 0.3)],
	]:
		var wall := _box(room, str(upstand[0]), upstand[1] as Vector3, upstand[2] as Vector3, _materials["pearl_deep"])
		_register_support(wall, &"lantern cap", &"ceiling slabs")
	var lantern_cap := _box(room, "LanternCap", Vector3(-1.6, 6.25, 8.6), Vector3(7.2, 0.3, 6.6), _materials["pearl_deep"])
	_register_support(lantern_cap, &"lantern soffit", &"lantern upstands")
	# The lantern's own soffit treatment: a bronze ring and a shallow coffer.
	_box(room, "LanternSoffit", Vector3(-1.6, 6.06, 8.6), Vector3(6.2, 0.08, 5.6), _materials["lacquer"], false)
	for ring in [
		["LanternRingFront", Vector3(-1.6, 6.02, 5.85), Vector3(6.6, 0.06, 0.1)],
		["LanternRingRear", Vector3(-1.6, 6.02, 11.35), Vector3(6.6, 0.06, 0.1)],
		["LanternRingPort", Vector3(-4.85, 6.02, 8.6), Vector3(0.1, 0.06, 5.6)],
		["LanternRingStarboard", Vector3(1.65, 6.02, 8.6), Vector3(0.1, 0.06, 5.6)],
	]:
		_box(room, str(ring[0]), ring[1] as Vector3, ring[2] as Vector3, _materials["bronze"], false)


## The view. This is the thing the working modules do not get: an unbroken
## outboard wall of glass at the end of the station's last arm, with nothing
## between it and open space, plus a starboard bay that looks back across the
## yard to the fleet dock comb.
func _build_outboard_glazing(structure: Node3D) -> void:
	var glazing := Node3D.new()
	glazing.name = "OutboardGlazing"
	structure.add_child(glazing)

	# Outboard bay across the full 11.2 m: sill, header, six mullions, five panes.
	_box(glazing, "OutboardSill", Vector3(-1.3, -0.07, 14.2), Vector3(12.0, 1.24, WALL_THICKNESS), _materials["pearl"])
	_box(glazing, "OutboardSillCap", Vector3(-1.3, 0.58, 14.05), Vector3(11.9, 0.08, 0.62), _materials["bronze"], false)
	_box(glazing, "OutboardHeader", Vector3(-1.3, 4.25, 14.2), Vector3(12.0, 0.7, WALL_THICKNESS), _materials["pearl"])
	for mullion_index in 6:
		var mullion_x := -6.9 + float(mullion_index) * 2.24
		_box(glazing, "OutboardMullion%02d" % (mullion_index + 1), Vector3(mullion_x, 2.225, 14.2), Vector3(0.22, 3.35, 0.42), _materials["pearl_deep"])
		_box(glazing, "OutboardMullionFillet%02d" % (mullion_index + 1), Vector3(mullion_x, 2.225, 13.97), Vector3(0.07, 3.35, 0.05), _materials["bronze"], false)
	for pane_index in 5:
		var pane_x := -5.78 + float(pane_index) * 2.24
		# 2.10 wide against a 2.02 opening, so each sheet is glazed *into* its
		# mullions instead of standing in the gap between them. That defect has a
		# name in this project: OPS-GLAZING-001.
		_register_pane(_box(
			glazing,
			"OutboardPane%02d" % (pane_index + 1),
			Vector3(pane_x, 2.225, 14.19),
			Vector3(2.10, 3.45, 0.1),
			_materials["view_glass"]
		))

	# Port clerestory: a high band over the servery, looking back down the station's
	# flank. It is above head height on purpose — this is the wall a guest has
	# their back to, so it earns its glass as light and silhouette, not as a view
	# to stand at.
	_box(glazing, "ClerestorySill", Vector3(-7.1, 2.75, 8.9), Vector3(WALL_THICKNESS, 0.3, 7.4), _materials["pearl_deep"])
	for mullion_index in 4:
		var clerestory_z := 5.2 + float(mullion_index) * 2.4667
		_box(glazing, "ClerestoryMullion%02d" % (mullion_index + 1), Vector3(-7.1, 3.35, clerestory_z), Vector3(0.42, 0.9, 0.2), _materials["pearl_deep"])
	for pane_index in 3:
		var clerestory_pane_z := 6.4333 + float(pane_index) * 2.4667
		_register_pane(_box(
			glazing,
			"ClerestoryPane%02d" % (pane_index + 1),
			Vector3(-7.09, 3.35, clerestory_pane_z),
			Vector3(0.1, 1.0, 2.35),
			_materials["view_glass"]
		))
	_box(glazing, "ClerestorySillCap", Vector3(-6.94, 2.92, 8.9), Vector3(0.1, 0.06, 7.3), _materials["bronze"], false)

	# Starboard bay, looking back along the station.
	_box(glazing, "StarboardSill", Vector3(4.5, -0.07, 8.75), Vector3(WALL_THICKNESS, 1.24, 7.5), _materials["pearl"])
	_box(glazing, "StarboardSillCap", Vector3(4.35, 0.58, 8.75), Vector3(0.62, 0.08, 7.4), _materials["bronze"], false)
	_box(glazing, "StarboardHeader", Vector3(4.5, 4.25, 8.75), Vector3(WALL_THICKNESS, 0.7, 7.5), _materials["pearl"])
	for mullion_index in 4:
		var mullion_z := 5.0 + float(mullion_index) * 2.5
		_box(glazing, "StarboardMullion%02d" % (mullion_index + 1), Vector3(4.5, 2.225, mullion_z), Vector3(0.42, 3.35, 0.22), _materials["pearl_deep"])
	for pane_index in 3:
		var pane_z := 6.25 + float(pane_index) * 2.5
		_register_pane(_box(
			glazing,
			"StarboardPane%02d" % (pane_index + 1),
			Vector3(4.49, 2.225, pane_z),
			Vector3(0.1, 3.45, 2.36),
			_materials["view_glass"]
		))


## Seating arranged for occupants, not tasks: a curved banquette around the well
## facing the outboard glazing, four loose armchairs, three stools at the
## servery, and a pair of window seats. Nothing in this room faces a console.
func _build_reception_furnishing(structure: Node3D) -> void:
	var fitout := Node3D.new()
	fitout.name = "Fitout"
	structure.add_child(fitout)

	# Banquette: seven segments on a 2.62 m arc centred in the well, sweeping the
	# entry side and both flanks and left open toward the view. Seat height is the
	# perimeter floor level, so the well's edge becomes the seat.
	var arc_centre := Vector3(-1.6, 0.0, 8.75)
	var joint_transforms: Array[Transform3D] = []
	for segment_index in 7:
		var angle := deg_to_rad(lerpf(128.0, 232.0, float(segment_index) / 6.0))
		var offset := Vector3(sin(angle), 0.0, cos(angle)) * 2.62
		_build_banquette_segment(
			fitout,
			segment_index,
			arc_centre + offset,
			rad_to_deg(angle) + 180.0,
			joint_transforms
		)
	_banquette_joint_transforms.assign(joint_transforms)
	_banquette_joint_batch = _multimesh_boxes(
		fitout,
		"BanquetteSegmentJoints",
		Vector3(0.05, 0.4, 0.76),
		_materials["lacquer"],
		_banquette_joint_transforms
	)

	# Low table on the well floor, with an inlaid ring that is the only light
	# source below knee height in the room.
	_cylinder(fitout, "WellTableBase", Vector3(-1.6, -0.34, 8.7), 0.42, 0.22, _materials["bronze"], false)
	var table := _cylinder(fitout, "WellTable", Vector3(-1.6, -0.16, 8.7), 1.05, 0.14, _materials["lacquer"], true)
	_register_support(table, &"table top", &"well floor")
	_cylinder(fitout, "WellTableInlay", Vector3(-1.6, -0.085, 8.7), 0.62, 0.02, _materials["inlay"], false)
	_torus(fitout, "WellTableRing", Vector3(-1.6, -0.09, 8.7), 1.0, 1.08, _materials["bronze"])
	# Lifted off the lens it used to sit 0.2 m above and re-aimed at the seating.
	# A practical that close to its own emissive disc lights nothing but the disc,
	# and photographed as a clipped white plate in the middle of the room.
	_fixture_practical(fitout, "WellTableGlow", Vector3(-1.6, 0.62, 8.7), Color("8fd8dc"), 0.2, 2.8)

	# Four armchairs: two in the well facing the view across the table, two on the
	# starboard glazing as a window pair.
	_build_armchair(fitout, 0, Vector3(-3.35, WELL_FLOOR, 9.9), 118.0)
	_build_armchair(fitout, 1, Vector3(0.15, WELL_FLOOR, 9.9), -118.0)
	_build_armchair(fitout, 2, Vector3(3.0, 0.0, 7.2), -74.0)
	_build_armchair(fitout, 3, Vector3(3.0, 0.0, 10.3), -106.0)
	_cylinder(fitout, "WindowPairTable", Vector3(3.35, 0.28, 8.75), 0.34, 0.56, _materials["bronze"], true)

	# Servery on the port wall: stone counter, lacquer body, a lit niche behind
	# it, and three stools. A bar is the most obviously non-industrial fitting in
	# the station and it is the clearest single signal that this room is for
	# being received in.
	var servery_body := _box(fitout, "ServeryBody", Vector3(-6.35, 0.5, 9.0), Vector3(0.9, 1.0, 4.4), _materials["lacquer"])
	_register_support(servery_body, &"servery counter", &"port floor plate")
	_box(fitout, "ServeryCounter", Vector3(-6.25, 1.03, 9.0), Vector3(1.15, 0.08, 4.6), _materials["stone"], false)
	_box(fitout, "ServeryCounterFillet", Vector3(-5.69, 1.0, 9.0), Vector3(0.05, 0.05, 4.6), _materials["bronze"], false)
	_box(fitout, "ServeryToeRail", Vector3(-5.88, 0.16, 9.0), Vector3(0.06, 0.06, 4.3), _materials["bronze"], false)
	_box(fitout, "ServeryNiche", Vector3(-6.79, 1.95, 9.0), Vector3(0.16, 1.5, 4.2), _materials["lacquer"], false)
	for shelf_index in 3:
		var shelf_y := 1.44 + float(shelf_index) * 0.48
		_box(fitout, "ServeryShelf%02d" % (shelf_index + 1), Vector3(-6.72, shelf_y, 9.0), Vector3(0.28, 0.05, 4.0), _materials["bronze"], false)
		_box(fitout, "ServeryShelfLens%02d" % (shelf_index + 1), Vector3(-6.7, shelf_y - 0.06, 9.0), Vector3(0.03, 0.05, 3.9), _materials["cove_lens"], false)

	for stool_index in 3:
		_build_stool(fitout, stool_index, Vector3(-5.35, 0.0, 7.7 + float(stool_index) * 1.3))

	# Host desk, just inside the room on the starboard side of the entry. Curved,
	# low, and turned toward the door rather than toward a screen.
	var desk := _box(fitout, "HostDesk", Vector3(2.6, 0.5, 4.35), Vector3(2.6, 1.0, 0.8), _materials["lacquer"], true, Vector3(0.0, -16.0, 0.0))
	_register_support(desk, &"host desk", &"front floor plate")
	_box(fitout, "HostDeskTop", Vector3(2.6, 1.03, 4.35), Vector3(2.8, 0.08, 0.98), _materials["stone"], false, Vector3(0.0, -16.0, 0.0))
	_box(fitout, "HostDeskFillet", Vector3(2.6, 0.98, 4.35), Vector3(2.82, 0.05, 1.0), _materials["bronze"], false, Vector3(0.0, -16.0, 0.0))
	_box(fitout, "HostDeskReader", Vector3(2.72, 1.16, 4.5), Vector3(0.5, 0.2, 0.32), _materials["inlay"], false, Vector3(-34.0, -16.0, 0.0))

	# Two light columns flanking the room's entry, and a planter run under the
	# outboard sill. Both are the room's only free-standing vertical objects, so
	# both are seated on the plate beneath them and recorded as such.
	for side in [-1.0, 1.0]:
		var column_x := float(side) * 3.1
		var column := _cylinder(fitout, "LightColumn%s" % ("Port" if side < 0.0 else "Starboard"), Vector3(column_x, 1.6, 3.6), 0.19, 3.2, _materials["smoked_glass"], true)
		_register_support(column, &"light column", &"front floor plate")
		_cylinder(fitout, "LightColumnCore", Vector3(column_x, 1.6, 3.6), 0.09, 3.0, _materials["cove_lens"], false)
		_cylinder(fitout, "LightColumnFoot", Vector3(column_x, 0.06, 3.6), 0.26, 0.12, _materials["bronze"], false)
		_cylinder(fitout, "LightColumnCap", Vector3(column_x, 3.24, 3.6), 0.24, 0.08, _materials["bronze"], false)
		_fixture_practical(fitout, "LightColumnSpill%s" % ("Port" if side < 0.0 else "Starboard"), Vector3(column_x, 1.9, 3.6), Color("ffdcb0"), 0.3, 3.0)
	# A window bench, not the planter run this used to be: photographed from the
	# banquette, the planter's foliage stood as a row of black canisters directly
	# between the seating and the only view in the station. What the sill wants is
	# something low enough to see over and worth sitting on.
	var bench := _box(fitout, "OutboardWindowBench", Vector3(-1.3, 0.21, 13.4), Vector3(8.4, 0.42, 0.66), _materials["lacquer"], true)
	_register_support(bench, &"window bench", &"rear floor plate")
	bench.set_meta("station_seat", true)
	bench.set_meta("seat_class", &"window-bench")
	_seat_nodes.append(bench)
	_box(fitout, "OutboardWindowBenchCushion", Vector3(-1.3, 0.47, 13.4), Vector3(8.3, 0.1, 0.62), _materials["upholstery"], false)
	_box(fitout, "OutboardWindowBenchFillet", Vector3(-1.3, 0.4, 13.08), Vector3(8.4, 0.05, 0.06), _materials["bronze"], false)


func _build_banquette_segment(
		parent: Node3D,
		index: int,
		segment_position: Vector3,
		yaw_degrees: float,
		joint_transforms: Array[Transform3D]
	) -> void:
	var segment := Node3D.new()
	segment.name = "Banquette%02d" % (index + 1)
	segment.position = segment_position
	segment.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	segment.set_meta("station_seat", true)
	segment.set_meta("seat_class", &"banquette")
	parent.add_child(segment)
	_seat_nodes.append(segment)
	# The banquette stands on the lowered well floor while its root remains at
	# reception-floor zero. Its back is local -Z, so the seated frame faces +Z.
	StationSeat.install(
		segment, -0.59, 180.0, 1.05, WELL_FLOOR, "RECEPTION BANQUETTE %02d" % (index + 1)
	)

	var base := _box(segment, "Base", Vector3(0.0, -0.225, 0.0), Vector3(1.05, 0.45, 0.78), _materials["lacquer"])
	_register_support(base, &"banquette seat", &"well floor")
	_box(segment, "Cushion", Vector3(0.0, 0.06, 0.02), Vector3(1.02, 0.14, 0.74), _materials["upholstery"], false)
	_box(segment, "Back", Vector3(0.0, 0.34, -0.34), Vector3(1.02, 0.7, 0.16), _materials["upholstery"], false, Vector3(-9.0, 0.0, 0.0))
	_box(segment, "BackFillet", Vector3(0.0, 0.7, -0.38), Vector3(1.06, 0.06, 0.2), _materials["bronze"], false)
	# Segment joints. Photographed from the entry, seven touching segments read as
	# one continuous tub; a piece of furniture has joints and these are them.
	for side in [-1.0, 1.0]:
		joint_transforms.append(
			segment.transform * Transform3D(
				Basis.IDENTITY,
				Vector3(float(side) * 0.52, -0.16, -0.02)
			)
		)


func _build_armchair(parent: Node3D, index: int, chair_position: Vector3, yaw_degrees: float) -> void:
	var chair := Node3D.new()
	chair.name = "Armchair%02d" % (index + 1)
	chair.position = chair_position
	chair.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	chair.set_meta("station_seat", true)
	chair.set_meta("seat_class", &"armchair")
	parent.add_child(chair)
	_seat_nodes.append(chair)
	StationSeat.install(chair, -0.20, 180.0, 1.05, 0.0, "RECEPTION ARMCHAIR %02d" % (index + 1))

	var pedestal := _cylinder(chair, "Pedestal", Vector3(0.0, 0.05, 0.0), 0.28, 0.1, _materials["bronze"], true)
	_register_support(pedestal, &"armchair", &"floor beneath it")
	_cylinder(chair, "Stem", Vector3(0.0, 0.24, 0.0), 0.1, 0.3, _materials["bronze"], false)
	_box(chair, "Seat", Vector3(0.0, 0.44, 0.0), Vector3(0.72, 0.16, 0.7), _materials["upholstery"], false)
	_box(chair, "Back", Vector3(0.0, 0.75, -0.29), Vector3(0.72, 0.62, 0.14), _materials["upholstery"], false, Vector3(-11.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_box(chair, "Arm", Vector3(float(side) * 0.37, 0.6, -0.02), Vector3(0.09, 0.16, 0.56), _materials["upholstery_dark"], false)
		_beam_between(chair, "ArmStay", Vector3(float(side) * 0.37, 0.44, 0.16), Vector3(float(side) * 0.37, 0.53, 0.16), 0.03, _materials["bronze"], false)


func _build_stool(parent: Node3D, index: int, stool_position: Vector3) -> void:
	var stool := Node3D.new()
	stool.name = "ServeryStool%02d" % (index + 1)
	stool.position = stool_position
	stool.set_meta("station_seat", true)
	stool.set_meta("seat_class", &"stool")
	parent.add_child(stool)
	_seat_nodes.append(stool)

	var foot := _cylinder(stool, "Foot", Vector3(0.0, 0.04, 0.0), 0.24, 0.08, _materials["bronze"], true)
	_register_support(foot, &"servery stool", &"port floor plate")
	_cylinder(stool, "Stem", Vector3(0.0, 0.4, 0.0), 0.07, 0.72, _materials["bronze"], false)
	_cylinder(stool, "Seat", Vector3(0.0, 0.79, 0.0), 0.26, 0.1, _materials["upholstery"], false)
	_torus(stool, "FootRing", Vector3(0.0, 0.26, 0.0), SERVERY_STOOL_FOOT_RING_INNER_RADIUS, SERVERY_STOOL_FOOT_RING_OUTER_RADIUS, _materials["bronze"], Vector3.ZERO, _servery_stool_foot_ring_mesh)


## Lighting the room rather than illuminating it. Every fixture here is a lens
## with a practical behind it: the habitat pass measured that emission alone
## makes a fitting that glows and lights nothing, which is the loudest "not real"
## cue an interior can carry. Twelve practicals, none casting shadows, all
## steeply attenuated and faded out well before the station's far side.
func _build_reception_lighting(structure: Node3D) -> void:
	var lighting := Node3D.new()
	lighting.name = "Lighting"
	structure.add_child(lighting)

	# Lantern cove: four lenses tucked behind the upstand reveal, washing the
	# lantern soffit. This is the room's ambient level and it is entirely
	# indirect — no lamp in the middle of the ceiling.
	_box(lighting, "LanternCoveFront", Vector3(-1.6, 4.72, 5.65), Vector3(6.4, 0.08, 0.1), _materials["cove_lens"], false)
	_box(lighting, "LanternCoveRear", Vector3(-1.6, 4.72, 11.55), Vector3(6.4, 0.08, 0.1), _materials["cove_lens"], false)
	_box(lighting, "LanternCovePort", Vector3(-4.85, 4.72, 8.6), Vector3(0.1, 0.08, 5.6), _materials["cove_lens"], false)
	_box(lighting, "LanternCoveStarboard", Vector3(1.65, 4.72, 8.6), Vector3(0.1, 0.08, 5.6), _materials["cove_lens"], false)
	for cove in [
		["LanternCoveSpillFront", Vector3(-1.6, 5.2, 6.1)],
		["LanternCoveSpillRear", Vector3(-1.6, 5.2, 11.1)],
		["LanternCoveSpillPort", Vector3(-4.4, 5.2, 8.6)],
		["LanternCoveSpillStarboard", Vector3(1.2, 5.2, 8.6)],
	]:
		_fixture_practical(lighting, str(cove[0]), cove[1] as Vector3, Color("ffe2ba"), 0.62, 6.6)

	# Perimeter downlights over the seating ring and the circulation behind it.
	for downlight in [
		["DownlightPortForward", Vector3(-5.6, 4.5, 6.1)],
		["DownlightPortAft", Vector3(-5.6, 4.5, 11.2)],
		["DownlightStarboardForward", Vector3(2.9, 4.5, 6.4)],
		["DownlightStarboardAft", Vector3(2.9, 4.5, 11.0)],
	]:
		var lamp_position := downlight[1] as Vector3
		_cylinder(lighting, "%sHousing" % str(downlight[0]), lamp_position + Vector3(0.0, 0.06, 0.0), 0.16, 0.12, _materials["bronze"], false)
		_cylinder(lighting, "%sLens" % str(downlight[0]), lamp_position, 0.12, 0.03, _materials["cove_lens"], false)
		_fixture_practical(lighting, str(downlight[0]), lamp_position - Vector3(0.0, 0.2, 0.0), Color("ffdcae"), 0.58, 5.4)

	# Sill cove along the outboard glazing. Without it the great window is a black
	# rectangle at night-side and its surround reads as a panel rather than an
	# opening — the exact defect the habitat's rear glazing was fixed for.
	_box(lighting, "OutboardSillCove", Vector3(-1.3, 0.62, 13.86), Vector3(11.4, 0.06, 0.1), _materials["cove_lens"], false)
	# The two original side practicals overlap across the full 11.4 m emissive
	# cove. The former centre omni duplicated their coverage without owning a
	# fixture mesh, collision, cue state, or any other authority.
	for sill_practical in [
		["OutboardSillSpill01", -5.2],
		["OutboardSillSpill03", 2.6],
	]:
		_fixture_practical(
			lighting,
			str(sill_practical[0]),
			Vector3(float(sill_practical[1]), 0.85, 13.7),
			Color("ffe6c4"),
			0.36,
			4.4
		)
	_fixture_practical(lighting, "ServeryNicheSpill", Vector3(-6.6, 1.95, 9.0), Color("ffd7a0"), 0.34, 3.0)
	_fixture_practical(lighting, "HostDeskSpill", Vector3(2.6, 1.7, 4.35), Color("ffe0b6"), 0.28, 2.6)


## Outside. The suite is seen from the aft deck, from the fleet dock connector
## and from every craft on approach, so its shell gets the same cassette-and-rib
## treatment the station's other pressure shells carry, in this module's finish.
func _build_exterior_dressing(structure: Node3D) -> void:
	var exterior := Node3D.new()
	exterior.name = "ExteriorShell"
	structure.add_child(exterior)

	var roof_cassette_transforms: Array[Transform3D] = []
	for cassette_index in ROOF_CASSETTE_COPY_COUNT:
		var cassette_z := 4.0 + float(cassette_index) * 2.2
		roof_cassette_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(-1.3, 5.46, cassette_z))
		)
	_roof_cassette_transforms.assign(roof_cassette_transforms)
	_roof_cassette_batch = _multimesh_boxes(
		exterior,
		"RoofCassettes",
		Vector3(11.6, 0.12, 1.7),
		_materials["pearl_deep"],
		_roof_cassette_transforms
	)
	_beam_between(exterior, "RoofServiceSpine", Vector3(-6.4, 5.58, 3.4), Vector3(-6.4, 5.58, 13.8), 0.11, _materials["graphite"], false)
	for rib_index in 4:
		var rib_z := 4.6 + float(rib_index) * 2.8
		# Stopped at the clerestory sill: run full height they barred the only
		# windows on the station-facing flank.
		_box(exterior, "PortShellRib%02d" % (rib_index + 1), Vector3(-7.36, 1.15, rib_z), Vector3(0.14, 3.5, 0.34), _materials["pearl_deep"], false)
		_box(exterior, "PortShellRibHead%02d" % (rib_index + 1), Vector3(-7.36, 4.2, rib_z), Vector3(0.14, 0.8, 0.34), _materials["pearl_deep"], false)
	_box(exterior, "OutboardFascia", Vector3(-1.3, 5.02, 14.36), Vector3(12.0, 0.72, 0.14), _materials["bronze_panel"], false)
	# The landmark's red, carried outside as a single crown line so the suite is
	# recognisably the same piece of architecture as the door it stands behind.
	_box(exterior, "OutboardCrownLine", Vector3(-1.3, 5.34, 14.4), Vector3(11.6, 0.1, 0.1), _materials["landmark_red"], false)
	for lamp_index in 2:
		var lamp_x := -1.3 + (-5.5 if lamp_index == 0 else 5.5)
		_cylinder(exterior, "OutboardMarkerLamp%02d" % (lamp_index + 1), Vector3(lamp_x, 5.34, 14.36), 0.09, 0.16, _materials["signal"], false)
	# There is deliberately no outboard legend. One was built and then removed: it
	# faced open space, no camera in the game is ever positioned to read it, and it
	# cost 2,761 triangles — which took the scene's lettering share from 4.9% to
	# 5.1% and through the documented ceiling for a sign nobody sees. The landmark
	# facade on the aft deck already carries `VIP RECEPTION // MODERN
	# INTERPRETATION` where a player meets it, and the plinth inside carries the
	# rest.


# --- Registration ----------------------------------------------------------


func _register_support(member: Node3D, carries: StringName, laps: StringName) -> Node3D:
	member.set_meta("station_support_member", true)
	member.set_meta("support_carries", carries)
	member.set_meta("support_laps", laps)
	_support_members.append(member)
	return member


func _register_pane(pane: Node3D) -> Node3D:
	pane.set_meta("station_window_pane", true)
	_glazing_panes.append(pane)
	return pane


# --- Primitive builders ----------------------------------------------------
#
# Deliberately the same shapes as the other station modules: chamfered kit boxes
# and cylinders carrying the registered triplanar panel recipe. A fancier room
# built from raw `BoxMesh` with a flat scalar colour would read as an untextured
# primitive at eye height, which is the opposite of the brief.


## Batches only repeated, visual-only stock. Transforms are in `parent` space;
## semantic seat roots and every solid/colliding piece stay independent nodes.
func _multimesh_boxes(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		material: Material,
		transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _rounded_box_mesh(size)
	multi.instance_count = transforms.size()
	multi.visible_instance_count = -1
	# Author the exact renderer payload in one operation so both the roster and
	# the raw 12-float-per-copy buffer are deterministic and mutation-auditable.
	multi.buffer = _encode_multimesh_transforms(transforms)
	# A raw-buffer-authored MultiMesh has no CPU-side transforms under headless,
	# so publish the exact union explicitly rather than accepting an empty cull box.
	multi.custom_aabb = _transformed_mesh_bounds(multi.mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multi
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _encode_multimesh_transforms(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _transformed_mesh_bounds(
		mesh_bounds: AABB,
		transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	var first := true
	for transform_value in transforms:
		var piece := (transform_value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


func _material(
		color: Color,
		metallic: float,
		roughness: float,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.clearcoat_enabled = true
	result.clearcoat = 0.3
	result.clearcoat_roughness = 0.28
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


## Cloth. The same PBR values without the clearcoat lobe `_material` gives
## everything else: photographed, a clearcoated carpet is a navy mirror with the
## lantern in it, which is the one surface in the room that must not be shiny.
func _matte_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := _material(color, metallic, roughness)
	result.clearcoat_enabled = false
	return result


func _transparent_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := _material(color, metallic, roughness)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return result


func _box(
		parent: Node3D,
		node_name: String,
		box_position: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool = true,
		box_rotation_degrees: Vector3 = Vector3.ZERO
	) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = box_position
	container.rotation_degrees = box_rotation_degrees
	parent.add_child(container)
	var mesh := _rounded_box_mesh(size)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
	return container


func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.18),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.UNIT_PER_QUAD
	)


func _cylinder(
		parent: Node3D,
		node_name: String,
		cylinder_position: Vector3,
		radius: float,
		height: float,
		material: Material,
		collidable: bool,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = MeshInstance3D.new()
	container.name = node_name
	container.position = cylinder_position
	container.rotation_degrees = rotation_degrees_value
	parent.add_child(container)
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(radius, radius, height, 32, _chamfered_cylinder_cache)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
	return container


func _beam_between(
		parent: Node3D,
		node_name: String,
		from: Vector3,
		to: Vector3,
		radius: float,
		material: Material,
		collidable: bool
	) -> Node3D:
	var direction := to - from
	var beam := _cylinder(parent, node_name, (from + to) * 0.5, radius, direction.length(), material, collidable)
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return beam


func _torus(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO,
		shared_mesh: TorusMesh = null
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = torus_position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := shared_mesh
	if mesh == null:
		mesh = TorusMesh.new()
		mesh.inner_radius = inner_radius
		mesh.outer_radius = outer_radius
		mesh.rings = 32
		mesh.ring_segments = 12
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _fixture_practical(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 2.1
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	light.set_meta("localized_practical_light", true)
	light.set_meta("fixture_practical", true)
	parent.add_child(light)
	_practical_lights.append(light)
	return light


func _text_sign(
		parent: Node3D,
		text: String,
		text_position: Vector3,
		text_rotation_degrees: Vector3,
		scale_value: float,
		material: Material
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	instance.position = text_position
	instance.rotation_degrees = text_rotation_degrees
	instance.scale = Vector3.ONE * scale_value
	instance.mesh = SignGeometryBudget.build(text)
	instance.material_override = material
	parent.add_child(instance)
	return instance
