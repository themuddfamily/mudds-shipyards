class_name CinderCargoAccess
extends Node3D

## Physical access module for the modern Cinder Reach cargo landing.
##
## This component deliberately stops at two handoff boundaries: its identity
## transform is a reusable placement slot on the existing extraction-platform
## anchor, and its final route marker is the reserved destination-terminal
## Player-root floor position. A later world owner may compose those pieces; this
## module owns no inventory or transfer authority. NearbySectorCluster now
## production-places this same scene and the real destination terminal at those
## slots; standalone instantiation remains supported for focused validation.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-cargo-access"
const CONTENT_STATUS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const BERTH_ID: StringName = &"cinder_cargo_jovian_berth"
const PLACEMENT_SLOT_ID: StringName = &"cinder_reach_cargo_access_slot"
const TERMINAL_SLOT_ID: StringName = &"station_cargo_destination_terminal_slot"

## Production mounts the component with identity under CinderReachPlatform;
## this equivalent cluster-root transform remains published for standalone
## tooling and focused placement checks.
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
## Match the coarse world-metric plate scale used by the extraction platform
## this access module bolts onto, rather than introducing a station-interior
## texture scale at the streamed Cinder destination.
const PANEL_SURFACE_SCALE := 0.12
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
	"mesh_instances": 15,
	"multimesh_instances": 5,
	"geometry_submissions": 20,
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
const PRESENTATION_STATE_IDS: Array[StringName] = [
	&"unavailable", &"ready", &"carrying", &"at_terminal",
	&"committed", &"stale_rejected", &"reset",
]
const PRESENTATION_NODE_DELTA := 0
const PRESENTATION_LIGHT_DELTA := 0
const PRESENTATION_SUBMISSION_DELTA := 0
const CARGO_ACTIVITY_STATE_IDLE := 0
const CARGO_ACTIVITY_STATE_ACTIVE := 1
const ROUTE_IDENTITY_HEADER := "< JOVIAN PICKUP   |   CARGO DELIVERY >"
const ROUTE_IDENTITY_COPY_COUNT := 3
const ROUTE_IDENTITY_LABEL_LOCAL := Vector3(-14.15, 5.96, 18.99)

