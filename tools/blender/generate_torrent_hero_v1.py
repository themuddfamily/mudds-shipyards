"""Generate the project-original Torrent hero craft in Blender 4.0.2.

Run from the repository root:
  blender --background --factory-startup --python tools/blender/generate_torrent_hero_v1.py

The checked-in .blend is the editable semantic source and the GLB is the
draw-call-bounded runtime asset.  The source is saved before deterministic,
export-only static batching so named construction remains editable without
shipping one MeshInstance3D per authored detail.  This is an original,
script-assisted modern interpretation; no source geometry or image pixels are
copied into the model.
"""

from __future__ import annotations

import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector


ROOT = Path.cwd()
BLEND_PATH = ROOT / "art_source/torrent/torrent_hero_v1.blend"
GLB_PATH = ROOT / "assets/models/torrent/hero/torrent_hero_art.glb"
MANIFEST_PATH = ROOT / "assets/models/torrent/hero/torrent_hero_asset_manifest.json"
CONCEPT_PATH = ROOT / "assets/concepts/torrent/torrent-hero-concept-multiview-v1.png"

MATS: dict[str, bpy.types.Material] = {}
OBJECTS: dict[str, list[str]] = {
    "LOD0": [],
    "LOD1": [],
    "CockpitArt": [],
    "CanopyPivot": [],
    "SemanticAnchors": [],
}

STATIC_BATCH_STRATEGY = "per_semantic_root_per_material_static_join"
BATCHABLE_ROOTS = ("LOD0", "LOD1", "CockpitArt", "CanopyPivot")
UNBATCHED_ROOTS = ("SemanticAnchors",)
PROTECTED_MESHES_BY_ROOT: dict[str, tuple[str, ...]] = {
    "LOD0": (
        "PortEngineCore",
        "PortEnginePlume",
        "StarboardEngineCore",
        "StarboardEnginePlume",
        "PortMainGearClampJawForward",
        "PortMainGearClampJawAft",
        "StarboardMainGearClampJawForward",
        "StarboardMainGearClampJawAft",
        "NoseGearCaptureClamp",
        "AmberUnknownFunctionPanel",
    ),
    "LOD1": (
        "LOD1PortEnginePlume",
        "LOD1StarboardEnginePlume",
    ),
    # HeroShip and the presentation audit resolve these exact imported nodes.
    # Everything else in the cabin/canopy is export-only batched by material.
    "CockpitArt": (
        "CrimsonSeatPan",
        "PrimaryDisplay",
    ),
    "CanopyPivot": (
        "CanopyGlass",
    ),
}
EXPECTED_SOURCE_MESH_COUNTS = {
    "LOD0": 238,
    "LOD1": 18,
    "CockpitArt": 39,
    "CanopyPivot": 22,
    "SemanticAnchors": 0,
}
EXPECTED_RUNTIME_MESH_COUNTS = {
    "LOD0": 17,
    "LOD1": 5,
    "CockpitArt": 7,
    "CanopyPivot": 3,
    "SemanticAnchors": 0,
}
EXPECTED_RUNTIME_TRIANGLES = 87_392
RUNTIME_MESH_INSTANCE_BUDGET = 36
SOURCE_MESH_INSTANCE_BUDGET = 320
CLOSE_TRIANGLE_RANGE = (70_000, 90_000)
FAR_TRIANGLE_RANGE = (7_000, 12_000)
TOTAL_TRIANGLE_BUDGET = 105_000

# Gameplay collision remains Godot-owned, but these exact boxes are audited
# against the evaluated editable Blender source before export-only batching.
# Coordinates are TorrentHeroArt-root-local metres, which are also HeroShip
# local metres under the identity import contract.
COLLISION_BOX_CONTRACT: dict[str, dict[str, tuple[float, float, float]]] = {
    "HullCollision": {
        "position": (0.0, 1.05, -0.3),
        "size": (4.6, 2.35, 9.0),
    },
    "WingCollision": {
        "position": (0.0, 0.62, 0.05),
        "size": (7.2, 1.5, 6.3),
    },
    "UpperSilhouetteCollision": {
        "position": (0.0, 2.85, 0.85),
        "size": (4.75, 1.75, 6.0),
    },
    "PortAftPropulsionCollision": {
        "position": (-2.5, 1.1, 3.25),
        "size": (1.35, 1.35, 1.7),
    },
    "StarboardAftPropulsionCollision": {
        "position": (2.5, 1.1, 3.25),
        "size": (1.35, 1.35, 1.7),
    },
    "LowerGearCollision": {
        "position": (0.0, -0.4, -0.15),
        "size": (5.0, 0.75, 4.95),
    },
    "NoseGearCollision": {
        "position": (0.0, -0.4, -3.05),
        "size": (0.85, 0.55, 1.35),
    },
}
COLLISION_COVERAGE_TOLERANCE_M = 0.02
COLLISION_EXCLUDED_OBJECTS: dict[str, str] = {
    "PortEnginePlume": "dynamic emissive engine effect; intentionally non-contact",
    "StarboardEnginePlume": "dynamic emissive engine effect; intentionally non-contact",
    **{
        f"{side}PlaneTipLight{tier}":
            "tiny decorative navigation-light fixture; intentionally non-contact"
        for side in ("Port", "Starboard")
        for tier in range(1, 5)
    },
}
COLLISION_PROPULSION_OBJECTS = {
    f"{side}{suffix}"
    for side in ("Port", "Starboard")
    for suffix in (
        "AftCircularHousing",
        "DominantAftRail",
        "EngineCore",
        "EngineNozzle",
        "EngineOuterCollar",
        "EngineThermalLip",
        "RailGraphiteInset",
    )
} | {
    f"{side}EngineStatorVane{index:02d}"
    for side in ("Port", "Starboard")
    for index in range(8)
} | {
    f"{side}{suffix}"
    for side in ("Port", "Starboard")
    for suffix in (
        "EngineHub",
        "NacelleUpperBrace",
        "NacelleLowerBrace",
    )
}
COLLISION_PARKED_GEAR_OBJECTS = {
    f"{side}MainGear{suffix}"
    for side in ("Port", "Starboard")
    for suffix in (
        "Strut", "Foot", "Shock", "ClampJawForward", "ClampJawAft",
        "UpperPivot", "OleoSleeve", "TrailingBrace", "ForkForward",
        "ForkAft", "Ankle", "HydraulicLine",
    )
} | {
    "NoseGearStrut", "NoseGearFoot", "NoseGearCaptureClamp",
    "NoseGearUpperPivot", "NoseGearOleoSleeve", "NoseGearTrailingBrace",
    "NoseGearForkPort", "NoseGearForkStarboard", "NoseGearAnkle",
    "NoseGearHydraulicLine",
}
def material(name: str, color: tuple[float, float, float, float], metallic: float, roughness: float,
             emission: tuple[float, float, float, float] | None = None) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = 2.2
    MATS[name] = mat
    return mat


