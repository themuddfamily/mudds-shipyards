import copy
import hashlib
import unittest

try:
    from .network_snapshot_linked_authority_provenance_digest_v40_validator import validate_provenance
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_linked_authority_provenance_digest_v40_validator import validate_provenance


def _link(order, link_id, parent, child):
    provenance_id = f"server|{link_id}|{order}"
    link = {"order": order, "link_id": link_id, "provenance_id": provenance_id, "authority": "server", "parent_digest": parent, "child_digest": child, "reconciled": True, "mutation_fields": [], "state_changed": False}
    link["link_digest"] = hashlib.sha256(f"server|{provenance_id}|{parent}|{child}".encode()).hexdigest()
    return link


def _provenance() -> dict:
    initial = hashlib.sha256(b"initial").hexdigest()
    middle = hashlib.sha256(b"middle").hexdigest()
    final = hashlib.sha256(b"final").hexdigest()
    links = [_link(1, "link-a", initial, middle), _link(2, "link-b", middle, final)]
    return {
        "schema_version": 40,
        "evidence_scope": "network_snapshot_linked_authority_provenance_digest_v40",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "sequence": 360,
        "initial_digest": initial,
        "final_digest": final,
        "links": links,
        "provenance_digest": hashlib.sha256("\n".join(f"{link['order']}|{link['provenance_id']}|{link['link_digest']}" for link in links).encode()).hexdigest(),
        "counts": {"links": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotLinkedAuthorityProvenanceDigestV40ValidatorTest(unittest.TestCase):
    def test_accepts_provenance_chain(self):
        self.assertEqual(validate_provenance(_provenance()), [])

    def test_rejects_provenance_id(self):
        report = _provenance()
        report["links"][0]["provenance_id"] = "client|link-a|1"
        self.assertTrue(any("provenance_id" in error for error in validate_provenance(report)))

    def test_rejects_link_digest(self):
        report = _provenance()
        report["links"][0]["link_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind authority provenance" in error for error in validate_provenance(report)))

    def test_rejects_provenance_digest(self):
        report = _provenance()
        report["provenance_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match ordered links" in error for error in validate_provenance(report)))

    def test_rejects_mutation_and_count(self):
        report = _provenance()
        report["links"][0]["state_changed"] = True
        errors = validate_provenance(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_provenance())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_provenance(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
