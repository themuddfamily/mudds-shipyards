import unittest

from tools.package.source_hash_verification_closure_v99 import validate_v99


def record():
    commit = "8" * 40
    digest = "d" * 64
    source_id = "source-99"
    verification_id = "verification-99"
    closure_id = "closure-99"
    source_version = "src-99"
    package_version = "9.9.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 99,
        "build_label": "verification-closure-v99",
        **common,
        "verification_id": verification_id,
        "closure_id": closure_id,
        "verification": {"status": "PASS", "evidence": "verification", "verification_id": verification_id, **common, "verified": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "verification_id": verification_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVerificationClosureV99Test(unittest.TestCase):
    def test_accepts_verified_closed_record(self):
        self.assertEqual(validate_v99(record()), [])

    def test_requires_verification_and_closure_hash_binding(self):
        item = record()
        item["verification"]["source_hash"] = "e" * 64
        item["closure"]["verification_id"] = "verification-other"
        errors = validate_v99(item)
        self.assertTrue(any("verification.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.verification_id must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 98
        item["verification"]["verified"] = False
        item["closure"]["closed"] = False
        errors = validate_v99(item)
        self.assertTrue(any("schema_version must be 99" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v99(item)))


if __name__ == "__main__":
    unittest.main()
