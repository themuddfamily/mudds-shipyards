import unittest

from tools.package.source_hash_attestation_lineage_v75 import validate_v75


def record():
    commit = "5" * 40
    digest = "a" * 64
    source_id = "source-75"
    attestation_id = "attestation-75"
    lineage_id = "lineage-75"
    source_version = "src-75"
    package_version = "7.5.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 75,
        "build_label": "attestation-lineage-v75",
        **common,
        "attestation_id": attestation_id,
        "lineage_id": lineage_id,
        "attestation": {"status": "PASS", "evidence": "attestation", "attestation_id": attestation_id, **common, "attested": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "attestation_id": attestation_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAttestationLineageV75Test(unittest.TestCase):
    def test_accepts_attested_traced_record(self):
        self.assertEqual(validate_v75(record()), [])

    def test_requires_attestation_and_lineage_hash_binding(self):
        item = record()
        item["attestation"]["source_hash"] = "b" * 64
        item["lineage"]["attestation_id"] = "attestation-other"
        errors = validate_v75(item)
        self.assertTrue(any("attestation.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.attestation_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 74
        item["attestation"]["attested"] = False
        item["lineage"]["traced"] = False
        errors = validate_v75(item)
        self.assertTrue(any("schema_version must be 75" in error for error in errors))
        self.assertTrue(any("attested must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v75(item)))


if __name__ == "__main__":
    unittest.main()
