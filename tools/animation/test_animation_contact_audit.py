"""Focused tests for animation contact and boarding acceptance evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from animation_contact_audit import release_ready, validate_audit  # noqa: E402


def audit() -> dict:
    def clip(name: str, kind: str | None = None) -> dict:
        value = {
            "id": name,
            "authoring_mode": "script_assisted",
            "sole_contact": {"min_mm": -5, "max_mm": 12, "tolerance_mm": 15, "evidence": f"checks/{name}_sole.json"},
            "cycle": {"closed": True, "velocity_continuous": True, "evidence": f"checks/{name}_cycle.json"},
        }
        if kind:
            value["seat_transition"] = {"kind": kind, "joins_seated_control": True, "contact_anchor_continuous": True, "evidence": f"checks/{kind}.json"}
        return value

    return {
        "schema_version": 1,
        "claim_scope": "animation_contact_boarding_audit",
        "asset_id": "pilot_motion_v2",
        "source_artifact": "res://assets/pilot/pilot_motion_v2.glb",
        "authoring_mode": "script_assisted",
        "provenance": {"generator": "tools/blender/generate_pilot_motion_v2.py", "source_rig": "art_source/pilot/pilot.blend", "asset_digest": "sha256:fixture", "byte_reproducible": False},
        "clips": [clip("walk"), clip("boarding", "boarding"), clip("disembark", "disembark")],
        "human_review": {"status": "pending", "reviewer": "animation lead", "evidence": []},
    }


class AnimationContactAuditTests(unittest.TestCase):
    def test_script_assisted_contact_audit_is_valid_but_pending(self):
        self.assertEqual(validate_audit(audit()), [])
        self.assertFalse(release_ready(audit()))

    def test_sole_error_outside_tolerance_fails(self):
        value = audit()
        value["clips"][0]["sole_contact"]["max_mm"] = 16
        self.assertIn("audit.clips[0].sole_contact error exceeds tolerance", validate_audit(value))

    def test_cycles_must_close_with_continuous_velocity(self):
        value = audit()
        value["clips"][0]["cycle"]["closed"] = False
        value["clips"][0]["cycle"]["velocity_continuous"] = False
        errors = validate_audit(value)
        self.assertIn("audit.clips[0].cycle.closed must be true", errors)
        self.assertIn("audit.clips[0].cycle.velocity_continuous must be true", errors)

    def test_both_seat_transitions_are_required_and_join_seated_control(self):
        value = audit()
        del value["clips"][2]
        value["clips"][1]["seat_transition"]["joins_seated_control"] = False
        errors = validate_audit(value)
        self.assertIn("audit.clips[1].seat_transition.joins_seated_control must be true", errors)
        self.assertIn("audit.clips must include a disembark seat transition", errors)

    def test_provenance_cannot_claim_byte_reproducibility_without_evidence(self):
        value = audit()
        value["provenance"]["byte_reproducible"] = True
        self.assertIn("audit.provenance.byte_reproducible must be false unless byte identity is proven", validate_audit(value))

    def test_approval_requires_animator_provenance_and_review_evidence(self):
        value = audit()
        value["authoring_mode"] = "animator_authored"
        for clip in value["clips"]:
            clip["authoring_mode"] = "animator_authored"
        value["human_review"] = {"status": "approved", "reviewer": "A. Animator", "reviewed_at": "2026-08-20", "evidence": ["reviews/pilot.mp4"]}
        self.assertEqual(validate_audit(value), [])
        self.assertTrue(release_ready(value))

    def test_duplicate_clip_ids_fail(self):
        value = copy.deepcopy(audit())
        value["clips"][1]["id"] = "walk"
        self.assertIn("audit.clips[1].id must be unique", validate_audit(value))


if __name__ == "__main__":
    unittest.main()
