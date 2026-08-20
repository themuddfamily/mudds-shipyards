import unittest

from tools.review.planetary_hazard_paired_lineage_root_visual_v29 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_paired_lineage_root_visual_v29", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "root_id": "world_root", "source_revision": "f543e0e",
        "pairs": [{"id": "hazard", "kind": "hazard", "parent_id": "world_root", "source_sha256": "a" * 64, "review_sha256": "b" * 64, "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "world_root", "source_sha256": "c" * 64, "review_sha256": "d" * 64, "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "world_root", "source_sha256": "e" * 64, "review_sha256": "f" * 64, "reconciled": False, "status": "pending"}],
        "root_lineage_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["root_lineage_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardPairedLineageRootVisualV29Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_pair_ids_differ_from_root(self):
        item = manifest(); item["pairs"][0]["id"] = "world_root"
        self.assertTrue(any("differ from root" in error for error in validate_manifest(item)))

    def test_parent_ids_equal_root(self):
        item = manifest(); item["pairs"][0]["parent_id"] = "other"
        self.assertTrue(any("parent_id" in error for error in validate_manifest(item)))

    def test_source_digest_is_strict(self):
        item = manifest(); item["pairs"][0]["source_sha256"] = "bad"
        self.assertTrue(any("source_sha256" in error for error in validate_manifest(item)))

    def test_review_digest_is_strict(self):
        item = manifest(); item["pairs"][0]["review_sha256"] = "bad"
        self.assertTrue(any("review_sha256" in error for error in validate_manifest(item)))

    def test_pairs_stay_unreconciled(self):
        item = manifest(); item["pairs"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_manifest(item)))

    def test_root_lineage_status_stays_open(self):
        item = manifest(); item["root_lineage_status"] = "approved"
        self.assertTrue(any("root_lineage_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
