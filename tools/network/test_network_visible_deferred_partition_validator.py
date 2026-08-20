import copy
import unittest

try:
    from .network_visible_deferred_partition_validator import validate_partition
except ImportError:  # Direct invocation from the tools/network directory.
    from network_visible_deferred_partition_validator import validate_partition


def _partition() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_visible_deferred_partition",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer_id": 7,
        "audit": {"server_owns_interest": True, "server_owns_replication_budget": True, "client_can_mutate_state": False},
        "candidate_entity_ids": ["alpha", "bravo", "charlie", "outside"],
        "visible_entity_ids": ["alpha"],
        "deferred_entity_ids": ["bravo", "charlie"],
        "excluded_entity_ids": ["outside"],
        "max_entities_per_tick": 1,
        "max_deferred_entities": 3,
        "entities": [
            {"entity_id": "alpha", "in_interest": True},
            {"entity_id": "bravo", "in_interest": True},
            {"entity_id": "charlie", "in_interest": True},
            {"entity_id": "outside", "in_interest": False},
        ],
        "batch_receipt": {"accepted": True, "status": "rate_limited", "source_peer_id": 99, "authority_peer_id": 99, "peer_id": 7, "visible_count": 1, "deferred_count": 2, "snapshot_detached": True},
    }


class NetworkVisibleDeferredPartitionValidatorTest(unittest.TestCase):
    def test_accepts_complete_partition(self):
        self.assertEqual(validate_partition(_partition()), [])

    def test_rejects_partition_gap(self):
        report = _partition()
        report["deferred_entity_ids"] = ["bravo"]
        self.assertTrue(any("cover every candidate" in error for error in validate_partition(report)))

    def test_rejects_partition_overlap(self):
        report = _partition()
        report["excluded_entity_ids"] = ["outside", "alpha"]
        self.assertTrue(any("must be disjoint" in error for error in validate_partition(report)))

    def test_rejects_visible_capacity_overflow(self):
        report = copy.deepcopy(_partition())
        report["max_entities_per_tick"] = 0
        self.assertTrue(any("max_entities_per_tick" in error for error in validate_partition(report)))

    def test_rejects_incorrect_batch_counts(self):
        report = _partition()
        report["batch_receipt"]["deferred_count"] = 1
        self.assertTrue(any("counts must match" in error for error in validate_partition(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _partition()
        report["audit"]["client_can_mutate_state"] = True
        report["uses_live_network"] = True
        errors = validate_partition(report)
        self.assertTrue(any("client_can_mutate_state" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