def link_only(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj: bpy.types.Object, name: str, collection: bpy.types.Collection,
           mat: bpy.types.Material | None, bevel: float = 0.04, segments: int = 2) -> bpy.types.Object:
    obj.name = name
    link_only(obj, collection)
    if mat and obj.type == "MESH":
        obj.data.materials.append(mat)
    if obj.type == "MESH" and bevel > 0.0:
        mod = obj.modifiers.new("ProductionBevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(25)
        mod.harden_normals = False
    OBJECTS[collection.name].append(name)
    return obj


def box(name: str, loc, scale, collection, mat, bevel=0.04, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.scale = (scale[0] * 0.5, scale[1] * 0.5, scale[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, collection, mat, bevel)


def compound_boxes(name: str, parts, collection, mat, bevel=.012):
    """One editable semantic object composed of several flush hard-surface cells."""
    verts = []
    faces = []
    cube_faces = ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
    for loc, size in parts:
        hx, hy, hz = (size[0] * .5, size[1] * .5, size[2] * .5)
        start = len(verts)
        verts.extend([
            (loc[0]-hx,loc[1]-hy,loc[2]-hz),(loc[0]+hx,loc[1]-hy,loc[2]-hz),
            (loc[0]-hx,loc[1]+hy,loc[2]-hz),(loc[0]+hx,loc[1]+hy,loc[2]-hz),
            (loc[0]-hx,loc[1]-hy,loc[2]+hz),(loc[0]+hx,loc[1]-hy,loc[2]+hz),
            (loc[0]-hx,loc[1]+hy,loc[2]+hz),(loc[0]+hx,loc[1]+hy,loc[2]+hz),
        ])
        faces.extend(tuple(start + index for index in face) for face in cube_faces)
    return wedge(name, collection, mat, verts, faces, bevel)


def cylinder(name: str, loc, radius, depth, collection, mat, vertices=32,
             rotation=(0, 0, 0), bevel=0.035):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=loc, rotation=rotation)
    obj = finish(bpy.context.object, name, collection, mat, bevel)
    for polygon in obj.data.polygons:
        # Keep the end caps planar while giving the barrel a continuous
        # production-machined highlight instead of a many-sided toy read.
        polygon.use_smooth = abs(polygon.normal.z) < 0.80
    return obj


def torus(name: str, loc, major, minor, collection, mat, rotation=(0, 0, 0), segments=48):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=segments, minor_segments=10,
                                    location=loc, rotation=rotation)
    obj = finish(bpy.context.object, name, collection, mat, 0.012, 2)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def wedge(name: str, collection, mat, verts, faces, bevel=0.05):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    if mat:
        mesh.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("ProductionBevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.harden_normals = False
    OBJECTS[collection.name].append(name)
    return obj


def annular_shell(name: str, collection, mat, center_xy, z_values,
                  outer_radii, inner_radii, segments=48, bevel=.008,
                  radial_y_scale=1.0):
    """Build one coherent recessed annular casing across several depth rings."""
    if not (len(z_values) == len(outer_radii) == len(inner_radii)) or len(z_values) < 2:
        raise ValueError(f"{name} has an invalid annular profile")
    cx, cy = center_xy
    verts = []
    ring_count = len(z_values)
    for radius_values in (outer_radii, inner_radii):
        for z_value, radius in zip(z_values, radius_values):
            for index in range(segments):
                angle = math.tau * index / segments
                verts.append((cx + math.cos(angle) * radius,
                              cy + math.sin(angle) * radius * radial_y_scale,
                              z_value))
    faces = []
    inner_offset = ring_count * segments
    for ring_index in range(ring_count - 1):
        for segment in range(segments):
            following = (segment + 1) % segments
            outer_a = ring_index * segments + segment
            outer_b = ring_index * segments + following
            outer_c = (ring_index + 1) * segments + following
            outer_d = (ring_index + 1) * segments + segment
            faces.append((outer_a, outer_b, outer_c, outer_d))
            inner_a = inner_offset + ring_index * segments + segment
            inner_b = inner_offset + (ring_index + 1) * segments + segment
            inner_c = inner_offset + (ring_index + 1) * segments + following
            inner_d = inner_offset + ring_index * segments + following
            faces.append((inner_a, inner_b, inner_c, inner_d))
    final_outer = (ring_count - 1) * segments
    final_inner = inner_offset + (ring_count - 1) * segments
    for segment in range(segments):
        following = (segment + 1) % segments
        faces.append((segment, inner_offset + segment,
                      inner_offset + following, following))
        faces.append((final_outer + segment, final_outer + following,
                      final_inner + following, final_inner + segment))
    obj = wedge(name, collection, mat, verts, faces, bevel)
    for polygon in obj.data.polygons:
        polygon.use_smooth = abs(polygon.normal.z) < .82
    return obj


def canopy_glass_shell(name: str, collection, mat):
    """One faceted transparent pressure shell with a low, uninterrupted sightline."""
    stations = (
        (-3.14, .78, .54),
        (-2.62, 1.00, 1.02),
        (-1.78, 1.10, 1.18),
        (-.92, 1.10, 1.16),
        (-.22, .98, .94),
        (.02, .82, .66),
    )
    arch = ((-1.0, 0.0), (-.82, .52), (-.46, .88), (0.0, 1.0),
            (.46, .88), (.82, .52), (1.0, 0.0))
    verts = [
        (x_factor * half_width, y_factor * height, z_value)
        for z_value, half_width, height in stations
        for x_factor, y_factor in arch
    ]
    faces = []
    ring = len(arch)
    for station in range(len(stations) - 1):
        start = station * ring
        following = (station + 1) * ring
        for edge in range(ring - 1):
            faces.append((start + edge, start + edge + 1,
                          following + edge + 1, following + edge))
    faces.append(tuple(reversed(range(ring))))
    final = (len(stations) - 1) * ring
    faces.append(tuple(final + index for index in range(ring)))
    return wedge(name, collection, mat, verts, faces, .018)


def articulated_foot(name: str, loc, size, collection, mat):
    """A clipped, articulated capture foot that preserves the exact contact AABB."""
    sx, sy, sz = size
    hx, hy, hz = sx * .5, sy * .5, sz * .5
    clip = min(hx, hz) * .28
    footprint = [
        (-hx + clip, -hz), (hx - clip, -hz), (hx, -hz + clip),
        (hx, hz - clip), (hx - clip, hz), (-hx + clip, hz),
        (-hx, hz - clip), (-hx, -hz + clip),
    ]
    verts = [(loc[0] + x, loc[1] - hy, loc[2] + z) for x, z in footprint]
    verts += [(loc[0] + x, loc[1] + hy, loc[2] + z) for x, z in footprint]
    faces = [tuple(reversed(range(8))), tuple(8 + index for index in range(8))]
    faces += [
        (index, (index + 1) % 8, 8 + (index + 1) % 8, 8 + index)
        for index in range(8)
    ]
    return wedge(name, collection, mat, verts, faces, .035)


def tapered_capture_jaw(name: str, loc, size, direction: float, collection, mat):
    """A connected wedge jaw, inset at its capture tip rather than a bright box."""
    sx, sy, sz = size
    hx, hy, hz = sx * .5, sy * .5, sz * .5
    taper = .54
    verts = [
        (loc[0]-hx, loc[1]-hy, loc[2]-hz),
        (loc[0]+hx, loc[1]-hy, loc[2]-hz),
        (loc[0]+hx*taper, loc[1]+hy, loc[2]-hz*direction),
        (loc[0]-hx*taper, loc[1]+hy, loc[2]-hz*direction),
        (loc[0]-hx, loc[1]-hy, loc[2]+hz),
        (loc[0]+hx, loc[1]-hy, loc[2]+hz),
        (loc[0]+hx*taper, loc[1]+hy, loc[2]+hz*direction),
        (loc[0]-hx*taper, loc[1]+hy, loc[2]+hz*direction),
    ]
    faces = [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(4,0,3,7)]
    return wedge(name, collection, mat, verts, faces, .026)


def ensure_deterministic_uv0() -> dict:
    """Publish finite, non-degenerate UV0 on every source mesh.

    Dominant-axis projection keeps hard-surface texel density consistent across
    custom and primitive meshes and survives material batching without zero-fill.
    Each polygon projection is reflected when necessary so the exported glTF
    tangent frame has one orientation. Blender converts UV V to glTF's convention
    at export, so the editable source deliberately uses negative handedness and
    the runtime TEXCOORD_0 data is positive-handed. Without this normal-sign
    correction, opposite-facing panels receive mirrored directional texture art.
    """
    mesh_count = polygon_count = loop_count = degenerate_polygon_count = 0
    reflected_polygon_count = 0
    fallback_polygon_count = 0
    projection_axis_polygon_counts = [0, 0, 0]
    for obj in sorted((value for value in bpy.data.objects if value.type == "MESH"),
                      key=lambda value: value.name):
        mesh = obj.data
        world_matrix = obj.matrix_world
        normal_matrix = world_matrix.to_3x3().inverted_safe().transposed()
        while len(mesh.uv_layers):
            mesh.uv_layers.remove(mesh.uv_layers[0])
        uv_layer = mesh.uv_layers.new(name="UVMap")
        mesh_count += 1
        for polygon in mesh.polygons:
            polygon_count += 1
            coordinates = [
                world_matrix @ mesh.vertices[mesh.loops[loop_index].vertex_index].co
                for loop_index in polygon.loop_indices
            ]
            root_normal = (normal_matrix @ polygon.normal).normalized()
            # Project through the face's dominant root-space normal axis. The
            # previous unique-coordinate tie-break frequently selected a nearly
            # edge-on plane and rotated motifs between otherwise paired panels.
            # Lowest axis index wins exact ties for a deterministic box mapping.
            projection_axis = max(
                range(3), key=lambda axis: (abs(float(root_normal[axis])), -axis)
            )
            projection_axis_polygon_counts[projection_axis] += 1
            best_projection = [
                (coordinate.z, coordinate.y) if projection_axis == 0 else
                (coordinate.x, coordinate.z) if projection_axis == 1 else
                (coordinate.x, coordinate.y)
                for coordinate in coordinates
            ]
            _unique_count = len({
                (round(float(value[0]), 8), round(float(value[1]), 8))
                for value in best_projection
            })
            if _unique_count < 3:
                # A few deliberately narrow custom side faces are collinear in
                # every local-axis projection. Give those loops a tiny stable
                # island rather than publishing zero-filled TEXCOORD_0 data.
                best_projection = [
                    (math.cos(math.tau * index / len(coordinates)) * .01,
                     math.sin(math.tau * index / len(coordinates)) * .01)
                    for index in range(len(coordinates))
                ]
                fallback_polygon_count += 1
            # Determine the source tangent-frame orientation using the first
            # non-degenerate fan triangle. Reflect U when it agrees with the
            # polygon normal: Blender flips V for glTF, so source-negative
            # becomes runtime-positive. This sign test works for every chosen
            # projection plane and both sides of the craft.
            source_handedness = 0.0
            for triangle_index in range(1, len(coordinates) - 1):
                edge_a = coordinates[triangle_index] - coordinates[0]
                edge_b = coordinates[triangle_index + 1] - coordinates[0]
                uv_a = Vector(best_projection[triangle_index]) - Vector(best_projection[0])
                uv_b = Vector(best_projection[triangle_index + 1]) - Vector(best_projection[0])
                uv_determinant = uv_a.x * uv_b.y - uv_a.y * uv_b.x
                normal_alignment = root_normal.dot(edge_a.cross(edge_b))
                if abs(uv_determinant) > 1e-12 and abs(normal_alignment) > 1e-12:
                    source_handedness = normal_alignment * uv_determinant
                    break
            if source_handedness > 0.0:
                best_projection = [(-value[0], value[1]) for value in best_projection]
                reflected_polygon_count += 1
            polygon_uvs = []
            for loop_index, projected in zip(polygon.loop_indices, best_projection):
                uv = (float(projected[0]) * .34 + .5,
                      float(projected[1]) * .34 + .5)
                uv_layer.data[loop_index].uv = uv
                polygon_uvs.append(uv)
                loop_count += 1
            if len({(round(value[0], 8), round(value[1], 8)) for value in polygon_uvs}) < 3:
                degenerate_polygon_count += 1
    if degenerate_polygon_count:
        raise RuntimeError(
            f"Generated UV0 contains {degenerate_polygon_count} degenerate polygons"
        )
    return {
        "mesh_count": mesh_count,
        "polygon_count": polygon_count,
        "loop_count": loop_count,
        "degenerate_polygon_count": degenerate_polygon_count,
        "reflected_polygon_count": reflected_polygon_count,
        "fallback_polygon_count": fallback_polygon_count,
        "projection_axis_polygon_counts": {
            "X": projection_axis_polygon_counts[0],
            "Y": projection_axis_polygon_counts[1],
            "Z": projection_axis_polygon_counts[2],
        },
        "projection_axis_tie_policy": "lowest_root_axis_index",
        "method": "dominant_root_normal_axis_sign_corrected_projection_v3",
        "texture_coordinate": "TEXCOORD_0",
        "editable_source_handedness": "negative",
        "runtime_glTF_handedness": "positive_after_Blender_V_conversion",
        "all_source_meshes_mapped": True,
    }


def tapered_box(name: str, collection, mat, z_front: float, z_back: float,
                front_half: tuple[float, float], back_half: tuple[float, float],
                center_y: float, bevel=0.06):
    fx, fy = front_half
    bx, by = back_half
    verts = [
        (-fx, center_y-fy, z_front), (fx, center_y-fy, z_front),
        (-fx, center_y+fy, z_front), (fx, center_y+fy, z_front),
        (-bx, center_y-by, z_back), (bx, center_y-by, z_back),
        (-bx, center_y+by, z_back), (bx, center_y+by, z_back),
    ]
    faces = [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    return wedge(name, collection, mat, verts, faces, bevel)


def lofted_fuselage(name: str, collection, mat, stations, bevel=0.055):
    """Build one continuous octagonal pressure shell from z/y/width stations."""
    verts = []
    for z, half_width, low_y, high_y in stations:
        height = high_y - low_y
        verts.extend([
            (-half_width * .68, low_y, z),
            (half_width * .68, low_y, z),
            (half_width, low_y + height * .24, z),
            (half_width * .92, high_y - height * .20, z),
            (half_width * .55, high_y, z),
            (-half_width * .55, high_y, z),
            (-half_width * .92, high_y - height * .20, z),
            (-half_width, low_y + height * .24, z),
        ])
    faces = []
    ring = 8
    faces.append(tuple(reversed(range(ring))))
    for station in range(len(stations) - 1):
        start = station * ring
        following = (station + 1) * ring
        for edge in range(ring):
            nxt = (edge + 1) % ring
            faces.append((start + edge, start + nxt, following + nxt, following + edge))
    final = (len(stations) - 1) * ring
    faces.append(tuple(final + i for i in range(ring)))
    return wedge(name, collection, mat, verts, faces, bevel)


def swept_plate(name: str, collection, mat, side: float, y: float, tier: int,
                inner_x: float, outer_x: float, z_front: float, z_back: float,
                thickness: float = .12):
    """A tapered, swept side-plane shell with a real root and clipped tip."""
    tip_x = side * outer_x
    root_x = side * inner_x
    tip_front = z_front + .34 + tier * .08
    tip_back = z_back - .24 - tier * .06
    lower = y - thickness * .5
    upper = y + thickness * .5
    verts = [
        (root_x, lower, z_front), (root_x, lower, z_back),
        (tip_x, lower, tip_back), (tip_x, lower, tip_front),
        (root_x, upper, z_front), (tip_x, upper, tip_front),
        (tip_x, upper, tip_back), (root_x, upper, z_back),
    ]
    faces = [
        (0, 3, 2, 1), (4, 7, 6, 5),
        (0, 4, 5, 3), (3, 5, 6, 2),
        (2, 6, 7, 1), (1, 7, 4, 0),
    ]
    # Negating X is a reflection, not a rotation. Reverse every face on the
    # port copy so its closed shell retains positive volume and outward normals.
    if side < 0.0:
        faces = [tuple(reversed(face)) for face in faces]
    return wedge(name, collection, mat, verts, faces, .045)


def cylinder_between(name: str, start, end, radius, collection, mat,
                     vertices=28, bevel=.025):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    depth = direction.length
    if depth <= 1e-5:
        raise ValueError(f"{name} has coincident endpoints")
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=(start_v + end_v) * .5,
    )
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.normalized().to_track_quat("Z", "Y")
    return finish(obj, name, collection, mat, bevel)


def empty(name: str, loc, parent: bpy.types.Object | None, collection: bpy.types.Collection,
          rotation=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.18
    obj.location = loc
    obj.rotation_euler = rotation
    collection.objects.link(obj)
    if parent:
        obj.parent = parent
    OBJECTS[collection.name].append(name)
    return obj


def add_panel_details(collection, prefix, x_sign=1.0):
    graphite = MATS["GraphiteMachinery"]
    cyan = MATS["CyanStatus"]
    for i in range(7):
        z = -2.65 + i * 0.78
        box(f"{prefix}ServiceInset{i:02d}", (x_sign * 1.48, 1.22 + (i % 2) * .08, z),
            (.055, .36, .48), collection, graphite, .018)
        box(f"{prefix}StatusMark{i:02d}", (x_sign * 1.515, 1.28, z),
            (.018, .06, .20), collection, cyan, .008)


def build_lod0(collection):
    ivory = MATS["WarmIvoryHull"]
    ivory2 = MATS["IvorySecondary"]
    graphite = MATS["GraphiteMachinery"]
    alloy = MATS["ExposedAlloy"]
    cyan = MATS["CyanStatus"]
    amber = MATS["AmberPanel"]
    red = MATS["CrimsonSeat"]
    livery = MATS["CrimsonLivery"]
    thermal = MATS["ThermalCeramic"]

    # One continuous faceted pressure shell provides the primary read. The
    # station widths change at every section so profile and three-quarter views
    # cannot collapse back into the former long rectangular slab.
    lofted_fuselage("ContinuousPressureShell", collection, ivory, [
        (-4.80, .08, .42, .76),
        (-4.15, .58, .24, 1.05),
        (-3.25, 1.22, .16, 1.48),
        (-2.10, 1.55, .12, 1.82),
        (-.75, 1.72, .10, 2.00),
        (.75, 1.84, .12, 2.14),
        (1.85, 1.92, .16, 2.12),
        (2.75, 1.78, .22, 1.92),
        (3.42, 1.56, .32, 1.70),
    ], .075)
    # A lower keel and tapered spine add purposeful longitudinal structure
    # without masking the continuous shell or turning the aft into a wall.
    tapered_box("VentralPressureKeel", collection, ivory2, -3.45, 2.95,
                (.72, .22), (1.15, .30), .18, .055)
    tapered_box("RaisedSpine", collection, ivory2, -1.75, 2.48,
                (.42, .30), (.78, .48), 2.18, .075)
    for section in range(5):
        z = -2.65 + section * 1.18
        box(f"DorsalPanelSeam{section:02d}", (0, 2.00 + section*.055, z),
            (1.34 + section*.16, .028, .035), collection, graphite, .006)
    # Recessed service breaks and restrained warm livery interrupt the large
    # primary shell without changing the preserved pointed-nose macroform.
    dorsal_breaks = [
        ((0, 2.055, z_value), (width, .018, .055))
        for z_value, width in ((-3.38, .68), (-2.34, 1.22), (-1.16, 1.48),
                               (.12, 1.62), (1.28, 1.54), (2.28, 1.22))
    ]
    compound_boxes("DorsalAccessBreaks", dorsal_breaks, collection, graphite, .004)
    tapered_box("DorsalCrimsonLivery", collection, livery, -3.34, 1.96,
                (.11, .020), (.18, .024), 2.075, .008)
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        tapered_box(f"{s}ShoulderLivery", collection, livery, -2.70, 2.18,
                    (.045, .16), (.065, .21), 1.61, .012).location.x = side * 1.26
        for panel_index, z_value in enumerate((-2.90, -1.72, -.42, .88, 2.02)):
            box(f"{s}FlushAccessPanel{panel_index:02d}",
                (side * 1.405, 1.47 + .045 * (panel_index % 2), z_value),
                (.016, .32, .58), collection, graphite, .004)

    # Four source-recognisable tiers now use swept planform shells rooted into
    # the fuselage, rather than rotated cuboids floating alongside it.
    for side in (-1, 1):
        side_name = "Port" if side < 0 else "Starboard"
        root_shadow_parts = []
        for tier in range(4):
            y = .45 + tier * .29
            inner_x = 1.40 + tier * .05
            outer_x = 2.38 + tier * .31
            z_front = -2.65 + tier * .16
            z_back = 2.62 - tier * .12
            swept_plate(f"{side_name}SteppedPlane{tier+1}", collection, ivory,
                        side, y, tier, inner_x, outer_x, z_front, z_back)
            box(f"{side_name}PlaneTipLight{tier+1}",
                (side*outer_x, y+.075, -1.16+tier*.13),
                (.030,.035,.42), collection, cyan, .006)
            # Thin root shadows make each tier read as a bonded airframe layer;
            # the warm strip provides one coherent livery sweep, not greeble dots.
            root_shadow_parts.append((
                (side * (inner_x + .055), y - .052, -.08 + tier * .04),
                (.07, .028, 4.44 - tier * .16),
            ))
            box(f"{side_name}PlaneLiveryStrip{tier+1}",
                (side * (inner_x + .22 + tier * .10), y + .068,
                 -.86 + tier * .16),
                (.055 + tier * .012, .018, 2.46 - tier * .14),
                collection, livery, .006)
            box(f"{side_name}PlaneLeadingEdge{tier+1}",
                (side * (inner_x + .35 + tier * .12), y, z_front + .05),
                (.56 + tier * .08, .07, .055), collection, alloy, .012,
                rotation=(0, math.radians(side * (8 + tier * 2)), 0))
        compound_boxes(f"{side_name}PlaneRootShadows", root_shadow_parts,
                       collection, graphite, .006)
        # Broad root fairing visually joins the four tiers to the pressure shell.
        tapered_box(f"{side_name}PlaneRootFairing", collection, ivory2,
                    -2.85, 2.72, (.25,.45), (.42,.60), .83, .055).location.x = side*1.50

    # Recessed weapons and service bays.
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        box(f"{s}WeaponBay", (side*1.55,.78,-2.55), (.38,.48,1.35), collection, graphite, .05)
        cylinder(f"{s}PulseCannonA", (side*1.48,.78,-3.25), .075, 1.12, collection, alloy, 28)
        cylinder(f"{s}PulseCannonB", (side*1.68,.78,-3.18), .065, .96, collection, alloy, 28)
        for port in range(3):
            cylinder(f"{s}RCSNozzle{port}", (side*2.00,1.46,-1.6+port*1.35), .075, .12,
                     collection, graphite, 24, rotation=(0,math.pi/2,0))
        add_panel_details(collection, s, side)

    # Paired source-observed round housings become coherent nacelle shells. Four
    # nested depth zones (load shell, collar, recessed throat and thermal lip)
    # replace the previous stack of unrelated glossy donuts.
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        x = side*2.50
        annular_shell(
            f"{s}AftCircularHousing", collection, ivory2, (x, 1.10),
            (2.48, 2.69, 2.98, 3.16),
            (.50, .62, .61, .54), (.34, .39, .41, .39), 64, .010,
        )
        annular_shell(
            f"{s}EngineOuterCollar", collection, alloy, (x, 1.10),
            (3.12, 3.24, 3.34), (.50, .49, .44), (.37, .36, .34), 56, .008,
        )
        annular_shell(
            f"{s}EngineNozzle", collection, graphite, (x, 1.10),
            (3.27, 3.43, 3.58), (.42, .37, .32), (.32, .27, .23), 56, .006,
        )
        annular_shell(
            f"{s}EngineThermalLip", collection, thermal, (x, 1.10),
            (3.55, 3.63, 3.69), (.34, .35, .31), (.235, .225, .22), 56, .006,
        )
        for vane_index in range(8):
            angle = math.tau * vane_index / 8.0
            radius = .255
            box(
                f"{s}EngineStatorVane{vane_index:02d}",
                (x + math.cos(angle) * radius,
                 1.10 + math.sin(angle) * radius * .90, 3.705),
                (.055, .24, .055), collection, alloy, .010,
                rotation=(0, 0, angle),
            )
        cylinder(f"{s}EngineHub", (x, 1.10, 3.705), .105, .10,
                 collection, thermal, 32, bevel=.010)
        cylinder(f"{s}EngineCore", (x,1.10,3.73), .135,.024,collection,cyan,36,bevel=.008)
        cylinder(f"{s}EnginePlume", (x,1.10,4.01), .16,.52,collection,cyan,32, bevel=.01)
        tapered_box(f"{s}DominantAftRail", collection, ivory, 1.86, 2.80,
                    (.15,1.10), (.22,.88), 2.50, .075).location.x = side*2.16
        tapered_box(f"{s}RailGraphiteInset", collection, graphite, 1.82, 2.72,
                    (.055,.65), (.075,.52), 2.515, .018).location.x = side*2.16
        cylinder_between(f"{s}NacelleUpperBrace", (side*2.05,2.98,2.25),
                         (side*2.37,1.59,2.78), .045, collection, alloy, 20, .010)
        cylinder_between(f"{s}NacelleLowerBrace", (side*2.04,1.86,2.48),
                         (side*2.37,.73,2.78), .040, collection, graphite, 20, .008)
    box("AftCrossbar", (0,3.57,2.36), (4.28,.22,.26), collection,alloy,.045)
    for i in range(8):
        box(f"AftMachineryRib{i:02d}", (-1.35+i*.385,1.42,3.52),
            (.12,.70,.12), collection,alloy,.018)
    # A deep graphite engine/service recess breaks the old blank aft wall and
    # visually connects the paired nozzles to one credible machinery bay.
    box("AftMachineryRecess", (0,1.22,3.15), (2.68,1.04,.56), collection,graphite,.04)
    box("AftBayFrameTop", (0,1.76,3.60), (2.78,.10,.13), collection,alloy,.018)
    box("AftBayFrameLower", (0,.69,3.60), (2.78,.10,.13), collection,alloy,.018)
    box("AftBayFramePort", (-1.34,1.22,3.60), (.10,1.02,.13), collection,alloy,.018)
    box("AftBayFrameStarboard", (1.34,1.22,3.60), (.10,1.02,.13), collection,alloy,.018)
    for conduit_index, y_value in enumerate((.88, 1.10, 1.34, 1.56)):
        conduit_z = 3.47 + conduit_index * .030
        cylinder_between(f"AftBayConduit{conduit_index:02d}", (-1.18,y_value,conduit_z),
                         (1.18,y_value,conduit_z), .025, collection,
                         cyan if conduit_index == 1 else alloy, 18, .006)
    annular_shell("CentralAftDockingMechanism", collection, alloy, (0,.78),
                  (3.50,3.62,3.72), (.39,.38,.33), (.24,.23,.20), 40,.007)
    cylinder("CentralAftDockingCore", (0,.78,3.69), .18,.05,collection,thermal,32,bevel=.008)
    for side in (-1,1):
        s="Port" if side<0 else "Starboard"
        box(f"{s}AftShoulderCutout",(side*1.48,1.25,3.58),(.58,.72,.22),collection,graphite,.05)
        for i in range(4):
            cylinder(f"{s}AftServiceCoupling{i}",(side*(1.25+i*.13),1.42,3.75),.045,.08,
                     collection,cyan,18,bevel=.008)

    # One authored cockpit visual authority. These live under CockpitArt so the
    # runtime adapter can mount them beneath the existing functional cockpit
    # root without duplicating the legacy mesh bank.
    cockpit_collection = bpy.data.collections["CockpitArt"]
    tapered_box("CockpitFloorShell", cockpit_collection, graphite, -2.18, .88,
                (.82,.075), (1.02,.095), 1.94, .055)
    tapered_box("CockpitSideTub", cockpit_collection, ivory2, -2.06, .92,
                (1.02,.22), (1.08,.29), 2.19, .065)
    tapered_box("CrimsonSeatPan", cockpit_collection, red, -.40, .36,
                (.34,.10), (.39,.13), 2.10, .075)
    tapered_box("CrimsonSeatBack", cockpit_collection, red, -.02, .48,
                (.37,.42), (.31,.35), 2.56, .085)
    box("SeatHeadrest", (0,2.98,.30), (.48,.26,.16), cockpit_collection,red,.075,
        rotation=(math.radians(-8),0,0))
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        box(f"{s}SeatBolster", (side*.38,2.40,.02), (.16,.62,.22),
            cockpit_collection,red,.07,rotation=(math.radians(-7),0,side*math.radians(3)))
        cylinder_between(f"{s}ShoulderHarness", (side*.22,2.93,.28),
                         (side*.13,2.30,-.02), .026, cockpit_collection,alloy,16,.008)
        cylinder_between(f"{s}LapHarness", (side*.34,2.34,-.18),
                         (side*.08,2.20,-.30), .026, cockpit_collection,alloy,16,.008)
    box("HarnessBuckle", (0,2.22,-.26), (.16,.08,.12), cockpit_collection,alloy,.020)

    tapered_box("InstrumentHood", cockpit_collection, graphite, -1.75, -1.06,
                (.66,.13), (.82,.19), 2.70, .065)
    tapered_box("InstrumentBinnacle", cockpit_collection, ivory2, -1.82, -1.00,
                (.78,.18), (.91,.24), 2.55, .060)
    box("PrimaryDisplay", (0,2.72,-1.55), (.74,.25,.025), cockpit_collection,cyan,.012,
        rotation=(math.radians(-16),0,0))
    box("PrimaryDisplayBezel", (0,2.70,-1.54), (.94,.34,.045),
        cockpit_collection,graphite,.025,rotation=(math.radians(-16),0,0))
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        box(f"{s}StatusDisplay", (side*.58,2.69,-1.45), (.28,.18,.022),
            cockpit_collection,cyan,.010,rotation=(math.radians(-16),0,side*math.radians(4)))
        compound_boxes(f"{s}StatusRepeaterCluster", [
            ((side*(.46+repeater*.11),2.82,-1.31),(.065,.035,.018))
            for repeater in range(3)
        ],cockpit_collection,cyan,.006)
    box("WarningStatusRegion", (0,2.84,-1.32), (.32,.035,.018),
        cockpit_collection,cyan,.006,rotation=(math.radians(-16),0,0))

    tapered_box("PortConsole", cockpit_collection, graphite, -1.48, .18,
                (.18,.10), (.15,.13), 2.28, .040).location.x = -.76
    tapered_box("StarboardConsole", cockpit_collection, graphite, -1.48, .18,
                (.18,.10), (.15,.13), 2.28, .040).location.x = .76
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        compound_boxes(f"{s}ConsoleKeyCluster", [
            ((side*(.70+key*.035),2.40+row*.045,-1.18+key*.27),
             (.035,.022,.065))
            for row in range(2) for key in range(4)
        ],cockpit_collection,alloy,.004)
        compound_boxes(f"{s}ConsoleStatusLamps", [
            ((side*.775,2.445,-1.10+lamp*.37),(.020,.018,.055))
            for lamp in range(3)
        ],cockpit_collection,cyan,.003)
        for rotary in range(2):
            cylinder(f"{s}ConsoleRotary{rotary}",
                     (side*.765,2.43,-.48+rotary*.31),.038,.035,
                     cockpit_collection,alloy,16,rotation=(math.pi/2,0,0),bevel=.006)

    cylinder_between("ControlStick", (.30,2.22,-.64), (.30,2.56,-.78), .035,
                     cockpit_collection,alloy,24,.010)
    box("ControlStickGrip", (.30,2.59,-.79), (.11,.18,.09),
        cockpit_collection,graphite,.030,rotation=(math.radians(-12),0,0))
    cylinder_between("ThrottleLever", (-.70,2.30,-.30), (-.76,2.55,-.34), .035,
                     cockpit_collection,alloy,24,.010)
    box("ThrottleGrip", (-.76,2.59,-.34), (.16,.10,.12),cockpit_collection,graphite,.028)
    for side in (-1, 1):
        s = "Port" if side < 0 else "Starboard"
        cylinder_between(f"{s}RudderPedalStem", (side*.28,2.02,-1.12),
                         (side*.32,2.18,-1.46), .025, cockpit_collection,alloy,16,.006)
        box(f"{s}RudderPedal", (side*.32,2.19,-1.49), (.26,.07,.12),
            cockpit_collection,graphite,.020,rotation=(math.radians(-18),0,0))
    box("AmberUnknownFunctionPanel", (0,1.06,-3.88), (.72,.045,.26), collection,amber,.03)

    # Canopy art is exported under a separate functional pivot root.
    canopy_collection = bpy.data.collections["CanopyPivot"]
    canopy_glass_shell("CanopyGlass", canopy_collection, MATS["NeutralCanopyGlass"])
    cylinder_between("CanopyForwardFrame", (-.78,.02,-3.13),(.78,.02,-3.13),.045,
                     canopy_collection,alloy,24,.010)
    for side in (-1,1):
        s = "Port" if side < 0 else "Starboard"
        cylinder_between(f"{s}CanopySill", (side*.78,.02,-3.13),
                         (side*.82,.02,.01),.040,canopy_collection,alloy,22,.010)
        cylinder_between(f"{s}CanopyUpright", (side*.82,.02,.01),
                         (side*.57,.66,.03),.040,canopy_collection,alloy,22,.010)
        cylinder_between(f"{s}CanopyForwardRake", (side*.78,.02,-3.13),
                         (side*.46,.54,-3.12),.040,canopy_collection,alloy,22,.010)
        cylinder_between(f"{s}CanopySideRail", (side*.82,.02,-2.48),
                         (side*.93,.83,-.36),.030,canopy_collection,alloy,20,.008)
        cylinder_between(f"{s}CanopySeal", (side*.75,.015,-3.04),
                         (side*.78,.015,-.04),.025,canopy_collection,graphite,18,.006)
        cylinder(f"{s}CanopyHinge", (side*.62,.08,.03),.075,.20,
                 canopy_collection,graphite,24,rotation=(0,math.pi/2,0),bevel=.010)
        box(f"{s}CanopyLatch", (side*.88,.16,-1.08),(.10,.18,.18),
            canopy_collection,graphite,.025)
        box(f"{s}CanopyStriker", (side*.92,.02,-1.08),(.12,.05,.24),
            canopy_collection,alloy,.018)
    cylinder_between("CanopyTopSpine", (0,.54,-3.12),(0,.66,.03),.035,
                     canopy_collection,alloy,22,.008)
    cylinder_between("CanopyRearFrame", (-.57,.66,.03),(.57,.66,.03),.040,
                     canopy_collection,alloy,24,.010)
    cylinder_between("CanopyRearSeal", (-.51,.62,.02),(.51,.62,.02),.025,
                     canopy_collection,graphite,18,.006)
    cylinder_between("CanopyHingeBar", (-.62,.08,.03),(.62,.08,.03),.035,
                     canopy_collection,graphite,24,.008)

    # Mechanically legible tricycle gear. Every assembly has an upper pivot,
    # telescoping oleo, trailing brace, split fork, articulated ankle/foot and a
    # restrained hydraulic line while preserving the exact parked contacts.
    def gear(side, name, root, foot):
        cylinder(name+"UpperPivot", root, .14, .34, collection, thermal, 28,
                 rotation=(0, math.pi/2, 0), bevel=.018)
        upper_joint = (side*1.60,.08,1.04)
        lower_joint = (side*1.84,-.43,1.20)
        cylinder_between(name+"Strut", root, lower_joint, .080, collection, alloy, 28,.014)
        cylinder_between(name+"OleoSleeve", upper_joint, lower_joint, .105,
                         collection, thermal, 28,.016)
        cylinder_between(name+"TrailingBrace", (side*1.42,.08,.82),
                         (side*1.83,-.52,1.02), .045, collection, alloy, 20,.008)
        cylinder_between(name+"Shock", (side*1.62,.05,1.04),
                         (side*1.87,-.50,1.22), .040, collection, alloy, 20,.010)
        cylinder_between(name+"ForkForward", lower_joint,
                         (foot[0],-.57,foot[2]-.30), .040, collection, alloy, 20,.008)
        cylinder_between(name+"ForkAft", lower_joint,
                         (foot[0],-.57,foot[2]+.30), .040, collection, alloy, 20,.008)
        cylinder(name+"Ankle", (foot[0],-.55,foot[2]), .11,.34,collection,
                 thermal,24,rotation=(0,math.pi/2,0),bevel=.014)
        articulated_foot(name+"Foot", foot, (.82,.15,1.05),collection,graphite)
        cylinder_between(name+"HydraulicLine", (side*1.54,.04,.98),
                         (side*1.80,-.46,1.10), .018, collection, thermal, 14,.004)
        # Two positive mechanical capture jaws make the parked/docking purpose
        # readable in the close presentation instead of leaving a generic pad.
        tapered_capture_jaw(name+"ClampJawForward", (foot[0],-.57,foot[2]-.48),
                            (.56,.18,.18),-1.0,collection,thermal)
        tapered_capture_jaw(name+"ClampJawAft", (foot[0],-.57,foot[2]+.48),
                            (.56,.18,.18),1.0,collection,thermal)
    gear(-1,"PortMainGear",(-1.55,.22,1.0),(-1.92,-.68,1.25))
    gear(1,"StarboardMainGear",(1.55,.22,1.0),(1.92,-.68,1.25))
    cylinder("NoseGearUpperPivot", (0,.24,-2.88),.13,.32,collection,thermal,28,
             rotation=(math.pi/2,0,0),bevel=.016)
    cylinder_between("NoseGearStrut", (0,.25,-2.88), (0,-.40,-3.02),
                     .070,collection,alloy,24,.012)
    cylinder_between("NoseGearOleoSleeve", (0,.03,-2.93),(0,-.40,-3.02),
                     .095,collection,thermal,24,.014)
    cylinder_between("NoseGearTrailingBrace", (0,.12,-2.62),(0,-.38,-3.00),
                     .040,collection,alloy,18,.008)
    cylinder_between("NoseGearForkPort", (0,-.38,-3.02),(-.24,-.54,-3.05),
                     .038,collection,alloy,18,.006)
    cylinder_between("NoseGearForkStarboard", (0,-.38,-3.02),(.24,-.54,-3.05),
                     .038,collection,alloy,18,.006)
    cylinder("NoseGearAnkle", (0,-.52,-3.05),.10,.48,collection,thermal,24,
             rotation=(0,math.pi/2,0),bevel=.012)
    articulated_foot("NoseGearFoot", (0,-.58,-3.05),(.68,.15,.82),collection,graphite)
    cylinder_between("NoseGearHydraulicLine", (.045,.14,-2.87),(.05,-.41,-3.01),
                     .016,collection,thermal,12,.004)
    tapered_capture_jaw("NoseGearCaptureClamp", (0,-.48,-3.05),(.38,.18,.48),
                        1.0,collection,thermal)
    annular_shell("VentralDockingReceiver",collection,alloy,(0,-.04),
                  (.20,.30,.40),(.40,.38,.34),(.23,.22,.20),40,.008)
    for i in range(3):
        box(f"PortBoardingStep{i}", (-2.18-i*.36,-.02+i*.28,.40), (.68,.12,.70),collection,alloy,.035)
    cylinder("PortBoardingHandhold", (-1.58,1.28,.32), .035,.88,collection,alloy,20,rotation=(0,0,0))

    # Countersunk flush treatment and zoned vent louvres provide the third scale
    # of detail without the former protruding black-dot fastener read.
    for side in (-1,1):
        s = "Port" if side<0 else "Starboard"
        for i in range(9):
            fastener = cylinder(
                f"{s}HullFastener{i:02d}",
                (side * 1.225, 1.59, -2.42 + i * .62),
                .018,
                .014,
                collection,
                graphite,
                16,
                rotation=(0, math.pi / 2, 0),
                bevel=.003,
            )
            # Preserve the existing evaluated topology while turning the round
            # protrusion into a shallow, elongated screw-slot buried into the
            # shell shoulder.  Scaling stays object-local so the export-only
            # modifier has the same deterministic face roster as before.
            fastener.scale = (1.8, .30, .18)
        for i in range(7):
            box(f"{s}AftVentLouver{i:02d}",
                (side*(.76 + .04*(i%2)),2.055,1.34+i*.18),
                (.52-.03*(i%3),.025,.060),collection,thermal,.008,
                rotation=(math.radians(-5),0,0))


def build_lod1(collection):
    ivory = MATS["WarmIvoryHull"]
    ivory2 = MATS["IvorySecondary"]
    graphite = MATS["GraphiteMachinery"]
    cyan = MATS["CyanStatus"]
    alloy = MATS["ExposedAlloy"]
    thermal = MATS["ThermalCeramic"]
    lofted_fuselage("LOD1ContinuousHull", collection, ivory, [
        (-4.80,.08,.42,.76), (-3.25,1.22,.16,1.48),
        (-.75,1.72,.10,2.00), (1.85,1.92,.16,2.12),
        (3.42,1.56,.32,1.70),
    ], .085)
    for side in (-1,1):
        s="Port" if side<0 else "Starboard"
        for tier in range(4):
            swept_plate(f"LOD1{s}Plane{tier+1}", collection, ivory, side,
                        .45+tier*.29, tier, 1.40+tier*.05,
                        2.38+tier*.31, -2.65+tier*.16,
                        2.62-tier*.12, .12)
        annular_shell(f"LOD1{s}Housing",collection,ivory2,(side*2.5,1.1),
                      (2.50,2.86,3.18,3.55),(.50,.62,.54,.34),
                      (.33,.40,.37,.22),32,.008)
        annular_shell(f"LOD1{s}Throat",collection,thermal,(side*2.5,1.1),
                      (3.30,3.53,3.67),(.40,.34,.29),(.28,.23,.19),28,.006)
        cylinder(f"LOD1{s}EnginePlume",(side*2.5,1.1,3.86),.15,.55,collection,cyan,24,bevel=.01)
        tapered_box(f"LOD1{s}Rail",collection,ivory,1.86,2.80,
                    (.15,1.10),(.22,.88),2.50,.075).location.x=side*2.16
    box("LOD1AftCrossbar",(0,3.57,2.36),(4.28,.22,.26),collection,ivory,.05)


def setup_scene() -> dict:
    for object_names in OBJECTS.values():
        object_names.clear()
    MATS.clear()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    scene_collection = bpy.context.scene.collection
    hero = bpy.data.collections.new("TorrentHeroArt")
    scene_collection.children.link(hero)
    for name in OBJECTS:
        child = bpy.data.collections.new(name)
        hero.children.link(child)
    material("WarmIvoryHull", (.90,.88,.78,1), .08,.48)
    material("IvorySecondary", (.72,.74,.68,1), .16,.42)
    material("GraphiteMachinery", (.025,.04,.045,1), .58,.28)
    material("ExposedAlloy", (.23,.28,.29,1), .78,.22)
    material("CyanStatus", (.04,.64,.70,1), .14,.20,(.02,.75,.84,1))
    material("AmberPanel", (.92,.55,.08,1), .16,.30,(.35,.12,.01,1))
    material("CrimsonSeat", (.38,.025,.035,1), .04,.68)
    material("CrimsonLivery", (.48,.035,.045,1), .12,.43)
    material("ThermalCeramic", (.075,.085,.082,1), .34,.64)
    glass = material("NeutralCanopyGlass", (.08,.20,.22,.22), .12,.08)
    glass.blend_method = "BLEND"
    glass.use_screen_refraction = True
    build_lod0(bpy.data.collections["LOD0"])
    build_lod1(bpy.data.collections["LOD1"])
    uv_contract = ensure_deterministic_uv0()
    anchors = bpy.data.collections["SemanticAnchors"]
    anchor_values = {
        "PilotSeatAnchor": ((0,1.56,-.02),(0,0,0)),
        "BoardingEntry": ((-1.42,2.32,.18),(0,-math.pi/2,0)),
        "BoardingPoint": ((-3.2,.05,.65),(0,0,0)),
        "ExitPoint": ((-7.6,-1,.75),(0,-math.pi/2,0)),
        "LeftMuzzle": ((-2.82,.42,-3.42),(0,0,0)),
        "RightMuzzle": ((2.82,.42,-3.42),(0,0,0)),
        "CockpitCamera": ((0,3.32,-.52),(0,0,0)),
        "PortEngineLight": ((-2.52,1.02,3.605),(0,0,0)),
        "StarboardEngineLight": ((2.52,1.02,3.605),(0,0,0)),
        "PortMainGearContact": ((-1.92,-.755,1.25),(0,0,0)),
        "StarboardMainGearContact": ((1.92,-.755,1.25),(0,0,0)),
        "NoseGearContact": ((0,-.655,-3.05),(0,0,0)),
        "BoardingStepContact0": ((-2.15,-.02,.40),(0,0,0)),
        "BoardingStepContact1": ((-2.53,.26,.40),(0,0,0)),
        "BoardingStepContact2": ((-2.91,.54,.40),(0,0,0)),
        "PortHandhold": ((-1.58,1.28,.32),(0,0,0)),
    }
    for name,(loc,rot) in anchor_values.items():
        empty(name,loc,None,anchors,rot)
    # Collections are an authoring convenience but glTF does not guarantee that
    # they become runtime nodes. Explicit empties publish the stable Godot
    # hierarchy and retain every child's ship-local transform.
    hierarchy_root = bpy.data.objects.new("TorrentHeroArt", None)
    hero.objects.link(hierarchy_root)
    for hierarchy_name in OBJECTS:
        hierarchy = bpy.data.objects.new(hierarchy_name, None)
        hero.objects.link(hierarchy)
        hierarchy.parent = hierarchy_root
        if hierarchy_name == "CanopyPivot":
            hierarchy.location = (0.0, 2.42, 1.02)
        for child_obj in list(bpy.data.collections[hierarchy_name].objects):
            world_matrix = child_obj.matrix_world.copy()
            child_obj.parent = hierarchy
            # Keep the authored object values local to the exported semantic
            # root. Assigning matrix_world here makes Blender evaluate an
            # unnecessary parent inverse that some glTF consumers collapse.
            child_obj.matrix_parent_inverse.identity()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene["asset_id"] = "torrent_hero_art_v1"
    bpy.context.scene["authorship"] = "original_script_assisted_blender"
    bpy.context.scene["authenticated_historical_geometry"] = False
    bpy.context.scene["uv0_contract_method"] = uv_contract["method"]
    bpy.context.scene["uv0_source_mesh_count"] = int(uv_contract["mesh_count"])
    return uv_contract


def mesh_counts_by_root() -> dict[str, int]:
    """Count direct mesh children of each published semantic root collection."""
    return {
        root_name: sum(
            1 for obj in bpy.data.collections[root_name].objects if obj.type == "MESH"
        )
        for root_name in OBJECTS
    }


def _single_material(obj: bpy.types.Object) -> bpy.types.Material:
    if obj.type != "MESH" or len(obj.data.materials) != 1 or obj.data.materials[0] is None:
        raise RuntimeError(f"Static batch member must have exactly one material: {obj.name}")
    material_value = obj.data.materials[0]
    if any(polygon.material_index != 0 for polygon in obj.data.polygons):
        raise RuntimeError(f"Static batch member uses an unexpected material slot: {obj.name}")
    return material_value


def _apply_modifiers(obj: bpy.types.Object) -> None:
    """Bake one source object's production modifiers before it enters a batch."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        result = bpy.ops.object.modifier_apply(modifier=modifier.name)
        if "FINISHED" not in result:
            raise RuntimeError(f"Unable to apply {modifier.name} on {obj.name}: {result}")


def _apply_deterministic_custom_normals(obj: bpy.types.Object) -> None:
    """Remove exporter/thread-order variance from smooth hard-surface normals."""
    def canonical_normal(value: Vector) -> Vector:
        normalized = value.normalized()
        return Vector(tuple(
            0.0 if abs(float(component)) <= 1e-12 else float(component)
            for component in normalized
        ))

    mesh = obj.data
    face_vectors: list[Vector] = []
    face_normals: list[Vector] = []
    vertex_face_vectors: list[list[Vector]] = [[] for _vertex in mesh.vertices]
    for polygon in mesh.polygons:
        indices = list(polygon.vertices)
        origin = mesh.vertices[indices[0]].co
        area_vector = Vector((0.0, 0.0, 0.0))
        for index in range(1, len(indices) - 1):
            edge_a = mesh.vertices[indices[index]].co - origin
            edge_b = mesh.vertices[indices[index + 1]].co - origin
            area_vector += edge_a.cross(edge_b)
        if area_vector.length_squared <= 1e-20:
            area_vector = Vector((0.0, 1.0, 0.0))
        face_vectors.append(area_vector)
        face_normal = canonical_normal(area_vector)
        face_normals.append(face_normal)
        if polygon.use_smooth:
            for vertex_index in indices:
                vertex_face_vectors[vertex_index].append(area_vector.copy())
    vertex_normals = []
    for values in vertex_face_vectors:
        ordered = sorted(values, key=lambda value: tuple(float(component) for component in value))
        summed = Vector(tuple(
            math.fsum(float(value[component_index]) for value in ordered)
            for component_index in range(3)
        ))
        vertex_normals.append(
            canonical_normal(summed)
            if summed.length_squared > 1e-20 else Vector((0.0, 1.0, 0.0))
        )
    loop_normals = []
    for polygon_index, polygon in enumerate(mesh.polygons):
        for loop_index in polygon.loop_indices:
            loop_normals.append(
                vertex_normals[mesh.loops[loop_index].vertex_index]
                if polygon.use_smooth else face_normals[polygon_index]
            )
    mesh.normals_split_custom_set(loop_normals)


def consolidate_static_lod_meshes() -> dict[str, dict[str, list[str]]]:
    """Join export-only static meshes by semantic LOD root and material.

    The function is deliberately called only after ``BLEND_PATH`` is saved.
    Protected meshes keep their names and independent nodes because runtime code
    may animate or discover them. All other meshes beneath each batchable root,
    including static cockpit and canopy detail, join by material; semantic
    anchors remain unbatched.
    """
    batch_member_map: dict[str, dict[str, list[str]]] = {}
    for root_name in BATCHABLE_ROOTS:
        collection = bpy.data.collections[root_name]
        protected = set(PROTECTED_MESHES_BY_ROOT[root_name])
        source_meshes = sorted(
            (obj for obj in collection.objects if obj.type == "MESH"),
            key=lambda obj: obj.name,
        )
        source_names = {obj.name for obj in source_meshes}
        missing_protected = sorted(protected - source_names)
        if missing_protected:
            raise RuntimeError(
                f"{root_name} is missing protected runtime meshes: {missing_protected}"
            )

        by_material: dict[str, list[bpy.types.Object]] = {}
        for obj in source_meshes:
            if obj.name in protected:
                _apply_modifiers(obj)
                continue
            material_name = _single_material(obj).name
            by_material.setdefault(material_name, []).append(obj)

        root_batches: dict[str, list[str]] = {}
        for material_name in sorted(by_material):
            members = sorted(by_material[material_name], key=lambda obj: obj.name)
            member_names = [obj.name for obj in members]
            material_value = MATS[material_name]
            for obj in members:
                _apply_modifiers(obj)

            bpy.ops.object.select_all(action="DESELECT")
            for obj in members:
                obj.select_set(True)
            batch = members[0]
            bpy.context.view_layer.objects.active = batch
            if len(members) > 1:
                result = bpy.ops.object.join()
                if "FINISHED" not in result:
                    raise RuntimeError(
                        f"Unable to join {root_name}/{material_name} static batch: {result}"
                    )

            batch_name = f"{root_name}StaticBatch_{material_name}"
            batch.name = batch_name
            batch.data.name = f"{batch_name}Mesh"
            for polygon in batch.data.polygons:
                polygon.material_index = 0
            batch.data.materials.clear()
            batch.data.materials.append(material_value)
            if batch.parent is None or batch.parent.name != root_name:
                raise RuntimeError(f"Static batch escaped its semantic root: {batch_name}")
            root_batches[batch_name] = member_names
        batch_member_map[root_name] = root_batches
        for obj in sorted(
            (candidate for candidate in collection.objects if candidate.type == "MESH"),
            key=lambda candidate: candidate.name,
        ):
            _apply_deterministic_custom_normals(obj)
    return batch_member_map


def mesh_metrics(evaluated: bool = False):
    vertices = triangles = 0
    bounds = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        evaluated_obj = None
        if evaluated:
            evaluated_obj = obj.evaluated_get(depsgraph)
            mesh = evaluated_obj.to_mesh()
        vertices += len(mesh.vertices)
        triangles += sum(max(1, len(p.vertices)-2) for p in mesh.polygons)
        bounds.extend([obj.matrix_world @ Vector(corner) for corner in obj.bound_box])
        if evaluated_obj is not None:
            evaluated_obj.to_mesh_clear()
    minimum = [min(v[i] for v in bounds) for i in range(3)]
    maximum = [max(v[i] for v in bounds) for i in range(3)]
    return vertices, triangles, minimum, maximum


def evaluated_art_quality_metrics() -> dict:
    """Return topology and material-area evidence by semantic source root."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    roots = {}
    material_area = {name: 0.0 for name in MATS}
    pale_exterior_area = 0.0
    for root_name in OBJECTS:
        root_vertices = root_triangles = root_meshes = 0
        root_area = 0.0
        for obj in sorted(bpy.data.collections[root_name].objects, key=lambda value: value.name):
            if obj.type != "MESH":
                continue
            evaluated_obj = obj.evaluated_get(depsgraph)
            evaluated_mesh = evaluated_obj.to_mesh()
            try:
                root_meshes += 1
                root_vertices += len(evaluated_mesh.vertices)
                root_triangles += sum(max(1, len(polygon.vertices) - 2)
                                      for polygon in evaluated_mesh.polygons)
                object_area = sum(float(polygon.area) for polygon in evaluated_mesh.polygons)
                root_area += object_area
                material_name = _single_material(obj).name
                material_area[material_name] += object_area
                if root_name == "LOD0" and material_name in {
                    "WarmIvoryHull", "IvorySecondary"
                }:
                    pale_exterior_area += object_area
            finally:
                evaluated_obj.to_mesh_clear()
        roots[root_name] = {
            "mesh_count": root_meshes,
            "evaluated_vertex_count": root_vertices,
            "evaluated_triangle_count": root_triangles,
            "evaluated_surface_area_m2": round(root_area, 6),
        }
    close_roots = ("LOD0", "CockpitArt", "CanopyPivot")
    close_triangles = sum(roots[name]["evaluated_triangle_count"] for name in close_roots)
    far_triangles = roots["LOD1"]["evaluated_triangle_count"]
    exterior_area = roots["LOD0"]["evaluated_surface_area_m2"]
    return {
        "roots": roots,
        "close_triangle_count": close_triangles,
        "far_triangle_count": far_triangles,
        "total_triangle_count": close_triangles + far_triangles,
        "material_surface_area_m2": {
            name: round(value, 6) for name, value in sorted(material_area.items())
        },
        "pale_exterior_surface_ratio": round(
            pale_exterior_area / exterior_area if exterior_area > 0.0 else 0.0, 6
        ),
        "pale_material_roles": ["WarmIvoryHull", "IvorySecondary"],
    }


def swept_plate_outward_winding_audit() -> dict:
    """Require all sixteen reflected side-plane shells to remain outward-wound."""
    expected_names = [
        f"{side}SteppedPlane{tier}"
        for side in ("Port", "Starboard") for tier in range(1, 5)
    ] + [
        f"LOD1{side}Plane{tier}"
        for side in ("Port", "Starboard") for tier in range(1, 5)
    ]
    volumes = {}
    for name in expected_names:
        obj = bpy.data.objects.get(name)
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"Swept-plate winding audit is missing {name}")
        volume_terms = []
        for polygon in obj.data.polygons:
            indices = list(polygon.vertices)
            first = obj.data.vertices[indices[0]].co
            for index in range(1, len(indices) - 1):
                second = obj.data.vertices[indices[index]].co
                third = obj.data.vertices[indices[index + 1]].co
                volume_terms.append(float(first.dot(second.cross(third))))
        signed_six_volume = math.fsum(volume_terms)
        signed_volume = signed_six_volume / 6.0
        volumes[name] = round(signed_volume, 9)
        if signed_volume <= 1e-9:
            raise RuntimeError(
                f"Swept plate {name} is inward-wound: signed volume {signed_volume}"
            )
    return {
        "schema_version": 1,
        "method": "closed_mesh_signed_tetrahedron_volume_v1",
        "expected_object_count": 16,
        "all_positive_outward_winding": True,
        "signed_volume_m3_by_object": volumes,
        "minimum_signed_volume_m3": min(volumes.values()),
    }


def _distance_to_axis_aligned_box(point: Vector, contract: dict) -> float:
    """Euclidean miss distance; zero means the point is inside/on the box."""
    center = Vector(contract["position"])
    half_size = Vector(contract["size"]) * 0.5
    delta = point - center
    outside = Vector((
        max(abs(delta.x) - half_size.x, 0.0),
        max(abs(delta.y) - half_size.y, 0.0),
        max(abs(delta.z) - half_size.z, 0.0),
    ))
    return outside.length


def _collision_category(object_name: str) -> str:
    if object_name in COLLISION_PROPULSION_OBJECTS:
        return "propulsion"
    if object_name in COLLISION_PARKED_GEAR_OBJECTS:
        return "parked_gear"
    return "primary_hull"


def collision_art_alignment_audit() -> dict:
    """Prove coverage from evaluated semantic source vertices, before batching.

    This deliberately audits exact objects rather than material roles.
    CockpitArt and the closed CanopyPivot are included so the contract covers
    the entire visible close craft. Engine plumes and tiny navigation lights are
    explicit effects, not implicit exceptions hidden by a broad name or
    material filter. LOD1 is excluded only because it duplicates the audited
    close silhouette.
    """
    source_collections = ("LOD0", "CockpitArt", "CanopyPivot")
    source_objects = sorted(
        (
            obj
            for collection_name in source_collections
            for obj in bpy.data.collections[collection_name].objects
            if obj.type == "MESH"
        ),
        key=lambda obj: obj.name,
    )
    source_names = {obj.name for obj in source_objects}
    exclusion_names = set(COLLISION_EXCLUDED_OBJECTS)
    missing_exclusions = sorted(exclusion_names - source_names)
    if missing_exclusions:
        raise RuntimeError(
            f"Collision coverage exclusions are absent from visible source: {missing_exclusions}"
        )
    classified_names = COLLISION_PROPULSION_OBJECTS | COLLISION_PARKED_GEAR_OBJECTS
    missing_classified = sorted(classified_names - source_names)
    if missing_classified:
        raise RuntimeError(
            f"Collision coverage classified objects are absent from visible source: {missing_classified}"
        )
    if classified_names & exclusion_names:
        raise RuntimeError("Collision coverage includes a classified object in its exclusions")

    root = bpy.data.objects.get("TorrentHeroArt")
    if root is None:
        raise RuntimeError("Collision coverage requires the TorrentHeroArt root")
    root_inverse = root.matrix_world.inverted_safe()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    categories: dict[str, dict] = {
        name: {
            "objects": [],
            "object_count": 0,
            "evaluated_vertex_count": 0,
            "uncovered_vertex_count": 0,
            "vertices_over_tolerance": 0,
            "maximum_uncovered_distance_m": 0.0,
            "worst_object": "",
            "worst_vertex_root_local_m": [0.0, 0.0, 0.0],
        }
        for name in ("primary_hull", "propulsion", "parked_gear")
    }
    objects_over_tolerance: list[str] = []

    for obj in source_objects:
        if obj.name in exclusion_names:
            continue
        category = categories[_collision_category(obj.name)]
        category["objects"].append(obj.name)
        category["object_count"] += 1
        evaluated_obj = obj.evaluated_get(depsgraph)
        evaluated_mesh = evaluated_obj.to_mesh()
        object_over_tolerance = False
        try:
            local_matrix = root_inverse @ evaluated_obj.matrix_world
            for vertex in evaluated_mesh.vertices:
                point = local_matrix @ vertex.co
                miss = min(
                    _distance_to_axis_aligned_box(point, box_contract)
                    for box_contract in COLLISION_BOX_CONTRACT.values()
                )
                category["evaluated_vertex_count"] += 1
                if miss > 1e-9:
                    category["uncovered_vertex_count"] += 1
                if miss > COLLISION_COVERAGE_TOLERANCE_M + 1e-6:
                    category["vertices_over_tolerance"] += 1
                    object_over_tolerance = True
                if miss > category["maximum_uncovered_distance_m"]:
                    category["maximum_uncovered_distance_m"] = miss
                    category["worst_object"] = obj.name
                    category["worst_vertex_root_local_m"] = list(point)
        finally:
            evaluated_obj.to_mesh_clear()
        if object_over_tolerance:
            objects_over_tolerance.append(obj.name)

    included_object_count = sum(value["object_count"] for value in categories.values())
    evaluated_vertex_count = sum(
        value["evaluated_vertex_count"] for value in categories.values()
    )
    uncovered_vertex_count = sum(
        value["uncovered_vertex_count"] for value in categories.values()
    )
    vertices_over_tolerance = sum(
        value["vertices_over_tolerance"] for value in categories.values()
    )
    maximum_uncovered_distance = max(
        value["maximum_uncovered_distance_m"] for value in categories.values()
    )
    valid = (
        included_object_count + len(exclusion_names) == len(source_objects)
        and evaluated_vertex_count > 0
        and all(value["object_count"] > 0 for value in categories.values())
        and vertices_over_tolerance == 0
        and not objects_over_tolerance
        and maximum_uncovered_distance <= COLLISION_COVERAGE_TOLERANCE_M + 1e-6
    )
    if not valid:
        raise RuntimeError(
            "Evaluated Torrent source exceeds its collision coverage contract: "
            f"max={maximum_uncovered_distance}, vertices={vertices_over_tolerance}, "
            f"objects={objects_over_tolerance}"
        )

    def rounded(value: float) -> float:
        return round(float(value), 9)

    for category in categories.values():
        category["maximum_uncovered_distance_m"] = rounded(
            category["maximum_uncovered_distance_m"]
        )
        category["worst_vertex_root_local_m"] = [
            rounded(component) for component in category["worst_vertex_root_local_m"]
        ]

    self_audit_checks = {
        "exact_source_roster_accounted_for": (
            included_object_count + len(exclusion_names) == len(source_objects)
            and len(exclusion_names) == 10
        ),
        "category_partition_is_complete": (
            set().union(*(set(value["objects"]) for value in categories.values()))
            == source_names - exclusion_names
        ),
        "category_totals_match_overall": (
            included_object_count == sum(
                value["object_count"] for value in categories.values()
            )
            and evaluated_vertex_count == sum(
                value["evaluated_vertex_count"] for value in categories.values()
            )
            and vertices_over_tolerance == sum(
                value["vertices_over_tolerance"] for value in categories.values()
            )
        ),
        "maximum_matches_category_maximum": abs(
            rounded(maximum_uncovered_distance)
            - max(value["maximum_uncovered_distance_m"] for value in categories.values())
        ) <= 1e-9,
        "no_evaluated_vertex_exceeds_tolerance": (
            vertices_over_tolerance == 0 and not objects_over_tolerance
        ),
        "maximum_within_two_centimetres": (
            maximum_uncovered_distance <= COLLISION_COVERAGE_TOLERANCE_M + 1e-6
        ),
        "seven_unique_axis_aligned_boxes": len(COLLISION_BOX_CONTRACT) == 7,
    }
    if not all(self_audit_checks.values()):
        raise RuntimeError(f"Collision coverage self-audit failed: {self_audit_checks}")

    return {
        "schema_version": 1,
        "valid": valid,
        "authority": "external_godot_gameplay_approximation",
        "historical_geometry_claim": False,
        "evaluation_stage": "editable_source_before_export_only_static_batching",
        "evaluation_method": "evaluated_mesh_vertices_to_nearest_axis_aligned_box_euclidean_distance_v1",
        "source_collections": list(source_collections),
        "source_root": "TorrentHeroArt",
        "scope": "visible_close_solid_geometry_with_closed_canopy",
        "roots_explicitly_out_of_scope": ["LOD1"],
        "out_of_scope_reason": (
            "LOD1 duplicates the audited close silhouette"
        ),
        "coordinate_contract": {
            "units": "metres",
            "space": "TorrentHeroArt root-local equals HeroShip local",
            "up": "+Y in Godot",
            "forward": "-Z in Godot",
            "root": "identity",
        },
        "body_contract": {
            "collision_layer": 4,
            "collision_mask": 7,
            "shape_type": "BoxShape3D",
            "direct_children": True,
            "enabled": True,
            "top_level": False,
            "rotation_degrees": [0.0, 0.0, 0.0],
        },
        "box_order": list(COLLISION_BOX_CONTRACT),
        "boxes": {
            name: {
                "position": list(contract["position"]),
                "size": list(contract["size"]),
                "rotation_degrees": [0.0, 0.0, 0.0],
                "scale": [1.0, 1.0, 1.0],
                "shape_type": "BoxShape3D",
                "enabled": True,
                "top_level": False,
            }
            for name, contract in COLLISION_BOX_CONTRACT.items()
        },
        "aggregate_local_aabb": {
            "position": [-3.6, -0.775, -4.8],
            "size": [7.2, 4.5, 9.0],
        },
        "tolerance_m": COLLISION_COVERAGE_TOLERANCE_M,
        "source_object_count": len(source_objects),
        "included_object_count": included_object_count,
        "excluded_object_count": len(exclusion_names),
        "excluded_objects": {
            name: COLLISION_EXCLUDED_OBJECTS[name]
            for name in sorted(COLLISION_EXCLUDED_OBJECTS)
        },
        "evaluated_vertex_count": evaluated_vertex_count,
        "uncovered_vertex_count": uncovered_vertex_count,
        "vertices_over_tolerance": vertices_over_tolerance,
        "objects_over_tolerance": sorted(objects_over_tolerance),
        "maximum_uncovered_distance_m": rounded(maximum_uncovered_distance),
        "categories": categories,
        "self_audit": {
            "checks": self_audit_checks,
            "passed": all(self_audit_checks.values()),
        },
    }


def source_semantic_sha256() -> str:
    """Hash editable scene meaning without Blender's volatile pointer tokens.

    Blender's binary file stores process-local address tokens even when scene
    content is unchanged. The semantic digest lets a verified checked-in .blend
    survive an idempotent regeneration byte-for-byte while still forcing a new
    save whenever editable geometry, transforms, hierarchy, modifiers,
    materials, or published scene metadata change.
    """
    def numbers(values) -> list[str]:
        return [float(value).hex() for value in values]

    def matrix_values(value) -> list[list[str]]:
        return [numbers(row) for row in value]

    object_records = []
    for obj in sorted(bpy.data.objects, key=lambda value: value.name):
        record = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent is not None else "",
            "matrix_local": matrix_values(obj.matrix_local),
            "matrix_parent_inverse": matrix_values(obj.matrix_parent_inverse),
            "hide_render": bool(obj.hide_render),
            "hide_viewport": bool(obj.hide_viewport),
            "custom_properties": {
                str(key): obj[key]
                for key in sorted(obj.keys())
                if key != "_RNA_UI" and isinstance(obj[key], (bool, int, float, str))
            },
        }
        if obj.type == "EMPTY":
            record["empty_display_type"] = obj.empty_display_type
            record["empty_display_size"] = float(obj.empty_display_size).hex()
        elif obj.type == "MESH":
            mesh = obj.data
            record["mesh"] = {
                "name": mesh.name,
                "vertices": [numbers(vertex.co) for vertex in mesh.vertices],
                "edges": [list(edge.vertices) for edge in mesh.edges],
                "polygons": [
                    {
                        "vertices": list(polygon.vertices),
                        "material_index": int(polygon.material_index),
                        "use_smooth": bool(polygon.use_smooth),
                    }
                    for polygon in mesh.polygons
                ],
                "materials": [
                    material_value.name if material_value is not None else ""
                    for material_value in mesh.materials
                ],
                "uv_layers": [
                    {
                        "name": uv_layer.name,
                        "active_render": bool(uv_layer.active_render),
                        "data": [numbers(loop.uv) for loop in uv_layer.data],
                    }
                    for uv_layer in mesh.uv_layers
                ],
            }
            modifier_records = []
            for modifier in obj.modifiers:
                if modifier.type != "BEVEL":
                    raise RuntimeError(
                        f"Semantic hashing needs an explicit serializer for {modifier.type}"
                    )
                modifier_records.append({
                    "name": modifier.name,
                    "type": modifier.type,
                    "width": float(modifier.width).hex(),
                    "segments": int(modifier.segments),
                    "limit_method": modifier.limit_method,
                    "angle_limit": float(modifier.angle_limit).hex(),
                    "harden_normals": bool(modifier.harden_normals),
                    "show_viewport": bool(modifier.show_viewport),
                    "show_render": bool(modifier.show_render),
                })
            record["modifiers"] = modifier_records
        object_records.append(record)

    material_records = []
    for material_value in sorted(bpy.data.materials, key=lambda value: value.name):
        nodes = []
        links = []
        if material_value.use_nodes and material_value.node_tree is not None:
            for node in sorted(material_value.node_tree.nodes, key=lambda value: value.name):
                inputs = []
                for socket in node.inputs:
                    if not hasattr(socket, "default_value"):
                        continue
                    default_value = socket.default_value
                    if isinstance(default_value, (bool, int, float)):
                        serialized_default = float(default_value).hex()
                    elif isinstance(default_value, str):
                        serialized_default = default_value
                    else:
                        try:
                            serialized_default = numbers(default_value)
                        except TypeError:
                            continue
                    inputs.append({
                        "identifier": socket.identifier,
                        "name": socket.name,
                        "default": serialized_default,
                    })
                nodes.append({
                    "name": node.name,
                    "type": node.bl_idname,
                    "inputs": inputs,
                })
            links = sorted(
                (
                    link.from_node.name,
                    link.from_socket.identifier,
                    link.to_node.name,
                    link.to_socket.identifier,
                )
                for link in material_value.node_tree.links
            )
        material_records.append({
            "name": material_value.name,
            "diffuse_color": numbers(material_value.diffuse_color),
            "use_nodes": bool(material_value.use_nodes),
            "blend_method": str(material_value.blend_method),
            "nodes": nodes,
            "links": links,
        })

    scene = bpy.context.scene
    document = {
        "schema_version": 1,
        "objects": object_records,
        "materials": material_records,
        "collections": {
            collection_name: sorted(
                obj.name for obj in bpy.data.collections[collection_name].objects
            )
            for collection_name in sorted(OBJECTS)
        },
        "published_rosters": OBJECTS,
        "scene": {
            "unit_system": scene.unit_settings.system,
            "unit_scale_length": float(scene.unit_settings.scale_length).hex(),
            "render_engine": scene.render.engine,
            "custom_properties": {
                str(key): scene[key]
                for key in sorted(scene.keys())
                if key != "_RNA_UI" and isinstance(scene[key], (bool, int, float, str))
            },
        },
    }
    encoded = json.dumps(
        document,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def can_preserve_existing_blend(semantic_sha256: str, generator_sha256: str) -> bool:
    """Keep verified source bytes when regeneration produced identical meaning."""
    if not BLEND_PATH.is_file() or not MANIFEST_PATH.is_file():
        return False
    try:
        existing = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    return (
        existing.get("asset_id") == "torrent_hero_art_v1"
        and existing.get("blender_version") == bpy.app.version_string
        and existing.get("generator_sha256") == generator_sha256
        and existing.get("source_semantic_sha256") == semantic_sha256
        and existing.get("blend_sha256") == sha(BLEND_PATH)
    )


def sha(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonicalize_glb_runtime_floats(path: Path) -> int:
    """Canonicalize exported normals and equivalent signed zero values.

    Blender's custom-normal conversion can differ by less than 1e-4 between
    otherwise identical background processes on the same evaluated bevel edge.
    Those normal differences are visually meaningless but make the GLB byte
    stream unstable.  Quantizing each NORMAL direction to two decimals before
    deterministic renormalization gives a documented sub-degree angular bound
    and retains glTF's unit-vector contract. Positions, UV0, colors, animation,
    indices, and every authored source value remain untouched.
    """
    payload = bytearray(path.read_bytes())
    if len(payload) < 20 or payload[:4] != b"glTF":
        raise RuntimeError(f"Not a GLB 2.0 file: {path}")
    cursor = 12
    document = None
    binary_offset = None
    while cursor + 8 <= len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, cursor)
        cursor += 8
        if chunk_type == 0x4E4F534A:
            document = json.loads(
                bytes(payload[cursor:cursor + chunk_length]).rstrip(b" \t\r\n\x00")
                .decode("utf-8")
            )
        elif chunk_type == 0x004E4942:
            binary_offset = cursor
        cursor += chunk_length
    if not isinstance(document, dict) or binary_offset is None:
        raise RuntimeError(f"GLB JSON or BIN chunk is missing: {path}")
    component_counts = {
        "SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
        "MAT2": 4, "MAT3": 9, "MAT4": 16,
    }
    normal_accessor_indices = {
        int(primitive["attributes"]["NORMAL"])
        for mesh in document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
        if "NORMAL" in primitive.get("attributes", {})
    }
    replacements = 0
    for accessor_index, accessor in enumerate(document.get("accessors", [])):
        if int(accessor.get("componentType", 0)) != 5126 or "bufferView" not in accessor:
            continue
        view = document["bufferViews"][int(accessor["bufferView"])]
        if int(view.get("buffer", 0)) != 0:
            raise RuntimeError("Torrent GLB unexpectedly references an external buffer")
        component_count = component_counts[str(accessor["type"])]
        element_size = component_count * 4
        stride = int(view.get("byteStride", element_size))
        start = (
            binary_offset + int(view.get("byteOffset", 0))
            + int(accessor.get("byteOffset", 0))
        )
        for element_index in range(int(accessor["count"])):
            element_start = start + element_index * stride
            if accessor_index in normal_accessor_indices:
                if component_count != 3:
                    raise RuntimeError("Torrent GLB NORMAL accessor is not VEC3")
                source_normal = struct.unpack_from("<fff", payload, element_start)
                if not all(math.isfinite(value) for value in source_normal):
                    raise RuntimeError("Torrent GLB contains a non-finite normal")
                quantized = tuple(
                    0.0 if abs(round(float(value), 2)) < .005
                    else round(float(value), 2)
                    for value in source_normal
                )
                length = math.sqrt(math.fsum(value * value for value in quantized))
                if length <= 1e-12:
                    raise RuntimeError("Torrent GLB contains a zero-length normal")
                canonical_normal = tuple(value / length for value in quantized)
                for component_index, canonical_value in enumerate(canonical_normal):
                    offset = element_start + component_index * 4
                    bits = struct.unpack_from("<I", payload, offset)[0]
                    replacement_bits = struct.unpack(
                        "<I", struct.pack("<f", canonical_value)
                    )[0]
                    if replacement_bits != bits:
                        struct.pack_into("<I", payload, offset, replacement_bits)
                        replacements += 1
                continue
            for component_index in range(component_count):
                offset = element_start + component_index * 4
                bits = struct.unpack_from("<I", payload, offset)[0]
                replacement_bits = bits
                if bits == 0x80000000:
                    replacement_bits = 0
                if replacement_bits != bits:
                    struct.pack_into("<I", payload, offset, replacement_bits)
                    replacements += 1
    if replacements:
        path.write_bytes(payload)
    return replacements


def glb_document(path: Path) -> dict:
    """Read and validate the JSON document embedded in a GLB 2.0 file."""
    payload = path.read_bytes()
    if len(payload) < 20 or payload[:4] != b"glTF":
        raise RuntimeError(f"Not a GLB 2.0 file: {path}")
    version, total_length = struct.unpack_from("<II", payload, 4)
    if version != 2 or total_length != len(payload):
        raise RuntimeError(f"Malformed GLB header: {path}")
    cursor = 12
    while cursor + 8 <= len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, cursor)
        cursor += 8
        chunk = payload[cursor:cursor + chunk_length]
        cursor += chunk_length
        if chunk_type == 0x4E4F534A:  # JSON
            document = json.loads(chunk.rstrip(b" \t\r\n\x00").decode("utf-8"))
            if isinstance(document, dict):
                return document
            break
    raise RuntimeError(f"GLB JSON chunk is missing: {path}")


def glb_mesh_metrics(document: dict) -> tuple[int, int]:
    """Count the geometry Godot will load from an exported GLB document.

    Blender's evaluated dependency graph is not proof that modifiers reached the
    runtime file. Keeping this independent export-side count in the manifest
    prevents a visually important modifier from being reported but omitted.
    """
    accessors = document.get("accessors", [])
    vertex_count = 0
    triangle_count = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if int(primitive.get("mode", 4)) != 4:
                raise RuntimeError("Torrent GLB contains a non-triangle primitive")
            position_accessor = primitive.get("attributes", {}).get("POSITION")
            if position_accessor is None:
                raise RuntimeError("Torrent GLB primitive has no POSITION accessor")
            vertex_count += int(accessors[int(position_accessor)]["count"])
            index_accessor = primitive.get("indices")
            element_count = (
                int(accessors[int(index_accessor)]["count"])
                if index_accessor is not None else
                int(accessors[int(position_accessor)]["count"])
            )
            if element_count % 3 != 0:
                raise RuntimeError("Torrent GLB triangle primitive has a partial triangle")
            triangle_count += element_count // 3
    return vertex_count, triangle_count


def glb_uv_orientation_audit(path: Path, document: dict) -> dict:
    """Measure UV tangent-frame handedness from the actual runtime GLB.

    The oracle uses each indexed triangle's geometric winding, averaged exported
    normal and TEXCOORD_0 determinant. Its sign is equivalent to
    ``dot(cross(N, tangent), bitangent)`` without depending on optional exported
    tangents. Positive is the one published runtime orientation. Surface area is
    included so many tiny triangles cannot hide a mirrored hero panel.
    """
    payload = path.read_bytes()
    cursor = 12
    binary = None
    while cursor + 8 <= len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, cursor)
        cursor += 8
        chunk = payload[cursor:cursor + chunk_length]
        cursor += chunk_length
        if chunk_type == 0x004E4942:
            binary = chunk
    if binary is None:
        raise RuntimeError("Torrent GLB UV audit requires one embedded BIN chunk")

    component_formats = {
        5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
        5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4),
    }
    component_counts = {
        "SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
        "MAT2": 4, "MAT3": 9, "MAT4": 16,
    }

    def accessor_values(accessor_index: int):
        accessor = document["accessors"][accessor_index]
        if "sparse" in accessor:
            raise RuntimeError("Torrent GLB UV audit does not accept sparse accessors")
        view = document["bufferViews"][int(accessor["bufferView"])]
        if int(view.get("buffer", 0)) != 0:
            raise RuntimeError("Torrent GLB UV audit found an external buffer")
        component_type = int(accessor["componentType"])
        format_char, component_size = component_formats[component_type]
        component_count = component_counts[str(accessor["type"])]
        element_size = component_size * component_count
        stride = int(view.get("byteStride", element_size))
        start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
        unpack_format = "<" + format_char * component_count
        values = []
        for element_index in range(int(accessor["count"])):
            value = struct.unpack_from(
                unpack_format, binary, start + element_index * stride
            )
            values.append(value[0] if component_count == 1 else value)
        return values

    material_names = [
        str(material_value.get("name", ""))
        for material_value in document.get("materials", [])
    ]
    textured_roles = {"WarmIvoryHull", "IvorySecondary"}
    totals = {
        "triangle_count": 0,
        "positive_triangle_count": 0,
        "mirrored_triangle_count": 0,
        "degenerate_triangle_count": 0,
        "surface_area_m2": 0.0,
        "positive_surface_area_m2": 0.0,
        "mirrored_surface_area_m2": 0.0,
    }
    by_material: dict[str, dict] = {}

    def blank_metrics() -> dict:
        return {key: 0 if "count" in key else 0.0 for key in totals}

    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            if not all(name in attributes for name in ("POSITION", "NORMAL", "TEXCOORD_0")):
                raise RuntimeError("Torrent GLB primitive lacks UV orientation attributes")
            positions = accessor_values(int(attributes["POSITION"]))
            normals = accessor_values(int(attributes["NORMAL"]))
            uvs = accessor_values(int(attributes["TEXCOORD_0"]))
            if primitive.get("indices") is None:
                indices = list(range(len(positions)))
            else:
                indices = accessor_values(int(primitive["indices"]))
            if len(indices) % 3:
                raise RuntimeError("Torrent GLB UV audit found a partial triangle")
            material_index = int(primitive.get("material", -1))
            material_name = (
                material_names[material_index]
                if 0 <= material_index < len(material_names) else ""
            )
            material_metrics = by_material.setdefault(material_name, blank_metrics())
            for offset in range(0, len(indices), 3):
                triangle = [int(value) for value in indices[offset:offset + 3]]
                p0, p1, p2 = (Vector(positions[index]) for index in triangle)
                uv0, uv1, uv2 = (Vector(uvs[index]) for index in triangle)
                normal = sum(
                    (Vector(normals[index]) for index in triangle),
                    Vector((0.0, 0.0, 0.0)),
                )
                geometry_cross = (p1 - p0).cross(p2 - p0)
                area = geometry_cross.length * 0.5
                uv_a = uv1 - uv0
                uv_b = uv2 - uv0
                uv_determinant = uv_a.x * uv_b.y - uv_a.y * uv_b.x
                handedness = geometry_cross.dot(normal) * uv_determinant
                for metrics in (totals, material_metrics):
                    metrics["triangle_count"] += 1
                    metrics["surface_area_m2"] += area
                    if area <= 1e-12 or abs(uv_determinant) <= 1e-12 or abs(handedness) <= 1e-15:
                        metrics["degenerate_triangle_count"] += 1
                    elif handedness > 0.0:
                        metrics["positive_triangle_count"] += 1
                        metrics["positive_surface_area_m2"] += area
                    else:
                        metrics["mirrored_triangle_count"] += 1
                        metrics["mirrored_surface_area_m2"] += area

    def publish(metrics: dict) -> dict:
        area = float(metrics["surface_area_m2"])
        result = dict(metrics)
        for key in (
            "surface_area_m2", "positive_surface_area_m2",
            "mirrored_surface_area_m2",
        ):
            result[key] = round(float(result[key]), 6)
        result["mirrored_surface_ratio"] = round(
            float(metrics["mirrored_surface_area_m2"]) / area if area > 0.0 else 0.0,
            9,
        )
        return result

    published_materials = {
        name: publish(metrics) for name, metrics in sorted(by_material.items())
    }
    textured = blank_metrics()
    for name in textured_roles:
        for key, value in by_material.get(name, {}).items():
            textured[key] += value
    result = {
        "schema_version": 1,
        "method": "indexed_triangle_geometric_normal_uv_determinant_v1",
        "orientation": "positive_runtime_TEXCOORD_0",
        "glTF_export_v_conversion_accounted_for": True,
        "textured_roles": sorted(textured_roles),
        "all_materials": publish(totals),
        "textured_materials": publish(textured),
        "by_material": published_materials,
    }
    # Bevel triangulation may create vanishing slivers whose float32 UV
    # determinant crosses zero after export. They are accepted only below a
    # strict aggregate area ratio; a real mirrored panel fails by orders of
    # magnitude (the superseded projection measured 57.19%).
    if (
        result["textured_materials"]["degenerate_triangle_count"] != 0
        or result["textured_materials"]["mirrored_surface_ratio"] > 0.00002
    ):
        raise RuntimeError(
            "Runtime Torrent textured UV0 contains mirrored or degenerate triangles: "
            f"{result['textured_materials']}"
        )
    return result


