import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_sequence_summary_no_mutation_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_sequence_summary_no_mutation_validator import validate_summary


def _summary() -> dict:
    initial_digest = hashlib.sha256(b"initial").hexdigest()
    final_digest = hashlib.sha256(b"final").hexdigest()
    details = [
        {"kind": "stale_digest", "accepted": False, "mutation_fields": [], "state_changed": False, "after_sequence": 9, "after_digest": final_digest},
        {"kind": "stale_sequence", "accepted": False, "mutation_fields": [], "state_changed": False, "after_sequence": 9, "after_digest": final_digest},
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_digest_sequence_summary_no_mutation",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "initial": {"sequence": 8, "digest": initial_digest},
        "final": {"sequence": 9, "digest": final_digest},
        "details": details,
        "summary": {"total_attempts": 2, "stale_rejections": 2, "state_mutations": 0, "digest_rejections": 1, "sequence_rejections": 1, "accepted_updates": 1},
        "snapshot_detached": True,
    }


class NetworkSnapshotDigestSequenceSummaryNoMutationValidatorTest(unittest.TestCase):
    def test_accepts_consistent_aggregate_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_wrong_digest_count(self):
        report = _summary()
        report["summary"]["digest_rejections"] = 0
        self.assertTrue(any("digest_rejections" in error for error in validate_summary(report)))

    def test_rejects_mutation_detail(self):
        report = _summary()
        report["details"][0]["mutation_fields"] = ["digest"]
        self.assertTrue(any("must have no mutation" in error for error in validate_summary(report)))

    def test_rejects_final_sequence_without_advance(self):
        report = _summary()
        report["final"]["sequence"] = 8
        self.assertTrue(any("advance once" in error for error in validate_summary(report)))

    def test_rejects_detail_not_matching_final_state(self):
        report = _summary()
        report["details"][1]["after_sequence"] = 8
        self.assertTrue(any("must match final state" in error for error in validate_summary(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
