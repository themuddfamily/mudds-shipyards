"""Generate the original skinned Keth pilot and authored motion library.

Run from the repository root with the pinned DCC tool:

  blender --background --factory-startup --python tools/blender/generate_pilot_motion_v2.py

The editable .blend is the source of truth.  The GLB is a visual-only runtime
asset: player collision, cameras, input, boarding traversal and seat authority
remain in Godot.  Geometry, rigging and animation in this file are original,
script-assisted work and do not contain third-party mesh or motion-capture data.

Reproducibility, measured rather than assumed: re-running this script on the
pinned Blender 4.0.2 reproduces the asset semantically but NOT byte for byte.
Three consecutive runs of the unmodified script produced three different GLB
digests. Diffing them shows identical glTF JSON and identical vertex, normal,
skin-weight and animation-sampler data; the only bytes that move are the
triangle INDEX buffers of five primitives, whose winding order the exporter
emits in a run-dependent sequence (setting PYTHONHASHSEED does not pin it).

The SHA256 contracts in the manifest, in `pilot_skinned_presentation.gd` and in
`pilot_blender_asset_test.gd` therefore pin the exact shipped bytes, which is
what stops the checked-in GLB drifting from the checked-in source unnoticed.
They are not a claim that a fresh run will reproduce those bytes. After any
re-run, expect to re-freeze them, and check what actually changed by comparing
the manifest's rig, bind-bounds, clip and topology fields - not the digests.
"""

from __future__ import annotations

import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector


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


# --------------------------------------------------------------------------
# Authoring frame
# --------------------------------------------------------------------------
#
# Every bone in this rig is built with roll 0, so its local axes are whatever
# Blender's roll-0 convention happens to produce for that bone's direction.
# For the spine that is world X; for the leg chain it is world X with the
# anatomical sense reversed, because the bone points down; and for the arms it
# is neither, because the arm bones lie out of the sagittal plane. Keying
# bone-local euler directly therefore means three different conventions in one
# rig, and this asset has already shipped two orientation defects that way:
# a mount-level mirror, and then 78 degrees of hip HYPEREXTENSION with the
# knees folding forwards - the reported "legs break to get in".
#
# So nothing below is authored in bone-local euler. Poses are authored in one
# anatomical frame for every bone:
#
#   swing   degrees about the rig's sagittal axis, POSITIVE = this segment's
#           tip swings TOWARDS THE PILOT'S FACE. Hip flexion, knee flexion
#           (as a negative, since a knee only unbends towards the face),
#           ankle dorsiflexion, shoulder flexion, elbow flexion, spine lean.
#   abduct  degrees about the rig's fore-aft axis, POSITIVE = tip towards +X.
#   twist   degrees about the rig's vertical axis, POSITIVE = counter-clockwise
#           seen from above.
#
# `bone_local_euler_degrees` is the single place that conversion happens, and
# it derives it from each bone's own rest matrix rather than from a hand-kept
# sign table, so a bone pointing any which way still obeys the one convention.
# It must not be compensated for by mirroring the mount, the seat anchor, or
# any downstream transform: those correct one camera angle and leave every
# other one wrong.
#
# Note for readers of the pose tables: the "_l" bones sit at negative X and the
# "_r" bones at positive X, but the pilot faces -Y, so his own left is +X. The
# side suffixes are therefore swapped with respect to his anatomy. The character
# is symmetric so this is cosmetic, and renaming bones would break the bone-tree
# contract published in the manifest and asserted by four suites; what matters
# for the motion is only that arm and leg stay contralateral, which is
# side-agnostic. It is recorded here so nobody "fixes" it in a downstream
# transform.

# Filled in from the built rig; local -> armature basis for every bone.
BONE_REST_BASIS: dict[str, Matrix] = {}
# +1 for a bone whose rest direction points up, -1 for one pointing down. This
# is what makes "positive swing is towards the face" hold for the spine and the
# leg chain at once.
BONE_UP_SIGN: dict[str, float] = {}


def capture_rest_frames(rig: bpy.types.Object) -> None:
    for bone in rig.data.bones:
        basis = bone.matrix_local.to_3x3()
        direction = (Vector(bone.tail_local) - Vector(bone.head_local)).normalized()
        BONE_REST_BASIS[bone.name] = basis
        BONE_UP_SIGN[bone.name] = 1.0 if direction.z >= 0.0 else -1.0


def bone_local_euler_degrees(
    name: str,
    degrees: tuple[float, float, float],
) -> tuple[float, float, float]:
    """Convert one authored anatomical key into this rig's bone-local euler."""
    swing, abduct, twist = degrees
    basis = BONE_REST_BASIS[name]
    sign = BONE_UP_SIGN[name]
    world = (
        Matrix.Rotation(math.radians(twist), 3, "Z")
        @ Matrix.Rotation(math.radians(abduct) * sign, 3, "Y")
        @ Matrix.Rotation(math.radians(swing) * sign, 3, "X")
    )
    local = basis.transposed() @ world @ basis
    euler = local.to_euler("XYZ")
    return (math.degrees(euler.x), math.degrees(euler.y), math.degrees(euler.z))


def bone_local_location(
    name: str,
    offset: tuple[float, float, float],
) -> tuple[float, float, float]:
    """Convert an authored (side, lift, forward) offset into bone-local metres.

    Recorded observation, now corrected: the walk and run cycles used to key
    `pelvis` location as (0, 0, lift). The pelvis bone points up, so its local
    Z is world -Y - the direction the pilot faces. Those clips were sliding his
    hips 18 and 25 mm FORWARD twice per stride and never lifting them at all,
    which is why the old cycles read as a rigid pair of tongs opening and
    closing. Vertical travel is world +Z and goes through this function.
    """
    side, lift, forward = offset
    world = Vector((side, -forward, lift))
    local = BONE_REST_BASIS[name].transposed() @ world
    return (local.x, local.y, local.z)


# --------------------------------------------------------------------------
# Timing
# --------------------------------------------------------------------------
#
# Poses are authored as tables of (phase, value) and evaluated with a
# Catmull-Rom spline, then sampled onto every other source frame and keyed
# LINEAR. Two reasons this is not sparse keys plus Blender's auto handles:
# a cyclic table wraps its own neighbours, so a loop closes with continuous
# velocity instead of the flat spot AUTO_CLAMPED puts on a first and last key;
# and the timing of an ease, an overshoot and a settle is then written here in
# the open rather than inferred by a handle heuristic.
KEY_STRIDE = 2


def _catmull(p0: float, p1: float, p2: float, p3: float, u: float) -> float:
    return 0.5 * (
        (2.0 * p1)
        + (-p0 + p2) * u
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u
    )


def cyclic(table: list[tuple[float, float]], phase: float) -> float:
    """Evaluate a table keyed on a 0..1 phase, wrapping at both ends."""
    phase = phase - math.floor(phase)
    count = len(table)
    index = 0
    for position in range(count):
        if table[position][0] <= phase:
            index = position
    start_phase, start_value = table[index]
    end_phase, end_value = table[(index + 1) % count]
    span = (end_phase - start_phase) % 1.0
    if span <= 0.0:
        return start_value
    u = ((phase - start_phase) % 1.0) / span
    before = table[(index - 1) % count][1]
    after = table[(index + 2) % count][1]
    return _catmull(before, start_value, end_value, after, u)


