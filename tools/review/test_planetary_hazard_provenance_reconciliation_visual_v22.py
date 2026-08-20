import unittest

from tools.review.planetary_hazard_provenance_reconciliation_visual_v22 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_provenance_reconciliation_visual_v22", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "3ce6168", "provenance_owner": "release-evidence",
        "records": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "provenance_note": "authored hazard evidence", "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "provenance_note": "authored landmark evidence", "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "provenance_note": "authored route evidence", "reconciled": False, "status": "pending"}],
        "provenance_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["provenance_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardProvenanceReconciliationVisualV22Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_provenance_owner_is_required(self):
        item = manifest(); item["provenance_owner"] = ""
        self.assertTrue(any("provenance_owner" in error for error in validate_manifest(item)))

    def test_record_manifest_ids_must_match(self):
        item = manifest(); item["records"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_provenance_note_is_required(self):
        item = manifest(); item["records"][0]["provenance_note"] = ""
        self.assertTrue(any("provenance_note" in error for error in validate_manifest(item)))

    def test_records_must_remain_unreconciled(self):
        item = manifest(); item["records"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_manifest(item)))

    def test_provenance_status_stays_open(self):
        item = manifest(); item["provenance_status"] = "approved"
        self.assertTrue(any("provenance_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
