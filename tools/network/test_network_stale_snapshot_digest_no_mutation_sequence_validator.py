import copy
import hashlib
import unittest

try:
    from .network_stale_snapshot_digest_no_mutation_sequence_validator import validate_digest_guard
except ImportError:  # Direct invocation from the tools/network directory.
    from network_stale_snapshot_digest_no_mutation_sequence_validator import validate_digest_guard


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _guard() -> dict:
    digest = _digest("current")
    return {
        "schema_version": 1,
        "evidence_scope": "network_stale_snapshot_digest_no_mutation_sequence",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"sequence": 8, "peer_generation": 3, "digest": digest},
        "attempts": [
            {"kind": kind, "accepted": False, "status": "stale_snapshot_digest", "server_rejected": True, "state_changed": False, "mutation_fields": [], "after_digest": digest, "after_sequence": 8, "after_peer_generation": 3, "attempted_digest": _digest("old") if kind == "stale_digest" else digest, "attempted_sequence": 7 if kind != "stale_digest" else 8}
            for kind in ("stale_digest", "stale_sequence", "digest_sequence_mismatch")
        ],
        "accepted_next": {"accepted": True, "status": "snapshot_accepted", "sequence": 9, "server_committed": True},
        "snapshot_detached": True,
    }


class NetworkStaleSnapshotDigestNoMutationSequenceValidatorTest(unittest.TestCase):
    def test_accepts_digest_first_no_mutation_guard(self):
        self.assertEqual(validate_digest_guard(_guard()), [])

    def test_rejects_current_digest_as_stale(self):
        report = _guard()
        report["attempts"][0]["attempted_digest"] = report["current"]["digest"]
        self.assertTrue(any("attempted_digest must be stale" in error for error in validate_digest_guard(report)))

    def test_rejects_current_sequence_as_stale(self):
        report = _guard()
        report["attempts"][1]["attempted_sequence"] = 8
        self.assertTrue(any("attempted_sequence must be older" in error for error in validate_digest_guard(report)))

    def test_rejects_mutation_fields(self):
        report = _guard()
        report["attempts"][2]["mutation_fields"] = ["digest"]
        self.assertTrue(any("must have no mutation" in error for error in validate_digest_guard(report)))

    def test_rejects_missing_digest_guard(self):
        report = _guard()
        report["attempts"] = report["attempts"][:-1]
        self.assertTrue(any("digest_sequence_mismatch" in error for error in validate_digest_guard(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_guard())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_digest_guard(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