def timed(table: list[tuple[float, float]], time: float) -> float:
    """Evaluate a one-shot table keyed on seconds, clamped at both ends."""
    if time <= table[0][0]:
        return table[0][1]
    if time >= table[-1][0]:
        return table[-1][1]
    index = 0
    for position in range(len(table) - 1):
        if table[position][0] <= time:
            index = position
    start_time, start_value = table[index]
    end_time, end_value = table[index + 1]
    u = (time - start_time) / (end_time - start_time)
    before = table[max(index - 1, 0)][1]
    after = table[min(index + 2, len(table) - 1)][1]
    return _catmull(before, start_value, end_value, after, u)


def assert_timing_table(
    label: str,
    table: list[tuple[float, float]],
    end: float,
    cyclic_table: bool = False,
) -> None:
    """Reject malformed authored timing data before it reaches Blender.

    A typo in a phase or beat table otherwise gets silently tolerated by the
    spline helpers: an out-of-order key changes which segment is selected, and
    a duplicate key can make a whole authored beat unreachable.  This is an
    authoring contract, not a runtime repair, so the generator stops at the
    source of the defect with the table name and offending key.
    """
    if len(table) < 3:
        raise RuntimeError(f"{label}: authored table needs at least three keys")
    previous = -math.inf
    for index, (time, value) in enumerate(table):
        if not math.isfinite(time) or not math.isfinite(value):
            raise RuntimeError(f"{label}: key {index} is not finite")
        if time <= previous:
            raise RuntimeError(f"{label}: keys must be strictly increasing")
        if time < 0.0 or time > end:
            raise RuntimeError(
                f"{label}: key {index} ({time}) falls outside 0..{end}"
            )
        previous = time
    if table[0][0] != 0.0 or (
        table[-1][0] >= end if cyclic_table else table[-1][0] > end
    ):
        raise RuntimeError(
            f"{label}: authored range must start at 0 and stay within its end"
        )
    if cyclic_table and table[-1][0] >= 1.0:
        raise RuntimeError(f"{label}: cyclic phase keys must stay below 1")


def assert_counter_swing(
    label: str,
    leg_table: list[tuple[float, float]],
    arm_table: list[tuple[float, float]],
) -> None:
    """Ensure a locomotion arm does not swing with its same-side leg.

    The old placeholder gait did exactly that and read as a pair of scissors.
    A negative sampled covariance is a compact source-level witness for the
    authored counter-swing while leaving the actual deformation checks to the
    Godot pilot suites.
    """
    samples = [index / 16.0 for index in range(16)]
    legs = [cyclic(leg_table, phase) for phase in samples]
    arms = [cyclic(arm_table, phase) for phase in samples]
    leg_mean = sum(legs) / len(legs)
    arm_mean = sum(arms) / len(arms)
    covariance = sum(
        (leg - leg_mean) * (arm - arm_mean)
        for leg, arm in zip(legs, arms)
    )
    if covariance >= -0.01:
        raise RuntimeError(
            f"{label}: same-side arm/leg channels do not counter-swing "
            f"(sampled covariance {covariance:.4f})"
        )


def blend_pose(start: dict, end: dict, amount: float) -> dict:
    """Interpolate two whole poses channel by channel."""
    amount = min(max(amount, 0.0), 1.0)
    result = {}
    for name in set(start) | set(end):
        first = start.get(name, (0.0, 0.0, 0.0))
        second = end.get(name, (0.0, 0.0, 0.0))
        result[name] = tuple(
            first[axis] + (second[axis] - first[axis]) * amount for axis in range(3)
        )
    return result


def with_swing(pose: dict, name: str, swing: float) -> None:
    """Replace one bone's sagittal channel, leaving abduct and twist alone."""
    channels = pose[name]
    pose[name] = (swing, channels[1], channels[2])


def merge(*poses: dict[str, tuple[float, float, float]]) -> dict:
    """Sum anatomical channels bone by bone, so a base pose can carry overlays."""
    result: dict[str, list[float]] = {}
    for pose in poses:
        for name, channels in pose.items():
            accumulated = result.setdefault(name, [0.0, 0.0, 0.0])
            for axis in range(3):
                accumulated[axis] += channels[axis]
    return {name: tuple(channels) for name, channels in result.items()}


# A person at rest is never at attention: soft knees, a little elbow bend, arms
# hanging clear of the suit. Idle, the head and tail of boarding, the recovery
# of disembark and the landing of jump all resolve here, so those clips join up
# instead of snapping when the controller crossfades between them.
STANDING = {
    "spine_01": (2.0, 0.0, 0.0),
    "spine_02": (-1.0, 0.0, 0.0),
    "chest": (1.5, 0.0, 0.0),
    "neck": (2.5, 0.0, 0.0),
    "head": (-2.5, 0.0, 0.0),
    "clavicle_l": (0.0, 1.5, 0.0),
    "clavicle_r": (0.0, -1.5, 0.0),
    "upper_arm_l": (2.0, -7.0, 0.0),
    "upper_arm_r": (2.0, 7.0, 0.0),
    "forearm_l": (14.0, 0.0, 0.0),
    "forearm_r": (14.0, 0.0, 0.0),
    "hand_l": (6.0, 0.0, 0.0),
    "hand_r": (6.0, 0.0, 0.0),
    "thigh_l": (1.0, -1.5, 0.0),
    "thigh_r": (1.0, 1.5, 0.0),
    "calf_l": (-4.0, 0.0, 0.0),
    "calf_r": (-4.0, 0.0, 0.0),
    # A flat sole needs the ankle to cancel everything above it: the segment
    # angles simply add, so foot = -(thigh + calf).
    "foot_l": (3.0, 0.0, 0.0),
    "foot_r": (3.0, 0.0, 0.0),
}

# The settled seated pose. Hip flexion 78 puts the thigh forward and near
# level, knee flexion 76 brings the shin down under it, and the sole comes off
# its standing droop to meet the pedal. Boarding ends exactly here and
# disembark starts exactly here, so the seat never pops.
SEATED = {
    "spine_01": (5.0, 0.0, 0.0),
    "spine_02": (-7.0, 0.0, 0.0),
    "chest": (2.0, 0.0, 0.0),
    "neck": (3.0, 0.0, 0.0),
    "head": (-4.0, 0.0, 0.0),
    "clavicle_l": (2.0, 2.0, 0.0),
    "clavicle_r": (2.0, -2.0, 0.0),
    "upper_arm_l": (30.0, -12.0, 0.0),
    "upper_arm_r": (30.0, 12.0, 0.0),
    "forearm_l": (62.0, -5.0, 0.0),
    "forearm_r": (62.0, 5.0, 0.0),
    "hand_l": (8.0, 0.0, 0.0),
    "hand_r": (8.0, 0.0, 0.0),
    "thigh_l": (78.0, -4.0, 0.0),
    "thigh_r": (78.0, 4.0, 0.0),
    "calf_l": (-76.0, 0.0, 0.0),
    "calf_r": (-76.0, 0.0, 0.0),
    "foot_l": (18.0, 0.0, 0.0),
    "foot_r": (18.0, 0.0, 0.0),
}


