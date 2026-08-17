class_name CinderCargoAccess
extends Node3D

## Standalone physical access module for the modern Cinder Reach cargo landing.
##
## This component deliberately stops at two handoff boundaries: its identity
## transform is a reusable placement slot on the existing extraction-platform
## anchor, and its final route marker is the reserved destination-terminal
## Player-root floor position. A later world owner may compose those pieces; this
## module does not claim that production integration has happened.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-cargo-access"
const CONTENT_STATUS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const BERTH_ID: StringName = &"cinder_cargo_jovian_berth"
const PLACEMENT_SLOT_ID: StringName = &"cinder_reach_cargo_access_slot"
const TERMINAL_SLOT_ID: StringName = &"station_cargo_destination_terminal_slot"

## Mount the component with this transform under the cluster/world root, or with
## identity under CinderReachPlatform. It is a published recommendation, not a
## live production-route or registry claim.
const RECOMMENDED_CLUSTER_TRANSFORM := Transform3D(
	Basis.IDENTITY,
	Vector3(60.0, -70.0, -700.0)
)
const EXTRACTION_PLATFORM_LOCAL_TRANSFORM := Transform3D.IDENTITY
const DESTINATION_TERMINAL_ROOT_LOCAL := Transform3D(
	Basis.IDENTITY,
	Vector3(0.0, 3.8, 14.0)
)
const DESTINATION_TERMINAL_PLAYER_APPROACH_OFFSET := Vector3(0.0, 0.85, 1.1)
const DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL := Vector3(0.0, 4.65, 15.1)

## The Jovian's authored landing contact is 1.25 m below its root. The deck top
## is y=2.90, so this exact dock root gives normal landed contact. A PI yaw turns
## the canonical port ExitPoint toward the connector without changing the
## freighter's collision envelope in berth-local space.
const BERTH_DOCK_LOCAL := Transform3D(
	Basis(Vector3.UP, PI),
	Vector3(-29.0, 4.15, 0.0)
)
const JOVIAN_EXIT_MARKER_LOCAL := Vector3(-4.7, -1.05, -8.2)
const BERTH_ROUTE_X := -24.3
const BERTH_EXIT_LOCAL := Vector3(BERTH_ROUTE_X, 3.1, 8.2)
const BERTH_EXIT_LOCAL_TRANSFORM := Transform3D(
	Basis(Vector3.UP, PI * 0.5),
	BERTH_EXIT_LOCAL
)
const LANDING_HALF_EXTENTS := Vector3(10.6, 4.9, 14.05)
const ASSIST_CAPTURE_CENTER := Vector3(0.0, 3.0, 42.0)
const ASSIST_CAPTURE_HALF_EXTENTS := Vector3(15.0, 18.0, 48.0)
const ASSIST_CAPTURE_MAXIMUM_SPEED := 35.0
const ASSIST_MAXIMUM_TILT_DEGREES := 75.0
const COMPATIBILITY_TAGS: Array[StringName] = [&"light_freighter"]

const LANDING_DECK_TOP := 2.9
const CATWALK_TOP := 3.8
const STAIR_RISE := 0.3
const ROUTE_HALF_WIDTH := 1.2
const ROUTE_IDS: Array[StringName] = [
	&"berth_exit",
	&"stair_top",
	&"cross_turn",
	&"platform_handoff",
	&"destination_terminal_player_approach",
]
const ROUTE_LOCAL_POINTS: Array[Vector3] = [
	BERTH_EXIT_LOCAL,
	Vector3(BERTH_ROUTE_X, LANDING_DECK_TOP, 13.75),
	Vector3(BERTH_ROUTE_X, CATWALK_TOP, 17.8),
	Vector3(-4.0, CATWALK_TOP, 18.0),
	Vector3(-2.4, CATWALK_TOP, 16.7),
	DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL,
]

const LOCAL_BUDGET := {
	"ship_berths": 1,
	"static_bodies": 21,
	"collision_shapes": 21,
	"mesh_instances": 26,
	"marker_nodes": 9,
	"label_nodes": 1,
	"lights": 0,
	"audio_nodes": 0,
	"particle_emitters": 0,
	"animation_players": 0,
	"process_loops": 0,
}
const WALKABLE_SURFACE_COUNT := 11

