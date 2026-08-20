import copy
import unittest

from tools.world.planetary_reward_leaf_evidence_digest_authority_v6_validator import validate_authority


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
    leaf_digests = ("a", "b", "c", "d", "e")
    leaves = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_leaf_v6",
            "leaf_digest_sha256": digest * 64,
            "evidence_ref": f"res://evidence/reward_leaf_v6/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority, digest in zip(activity_ids, authorities, leaf_digests)
    ]
    return {
        "schema_version": 6,
        "evidence_scope": "planetary_reward_leaf_evidence_digest_authority_v6",
        "evidence_mode": "detached_reward_leaf_digest_authority_v6",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "leaf-authority-v6",
        "summary_digest_sha256": "f" * 64,
        "leaf_authority": {
            "owner_id": "game_flow_reward_authority",
            "store_id": "game_flow_reward_store",
            "source": "detached_evidence",
            "contract_revision": "reward_leaf_digest_authority_v6",
            "writes_store": False,
            "writes_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
            "committed_once": True,
        },
        "leaves": leaves,
        "counts": {"leaves": 5, "evidence_refs": 5, "pass_leaves": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardLeafEvidenceDigestAuthorityV6ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_authority(evidence()), [])

    def test_schema_version_is_v6(self):
        item = evidence()
        item["schema_version"] = 5
        self.assertTrue(any("schema_version must be 6" in error for error in validate_authority(item)))

    def test_leaf_digest_must_be_sha256(self):
        item = evidence()
        item["leaves"][0]["leaf_digest_sha256"] = "not-a-digest"
        self.assertTrue(any("leaf_digest_sha256" in error for error in validate_authority(item)))

    def test_leaf_ids_are_unique(self):
        item = evidence()
        item["leaves"][4]["leaf_id"] = item["leaves"][0]["leaf_id"]
        self.assertTrue(any("leaf_ids must not contain duplicates" in error for error in validate_authority(item)))

    def test_evidence_refs_are_unique_res_paths(self):
        item = evidence()
        item["leaves"][4]["evidence_ref"] = item["leaves"][0]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_authority(item)))

    def test_authority_cannot_write_store(self):
        item = evidence()
        item["leaf_authority"]["writes_store"] = True
        self.assertTrue(any("writes_store must be false" in error for error in validate_authority(item)))

    def test_counts_must_show_no_writes(self):
        item = evidence()
        item["counts"]["store_writes"] = 1
        self.assertTrue(any("counts.store_writes must be 0" in error for error in validate_authority(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_authority(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