# --------------------------------------------------------------------------
# Cycle tables
# --------------------------------------------------------------------------
#
# One set of tables per limb channel, in cycle phase, evaluated once per leg
# with the right leg half a cycle behind. That is what gives contact, loading,
# passing and lift their own timing instead of the two legs being exact
# negatives of each other at every instant, which is what the old scissor
# cycles were.

WALK_THIGH = [(0.00, 28.0), (0.12, 20.0), (0.30, 4.0), (0.50, -18.0),
              (0.68, 2.0), (0.84, 21.0), (0.94, 27.0)]
# Knee flexion is authored negative and never crosses zero: a knee does not
# bend forwards, and the shipped GLB is measured for exactly that.
WALK_CALF = [(0.00, -5.0), (0.10, -17.0), (0.26, -8.0), (0.44, -23.0),
             (0.56, -50.0), (0.66, -62.0), (0.80, -33.0), (0.92, -10.0)]
WALK_FOOT = [(0.00, 6.0), (0.10, -8.0), (0.26, 4.0), (0.42, -4.0),
             (0.52, -22.0), (0.64, -4.0), (0.80, 4.0), (0.92, 8.0)]
WALK_TOE = [(0.00, 0.0), (0.30, 0.0), (0.42, 20.0), (0.56, 4.0), (0.70, 0.0)]
WALK_ARM = [(0.00, -20.0), (0.25, -5.0), (0.50, 21.0), (0.75, 3.0), (0.90, -16.0)]
WALK_FOREARM = [(0.00, 26.0), (0.25, 18.0), (0.50, 12.0), (0.75, 21.0), (0.90, 25.0)]

RUN_THIGH = [(0.00, 44.0), (0.10, 30.0), (0.26, 8.0), (0.50, -26.0),
             (0.66, 6.0), (0.80, 33.0), (0.92, 44.0)]
RUN_CALF = [(0.00, -20.0), (0.10, -36.0), (0.24, -20.0), (0.42, -42.0),
            (0.54, -78.0), (0.64, -95.0), (0.78, -56.0), (0.90, -24.0)]
RUN_FOOT = [(0.00, 4.0), (0.12, -10.0), (0.28, 2.0), (0.44, -14.0),
            (0.54, -30.0), (0.66, -6.0), (0.82, 6.0), (0.92, 6.0)]
RUN_TOE = [(0.00, 0.0), (0.32, 0.0), (0.46, 24.0), (0.58, 4.0), (0.72, 0.0)]
RUN_ARM = [(0.00, -28.0), (0.25, -6.0), (0.50, 30.0), (0.75, 4.0), (0.90, -24.0)]
RUN_FOREARM = [(0.00, 92.0), (0.25, 80.0), (0.50, 74.0), (0.75, 86.0), (0.90, 92.0)]


def leg_cycle(
    phase: float,
    thigh_table: list[tuple[float, float]],
    calf_table: list[tuple[float, float]],
    foot_table: list[tuple[float, float]],
    toe_table: list[tuple[float, float]],
    side: float,
    suffix: str,
) -> dict[str, tuple[float, float, float]]:
    thigh = cyclic(thigh_table, phase)
    calf = min(cyclic(calf_table, phase), 0.0)
    return {
        f"thigh_{suffix}": (thigh, side * 1.5, side * -1.5),
        f"calf_{suffix}": (calf, 0.0, 0.0),
        f"foot_{suffix}": (cyclic(foot_table, phase), side * -1.0, 0.0),
        f"toe_{suffix}": (cyclic(toe_table, phase), 0.0, 0.0),
    }


def arm_cycle(
    phase: float,
    arm_table: list[tuple[float, float]],
    forearm_table: list[tuple[float, float]],
    side: float,
    suffix: str,
    spread: float,
) -> dict[str, tuple[float, float, float]]:
    swing = cyclic(arm_table, phase)
    return {
        f"clavicle_{suffix}": (swing * 0.10, side * 1.5, 0.0),
        # `_l` sits at -X, so "outward" is a negative abduct on that side and a
        # positive one on the other: hence side * spread, spread positive.
        f"upper_arm_{suffix}": (swing, side * spread, side * -4.0),
        f"forearm_{suffix}": (cyclic(forearm_table, phase), side * 3.0, 0.0),
        f"hand_{suffix}": (6.0 + swing * 0.15, 0.0, 0.0),
    }


def locomotion_pose(
    phase: float,
    thigh_table,
    calf_table,
    foot_table,
    toe_table,
    arm_table,
    forearm_table,
    lean: float,
    pelvis_lift: float,
    pelvis_lift_phase: float,
    pelvis_sway: float,
    pelvis_twist: float,
    pelvis_drop: float,
    spread: float,
) -> tuple[dict, dict]:
    """One frame of a two-step locomotion cycle.

    `_l` sits at -X and `_r` at +X. The right leg runs half a cycle behind the
    left, and each arm counter-swings against the leg on its OWN side, which is
    what makes the gait contralateral. The old cycles had `upper_arm_l` and
    `thigh_l` reaching forward together on the same frame.
    """
    left = leg_cycle(phase, thigh_table, calf_table, foot_table, toe_table, -1.0, "l")
    right = leg_cycle(phase + 0.5, thigh_table, calf_table, foot_table, toe_table, 1.0, "r")
    left_arm = arm_cycle(phase, arm_table, forearm_table, -1.0, "l", spread)
    right_arm = arm_cycle(phase + 0.5, arm_table, forearm_table, 1.0, "r", spread)

    # Hips carry the weight: highest over each midstance, lowest at each
    # contact, so the pelvis oscillates twice per cycle. It swings towards
    # whichever leg is carrying, and drops on the side that is swinging.
    lift = pelvis_lift * math.cos(2.0 * math.tau * (phase - pelvis_lift_phase))
    sway = -pelvis_sway * math.cos(math.tau * (phase - 0.25))
    twist = pelvis_twist * math.cos(math.tau * phase)
    drop = pelvis_drop * math.cos(math.tau * (phase - 0.25))

    # Shoulders counter-rotate against the hips; the head then unwinds most of
    # what the chest did, so the pilot keeps looking where he is going.
    spine = {
        "pelvis": (0.0, 0.0, twist),
        "spine_01": (lean * 0.45, drop * -0.25, twist * -0.7),
        "spine_02": (lean * 0.30, drop * -0.30, twist * -0.8),
        "chest": (lean * 0.25, drop * -0.20, twist * -0.6),
        "neck": (-lean * 0.35, 0.0, twist * 0.5),
        "head": (-lean * 0.45, drop * 0.35, twist * 1.1),
    }
    rotations = merge(left, right, left_arm, right_arm, spine)
    locations = {"pelvis": (sway, lift, 0.0)}
    return rotations, locations


def window(start: float, end: float, rising: bool) -> "callable":
    """A 0..1 weight that eases across [start, end], for the ground solve."""

    def weight(time: float) -> float:
        if end <= start:
            return 1.0 if rising else 0.0
        span = min(max((time - start) / (end - start), 0.0), 1.0)
        eased = span * span * (3.0 - 2.0 * span)
        return eased if rising else 1.0 - eased

    return weight


