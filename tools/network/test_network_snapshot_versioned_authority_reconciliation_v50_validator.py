import copy
import hashlib
import unittest

try:
    from .network_snapshot_versioned_authority_reconciliation_v50_validator import validate_checks
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_versioned_authority_reconciliation_v50_validator import validate_checks


def _check(order, check_id, digest):
    check = {"order": order, "check_id": check_id, "authority": "server", "version": 2, "sequence": 420, "expected_digest": digest, "observed_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
    check["authority_digest"] = hashlib.sha256(f"server|2|{check_id}|{digest}|{digest}".encode()).hexdigest()
    return check


def _checks() -> dict:
    digest = hashlib.sha256(b"snapshot").hexdigest()
    checks = [_check(1, "ship-a", hashlib.sha256(b"a").hexdigest()), _check(2, "ship-b", hashlib.sha256(b"b").hexdigest())]
    return {
        "schema_version": 50,
        "evidence_scope": "network_snapshot_versioned_authority_reconciliation_v50",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "snapshot_version": 2,
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": {"authority": "server", "version": 2, "sequence": 420, "digest": digest},
        "checks": checks,
        "aggregate_digest": hashlib.sha256("\n".join(f"{check['order']}|{check['check_id']}|{check['authority_digest']}" for check in checks).encode()).hexdigest(),
        "counts": {"checks": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotVersionedAuthorityReconciliationV50ValidatorTest(unittest.TestCase):
    def test_accepts_versioned_checks(self):
        self.assertEqual(validate_checks(_checks()), [])

    def test_rejects_check_version(self):
        report = _checks()
        report["checks"][0]["version"] = 1
        self.assertTrue(any("bind versioned check" in error for error in validate_checks(report)))

    def test_rejects_sequence_reference(self):
        report = _checks()
        report["checks"][0]["sequence"] = 419
        self.assertTrue(any("sequence must match" in error for error in validate_checks(report)))

    def test_rejects_aggregate_digest(self):
        report = _checks()
        report["aggregate_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match versioned checks" in error for error in validate_checks(report)))

    def test_rejects_mutation_and_count(self):
        report = _checks()
        report["checks"][0]["state_changed"] = True
        errors = validate_checks(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_checks())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_checks(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
