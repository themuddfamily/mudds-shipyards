import copy
import unittest

from tools.world.planetary_reward_lineage_root_evidence_digest_v10_validator import _root_digest, validate_root


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
    root_id = "planetary_reward_evidence_root_v10"
    root_ref = "res://evidence/reward_root_v10/root.json"
    leaves = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_root_leaf_v10",
            "parent_id": root_id,
            "evidence_ref": f"res://evidence/reward_root_v10/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 10,
        "evidence_scope": "planetary_reward_lineage_root_evidence_digest_v10",
        "evidence_mode": "detached_reward_lineage_root_v10",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "root-v10",
        "root_id": root_id,
        "root_evidence_ref": root_ref,
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "leaves": leaves,
        "root_digest_sha256": _root_digest(root_id, root_ref, leaves),
        "counts": {"leaves": 5, "evidence_refs": 6, "pass_leaves": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardLineageRootEvidenceDigestV10ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_root(evidence()), [])

    def test_schema_version_is_v10(self):
        item = evidence()
        item["schema_version"] = 9
        self.assertTrue(any("schema_version must be 10" in error for error in validate_root(item)))

    def test_root_reference_must_be_res_path(self):
        item = evidence()
        item["root_evidence_ref"] = "file://root.json"
        self.assertTrue(any("root_evidence_ref must be a res:// path" in error for error in validate_root(item)))

    def test_root_digest_must_match(self):
        item = evidence()
        item["leaves"][0]["evidence_ref"] = "res://evidence/other.json"
        self.assertTrue(any("does not match canonical root and leaves" in error for error in validate_root(item)))

    def test_leaf_parent_must_be_root(self):
        item = evidence()
        item["leaves"][2]["parent_id"] = "other_root"
        self.assertTrue(any("parent_id must reference" in error for error in validate_root(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["leaves"][4]["evidence_ref"] = item["root_evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_root(item)))

    def test_counts_include_root_reference(self):
        item = evidence()
        item["counts"]["evidence_refs"] = 5
        self.assertTrue(any("counts.evidence_refs must be 6" in error for error in validate_root(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_root(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
