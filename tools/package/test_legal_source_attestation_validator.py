import unittest

from tools.package.legal_source_attestation_validator import validate_attestation


def attestation():
    return {
        "schema_version": 1,
        "build_label": "legal-42",
        "source_commit": "a" * 40,
        "artifact_path": "build/game.exe",
        "redistribution_authorized": False,
        "source_review": {"status": "PASS", "evidence": "review ledger", "reviewer": "operator", "reviewed_at": "2026-08-20"},
        "sources": [{"identifier": "project-original-code", "kind": "code", "license": "project-original", "provenance": "repository", "evidence": "source ledger", "redistributable": False}],
        "completeness": {"status": "PASS", "evidence": "asset inventory", "all_assets_accounted": True, "unknown_assets": 0},
    }


class LegalSourceAttestationValidatorTest(unittest.TestCase):
    def test_accepts_complete_non_authorizing_attestation(self):
        self.assertEqual(validate_attestation(attestation()), [])

    def test_review_pass_requires_reviewer_and_date(self):
        item = attestation()
        item["source_review"]["reviewer"] = None
        self.assertTrue(any("reviewer is required" in error for error in validate_attestation(item)))

    def test_sources_require_nonredistributable_explicitness_and_unique_ids(self):
        item = attestation()
        item["sources"].append(dict(item["sources"][0]))
        item["sources"][0]["redistributable"] = True
        errors = validate_attestation(item)
        self.assertTrue(any("identifier must be unique" in error for error in errors))
        self.assertTrue(any("redistributable must be false" in error for error in errors))

    def test_completeness_rejects_unknown_assets(self):
        item = attestation()
        item["completeness"]["unknown_assets"] = 1
        self.assertTrue(any("unknown_assets must be 0" in error for error in validate_attestation(item)))


if __name__ == "__main__":
    unittest.main()
