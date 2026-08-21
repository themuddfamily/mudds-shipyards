import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_handoff_v270_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_handoff_v270_validator import validate_snapshot


def _step(order, step_id, digest, phase):
    step = {
        "order": order,
        "step_id": step_id,
        "handoff_id": "server-authority-handoff-v1",
        "from_authority": "peer",
        "to_authority": "server",
        "takeover_token": "server-authority-takeover-token-v41",
        "snapshot_id": "snapshot-authority-v153",
        "sequence": 42165,
        "phase": phase,
        "expected_digest": digest,
        "observed_digest": digest,
        "accepted": True,
        "mutation_fields": [],
        "state_changed": False,
    }
    fields = (
        "handoff_id", "from_authority", "to_authority", "takeover_token",
        "snapshot_id", "sequence", "phase", "step_id", "expected_digest",
        "observed_digest",
    )
    material = "|".join(str(step[key]) for key in fields)
    step["handoff_digest"] = hashlib.sha256(material.encode()).hexdigest()
    return step


def _not_run(reason):
    return {"status": "NOT_RUN", "evidence": None, "reason": reason}


def _report():
    steps = [
        _step(1, "prepare", hashlib.sha256(b"prepare").hexdigest(), "prepared"),
        _step(2, "adopt", hashlib.sha256(b"adopt").hexdigest(), "adopted"),
    ]
    material = "\n".join(
        f"{step['order']}|{step['step_id']}|{step['handoff_digest']}"
        for step in steps
    )
    return {
        "schema_version": 270,
        "evidence_scope": "network_snapshot_authority_takeover_handoff_v270",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server",
        "handoff_id": "server-authority-handoff-v1",
        "takeover_token": "server-authority-takeover-token-v41",
        "snapshot_id": "snapshot-authority-v153",
        "source": "server_snapshot",
        "snapshot_version": 42,
        "release": "release-1",
        "native_claims": False,
        "uses_live_network": False,
        "snapshot_detached": True,
        "no_mutation_guarantee": True,
        "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
        "native_run": _not_run("Native transport is outside this validator scope."),
        "hardware_run": _not_run("Hardware validation is outside this validator scope."),
        "human_review": _not_run("Human review is outside this validator scope."),
        "snapshot": {
            "handoff_id": "server-authority-handoff-v1",
            "takeover_token": "server-authority-takeover-token-v41",
            "snapshot_id": "snapshot-authority-v153", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 42,
            "sequence": 42165, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "handoff_steps": steps,
        "ledger_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"steps": 2, "unique": 2, "accepted": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverHandoffV270ValidatorTest(unittest.TestCase):
    def test_accepts_handoff_ledger(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_handoff_binding(self):
        report = _report()
        report["handoff_steps"][0]["takeover_token"] = "wrong-token"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority handoff" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["handoff_steps"][1]["order"] = 1
        report["handoff_steps"][1]["step_id"] = report["handoff_steps"][0]["step_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("step_id must be unique" in error for error in errors))

    def test_rejects_ledger_and_counts(self):
        report = _report()
        report["ledger_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["steps"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority handoff steps" in error for error in errors))
        self.assertTrue(any("counts.steps" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["handoff_steps"][0]["mutation_fields"] = ["authority"]
        report["counts"]["mutations"] = 1
        errors = validate_snapshot(report)
        self.assertTrue(any("must have no mutation" in error for error in errors))
        self.assertTrue(any("counts.mutations must be zero" in error for error in errors))

    def test_preserves_all_not_run_boundaries(self):
        report = _report()
        for key in ("stale_check", "native_run", "hardware_run", "human_review"):
            report[key]["status"] = "PASS"
            report[key]["evidence"] = "capture"
        errors = validate_snapshot(report)
        for key in ("stale_check", "native_run", "hardware_run", "human_review"):
            self.assertTrue(any(f"{key}.status must remain NOT_RUN" in error for error in errors))
            self.assertTrue(any(f"{key}.evidence must be null" in error for error in errors))

    def test_rejects_live_or_native_claims(self):
        report = copy.deepcopy(_report())
        report["uses_live_network"] = True
        report["native_claims"] = True
        errors = validate_snapshot(report)
        self.assertTrue(any("uses_live_network" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