const DECK_COLOR := Color("495b61")
const STEP_COLOR := Color("61747a")
const RAIL_COLOR := Color("18343e")
const CUE_COLOR := Color("56e0e3")
const HAZARD_COLOR := Color("f6a13b")

## Phase 9 component-local allocation freeze. The first childless, visual-only
## repeated family in authored order is the five route cues. They retain five
## named nodes, five visible copies, two exact material identities, and five
## renderer submissions, while one immutable BoxMesh replaces five identical
## primitive allocations.
const ROUTE_CUE_COUNT := 5
const ROUTE_CUE_SIZE := Vector3(0.42, 0.08, 0.42)
const ROUTE_CUE_NODE_NAMES: Array[String] = [
	"RouteCue1",
	"RouteCue2",
	"RouteCue3",
	"RouteCue4",
	"RouteCue5",
]
const ROUTE_CUE_LEGACY_ALLOCATION := {
	"nodes": 5,
	"visible_copies": 5,
	"renderer_submissions": 5,
	"mesh_resource_allocations": 5,
	"material_resource_allocations": 2,
}
const ROUTE_CUE_CURRENT_ALLOCATION := {
	"nodes": 5,
	"visible_copies": 5,
	"renderer_submissions": 5,
	"mesh_resource_allocations": 1,
	"material_resource_allocations": 2,
}

var _built := false
var _build_generation := 0
var _attachment_generation := 0
var _berth: ShipBerth
var _placement_root: Marker3D
var _terminal_root: Marker3D
var _terminal_approach: Marker3D
var _route_markers: Array[Marker3D] = []
var _materials: Dictionary = {}


func _enter_tree() -> void:
	_attachment_generation += 1


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if _built:
		return
	_built = true
	_build_generation = 1
	_create_materials()
	_build_berth()
	_build_placement_slots()
	_build_structure()
	_build_route_markers_and_cues()
	_tag_authored_tree(self)


func get_berth() -> ShipBerth:
	return _berth


func get_build_generation() -> int:
	return _build_generation


func get_attachment_generation() -> int:
	return _attachment_generation


## Read-only generation guard for a future streaming owner. It owns no loading
## decision; an old attachment snapshot simply fails closed after re-entry.
func get_attachment_snapshot(expected_generation: int) -> Dictionary:
	if expected_generation != _attachment_generation:
		return {
			"accepted": false,
			"reason": &"stale_attachment_generation",
			"expected_generation": expected_generation,
			"attachment_generation": _attachment_generation,
		}.duplicate(true)
	if not is_inside_tree():
		return {
			"accepted": false,
			"reason": &"detached",
			"expected_generation": expected_generation,
			"attachment_generation": _attachment_generation,
		}.duplicate(true)
	return {
		"accepted": true,
		"reason": &"current",
		"expected_generation": expected_generation,
		"attachment_generation": _attachment_generation,
		"component_instance_id": get_instance_id(),
		"berth_instance_id": _berth.get_instance_id() if is_instance_valid(_berth) else 0,
	}.duplicate(true)


func get_route_local_points() -> PackedVector3Array:
	return PackedVector3Array(ROUTE_LOCAL_POINTS)


func get_route_marker(route_id: StringName) -> Marker3D:
	if route_id == &"destination_terminal_player_approach":
		return _terminal_approach
	for marker in _route_markers:
		if marker.get_meta("route_id", &"") == route_id:
			return marker
	return null


func get_route_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route_id in ROUTE_IDS:
		var marker := get_route_marker(route_id)
		if marker == null:
			continue
		result.append({
			"route_id": route_id,
			"local_transform": global_transform.affine_inverse() * marker.global_transform,
			"world_transform": marker.global_transform,
		})
	return result.duplicate(true)


