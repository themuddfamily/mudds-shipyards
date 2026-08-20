import copy
import hashlib
import unittest

try:
    from .network_snapshot_manifest_identity_count_authority_v14_validator import validate_identity_counts
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_manifest_identity_count_authority_v14_validator import validate_identity_counts


def _anchor() -> dict:
    digest = hashlib.sha256(b"manifest").hexdigest()
    anchor = {"authority": "server", "identity_id": "manifest-100", "sequence": 100, "digest": digest}
    anchor["identity_digest"] = hashlib.sha256(f"server|manifest-100|100|{digest}".encode()).hexdigest()
    return anchor


def _identity_counts() -> dict:
    anchor = _anchor()
    identities = [
        {"identity_id": "ship-a", "authority": "server", "manifest_identity_id": anchor["identity_id"], "identity_digest": anchor["identity_digest"], "sequence": 100, "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
        {"identity_id": "ship-b", "authority": "server", "manifest_identity_id": anchor["identity_id"], "identity_digest": anchor["identity_digest"], "sequence": 100, "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
    ]
    return {
        "schema_version": 14,
        "evidence_scope": "network_snapshot_manifest_identity_count_authority_v14",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "manifest_identity": anchor,
        "identities": identities,
        "counts": {"records": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotManifestIdentityCountAuthorityV14ValidatorTest(unittest.TestCase):
    def test_accepts_identity_counts(self):
        self.assertEqual(validate_identity_counts(_identity_counts()), [])

    def test_rejects_anchor_digest(self):
        report = _identity_counts()
        report["manifest_identity"]["identity_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor identity" in error for error in validate_identity_counts(report)))

    def test_rejects_identity_count(self):
        report = _identity_counts()
        report["counts"]["unique"] = 1
        self.assertTrue(any("counts.unique" in error for error in validate_identity_counts(report)))

    def test_rejects_duplicate_identity(self):
        report = _identity_counts()
        report["identities"][1]["identity_id"] = report["identities"][0]["identity_id"]
        self.assertTrue(any("identity_id must be unique" in error for error in validate_identity_counts(report)))

    def test_rejects_mutation_and_count(self):
        report = _identity_counts()
        report["identities"][0]["state_changed"] = True
        errors = validate_identity_counts(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_identity_counts())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_identity_counts(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
