import unittest

from tools.review.planetary_hazard_lineage_root_visual_digest_v10 import validate_digest


def digest():
    return {
        "schema": "planetary_hazard_lineage_root_visual_digest_v10", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "b5968eb", "root_id": "authored_world_root",
        "records": [{"id": "hazard", "kind": "hazard", "parent_id": "authored_world_root", "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "authored_world_root", "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "landmark", "status": "pending"}],
        "lineage_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["lineage_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardLineageRootVisualDigestV10Test(unittest.TestCase):
    def test_open_rooted_digest_is_valid(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_root_id_must_be_external(self):
        item = digest(); item["root_id"] = "hazard"
        self.assertTrue(any("external" in error for error in validate_digest(item)))

    def test_parent_must_reference_root_or_record(self):
        item = digest(); item["records"][0]["parent_id"] = "missing"
        self.assertTrue(any("root or a record" in error for error in validate_digest(item)))

    def test_lineage_must_terminate_at_root(self):
        item = digest(); item["records"][2]["parent_id"] = "route"
        self.assertTrue(any("terminate at root" in error for error in validate_digest(item)))

    def test_record_ids_are_unique(self):
        item = digest(); item["records"].append(dict(item["records"][0]))
        self.assertTrue(any("unique" in error for error in validate_digest(item)))

    def test_record_kinds_are_strict(self):
        item = digest(); item["records"][0]["kind"] = "other"
        self.assertTrue(any("kind is invalid" in error for error in validate_digest(item)))

    def test_native_human_gates_stay_open(self):
        item = digest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_digest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_digest(item)))

    def test_exclusions_are_required(self):
        item = digest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