## Phase 9 component-local allocation freeze. The five childless, visual-only
## route cues retain their exact authored copy names/anchors. Three additional
## scaled copies build the static cargo-direction fascia from that same immutable
## BoxMesh and two exact material identities. Their presentation-only bases may
## show authoritative cargo state in place. Both families remain in the same two
## renderer nodes/submissions; route markers, collision, interaction and
## component lifecycle remain separate.
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
const ROUTE_CUE_PREBATCH_ALLOCATION := {
	"nodes": 5,
	"visible_copies": 5,
	"renderer_submissions": 5,
	"mesh_resource_allocations": 1,
	"material_resource_allocations": 2,
}
const ROUTE_CUE_CURRENT_ALLOCATION := {
	"nodes": 2,
	"visible_copies": 8,
	"renderer_submissions": 2,
	"mesh_resource_allocations": 1,
	"material_resource_allocations": 2,
}
const TERMINAL_APPROACH_SUPPORT_COUNT := 2
const TERMINAL_APPROACH_SUPPORT_SIZE := Vector3(0.18, 0.61, 0.18)
const TERMINAL_APPROACH_SUPPORT_NODE_NAMES: Array[String] = [
	"TerminalApproachSupportPort",
	"TerminalApproachSupportStarboard",
]
const RISE_RAIL_COUNT := 2
const RISE_RAIL_SIZE := Vector3(0.12, 0.12, 1.25)
const RISE_RAIL_NODE_NAMES: Array[String] = [
	"RiseRailPort",
	"RiseRailStarboard",
]
const CROSS_RAIL_COUNT := 2
const CROSS_RAIL_SIZE := Vector3(0.12, 0.12, 17.95)
const CROSS_RAIL_NODE_NAMES: Array[String] = [
	"CrossRailNorth",
	"CrossRailSouth",
]
const STATIC_BOX_VIEW_COUNT := 21
const STATIC_BOX_MESH_RESOURCE_ALLOCATIONS := 16
const STATIC_BOX_COLLISION_RESOURCE_ALLOCATIONS := 21
const STATIC_BOX_LEGACY_ALLOCATION := {
	"mesh_resource_allocations": 21,
	"collision_resource_allocations": 21,
}
const STATIC_BOX_CURRENT_ALLOCATION := {
	"mesh_resource_allocations": STATIC_BOX_MESH_RESOURCE_ALLOCATIONS,
	"collision_resource_allocations": STATIC_BOX_COLLISION_RESOURCE_ALLOCATIONS,
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
var _static_box_mesh_cache: Dictionary = {}
var _terminal_actor: WeakRef
var _terminal_actor_ship: WeakRef
var _terminal_actor_lease: StringName = &""
var _terminal_actor_attachment_generation := 0
var _cargo_presentation_state: Dictionary = {}
var _cue_presentation_energy := 1.5
var _hazard_presentation_energy := 1.5


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
	if is_queued_for_deletion():
		return {
			"accepted": false,
			"reason": &"queued_for_deletion",
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


## Records only the physical disembark handoff at this occupied berth. It grants
## no cargo capability: the activity binding still validates this exact actor,
## craft, lease and attachment generation before asking cargo authority to act.
func authorize_disembarked_terminal_actor(
		actor: Node3D,
		ship: Node,
		lease_token: StringName,
		expected_attachment_generation: int
	) -> Dictionary:
	var attachment := get_attachment_snapshot(expected_attachment_generation)
	if not bool(attachment.get("accepted", false)):
		return attachment
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return {"accepted": false, "reason": &"invalid_terminal_actor"}
	if (
		not is_instance_valid(ship)
		or _berth.get_occupant() != ship
		or _berth.get_reservation_owner() != ship
		or lease_token.is_empty()
		or _berth.get_reservation_token(ship) != lease_token
	):
		return {"accepted": false, "reason": &"stale_berth_lease"}
	var exit_marker := get_route_marker(&"berth_exit")
	if not is_instance_valid(exit_marker) \
		or actor.global_position.distance_to(exit_marker.global_position) > 2.5:
		return {"accepted": false, "reason": &"actor_not_disembarked_at_berth"}
	_terminal_actor = weakref(actor)
	_terminal_actor_ship = weakref(ship)
	_terminal_actor_lease = lease_token
	_terminal_actor_attachment_generation = expected_attachment_generation
	return {"accepted": true, "reason": &"terminal_actor_authorized"}


func validate_terminal_actor(
		actor: Node,
		ship: Node,
		expected_attachment_generation: int
	) -> Dictionary:
	var attachment := get_attachment_snapshot(expected_attachment_generation)
	if not bool(attachment.get("accepted", false)):
		return attachment
	var authorized_actor: Node = _terminal_actor.get_ref() if _terminal_actor != null else null
	var authorized_ship: Node = (
		_terminal_actor_ship.get_ref() if _terminal_actor_ship != null else null
	)
	if actor != authorized_actor:
		return {"accepted": false, "reason": &"wrong_terminal_actor"}
	if ship != authorized_ship or _berth.get_occupant() != ship:
		return {"accepted": false, "reason": &"wrong_terminal_craft"}
	if (
		_terminal_actor_attachment_generation != expected_attachment_generation
		or _terminal_actor_lease.is_empty()
		or _berth.get_reservation_token(ship) != _terminal_actor_lease
	):
		return {"accepted": false, "reason": &"stale_berth_lease"}
	return {"accepted": true, "reason": &"terminal_actor_current"}


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


## Applies only a detached caller record to the existing two route-cue batches
## and label. Cargo, berth, terminal interaction, and reward state stay external.
func apply_cargo_presentation_snapshot(snapshot: Dictionary) -> Dictionary:
	if StringName(snapshot.get("component_id", &"")) != COMPONENT_ID:
		return {"accepted": false, "reason": &"wrong_cargo_access_component"}
	if int(snapshot.get("attachment_generation", -1)) != _attachment_generation:
		return {"accepted": false, "reason": &"stale_attachment_generation"}
	var state_id := StringName(snapshot.get("state_id", &""))
	if state_id not in PRESENTATION_STATE_IDS:
		return {"accepted": false, "reason": &"invalid_cargo_presentation_state"}
	var cue_energy := 1.5
	var hazard_energy := 1.5
	var status_text := "CINDER CARGO — READY"
	var label_color := CUE_COLOR
	var geometry_state: StringName = &"pickup_ready"
	var geometry_scale := Vector3(2.5, 6.0, 2.5)
	var geometry_turn_degrees := 0.0
	var urgency_id: StringName = &"normal"
	var activity := snapshot.get("activity", {}) as Dictionary
	var activity_state := int(activity.get("state", CARGO_ACTIVITY_STATE_IDLE))
	var phase_index := maxi(0, int(activity.get("next_phase_index", 0)))
	var deadline := maxf(0.0, float(activity.get("deadline_seconds", 0.0)))
	var remaining := clampf(
		float(activity.get("deadline_remaining_seconds", deadline)), 0.0, deadline
	)
	var deadline_fraction := remaining / deadline if deadline > 0.0 else 1.0
	match state_id:
		&"unavailable":
			cue_energy = 0.18
			hazard_energy = 0.18
			status_text = "CINDER CARGO — BERTH REQUIRED"
			label_color = HAZARD_COLOR.darkened(0.35)
			geometry_state = &"unavailable"
			geometry_scale = Vector3.ONE
		&"ready":
			geometry_state = &"pickup_ready"
		&"carrying":
			cue_energy = 2.6
			hazard_energy = 0.65
			status_text = "CINDER CARGO — FOLLOW ROUTE"
			if activity_state == CARGO_ACTIVITY_STATE_ACTIVE and phase_index == 0:
				geometry_state = &"pickup"
				geometry_scale = Vector3(2.5, 6.0, 2.5)
			else:
				geometry_state = &"carrying"
				geometry_scale = Vector3(4.0, 1.0, 1.0)
			if deadline_fraction <= 0.10:
				urgency_id = &"critical"
				geometry_state = &"carrying_critical"
				geometry_scale = Vector3(5.0, 0.5, 5.0)
				geometry_turn_degrees = 45.0
			elif deadline_fraction <= 0.25:
				urgency_id = &"warning"
				geometry_state = &"carrying_warning"
				geometry_scale = Vector3(1.5, 5.0, 1.5)
				geometry_turn_degrees = 30.0
		&"at_terminal":
			cue_energy = 3.2
			hazard_energy = 1.1
			status_text = "CINDER CARGO — TERMINAL READY"
			geometry_state = &"delivery_ready"
			geometry_scale = Vector3(4.0, 4.0, 4.0)
		&"committed":
			cue_energy = 3.0
			hazard_energy = 3.0
			status_text = "CINDER CARGO — TRANSFER COMMITTED"
			geometry_state = &"delivered"
			geometry_scale = Vector3(7.0, 0.35, 7.0)
		&"stale_rejected":
			cue_energy = 0.15
			hazard_energy = 3.4
			status_text = "CINDER CARGO — REQUEST REJECTED"
			label_color = HAZARD_COLOR
			geometry_state = &"failed"
			geometry_scale = Vector3(1.0, 7.0, 1.0)
			geometry_turn_degrees = 45.0
		&"reset":
			cue_energy = 0.25
			hazard_energy = 0.25
			status_text = "CINDER CARGO — RESET"
			label_color = HAZARD_COLOR.darkened(0.25)
			geometry_state = &"reset"
			geometry_scale = Vector3.ONE
		_:
			pass
	_cue_presentation_energy = cue_energy
	_hazard_presentation_energy = hazard_energy
	(_materials.cue as StandardMaterial3D).emission_energy_multiplier = cue_energy
	(_materials.hazard as StandardMaterial3D).emission_energy_multiplier = hazard_energy
	var label := get_node_or_null(^"VisualRouteCues/CargoAccessLabel") as Label3D
	if label == null:
		return {"accepted": false, "reason": &"cargo_route_presentation_missing"}
	var label_text := "%s\n%s" % [ROUTE_IDENTITY_HEADER, status_text]
	label.text = label_text
	label.modulate = label_color
	_apply_route_cue_geometry(geometry_scale, geometry_turn_degrees)
	_cargo_presentation_state = snapshot.duplicate(true)
	_cargo_presentation_state.merge({
		"cue_energy": cue_energy,
		"hazard_energy": hazard_energy,
		"label_text": label_text,
		"geometry_state": geometry_state,
		"geometry_scale": geometry_scale,
		"geometry_turn_degrees": geometry_turn_degrees,
		"urgency_id": urgency_id,
		"deadline_fraction": deadline_fraction,
		"cargo_phase_index": phase_index,
		"static_geometry_only": true,
		"node_delta": PRESENTATION_NODE_DELTA,
		"light_delta": PRESENTATION_LIGHT_DELTA,
		"submission_delta": PRESENTATION_SUBMISSION_DELTA,
		"inventory_authority": false,
		"reward_authority": false,
		"interaction_authority": false,
	}, true)
	return {"accepted": true, "reason": &"cargo_route_presentation_applied"}


func get_cargo_presentation_state() -> Dictionary:
	return _cargo_presentation_state.duplicate(true)


func _apply_route_cue_geometry(scale_value: Vector3, turn_degrees: float) -> void:
	var authored := _get_route_cue_authored_transforms()
	var presentation := _get_route_cue_presentation_transforms(
		authored, scale_value, turn_degrees
	)
	var batch_specs := [
		{"name": "RouteCueCyanBatch", "indices": PackedInt32Array([0, 2, 4]), "cyan": true},
		{"name": "RouteCueHazardBatch", "indices": PackedInt32Array([1, 3]), "cyan": false},
	]
	for spec in batch_specs:
		var batch := get_node_or_null(
			NodePath("VisualRouteCues/%s" % String(spec.name))
		) as MultiMeshInstance3D
		if batch == null or batch.multimesh == null:
			continue
		var transforms := _compose_route_cue_batch_transforms(
			presentation, bool(spec.cyan)
		)
		batch.multimesh.buffer = _encode_multimesh_transforms(transforms)
		var mesh := batch.multimesh.mesh as BoxMesh
		if mesh != null:
			batch.multimesh.custom_aabb = _transformed_bounds(mesh.get_aabb(), transforms)


func _get_route_cue_presentation_transforms(
		authored: Array[Transform3D],
		scale_value: Vector3 = Vector3.ONE,
		turn_degrees: float = 0.0
	) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for cue_index in authored.size():
		var source := authored[cue_index]
		var turn_sign := -1.0 if cue_index % 2 == 0 else 1.0
		var presentation_basis := source.basis.rotated(
			Vector3.FORWARD, deg_to_rad(turn_degrees * turn_sign)
		).scaled(scale_value)
		result.append(Transform3D(presentation_basis, source.origin))
	return result


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
	var production_placed := _is_production_placed()
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
		"requires_world_owner": not production_placed,
		"production_route_claim": production_placed,
		"station_registry_claim": false,
		"streaming_ownership_claim": production_placed,
		"attachment_generation": _attachment_generation,
	}.duplicate(true)


## Headless-safe allocation and renderer-value evidence for the route-cue
## family. Resource identity comes from live Objects; authored anchors and the
## current authoritative presentation transforms are checked against the raw
## renderer buffer.
func get_route_cue_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var visible_copy_count := 0
	var childless_count := 0
	var renderer_submission_count := 0
	var authored_transforms := _get_route_cue_authored_transforms()
	var presentation_scale := (
		_cargo_presentation_state.get("geometry_scale", Vector3.ONE) as Vector3
	)
	var presentation_turn := float(
		_cargo_presentation_state.get("geometry_turn_degrees", 0.0)
	)
	var presentation_transforms := _get_route_cue_presentation_transforms(
		authored_transforms, presentation_scale, presentation_turn
	)
	var live_transforms: Array[Transform3D] = []
	live_transforms.resize(ROUTE_CUE_COUNT)
	var batch_specs := [
		{
			"name": "RouteCueCyanBatch",
			"indices": PackedInt32Array([0, 2, 4]),
			"cyan": true,
			"material": _materials.cue,
			"color": CUE_COLOR,
		},
		{
			"name": "RouteCueHazardBatch",
			"indices": PackedInt32Array([1, 3]),
			"cyan": false,
			"material": _materials.hazard,
			"color": HAZARD_COLOR,
		},
	]
	for spec in batch_specs:
		var batch := get_node_or_null(
			NodePath("VisualRouteCues/%s" % String(spec.name))
		) as MultiMeshInstance3D
		if batch == null or batch.multimesh == null:
			errors.append("route_cue_batch_missing_%s" % String(spec.name))
			continue
		if batch.get_child_count() != 0:
			errors.append("route_cue_batch_not_childless_%s" % String(spec.name))
		else:
			childless_count += 1
		if (
			not batch.transform.is_equal_approx(Transform3D.IDENTITY)
			or batch.get_script() != null
			or not batch.get_groups().is_empty()
			or batch.is_processing()
			or batch.is_physics_processing()
			or not bool(batch.get_meta("presentation_only", false))
			or bool(batch.get_meta("collision_authority", true))
			or bool(batch.get_meta("interaction_authority", true))
		):
			errors.append("route_cue_batch_authority_or_lifecycle_drift_%s" % String(spec.name))
		var indices := spec.indices as PackedInt32Array
		var expected_batch_transforms := _compose_route_cue_batch_transforms(
			presentation_transforms, bool(spec.cyan)
		)
		if batch.multimesh.instance_count != expected_batch_transforms.size() \
			or batch.multimesh.visible_instance_count != expected_batch_transforms.size():
			errors.append("route_cue_batch_copy_count_drift_%s" % String(spec.name))
		if not batch.visible:
			errors.append("route_cue_batch_visibility_drift_%s" % String(spec.name))
		else:
			visible_copy_count += batch.multimesh.visible_instance_count
		if batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.material_overlay != null or batch.layers != 1 \
			or not is_zero_approx(batch.extra_cull_margin) \
			or not is_zero_approx(batch.visibility_range_begin) \
			or not is_zero_approx(batch.visibility_range_end):
			errors.append("route_cue_renderer_state_drift_%s" % String(spec.name))
		var mesh := batch.multimesh.mesh as BoxMesh
		if mesh == null:
			errors.append("route_cue_box_mesh_missing_%s" % String(spec.name))
		else:
			mesh_resource_ids[mesh.get_instance_id()] = true
			renderer_submission_count += mesh.get_surface_count()
			if not mesh.size.is_equal_approx(ROUTE_CUE_SIZE) \
				or mesh.material != null or mesh.get_surface_count() != 1:
				errors.append("route_cue_mesh_recipe_drift_%s" % String(spec.name))
		var material := batch.material_override as StandardMaterial3D
		if material != null:
			material_resource_ids[material.get_instance_id()] = true
		if material == null or material != spec.material \
			or not _matches_route_cue_material_recipe(material, spec.color as Color):
			errors.append("route_cue_material_recipe_drift_%s" % String(spec.name))
		var batch_authored := batch.get_meta("authored_instance_transforms", []) as Array
		for cue_index in indices:
			live_transforms[cue_index] = presentation_transforms[cue_index]
		if batch.multimesh.buffer != _encode_multimesh_transforms(expected_batch_transforms):
			errors.append("route_cue_transform_buffer_drift_%s" % String(spec.name))
		var expected_authored_batch := _compose_route_cue_batch_transforms(
			authored_transforms, bool(spec.cyan)
		)
		if batch_authored.size() != expected_authored_batch.size():
			errors.append("route_cue_authored_transform_count_drift_%s" % String(spec.name))
		for instance_index in mini(expected_authored_batch.size(), batch_authored.size()):
			if not batch_authored[instance_index] is Transform3D:
				errors.append("route_cue_transform_type_drift_%s_%d" % [String(spec.name), instance_index])
				continue
			var authored_transform := batch_authored[instance_index] as Transform3D
			var expected_authored := expected_authored_batch[instance_index]
			if not authored_transform.is_equal_approx(expected_authored):
				errors.append("route_cue_transform_drift_%s_%d" % [String(spec.name), instance_index])
		if mesh != null and not batch.multimesh.custom_aabb.is_equal_approx(
			_transformed_bounds(mesh.get_aabb(), expected_batch_transforms)
		):
			errors.append("route_cue_culling_bounds_drift_%s" % String(spec.name))
	if mesh_resource_ids.size() != 1:
		errors.append("route_cue_mesh_resource_count_drift")
	if material_resource_ids.size() != 2:
		errors.append("route_cue_material_resource_count_drift")
	if visible_copy_count != ROUTE_CUE_COUNT + ROUTE_IDENTITY_COPY_COUNT:
		errors.append("route_cue_visible_copy_count_drift")
	if renderer_submission_count != 2:
		errors.append("route_cue_renderer_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"family_id": &"route_cue_boxes",
		"visual_only": childless_count == 2,
		"childless": childless_count == 2,
		"batched": true,
		"immutable_shared_mesh": mesh_resource_ids.size() == 1,
		"authored_node_names": PackedStringArray(ROUTE_CUE_NODE_NAMES),
		"batch_node_names": PackedStringArray(["RouteCueCyanBatch", "RouteCueHazardBatch"]),
		"authored_transforms": authored_transforms.duplicate(true),
		"live_transforms": live_transforms.duplicate(true),
		"mesh_size": ROUTE_CUE_SIZE,
		"visible_copy_count": visible_copy_count,
		"renderer_submission_count": renderer_submission_count,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"material_resource_allocations": material_resource_ids.size(),
		"legacy": ROUTE_CUE_LEGACY_ALLOCATION.duplicate(true),
		"before": ROUTE_CUE_PREBATCH_ALLOCATION.duplicate(true),
		"current": ROUTE_CUE_CURRENT_ALLOCATION.duplicate(true),
		"mesh_resource_allocation_delta": (
			int(ROUTE_CUE_CURRENT_ALLOCATION.mesh_resource_allocations)
			- int(ROUTE_CUE_PREBATCH_ALLOCATION.mesh_resource_allocations)
		),
		"renderer_submission_delta": (
			int(ROUTE_CUE_CURRENT_ALLOCATION.renderer_submissions)
			- int(ROUTE_CUE_PREBATCH_ALLOCATION.renderer_submissions)
		),
		"node_delta": int(ROUTE_CUE_CURRENT_ALLOCATION.nodes) - int(ROUTE_CUE_PREBATCH_ALLOCATION.nodes),
	}.duplicate(true)


## Static bodies retain their independent BoxShape3D resources. Only exact
## visual BoxMesh recipes are shared, preserving every collision owner and
## renderer node while avoiding duplicate immutable surface allocations.
func get_static_box_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var collision_resource_ids := {}
	var ordinary_views := 0
	for body_node in find_children("*", "StaticBody3D", true, false):
		var body := body_node as StaticBody3D
		var view := body.get_node_or_null(^"Mesh") as MeshInstance3D
		var mesh := view.mesh as BoxMesh if view != null else null
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if mesh == null and body.name not in TERMINAL_APPROACH_SUPPORT_NODE_NAMES \
		and body.name not in RISE_RAIL_NODE_NAMES \
			and body.name not in CROSS_RAIL_NODE_NAMES:
			errors.append("static_box_mesh_missing_%s" % body.name)
		elif mesh != null:
			ordinary_views += 1
			mesh_resource_ids[mesh.get_instance_id()] = true
		if shape == null:
			errors.append("static_box_collision_missing_%s" % body.name)
		else:
			collision_resource_ids[shape.get_instance_id()] = true
	var support_audit := get_terminal_approach_support_visual_audit()
	for support_error in support_audit.errors:
		errors.append(String(support_error))
	var support_batch := get_node_or_null(
		^"Structure/TerminalApproachSupportBatch"
	) as MultiMeshInstance3D
	var support_mesh := (
		support_batch.multimesh.mesh as BoxMesh
		if support_batch != null and support_batch.multimesh != null else null
	)
	if support_mesh != null:
		mesh_resource_ids[support_mesh.get_instance_id()] = true
	var rise_rail_audit := get_rise_rail_visual_audit()
	for rise_rail_error in rise_rail_audit.errors:
		errors.append(String(rise_rail_error))
	var rise_rail_batch := get_node_or_null(^"Rails/RiseRailBatch") as MultiMeshInstance3D
	var rise_rail_mesh := (
		rise_rail_batch.multimesh.mesh as BoxMesh
		if rise_rail_batch != null and rise_rail_batch.multimesh != null else null
	)
	if rise_rail_mesh != null:
		mesh_resource_ids[rise_rail_mesh.get_instance_id()] = true
	var cross_rail_audit := get_cross_rail_visual_audit()
	for cross_rail_error in cross_rail_audit.errors:
		errors.append(String(cross_rail_error))
	var cross_rail_batch := get_node_or_null(^"Rails/CrossRailBatch") as MultiMeshInstance3D
	var cross_rail_mesh := (
		cross_rail_batch.multimesh.mesh as BoxMesh
		if cross_rail_batch != null and cross_rail_batch.multimesh != null else null
	)
	if cross_rail_mesh != null:
		mesh_resource_ids[cross_rail_mesh.get_instance_id()] = true
	var views := ordinary_views + int(support_audit.visible_copy_count) \
		+ int(rise_rail_audit.visible_copy_count) + int(cross_rail_audit.visible_copy_count)
	if views != STATIC_BOX_VIEW_COUNT or ordinary_views != 15:
		errors.append("static_box_view_count_drift")
	if mesh_resource_ids.size() != STATIC_BOX_MESH_RESOURCE_ALLOCATIONS:
		errors.append("static_box_mesh_resource_count_drift")
	if collision_resource_ids.size() != STATIC_BOX_COLLISION_RESOURCE_ALLOCATIONS:
		errors.append("static_box_collision_resource_count_drift")
	if _static_box_mesh_cache.size() != STATIC_BOX_MESH_RESOURCE_ALLOCATIONS:
		errors.append("static_box_cache_recipe_count_drift")
	_validate_shared_static_box_family(
		[^"Rails/StairRailPort", ^"Rails/StairRailStarboard"], errors
	)
	_validate_shared_static_box_family(
		[^"Rails/HandoffRailPort", ^"Rails/HandoffRailStarboard"], errors
	)
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"view_count": views,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"collision_resource_allocations": collision_resource_ids.size(),
		"legacy": STATIC_BOX_LEGACY_ALLOCATION.duplicate(true),
		"current": STATIC_BOX_CURRENT_ALLOCATION.duplicate(true),
		"mesh_resource_allocation_delta": (
			STATIC_BOX_MESH_RESOURCE_ALLOCATIONS
			- int(STATIC_BOX_LEGACY_ALLOCATION.mesh_resource_allocations)
		),
	}.duplicate(true)


