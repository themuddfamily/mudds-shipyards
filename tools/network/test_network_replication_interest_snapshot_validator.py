import copy
import unittest

try:
    from .network_replication_interest_snapshot_validator import validate_snapshot
except ImportError:  # Direct invocation from the tools/network directory.
    from network_replication_interest_snapshot_validator import validate_snapshot


def _snapshot() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "network_replication_interest_snapshot",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "uses_live_network": False,
        "policy_version": "network_replication_interest_authority_v1",
        "audit": {
            "server_owns_interest": True,
            "server_owns_replication_budget": True,
            "server_owns_entity_generations": True,
            "server_owns_ownership_transfers": True,
            "client_can_mutate_state": False,
            "client_can_transfer_ownership": False,
        },
        "peer": {"peer_id": 7, "center": [0, 0, 0], "radius": 20, "max_entities": 1},
        "candidates": [
            {
                "entity_id": "near",
                "entity_generation": 3,
                "owner_peer_id": 7,
                "position": [0, 0, -5],
                "replication_radius": 20,
                "state_revision": 1,
            },
            {
                "entity_id": "outside",
                "entity_generation": 2,
                "owner_peer_id": 8,
                "position": [100, 0, 0],
                "replication_radius": 20,
                "state_revision": 1,
            },
            {
                "entity_id": "queued",
                "entity_generation": 1,
                "owner_peer_id": 0,
                "position": [0, 0, 4],
                "replication_radius": 20,
                "state_revision": 1,
            },
        ],
        "visible_entity_ids": ["near"],
        "deferred_entity_ids": ["queued"],
        "excluded_entity_ids": ["outside"],
    }


class NetworkReplicationInterestSnapshotValidatorTest(unittest.TestCase):
    def test_accepts_bounded_interest_split(self):
        self.assertEqual(validate_snapshot(_snapshot()), [])

    def test_rejects_in_interest_entity_omitted_from_batch(self):
        report = _snapshot()
        report["deferred_entity_ids"] = []
        self.assertTrue(any("missing from visible/deferred" in error for error in validate_snapshot(report)))

    def test_rejects_out_of_interest_entity_as_visible(self):
        report = _snapshot()
        report["visible_entity_ids"] = ["outside"]
        report["deferred_entity_ids"] = ["queued"]
        report["excluded_entity_ids"] = []
        errors = validate_snapshot(report)
        self.assertTrue(any("out-of-interest entity outside" in error for error in errors))
        self.assertTrue(any("in-interest entity near" in error for error in errors))

    def test_rejects_capacity_overflow(self):
        report = _snapshot()
        report["visible_entity_ids"] = ["near", "queued"]
        report["deferred_entity_ids"] = []
        self.assertTrue(any("exceeds peer.max_entities" in error for error in validate_snapshot(report)))

    def test_rejects_client_mutation_and_native_claims(self):
        report = copy.deepcopy(_snapshot())
        report["audit"]["client_can_mutate_state"] = True
        report["native_claims"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("client_can_mutate_state" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))

    def test_rejects_unstable_candidate_order(self):
        report = _snapshot()
        report["candidates"][0], report["candidates"][1] = report["candidates"][1], report["candidates"][0]
        self.assertTrue(any("candidates must be sorted" in error for error in validate_snapshot(report)))


if __name__ == "__main__":
    unittest.main()
