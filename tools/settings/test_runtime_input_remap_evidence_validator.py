import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.settings.runtime_input_remap_evidence_validator import validate, validate_manifest


class RuntimeInputRemapEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "remap_evidence.json"

    def tearDown(self):
        self.tmp.cleanup()

    def trial(
        self,
        trial_id: str,
        *,
        action: str,
        candidate: str,
        resolution: str,
        outcome: str,
        before: int,
        after: int,
        expected: int,
        conflicts: list[dict],
        unchanged: bool,
    ) -> dict:
        fingerprint = f"fp-{before}-{trial_id}"
        return {
            "id": trial_id,
            "action": action,
            "candidate_signature": candidate,
            "resolution": resolution,
            "outcome": outcome,
            "expected_revision": expected,
            "revision_before": before,
            "revision_after": after,
            "profile_fingerprint_before": fingerprint,
            "profile_fingerprint_after": fingerprint if unchanged else f"{fingerprint}-next",
            "profile_unchanged": unchanged,
            "conflicts": conflicts,
            "notes": "deterministic focused remap witness",
        }

    def manifest(self) -> dict:
        candidate = "keyboard:key:70"
        return {
            "schema": "runtime_input_remap_evidence_v1",
            "source_revision": "working-tree-remap-review",
            "contract": "scripts/input/runtime_input_remap_contract.gd",
            "evidence_scope": "detached runtime remap and conflict resolution",
            "runtime_authority_unchanged": True,
            "hardware_validation_status": "not_run",
            "conflict_policies": ["reject", "replace"],
            "action_roster": {
                "required_actions": ["alpha", "bravo", "hover", "jump"],
                "covered_actions": ["alpha", "bravo", "hover", "jump"],
            },
            "authored_overlaps": [{
                "binding_signature": "gamepad:joy_button:0",
                "actions": ["hover", "jump"],
                "rationale": "authored context-dependent shared face button",
            }],
            "trials": [
                self.trial(
                    "reject-conflict", action="bravo", candidate=candidate,
                    resolution="reject", outcome="rejected_conflict", before=0,
                    after=0, expected=0,
                    conflicts=[{"action": "alpha", "binding_signature": candidate}],
                    unchanged=True,
                ),
                self.trial(
                    "replace-conflict", action="bravo", candidate=candidate,
                    resolution="replace", outcome="committed_replace", before=0,
                    after=1, expected=0,
                    conflicts=[{"action": "alpha", "binding_signature": candidate}],
                    unchanged=False,
                ),
                self.trial(
                    "commit-free", action="alpha", candidate="keyboard:key:71",
                    resolution="reject", outcome="committed_no_conflict", before=1,
                    after=2, expected=1, conflicts=[], unchanged=False,
                ),
                self.trial(
                    "stale-menu", action="bravo", candidate="keyboard:key:72",
                    resolution="replace", outcome="rejected_stale_revision", before=2,
                    after=2, expected=1, conflicts=[], unchanged=True,
                ),
                self.trial(
                    "invalid-candidate", action="alpha", candidate="malformed",
                    resolution="reject", outcome="rejected_invalid", before=2,
                    after=2, expected=2, conflicts=[], unchanged=True,
                ),
            ],
        }

    def write(self, value: dict) -> None:
        self.path.write_text(json.dumps(value), encoding="utf-8")

    def test_complete_evidence_manifest_is_coherent(self):
        self.assertEqual(validate_manifest(self.manifest()), [])

    def test_reject_and_replace_require_atomic_revision_and_profile_rules(self):
        value = self.manifest()
        value["trials"][0]["revision_after"] = 1
        value["trials"][1]["profile_unchanged"] = True
        errors = validate_manifest(value)
        self.assertTrue(any("rejected_conflict must leave" in error for error in errors))
        self.assertTrue(any("committed_replace must change" in error for error in errors))

    def test_conflicts_must_match_candidate_and_action_roster(self):
        value = self.manifest()
        value["trials"][0]["conflicts"][0]["binding_signature"] = "keyboard:key:71"
        value["trials"][0]["conflicts"][0]["action"] = "unknown"
        errors = validate_manifest(value)
        self.assertTrue(any("must match candidate_signature" in error for error in errors))
        self.assertTrue(any("outside the action roster" in error for error in errors))

    def test_authored_overlap_and_hardware_boundaries_fail_closed(self):
        value = self.manifest()
        value["authored_overlaps"][0]["actions"] = ["hover", "unknown"]
        value["hardware_validation_status"] = "passed"
        errors = validate_manifest(value)
        self.assertTrue(any("unknown actions" in error for error in errors))
        self.assertTrue(any("hardware_validation_status" in error for error in errors))

    def test_duplicate_trials_and_parse_errors_are_reported(self):
        value = self.manifest()
        value["trials"].append(copy.deepcopy(value["trials"][0]))
        errors = validate_manifest(value)
        self.assertTrue(any("trials.id values must be unique" in error for error in errors))
        self.path.write_text("{broken", encoding="utf-8")
        self.assertTrue(any("manifest unreadable" in error for error in validate(self.path)))


if __name__ == "__main__":
    unittest.main()
