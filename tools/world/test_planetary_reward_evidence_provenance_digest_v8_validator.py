import copy
import unittest

from tools.world.planetary_reward_evidence_provenance_digest_v8_validator import _provenance_digest, validate_provenance


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
    references = [f"res://evidence/provenance_v8/{activity_id}.json" for activity_id in activity_ids]
    provenance = {"source": "detached_evidence", "provenance_id": "reward_evidence_provenance_v8", "generated_by": "authored_fixture", "historical_claim": False, "procedural_generation": False, "runtime_generated": False}
    records = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "evidence_ref": reference,
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority, reference in zip(activity_ids, authorities, references)
    ]
    return {
        "schema_version": 8,
        "evidence_scope": "planetary_reward_evidence_provenance_digest_v8",
        "evidence_mode": "detached_reward_evidence_provenance_v8",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "store_created": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "provenance-v8",
        "provenance": provenance,
        "authority": {"reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "source": "detached_evidence", "writes_store": False, "writes_inventory": False, "writes_runtime": False, "runs_native": False},
        "records": records,
        "provenance_digest_sha256": _provenance_digest(provenance, references),
        "counts": {"records": 5, "unique_references": 5, "pass_records": 5, "store_writes": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardEvidenceProvenanceDigestV8ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_provenance(evidence()), [])

    def test_schema_version_is_v8(self):
        item = evidence()
        item["schema_version"] = 7
        self.assertTrue(any("schema_version must be 8" in error for error in validate_provenance(item)))

    def test_provenance_digest_must_match(self):
        item = evidence()
        item["records"][0]["evidence_ref"] = "res://evidence/other.json"
        self.assertTrue(any("does not match provenance and references" in error for error in validate_provenance(item)))

    def test_provenance_must_be_detached(self):
        item = evidence()
        item["provenance"]["runtime_generated"] = True
        self.assertTrue(any("provenance.runtime_generated" in error for error in validate_provenance(item)))

    def test_references_must_be_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_provenance(item)))

    def test_reference_must_be_res_path(self):
        item = evidence()
        item["records"][1]["evidence_ref"] = "file://other.json"
        self.assertTrue(any("res:// path" in error for error in validate_provenance(item)))

    def test_counts_must_show_no_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_provenance(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_provenance(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
