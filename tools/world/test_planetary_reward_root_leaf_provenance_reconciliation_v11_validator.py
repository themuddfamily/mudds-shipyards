import copy
import unittest

from tools.world.planetary_reward_root_leaf_provenance_reconciliation_v11_validator import validate_reconciliation


def evidence() -> dict:
    activity_ids = (
        "ember_beacon_survey",
        "ember_caldera_patrol",
        "ember_kit_cargo_run",
        "ember_checkpoint_race",
        "ember_convoy_escort",
    )
    authorities = (
        "activity_director",
        "activity_director",
        "cargo_delivery_activity",
        "timed_checkpoint_race",
        "convoy_escort_activity",
    )
    root_id = "planetary_reward_evidence_root_v11"
    provenance_id = "planetary_reward_provenance_v11"
    root_ref = "res://evidence/reconciliation_v11/root.json"
    leaves = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_reconciled_leaf_v11",
            "parent_id": root_id,
            "provenance_id": provenance_id,
            "evidence_ref": f"res://evidence/reconciliation_v11/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    leaf_ids = [leaf["leaf_id"] for leaf in leaves]
    leaf_refs = [leaf["evidence_ref"] for leaf in leaves]
    return {
        "schema_version": 11,
        "evidence_scope": "planetary_reward_root_leaf_provenance_reconciliation_v11",
        "evidence_mode": "detached_reward_root_leaf_reconciliation_v11",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "reconciliation-v11",
        "root": {"id": root_id, "evidence_ref": root_ref, "provenance_id": provenance_id, "expected_leaf_count": 5, "status": "PASS", "committed_once": True},
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "leaves": leaves,
        "reconciled_manifest": {"root_id": root_id, "provenance_id": provenance_id, "leaf_ids": leaf_ids, "evidence_refs": leaf_refs, "reconciled_once": True},
        "counts": {"leaves": 5, "evidence_refs": 6, "reconciled_leaves": 5, "pass_leaves": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardRootLeafProvenanceReconciliationV11ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_reconciliation(evidence()), [])

    def test_schema_version_is_v11(self):
        item = evidence()
        item["schema_version"] = 10
        self.assertTrue(any("schema_version must be 11" in error for error in validate_reconciliation(item)))

    def test_root_provenance_is_reconciled(self):
        item = evidence()
        item["leaves"][0]["provenance_id"] = "other_provenance"
        self.assertTrue(any("reconcile to the root" in error for error in validate_reconciliation(item)))

    def test_manifest_enumerates_leaves(self):
        item = evidence()
        item["reconciled_manifest"]["leaf_ids"] = []
        self.assertTrue(any("enumerate the authored leaves" in error for error in validate_reconciliation(item)))

    def test_root_reference_must_be_unique(self):
        item = evidence()
        item["leaves"][4]["evidence_ref"] = item["root"]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_reconciliation(item)))

    def test_leaf_parent_must_match_root(self):
        item = evidence()
        item["leaves"][2]["parent_id"] = "other_root"
        self.assertTrue(any("parent_id must match the root" in error for error in validate_reconciliation(item)))

    def test_counts_must_show_reconciliation(self):
        item = evidence()
        item["counts"]["reconciled_leaves"] = 4
        self.assertTrue(any("counts.reconciled_leaves must be 5" in error for error in validate_reconciliation(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_reconciliation(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
