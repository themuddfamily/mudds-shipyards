import copy
import hashlib
import unittest

try:
    from .network_snapshot_linked_authority_provenance_version_v42_validator import validate_version
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_linked_authority_provenance_version_v42_validator import validate_version


def _link(order, link_id, parent, child, event):
    provenance = {"authority": "server", "version": 1, "event": event, "sequence": order}
    link = {"order": order, "link_id": link_id, "authority": "server", "provenance_version": 1, "provenance": provenance, "parent_digest": parent, "child_digest": child, "reconciled": True, "mutation_fields": [], "state_changed": False}
    link["provenance_digest"] = hashlib.sha256(f"server|1|{link_id}|{event}|1|{order}|{parent}|{child}".encode()).hexdigest()
    return link


def _version() -> dict:
    initial = hashlib.sha256(b"initial").hexdigest()
    middle = hashlib.sha256(b"middle").hexdigest()
    final = hashlib.sha256(b"final").hexdigest()
    links = [_link(1, "link-a", initial, middle, "reconcile-a"), _link(2, "link-b", middle, final, "reconcile-b")]
    return {
        "schema_version": 42,
        "evidence_scope": "network_snapshot_linked_authority_provenance_version_v42",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "provenance_version": 1,
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "initial_digest": initial,
        "final_digest": final,
        "links": links,
        "provenance_root": hashlib.sha256("\n".join(f"{link['order']}|{link['link_id']}|{link['provenance_digest']}" for link in links).encode()).hexdigest(),
        "counts": {"links": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotLinkedAuthorityProvenanceVersionV42ValidatorTest(unittest.TestCase):
    def test_accepts_versioned_provenance(self):
        self.assertEqual(validate_version(_version()), [])

    def test_rejects_version(self):
        report = _version()
        report["links"][0]["provenance"]["version"] = 2
        self.assertTrue(any("bind versioned provenance" in error for error in validate_version(report)))

    def test_rejects_provenance_root(self):
        report = _version()
        report["provenance_root"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match versioned links" in error for error in validate_version(report)))

    def test_rejects_predecessor(self):
        report = _version()
        report["links"][1]["parent_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("versioned predecessor" in error for error in validate_version(report)))

    def test_rejects_mutation_and_count(self):
        report = _version()
        report["links"][0]["state_changed"] = True
        errors = validate_version(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_version())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_version(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
