import copy
import hashlib
import unittest

try:
    from .network_snapshot_schema_version_root_authority_digest_v34_validator import validate_schema
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_schema_version_root_authority_digest_v34_validator import validate_schema


def _report() -> dict:
    schema = {"name": "snapshot", "version": 4}
    digest = hashlib.sha256(b"root").hexdigest()
    authority_digest = hashlib.sha256(f"server|snapshot|4|300|{digest}".encode()).hexdigest()
    return {
        "schema_version": 34,
        "evidence_scope": "network_snapshot_schema_version_root_authority_digest_v34",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot_schema": schema,
        "root": {"authority": "server", "schema_version": 4, "sequence": 300, "digest": digest, "authority_digest": authority_digest},
        "members": [{"order": 1, "member_id": "ship-a", "authority": "server", "schema_version": 4, "authority_digest": authority_digest, "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}, {"order": 2, "member_id": "ship-b", "authority": "server", "schema_version": 4, "authority_digest": authority_digest, "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False}],
        "counts": {"members": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotSchemaVersionRootAuthorityDigestV34ValidatorTest(unittest.TestCase):
    def test_accepts_schema_versioned_root(self):
        self.assertEqual(validate_schema(_report()), [])

    def test_rejects_schema_version_digest(self):
        report = _report()
        report["snapshot_schema"]["version"] = 5
        self.assertTrue(any("bind schema version" in error for error in validate_schema(report)))

    def test_rejects_member_schema_version(self):
        report = _report()
        report["members"][0]["schema_version"] = 3
        self.assertTrue(any("schema_version must match" in error for error in validate_schema(report)))

    def test_rejects_root_schema_reference(self):
        report = _report()
        report["root"]["schema_version"] = 3
        self.assertTrue(any("root.schema_version" in error for error in validate_schema(report)))

    def test_rejects_mutation_and_count(self):
        report = _report()
        report["members"][0]["state_changed"] = True
        errors = validate_schema(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_schema(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
