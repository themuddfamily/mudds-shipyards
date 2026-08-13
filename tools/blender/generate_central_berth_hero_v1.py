"""Build the editable and runtime central-berth platform shell.

Run from the repository root with the pinned DCC tool:

  blender --background --factory-startup --python \
    tools/blender/generate_central_berth_hero_v1.py

The .blend retains every authored component.  The GLB contains only compact,
visual-only batches grouped by semantic root and material.  Landing, walking,
collision, docking, utilities and ship authority remain in Godot.
"""

from __future__ import annotations

import bpy
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
from mathutils import Vector


ROOT = Path.cwd()
GENERATOR_PATH = ROOT / "tools/blender/generate_central_berth_hero_v1.py"
BLEND_PATH = ROOT / "art_source/station/central_berth_hero_v1.blend"
GLB_PATH = ROOT / "assets/models/station/central_berth_hero_v1.glb"
MANIFEST_PATH = ROOT / "assets/models/station/central_berth_hero_v1_asset_manifest.json"

ASSET_ID = "mudds.station.central_berth_hero.v1"
SEMANTIC_ROOTS = (
    "deck_panels",
    "edge_fascia",
    "primary_structure",
    "secondary_structure",
    "service_channels",
)
MATERIAL_SPECS = {
    "DeckComposite": {
        "color": (0.105, 0.145, 0.165, 1.0), "metallic": 0.52, "roughness": 0.38,
    },
    "EdgeIvory": {
        "color": (0.70, 0.72, 0.66, 1.0), "metallic": 0.18, "roughness": 0.34,
    },
    "StructuralAlloy": {
        "color": (0.13, 0.22, 0.27, 1.0), "metallic": 0.72, "roughness": 0.29,
    },
    "ServiceGraphite": {
        "color": (0.018, 0.032, 0.038, 1.0), "metallic": 0.42, "roughness": 0.48,
    },
    "GuidanceCyan": {
        "color": (0.015, 0.36, 0.42, 1.0), "metallic": 0.16, "roughness": 0.25,
        "emission": (0.015, 0.73, 0.84, 1.0), "emission_strength": 2.1,
    },
}

# Exact established presentation envelope in LandingPad/world-aligned Godot
# coordinates.  The authored shell never rises above the established walkable
# surface and therefore cannot visually obstruct clamps or utility approaches.
EXPECTED_BOUNDS_GODOT = {
    "minimum": [-12.75, -2.58, -27.75],
    "maximum": [12.75, 0.095, 7.75],
}

MATERIALS: dict[str, bpy.types.Material] = {}
SOURCE_PARTS: list[bpy.types.Object] = []
SOURCE_COUNTS_BY_ROOT: Counter[str] = Counter()
SOURCE_COUNTS_BY_MATERIAL: Counter[str] = Counter()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def godot_to_blender(point: tuple[float, float, float] | Vector) -> Vector:
    """Godot +Y up/-Z forward -> Blender +Z up/-Y forward."""
    return Vector((point[0], -point[2], point[1]))


def godot_size_to_blender(size: tuple[float, float, float]) -> tuple[float, float, float]:
    return (size[0], size[2], size[1])


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
    material["central_berth_material_role"] = name
    MATERIALS[name] = material
    return material


