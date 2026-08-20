import copy
import unittest

from tools.world.planetary_reward_provenance_lineage_digest_v9_validator import _lineage_digest, validate_lineage


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
    root_id = "planetary_reward_evidence_root_v9"
    leaves = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "lineage_id": f"{activity_id}_reward_lineage_v9",
            "parent_id": root_id,
            "evidence_ref": f"res://evidence/lineage_v9/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 9,
        "evidence_scope": "planetary_reward_provenance_lineage_digest_v9",
        "evidence_mode": "detached_reward_provenance_lineage_v9",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "lineage-v9",
        "root_id": root_id,
        "provenance": {"source": "detached_evidence", "lineage_version": "v9", "generated_by": "authored_fixture", "runtime_generated": False, "historical_claim": False, "procedural_generation": False},
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "leaves": leaves,
        "lineage_digest_sha256": _lineage_digest(root_id, leaves),
        "counts": {"leaves": 5, "unique_lineages": 5, "unique_references": 5, "pass_leaves": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardProvenanceLineageDigestV9ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_lineage(evidence()), [])

    def test_schema_version_is_v9(self):
        item = evidence()
        item["schema_version"] = 8
        self.assertTrue(any("schema_version must be 9" in error for error in validate_lineage(item)))

    def test_lineage_digest_must_match(self):
        item = evidence()
        item["leaves"][0]["evidence_ref"] = "res://evidence/other.json"
        self.assertTrue(any("does not match canonical lineage" in error for error in validate_lineage(item)))

    def test_lineage_ids_are_unique(self):
        item = evidence()
        item["leaves"][4]["lineage_id"] = item["leaves"][0]["lineage_id"]
        self.assertTrue(any("lineage_ids must not contain duplicates" in error for error in validate_lineage(item)))

    def test_leaf_parent_must_be_root(self):
        item = evidence()
        item["leaves"][1]["parent_id"] = "other_root"
        self.assertTrue(any("parent_id must reference" in error for error in validate_lineage(item)))

    def test_provenance_must_be_detached(self):
        item = evidence()
        item["provenance"]["runtime_generated"] = True
        self.assertTrue(any("provenance.runtime_generated" in error for error in validate_lineage(item)))

    def test_counts_must_show_no_writes(self):
        item = evidence()
        item["counts"]["store_writes"] = 1
        self.assertTrue(any("counts.store_writes must be 0" in error for error in validate_lineage(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_lineage(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
