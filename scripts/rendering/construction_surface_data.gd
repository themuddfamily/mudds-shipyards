extends Mesh

# CPU staging only: never attached to a renderer. Keeping the decoded surface
# lets native SurfaceTool.append_from preserve its packing/transform semantics
# without reading the same ArrayMesh back from the rendering server per fitting.
var arrays: Array

func _init(source: Mesh) -> void:
	arrays = source.surface_get_arrays(0)

func _get_surface_count() -> int:
	return 1

func _surface_get_arrays(_surface: int) -> Array:
	return arrays

func _surface_get_primitive_type(_surface: int) -> int:
	return Mesh.PRIMITIVE_TRIANGLES
