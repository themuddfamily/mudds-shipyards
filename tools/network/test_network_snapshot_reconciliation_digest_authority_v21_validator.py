import copy
import hashlib
import unittest

try:
    from .network_snapshot_reconciliation_digest_authority_v21_validator import validate_reconciliation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_reconciliation_digest_authority_v21_validator import validate_reconciliation


def _reconciliation() -> dict:
    digest_a = hashlib.sha256(b"a").hexdigest()
    digest_b = hashlib.sha256(b"b").hexdigest()
    checks = [
        {"order": 1, "check_id": "ship-a", "authority": "server", "expected_digest": digest_a, "observed_digest": digest_a, "reconciled": True, "mutation_fields": [], "state_changed": False},
        {"order": 2, "check_id": "ship-b", "authority": "server", "expected_digest": digest_b, "observed_digest": digest_b, "reconciled": True, "mutation_fields": [], "state_changed": False},
    ]
    return {
        "schema_version": 21,
        "evidence_scope": "network_snapshot_reconciliation_digest_authority_v21",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "before": {"authority": "server", "sequence": 170, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "after": {"authority": "server", "sequence": 170, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "checks": checks,
        "reconciliation_digest": hashlib.sha256("\n".join(f"{check['order']}|{check['check_id']}|{check['expected_digest']}|{check['observed_digest']}" for check in checks).encode()).hexdigest(),
        "counts": {"checks": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotReconciliationDigestAuthorityV21ValidatorTest(unittest.TestCase):
    def test_accepts_digest_reconciliation(self):
        self.assertEqual(validate_reconciliation(_reconciliation()), [])

    def test_rejects_changed_after_state(self):
        report = _reconciliation()
        report["after"]["sequence"] = 171
        self.assertTrue(any("preserve before" in error for error in validate_reconciliation(report)))

    def test_rejects_observed_digest_mismatch(self):
        report = _reconciliation()
        report["checks"][0]["observed_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match expected digest" in error for error in validate_reconciliation(report)))

    def test_rejects_reconciliation_digest(self):
        report = _reconciliation()
        report["reconciliation_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match ordered checks" in error for error in validate_reconciliation(report)))

    def test_rejects_mutation_and_count(self):
        report = _reconciliation()
        report["checks"][0]["state_changed"] = True
        errors = validate_reconciliation(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_reconciliation())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_reconciliation(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
