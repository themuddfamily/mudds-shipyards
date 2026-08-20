import unittest

from tools.package.source_hash_readiness_consistency_v65 import validate_v65


def record():
    commit = "5" * 40
    digest = "c" * 64
    source_id = "source-65"
    source_version = "src-65"
    package_version = "6.5.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 65,
        "build_label": "readiness-consistency-v65",
        **common,
        "readiness": {"status": "PASS", "evidence": "readiness", **common, "ready": True},
        "consistency": {"status": "PASS", "evidence": "consistency", **common, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReadinessConsistencyV65Test(unittest.TestCase):
    def test_accepts_ready_consistent_record(self):
        self.assertEqual(validate_v65(record()), [])

    def test_requires_readiness_and_consistency_hash_binding(self):
        item = record()
        item["readiness"]["source_hash"] = "d" * 64
        item["consistency"]["source_version"] = "src-other"
        errors = validate_v65(item)
        self.assertTrue(any("readiness.source_hash must match" in error for error in errors))
        self.assertTrue(any("consistency.source_version must match" in error for error in errors))

    def test_rejects_schema_or_readiness_flags(self):
        item = record()
        item["schema_version"] = 64
        item["readiness"]["ready"] = False
        item["consistency"]["consistent"] = False
        errors = validate_v65(item)
        self.assertTrue(any("schema_version must be 65" in error for error in errors))
        self.assertTrue(any("ready must be true" in error for error in errors))
        self.assertTrue(any("consistent must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v65(item)))


if __name__ == "__main__":
    unittest.main()
