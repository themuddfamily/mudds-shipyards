import copy
import hashlib
import unittest

try:
    from .network_stale_snapshot_sequence_digest_no_mutation_validator import validate_report
except ImportError:  # Direct invocation from the tools/network directory.
    from network_stale_snapshot_sequence_digest_no_mutation_validator import validate_report


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _report() -> dict:
    current = _digest("current")
    statuses = ["stale_sequence", "stale_digest", "sequence_digest_mismatch"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_stale_snapshot_sequence_digest_no_mutation",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"sequence": 8, "peer_generation": 3, "digest": current},
        "accepted_next": {"accepted": True, "status": "snapshot_accepted", "sequence": 9, "peer_generation": 3, "digest": _digest("next"), "server_committed": True, "snapshot_detached": True},
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True, "state_changed": False, "mutation_fields": [], "after_sequence": 8, "after_peer_generation": 3, "after_digest": current, "attempted_sequence": 7 if status == "stale_sequence" else 8, "attempted_digest": _digest("old") if status == "stale_digest" else current}
            for status in statuses
        ],
        "snapshot_detached": True,
    }


class NetworkStaleSnapshotSequenceDigestNoMutationValidatorTest(unittest.TestCase):
    def test_accepts_combined_no_mutation_fence(self):
        self.assertEqual(validate_report(_report()), [])

    def test_rejects_changed_state_after_stale_attempt(self):
        report = _report()
        report["rejections"][0]["after_sequence"] = 9
        self.assertTrue(any("preserve current" in error for error in validate_report(report)))

    def test_rejects_nonempty_mutation_fields(self):
        report = _report()
        report["rejections"][1]["mutation_fields"] = ["digest"]
        self.assertTrue(any("must have no mutation" in error for error in validate_report(report)))

    def test_rejects_current_sequence_as_stale(self):
        report = _report()
        report["rejections"][0]["attempted_sequence"] = 8
        self.assertTrue(any("attempted_sequence must be older" in error for error in validate_report(report)))

    def test_rejects_missing_mismatch_status(self):
        report = _report()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("sequence_digest_mismatch" in error for error in validate_report(report)))

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_report(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
