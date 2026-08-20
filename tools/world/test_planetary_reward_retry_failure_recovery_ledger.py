import copy
import unittest

from tools.world.planetary_reward_retry_failure_recovery_ledger import validate_ledger


def evidence() -> dict:
    activity_ids = (
        "ember_beacon_survey",
        "ember_caldera_patrol",
        "ember_kit_cargo_run",
        "ember_checkpoint_race",
        "ember_convoy_escort",
    )
    activities = [
        {
            "activity_id": activity_id,
            "attempt_generation": 1,
            "failure_state": "failed",
            "failure_reason": "surface_hazard",
            "recovery_id": "return_to_landed_ship",
            "recovery_target": "landed_ship",
            "recovery_route_id": "route_recover_to_ship",
            "recovery_accepted": True,
            "recovery_once": True,
            "retry_allowed": True,
            "retry_generation": 2,
            "stale_recovery_accepted": False,
            "stale_rejection_reason": "stale_generation",
            "reward_granted_before_failure": False,
            "reward_grant_once": True,
            "duplicate_reward_rejected": True,
        }
        for activity_id in activity_ids
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_retry_failure_recovery",
        "evidence_mode": "detached_recovery_fixture",
        "runtime_authority": False,
        "reward_inventory": False,
        "recovery_mutation": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "source_revision": "reward-recovery-v1",
        "activities": activities,
        "authority": {
            "activity": False,
            "objective": False,
            "reward": False,
            "reward_store": False,
            "recovery": False,
            "save": False,
            "network": False,
            "gameplay": False,
            "clock": False,
        },
    }


class PlanetaryRewardRetryFailureRecoveryLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_recovery_id_must_be_authored(self):
        item = evidence()
        item["activities"][0]["recovery_id"] = "invented_recovery"
        self.assertTrue(any("existing recovery ID" in error for error in validate_ledger(item)))

    def test_retry_generation_must_advance_once(self):
        item = evidence()
        item["activities"][0]["retry_generation"] = 4
        self.assertTrue(any("advance exactly once" in error for error in validate_ledger(item)))

    def test_stale_recovery_must_be_rejected(self):
        item = evidence()
        item["activities"][1]["stale_recovery_accepted"] = True
        self.assertTrue(any("stale_recovery_accepted" in error for error in validate_ledger(item)))

    def test_reward_cannot_precede_failure(self):
        item = evidence()
        item["activities"][2]["reward_granted_before_failure"] = True
        self.assertTrue(any("before_failure" in error for error in validate_ledger(item)))

    def test_recovery_is_exactly_once(self):
        item = evidence()
        item["activities"][3]["recovery_once"] = False
        self.assertTrue(any("recovery_once" in error for error in validate_ledger(item)))

    def test_runtime_authority_is_external(self):
        item = evidence()
        item["authority"]["recovery"] = True
        self.assertTrue(any("authority.recovery" in error for error in validate_ledger(item)))

    def test_native_claim_fails_closed(self):
        item = copy.deepcopy(evidence())
        item["native_claims"] = True
        self.assertTrue(any("native_claims" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
