import copy
import unittest

try:
    from .network_interest_rejection_ledger_validator import validate_ledger
except ImportError:  # Direct invocation from the tools/network directory.
    from network_interest_rejection_ledger_validator import validate_ledger


def _ledger() -> dict:
    statuses = ["unauthorized_source", "stale_peer_generation", "unknown_peer", "invalid_interest_region", "invalid_interest_capacity"]
    before = {"center_digest": "center-a", "region_digest": "region-a", "radius": 20, "max_entities": 4, "subscription_generation": 3}
    return {
        "schema_version": 1,
        "evidence_scope": "network_interest_rejection_ledger",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer_id": 7,
        "audit": {"server_owns_interest": True, "client_can_mutate_interest": False},
        "before": before,
        "after": copy.deepcopy(before),
        "attempts": [
            {
                "status": status,
                "accepted": False,
                "server_rejected": True,
                "region_changed": False,
                "subscription_generation_changed": False,
                "peer_interest_created": False,
                "before_region_digest": "region-a",
                "after_region_digest": "region-a",
                "before_subscription_generation": 3,
                "after_subscription_generation": 3,
            }
            for status in statuses
        ],
        "snapshot_detached": True,
    }


class NetworkInterestRejectionLedgerValidatorTest(unittest.TestCase):
    def test_accepts_complete_no_mutation_rejection_ledger(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_rejects_changed_region_after_failed_attempt(self):
        report = _ledger()
        report["attempts"][0]["after_region_digest"] = "region-b"
        self.assertTrue(any("retain the prior region digest" in error for error in validate_ledger(report)))

    def test_rejects_changed_subscription_generation(self):
        report = _ledger()
        report["attempts"][1]["after_subscription_generation"] = 4
        self.assertTrue(any("retain the prior subscription generation" in error for error in validate_ledger(report)))

    def test_rejects_missing_failure_status(self):
        report = _ledger()
        report["attempts"] = report["attempts"][:-1]
        self.assertTrue(any("invalid_interest_capacity" in error for error in validate_ledger(report)))

    def test_rejects_peer_interest_creation_on_rejection(self):
        report = copy.deepcopy(_ledger())
        report["attempts"][0]["peer_interest_created"] = True
        self.assertTrue(any("peer_interest_created" in error for error in validate_ledger(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _ledger()
        report["audit"]["client_can_mutate_interest"] = True
        report["uses_live_network"] = True
        errors = validate_ledger(report)
        self.assertTrue(any("client_can_mutate_interest" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
