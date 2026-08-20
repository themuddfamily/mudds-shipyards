"""Focused tests for the animation provenance and human-review gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from animation_provenance_validator import release_ready, validate_manifest


def manifest() -> dict:
    checks = {
        name: {"status": "pass", "evidence": f"automated/{name}.json"}
        for name in ("foot_contacts", "pose_continuity", "transition_continuity", "semantic_orientation")
    }
    return {
        "schema_version": 1,
        "claim_scope": "animation_provenance_and_quality_audit",
        "asset_id": "pilot_motion_v2",
        "source_artifact": "res://assets/pilot/pilot_motion_v2.glb",
        "authoring_mode": "script_assisted",
        "clips": [{
            "id": "boarding", "authoring_mode": "script_assisted",
            "duration_seconds": 1.2, "sample_rate_hz": 30, "keyframe_count": 42,
        }],
        "quality_audit": {
            "auditor": "tools/blender/generate_pilot_motion_v2.py",
            "checks": checks,
            "limitations": ["No animator hand-key review or foot IK evidence recorded."],
        },
        "human_review": {"status": "pending", "reviewer": "animation lead", "evidence": []},
    }


class AnimationProvenanceValidatorTests(unittest.TestCase):
    def test_script_assisted_manifest_is_valid_but_not_release_ready(self):
        value = manifest()
        self.assertEqual(validate_manifest(value), [])
        self.assertFalse(release_ready(value))

    def test_missing_human_review_fails_closed(self):
        value = manifest()
        del value["human_review"]
        errors = validate_manifest(value)
        self.assertTrue(any("human_review is required" in error for error in errors))

    def test_script_assisted_cannot_claim_animator_authored_clip(self):
        value = manifest()
        value["clips"][0]["authoring_mode"] = "animator_authored"
        errors = validate_manifest(value)
        self.assertTrue(any("cannot contain animator_authored clips" in error for error in errors))

    def test_approval_requires_timestamp_and_evidence(self):
        value = manifest()
        value["authoring_mode"] = "animator_authored"
        value["clips"][0]["authoring_mode"] = "animator_authored"
        value["human_review"]["status"] = "approved"
        errors = validate_manifest(value)
        self.assertIn("manifest.human_review.reviewed_at is required for approval", errors)
        self.assertIn("manifest.human_review.evidence is required for approval", errors)

    def test_only_animator_authored_approved_manifest_is_release_ready(self):
        value = manifest()
        value["authoring_mode"] = "animator_authored"
        value["clips"][0]["authoring_mode"] = "animator_authored"
        value["human_review"] = {
            "status": "approved", "reviewer": "A. Animator", "reviewed_at": "2026-08-20",
            "evidence": ["reviews/pilot_motion_v2_turntable.mp4"],
        }
        self.assertEqual(validate_manifest(value), [])
        self.assertTrue(release_ready(value))

    def test_mixed_mode_requires_distinct_clip_provenance(self):
        value = manifest()
        value["authoring_mode"] = "mixed"
        errors = validate_manifest(value)
        self.assertTrue(any("mixed must identify at least two" in error for error in errors))

    def test_quality_check_requires_evidence(self):
        value = copy.deepcopy(manifest())
        value["quality_audit"]["checks"]["foot_contacts"]["evidence"] = ""
        errors = validate_manifest(value)
        self.assertIn("manifest.quality_audit.checks.foot_contacts.evidence must be non-empty", errors)


if __name__ == "__main__":
    unittest.main()
