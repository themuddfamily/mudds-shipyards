import copy
import hashlib
import unittest

try:
    from .network_snapshot_digest_final_state_authority_summary_v7_validator import validate_summary
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_digest_final_state_authority_summary_v7_validator import validate_summary


def _rejection(kind, after_sequence, after_digest):
    return {
        "authority": "server",
        "kind": kind,
        "accepted": False,
        "after_sequence": after_sequence,
        "after_digest": after_digest,
        "mutation_fields": [],
        "state_changed": False,
    }


def _summary() -> dict:
    initial = hashlib.sha256(b"initial").hexdigest()
    final = hashlib.sha256(b"final").hexdigest()
    return {
        "schema_version": 7,
        "evidence_scope": "network_snapshot_digest_final_state_authority_summary_v7",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "initial": {"sequence": 30, "digest": initial},
        "accepted_update": {
            "authority": "server",
            "accepted": True,
            "sequence": 31,
            "digest": final,
            "mutation_fields": [],
            "state_changed": False,
        },
        "final": {"sequence": 31, "digest": final},
        "rejections": [
            _rejection("stale_digest", 31, final),
            _rejection("stale_sequence", 31, final),
        ],
        "summary": {"rejections": 2, "stale_digest": 1, "stale_sequence": 1, "mutations": 0, "accepted_updates": 1},
    }


class NetworkSnapshotDigestFinalStateAuthoritySummaryV7ValidatorTest(unittest.TestCase):
    def test_accepts_final_state_summary(self):
        self.assertEqual(validate_summary(_summary()), [])

    def test_rejects_nonadvancing_accepted_update(self):
        report = _summary()
        report["accepted_update"]["sequence"] = 30
        self.assertTrue(any("advance once" in error for error in validate_summary(report)))

    def test_rejects_rejection_not_preserving_final(self):
        report = _summary()
        report["rejections"][0]["after_sequence"] = 30
        self.assertTrue(any("preserve final state" in error for error in validate_summary(report)))

    def test_rejects_wrong_rejection_count(self):
        report = _summary()
        report["summary"]["stale_sequence"] = 0
        self.assertTrue(any("summary.stale_sequence" in error for error in validate_summary(report)))

    def test_rejects_mutation_boundary(self):
        report = _summary()
        report["rejections"][1]["state_changed"] = True
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
