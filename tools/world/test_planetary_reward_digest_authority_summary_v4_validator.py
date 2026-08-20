import copy
import unittest

from tools.world.planetary_reward_digest_authority_summary_v4_validator import validate_summary


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
    recovery_ids = (
        "return_to_landed_ship",
        "abort_to_orbit_return",
        "reset_at_start_beacon",
        "reset_at_start_beacon",
        "recover_convoy_at_return_beacon",
    )
    records = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "recovery_id": recovery_id,
            "return_target_id": "mudds_shipyards",
            "digest_leaf_id": f"{activity_id}_reward_digest_leaf",
            "evidence_ref": f"res://evidence/reward_digest/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority, recovery_id in zip(activity_ids, authorities, recovery_ids)
    ]
    handoffs = [
        {"id": "objective_evidence_to_reward", "source": "objective_evidence", "target": "game_flow_reward_authority"},
        {"id": "reward_to_store", "source": "game_flow_reward_authority", "target": "game_flow_reward_store"},
        {"id": "reward_to_return", "source": "game_flow_reward_authority", "target": "planetary_landing_return_contract"},
        {"id": "recovery_to_return", "source": "planetary_recovery_evidence", "target": "planetary_landing_return_contract"},
    ]
    for handoff in handoffs:
        handoff.update({"runtime_wired": False, "mutates_inventory": False, "runs_recovery": False, "native_run": False, "committed_once": True})
    return {
        "schema_version": 4,
        "evidence_scope": "planetary_reward_digest_authority_summary_v4",
        "evidence_mode": "detached_reward_digest_authority_v4",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "recovery_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "source_revision": "digest-authority-v4",
        "digest_sha256": "d" * 64,
        "digest_authority": {
            "owner_id": "game_flow_reward_authority",
            "store_id": "game_flow_reward_store",
            "return_authority_id": "planetary_landing_return_contract",
            "source": "detached_evidence",
            "contract_revision": "reward_digest_authority_v4",
            "owns_inventory": False,
            "writes_runtime": False,
            "runs_recovery": False,
            "runs_native": False,
        },
        "handoffs": handoffs,
        "records": records,
        "counts": {"records": 5, "handoffs": 4, "digest_leaves": 5, "pass_records": 5, "runtime_mutations": 0, "inventory_writes": 0, "recovery_runs": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardDigestAuthoritySummaryV4ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_summary(evidence()), [])

    def test_schema_version_is_v4(self):
        item = evidence()
        item["schema_version"] = 3
        self.assertTrue(any("schema_version must be 4" in error for error in validate_summary(item)))

    def test_recovery_handoff_is_required(self):
        item = evidence()
        item["handoffs"].pop()
        self.assertTrue(any("exactly four authored handoffs" in error for error in validate_summary(item)))

    def test_recovery_handoff_must_be_non_runtime(self):
        item = evidence()
        item["handoffs"][3]["runs_recovery"] = True
        self.assertTrue(any("runs_recovery must be false" in error for error in validate_summary(item)))

    def test_recovery_id_must_be_existing(self):
        item = evidence()
        item["records"][0]["recovery_id"] = "invented_recovery"
        self.assertTrue(any("existing recovery ID" in error for error in validate_summary(item)))

    def test_counts_must_include_recovery_runs(self):
        item = evidence()
        item["counts"]["recovery_runs"] = 1
        self.assertTrue(any("counts.recovery_runs must be 0" in error for error in validate_summary(item)))

    def test_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_summary(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_summary(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
