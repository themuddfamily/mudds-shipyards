import unittest

from tools.review.planetary_hazard_reconciliation_manifest_visual_v12 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_reconciliation_manifest_visual_v12", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "13a578c", "root_id": "world_root",
        "leaves": [{"id": "hazard", "kind": "hazard", "parent_id": "world_root", "evidence_path": "res://docs/evidence/hazard.png", "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "world_root", "evidence_path": "res://docs/evidence/landmark.png", "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "world_root", "evidence_path": "res://docs/evidence/route.png", "status": "pending"}],
        "manifest_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["manifest_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardReconciliationManifestVisualV12Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_requires_three_leaves(self):
        item = manifest(); item["leaves"] = item["leaves"][:2]
        self.assertTrue(any("exactly three" in error for error in validate_manifest(item)))

    def test_leaf_ids_are_unique(self):
        item = manifest(); item["leaves"][1]["id"] = item["leaves"][0]["id"]
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_parent_id_must_equal_root(self):
        item = manifest(); item["leaves"][0]["parent_id"] = "other"
        self.assertTrue(any("parent_id" in error for error in validate_manifest(item)))

    def test_leaf_kinds_must_cover_all_categories(self):
        item = manifest(); item["leaves"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_manifest(item)))

    def test_evidence_path_must_be_res_path(self):
        item = manifest(); item["leaves"][0]["evidence_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
