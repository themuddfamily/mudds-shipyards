import copy
import hashlib
import unittest

try:
    from .network_snapshot_reconciliation_manifest_authority_v12_validator import validate_manifest
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_reconciliation_manifest_authority_v12_validator import validate_manifest


def _root() -> dict:
    state = {"sequence": 80, "digest": hashlib.sha256(b"root").hexdigest()}
    authority_digest = hashlib.sha256(f"server|{state['sequence']}|{state['digest']}".encode()).hexdigest()
    return {**state, "authority": "server", "authority_digest": authority_digest}


def _manifest() -> dict:
    root = _root()
    entries = [
        {"entity_id": "ship-a", "authority": "server", "root_digest": root["authority_digest"], "sequence": 80, "digest": hashlib.sha256(b"ship-a").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
        {"entity_id": "ship-b", "authority": "server", "root_digest": root["authority_digest"], "sequence": 80, "digest": hashlib.sha256(b"ship-b").hexdigest(), "reconciled": True, "mutation_fields": [], "state_changed": False},
    ]
    manifest_digest = hashlib.sha256("\n".join(f"{entry['entity_id']}|{entry['sequence']}|{entry['digest']}" for entry in entries).encode()).hexdigest()
    return {
        "schema_version": 12,
        "evidence_scope": "network_snapshot_reconciliation_manifest_authority_v12",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "root": root,
        "entries": entries,
        "manifest_digest": manifest_digest,
        "counts": {"entries": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotReconciliationManifestAuthorityV12ValidatorTest(unittest.TestCase):
    def test_accepts_manifest(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_rejects_manifest_digest(self):
        report = _manifest()
        report["manifest_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match canonical entries" in error for error in validate_manifest(report)))

    def test_rejects_root_reference(self):
        report = _manifest()
        report["entries"][0]["root_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("root_digest" in error for error in validate_manifest(report)))

    def test_rejects_duplicate_entity(self):
        report = _manifest()
        report["entries"][1]["entity_id"] = report["entries"][0]["entity_id"]
        self.assertTrue(any("entity_id must be unique" in error for error in validate_manifest(report)))

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
