import copy
import unittest

from tools.settings.review.accessibility_runtime_tutorial_provenance_v143_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    TUTORIAL_POLICY,
    validate_runtime_tutorial_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-tutorial-v143",
        "reviewer_required": "human accessibility and controller QA",
        "open_gate_reason": "no human tutorial review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "tutorial_policy": copy.deepcopy(TUTORIAL_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "tutorial_prompt_definition",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeTutorialProvenanceV143Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_tutorial_provenance(_record()), [])

    def test_tutorial_policy_and_binding_are_exact(self):
        value = _record()
        value["tutorial_policy"]["accessible_variant"] = "colour_only"
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_tutorial_provenance(value)
        self.assertTrue(any("tutorial_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_all_prompt_variants_are_required(self):
        value = _record()
        value["tutorial_policy"]["prompt_variants"] = ["keyboard"]
        value["tutorial_policy"]["missing_prompt"] = "silently_skip"
        errors = validate_runtime_tutorial_provenance(value)
        self.assertTrue(any("tutorial_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_tutorial_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_progression_authority_fails_closed(self):
        value = _record()
        value["authority"]["tutorial_progression_authority"] = True
        value["tutorial_progression_authority"] = True
        errors = validate_runtime_tutorial_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("tutorial_progression_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["tutorial_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_tutorial_provenance(value)
        self.assertTrue(any("tutorial_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
