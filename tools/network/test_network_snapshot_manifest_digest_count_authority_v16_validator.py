import copy
import hashlib
import unittest

try:
    from .network_snapshot_manifest_digest_count_authority_v16_validator import validate_manifest
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_manifest_digest_count_authority_v16_validator import validate_manifest


def _manifest() -> dict:
    root_digest = hashlib.sha256(b"root").hexdigest()
    entries = [
        {"order": 1, "key": "ship-a", "authority": "server", "sequence": 120, "digest": hashlib.sha256(b"a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
        {"order": 2, "key": "ship-b", "authority": "server", "sequence": 120, "digest": hashlib.sha256(b"b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
    ]
    manifest = {"authority": "server", "sequence": 120, "root_digest": root_digest, "entry_count": 2, "entries_digest": hashlib.sha256("\n".join(f"{entry['order']}|{entry['key']}|{entry['digest']}" for entry in entries).encode()).hexdigest()}
    manifest["authority_digest"] = hashlib.sha256(f"server|120|{root_digest}".encode()).hexdigest()
    for entry in entries:
        entry["authority_digest"] = manifest["authority_digest"]
    return {
        "schema_version": 16,
        "evidence_scope": "network_snapshot_manifest_digest_count_authority_v16",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "manifest": manifest,
        "entries": entries,
        "counts": {"entries": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotManifestDigestCountAuthorityV16ValidatorTest(unittest.TestCase):
    def test_accepts_digest_count_manifest(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_rejects_entry_count(self):
        report = _manifest()
        report["manifest"]["entry_count"] = 1
        self.assertTrue(any("entry_count" in error for error in validate_manifest(report)))

    def test_rejects_entries_digest(self):
        report = _manifest()
        report["manifest"]["entries_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("entries_digest must match" in error for error in validate_manifest(report)))

    def test_rejects_key_order(self):
        report = _manifest()
        report["entries"][1]["order"] = 3
        self.assertTrue(any("order" in error for error in validate_manifest(report)))

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
