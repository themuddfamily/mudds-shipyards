"""Generate the evidence-bounded Zenith authored-art package in Blender 4.0.2.

Run from the repository root:

  blender --background --factory-startup --python \
    tools/blender/generate_zenith_authored_v1.py

The B7 evidence window is deliberately limited to frames 373-467 of the
locally audited rendition.  No video pixels or source geometry are bundled.
`SourceCore` contains only the supported macroform; deleting sibling
`ModernSystems` removes every newly designed functional detail at once.
"""

from __future__ import annotations

import bpy
import bmesh
import hashlib
import json
import math
import struct
from collections import Counter, defaultdict
from pathlib import Path
from mathutils import Euler, Vector
from mathutils.bvhtree import BVHTree


ROOT = Path.cwd()
GENERATOR_PATH = ROOT / "tools/blender/generate_zenith_authored_v1.py"
BLEND_PATH = ROOT / "art_source/zenith/zenith_authored_v1.blend"
GLB_PATH = ROOT / "assets/models/zenith/zenith_authored_art.glb"
MANIFEST_PATH = ROOT / "assets/models/zenith/zenith_authored_asset_manifest.json"

ASSET_ID = "mudds.ship.zenith.b7_authored.v1"
EVIDENCE_SCOPE = "B7_frames_373_467_only"
EVIDENCE_SHA256 = "c716c506d9fd7042ac98720e8815725cf083d24967bc8c9f842cdfa58e8ca144"
ROOT_NAME = "ZenithAuthoredArt"
GROUP_PATHS = (
    "SourceCore/LOD0",
    "SourceCore/LOD1",
    "ModernSystems/LOD0",
    "ModernSystems/LOD1",
    "ModernSystems/CanopyPivot",
    "ModernSystems/SemanticAnchors",
)

MATERIAL_SPECS = {
    "PaleCeramicHull": {
        "boundary": "source_supported", "color": (0.78, 0.79, 0.75, 1.0),
        "metallic": 0.10, "roughness": 0.43,
    },
    "PaleFacetSecondary": {
        "boundary": "source_supported", "color": (0.57, 0.59, 0.57, 1.0),
        "metallic": 0.14, "roughness": 0.49,
    },
    "GraphitePanel": {
        "boundary": "modern_only", "color": (0.075, 0.095, 0.105, 1.0),
        "metallic": 0.48, "roughness": 0.43,
    },
    "EngineGraphite": {
        "boundary": "modern_only", "color": (0.115, 0.140, 0.150, 1.0),
        "metallic": 0.46, "roughness": 0.52,
    },
    "ExposedAlloy": {
        "boundary": "modern_only", "color": (0.22, 0.26, 0.27, 1.0),
        "metallic": 0.82, "roughness": 0.24,
    },
    "CanopyGlass": {
        "boundary": "modern_only", "color": (0.035, 0.16, 0.19, 0.22),
        "metallic": 0.14, "roughness": 0.07, "alpha_blend": True,
    },
    "EngineEmission": {
        "boundary": "modern_only", "color": (0.015, 0.20, 0.23, 1.0),
        "metallic": 0.10, "roughness": 0.24,
        "emission": (0.02, 0.75, 0.91, 1.0), "emission_strength": 3.1,
    },
    "PortNavRed": {
        "boundary": "modern_only", "color": (0.42, 0.015, 0.018, 1.0),
        "metallic": 0.06, "roughness": 0.25,
        "emission": (1.0, 0.012, 0.018, 1.0), "emission_strength": 2.6,
    },
    "StarboardNavGreen": {
        "boundary": "modern_only", "color": (0.01, 0.31, 0.10, 1.0),
        "metallic": 0.06, "roughness": 0.25,
        "emission": (0.015, 0.95, 0.19, 1.0), "emission_strength": 2.6,
    },
    "CockpitEmission": {
        "boundary": "modern_only", "color": (0.012, 0.16, 0.19, 1.0),
        "metallic": 0.08, "roughness": 0.28,
        "emission": (0.018, 0.66, 0.76, 1.0), "emission_strength": 1.9,
    },
}

# Modern ergonomic normalization only; B7 establishes no cockpit plan, seat or
# eye point.  `PilotSeatAnchor` is a *feet-frame* marker: `PlayerController`
# carries its hips 0.72 m above its own root, so the anchor is the authored seat
# cushion height minus 0.72.  `InterceptorSeat` tops out at 1.83 m, which fixes
# the anchor at 1.11 m.  The cockpit eye point then follows the fleet-wide
# `seat + 1.76 m` convention (Torrent/Arrow/Jovian all use it), placing the
# camera 0.201 m above the seated pilot's head bone.  Its `z` sits at -0.80 m so
# the eye stays inside the modern canopy dome, whose glass crown is 2.986 m
# there.  See the re-freeze note in `tests/zenith_interceptor_test.gd`.
ANCHORS_GODOT = {
    "PilotSeatAnchor": (0.0, 1.11, -0.55),
    "BoardingEntry": (-1.18, 1.62, -0.32),
    "BoardingPoint": (-7.65, -0.55, 0.55),
    "ExitPoint": (-7.85, -0.55, 0.85),
    "LeftMuzzle": (-1.25, 0.34, -4.25),
    "RightMuzzle": (1.25, 0.34, -4.25),
    "CockpitCamera": (0.0, 2.87, -0.80),
    "DockingReceiver": (0.0, -0.82, 1.05),
    "DamageCenter": (0.0, 0.48, 0.0),
    "DamagePortWing": (-4.55, 0.18, 0.20),
    "DamageStarboardWing": (4.55, 0.18, 0.20),
    "PortEnginePlume": (-2.20, 0.38, 4.95),
    "StarboardEnginePlume": (2.20, 0.38, 4.95),
}

EXPECTED_BOUNDS = {
    "minimum": (-7.20, -1.05, -5.35),
    "maximum": (7.20, 3.20, 5.30),
}
CLOSE_TRIANGLE_RANGE = (45_000, 75_000)
FAR_TRIANGLE_RANGE = (5_000, 10_000)
RUNTIME_MESH_BUDGET = 30
RUNTIME_SURFACE_BUDGET = 30

# Visual-only V2 proposal for future Godot-owned gameplay collision. The GLB
# and presentation wrapper remain authority-free. Exact low-point convex hulls
# follow the tapered structural art; localized cylinders/boxes cover gear.
COLLISION_MAXIMUM_MISS_M = .020
COLLISION_MAXIMUM_SHAPES = 24
COLLISION_REVERSE_MAXIMUM_M = .150
COLLISION_REVERSE_TARGET_M = .050
COLLISION_EXCLUSIONS = {
    "PortEnginePlume": "dynamic emissive plume; deliberately non-contact",
    "StarboardEnginePlume": "dynamic emissive plume; deliberately non-contact",
    "PortNavigationLight": "tiny emissive navigation fixture; deliberately non-contact",
    "StarboardNavigationLight": "tiny emissive navigation fixture; deliberately non-contact",
    "CanopyGlassShell": "modern articulated glass; external gameplay may use a separate canopy rule",
}
NON_CONTACT_DECORATIVE_TRIM = {
    **{
        f"{side}SteppedSubdivision{index:02d}": (
            "source-supported shallow stepped-subdivision relief; retained visual art over "
            "the structurally collidable primary plane"
        )
        for side in ("Port", "Starboard") for index in range(1, 8)
    },
    "CanopyPortSill": "modern 27mm non-contact decorative canopy rail",
    "CanopyStarboardSill": "modern 27mm non-contact decorative canopy rail",
    "CanopyCentreFrame": "modern 27mm non-contact decorative canopy rail",
    "CanopyForwardHoop": "modern 27mm non-contact decorative canopy hoop",
    "CanopyAftHoop": "modern 27mm non-contact decorative canopy hoop",
}
BOARDING_CAPSULE = {
    "root_position": ANCHORS_GODOT["BoardingPoint"],
    "center_offset": (0.0, .97, 0.0),
    "center_position": (
        ANCHORS_GODOT["BoardingPoint"][0],
        ANCHORS_GODOT["BoardingPoint"][1] + .97,
        ANCHORS_GODOT["BoardingPoint"][2],
    ),
    "radius": .38,
    "total_height": 1.94,
    "minimum_art_clearance": .05,
    "semantics": "production_player_capsule_root_plus_center_offset",
}
BOARDING_ROUTE = {
    "initial_root_position": (-7.65, -.50, 4.75),
    "grounded_root_position": (-7.65, -1.08, 4.75),
    "grounded_end_root_position": (-7.65, -1.08, .55),
    "world_dock_origin": (22.0, 5.28, 53.30),
    "required_minimum_clearance_m": .05,
}
BOARDING_AREA_WITNESS = {
    "center": (
        ANCHORS_GODOT["BoardingPoint"][0],
        ANCHORS_GODOT["BoardingPoint"][1] + .5,
        ANCHORS_GODOT["BoardingPoint"][2],
    ),
    "radius": 4.5,
    "authority": "external_runtime_trigger_witness_only",
}

MATERIALS: dict[str, bpy.types.Material] = {}
HIERARCHY: dict[str, bpy.types.Object] = {}
GROUP_OBJECTS: dict[str, list[bpy.types.Object]] = defaultdict(list)
SOURCE_COUNTS: Counter[str] = Counter()
PROTECTED_BY_GROUP = {
    "ModernSystems/LOD0": {
        "PortEnginePlume", "StarboardEnginePlume",
    },
    "ModernSystems/LOD1": {
        "LOD1PortEnginePlume", "LOD1StarboardEnginePlume",
    },
    "ModernSystems/CanopyPivot": {"CanopyGlassShell"},
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_material(name: str, spec: dict) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = spec["color"]
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = spec["color"]
    bsdf.inputs["Metallic"].default_value = spec["metallic"]
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    if "emission" in spec:
        bsdf.inputs["Emission Color"].default_value = spec["emission"]
        bsdf.inputs["Emission Strength"].default_value = spec["emission_strength"]
    if spec.get("alpha_blend", False):
        material.blend_method = "BLEND"
    material["zenith_material_role"] = name
    material["evidence_boundary"] = spec["boundary"]
    MATERIALS[name] = material
    return material


def apply_modifier(obj: bpy.types.Object, modifier: bpy.types.Modifier) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    result = bpy.ops.object.modifier_apply(modifier=modifier.name)
    if "FINISHED" not in result:
        raise RuntimeError(f"Unable to apply {modifier.name} to {obj.name}: {result}")
    obj.select_set(False)


def recalculate_outward(mesh: bpy.types.Mesh) -> None:
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def register_mesh(
    obj: bpy.types.Object,
    name: str,
    group_path: str,
    material_role: str,
    bevel: float = 0.0,
    bevel_segments: int = 2,
    smooth: bool = False,
) -> bpy.types.Object:
    if group_path not in GROUP_PATHS or group_path.endswith("SemanticAnchors"):
        raise RuntimeError(f"Invalid mesh group {group_path}")
    obj.name = name
    obj.data.name = f"{name}Mesh"
    obj.parent = HIERARCHY[group_path]
    obj.matrix_parent_inverse.identity()
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS[material_role])
    obj["zenith_group"] = group_path
    obj["zenith_material_role"] = material_role
    obj["presentation_only"] = True
    obj["gameplay_authority"] = False
    obj["evidence_boundary"] = MATERIAL_SPECS[material_role]["boundary"]
    if bevel > 0.0:
        modifier = obj.modifiers.new("ProductionEdgeTreatment", "BEVEL")
        modifier.width = bevel
        modifier.segments = bevel_segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(18.0)
        modifier.harden_normals = False
        apply_modifier(obj, modifier)
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth
    GROUP_OBJECTS[group_path].append(obj)
    SOURCE_COUNTS[group_path] += 1
    return obj


def box(
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    group: str,
    role: str,
    bevel: float = 0.025,
    segments: int = 2,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=center, rotation=rotation)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return register_mesh(obj, name, group, role, bevel, segments)


