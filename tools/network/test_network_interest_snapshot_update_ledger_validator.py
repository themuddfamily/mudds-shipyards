import copy
import unittest

try:
    from .network_interest_snapshot_update_ledger_validator import validate_snapshot
except ImportError:  # Direct invocation from the tools/network directory.
    from network_interest_snapshot_update_ledger_validator import validate_snapshot


def _snapshot() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_interest_snapshot_update_ledger",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "audit": {"server_owns_interest": True, "server_owns_entity_generations": True, "client_can_mutate_state": False},
        "before": {"peer_id": 7, "peer_generation": 3, "subscription_generation": 4, "region_digest": "region-a"},
        "after": {
            "peer_id": 7, "peer_generation": 3, "subscription_generation": 5, "region_digest": "region-b",
            "entity_ids": ["alpha", "bravo", "charlie"], "visible_entity_ids": ["alpha", "bravo"],
            "deferred_entity_ids": ["charlie"], "unchanged_entity_ids": [], "max_entities": 2,
            "visible_entries": [
                {"entity_id": "alpha", "state_revision": 2, "entity_generation": 1, "owner_peer_id": 7, "detached": True},
                {"entity_id": "bravo", "state_revision": 1, "entity_generation": 2, "owner_peer_id": 0, "detached": True},
            ],
        },
        "update_receipt": {"accepted": True, "status": "interest_updated", "source_peer_id": 99, "authority_peer_id": 99, "peer_id": 7, "peer_generation": 3, "subscription_generation": 5, "snapshot_detached": True},
    }


class NetworkInterestSnapshotUpdateLedgerValidatorTest(unittest.TestCase):
    def test_accepts_detached_visible_and_deferred_snapshot(self):
        self.assertEqual(validate_snapshot(_snapshot()), [])

    def test_rejects_visible_entry_set_mismatch(self):
        report = _snapshot()
        report["after"]["visible_entries"] = report["after"]["visible_entries"][:1]
        self.assertTrue(any("exactly match visible" in error for error in validate_snapshot(report)))

    def test_rejects_duplicate_or_overlapping_sets(self):
        report = _snapshot()
        report["after"]["unchanged_entity_ids"] = ["alpha"]
        self.assertTrue(any("sets must be disjoint" in error for error in validate_snapshot(report)))

    def test_rejects_snapshot_generation_rollback(self):
        report = _snapshot()
        report["after"]["subscription_generation"] = 4
        self.assertTrue(any("must advance" in error for error in validate_snapshot(report)))

    def test_rejects_visible_capacity_overflow(self):
        report = copy.deepcopy(_snapshot())
        report["after"]["visible_entity_ids"] = ["alpha", "bravo", "charlie"]
        report["after"]["visible_entries"].append({"entity_id": "charlie", "state_revision": 1, "entity_generation": 1, "owner_peer_id": 0, "detached": True})
        report["after"]["deferred_entity_ids"] = []
        self.assertTrue(any("exceeds max_entities" in error for error in validate_snapshot(report)))

    def test_rejects_client_mutation_or_live_claim(self):
        report = _snapshot()
        report["audit"]["client_can_mutate_state"] = True
        report["uses_live_network"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("client_can_mutate_state" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
