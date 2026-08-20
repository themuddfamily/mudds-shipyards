import copy
import hashlib
import unittest

try:
    from .network_snapshot_stale_sequence_no_mutation_validator import validate_sequence
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_stale_sequence_no_mutation_validator import validate_sequence


def _sequence() -> dict:
    digest = hashlib.sha256(b"state").hexdigest()
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_stale_sequence_no_mutation",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"sequence": 8, "peer_generation": 3, "digest": digest},
        "attempts": [
            {"kind": kind, "attempted_sequence": 8 if kind == "duplicate" else 7, "accepted": False, "status": "stale_snapshot_sequence", "server_rejected": True, "state_changed": False, "mutation_fields": [], "after_sequence": 8, "after_peer_generation": 3, "after_digest": digest}
            for kind in ("duplicate", "lower", "out_of_order")
        ],
        "accepted_next": {"accepted": True, "sequence": 9, "server_committed": True},
        "snapshot_detached": True,
    }


class NetworkSnapshotStaleSequenceNoMutationValidatorTest(unittest.TestCase):
    def test_accepts_sequence_no_mutation_evidence(self):
        self.assertEqual(validate_sequence(_sequence()), [])

    def test_rejects_mutation_fields(self):
        report = _sequence()
        report["attempts"][0]["mutation_fields"] = ["sequence"]
        self.assertTrue(any("no state or field mutation" in error for error in validate_sequence(report)))

    def test_rejects_after_state_change(self):
        report = _sequence()
        report["attempts"][1]["after_sequence"] = 9
        self.assertTrue(any("preserve current snapshot state" in error for error in validate_sequence(report)))

    def test_rejects_missing_out_of_order_attempt(self):
        report = _sequence()
        report["attempts"] = report["attempts"][:-1]
        self.assertTrue(any("out_of_order" in error for error in validate_sequence(report)))

    def test_rejects_nonadvancing_next_snapshot(self):
        report = _sequence()
        report["accepted_next"]["sequence"] = 8
        self.assertTrue(any("advance once" in error for error in validate_sequence(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_sequence())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_sequence(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
