import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_manifest_v275_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_manifest_v275_validator import validate_snapshot


def _entry(order, entry_id, digest, component):
    entry = {
        "order": order, "entry_id": entry_id,
        "manifest_id": "server-authority-manifest-v1", "authority": "server",
        "takeover_token": "server-authority-takeover-token-v46",
        "snapshot_id": "snapshot-authority-v158", "sequence": 42170,
        "component": component, "expected_digest": digest, "observed_digest": digest,
        "listed": True, "mutation_fields": [], "state_changed": False,
    }
    fields = (
        "manifest_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "component", "entry_id", "expected_digest", "observed_digest",
    )
    entry["manifest_digest"] = hashlib.sha256(
        "|".join(str(entry[key]) for key in fields).encode()
    ).hexdigest()
    return entry


def _not_run(reason):
    return {"status": "NOT_RUN", "evidence": None, "reason": reason}


def _report():
    entries = [
        _entry(1, "authority", hashlib.sha256(b"authority").hexdigest(), "authority"),
        _entry(2, "snapshot", hashlib.sha256(b"snapshot").hexdigest(), "snapshot"),
    ]
    material = "\n".join(
        f"{entry['order']}|{entry['entry_id']}|{entry['manifest_digest']}"
        for entry in entries
    )
    return {
        "schema_version": 275,
        "evidence_scope": "network_snapshot_authority_takeover_manifest_v275",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "manifest_id": "server-authority-manifest-v1",
        "takeover_token": "server-authority-takeover-token-v46",
        "snapshot_id": "snapshot-authority-v158", "source": "server_snapshot",
        "snapshot_version": 47, "release": "release-1",
        "native_claims": False, "uses_live_network": False,
        "snapshot_detached": True, "no_mutation_guarantee": True,
        "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
        "native_run": _not_run("Native transport is outside this validator scope."),
        "hardware_run": _not_run("Hardware validation is outside this validator scope."),
        "human_review": _not_run("Human review is outside this validator scope."),
        "snapshot": {
            "manifest_id": "server-authority-manifest-v1",
            "takeover_token": "server-authority-takeover-token-v46",
            "snapshot_id": "snapshot-authority-v158", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 47,
            "sequence": 42170, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "manifest_entries": entries,
        "rollup_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"entries": 2, "unique": 2, "listed": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverManifestV275ValidatorTest(unittest.TestCase):
    def test_accepts_manifest_rollup(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_manifest_binding(self):
        report = _report()
        report["manifest_entries"][0]["takeover_token"] = "wrong-token"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority manifest" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["manifest_entries"][1]["order"] = 1
        report["manifest_entries"][1]["entry_id"] = report["manifest_entries"][0]["entry_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("entry_id must be unique" in error for error in errors))

    def test_rejects_rollup_and_counts(self):
        report = _report()
        report["rollup_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["entries"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority manifest entries" in error for error in errors))
        self.assertTrue(any("counts.entries" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["manifest_entries"][0]["mutation_fields"] = ["authority"]
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
