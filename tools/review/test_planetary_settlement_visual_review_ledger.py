import unittest

from tools.review.planetary_settlement_visual_review_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_settlement_visual_review_v1", "world_id": "ember_moon", "settlement_id": "caldera_staging", "source_revision": "e607c83", "reviewer_role": "art-and-level-design-reviewer",
        "structures": [{"id": "staging_relay", "scene_path": "res://scenes/world/settlements/staging_relay.tscn", "role": "surface logistics relay", "authored_status": "authored"}],
        "view_captures": [
            {"view": "approach", "capture_path": "res://docs/evidence/caldera_approach.png", "review_status": "pending", "evidence": None},
            {"view": "surface", "capture_path": "res://docs/evidence/caldera_surface.png", "review_status": "pending", "evidence": None},
            {"view": "interior", "capture_path": "res://docs/evidence/caldera_interior.png", "review_status": "not_performed", "evidence": None},
        ],
        "human_signoff": {"status": "pending", "evidence": None},
        "claims_excluded": ["human_visual_approval", "production_art_signoff"],
    }


class PlanetarySettlementVisualReviewLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_structure_path_must_be_res_path(self):
        item = ledger(); item["structures"][0]["scene_path"] = "/tmp/settlement.tscn"
        self.assertTrue(any("scene_path" in error for error in validate_ledger(item)))

    def test_structure_ids_are_unique(self):
        item = ledger(); item["structures"].append(dict(item["structures"][0]))
        self.assertTrue(any("unique" in error for error in validate_ledger(item)))

    def test_capture_views_are_ordered(self):
        item = ledger(); item["view_captures"][1]["view"] = "approach"
        self.assertTrue(any("out of order" in error for error in validate_ledger(item)))

    def test_capture_path_must_be_res_path(self):
        item = ledger(); item["view_captures"][0]["capture_path"] = "capture.png"
        self.assertTrue(any("capture_path" in error for error in validate_ledger(item)))

    def test_capture_cannot_claim_approval(self):
        item = ledger(); item["view_captures"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_ledger(item)))

    def test_human_signoff_stays_open(self):
        item = ledger(); item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("human_signoff" in error for error in validate_ledger(item)))

    def test_excluded_claims_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
