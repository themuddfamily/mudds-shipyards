import copy
import unittest

from tools.settings.review.accessibility_caption_release_lineage_v72_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    PREVIOUS_VERSION,
    RELEASE_CHECKS,
    RELEASE_ID,
    RELEASE_LINEAGE,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    SOURCE_STATE_ID,
    validate_release_lineage,
)


def _record() -> dict:
    return {
        "schema": "accessibility_caption_release_lineage_v72_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-caption-release-v72",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v72 release/lineage review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "release_claimed": False,
        "lineage_verified": False,
        "stale_payload_mutation": False,
        "binding": copy.deepcopy(BINDING),
        "release_lineage": copy.deepcopy(RELEASE_LINEAGE),
        "release_checks": copy.deepcopy(RELEASE_CHECKS),
        "authority": copy.deepcopy(AUTHORITY),
        "release_id": RELEASE_ID,
        "release_status": "unclaimed",
        "lineage_status": "unverified",
        "lineage_mode": "exact",
        "source_id": SOURCE_ID,
        "source_mode": "exact",
        "source_state_id": SOURCE_STATE_ID,
        "source_state_status": "open",
        "contract_id": CONTRACT_ID,
        "contract_mode": "exact",
        "current_version": SCHEMA_VERSION,
        "previous_version": PREVIOUS_VERSION,
        "version_relation": "adjacent_exact",
        "provenance_source_of_truth": "presentation_only",
        "status": "planned",
        "authority_owner": SOURCE_ID,
        "generation_owner": SOURCE_ID,
        "service_id": SOURCE_ID,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionReleaseLineageV72Tests(unittest.TestCase):
    def test_complete_record_keeps_release_unclaimed_and_native_gate_closed(self):
        self.assertEqual(validate_release_lineage(_record()), [])

    def test_v71_source_chain_is_exact(self):
        value = _record()
        value["source_schema"] = "accessibility_caption_state_consistency_v70_evidence_v1"
        value["source_state_id"] = "caption-accessibility-state-v70"
        value["release_lineage"]["previous_version"] = "v70"
        errors = validate_release_lineage(value)
        self.assertTrue(any("source_schema must be" in error for error in errors))
        self.assertTrue(any("source_state_id must be" in error for error in errors))
        self.assertTrue(any("release_lineage must exactly" in error for error in errors))

    def test_human_native_and_release_gates_remain_open(self):
        value = _record()
        value["native_render_status"] = "planned"
        value["human_review_performed"] = True
        value["release_claimed"] = True
        errors = validate_release_lineage(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("human_review_performed must be false" in error for error in errors))
        self.assertTrue(any("release_claimed must be false" in error for error in errors))

    def test_authority_and_stale_policy_fail_closed(self):
        value = _record()
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_release_lineage(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_release_checks_are_exact(self):
        value = _record()
        value["release_checks"]["release_owner"] = False
        value["lineage_mode"] = "best_effort"
        errors = validate_release_lineage(value)
        self.assertTrue(any("release_checks must exactly" in error for error in errors))
        self.assertTrue(any("lineage_mode must be exact" in error for error in errors))

    def test_evidence_requires_sha256_metadata(self):
        value = _record()
        value["evidence"] = [{"kind": "report", "path": "reports/v72.json", "sha256": "bad"}]
        errors = validate_release_lineage(value)
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["human_review_status"] = []
        value["binding"] = []
        value["release_lineage"] = []
        value["release_checks"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_release_lineage(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("release_lineage must exactly" in error for error in errors))
        self.assertTrue(any("release_checks must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
