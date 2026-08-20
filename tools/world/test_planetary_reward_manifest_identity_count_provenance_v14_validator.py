import copy
import unittest

from tools.world.planetary_reward_manifest_identity_count_provenance_v14_validator import validate_identity


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
    manifest_id = "planetary_reward_manifest_v14"
    provenance_id = "planetary_reward_provenance_v14"
    identity_ref = "res://evidence/identity_v14/manifest.json"
    records = [
        {
            "activity_id": activity_id,
            "manifest_id": manifest_id,
            "provenance_id": provenance_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_count_leaf_v14",
            "evidence_ref": f"res://evidence/identity_v14/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 14,
        "evidence_scope": "planetary_reward_manifest_identity_count_provenance_v14",
        "evidence_mode": "detached_reward_manifest_identity_count_v14",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "identity-count-v14",
        "identity": {"manifest_id": manifest_id, "manifest_version": "v14", "world_id": "ember_moon", "provenance_id": provenance_id, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "evidence_ref": identity_ref, "leaf_count": 5, "status": "PASS", "identity_digest_sha256": "a" * 64, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False, "committed_once": True},
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "records": records,
        "counts": {"records": 5, "leaf_ids": 5, "evidence_refs": 6, "pass_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardManifestIdentityCountProvenanceV14ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_identity(evidence()), [])

    def test_schema_version_is_v14(self):
        item = evidence()
        item["schema_version"] = 13
        self.assertTrue(any("schema_version must be 14" in error for error in validate_identity(item)))

    def test_identity_leaf_count_is_five(self):
        item = evidence()
        item["identity"]["leaf_count"] = 4
        self.assertTrue(any("identity.leaf_count must be five" in error for error in validate_identity(item)))

    def test_record_identity_is_reconciled(self):
        item = evidence()
        item["records"][0]["provenance_id"] = "other_provenance"
        self.assertTrue(any("manifest/provenance IDs must match identity" in error for error in validate_identity(item)))

    def test_counts_include_identity_reference(self):
        item = evidence()
        item["counts"]["evidence_refs"] = 5
        self.assertTrue(any("counts.evidence_refs must be 6" in error for error in validate_identity(item)))

    def test_leaf_ids_are_unique(self):
        item = evidence()
        item["records"][4]["leaf_id"] = item["records"][0]["leaf_id"]
        self.assertTrue(any("leaf_ids must not contain duplicates" in error for error in validate_identity(item)))

    def test_identity_digest_format_is_valid(self):
        item = evidence()
        item["identity"]["identity_digest_sha256"] = "not-a-digest"
        self.assertTrue(any("identity_digest_sha256" in error for error in validate_identity(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_identity(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