## The support bodies keep their authored names, transforms, and private
## collision shapes. Only their identical childless rail-box renderers are
## represented by this structure-local batch.
func get_terminal_approach_support_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	for support_name in TERMINAL_APPROACH_SUPPORT_NODE_NAMES:
		var body := get_node_or_null(
			NodePath("Structure/%s" % support_name)
		) as StaticBody3D
		if body == null:
			errors.append("terminal_approach_support_body_missing_%s" % support_name)
			continue
		if body.get_node_or_null(^"Mesh") != null:
			errors.append("terminal_approach_support_legacy_renderer_%s" % support_name)
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape == null or not shape.size.is_equal_approx(TERMINAL_APPROACH_SUPPORT_SIZE):
			errors.append("terminal_approach_support_collision_drift_%s" % support_name)
		expected_transforms.append(body.transform)
	var batch := get_node_or_null(
		^"Structure/TerminalApproachSupportBatch"
	) as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		errors.append("terminal_approach_support_batch_missing")
		return {
			"valid": false,
			"errors": errors,
			"visible_copy_count": 0,
		}.duplicate(true)
	var mesh := batch.multimesh.mesh as BoxMesh
	if mesh == null or not mesh.size.is_equal_approx(TERMINAL_APPROACH_SUPPORT_SIZE) \
			or mesh.material != null or mesh.get_surface_count() != 1:
		errors.append("terminal_approach_support_mesh_recipe_drift")
	if batch.material_override != _materials.service \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.material_overlay != null or batch.layers != 1 \
			or not is_zero_approx(batch.extra_cull_margin) \
			or not is_zero_approx(batch.visibility_range_begin) \
			or not is_zero_approx(batch.visibility_range_end):
		errors.append("terminal_approach_support_renderer_state_drift")
	if batch.get_child_count() != 0 or batch.get_script() != null \
			or not bool(batch.get_meta("presentation_only", false)) \
			or bool(batch.get_meta("collision_authority", true)) \
			or bool(batch.get_meta("interaction_authority", true)):
		errors.append("terminal_approach_support_authority_drift")
	if batch.multimesh.instance_count != TERMINAL_APPROACH_SUPPORT_COUNT \
			or batch.multimesh.visible_instance_count != TERMINAL_APPROACH_SUPPORT_COUNT:
		errors.append("terminal_approach_support_copy_count_drift")
	if batch.multimesh.buffer != _encode_multimesh_transforms(expected_transforms):
		errors.append("terminal_approach_support_transform_buffer_drift")
	if mesh != null and not batch.multimesh.custom_aabb.is_equal_approx(
		_transformed_bounds(mesh.get_aabb(), expected_transforms)
	):
		errors.append("terminal_approach_support_culling_bounds_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family_id": &"terminal_approach_support_boxes",
		"body_node_names": TERMINAL_APPROACH_SUPPORT_NODE_NAMES.duplicate(),
		"authored_transforms": expected_transforms.duplicate(true),
		"visible_copy_count": batch.multimesh.visible_instance_count,
		"renderer_submissions": mesh.get_surface_count() if mesh != null else 0,
		"before_renderer_submissions": TERMINAL_APPROACH_SUPPORT_COUNT,
		"renderer_submission_delta": 1 - TERMINAL_APPROACH_SUPPORT_COUNT,
		"collision_shape_count": TERMINAL_APPROACH_SUPPORT_COUNT,
	}.duplicate(true)


