import copy
import unittest

try:
    from .network_interest_rejection_generation_guard_validator import validate_guard
except ImportError:  # Direct invocation from the tools/network directory.
    from network_interest_rejection_generation_guard_validator import validate_guard


def _guard() -> dict:
    statuses = ["stale_peer_generation", "stale_subscription_generation", "replayed_update", "unknown_peer"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_interest_rejection_generation_guard",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "audit": {"server_owns_interest": True, "server_owns_peer_generation": True, "client_can_mutate_interest": False},
        "current": {"peer_id": 7, "peer_generation": 3, "subscription_generation": 4, "last_update_sequence": 8, "region_digest": "region-current"},
        "accepted_update": {"accepted": True, "status": "interest_updated", "peer_id": 7, "peer_generation": 3, "subscription_generation": 4, "sequence": 9, "server_committed": True},
        "rejections": [
            {
                "status": status, "accepted": False, "server_rejected": True,
                "peer_id": 0 if status == "unknown_peer" else 7,
                "attempted_generation": 2 if status in {"stale_peer_generation", "stale_subscription_generation"} else 0,
                "attempted_sequence": 8 if status == "replayed_update" else 0,
                "region_changed": False, "peer_generation_changed": False,
                "subscription_generation_changed": False, "region_digest_after": "region-current",
                "peer_generation_after": 3, "subscription_generation_after": 4,
            }
            for status in statuses
        ],
        "snapshot_detached": True,
    }


class NetworkInterestRejectionGenerationGuardValidatorTest(unittest.TestCase):
    def test_accepts_current_update_and_stale_generation_rejections(self):
        self.assertEqual(validate_guard(_guard()), [])

    def test_rejects_stale_attempt_that_changes_region(self):
        report = _guard()
        report["rejections"][0]["region_changed"] = True
        self.assertTrue(any("region_changed" in error for error in validate_guard(report)))

    def test_rejects_stale_attempt_that_changes_generation(self):
        report = _guard()
        report["rejections"][1]["subscription_generation_after"] = 5
        self.assertTrue(any("retain current generations" in error for error in validate_guard(report)))

    def test_rejects_replay_ahead_of_current_sequence(self):
        report = _guard()
        report["rejections"][2]["attempted_sequence"] = 9
        self.assertTrue(any("not be newer" in error for error in validate_guard(report)))

    def test_rejects_missing_generation_rejection(self):
        report = _guard()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("unknown_peer" in error for error in validate_guard(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = copy.deepcopy(_guard())
        report["audit"]["client_can_mutate_interest"] = True
        report["uses_live_network"] = True
        errors = validate_guard(report)
        self.assertTrue(any("client_can_mutate_interest" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
