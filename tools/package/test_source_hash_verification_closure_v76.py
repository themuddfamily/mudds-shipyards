import unittest

from tools.package.source_hash_verification_closure_v76 import validate_v76


def record():
    commit = "6" * 40
    digest = "b" * 64
    source_id = "source-76"
    verification_id = "verification-76"
    closure_id = "closure-76"
    source_version = "src-76"
    package_version = "7.6.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 76,
        "build_label": "verification-closure-v76",
        **common,
        "verification_id": verification_id,
        "closure_id": closure_id,
        "verification": {"status": "PASS", "evidence": "verification", "verification_id": verification_id, **common, "verified": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "verification_id": verification_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVerificationClosureV76Test(unittest.TestCase):
    def test_accepts_verified_closed_record(self):
        self.assertEqual(validate_v76(record()), [])

    def test_requires_verification_and_closure_hash_binding(self):
        item = record()
        item["verification"]["source_hash"] = "c" * 64
        item["closure"]["verification_id"] = "verification-other"
        errors = validate_v76(item)
        self.assertTrue(any("verification.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.verification_id must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 75
        item["verification"]["verified"] = False
        item["closure"]["closed"] = False
        errors = validate_v76(item)
        self.assertTrue(any("schema_version must be 76" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v76(item)))


if __name__ == "__main__":
    unittest.main()
