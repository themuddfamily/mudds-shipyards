import json
import tempfile
import unittest
from pathlib import Path

from .human_art_review_checklist_validator import DOMAINS, validate


class HumanArtReviewChecklistTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        value = {
            "schema": "human_art_review_checklist_v1",
            "human_review_status": "pending",
            "automated_signoff": False,
            "reviewer": {"identity": "A. Reviewer", "role": "art director", "review_date": "2026-08-20"},
            "domains": [{"id": ident, "capture_refs": [f"capture://{ident}/hero"],
                         "acceptance": "review visual hierarchy", "review_status": "pending"} for ident in DOMAINS],
        }
        value.update(changes)
        path = self.root / "checklist.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_checklist_covers_all_domains(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_missing_domain_and_capture_reference_fail(self):
        path = self.manifest(domains=[])
        errors = validate(path)
        self.assertTrue(any("required domains missing" in error for error in errors))

    def test_identity_and_date_are_required(self):
        path = self.manifest(reviewer={"identity": "", "role": "art director", "review_date": "yesterday"})
        errors = validate(path)
        self.assertTrue(any("reviewer.identity" in error for error in errors))
        self.assertTrue(any("ISO-8601" in error for error in errors))

    def test_approval_or_automated_signoff_is_rejected(self):
        errors = validate(self.manifest(human_review_status="approved", automated_signoff=True))
        self.assertTrue(any("cannot claim human approval" in error for error in errors))
        self.assertTrue(any("automated_signoff must be false" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
