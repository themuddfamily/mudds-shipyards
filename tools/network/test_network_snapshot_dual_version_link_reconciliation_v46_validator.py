import copy
import hashlib
import unittest

try:
    from .network_snapshot_dual_version_link_reconciliation_v46_validator import validate_links
except ImportError:  # Direct invocation from the tools/network directory.
    from network_snapshot_dual_version_link_reconciliation_v46_validator import validate_links


def _link(order, link_id, digest):
    link = {"order": order, "link_id": link_id, "authority": "server", "authority_version": 1, "provenance_version": 1, "sequence": 380, "source_digest": digest, "target_digest": digest, "reconciled": True, "mutation_fields": [], "state_changed": False}
    link["binding_digest"] = hashlib.sha256(f"server|1|1|{link_id}|{digest}|{digest}".encode()).hexdigest()
    return link


def _links() -> dict:
    links = [_link(1, "link-a", hashlib.sha256(b"a").hexdigest()), _link(2, "link-b", hashlib.sha256(b"b").hexdigest())]
    return {
        "schema_version": 46,
        "evidence_scope": "network_snapshot_dual_version_link_reconciliation_v46",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "authority_version": 1,
        "provenance_version": 1,
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "links": links,
        "link_root": hashlib.sha256("\n".join(f"{link['order']}|{link['link_id']}|{link['binding_digest']}" for link in links).encode()).hexdigest(),
        "counts": {"links": 2, "unique": 2, "reconciled": 2, "mutations": 0},
    }


class NetworkSnapshotDualVersionLinkReconciliationV46ValidatorTest(unittest.TestCase):
    def test_accepts_dual_version_reconciliation(self):
        self.assertEqual(validate_links(_links()), [])

    def test_rejects_source_target_mismatch(self):
        report = _links()
        report["links"][0]["target_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("target_digest must match" in error for error in validate_links(report)))

    def test_rejects_binding_digest(self):
        report = _links()
        report["links"][0]["binding_digest"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("bind dual-version" in error for error in validate_links(report)))

    def test_rejects_link_root(self):
        report = _links()
        report["link_root"] = hashlib.sha256(b"wrong").hexdigest()
        self.assertTrue(any("match dual-version links" in error for error in validate_links(report)))

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
