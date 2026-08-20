import unittest

from tools.package.source_hash_provenance_closure_v69 import validate_v69


def record():
    commit = "9" * 40
    digest = "a" * 64
    source_id = "source-69"
    provenance_id = "provenance-69"
    closure_id = "closure-69"
    source_version = "src-69"
    package_version = "6.9.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 69,
        "build_label": "provenance-closure-v69",
        **common,
        "provenance_id": provenance_id,
        "closure_id": closure_id,
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": provenance_id, **common, "proven": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "provenance_id": provenance_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceClosureV69Test(unittest.TestCase):
    def test_accepts_proven_closed_record(self):
        self.assertEqual(validate_v69(record()), [])

    def test_requires_provenance_and_closure_hash_binding(self):
        item = record()
        item["provenance"]["source_hash"] = "b" * 64
        item["closure"]["provenance_id"] = "provenance-other"
        errors = validate_v69(item)
        self.assertTrue(any("provenance.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.provenance_id must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 68
        item["provenance"]["proven"] = False
        item["closure"]["closed"] = False
        errors = validate_v69(item)
        self.assertTrue(any("schema_version must be 69" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v69(item)))


if __name__ == "__main__":
    unittest.main()
