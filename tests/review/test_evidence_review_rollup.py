import json
import tempfile
import unittest
from pathlib import Path

from tools.review.evidence_review_rollup import validate


class EvidenceReviewRollupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "rollup.json"

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self):
        return {
            "schema": "evidence_review_rollup_v1",
            "roadmap_items": [582, 625, 627, 967],
            "source_revision": "working-tree-review",
            "reviewer_required": "art director and gameplay QA",
            "areas": {
                area: {"status": "pending", "evidence": f"{area} handoff", "notes": "record findings"}
                for area in ("capture", "source", "art", "human_review")
            },
        }

    def write(self, data):
        self.path.write_text(json.dumps(data), encoding="utf-8")

    def test_complete_rollup_is_handoff_ready(self):
        self.write(self.manifest())
        self.assertEqual(validate(self.path), [])

    def test_missing_area_and_bad_status_fail(self):
        data = self.manifest()
        del data["areas"]["source"]
        data["areas"]["capture"]["status"] = "approved"
        self.write(data)
        errors = validate(self.path)
        self.assertTrue(any("areas missing" in error for error in errors))
        self.assertTrue(any("status must be" in error for error in errors))

    def test_rollup_rejects_approval_language(self):
        data = self.manifest()
        data["areas"]["art"]["decision"] = "signed-off"
        self.write(data)
        self.assertTrue(any("cannot claim approval" in error for error in validate(self.path)))

    def test_duplicate_item_and_empty_evidence_fail(self):
        data = self.manifest()
        data["roadmap_items"] = [582, 582]
        data["areas"]["human_review"]["evidence"] = ""
        self.write(data)
        errors = validate(self.path)
        self.assertTrue(any("duplicate" in error for error in errors))
        self.assertTrue(any("evidence" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
