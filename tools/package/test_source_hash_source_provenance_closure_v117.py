import unittest

from tools.package.source_hash_source_provenance_closure_v117 import validate_v117


def record():
    commit = "8" * 40
    digest = "f" * 64
    source_id = "source-117"
    provenance_id = "provenance-117"
    closure_id = "closure-117"
    source_version = "src-117"
    package_version = "11.7.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 117,
        "build_label": "source-provenance-closure-v117",
        **common,
        "provenance_id": provenance_id,
        "closure_id": closure_id,
        "source": {"status": "PASS", "evidence": "source", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": provenance_id, **common, "proven": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "provenance_id": provenance_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSourceProvenanceClosureV117Test(unittest.TestCase):
    def test_accepts_source_provenance_closure(self):
        self.assertEqual(validate_v117(record()), [])

    def test_requires_source_and_provenance_hash_binding(self):
        item = record()
        item["source"]["source_hash"] = "a" * 64
        item["provenance"]["source_version"] = "src-other"
        errors = validate_v117(item)
        self.assertTrue(any("source.source_hash must match" in error for error in errors))
        self.assertTrue(any("provenance.source_version must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 116
        item["provenance"]["proven"] = False
        item["closure"]["closed"] = False
        errors = validate_v117(item)
        self.assertTrue(any("schema_version must be 117" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v117(item)))


if __name__ == "__main__":
    unittest.main()
