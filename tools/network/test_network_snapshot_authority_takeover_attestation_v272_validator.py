import copy
import hashlib
import unittest

try:
    from .network_snapshot_authority_takeover_attestation_v272_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_takeover_attestation_v272_validator import validate_snapshot


def _attestation(order, record_id, digest, claim):
    record = {
        "order": order, "record_id": record_id,
        "attestation_id": "server-authority-attestation-v1", "authority": "server",
        "takeover_token": "server-authority-takeover-token-v43",
        "snapshot_id": "snapshot-authority-v155", "sequence": 42167,
        "claim": claim, "expected_digest": digest, "observed_digest": digest,
        "attested": True, "mutation_fields": [], "state_changed": False,
    }
    fields = (
        "attestation_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "claim", "record_id", "expected_digest", "observed_digest",
    )
    record["attestation_digest"] = hashlib.sha256(
        "|".join(str(record[key]) for key in fields).encode()
    ).hexdigest()
    return record


def _not_run(reason):
    return {"status": "NOT_RUN", "evidence": None, "reason": reason}


def _report():
    records = [
        _attestation(1, "authority", hashlib.sha256(b"authority").hexdigest(), "authority-bound"),
        _attestation(2, "snapshot", hashlib.sha256(b"snapshot").hexdigest(), "snapshot-bound"),
    ]
    material = "\n".join(
        f"{record['order']}|{record['record_id']}|{record['attestation_digest']}"
        for record in records
    )
    return {
        "schema_version": 272,
        "evidence_scope": "network_snapshot_authority_takeover_attestation_v272",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_replication_interest_authority_v1",
        "authority": "server", "attestation_id": "server-authority-attestation-v1",
        "takeover_token": "server-authority-takeover-token-v43",
        "snapshot_id": "snapshot-authority-v155", "source": "server_snapshot",
        "snapshot_version": 44, "release": "release-1",
        "native_claims": False, "uses_live_network": False,
        "snapshot_detached": True, "no_mutation_guarantee": True,
        "stale_check": _not_run("Detached fixture does not execute stale replay checks."),
        "native_run": _not_run("Native transport is outside this validator scope."),
        "hardware_run": _not_run("Hardware validation is outside this validator scope."),
        "human_review": _not_run("Human review is outside this validator scope."),
        "snapshot": {
            "attestation_id": "server-authority-attestation-v1",
            "takeover_token": "server-authority-takeover-token-v43",
            "snapshot_id": "snapshot-authority-v155", "authority": "server",
            "source": "server_snapshot", "release": "release-1", "version": 44,
            "sequence": 42167, "digest": hashlib.sha256(b"snapshot").hexdigest(),
        },
        "attestations": records,
        "rollup_digest": hashlib.sha256(material.encode()).hexdigest(),
        "counts": {"records": 2, "unique": 2, "attested": 2, "mutations": 0},
    }


class NetworkSnapshotAuthorityTakeoverAttestationV272ValidatorTest(unittest.TestCase):
    def test_accepts_attestation_rollup(self):
        self.assertEqual(validate_snapshot(_report()), [])

    def test_rejects_attestation_binding(self):
        report = _report()
        report["attestations"][0]["takeover_token"] = "wrong-token"
        errors = validate_snapshot(report)
        self.assertTrue(any("bind authority attestation" in error for error in errors))

    def test_rejects_order_and_duplicate_identity(self):
        report = _report()
        report["attestations"][1]["order"] = 1
        report["attestations"][1]["record_id"] = report["attestations"][0]["record_id"]
        errors = validate_snapshot(report)
        self.assertTrue(any("order must be 2" in error for error in errors))
        self.assertTrue(any("record_id must be unique" in error for error in errors))

    def test_rejects_rollup_and_counts(self):
        report = _report()
        report["rollup_digest"] = hashlib.sha256(b"wrong").hexdigest()
        report["counts"]["records"] = 9
        errors = validate_snapshot(report)
        self.assertTrue(any("match authority attestation records" in error for error in errors))
        self.assertTrue(any("counts.records" in error for error in errors))

    def test_rejects_mutation(self):
        report = _report()
        report["attestations"][0]["mutation_fields"] = ["authority"]
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
