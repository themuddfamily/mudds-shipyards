import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_summary_count_no_mutation_v4_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_summary_count_no_mutation_v4_validator import validate_summary


def _entry(classification: str, accepted: bool, digest: str) -> dict:
    return {
        "classification": classification,
        "accepted": accepted,
        "digest": digest,
        "mutation_fields": [],
        "state_changed": False,
    }


def _summary() -> dict:
    expected = hashlib.sha256(b"current").hexdigest()
    mismatch = hashlib.sha256(b"older").hexdigest()
    return {
        "schema_version": 4,
        "evidence_scope": "network_snapshot_digest_summary_count_no_mutation_v4",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "expected_digest": expected,
        "entries": [
            _entry("accepted", True, expected),
            _entry("digest_mismatch", False, mismatch),
            _entry("invalid_digest", False, "invalid"),
        ],
        "totals": {
            "entries": 3,
            "accepted": 1,
            "digest_mismatches": 1,
            "invalid_digests": 1,
            "rejected": 2,
            "mutations": 0,
        },
    }


class NetworkSnapshotDigestSummaryCountNoMutationV4ValidatorTest(unittest.TestCase):
    def test_accepts_consistent_v4_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_wrong_total(self):
        report = _summary()
        report["totals"]["entries"] = 2
        self.assertTrue(any("totals.entries" in error for error in validate_summary(report)))

    def test_rejects_wrong_classification_count(self):
        report = _summary()
        report["totals"]["digest_mismatches"] = 0
        self.assertTrue(any("totals.digest_mismatches" in error for error in validate_summary(report)))

    def test_rejects_mutation_entry(self):
        report = _summary()
        report["entries"][0]["mutation_fields"] = ["digest"]
        errors = validate_summary(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("totals.mutations" in error for error in errors))

    def test_rejects_valid_digest_marked_invalid(self):
        report = _summary()
        report["entries"][2]["digest"] = report["expected_digest"]
        self.assertTrue(any("digest must be invalid" in error for error in validate_summary(report)))

    def test_rejects_live_native_or_detached_claims(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["native_claims"] = True
        report["snapshot_detached"] = False
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
