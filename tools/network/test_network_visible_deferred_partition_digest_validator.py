import copy
import unittest

try:
    from .network_visible_deferred_partition_digest_validator import (
        canonical_partition_payload,
        partition_digest,
        validate_digest,
    )
except ImportError:  # Direct invocation from the tools/network directory.
    from network_visible_deferred_partition_digest_validator import (
        canonical_partition_payload,
        partition_digest,
        validate_digest,
    )


def _digest() -> dict:
    report = {
        "schema_version": 1,
        "evidence_scope": "network_visible_deferred_partition_digest",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "peer_id": 7,
        "server_tick": 12,
        "candidate_entity_ids": ["alpha", "bravo", "outside"],
        "visible_entity_ids": ["alpha"],
        "deferred_entity_ids": ["bravo"],
        "excluded_entity_ids": ["outside"],
        "snapshot_detached": True,
    }
    digest = partition_digest(report)
    report["digest"] = {"algorithm": "sha256", "expected": digest, "actual": digest, "canonical_payload": canonical_partition_payload(report)}
    return report


class NetworkVisibleDeferredPartitionDigestValidatorTest(unittest.TestCase):
    def test_accepts_canonical_partition_digest(self):
        self.assertEqual(validate_digest(_digest()), [])

    def test_rejects_tampered_expected_digest(self):
        report = _digest()
        report["digest"]["expected"] = "0" * 64
        self.assertTrue(any("does not match canonical" in error for error in validate_digest(report)))

    def test_rejects_tampered_canonical_payload(self):
        report = _digest()
        report["digest"]["canonical_payload"] = "{}"
        self.assertTrue(any("canonical_payload" in error for error in validate_digest(report)))

    def test_rejects_partition_overlap(self):
        report = _digest()
        report["excluded_entity_ids"] = ["outside", "alpha"]
        self.assertTrue(any("must be disjoint" in error for error in validate_digest(report)))

    def test_digest_changes_when_partition_changes(self):
        report = _digest()
        original = report["digest"]["expected"]
        report["deferred_entity_ids"] = []
        self.assertNotEqual(partition_digest(report), original)

    def test_rejects_client_or_live_claim(self):
        report = copy.deepcopy(_digest())
        report["uses_live_network"] = True
        report["snapshot_detached"] = False
        errors = validate_digest(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("snapshot_detached" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
