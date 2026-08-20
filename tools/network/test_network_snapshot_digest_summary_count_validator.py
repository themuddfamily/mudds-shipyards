import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_summary_count_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_summary_count_validator import validate_summary


def _summary() -> dict:
    expected = hashlib.sha256(b"current").hexdigest()
    stale = hashlib.sha256(b"older").hexdigest()
    return {
        "schema_version": 1,
        "evidence_scope": "network_snapshot_digest_summary_count",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "expected_digest": expected,
        "observations": [
            {"kind": "accepted", "accepted": True, "digest": expected},
            {"kind": "stale_digest", "accepted": False, "digest": stale},
            {"kind": "invalid_digest", "accepted": False, "digest": "not-a-digest"},
        ],
        "summary": {"total": 3, "accepted": 1, "stale_digest_rejected": 1, "invalid_digest_rejected": 1, "rejected": 2},
    }


class NetworkSnapshotDigestSummaryCountValidatorTest(unittest.TestCase):
    def test_accepts_consistent_counts(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_wrong_rejected_count(self):
        report = _summary()
        report["summary"]["rejected"] = 1
        self.assertTrue(any("summary.rejected" in error for error in validate_summary(report)))

    def test_rejects_accepted_digest_mismatch(self):
        report = _summary()
        report["observations"][0]["digest"] = hashlib.sha256(b"other").hexdigest()
        self.assertTrue(any("match expected_digest" in error for error in validate_summary(report)))

    def test_rejects_stale_digest_that_matches_current(self):
        report = _summary()
        report["observations"][1]["digest"] = report["expected_digest"]
        self.assertTrue(any("different lowercase SHA-256" in error for error in validate_summary(report)))

    def test_rejects_valid_digest_classified_as_invalid(self):
        report = _summary()
        report["observations"][2]["digest"] = hashlib.sha256(b"malformed").hexdigest()
        self.assertTrue(any("digest must be invalid" in error for error in validate_summary(report)))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
