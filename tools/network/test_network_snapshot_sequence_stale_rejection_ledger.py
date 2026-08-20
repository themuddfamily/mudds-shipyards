import copy
import hashlib
import unittest

try:
    from .network_snapshot_sequence_stale_rejection_ledger import validate_ledger
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_sequence_stale_rejection_ledger import validate_ledger


def _ledger() -> dict:
    digest = hashlib.sha256(b"current").hexdigest()
    statuses = ["duplicate_snapshot_sequence", "lower_snapshot_sequence", "out_of_order_snapshot_sequence"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_sequence_stale_rejection",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"sequence": 8, "digest": digest, "peer_generation": 3},
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True, "attempted_sequence": 7 if status != "duplicate_snapshot_sequence" else 8, "current_sequence": 8, "current_digest": digest, "current_peer_generation": 3, "state_changed": False, "cursor_changed": False}
            for status in statuses
        ],
        "accepted_next": {"accepted": True, "status": "snapshot_accepted", "sequence": 9, "server_committed": True},
        "snapshot_detached": True,
    }


class NetworkSnapshotSequenceStaleRejectionLedgerTest(unittest.TestCase):
    def test_accepts_sequence_rejection_ledger(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_rejects_attempt_at_current_sequence(self):
        report = _ledger()
        report["rejections"][1]["attempted_sequence"] = 8
        self.assertTrue(any("must be stale" in error for error in validate_ledger(report)))

    def test_rejects_cursor_mutation(self):
        report = _ledger()
        report["rejections"][0]["cursor_changed"] = True
        self.assertTrue(any("state or cursor" in error for error in validate_ledger(report)))

    def test_rejects_missing_sequence_status(self):
        report = _ledger()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("out_of_order_snapshot_sequence" in error for error in validate_ledger(report)))

    def test_rejects_nonadvancing_accepted_snapshot(self):
        report = _ledger()
        report["accepted_next"]["sequence"] = 8
        self.assertTrue(any("advance once" in error for error in validate_ledger(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_ledger())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_ledger(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