## The paired rise-rail bodies keep their authored names, transforms, and
## private collision shapes. Their identical immutable frame renderers share
## one rail-local batch without assuming traversal or interaction authority.
func get_rise_rail_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	for rail_name in RISE_RAIL_NODE_NAMES:
		var body := get_node_or_null(NodePath("Rails/%s" % rail_name)) as StaticBody3D
		if body == null:
			errors.append("rise_rail_body_missing_%s" % rail_name)
			continue
		if body.get_node_or_null(^"Mesh") != null:
			errors.append("rise_rail_legacy_renderer_%s" % rail_name)
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape == null or not shape.size.is_equal_approx(RISE_RAIL_SIZE):
			errors.append("rise_rail_collision_drift_%s" % rail_name)
		expected_transforms.append(body.transform)
	var batch := get_node_or_null(^"Rails/RiseRailBatch") as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		errors.append("rise_rail_batch_missing")
		return {
			"valid": false,
			"errors": errors,
			"visible_copy_count": 0,
		}.duplicate(true)
	var mesh := batch.multimesh.mesh as BoxMesh
	if mesh == null or not mesh.size.is_equal_approx(RISE_RAIL_SIZE) \
			or mesh.material != null or mesh.get_surface_count() != 1:
		errors.append("rise_rail_mesh_recipe_drift")
	if batch.material_override != _materials.frame \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.material_overlay != null or batch.layers != 1 \
			or not is_zero_approx(batch.extra_cull_margin) \
			or not is_zero_approx(batch.visibility_range_begin) \
			or not is_zero_approx(batch.visibility_range_end):
		errors.append("rise_rail_renderer_state_drift")
	if batch.get_child_count() != 0 or batch.get_script() != null \
			or not bool(batch.get_meta("presentation_only", false)) \
			or bool(batch.get_meta("collision_authority", true)) \
			or bool(batch.get_meta("interaction_authority", true)):
		errors.append("rise_rail_authority_drift")
	if batch.multimesh.instance_count != RISE_RAIL_COUNT \
			or batch.multimesh.visible_instance_count != RISE_RAIL_COUNT:
		errors.append("rise_rail_copy_count_drift")
	if batch.multimesh.buffer != _encode_multimesh_transforms(expected_transforms):
		errors.append("rise_rail_transform_buffer_drift")
	if mesh != null and not batch.multimesh.custom_aabb.is_equal_approx(
		_transformed_bounds(mesh.get_aabb(), expected_transforms)
	):
		errors.append("rise_rail_culling_bounds_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family_id": &"rise_rail_boxes",
		"body_node_names": RISE_RAIL_NODE_NAMES.duplicate(),
		"authored_transforms": expected_transforms.duplicate(true),
		"visible_copy_count": batch.multimesh.visible_instance_count,
		"renderer_submissions": mesh.get_surface_count() if mesh != null else 0,
		"before_renderer_submissions": RISE_RAIL_COUNT,
		"renderer_submission_delta": 1 - RISE_RAIL_COUNT,
		"collision_shape_count": RISE_RAIL_COUNT,
	}.duplicate(true)


