import unittest

from tools.review.planetary_hazard_landmark_review_digest_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_hazard_landmark_review_digest_v1", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "be8cfc6",
        "records": [{"id": "hazard-view", "kind": "hazard", "capture_path": "res://docs/evidence/hazard.png", "sha256": "c" * 64, "review_status": "pending", "question": "does the hazard read?"}, {"id": "route-view", "kind": "route", "capture_path": "res://docs/evidence/route.png", "sha256": "d" * 64, "review_status": "not_performed", "question": "does the route read?"}],
        "aggregate_digest": {"sha256": "e" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_review": {"status": "pending"}, "claims_excluded": ["digest_verification", "native_render", "human_review"],
    }


class PlanetaryHazardLandmarkReviewDigestLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_record_ids_are_unique(self):
        item = ledger(); item["records"].append(dict(item["records"][0]))
        self.assertTrue(any("unique" in error for error in validate_ledger(item)))

    def test_record_kind_is_strict(self):
        item = ledger(); item["records"][0]["kind"] = "unknown"
        self.assertTrue(any("kind is invalid" in error for error in validate_ledger(item)))

    def test_record_path_must_be_res_path(self):
        item = ledger(); item["records"][0]["capture_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_ledger(item)))

    def test_record_digest_is_strict(self):
        item = ledger(); item["records"][0]["sha256"] = "short"
        self.assertTrue(any("64-character" in error for error in validate_ledger(item)))

    def test_aggregate_digest_is_required(self):
        item = ledger(); item["aggregate_digest"]["sha256"] = "bad"
        self.assertTrue(any("aggregate_digest" in error for error in validate_ledger(item)))

    def test_human_review_stays_open(self):
        item = ledger(); item["human_review"]["status"] = "approved"
        self.assertTrue(any("human_review" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
