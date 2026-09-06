class_name PlanetaryTerrainClipmapRenderer
extends Node3D

## Caller-driven spherical terrain clipmap renderer.
##
## A validated PlanetaryTerrainProfile supplies the radius, LOD extents,
## elevation envelope and budgets. One explicit rebuild creates a bounded stack
## of nested spherical tangent grids around a body-local focus. Successive
## coarser grids sit a few centimetres below the finer grid, hiding transition
## cracks without skirts or duplicate coplanar faces. One separately bounded
## relief-matched collision surface reaches the profile's collision distance;
## an authored landing patch may own a square clearance at its centre. When a
## caller moves beyond that fixed landing footprint, one bounded polar sector
## extends physical support from the exact outer seam toward the live focus.
##
## The component owns its generated MeshInstance3D and StaticBody3D children.
## It never observes a camera, advances a clock, moves an actor, shifts an
## origin, streams a scene, chooses gameplay state, saves, or networks.

signal terrain_rebuilt(generation: int, revision: int, snapshot: Dictionary)

const COMPONENT_ID: StringName = &"planetary-terrain-clipmap-renderer"
const SCHEMA_VERSION := 1
const MAX_GENERATION := 9_007_199_254_740_991
const MAX_RENDER_VERTICES := 300_000
const MAX_RENDER_TRIANGLES := 600_000
const MAX_ACTIVE_RING_COUNT := 16
const MIN_RESOLUTION_VERTICES_PER_EDGE := 17
const MAX_RESOLUTION_VERTICES_PER_EDGE := 257
const MAX_FLATTEN_RADIUS_M := 10_000.0
const MAX_VISUAL_CLEARANCE_RADIUS_M := 10_000.0
const MAX_COLLISION_CLEARANCE_RADIUS_M := 10_000.0
const MAX_AUTHORED_RELIEF_M := 420.0
const MAX_COLLISION_RADIAL_SEGMENTS := 64
const COLLISION_ANGULAR_SEGMENTS_PER_RADIAL := 4
const MAX_FIXED_COLLISION_TRIANGLES := 32_768
const MAX_DYNAMIC_COLLISION_TRIANGLES := 8_320
const MAX_TOTAL_COLLISION_TRIANGLES := (
	MAX_FIXED_COLLISION_TRIANGLES + MAX_DYNAMIC_COLLISION_TRIANGLES
)
const COLLISION_CORRIDOR_PREFETCH_MARGIN_M := 300.0
const COLLISION_CORRIDOR_RADIAL_STEP_M := 48.0
const COARSE_RING_RADIAL_BIAS_M := 0.25
const DEFAULT_SEED := 20_260_830
const COMMITTED_ROOT_NAME := &"CommittedTerrain"
const VISUAL_ROOT_NAME := &"TerrainVisuals"
const COLLISION_BODY_NAME := &"TerrainCollision"
const FIXED_COLLISION_NAME := &"TerrainCollisionSurface"
const FOCUS_COLLISION_NAME := &"TerrainFocusCollisionCorridor"
const TERRAIN_LAYER := 1

const SHORE_COLOR := Color("5c796d")
const LOWLAND_COLOR := Color("426f4c")
const HIGHLAND_COLOR := Color("69755d")
const ROCK_COLOR := Color("727a78")
const SNOW_COLOR := Color("c3d0ce")

