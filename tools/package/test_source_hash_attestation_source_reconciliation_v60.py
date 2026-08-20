import unittest

from tools.package.source_hash_attestation_source_reconciliation_v60 import validate_v60


def record():
    commit = "f" * 40
    digest = "d" * 64
    source_id = "source-60"
    source_version = "src-60"
    package_version = "6.0.0"
    return {
        "schema_version": 60,
        "build_label": "source-reconciliation-v60",
        "source_id": source_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "source_attestation": {"status": "PASS", "evidence": "attestation", "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "attested": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAttestationSourceReconciliationV60Test(unittest.TestCase):
    def test_accepts_attested_reconciliation(self):
        self.assertEqual(validate_v60(record()), [])

    def test_requires_attestation_and_reconciliation_hash_binding(self):
        item = record()
        item["source_attestation"]["source_hash"] = "e" * 64
        item["reconciliation"]["source_version"] = "src-other"
        errors = validate_v60(item)
        self.assertTrue(any("source_attestation.source_hash must match" in error for error in errors))
        self.assertTrue(any("reconciliation.source_version must match" in error for error in errors))

    def test_rejects_schema_or_flags(self):
        item = record()
        item["schema_version"] = 59
        item["source_attestation"]["attested"] = False
        item["reconciliation"]["reconciled"] = False
        errors = validate_v60(item)
        self.assertTrue(any("schema_version must be 60" in error for error in errors))
        self.assertTrue(any("attested must be true" in error for error in errors))
        self.assertTrue(any("reconciled must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v60(item)))


if __name__ == "__main__":
    unittest.main()
