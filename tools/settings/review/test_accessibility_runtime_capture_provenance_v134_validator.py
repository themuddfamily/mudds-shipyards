import copy
import unittest

from tools.settings.review.accessibility_runtime_capture_provenance_v134_validator import (
    AUTHORITY,
    BINDING,
    CAPTURE_POLICY,
    CAPTURE_SCENARIOS,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_capture_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-capture-v134",
        "reviewer_required": "human accessibility visual QA",
        "open_gate_reason": "no human capture review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "capture_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "capture_scenarios": copy.deepcopy(CAPTURE_SCENARIOS),
        "capture_policy": copy.deepcopy(CAPTURE_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "stable_visual_capture_plan",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeCaptureProvenanceV134Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_capture_provenance(_record()), [])

    def test_capture_scenarios_and_policy_are_exact(self):
        value = _record()
        value["capture_scenarios"].remove("ultrawide")
        value["capture_policy"]["camera_mode"] = "free_camera"
        errors = validate_runtime_capture_provenance(value)
        self.assertTrue(any("capture_scenarios must exactly" in error for error in errors))
        self.assertTrue(any("capture_policy must exactly" in error for error in errors))

    def test_hardware_claim_boundary_is_exact(self):
        value = _record()
        value["capture_policy"]["hardware_claim"] = "passed"
        errors = validate_runtime_capture_provenance(value)
        self.assertTrue(any("capture_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_capture_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_capture_and_network_authority_fail_closed(self):
        value = _record()
        value["authority"]["capture_authority"] = True
        value["capture_authority"] = True
        errors = validate_runtime_capture_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("capture_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["capture_scenarios"] = {}
        value["capture_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_capture_provenance(value)
        self.assertTrue(any("capture_scenarios must exactly" in error for error in errors))
        self.assertTrue(any("capture_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
