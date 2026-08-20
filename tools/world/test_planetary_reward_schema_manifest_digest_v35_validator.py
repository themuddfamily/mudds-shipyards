import copy
import unittest

from tools.world.planetary_reward_schema_manifest_digest_v35_validator import (
    _manifest_digest,
    validate_schema_manifest,
)


def evidence() -> dict:
    activities = (("ember_beacon_survey", "activity_director"), ("ember_caldera_patrol", "activity_director"), ("ember_kit_cargo_run", "cargo_delivery_activity"), ("ember_checkpoint_race", "timed_checkpoint_race"), ("ember_convoy_escort", "convoy_escort_activity"))
    manifest_id = "planetary_reward_manifest_v35"
    provenance_id = "planetary_reward_provenance_v35"
    lineage_id = "planetary_reward_lineage_v35"
    manifest_ref = "res://evidence/schema_manifest_v35/manifest.json"
    records = [{"activity_id": activity_id, "manifest_id": manifest_id, "provenance_id": provenance_id, "activity_authority_id": activity_authority, "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "reward_id": f"reward_{activity_id}", "leaf_id": f"{activity_id}_reward_schema_manifest_leaf_v35", "evidence_ref": f"res://evidence/schema_manifest_v35/{activity_id}.json", "status": "PASS", "included_once": True} for activity_id, activity_authority in activities]
    manifest = {"manifest_id": manifest_id, "manifest_version": "v35", "provenance_id": provenance_id, "lineage_id": lineage_id, "source": "detached_evidence", "evidence_ref": manifest_ref, "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    authority = {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "authority_scope": "planetary_reward_schema_manifest", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False}
    reconciliation = {"schema_version": 35, "digest_version": "schema_manifest_v35", "manifest_id": manifest_id, "manifest_version": "v35", "provenance_id": provenance_id, "lineage_id": lineage_id, "algorithm": "sha256", "canonicalization": "json_sort_keys_compact", "evidence_ref": "res://evidence/schema_manifest_v35/reconciliation.json", "records_expected": 5, "records_observed": 5, "references_expected": 6, "references_observed": 6, "records_reconciled": 5, "authority_reconciled": True, "all_fields_present": True, "all_status_pass": True, "complete": True}
    return {"schema_version": 35, "evidence_scope": "planetary_reward_schema_manifest_digest_v35", "evidence_mode": "detached_reward_schema_manifest_v35", "runtime_authority": False, "reward_inventory": False, "reward_runtime": False, "native_claims": False, "store_created": False, "historical_claim": False, "procedural_generation": False, "world_id": "ember_moon", "source_revision": "schema-manifest-v35", "manifest": manifest, "authority": authority, "records": records, "schema_manifest_reconciliation": reconciliation, "schema_manifest_digest_sha256": _manifest_digest(manifest, authority, reconciliation, records), "counts": {"records": 5, "references": 6, "records_reconciled": 5, "complete_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0}, "overall_status": "PASS"}


class PlanetaryRewardSchemaManifestDigestV35ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_schema_manifest(evidence()), [])

    def test_schema_version_is_v35(self):
        item = evidence()
        item["schema_version"] = 34
        self.assertTrue(any("schema_version must be 35" in error for error in validate_schema_manifest(item)))

    def test_manifest_version_is_required(self):
        item = evidence()
        item["manifest"]["manifest_version"] = "v34"
        self.assertTrue(any("manifest.manifest_version must be v35" in error for error in validate_schema_manifest(item)))

    def test_reconciliation_digest_version_is_required(self):
        item = evidence()
        item["schema_manifest_reconciliation"]["digest_version"] = "other"
        self.assertTrue(any("schema_manifest_reconciliation.digest_version must be schema_manifest_v35" in error for error in validate_schema_manifest(item)))

    def test_digest_binds_manifest(self):
        item = evidence()
        item["manifest"]["manifest_id"] = "other_manifest"
        self.assertTrue(any("schema_manifest_digest_sha256 does not match canonical schema/manifest payload" in error for error in validate_schema_manifest(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_schema_manifest(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_schema_manifest(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_schema_manifest(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
