import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from .native_capture_evidence_manifest import validate


class NativeCaptureEvidenceManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.frame = self.root / "frame.png"
        self.frame.write_bytes(b"native-frame")

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        digest = hashlib.sha256(self.frame.read_bytes()).hexdigest()
        data = {
            "schema": "native_capture_evidence_manifest_v1",
            "human_review_status": "pending",
            "target": {"os": "Windows", "architecture": "x86_64", "build_identity": "build-42",
                       "gpu": "RTX test", "driver": "555.1", "capture_method": "native_windows"},
            "camera_lock": {"stable": True, "position": [1, 2, 3], "rotation": [0, 0, 0],
                            "fov": 65, "projection": "perspective", "profile": "hero-wide"},
            "captures": [{"path": "frame.png", "sha256": digest, "viewpoint": "hero shot",
                          "camera_lock_profile": "hero-wide"}],
        }
        data.update(changes)
        path = self.root / "manifest.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_valid_native_handoff(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_hash_tampering_fails(self):
        path = self.manifest()
        self.frame.write_bytes(b"tampered")
        self.assertTrue(any("SHA-256" in error for error in validate(path)))

    def test_native_provenance_required(self):
        path = self.manifest(target={"os": "Linux"})
        errors = validate(path)
        self.assertIn("target.os must be Windows", errors)
        self.assertTrue(any("native provenance" in error for error in errors))

    def test_unstable_camera_fails(self):
        path = self.manifest(camera_lock={"stable": False})
        self.assertIn("camera_lock.stable must be true", validate(path))

    def test_approval_is_not_claimed(self):
        path = self.manifest(human_review_status="approved")
        self.assertIn("human_review_status must remain pending or not_performed", validate(path))

    def test_path_escape_fails(self):
        path = self.manifest(captures=[{"path": "../outside.png", "sha256": "0" * 64,
                                      "viewpoint": "shot", "camera_lock_profile": "hero-wide"}])
        self.assertTrue(any("escapes manifest directory" in error for error in validate(path)))


if __name__ == "__main__":
    unittest.main()
