import unittest

from tools.package.source_hash_paired_root_authority_digest_v31 import validate_v31


def authority():
    root_digest = "a" * 64
    authority_digest = "b" * 64
    return {
        "schema_version": 31,
        "build_label": "authority-digest-v31-42",
        "source_commit": "c" * 40,
        "root_id": "root-42",
        "root_digest": root_digest,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "root": {"status": "PASS", "evidence": "root record", "root_id": "root-42", "digest": root_digest},
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "root_id": "root-42", "digest": authority_digest},
        "pair": {"status": "PASS", "evidence": "pair report", "root_digest": root_digest, "authority_digest": authority_digest, "root_id": "root-42", "authority_id": "authority-42", "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashPairedRootAuthorityDigestV31Test(unittest.TestCase):
    def test_accepts_root_authority_digests(self):
        self.assertEqual(validate_v31(authority()), [])

    def test_requires_schema_v31_and_matching_authority_digest(self):
        item = authority()
        item["schema_version"] = 30
        item["authority"]["digest"] = "d" * 64
        errors = validate_v31(item)
        self.assertTrue(any("schema_version must be 31" in error for error in errors))
        self.assertTrue(any("authority.digest must match" in error for error in errors))

    def test_rejects_pair_digest_or_id_drift(self):
        item = authority()
        item["pair"]["authority_digest"] = "d" * 64
        item["pair"]["root_id"] = "other"
        errors = validate_v31(item)
        self.assertTrue(any("pair digests must match" in error for error in errors))
        self.assertTrue(any("pair IDs must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = authority()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v31(item)))


if __name__ == "__main__":
    unittest.main()
