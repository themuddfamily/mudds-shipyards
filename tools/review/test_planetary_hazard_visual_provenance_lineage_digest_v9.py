import unittest

from tools.review.planetary_hazard_visual_provenance_lineage_digest_v9 import validate_digest


def digest():
    return {
        "schema": "planetary_hazard_visual_provenance_lineage_digest_v9", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "ec62694",
        "records": [{"id": "hazard", "kind": "hazard", "parent_id": "world_content", "source_path": "res://docs/evidence/hazard.png", "sha256": "a" * 64, "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "world_content", "source_path": "res://docs/evidence/landmark.png", "sha256": "b" * 64, "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "landmark", "source_path": "res://docs/evidence/route.png", "sha256": "c" * 64, "status": "pending"}],
        "lineage_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["lineage_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardVisualProvenanceLineageDigestV9Test(unittest.TestCase):
    def test_open_digest_is_valid(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_record_ids_are_unique(self):
        item = digest(); item["records"].append(dict(item["records"][0]))
        self.assertTrue(any("unique" in error for error in validate_digest(item)))

    def test_record_kinds_are_strict(self):
        item = digest(); item["records"][0]["kind"] = "other"
        self.assertTrue(any("kind is invalid" in error for error in validate_digest(item)))

    def test_parent_id_is_required(self):
        item = digest(); item["records"][0]["parent_id"] = ""
        self.assertTrue(any("parent_id" in error for error in validate_digest(item)))

    def test_source_path_is_res_path(self):
        item = digest(); item["records"][0]["source_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_digest(item)))

    def test_sha256_is_strict(self):
        item = digest(); item["records"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_digest(item)))

    def test_lineage_status_stays_open(self):
        item = digest(); item["lineage_status"] = "approved"
        self.assertTrue(any("lineage_status" in error for error in validate_digest(item)))

    def test_native_human_exclusions_are_required(self):
        item = digest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
