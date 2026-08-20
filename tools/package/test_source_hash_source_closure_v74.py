import unittest

from tools.package.source_hash_source_closure_v74 import validate_v74


def record():
    commit = "4" * 40
    digest = "f" * 64
    source_id = "source-74"
    closure_id = "closure-74"
    source_version = "src-74"
    package_version = "7.4.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 74,
        "build_label": "source-closure-v74",
        **common,
        "closure_id": closure_id,
        "source": {"status": "PASS", "evidence": "source", **common, "identified": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSourceClosureV74Test(unittest.TestCase):
    def test_accepts_identified_closed_source(self):
        self.assertEqual(validate_v74(record()), [])

    def test_requires_source_and_closure_hash_binding(self):
        item = record()
        item["source"]["source_hash"] = "a" * 64
        item["closure"]["source_version"] = "src-other"
        errors = validate_v74(item)
        self.assertTrue(any("source.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.source_version must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 73
        item["source"]["identified"] = False
        item["closure"]["closed"] = False
        errors = validate_v74(item)
        self.assertTrue(any("schema_version must be 74" in error for error in errors))
        self.assertTrue(any("identified must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v74(item)))


if __name__ == "__main__":
    unittest.main()
