import json
import tempfile
import unittest
from pathlib import Path

from tools.review.fleet_visual_evidence_rollup import EXPECTED_CRAFT, validate, validate_manifest


class FleetVisualEvidenceRollupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "fleet_visual_evidence.json"

    def tearDown(self):
        self.tmp.cleanup()

    def frame(self, frame_id: str, description: str) -> dict:
        return {
            "frame_id": frame_id,
            "evidence_path": f"captures/{frame_id}.png",
            "description": description,
            "resolution": [2560, 1440],
        }

    def craft(self, craft_id: str, *, new: bool = False, medium: bool = False) -> dict:
        views = {
            "silhouette": [self.frame(f"{craft_id}_silhouette", "three-quarter silhouette")],
            "berth_or_approach": [self.frame(f"{craft_id}_berth", "berth approach")],
            "cockpit_or_access": [self.frame(f"{craft_id}_cockpit", "cockpit/access")],
        }
        if medium:
            views["interior_route"] = [self.frame(f"{craft_id}_interior", "connected interior route")]
        return {
            "craft_id": craft_id,
            "evidence_status": "new" if new else "provisional",
            "evidence_references": [] if new else [f"source/{craft_id}"],
            "capture": {"status": "ready", "views": views},
            "human_review": {
                "status": "pending",
                "reviewer_required": "art director",
                "notes": "review silhouette, access readability, and material hierarchy",
            },
        }

    def manifest(self) -> dict:
        return {
            "schema": "fleet_visual_evidence_rollup_v1",
            "source_revision": "working-tree-fleet-review",
            "human_signoff_remains": True,
            "remaining_gates": ["original-resolution visual review", "native-GPU review"],
            "craft": [
                self.craft("torrent_provisional"),
                self.craft("arrow_provisional"),
                self.craft("jovian_provisional", medium=True),
                self.craft("zenith_b7_observed"),
                self.craft("halyard_new_design", new=True, medium=True),
            ],
        }

    def write(self, value: dict) -> None:
        self.path.write_text(json.dumps(value), encoding="utf-8")

    def test_complete_roster_is_ready_for_external_review(self):
        value = self.manifest()
        self.assertEqual(set(item["craft_id"] for item in value["craft"]), EXPECTED_CRAFT)
        self.assertEqual(validate_manifest(value), [])

    def test_medium_craft_requires_interior_route_and_frame_metadata(self):
        value = self.manifest()
        del value["craft"][2]["capture"]["views"]["interior_route"]
        value["craft"][2]["capture"]["views"]["silhouette"][0]["resolution"] = [0, 1440]
        errors = validate_manifest(value)
        self.assertTrue(any("interior_route" in error for error in errors))
        self.assertTrue(any("resolution" in error for error in errors))

    def test_provenance_and_approval_boundaries_fail_closed(self):
        value = self.manifest()
        value["craft"][4]["evidence_references"] = ["historical/source"]
        value["craft"][0]["human_review"]["decision"] = "approved"
        errors = validate_manifest(value)
        self.assertTrue(any("new craft cannot" in error for error in errors))
        self.assertTrue(any("cannot claim final approval" in error for error in errors))

    def test_duplicate_frame_and_incomplete_capture_fail(self):
        value = self.manifest()
        view = value["craft"][0]["capture"]["views"]["silhouette"]
        view.append(view[0].copy())
        value["craft"][1]["capture"]["status"] = "bogus"
        errors = validate_manifest(value)
        self.assertTrue(any("duplicate frame IDs" in error for error in errors))
        self.assertTrue(any("craft[1].capture.status" in error for error in errors))

    def test_file_parse_errors_are_reported(self):
        self.path.write_text("{broken", encoding="utf-8")
        errors = validate(self.path)
        self.assertTrue(any("manifest unreadable" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