## The cross-catwalk rails retain named collision owners and private shapes.
## Their matching, static frame visuals share one childless renderer batch.
func get_cross_rail_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	for rail_name in CROSS_RAIL_NODE_NAMES:
		var body := get_node_or_null(NodePath("Rails/%s" % rail_name)) as StaticBody3D
		if body == null:
			errors.append("cross_rail_body_missing_%s" % rail_name)
			continue
		if body.get_node_or_null(^"Mesh") != null:
			errors.append("cross_rail_legacy_renderer_%s" % rail_name)
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape == null or not shape.size.is_equal_approx(CROSS_RAIL_SIZE):
			errors.append("cross_rail_collision_drift_%s" % rail_name)
		expected_transforms.append(body.transform)
	var batch := get_node_or_null(^"Rails/CrossRailBatch") as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		errors.append("cross_rail_batch_missing")
		return {"valid": false, "errors": errors, "visible_copy_count": 0}.duplicate(true)
	var mesh := batch.multimesh.mesh as BoxMesh
	if mesh == null or not mesh.size.is_equal_approx(CROSS_RAIL_SIZE) \
			or mesh.material != null or mesh.get_surface_count() != 1:
		errors.append("cross_rail_mesh_recipe_drift")
	if batch.material_override != _materials.frame \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			or batch.material_overlay != null or batch.layers != 1 \
			or not is_zero_approx(batch.extra_cull_margin) \
			or not is_zero_approx(batch.visibility_range_begin) \
			or not is_zero_approx(batch.visibility_range_end):
		errors.append("cross_rail_renderer_state_drift")
	if batch.get_child_count() != 0 or batch.get_script() != null \
			or not bool(batch.get_meta("presentation_only", false)) \
			or bool(batch.get_meta("collision_authority", true)) \
			or bool(batch.get_meta("interaction_authority", true)):
		errors.append("cross_rail_authority_drift")
	if batch.multimesh.instance_count != CROSS_RAIL_COUNT \
			or batch.multimesh.visible_instance_count != CROSS_RAIL_COUNT:
		errors.append("cross_rail_copy_count_drift")
	if batch.multimesh.buffer != _encode_multimesh_transforms(expected_transforms):
		errors.append("cross_rail_transform_buffer_drift")
	if mesh != null and not batch.multimesh.custom_aabb.is_equal_approx(
		_transformed_bounds(mesh.get_aabb(), expected_transforms)
	):
		errors.append("cross_rail_culling_bounds_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family_id": &"cross_rail_boxes",
		"body_node_names": CROSS_RAIL_NODE_NAMES.duplicate(),
		"authored_transforms": expected_transforms.duplicate(true),
		"visible_copy_count": batch.multimesh.visible_instance_count,
		"renderer_submissions": mesh.get_surface_count() if mesh != null else 0,
		"before_renderer_submissions": CROSS_RAIL_COUNT,
		"renderer_submission_delta": 1 - CROSS_RAIL_COUNT,
		"collision_shape_count": CROSS_RAIL_COUNT,
	}.duplicate(true)


