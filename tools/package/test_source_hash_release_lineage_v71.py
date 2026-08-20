import unittest

from tools.package.source_hash_release_lineage_v71 import validate_v71


def record():
    commit = "1" * 40
    digest = "c" * 64
    source_id = "source-71"
    release_id = "release-71"
    lineage_id = "lineage-71"
    source_version = "src-71"
    package_version = "7.1.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 71,
        "build_label": "release-lineage-v71",
        **common,
        "release_id": release_id,
        "lineage_id": lineage_id,
        "release": {"status": "PASS", "evidence": "release", "release_id": release_id, **common, "released": True},
        "lineage": {"status": "PASS", "evidence": "lineage", "lineage_id": lineage_id, "release_id": release_id, **common, "traced": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseLineageV71Test(unittest.TestCase):
    def test_accepts_released_traced_record(self):
        self.assertEqual(validate_v71(record()), [])

    def test_requires_release_and_lineage_hash_binding(self):
        item = record()
        item["release"]["source_hash"] = "d" * 64
        item["lineage"]["release_id"] = "release-other"
        errors = validate_v71(item)
        self.assertTrue(any("release.source_hash must match" in error for error in errors))
        self.assertTrue(any("lineage.release_id must match" in error for error in errors))

    def test_rejects_schema_or_lineage_flags(self):
        item = record()
        item["schema_version"] = 70
        item["release"]["released"] = False
        item["lineage"]["traced"] = False
        errors = validate_v71(item)
        self.assertTrue(any("schema_version must be 71" in error for error in errors))
        self.assertTrue(any("released must be true" in error for error in errors))
        self.assertTrue(any("traced must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v71(item)))


if __name__ == "__main__":
    unittest.main()
