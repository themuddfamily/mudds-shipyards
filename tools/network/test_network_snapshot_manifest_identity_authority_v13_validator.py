import copy
import hashlib
import unittest

try:
    from .network_snapshot_manifest_identity_authority_v13_validator import validate_identity
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_manifest_identity_authority_v13_validator import validate_identity


def _manifest() -> dict:
    digest = hashlib.sha256(b"manifest").hexdigest()
    manifest = {"authority": "server", "manifest_id": "snapshot-90", "sequence": 90, "digest": digest}
    manifest["identity_digest"] = hashlib.sha256(f"server|snapshot-90|90|{digest}".encode()).hexdigest()
    return manifest


def _identity() -> dict:
    manifest = _manifest()
    members = []
    for member_id, payload in (("ship-a", b"a"), ("ship-b", b"b")):
        member = {
            "member_id": member_id,
            "authority": "server",
            "manifest_id": manifest["manifest_id"],
            "identity_digest": manifest["identity_digest"],
            "member_digest": hashlib.sha256(payload).hexdigest(),
            "reconciled": True,
            "mutation_fields": [],
            "state_changed": False,
        }
        member["member_identity_digest"] = hashlib.sha256(f"{manifest['identity_digest']}|{member_id}|{member['member_digest']}".encode()).hexdigest()
        members.append(member)
    return {
        "schema_version": 13,
        "evidence_scope": "network_snapshot_manifest_identity_authority_v13",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "manifest": manifest,
        "members": members,
        "counts": {"members": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotManifestIdentityAuthorityV13ValidatorTest(unittest.TestCase):
    def test_accepts_manifest_identity(self):
        self.assertEqual(validate_identity(_identity()), [])

    def test_rejects_manifest_identity_digest(self):
        report = _identity()
        report["manifest"]["identity_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor manifest identity" in error for error in validate_identity(report)))

    def test_rejects_member_identity_digest(self):
        report = _identity()
        report["members"][0]["member_identity_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("anchor member identity" in error for error in validate_identity(report)))

    def test_rejects_duplicate_member(self):
        report = _identity()
        report["members"][1]["member_id"] = report["members"][0]["member_id"]
        self.assertTrue(any("member_id must be unique" in error for error in validate_identity(report)))

    def test_rejects_mutation_and_count(self):
        report = _identity()
        report["members"][0]["state_changed"] = True
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
