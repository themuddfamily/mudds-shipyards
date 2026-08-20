import unittest

from tools.review.planetary_hazard_paired_digest_reconciliation_visual_v27 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_paired_digest_reconciliation_visual_v27", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "b379ec3",
        "pairs": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "source_sha256": "a" * 64, "review_sha256": "b" * 64, "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "source_sha256": "c" * 64, "review_sha256": "d" * 64, "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "source_sha256": "e" * 64, "review_sha256": "f" * 64, "reconciled": False, "status": "pending"}],
        "pair_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["paired_digest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardPairedDigestReconciliationVisualV27Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_source_digest_is_strict(self):
        item = manifest(); item["pairs"][0]["source_sha256"] = "bad"
        self.assertTrue(any("source_sha256" in error for error in validate_manifest(item)))

    def test_review_digest_is_strict(self):
        item = manifest(); item["pairs"][0]["review_sha256"] = "bad"
        self.assertTrue(any("review_sha256" in error for error in validate_manifest(item)))

    def test_pair_ids_are_unique(self):
        item = manifest(); item["pairs"][1]["id"] = item["pairs"][0]["id"]
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_manifest_ids_must_match(self):
        item = manifest(); item["pairs"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_pairs_must_remain_unreconciled(self):
        item = manifest(); item["pairs"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_manifest(item)))

    def test_pair_status_stays_open(self):
        item = manifest(); item["pair_status"] = "approved"
        self.assertTrue(any("pair_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
