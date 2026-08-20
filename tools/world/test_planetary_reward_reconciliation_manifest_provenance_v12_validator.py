import copy
import unittest

from tools.world.planetary_reward_reconciliation_manifest_provenance_v12_validator import validate_manifest


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
    root_id = "planetary_reward_evidence_root_v12"
    provenance_id = "planetary_reward_provenance_v12"
    manifest_ref = "res://evidence/manifest_v12/manifest.json"
    leaves = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "leaf_id": f"{activity_id}_reward_manifest_leaf_v12",
            "root_id": root_id,
            "provenance_id": provenance_id,
            "evidence_ref": f"res://evidence/manifest_v12/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    leaf_ids = [leaf["leaf_id"] for leaf in leaves]
    refs = [leaf["evidence_ref"] for leaf in leaves]
    return {
        "schema_version": 12,
        "evidence_scope": "planetary_reward_reconciliation_manifest_provenance_v12",
        "evidence_mode": "detached_reward_reconciliation_manifest_v12",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "manifest-v12",
        "manifest": {"id": "planetary_reward_reconciliation_manifest_v12", "root_id": root_id, "provenance_id": provenance_id, "source": "detached_evidence", "evidence_ref": manifest_ref, "leaf_count": 5, "leaf_ids": leaf_ids, "evidence_refs": refs, "status": "PASS", "committed_once": True, "digest_sha256": "a" * 64},
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "leaves": leaves,
        "counts": {"leaves": 5, "evidence_refs": 6, "pass_leaves": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardReconciliationManifestProvenanceV12ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_manifest(evidence()), [])

    def test_schema_version_is_v12(self):
        item = evidence()
        item["schema_version"] = 11
        self.assertTrue(any("schema_version must be 12" in error for error in validate_manifest(item)))

    def test_manifest_enumerates_leaf_ids(self):
        item = evidence()
        item["manifest"]["leaf_ids"] = []
        self.assertTrue(any("enumerate authored leaf IDs" in error for error in validate_manifest(item)))

    def test_leaf_provenance_reconciles(self):
        item = evidence()
        item["leaves"][0]["provenance_id"] = "other_provenance"
        self.assertTrue(any("root/provenance must reconcile" in error for error in validate_manifest(item)))

    def test_manifest_reference_is_unique(self):
        item = evidence()
        item["leaves"][4]["evidence_ref"] = item["manifest"]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_manifest(item)))

    def test_manifest_digest_format_is_valid(self):
        item = evidence()
        item["manifest"]["digest_sha256"] = "not-a-digest"
        self.assertTrue(any("digest_sha256 must be" in error for error in validate_manifest(item)))

    def test_counts_include_manifest_reference(self):
        item = evidence()
        item["counts"]["evidence_refs"] = 5
        self.assertTrue(any("counts.evidence_refs must be 6" in error for error in validate_manifest(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_manifest(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