def build_actions(rig: bpy.types.Object) -> None:
    # Validate the reusable locomotion tables before any action datablock is
    # created.  These checks intentionally operate on authored source values;
    # they do not hide a bad key with a clamp or a post-export correction.
    for label, table in (
        ("WALK_THIGH", WALK_THIGH),
        ("WALK_CALF", WALK_CALF),
        ("WALK_FOOT", WALK_FOOT),
        ("WALK_TOE", WALK_TOE),
        ("WALK_ARM", WALK_ARM),
        ("WALK_FOREARM", WALK_FOREARM),
        ("RUN_THIGH", RUN_THIGH),
        ("RUN_CALF", RUN_CALF),
        ("RUN_FOOT", RUN_FOOT),
        ("RUN_TOE", RUN_TOE),
        ("RUN_ARM", RUN_ARM),
        ("RUN_FOREARM", RUN_FOREARM),
    ):
        assert_timing_table(label, table, 1.0, cyclic_table=True)
    assert_counter_swing("WALK", WALK_THIGH, WALK_ARM)
    assert_counter_swing("RUN", RUN_THIGH, RUN_ARM)

    rig.animation_data_create()
    make_action(rig, "RESET", 0.0, lambda time: ({}, {}))

    # ---------------------------------------------------------------- idle
    # Two rhythms at different periods so the loop never reads as a metronome:
    # a breath twice over the 2.4 s, and one slow shift of weight from foot to
    # foot across the whole of it. Anything is better than the mannequin the
    # old idle was, whose only travel was a 0.8 mm pelvis nudge - and that
    # nudge was horizontal.
    def idle_pose(time: float) -> tuple[dict, dict]:
        breath = math.sin(math.tau * time / 1.2)
        weight = math.sin(math.tau * time / 2.4)
        settle = math.sin(math.tau * time / 2.4 - 0.9)
        overlay = {
            "spine_01": (breath * 1.1, weight * -0.9, weight * 1.2),
            "spine_02": (breath * -1.6, weight * -1.1, weight * 0.8),
            "chest": (breath * 1.9, weight * -1.0, weight * -1.4),
            "neck": (breath * -0.8, weight * 0.6, weight * -1.0),
            "head": (breath * -0.6 + settle * 0.8, weight * 1.0, settle * 3.5),
            "clavicle_l": (breath * 1.2, -breath * 0.8, 0.0),
            "clavicle_r": (breath * 1.2, breath * 0.8, 0.0),
            "upper_arm_l": (settle * 2.2, breath * -1.4 + weight * 1.0, 0.0),
            "upper_arm_r": (settle * 2.2, breath * 1.4 + weight * 1.0, 0.0),
            "forearm_l": (settle * 3.0, 0.0, 0.0),
            "forearm_r": (settle * -3.0, 0.0, 0.0),
            # The loaded leg straightens and the unloaded one softens: that,
            # not the breath, is what stops him reading as a shop dummy.
            "thigh_l": (weight * 1.4, weight * 0.8, 0.0),
            "thigh_r": (weight * -1.4, weight * 0.8, 0.0),
            "calf_l": (min(weight * 2.2, 3.5), 0.0, 0.0),
            "calf_r": (min(weight * -2.2, 3.5), 0.0, 0.0),
            "foot_l": (weight * -3.6, 0.0, 0.0),
            "foot_r": (weight * 3.6, 0.0, 0.0),
        }
        rotations = merge(STANDING, overlay)
        for suffix in ("l", "r"):
            calf = min(rotations[f"calf_{suffix}"][0], -0.5)
            rotations[f"calf_{suffix}"] = (calf, 0.0, 0.0)
        locations = {
            "pelvis": (
                weight * 0.013,
                breath * 0.0035 - abs(weight) * 0.004,
                breath * 0.002,
            )
        }
        return rotations, locations

    # Both feet are planted, so the solve just holds them there.
    make_action(rig, "idle-loop", 2.4, idle_pose, ground={
        "weight": window(0.0, 0.0, True), "minimum": -0.02, "maximum": 0.02,
    })

    # ---------------------------------------------------------------- walk
    def walk_pose(time: float) -> tuple[dict, dict]:
        rotations, locations = locomotion_pose(
            time / 0.8, WALK_THIGH, WALK_CALF, WALK_FOOT, WALK_TOE,
            WALK_ARM, WALK_FOREARM,
            lean=7.0, pelvis_lift=0.022, pelvis_lift_phase=0.25,
            pelvis_sway=0.016, pelvis_twist=5.0, pelvis_drop=3.5, spread=3.0,
        )
        return merge(STANDING, rotations), locations

    # A walk always has a foot down, so the solve runs the whole cycle and it,
    # not the authored cosine, decides the final hip height frame by frame.
    make_action(rig, "walk-loop", 0.8, walk_pose, ground={
        "weight": window(0.0, 0.0, True), "minimum": -0.06, "maximum": 0.09,
    })

    # ---------------------------------------------------------------- run
    # Running lands and rebounds rather than rolling: the pelvis is LOWEST over
    # each midstance as the leg absorbs, and highest through the flight phase,
    # which is the opposite of the walk. Hence the shifted lift phase.
    def run_pose(time: float) -> tuple[dict, dict]:
        rotations, locations = locomotion_pose(
            time / 0.56, RUN_THIGH, RUN_CALF, RUN_FOOT, RUN_TOE,
            RUN_ARM, RUN_FOREARM,
            lean=20.0, pelvis_lift=-0.040, pelvis_lift_phase=0.17,
            pelvis_sway=0.020, pelvis_twist=7.0, pelvis_drop=4.0, spread=2.0,
        )
        return merge(STANDING, rotations), locations

    # A run leaves the floor entirely, so the solve is only allowed to push the
    # hips UP out of a penetrating stance. Through the flight phase the legs
    # fold and the lowest sole rises on its own; a two-way solve would haul the
    # pelvis down after it and flatten the flight arc into a shuffle.
    make_action(rig, "run-loop", 0.56, run_pose, ground={
        "weight": window(0.0, 0.0, True), "minimum": 0.0, "maximum": 0.12,
    })

    # ---------------------------------------------------------------- jump
    # The controller only starts this clip once the body is already leaving the
    # ground, so it opens at the last instant of the push rather than on an
    # anticipation crouch, extends hard, then folds into a tuck.
    JUMP_SPINE = [(0.0, 16.0), (0.14, 2.0), (0.26, -6.0), (0.42, 4.0)]
    JUMP_THIGH_L = [(0.0, 30.0), (0.12, 6.0), (0.26, -6.0), (0.42, 38.0)]
    JUMP_THIGH_R = [(0.0, 26.0), (0.12, 2.0), (0.26, -10.0), (0.42, -14.0)]
    JUMP_CALF_L = [(0.0, -66.0), (0.14, -14.0), (0.26, -5.0), (0.42, -48.0)]
    JUMP_CALF_R = [(0.0, -62.0), (0.14, -10.0), (0.26, -4.0), (0.42, -26.0)]
    JUMP_FOOT_L = [(0.0, 14.0), (0.16, -20.0), (0.26, -28.0), (0.42, 8.0)]
    JUMP_FOOT_R = [(0.0, 12.0), (0.16, -22.0), (0.26, -30.0), (0.42, -12.0)]
    JUMP_ARM = [(0.0, -38.0), (0.16, 24.0), (0.26, 52.0), (0.42, 30.0)]

    def jump_pose(time: float) -> tuple[dict, dict]:
        lean = timed(JUMP_SPINE, time)
        arm = timed(JUMP_ARM, time)
        overlay = {
            "spine_01": (lean * 0.5, 0.0, 0.0),
            "spine_02": (lean * 0.3, 0.0, 0.0),
            "chest": (lean * 0.2, 0.0, 0.0),
            "head": (-lean * 0.5, 0.0, 0.0),
            "upper_arm_l": (arm, -10.0, 0.0),
            "upper_arm_r": (arm, 10.0, 0.0),
            "forearm_l": (26.0 + max(arm, 0.0) * 0.35, -4.0, 0.0),
            "forearm_r": (26.0 + max(arm, 0.0) * 0.35, 4.0, 0.0),
            "thigh_l": (timed(JUMP_THIGH_L, time), -2.0, 0.0),
            "thigh_r": (timed(JUMP_THIGH_R, time), 2.0, 0.0),
            "calf_l": (min(timed(JUMP_CALF_L, time), 0.0), 0.0, 0.0),
            "calf_r": (min(timed(JUMP_CALF_R, time), 0.0), 0.0, 0.0),
            "foot_l": (timed(JUMP_FOOT_L, time), 0.0, 0.0),
            "foot_r": (timed(JUMP_FOOT_R, time), 0.0, 0.0),
        }
        lift = timed([(0.0, -0.03), (0.16, 0.012), (0.26, 0.02), (0.42, 0.0)], time)
        return merge(STANDING, overlay), {"pelvis": (0.0, lift, 0.0)}

    make_action(rig, "jump", 0.42, jump_pose)

    # ------------------------------------------------------------ airborne
    def airborne_pose(time: float) -> tuple[dict, dict]:
        phase = time / 0.9
        cycle = math.sin(math.tau * phase)
        offset = math.sin(math.tau * phase + math.pi * 0.65)
        overlay = {
            "spine_01": (-2.0 + cycle * 2.5, 0.0, cycle * 2.0),
            "spine_02": (1.0, 0.0, cycle * -1.5),
            "chest": (1.0, 0.0, cycle * -1.0),
            "head": (2.0 - cycle * 1.5, 0.0, cycle * 2.5),
            "upper_arm_l": (-14.0 + cycle * 9.0, -22.0, 0.0),
            "upper_arm_r": (-12.0 - cycle * 9.0, 22.0, 0.0),
            "forearm_l": (34.0 + cycle * 8.0, -6.0, 0.0),
            "forearm_r": (30.0 - cycle * 8.0, 6.0, 0.0),
            "thigh_l": (18.0 + cycle * 12.0, -3.0, 0.0),
            "thigh_r": (10.0 + offset * 12.0, 3.0, 0.0),
            "calf_l": (-30.0 - max(cycle, 0.0) * 18.0, 0.0, 0.0),
            "calf_r": (-26.0 - max(offset, 0.0) * 18.0, 0.0, 0.0),
            "foot_l": (6.0 + cycle * 6.0, 0.0, 0.0),
            "foot_r": (2.0 + offset * 6.0, 0.0, 0.0),
        }
        locations = {"pelvis": (cycle * 0.004, offset * 0.006, 0.0)}
        return merge(STANDING, overlay), locations

    make_action(rig, "airborne-loop", 0.9, airborne_pose)

    # ------------------------------------------------------------ boarding
    # This is the clip the player was complaining about: "the animation turns
    # my legs the wrong way, it looks like my legs break to get in". The legs
    # were fixed; what was left was still a pose lerp from standing to seated,
    # a man folding in half on the spot. It is authored here as five beats of
    # someone climbing into a cockpit.
    #
    #   0.00-0.14  sink and reach - weight drops onto the trailing leg, the
    #              torso leans in, the near hand goes up for a grab handle
    #   0.14-0.36  step up - the leading foot lifts high onto the sill and the
    #              torso follows it forward over the new foothold
    #   0.36-0.58  weight transfer - the hips ride up to their highest and
    #              furthest forward, the trailing foot leaves the floor
    #   0.58-0.86  lower in - both knees come up as the hips descend past the
    #              standing height, and the hands come off the handle and down
    #   0.86-1.10  settle - the hips compress into the cushion and rebound, the
    #              torso rocks back a few degrees past its seated angle and
    #              comes forward again, the hands arrive last
    #
    # The hips must be back at their authored rest height by 1.10 exactly. The
    # seat anchor is a feet-frame marker - the cushion minus the 0.72 m the
    # PlayerController carries its hips at - so a pelvis left low or high here
    # would ride the seated pilot into or above the cushion, which is how a
    # previous pass put the Zenith pilot 0.47 m too high.
    BOARD_LIFT = [(0.00, 0.0), (0.14, -0.022), (0.36, 0.030), (0.58, 0.072),
                  (0.72, 0.040), (0.86, -0.030), (0.95, -0.045), (1.02, -0.006),
                  (1.10, 0.0)]
    BOARD_FORWARD = [(0.00, 0.0), (0.14, 0.010), (0.36, 0.048), (0.58, 0.090),
                     (0.78, 0.062), (0.95, 0.018), (1.10, 0.0)]
    BOARD_SIDE = [(0.00, 0.0), (0.14, -0.016), (0.36, -0.010), (0.58, 0.012),
                  (0.86, 0.004), (1.10, 0.0)]
    # Extra lean ON TOP of the standing -> seated blend, so it opens and closes
    # at zero: a torso that rides forward over the new foothold, comes up, then
    # rocks four degrees back past the seated angle before settling forward
    # onto it. That last rock is the follow-through the old pose lerp had none
    # of - the body arrives before it has finished moving.
    BOARD_LEAN = [(0.00, 0.0), (0.14, 13.0), (0.36, 22.0), (0.58, 17.0),
                  (0.78, 5.0), (0.90, -10.0), (1.00, 3.0), (1.10, 0.0)]
    BOARD_TWIST = [(0.00, 0.0), (0.20, -5.0), (0.48, -9.0), (0.70, -4.0),
                   (0.90, 1.5), (1.10, 0.0)]
    # Leading leg: the one that goes up onto the sill first.
    BOARD_THIGH_L = [(0.00, 1.0), (0.14, 14.0), (0.30, 74.0), (0.44, 62.0),
                     (0.58, 44.0), (0.74, 58.0), (0.90, 74.0), (1.10, 78.0)]
    BOARD_CALF_L = [(0.00, -4.0), (0.14, -22.0), (0.30, -88.0), (0.44, -72.0),
                    (0.58, -48.0), (0.74, -62.0), (0.90, -80.0), (1.10, -76.0)]
    BOARD_FOOT_L = [(0.00, 3.0), (0.14, 8.0), (0.30, 16.0), (0.50, 6.0),
                    (0.74, 12.0), (1.10, 18.0)]
    # Trailing leg: stays under him taking the load, then follows.
    BOARD_THIGH_R = [(0.00, 1.0), (0.14, 8.0), (0.30, 5.0), (0.46, 26.0),
                     (0.62, 58.0), (0.80, 72.0), (0.94, 80.0), (1.10, 78.0)]
    BOARD_CALF_R = [(0.00, -4.0), (0.14, -20.0), (0.30, -8.0), (0.46, -46.0),
                    (0.62, -76.0), (0.80, -84.0), (0.94, -72.0), (1.10, -76.0)]
    BOARD_FOOT_R = [(0.00, 3.0), (0.20, -14.0), (0.40, -6.0), (0.62, 10.0),
                    (0.86, 16.0), (1.10, 18.0)]
    # The reaching hand goes overhead onto a grab handle, takes load through the
    # step-up, then comes down to the armrest. Shoulder flexion runs past 100
    # degrees so the hand is genuinely above the helmet rather than pointing
    # out in front, which just reads as sleepwalking. The other arm swings back
    # and out for balance and arrives on its armrest last.
    BOARD_ARM_R = [(0.00, 2.0), (0.14, 62.0), (0.32, 104.0), (0.52, 96.0),
                   (0.70, 46.0), (0.88, -4.0), (1.00, 24.0), (1.10, 30.0)]
    BOARD_ABDUCT_R = [(0.00, 7.0), (0.14, 22.0), (0.32, 26.0), (0.58, 20.0),
                      (0.82, 8.0), (1.10, 12.0)]
    BOARD_FOREARM_R = [(0.00, 14.0), (0.14, 52.0), (0.32, 34.0), (0.52, 74.0),
                       (0.74, 52.0), (0.94, 76.0), (1.10, 62.0)]
    BOARD_ARM_L = [(0.00, 2.0), (0.16, -26.0), (0.36, -34.0), (0.58, -10.0),
                   (0.78, 14.0), (0.94, 40.0), (1.04, 26.0), (1.10, 30.0)]
    BOARD_ABDUCT_L = [(0.00, -7.0), (0.20, -24.0), (0.44, -26.0), (0.72, -14.0),
                      (0.94, -8.0), (1.10, -12.0)]
    BOARD_FOREARM_L = [(0.00, 14.0), (0.16, 30.0), (0.40, 22.0), (0.62, 40.0),
                       (0.86, 66.0), (1.00, 56.0), (1.10, 62.0)]
    # How far through "standing" -> "seated" the un-tabled channels are. Held
    # near zero while he is still climbing so the settle happens late and fast.
    BOARD_SEATED = [(0.00, 0.0), (0.30, 0.04), (0.58, 0.22), (0.80, 0.62),
                    (0.95, 0.94), (1.10, 1.0)]

    def boarding_pose(time: float) -> tuple[dict, dict]:
        lean = timed(BOARD_LEAN, time)
        twist = timed(BOARD_TWIST, time)
        # Everything not driven by a table below rides a plain standing ->
        # seated blend. That is what makes the last frame of this clip EXACTLY
        # the first frame of seated_control, on every channel, rather than
        # nearly so; the two are checked against each other before export.
        rotations = blend_pose(STANDING, SEATED, timed(BOARD_SEATED, time))
        spine = {
            "pelvis": (0.0, 0.0, twist * 0.55),
            "spine_01": (lean * 0.42, 0.0, twist * 0.2),
            "spine_02": (lean * 0.30, 0.0, twist * 0.2),
            "chest": (lean * 0.24, 0.0, twist * 0.2),
            "neck": (-lean * 0.30, 0.0, twist * -0.3),
            "head": (-lean * 0.40, 0.0, twist * -0.6),
        }
        rotations = merge(rotations, spine)
        with_swing(rotations, "thigh_l", timed(BOARD_THIGH_L, time))
        with_swing(rotations, "thigh_r", timed(BOARD_THIGH_R, time))
        with_swing(rotations, "calf_l", timed(BOARD_CALF_L, time))
        with_swing(rotations, "calf_r", timed(BOARD_CALF_R, time))
        with_swing(rotations, "foot_l", timed(BOARD_FOOT_L, time))
        with_swing(rotations, "foot_r", timed(BOARD_FOOT_R, time))
        with_swing(rotations, "forearm_l", timed(BOARD_FOREARM_L, time))
        with_swing(rotations, "forearm_r", timed(BOARD_FOREARM_R, time))
        rotations["upper_arm_l"] = (
            timed(BOARD_ARM_L, time), timed(BOARD_ABDUCT_L, time), 0.0
        )
        rotations["upper_arm_r"] = (
            timed(BOARD_ARM_R, time), timed(BOARD_ABDUCT_R, time), 0.0
        )
        # A reaching shoulder rides up with the arm, but only by how far the arm
        # has left its own blended base, so both ends of the clip stay exact.
        for suffix, table in (("l", BOARD_ARM_L), ("r", BOARD_ARM_R)):
            base_arm = blend_pose(STANDING, SEATED, timed(BOARD_SEATED, time))
            shrug = (timed(table, time) - base_arm[f"upper_arm_{suffix}"][0]) * 0.10
            clavicle = rotations[f"clavicle_{suffix}"]
            rotations[f"clavicle_{suffix}"] = (
                clavicle[0] + shrug, clavicle[1], clavicle[2]
            )
        locations = {
            "pelvis": (
                timed(BOARD_SIDE, time),
                timed(BOARD_LIFT, time),
                timed(BOARD_FORWARD, time),
            )
        }
        return seat_transition_pose(rotations), locations

    make_action(rig, "boarding", 1.1, boarding_pose, ground={
        "weight": window(0.18, 0.42, False), "minimum": -0.04, "maximum": 0.14,
    })

    # ------------------------------------------------- seated flight controls
    # Held exactly on the boarding end pose from the waist down so the seat is
    # rock steady, with breathing and small control corrections on three
    # different periods above it, so the loop never beats in time with itself.
    def seated_pose(time: float) -> tuple[dict, dict]:
        breath = math.sin(math.tau * time / 1.2)
        scan = math.sin(math.tau * time / 2.4)
        stick = math.sin(math.tau * time / 0.8)
        overlay = {
            "spine_01": (breath * 0.9, 0.0, scan * 0.8),
            "spine_02": (breath * -1.4, 0.0, scan * 0.6),
            "chest": (breath * 1.7, scan * -0.7, scan * -1.0),
            "neck": (breath * -0.7, scan * 0.4, scan * -1.6),
            "head": (scan * -1.2, scan * 0.8, scan * 4.5),
            "clavicle_l": (breath * 1.0, -breath * 0.6, 0.0),
            "clavicle_r": (breath * 1.0, breath * 0.6, 0.0),
            "upper_arm_l": (stick * 1.6, breath * -1.0, 0.0),
            "upper_arm_r": (stick * -1.4, breath * 1.0, 0.0),
            "forearm_l": (stick * 3.5, stick * -2.0, 0.0),
            "forearm_r": (stick * -4.0, stick * 2.0, 0.0),
            "hand_l": (stick * 4.0, 0.0, stick * 3.0),
            "hand_r": (stick * -3.5, 0.0, stick * -3.0),
        }
        locations = {"pelvis": (0.0, breath * 0.002, 0.0)}
        return merge(SEATED, overlay), locations

    make_action(rig, "seated_control-loop", 2.4, seated_pose)

    # --------------------------------------------------- disembark recovery
    # Boarding run backwards is not the same move: getting out is a push, a
    # step down and a landing, so the hips lead and the feet catch up.
    OUT_LIFT = [(0.00, 0.0), (0.12, -0.012), (0.34, 0.046), (0.52, 0.058),
                (0.68, -0.022), (0.80, 0.006), (0.90, 0.0)]
    OUT_FORWARD = [(0.00, 0.0), (0.14, 0.026), (0.36, 0.070), (0.56, 0.048),
                   (0.74, 0.014), (0.90, 0.0)]
    OUT_LEAN = [(0.00, 0.0), (0.16, 16.0), (0.36, 21.0), (0.54, 9.0),
                (0.68, 7.0), (0.80, -6.0), (0.90, 0.0)]
    OUT_THIGH_L = [(0.00, 78.0), (0.16, 66.0), (0.34, 34.0), (0.52, 16.0),
                   (0.68, 8.0), (0.90, 1.0)]
    OUT_CALF_L = [(0.00, -76.0), (0.16, -70.0), (0.34, -44.0), (0.52, -26.0),
                  (0.68, -28.0), (0.80, -10.0), (0.90, -4.0)]
    OUT_FOOT_L = [(0.00, 18.0), (0.24, 10.0), (0.52, 6.0), (0.68, 2.0), (0.90, 3.0)]
    OUT_THIGH_R = [(0.00, 78.0), (0.16, 72.0), (0.34, 52.0), (0.52, 24.0),
                   (0.70, 12.0), (0.90, 1.0)]
    OUT_CALF_R = [(0.00, -76.0), (0.16, -78.0), (0.34, -64.0), (0.52, -34.0),
                  (0.70, -22.0), (0.82, -8.0), (0.90, -4.0)]
    OUT_FOOT_R = [(0.00, 18.0), (0.28, 14.0), (0.52, 8.0), (0.70, 1.0), (0.90, 3.0)]
    OUT_ARM = [(0.00, 30.0), (0.14, -14.0), (0.34, -34.0), (0.54, -16.0),
               (0.72, 8.0), (0.90, 2.0)]
    OUT_ABDUCT = [(0.00, 12.0), (0.18, 24.0), (0.44, 26.0), (0.68, 12.0),
                  (0.90, 7.0)]
    OUT_FOREARM = [(0.00, 62.0), (0.14, 40.0), (0.34, 30.0), (0.56, 24.0),
                   (0.74, 18.0), (0.90, 14.0)]
    OUT_STANDING = [(0.00, 0.0), (0.22, 0.16), (0.46, 0.58), (0.68, 0.88),
                    (0.90, 1.0)]

    def disembark_pose(time: float) -> tuple[dict, dict]:
        lean = timed(OUT_LEAN, time)
        arm = timed(OUT_ARM, time)
        abduct = timed(OUT_ABDUCT, time)
        forearm = timed(OUT_FOREARM, time)
        rotations = blend_pose(SEATED, STANDING, timed(OUT_STANDING, time))
        spine = {
            "spine_01": (lean * 0.42, 0.0, 0.0),
            "spine_02": (lean * 0.30, 0.0, 0.0),
            "chest": (lean * 0.24, 0.0, 0.0),
            "neck": (-lean * 0.30, 0.0, 0.0),
            "head": (-lean * 0.42, 0.0, 0.0),
        }
        rotations = merge(rotations, spine)
        with_swing(rotations, "thigh_l", timed(OUT_THIGH_L, time))
        with_swing(rotations, "thigh_r", timed(OUT_THIGH_R, time))
        with_swing(rotations, "calf_l", timed(OUT_CALF_L, time))
        with_swing(rotations, "calf_r", timed(OUT_CALF_R, time))
        with_swing(rotations, "foot_l", timed(OUT_FOOT_L, time))
        with_swing(rotations, "foot_r", timed(OUT_FOOT_R, time))
        with_swing(rotations, "forearm_l", forearm)
        with_swing(rotations, "forearm_r", forearm)
        rotations["upper_arm_l"] = (arm, -abduct, 0.0)
        rotations["upper_arm_r"] = (arm, abduct, 0.0)
        base = blend_pose(SEATED, STANDING, timed(OUT_STANDING, time))
        for suffix in ("l", "r"):
            shrug = (arm - base[f"upper_arm_{suffix}"][0]) * 0.10
            clavicle = rotations[f"clavicle_{suffix}"]
            rotations[f"clavicle_{suffix}"] = (
                clavicle[0] + shrug, clavicle[1], clavicle[2]
            )
        locations = {
            "pelvis": (0.0, timed(OUT_LIFT, time), timed(OUT_FORWARD, time))
        }
        return seat_transition_pose(rotations), locations

    assert_pose_matches(
        "boarding must start standing", boarding_pose(0.0),
        (seat_transition_pose(dict(STANDING)), {"pelvis": (0.0, 0.0, 0.0)}),
    )
    assert_pose_matches(
        "boarding must hand over to seated_control",
        boarding_pose(1.1), seated_pose(0.0),
    )
    assert_pose_matches(
        "disembark_recovery must take over from seated_control",
        disembark_pose(0.0), seated_pose(0.0),
    )
    assert_pose_matches(
        "disembark_recovery must finish standing", disembark_pose(0.9),
        (seat_transition_pose(dict(STANDING)), {"pelvis": (0.0, 0.0, 0.0)}),
    )

    # Every boarding/exit beat is one-shot data.  Keep the beat order strict so
    # Catmull-Rom cannot skip an authored event or introduce an accidental
    # duplicate timestamp while preserving the existing hand-off assertions.
    for label, table in (
        ("BOARD_LIFT", BOARD_LIFT),
        ("BOARD_FORWARD", BOARD_FORWARD),
        ("BOARD_SIDE", BOARD_SIDE),
        ("BOARD_LEAN", BOARD_LEAN),
        ("BOARD_TWIST", BOARD_TWIST),
        ("BOARD_THIGH_L", BOARD_THIGH_L),
        ("BOARD_CALF_L", BOARD_CALF_L),
        ("BOARD_FOOT_L", BOARD_FOOT_L),
        ("BOARD_THIGH_R", BOARD_THIGH_R),
        ("BOARD_CALF_R", BOARD_CALF_R),
        ("BOARD_FOOT_R", BOARD_FOOT_R),
        ("BOARD_ARM_R", BOARD_ARM_R),
        ("BOARD_ABDUCT_R", BOARD_ABDUCT_R),
        ("BOARD_FOREARM_R", BOARD_FOREARM_R),
        ("BOARD_ARM_L", BOARD_ARM_L),
        ("BOARD_ABDUCT_L", BOARD_ABDUCT_L),
        ("BOARD_FOREARM_L", BOARD_FOREARM_L),
        ("BOARD_SEATED", BOARD_SEATED),
    ):
        assert_timing_table(label, table, 1.1)
    for label, table in (
        ("OUT_LIFT", OUT_LIFT),
        ("OUT_FORWARD", OUT_FORWARD),
        ("OUT_LEAN", OUT_LEAN),
        ("OUT_THIGH_L", OUT_THIGH_L),
        ("OUT_CALF_L", OUT_CALF_L),
        ("OUT_FOOT_L", OUT_FOOT_L),
        ("OUT_THIGH_R", OUT_THIGH_R),
        ("OUT_CALF_R", OUT_CALF_R),
        ("OUT_FOOT_R", OUT_FOOT_R),
        ("OUT_ARM", OUT_ARM),
        ("OUT_ABDUCT", OUT_ABDUCT),
        ("OUT_FOREARM", OUT_FOREARM),
        ("OUT_STANDING", OUT_STANDING),
    ):
        assert_timing_table(label, table, 0.9)

    make_action(rig, "disembark_recovery", 0.9, disembark_pose, ground={
        "weight": window(0.56, 0.78, True), "minimum": -0.04, "maximum": 0.14,
    })
    reset_pose(rig)


