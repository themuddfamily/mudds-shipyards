import unittest

from tools.package.source_hash_paired_root_authority_v30 import validate_v30


def authority():
    source = "a" * 64
    artifact = "b" * 64
    auth_digest = "c" * 64
    return {
        "schema_version": 30,
        "build_label": "authority-v30-42",
        "source_commit": "d" * 40,
        "source_digest": source,
        "artifact_digest": artifact,
        "root_id": "root-42",
        "authority_id": "authority-42",
        "authority_digest": auth_digest,
        "root": {"status": "PASS", "evidence": "root record", "root_id": "root-42", "source_digest": source, "artifact_digest": artifact},
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "root_id": "root-42", "digest": auth_digest, "owner": "release operator"},
        "pair": {"status": "PASS", "evidence": "pair record", "root_id": "root-42", "authority_id": "authority-42", "authority_digest": auth_digest, "authorized": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashPairedRootAuthorityV30Test(unittest.TestCase):
    def test_accepts_paired_root_authority(self):
        self.assertEqual(validate_v30(authority()), [])

    def test_requires_schema_v30_and_matching_authority_digest(self):
        item = authority()
        item["schema_version"] = 29
        item["authority"]["digest"] = "e" * 64
        errors = validate_v30(item)
        self.assertTrue(any("schema_version must be 30" in error for error in errors))
        self.assertTrue(any("authority.digest must match" in error for error in errors))

    def test_rejects_root_or_pair_id_drift(self):
        item = authority()
        item["root"]["root_id"] = "other"
        item["pair"]["authority_id"] = "other"
        errors = validate_v30(item)
        self.assertTrue(any("root.root_id must match" in error for error in errors))
        self.assertTrue(any("pair root/authority IDs must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = authority()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v30(item)))


if __name__ == "__main__":
    unittest.main()
