"""Generate the original skinned Keth pilot and authored motion library.

Run from the repository root with the pinned DCC tool:

  blender --background --factory-startup --python tools/blender/generate_pilot_motion_v2.py

The editable .blend is the source of truth.  The GLB is a visual-only runtime
asset: player collision, cameras, input, boarding traversal and seat authority
remain in Godot.  Geometry, rigging and animation in this file are original,
script-assisted work and do not contain third-party mesh or motion-capture data.
"""

from __future__ import annotations

import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector


ROOT = Path.cwd()
BLEND_PATH = ROOT / "art_source/pilot/pilot_motion_v2.blend"
GLB_PATH = ROOT / "assets/models/pilot/pilot_motion_v2.glb"
MANIFEST_PATH = ROOT / "assets/models/pilot/pilot_motion_v2_asset_manifest.json"
GENERATOR_PATH = Path(__file__).resolve()
# One hundred source frames per second lets the requested .42 and .56 second
# one-shots end on exact source frames. Godot may resample tracks at import, but
# retains these exact authored clip boundaries.
FPS = 100

MATERIALS: dict[str, bpy.types.Material] = {}
PARTS: list[bpy.types.Object] = []
PART_NAMES: list[str] = []

BONE_TREE: dict[str, str | None] = {
    "root": None,
    "pelvis": "root",
    "spine_01": "pelvis",
    "spine_02": "spine_01",
    "chest": "spine_02",
    "neck": "chest",
    "head": "neck",
    "clavicle_l": "chest",
    "upper_arm_l": "clavicle_l",
    "forearm_l": "upper_arm_l",
    "hand_l": "forearm_l",
    "clavicle_r": "chest",
    "upper_arm_r": "clavicle_r",
    "forearm_r": "upper_arm_r",
    "hand_r": "forearm_r",
    "thigh_l": "pelvis",
    "calf_l": "thigh_l",
    "foot_l": "calf_l",
    "toe_l": "foot_l",
    "thigh_r": "pelvis",
    "calf_r": "thigh_r",
    "foot_r": "calf_r",
    "toe_r": "foot_r",
}

# Blender source coordinates are conventional metres, Z up and -Y forward.
BONES: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {
    "root": ((0.0, 0.0, 0.0), (0.0, 0.0, 0.12)),
    "pelvis": ((0.0, 0.0, 0.86), (0.0, 0.0, 0.99)),
    "spine_01": ((0.0, 0.0, 0.99), (0.0, 0.0, 1.12)),
    "spine_02": ((0.0, 0.0, 1.12), (0.0, 0.0, 1.28)),
    "chest": ((0.0, 0.0, 1.28), (0.0, 0.0, 1.45)),
    "neck": ((0.0, 0.0, 1.45), (0.0, 0.0, 1.56)),
    "head": ((0.0, 0.0, 1.56), (0.0, 0.0, 1.84)),
    "clavicle_l": ((-0.02, 0.0, 1.41), (-0.18, 0.0, 1.42)),
    "upper_arm_l": ((-0.18, 0.0, 1.42), (-0.39, 0.0, 1.20)),
    "forearm_l": ((-0.39, 0.0, 1.20), (-0.49, -0.015, 0.98)),
    "hand_l": ((-0.49, -0.015, 0.98), (-0.50, -0.06, 0.87)),
    "clavicle_r": ((0.02, 0.0, 1.41), (0.18, 0.0, 1.42)),
    "upper_arm_r": ((0.18, 0.0, 1.42), (0.39, 0.0, 1.20)),
    "forearm_r": ((0.39, 0.0, 1.20), (0.49, -0.015, 0.98)),
    "hand_r": ((0.49, -0.015, 0.98), (0.50, -0.06, 0.87)),
    "thigh_l": ((-0.13, 0.0, 0.88), (-0.14, 0.0, 0.51)),
    "calf_l": ((-0.14, 0.0, 0.51), (-0.14, 0.0, 0.15)),
    "foot_l": ((-0.14, 0.0, 0.15), (-0.14, -0.16, 0.08)),
    "toe_l": ((-0.14, -0.16, 0.08), (-0.14, -0.30, 0.07)),
    "thigh_r": ((0.13, 0.0, 0.88), (0.14, 0.0, 0.51)),
    "calf_r": ((0.14, 0.0, 0.51), (0.14, 0.0, 0.15)),
    "foot_r": ((0.14, 0.0, 0.15), (0.14, -0.16, 0.08)),
    "toe_r": ((0.14, -0.16, 0.08), (0.14, -0.30, 0.07)),
}

