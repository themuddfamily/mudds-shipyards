import unittest

from tools.review.planetary_hazard_identity_digest_reconciliation_visual_v25 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_identity_digest_reconciliation_visual_v25", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "75a8dee",
        "records": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "sha256": "a" * 64, "identity_reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "sha256": "b" * 64, "identity_reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "sha256": "c" * 64, "identity_reconciled": False, "status": "pending"}],
        "aggregate_digest": {"sha256": "d" * 64, "status": "pending"}, "identity_digest_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["identity_digest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardIdentityDigestReconciliationVisualV25Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_record_digests_are_strict(self):
        item = manifest(); item["records"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_records_must_remain_unreconciled(self):
        item = manifest(); item["records"][0]["identity_reconciled"] = True
        self.assertTrue(any("identity_reconciled" in error for error in validate_manifest(item)))

    def test_manifest_ids_must_match(self):
        item = manifest(); item["records"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_kinds_cover_all_categories(self):
        item = manifest(); item["records"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_aggregate_digest_is_strict(self):
        item = manifest(); item["aggregate_digest"]["sha256"] = "bad"
        self.assertTrue(any("aggregate_digest" in error for error in validate_manifest(item)))

    def test_identity_digest_status_stays_open(self):
        item = manifest(); item["identity_digest_status"] = "approved"
        self.assertTrue(any("identity_digest_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
