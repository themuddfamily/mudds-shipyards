class_name StationStructuralEdgeTreatment
extends RefCounted

## Tool-width edges for the ShipyardWorld's own structural stock.
##
## The expansion berths, the Arrow, the Observation Logistics Spur and the
## Salvage Terrace already cut their slabs with the station's calibrated 38.2 mm
## edge tool (`ShipChamferedStock.structural_box_mesh`). The hub's own lattice
## decks, the catwalk landing and ramp, the Dock Operations control pod and the
## launch arm were never flat primitives, but they were still on the hub's older
## *proportional* rolled edge: `clamp(shortest * 0.22, 0.003, 0.20)`. On a 1.2 m
## lattice deck that is a 0.20 m rounded nosing, so wherever two decks butt
## (branch arm onto berth node, spine onto junction) the walked surface carried a
## 0.40 m rounded trough, and a 0.55 m catwalk landing read as a soft pill rather
## than plate stock. A chamfer is a tool width, not a proportion of the stock.
##
## This pass replaces exactly those renderers — the ones whose proportional
## edge is wider than the tool — with the 44-triangle tangent-chamfer recipe at
## the tool width. It runs once, from the world's build stages, after every
## ShipyardWorld builder and before `StationDressingBatch` folds anonymous
## dressing, so a merged batch inherits the treated geometry.
##
## What it never touches, by construction:
##
## * Collision. Only `MeshInstance3D.mesh` is reassigned; the `BoxShape3D` the
##   builder made from the same size is not read or written.
## * The authored extent. The chamfered box's AABB is the requested size exactly,
##   so every footprint, route, marker, seat and published envelope holds.
## * Anything with its own identity: a mesh carrying a `resource_name` (a named
##   authored contract such as `operations_pod_floor_inset_v1`), a mesh that is
##   not the hub's 324-vertex rolled box, glazing, emissive practicals, hidden
##   legacy slabs and every `MultiMesh`.
## * Metadata on the renderer. `StationDressingBatch` only merges pieces whose
##   metadata is identical, so tagging treated renderers would fragment batches;
##   the recipe is recorded on the shared mesh resource instead.

## The ShipyardWorld subtrees whose structural stock this pass owns: the
## operational lattice decks and connectors, the catwalk/landing and the Dock
## Operations control pod, and the launch arm with its rails and keels.
const TREATED_ROOTS: Array[NodePath] = [
	^"ExposedDockLattice",
	^"UpperOperations",
	^"OpenLaunchSpine",
]

## Recorded on every mesh this pass builds (resource name and meta).
const RECIPE := &"station_structural_tool_chamfer"
const MESH_RESOURCE_NAME := "station_structural_tool_chamfer"

## `StationSurfaceKit.rounded_box_mesh_with_bevel` emits nine quads per face.
const ROLLED_BOX_VERTEX_COUNT := 324
const ROLLED_BOX_TRIANGLES := 108
## `ShipChamferedStock.chamfered_box_mesh`: six faces, twelve edge quads, eight
## corner facets.
const TOOL_CHAMFER_TRIANGLES := 44

## The hub's frozen proportional rule (`ShipyardWorld._rounded_box_mesh`).
const HUB_MAXIMUM_BEVEL := 0.2

## Resident-triangle allowance granted to this pass. Replacing a 108-triangle
## rolled box with the 44-triangle chamfer can only lower the count, so the
## report's delta is expected to be negative; the ceiling is asserted anyway.
const MAX_RESIDENT_TRIANGLE_DELTA := 6000

const CENTRED_AABB_TOLERANCE := 0.0005


## Shortest section at which the hub's proportional edge first exceeds the tool.
## Thinner stock (treads, insets, keylines, glazing) keeps its current edge,
## because there the proportional width *is* the physical answer.
static func minimum_treated_section() -> float:
	return ShipChamferedStock.largest_resolvable_chamfer() / StationSurfaceKit.BEVEL_PROPORTION


## Chamfer width this pass cuts on `size`, in metres. Equal to the tool width for
## every piece the pass accepts.
static func chamfer_for_size(size: Vector3) -> float:
	return ShipChamferedStock.structural_chamfer_for_size(size)


