import unittest

from tools.package.source_hash_closure_provenance_v120 import validate_v120


def record():
    commit = "b" * 40
    digest = "f" * 64
    source_id = "source-120"
    provenance_id = "provenance-120"
    closure_id = "closure-120"
    source_version = "src-120"
    package_version = "12.0.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 120,
        "build_label": "closure-provenance-v120",
        **common,
        "provenance_id": provenance_id,
        "closure_id": closure_id,
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, **common, "closed": True},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": provenance_id, "closure_id": closure_id, **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashClosureProvenanceV120Test(unittest.TestCase):
    def test_accepts_closed_provenance(self):
        self.assertEqual(validate_v120(record()), [])

    def test_requires_closure_and_provenance_hash_binding(self):
        item = record()
        item["closure"]["source_hash"] = "a" * 64
        item["provenance"]["closure_id"] = "closure-other"
        errors = validate_v120(item)
        self.assertTrue(any("closure.source_hash must match" in error for error in errors))
        self.assertTrue(any("provenance.closure_id must match" in error for error in errors))

    def test_rejects_schema_or_flags(self):
        item = record()
        item["schema_version"] = 119
        item["closure"]["closed"] = False
        item["provenance"]["proven"] = False
        errors = validate_v120(item)
        self.assertTrue(any("schema_version must be 120" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v120(item)))


if __name__ == "__main__":
    unittest.main()
