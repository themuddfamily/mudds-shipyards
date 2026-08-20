import unittest

from tools.review.planetary_package_evidence_index_validator import validate_index


def index():
    return {
        "schema": "planetary_package_evidence_index_v1", "source_revision": "66479e5", "owner": "release-evidence",
        "entries": [
            {"id": "planetary-contract", "kind": "planetary_source", "path": "res://scripts/world/planetary_world_definition.gd", "purpose": "world contract", "status": "present", "historical_claim": False},
            {"id": "package-manifest", "kind": "package_manifest", "path": "res://docs/RELEASE_EVIDENCE_TOOL.md", "purpose": "package evidence route", "status": "present", "historical_claim": False},
        ],
        "native_execution": {"status": "not_performed", "evidence": None}, "human_review": {"status": "pending", "evidence": None}, "release_signoff": {"status": "pending", "evidence": None},
        "claims_excluded": ["native_execution", "human_review", "release_signoff"],
    }


class PlanetaryPackageEvidenceIndexValidatorTest(unittest.TestCase):
    def test_open_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_schema_is_strict(self):
        item = index(); item["schema"] = "v0"
        self.assertTrue(any("schema" in error for error in validate_index(item)))

    def test_entry_ids_are_unique(self):
        item = index(); item["entries"][1]["id"] = item["entries"][0]["id"]
        self.assertTrue(any("unique" in error for error in validate_index(item)))

    def test_entry_path_must_be_res_path(self):
        item = index(); item["entries"][0]["path"] = "/tmp/contract.gd"
        self.assertTrue(any("res://" in error for error in validate_index(item)))

    def test_missing_entry_requires_reason(self):
        item = index(); item["entries"][0]["status"] = "missing"
        self.assertTrue(any("reason" in error for error in validate_index(item)))

    def test_historical_claims_are_rejected(self):
        item = index(); item["entries"][0]["historical_claim"] = True
        self.assertTrue(any("historical_claim" in error for error in validate_index(item)))

    def test_native_not_performed_cannot_have_evidence(self):
        item = index(); item["native_execution"]["evidence"] = "Windows run"
        self.assertTrue(any("evidence must be null" in error for error in validate_index(item)))

    def test_all_open_gate_exclusions_are_required(self):
        item = index(); item["claims_excluded"] = []
        self.assertTrue(any("claims_excluded" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
