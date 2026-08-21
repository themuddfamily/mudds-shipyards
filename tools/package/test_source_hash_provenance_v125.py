import unittest

from tools.package.source_hash_provenance_v125 import validate_v125


def record():
    commit = "1" * 40
    digest = "e" * 64
    source_id = "source-125"
    provenance_id = "provenance-125"
    source_version = "src-125"
    package_version = "12.5.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 125,
        "build_label": "source-provenance-v125",
        **common,
        "provenance_id": provenance_id,
        "source": {"status": "PASS", "evidence": "source", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": provenance_id, **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV125Test(unittest.TestCase):
    def test_accepts_source_provenance(self):
        self.assertEqual(validate_v125(record()), [])

    def test_requires_source_and_provenance_hash_binding(self):
        item = record()
        item["source"]["source_hash"] = "f" * 64
        item["provenance"]["source_version"] = "src-other"
        errors = validate_v125(item)
        self.assertTrue(any("source.source_hash must match" in error for error in errors))
        self.assertTrue(any("provenance.source_version must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flags(self):
        item = record()
        item["schema_version"] = 124
        item["source"]["identified"] = False
        item["provenance"]["proven"] = False
        errors = validate_v125(item)
        self.assertTrue(any("schema_version must be 125" in error for error in errors))
        self.assertTrue(any("identified must be true" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v125(item)))


if __name__ == "__main__":
    unittest.main()
