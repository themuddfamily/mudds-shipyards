import unittest

from tools.review.planetary_hazard_root_leaf_reconciliation_digest_v11 import validate_digest


def digest():
    return {
        "schema": "planetary_hazard_root_leaf_reconciliation_digest_v11", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "8ed6cbf", "root_id": "authored_world_root",
        "leaves": [{"id": "hazard", "kind": "hazard", "parent_id": "authored_world_root", "reconciled": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "parent_id": "authored_world_root", "reconciled": False, "status": "not_performed"}, {"id": "route", "kind": "route", "parent_id": "landmark", "reconciled": False, "status": "pending"}],
        "leaf_counts": {"hazard": 1, "landmark": 1, "route": 1}, "reconciliation_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["reconciliation_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardRootLeafReconciliationDigestV11Test(unittest.TestCase):
    def test_open_reconciliation_is_valid(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_leaf_ids_are_unique(self):
        item = digest(); item["leaves"].append(dict(item["leaves"][0]))
        self.assertTrue(any("unique" in error for error in validate_digest(item)))

    def test_parent_must_be_root_or_earlier_leaf(self):
        item = digest(); item["leaves"][2]["parent_id"] = "missing"
        self.assertTrue(any("earlier leaf" in error for error in validate_digest(item)))

    def test_leaves_must_remain_unreconciled(self):
        item = digest(); item["leaves"][0]["reconciled"] = True
        self.assertTrue(any("reconciled" in error for error in validate_digest(item)))

    def test_leaf_kinds_cover_all_categories(self):
        item = digest(); item["leaves"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_digest(item)))

    def test_leaf_counts_match(self):
        item = digest(); item["leaf_counts"]["route"] = 2
        self.assertTrue(any("leaf_counts.route" in error for error in validate_digest(item)))

    def test_native_human_gates_stay_open(self):
        item = digest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_digest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_digest(item)))

    def test_exclusions_are_required(self):
        item = digest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
