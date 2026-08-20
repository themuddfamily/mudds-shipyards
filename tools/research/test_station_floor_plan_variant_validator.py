import json
import tempfile
import unittest
from pathlib import Path

from tools.research.station_floor_plan_variant_validator import validate_manifest


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/station_floor_plan_variants.json"
LEDGER = ROOT / "docs/research/source_ledger.json"


class StationFloorPlanVariantValidatorTests(unittest.TestCase):
    def test_repository_manifest_is_bounded_and_anchored(self):
        self.assertEqual(validate_manifest(MANIFEST, LEDGER), [])

    def test_missing_anchor_and_claim_support_are_rejected(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        ledger = {
            "sources": [
                {
                    "id": "B2",
                    "anchors": [],
                    "claims_supported": ["station.other_claim"],
                }
            ]
        }
        manifest["variants"] = [
            {
                "variant_id": "fixture",
                "scope": "original_era_observed",
                "source_ids": ["B2"],
                "claim_ids": ["station.original_era_comb_trunk_rungs_slabs"],
                "resolved": {
                    "adjacency": False,
                    "scale": False,
                    "version_conflicts": False,
                },
                "disposition": "deferred",
                "reason": "Adjacency and scale remain unknown.",
            }
        ]
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "manifest.json"
            ledger_path = Path(directory) / "ledger.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
            errors = validate_manifest(manifest_path, ledger_path)
        self.assertTrue(any("without observation anchors" in error for error in errors))
        self.assertTrue(any("not supported by source" in error for error in errors))

    def test_adjacency_must_remain_uncertain(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["variants"][0]["resolved"]["adjacency"] = True
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_manifest(manifest_path, LEDGER)
        self.assertTrue(any("retain adjacency uncertainty" in error for error in errors))

    def test_authenticated_disposition_or_claim_is_rejected(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["variants"][0]["disposition"] = "authenticated"
        manifest["variants"][0]["confidence"] = "authenticated historical floor plan"
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_manifest(manifest_path, LEDGER)
        self.assertTrue(any("must remain deferred" in error for error in errors))
        self.assertTrue(any("authenticated historical claim" in error for error in errors))

    def test_duplicate_ids_and_unknown_scopes_fail_closed(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["variants"][1]["variant_id"] = manifest["variants"][0]["variant_id"]
        manifest["variants"][2]["scope"] = "live_geometry"
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_manifest(manifest_path, LEDGER)
        self.assertTrue(any("duplicates variant_id" in error for error in errors))
        self.assertTrue(any("invalid evidence scope" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
