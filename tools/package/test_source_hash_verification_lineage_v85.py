import unittest

from tools.package.source_hash_verification_lineage_v85 import validate_v85


def record():
    commit = "7" * 40
    digest = "e" * 64
    source_id = "source-85"
    verification_id = "verification-85"
    lineage_id = "lineage-85"
    source_version = "src-85"
    package_version = "8.5.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 85,
        "build_label": "verification-lineage-v85",
        **common,
        "verification_id": verification_id,
        "lineage_id": lineage_id,
        "verification": {"status": "PASS", "evidence": "verification", "verification_id": verification_id, **common, "verified": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "verification_id": verification_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVerificationLineageV85Test(unittest.TestCase):
    def test_accepts_verified_traced_record(self):
        self.assertEqual(validate_v85(record()), [])

    def test_requires_verification_and_lineage_hash_binding(self):
        item = record()
        item["verification"]["source_hash"] = "f" * 64
        item["lineage"]["verification_id"] = "verification-other"
        errors = validate_v85(item)
        self.assertTrue(any("verification.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.verification_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 84
        item["verification"]["verified"] = False
        item["lineage"]["traced"] = False
        errors = validate_v85(item)
        self.assertTrue(any("schema_version must be 85" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v85(item)))


if __name__ == "__main__":
    unittest.main()
