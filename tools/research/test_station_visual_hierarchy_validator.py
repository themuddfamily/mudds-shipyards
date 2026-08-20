import json
import tempfile
import unittest
from pathlib import Path

from tools.research.station_visual_hierarchy_validator import validate_manifest


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/station_visual_hierarchy.json"


class StationVisualHierarchyValidatorTests(unittest.TestCase):
    def test_repository_contract_is_pending_and_bounded(self):
        self.assertEqual(validate_manifest(MANIFEST), [])

    def test_review_cannot_be_promoted_by_metadata(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["review"]["status"] = "reviewed"
        manifest["modules"][0]["review_status"] = "reviewed"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_manifest(path)
        self.assertTrue(any("must remain pending_art_review" in error for error in errors))

    def test_duplicate_priority_and_missing_shape_channel_fail(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["modules"][1]["navigation_priority"] = manifest["modules"][0]["navigation_priority"]
        manifest["modules"][1]["colour_safe_shape_channel"] = False
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_manifest(path)
        self.assertTrue(any("duplicates navigation_priority" in error for error in errors))
        self.assertTrue(any("colour-safe shape channel" in error for error in errors))

    def test_historical_boundary_and_bad_palette_fail_closed(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["evidence_boundary"] = "historical_evidence"
        manifest["historical_authentication"] = "canonical"
        manifest["modules"][0]["palette"]["colors"]["primary"] = "blue"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_manifest(path)
        self.assertTrue(any("modern_interpretation_only" in error for error in errors))
        self.assertTrue(any("historical_authentication must remain none" in error for error in errors))
        self.assertTrue(any("six-digit hex colour" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
