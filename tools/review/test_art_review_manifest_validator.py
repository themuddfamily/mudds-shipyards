import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.review.art_review_manifest_validator import validate


class ArtReviewManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "berth.png").write_bytes(b"capture")

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        digest = hashlib.sha256(b"capture").hexdigest()
        value = {"schema": "art_review_manifest_v1", "human_review_status": "pending",
                 "reviewer_required": "art director", "rubric": ["composition", "materials"],
                 "captures": [{"path": "berth.png", "sha256": digest, "viewpoint": "central berth"}]}
        value.update(changes)
        path = self.root / "review.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_manifest_is_only_handoff_ready(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_human_approval_is_rejected(self):
        errors = validate(self.manifest(human_review_status="approved"))
        self.assertTrue(any("cannot claim human approval" in error for error in errors))

    def test_tampered_capture_fails(self):
        path = self.manifest()
        (self.root / "berth.png").write_bytes(b"changed")
        self.assertTrue(any("SHA-256" in error for error in validate(path)))

    def test_missing_viewpoint_and_duplicate_rubric_fail(self):
        capture = {"path": "berth.png", "sha256": hashlib.sha256(b"capture").hexdigest()}
        errors = validate(self.manifest(rubric=["composition", "composition"], captures=[capture]))
        self.assertTrue(any("duplicate criteria" in error for error in errors))
        self.assertTrue(any("viewpoint is required" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