func _validate_shared_static_box_family(paths: Array[NodePath], errors: PackedStringArray) -> void:
	var shared_mesh: BoxMesh
	for path in paths:
		var body := get_node_or_null(path) as StaticBody3D
		var view := body.get_node_or_null(^"Mesh") as MeshInstance3D if body != null else null
		var mesh := view.mesh as BoxMesh if view != null else null
		if mesh == null:
			errors.append("static_box_family_node_or_mesh_lost")
			continue
		if shared_mesh == null:
			shared_mesh = mesh
		elif mesh != shared_mesh:
			errors.append("static_box_shared_family_identity_drift")


func audit() -> Dictionary:
	var actual_budget := {
		"ship_berths": find_children("*", "ShipBerth", true, false).size(),
		"static_bodies": find_children("*", "StaticBody3D", true, false).size(),
		"collision_shapes": find_children("*", "CollisionShape3D", true, false).size(),
		"mesh_instances": find_children("*", "MeshInstance3D", true, false).size(),
		"multimesh_instances": find_children("*", "MultiMeshInstance3D", true, false).size(),
		"geometry_submissions": _geometry_submission_count(),
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
		"route_identity_visual": get_route_identity_visual_audit(),
		"static_box_visual_allocation": get_static_box_visual_allocation_audit(),
		"rise_rail_visual_allocation": get_rise_rail_visual_audit(),
		"cross_rail_visual_allocation": get_cross_rail_visual_audit(),
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
		"production_route_claim": _is_production_placed(),
	}.duplicate(true)


func _is_production_placed() -> bool:
	var platform := get_parent() as Node3D
	if not is_instance_valid(platform) or platform.name != &"CinderReachPlatform":
		return false
	var terminal := platform.get_node_or_null(^"CargoDestinationTerminal") as CargoTransferTerminal
	return (
		is_instance_valid(terminal)
		and transform.is_equal_approx(EXTRACTION_PLATFORM_LOCAL_TRANSFORM)
		and terminal.transform.is_equal_approx(DESTINATION_TERMINAL_ROOT_LOCAL)
		and terminal.placement_slot_id == TERMINAL_SLOT_ID
	)


