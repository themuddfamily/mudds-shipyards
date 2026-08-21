import unittest

from tools.package.source_hash_verification_closure_v90 import validate_v90


def record():
    commit = "2" * 40
    digest = "e" * 64
    source_id = "source-90"
    verification_id = "verification-90"
    closure_id = "closure-90"
    source_version = "src-90"
    package_version = "9.0.0"
    common = {"source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version}
    return {
        "schema_version": 90,
        "build_label": "verification-closure-v90",
        **common,
        "verification_id": verification_id,
        "closure_id": closure_id,
        "verification": {"status": "PASS", "evidence": "verification", "verification_id": verification_id, **common, "verified": True},
        "closure": {"status": "PASS", "evidence": "closure", "closure_id": closure_id, "verification_id": verification_id, **common, "closed": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVerificationClosureV90Test(unittest.TestCase):
    def test_accepts_verified_closed_record(self):
        self.assertEqual(validate_v90(record()), [])

    def test_requires_verification_and_closure_hash_binding(self):
        item = record()
        item["verification"]["source_hash"] = "f" * 64
        item["closure"]["verification_id"] = "verification-other"
        errors = validate_v90(item)
        self.assertTrue(any("verification.source_hash must match" in error for error in errors))
        self.assertTrue(any("closure.verification_id must match" in error for error in errors))

    def test_rejects_schema_or_closure_flags(self):
        item = record()
        item["schema_version"] = 89
        item["verification"]["verified"] = False
        item["closure"]["closed"] = False
        errors = validate_v90(item)
        self.assertTrue(any("schema_version must be 90" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("closed must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v90(item)))


if __name__ == "__main__":
    unittest.main()