def glb_mesh_instance_counts(document: dict) -> tuple[dict[str, int], int]:
    """Count GLB nodes carrying meshes beneath each published semantic root."""
    nodes = document.get("nodes", [])

    def descendants(node_index: int) -> set[int]:
        result: set[int] = set()
        pending = [node_index]
        while pending:
            current = pending.pop()
            if current in result:
                continue
            result.add(current)
            pending.extend(int(child) for child in nodes[current].get("children", []))
        return result

    counts: dict[str, int] = {}
    for root_name in OBJECTS:
        root_indices = [
            index for index, node in enumerate(nodes) if node.get("name") == root_name
        ]
        if len(root_indices) != 1:
            raise RuntimeError(
                f"Expected one GLB node named {root_name}, found {len(root_indices)}"
            )
        counts[root_name] = sum(
            1 for index in descendants(root_indices[0]) if "mesh" in nodes[index]
        )
    total = sum(1 for node in nodes if "mesh" in node)
    return counts, total


def main():
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    uv_contract = setup_scene()

    source_mesh_counts = mesh_counts_by_root()
    if source_mesh_counts != EXPECTED_SOURCE_MESH_COUNTS:
        raise RuntimeError(
            "Editable Torrent source mesh roster drifted: "
            f"{source_mesh_counts} != {EXPECTED_SOURCE_MESH_COUNTS}"
        )
    base_vertices, base_triangles, minimum, maximum = mesh_metrics(False)
    evaluated_vertices, evaluated_triangles, _evaluated_minimum, _evaluated_maximum = mesh_metrics(True)
    art_quality = evaluated_art_quality_metrics()
    swept_plate_winding = swept_plate_outward_winding_audit()
    source_mesh_count = sum(source_mesh_counts.values())
    if source_mesh_count > SOURCE_MESH_INSTANCE_BUDGET:
        raise RuntimeError(
            f"Editable Torrent source exceeds its semantic mesh budget: "
            f"{source_mesh_count} > {SOURCE_MESH_INSTANCE_BUDGET}"
        )
    if int(uv_contract["mesh_count"]) != source_mesh_count:
        raise RuntimeError("UV0 coverage does not account for every editable source mesh")
    close_triangles = int(art_quality["close_triangle_count"])
    far_triangles = int(art_quality["far_triangle_count"])
    if not (CLOSE_TRIANGLE_RANGE[0] <= close_triangles <= CLOSE_TRIANGLE_RANGE[1]):
        raise RuntimeError(
            f"Close art triangle count is outside its production band: {close_triangles}"
        )
    if not (FAR_TRIANGLE_RANGE[0] <= far_triangles <= FAR_TRIANGLE_RANGE[1]):
        raise RuntimeError(
            f"Far art triangle count is outside its silhouette band: {far_triangles}"
        )
    if int(art_quality["total_triangle_count"]) > TOTAL_TRIANGLE_BUDGET:
        raise RuntimeError("Torrent art exceeds its total triangle budget")
    if not (0.70 <= float(art_quality["pale_exterior_surface_ratio"]) <= 0.80):
        raise RuntimeError("Torrent exterior no longer preserves its 70-80% pale palette")
    if evaluated_triangles != EXPECTED_RUNTIME_TRIANGLES:
        raise RuntimeError(
            "Editable Torrent source triangle contract drifted: "
            f"{evaluated_triangles} != {EXPECTED_RUNTIME_TRIANGLES}"
        )
    collision_alignment = collision_art_alignment_audit()
    bpy.context.scene["collision_coverage_schema_version"] = int(
        collision_alignment["schema_version"]
    )
    bpy.context.scene["collision_coverage_valid"] = bool(collision_alignment["valid"])
    bpy.context.scene["collision_coverage_tolerance_m"] = float(
        collision_alignment["tolerance_m"]
    )
    bpy.context.scene["collision_coverage_evaluated_vertex_count"] = int(
        collision_alignment["evaluated_vertex_count"]
    )
    bpy.context.scene["collision_coverage_maximum_uncovered_distance_m"] = float(
        collision_alignment["maximum_uncovered_distance_m"]
    )
    generator_path = Path(__file__).resolve()
    generator_digest = sha(generator_path)
    semantic_digest = source_semantic_sha256()

    # This is intentionally the only possible save. Blender serializes volatile
    # process-local pointer tokens into .blend files, so an idempotent generation
    # preserves already verified bytes using the comprehensive semantic digest.
    # A semantic or generator change forces one fresh source save. The checked-in
    # file retains the complete named source roster and unapplied production
    # modifiers;
    # batching below mutates only the in-memory export scene.
    bpy.context.preferences.filepaths.save_version = 0
    if can_preserve_existing_blend(semantic_digest, generator_digest):
        print("TORRENT_BLEND_BYTES_PRESERVED", semantic_digest, sha(BLEND_PATH))
    else:
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    batch_member_map = consolidate_static_lod_meshes()
    runtime_blender_mesh_counts = mesh_counts_by_root()
    if runtime_blender_mesh_counts != EXPECTED_RUNTIME_MESH_COUNTS:
        raise RuntimeError(
            "In-memory Torrent static batching produced the wrong mesh counts: "
            f"{runtime_blender_mesh_counts} != {EXPECTED_RUNTIME_MESH_COUNTS}"
        )
    runtime_blender_vertices, runtime_blender_triangles, _, _ = mesh_metrics(True)
    if runtime_blender_triangles != evaluated_triangles:
        raise RuntimeError(
            "Static batching changed evaluated triangle count: "
            f"{runtime_blender_triangles} != {evaluated_triangles}"
        )

    # Godot already converts glTF's native Y-up coordinates. The generator is
    # authored directly in that convention, so do not apply Blender's Z-up
    # conversion a second time during export.
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB", use_visible=True,
                              export_apply=True, export_yup=False, export_materials="EXPORT")
    canonicalize_glb_runtime_floats(GLB_PATH)
    document = glb_document(GLB_PATH)
    runtime_vertices, runtime_triangles = glb_mesh_metrics(document)
    uv_orientation_contract = glb_uv_orientation_audit(GLB_PATH, document)
    runtime_mesh_counts, runtime_mesh_count = glb_mesh_instance_counts(document)
    if runtime_triangles != evaluated_triangles:
        raise RuntimeError(
            "Runtime GLB triangle count does not match Blender's evaluated geometry: "
            f"{runtime_triangles} != {evaluated_triangles}"
        )
    if runtime_mesh_counts != EXPECTED_RUNTIME_MESH_COUNTS:
        raise RuntimeError(
            "Runtime GLB semantic-root mesh counts drifted: "
            f"{runtime_mesh_counts} != {EXPECTED_RUNTIME_MESH_COUNTS}"
        )
    if runtime_mesh_count != sum(EXPECTED_RUNTIME_MESH_COUNTS.values()):
        raise RuntimeError(
            "Runtime GLB contains mesh nodes outside the published roots: "
            f"{runtime_mesh_count} != {sum(EXPECTED_RUNTIME_MESH_COUNTS.values())}"
        )
    if runtime_mesh_count > RUNTIME_MESH_INSTANCE_BUDGET:
        raise RuntimeError(
            f"Runtime GLB exceeds its mesh-instance budget: "
            f"{runtime_mesh_count} > {RUNTIME_MESH_INSTANCE_BUDGET}"
        )
    runtime_mesh_node_names = {
        str(node.get("name", "")) for node in document.get("nodes", []) if "mesh" in node
    }
    for root_name, protected_names in PROTECTED_MESHES_BY_ROOT.items():
        missing_names = sorted(set(protected_names) - runtime_mesh_node_names)
        if missing_names:
            raise RuntimeError(
                f"Runtime GLB lost protected {root_name} mesh names: {missing_names}"
            )

    collision_alignment["provenance"] = {
        "generator": str(generator_path.relative_to(ROOT)),
        "generator_sha256": generator_digest,
        "evaluated_source_blend": str(BLEND_PATH.relative_to(ROOT)),
        "evaluated_source_blend_sha256": sha(BLEND_PATH),
        "evaluated_source_semantic_sha256": semantic_digest,
        "runtime_glb": str(GLB_PATH.relative_to(ROOT)),
        "runtime_glb_sha256": sha(GLB_PATH),
        "blender_version": bpy.app.version_string,
    }

    manifest = {
        "schema_version": 1,
        "asset_id": "torrent_hero_art_v1",
        "blender_version": bpy.app.version_string,
        "authorship": "original_script_assisted_blender",
        "motion_or_geometry_source": "project_original_modern_interpretation",
        "authenticated_historical_geometry": False,
        "concept_reference": str(CONCEPT_PATH.relative_to(ROOT)),
        "concept_sha256": sha(CONCEPT_PATH),
        "coordinate_contract": {"units":"metres","up":"+Y in Godot","forward":"-Z in Godot","root":"identity"},
        "mesh_vertices_before_modifier_application": base_vertices,
        "mesh_triangles_before_modifier_application": base_triangles,
        "mesh_vertices_evaluated_in_blender": evaluated_vertices,
        "mesh_triangles_evaluated_in_blender": evaluated_triangles,
        "mesh_vertices_after_static_batching_in_blender": runtime_blender_vertices,
        "mesh_triangles_after_static_batching_in_blender": runtime_blender_triangles,
        "mesh_vertices_exported_runtime": runtime_vertices,
        "mesh_triangles_exported_runtime": runtime_triangles,
        "runtime_binary_canonicalization": {
            "method": "normal_direction_centiquantization_renormalization_and_negative_zero_v1",
            "applied": True,
            "normal_component_step": 0.01,
        },
        "bounds_blender_xyz": {"min": minimum, "max": maximum},
        "material_roles": sorted(MATS),
        "material_texture_contract": {
            "runtime_authority": "torrent_hero_presentation_standard_material_3d",
            "textured_roles": ["WarmIvoryHull", "IvorySecondary"],
            "texture_coordinate": "UV0/TEXCOORD_0",
            "triplanar": False,
            "albedo": {
                "path": "assets/materials/torrent-hull-albedo-v1.png",
                "sha256": sha(ROOT / "assets/materials/torrent-hull-albedo-v1.png"),
            },
            "normal": {
                "path": "assets/materials/torrent-hull-normal-v1.png",
                "sha256": sha(ROOT / "assets/materials/torrent-hull-normal-v1.png"),
            },
            "roughness": {
                "path": "assets/materials/torrent-hull-roughness-v1.png",
                "sha256": sha(ROOT / "assets/materials/torrent-hull-roughness-v1.png"),
            },
        },
        "uv0_contract": uv_contract,
        "uv_orientation_contract": uv_orientation_contract,
        "swept_plate_winding_contract": swept_plate_winding,
        "art_quality_contract": {
            **art_quality,
            "source_mesh_instance_budget": SOURCE_MESH_INSTANCE_BUDGET,
            "close_triangle_range": list(CLOSE_TRIANGLE_RANGE),
            "far_triangle_range": list(FAR_TRIANGLE_RANGE),
            "total_triangle_budget": TOTAL_TRIANGLE_BUDGET,
            "pale_exterior_surface_ratio_range": [0.70, 0.80],
            "propulsion_depth_layers": 4,
            "engine_stator_vanes_per_nacelle": 8,
            "gear_articulation_elements": [
                "upper_pivot", "oleo", "trailing_brace", "split_fork",
                "ankle", "articulated_foot", "capture_jaws", "hydraulic_line",
            ],
            "cockpit_features": [
                "molded_binnacle", "primary_and_side_displays", "status_regions",
                "key_and_rotary_clusters", "stick", "throttle", "rudder_pedals",
                "bolstered_seat", "four_point_harness",
            ],
            "canopy_features": [
                "single_shaped_transparent_shell", "continuous_perimeter_frame",
                "top_spine", "side_rails", "seals", "hinges", "paired_latches",
            ],
        },
        "collections": OBJECTS,
        "runtime_static_batching": {
            "strategy": STATIC_BATCH_STRATEGY,
            "export_only": True,
            "modifiers_applied_before_join": True,
            "source_preserved_in_blend": True,
            "unbatched_roots": list(UNBATCHED_ROOTS),
            "protected_meshes_by_root": {
                root_name: list(PROTECTED_MESHES_BY_ROOT[root_name])
                for root_name in BATCHABLE_ROOTS
            },
            "source_mesh_counts_by_root": source_mesh_counts,
            "runtime_mesh_counts_by_root": runtime_mesh_counts,
            "source_mesh_count_total": sum(source_mesh_counts.values()),
            "runtime_mesh_count_total": runtime_mesh_count,
            "runtime_mesh_instance_budget": RUNTIME_MESH_INSTANCE_BUDGET,
            "batch_member_map": batch_member_map,
        },
        "collision_art_alignment": collision_alignment,
        "source_semantic_sha256": semantic_digest,
        "blend_sha256": sha(BLEND_PATH),
        "glb_sha256": sha(GLB_PATH),
        "generator": str(generator_path.relative_to(ROOT)),
        "generator_sha256": generator_digest,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(
        "TORRENT_HERO_BLENDER_ASSET_OK",
        runtime_mesh_count,
        runtime_vertices,
        runtime_triangles,
        sha(GLB_PATH),
    )


if __name__ == "__main__":
    main()
