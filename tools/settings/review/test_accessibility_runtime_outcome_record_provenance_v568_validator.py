import copy
import unittest

from tools.settings.review.accessibility_runtime_outcome_record_provenance_v306_validator import (
    AUTHORITY, BINDING, CONTRACT_ID, OUTCOME_POLICY, SOURCE_ID, SOURCE_SCHEMA,
)
from tools.settings.review.accessibility_runtime_outcome_record_provenance_v568_validator import (
    SCHEMA, validate_runtime_outcome_record_provenance,
)


def record():
    return {
        "schema": SCHEMA, "source_schema": SOURCE_SCHEMA, "schema_version": "v568",
        "source_revision": "r", "reviewer_required": "human", "open_gate_reason": "open",
        "human_review_status": "not_performed", "native_render_status": "not_run",
        "human_review_performed": False, "native_render_performed": False,
        "policy_verified": False, "runtime_claimed": False, "outcome_written": False,
        "outcome_confirmed": False, "outcome_policy": copy.deepcopy(OUTCOME_POLICY),
        "binding": copy.deepcopy(BINDING), "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID, "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "runtime_accessibility_outcome_record_policy",
        "status": "planned", "evidence": None, **AUTHORITY,
    }


class AccessibilityRuntimeOutcomeRecordProvenanceV568Tests(unittest.TestCase):
    def test_complete(self): self.assertEqual(validate_runtime_outcome_record_provenance(record()), [])
    def test_schema(self):
        value = record(); value["schema"] = "bad"
        self.assertTrue(validate_runtime_outcome_record_provenance(value))
    def test_policy(self):
        value = record(); value["outcome_policy"] = []
        self.assertTrue(validate_runtime_outcome_record_provenance(value))
    def test_fields(self):
        value = record(); value["outcome_policy"]["outcome_fields"] = []
        self.assertTrue(validate_runtime_outcome_record_provenance(value))
    def test_gates(self):
        value = record(); value["native_render_status"] = "passed"
        self.assertTrue(validate_runtime_outcome_record_provenance(value))
    def test_authority(self):
        value = record(); value["authority"] = []
        self.assertTrue(validate_runtime_outcome_record_provenance(value))
