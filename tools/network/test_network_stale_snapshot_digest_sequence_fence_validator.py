import hashlib
import unittest

try:
    from .network_stale_snapshot_digest_sequence_fence_validator import validate_fence
except ImportError:  # Direct invocation from the tools/network directory.
    from network_stale_snapshot_digest_sequence_fence_validator import validate_fence


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _fence() -> dict:
    current = _digest("current")
    next_digest = _digest("next")
    statuses = ["stale_snapshot_sequence", "stale_snapshot_digest", "sequence_digest_mismatch"]
    return {
        "schema_version": 1,
        "evidence_scope": "network_stale_snapshot_digest_sequence_fence",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "current": {"sequence": 8, "digest": current},
        "accepted_next": {"accepted": True, "status": "snapshot_accepted", "sequence": 9, "digest": next_digest, "server_committed": True, "snapshot_detached": True},
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True, "state_changed": False, "current_sequence": 8, "current_digest": current, "attempted_sequence": 7 if status == "stale_snapshot_sequence" else 8, "attempted_digest": _digest("old") if status == "stale_snapshot_digest" else current}
            for status in statuses
        ],
        "client_can_mutate_fence": False,
    }


class NetworkStaleSnapshotDigestSequenceFenceValidatorTest(unittest.TestCase):
    def test_accepts_paired_digest_sequence_fence(self):
        self.assertEqual(validate_fence(_fence()), [])

    def test_rejects_current_sequence_as_stale(self):
        report = _fence()
        report["rejections"][0]["attempted_sequence"] = 8
        self.assertTrue(any("attempted_sequence must be older" in error for error in validate_fence(report)))

    def test_rejects_current_digest_as_stale(self):
        report = _fence()
        report["rejections"][1]["attempted_digest"] = report["current"]["digest"]
        self.assertTrue(any("attempted_digest must be stale" in error for error in validate_fence(report)))

    def test_rejects_next_sequence_without_digest_change(self):
        report = _fence()
        report["accepted_next"]["digest"] = report["current"]["digest"]
        self.assertTrue(any("digest must change" in error for error in validate_fence(report)))

    def test_rejects_missing_mismatch_rejection(self):
        report = _fence()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("sequence_digest_mismatch" in error for error in validate_fence(report)))

    def test_rejects_client_or_live_claim(self):
        report = _fence()
        report["client_can_mutate_fence"] = True
        report["uses_live_network"] = True
        errors = validate_fence(report)
        self.assertTrue(any("client_can_mutate_fence" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