func get_approach_sample_transforms(sample_count: int = 17) -> Array[Transform3D]:
	var bounded_count := clampi(sample_count, 2, 65)
	var dock := global_transform * BERTH_DOCK_LOCAL
	var staging := dock * Transform3D(Basis.IDENTITY, ASSIST_CAPTURE_CENTER)
	var samples: Array[Transform3D] = []
	for index in bounded_count:
		var weight := float(index) / float(bounded_count - 1)
		samples.append(Transform3D(
			dock.basis,
			staging.origin.lerp(dock.origin, weight)
		))
	return samples


func get_placement_snapshot() -> Dictionary:
	var root_local := (
		_placement_root.transform
		if is_instance_valid(_placement_root)
		else EXTRACTION_PLATFORM_LOCAL_TRANSFORM
	)
	var terminal_local := (
		_terminal_root.transform
		if is_instance_valid(_terminal_root)
		else DESTINATION_TERMINAL_ROOT_LOCAL
	)
	var approach_local := (
		_terminal_approach.position
		if is_instance_valid(_terminal_approach)
		else DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"placement_slot_id": PLACEMENT_SLOT_ID,
		"terminal_slot_id": TERMINAL_SLOT_ID,
		"recommended_cluster_transform": RECOMMENDED_CLUSTER_TRANSFORM,
		"extraction_platform_local_transform": root_local,
		"destination_terminal_root_local": terminal_local,
		"destination_terminal_player_approach_local": approach_local,
		"destination_terminal_player_approach_world": global_transform * approach_local,
		"requires_world_owner": true,
		"production_route_claim": false,
		"station_registry_claim": false,
		"streaming_ownership_claim": false,
		"attachment_generation": _attachment_generation,
	}.duplicate(true)


## Headless-safe allocation and renderer-value evidence for the route-cue
## family. Resource identity comes from live Objects; submission count comes
## from bound mesh surfaces and does not require a RenderingServer buffer.
func get_route_cue_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var visible_copy_count := 0
	var childless_count := 0
	var renderer_submission_count := 0
	var authored_transforms := _get_route_cue_authored_transforms()
	var live_transforms: Array[Transform3D] = []
	for cue_index in ROUTE_CUE_COUNT:
		var cue_name := ROUTE_CUE_NODE_NAMES[cue_index]
		var cue := get_node_or_null(
			NodePath("VisualRouteCues/%s" % cue_name)
		) as MeshInstance3D
		if cue == null:
			errors.append("route_cue_node_missing_%s" % cue_name)
			continue
		live_transforms.append(cue.transform)
		if cue.get_child_count() != 0:
			errors.append("route_cue_not_childless_%s" % cue_name)
		else:
			childless_count += 1
		if not cue.transform.is_equal_approx(authored_transforms[cue_index]):
			errors.append("route_cue_transform_drift_%s" % cue_name)
		if not cue.visible:
			errors.append("route_cue_visibility_drift_%s" % cue_name)
		else:
			visible_copy_count += 1
		if cue.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or cue.material_overlay != null or cue.layers != 1 \
			or not is_zero_approx(cue.extra_cull_margin) \
			or not is_zero_approx(cue.visibility_range_begin) \
			or not is_zero_approx(cue.visibility_range_end):
			errors.append("route_cue_renderer_state_drift_%s" % cue_name)
		var mesh := cue.mesh as BoxMesh
		if mesh == null:
			errors.append("route_cue_box_mesh_missing_%s" % cue_name)
		else:
			mesh_resource_ids[mesh.get_instance_id()] = true
			renderer_submission_count += mesh.get_surface_count()
			if not mesh.size.is_equal_approx(ROUTE_CUE_SIZE) \
				or mesh.material != null or mesh.get_surface_count() != 1:
				errors.append("route_cue_mesh_recipe_drift_%s" % cue_name)
		var material := cue.material_override as StandardMaterial3D
		var expected_material := (
			_materials.cue if cue_index % 2 == 0 else _materials.hazard
		) as StandardMaterial3D
		var expected_color := CUE_COLOR if cue_index % 2 == 0 else HAZARD_COLOR
		if material == null:
			errors.append("route_cue_material_missing_%s" % cue_name)
		else:
			material_resource_ids[material.get_instance_id()] = true
			if material != expected_material \
				or not _matches_route_cue_material_recipe(material, expected_color):
				errors.append("route_cue_material_recipe_drift_%s" % cue_name)
	if mesh_resource_ids.size() != 1:
		errors.append("route_cue_mesh_resource_count_drift")
	if material_resource_ids.size() != 2:
		errors.append("route_cue_material_resource_count_drift")
	if visible_copy_count != ROUTE_CUE_COUNT:
		errors.append("route_cue_visible_copy_count_drift")
	if renderer_submission_count != ROUTE_CUE_COUNT:
		errors.append("route_cue_renderer_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"family_id": &"route_cue_boxes",
		"visual_only": childless_count == ROUTE_CUE_COUNT,
		"childless": childless_count == ROUTE_CUE_COUNT,
		"batched": false,
		"immutable_shared_mesh": mesh_resource_ids.size() == 1,
		"authored_node_names": PackedStringArray(ROUTE_CUE_NODE_NAMES),
		"authored_transforms": authored_transforms.duplicate(true),
		"live_transforms": live_transforms.duplicate(true),
		"mesh_size": ROUTE_CUE_SIZE,
		"visible_copy_count": visible_copy_count,
		"renderer_submission_count": renderer_submission_count,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"material_resource_allocations": material_resource_ids.size(),
		"legacy": ROUTE_CUE_LEGACY_ALLOCATION.duplicate(true),
		"current": ROUTE_CUE_CURRENT_ALLOCATION.duplicate(true),
		"mesh_resource_allocation_delta": (
			int(ROUTE_CUE_CURRENT_ALLOCATION.mesh_resource_allocations)
			- int(ROUTE_CUE_LEGACY_ALLOCATION.mesh_resource_allocations)
		),
		"renderer_submission_delta": (
			int(ROUTE_CUE_CURRENT_ALLOCATION.renderer_submissions)
			- int(ROUTE_CUE_LEGACY_ALLOCATION.renderer_submissions)
		),
	}.duplicate(true)


