import copy
import hashlib
import unittest

try:
    from .network_snapshot_completeness_authority_digest_v18_validator import validate_completeness
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_completeness_authority_digest_v18_validator import validate_completeness


def _report() -> dict:
    root_digest = hashlib.sha256(b"root").hexdigest()
    authority_digest = hashlib.sha256(f"server|140|{root_digest}".encode()).hexdigest()
    expected_keys = ["ship-a", "ship-b"]
    observed = [
        {"position": 1, "key": "ship-a", "authority": "server", "authority_digest": authority_digest, "sequence": 140, "digest": hashlib.sha256(b"a").hexdigest(), "complete": True, "mutation_fields": [], "state_changed": False},
        {"position": 2, "key": "ship-b", "authority": "server", "authority_digest": authority_digest, "sequence": 140, "digest": hashlib.sha256(b"b").hexdigest(), "complete": True, "mutation_fields": [], "state_changed": False},
    ]
    return {
        "schema_version": 18,
        "evidence_scope": "network_snapshot_completeness_authority_digest_v18",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root": {"authority": "server", "sequence": 140, "root_digest": root_digest, "authority_digest": authority_digest},
        "expected": {"keys": expected_keys, "count": 2, "keys_digest": hashlib.sha256("\n".join(sorted(expected_keys)).encode()).hexdigest()},
        "observed": observed,
        "observed_digest": hashlib.sha256("\n".join(f"{entry['position']}|{entry['key']}|{entry['digest']}" for entry in observed).encode()).hexdigest(),
        "counts": {"expected": 2, "observed": 2, "complete": 2, "mutations": 0},
    }


class NetworkSnapshotCompletenessAuthorityDigestV18ValidatorTest(unittest.TestCase):
    def test_accepts_expected_observed_completeness(self):
        self.assertEqual(validate_completeness(_report()), [])

    def test_rejects_expected_key_digest(self):
        report = _report()
        report["expected"]["keys_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("expected.keys_digest" in error for error in validate_completeness(report)))

    def test_rejects_observed_missing_key(self):
        report = _report()
        report["observed"][1]["key"] = "ship-c"
        self.assertTrue(any("cover expected keys" in error for error in validate_completeness(report)))

    def test_rejects_observed_digest(self):
        report = _report()
        report["observed_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("observed_digest must match" in error for error in validate_completeness(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["observed"][0]["state_changed"] = True
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
