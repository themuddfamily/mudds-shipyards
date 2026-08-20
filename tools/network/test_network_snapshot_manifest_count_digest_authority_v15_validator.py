import copy
import hashlib
import unittest

try:
    from .network_snapshot_manifest_count_digest_authority_v15_validator import validate_manifest
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_manifest_count_digest_authority_v15_validator import validate_manifest


def _manifest() -> dict:
    root_digest = hashlib.sha256(b"root").hexdigest()
    manifest = {"authority": "server", "sequence": 110, "root_digest": root_digest, "declared_count": 2}
    manifest["authority_digest"] = hashlib.sha256(f"server|110|{root_digest}".encode()).hexdigest()
    entries = [
        {"ordinal": 1, "entity_id": "ship-a", "authority": "server", "authority_digest": manifest["authority_digest"], "sequence": 110, "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
        {"ordinal": 2, "entity_id": "ship-b", "authority": "server", "authority_digest": manifest["authority_digest"], "sequence": 110, "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
    ]
    manifest_digest = hashlib.sha256("\n".join(f"{entry['ordinal']}|{entry['entity_id']}|{entry['digest']}" for entry in entries).encode()).hexdigest()
    return {
        "schema_version": 15,
        "evidence_scope": "network_snapshot_manifest_count_digest_authority_v15",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "manifest": manifest,
        "entries": entries,
        "manifest_digest": manifest_digest,
        "counts": {"entries": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotManifestCountDigestAuthorityV15ValidatorTest(unittest.TestCase):
    def test_accepts_count_digest_manifest(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_rejects_declared_count(self):
        report = _manifest()
        report["manifest"]["declared_count"] = 1
        self.assertTrue(any("declared_count" in error for error in validate_manifest(report)))

    def test_rejects_manifest_digest(self):
        report = _manifest()
        report["manifest_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match ordered entries" in error for error in validate_manifest(report)))

    def test_rejects_entry_order(self):
        report = _manifest()
        report["entries"][1]["ordinal"] = 3
        self.assertTrue(any("ordinal" in error for error in validate_manifest(report)))

    def test_rejects_mutation_and_count(self):
        report = _manifest()
        report["entries"][0]["state_changed"] = True
        errors = validate_manifest(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_manifest())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_manifest(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