def apply_modifiers(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def finish_source_part(
    obj: bpy.types.Object,
    name: str,
    semantic_root: str,
    material_role: str,
    source_parent: bpy.types.Object,
    bevel: float = 0.0,
) -> bpy.types.Object:
    obj.name = name
    obj.parent = source_parent
    obj.data.name = f"{name}Mesh"
    obj.data.materials.append(MATERIALS[material_role])
    if bevel > 0.0:
        modifier = obj.modifiers.new("AuthoredEdgeTreatment", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        modifier.affect = "EDGES"
        apply_modifiers(obj)
    obj["semantic_root"] = semantic_root
    obj["material_role"] = material_role
    obj["presentation_only"] = True
    obj["gameplay_authority"] = False
    obj["authored_uv0"] = True
    SOURCE_PARTS.append(obj)
    SOURCE_COUNTS_BY_ROOT[semantic_root] += 1
    SOURCE_COUNTS_BY_MATERIAL[material_role] += 1
    return obj


def box_part(
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    semantic_root: str,
    material_role: str,
    parent: bpy.types.Object,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=godot_to_blender(center))
    obj = bpy.context.object
    obj.dimensions = godot_size_to_blender(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_source_part(obj, name, semantic_root, material_role, parent, bevel)


def beam_part(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width: float,
    semantic_root: str,
    material_role: str,
    parent: bpy.types.Object,
    bevel: float = 0.0,
) -> bpy.types.Object:
    start_bl = godot_to_blender(start)
    end_bl = godot_to_blender(end)
    axis = (end_bl - start_bl).normalized()
    reference = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.92 else Vector((0.0, 1.0, 0.0))
    side = axis.cross(reference).normalized() * width * 0.5
    up = side.cross(axis).normalized() * width * 0.5
    vertices = [
        start_bl - side - up, start_bl + side - up,
        start_bl + side + up, start_bl - side + up,
        end_bl - side - up, end_bl + side - up,
        end_bl + side + up, end_bl - side + up,
    ]
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5),
        (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    face_uvs = ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))
    for polygon in mesh.polygons:
        for loop_index, uv in zip(polygon.loop_indices, face_uvs):
            uv_layer.data[loop_index].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_source_part(obj, name, semantic_root, material_role, parent, bevel)


def build_authored_source(source_collection: bpy.types.Collection) -> bpy.types.Object:
    source_root = bpy.data.objects.new("CentralBerthAuthoredComponents", None)
    source_root["asset_id"] = ASSET_ID
    source_root["editable_component_source"] = True
    source_collection.objects.link(source_root)
    semantic_parents: dict[str, bpy.types.Object] = {}
    for semantic_root in SEMANTIC_ROOTS:
        parent = bpy.data.objects.new(f"source_{semantic_root}", None)
        parent.parent = source_root
        parent["semantic_root"] = semantic_root
        source_collection.objects.link(parent)
        semantic_parents[semantic_root] = parent

    # Fifteen individually authored deck cassettes leave narrow, readable seams
    # while retaining an exact flush top.  Side strips close the walking skin to
    # the established shell without moving the outer fascia envelope.
    x_bands = [(-8.0, 7.5), (0.0, 7.8), (8.0, 7.5)]
    z_bands = [(-24.20, 6.70), (-17.25, 6.70), (-10.0, 7.30), (-2.75, 6.70), (4.20, 6.70)]
    for x_index, (x, width) in enumerate(x_bands):
        for z_index, (z, depth) in enumerate(z_bands):
            box_part(
                f"DeckCassette_{x_index + 1}_{z_index + 1}",
                (x, 0.045, z), (width, 0.10, depth),
                "deck_panels", "DeckComposite", semantic_parents["deck_panels"], 0.025,
            )
    for side, x in (("Port", -12.325), ("Starboard", 12.325)):
        box_part(
            f"{side}DeckMargin", (x, 0.045, -10.0), (0.35, 0.10, 34.5),
            "deck_panels", "DeckComposite", semantic_parents["deck_panels"], 0.018,
        )
    for end, z in (("Forward", -27.325), ("Aft", 7.325)):
        box_part(
            f"{end}DeckMargin", (0.0, 0.045, z), (24.3, 0.10, 0.35),
            "deck_panels", "DeckComposite", semantic_parents["deck_panels"], 0.018,
        )

    # Four exact boundary rails carry the original platform silhouette.  Lower
    # segmented skins add readable depth from space without growing the bounds.
    edge_parent = semantic_parents["edge_fascia"]
    for side, x in (("Port", -12.50), ("Starboard", 12.50)):
        box_part(
            f"{side}UpperFascia", (x, -0.51, -10.0), (0.50, 1.21, 35.5),
            "edge_fascia", "EdgeIvory", edge_parent, 0.0,
        )
        for segment, z in enumerate((-23.35, -16.65, -10.0, -3.35, 3.35), 1):
            box_part(
                f"{side}LowerFasciaPanel_{segment}", (x, -1.17, z), (0.46, 0.22, 6.30),
                "edge_fascia", "ServiceGraphite", edge_parent, 0.035,
            )
    for end, z in (("Forward", -27.50), ("Aft", 7.50)):
        box_part(
            f"{end}UpperFascia", (0.0, -0.51, z), (24.5, 1.21, 0.50),
            "edge_fascia", "EdgeIvory", edge_parent, 0.0,
        )
        for segment, x in enumerate((-9.6, -4.8, 0.0, 4.8, 9.6), 1):
            box_part(
                f"{end}LowerFasciaPanel_{segment}", (x, -1.17, z), (4.35, 0.22, 0.46),
                "edge_fascia", "ServiceGraphite", edge_parent, 0.035,
            )

    # Primary I-girders: separated webs/flanges retain a strong station-scale
    # silhouette, but their runtime copies batch into one StructuralAlloy draw.
    primary = semantic_parents["primary_structure"]
    for index, x in enumerate((-7.25, 7.25), 1):
        box_part(
            f"LongitudinalWeb_{index}", (x, -1.78, -10.0), (0.22, 1.10, 31.8),
            "primary_structure", "StructuralAlloy", primary, 0.025,
        )
        for level, y in (("Upper", -1.25), ("Lower", -2.31)):
            box_part(
                f"Longitudinal{level}Flange_{index}", (x, y, -10.0), (0.82, 0.14, 31.8),
                "primary_structure", "StructuralAlloy", primary, 0.025,
            )
    for index, z in enumerate((-25.3, -17.65, -10.0, -2.35, 5.3), 1):
        box_part(
            f"CrossWeb_{index}", (0.0, -1.78, z), (23.9, 0.92, 0.20),
            "primary_structure", "StructuralAlloy", primary, 0.022,
        )
        for level, y in (("Upper", -1.34), ("Lower", -2.22)):
            box_part(
                f"Cross{level}Flange_{index}", (0.0, y, z), (23.9, 0.13, 0.64),
                "primary_structure", "StructuralAlloy", primary, 0.022,
            )
    box_part(
        "LowerDatumSpine", (0.0, -2.55, -10.0), (0.42, 0.06, 29.8),
        "primary_structure", "StructuralAlloy", primary, 0.0,
    )

    # Secondary X-bracing lives entirely below and inside the original deck.
    secondary = semantic_parents["secondary_structure"]
    brace_index = 0
    for side_x in (-11.78, 11.78):
        for z_center in (-23.3, -16.65, -10.0, -3.35, 3.3):
            brace_index += 1
            beam_part(
                f"OuterBraceRise_{brace_index}",
                (side_x, -1.05, z_center - 2.75), (side_x, -2.48, z_center + 2.75), 0.19,
                "secondary_structure", "StructuralAlloy", secondary, 0.018,
            )
            brace_index += 1
            beam_part(
                f"OuterBraceFall_{brace_index}",
                (side_x, -2.48, z_center - 2.75), (side_x, -1.05, z_center + 2.75), 0.19,
                "secondary_structure", "StructuralAlloy", secondary, 0.018,
            )
    for z in (-21.5, -13.8, -6.2, 1.5):
        beam_part(
            f"LowerPlanBracePort_{abs(int(z * 10))}", (-11.6, -2.48, z - 2.5), (11.6, -2.48, z + 2.5), 0.17,
            "secondary_structure", "StructuralAlloy", secondary, 0.015,
        )
        beam_part(
            f"LowerPlanBraceStarboard_{abs(int(z * 10))}", (11.6, -2.48, z - 2.5), (-11.6, -2.48, z + 2.5), 0.17,
            "secondary_structure", "StructuralAlloy", secondary, 0.015,
        )

    # Flush channel hardware enriches the operational read while preserving the
    # established top plane and all approach/boarding routes.  Cyan strips are
    # deliberately recessed 5 mm below the 0.095 m deck surface.
    services = semantic_parents["service_channels"]
    for side, x in (("Port", -8.08), ("Starboard", 8.08)):
        box_part(
            f"{side}ServiceChannel", (x, -0.015, -10.0), (0.48, 0.19, 25.7),
            "service_channels", "ServiceGraphite", services, 0.025,
        )
        box_part(
            f"{side}ServiceTracer", (x, 0.075, -10.0), (0.055, 0.03, 24.8),
            "service_channels", "GuidanceCyan", services, 0.010,
        )
        for index, z in enumerate((-20.8, -10.0, 0.8), 1):
            box_part(
                f"{side}ChannelAccess_{index}", (x, 0.078, z), (0.72, 0.026, 1.25),
                "service_channels", "EdgeIvory", services, 0.022,
            )
    box_part(
        "CentreGuidanceRecess", (0.0, -0.010, -10.0), (0.34, 0.20, 31.2),
        "service_channels", "ServiceGraphite", services, 0.022,
    )
    for index, z in enumerate((-24.0, -19.3, -14.6, -10.0, -5.4, -0.7, 4.0), 1):
        box_part(
            f"CentreGuidanceSegment_{index}", (0.0, 0.075, z), (0.10, 0.03, 3.45),
            "service_channels", "GuidanceCyan", services, 0.012,
        )
    return source_root


def clone_runtime_batches(
    runtime_collection: bpy.types.Collection,
) -> tuple[bpy.types.Object, dict[str, int], dict[str, list[str]]]:
    runtime_root = bpy.data.objects.new("CentralBerthHeroArt", None)
    runtime_root["asset_id"] = ASSET_ID
    runtime_root["presentation_only"] = True
    runtime_root["gameplay_authority"] = False
    runtime_root["collision_authority"] = False
    runtime_root["walking_surface_authority"] = False
    runtime_root["coordinate_contract"] = "Godot +Y up, -Z forward, metres; LandingPad identity"
    runtime_collection.objects.link(runtime_root)

    root_objects: dict[str, bpy.types.Object] = {}
    for semantic_root in SEMANTIC_ROOTS:
        root = bpy.data.objects.new(semantic_root, None)
        root.parent = runtime_root
        root["semantic_root"] = semantic_root
        root["presentation_only"] = True
        root["gameplay_authority"] = False
        runtime_collection.objects.link(root)
        root_objects[semantic_root] = root

    grouped: dict[tuple[str, str], list[bpy.types.Object]] = defaultdict(list)
    for source in SOURCE_PARTS:
        semantic_root = source["semantic_root"]
        material_role = source["material_role"]
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        duplicate.animation_data_clear()
        duplicate.parent = root_objects[semantic_root]
        duplicate.matrix_world = source.matrix_world.copy()
        duplicate.name = f"runtime_{source.name}"
        duplicate["source_component"] = source.name
        runtime_collection.objects.link(duplicate)
        grouped[(semantic_root, material_role)].append(duplicate)

    mesh_counts: Counter[str] = Counter()
    batches_by_root: dict[str, list[str]] = defaultdict(list)
    for (semantic_root, material_role), objects in sorted(grouped.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        batch = bpy.context.object
        batch.name = f"{semantic_root}__{material_role}"
        batch.data.name = f"{batch.name}Mesh"
        batch.parent = root_objects[semantic_root]
        batch["semantic_root"] = semantic_root
        batch["material_role"] = material_role
        batch["source_component_count"] = len(objects)
        batch["authored_uv0"] = True
        batch["presentation_only"] = True
        batch["gameplay_authority"] = False
        mesh_counts[semantic_root] += 1
        batches_by_root[semantic_root].append(batch.name)
    return runtime_root, dict(mesh_counts), dict(batches_by_root)


def mesh_counts(objects: list[bpy.types.Object]) -> tuple[int, int]:
    vertices = 0
    triangles = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        vertices += len(mesh.vertices)
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return vertices, triangles


def uv_report(objects: list[bpy.types.Object]) -> dict:
    uv_mesh_count = 0
    uv_loop_count = 0
    minimum_span = float("inf")
    for obj in objects:
        if obj.type != "MESH":
            continue
        uv_layer = obj.data.uv_layers.active
        if uv_layer is None or len(uv_layer.data) == 0:
            continue
        uv_mesh_count += 1
        uv_loop_count += len(uv_layer.data)
        u_values = [loop.uv.x for loop in uv_layer.data]
        v_values = [loop.uv.y for loop in uv_layer.data]
        minimum_span = min(minimum_span, max(u_values) - min(u_values), max(v_values) - min(v_values))
    return {
        "method": "authored_component_uv0_preserved_through_static_join",
        "runtime_meshes_with_uv0": uv_mesh_count,
        "runtime_uv_loop_count": uv_loop_count,
        "minimum_uv_axis_span": round(minimum_span if minimum_span != float("inf") else 0.0, 6),
        "texture_coordinate": "UV0/TEXCOORD_0",
        "triplanar": False,
    }


def runtime_bounds_godot(objects: list[bpy.types.Object]) -> dict[str, list[float]]:
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    minimum_bl = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum_bl = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    # Convert all eight aggregate corners because the Y/Z axis includes a sign flip.
    godot_points = []
    for x in (minimum_bl.x, maximum_bl.x):
        for y in (minimum_bl.y, maximum_bl.y):
            for z in (minimum_bl.z, maximum_bl.z):
                godot_points.append(Vector((x, z, -y)))
    minimum = Vector((min(p.x for p in godot_points), min(p.y for p in godot_points), min(p.z for p in godot_points)))
    maximum = Vector((max(p.x for p in godot_points), max(p.y for p in godot_points), max(p.z for p in godot_points)))
    return {
        "minimum": [round(v, 6) for v in minimum],
        "maximum": [round(v, 6) for v in maximum],
        "size_metres": [round(v, 6) for v in maximum - minimum],
    }


def main() -> None:
    if bpy.app.version_string != "4.0.2":
        raise RuntimeError(f"Pinned Blender 4.0.2 required, found {bpy.app.version_string}")
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection != bpy.context.scene.collection:
            bpy.data.collections.remove(collection)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            datablocks.remove(block)

    scene = bpy.context.scene
    scene.name = "CentralBerthHeroV1Source"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    for name, spec in MATERIAL_SPECS.items():
        make_material(name, spec)

    source_collection = bpy.data.collections.new("AUTHORED_SOURCE_COMPONENTS")
    runtime_collection = bpy.data.collections.new("RUNTIME_EXPORT_BATCHES")
    scene.collection.children.link(source_collection)
    scene.collection.children.link(runtime_collection)
    build_authored_source(source_collection)
    runtime_root, runtime_mesh_counts, batches_by_root = clone_runtime_batches(runtime_collection)

    runtime_meshes = [obj for obj in runtime_collection.all_objects if obj.type == "MESH"]
    vertex_count, triangle_count = mesh_counts(runtime_meshes)
    bounds = runtime_bounds_godot(runtime_meshes)
    if bounds["minimum"] != EXPECTED_BOUNDS_GODOT["minimum"] or bounds["maximum"] != EXPECTED_BOUNDS_GODOT["maximum"]:
        for obj in runtime_meshes:
            print("BOUND_DEBUG", obj.name, runtime_bounds_godot([obj]))
        raise RuntimeError(f"Runtime bounds drifted: {bounds}")
    uv_contract = uv_report(runtime_meshes)
    if uv_contract["runtime_meshes_with_uv0"] != len(runtime_meshes):
        raise RuntimeError(f"A runtime batch lacks authored UV0: {uv_contract}")

    # Save the editable file with source and runtime collections intact, then
    # export only the compact runtime hierarchy.
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    runtime_root.select_set(True)
    for obj in runtime_collection.all_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = runtime_root
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_animations=False,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )

    manifest = {
        "schema_version": 1,
        "asset_id": ASSET_ID,
        "authorship": "original_script_assisted_blender",
        "historical_geometry_authenticated": False,
        "runtime_generation": False,
        "presentation_only": True,
        "gameplay_authority": False,
        "collision_authority": False,
        "walking_surface_authority": False,
        "blender_version": bpy.app.version_string,
        "generator": "tools/blender/generate_central_berth_hero_v1.py",
        "source_path": "art_source/station/central_berth_hero_v1.blend",
        "runtime_path": "assets/models/station/central_berth_hero_v1.glb",
        "coordinate_contract": {
            "source": "Blender Z-up, -Y forward, metres",
            "runtime": "Godot +Y up, -Z forward, metres",
            "mount": "identity transform beneath world-aligned LandingPad",
        },
        "envelope_contract_godot_metres": {
            **bounds,
            "deck_top_y": 0.095,
            "existing_pad_envelope_preserved": True,
            "all_authored_form_at_or_below_deck_top": True,
        },
        "hierarchy_contract": ["CentralBerthHeroArt", *SEMANTIC_ROOTS],
        "semantic_roots": list(SEMANTIC_ROOTS),
        "semantic_root_count": len(SEMANTIC_ROOTS),
        "material_roles": MATERIAL_SPECS,
        "material_role_count": len(MATERIAL_SPECS),
        "source_component_count": len(SOURCE_PARTS),
        "source_component_counts_by_root": dict(sorted(SOURCE_COUNTS_BY_ROOT.items())),
        "source_component_counts_by_material": dict(sorted(SOURCE_COUNTS_BY_MATERIAL.items())),
        "source_component_names": sorted(obj.name for obj in SOURCE_PARTS),
        "runtime_static_batching": {
            "strategy": "per_semantic_root_per_material_static_join",
            "source_preserved_in_blend": True,
            "runtime_mesh_counts_by_root": runtime_mesh_counts,
            "runtime_batch_names_by_root": batches_by_root,
            "runtime_mesh_instance_count": len(runtime_meshes),
            "runtime_mesh_instance_budget": 12,
            "runtime_surface_budget": 12,
        },
        "mesh_vertices_exported_runtime": vertex_count,
        "mesh_triangles_exported_runtime": triangle_count,
        "uv0_contract": uv_contract,
        "forbidden_authority_nodes": [
            "CollisionObject3D", "CollisionShape3D", "Area3D", "Camera3D",
            "AudioStreamPlayer3D", "NavigationRegion3D", "VehicleBody3D",
        ],
        "generator_sha256": sha256(GENERATOR_PATH),
        "blend_sha256": sha256(BLEND_PATH),
        "glb_sha256": sha256(GLB_PATH),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "CENTRAL_BERTH_HERO_V1_OK",
        len(SOURCE_PARTS), len(runtime_meshes), vertex_count, triangle_count,
        manifest["blend_sha256"], manifest["glb_sha256"],
    )


if __name__ == "__main__":
    main()
