import json
import tempfile
import unittest
from pathlib import Path

from tools.geometry.embodied_geometry_audit_validator import CATEGORIES, validate


class EmbodiedGeometryAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        viewpoints = [
            {"id": "station-walk", "perspective": "embodied_player", "location": "upper concourse", "route": "airlock-to-berth"},
            {"id": "cinder-cockpit", "perspective": "ship", "location": "Cinder cockpit", "route": "berth-to-landing-site"},
        ]
        observations = [{"viewpoint": "station-walk", "category": category,
                         "result": "clear", "evidence": f"capture/{category}.png"}
                        for category in CATEGORIES]
        value = {"schema": "embodied_geometry_audit_v1", "source_revision": "HEAD",
                 "human_review_status": "pending", "reviewer_required": "gameplay QA",
                 "viewpoints": viewpoints, "observations": observations}
        value.update(changes)
        path = self.root / "geometry-audit.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_complete_manifest_is_ready_only_for_human_review(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_player_and_ship_coverage_is_required(self):
        path = self.manifest(viewpoints=[{"id": "only-player", "perspective": "embodied_player",
                                         "location": "concourse", "route": "walk"}])
        self.assertTrue(any("ship" in error for error in validate(path)))

    def test_missing_observation_and_route_evidence_fail(self):
        path = self.manifest(observations=[])
        errors = validate(path)
        self.assertTrue(any("observations must contain" in error for error in errors))
        self.assertTrue(any("observation coverage missing" in error for error in errors))

    def test_approval_claim_is_rejected(self):
        errors = validate(self.manifest(human_review_status="approved"))
        self.assertTrue(any("cannot approve geometry" in error for error in errors))

    def test_unknown_viewpoint_and_empty_evidence_fail(self):
        path = self.manifest(observations=[{"viewpoint": "missing", "category": "clipping",
                                           "result": "clear", "evidence": ""}])
        errors = validate(path)
        self.assertTrue(any("unknown viewpoint" in error for error in errors))
        self.assertTrue(any("evidence is required" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
