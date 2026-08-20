import unittest

from tools.review.planetary_hazard_visual_evidence_ordering_digest_v7 import validate_digest


def digest():
    return {
        "schema": "planetary_hazard_visual_evidence_ordering_digest_v7", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "97243b9",
        "entries": [{"kind": "hazard", "sequence": 1, "path": "res://docs/evidence/hazard.png", "status": "pending"}, {"kind": "landmark", "sequence": 2, "path": "res://docs/evidence/landmark.png", "status": "not_performed"}, {"kind": "route", "sequence": 3, "path": "res://docs/evidence/route.png", "status": "pending"}],
        "digest_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["ordering_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardVisualEvidenceOrderingDigestV7Test(unittest.TestCase):
    def test_open_digest_is_valid(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_kind_order_is_strict(self):
        item = digest(); item["entries"][1]["kind"] = "route"
        self.assertTrue(any("out of order" in error for error in validate_digest(item)))

    def test_sequences_are_strict(self):
        item = digest(); item["entries"][0]["sequence"] = 2
        self.assertTrue(any("sequence must be 1" in error for error in validate_digest(item)))

    def test_paths_must_be_res_paths(self):
        item = digest(); item["entries"][0]["path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_digest(item)))

    def test_entry_status_stays_open(self):
        item = digest(); item["entries"][0]["status"] = "approved"
        self.assertTrue(any("status must remain open" in error for error in validate_digest(item)))

    def test_digest_status_stays_open(self):
        item = digest(); item["digest_status"] = "complete"
        self.assertTrue(any("digest_status" in error for error in validate_digest(item)))

    def test_native_signoff_stays_open(self):
        item = digest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_digest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_digest(item)))

    def test_exclusions_are_required(self):
        item = digest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