# Boarding and disembark are measured in the shipped GLB for two invariants a
# spline can violate between the keys that satisfy it: a knee may never fold
# forwards, and a knee may never swing behind its hip. Catmull-Rom is used for
# the overshoot it gives a settle, and overshoot is exactly what could dip a
# thigh below zero on the way to a key that is above it. These floors are the
# guard's invariant written where the poses are made, not a fixup downstream.
SEAT_TRANSITION_MINIMUM_HIP_FLEXION = 0.75
SEAT_TRANSITION_MAXIMUM_KNEE_EXTENSION = -0.5


def assert_pose_matches(label: str, first: tuple, second: tuple) -> None:
    """Fail the build if two clips do not join up on every channel.

    boarding has to hand over to seated_control, and disembark_recovery has to
    take over from it, without a frame of pop. Both transitions are stitched
    from a standing -> seated blend plus per-bone tables, and it is very easy
    to leave one table ending a couple of degrees off and never see it in a
    still. Checked here rather than trusted.
    """
    channels = ("swing/side", "abduct/lift", "twist/forward")
    for part, (source, target, tolerance) in enumerate(
        ((first[0], second[0], 0.01), (first[1], second[1], 1e-6))
    ):
        kind = "rotation" if part == 0 else "location"
        for name in sorted(set(source) | set(target)):
            left = source.get(name, (0.0, 0.0, 0.0))
            right = target.get(name, (0.0, 0.0, 0.0))
            for axis in range(3):
                if abs(left[axis] - right[axis]) > tolerance:
                    raise RuntimeError(
                        f"{label}: {name} {kind} {channels[axis]} does not join "
                        f"up ({left[axis]:.4f} vs {right[axis]:.4f})"
                    )


