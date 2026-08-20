import copy
import hashlib
import unittest

try:
    from .network_snapshot_identity_digest_reconciliation_authority_v25_validator import validate_reconciliation
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_identity_digest_reconciliation_authority_v25_validator import validate_reconciliation


def _reconciliation() -> dict:
    snapshot = {"authority": "server", "sequence": 210, "digest": hashlib.sha256(b"snapshot").hexdigest()}
    identities = []
    for order, identity_id, payload in ((1, "ship-a", b"a"), (2, "ship-b", b"b")):
        digest = hashlib.sha256(payload).hexdigest()
        identity = {"order": order, "identity_id": identity_id, "authority": "server", "sequence": 210, "expected_digest": digest, "observed_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
        identity["identity_digest"] = hashlib.sha256(f"server|{identity_id}|210|{digest}".encode()).hexdigest()
        identities.append(identity)
    return {
        "schema_version": 25,
        "evidence_scope": "network_snapshot_identity_digest_reconciliation_authority_v25",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": snapshot,
        "identities": identities,
        "counts": {"identities": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotIdentityDigestReconciliationAuthorityV25ValidatorTest(unittest.TestCase):
    def test_accepts_identity_digest_reconciliation(self):
        self.assertEqual(validate_reconciliation(_reconciliation()), [])

    def test_rejects_expected_observed_mismatch(self):
        report = _reconciliation()
        report["identities"][0]["observed_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("observed_digest must match" in error for error in validate_reconciliation(report)))

    def test_rejects_identity_digest_binding(self):
        report = _reconciliation()
        report["identities"][0]["identity_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind identity digest" in error for error in validate_reconciliation(report)))

    def test_rejects_identity_order(self):
        report = _reconciliation()
        report["identities"][1]["order"] = 3
        self.assertTrue(any("order" in error for error in validate_reconciliation(report)))

    def test_rejects_mutation_and_count(self):
        report = _reconciliation()
        report["identities"][0]["state_changed"] = True
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
