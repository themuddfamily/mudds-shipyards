import json
import tempfile
import unittest
from pathlib import Path

from tools.review.final_visual_review_bundle_validator import validate


class FinalVisualReviewBundleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        value = {
            "schema": "final_visual_review_bundle_v1",
            "source_revision": "abc123",
            "human_review_status": "pending",
            "reviewer_required": "art director and gameplay QA",
            "viewpoints": [{"id": ident, "capture": f"captures/{ident}.png",
                            "acceptance": "inspect framing, readability, and authored detail",
                            "notes": "record issue IDs here", "review_status": "pending"}
                           for ident in ("station", "cockpit", "combat", "landing", "disembark")],
        }
        value.update(changes)
        path = self.root / "bundle.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_complete_bundle_is_ready_for_human_review(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_missing_viewpoint_is_rejected(self):
        path = self.manifest()
        data = json.loads(path.read_text())
        data["viewpoints"] = data["viewpoints"][:-1]
        path.write_text(json.dumps(data))
        self.assertTrue(any("required viewpoints missing" in e for e in validate(path)))

    def test_approval_cannot_be_automated(self):
        self.assertTrue(any("cannot claim approval" in e for e in validate(self.manifest(human_review_status="approved"))))

    def test_duplicate_and_unknown_viewpoints_fail(self):
        path = self.manifest()
        data = json.loads(path.read_text())
        data["viewpoints"][0]["id"] = "unknown"
        data["viewpoints"][1]["id"] = "station"
        data["viewpoints"][2]["id"] = "station"
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("one of" in e for e in errors))
        self.assertTrue(any("duplicate id" in e for e in errors))

    def test_empty_acceptance_and_invalid_status_fail(self):
        path = self.manifest()
        data = json.loads(path.read_text())
        data["viewpoints"][0]["acceptance"] = ""
        data["viewpoints"][0]["review_status"] = "approved"
        path.write_text(json.dumps(data))
        errors = validate(path)
        self.assertTrue(any("acceptance" in e for e in errors))
        self.assertTrue(any("review_status" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
