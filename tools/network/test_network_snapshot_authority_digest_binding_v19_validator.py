import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_digest_binding_v19_validator import validate_bindings
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_authority_digest_binding_v19_validator import validate_bindings


def _binding(binding_id, digest):
    binding = {"binding_id": binding_id, "authority": "server", "sequence": 150, "snapshot_digest": SNAPSHOT_DIGEST, "digest": digest, "valid": True, "mutation_fields": [], "state_changed": False}
    binding["binding_digest"] = hashlib.sha256(f"server|{binding_id}|150|{digest}".encode()).hexdigest()
    return binding


SNAPSHOT_DIGEST = hashlib.sha256(b"snapshot").hexdigest()


def _bindings() -> dict:
    return {
        "schema_version": 19,
        "evidence_scope": "network_snapshot_authority_digest_binding_v19",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "snapshot": {"authority": "server", "sequence": 150, "digest": SNAPSHOT_DIGEST},
        "bindings": [_binding("ship-a", hashlib.sha256(b"a").hexdigest()), _binding("ship-b", hashlib.sha256(b"b").hexdigest())],
        "counts": {"bindings": 2, "unique": 2, "valid": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityDigestBindingV19ValidatorTest(unittest.TestCase):
    def test_accepts_bindings(self):
        self.assertEqual(validate_bindings(_bindings()), [])

    def test_rejects_binding_digest(self):
        report = _bindings()
        report["bindings"][0]["binding_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind authority" in error for error in validate_bindings(report)))

    def test_rejects_snapshot_binding(self):
        report = _bindings()
        report["bindings"][0]["snapshot_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("snapshot_digest" in error for error in validate_bindings(report)))

    def test_rejects_duplicate_binding_id(self):
        report = _bindings()
        report["bindings"][1]["binding_id"] = report["bindings"][0]["binding_id"]
        self.assertTrue(any("binding_id must be unique" in error for error in validate_bindings(report)))

    def test_rejects_mutation_and_count(self):
        report = _bindings()
        report["bindings"][0]["state_changed"] = True
        errors = validate_bindings(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_bindings())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_bindings(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
