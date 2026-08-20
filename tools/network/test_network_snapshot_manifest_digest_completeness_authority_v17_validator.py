import copy
import hashlib
import unittest

try:
    from .network_snapshot_manifest_digest_completeness_authority_v17_validator import validate_completeness
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_manifest_digest_completeness_authority_v17_validator import validate_completeness


def _report() -> dict:
    root_digest = hashlib.sha256(b"root").hexdigest()
    authority_digest = hashlib.sha256(f"server|130|{root_digest}".encode()).hexdigest()
    expected_keys = ["ship-a", "ship-b"]
    entries = [
        {"order": 1, "key": "ship-a", "authority": "server", "authority_digest": authority_digest, "sequence": 130, "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
        {"order": 2, "key": "ship-b", "authority": "server", "authority_digest": authority_digest, "sequence": 130, "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
    ]
    return {
        "schema_version": 17,
        "evidence_scope": "network_snapshot_manifest_digest_completeness_authority_v17",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "manifest": {"authority": "server", "sequence": 130, "root_digest": root_digest, "authority_digest": authority_digest},
        "expected_keys": expected_keys,
        "completeness_digest": hashlib.sha256("\n".join(expected_keys).encode()).hexdigest(),
        "entries": entries,
        "entries_digest": hashlib.sha256("\n".join(f"{entry['order']}|{entry['key']}|{entry['digest']}" for entry in entries).encode()).hexdigest(),
        "counts": {"expected": 2, "entries": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotManifestDigestCompletenessAuthorityV17ValidatorTest(unittest.TestCase):
    def test_accepts_complete_manifest(self):
        self.assertEqual(validate_completeness(_report()), [])

    def test_rejects_missing_key(self):
        report = _report()
        report["expected_keys"] = ["ship-a", "ship-c"]
        self.assertTrue(any("exactly cover" in error for error in validate_completeness(report)))

    def test_rejects_completeness_digest(self):
        report = _report()
        report["completeness_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("completeness_digest" in error for error in validate_completeness(report)))

    def test_rejects_entries_digest(self):
        report = _report()
        report["entries_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("entries_digest" in error for error in validate_completeness(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["entries"][0]["state_changed"] = True
        errors = validate_completeness(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_completeness(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
