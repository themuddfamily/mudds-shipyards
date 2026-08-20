import unittest

from tools.review.fleet_planetary_visual_review_evidence_index import validate_index


def index():
    return {
        "schema": "fleet_planetary_visual_review_index_v1", "source_revision": "1a2c4ec", "reviewer_role": "visual-reviewer",
        "entries": [
            {"id": "torrent_fleet", "kind": "fleet_ship", "scene_path": "res://scenes/ships/torrent_interceptor.tscn", "capture_id": "fleet-capture", "review_status": "pending", "historical_claim": False},
            {"id": "ember_surface", "kind": "planetary_surface", "scene_path": "res://scenes/world/planets/ember_moon.tscn", "capture_id": "surface-capture", "review_status": "not_performed", "historical_claim": False},
        ],
        "human_visual_review": {"status": "pending", "evidence": None}, "native_render": {"status": "NOT_RUN", "evidence": None}, "claims_excluded": ["human_visual_signoff", "native_render"],
    }


class FleetPlanetaryVisualReviewEvidenceIndexTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_fleet_and_planetary_entries_are_required(self):
        item = index(); item["entries"][1]["kind"] = "fleet_ship"
        self.assertTrue(any("fleet and planetary" in error for error in validate_index(item)))

    def test_scene_path_must_be_res_path(self):
        item = index(); item["entries"][0]["scene_path"] = "scene.tscn"
        self.assertTrue(any("res://" in error for error in validate_index(item)))

    def test_capture_id_is_required(self):
        item = index(); item["entries"][0]["capture_id"] = ""
        self.assertTrue(any("capture_id" in error for error in validate_index(item)))

    def test_review_status_stays_open(self):
        item = index(); item["entries"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_index(item)))

    def test_historical_claims_are_rejected(self):
        item = index(); item["entries"][0]["historical_claim"] = True
        self.assertTrue(any("historical_claim" in error for error in validate_index(item)))

    def test_native_render_stays_not_run(self):
        item = index(); item["native_render"]["evidence"] = "capture"
        self.assertTrue(any("NOT_RUN" in error for error in validate_index(item)))

    def test_gate_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
