import copy
import hashlib
import unittest

try:
    from .network_snapshot_root_leaf_authority_reconciliation_v11_validator import validate_reconciliation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_root_leaf_authority_reconciliation_v11_validator import validate_reconciliation


def _root() -> dict:
    state = {"sequence": 70, "digest": hashlib.sha256(b"root").hexdigest()}
    authority_digest = hashlib.sha256(f"server|{state['sequence']}|{state['digest']}".encode()).hexdigest()
    return {**state, "authority": "server", "authority_digest": authority_digest}


def _reconciliation() -> dict:
    root = _root()
    return {
        "schema_version": 11,
        "evidence_scope": "network_snapshot_root_leaf_authority_reconciliation_v11",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root": root,
        "leaves": [
            {"leaf_id": "interest-a", "authority": "server", "root_digest": root["authority_digest"], "sequence": 70, "digest": hashlib.sha256(b"leaf-a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
            {"leaf_id": "interest-b", "authority": "server", "root_digest": root["authority_digest"], "sequence": 70, "digest": hashlib.sha256(b"leaf-b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
        ],
        "counts": {"leaves": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotRootLeafAuthorityReconciliationV11ValidatorTest(unittest.TestCase):
    def test_accepts_root_leaf_reconciliation(self):
        self.assertEqual(validate_reconciliation(_reconciliation()), [])

    def test_rejects_root_digest_mismatch(self):
        report = _reconciliation()
        report["leaves"][0]["root_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("root_digest" in error for error in validate_reconciliation(report)))

    def test_rejects_root_authority_digest(self):
        report = _reconciliation()
        report["root"]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor root authority" in error for error in validate_reconciliation(report)))

    def test_rejects_duplicate_leaf_id(self):
        report = _reconciliation()
        report["leaves"][1]["leaf_id"] = report["leaves"][0]["leaf_id"]
        self.assertTrue(any("unique" in error for error in validate_reconciliation(report)))

    def test_rejects_mutation_and_count(self):
        report = _reconciliation()
        report["leaves"][0]["state_changed"] = True
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