func audit() -> Dictionary:
	var actual_budget := {
		"ship_berths": find_children("*", "ShipBerth", true, false).size(),
		"static_bodies": find_children("*", "StaticBody3D", true, false).size(),
		"collision_shapes": find_children("*", "CollisionShape3D", true, false).size(),
		"mesh_instances": find_children("*", "MeshInstance3D", true, false).size(),
		"marker_nodes": find_children("*", "Marker3D", true, false).size(),
		"label_nodes": find_children("*", "Label3D", true, false).size(),
		"lights": find_children("*", "Light3D", true, false).size(),
		"audio_nodes": find_children("*", "AudioStreamPlayer3D", true, false).size(),
		"particle_emitters": find_children("*", "GPUParticles3D", true, false).size(),
		"animation_players": find_children("*", "AnimationPlayer", true, false).size(),
		"process_loops": 0,
	}
	var errors := _get_contract_errors(actual_budget)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"component_id": COMPONENT_ID,
		"content_status": CONTENT_STATUS,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"build_generation": _build_generation,
		"attachment_generation": _attachment_generation,
		"built": _built,
		"berth_id": BERTH_ID,
		"berth_dock_local": BERTH_DOCK_LOCAL,
		"assist_capture_center": ASSIST_CAPTURE_CENTER,
		"assist_capture_local": BERTH_DOCK_LOCAL * Transform3D(
			Basis.IDENTITY, ASSIST_CAPTURE_CENTER
		),
		"jovian_exit_marker_local": JOVIAN_EXIT_MARKER_LOCAL,
		"berth_exit_local": BERTH_EXIT_LOCAL,
		"berth_exit_local_transform": BERTH_EXIT_LOCAL_TRANSFORM,
		"berth_contract": _berth.audit() if is_instance_valid(_berth) else {},
		"placement": get_placement_snapshot(),
		"route_local_points": get_route_local_points(),
		"route_markers": get_route_snapshot(),
		"maximum_step_rise": STAIR_RISE,
		"local_budget": LOCAL_BUDGET.duplicate(true),
		"actual_budget": actual_budget,
		"budget_exact": actual_budget == LOCAL_BUDGET,
		"route_cue_visual_allocation": get_route_cue_visual_allocation_audit(),
		"cargo_authority": false,
		"inventory_authority": false,
		"reward_authority": false,
		"combat_authority": false,
		"activity_authority": false,
		"save_authority": false,
		"network_authority": false,
		"ui_authority": false,
		"world_placement_authority": false,
		"streaming_authority": false,
		"route_registry_authority": false,
		"ship_control_authority": false,
		"landing_motion_authority": false,
		"owns_physical_berth_lease": true,
		"production_route_claim": false,
	}.duplicate(true)


