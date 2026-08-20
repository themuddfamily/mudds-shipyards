import json
import tempfile
import unittest
from pathlib import Path

from tools.research.source_currentness_validator import validate_manifest


ROOT = Path(__file__).resolve().parents[2]


class SourceCurrentnessTests(unittest.TestCase):
    def test_repository_manifest_is_current_and_conservative(self):
        self.assertEqual(validate_manifest(ROOT / "docs/research/source_ledger.json", ROOT / "docs/research/ship_evidence_matrix.json"), [])

    def test_missing_anchor_provenance_and_source_are_rejected(self):
        ledger = {"sources": [{"id": "B1", "artifacts": []}]}
        matrix = {"policy": {"evidence_status_vocabulary": list({"authenticated", "bounded_partial_reconstruction", "provisional_candidate", "modern_interpretation", "unknown"}), "current_authenticated_ship_count": 0}, "ships": [{"ship_id": "x", "name_to_model_status": "unknown", "unknowns": ["date"], "model_sources": ["B9"]}]}
        with tempfile.TemporaryDirectory() as d:
            lp, mp = Path(d) / "l.json", Path(d) / "m.json"
            lp.write_text(json.dumps(ledger)); mp.write_text(json.dumps(matrix))
            errors = validate_manifest(lp, mp)
        self.assertTrue(any("unregistered source" in e for e in errors))

    def test_authentication_requires_no_unknowns_and_is_never_implicit(self):
        ledger = {"sources": [{"id": "B1", "artifacts": [], "anchors": [{"time_ms": 1, "observation": "craft"}]}]}
        matrix = {"policy": {"evidence_status_vocabulary": ["authenticated", "bounded_partial_reconstruction", "provisional_candidate", "modern_interpretation", "unknown"], "current_authenticated_ship_count": 1}, "ships": [{"ship_id": "x", "name_to_model_status": "authenticated", "model_sources": ["B1"], "unknowns": ["recording date"]}]}
        with tempfile.TemporaryDirectory() as d:
            lp, mp = Path(d) / "l.json", Path(d) / "m.json"
            lp.write_text(json.dumps(ledger)); mp.write_text(json.dumps(matrix))
            errors = validate_manifest(lp, mp)
        self.assertTrue(any("retaining unknowns" in e for e in errors))
        self.assertTrue(any("manual review" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
