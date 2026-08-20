import copy
import hashlib
import unittest

try:
    from .network_snapshot_stale_no_mutation_ledger import validate_ledger
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_stale_no_mutation_ledger import validate_ledger


def _ledger() -> dict:
    state = {"peer_generation": 3, "server_tick": 12, "snapshot_sequence": 8, "partition_digest": hashlib.sha256(b"current").hexdigest(), "visible_ids": ["alpha"], "deferred_ids": ["bravo"]}
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_stale_no_mutation",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "before": state,
        "after": copy.deepcopy(state),
        "attempts": [
            {"status": status, "accepted": False, "server_rejected": True, "state_changed": False, "mutation_fields": [], "after_state": copy.deepcopy(state)}
            for status in ("stale_snapshot_digest", "stale_snapshot_sequence", "stale_peer_generation")
        ],
        "snapshot_detached": True,
    }


class NetworkSnapshotStaleNoMutationLedgerTest(unittest.TestCase):
    def test_accepts_full_state_no_mutation_ledger(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_rejects_changed_after_state(self):
        report = _ledger()
        report["after"]["snapshot_sequence"] = 9
        self.assertTrue(any("after must equal before" in error for error in validate_ledger(report)))

    def test_rejects_nonempty_mutation_fields(self):
        report = _ledger()
        report["attempts"][0]["mutation_fields"] = ["partition_digest"]
        self.assertTrue(any("mutation_fields must be empty" in error for error in validate_ledger(report)))

    def test_rejects_attempt_after_state_mismatch(self):
        report = _ledger()
        report["attempts"][1]["after_state"]["server_tick"] = 13
        self.assertTrue(any("after_state must equal" in error for error in validate_ledger(report)))

    def test_rejects_missing_generation_attempt(self):
        report = _ledger()
        report["attempts"] = report["attempts"][:-1]
        self.assertTrue(any("stale_peer_generation" in error for error in validate_ledger(report)))

    def test_rejects_live_or_attached_snapshot_claim(self):
        report = _ledger()
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_ledger(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
