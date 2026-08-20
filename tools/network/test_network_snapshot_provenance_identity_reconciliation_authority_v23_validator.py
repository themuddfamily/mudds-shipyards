import copy
import hashlib
import unittest

try:
    from .network_snapshot_provenance_identity_reconciliation_authority_v23_validator import validate_identity
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_provenance_identity_reconciliation_authority_v23_validator import validate_identity


def _identity() -> dict:
    root_digest = hashlib.sha256(b"root").hexdigest()
    root_identity = hashlib.sha256(f"server|root-id|190|{root_digest}".encode()).hexdigest()
    records = []
    for order, provenance_id, payload in ((1, "ship-a", b"a"), (2, "ship-b", b"b")):
        digest = hashlib.sha256(payload).hexdigest()
        records.append({"order": order, "provenance_id": provenance_id, "authority": "server", "identity_digest": root_identity, "expected_digest": digest, "observed_digest": digest, "record_identity_digest": hashlib.sha256(f"{root_identity}|{provenance_id}|{digest}".encode()).hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False})
    return {
        "schema_version": 23,
        "evidence_scope": "network_snapshot_provenance_identity_reconciliation_authority_v23",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "before": {"authority": "server", "sequence": 190, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "after": {"authority": "server", "sequence": 190, "digest": hashlib.sha256(b"snapshot").hexdigest()},
        "identity_root": {"authority": "server", "identity_id": "root-id", "sequence": 190, "digest": root_digest, "identity_digest": root_identity},
        "records": records,
        "counts": {"records": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotProvenanceIdentityReconciliationAuthorityV23ValidatorTest(unittest.TestCase):
    def test_accepts_identity_reconciliation(self):
        self.assertEqual(validate_identity(_identity()), [])

    def test_rejects_root_identity_digest(self):
        report = _identity()
        report["identity_root"]["identity_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor identity root" in error for error in validate_identity(report)))

    def test_rejects_record_identity_digest(self):
        report = _identity()
        report["records"][0]["record_identity_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind provenance identity" in error for error in validate_identity(report)))

    def test_rejects_changed_after_state(self):
        report = _identity()
        report["after"]["sequence"] = 191
        self.assertTrue(any("preserve before" in error for error in validate_identity(report)))

    def test_rejects_mutation_and_count(self):
        report = _identity()
        report["records"][0]["state_changed"] = True
        errors = validate_identity(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_identity())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_identity(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
