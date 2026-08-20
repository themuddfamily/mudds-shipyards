import copy
import unittest

try:
    from .network_replication_tick_budget_validator import validate_budget
except ImportError:  # Direct invocation from the tools/network directory.
    from network_replication_tick_budget_validator import validate_budget


def _budget() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_replication_tick_budget",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "uses_live_network": False,
        "policy_version": "network_replication_interest_authority_v1",
        "audit": {"server_owns_replication_budget": True, "client_can_mutate_state": False},
        "limits": {"max_entities_per_tick": 2, "max_bytes_per_tick": 1024, "max_deferred_entities": 3},
        "ticks": [
            {
                "server_tick": 10,
                "sent_entity_ids": ["alpha", "bravo"],
                "deferred_entity_ids": ["charlie"],
                "sent_bytes": 900,
                "remaining_entity_budget": 0,
                "source": "server_adapter",
            },
            {
                "server_tick": 11,
                "sent_entity_ids": ["charlie"],
                "deferred_entity_ids": [],
                "sent_bytes": 500,
                "remaining_entity_budget": 1,
                "source": "server_adapter",
            },
        ],
    }


class NetworkReplicationTickBudgetValidatorTest(unittest.TestCase):
    def test_accepts_bounded_server_batches(self):
        self.assertEqual(validate_budget(_budget()), [])

    def test_rejects_entity_count_overflow(self):
        report = _budget()
        report["ticks"][0]["sent_entity_ids"] = ["alpha", "bravo", "delta"]
        self.assertTrue(any("max_entities_per_tick" in error for error in validate_budget(report)))

    def test_rejects_byte_overflow(self):
        report = _budget()
        report["ticks"][0]["sent_bytes"] = 1025
        self.assertTrue(any("max_bytes_per_tick" in error for error in validate_budget(report)))

    def test_rejects_inconsistent_remaining_budget(self):
        report = _budget()
        report["ticks"][1]["remaining_entity_budget"] = 0
        self.assertTrue(any("remaining_entity_budget" in error for error in validate_budget(report)))

    def test_rejects_duplicate_or_overlapping_ids(self):
        report = copy.deepcopy(_budget())
        report["ticks"][0]["sent_entity_ids"] = ["alpha", "alpha"]
        report["ticks"][0]["deferred_entity_ids"] = ["alpha"]
        errors = validate_budget(report)
        self.assertTrue(any("must not contain duplicates" in error for error in errors))
        self.assertTrue(any("must be disjoint" in error for error in errors))

    def test_rejects_live_claim_and_non_server_source(self):
        report = _budget()
        report["uses_live_network"] = True
        report["ticks"][0]["source"] = "client"
        errors = validate_budget(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("source must be server_adapter" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
