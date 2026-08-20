import unittest

from tools.review.planetary_hazard_manifest_digest_completeness_visual_v17 import validate_manifest


def manifest():
    return {
        "schema": "planetary_hazard_manifest_digest_completeness_visual_v17", "world_id": "ember_moon", "region_id": "caldera_rim", "manifest_id": "caldera_visual_manifest", "source_revision": "abd5431",
        "entries": [{"id": "hazard", "kind": "hazard", "manifest_id": "caldera_visual_manifest", "evidence_refs": ["res://docs/evidence/hazard.png"], "sha256": "a" * 64, "complete": False, "status": "pending"}, {"id": "landmark", "kind": "landmark", "manifest_id": "caldera_visual_manifest", "evidence_refs": ["res://docs/evidence/landmark.png"], "sha256": "b" * 64, "complete": False, "status": "not_performed"}, {"id": "route", "kind": "route", "manifest_id": "caldera_visual_manifest", "evidence_refs": ["res://docs/evidence/route.png"], "sha256": "c" * 64, "complete": False, "status": "pending"}],
        "completeness_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["completeness_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardManifestDigestCompletenessVisualV17Test(unittest.TestCase):
    def test_open_manifest_is_valid(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_evidence_refs_must_be_res_paths(self):
        item = manifest(); item["entries"][0]["evidence_refs"] = ["hazard.png"]
        self.assertTrue(any("evidence_refs" in error for error in validate_manifest(item)))

    def test_digest_is_strict(self):
        item = manifest(); item["entries"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_manifest(item)))

    def test_complete_must_remain_false(self):
        item = manifest(); item["entries"][0]["complete"] = True
        self.assertTrue(any("complete" in error for error in validate_manifest(item)))

    def test_entry_ids_are_unique(self):
        item = manifest(); item["entries"][1]["id"] = item["entries"][0]["id"]
        self.assertTrue(any("unique" in error for error in validate_manifest(item)))

    def test_completeness_status_stays_open(self):
        item = manifest(); item["completeness_status"] = "complete"
        self.assertTrue(any("completeness_status" in error for error in validate_manifest(item)))

    def test_native_human_gates_stay_open(self):
        item = manifest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_manifest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_manifest(item)))

    def test_exclusions_are_required(self):
        item = manifest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(item)))


if __name__ == "__main__":
    unittest.main()
