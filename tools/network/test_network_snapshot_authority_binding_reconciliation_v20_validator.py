import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_binding_reconciliation_v20_validator import validate_reconciliation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_authority_binding_reconciliation_v20_validator import validate_reconciliation


SNAPSHOT_DIGEST = hashlib.sha256(b"snapshot").hexdigest()


def _digest(binding_id):
    return hashlib.sha256(f"server|{binding_id}|160|{SNAPSHOT_DIGEST}".encode()).hexdigest()


def _reconciliation() -> dict:
    expected = [{"binding_id": "ship-a", "authority": "server", "binding_digest": _digest("ship-a")}, {"binding_id": "ship-b", "authority": "server", "binding_digest": _digest("ship-b")}]
    observed = [{"binding_id": item["binding_id"], "authority": "server", "sequence": 160, "snapshot_digest": SNAPSHOT_DIGEST, "binding_digest": item["binding_digest"], "reconciled": True, "mutation_fields": [], "state_changed": False} for item in expected]
    return {
        "schema_version": 20,
        "evidence_scope": "network_snapshot_authority_binding_reconciliation_v20",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": {"authority": "server", "sequence": 160, "digest": SNAPSHOT_DIGEST},
        "expected_bindings": expected,
        "observed_bindings": observed,
        "counts": {"expected": 2, "observed": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityBindingReconciliationV20ValidatorTest(unittest.TestCase):
    def test_accepts_reconciled_bindings(self):
        self.assertEqual(validate_reconciliation(_reconciliation()), [])

    def test_rejects_expected_binding_digest(self):
        report = _reconciliation()
        report["expected_bindings"][0]["binding_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("expected authority binding" in error for error in validate_reconciliation(report)))

    def test_rejects_observed_missing_binding(self):
        report = _reconciliation()
        report["observed_bindings"].pop()
        self.assertTrue(any("exactly cover" in error for error in validate_reconciliation(report)))

    def test_rejects_snapshot_sequence(self):
        report = _reconciliation()
        report["observed_bindings"][0]["sequence"] = 159
        self.assertTrue(any("sequence must match" in error for error in validate_reconciliation(report)))

    def test_rejects_mutation_and_count(self):
        report = _reconciliation()
        report["observed_bindings"][0]["state_changed"] = True
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
