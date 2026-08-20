import unittest

from tools.review.planetary_hazard_provenance_identity_reconciliation_visual_v23 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_provenance_identity_reconciliation_visual_v23", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "5235b57", "provenance_owner": "release-evidence", "provenance_id": "caldera-provenance-v1",
        "records": [{"id": "hazard", "kind": "hazard", "provenance_id": "caldera-provenance-v1", "provenance_owner": "release-evidence", "identity_reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "provenance_id": "caldera-provenance-v1", "provenance_owner": "release-evidence", "identity_reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "provenance_id": "caldera-provenance-v1", "provenance_owner": "release-evidence", "identity_reconciled": False, "status": "pending"}],
        "identity_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["identity_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardProvenanceIdentityReconciliationVisualV23Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_provenance_id_must_match(self):
        item = manifest(); item["records"][0]["provenance_id"] = "other"
        self.assertTrue(any("provenance_id must match" in error for error in validate_manifest(item)))

    def test_provenance_owner_must_match(self):
        item = manifest(); item["records"][0]["provenance_owner"] = "other"
        self.assertTrue(any("provenance_owner must match" in error for error in validate_manifest(item)))

    def test_identity_reconciliation_stays_false(self):
        item = manifest(); item["records"][0]["identity_reconciled"] = True
        self.assertTrue(any("identity_reconciled" in error for error in validate_manifest(item)))

    def test_record_kinds_cover_all_categories(self):
        item = manifest(); item["records"][2]["kind"] = "hazard"
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
