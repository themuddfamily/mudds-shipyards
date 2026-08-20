import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.review.five_berth_capture_manifest_validator import validate


class FiveBerthCaptureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for berth in ("central", "aft", "habitat", "freight", "fleet_dock"):
            (self.root / f"{berth}.png").write_bytes(berth.encode())

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        captures = []
        for berth in ("central", "aft", "habitat", "freight", "fleet_dock"):
            path = self.root / f"{berth}.png"
            captures.append({"berth": berth, "path": path.name,
                             "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                             "viewpoint": f"{berth} berth approach", "source_current": True,
                             "source_revision": "abc123"})
        value = {"schema": "five_berth_capture_manifest_v1", "source_revision": "abc123",
                 "human_review_status": "pending", "reviewer_required": "art director",
                 "captures": captures}
        value.update(changes)
        path = self.root / "manifest.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_five_berth_handoff(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_missing_berth_and_stale_source_fail(self):
        path = self.manifest(captures=[])
        errors = validate(path)
        self.assertTrue(any("exactly five" in e for e in errors))
        path = self.manifest()
        data = json.loads(path.read_text())
        data["captures"][0]["source_current"] = False
        path.write_text(json.dumps(data))
        self.assertTrue(any("source_current" in e for e in validate(path)))

    def test_tamper_duplicate_and_approval_fail(self):
        path = self.manifest(human_review_status="approved")
        data = json.loads(path.read_text())
        data["captures"][1]["berth"] = "central"
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("pending" in e for e in errors))
        self.assertTrue(any("duplicate berth" in e for e in errors))
        (self.root / "central.png").write_bytes(b"tampered")
        self.assertTrue(any("SHA-256" in e for e in validate(path)))


if __name__ == "__main__":
    unittest.main()
