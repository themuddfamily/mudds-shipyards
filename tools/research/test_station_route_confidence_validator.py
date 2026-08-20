import json
import tempfile
import unittest
from pathlib import Path

from tools.research.station_route_confidence_validator import (
    ConfidenceRow,
    validate_rows,
    validate_topology,
)


ROOT = Path(__file__).resolve().parents[2]
TOPOLOGY = ROOT / "docs/research/STATION_TOPOLOGY.md"
LEDGER = ROOT / "docs/research/source_ledger.json"


class StationRouteConfidenceValidatorTests(unittest.TestCase):
    def test_repository_topology_is_conservative_and_anchored(self):
        self.assertEqual(validate_topology(TOPOLOGY, ledger_path=LEDGER), [])

    def test_observed_and_fixed_era_rows_require_registered_anchor(self):
        rows = (
            ConfidenceRow(
                "Test relationships", "observed route", "deck", "observed", "none", "original_era_observed", "scale"
                , 10
            ),
            ConfidenceRow(
                "Test relationships", "fixed route", "deck", "fixed-era-inspired", "unknown", "later_source_only", "era"
                , 11
            ),
        )
        errors = validate_rows(rows)
        self.assertEqual(sum("requires a registered source anchor" in error for error in errors), 2)

    def test_new_and_unknown_rows_cannot_carry_source_anchor(self):
        rows = (
            ConfidenceRow(
                "Test relationships", "invented route", "deck", "new", "B3 `00:04–00:52`", "modern_interpretation", "history"
                , 20
            ),
            ConfidenceRow(
                "Test relationships", "unresolved route", "none", "unknown", "B2 `00:00–01:20`", "unknown", "join"
                , 21
            ),
        )
        errors = validate_rows(rows)
        self.assertTrue(any("new must use an explicit no-anchor marker" in error for error in errors))
        self.assertTrue(any("unknown must use an explicit no-anchor marker" in error for error in errors))

    def test_inferred_can_remain_unanchored_but_not_authenticated(self):
        rows = (
            ConfidenceRow(
                "Test relationships", "inferred route", "deck", "inferred", "none registered", "modern_interpretation", "join"
                , 30
            ),
        )
        errors = validate_rows(rows)
        self.assertTrue(any("confidence tables do not exercise label" in error for error in errors))
        self.assertFalse(any("requires a registered source anchor" in error for error in errors))

        authenticated = rows[0].__class__(
            rows[0].family,
            rows[0].relationship,
            rows[0].live_implementation,
            rows[0].label,
            rows[0].evidence_anchor,
            "authenticated",
            rows[0].unknowns,
            rows[0].line_number,
        )
        self.assertTrue(any("cannot be authenticated" in error for error in validate_rows((authenticated,))))

    def test_unknown_ledger_source_and_unanchored_source_are_rejected(self):
        rows = (
            ConfidenceRow(
                "Test relationships", "observed route", "deck", "observed", "A8 `01:00`", "original_era_observed", "scale"
                , 40
            ),
            ConfidenceRow(
                "Test relationships", "other route", "deck", "observed", "B9 `01:00`", "original_era_observed", "scale"
                , 41
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            ledger = Path(directory) / "ledger.json"
            ledger.write_text(
                json.dumps(
                    {
                        "sources": [
                            {"id": "A8", "anchors": []},
                        ]
                    }
                ),
                encoding="utf-8",
            )
            errors = validate_rows(rows, ledger_path=ledger)
        self.assertTrue(any("no source with a registered ledger anchor" in error for error in errors))
        self.assertTrue(any("unregistered source(s): B9" in error for error in errors))

    def test_topology_parser_fails_when_a_confidence_family_is_missing(self):
        text = TOPOLOGY.read_text(encoding="utf-8")
        text = text.replace("### Ladder relationships", "### Ladder notes", 1)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "topology.md"
            path.write_text(text, encoding="utf-8")
            errors = validate_topology(path, ledger_path=LEDGER)
        self.assertTrue(any("missing confidence family heading: Ladder relationships" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
