import unittest

from tools.review.planetary_hazard_authority_binding_reconciliation_visual_v20 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_authority_binding_reconciliation_visual_v20", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "1524a17",
        "bindings": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "authority_id": "external_visual_review_authority", "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "authority_id": "external_visual_review_authority", "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "authority_id": "external_visual_review_authority", "reconciled": False, "status": "pending"}],
        "reconciliation_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["runtime_authority", "reconciliation_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardAuthorityBindingReconciliationVisualV20Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_authority_id_must_remain_external(self):
        item = manifest(); item["bindings"][0]["authority_id"] = "runtime_authority"
        self.assertTrue(any("authority_id" in error for error in validate_manifest(item)))

    def test_bindings_must_remain_unreconciled(self):
        item = manifest(); item["bindings"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_manifest(item)))

    def test_manifest_ids_must_match(self):
        item = manifest(); item["bindings"][0]["manifest_id"] = "other"
        self.assertTrue(any("must match" in error for error in validate_manifest(item)))

    def test_binding_kinds_cover_all_categories(self):
        item = manifest(); item["bindings"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_reconciliation_status_stays_open(self):
        item = manifest(); item["reconciliation_status"] = "approved"
        self.assertTrue(any("reconciliation_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
