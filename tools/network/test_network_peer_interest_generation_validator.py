import copy
import unittest

try:
    from .network_peer_interest_generation_validator import validate_generation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_peer_interest_generation_validator import validate_generation


def _interest() -> dict:
    rejection_statuses = ["unauthorized_source", "stale_peer_generation", "unknown_peer", "invalid_interest_region"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_peer_interest_generation",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "audit": {
            "server_owns_interest": True,
            "server_owns_entity_generations": True,
            "client_can_mutate_state": False,
            "client_can_mutate_interest": False,
        },
        "peer": {
            "peer_id": 7, "peer_generation_before": 1, "peer_generation_after": 2,
            "subscription_generation_before": 1, "subscription_generation_after": 2,
        },
        "region_before": {"center": [0, 0, 0], "radius": 20, "max_entities": 4},
        "region_after": {"center": [50, 0, 0], "radius": 40, "max_entities": 8},
        "update": {
            "accepted": True, "status": "interest_updated", "source_peer_id": 99,
            "authority_peer_id": 99, "peer_id": 7, "peer_generation": 2,
            "subscription_generation": 2, "snapshot_detached": True,
        },
        "stale_updates": [
            {"status": status, "accepted": False, "server_rejected": True, "subscription_generation_changed": False}
            for status in rejection_statuses
        ],
    }


class NetworkPeerInterestGenerationValidatorTest(unittest.TestCase):
    def test_accepts_new_peer_and_subscription_generations(self):
        self.assertEqual(validate_generation(_interest()), [])

    def test_rejects_peer_generation_rollback(self):
        report = _interest()
        report["peer"]["peer_generation_after"] = 1
        self.assertTrue(any("peer_generation_after must advance" in error for error in validate_generation(report)))

    def test_rejects_subscription_generation_rollback(self):
        report = _interest()
        report["peer"]["subscription_generation_after"] = 1
        self.assertTrue(any("subscription_generation_after must advance" in error for error in validate_generation(report)))

    def test_rejects_update_from_stale_peer_generation(self):
        report = _interest()
        report["update"]["peer_generation"] = 1
        self.assertTrue(any("current peer generation" in error for error in validate_generation(report)))

    def test_rejects_stale_update_that_changes_subscription(self):
        report = copy.deepcopy(_interest())
        report["stale_updates"][0]["subscription_generation_changed"] = True
        self.assertTrue(any("subscription_generation_changed" in error for error in validate_generation(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _interest()
        report["audit"]["client_can_mutate_interest"] = True
        report["uses_live_network"] = True
        errors = validate_generation(report)
        self.assertTrue(any("client_can_mutate_interest" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
