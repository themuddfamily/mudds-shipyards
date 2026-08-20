import unittest

from tools.review.planetary_hazard_reconciliation_digest_visual_v21 import validate_digest


def digest():
    return {
        "schema": "planetary_hazard_reconciliation_digest_visual_v21", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "df00424",
        "records": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "digest_path": "res://docs/evidence/hazard.sha256", "sha256": "a" * 64, "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "digest_path": "res://docs/evidence/landmark.sha256", "sha256": "b" * 64, "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "digest_path": "res://docs/evidence/route.sha256", "sha256": "c" * 64, "reconciled": False, "status": "pending"}],
        "aggregate_digest": {"sha256": "d" * 64, "status": "pending"}, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["reconciliation_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardReconciliationDigestVisualV21Test(unittest.TestCase):
    def test_open_digest_is_valid(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_digest_paths_are_res_paths(self):
        item = digest(); item["records"][0]["digest_path"] = "hazard.sha256"
        self.assertTrue(any("res://" in error for error in validate_digest(item)))

    def test_record_digests_are_strict(self):
        item = digest(); item["records"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_digest(item)))

    def test_records_must_remain_unreconciled(self):
        item = digest(); item["records"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_digest(item)))

    def test_manifest_ids_must_match(self):
        item = digest(); item["records"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_digest(item)))

    def test_aggregate_digest_is_strict(self):
        item = digest(); item["aggregate_digest"]["sha256"] = "bad"
        self.assertTrue(any("aggregate_digest" in error for error in validate_digest(item)))

    def test_native_human_gates_stay_open(self):
        item = digest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_digest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_digest(item)))

    def test_exclusions_are_required(self):
        item = digest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
