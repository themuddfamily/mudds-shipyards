import copy
import unittest

from tools.settings.review.accessibility_runtime_export_report_provenance_v201_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    EXPORT_POLICY,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_export_report_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-export-report-v201",
        "reviewer_required": "human accessibility and export-report QA",
        "open_gate_reason": "no human export-report review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "report_written": False,
        "export_replayed": False,
        "export_policy": copy.deepcopy(EXPORT_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_export_policy",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeExportReportProvenanceV201Tests(unittest.TestCase):
    def test_complete_record_keeps_gates_open(self):
        self.assertEqual(validate_runtime_export_report_provenance(_record()), [])

    def test_export_policy_and_binding_are_exact(self):
        value = _record()
        value["export_policy"]["invalid_destination"] = "partial_write"
        value["binding"]["apply_rule"] = "write_settings"
        errors = validate_runtime_export_report_provenance(value)
        self.assertTrue(any("export_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_preserved_accessibility_fields_cannot_shrink(self):
        value = _record()
        value["export_policy"]["preserved_fields"] = ["camera"]
        errors = validate_runtime_export_report_provenance(value)
        self.assertTrue(any("export_policy must exactly" in error for error in errors))

    def test_native_and_report_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["report_written"] = True
        errors = validate_runtime_export_report_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("report_written must be false" in error for error in errors))

    def test_export_report_authority_fails_closed(self):
        value = _record()
        value["authority"]["export_report_authority"] = True
        value["export_report_authority"] = True
        errors = validate_runtime_export_report_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("export_report_authority must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["export_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_export_report_provenance(value)
        self.assertTrue(any("export_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
