import unittest

from tools.package.source_hash_linked_authority_provenance_v41 import validate_v41


def linked():
    commit = "a" * 40
    return {
        "schema_version": 41,
        "build_label": "linked-v41-42",
        "source_commit": commit,
        "authority_id": "authority-42",
        "provenance_id": "prov-42",
        "link_id": "link-42",
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "source_commit": commit},
        "provenance": {"status": "PASS", "evidence": "provenance record", "provenance_id": "prov-42", "source_commit": commit},
        "link": {"status": "PASS", "evidence": "link report", "link_id": "link-42", "authority_id": "authority-42", "provenance_id": "prov-42", "source_commit": commit, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashLinkedAuthorityProvenanceV41Test(unittest.TestCase):
    def test_accepts_linked_authority_provenance(self):
        self.assertEqual(validate_v41(linked()), [])

    def test_requires_schema_v41_and_matching_link_ids(self):
        item = linked()
        item["schema_version"] = 40
        item["link"]["provenance_id"] = "other"
        errors = validate_v41(item)
        self.assertTrue(any("schema_version must be 41" in error for error in errors))
        self.assertTrue(any("link.provenance_id must match" in error for error in errors))

    def test_rejects_authority_or_source_drift(self):
        item = linked()
        item["authority"]["authority_id"] = "other"
        item["provenance"]["source_commit"] = "d" * 40
        errors = validate_v41(item)
        self.assertTrue(any("authority.authority_id must match" in error for error in errors))
        self.assertTrue(any("provenance.source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = linked()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v41(item)))


if __name__ == "__main__":
    unittest.main()