def cylinder(
    name: str,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    group: str,
    role: str,
    vertices: int = 48,
    bevel: float = 0.025,
    segments: int = 2,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth,
        location=center, rotation=rotation,
    )
    return register_mesh(
        bpy.context.object, name, group, role, bevel, segments, smooth=True,
    )


def torus(
    name: str,
    center: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    group: str,
    role: str,
    major_segments: int = 64,
    minor_segments: int = 12,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius, minor_radius=minor_radius,
        major_segments=major_segments, minor_segments=minor_segments,
        location=center,
    )
    return register_mesh(bpy.context.object, name, group, role, 0.0, smooth=True)


def uv_sphere(
    name: str,
    center: tuple[float, float, float],
    scale: tuple[float, float, float],
    group: str,
    role: str,
    segments: int = 48,
    rings: int = 24,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=center,
    )
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return register_mesh(obj, name, group, role, 0.0, smooth=True)


def cone(
    name: str,
    center: tuple[float, float, float],
    radius1: float,
    radius2: float,
    depth: float,
    group: str,
    role: str,
    vertices: int = 48,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=radius2,
        depth=depth, location=center,
    )
    return register_mesh(bpy.context.object, name, group, role, 0.0, smooth=True)


def prism(
    name: str,
    footprint_xz: list[tuple[float, float]],
    bottom_y: float,
    top_y: float,
    group: str,
    role: str,
    bevel: float = 0.0,
    segments: int = 2,
) -> bpy.types.Object:
    area = math.fsum(
        footprint_xz[i][0] * footprint_xz[(i + 1) % len(footprint_xz)][1]
        - footprint_xz[(i + 1) % len(footprint_xz)][0] * footprint_xz[i][1]
        for i in range(len(footprint_xz))
    )
    # Clockwise X/Z produces +Y on the top face in a right-handed XYZ frame.
    footprint = footprint_xz if area < 0.0 else list(reversed(footprint_xz))
    count = len(footprint)
    vertices = [(x, bottom_y, z) for x, z in footprint]
    vertices.extend((x, top_y, z) for x, z in footprint)
    faces = [tuple(reversed(range(count))), tuple(count + i for i in range(count))]
    faces.extend(
        (i, (i + 1) % count, count + (i + 1) % count, count + i)
        for i in range(count)
    )
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    recalculate_outward(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return register_mesh(obj, name, group, role, bevel, segments)


def loft(
    name: str,
    sections: list[tuple[float, float, float, float]],
    group: str,
    role: str,
    bevel: float = 0.0,
    segments: int = 2,
) -> bpy.types.Object:
    """Create a closed longitudinal faceted body.

    Section values are (z, half_width, bottom_y, top_y).  Each section is a
    four-corner vertical slice and deliberately retains a planar upper ridge.
    """
    vertices = []
    for z, half_width, bottom_y, top_y in sections:
        vertices.extend([
            (-half_width, bottom_y, z),
            (half_width, bottom_y, z),
            (half_width, top_y, z),
            (-half_width, top_y, z),
        ])
    faces = [(0, 3, 2, 1)]
    for index in range(len(sections) - 1):
        a = index * 4
        b = (index + 1) * 4
        faces.extend([
            (a, b, b + 3, a + 3),
            (a + 1, a + 2, b + 2, b + 1),
            (a + 3, b + 3, b + 2, a + 2),
            (a, a + 1, b + 1, b),
        ])
    end = (len(sections) - 1) * 4
    faces.append((end, end + 1, end + 2, end + 3))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    recalculate_outward(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return register_mesh(obj, name, group, role, bevel, segments)


CANOPY_Z_FRONT = -2.72
CANOPY_Z_BACK = .48
CANOPY_SPINE_PROFILE = [(-3.55, .98), (-1.65, 2.05), (.65, 3.2055)]


def canopy_spine_top(z_value: float) -> float:
    for (z0, y0), (z1, y1) in zip(CANOPY_SPINE_PROFILE, CANOPY_SPINE_PROFILE[1:]):
        if z0 <= z_value <= z1:
            fraction = (z_value - z0) / (z1 - z0)
            return y0 + (y1 - y0) * fraction
    return (
        CANOPY_SPINE_PROFILE[0][1]
        if z_value < CANOPY_SPINE_PROFILE[0][0]
        else CANOPY_SPINE_PROFILE[-1][1]
    )


def canopy_surface_point(t: float, theta: float, frame_offset: float = 0.0) -> tuple[float, float, float]:
    z = CANOPY_Z_FRONT + (CANOPY_Z_BACK - CANOPY_Z_FRONT) * t
    envelope = math.sin(math.pi * t)
    half_width = .94 * envelope ** .72
    base_y = canopy_spine_top(z) - .035
    dome_height = .54 * envelope ** .88
    return (
        half_width * math.cos(theta),
        base_y + dome_height * math.sin(theta) + frame_offset,
        z,
    )


def curve_tube(
    name: str,
    points: list[tuple[float, float, float]],
    group: str,
    role: str,
    radius: float,
) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(f"{name}Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 2
    curve_data.resolution_u = 1
    spline = curve_data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*coordinate, 1.0)
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return register_mesh(obj, name, group, role, 0.0, smooth=True)


def canopy_dome(
    name: str,
    group: str,
    role: str,
    longitudinal_segments: int = 48,
    cross_segments: int = 20,
) -> bpy.types.Object:
    """Build a sleek closed half-dome conforming to the tall source wedge.

    Unlike a generic bubble intersected through the evidence-supported spine,
    this modern glazing begins on the wedge's upper facets and stays below the
    frozen 3.2m silhouette peak. Deliberately bounded longitudinal/cross rings
    give the PBR glass stable highlights without spending close density on a
    featureless transparent surface; modern frame rails carry the sharper read.
    """
    vertices = []
    rings: list[list[int]] = []
    for longitudinal_index in range(1, longitudinal_segments):
        t = longitudinal_index / longitudinal_segments
        ring = []
        for cross_index in range(cross_segments + 1):
            theta = math.pi * cross_index / cross_segments
            ring.append(len(vertices))
            vertices.append(canopy_surface_point(t, theta))
        rings.append(ring)
    front_tip = len(vertices)
    vertices.append((0.0, canopy_spine_top(CANOPY_Z_FRONT) - .035, CANOPY_Z_FRONT))
    back_tip = len(vertices)
    vertices.append((0.0, canopy_spine_top(CANOPY_Z_BACK) - .035, CANOPY_Z_BACK))
    faces = []
    for first, second in zip(rings, rings[1:]):
        for cross_index in range(cross_segments):
            faces.append((
                first[cross_index], second[cross_index],
                second[cross_index + 1], first[cross_index + 1],
            ))
    for cross_index in range(cross_segments):
        faces.append((front_tip, rings[0][cross_index + 1], rings[0][cross_index]))
        faces.append((back_tip, rings[-1][cross_index], rings[-1][cross_index + 1]))
    # Close the thin lower seam between the two dome edges.
    port_edge = [ring[0] for ring in rings]
    starboard_edge = [ring[-1] for ring in rings]
    faces.append((front_tip, port_edge[0], starboard_edge[0]))
    for index in range(len(port_edge) - 1):
        faces.append((
            port_edge[index], port_edge[index + 1],
            starboard_edge[index + 1], starboard_edge[index],
        ))
    faces.append((port_edge[-1], back_tip, starboard_edge[-1]))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    recalculate_outward(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return register_mesh(obj, name, group, role, 0.0, smooth=True)


def build_hierarchy() -> None:
    root = bpy.data.objects.new(ROOT_NAME, None)
    bpy.context.collection.objects.link(root)
    root["asset_id"] = ASSET_ID
    root["evidence_scope"] = EVIDENCE_SCOPE
    root["presentation_only"] = True
    HIERARCHY[ROOT_NAME] = root
    for direct_name in ("SourceCore", "ModernSystems"):
        direct = bpy.data.objects.new(direct_name, None)
        bpy.context.collection.objects.link(direct)
        direct.parent = root
        direct.matrix_parent_inverse.identity()
        direct["evidence_boundary"] = (
            "B7_observed_macroform" if direct_name == "SourceCore" else "modern_only"
        )
        HIERARCHY[direct_name] = direct
    for group_path in GROUP_PATHS:
        parent_name, child_name = group_path.split("/")
        child = bpy.data.objects.new(child_name, None)
        bpy.context.collection.objects.link(child)
        child.parent = HIERARCHY[parent_name]
        child.matrix_parent_inverse.identity()
        child["zenith_group"] = group_path
        child["presentation_only"] = True
        HIERARCHY[group_path] = child


def build_source_core_lod0() -> None:
    group = "SourceCore/LOD0"
    # Width-dominant arrow/delta shell.  The coarse footage supports the broad
    # planform and tiering, not exact topology or metre dimensions.
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        prism(
            f"{side}PrimaryDeltaPlane",
            [(0.0, -5.35), (sign * 1.85, -3.05), (sign * 7.21, 0.85),
             (sign * 6.55, 3.72), (sign * 2.05, 4.55), (0.0, 3.85)],
            0.00, 0.28, group, "PaleCeramicHull", 0.055, 4,
        )
    loft(
        "CentralFacetedWedge",
        [(-5.35, 0.03, 0.05, 0.18), (-3.55, 0.68, 0.02, 0.98),
         (-1.65, 1.32, 0.00, 2.05), (0.65, 1.48, 0.02, 3.2055),
         (2.65, 1.30, 0.02, 2.72), (4.62, 0.92, 0.02, 1.52)],
        group, "PaleCeramicHull", 0.065, 5,
    )
    # Long raised strakes and stepped plane subdivisions are visible across the
    # permitted approach/flight frames; the exact count and topology remain a
    # cautious modern indexing of that supported read.
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        prism(
            f"{side}LongUpperStrake",
            [(sign * 0.58, -3.15), (sign * 1.12, -2.58),
             (sign * 4.90, 3.52), (sign * 4.18, 3.73)],
            0.27, 0.66, group, "PaleCeramicHull", 0.045, 4,
        )
        prism(
            f"{side}InboardSpineShoulder",
            [(sign * 0.42, -2.75), (sign * 0.92, -2.08),
             (sign * 2.18, 3.35), (sign * 1.48, 3.62)],
            0.31, 0.82, group, "PaleFacetSecondary", 0.038, 3,
        )
        for tier in range(7):
            z0 = -1.92 + tier * 0.72
            inner = 1.55 + tier * 0.38
            outer = min(6.32, inner + 2.12 + tier * 0.10)
            prism(
                f"{side}SteppedSubdivision{tier + 1:02d}",
                [(sign * inner, z0 - 0.25), (sign * outer, z0 + 0.08),
                 (sign * (outer - 0.18), z0 + 0.43),
                 (sign * (inner + 0.12), z0 + 0.22)],
                0.285 + tier * 0.006, 0.335 + tier * 0.008,
                group, "PaleFacetSecondary", 0.018, 3,
            )
        # Cautiously indexed pod-like aft forms and small faceted fins.
        pod_form = cylinder(
            f"{side}ObservedPodLikeForm", (sign * 4.92, 0.54, 3.18),
            0.54, 1.62, group, "PaleCeramicHull", 32, 0.035, 3,
        )
        pod_form["historical_function_unresolved"] = True
        pod_form["count_placement_function_unauthenticated"] = True
        pod_form["evidence_claim"] = "cautiously_indexed_pod_like_form_only"
        prism(
            f"{side}IndexedAftFin",
            [(sign * 4.15, 2.42), (sign * 5.04, 3.18),
             (sign * 4.75, 4.12), (sign * 3.98, 3.48)],
            0.55, 1.38, group, "PaleCeramicHull", 0.035, 3,
        )


def build_source_core_lod1() -> None:
    group = "SourceCore/LOD1"
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        prism(
            f"LOD1{side}DeltaPlane",
            [(0.0, -5.35), (sign * 1.9, -3.0), (sign * 7.21, 0.85),
             (sign * 6.55, 3.72), (sign * 2.05, 4.55), (0.0, 3.85)],
            0.0, 0.28, group, "PaleCeramicHull", 0.06, 3,
        )
        prism(
            f"LOD1{side}LongStrake",
            [(sign * 0.60, -3.10), (sign * 1.12, -2.55),
             (sign * 4.9, 3.50), (sign * 4.15, 3.72)],
            0.27, 0.63, group, "PaleCeramicHull", 0.045, 2,
        )
        lod1_pod_form = cylinder(
            f"LOD1{side}PodForm", (sign * 4.92, 0.54, 3.18),
            0.54, 1.62, group, "PaleCeramicHull", 24, 0.03, 2,
        )
        lod1_pod_form["historical_function_unresolved"] = True
        lod1_pod_form["count_placement_function_unauthenticated"] = True
        lod1_pod_form["evidence_claim"] = "cautiously_indexed_pod_like_form_only"
        for tier in range(4):
            z0 = -1.65 + tier * 1.33
            inner = 1.75 + tier * 0.58
            prism(
                f"LOD1{side}Step{tier + 1}",
                [(sign * inner, z0 - .28), (sign * min(6.3, inner + 2.5), z0),
                 (sign * min(6.0, inner + 2.32), z0 + .42),
                 (sign * (inner + .12), z0 + .25)],
                .29, .34, group, "PaleFacetSecondary", .02, 2,
            )
    loft(
        "LOD1CentralFacetedWedge",
        [(-5.35, .03, .05, .18), (-3.55, .68, .02, .98),
         (-1.65, 1.32, 0.0, 2.05), (.65, 1.48, .02, 3.2055),
         (2.65, 1.30, .02, 2.72), (4.62, .92, .02, 1.52)],
        group, "PaleCeramicHull", .065, 3,
    )


def build_modern_lod0() -> None:
    group = "ModernSystems/LOD0"
    # Cockpit tub, anti-glare coaming, seat and compact PBR instrument panel.
    box("CockpitTub", (0.0, 1.10, -0.48), (1.62, .42, 2.35), group, "GraphitePanel", .08, 4)
    box("InterceptorSeat", (0.0, 1.42, -0.18), (.72, .82, .72), group, "GraphitePanel", .065, 4)
    box("InstrumentPanel", (0.0, 1.52, -1.26), (1.12, .38, .22), group, "GraphitePanel", .04, 3,
        rotation=(math.radians(-18), 0.0, 0.0))
    for index, x in enumerate((-.38, -.19, 0.0, .19, .38), 1):
        box(f"CockpitDisplay{index}", (x, 1.62, -1.375), (.14, .12, .025), group,
            "CockpitEmission", .012, 2, rotation=(math.radians(-18), 0.0, 0.0))
    # Layered paired propulsion, aligned to the non-authoritative plume anchors.
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        x = sign * 2.20
        cylinder(f"{side}EngineOuterCollar", (x, .42, 4.18), .74, 1.66,
                 group, "EngineGraphite", 64, .045, 4)
        torus(f"{side}EngineAlloyRing", (x, .42, 4.77), .56, .10,
              group, "ExposedAlloy", 128, 24)
        torus(f"{side}EngineThermalRing", (x, .42, 4.93), .42, .085,
              group, "EngineGraphite", 112, 20)
        cylinder(f"{side}EngineCore", (x, .42, 4.88), .34, .44,
                 group, "EngineEmission", 64, .025, 3)
        for vane in range(12):
            angle = math.tau * vane / 12.0
            box(
                f"{side}EngineStator{vane + 1:02d}",
                (x + math.cos(angle) * .42, .42 + math.sin(angle) * .42, 4.86),
                (.07, .25, .32), group, "ExposedAlloy", .014, 2,
                rotation=(0.0, 0.0, angle),
            )
        cone(f"{side}EnginePlume", (x, .38, 5.08), .31, .11, .44,
             group, "EngineEmission", 64)
        # Forward cannons stay visually authored but publish no weapon authority.
        cylinder(f"{side}CannonBarrel", (sign * 1.25, .34, -3.84), .105, .82,
                 group, "ExposedAlloy", 32, .018, 2)
        cylinder(f"{side}CannonShroud", (sign * 1.25, .34, -3.48), .235, .66,
                 group, "EngineGraphite", 32, .035, 3)
        # Folded/deployed gear is intentionally a modern landing solution.
        cylinder(f"{side}MainGearStrut", (sign * 2.55, -.30, 1.25), .10, 1.18,
                 group, "ExposedAlloy", 32, .018, 2, rotation=(math.pi / 2.0, 0.0, 0.0))
        box(f"{side}MainGearFoot", (sign * 2.55, -.95, 1.25), (.72, .20, .55),
            group, "GraphitePanel", .055, 3)
        box(f"{side}GearDoor", (sign * 2.10, -.03, .92), (.82, .08, 1.42),
            group, "GraphitePanel", .035, 3, rotation=(0.0, 0.0, sign * .12))
    cylinder("NoseGearStrut", (0.0, -.34, -2.82), .09, 1.08,
             group, "ExposedAlloy", 32, .018, 2, rotation=(math.pi / 2.0, 0.0, 0.0))
    box("NoseGearFoot", (0.0, -.95, -2.82), (.58, .20, .48), group, "GraphitePanel", .05, 3)
    box("VentralDockingPlate", (0.0, -.13, 1.05), (1.08, .16, 1.18), group, "GraphitePanel", .05, 3)
    torus("VentralDockingReceiverArt", (0.0, -.24, 1.05), .32, .07,
          group, "ExposedAlloy", 48, 10).rotation_euler[0] = math.pi / 2.0
    # Exact aviation convention is kept to the wrapper material bank.
    uv_sphere("PortNavigationLight", (-7.08, .28, .88), (.11, .11, .11),
              group, "PortNavRed", 24, 12)
    uv_sphere("StarboardNavigationLight", (7.08, .28, .88), (.11, .11, .11),
              group, "StarboardNavGreen", 24, 12)


def build_modern_lod1() -> None:
    group = "ModernSystems/LOD1"
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        x = sign * 2.20
        cylinder(f"LOD1{side}EngineHousing", (x, .42, 4.35), .68, 1.42,
                 group, "EngineGraphite", 32, .035, 2)
        cylinder(f"LOD1{side}EngineCore", (x, .42, 4.87), .33, .34,
                 group, "EngineEmission", 32, .015, 2)
        cone(f"LOD1{side}EnginePlume", (x, .38, 5.08), .29, .10, .44,
             group, "EngineEmission", 32)
    uv_sphere("LOD1PortNavigationLight", (-7.08, .28, .88), (.105, .105, .105),
              group, "PortNavRed", 16, 8)
    uv_sphere("LOD1StarboardNavigationLight", (7.08, .28, .88), (.105, .105, .105),
              group, "StarboardNavGreen", 16, 8)
    # Far canopy is an opaque, batched tonal witness so the complete craft does
    # not lose its cockpit read when the close articulated glass is hidden.
    uv_sphere("LOD1CanopyWitness", (0.0, 1.76, -.78), (.98, .66, 1.46),
              group, "GraphitePanel", 28, 14)


def build_canopy_and_anchors() -> None:
    pivot = HIERARCHY["ModernSystems/CanopyPivot"]
    pivot.location = (0.0, 2.65, 0.55)
    canopy = canopy_dome(
        "CanopyGlassShell", "ModernSystems/CanopyPivot", "CanopyGlass", 48, 20,
    )
    # Custom vertices are authored in root-local closed-pose coordinates.
    canopy.location = -pivot.location
    frame_specs = {
        "CanopyPortSill": [canopy_surface_point(index / 40.0, 0.0, .025) for index in range(1, 40)],
        "CanopyStarboardSill": [canopy_surface_point(index / 40.0, math.pi, .025) for index in range(1, 40)],
        "CanopyCentreFrame": [canopy_surface_point(index / 40.0, math.pi * .5, .025) for index in range(1, 40)],
        "CanopyForwardHoop": [canopy_surface_point(.34, math.pi * index / 24.0, .025) for index in range(25)],
        "CanopyAftHoop": [canopy_surface_point(.68, math.pi * index / 24.0, .025) for index in range(25)],
    }
    for frame_name, points in frame_specs.items():
        frame = curve_tube(
            frame_name, points, "ModernSystems/CanopyPivot", "GraphitePanel", .027,
        )
        frame.location = -pivot.location
    for name, position in ANCHORS_GODOT.items():
        anchor = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(anchor)
        anchor.parent = HIERARCHY["ModernSystems/SemanticAnchors"]
        anchor.matrix_parent_inverse.identity()
        anchor.location = position
        anchor.empty_display_type = "ARROWS"
        anchor.empty_display_size = .16
        anchor["semantic_anchor"] = True
        anchor["presentation_only"] = True
        anchor["gameplay_authority"] = False


def apply_uv0() -> dict:
    mesh_count = polygon_count = loop_count = fallback_count = 0
    for obj in sorted(
        (candidate for candidate in bpy.data.objects if candidate.type == "MESH"),
        key=lambda candidate: candidate.name,
    ):
        mesh = obj.data
        while mesh.uv_layers:
            mesh.uv_layers.remove(mesh.uv_layers[0])
        uv_layer = mesh.uv_layers.new(name="UVMap")
        normal_matrix = obj.matrix_world.to_3x3().inverted_safe().transposed()
        for polygon in mesh.polygons:
            polygon_count += 1
            coordinates = [
                obj.matrix_world @ mesh.vertices[mesh.loops[index].vertex_index].co
                for index in polygon.loop_indices
            ]
            normal = (normal_matrix @ polygon.normal).normalized()
            axis = max(range(3), key=lambda value: (abs(float(normal[value])), -value))
            projected = [
                (point.z, point.y) if axis == 0 else
                (point.x, point.z) if axis == 1 else (point.x, point.y)
                for point in coordinates
            ]
            if len({(round(u, 8), round(v, 8)) for u, v in projected}) < 3:
                projected = [
                    (.012 * math.cos(math.tau * index / len(coordinates)),
                     .012 * math.sin(math.tau * index / len(coordinates)))
                    for index in range(len(coordinates))
                ]
                fallback_count += 1
            scale = 0.32
            for loop_index, (u, v) in zip(polygon.loop_indices, projected):
                uv_layer.data[loop_index].uv = (u * scale, v * scale)
                loop_count += 1
        mesh_count += 1
    return {
        "method": "deterministic_dominant_axis_box_projection_v1",
        "texture_coordinate": "UV0/TEXCOORD_0",
        "mesh_count": mesh_count,
        "polygon_count": polygon_count,
        "loop_count": loop_count,
        "fallback_polygon_count": fallback_count,
        "all_source_meshes_mapped": True,
    }


def group_metrics() -> dict:
    result = {}
    for group_path in GROUP_PATHS:
        vertices = triangles = 0
        bounds: list[Vector] = []
        for obj in GROUP_OBJECTS[group_path]:
            vertices += len(obj.data.vertices)
            triangles += sum(max(1, len(polygon.vertices) - 2) for polygon in obj.data.polygons)
            bounds.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
        result[group_path] = {
            "mesh_count": len(GROUP_OBJECTS[group_path]),
            "vertex_count": vertices,
            "triangle_count": triangles,
            "bounds_minimum": [min(point[i] for point in bounds) for i in range(3)] if bounds else [],
            "bounds_maximum": [max(point[i] for point in bounds) for i in range(3)] if bounds else [],
        }
    return result


def whole_bounds() -> dict[str, list[float]]:
    points = [
        obj.matrix_world @ Vector(corner)
        for group_path in GROUP_PATHS
        for obj in GROUP_OBJECTS[group_path]
        for corner in obj.bound_box
    ]
    return {
        "minimum": [min(point[axis] for point in points) for axis in range(3)],
        "maximum": [max(point[axis] for point in points) for axis in range(3)],
    }


def _source_core_bvh() -> BVHTree:
    return _objects_bvh(GROUP_OBJECTS["SourceCore/LOD0"])


def _objects_bvh(objects: list[bpy.types.Object]) -> BVHTree:
    vertices: list[tuple[float, float, float]] = []
    polygons: list[list[int]] = []
    for obj in objects:
        offset = len(vertices)
        vertices.extend(tuple(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices)
        polygons.extend([[offset + index for index in polygon.vertices] for polygon in obj.data.polygons])
    return BVHTree.FromPolygons(vertices, polygons, all_triangles=False)


def _collision_prism_points(
    footprint: list[tuple[float, float]], low: float, high: float,
) -> list[tuple[float, float, float]]:
    return [(x, low, z) for x, z in footprint] + [(x, high, z) for x, z in footprint]


def _collision_box_points(
    position: tuple[float, float, float], size: tuple[float, float, float],
    rotation_degrees: tuple[float, float, float],
) -> list[tuple[float, float, float]]:
    rotation = Euler(tuple(math.radians(value) for value in rotation_degrees), "XYZ").to_matrix()
    centre = Vector(position)
    half = Vector(size) * .5
    return [
        tuple(centre + rotation @ Vector((sx * half.x, sy * half.y, sz * half.z)))
        for sx in (-1.0, 1.0) for sy in (-1.0, 1.0) for sz in (-1.0, 1.0)
    ]


def _collision_cylinder_points(
    position: tuple[float, float, float], radius: float, height: float,
    rotation_degrees: tuple[float, float, float], segments: int = 32,
) -> list[tuple[float, float, float]]:
    rotation = Euler(tuple(math.radians(value) for value in rotation_degrees), "XYZ").to_matrix()
    centre = Vector(position)
    return [
        tuple(centre + rotation @ Vector((
            radius * math.cos(math.tau * index / segments), end,
            radius * math.sin(math.tau * index / segments),
        )))
        for end in (-height * .5, height * .5) for index in range(segments)
    ]


def _collision_object_points(names: list[str]) -> list[tuple[float, float, float]]:
    result = []
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"Missing collision proposal source object: {name}")
        result.extend(tuple(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices)
    return result


def _convex_hull_geometry(
    source_points: list[tuple[float, float, float]],
) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int]]]:
    unique = sorted({tuple(round(float(axis), 6) for axis in point) for point in source_points})
    if len(unique) < 4:
        raise RuntimeError("Collision convex hull needs at least four unique points")
    bm = bmesh.new()
    verts = [bm.verts.new(point) for point in unique]
    bmesh.ops.convex_hull(bm, input=verts, use_existing_faces=False)
    bm.faces.ensure_lookup_table()
    referenced = sorted({
        tuple(round(float(axis), 6) for axis in vertex.co)
        for face in bm.faces for vertex in face.verts
    })
    index_by_point = {point: index for index, point in enumerate(referenced)}
    centroid = sum((Vector(point) for point in referenced), Vector()) / len(referenced)
    triangles: set[tuple[int, int, int]] = set()
    for face in bm.faces:
        face_points = [tuple(round(float(axis), 6) for axis in vertex.co) for vertex in face.verts]
        for offset in range(1, len(face_points) - 1):
            indices = [
                index_by_point[face_points[0]], index_by_point[face_points[offset]],
                index_by_point[face_points[offset + 1]],
            ]
            a, b, c = (Vector(referenced[index]) for index in indices)
            normal = (b - a).cross(c - a)
            if normal.dot((a + b + c) / 3.0 - centroid) < 0.0:
                indices[1], indices[2] = indices[2], indices[1]
            lowest = indices.index(min(indices))
            triangles.add(tuple(indices[lowest:] + indices[:lowest]))
    bm.free()
    if not triangles:
        raise RuntimeError("Collision convex hull produced no boundary triangles")
    return referenced, sorted(triangles)


def _collision_shape_specs() -> list[dict]:
    center_root = [(0.0, -5.35), (1.85, -3.05), (0.0, 3.85), (-1.85, -3.05)]
    port_main = [(-1.85, -3.05), (-7.21, .85), (-6.55, 3.72), (-2.05, 4.55), (0.0, 3.85)]
    sections = [
        (-5.35, .03, .05, .18), (-3.55, .68, .02, .98),
        (-1.65, 1.32, 0.0, 2.05), (.65, 1.48, .02, 3.2055),
        (2.65, 1.30, .02, 2.72), (4.62, .92, .02, 1.52),
    ]
    central = []
    for z, half_width, bottom, top in sections:
        central.extend([
            (-half_width, bottom, z), (half_width, bottom, z),
            (half_width, top + .02, z), (-half_width, top + .02, z),
        ])

    specs: list[dict] = []
    def convex(name: str, points, purpose: str, source_names=(), **extra) -> None:
        specs.append({
            "name": name, "shape_type": "ConvexPolygonShape3D", "points": list(points),
            "purpose": purpose, "source_object_names": list(source_names), **extra,
        })
    def cylinder_spec(name: str, position, radius, height, purpose: str, source_names=()) -> None:
        specs.append({
            "name": name, "shape_type": "CylinderShape3D", "position": position,
            "radius": radius, "height": height, "rotation_degrees": (0.0, 0.0, 0.0),
            "purpose": purpose, "source_object_names": list(source_names),
        })
    def box_spec(name: str, position, size, purpose: str, source_names=()) -> None:
        specs.append({
            "name": name, "shape_type": "BoxShape3D", "position": position, "size": size,
            "rotation_degrees": (0.0, 0.0, 0.0), "purpose": purpose,
            "source_object_names": list(source_names),
        })

    convex("CenterWingRoot", _collision_prism_points(center_root, 0.0, .28),
           "exact central primary-delta structural prism", ["PortPrimaryDeltaPlane", "StarboardPrimaryDeltaPlane"])
    convex("PortMainWing", _collision_prism_points(port_main, 0.0, .28),
           "exact concavity-free port primary-delta outer prism", ["PortPrimaryDeltaPlane"])
    convex("StarboardMainWing", _collision_prism_points([(-x, z) for x, z in port_main], 0.0, .28),
           "exact concavity-free starboard primary-delta outer prism", ["StarboardPrimaryDeltaPlane"])
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        convex(
            f"{side}LongStrake",
            _collision_prism_points([
                (sign * .58, -3.15), (sign * 1.12, -2.58),
                (sign * 4.90, 3.52), (sign * 4.18, 3.73),
            ], .27, .66),
            f"{side.lower()} long source-supported strake prism", [f"{side}LongUpperStrake"],
        )
        convex(
            f"{side}SpineShoulder",
            _collision_prism_points([
                (sign * .42, -2.75), (sign * .92, -2.08),
                (sign * 2.18, 3.35), (sign * 1.48, 3.62),
            ], .31, .82),
            f"{side.lower()} raised spine-shoulder prism", [f"{side}InboardSpineShoulder"],
        )
        pod_name = f"{side}ObservedPodLikeForm"
        convex(
            f"{side}ObservedPod", _collision_object_points([pod_name]),
            f"{side.lower()} cautiously indexed observed pod-like solid", [pod_name],
            historical_function_unresolved=True,
            count_placement_function_unauthenticated=True,
        )
        fin_name = f"{side}IndexedAftFin"
        convex(f"{side}IndexedFin", _collision_object_points([fin_name]),
               f"{side.lower()} cautiously indexed aft fin", [fin_name])
    convex("CentralWedgeRaised20mm", central,
           "tapered central wedge/spine loft with 20mm structural top allowance", ["CentralFacetedWedge"])
    for side, sign in (("Port", -1.0), ("Starboard", 1.0)):
        engine_names = [
            f"{side}EngineOuterCollar", f"{side}EngineAlloyRing",
            f"{side}EngineThermalRing", f"{side}EngineCore",
            *[f"{side}EngineStator{index:02d}" for index in range(1, 13)],
        ]
        convex(f"{side}EngineHull", _collision_object_points(engine_names),
               f"localized {side.lower()} engine assembly hull excluding plume", engine_names)
        cannon_names = [f"{side}CannonBarrel", f"{side}CannonShroud"]
        convex(f"{side}CannonHull", _collision_object_points(cannon_names),
               f"localized {side.lower()} cannon barrel/shroud hull", cannon_names)
        cylinder_spec(f"{side}MainGearStrut", (sign * 2.55, -.30, 1.25), .10, 1.18,
                      f"{side.lower()} main gear strut", [f"{side}MainGearStrut"])
        box_spec(f"{side}MainGearFoot", (sign * 2.55, -.95, 1.25), (.72, .20, .55),
                 f"{side.lower()} main gear foot", [f"{side}MainGearFoot"])
    door_names = ["PortGearDoor", "StarboardGearDoor"]
    convex("PairedMainGearDoorRelief", _collision_object_points(door_names),
           "thin paired main-gear door relief under retained central wing structure", door_names)
    cylinder_spec("NoseGearStrut", (0.0, -.34, -2.82), .09, 1.08,
                  "nose gear strut", ["NoseGearStrut"])
    box_spec("NoseGearFoot", (0.0, -.95, -2.82), (.58, .20, .48),
             "nose gear foot", ["NoseGearFoot"])
    docking_names = ["VentralDockingPlate", "VentralDockingReceiverArt"]
    convex("DockingHull", _collision_object_points(docking_names),
           "localized ventral docking plate/receiver visual hull", docking_names)
    return specs


class _CollisionShapeRuntime:
    def __init__(self, spec: dict):
        self.spec = spec
        self.name = spec["name"]
        self.shape_type = spec["shape_type"]
        if self.shape_type == "ConvexPolygonShape3D":
            raw_points = spec["points"]
        elif self.shape_type == "BoxShape3D":
            raw_points = _collision_box_points(
                spec["position"], spec["size"], spec["rotation_degrees"],
            )
        elif self.shape_type == "CylinderShape3D":
            raw_points = _collision_cylinder_points(
                spec["position"], spec["radius"], spec["height"],
                spec["rotation_degrees"], 32,
            )
        else:
            raise RuntimeError(f"Unsupported collision proposal shape: {self.shape_type}")
        self.boundary_approximation_allowance_m = (
            spec["radius"] * (1.0 - math.cos(math.pi / 32.0))
            if self.shape_type == "CylinderShape3D" else 0.0
        )
        self.points, self.faces = _convex_hull_geometry(raw_points)
        self.minimum = Vector(tuple(min(point[axis] for point in self.points) for axis in range(3)))
        self.maximum = Vector(tuple(max(point[axis] for point in self.points) for axis in range(3)))
        self.bvh = BVHTree.FromPolygons(self.points, self.faces, all_triangles=True)
        self.centroid = sum((Vector(point) for point in self.points), Vector()) / len(self.points)
        self.face_records = []
        for face in self.faces:
            a, b, c = (Vector(self.points[index]) for index in face)
            normal = (b - a).cross(c - a).normalized()
            if normal.dot((a + b + c) / 3.0 - self.centroid) < 0.0:
                normal = -normal
            self.face_records.append((face, normal))

    def contains(self, point: Vector, inset: float = 0.0) -> bool:
        if self.shape_type == "CylinderShape3D":
            rotation = Euler(
                tuple(math.radians(value) for value in self.spec["rotation_degrees"]), "XYZ",
            ).to_matrix()
            local = rotation.transposed() @ (point - Vector(self.spec["position"]))
            radial = math.sqrt(local.x * local.x + local.z * local.z)
            return (
                radial <= self.spec["radius"] - inset + 1e-8
                and abs(local.y) <= self.spec["height"] * .5 - inset + 1e-8
            )
        for face, normal in self.face_records:
            if (point - Vector(self.points[face[0]])).dot(normal) > -inset + 1e-8:
                return False
        return True

    def distance(self, point: Vector) -> float:
        if self.shape_type == "CylinderShape3D":
            rotation = Euler(
                tuple(math.radians(value) for value in self.spec["rotation_degrees"]), "XYZ",
            ).to_matrix()
            local = rotation.transposed() @ (point - Vector(self.spec["position"]))
            radial_gap = max(math.sqrt(local.x * local.x + local.z * local.z) - self.spec["radius"], 0.0)
            axial_gap = max(abs(local.y) - self.spec["height"] * .5, 0.0)
            return math.sqrt(radial_gap * radial_gap + axial_gap * axial_gap)
        if self.contains(point):
            return 0.0
        nearest = self.bvh.find_nearest(point)
        return nearest[3] if nearest else math.inf

    def exact_boundary_sample(self, point: Vector, face_normal: Vector) -> Vector:
        """Map an inscribed-cylinder side proxy onto the exact curved surface."""
        if self.shape_type != "CylinderShape3D":
            return point
        rotation = Euler(
            tuple(math.radians(value) for value in self.spec["rotation_degrees"]), "XYZ",
        ).to_matrix()
        local = rotation.transposed() @ (point - Vector(self.spec["position"]))
        local_normal = rotation.transposed() @ face_normal
        if abs(local_normal.y) >= .5:
            return point  # Exact cap plane sample.
        radial = Vector((local.x, 0.0, local.z))
        if radial.length <= 1e-12:
            return point
        projected = radial.normalized() * self.spec["radius"]
        projected.y = local.y
        return Vector(self.spec["position"]) + rotation @ projected

    def manifest_record(self) -> dict:
        record = {
            "name": self.name, "shape_type": self.shape_type,
            "purpose": self.spec["purpose"], "authority": False,
            "provenance": "generator_fitted_to_frozen_original_close_art_v2",
            "source_object_names": self.spec["source_object_names"],
        }
        if self.shape_type == "ConvexPolygonShape3D":
            record["points"] = [list(point) for point in self.points]
            record["point_count"] = len(self.points)
            record["points_sha256"] = hashlib.sha256(json.dumps(
                record["points"], separators=(",", ":"), sort_keys=False,
            ).encode("utf-8")).hexdigest()
        elif self.shape_type == "BoxShape3D":
            record.update({
                "position": list(self.spec["position"]), "size": list(self.spec["size"]),
                "rotation_degrees": list(self.spec["rotation_degrees"]),
            })
        else:
            record.update({
                "position": list(self.spec["position"]), "radius": self.spec["radius"],
                "height": self.spec["height"],
                "rotation_degrees": list(self.spec["rotation_degrees"]),
            })
        for key in ("historical_function_unresolved", "count_placement_function_unauthenticated"):
            if key in self.spec:
                record[key] = self.spec[key]
        return record


class _AuthoredSolid:
    _RAY_DIRECTIONS = (
        Vector((1.0, .371, .529)).normalized(),
        Vector((-.283, 1.0, .617)).normalized(),
        Vector((.419, -.337, 1.0)).normalized(),
    )

    def __init__(self, obj: bpy.types.Object):
        self.name = obj.name
        self.points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        self.minimum = Vector(tuple(min(point[axis] for point in self.points) for axis in range(3)))
        self.maximum = Vector(tuple(max(point[axis] for point in self.points) for axis in range(3)))
        self.bvh = _objects_bvh([obj])
        edge_use = Counter(index for polygon in obj.data.polygons for index in polygon.edge_keys)
        # `polygon.edge_keys` yields key tuples; Counter value 2 means closed manifold.
        if edge_use and any(count != 2 for count in edge_use.values()):
            raise RuntimeError(f"Structural collision audit mesh is not closed: {obj.name}")

    def contains(self, point: Vector) -> bool:
        if any(
            point[axis] < self.minimum[axis] - 1e-6
            or point[axis] > self.maximum[axis] + 1e-6
            for axis in range(3)
        ):
            return False
        nearest = self.bvh.find_nearest(point)
        if nearest and nearest[3] <= 1e-6:
            return True
        votes = 0
        for direction in self._RAY_DIRECTIONS:
            cursor = point.copy()
            hits = 0
            for _ in range(128):
                hit = self.bvh.ray_cast(cursor, direction, 100.0)
                if hit[0] is None:
                    break
                hits += 1
                cursor = hit[0] + direction * 1e-5
            else:
                raise RuntimeError(f"Ray-parity containment failed to terminate for {self.name}")
            votes += hits % 2
        return votes >= 2


def _triangle_grid_cells(a: Vector, b: Vector, c: Vector, divisions: int):
    def point(i: int, j: int) -> Vector:
        return a + (b - a) * (i / divisions) + (c - a) * (j / divisions)
    for i in range(divisions):
        for j in range(divisions - i):
            yield (point(i, j), point(i + 1, j), point(i, j + 1))
            if i + j <= divisions - 2:
                yield (point(i + 1, j), point(i + 1, j + 1), point(i, j + 1))


def _capsule_collision_sweep(
    shapes: list[_CollisionShapeRuntime], start_root: Vector, end_root: Vector,
    route_spacing: float,
) -> dict:
    radius = BOARDING_CAPSULE["radius"]
    segment_half = BOARDING_CAPSULE["total_height"] * .5 - radius
    offset = Vector(BOARDING_CAPSULE["center_offset"])
    route_distance = (end_root - start_root).length
    route_intervals = max(1, math.ceil(route_distance / route_spacing))
    axis_intervals = max(1, math.ceil(2.0 * segment_half / route_spacing))
    actual_route_spacing = route_distance / route_intervals if route_distance else 0.0
    actual_axis_spacing = 2.0 * segment_half / axis_intervals
    minimum = math.inf
    worst_root = None
    worst_axis = None
    for route_index in range(route_intervals + 1):
        root = start_root.lerp(end_root, route_index / route_intervals)
        centre = root + offset
        for axis_index in range(axis_intervals + 1):
            point = Vector((
                centre.x,
                centre.y - segment_half + 2.0 * segment_half * axis_index / axis_intervals,
                centre.z,
            ))
            distance = min(shape.distance(point) for shape in shapes)
            if distance < minimum:
                minimum = distance
                worst_root = root.copy()
                worst_axis = point.copy()
    route_half = actual_route_spacing * .5
    axis_half = actual_axis_spacing * .5
    route_direction = (
        (end_root - start_root).normalized() if route_distance > 1e-12 else Vector()
    )
    route_axis_correlation = abs(route_direction.dot(Vector((0.0, 1.0, 0.0))))
    covering_radius = math.sqrt(
        route_half * route_half + axis_half * axis_half
        + 2.0 * route_axis_correlation * route_half * axis_half
    )
    conservative = minimum - radius - covering_radius
    return {
        "sample_count": (route_intervals + 1) * (axis_intervals + 1),
        "route_spacing_m": actual_route_spacing,
        "axis_spacing_m": actual_axis_spacing,
        "continuous_error_bound_m": covering_radius,
        "route_axis_absolute_dot": route_axis_correlation,
        "sampled_clearance_m": minimum - radius,
        "conservative_continuous_clearance_m": conservative,
        "worst_root_position": list(worst_root),
        "worst_axis_point": list(worst_axis),
        "clear": conservative + 1e-9 >= BOARDING_ROUTE["required_minimum_clearance_m"],
    }


def collision_proposal_audit() -> dict:
    close_paths = ("SourceCore/LOD0", "ModernSystems/LOD0", "ModernSystems/CanopyPivot")
    close_objects = [obj for path in close_paths for obj in GROUP_OBJECTS[path]]
    close_names = {obj.name for obj in close_objects}
    classified_names = set(COLLISION_EXCLUSIONS) | set(NON_CONTACT_DECORATIVE_TRIM)
    missing = sorted(classified_names - close_names)
    if missing:
        raise RuntimeError(f"Collision classification missing from close art: {missing}")
    included = sorted(
        (obj for obj in close_objects if obj.name not in classified_names),
        key=lambda item: item.name,
    )
    excluded = sorted(
        (obj for obj in close_objects if obj.name in COLLISION_EXCLUSIONS),
        key=lambda item: item.name,
    )
    decorative_trim = sorted(
        (obj for obj in close_objects if obj.name in NON_CONTACT_DECORATIVE_TRIM),
        key=lambda item: item.name,
    )
    if len(included) != 65:
        raise RuntimeError(f"Structural collision roster drift: {len(included)} != 65")

    shapes = [_CollisionShapeRuntime(spec) for spec in _collision_shape_specs()]
    if len(shapes) != COLLISION_MAXIMUM_SHAPES:
        raise RuntimeError(f"Zenith V2 proposal must use exactly 24 shapes: {len(shapes)}")
    if len({shape.name for shape in shapes}) != len(shapes):
        raise RuntimeError("Duplicate Zenith collision shape name")
    type_counts = Counter(shape.shape_type for shape in shapes)
    if type_counts != Counter({"ConvexPolygonShape3D": 18, "CylinderShape3D": 3, "BoxShape3D": 3}):
        raise RuntimeError(f"Zenith collision type roster drift: {type_counts}")

    shape_stats = {
        shape.name: {
            "assigned_vertex_count": 0, "assigned_within_20mm_count": 0,
            "assigned_object_names": set(), "maximum_assigned_miss_m": 0.0,
        }
        for shape in shapes
    }
    object_stats = {}
    maximum_miss = 0.0
    failure_count = 0
    audited_vertex_count = 0
    for obj in included:
        object_max = 0.0
        object_failures = 0
        object_worst = None
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            miss, nearest = min(
                ((shape.distance(point), shape) for shape in shapes),
                key=lambda item: item[0],
            )
            stats = shape_stats[nearest.name]
            stats["assigned_vertex_count"] += 1
            stats["assigned_object_names"].add(obj.name)
            stats["maximum_assigned_miss_m"] = max(stats["maximum_assigned_miss_m"], miss)
            if miss <= COLLISION_MAXIMUM_MISS_M + 1e-9:
                stats["assigned_within_20mm_count"] += 1
            else:
                object_failures += 1
                failure_count += 1
            if miss > object_max:
                object_max = miss
                object_worst = point.copy()
            maximum_miss = max(maximum_miss, miss)
            audited_vertex_count += 1
        object_stats[obj.name] = {
            "vertex_count": len(obj.data.vertices), "vertices_over_20mm": object_failures,
            "maximum_miss_m": object_max,
            "worst_point": list(object_worst) if object_worst else [],
        }
    if audited_vertex_count != 19_378:
        raise RuntimeError(f"Structural collision vertex roster drift: {audited_vertex_count}")
    if failure_count:
        offenders = sorted(
            ((record["maximum_miss_m"], name, record["vertices_over_20mm"])
             for name, record in object_stats.items() if record["vertices_over_20mm"]),
            reverse=True,
        )
        raise RuntimeError(f"Zenith structural collision misses: {offenders[:16]}")

    art_bvh = _objects_bvh(included)
    art_solids = [_AuthoredSolid(obj) for obj in included]
    distance_cache: dict[tuple[float, float, float], float] = {}
    def conservative_art_solid_distance(point: Vector) -> float:
        key = tuple(round(float(axis), 7) for axis in point)
        if key in distance_cache:
            return distance_cache[key]
        nearest = art_bvh.find_nearest(point)
        if nearest is None:
            value = math.inf
        elif nearest[3] <= .10:
            # Unsigned surface distance is an upper bound on distance to the
            # actual solid. Keeping it is conservative and avoids optimistic
            # point-in-solid assumptions for values already safely below gate.
            value = nearest[3]
        else:
            value = 0.0 if any(solid.contains(point) for solid in art_solids) else nearest[3]
        distance_cache[key] = value
        return value

    spacing_by_shape = {
        shape.name: (
            .020 if shape.name == "PairedMainGearDoorRelief"
            else .030 if shape.name in {
                "CenterWingRoot", "PortMainWing", "StarboardMainWing",
                "CentralWedgeRaised20mm",
            }
            else .040
        )
        for shape in shapes
    }
    reverse_by_shape = {}
    sampled_cells = 0
    fully_hidden_cells = 0
    tested_cells = 0
    vertex_distance_queries = 0
    global_sample_max = 0.0
    global_exposed_sample_max = 0.0
    global_bound = 0.0
    global_sample_worst = None
    global_exposed_sample_worst = None
    global_bound_worst = None
    exposed_sample_count = 0
    for shape in shapes:
        shape_sample_max = 0.0
        shape_exposed_sample_max = 0.0
        shape_bound = 0.0
        shape_worst = None
        shape_exposed_worst = None
        shape_bound_worst = None
        shape_cells = 0
        shape_hidden = 0
        for face, outward_normal in shape.face_records:
            a, b, c = (Vector(shape.points[index]) for index in face)
            maximum_edge = max((a - b).length, (b - c).length, (c - a).length)
            divisions = max(1, math.ceil(maximum_edge / spacing_by_shape[shape.name]))
            face_minimum = Vector(tuple(min(point[axis] for point in (a, b, c)) - .001 for axis in range(3)))
            face_maximum = Vector(tuple(max(point[axis] for point in (a, b, c)) + .001 for axis in range(3)))
            possible_occluders = [
                other for other in shapes
                if other is not shape and all(
                    other.maximum[axis] >= face_minimum[axis]
                    and other.minimum[axis] <= face_maximum[axis]
                    for axis in range(3)
                )
            ]
            for cell in _triangle_grid_cells(a, b, c, divisions):
                sampled_cells += 1
                shape_cells += 1
                # Convexity proof: if one other shape contains all three cell
                # vertices a millimetre outward from this face, its entire
                # affine subtriangle is hidden. No exposed island is skipped.
                if shape.shape_type != "CylinderShape3D" and any(
                    other is not shape
                    and all(other.contains(point) for point in cell)
                    and all(other.contains(point + outward_normal * .001) for point in cell)
                    for other in possible_occluders
                ):
                    fully_hidden_cells += 1
                    shape_hidden += 1
                    continue
                tested_cells += 1
                query_cell = tuple(
                    shape.exact_boundary_sample(point, outward_normal) for point in cell
                )
                distances = [conservative_art_solid_distance(point) for point in query_cell]
                vertex_distance_queries += 3
                exposed_flags = [
                    not any(
                        other.contains(point, inset=1e-6)
                        for other in possible_occluders
                    )
                    for point in query_cell
                ]
                exposed_sample_count += sum(exposed_flags)
                cell_sample_max = max(distances)
                cell_diameter = max(
                    (query_cell[0] - query_cell[1]).length,
                    (query_cell[1] - query_cell[2]).length,
                    (query_cell[2] - query_cell[0]).length,
                )
                cell_bound = (
                    cell_sample_max + cell_diameter
                    + shape.boundary_approximation_allowance_m
                )
                if cell_sample_max > shape_sample_max:
                    shape_sample_max = cell_sample_max
                    shape_worst = query_cell[distances.index(cell_sample_max)].copy()
                for point, distance, exposed in zip(query_cell, distances, exposed_flags):
                    if exposed and distance > shape_exposed_sample_max:
                        shape_exposed_sample_max = distance
                        shape_exposed_worst = point.copy()
                if cell_bound > shape_bound:
                    shape_bound = cell_bound
                    shape_bound_worst = query_cell[distances.index(cell_sample_max)].copy()
        reverse_by_shape[shape.name] = {
            "spacing_limit_m": spacing_by_shape[shape.name],
            "sampled_cell_count": shape_cells,
            "fully_hidden_cell_count": shape_hidden,
            "tested_cell_count": shape_cells - shape_hidden,
            "maximum_bound_anchor_distance_to_included_art_solid_m": shape_sample_max,
            "maximum_exposed_sample_distance_to_included_art_solid_m": shape_exposed_sample_max,
            "conservative_continuous_upper_bound_m": shape_bound,
            "analytic_boundary_approximation_allowance_m": shape.boundary_approximation_allowance_m,
            "worst_point": list(shape_worst) if shape_worst else [],
            "exposed_sample_worst_point": list(shape_exposed_worst) if shape_exposed_worst else [],
            "continuous_bound_worst_point": list(shape_bound_worst) if shape_bound_worst else [],
        }
        if shape_sample_max > global_sample_max:
            global_sample_max = shape_sample_max
            global_sample_worst = (shape.name, shape_worst.copy() if shape_worst else None)
        if shape_exposed_sample_max > global_exposed_sample_max:
            global_exposed_sample_max = shape_exposed_sample_max
            global_exposed_sample_worst = (
                shape.name, shape_exposed_worst.copy() if shape_exposed_worst else None,
            )
        if shape_bound > global_bound:
            global_bound = shape_bound
            global_bound_worst = (
                shape.name, shape_bound_worst.copy() if shape_bound_worst else None,
            )
    if global_bound > COLLISION_REVERSE_MAXIMUM_M + 1e-9:
        raise RuntimeError(
            f"Zenith collision reverse-fit RED: {global_bound:.9f}m at {global_bound_worst}"
        )

    probes = [
        (-6.0, .2, -3.0), (6.0, .2, -3.0), (-6.0, .2, 4.5), (6.0, .2, 4.5),
        (-7.0, .2, -4.0), (7.0, .2, -4.0), (-6.8, .2, 4.3), (6.8, .2, 4.3),
    ]
    probe_records = [{
        "point": list(point),
        "inside_union": any(shape.contains(Vector(point)) for shape in shapes),
    } for point in probes]
    if any(record["inside_union"] for record in probe_records):
        raise RuntimeError(f"Zenith collision entered an empty-corner probe: {probe_records}")

    grounding_sweep = _capsule_collision_sweep(
        shapes, Vector(BOARDING_ROUTE["initial_root_position"]),
        Vector(BOARDING_ROUTE["grounded_root_position"]), .010,
    )
    grounded_walk = _capsule_collision_sweep(
        shapes, Vector(BOARDING_ROUTE["grounded_root_position"]),
        Vector(BOARDING_ROUTE["grounded_end_root_position"]), .010,
    )
    marker_capsule = _capsule_collision_sweep(
        shapes, Vector(BOARDING_CAPSULE["root_position"]),
        Vector(BOARDING_CAPSULE["root_position"]), .005,
    )
    if not grounding_sweep["clear"] or not grounded_walk["clear"] or not marker_capsule["clear"]:
        raise RuntimeError(
            f"Production capsule route RED: grounding={grounding_sweep}, "
            f"walk={grounded_walk}, marker={marker_capsule}"
        )

    capsule_centre = Vector(BOARDING_CAPSULE["center_position"])
    segment_half = BOARDING_CAPSULE["total_height"] * .5 - BOARDING_CAPSULE["radius"]
    art_axis_samples = 1001
    art_axis_spacing = 2.0 * segment_half / (art_axis_samples - 1)
    sampled_art_axis_distance = min(
        art_bvh.find_nearest(Vector((
            capsule_centre.x,
            capsule_centre.y - segment_half + 2.0 * segment_half * index / (art_axis_samples - 1),
            capsule_centre.z,
        )))[3]
        for index in range(art_axis_samples)
    )
    marker_art_clearance = (
        sampled_art_axis_distance - art_axis_spacing * .5 - BOARDING_CAPSULE["radius"]
    )
    if marker_art_clearance < BOARDING_CAPSULE["minimum_art_clearance"] - 1e-9:
        raise RuntimeError(f"Production marker capsule/art clearance RED: {marker_art_clearance}")

    area_center = Vector(BOARDING_AREA_WITNESS["center"])
    area_art_clearance = art_bvh.find_nearest(area_center)[3]
    area_collision_clearance = min(shape.distance(area_center) for shape in shapes)
    trim_records = []
    for obj in decorative_trim:
        maximum_inset = max(
            min(shape.distance(obj.matrix_world @ vertex.co) for shape in shapes)
            for vertex in obj.data.vertices
        )
        trim_records.append({
            "name": obj.name, "classification": "non_contact_decorative_trim",
            "reason": NON_CONTACT_DECORATIVE_TRIM[obj.name],
            "maximum_visual_vertex_inset_from_collision_union_m": maximum_inset,
            "visual_solid_retained": True, "authority": False,
        })

    source_bvh = _source_core_bvh()
    cannon_contact = {}
    for side in ("Port", "Starboard"):
        for name in (f"{side}CannonShroud", f"{side}CannonBarrel"):
            obj = bpy.data.objects.get(name)
            minimum = min(
                source_bvh.find_nearest(obj.matrix_world @ vertex.co)[3]
                for vertex in obj.data.vertices
            )
            cannon_contact[name] = {
                "minimum_distance_to_source_solid_m": minimum,
                "attachment_maximum_m": COLLISION_MAXIMUM_MISS_M,
                "attached": minimum <= COLLISION_MAXIMUM_MISS_M + 1e-9,
            }
    if any(not record["attached"] for record in cannon_contact.values()):
        raise RuntimeError(f"Detached Zenith cannon geometry: {cannon_contact}")

    manifest_shapes = []
    for shape in shapes:
        record = shape.manifest_record()
        stats = shape_stats[shape.name]
        record.update({
            "assigned_vertex_count": stats["assigned_vertex_count"],
            "assigned_within_20mm_count": stats["assigned_within_20mm_count"],
            "assigned_object_names": sorted(stats["assigned_object_names"]),
            "maximum_assigned_miss_m": stats["maximum_assigned_miss_m"],
        })
        manifest_shapes.append(record)
    geometry_oracle = [
        {key: record[key] for key in (
            "name", "shape_type", "points", "position", "size", "radius", "height",
            "rotation_degrees", "purpose",
        ) if key in record}
        for record in manifest_shapes
    ]
    geometry_sha256 = hashlib.sha256(json.dumps(
        geometry_oracle, sort_keys=True, separators=(",", ":"),
    ).encode("utf-8")).hexdigest()
    print(
        "ZENITH_COLLISION_V2_AUDIT", len(shapes), audited_vertex_count, maximum_miss,
        global_sample_max, global_bound,
        grounded_walk["conservative_continuous_clearance_m"],
        marker_capsule["conservative_continuous_clearance_m"], geometry_sha256,
    )
    return {
        "schema_version": 2,
        "ready": True,
        "authority": False,
        "collision_authority": False,
        "provenance": "future_runtime_proposal_fitted_to_frozen_original_close_art",
        "shape_count": len(shapes),
        "maximum_shape_count": COLLISION_MAXIMUM_SHAPES,
        "shape_type_counts": dict(sorted(type_counts.items())),
        "shape_geometry_sha256": geometry_sha256,
        "shapes": manifest_shapes,
        "structural_art_coverage": {
            "evaluated_scope": "primary_structural_solid_close_art_vertices",
            "included_object_count": len(included),
            "audited_vertex_count": audited_vertex_count,
            "maximum_allowed_miss_m": COLLISION_MAXIMUM_MISS_M,
            "maximum_observed_miss_m": maximum_miss,
            "vertices_over_20mm": failure_count,
            "per_object": object_stats,
        },
        "reverse_fit": {
            "distance_semantics": "conservative_distance_to_included_art_solid_not_unsigned_surface_only",
            "maximum_allowed_continuous_overreach_m": COLLISION_REVERSE_MAXIMUM_M,
            "target_continuous_overreach_m": COLLISION_REVERSE_TARGET_M,
            "target_met": global_bound <= COLLISION_REVERSE_TARGET_M,
            "maximum_bound_anchor_distance_to_included_art_solid_m": global_sample_max,
            "maximum_exposed_sample_distance_to_included_art_solid_m": global_exposed_sample_max,
            "conservative_continuous_upper_bound_m": global_bound,
            "maximum_sample_worst_shape": global_sample_worst[0] if global_sample_worst else "",
            "maximum_sample_worst_point": list(global_sample_worst[1]) if global_sample_worst and global_sample_worst[1] else [],
            "maximum_exposed_sample_worst_shape": global_exposed_sample_worst[0] if global_exposed_sample_worst else "",
            "maximum_exposed_sample_worst_point": list(global_exposed_sample_worst[1]) if global_exposed_sample_worst and global_exposed_sample_worst[1] else [],
            "worst_shape": global_bound_worst[0] if global_bound_worst else "",
            "worst_point": list(global_bound_worst[1]) if global_bound_worst and global_bound_worst[1] else [],
            "sampled_cell_count": sampled_cells,
            "fully_hidden_cell_count": fully_hidden_cells,
            "tested_cell_count": tested_cells,
            "vertex_distance_query_count": vertex_distance_queries,
            "exposed_sample_count": exposed_sample_count,
            "unique_distance_query_count": len(distance_cache),
            "sampling_method": "barycentric_subtriangle_cells_with_1_lipschitz_cell_diameter_bound",
            "exposure_method": "cell_hidden_only_when_all_three_original_and_1mm_outward_vertices_are_inside_one_same_convex_shape",
            "partially_hidden_cells": "audited_conservatively_as_potentially_exposed",
            "bound_anchor_semantics": "all_non_fully_hidden_cell_vertices_including_hidden_anchors_for_conservative_lipschitz_proof",
            "art_containment_method": "three_deterministic_nonaxis_ray_parity_majority_for_threatening_unsigned_distances",
            "per_shape": reverse_by_shape,
        },
        "empty_corner_probes": probe_records,
        "non_solid_exclusions": [
            {"name": obj.name, "reason": COLLISION_EXCLUSIONS[obj.name], "authority": False}
            for obj in excluded
        ],
        # Backward-compatible alias remains the exact five non-solid exclusions.
        "exclusions": [
            {"name": obj.name, "reason": COLLISION_EXCLUSIONS[obj.name], "authority": False}
            for obj in excluded
        ],
        "non_contact_decorative_trim": trim_records,
        "production_boarding_capsule": {
            **{
                key: list(value) if isinstance(value, tuple) else value
                for key, value in BOARDING_CAPSULE.items()
            },
            "art_clearance_method": "1001_axis_samples_mesh_bvh_1_lipschitz_lower_bound",
            "art_axis_sample_count": art_axis_samples,
            "art_axis_spacing_m": art_axis_spacing,
            "art_continuous_error_bound_m": art_axis_spacing * .5,
            "conservative_art_clearance_m": marker_art_clearance,
            "collision_marker_witness": marker_capsule,
        },
        "boarding_route": {
            **{
                key: list(value) if isinstance(value, tuple) else value
                for key, value in BOARDING_ROUTE.items()
            },
            "vertical_grounding_sweep": grounding_sweep,
            "grounded_walk_sweep": grounded_walk,
            "clear": grounding_sweep["clear"] and grounded_walk["clear"],
        },
        "boarding_area_witness": {
            **{
                key: list(value) if isinstance(value, tuple) else value
                for key, value in BOARDING_AREA_WITNESS.items()
            },
            "art_surface_center_clearance_m": area_art_clearance,
            "collision_center_clearance_m": area_collision_clearance,
        },
        "cannon_attachment": cannon_contact,
    }


def semantic_sha256() -> str:
    def quantized(value: float) -> str:
        # Applied bevel output is geometrically stable but Blender can vary a
        # few last-place floats and polygon iteration order between processes.
        # The source digest records meaningful micrometre-scale geometry rather
        # than those volatile implementation details.
        rounded = round(float(value), 6)
        return (0.0 if rounded == 0.0 else rounded).hex()

    def canonical_face(indices) -> list[int]:
        values = list(indices)
        rotations = [values[index:] + values[:index] for index in range(len(values))]
        return min(rotations)

    records = []
    for obj in sorted(bpy.data.objects, key=lambda candidate: candidate.name):
        record = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent else "",
            "matrix_local": [[quantized(value) for value in row] for row in obj.matrix_local],
            "properties": {
                key: obj[key] for key in sorted(obj.keys())
                if key != "_RNA_UI" and isinstance(obj[key], (bool, int, float, str))
            },
        }
        if obj.type == "MESH":
            record["vertices"] = [
                [quantized(value) for value in vertex.co] for vertex in obj.data.vertices
            ]
            record["polygons"] = sorted(
                canonical_face(polygon.vertices) for polygon in obj.data.polygons
            )
            record["uv0_method"] = "deterministic_dominant_axis_box_projection_v1"
            record["material"] = obj.data.materials[0].name
        records.append(record)
    document = {
        "schema_version": 1,
        "objects": records,
        "materials": MATERIAL_SPECS,
        "anchors": ANCHORS_GODOT,
        "scene": {
            "unit_system": bpy.context.scene.unit_settings.system,
            "unit_scale": float(bpy.context.scene.unit_settings.scale_length).hex(),
        },
    }
    encoded = json.dumps(document, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def can_preserve_blend(semantic_digest: str, generator_digest: str) -> bool:
    if not BLEND_PATH.is_file() or not MANIFEST_PATH.is_file():
        return False
    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    return (
        manifest.get("asset_id") == ASSET_ID
        and manifest.get("blender_version") == bpy.app.version_string
        and manifest.get("source_semantic_sha256") == semantic_digest
        and manifest.get("blend_sha256") == sha256(BLEND_PATH)
    )


def join_runtime_batches() -> tuple[dict, dict]:
    batches: dict[str, dict[str, list[str]]] = {}
    runtime_counts: dict[str, int] = {}
    for group_path in GROUP_PATHS:
        if group_path.endswith("SemanticAnchors"):
            batches[group_path] = {}
            runtime_counts[group_path] = 0
            continue
        protected = PROTECTED_BY_GROUP.get(group_path, set())
        names = {obj.name for obj in GROUP_OBJECTS[group_path]}
        missing = protected - names
        if missing:
            raise RuntimeError(f"Missing protected Zenith meshes in {group_path}: {sorted(missing)}")
        grouped: dict[str, list[bpy.types.Object]] = defaultdict(list)
        for obj in sorted(GROUP_OBJECTS[group_path], key=lambda candidate: candidate.name):
            if obj.name not in protected:
                grouped[obj.data.materials[0].name].append(obj)
        group_batches = {}
        for material_role in sorted(grouped):
            members = grouped[material_role]
            member_names = [obj.name for obj in members]
            bpy.ops.object.select_all(action="DESELECT")
            for obj in members:
                obj.select_set(True)
            batch = members[0]
            bpy.context.view_layer.objects.active = batch
            if len(members) > 1:
                result = bpy.ops.object.join()
                if "FINISHED" not in result:
                    raise RuntimeError(f"Unable to join {group_path}/{material_role}")
            safe_group = group_path.replace("/", "")
            batch.name = f"{safe_group}StaticBatch_{material_role}"
            batch.data.name = f"{batch.name}Mesh"
            batch.data.materials.clear()
            batch.data.materials.append(MATERIALS[material_role])
            for polygon in batch.data.polygons:
                polygon.material_index = 0
            group_batches[batch.name] = member_names
        batches[group_path] = group_batches
        runtime_counts[group_path] = len(grouped) + len(protected)
    return batches, runtime_counts


def parse_glb(path: Path) -> tuple[dict, int, bytearray]:
    payload = bytearray(path.read_bytes())
    if payload[:4] != b"glTF":
        raise RuntimeError("Zenith export is not GLB 2.0")
    document = None
    binary_offset = -1
    cursor = 12
    while cursor + 8 <= len(payload):
        length, chunk_type = struct.unpack_from("<II", payload, cursor)
        cursor += 8
        if chunk_type == 0x4E4F534A:
            document = json.loads(bytes(payload[cursor:cursor + length]).rstrip(b" \0").decode("utf-8"))
        elif chunk_type == 0x004E4942:
            binary_offset = cursor
        cursor += length
    if document is None or binary_offset < 0:
        raise RuntimeError("Zenith GLB JSON/BIN chunk is missing")
    return document, binary_offset, payload


def canonicalize_glb_normals(path: Path) -> int:
    document, binary_offset, payload = parse_glb(path)
    normal_accessors = {
        primitive["attributes"]["NORMAL"]
        for mesh in document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
        if "NORMAL" in primitive.get("attributes", {})
    }
    replacements = 0
    for accessor_index in normal_accessors:
        accessor = document["accessors"][accessor_index]
        view = document["bufferViews"][accessor["bufferView"]]
        if accessor.get("componentType") != 5126 or accessor.get("type") != "VEC3":
            raise RuntimeError("Zenith NORMAL accessor must be float VEC3")
        stride = int(view.get("byteStride", 12))
        start = binary_offset + int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
        for index in range(int(accessor["count"])):
            offset = start + index * stride
            source = struct.unpack_from("<fff", payload, offset)
            quantized = [round(float(value), 5) for value in source]
            length = math.sqrt(math.fsum(value * value for value in quantized))
            if not math.isfinite(length) or length <= 1e-8:
                raise RuntimeError("Zenith GLB contains a non-finite/zero normal")
            normalized = tuple(0.0 if abs(value) <= 1e-8 else value / length for value in quantized)
            if struct.pack("<fff", *source) != struct.pack("<fff", *normalized):
                struct.pack_into("<fff", payload, offset, *normalized)
                replacements += 1
    path.write_bytes(payload)
    return replacements


def canonicalize_glb_triangle_order(path: Path) -> int:
    """Sort indexed triangles without changing their winding or geometry.

    Blender 4.0's glTF exporter can emit the same indexed triangles in a
    different order between background processes after a multi-object join.
    Vertex attributes and each triangle's winding remain identical. Sorting the
    triangle tuples makes the checked-in GLB byte-repeatable and does not alter
    topology, draw count, normals, UVs, or rasterized output.
    """
    document, binary_offset, payload = parse_glb(path)
    index_accessors = sorted({
        int(primitive["indices"])
        for mesh in document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
        if "indices" in primitive
    })
    formats = {5121: "B", 5123: "H", 5125: "I"}
    reordered_triangles = 0
    for accessor_index in index_accessors:
        accessor = document["accessors"][accessor_index]
        component_type = int(accessor.get("componentType", 0))
        if accessor.get("type") != "SCALAR" or component_type not in formats:
            raise RuntimeError("Zenith index accessor has an unsupported format")
        count = int(accessor["count"])
        if count % 3 != 0:
            raise RuntimeError("Zenith index accessor is not a triangle list")
        view = document["bufferViews"][int(accessor["bufferView"])]
        value_format = formats[component_type]
        value_size = struct.calcsize("<" + value_format)
        stride = int(view.get("byteStride", value_size))
        if stride != value_size:
            raise RuntimeError("Zenith index accessor unexpectedly uses a stride")
        start = (
            binary_offset + int(view.get("byteOffset", 0))
            + int(accessor.get("byteOffset", 0))
        )
        values = [
            struct.unpack_from("<" + value_format, payload, start + index * value_size)[0]
            for index in range(count)
        ]
        triangles = [tuple(values[index:index + 3]) for index in range(0, count, 3)]
        canonical = sorted(triangles)
        reordered_triangles += sum(
            1 for original, ordered in zip(triangles, canonical) if original != ordered
        )
        flattened = [value for triangle in canonical for value in triangle]
        for index, value in enumerate(flattened):
            struct.pack_into("<" + value_format, payload, start + index * value_size, value)
    path.write_bytes(payload)
    return reordered_triangles


def glb_metrics(path: Path) -> dict:
    document, binary_offset, payload = parse_glb(path)
    triangles = vertices = surfaces = 0
    normal_count = uv_count = 0
    min_normal_length = math.inf
    max_normal_length = 0.0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            surfaces += 1
            position_accessor = document["accessors"][primitive["attributes"]["POSITION"]]
            vertices += int(position_accessor["count"])
            if "indices" in primitive:
                triangles += int(document["accessors"][primitive["indices"]]["count"]) // 3
            else:
                triangles += int(position_accessor["count"]) // 3
            if "TEXCOORD_0" not in primitive["attributes"] or "NORMAL" not in primitive["attributes"]:
                raise RuntimeError("Every Zenith primitive must carry UV0 and normals")
            uv_accessor = document["accessors"][primitive["attributes"]["TEXCOORD_0"]]
            normal_accessor = document["accessors"][primitive["attributes"]["NORMAL"]]
            uv_count += int(uv_accessor["count"])
            normal_count += int(normal_accessor["count"])
            view = document["bufferViews"][normal_accessor["bufferView"]]
            stride = int(view.get("byteStride", 12))
            start = binary_offset + int(view.get("byteOffset", 0)) + int(normal_accessor.get("byteOffset", 0))
            for index in range(int(normal_accessor["count"])):
                values = struct.unpack_from("<fff", payload, start + index * stride)
                length = math.sqrt(math.fsum(value * value for value in values))
                min_normal_length = min(min_normal_length, length)
                max_normal_length = max(max_normal_length, length)
    nodes = document.get("nodes", [])
    mesh_nodes = sum(1 for node in nodes if "mesh" in node)
    node_names = [str(node.get("name", "")) for node in nodes]
    required_names = [ROOT_NAME, "SourceCore", "ModernSystems", "LOD0", "LOD1",
                      "CanopyPivot", "SemanticAnchors", *ANCHORS_GODOT.keys()]
    missing = [name for name in required_names if name not in node_names]
    if missing:
        raise RuntimeError(f"Zenith GLB hierarchy is missing nodes: {missing}")
    return {
        "vertex_count": vertices,
        "triangle_count": triangles,
        "mesh_instance_count": mesh_nodes,
        "surface_count": surfaces,
        "uv0_vertex_count": uv_count,
        "normal_count": normal_count,
        "minimum_normal_length": min_normal_length,
        "maximum_normal_length": max_normal_length,
    }


def setup_scene() -> dict:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                       bpy.data.lights, bpy.data.curves):
        for datablock in list(datablocks):
            datablocks.remove(datablock)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene["asset_id"] = ASSET_ID
    bpy.context.scene["authorship"] = "original_script_assisted_blender"
    bpy.context.scene["historical_geometry_authenticated"] = False
    bpy.context.scene["evidence_scope"] = EVIDENCE_SCOPE
    bpy.context.scene["source_redistributed"] = False
    for name, spec in MATERIAL_SPECS.items():
        make_material(name, spec)
    build_hierarchy()
    build_source_core_lod0()
    build_source_core_lod1()
    build_modern_lod0()
    build_modern_lod1()
    build_canopy_and_anchors()
    return apply_uv0()