func _get_contract_errors(actual_budget: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if actual_budget != LOCAL_BUDGET:
		errors.append("local_budget_drift")
	for allocation_error in get_route_cue_visual_allocation_audit().get(
		"errors", PackedStringArray()
	):
		errors.append(String(allocation_error))
	var surface_ids := PackedStringArray()
	for body_node in find_children("*", "StaticBody3D", true, false):
		var body := body_node as StaticBody3D
		var walkable := bool(body.get_meta("walkable_surface", false))
		if walkable:
			var surface_id := StringName(body.get_meta("walkable_surface_id", &""))
			if surface_id.is_empty() or surface_ids.has(surface_id):
				errors.append("walkable_surface_id_%s" % body.name)
			else:
				surface_ids.append(surface_id)
			if body.get_meta("walkable_surface_kind", &"") != &"level":
				errors.append("walkable_surface_kind_%s" % body.name)
			if body.get_meta("walkable_surface_owner", &"") != COMPONENT_ID:
				errors.append("walkable_surface_owner_%s" % body.name)
		elif body.has_meta("walkable_surface_id") \
				or body.has_meta("walkable_surface_kind") \
				or body.has_meta("walkable_surface_owner"):
			errors.append("barrier_surface_identity_%s" % body.name)
	if surface_ids.size() != WALKABLE_SURFACE_COUNT:
		errors.append("walkable_surface_count")
	var platform := get_node_or_null(
		^"Structure/TerminalApproachPlatform"
	) as StaticBody3D
	if platform == null:
		errors.append("terminal_approach_platform_missing")
		return errors
	if platform.collision_layer != PhysicsLayers.WORLD_BODY_LAYER:
		errors.append("terminal_approach_platform_layer")
	var collision := platform.get_node_or_null(^"Collision") as CollisionShape3D
	if collision == null or collision.shape == null:
		errors.append("terminal_approach_platform_collision_missing")
		return errors
	if collision.disabled:
		errors.append("terminal_approach_platform_collision_disabled")
	var shape := collision.shape as BoxShape3D
	if shape == null or not shape.size.is_equal_approx(Vector3(2.4, 0.24, 2.4)):
		errors.append("terminal_approach_platform_collision_size")
	elif not is_equal_approx(platform.position.y + shape.size.y * 0.5, 4.65):
		errors.append("terminal_approach_platform_top")
	return errors


func _build_berth() -> void:
	_berth = ShipBerth.new()
	_berth.name = "JovianCargoBerth"
	_berth.berth_id = BERTH_ID
	_berth.compatibility_tags = PackedStringArray(COMPATIBILITY_TAGS)
	_berth.dock_transform = BERTH_DOCK_LOCAL
	_berth.landing_half_extents = LANDING_HALF_EXTENTS
	_berth.assist_capture_center = ASSIST_CAPTURE_CENTER
	_berth.assist_capture_half_extents = ASSIST_CAPTURE_HALF_EXTENTS
	_berth.assist_capture_maximum_speed = ASSIST_CAPTURE_MAXIMUM_SPEED
	_berth.assist_maximum_tilt_degrees = ASSIST_MAXIMUM_TILT_DEGREES
	add_child(_berth)


func _build_placement_slots() -> void:
	var slots := Node3D.new()
	slots.name = "PlacementSlots"
	add_child(slots)
	_placement_root = _marker(
		slots,
		"ExtractionPlatformRoot",
		EXTRACTION_PLATFORM_LOCAL_TRANSFORM.origin
	)
	_placement_root.set_meta("slot_id", PLACEMENT_SLOT_ID)
	_placement_root.set_meta("recommended_cluster_transform", RECOMMENDED_CLUSTER_TRANSFORM)
	_terminal_root = _marker(
		slots,
		"DestinationTerminalRoot",
		DESTINATION_TERMINAL_ROOT_LOCAL.origin
	)
	_terminal_root.set_meta("slot_id", TERMINAL_SLOT_ID)
	_terminal_approach = _marker(
		slots,
		"DestinationTerminalPlayerApproach",
		DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL
	)
	_terminal_approach.set_meta("player_root_floor_position", true)
	_terminal_approach.set_meta("route_id", &"destination_terminal_player_approach")
	_marker(slots, "DockFinal", BERTH_DOCK_LOCAL.origin).basis = BERTH_DOCK_LOCAL.basis
	_marker(
		slots,
		"ApproachCapture",
		(BERTH_DOCK_LOCAL * Transform3D(Basis.IDENTITY, ASSIST_CAPTURE_CENTER)).origin
	).basis = BERTH_DOCK_LOCAL.basis


func _build_structure() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	_static_box(
		structure,
		"LandingDeck",
		Vector3(-27.825, 2.6, 0.8),
		Vector3(19.05, 0.6, 26.7),
		_materials.deck,
		true
	)
	for step_index in 3:
		var step_number := step_index + 1
		var step_height := STAIR_RISE * float(step_number)
		_static_box(
			structure,
			"ConnectorStep%d" % step_number,
			Vector3(
				BERTH_ROUTE_X,
				LANDING_DECK_TOP + step_height * 0.5,
				14.45 + float(step_index) * 0.6
			),
			Vector3(2.4, step_height, 0.6),
			_materials.step,
			true
		)
	_static_horizontal_segment(
		structure,
		"RiseCatwalk",
		Vector3(BERTH_ROUTE_X, CATWALK_TOP, 15.95),
		Vector3(BERTH_ROUTE_X, CATWALK_TOP, 18.0),
		2.4,
		0.3,
		_materials.deck
	)
	_static_horizontal_segment(
		structure,
		"CrossCatwalk",
		Vector3(BERTH_ROUTE_X, CATWALK_TOP, 18.0),
		Vector3(-4.0, CATWALK_TOP, 18.0),
		2.4,
		0.3,
		_materials.deck
	)
	_static_horizontal_segment(
		structure,
		"TerminalHandoff",
		Vector3(-4.0, CATWALK_TOP, 18.0),
		Vector3(-2.4, CATWALK_TOP, 16.7),
		2.2,
		0.3,
		_materials.deck
	)
	var approach_start := Vector3(-2.4, CATWALK_TOP, 16.7)
	var approach_end := Vector3(
		DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL.x,
		CATWALK_TOP,
		DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL.z
	)
	for approach_step_index in 3:
		var from_weight := float(approach_step_index) / 3.0
		var to_weight := float(approach_step_index + 1) / 3.0
		var step_from := approach_start.lerp(approach_end, from_weight)
		var step_to := approach_start.lerp(approach_end, to_weight)
		var step_height := 0.85 * to_weight
		var step_direction := step_to - step_from
		var approach_step := _static_box(
			structure,
			"TerminalApproachStep%d" % (approach_step_index + 1),
			Vector3(
				(step_from.x + step_to.x) * 0.5,
				CATWALK_TOP + step_height * 0.5,
				(step_from.z + step_to.z) * 0.5
			),
			Vector3(3.0, step_height, step_direction.length() + 0.08),
			_materials.step,
			true
		)
		approach_step.basis = Basis.looking_at(
			step_direction.normalized(), Vector3.UP
		)
	_static_box(
		structure,
		"TerminalApproachPlatform",
		DESTINATION_TERMINAL_PLAYER_APPROACH_LOCAL - Vector3.UP * 0.12,
		Vector3(2.4, 0.24, 2.4),
		_materials.deck,
		true
	)
	for support_side in [-1.0, 1.0]:
		_static_box(
			structure,
			"TerminalApproachSupport%s" % ("Port" if support_side < 0.0 else "Starboard"),
			Vector3(support_side * 0.56, 4.105, 15.1),
			Vector3(0.18, 0.61, 0.18),
			_materials.rail,
			false
		)

	var rails := Node3D.new()
	rails.name = "Rails"
	add_child(rails)
	_static_segment(
		rails, "StairRailPort",
		Vector3(-25.42, 3.72, 14.15), Vector3(-25.42, 4.62, 15.95),
		0.12, _materials.rail
	)
	_static_segment(
		rails, "StairRailStarboard",
		Vector3(-23.18, 3.72, 14.15), Vector3(-23.18, 4.62, 15.95),
		0.12, _materials.rail
	)
	_static_segment(
		rails, "RiseRailPort",
		Vector3(-25.42, 4.62, 15.95), Vector3(-25.42, 4.62, 17.2),
		0.12, _materials.rail
	)
	_static_segment(
		rails, "RiseRailStarboard",
		Vector3(-23.18, 4.62, 15.95), Vector3(-23.18, 4.62, 17.2),
		0.12, _materials.rail
	)
	_static_segment(
		rails, "CrossRailNorth",
		Vector3(-23.1, 4.62, 19.12), Vector3(-5.15, 4.62, 19.12),
		0.12, _materials.rail
	)
	_static_segment(
		rails, "CrossRailSouth",
		Vector3(-23.1, 4.62, 16.88), Vector3(-5.15, 4.62, 16.88),
		0.12, _materials.rail
	)
	var handoff_direction := Vector3(0.9, 0.0, -0.75)
	var handoff_lateral := Vector3(
		-handoff_direction.z, 0.0, handoff_direction.x
	).normalized() * 1.0
	var handoff_start := Vector3(-3.65, 4.62, 17.7)
	var handoff_end := Vector3(-2.75, 4.62, 16.95)
	_static_segment(
		rails, "HandoffRailPort",
		handoff_start + handoff_lateral, handoff_end + handoff_lateral,
		0.12, _materials.rail
	)
	_static_segment(
		rails, "HandoffRailStarboard",
		handoff_start - handoff_lateral, handoff_end - handoff_lateral,
		0.12, _materials.rail
	)


func _build_route_markers_and_cues() -> void:
	var markers := Node3D.new()
	markers.name = "RouteMarkers"
	add_child(markers)
	var marker_specs := [
		{"id": &"berth_exit", "name": "BerthExit", "position": BERTH_EXIT_LOCAL},
		{"id": &"stair_top", "name": "StairTop", "position": Vector3(BERTH_ROUTE_X, CATWALK_TOP, 17.8)},
		{"id": &"cross_turn", "name": "CrossTurn", "position": Vector3(-4.0, CATWALK_TOP, 18.0)},
		{"id": &"platform_handoff", "name": "PlatformHandoff", "position": Vector3(-2.4, CATWALK_TOP, 16.7)},
	]
	for spec in marker_specs:
		var route_marker := _marker(
			markers,
			String(spec.name),
			spec.position as Vector3
		)
		route_marker.set_meta("route_marker", true)
		route_marker.set_meta("route_id", spec.id as StringName)
		route_marker.set_meta("route_index", _route_markers.size())
		if spec.id == &"berth_exit":
			route_marker.transform = BERTH_EXIT_LOCAL_TRANSFORM
		_route_markers.append(route_marker)

	var cues := Node3D.new()
	cues.name = "VisualRouteCues"
	add_child(cues)
	var shared_route_cue_mesh := BoxMesh.new()
	shared_route_cue_mesh.size = ROUTE_CUE_SIZE
	for cue_index in ROUTE_CUE_COUNT:
		var cue_position := ROUTE_LOCAL_POINTS[cue_index]
		cue_position.y += 0.08
		_visual_box(
			cues,
			"RouteCue%d" % (cue_index + 1),
			cue_position,
			ROUTE_CUE_SIZE,
			_materials.cue if cue_index % 2 == 0 else _materials.hazard,
			shared_route_cue_mesh
		)
	var label := Label3D.new()
	label.name = "CargoAccessLabel"
	label.text = "CINDER CARGO ACCESS"
	label.position = Vector3(-14.15, 5.5, 18.0)
	label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	label.font_size = 52
	label.modulate = CUE_COLOR
	label.outline_size = 10
	cues.add_child(label)


func _create_materials() -> void:
	_materials.deck = _material(DECK_COLOR, 0.54, 0.32)
	_materials.step = _material(STEP_COLOR, 0.42, 0.34)
	_materials.rail = _material(RAIL_COLOR, 0.64, 0.25)
	_materials.cue = _emissive_material(CUE_COLOR)
	_materials.hazard = _emissive_material(HAZARD_COLOR)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return material


func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color.darkened(0.46), 0.26, 0.22)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
	return material


