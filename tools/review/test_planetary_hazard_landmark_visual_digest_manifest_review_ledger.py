import unittest

from tools.review.planetary_hazard_landmark_visual_digest_manifest_review_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_manifest_review_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "c2e8d93", "reviewer_role": "art-reviewer",
        "entries": [{"id": "hazard", "sha256": "a" * 64, "review_question": "hazard reads", "reviewer_note": "pending visual inspection", "status": "pending"}, {"id": "route", "sha256": "b" * 64, "review_question": "route reads", "reviewer_note": "capture not yet inspected", "status": "not_performed"}],
        "aggregate_review": {"status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["manifest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardLandmarkVisualDigestManifestReviewLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_entry_ids_are_unique(self):
        item = ledger(); item["entries"].append(dict(item["entries"][0]))
        self.assertTrue(any("unique" in error for error in validate_ledger(item)))

    def test_entry_digest_is_strict(self):
        item = ledger(); item["entries"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_ledger(item)))

    def test_review_question_and_note_are_required(self):
        item = ledger(); item["entries"][0]["reviewer_note"] = ""
        self.assertTrue(any("reviewer_note" in error for error in validate_ledger(item)))

    def test_entry_status_stays_open(self):
        item = ledger(); item["entries"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_ledger(item)))

    def test_aggregate_review_stays_open(self):
        item = ledger(); item["aggregate_review"]["status"] = "complete"
        self.assertTrue(any("aggregate_review" in error for error in validate_ledger(item)))

    def test_native_gate_stays_open(self):
        item = ledger(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
