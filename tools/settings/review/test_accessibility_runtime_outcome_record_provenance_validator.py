#!/usr/bin/env python3
"""Tests for the consolidated accessibility runtime outcome-record validator.

The fixture beside this file is the exact record the retired v1029 module
accepted, captured before that 769-module family was deleted, so these tests
pin the same contract against a real artifact.
"""

import json
import unittest
from pathlib import Path

from tools.settings.review.accessibility_runtime_outcome_record_provenance_validator import (
    SUPPORTED_VERSIONS,
    document_version,
    schema_name,
    validate_runtime_outcome_record_provenance as validate_record,
)

FIXTURE = (
    Path(__file__).resolve().parent
    / "fixtures"
    / "accessibility_runtime_outcome_record_provenance_v1029.json"
)


def record() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


class AccessibilityRuntimeOutcomeRecordProvenanceValidatorTest(unittest.TestCase):
    def test_captured_v1029_record_is_valid(self):
        self.assertEqual(validate_record(record()), [])

    def test_version_is_read_from_the_record(self):
        self.assertEqual(document_version(record()), 1029)
        self.assertIn(261, SUPPORTED_VERSIONS)
        self.assertIn(1029, SUPPORTED_VERSIONS)
        self.assertNotIn(260, SUPPORTED_VERSIONS)
        self.assertNotIn(1030, SUPPORTED_VERSIONS)

    def test_version_outside_the_range_is_refused(self):
        item = record()
        item["schema_version"] = "v1030"
        self.assertEqual(validate_record(item), ["schema_version must be v261 through v1029"])

    def test_schema_name_tracks_the_version(self):
        item = record()
        item["schema_version"] = "v900"
        item["schema"] = schema_name(900)
        self.assertEqual(validate_record(item), [])

    def test_a_record_claiming_review_was_performed_is_refused(self):
        item = record()
        item["human_review_performed"] = True
        self.assertIn("human_review_performed", validate_record(item))

    def test_a_record_claiming_a_native_run_is_refused(self):
        item = record()
        item["native_render_status"] = "run"
        self.assertIn("native_render_status", validate_record(item))

    def test_a_closed_review_gate_is_refused(self):
        item = record()
        item["human_review_status"] = "passed"
        self.assertIn("human_review_status", validate_record(item))

    def test_authority_cannot_be_claimed(self):
        item = record()
        item["gameplay_authority"] = True
        self.assertIn("gameplay_authority", validate_record(item))

    def test_policy_and_binding_are_pinned(self):
        item = record()
        item["binding"] = dict(item["binding"], human_gate="closed")
        self.assertIn("binding", validate_record(item))

    def test_evidence_items_need_a_kind_path_and_digest(self):
        item = record()
        item["evidence"] = [{"kind": "log", "path": "run.log", "sha256": "zz"}]
        self.assertIn("evidence item", validate_record(item))

    def test_evidence_may_be_absent_but_not_empty(self):
        item = record()
        item.pop("evidence", None)
        self.assertEqual(validate_record(item), [])
        item["evidence"] = []
        self.assertIn("evidence", validate_record(item))

    def test_non_object_is_refused(self):
        self.assertEqual(validate_record("record"), ["record must be an object"])


if __name__ == "__main__":
    unittest.main()
