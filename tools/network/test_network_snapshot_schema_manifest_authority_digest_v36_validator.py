import copy
import hashlib
import unittest

try:
    from .network_snapshot_schema_manifest_authority_digest_v36_validator import validate_digests
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_schema_manifest_authority_digest_v36_validator import validate_digests


def _report() -> dict:
    schema = {"name": "snapshot", "version": 6}
    schema_digest = hashlib.sha256(b"snapshot|6").hexdigest()
    root_digest = hashlib.sha256(b"root").hexdigest()
    manifest = {"authority": "server", "manifest_id": "manifest-320", "schema_version": 6, "schema_digest": schema_digest, "sequence": 320, "digest": root_digest}
    manifest["authority_digest"] = hashlib.sha256(f"server|manifest-320|{schema_digest}|320|{root_digest}".encode()).hexdigest()
    return {
        "schema_version": 36,
        "evidence_scope": "network_snapshot_schema_manifest_authority_digest_v36",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "schema": schema | {"schema_digest": schema_digest},
        "manifest": manifest,
        "entries": [{"order": 1, "entry_id": "ship-a", "authority": "server", "schema_digest": schema_digest, "authority_digest": manifest["authority_digest"], "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}, {"order": 2, "entry_id": "ship-b", "authority": "server", "schema_digest": schema_digest, "authority_digest": manifest["authority_digest"], "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}],
        "counts": {"entries": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotSchemaManifestAuthorityDigestV36ValidatorTest(unittest.TestCase):
    def test_accepts_schema_manifest_digests(self):
        self.assertEqual(validate_digests(_report()), [])

    def test_rejects_schema_digest(self):
        report = _report()
        report["schema"]["schema_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind schema" in error for error in validate_digests(report)))

    def test_rejects_manifest_authority_digest(self):
        report = _report()
        report["manifest"]["authority_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind schema and manifest" in error for error in validate_digests(report)))

    def test_rejects_entry_schema_reference(self):
        report = _report()
        report["entries"][0]["schema_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("schema_digest" in error for error in validate_digests(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["entries"][0]["state_changed"] = True
        errors = validate_digests(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_digests(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
