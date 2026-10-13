"""Direct regression checks for the offline pilot export's triangle ordering."""
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
from types import ModuleType
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools/blender/generate_pilot_motion_v2.py"


def load_generator():
    # The binary postprocessing has no DCC dependency. Stub only imports so the
    # same production function is exercised on machines without Blender.
    mathutils = ModuleType("mathutils")
    mathutils.Matrix = object
    mathutils.Vector = object
    with patch.dict(sys.modules, {"bpy": ModuleType("bpy"), "mathutils": mathutils}):
        spec = importlib.util.spec_from_file_location("pilot_generator", GENERATOR)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module


def glb(triangles, component_type):
    component = {5121: "B", 5123: "H", 5125: "I"}[component_type]
    indices = struct.pack("<" + component * (3 * len(triangles)), *(v for t in triangles for v in t))
    # Prefix/suffix stand in for vertex and animation data in shared binary storage.
    binary = b"VERT" + indices + b"ANIM"
    binary += b"\0" * (-len(binary) % 4)
    document = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [{"buffer": 0, "byteOffset": 4, "byteLength": len(indices)}],
        "accessors": [{"bufferView": 0, "componentType": component_type, "count": len(triangles) * 3, "type": "SCALAR"}],
        "meshes": [{"primitives": [{"indices": 0}]}],
    }
    document_bytes = json.dumps(document).encode()
    document_bytes += b" " * (-len(document_bytes) % 4)
    data = struct.pack("<4sII", b"glTF", 2, 28 + len(document_bytes) + len(binary))
    data += struct.pack("<II", len(document_bytes), 0x4E4F534A) + document_bytes
    data += struct.pack("<II", len(binary), 0x004E4942) + binary
    return data, 28 + len(document_bytes) + 4, len(indices)


class PilotTriangleOrderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generator = load_generator()

    def test_order_is_stable_preserving_winding_duplicates_and_other_bytes(self):
        original = [(4, 2, 1), (3, 7, 5), (1, 4, 2), (1, 2, 4)]
        reordered = [(5, 3, 7), (2, 1, 4), (4, 2, 1), (2, 4, 1)]
        canonical = lambda t: min(t, t[1:] + t[:1], t[2:] + t[:2])
        for component_type in (5121, 5123, 5125):
            with self.subTest(component_type=component_type), tempfile.TemporaryDirectory() as temp:
                outputs = []
                for i, triangles in enumerate((original, reordered)):
                    before, offset, size = glb(triangles, component_type)
                    path = Path(temp) / f"{i}.glb"
                    path.write_bytes(before)
                    self.generator.canonicalize_glb_triangle_indices(path)
                    after = path.read_bytes()
                    self.assertEqual(before[:offset], after[:offset])
                    self.assertEqual(before[offset + size:], after[offset + size:])
                    component = {5121: "B", 5123: "H", 5125: "I"}[component_type]
                    indices = struct.unpack_from("<" + component * (3 * len(triangles)), after, offset)
                    actual = list(zip(*[iter(indices)] * 3))
                    self.assertEqual(Counter(map(canonical, triangles)), Counter(actual))
                    self.assertNotEqual(canonical((1, 2, 4)), canonical((1, 4, 2)))
                    self.generator.canonicalize_glb_triangle_indices(path)
                    self.assertEqual(after, path.read_bytes())
                    outputs.append(after)
                self.assertEqual(outputs[0], outputs[1])

    def test_manifest_pins_current_generator(self):
        manifest = json.loads((ROOT / "assets/models/pilot/pilot_motion_v2_asset_manifest.json").read_text())
        self.assertEqual(manifest["generator_sha256"], hashlib.sha256(GENERATOR.read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
