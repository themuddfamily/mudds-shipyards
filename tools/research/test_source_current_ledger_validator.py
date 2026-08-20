import json
import tempfile
import unittest
from pathlib import Path

from tools.research.source_current_ledger_validator import validate_ledger


ROOT = Path(__file__).resolve().parents[2]


class SourceCurrentLedgerTests(unittest.TestCase):
    def test_repository_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ROOT / "docs/research/source_ledger.json"), [])

    def test_cross_reference_fields_are_strict(self):
        value = {"sources": [{"id": "B1", "artifacts": [{"url": "ftp://bad", "accessed_on": "2026-02-31"}], "anchors": [{"observation": "x", "time_ms": -1}]}]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ledger.json"
            path.write_text(json.dumps(value))
            errors = validate_ledger(path)
        self.assertTrue(any("URL" in error for error in errors))
        self.assertTrue(any("accessed_on" in error for error in errors))
        self.assertTrue(any("non-negative" in error for error in errors))

    def test_authentication_cannot_be_implicit(self):
        value = {"sources": [{"id": "A1", "status": "authenticated", "artifacts": []}]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ledger.json"
            path.write_text(json.dumps(value))
            errors = validate_ledger(path)
        self.assertTrue(any("explicit review" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