ACTION_SPECS = [
    {"source": "RESET", "runtime": "RESET", "duration": 0.0, "loop": False},
    {"source": "idle-loop", "runtime": "idle", "duration": 2.4, "loop": True},
    {"source": "walk-loop", "runtime": "walk", "duration": 0.8, "loop": True},
    {"source": "run-loop", "runtime": "run", "duration": 0.56, "loop": True},
    {"source": "jump", "runtime": "jump", "duration": 0.42, "loop": False},
    {"source": "airborne-loop", "runtime": "airborne", "duration": 0.9, "loop": True},
    {"source": "boarding", "runtime": "boarding", "duration": 1.1, "loop": False},
    {"source": "seated_control-loop", "runtime": "seated_control", "duration": 2.4, "loop": True},
    {"source": "disembark_recovery", "runtime": "disembark_recovery", "duration": 0.9, "loop": False},
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission: tuple[float, float, float, float] | None = None,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = 0.65
    MATERIALS[name] = mat
    return mat


def apply_modifiers(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def finish_part(
    obj: bpy.types.Object,
    name: str,
    mat: bpy.types.Material,
    weights: dict[str, float],
    bevel: float = 0.0,
) -> bpy.types.Object:
    obj.name = name
    if mat not in obj.data.materials[:]:
        obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("SuitEdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        apply_modifiers(obj)
    vertex_indices = list(range(len(obj.data.vertices)))
    total = sum(weights.values())
    for bone_name, raw_weight in weights.items():
        group = obj.vertex_groups.new(name=bone_name)
        group.add(vertex_indices, raw_weight / total, "REPLACE")
    obj["pilot_part"] = name
    obj["construction_role"] = (
        "glazing" if mat.name == "VisorGlazing"
        else "light" if mat.name.endswith("Light")
        else "flexible" if mat.name in {"PressureTextile", "JointRubber"}
        else "hard"
    )
    PARTS.append(obj)
    PART_NAMES.append(name)
    return obj


def uv_part(name, loc, scale, mat, weights, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        location=loc,
    )
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_part(obj, name, mat, weights)


def box_part(name, loc, size, mat, weights, bevel=0.025, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_part(obj, name, mat, weights, bevel)


def cylinder_part(
    name,
    start,
    end,
    radius,
    mat,
    weights,
    vertices=20,
    bevel=0.012,
):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=direction.length,
        location=(start_v + end_v) * 0.5,
    )
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.normalized().to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_part(obj, name, mat, weights, bevel)


def torus_part(name, loc, major, minor, mat, weights, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=24,
        minor_segments=8,
        location=loc,
        rotation=rotation,
    )
    return finish_part(bpy.context.object, name, mat, weights)


def build_rig(pilot_art: bpy.types.Object) -> bpy.types.Object:
    armature_data = bpy.data.armatures.new("PilotSkeleton")
    rig = bpy.data.objects.new("PilotRig", armature_data)
    bpy.context.collection.objects.link(rig)
    rig.parent = pilot_art
    rig.matrix_parent_inverse.identity()
    rig.show_in_front = True
    rig["asset_role"] = "visual_deformation_rig"

    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones: dict[str, bpy.types.EditBone] = {}
    for bone_name, (head, tail) in BONES.items():
        bone = armature_data.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0.0
        edit_bones[bone_name] = bone
    for bone_name, parent_name in BONE_TREE.items():
        if parent_name is not None:
            edit_bones[bone_name].parent = edit_bones[parent_name]
            edit_bones[bone_name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def build_original_suit(rig: bpy.types.Object) -> bpy.types.Object:
    textile = MATERIALS["PressureTextile"]
    armor = MATERIALS["CeramicArmor"]
    dark_armor = MATERIALS["GraphiteArmor"]
    rubber = MATERIALS["JointRubber"]
    harness = MATERIALS["HarnessWebbing"]
    visor = MATERIALS["VisorGlazing"]
    cyan = MATERIALS["CyanStatusLight"]
    amber = MATERIALS["AmberStatusLight"]

    # Core pressure garment and articulated hard-shell plates.
    uv_part("PelvisPressureLayer", (0, 0, .88), (.245, .16, .19), textile,
            {"pelvis": .88, "spine_01": .12})
    box_part("PelvisArmor", (0, -.125, .90), (.38, .075, .20), armor,
             {"pelvis": 1.0}, .035)
    uv_part("AbdomenPressureLayer", (0, 0, 1.08), (.235, .145, .23), textile,
            {"spine_01": .68, "spine_02": .32})
    uv_part("ChestPressureLayer", (0, 0, 1.31), (.31, .17, .24), textile,
            {"chest": .70, "spine_02": .30})
    box_part("ChestArmor", (0, -.145, 1.34), (.48, .085, .30), armor,
             {"chest": .90, "spine_02": .10}, .045)
    box_part("ChestInset", (0, -.195, 1.34), (.24, .018, .11), dark_armor,
             {"chest": 1.0}, .008)
    box_part("BackLifeSupport", (0, .155, 1.29), (.35, .12, .37), dark_armor,
             {"chest": .78, "spine_02": .22}, .035)
    cylinder_part("LeftHarness", (-.18, -.198, 1.45), (-.04, -.205, 1.02), .018,
                  harness, {"chest": .55, "spine_01": .45}, 12, .004)
    cylinder_part("RightHarness", (.18, -.198, 1.45), (.04, -.205, 1.02), .018,
                  harness, {"chest": .55, "spine_01": .45}, 12, .004)
    torus_part("NeckPressureSeal", (0, 0, 1.50), .145, .035, rubber,
               {"neck": .70, "chest": .30})

    # Practical compact pressure helmet with a restrained, non-emissive visor.
    uv_part("HelmetShell", (0, 0, 1.70), (.245, .215, .245), armor,
            {"head": .94, "neck": .06}, 32, 16)
    box_part("HelmetRearModule", (0, .18, 1.69), (.28, .10, .23), dark_armor,
             {"head": 1.0}, .035)
    uv_part("Visor", (0, -.196, 1.72), (.184, .035, .115), visor,
            {"head": 1.0}, 28, 12)
    box_part("VisorBrow", (0, -.224, 1.82), (.35, .045, .045), dark_armor,
             {"head": 1.0}, .014)
    box_part("HelmetChin", (0, -.203, 1.59), (.30, .065, .075), dark_armor,
             {"head": .92, "neck": .08}, .022)
    box_part("HelmetStatus", (.165, -.225, 1.61), (.025, .018, .055), cyan,
             {"head": 1.0}, .006)

    # Layered shoulders, sleeves and gloves. Elbow bellows receive equal
    # adjacent-bone weights so the joined suit has visible smooth deformation.
    for side, suffix in ((-1, "L"), (1, "R")):
        key = "l" if side < 0 else "r"
        clavicle = f"clavicle_{key}"
        upper = f"upper_arm_{key}"
        forearm = f"forearm_{key}"
        hand = f"hand_{key}"
        shoulder_x = side * .235
        elbow_x = side * .39
        wrist_x = side * .49
        uv_part(f"ShoulderPressure{suffix}", (side*.245, 0, 1.40), (.13, .145, .15),
                textile, {clavicle: .55, upper: .45})
        uv_part(f"ShoulderPlate{suffix}", (side*.285, -.08, 1.43), (.135, .11, .09),
                armor, {clavicle: .65, upper: .35})
        cylinder_part(f"UpperArmSuit{suffix}", (shoulder_x, 0, 1.36),
                      (side*.37, 0, 1.22), .085, textile,
                      {upper: .90, clavicle: .10}, 20)
        torus_part(f"ElbowBellow{suffix}", (elbow_x, 0, 1.18), .082, .022, rubber,
                   {upper: .50, forearm: .50}, rotation=(0, math.pi/2, 0))
        cylinder_part(f"ForearmSuit{suffix}", (side*.405, -.005, 1.15),
                      (side*.48, -.02, 1.00), .078, textile,
                      {forearm: .88, upper: .12}, 20)
        box_part(f"ForearmGuard{suffix}", (side*.455, -.065, 1.075),
                 (.13, .10, .18), armor, {forearm: .92, upper: .08}, .025,
                 rotation=(0, side*.05, -side*.18))
        torus_part(f"WristSeal{suffix}", (wrist_x, -.028, .98), .068, .018, rubber,
                   {forearm: .45, hand: .55}, rotation=(0, math.pi/2, 0))
        uv_part(f"Glove{suffix}", (side*.50, -.045, .91), (.073, .07, .105),
                dark_armor, {hand: 1.0}, 18, 10)

    # Narrow load-bearing legs, articulated knees and grounded boot soles.
    for side, suffix in ((-1, "L"), (1, "R")):
        key = "l" if side < 0 else "r"
        thigh = f"thigh_{key}"
        calf = f"calf_{key}"
        foot = f"foot_{key}"
        toe = f"toe_{key}"
        x = side * .14
        cylinder_part(f"ThighSuit{suffix}", (x, 0, .82), (x, 0, .55), .105,
                      textile, {thigh: .92, "pelvis": .08}, 22)
        box_part(f"ThighPlate{suffix}", (x, -.085, .69), (.16, .065, .24), armor,
                 {thigh: 1.0}, .025)
        torus_part(f"KneeBellow{suffix}", (x, 0, .50), .095, .025, rubber,
                   {thigh: .50, calf: .50})
        uv_part(f"KneeCap{suffix}", (x, -.09, .50), (.09, .055, .10), armor,
                {thigh: .25, calf: .75}, 18, 9)
        cylinder_part(f"CalfSuit{suffix}", (x, 0, .45), (x, 0, .18), .093,
                      textile, {calf: .92, thigh: .08}, 22)
        box_part(f"ShinGuard{suffix}", (x, -.085, .315), (.15, .07, .25), armor,
                 {calf: 1.0}, .024)
        torus_part(f"AnkleSeal{suffix}", (x, 0, .145), .083, .021, rubber,
                   {calf: .42, foot: .58})
        box_part(f"BootBody{suffix}", (x, -.075, .105), (.175, .28, .15),
                 dark_armor, {foot: .78, toe: .22}, .025)
        box_part(f"BootToe{suffix}", (x, -.225, .075), (.18, .18, .105),
                 dark_armor, {toe: .88, foot: .12}, .028)
        box_part(f"BootSole{suffix}", (x, -.105, .025), (.19, .38, .05),
                 rubber, {foot: .62, toe: .38}, .008)

    # Small readable functional details; no glowing body-wide strips.
    box_part("BeltWebbing", (0, -.16, .98), (.43, .035, .045), harness,
             {"pelvis": .55, "spine_01": .45}, .008)
    uv_part("HarnessRelease", (0, -.222, 1.16), (.045, .02, .045), amber,
            {"spine_02": 1.0}, 16, 8)
    for side, suffix in ((-1, "L"), (1, "R")):
        cylinder_part(f"ServiceHose{suffix}", (side*.14, .19, 1.40),
                      (side*.23, .20, 1.10), .018, rubber,
                      {"chest": .55, "spine_01": .45}, 12, .004)

    # Join every authored component into one multi-material, genuinely skinned
    # ArrayMesh. Named source components remain documented in the manifest.
    bpy.ops.object.select_all(action="DESELECT")
    for part in PARTS:
        part.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    suit = bpy.context.object
    suit.name = "PilotSuit"
    suit["asset_role"] = "original_skinned_pressure_suit"
    suit["visual_only"] = True
    modifier = suit.modifiers.new("PilotSkin", "ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = True
    suit.parent = rig
    suit.matrix_parent_inverse = rig.matrix_world.inverted()
    return suit


def reset_pose(rig: bpy.types.Object) -> None:
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)


# The spine and leg bones are built in the sagittal plane with roll 0, so each
# one's local X axis is world +X and a positive local-X key is a rotation about
# world +X. That rotation carries a bone's tip from +Z round towards -Y, which
# reads in opposite anatomical directions depending on which way the bone
# points: the up-pointing spine leans FORWARD (towards the pilot's face at -Y)
# while the down-pointing leg chain swings BACKWARD, behind him at +Y.
#
# The pose tables below are all authored in one anatomical convention, carried
# over from the legacy Godot fallback rig: positive local X means "this segment
# swings towards the face". That convention already holds for the spine, and
# the arm bones lie out of the sagittal plane and are keyed to a measured
# result, but it is inverted for the leg chain, because the legacy rig's leg
# node points -Y with forward at -Z, the mirror image of a Blender
# -Y-forward bone pointing -Z.
# Keyed unconverted, it gave the seated pose 78 degrees of hip HYPEREXTENSION
# and a knee folding forwards - the reported "legs break to get in" defect.
#
# The conversion belongs here, at the single place authored degrees become
# bone-local euler. It must not be compensated for by mirroring the mount, the
# seat anchor, or any downstream transform: those correct one camera angle and
# leave every other one wrong.
SAGITTAL_SIGN_INVERTED_BONES = frozenset(
    {
        "thigh_l", "calf_l", "foot_l", "toe_l",
        "thigh_r", "calf_r", "foot_r", "toe_r",
    }
)


def bone_local_euler_degrees(
    name: str,
    degrees: tuple[float, float, float],
) -> tuple[float, float, float]:
    """Convert one authored anatomical key into this rig's bone-local euler."""
    sagittal, local_y, local_z = degrees
    if name in SAGITTAL_SIGN_INVERTED_BONES:
        sagittal = -sagittal
    return (sagittal, local_y, local_z)


def key_pose(
    rig: bpy.types.Object,
    frame: float,
    rotations: dict[str, tuple[float, float, float]] | None = None,
    locations: dict[str, tuple[float, float, float]] | None = None,
) -> None:
    reset_pose(rig)
    rotations = rotations or {}
    locations = locations or {}
    for name, degrees in rotations.items():
        rig.pose.bones[name].rotation_euler = tuple(
            math.radians(value) for value in bone_local_euler_degrees(name, degrees)
        )
    for name, location in locations.items():
        rig.pose.bones[name].location = location

    # Root keys are deliberately invariant. The exported motion can deform the
    # suit, but never owns horizontal traversal or yaw.
    keyed_bones = set(rotations) | set(locations) | {"root"}
    for name in keyed_bones:
        bone = rig.pose.bones[name]
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        bone.keyframe_insert(data_path="location", frame=frame, group=name)


def make_action(rig: bpy.types.Object, name: str, duration: float, poses: list[dict]) -> None:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for pose in poses:
        key_pose(
            rig,
            pose["time"] * FPS,
            pose.get("rotations"),
            pose.get("locations"),
        )
    # A RESET action with a single bind key is valid source data. Every other
    # action gets an explicit duration boundary, even where the end is a loop.
    if duration > 0.0 and poses[-1]["time"] < duration:
        last = dict(poses[-1])
        last["time"] = duration
        key_pose(rig, duration * FPS, last.get("rotations"), last.get("locations"))
    for curve in action.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "BEZIER"
            point.handle_left_type = "AUTO_CLAMPED"
            point.handle_right_type = "AUTO_CLAMPED"
    rig.animation_data.action = None


def build_actions(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    make_action(rig, "RESET", 0.0, [{"time": 0.0}])

    idle = []
    for time, breath, sway in ((0, 0, 0), (.6, 1.5, .7), (1.2, 0, 0), (1.8, -1.2, -.7), (2.4, 0, 0)):
        idle.append({"time": time, "rotations": {
            "spine_02": (breath*.25, 0, sway), "chest": (-breath*.35, 0, -sway*.5),
            "upper_arm_l": (sway*.3, 0, sway*.25), "upper_arm_r": (-sway*.3, 0, -sway*.25),
            "head": (0, sway*.25, 0),
        }, "locations": {"pelvis": (0, 0, breath*.0008)}})
    make_action(rig, "idle-loop", 2.4, idle)

    walk = []
    for time, phase in ((0, 1), (.2, 0), (.4, -1), (.6, 0), (.8, 1)):
        lift_l = .018 if phase < 0 else 0
        lift_r = .018 if phase > 0 else 0
        walk.append({"time": time, "rotations": {
            "thigh_l": (28*phase, 0, 0), "thigh_r": (-28*phase, 0, 0),
            "calf_l": (-20 if phase <= 0 else -4, 0, 0),
            "calf_r": (-20 if phase >= 0 else -4, 0, 0),
            "foot_l": (12*phase, 0, 0), "foot_r": (-12*phase, 0, 0),
            "toe_l": (-8*phase, 0, 0), "toe_r": (8*phase, 0, 0),
            "upper_arm_l": (-20*phase, 0, 0), "upper_arm_r": (20*phase, 0, 0),
            "forearm_l": (-8, 0, 0), "forearm_r": (-8, 0, 0),
            "spine_02": (0, 0, -2.5*phase), "chest": (0, 0, 1.5*phase),
        }, "locations": {"pelvis": (0, 0, lift_l+lift_r)}})
    make_action(rig, "walk-loop", .8, walk)

    run = []
    for time, phase in ((0, 1), (.14, 0), (.28, -1), (.42, 0), (.56, 1)):
        run.append({"time": time, "rotations": {
            "thigh_l": (43*phase, 0, 0), "thigh_r": (-43*phase, 0, 0),
            "calf_l": (-34 if phase <= 0 else -10, 0, 0),
            "calf_r": (-34 if phase >= 0 else -10, 0, 0),
            "foot_l": (16*phase, 0, 0), "foot_r": (-16*phase, 0, 0),
            "upper_arm_l": (-34*phase, 0, -4), "upper_arm_r": (34*phase, 0, 4),
            "forearm_l": (-30, 0, 0), "forearm_r": (-30, 0, 0),
            "spine_01": (7, 0, 0), "chest": (2, 0, 2.5*phase),
        }, "locations": {"pelvis": (0, 0, .025 if phase == 0 else .008)}})
    make_action(rig, "run-loop", .56, run)

    make_action(rig, "jump", .42, [
        {"time": 0, "rotations": {"spine_01": (8,0,0), "thigh_l": (-18,0,0), "thigh_r": (-18,0,0), "calf_l": (-35,0,0), "calf_r": (-35,0,0), "upper_arm_l": (15,0,0), "upper_arm_r": (15,0,0)}},
        {"time": .18, "rotations": {"spine_01": (-5,0,0), "thigh_l": (10,0,0), "thigh_r": (-5,0,0), "calf_l": (-12,0,0), "calf_r": (-22,0,0), "upper_arm_l": (-25,0,-8), "upper_arm_r": (-25,0,8)}},
        {"time": .42, "rotations": {"spine_01": (-3,0,0), "thigh_l": (24,0,0), "thigh_r": (-14,0,0), "calf_l": (-24,0,0), "calf_r": (-31,0,0), "foot_l": (12,0,0), "foot_r": (-8,0,0), "upper_arm_l": (-18,0,-6), "upper_arm_r": (-12,0,8)}},
    ])

    make_action(rig, "airborne-loop", .9, [
        {"time": 0, "rotations": {"spine_01": (-2,0,0), "thigh_l": (22,0,0), "thigh_r": (-12,0,0), "calf_l": (-24,0,0), "calf_r": (-30,0,0), "foot_l": (10,0,0), "upper_arm_l": (-14,0,-7), "upper_arm_r": (-10,0,8)}},
        {"time": .45, "rotations": {"spine_01": (1,0,0), "thigh_l": (14,0,0), "thigh_r": (-18,0,0), "calf_l": (-30,0,0), "calf_r": (-22,0,0), "foot_r": (-10,0,0), "upper_arm_l": (-10,0,-5), "upper_arm_r": (-15,0,6)}},
        {"time": .9, "rotations": {"spine_01": (-2,0,0), "thigh_l": (22,0,0), "thigh_r": (-12,0,0), "calf_l": (-24,0,0), "calf_r": (-30,0,0), "foot_l": (10,0,0), "upper_arm_l": (-14,0,-7), "upper_arm_r": (-10,0,8)}},
    ])

    # Anatomical degrees, positive towards the face; see
    # bone_local_euler_degrees for the leg chain's sign conversion. Seated is
    # hip flexion 78 with the thigh forward and near level, knee flexion 76
    # bringing the shin down under it, and the sole taken off its standing
    # droop so it meets the pedal.
    seated = {"spine_01": (5,0,0), "spine_02": (-7,0,0),
              "thigh_l": (78,0,-4), "thigh_r": (78,0,4),
              "calf_l": (-76,0,0), "calf_r": (-76,0,0),
              "foot_l": (18,0,0), "foot_r": (18,0,0),
              "upper_arm_l": (-30,0,-12), "upper_arm_r": (-30,0,12),
              "forearm_l": (-62,0,-5), "forearm_r": (-62,0,5)}
    make_action(rig, "boarding", 1.1, [
        {"time": 0, "rotations": {}},
        {"time": .28, "rotations": {"spine_01": (8,0,-4), "thigh_l": (22,0,0), "thigh_r": (10,0,0), "calf_l": (-30,0,0), "upper_arm_l": (-18,0,-8), "forearm_l": (-25,0,0)}},
        {"time": .62, "rotations": {"spine_01": (10,0,2), "thigh_l": (55,0,-3), "thigh_r": (42,0,3), "calf_l": (-62,0,0), "calf_r": (-48,0,0), "upper_arm_l": (-25,0,-12), "upper_arm_r": (-20,0,10), "forearm_l": (-50,0,0), "forearm_r": (-42,0,0)}},
        {"time": 1.1, "rotations": seated},
    ])

    seated_a = dict(seated)
    seated_b = dict(seated)
    seated_b.update({"forearm_l": (-58, 0, -7), "forearm_r": (-66, 0, 7), "head": (0, 4, 0), "chest": (-1,0,0)})
    make_action(rig, "seated_control-loop", 2.4, [
        {"time": 0, "rotations": seated_a}, {"time": .6, "rotations": seated_b},
        {"time": 1.2, "rotations": seated_a}, {"time": 1.8, "rotations": seated_b},
        {"time": 2.4, "rotations": seated_a},
    ])

    make_action(rig, "disembark_recovery", .9, [
        {"time": 0, "rotations": seated},
        {"time": .34, "rotations": {"spine_01": (12,0,-3), "thigh_l": (50,0,-4), "thigh_r": (62,0,4), "calf_l": (-52,0,0), "calf_r": (-68,0,0), "upper_arm_l": (-20,0,-10), "upper_arm_r": (-26,0,9), "forearm_l": (-32,0,0), "forearm_r": (-45,0,0)}},
        {"time": .66, "rotations": {"spine_01": (5,0,2), "thigh_l": (16,0,0), "thigh_r": (26,0,0), "calf_l": (-18,0,0), "calf_r": (-30,0,0), "upper_arm_l": (-8,0,-4), "upper_arm_r": (-12,0,4)}},
        {"time": .9, "rotations": {}},
    ])
    reset_pose(rig)


def evaluated_counts(obj: bpy.types.Object) -> tuple[int, int]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    result = (len(mesh.vertices), len(mesh.loop_triangles))
    evaluated.to_mesh_clear()
    return result


def object_bounds(obj: bpy.types.Object) -> dict[str, list[float]]:
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    lower = Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners)))
    upper = Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners)))
    return {
        "min_blender_xyz": [round(v, 6) for v in lower],
        "max_blender_xyz": [round(v, 6) for v in upper],
        "size_metres": [round(v, 6) for v in upper - lower],
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
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials):
        for block in list(datablocks):
            datablocks.remove(block)

    scene = bpy.context.scene
    scene.name = "PilotMotionV2Source"
    scene.render.fps = FPS
    scene.render.fps_base = 1.0
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.frame_start = 0
    scene.frame_end = 72

    material("PressureTextile", (.075, .105, .125, 1), 0.02, 0.88)
    material("CeramicArmor", (.68, .72, .70, 1), 0.10, 0.42)
    material("GraphiteArmor", (.025, .04, .05, 1), 0.32, 0.33)
    material("JointRubber", (.018, .022, .025, 1), 0.01, 0.96)
    material("HarnessWebbing", (.22, .17, .10, 1), 0.01, 0.82)
    material("VisorGlazing", (.025, .105, .125, .62), 0.18, 0.12)
    material("CyanStatusLight", (.01, .28, .32, 1), 0.10, 0.30, (.02, .65, .78, 1))
    material("AmberStatusLight", (.34, .13, .015, 1), 0.08, 0.38, (.75, .28, .025, 1))

    pilot_art = bpy.data.objects.new("PilotArt", None)
    pilot_art.empty_display_type = "PLAIN_AXES"
    pilot_art["asset_id"] = "keth.pilot.motion.v2"
    pilot_art["coordinate_contract"] = (
        "Godot +Y up, imported semantic visual forward +Z, metres; "
        "Player mount rotates PI to canonical -Z"
    )
    pilot_art["gameplay_authority"] = False
    bpy.context.collection.objects.link(pilot_art)
    rig = build_rig(pilot_art)
    suit = build_original_suit(rig)
    build_actions(rig)

    vertex_count, triangle_count = evaluated_counts(suit)
    bpy.context.view_layer.objects.active = rig
    rig.animation_data.action = None
    reset_pose(rig)
    bpy.context.view_layer.update()

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), check_existing=False)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_visible=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_skins=True,
        export_all_influences=True,
        export_def_bones=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )

    manifest = {
        "schema_version": 2,
        "asset_id": "keth.pilot.motion.v2",
        "authorship": "original_script_assisted_blender",
        "motion_capture": False,
        "runtime_generation": False,
        "blender_version": bpy.app.version_string,
        "generator": "tools/blender/generate_pilot_motion_v2.py",
        "generator_sha256": sha256(GENERATOR_PATH),
        "source_path": "art_source/pilot/pilot_motion_v2.blend",
        "runtime_path": "assets/models/pilot/pilot_motion_v2.glb",
        "coordinate_contract": {
            "source": "Blender Z-up, -Y forward, metres",
            "runtime": "Godot +Y up, imported semantic visual forward +Z, metres",
            "imported_visual_forward_axis": "+Z",
            "mounted_player_forward_axis": "-Z after Player BodyPivot PI yaw offset",
            "soles_ground_plane_metres": 0.0,
            "root_motion": "in_place_no_horizontal_or_yaw",
            "authored_pose_sign": (
                "anatomical degrees, positive towards the face; the leg chain's "
                "sagittal sign is inverted into bone-local euler because a "
                "-Z-pointing bone reads world +X rotation the opposite way "
                "round from the -Y-forward source frame"
            ),
            "knee_flexion_world_axis": (
                "+X; the shin never rotates forward past the thigh"
            ),
        },
        "hierarchy_contract": ["PilotArt", "PilotRig", "PilotSkeleton", "PilotSuit"],
        "bone_tree": BONE_TREE,
        "bone_count": len(BONE_TREE),
        "actions": ACTION_SPECS,
        "source_part_names": PART_NAMES,
        "source_part_count": len(PART_NAMES),
        "skinned_mesh_count": 1,
        "material_roles": sorted(MATERIALS),
        "mesh_vertices_exported_evaluated": vertex_count,
        "mesh_triangles_exported_evaluated": triangle_count,
        "bind_bounds": object_bounds(suit),
        "blend_sha256": sha256(BLEND_PATH),
        "glb_sha256": sha256(GLB_PATH),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "PILOT_MOTION_V2_BLENDER_ASSET_OK",
        len(BONE_TREE), len(ACTION_SPECS), vertex_count, triangle_count,
        manifest["glb_sha256"],
    )


if __name__ == "__main__":
    main()
