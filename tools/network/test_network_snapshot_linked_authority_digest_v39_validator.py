import copy
import hashlib
import unittest

try:
    from .network_snapshot_linked_authority_digest_v39_validator import validate_links
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_linked_authority_digest_v39_validator import validate_links


def _link(order, link_id, parent, child):
    link = {"order": order, "link_id": link_id, "authority": "server", "parent_digest": parent, "child_digest": child, "reconciled": True, "mutation_fields": [], "state_changed": False}
    link["link_digest"] = hashlib.sha256(f"server|{link_id}|{parent}|{child}".encode()).hexdigest()
    return link


def _links() -> dict:
    initial = hashlib.sha256(b"initial").hexdigest()
    middle = hashlib.sha256(b"middle").hexdigest()
    final = hashlib.sha256(b"final").hexdigest()
    return {
        "schema_version": 39,
        "evidence_scope": "network_snapshot_linked_authority_digest_v39",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "sequence": 350,
        "initial_digest": initial,
        "final_digest": final,
        "links": [_link(1, "link-a", initial, middle), _link(2, "link-b", middle, final)],
        "counts": {"links": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotLinkedAuthorityDigestV39ValidatorTest(unittest.TestCase):
    def test_accepts_linked_chain(self):
        self.assertEqual(validate_links(_links()), [])

    def test_rejects_broken_predecessor(self):
        report = _links()
        report["links"][1]["parent_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("linked predecessor" in error for error in validate_links(report)))

    def test_rejects_link_digest(self):
        report = _links()
        report["links"][0]["link_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind linked authority" in error for error in validate_links(report)))

    def test_rejects_final_digest(self):
        report = _links()
        report["final_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("final_digest must match" in error for error in validate_links(report)))

    def test_rejects_mutation_and_count(self):
        report = _links()
        report["links"][0]["state_changed"] = True
        errors = validate_links(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_links())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_links(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
