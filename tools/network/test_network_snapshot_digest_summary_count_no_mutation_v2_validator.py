import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_summary_count_no_mutation_v2_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_summary_count_no_mutation_v2_validator import validate_summary


def _summary() -> dict:
    expected = hashlib.sha256(b"current").hexdigest()
    stale = hashlib.sha256(b"older").hexdigest()
    observation = lambda kind, accepted, digest: {
        "kind": kind,
        "accepted": accepted,
        "digest": digest,
        "mutation_fields": [],
        "state_changed": False,
    }
    return {
        "schema_version": 2,
        "evidence_scope": "network_snapshot_digest_summary_count_no_mutation_v2",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "expected_digest": expected,
        "observations": [
            observation("accepted", True, expected),
            observation("stale_digest", False, stale),
            observation("invalid_digest", False, "not-a-digest"),
        ],
        "summary": {
            "total": 3,
            "accepted": 1,
            "stale_digest_rejected": 1,
            "invalid_digest_rejected": 1,
            "rejected": 2,
            "mutation_count": 0,
        },
    }


class NetworkSnapshotDigestSummaryCountNoMutationV2ValidatorTest(unittest.TestCase):
    def test_accepts_consistent_v2_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_mutation_detail(self):
        report = _summary()
        report["observations"][0]["mutation_fields"] = ["digest"]
        errors = validate_summary(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("mutation_count" in error for error in errors))

    def test_rejects_nonzero_mutation_count_even_without_detail(self):
        report = _summary()
        report["summary"]["mutation_count"] = 1
        self.assertTrue(any("must be zero" in error for error in validate_summary(report)))

    def test_rejects_wrong_digest_classification(self):
        report = _summary()
        report["observations"][1]["digest"] = report["expected_digest"]
        self.assertTrue(any("different lowercase SHA-256" in error for error in validate_summary(report)))

    def test_rejects_wrong_count(self):
        report = _summary()
        report["summary"]["stale_digest_rejected"] = 0
        self.assertTrue(any("stale_digest_rejected" in error for error in validate_summary(report)))

    def test_rejects_live_native_or_detached_claims(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["native_claims"] = True
        report["no_mutation_guarantee"] = False
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("no_mutation_guarantee" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
