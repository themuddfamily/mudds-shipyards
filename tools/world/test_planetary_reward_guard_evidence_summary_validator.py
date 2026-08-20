import copy
import unittest

from tools.world.planetary_reward_guard_evidence_summary_validator import validate_summary


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
    records = []
    for activity_id, authority in zip(activity_ids, authorities):
        records.append(
            {
                "activity_id": activity_id,
                "activity_authority_id": authority,
                "reward_authority_id": "game_flow_reward_authority",
                "reward_id": f"reward_{activity_id}",
                "retry_guard_id": f"{activity_id}_reward_retry_g2",
                "stale_guard_id": f"{activity_id}_reward_stale_g0",
                "retry_generation": 2,
                "retry_accepted": True,
                "stale_generation": 0,
                "stale_rejected": True,
                "status": "PASS",
                "evidence_ref": f"res://evidence/reward_guards/{activity_id}.json",
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_guard_evidence_summary",
        "evidence_mode": "detached_reward_guard_summary",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "source_revision": "guard-summary-v1",
        "records": records,
        "counts": {
            "records": 5,
            "retry_guards": 5,
            "stale_guards": 5,
            "retry_accepted": 5,
            "stale_rejected": 5,
            "pass_records": 5,
            "duplicate_guard_ids": 0,
            "runtime_mutations": 0,
            "native_runs": 0,
        },
        "overall_status": "PASS",
        "authority": {
            "activity": False,
            "objective": False,
            "reward": False,
            "reward_store": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryRewardGuardEvidenceSummaryValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_summary(evidence()), [])

    def test_counts_must_match_records(self):
        item = evidence()
        item["counts"]["retry_accepted"] = 4
        self.assertTrue(any("counts.retry_accepted must be 5" in error for error in validate_summary(item)))

    def test_guard_ids_must_be_unique(self):
        item = evidence()
        item["records"][4]["stale_guard_id"] = item["records"][0]["stale_guard_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_summary(item)))

    def test_records_retain_activity_order(self):
        item = evidence()
        item["records"].reverse()
        self.assertTrue(any("authored activity order" in error for error in validate_summary(item)))

    def test_evidence_ref_must_be_res_path(self):
        item = evidence()
        item["records"][0]["evidence_ref"] = "file://guard.json"
        self.assertTrue(any("res:// path" in error for error in validate_summary(item)))

    def test_overall_status_must_pass(self):
        item = evidence()
        item["overall_status"] = "NOT_RUN"
        self.assertTrue(any("overall_status must be PASS" in error for error in validate_summary(item)))

    def test_claim_flags_fail_closed(self):
        item = evidence()
        item["procedural_generation"] = True
        self.assertTrue(any("procedural_generation" in error for error in validate_summary(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_summary(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
