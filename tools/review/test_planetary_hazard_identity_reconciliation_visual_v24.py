import unittest

from tools.review.planetary_hazard_identity_reconciliation_visual_v24 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_identity_reconciliation_visual_v24", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "4bed1fe",
        "identities": [{"id": "hazard", "kind": "hazard", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "reconciled": False, "status": "pending"}],
        "identity_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["identity_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardIdentityReconciliationVisualV24Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_world_region_identity_must_match(self):
        item = manifest(); item["identities"][0]["region_id"] = "other"
        self.assertTrue(any("world_id and region_id" in error for error in validate_manifest(item)))

    def test_manifest_identity_must_match(self):
        item = manifest(); item["identities"][0]["manifest_id"] = "other"
        self.assertTrue(any("manifest_id" in error for error in validate_manifest(item)))

    def test_identities_must_remain_unreconciled(self):
        item = manifest(); item["identities"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_manifest(item)))

    def test_identity_kinds_cover_all_categories(self):
        item = manifest(); item["identities"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_identity_status_stays_open(self):
        item = manifest(); item["identity_status"] = "approved"
        self.assertTrue(any("identity_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
