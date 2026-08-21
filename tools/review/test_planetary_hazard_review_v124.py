import unittest

from tools.review.planetary_hazard_review_v124 import validate_manifest


def manifest() -> dict:
    schema = "planetary_hazard_review_v124"
    root = "world_root"
    review = "review_record"
    consistency = "consistency_record"
    state = "state_record"
    pairs = [
        {
            "id": kind,
            "kind": kind,
            "review_evidence_id": "evidence_" + kind,
            "review_version": 124,
            "schema": schema,
            "schema_version": 124,
            "parent_id": root,
            "review_id": review,
            "consistency_id": consistency,
            "state_id": state,
            "runtime_authority": False,
            "status": status,
        }
        for kind, status in (("hazard", "pending"), ("landmark", "not_performed"), ("route", "pending"))
    ]
    return {
        "schema": schema,
        "schema_version": 124,
        "review_version": 124,
        "world_id": "ember_moon",
        "region_id": "caldera_rim",
        "manifest_id": "caldera_review_manifest",
        "root_id": root,
        "review_id": review,
        "consistency_id": consistency,
        "state_id": state,
        "source_revision": "working-tree-planetary-review-v124",
        "pairs": pairs,
        "native_render": {"status": "not_performed"},
        "human_signoff": {"status": "pending"},
        "claims_excluded": [
            "visual_consistency_state_approval",
            "visual_review_consistency_approval",
            "native_render",
            "human_signoff",
        ],
    }


class PlanetaryHazardReviewV124Test(unittest.TestCase):
    def test_valid_open_manifest(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_version_strict(self):
        value = manifest()
        value["schema_version"] = 123
        self.assertTrue(any("schema_version must be 124" in error for error in validate_manifest(value)))

    def test_review_version_strict(self):
        value = manifest()
        value["review_version"] = 123
        self.assertTrue(any("review_version must be 124" in error for error in validate_manifest(value)))

    def test_pair_review_version_strict(self):
        value = manifest()
        value["pairs"][0]["review_version"] = 123
        self.assertTrue(any("review_version must be 124" in error for error in validate_manifest(value)))

    def test_evidence_unique(self):
        value = manifest()
        value["pairs"][1]["review_evidence_id"] = value["pairs"][0]["review_evidence_id"]
        self.assertTrue(any("evidence_id" in error for error in validate_manifest(value)))

    def test_review_binding_matches(self):
        value = manifest()
        value["pairs"][1]["review_id"] = "other"
        self.assertTrue(any("review_id" in error for error in validate_manifest(value)))

    def test_review_gates_open(self):
        value = manifest()
        value["native_render"]["status"] = "passed"
        value["human_signoff"]["status"] = "approved"
        errors = validate_manifest(value)
        self.assertTrue(any("native_render" in error for error in errors))
        self.assertTrue(any("human_signoff" in error for error in errors))

    def test_exclusions_required(self):
        value = manifest()
        value["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_manifest(value)))

    def test_non_object_pair_fails_closed(self):
        value = manifest()
        value["pairs"][0] = None
        self.assertTrue(any("pairs[0] must be an object" in error for error in validate_manifest(value)))


if __name__ == "__main__":
    unittest.main()
