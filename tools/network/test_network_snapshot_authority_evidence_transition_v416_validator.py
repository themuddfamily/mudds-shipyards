import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_evidence_transition_v416_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_evidence_transition_v416_validator import validate_snapshot


def _item(order, item_id, digest, subject):
    item = {"order": order, "item_id": item_id, "assertion_id": "authority-snapshot-evidence-transition-assertion-v1",
            "integrity_gate_id": "authority-evidence-transition-v416", "snapshot_id": "snapshot-authority-v299",
            "authority": "server", "sequence": 46716, "subject": subject, "authority_digest": digest,
            "snapshot_digest": digest, "asserted": True, "mutation_fields": [], "state_changed": False}
    fields = ("assertion_id", "integrity_gate_id", "snapshot_id", "sequence", "subject", "authority_digest", "snapshot_digest")
    item["assertion_digest"] = hashlib.sha256("|".join(str(item[key]) for key in fields).encode()).hexdigest(); return item


def _not_run(reason): return {"status": "NOT_RUN", "evidence": None, "reason": reason}


def _report():
    items = [_item(1, "authority", hashlib.sha256(b"authority").hexdigest(), "authority"), _item(2, "transition", hashlib.sha256(b"transition").hexdigest(), "transition")]
    material = "\n".join(f"{item['order']}|{item['item_id']}|{item['assertion_digest']}" for item in items)
    return {"schema_version": 416, "evidence_scope": "network_snapshot_authority_evidence_transition_v416", "evidence_mode": "detached_contract_fixture",
            "policy_version": "network_replication_interest_authority_v1", "authority": "server", "integrity_gate_id": "authority-evidence-transition-v416",
            "snapshot_id": "snapshot-authority-v299", "assertion_id": "authority-snapshot-evidence-transition-assertion-v1", "source": "server_snapshot",
            "snapshot_version": 188, "release": "release-1", "native_claims": False, "uses_live_network": False, "snapshot_detached": True,
            "no_mutation_guarantee": True, "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
            "native_run": _not_run("Native transport is outside this validator scope."), "hardware_run": _not_run("Hardware validation is outside this validator scope."),
            "human_review": _not_run("Human review is outside this validator scope."), "snapshot": {"integrity_gate_id": "authority-evidence-transition-v416",
            "snapshot_id": "snapshot-authority-v299", "assertion_id": "authority-snapshot-evidence-transition-assertion-v1", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 188, "sequence": 46716, "digest": hashlib.sha256(b"snapshot").hexdigest()},
            "assertion_members": items, "rollup_digest": hashlib.sha256(material.encode()).hexdigest(), "counts": {"assertion_members": 2, "unique": 2, "asserted": 2, "mutations": 0}}


class NetworkSnapshotAuthorityEvidenceTransitionV416ValidatorTest(unittest.TestCase):
    def test_accepts_evidence_transition_rollup(self): self.assertEqual(validate_snapshot(_report()), [])
    def test_rejects_evidence_transition_binding(self):
        report = _report(); report["assertion_members"][0]["snapshot_id"] = "wrong-transition"; self.assertTrue(any("bind authority evidence transition" in e for e in validate_snapshot(report)))
    def test_rejects_order_and_duplicate_identity(self):
        report = _report(); report["assertion_members"][1].update(order=1, item_id="authority"); errors = validate_snapshot(report); self.assertTrue(any("order must be 2" in e for e in errors)); self.assertTrue(any("item_id must be unique" in e for e in errors))
    def test_rejects_digest_and_counts(self):
        report = _report(); report["assertion_members"][0]["snapshot_digest"] = hashlib.sha256(b"wrong").hexdigest(); report["counts"]["asserted"] = 9; errors = validate_snapshot(report); self.assertTrue(any("snapshot_digest must match authority digest" in e for e in errors)); self.assertTrue(any("counts.asserted" in e for e in errors))
    def test_rejects_rollup_and_mutation(self):
        report = _report(); report["rollup_digest"] = hashlib.sha256(b"wrong").hexdigest(); report["assertion_members"][0]["mutation_fields"] = ["transition"]; report["counts"]["mutations"] = 1; errors = validate_snapshot(report); self.assertTrue(any("match authority evidence members" in e for e in errors)); self.assertTrue(any("must have no mutation" in e for e in errors)); self.assertTrue(any("counts.mutations must be zero" in e for e in errors))
    def test_preserves_all_not_run_boundaries(self):
        report = _report()
        for key in ("stale_check", "native_run", "hardware_run", "human_review"): report[key].update(status="PASS", evidence="capture")
        errors = validate_snapshot(report)
        for key in ("stale_check", "native_run", "hardware_run", "human_review"): self.assertTrue(any(f"{key}.status must remain NOT_RUN" in e for e in errors)); self.assertTrue(any(f"{key}.evidence must be null" in e for e in errors))
    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report()); report.update(uses_live_network=True, native_claims=True); errors = validate_snapshot(report); self.assertTrue(any("uses_live_network" in e for e in errors)); self.assertTrue(any("native_claims" in e for e in errors))


if __name__ == "__main__": unittest.main()
