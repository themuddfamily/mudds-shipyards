import unittest

from tools.review.planetary_hazard_landmark_visual_digest_review_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_hazard_landmark_visual_digest_review_v1", "world_id": "ember_moon", "landmark_id": "relay_hazard", "source_revision": "2230460",
        "visual_digest": {"capture_path": "res://docs/evidence/relay_hazard.png", "sha256": "b" * 64, "status": "pending"},
        "review": {"silhouette": "marker remains visible", "route_readability": "route remains traceable", "hazard_legibility": "hazard reads at distance", "status": "not_performed"},
        "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["digest_verification", "native_render", "human_signoff"],
    }


class PlanetaryHazardLandmarkVisualDigestReviewLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_capture_path_is_res_path(self):
        item = ledger(); item["visual_digest"]["capture_path"] = "capture.png"
        self.assertTrue(any("res://" in error for error in validate_ledger(item)))

    def test_digest_is_strict(self):
        item = ledger(); item["visual_digest"]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_ledger(item)))

    def test_digest_status_stays_open(self):
        item = ledger(); item["visual_digest"]["status"] = "PASS"
        self.assertTrue(any("visual_digest.status" in error for error in validate_ledger(item)))

    def test_review_rubric_is_required(self):
        item = ledger(); item["review"]["hazard_legibility"] = ""
        self.assertTrue(any("hazard_legibility" in error for error in validate_ledger(item)))

    def test_review_stays_open(self):
        item = ledger(); item["review"]["status"] = "approved"
        self.assertTrue(any("review.status" in error for error in validate_ledger(item)))

    def test_native_gate_stays_open(self):
        item = ledger(); item["native_render"]["status"] = "PASS"
        self.assertTrue(any("native_render" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