func _static_box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		walkable: bool
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	body.collision_mask = PhysicsLayers.WORLD_BODY_MASK
	body.set_meta("walkable_surface", walkable)
	if walkable:
		body.set_meta(
			"walkable_surface_id",
			StringName("cinder_cargo_access_%s" % node_name.to_snake_case())
		)
		body.set_meta("walkable_surface_kind", &"level")
		body.set_meta("walkable_surface_owner", COMPONENT_ID)
	parent.add_child(body)
	var visible := MeshInstance3D.new()
	visible.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	visible.mesh = mesh
	visible.material_override = material
	visible.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visible)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _static_horizontal_segment(
		parent: Node3D,
		node_name: String,
		from_top: Vector3,
		to_top: Vector3,
		width: float,
		thickness: float,
		material: Material
	) -> StaticBody3D:
	var direction := to_top - from_top
	var center := (from_top + to_top) * 0.5 - Vector3.UP * thickness * 0.5
	var body := _static_box(
		parent,
		node_name,
		center,
		Vector3(width, thickness, direction.length()),
		material,
		true
	)
	body.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return body


func _static_segment(
		parent: Node3D,
		node_name: String,
		from_point: Vector3,
		to_point: Vector3,
		thickness: float,
		material: Material
	) -> StaticBody3D:
	var direction := to_point - from_point
	var body := _static_box(
		parent,
		node_name,
		(from_point + to_point) * 0.5,
		Vector3(thickness, thickness, direction.length()),
		material,
		false
	)
	body.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return body


