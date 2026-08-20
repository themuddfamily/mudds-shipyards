import copy
import unittest

try:
    from .network_interest_cleanup_detachment_validator import validate_cleanup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_interest_cleanup_detachment_validator import validate_cleanup


def _cleanup() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_interest_cleanup_detachment",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer_id": 7,
        "audit": {
            "server_owns_interest": True,
            "server_owns_entity_generations": True,
            "server_owns_ownership_transfers": True,
            "client_can_mutate_state": False,
            "client_can_transfer_ownership": False,
        },
        "before": {
            "peer_interest_present": True,
            "entity_ids": ["avatar_a", "remote_a"],
            "peer_owned_entity_ids": ["avatar_a"],
        },
        "cleanup_receipt": {
            "accepted": True,
            "status": "peer_disconnected",
            "source_peer_id": 99,
            "authority_peer_id": 99,
            "peer_id": 7,
            "interest_removed": True,
            "peer_removed": True,
            "ownership_detached": True,
            "retained_entity_ids": ["avatar_a", "remote_a"],
        },
        "after": {
            "peer_interest_present": False,
            "entity_ids": ["avatar_a", "remote_a"],
            "unowned_entity_ids": ["avatar_a"],
            "entity_generations_preserved": True,
            "snapshot_detached": True,
        },
        "stale_update": {
            "accepted": False,
            "status": "unknown_peer",
            "server_rejected": True,
            "recreated_interest": False,
        },
    }


class NetworkInterestCleanupDetachmentValidatorTest(unittest.TestCase):
    def test_accepts_subscription_cleanup_and_entity_retention(self):
        self.assertEqual(validate_cleanup(_cleanup()), [])

    def test_rejects_entity_deletion_during_interest_cleanup(self):
        report = _cleanup()
        report["cleanup_receipt"]["retained_entity_ids"] = ["remote_a"]
        self.assertTrue(any("preserve all entities" in error for error in validate_cleanup(report)))

    def test_rejects_interest_subscription_left_active(self):
        report = _cleanup()
        report["after"]["peer_interest_present"] = True
        self.assertTrue(any("peer_interest_present" in error for error in validate_cleanup(report)))

    def test_rejects_owned_entity_not_detached(self):
        report = _cleanup()
        report["after"]["unowned_entity_ids"] = []
        self.assertTrue(any("unowned_entity_ids" in error for error in validate_cleanup(report)))

    def test_rejects_stale_update_recreating_interest(self):
        report = copy.deepcopy(_cleanup())
        report["stale_update"]["recreated_interest"] = True
        self.assertTrue(any("recreate interest" in error for error in validate_cleanup(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _cleanup()
        report["audit"]["client_can_mutate_state"] = True
        report["uses_live_network"] = True
        errors = validate_cleanup(report)
        self.assertTrue(any("client_can_mutate_state" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
