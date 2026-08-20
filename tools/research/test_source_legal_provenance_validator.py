import json
import tempfile
import unittest
from pathlib import Path

from tools.research.source_legal_provenance_validator import validate_manifest


def ledger(**entry):
    base = {
        "source_id": "B5", "source_urls": ["https://example.test/footage"],
        "usage_scope": ["internal source comparison", "provenance review"],
        "unknowns": ["recording date", "licence terms"],
        "rights": {"permission_status": "permission_not_recorded", "redistribution_policy": "do_not_bundle_or_commit"},
    }
    base.update(entry)
    return {"schema_version": 1, "policy": {"availability_claims": "forbidden"}, "sources": [base]}


class SourceLegalProvenanceTests(unittest.TestCase):
    def check(self, document):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ledger.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            return validate_manifest(path)

    def test_cautious_entry_passes(self):
        self.assertEqual(self.check(ledger()), [])

    def test_missing_rights_usage_and_unknowns_fail(self):
        errors = self.check(ledger(rights=None, usage_scope=[], unknowns=None))
        self.assertTrue(any("rights is required" in error for error in errors))
        self.assertTrue(any("usage_scope" in error for error in errors))
        self.assertTrue(any("unknowns" in error for error in errors))

    def test_availability_claim_fails_closed(self):
        errors = self.check(ledger(available=True))
        self.assertTrue(any("availability" in error for error in errors))

    def test_duplicate_ids_and_bad_url_fail(self):
        document = ledger(source_urls=["not-a-url"])
        document["sources"].append(dict(document["sources"][0]))
        errors = self.check(document)
        self.assertTrue(any("http(s) URL" in error for error in errors))
        self.assertTrue(any("duplicate source_id" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