def seat_transition_pose(rotations: dict) -> dict:
    rotations = dict(rotations)
    for suffix in ("l", "r"):
        thigh = rotations[f"thigh_{suffix}"]
        calf = rotations[f"calf_{suffix}"]
        rotations[f"thigh_{suffix}"] = (
            max(thigh[0], SEAT_TRANSITION_MINIMUM_HIP_FLEXION), thigh[1], thigh[2]
        )
        rotations[f"calf_{suffix}"] = (
            min(calf[0], SEAT_TRANSITION_MAXIMUM_KNEE_EXTENSION), calf[1], calf[2]
        )
    return rotations


def key_pose(
    rig: bpy.types.Object,
    frame: float,
    rotations: dict[str, tuple[float, float, float]] | None = None,
    locations: dict[str, tuple[float, float, float]] | None = None,
    insert: bool = True,
) -> None:
    reset_pose(rig)
    rotations = rotations or {}
    locations = locations or {}
    for name, degrees in rotations.items():
        rig.pose.bones[name].rotation_euler = tuple(
            math.radians(value) for value in bone_local_euler_degrees(name, degrees)
        )
    for name, offset in locations.items():
        rig.pose.bones[name].location = bone_local_location(name, offset)

    if not insert:
        # Pose applied only so the weight-bearing solve can measure it.
        return

    # Root keys are deliberately invariant. The exported motion can deform the
    # suit, but never owns horizontal traversal or yaw.
    keyed_bones = set(rotations) | set(locations) | {"root"}
    for name in keyed_bones:
        bone = rig.pose.bones[name]
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        bone.keyframe_insert(data_path="location", frame=frame, group=name)


