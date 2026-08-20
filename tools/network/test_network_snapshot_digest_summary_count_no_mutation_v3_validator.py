import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_summary_count_no_mutation_v3_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_summary_count_no_mutation_v3_validator import validate_summary


def _record(kind: str, accepted: bool, digest: str) -> dict:
    return {
        "kind": kind,
        "accepted": accepted,
        "digest": digest,
        "mutation_fields": [],
        "state_changed": False,
    }


def _summary() -> dict:
    expected = hashlib.sha256(b"current").hexdigest()
    stale = hashlib.sha256(b"older").hexdigest()
    return {
        "schema_version": 3,
        "evidence_scope": "network_snapshot_digest_summary_count_no_mutation_v3",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "expected_digest": expected,
        "records": [
            _record("accepted", True, expected),
            _record("stale_digest", False, stale),
            _record("invalid_digest", False, "invalid"),
        ],
        "counts": {
            "by_kind": {"accepted": 1, "stale_digest": 1, "invalid_digest": 1},
            "total": 3,
            "rejected": 2,
            "mutations": 0,
        },
    }


class NetworkSnapshotDigestSummaryCountNoMutationV3ValidatorTest(unittest.TestCase):
    def test_accepts_consistent_v3_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_nested_kind_count(self):
        report = _summary()
        report["counts"]["by_kind"]["stale_digest"] = 0
        self.assertTrue(any("by_kind.stale_digest" in error for error in validate_summary(report)))

    def test_rejects_mutation_record(self):
        report = _summary()
        report["records"][0]["state_changed"] = True
        errors = validate_summary(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_nonzero_mutation_count(self):
        report = _summary()
        report["counts"]["mutations"] = 1
        self.assertTrue(any("must be zero" in error for error in validate_summary(report)))

    def test_rejects_accepted_digest_mismatch(self):
        report = _summary()
        report["records"][0]["digest"] = hashlib.sha256(b"other").hexdigest()
        self.assertTrue(any("match expected_digest" in error for error in validate_summary(report)))

    def test_rejects_live_or_native_fixture_claim(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