def main() -> None:
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    uv_contract = setup_scene()
    metrics = group_metrics()
    bounds = whole_bounds()
    collision_proposal = collision_proposal_audit()
    pod_like_form_contract = {
        "historical_function_unresolved": True,
        "count_placement_function_unauthenticated": True,
        "aggregate_evidence_survives_runtime_batching": True,
        "source_object_records": [
            {
                "name": name,
                "lod": lod,
                "historical_function_unresolved": bool(bpy.data.objects[name]["historical_function_unresolved"]),
                "count_placement_function_unauthenticated": bool(bpy.data.objects[name]["count_placement_function_unauthenticated"]),
                "evidence_claim": bpy.data.objects[name]["evidence_claim"],
            }
            for name, lod in (
                ("PortObservedPodLikeForm", 0),
                ("StarboardObservedPodLikeForm", 0),
                ("LOD1PortPodForm", 1),
                ("LOD1StarboardPodForm", 1),
            )
        ],
    }
    canopy_contract = {
        "glass_source_triangle_count": sum(
            max(1, len(polygon.vertices) - 2)
            for polygon in bpy.data.objects["CanopyGlassShell"].data.polygons
        ),
        "superseded_glass_triangle_count": 9310,
        "frame_object_names": [
            "CanopyPortSill", "CanopyStarboardSill", "CanopyCentreFrame",
            "CanopyForwardHoop", "CanopyAftHoop",
        ],
        "readable_coaming": True,
    }
    for key in ("minimum", "maximum"):
        if (Vector(bounds[key]) - Vector(EXPECTED_BOUNDS[key])).length > 0.002:
            raise RuntimeError(
                f"Zenith visual bounds drifted: {bounds} != {EXPECTED_BOUNDS}"
            )
    close_triangles = sum(metrics[path]["triangle_count"] for path in (
        "SourceCore/LOD0", "ModernSystems/LOD0", "ModernSystems/CanopyPivot",
    ))
    far_triangles = sum(metrics[path]["triangle_count"] for path in (
        "SourceCore/LOD1", "ModernSystems/LOD1",
    ))
    if not CLOSE_TRIANGLE_RANGE[0] <= close_triangles <= CLOSE_TRIANGLE_RANGE[1]:
        raise RuntimeError(f"Zenith close art outside 45-75k band: {close_triangles}")
    if not FAR_TRIANGLE_RANGE[0] <= far_triangles <= FAR_TRIANGLE_RANGE[1]:
        raise RuntimeError(f"Zenith far art outside 5-10k band: {far_triangles}")
    generator_digest = sha256(GENERATOR_PATH)
    semantic_digest = semantic_sha256()
    bpy.context.preferences.filepaths.save_version = 0
    if can_preserve_blend(semantic_digest, generator_digest):
        print("ZENITH_BLEND_BYTES_PRESERVED", semantic_digest, sha256(BLEND_PATH))
    else:
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    batches, runtime_counts = join_runtime_batches()
    runtime_mesh_count = sum(runtime_counts.values())
    if runtime_mesh_count > RUNTIME_MESH_BUDGET:
        raise RuntimeError(f"Zenith runtime mesh budget exceeded: {runtime_mesh_count}")
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH), export_format="GLB", export_apply=True,
        export_yup=False, export_materials="EXPORT", export_cameras=False,
        export_lights=False, use_visible=True,
    )
    normal_replacements = canonicalize_glb_normals(GLB_PATH)
    canonicalize_glb_triangle_order(GLB_PATH)
    runtime = glb_metrics(GLB_PATH)
    if runtime["mesh_instance_count"] != runtime_mesh_count:
        raise RuntimeError(
            f"Zenith GLB mesh roster drift: {runtime['mesh_instance_count']} != {runtime_mesh_count}"
        )
    if runtime["surface_count"] > RUNTIME_SURFACE_BUDGET:
        raise RuntimeError("Zenith runtime surface budget exceeded")
    if runtime["triangle_count"] != close_triangles + far_triangles:
        raise RuntimeError("Zenith GLB changed authored triangle count")
    if not (0.9999 <= runtime["minimum_normal_length"] <= 1.0001
            and 0.9999 <= runtime["maximum_normal_length"] <= 1.0001):
        raise RuntimeError("Zenith GLB normals are not unit length")

    manifest = {
        "schema_version": 1,
        "asset_id": ASSET_ID,
        "authorship": "original_script_assisted_blender",
        "historical_geometry_authenticated": False,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_source": {
            "ledger_id": "B7", "rendition_sha256": EVIDENCE_SHA256,
            "included_frames_zero_based": [373, 467],
            "excluded_from_frame_zero_based": 468,
            "source_pixels_or_geometry_redistributed": False,
        },
        "interpretation_boundary": {
            "SourceCore": [
                "pale_off_white_exterior", "width_dominant_delta_arrow_planform",
                "tall_faceted_central_wedge_spine", "long_strakes",
                "stepped_subdivisions", "cautiously_indexed_fins_and_pod_like_forms",
            ],
            "ModernSystems": [
                "canopy_and_cockpit", "pbr_functional_panels", "engines",
                "cannons", "navigation_lights", "landing_gear",
                "docking_and_damage_alignment_anchors",
            ],
            "modern_systems_removable": True,
            "source_core_complete_without_modern_systems": True,
        },
        "blender_version": bpy.app.version_string,
        "generator": str(GENERATOR_PATH.relative_to(ROOT)),
        "source_path": str(BLEND_PATH.relative_to(ROOT)),
        "runtime_path": str(GLB_PATH.relative_to(ROOT)),
        "coordinate_contract": {
            "units": "metres", "runtime_up": "+Y", "runtime_forward": "-Z",
            "mount": "identity beneath ZenithVisual",
            "dimensions_are_modern_ergonomic_normalization": True,
        },
        "bounds_godot_metres": {
            "minimum": bounds["minimum"],
            "maximum": bounds["maximum"],
        },
        "hierarchy_contract": {
            "root": ROOT_NAME,
            "root_direct_children_exact": ["SourceCore", "ModernSystems"],
            "SourceCore_direct_children_exact": ["LOD0", "LOD1"],
            "ModernSystems_direct_children_exact": ["LOD0", "LOD1", "CanopyPivot", "SemanticAnchors"],
            "group_paths": list(GROUP_PATHS),
        },
        "semantic_anchors_godot_metres": {
            name: list(position) for name, position in ANCHORS_GODOT.items()
        },
        "collision_proposal": collision_proposal,
        "collision_authority": False,
        "pod_like_form_contract": pod_like_form_contract,
        "canopy_contract": canopy_contract,
        "removed_surface_pattern_contract": {
            "removed_lod0_source_surface_cell_count": 28,
            "removed_lod1_silhouette_cell_count": 24,
            "replacement": "existing_stepped_bands_and_faceted_subdivisions",
            "forbidden_name_fragments": ["SourceSurfaceCell", "SilhouetteCell"],
        },
        "material_roles": MATERIAL_SPECS,
        "material_role_count": len(MATERIAL_SPECS),
        "registered_runtime_hull_maps": {
            "albedo": "res://assets/materials/torrent-hull-albedo-v1.png",
            "normal": "res://assets/materials/torrent-hull-normal-v1.png",
            "roughness": "res://assets/materials/torrent-hull-roughness-v1.png",
            "texture_coordinate": "UV0/TEXCOORD_0", "triplanar": False,
        },
        "art_quality_contract": {
            "close_triangle_count": close_triangles,
            "far_triangle_count": far_triangles,
            "total_triangle_count": close_triangles + far_triangles,
            "close_triangle_range": list(CLOSE_TRIANGLE_RANGE),
            "far_triangle_range": list(FAR_TRIANGLE_RANGE),
            "whole_ship_lod_switch": True,
            "per_surface_auto_lod": False,
            "far_lod_unbounded": True,
        },
        "source_mesh_counts_by_group": dict(SOURCE_COUNTS),
        "source_group_metrics": metrics,
        "runtime_static_batching": {
            "strategy": "per_semantic_group_per_material_static_join_with_protected_plumes",
            "source_preserved_in_blend": True,
            "runtime_mesh_counts_by_group": runtime_counts,
            "runtime_mesh_instance_count": runtime_mesh_count,
            "runtime_mesh_budget": RUNTIME_MESH_BUDGET,
            "runtime_surface_budget": RUNTIME_SURFACE_BUDGET,
            "batches": batches,
            "protected_meshes_by_group": {
                key: sorted(value) for key, value in PROTECTED_BY_GROUP.items()
            },
        },
        "runtime_metrics": runtime,
        "uv0_contract": uv_contract,
        "normal_contract": {
            "attribute": "NORMAL", "unit_length": True,
            "minimum_length": runtime["minimum_normal_length"],
            "maximum_length": runtime["maximum_normal_length"],
            "canonicalized_value_count": normal_replacements,
        },
        "triangle_order_contract": {
            "method": "lexicographic_indexed_triangle_tuple_sort_v1",
            "winding_preserved": True,
            "canonicalized_triangle_count": runtime["triangle_count"],
        },
        "forbidden_imported_authority": [
            "scripts", "collision", "physics_bodies", "areas", "cameras",
            "animation", "audio", "gameplay_state",
        ],
        "source_semantic_sha256": semantic_digest,
        "generator_sha256": generator_digest,
        "blend_sha256": sha256(BLEND_PATH),
        "glb_sha256": sha256(GLB_PATH),
    }
    MANIFEST_PATH.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8",
    )
    print(
        "ZENITH_AUTHORED_V1_OK",
        close_triangles, far_triangles, runtime_mesh_count, runtime["surface_count"],
        manifest["blend_sha256"], manifest["glb_sha256"],
    )


if __name__ == "__main__":
    main()