# --------------------------------------------------------------------------
# Ground contact
# --------------------------------------------------------------------------
#
# The corners of the authored boot sole, and the bone each one is carried by.
# `BootSole` is built as a 0.19 x 0.38 x 0.05 box centred on (x, -.105, .025),
# so its underside is exactly the z = 0 standing ground plane.
SOLE_WITNESSES = (
    ("foot_%s", 0.085, 0.0),
    ("foot_%s", -0.16, 0.0),
    ("toe_%s", -0.295, 0.0),
)


def lowest_sole(rig: bpy.types.Object) -> float:
    """Height of the lowest boot-sole corner in the currently applied pose."""
    bpy.context.view_layer.update()
    lowest = math.inf
    for side, x in (("l", -0.14), ("r", 0.14)):
        for template, y, z in SOLE_WITNESSES:
            name = template % side
            deformed = (
                rig.pose.bones[name].matrix
                @ rig.data.bones[name].matrix_local.inverted()
                @ Vector((x, y, z))
            )
            lowest = min(lowest, deformed.z)
    return lowest


def make_action(
    rig: bpy.types.Object,
    name: str,
    duration: float,
    pose_at,
    ground=None,
) -> None:
    """Sample one authored clip onto source frames and key it LINEAR.

    Every sampled frame carries the same bone set, so no curve is left to
    interpolate across a gap, and a cycle whose tables wrap closes on itself
    exactly. A RESET action with a single bind key is valid source data.

    `ground` is the weight-bearing solve. Where it is active, the frame is
    posed once, the lowest boot-sole corner is measured on the real deformed
    rig, and the pelvis is raised or lowered by that much before the frame is
    keyed - so the stance foot sits on the floor and the pelvis's vertical
    travel is a CONSEQUENCE of the leg poses rather than a cosine guessed to
    look about right. It is a solve over the authored pose, in the generator,
    at author time; it is not a runtime correction and it never touches
    anything downstream of this file. The clips that leave the floor - jump,
    airborne, the middle of boarding, the seat itself - opt out by window.
    """
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    last_frame = int(round(duration * FPS))
    frames = list(range(0, last_frame + 1, KEY_STRIDE)) or [0]
    if frames[-1] != last_frame:
        frames.append(last_frame)
    for frame in frames:
        time = frame / FPS
        rotations, locations = pose_at(time)
        if ground is not None:
            weight = ground["weight"](time)
            if weight > 0.0:
                key_pose(rig, frame, rotations, locations, insert=False)
                correction = max(
                    ground["minimum"],
                    min(ground["maximum"], -lowest_sole(rig)),
                )
                side, lift, forward = locations.get("pelvis", (0.0, 0.0, 0.0))
                locations = dict(locations)
                locations["pelvis"] = (side, lift + correction * weight, forward)
        key_pose(rig, frame, rotations, locations)
    for curve in action.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "LINEAR"
    rig.animation_data.action = None




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
    # Anatomical authoring reads every bone's rest frame off the built rig, so
    # this must happen before a single pose is keyed.
    capture_rest_frames(rig)
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
                "anatomical degrees (swing, abduct, twist), swing positive "
                "towards the face for every bone; converted into bone-local "
                "euler from each bone's own rest matrix, so an up-pointing "
                "spine, a down-pointing leg chain and the out-of-plane arm "
                "chain all obey one convention"
            ),
            "pelvis_translation_axes": (
                "authored (side, lift, forward) in metres and converted through "
                "the pelvis rest matrix; local Z is world -Y, so keying lift "
                "into local Z slides the hips forward instead of raising them"
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