func _visual_box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		shared_mesh: BoxMesh = null
	) -> MeshInstance3D:
	var visible := MeshInstance3D.new()
	visible.name = node_name
	visible.position = position_value
	var mesh := shared_mesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
	visible.mesh = mesh
	visible.material_override = material
	visible.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visible)
	return visible


func _get_route_cue_authored_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for cue_index in ROUTE_CUE_COUNT:
		var cue_position := ROUTE_LOCAL_POINTS[cue_index]
		cue_position.y += 0.08
		transforms.append(Transform3D(Basis.IDENTITY, cue_position))
	return transforms


func _matches_route_cue_material_recipe(
		material: StandardMaterial3D,
		emission_color: Color
	) -> bool:
	return material.albedo_color.is_equal_approx(emission_color.darkened(0.46)) \
		and is_equal_approx(material.metallic, 0.26) \
		and is_equal_approx(material.roughness, 0.22) \
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
		and material.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY \
		and material.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX \
		and material.emission_enabled \
		and material.emission.is_equal_approx(emission_color) \
		and is_equal_approx(material.emission_energy_multiplier, 1.5)


func _marker(parent: Node3D, node_name: String, position_value: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = position_value
	parent.add_child(marker)
	return marker


func _tag_authored_tree(node: Node) -> void:
	node.set_meta("content_status", CONTENT_STATUS)
	node.set_meta("evidence_status", EVIDENCE_STATUS)
	node.set_meta("historically_supported", false)
	for child in node.get_children():
		_tag_authored_tree(child)
