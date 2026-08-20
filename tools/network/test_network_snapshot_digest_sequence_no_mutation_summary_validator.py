import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_sequence_no_mutation_summary_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_sequence_no_mutation_summary_validator import validate_summary


def _summary() -> dict:
    digest = hashlib.sha256(b"current").hexdigest()
    attempts = [
        {"kind": "stale_digest", "accepted": False, "mutation_fields": [], "state_changed": False, "after_sequence": 8, "after_digest": digest},
        {"kind": "stale_sequence", "accepted": False, "mutation_fields": [], "state_changed": False, "after_sequence": 8, "after_digest": digest},
        {"kind": "stale_sequence", "accepted": False, "mutation_fields": [], "state_changed": False, "after_sequence": 8, "after_digest": digest},
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_digest_sequence_no_mutation_summary",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"sequence": 8, "digest": digest},
        "attempts": attempts,
        "counters": {"attempt_count": 3, "rejected_count": 3, "mutation_count": 0, "digest_rejection_count": 1, "sequence_rejection_count": 2},
        "accepted_next_sequence": 9,
        "snapshot_detached": True,
    }


class NetworkSnapshotDigestSequenceNoMutationSummaryValidatorTest(unittest.TestCase):
    def test_accepts_consistent_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_wrong_attempt_count(self):
        report = _summary()
        report["counters"]["attempt_count"] = 2
        self.assertTrue(any("attempt_count" in error for error in validate_summary(report)))

    def test_rejects_wrong_digest_rejection_count(self):
        report = _summary()
        report["counters"]["digest_rejection_count"] = 0
        self.assertTrue(any("digest_rejection_count" in error for error in validate_summary(report)))

    def test_rejects_mutation_in_detail(self):
        report = _summary()
        report["attempts"][0]["mutation_fields"] = ["digest"]
        self.assertTrue(any("must have no mutation" in error for error in validate_summary(report)))

    def test_rejects_nonadvancing_next_sequence(self):
        report = _summary()
        report["accepted_next_sequence"] = 8
        self.assertTrue(any("advance once" in error for error in validate_summary(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
