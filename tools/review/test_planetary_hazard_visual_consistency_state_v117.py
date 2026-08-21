import unittest

from tools.review.planetary_hazard_visual_consistency_state_v117 import validate_manifest


def manifest() -> dict:
    schema = "planetary_hazard_visual_consistency_state_v117"
    root = "world_root"
    consistency = "consistency_record"
    state = "state_record"
    pairs = [
        {
            "id": kind,
            "kind": kind,
            "consistency_state_evidence_id": "evidence_" + kind,
            "consistency_version": 117,
            "state_version": 117,
            "schema": schema,
            "schema_version": 117,
            "parent_id": root,
            "consistency_id": consistency,
            "state_id": state,
            "runtime_authority": False,
            "status": status,
        }
        for kind, status in (("hazard", "pending"), ("landmark", "not_performed"), ("route", "pending"))
    ]
    return {
        "schema": schema,
        "schema_version": 117,
        "consistency_version": 117,
        "state_version": 117,
        "world_id": "ember_moon",
        "region_id": "caldera_rim",
        "manifest_id": "caldera_visual_manifest",
        "root_id": root,
        "consistency_id": consistency,
        "state_id": state,
        "source_revision": "working-tree-planetary-visual-v117",
        "pairs": pairs,
        "native_render": {"status": "not_performed"},
        "human_signoff": {"status": "pending"},
        "claims_excluded": [
            "visual_consistency_state_approval",
            "native_render",
            "human_signoff",
        ],
    }


class PlanetaryHazardVisualConsistencyStateV117Test(unittest.TestCase):
    def test_valid_open_manifest(self):
        self.assertEqual(validate_manifest(manifest()), [])

    def test_manifest_version_strict(self):
        value = manifest()
        value["schema_version"] = 116
        self.assertTrue(any("schema_version must be 117" in error for error in validate_manifest(value)))

    def test_consistency_version_strict(self):
        value = manifest()
        value["consistency_version"] = 116
        self.assertTrue(any("consistency_version must be 117" in error for error in validate_manifest(value)))

    def test_state_version_strict(self):
        value = manifest()
        value["pairs"][0]["state_version"] = 116
        self.assertTrue(any("state_version must be 117" in error for error in validate_manifest(value)))

    def test_evidence_unique(self):
        value = manifest()
        value["pairs"][1]["consistency_state_evidence_id"] = value["pairs"][0]["consistency_state_evidence_id"]
        self.assertTrue(any("evidence_id" in error for error in validate_manifest(value)))

    def test_state_binding_matches(self):
        value = manifest()
        value["pairs"][1]["state_id"] = "other"
        self.assertTrue(any("state_id" in error for error in validate_manifest(value)))

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
