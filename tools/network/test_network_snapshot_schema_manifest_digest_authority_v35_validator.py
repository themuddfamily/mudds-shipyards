import copy
import hashlib
import unittest

try:
    from .network_snapshot_schema_manifest_digest_authority_v35_validator import validate_manifest
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_schema_manifest_digest_authority_v35_validator import validate_manifest


def _report() -> dict:
    schema = {"name": "snapshot", "version": 5}
    root_digest = hashlib.sha256(b"root").hexdigest()
    manifest = {"authority": "server", "manifest_id": "manifest-310", "schema_version": 5, "sequence": 310, "digest": root_digest}
    manifest["manifest_digest"] = hashlib.sha256(f"server|manifest-310|5|310|{root_digest}".encode()).hexdigest()
    return {
        "schema_version": 35,
        "evidence_scope": "network_snapshot_schema_manifest_digest_authority_v35",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot_schema": schema,
        "manifest": manifest,
        "entries": [{"order": 1, "entry_id": "ship-a", "authority": "server", "manifest_id": "manifest-310", "schema_version": 5, "manifest_digest": manifest["manifest_digest"], "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}, {"order": 2, "entry_id": "ship-b", "authority": "server", "manifest_id": "manifest-310", "schema_version": 5, "manifest_digest": manifest["manifest_digest"], "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}],
        "counts": {"entries": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotSchemaManifestDigestAuthorityV35ValidatorTest(unittest.TestCase):
    def test_accepts_schema_manifest(self):
        self.assertEqual(validate_manifest(_report()), [])

    def test_rejects_manifest_digest(self):
        report = _report()
        report["manifest"]["manifest_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind schema manifest" in error for error in validate_manifest(report)))

    def test_rejects_manifest_schema_reference(self):
        report = _report()
        report["entries"][0]["schema_version"] = 4
        self.assertTrue(any("schema_version must match" in error for error in validate_manifest(report)))

    def test_rejects_manifest_identity_reference(self):
        report = _report()
        report["entries"][0]["manifest_id"] = "other"
        self.assertTrue(any("manifest_id must match" in error for error in validate_manifest(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["entries"][0]["state_changed"] = True
        errors = validate_manifest(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_manifest(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
