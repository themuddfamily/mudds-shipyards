"""Focused tests for station/combat listening ledger claim safety."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import station_combat_listening_ledger_validator as validator  # noqa: E402


def row(surface: str, index: int) -> dict:
    return {
        "review_id": f"review-{index}",
        "surface": surface,
        "capture_id": f"native-capture-{index}",
        "capture_status": "CAPTURED",
        "backend": "native_output",
        "route_evidence": f"artifacts/audio/{surface}-route.json",
        "status": "PASS",
        "reviewer": "operator-1",
        "device": "reference-headphones",
        "mix_levels": ["quiet", "nominal", "loud"],
        "distance_checks": ["near", "far"],
        "notes": "No clipping or masking heard.",
    }


def ledger() -> dict:
    return {"schema_version": 1, "ledger_id": "station-combat-listening-v1", "build_label": "v0.12-candidate", "source_commit": "a" * 40, "claim": "ALL_NATIVE_LISTENING_PASS", "reviews": [row("station_music", 1), row("station_machinery", 2), row("combat_cues", 3)]}


class StationCombatListeningLedgerTests(unittest.TestCase):
    def test_complete_native_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_open_review_requires_boundary_note(self):
        value = copy.deepcopy(ledger())
        value["claim"] = "OPEN_NATIVE_REVIEW"
        value["reviews"][1]["status"] = "OUTSTANDING"
        value["reviews"][1]["notes"] = "Native output session remains open."
        errors = validator.validate_ledger(value)
        self.assertIn("ledger.boundary_note is required for OPEN_NATIVE_REVIEW", errors)
        value["boundary_note"] = "Dummy/headless checks do not establish audibility."
        self.assertEqual(validator.validate_ledger(value), [])

    def test_pass_cannot_use_dummy_or_uncaptured_evidence(self):
        value = copy.deepcopy(ledger())
        value["reviews"][0]["backend"] = "dummy"
        value["reviews"][0]["capture_status"] = "NOT_RUN"
        errors = validator.validate_ledger(value)
        self.assertIn("ledger.reviews[0].PASS requires CAPTURED evidence", errors)
        self.assertIn("ledger.reviews[0].PASS requires native_output backend", errors)

    def test_duplicate_rows_and_missing_surface_are_rejected(self):
        value = copy.deepcopy(ledger())
        value["reviews"][2]["review_id"] = value["reviews"][0]["review_id"]
        value["reviews"][2]["surface"] = "station_music"
        errors = validator.validate_ledger(value)
        self.assertIn("ledger.reviews[2].review_id is duplicated", errors)
        self.assertIn("ledger.reviews must cover: combat_cues", errors)


if __name__ == "__main__":
    unittest.main()
