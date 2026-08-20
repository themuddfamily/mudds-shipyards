import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_sequence_no_mutation_summary_v5_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_sequence_no_mutation_summary_v5_validator import validate_summary


def _record(ordinal, kind, sequence, digest, accepted, after_sequence, after_digest):
    return {
        "ordinal": ordinal,
        "kind": kind,
        "sequence": sequence,
        "digest": digest,
        "accepted": accepted,
        "after_sequence": after_sequence,
        "after_digest": after_digest,
        "mutation_fields": [],
        "state_changed": False,
    }


def _summary() -> dict:
    initial = hashlib.sha256(b"initial").hexdigest()
    accepted = hashlib.sha256(b"accepted").hexdigest()
    final = hashlib.sha256(b"final").hexdigest()
    stale = hashlib.sha256(b"stale").hexdigest()
    return {
        "schema_version": 5,
        "evidence_scope": "network_snapshot_digest_sequence_no_mutation_summary_v5",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "initial": {"sequence": 10, "digest": initial},
        "records": [
            _record(1, "accepted", 11, accepted, True, 11, accepted),
            _record(2, "stale_digest", 11, stale, False, 11, accepted),
            _record(3, "stale_sequence", 10, initial, False, 11, accepted),
            _record(4, "accepted", 12, final, True, 12, final),
        ],
        "final": {"sequence": 12, "digest": final},
        "summary": {"total": 4, "accepted": 2, "stale_digest": 1, "stale_sequence": 1, "rejected": 2, "mutations": 0},
    }


class NetworkSnapshotDigestSequenceNoMutationSummaryV5ValidatorTest(unittest.TestCase):
    def test_accepts_ordered_sequence_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_wrong_record_order(self):
        report = _summary()
        report["records"][1]["ordinal"] = 3
        self.assertTrue(any("ordinal" in error for error in validate_summary(report)))

    def test_rejects_nonadvancing_accepted_sequence(self):
        report = _summary()
        report["records"][3]["sequence"] = 11
        self.assertTrue(any("advance once" in error for error in validate_summary(report)))

    def test_rejects_stale_record_state_change(self):
        report = _summary()
        report["records"][1]["after_sequence"] = 12
        self.assertTrue(any("preserve or publish" in error for error in validate_summary(report)))

    def test_rejects_mutation_and_summary_count(self):
        report = _summary()
        report["records"][0]["mutation_fields"] = ["digest"]
        errors = validate_summary(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("summary.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_summary())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_summary(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
