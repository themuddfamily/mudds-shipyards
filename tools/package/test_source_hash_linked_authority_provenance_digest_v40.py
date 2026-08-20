import unittest

from tools.package.source_hash_linked_authority_provenance_digest_v40 import validate_v40


def provenance():
    commit = "a" * 40
    authority_digest = "b" * 64
    provenance_digest = "c" * 64
    return {
        "schema_version": 40,
        "build_label": "provenance-v40-42",
        "source_commit": commit,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "provenance_id": "prov-42",
        "provenance_digest": provenance_digest,
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "digest": authority_digest, "source_commit": commit},
        "provenance": {"status": "PASS", "evidence": "provenance record", "provenance_id": "prov-42", "digest": provenance_digest, "source_commit": commit},
        "link": {"status": "PASS", "evidence": "link report", "authority_id": "authority-42", "provenance_id": "prov-42", "authority_digest": authority_digest, "provenance_digest": provenance_digest, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashLinkedAuthorityProvenanceDigestV40Test(unittest.TestCase):
    def test_accepts_linked_authority_provenance(self):
        self.assertEqual(validate_v40(provenance()), [])

    def test_requires_schema_v40_and_matching_provenance_digest(self):
        item = provenance()
        item["schema_version"] = 39
        item["provenance"]["digest"] = "d" * 64
        errors = validate_v40(item)
        self.assertTrue(any("schema_version must be 40" in error for error in errors))
        self.assertTrue(any("provenance identity must match" in error for error in errors))

    def test_rejects_link_id_or_authority_digest_drift(self):
        item = provenance()
        item["link"]["authority_id"] = "other"
        item["link"]["authority_digest"] = "d" * 64
        errors = validate_v40(item)
        self.assertTrue(any("link IDs must match" in error for error in errors))
        self.assertTrue(any("link digests must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = provenance()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v40(item)))


if __name__ == "__main__":
    unittest.main()
