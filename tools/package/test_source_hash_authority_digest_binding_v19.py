import unittest

from tools.package.source_hash_authority_digest_binding_v19 import validate_v19


def binding():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 19,
        "build_label": "binding-v19-42",
        "source_commit": commit,
        "authority_id": "authority-42",
        "authority_digest": digest,
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "source_commit": commit, "digest": digest, "owner": "release operator"},
        "binding": {"status": "PASS", "evidence": "binding report", "authority_id": "authority-42", "bound_digest": digest, "bound": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuthorityDigestBindingV19Test(unittest.TestCase):
    def test_accepts_authority_digest_binding(self):
        self.assertEqual(validate_v19(binding()), [])

    def test_requires_schema_v19_and_matching_authority_digest(self):
        item = binding()
        item["schema_version"] = 18
        item["authority"]["digest"] = "c" * 64
        errors = validate_v19(item)
        self.assertTrue(any("schema_version must be 19" in error for error in errors))
        self.assertTrue(any("authority.digest must match" in error for error in errors))

    def test_rejects_binding_id_or_source_drift(self):
        item = binding()
        item["binding"]["authority_id"] = "other"
        item["authority"]["source_commit"] = "d" * 40
        errors = validate_v19(item)
        self.assertTrue(any("binding.authority_id must match" in error for error in errors))
        self.assertTrue(any("authority.source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = binding()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v19(item)))


if __name__ == "__main__":
    unittest.main()