## Tool-chamfered mesh at `size`, shared through the caller-owned `cache`.
static func tool_chamfer_mesh_cached(size: Vector3, cache: Dictionary) -> ArrayMesh:
	var key := "%0.4f:%0.4f:%0.4f" % [size.x, size.y, size.z]
	if cache.has(key):
		return cache[key] as ArrayMesh
	var mesh := ShipChamferedStock.chamfered_box_mesh(
		size, chamfer_for_size(size), ShipChamferedStock.StockUV.FACE_GRID
	)
	mesh.resource_name = MESH_RESOURCE_NAME
	mesh.set_meta(&"structural_edge_recipe", RECIPE)
	mesh.set_meta(&"chamfer_width_m", chamfer_for_size(size))
	mesh.set_meta(&"authored_size", size)
	cache[key] = mesh
	return mesh


## True when `mesh_instance` is hub structural stock this pass should re-cut.
static func accepts(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or not mesh_instance.visible:
		return false
	if mesh_instance.is_inside_tree() and not mesh_instance.is_visible_in_tree():
		return false
	if bool(mesh_instance.get_meta(&"hidden_by_authored_central_berth", false)):
		return false
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1 or not mesh.resource_name.is_empty():
		return false
	if mesh.has_meta(&"structural_edge_recipe"):
		return false
	var aabb := mesh.get_aabb()
	if (aabb.position + aabb.size * 0.5).length() > CENTRED_AABB_TOLERANCE:
		return false
	var size := aabb.size
	if minf(size.x, minf(size.y, size.z)) < minimum_treated_section():
		return false
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return false
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != ROLLED_BOX_VERTEX_COUNT:
		return false
	var material := mesh_instance.material_override as BaseMaterial3D
	if material == null:
		return false
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.emission_enabled:
		return false
	return true


## Re-cuts every accepted renderer under `world`'s treated roots. Returns the
## per-piece record the world publishes for tests and probes.
static func apply(world: Node3D, cache: Dictionary) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var triangle_delta := 0
	var errors := PackedStringArray()
	if world == null:
		errors.append("world_missing")
		return _report(pieces, triangle_delta, errors)
	for root_path in TREATED_ROOTS:
		var root := world.get_node_or_null(root_path) as Node3D
		if root == null:
			errors.append("treated_root_missing:%s" % root_path)
			continue
		for candidate in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if not accepts(mesh_instance):
				continue
			var authored_size := mesh_instance.mesh.get_aabb().size
			var treated := tool_chamfer_mesh_cached(authored_size, cache)
			if not treated.get_aabb().is_equal_approx(AABB(-authored_size * 0.5, authored_size)):
				errors.append("aabb_drift:%s" % world.get_path_to(mesh_instance))
				continue
			mesh_instance.mesh = treated
			var material := mesh_instance.material_override as StandardMaterial3D
			pieces.append({
				"path": world.get_path_to(mesh_instance),
				"size": authored_size,
				"chamfer_m": chamfer_for_size(authored_size),
				"previous_bevel_m": StationSurfaceKit.proportional_bevel_for_size(
					authored_size, HUB_MAXIMUM_BEVEL
				),
				"triplanar_bound": material != null and material.uv1_world_triplanar,
				"orm_bound": material != null and material.ao_enabled
					and StationSurfaceKit.texture_path(material.ao_texture) == StationSurfaceKit.PANEL_ORM_PATH,
			})
			triangle_delta += TOOL_CHAMFER_TRIANGLES - ROLLED_BOX_TRIANGLES
	if triangle_delta > MAX_RESIDENT_TRIANGLE_DELTA:
		errors.append("triangle_budget_exceeded:%d" % triangle_delta)
	return _report(pieces, triangle_delta, errors)


static func _report(pieces: Array[Dictionary], triangle_delta: int, errors: PackedStringArray) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"recipe": RECIPE,
		"chamfer_m": ShipChamferedStock.largest_resolvable_chamfer(),
		"piece_count": pieces.size(),
		"pieces": pieces,
		"resident_triangle_delta": triangle_delta,
	}