func _get_contract_errors(actual_budget: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if actual_budget != LOCAL_BUDGET:
		errors.append("local_budget_drift")
	for allocation_error in get_route_cue_visual_allocation_audit().get(
		"errors", PackedStringArray()
	):
		errors.append(String(allocation_error))
	for allocation_error in get_static_box_visual_allocation_audit().get(
		"errors", PackedStringArray()
	):
		errors.append(String(allocation_error))
	for identity_error in get_route_identity_visual_audit().get(
		"errors", PackedStringArray()
	):
		errors.append(String(identity_error))
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
		_materials.cargo,
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
			_materials.grip,
			true
		)
	_static_horizontal_segment(
		structure,
		"RiseCatwalk",
		Vector3(BERTH_ROUTE_X, CATWALK_TOP, 15.95),
		Vector3(BERTH_ROUTE_X, CATWALK_TOP, 18.0),
		2.4,
		0.3,
		_materials.route
	)
	_static_horizontal_segment(
		structure,
		"CrossCatwalk",
		Vector3(BERTH_ROUTE_X, CATWALK_TOP, 18.0),
		Vector3(-4.0, CATWALK_TOP, 18.0),
		2.4,
		0.3,
		_materials.route
	)
	_static_horizontal_segment(
		structure,
		"TerminalHandoff",
		Vector3(-4.0, CATWALK_TOP, 18.0),
		Vector3(-2.4, CATWALK_TOP, 16.7),
		2.2,
		0.3,
		_materials.route
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
			_materials.grip,
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
	var support_transforms: Array[Transform3D] = []
	for support_side in [-1.0, 1.0]:
		var support := _static_box(
			structure,
			"TerminalApproachSupport%s" % ("Port" if support_side < 0.0 else "Starboard"),
			Vector3(support_side * 0.56, 4.105, 15.1),
			TERMINAL_APPROACH_SUPPORT_SIZE,
			_materials.service,
			false,
			false
		)
		support_transforms.append(support.transform)
	_visual_multimesh_boxes(
		structure,
		"TerminalApproachSupportBatch",
		_shared_static_box_mesh(TERMINAL_APPROACH_SUPPORT_SIZE),
		_materials.service,
		support_transforms
	)

	var rails := Node3D.new()
	rails.name = "Rails"
	add_child(rails)
	_static_segment(
		rails, "StairRailPort",
		Vector3(-25.42, 3.72, 14.15), Vector3(-25.42, 4.62, 15.95),
		0.12, _materials.frame
	)
	_static_segment(
		rails, "StairRailStarboard",
		Vector3(-23.18, 3.72, 14.15), Vector3(-23.18, 4.62, 15.95),
		0.12, _materials.frame
	)
	var rise_rail_transforms: Array[Transform3D] = []
	var rise_rail_port := _static_segment(
		rails, "RiseRailPort",
		Vector3(-25.42, 4.62, 15.95), Vector3(-25.42, 4.62, 17.2),
		0.12, _materials.frame, false
	)
	rise_rail_transforms.append(rise_rail_port.transform)
	var rise_rail_starboard := _static_segment(
		rails, "RiseRailStarboard",
		Vector3(-23.18, 4.62, 15.95), Vector3(-23.18, 4.62, 17.2),
		0.12, _materials.frame, false
	)
	rise_rail_transforms.append(rise_rail_starboard.transform)
	_visual_multimesh_boxes(
		rails,
		"RiseRailBatch",
		_shared_static_box_mesh(RISE_RAIL_SIZE),
		_materials.frame,
		rise_rail_transforms
	)
	var cross_rail_transforms: Array[Transform3D] = []
	var cross_rail_north := _static_segment(
		rails, "CrossRailNorth",
		Vector3(-23.1, 4.62, 19.12), Vector3(-5.15, 4.62, 19.12),
		0.12, _materials.frame, false
	)
	cross_rail_transforms.append(cross_rail_north.transform)
	var cross_rail_south := _static_segment(
		rails, "CrossRailSouth",
		Vector3(-23.1, 4.62, 16.88), Vector3(-5.15, 4.62, 16.88),
		0.12, _materials.frame, false
	)
	cross_rail_transforms.append(cross_rail_south.transform)
	_visual_multimesh_boxes(
		rails,
		"CrossRailBatch",
		_shared_static_box_mesh(CROSS_RAIL_SIZE),
		_materials.frame,
		cross_rail_transforms
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
		0.12, _materials.frame
	)
	_static_segment(
		rails, "HandoffRailStarboard",
		handoff_start - handoff_lateral, handoff_end - handoff_lateral,
		0.12, _materials.frame
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
	var authored_transforms := _get_route_cue_authored_transforms()
	_visual_multimesh_boxes(
		cues,
		"RouteCueCyanBatch",
		shared_route_cue_mesh,
		_materials.cue,
		_compose_route_cue_batch_transforms(authored_transforms, true)
	)
	_visual_multimesh_boxes(
		cues,
		"RouteCueHazardBatch",
		shared_route_cue_mesh,
		_materials.hazard,
		_compose_route_cue_batch_transforms(authored_transforms, false)
	)
	var label := Label3D.new()
	label.name = "CargoAccessLabel"
	label.text = "%s\nCINDER CARGO — READY" % ROUTE_IDENTITY_HEADER
	label.position = ROUTE_IDENTITY_LABEL_LOCAL
	label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	label.font_size = 46
	label.modulate = CUE_COLOR
	label.outline_size = 10
	cues.add_child(label)


## Three extra copies in the two existing cue batches form a legible,
## rail-supported fascia at the route midpoint for zero new submissions. It is
## deliberately presentation-only: the real deck, rails, markers, berth and
## terminal retain all collision and handoff roles.
func get_route_identity_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var expected := _get_route_identity_transforms()
	var cyan := get_node_or_null(
		^"VisualRouteCues/RouteCueCyanBatch"
	) as MultiMeshInstance3D
	var hazard := get_node_or_null(
		^"VisualRouteCues/RouteCueHazardBatch"
	) as MultiMeshInstance3D
	var label := get_node_or_null(
		^"VisualRouteCues/CargoAccessLabel"
	) as Label3D
	if cyan == null or hazard == null \
			or cyan.multimesh == null or hazard.multimesh == null:
		errors.append("cargo_route_identity_host_batch_missing")
		return {"valid": false, "errors": errors}.duplicate(true)
	var authored_cyan := cyan.get_meta("authored_instance_transforms", []) as Array
	var authored_hazard := hazard.get_meta("authored_instance_transforms", []) as Array
	if authored_cyan.size() != 4 \
			or not (authored_cyan[3] as Transform3D).is_equal_approx(expected[2]):
		errors.append("cargo_route_identity_cyan_fascia_drift")
	if authored_hazard.size() != 4 \
			or not (authored_hazard[2] as Transform3D).is_equal_approx(expected[0]) \
			or not (authored_hazard[3] as Transform3D).is_equal_approx(expected[1]):
		errors.append("cargo_route_identity_hazard_support_drift")
	if not bool(get_route_cue_visual_allocation_audit().valid):
		errors.append("cargo_route_identity_host_batch_drift")
	if label == null or label.position != ROUTE_IDENTITY_LABEL_LOCAL \
			or not label.text.begins_with(ROUTE_IDENTITY_HEADER + "\n"):
		errors.append("cargo_route_identity_label_drift")
	var rail := get_node_or_null(^"Rails/CrossRailNorth") as StaticBody3D
	var rail_collision := (
		rail.get_node_or_null(^"Collision") as CollisionShape3D
		if rail != null else null
	)
	var rail_shape := (
		rail_collision.shape as BoxShape3D
		if rail_collision != null else null
	)
	var rail_top := (
		rail.position.y + rail_shape.size.y * 0.5
		if rail != null and rail_shape != null else -INF
	)
	var post_bottom := expected[0].origin.y - ROUTE_CUE_SIZE.y \
		* expected[0].basis.get_scale().y * 0.5
	var post_top := expected[0].origin.y + ROUTE_CUE_SIZE.y \
		* expected[0].basis.get_scale().y * 0.5
	var fascia_bottom := expected[2].origin.y - ROUTE_CUE_SIZE.y \
		* expected[2].basis.get_scale().y * 0.5
	if not is_equal_approx(post_bottom, rail_top) \
			or not is_equal_approx(post_top, fascia_bottom):
		errors.append("cargo_route_identity_support_contact_drift")
	if is_equal_approx(expected[0].origin.z, expected[2].origin.z) \
			or is_equal_approx(label.position.z, expected[2].origin.z):
		errors.append("cargo_route_identity_coplanar_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family_id": &"cargo_route_identity_fascia",
		"copy_count": ROUTE_IDENTITY_COPY_COUNT,
		"incremental_renderer_submissions": 0,
		"material_reused": cyan.material_override == _materials.cue \
			and hazard.material_override == _materials.hazard,
		"collision_nodes": get_node(^"VisualRouteCues").find_children(
			"*", "CollisionObject3D", true, false
		).size(),
		"supported": is_equal_approx(post_bottom, rail_top) \
			and is_equal_approx(post_top, fascia_bottom),
		"non_coplanar": not is_equal_approx(
			expected[0].origin.z, expected[2].origin.z
		) and not is_equal_approx(label.position.z, expected[2].origin.z),
		"authored_transforms": expected.duplicate(true),
	}.duplicate(true)


func _get_route_identity_transforms() -> Array[Transform3D]:
	return [
		Transform3D(
			Basis.IDENTITY.scaled(Vector3(
				0.14 / ROUTE_CUE_SIZE.x,
				0.72 / ROUTE_CUE_SIZE.y,
				0.14 / ROUTE_CUE_SIZE.z
			)),
			Vector3(-17.05, 5.04, 19.12)
		),
		Transform3D(
			Basis.IDENTITY.scaled(Vector3(
				0.14 / ROUTE_CUE_SIZE.x,
				0.72 / ROUTE_CUE_SIZE.y,
				0.14 / ROUTE_CUE_SIZE.z
			)),
			Vector3(-11.25, 5.04, 19.12)
		),
		Transform3D(
			Basis.IDENTITY.scaled(Vector3(
				7.4 / ROUTE_CUE_SIZE.x,
				1.12 / ROUTE_CUE_SIZE.y,
				0.14 / ROUTE_CUE_SIZE.z
			)),
			Vector3(-14.15, 5.96, 19.08)
		),
	]


func _compose_route_cue_batch_transforms(
		route_transforms: Array[Transform3D],
		cyan: bool
	) -> Array[Transform3D]:
	var identity := _get_route_identity_transforms()
	if cyan:
		return [
			route_transforms[0], route_transforms[2], route_transforms[4],
			identity[2],
		]
	return [
		route_transforms[1], route_transforms[3], identity[0], identity[1],
	]


func _create_materials() -> void:
	# Keep the Cinder palette and scalar PBR values, but give each physical role
	# the same registered panel maps and response hierarchy as nearby manufactured
	# world surfaces. Several semantic roles intentionally share one material:
	# their authored tint and physical finish are identical, so allocating copies
	# would not change a pixel and would only grow the resource budget.
	var walked := _panel_material(
		DECK_COLOR, 0.54, 0.32, StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	var grip := _panel_material(
		STEP_COLOR, 0.42, 0.34, StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	var frame := _panel_material(
		RAIL_COLOR, 0.64, 0.25, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
	)
	_materials.deck = walked
	_materials.route = walked
	_materials.cargo = walked
	_materials.step = grip
	_materials.grip = grip
	_materials.rail = frame
	_materials.frame = frame
	_materials.service = frame
	_materials.cue = _emissive_material(CUE_COLOR)
	_materials.hazard = _emissive_material(HAZARD_COLOR)


func _panel_material(
		color: Color,
		metallic: float,
		roughness: float,
		finish: StationSurfaceKit.PanelFinish
	) -> StandardMaterial3D:
	var material := _material(color, metallic, roughness)
	StationSurfaceKit.apply_panel_triplanar(material, PANEL_SURFACE_SCALE, finish)
	return material


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
		walkable: bool,
		create_visual: bool = true
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
	if create_visual:
		var visible := MeshInstance3D.new()
		visible.name = "Mesh"
		var mesh := _shared_static_box_mesh(size)
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


func _shared_static_box_mesh(size: Vector3) -> BoxMesh:
	if _static_box_mesh_cache.has(size):
		return _static_box_mesh_cache[size] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_static_box_mesh_cache[size] = mesh
	return mesh


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
		material: Material,
		create_visual: bool = true
	) -> StaticBody3D:
	var direction := to_point - from_point
	var body := _static_box(
		parent,
		node_name,
		(from_point + to_point) * 0.5,
		Vector3(thickness, thickness, direction.length()),
		material,
		false,
		create_visual
	)
	body.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return body


func _visual_multimesh_boxes(
		parent: Node3D,
		node_name: String,
		mesh: BoxMesh,
		material: Material,
		transforms: Array
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	var authored_transforms: Array[Transform3D] = []
	for transform_value in transforms:
		var authored_transform := transform_value as Transform3D
		authored_transforms.append(authored_transform)
	multimesh.buffer = _encode_multimesh_transforms(authored_transforms)
	multimesh.custom_aabb = _transformed_bounds(mesh.get_aabb(), authored_transforms)
	var visible := MultiMeshInstance3D.new()
	visible.name = node_name
	visible.multimesh = multimesh
	visible.material_override = material
	visible.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible.set_meta("presentation_only", true)
	visible.set_meta("collision_authority", false)
	visible.set_meta("interaction_authority", false)
	visible.set_meta("authored_instance_transforms", authored_transforms.duplicate())
	parent.add_child(visible)
	return visible


static func _encode_multimesh_transforms(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for transform_index in transforms.size():
		var transform_value := transforms[transform_index]
		var offset := transform_index * 12
		buffer[offset] = transform_value.basis.x.x
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


func _geometry_submission_count() -> int:
	var count := 0
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		count += mesh.get_surface_count() if mesh != null else 0
	for candidate in find_children("*", "MultiMeshInstance3D", true, false):
		var multimesh := (candidate as MultiMeshInstance3D).multimesh
		count += multimesh.mesh.get_surface_count() \
			if multimesh != null and multimesh.mesh != null else 0
	return count


static func _transformed_bounds(
		mesh_bounds: AABB,
		transforms: Array[Transform3D]
	) -> AABB:
	var bounds := AABB()
	var initialized := false
	for transform_value in transforms:
		for corner_index in 8:
			var corner := mesh_bounds.position + Vector3(
				mesh_bounds.size.x if corner_index & 1 else 0.0,
				mesh_bounds.size.y if corner_index & 2 else 0.0,
				mesh_bounds.size.z if corner_index & 4 else 0.0
			)
			var point := transform_value * corner
			if initialized:
				bounds = bounds.expand(point)
			else:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
	return bounds


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
		and is_equal_approx(
			material.emission_energy_multiplier,
			_cue_presentation_energy if emission_color == CUE_COLOR else _hazard_presentation_energy
		)


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
