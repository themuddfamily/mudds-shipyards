import copy
import unittest

try:
    from .network_interest_generation_update_ledger_validator import validate_updates
except ImportError:  # Direct invocation from the tools/network directory.
    from network_interest_generation_update_ledger_validator import validate_updates


def _ledger() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_interest_generation_update_ledger",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer": {"peer_id": 7, "peer_generation": 3, "subscription_generation": 4, "update_sequence": 8, "region_digest": "region-a"},
        "audit": {"server_owns_interest": True, "server_owns_peer_generation": True, "client_can_mutate_interest": False},
        "updates": [
            {"accepted": True, "status": "interest_updated", "source_peer_id": 99, "authority_peer_id": 99, "peer_id": 7, "peer_generation": 3, "subscription_generation": 5, "update_sequence": 9, "region_digest": "region-b", "max_entities": 4, "visible_entity_count": 2, "snapshot_detached": True},
            {"accepted": True, "status": "interest_updated", "source_peer_id": 99, "authority_peer_id": 99, "peer_id": 7, "peer_generation": 3, "subscription_generation": 6, "update_sequence": 10, "region_digest": "region-c", "max_entities": 8, "visible_entity_count": 4, "snapshot_detached": True},
        ],
        "final": {"subscription_generation": 6, "update_sequence": 10, "region_digest": "region-c", "active": True},
    }


class NetworkInterestGenerationUpdateLedgerValidatorTest(unittest.TestCase):
    def test_accepts_monotonic_current_generation_updates(self):
        self.assertEqual(validate_updates(_ledger()), [])

    def test_rejects_subscription_generation_replay(self):
        report = _ledger()
        report["updates"][1]["subscription_generation"] = 5
        self.assertTrue(any("subscription_generation must advance" in error for error in validate_updates(report)))

    def test_rejects_update_sequence_replay(self):
        report = _ledger()
        report["updates"][1]["update_sequence"] = 9
        self.assertTrue(any("update_sequence must advance" in error for error in validate_updates(report)))

    def test_rejects_visible_count_over_capacity(self):
        report = _ledger()
        report["updates"][0]["visible_entity_count"] = 5
        self.assertTrue(any("visible_entity_count exceeds" in error for error in validate_updates(report)))

    def test_rejects_wrong_peer_generation_or_final_snapshot(self):
        report = copy.deepcopy(_ledger())
        report["updates"][0]["peer_generation"] = 2
        report["final"]["region_digest"] = "wrong"
        errors = validate_updates(report)
        self.assertTrue(any("current peer generation" in error for error in errors))
        self.assertTrue(any("final must match" in error for error in errors))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _ledger()
        report["audit"]["client_can_mutate_interest"] = True
        report["uses_live_network"] = True
        errors = validate_updates(report)
        self.assertTrue(any("client_can_mutate_interest" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
