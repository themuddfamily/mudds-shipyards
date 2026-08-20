import unittest

from tools.review.planetary_hazard_visual_evidence_provenance_digest_v8 import validate_digest


def digest():
    return {
        "schema": "planetary_hazard_visual_evidence_provenance_digest_v8", "world_id": "ember_moon", "region_id": "caldera_rim", "source_revision": "cacffed",
        "records": [{"id": "hazard", "kind": "hazard", "source_path": "res://docs/evidence/hazard.png", "sha256": "a" * 64, "provenance_note": "authored hazard capture", "status": "pending"}, {"id": "landmark", "kind": "landmark", "source_path": "res://docs/evidence/landmark.png", "sha256": "b" * 64, "provenance_note": "authored landmark capture", "status": "not_performed"}, {"id": "route", "kind": "route", "source_path": "res://docs/evidence/route.png", "sha256": "c" * 64, "provenance_note": "authored route capture", "status": "pending"}],
        "digest_status": "pending", "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["provenance_approval", "native_render", "human_signoff"],
    }


class PlanetaryHazardVisualEvidenceProvenanceDigestV8Test(unittest.TestCase):
    def test_open_digest_is_valid(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_record_ids_are_unique(self):
        item = digest(); item["records"].append(dict(item["records"][0]))
        self.assertTrue(any("unique" in error for error in validate_digest(item)))

    def test_record_kinds_cover_all_categories(self):
        item = digest(); item["records"][2]["kind"] = "hazard"
        self.assertTrue(any("cover hazard" in error for error in validate_digest(item)))

    def test_source_path_is_res_path(self):
        item = digest(); item["records"][0]["source_path"] = "hazard.png"
        self.assertTrue(any("res://" in error for error in validate_digest(item)))

    def test_digest_is_strict(self):
        item = digest(); item["records"][0]["sha256"] = "bad"
        self.assertTrue(any("64-character" in error for error in validate_digest(item)))

    def test_provenance_note_is_required(self):
        item = digest(); item["records"][0]["provenance_note"] = ""
        self.assertTrue(any("provenance_note" in error for error in validate_digest(item)))

    def test_native_signoff_stays_open(self):
        item = digest(); item["native_render"]["status"] = "PASS"; item["human_signoff"]["status"] = "approved"
        self.assertTrue(any("native_render" in error for error in validate_digest(item)))
        self.assertTrue(any("human_signoff" in error for error in validate_digest(item)))

    def test_exclusions_are_required(self):
        item = digest(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