var _configured := false
var _generation := 0
var _revision := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _profile_id: StringName = &""
var _profile_snapshot: Dictionary = {}
var _body_radius_m := 0.0
var _minimum_elevation_m := 0.0
var _maximum_elevation_m := 0.0
var _ring_distances_m := PackedFloat64Array()
var _resolution := 0
var _seed := DEFAULT_SEED
var _flatten_direction := Vector3.ZERO
var _flatten_radius_m := 0.0
var _visual_clearance_radius_m := 0.0
var _collision_clearance_radius_m := 0.0
var _collision_maximum_distance_m := 0.0
var _material_tint := Color.WHITE
var _last_focus_body_local_m := Vector3.ZERO
var _last_snapshot: Dictionary = {}
var _shared_material: StandardMaterial3D
var _fixed_collision_shape: ConcavePolygonShape3D
var _fixed_collision_report: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func configure(
	profile: PlanetaryTerrainProfile,
	resolution_vertices_per_edge: int,
	seed: int = DEFAULT_SEED,
	flatten_center_body_local_m: Vector3 = Vector3.ZERO,
	flatten_radius_m: float = 0.0,
	visual_clearance_radius_m: float = 0.0,
	collision_clearance_radius_m: float = 0.0,
	material_tint: Color = Color.WHITE,
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if _configured:
		return _result(false, &"already_configured")
	if profile == null or not profile.is_profile_valid():
		return _result(false, &"invalid_terrain_profile")
	if (
		resolution_vertices_per_edge < MIN_RESOLUTION_VERTICES_PER_EDGE
		or resolution_vertices_per_edge > MAX_RESOLUTION_VERTICES_PER_EDGE
		or not _is_power_of_two_plus_one(resolution_vertices_per_edge)
		or resolution_vertices_per_edge
			> profile.tile_resolution_vertices_per_edge
	):
		return _result(false, &"invalid_render_resolution")
	var rings := profile.get_clipmap_ring_distances_meters()
	if rings.is_empty() or rings.size() > MAX_ACTIVE_RING_COUNT:
		return _result(false, &"invalid_ring_roster")
	var vertex_count := rings.size() * (
		resolution_vertices_per_edge * resolution_vertices_per_edge
	)
	var triangle_count := rings.size() * (
		(resolution_vertices_per_edge - 1)
		* (resolution_vertices_per_edge - 1)
		* 2
	)
	if (
		vertex_count > MAX_RENDER_VERTICES
		or triangle_count > MAX_RENDER_TRIANGLES
		or vertex_count > profile.maximum_visible_tile_count * 2048
	):
		return _result(false, &"render_budget_exceeded")
	if (
		not is_finite(flatten_radius_m)
		or flatten_radius_m < 0.0
		or flatten_radius_m > MAX_FLATTEN_RADIUS_M
		or not is_finite(visual_clearance_radius_m)
		or visual_clearance_radius_m < 0.0
		or visual_clearance_radius_m > MAX_VISUAL_CLEARANCE_RADIUS_M
		or not is_finite(collision_clearance_radius_m)
		or collision_clearance_radius_m < 0.0
		or collision_clearance_radius_m > MAX_COLLISION_CLEARANCE_RADIUS_M
	):
		return _result(false, &"invalid_landing_clearance")
	if (
		not is_finite(material_tint.r)
		or not is_finite(material_tint.g)
		or not is_finite(material_tint.b)
		or not is_finite(material_tint.a)
		or not is_equal_approx(material_tint.a, 1.0)
	):
		return _result(false, &"invalid_material_tint")
	if (
		flatten_radius_m > 0.0
		and (
			not flatten_center_body_local_m.is_finite()
			or flatten_center_body_local_m.is_zero_approx()
		)
	):
		return _result(false, &"invalid_flatten_center")
	if (
		visual_clearance_radius_m > 0.0
		and flatten_radius_m <= 0.0
	) or (
		collision_clearance_radius_m > 0.0
		and flatten_radius_m <= 0.0
	):
		return _result(false, &"collision_clearance_requires_flatten_region")
	if (
		visual_clearance_radius_m > flatten_radius_m
		or collision_clearance_radius_m > flatten_radius_m
	):
		return _result(false, &"collision_clearance_exceeds_flatten_region")
	if _generation >= MAX_GENERATION:
		return _result(false, &"generation_exhausted")

	var snapshot := profile.get_snapshot()
	var collision_maximum_distance_m := float(
		snapshot.get("collision_maximum_distance_meters", 0.0)
	)
	if (
		not is_finite(collision_maximum_distance_m)
		or collision_maximum_distance_m <= 0.0
		or collision_clearance_radius_m * sqrt(2.0)
			>= collision_maximum_distance_m
	):
		return _result(false, &"invalid_collision_distance")
	_mutation_active = true
	_profile_id = profile.profile_id
	_profile_snapshot = snapshot.duplicate(true)
	_body_radius_m = profile.reference_planet_radius_meters
	_minimum_elevation_m = profile.minimum_elevation_meters
	_maximum_elevation_m = profile.maximum_elevation_meters
	_ring_distances_m = rings.duplicate()
	_resolution = resolution_vertices_per_edge
	_seed = seed
	_flatten_direction = (
		flatten_center_body_local_m.normalized()
		if flatten_radius_m > 0.0
		else Vector3.ZERO
	)
	_flatten_radius_m = flatten_radius_m
	_visual_clearance_radius_m = visual_clearance_radius_m
	_collision_clearance_radius_m = collision_clearance_radius_m
	_collision_maximum_distance_m = collision_maximum_distance_m
	_material_tint = material_tint
	_shared_material = _create_shared_material()
	_generation += 1
	_configured = true
	_mutation_active = false
	return _result(true, &"configured", {
		"generation": _generation,
		"profile_id": _profile_id,
		"ring_count": _ring_distances_m.size(),
		"resolution_vertices_per_edge": _resolution,
		"maximum_render_vertices": vertex_count,
		"maximum_render_triangles": triangle_count,
		"collision_maximum_distance_m": _collision_maximum_distance_m,
		"maximum_collision_triangles": MAX_TOTAL_COLLISION_TRIANGLES,
		"maximum_fixed_collision_triangles": MAX_FIXED_COLLISION_TRIANGLES,
		"maximum_dynamic_collision_triangles": MAX_DYNAMIC_COLLISION_TRIANGLES,
		"material_tint": _material_tint,
	})


func rebuild(
	focus_body_local_m: Vector3,
	expected_generation: int,
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if (
		not focus_body_local_m.is_finite()
		or focus_body_local_m.is_zero_approx()
	):
		return _result(false, &"invalid_focus")
	if not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"renderer_detached")

	_mutation_active = true
	var focus_up := focus_body_local_m.normalized()
	var tangent_right := _tangent_right(focus_up)
	var tangent_back := tangent_right.cross(focus_up).normalized()
	var fixed_landing_collision := _collision_clearance_radius_m > 0.0
	var collision_focus_up := (
		_flatten_direction if fixed_landing_collision else focus_up
	)
	var collision_tangent_right := _tangent_right(collision_focus_up)
	var collision_tangent_back := (
		collision_tangent_right.cross(collision_focus_up).normalized()
	)
	var staged_root := Node3D.new()
	staged_root.name = COMMITTED_ROOT_NAME
	staged_root.set_meta(&"terrain_generation", _generation)
	staged_root.set_meta(&"terrain_revision", _revision + 1)
	var visuals := Node3D.new()
	visuals.name = VISUAL_ROOT_NAME
	staged_root.add_child(visuals)
	var collision_body := StaticBody3D.new()
	collision_body.name = COLLISION_BODY_NAME
	# Keep narrow-phase collision coordinates near the surface, not the body centre.
	# Large (~120 km) shape-local coordinates destabilize CharacterBody contact.
	collision_body.position = collision_focus_up * _body_radius_m
	collision_body.collision_layer = TERRAIN_LAYER
	collision_body.collision_mask = 0
	collision_body.set_meta(&"generated_planetary_terrain", true)
	staged_root.add_child(collision_body)

	var ring_reports: Array[Dictionary] = []
	var total_vertices := 0
	var total_triangles := 0
	var minimum_generated_height := INF
	var maximum_generated_height := -INF
	for ring_index in _ring_distances_m.size():
		var extent_m := float(_ring_distances_m[ring_index])
		var built := _build_ring(
			ring_index,
			extent_m,
			focus_up,
			tangent_right,
			tangent_back,
		)
		var mesh := built.get("mesh") as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 1:
			staged_root.free()
			_mutation_active = false
			return _result(false, &"ring_build_failed", {
				"ring_index": ring_index,
			})
		var instance := MeshInstance3D.new()
		instance.name = "TerrainRing%02d" % ring_index
		instance.mesh = mesh
		instance.material_override = _shared_material
		instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if ring_index <= 1
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		instance.set_meta(&"clipmap_ring_index", ring_index)
		instance.set_meta(&"clipmap_outer_extent_m", extent_m)
		visuals.add_child(instance)
		var ring_vertices := int(built.get("vertex_count", 0))
		var ring_triangles := int(built.get("triangle_count", 0))
		total_vertices += ring_vertices
		total_triangles += ring_triangles
		minimum_generated_height = minf(
			minimum_generated_height,
			float(built.get("minimum_height_m", INF)),
		)
		maximum_generated_height = maxf(
			maximum_generated_height,
			float(built.get("maximum_height_m", -INF)),
		)
		ring_reports.append({
			"ring_index": ring_index,
			"outer_extent_m": extent_m,
			"resolution_vertices_per_edge": _resolution,
			"vertex_count": ring_vertices,
			"triangle_count": ring_triangles,
			"collision_triangle_count": 0,
			"radial_bias_m": float(ring_index) * COARSE_RING_RADIAL_BIAS_M,
		}.duplicate(true))

	var collision_report: Dictionary = {}
	var collision_shape: ConcavePolygonShape3D
	var commit_fixed_collision_cache := false
	if fixed_landing_collision \
			and _fixed_collision_shape != null \
			and not _fixed_collision_report.is_empty():
		collision_shape = _fixed_collision_shape
		collision_report = _fixed_collision_report.duplicate(true)
	else:
		var collision_surface := _build_collision_surface(
			collision_focus_up,
			collision_tangent_right,
			collision_tangent_back,
		)
		var collision_faces := collision_surface.get(
			"faces", PackedVector3Array()
		) as PackedVector3Array
		var built_collision_triangles := collision_faces.size() / 3
		if (
			collision_faces.is_empty()
			or built_collision_triangles > MAX_FIXED_COLLISION_TRIANGLES
		):
			staged_root.free()
			_mutation_active = false
			return _result(false, &"collision_build_failed")
		collision_shape = ConcavePolygonShape3D.new()
		collision_shape.set_faces(_collision_faces_relative_to(
			collision_faces, collision_body.position
		))
		collision_shape.backface_collision = false
		collision_report = {
			"vertex_count": int(collision_surface.get("vertex_count", 0)),
			"triangle_count": built_collision_triangles,
			"radial_segments": int(collision_surface.get("radial_segments", 0)),
			"angular_segments": int(collision_surface.get("angular_segments", 0)),
			"focus_radial_up": collision_focus_up,
			"topology": (
				&"square_clearance_to_circular_profile_boundary"
				if fixed_landing_collision
				else &"disc_to_circular_profile_boundary"
			),
		}.duplicate(true)
		commit_fixed_collision_cache = fixed_landing_collision
	var fixed_collision_triangles := int(collision_report.get("triangle_count", 0))
	var fixed_collision_vertices := int(collision_report.get("vertex_count", 0))
	if collision_shape == null or fixed_collision_triangles <= 0 \
			or fixed_collision_triangles > MAX_FIXED_COLLISION_TRIANGLES:
		staged_root.free()
		_mutation_active = false
		return _result(false, &"collision_build_failed")
	var collision := CollisionShape3D.new()
	collision.name = FIXED_COLLISION_NAME
	collision.shape = collision_shape
	collision_body.add_child(collision)

	var focus_collision_report := {
		"active": false,
		"reason": &"fixed_landing_collision_unavailable",
		"vertex_count": 0,
		"triangle_count": 0,
		"radial_segments": 0,
		"angular_segments": 0,
		"radial_step_m": 0.0,
		"inner_distance_m": _collision_maximum_distance_m,
		"outer_distance_m": _collision_maximum_distance_m,
		"focus_surface_distance_m": 0.0,
		"focus_tangent_distance_m": 0.0,
		"activation_distance_m": _collision_corridor_activation_distance_m(),
		"maximum_focus_distance_m": float(
			_ring_distances_m[_ring_distances_m.size() - 1]
		),
	}.duplicate(true)
	if fixed_landing_collision:
		focus_collision_report = _build_focus_collision_corridor(
			focus_up,
			collision_focus_up,
			collision_tangent_right,
			collision_tangent_back,
		)
	if bool(focus_collision_report.get("active", false)):
		var focus_collision_faces := focus_collision_report.get(
			"faces", PackedVector3Array()
		) as PackedVector3Array
		var focus_collision_triangles := focus_collision_faces.size() / 3
		if (
			focus_collision_faces.is_empty()
			or focus_collision_triangles
				> MAX_DYNAMIC_COLLISION_TRIANGLES
		):
			staged_root.free()
			_mutation_active = false
			return _result(false, &"focus_collision_build_failed")
		var focus_collision_shape := ConcavePolygonShape3D.new()
		focus_collision_shape.set_faces(_collision_faces_relative_to(
			focus_collision_faces, collision_body.position
		))
		focus_collision_shape.backface_collision = false
		var focus_collision := CollisionShape3D.new()
		focus_collision.name = FOCUS_COLLISION_NAME
		focus_collision.shape = focus_collision_shape
		collision_body.add_child(focus_collision)
		focus_collision_report["triangle_count"] = focus_collision_triangles
		focus_collision_report.erase("faces")

	var dynamic_collision_triangles := int(
		focus_collision_report.get("triangle_count", 0)
	)
	var dynamic_collision_vertices := int(
		focus_collision_report.get("vertex_count", 0)
	)
	var collision_triangles := (
		fixed_collision_triangles + dynamic_collision_triangles
	)
	var collision_vertices := fixed_collision_vertices + dynamic_collision_vertices
	if collision_triangles > MAX_TOTAL_COLLISION_TRIANGLES:
		staged_root.free()
		_mutation_active = false
		return _result(false, &"collision_budget_exceeded")

	if (
		total_vertices > MAX_RENDER_VERTICES
		or total_triangles > MAX_RENDER_TRIANGLES
		or not is_finite(minimum_generated_height)
		or not is_finite(maximum_generated_height)
		or minimum_generated_height < _minimum_elevation_m
		or maximum_generated_height > _maximum_elevation_m
	):
		staged_root.free()
		_mutation_active = false
		return _result(false, &"generated_terrain_contract_invalid")

	var previous := get_node_or_null(NodePath(String(COMMITTED_ROOT_NAME)))
	if previous != null:
		remove_child(previous)
		previous.free()
	add_child(staged_root)
	if commit_fixed_collision_cache:
		_fixed_collision_shape = collision_shape
		_fixed_collision_report = collision_report.duplicate(true)
	_revision += 1
	_last_focus_body_local_m = focus_body_local_m
	_last_snapshot = {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"configured": true,
		"generation": _generation,
		"revision": _revision,
		"profile_id": _profile_id,
		"focus_body_local_m": focus_body_local_m,
		"focus_radial_up": focus_up,
		"tangent_right": tangent_right,
		"tangent_back": tangent_back,
		"body_radius_m": _body_radius_m,
		"ring_count": ring_reports.size(),
		"rings": ring_reports,
		"render_vertex_count": total_vertices,
		"render_triangle_count": total_triangles,
		"collision_triangle_count": collision_triangles,
		"collision_vertex_count": collision_vertices,
		"collision_ring_count": collision_body.get_child_count(),
		"collision_focus_radial_up": collision_report.get(
			"focus_radial_up", Vector3.ZERO
		),
		"collision_reused": fixed_landing_collision and not commit_fixed_collision_cache,
		"fixed_collision_triangle_count": fixed_collision_triangles,
		"fixed_collision_vertex_count": fixed_collision_vertices,
		"dynamic_collision_active": bool(
			focus_collision_report.get("active", false)
		),
		"dynamic_collision_reason": focus_collision_report.get("reason", &""),
		"dynamic_collision_triangle_count": dynamic_collision_triangles,
		"dynamic_collision_vertex_count": dynamic_collision_vertices,
		"dynamic_collision_radial_segment_count": int(
			focus_collision_report.get("radial_segments", 0)
		),
		"dynamic_collision_angular_segment_count": int(
			focus_collision_report.get("angular_segments", 0)
		),
		"dynamic_collision_radial_step_m": float(
			focus_collision_report.get("radial_step_m", 0.0)
		),
		"dynamic_collision_inner_distance_m": float(
			focus_collision_report.get("inner_distance_m", 0.0)
		),
		"dynamic_collision_outer_distance_m": float(
			focus_collision_report.get("outer_distance_m", 0.0)
		),
		"dynamic_collision_focus_surface_distance_m": float(
			focus_collision_report.get("focus_surface_distance_m", 0.0)
		),
		"dynamic_collision_focus_tangent_distance_m": float(
			focus_collision_report.get("focus_tangent_distance_m", 0.0)
		),
		"dynamic_collision_activation_distance_m": float(
			focus_collision_report.get("activation_distance_m", 0.0)
		),
		"dynamic_collision_maximum_focus_distance_m": float(
			focus_collision_report.get("maximum_focus_distance_m", 0.0)
		),
		"minimum_generated_height_m": minimum_generated_height,
		"maximum_generated_height_m": maximum_generated_height,
		"flatten_radius_m": _flatten_radius_m,
		"visual_clearance_radius_m": _visual_clearance_radius_m,
		"collision_clearance_radius_m": _collision_clearance_radius_m,
		"collision_maximum_distance_m": _collision_maximum_distance_m,
		"collision_topology": collision_report.get("topology", &""),
		"material_tint": _material_tint,
		"authority": _authority_snapshot(),
	}.duplicate(true)
	_mutation_active = false
	_signal_dispatch_active = true
	terrain_rebuilt.emit(_generation, _revision, _last_snapshot.duplicate(true))
	_signal_dispatch_active = false
	return _result(true, &"terrain_rebuilt", {
		"generation": _generation,
		"revision": _revision,
		"snapshot": _last_snapshot,
	})


func retire(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_GENERATION:
		return _result(false, &"generation_exhausted")
	_mutation_active = true
	var committed := get_node_or_null(NodePath(String(COMMITTED_ROOT_NAME)))
	if committed != null:
		remove_child(committed)
		committed.free()
	_generation += 1
	_revision = 0
	_last_focus_body_local_m = Vector3.ZERO
	_last_snapshot.clear()
	_mutation_active = false
	return _result(true, &"terrain_retired", {"generation": _generation})


func get_generation() -> int:
	return _generation


func get_revision() -> int:
	return _revision


func get_focus_radial_up() -> Vector3:
	return (
		_last_focus_body_local_m.normalized()
		if not _last_focus_body_local_m.is_zero_approx()
		else Vector3.ZERO
	)


func get_snapshot() -> Dictionary:
	if _last_snapshot.is_empty():
		return {
			"schema_version": SCHEMA_VERSION,
			"component_id": COMPONENT_ID,
			"configured": _configured,
			"generation": _generation,
			"revision": _revision,
			"profile_id": _profile_id,
			"ring_count": 0,
			"rings": [],
			"authority": _authority_snapshot(),
		}.duplicate(true)
	return _last_snapshot.duplicate(true)


func sample_height(body_direction: Vector3) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not body_direction.is_finite() or body_direction.is_zero_approx():
		return _result(false, &"invalid_body_direction")
	var direction := body_direction.normalized()
	return _result(true, &"height_sampled", {
		"body_direction": direction,
		"height_m": _sample_height_direction(direction),
	})


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("terrain renderer is not configured")
	if is_processing() or is_physics_processing():
		errors.append("terrain renderer gained automatic cadence")
	if _configured and (
		_profile_id.is_empty()
		or _body_radius_m <= 0.0
		or _ring_distances_m.is_empty()
		or _resolution < MIN_RESOLUTION_VERTICES_PER_EDGE
		or _collision_maximum_distance_m <= _collision_clearance_radius_m
		or (_revision > 0 and _collision_clearance_radius_m > 0.0 and (
			_fixed_collision_shape == null or _fixed_collision_report.is_empty()
		))
		or _shared_material == null
		or not _shared_material.albedo_color.is_equal_approx(_material_tint)
	):
		errors.append("frozen terrain renderer contract is invalid")
	var committed := get_node_or_null(NodePath(String(COMMITTED_ROOT_NAME)))
	if _revision == 0 and committed != null:
		errors.append("unbuilt renderer owns committed terrain")
	elif _revision > 0:
		if committed == null:
			errors.append("committed terrain root is unavailable")
		else:
			var visuals := committed.get_node_or_null(
				NodePath(String(VISUAL_ROOT_NAME))
			) as Node3D
			var collision := committed.get_node_or_null(
				NodePath(String(COLLISION_BODY_NAME))
			) as StaticBody3D
			var expected_collision_shape_count := (
				2
				if bool(_last_snapshot.get("dynamic_collision_active", false))
				else 1
			)
			var fixed_collision := (
				collision.get_node_or_null(NodePath(String(FIXED_COLLISION_NAME)))
					as CollisionShape3D
				if collision != null
				else null
			)
			var focus_collision := (
				collision.get_node_or_null(NodePath(String(FOCUS_COLLISION_NAME)))
					as CollisionShape3D
				if collision != null
				else null
			)
			if visuals == null or visuals.get_child_count() != _ring_distances_m.size():
				errors.append("terrain visual ring roster drifted")
			if collision == null \
					or collision.basis != Basis.IDENTITY \
					or collision.position != (
						_last_snapshot.get("collision_focus_radial_up", Vector3.ZERO) as Vector3
					) * _body_radius_m \
					or collision.collision_layer != TERRAIN_LAYER \
					or collision.collision_mask != 0 \
					or collision.get_child_count() != expected_collision_shape_count \
					or fixed_collision == null \
					or not fixed_collision.shape is ConcavePolygonShape3D \
					or (expected_collision_shape_count == 2 and (
						focus_collision == null
						or not focus_collision.shape is ConcavePolygonShape3D
					)) \
					or (expected_collision_shape_count == 1 and focus_collision != null):
				errors.append("terrain collision owner drifted")
		if (
			int(_last_snapshot.get("render_vertex_count", 0)) > MAX_RENDER_VERTICES
			or int(_last_snapshot.get("render_triangle_count", 0))
				> MAX_RENDER_TRIANGLES
			or int(_last_snapshot.get("collision_triangle_count", 0))
				> MAX_TOTAL_COLLISION_TRIANGLES
			or int(_last_snapshot.get("fixed_collision_triangle_count", 0))
				> MAX_FIXED_COLLISION_TRIANGLES
			or int(_last_snapshot.get("dynamic_collision_triangle_count", 0))
				> MAX_DYNAMIC_COLLISION_TRIANGLES
			or float(_last_snapshot.get("collision_maximum_distance_m", 0.0))
				!= _collision_maximum_distance_m
		):
			errors.append("terrain renderer exceeded its hard budget")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"authority": _authority_snapshot(),
		"cadence": &"caller_driven_rebuild_only",
		"lod_strategy": &"nested_spherical_tangent_clipmap_grids",
		"collision_strategy": &"fixed_landing_surface_with_bounded_focus_corridor",
	}.duplicate(true)


func _build_ring(
	ring_index: int,
	extent_m: float,
	focus_up: Vector3,
	tangent_right: Vector3,
	tangent_back: Vector3,
) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var minimum_height := INF
	var maximum_height := -INF
	var segment_count := _resolution - 1
	var step_m := extent_m * 2.0 / float(segment_count)
	var radial_bias_m := float(ring_index) * COARSE_RING_RADIAL_BIAS_M
	for z_index in _resolution:
		var z_m := -extent_m + float(z_index) * step_m
		for x_index in _resolution:
			var x_m := -extent_m + float(x_index) * step_m
			var tangent_point := (
				focus_up * _body_radius_m
				+ tangent_right * x_m
				+ tangent_back * z_m
			)
			var direction := tangent_point.normalized()
			var height_m := _sample_height_direction(direction)
			minimum_height = minf(minimum_height, height_m)
			maximum_height = maxf(maximum_height, height_m)
			vertices.append(direction * (
				_body_radius_m + height_m - radial_bias_m
			))
			normals.append(direction)
			colors.append(_terrain_color(height_m, direction))
			uvs.append(Vector2(
				float(x_index) / float(segment_count),
				float(z_index) / float(segment_count),
			))
	for z_index in segment_count:
		for x_index in segment_count:
			var i00 := z_index * _resolution + x_index
			var i10 := i00 + 1
			var i01 := i00 + _resolution
			var i11 := i01 + 1
			var center_x := -extent_m + (float(x_index) + 0.5) * step_m
			var center_z := -extent_m + (float(z_index) + 0.5) * step_m
			var inside_visual_clearance := false
			if ring_index == 0 and _visual_clearance_radius_m > 0.0:
				var center_direction := (
					focus_up * _body_radius_m
					+ tangent_right * center_x
					+ tangent_back * center_z
				).normalized()
				inside_visual_clearance = _surface_distance_m(
					center_direction, _flatten_direction
				) < _visual_clearance_radius_m
			if not inside_visual_clearance:
				_append_clockwise_triangle(indices, vertices, i00, i10, i11)
				_append_clockwise_triangle(indices, vertices, i00, i11, i01)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.resource_name = "%s_ring_%02d" % [_profile_id, ring_index]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {
		"mesh": mesh,
		"vertex_count": vertices.size(),
		"triangle_count": indices.size() / 3,
		"minimum_height_m": minimum_height,
		"maximum_height_m": maximum_height,
	}


func _build_collision_surface(
	focus_up: Vector3,
	tangent_right: Vector3,
	tangent_back: Vector3,
) -> Dictionary:
	var vertices := PackedVector3Array()
	var faces := PackedVector3Array()
	var radial_segments := mini(
		_resolution - 1,
		MAX_COLLISION_RADIAL_SEGMENTS,
	)
	var angular_segments := (
		radial_segments * COLLISION_ANGULAR_SEGMENTS_PER_RADIAL
	)
	if radial_segments <= 0 or angular_segments < 3:
		return {}

	if is_zero_approx(_collision_clearance_radius_m):
		vertices.append(_collision_surface_vertex(
			focus_up,
			tangent_right,
			tangent_back,
			Vector2.ZERO,
		))
		for radial_index in range(1, radial_segments + 1):
			var radius_m := (
				_collision_maximum_distance_m
				* float(radial_index)
				/ float(radial_segments)
			)
			_append_collision_vertex_ring(
				vertices,
				focus_up,
				tangent_right,
				tangent_back,
				radius_m,
				radius_m,
				angular_segments,
			)
		for angular_index in angular_segments:
			var next_angular := (angular_index + 1) % angular_segments
			_append_collision_triangle(
				faces,
				vertices,
				0,
				1 + angular_index,
				1 + next_angular,
			)
		for radial_index in range(1, radial_segments):
			var inner_start := 1 + (radial_index - 1) * angular_segments
			var outer_start := inner_start + angular_segments
			_append_collision_band(
				faces,
				vertices,
				inner_start,
				outer_start,
				angular_segments,
			)
	else:
		for radial_index in range(radial_segments + 1):
			var blend := float(radial_index) / float(radial_segments)
			_append_collision_vertex_ring(
				vertices,
				focus_up,
				tangent_right,
				tangent_back,
				_collision_clearance_radius_m,
				_collision_maximum_distance_m,
				angular_segments,
				blend,
			)
		for radial_index in radial_segments:
			_append_collision_band(
				faces,
				vertices,
				radial_index * angular_segments,
				(radial_index + 1) * angular_segments,
				angular_segments,
			)

	return {
		"faces": faces,
		"vertex_count": vertices.size(),
		"triangle_count": faces.size() / 3,
		"radial_segments": radial_segments,
		"angular_segments": angular_segments,
	}


func _build_focus_collision_corridor(
	focus_up: Vector3,
	landing_up: Vector3,
	tangent_right: Vector3,
	tangent_back: Vector3,
) -> Dictionary:
	var activation_distance_m := _collision_corridor_activation_distance_m()
	var maximum_focus_distance_m := float(
		_ring_distances_m[_ring_distances_m.size() - 1]
	)
	var focus_surface_distance_m := _surface_distance_m(focus_up, landing_up)
	var report := {
		"active": false,
		"reason": &"focus_inside_fixed_collision",
		"vertex_count": 0,
		"triangle_count": 0,
		"radial_segments": 0,
		"angular_segments": 0,
		"radial_step_m": 0.0,
		"inner_distance_m": _collision_maximum_distance_m,
		"outer_distance_m": _collision_maximum_distance_m,
		"focus_surface_distance_m": focus_surface_distance_m,
		"focus_tangent_distance_m": 0.0,
		"activation_distance_m": activation_distance_m,
		"maximum_focus_distance_m": maximum_focus_distance_m,
	}.duplicate(true)
	if focus_surface_distance_m < activation_distance_m:
		return report
	if focus_surface_distance_m > maximum_focus_distance_m:
		report["reason"] = &"focus_outside_collision_streaming_envelope"
		return report

	var landing_projection := focus_up.dot(landing_up)
	if landing_projection <= 0.0:
		report["reason"] = &"focus_outside_landing_tangent_hemisphere"
		return report
	var focus_tangent_offset_m := Vector2(
		focus_up.dot(tangent_right),
		focus_up.dot(tangent_back),
	) * (_body_radius_m / landing_projection)
	var focus_tangent_distance_m := focus_tangent_offset_m.length()
	report["focus_tangent_distance_m"] = focus_tangent_distance_m
	if focus_tangent_distance_m < activation_distance_m:
		return report

	var fixed_radial_segments := mini(
		_resolution - 1,
		MAX_COLLISION_RADIAL_SEGMENTS,
	)
	var full_angular_segments := (
		fixed_radial_segments * COLLISION_ANGULAR_SEGMENTS_PER_RADIAL
	)
	if full_angular_segments < 3:
		report["active"] = true
		report["reason"] = &"invalid_fixed_collision_topology"
		return report
	var angular_step_rad := TAU / float(full_angular_segments)
	var focus_bearing_rad := fposmod(
		atan2(focus_tangent_offset_m.y, focus_tangent_offset_m.x),
		TAU,
	)
	var half_angle_rad := asin(clampf(
		_collision_maximum_distance_m
			/ maxf(focus_tangent_distance_m, _collision_maximum_distance_m),
		0.0,
		1.0,
	))
	var half_angular_segments := clampi(
		# The corridor bearing is snapped to the fixed seam's angular grid.
		# Reserve another half segment so the snap cannot narrow either side
		# of the promised collision-distance disc around the live focus.
		ceili(half_angle_rad / angular_step_rad + 0.5),
		1,
		(full_angular_segments >> 1) + 1,
	)
	var angular_segments := half_angular_segments * 2
	var centre_angular_index := posmod(
		int(floor(focus_bearing_rad / angular_step_rad + 0.5)),
		full_angular_segments,
	)
	var start_angular_index := centre_angular_index - half_angular_segments
	var inner_distance_m := _collision_maximum_distance_m
	var outer_distance_m := (
		focus_tangent_distance_m + _collision_maximum_distance_m
	)
	var target_radial_segments := ceili(
		(outer_distance_m - inner_distance_m)
			/ COLLISION_CORRIDOR_RADIAL_STEP_M
	)
	var maximum_radial_segments := maxi(
		1,
		floori(
			float(MAX_DYNAMIC_COLLISION_TRIANGLES)
				/ float(angular_segments * 2)
		),
	)
	var radial_segments := mini(
		target_radial_segments,
		maximum_radial_segments,
	)
	var radial_step_m := (
		(outer_distance_m - inner_distance_m) / float(radial_segments)
	)
	var triangle_count := radial_segments * angular_segments * 2
	report.merge({
		"active": true,
		"reason": &"focus_collision_corridor_built",
		"radial_segments": radial_segments,
		"angular_segments": angular_segments,
		"radial_step_m": radial_step_m,
		"inner_distance_m": inner_distance_m,
		"outer_distance_m": outer_distance_m,
		"bearing_angle_rad": focus_bearing_rad,
		"centre_angular_index": centre_angular_index,
		"start_angular_index": start_angular_index,
		"full_angular_segments": full_angular_segments,
		"triangle_count": triangle_count,
	}, true)
	if radial_segments <= 0 or triangle_count > MAX_DYNAMIC_COLLISION_TRIANGLES:
		report["reason"] = &"focus_collision_budget_exceeded"
		return report

	var vertices := PackedVector3Array()
	var faces := PackedVector3Array()
	for radial_index in range(radial_segments + 1):
		var radial_blend := float(radial_index) / float(radial_segments)
		var radius_m := lerpf(
			inner_distance_m,
			outer_distance_m,
			radial_blend,
		)
		for angular_offset in range(angular_segments + 1):
			var angular_index := posmod(
				start_angular_index + angular_offset,
				full_angular_segments,
			)
			var angle := (
				TAU * float(angular_index) / float(full_angular_segments)
			)
			vertices.append(_collision_surface_vertex(
				landing_up,
				tangent_right,
				tangent_back,
				Vector2(cos(angle), sin(angle)) * radius_m,
			))
	var angular_vertex_count := angular_segments + 1
	for radial_index in radial_segments:
		var inner_start := radial_index * angular_vertex_count
		var outer_start := inner_start + angular_vertex_count
		for angular_index in angular_segments:
			var inner_current := inner_start + angular_index
			var inner_next := inner_current + 1
			var outer_current := outer_start + angular_index
			var outer_next := outer_current + 1
			_append_collision_triangle(
				faces, vertices, inner_current, outer_current, outer_next
			)
			_append_collision_triangle(
				faces, vertices, inner_current, outer_next, inner_next
			)
	report["faces"] = faces
	report["vertex_count"] = vertices.size()
	return report


func _collision_corridor_activation_distance_m() -> float:
	return _collision_maximum_distance_m - minf(
		COLLISION_CORRIDOR_PREFETCH_MARGIN_M,
		_collision_maximum_distance_m * 0.2,
	)


func _append_collision_vertex_ring(
	vertices: PackedVector3Array,
	focus_up: Vector3,
	tangent_right: Vector3,
	tangent_back: Vector3,
	inner_radius_m: float,
	outer_radius_m: float,
	angular_segments: int,
	radial_blend: float = 1.0,
) -> void:
	for angular_index in angular_segments:
		var angle := TAU * float(angular_index) / float(angular_segments)
		var radial_direction := Vector2(cos(angle), sin(angle))
		var square_boundary_distance := (
			inner_radius_m
			/ maxf(absf(radial_direction.x), absf(radial_direction.y))
		)
		var radius_m := lerpf(
			square_boundary_distance,
			outer_radius_m,
			radial_blend,
		)
		vertices.append(_collision_surface_vertex(
			focus_up,
			tangent_right,
			tangent_back,
			radial_direction * radius_m,
		))


func _collision_surface_vertex(
	focus_up: Vector3,
	tangent_right: Vector3,
	tangent_back: Vector3,
	tangent_offset_m: Vector2,
) -> Vector3:
	var tangent_point := (
		focus_up * _body_radius_m
		+ tangent_right * tangent_offset_m.x
		+ tangent_back * tangent_offset_m.y
	)
	var direction := tangent_point.normalized()
	return direction * (_body_radius_m + _sample_height_direction(direction))


static func _append_collision_band(
	faces: PackedVector3Array,
	vertices: PackedVector3Array,
	inner_start: int,
	outer_start: int,
	angular_segments: int,
) -> void:
	for angular_index in angular_segments:
		var next_angular := (angular_index + 1) % angular_segments
		var inner_current := inner_start + angular_index
		var inner_next := inner_start + next_angular
		var outer_current := outer_start + angular_index
		var outer_next := outer_start + next_angular
		_append_collision_triangle(
			faces, vertices, inner_current, outer_current, outer_next
		)
		_append_collision_triangle(
			faces, vertices, inner_current, outer_next, inner_next
		)


func _sample_height_direction(direction: Vector3) -> float:
	var phase := float(posmod(_seed, 4093)) * 0.0017
	var continental := sin(direction.x * 19.0 + direction.z * 7.0 + phase)
	continental += sin(direction.z * 27.0 - direction.y * 11.0 - phase * 0.7) * 0.58
	continental += sin(
		(direction.x + direction.y - direction.z) * 43.0 + phase * 1.9
	) * 0.29
	continental /= 1.87
	var detail := sin(direction.x * 101.0 - direction.z * 71.0 + phase * 2.7)
	detail += sin(direction.y * 137.0 + direction.z * 83.0 - phase) * 0.55
	detail /= 1.55
	var ridge := 1.0 - absf(
		sin((direction.x - direction.z) * 67.0 + direction.y * 23.0)
	)
	var normalized := clampf(
		continental * 0.70 + detail * 0.20 + (ridge - 0.5) * 0.22,
		-1.0,
		1.0,
	)
	var negative_amplitude := minf(
		absf(minf(_minimum_elevation_m, 0.0)),
		MAX_AUTHORED_RELIEF_M * 0.62,
	)
	var positive_amplitude := minf(
		maxf(_maximum_elevation_m, 0.0),
		MAX_AUTHORED_RELIEF_M,
	)
	var height_m := (
		normalized * positive_amplitude
		if normalized >= 0.0
		else normalized * negative_amplitude
	)
	if _flatten_radius_m > 0.0:
		var angular_distance := acos(clampf(
			direction.dot(_flatten_direction), -1.0, 1.0
		)) * _body_radius_m
		var flatten_blend := smoothstep(
			_flatten_radius_m,
			_flatten_radius_m * 2.2,
			angular_distance,
		)
		height_m *= flatten_blend
	return clampf(height_m, _minimum_elevation_m, _maximum_elevation_m)


func _surface_distance_m(a: Vector3, b: Vector3) -> float:
	var chord := clampf(a.distance_to(b), 0.0, 2.0)
	return 2.0 * asin(chord * 0.5) * _body_radius_m


func _terrain_color(height_m: float, direction: Vector3) -> Color:
	var moisture := clampf(
		0.5 + sin(direction.x * 53.0 + direction.z * 31.0) * 0.24,
		0.0,
		1.0,
	)
	if height_m < 8.0:
		return SHORE_COLOR.lerp(LOWLAND_COLOR, moisture * 0.28)
	if height_m < 260.0:
		return LOWLAND_COLOR.lerp(HIGHLAND_COLOR, height_m / 260.0 * 0.45)
	if height_m < 620.0:
		return HIGHLAND_COLOR.lerp(ROCK_COLOR, (height_m - 260.0) / 360.0)
	return ROCK_COLOR.lerp(
		SNOW_COLOR,
		clampf((height_m - 620.0) / 280.0, 0.0, 1.0),
	)


func _create_shared_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "%s_clipmap_vertex_material" % _profile_id
	material.vertex_color_use_as_albedo = true
	material.albedo_color = _material_tint
	material.roughness = 0.92
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


static func _append_clockwise_triangle(
	indices: PackedInt32Array,
	vertices: PackedVector3Array,
	a: int,
	b: int,
	c: int,
) -> void:
	var va := vertices[a]
	var vb := vertices[b]
	var vc := vertices[c]
	var mathematical_normal := (vb - va).cross(vc - va)
	var outward := (va + vb + vc).normalized()
	indices.append(a)
	if mathematical_normal.dot(outward) > 0.0:
		indices.append(c)
		indices.append(b)
	else:
		indices.append(b)
		indices.append(c)


static func _collision_faces_relative_to(
	faces: PackedVector3Array, origin: Vector3
) -> PackedVector3Array:
	var local_faces := PackedVector3Array()
	local_faces.resize(faces.size())
	for index in faces.size():
		local_faces[index] = faces[index] - origin
	return local_faces


static func _append_collision_triangle(
	faces: PackedVector3Array,
	vertices: PackedVector3Array,
	a: int,
	b: int,
	c: int,
) -> void:
	var ordered := PackedInt32Array()
	_append_clockwise_triangle(ordered, vertices, a, b, c)
	faces.append(vertices[ordered[0]])
	faces.append(vertices[ordered[1]])
	faces.append(vertices[ordered[2]])


static func _tangent_right(up: Vector3) -> Vector3:
	var reference := Vector3.FORWARD
	if absf(reference.dot(up)) > 0.95:
		reference = Vector3.RIGHT
	return reference.cross(up).normalized()


static func _is_power_of_two_plus_one(value: int) -> bool:
	var candidate := value - 1
	return candidate > 0 and (candidate & (candidate - 1)) == 0


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


static func _authority_snapshot() -> Dictionary:
	return {
		"renderer": true,
		"terrain_generation": true,
		"collision_generation": true,
		"automatic_process": false,
		"camera_observation": false,
		"movement": false,
		"origin_shift": false,
		"scene_streaming": false,
		"landing_decision": false,
		"gameplay": false,
		"save": false,
		"network": false,
	}.duplicate(true)


static func _result(
	accepted: bool,
	reason: StringName,
	extra: Dictionary = {},
) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
