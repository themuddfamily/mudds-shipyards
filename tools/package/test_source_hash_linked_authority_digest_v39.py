import unittest

from tools.package.source_hash_linked_authority_digest_v39 import validate_v39


def linked():
    commit = "a" * 40
    authority_digest = "b" * 64
    link_digest = "c" * 64
    return {
        "schema_version": 39,
        "build_label": "linked-v39-42",
        "source_commit": commit,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "link_id": "link-42",
        "link_digest": link_digest,
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "source_commit": commit, "digest": authority_digest},
        "link": {"status": "PASS", "evidence": "link report", "link_id": "link-42", "authority_id": "authority-42", "digest": link_digest, "authority_digest": authority_digest, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashLinkedAuthorityDigestV39Test(unittest.TestCase):
    def test_accepts_linked_authority_digest(self):
        self.assertEqual(validate_v39(linked()), [])

    def test_requires_schema_v39_and_matching_link_digest(self):
        item = linked()
        item["schema_version"] = 38
        item["link"]["digest"] = "d" * 64
        errors = validate_v39(item)
        self.assertTrue(any("schema_version must be 39" in error for error in errors))
        self.assertTrue(any("link.digest must match" in error for error in errors))

    def test_rejects_authority_or_link_id_drift(self):
        item = linked()
        item["authority"]["authority_id"] = "other"
        item["link"]["link_id"] = "other"
        errors = validate_v39(item)
        self.assertTrue(any("authority.authority_id must match" in error for error in errors))
        self.assertTrue(any("link.link_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = linked()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v39(item)))


if __name__ == "__main__":
    unittest.main()
