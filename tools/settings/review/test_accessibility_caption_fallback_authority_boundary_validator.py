import copy
import unittest

from tools.settings.review.accessibility_caption_fallback_authority_boundary_validator import (
    AUTHORITY_VALUES,
    BOUNDARY_IDS,
    BOUNDARY_RULES,
    validate_ledger,
)


def _ledger() -> dict:
    boundaries = [{
        "id": boundary_id,
        "owner": BOUNDARY_RULES[boundary_id]["owner"],
        "direction": BOUNDARY_RULES[boundary_id]["direction"],
        "mutates": BOUNDARY_RULES[boundary_id]["mutates"],
        "scope": BOUNDARY_RULES[boundary_id]["scope"],
        "expected_behavior": f"The {boundary_id} authority boundary remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for boundary_id in BOUNDARY_IDS]
    case_specs = (
        ("audio_observation_not_playback", "audio_observation"),
        ("settings_profile_not_mutated", "settings_profile"),
        ("decision_accept_reject_only", "caption_decision"),
        ("queue_handoff_not_owned", "queue_handoff"),
        ("fallback_text_not_audio", "fallback_text"),
        ("forbidden_gameplay_effects", "authority_roster"),
    )
    cases = [{
        "id": case_id,
        "boundary": boundary,
        "expected": f"The {case_id} authority result remains deterministic.",
        "source_test": "tests/caption_accessibility_contract_test.gd",
        "status": "planned",
        "evidence": None,
    } for case_id, boundary in case_specs]
    value = {
        "schema": "accessibility_caption_fallback_authority_boundary_evidence_v1",
        "source_revision": "working-tree-caption-authority-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human caption authority-boundary review or native render has been performed",
        "contract_id": "caption-accessibility-contract",
        "service_id": "caption-presentation-service",
        "decision_outputs": ["accepted", "reason", "stable_id", "category", "speaker", "text"],
        "forbidden_effects": ["audio_playback", "settings_mutation", "gameplay_mutation", "reward_mutation", "network_mutation"],
        "boundaries": boundaries,
        "cases": cases,
    }
    value.update(AUTHORITY_VALUES)
    return value


class AccessibilityCaptionFallbackAuthorityBoundaryTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_authority_roster_is_exact(self):
        value = _ledger()
        value["audio_authority"] = True
        value["presentation_only"] = False
        value["forbidden_effects"] = ["audio_playback"]
        errors = validate_ledger(value)
        self.assertTrue(any("audio_authority must be false" in error for error in errors))
        self.assertTrue(any("presentation_only must be true" in error for error in errors))
        self.assertTrue(any("forbidden_effects must exactly" in error for error in errors))

    def test_boundary_owners_and_mutation_flags_fail_closed(self):
        value = _ledger()
        value["boundaries"][0]["owner"] = "caption_contract"
        value["boundaries"][1]["mutates"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("boundaries[0].owner" in error for error in errors))
        self.assertTrue(any("boundaries[1].mutates" in error for error in errors))

    def test_observed_boundary_requires_valid_evidence_digest(self):
        value = _ledger()
        value["boundaries"][2]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("boundaries[2].evidence must be null" in error for error in errors))
        value["boundaries"][2]["evidence"] = [{"kind": "report", "path": "reports/caption-authority.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_decision_outputs_and_identity_fail_closed(self):
        value = _ledger()
        value["decision_outputs"].remove("text")
        value["contract_id"] = "other-contract"
        value["service_id"] = "other-service"
        errors = validate_ledger(value)
        self.assertTrue(any("decision_outputs must exactly" in error for error in errors))
        self.assertTrue(any("contract_id must identify" in error for error in errors))
        self.assertTrue(any("service_id must identify" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["boundaries"][1] = {"id": {}, "owner": [], "direction": {}, "mutates": [], "scope": [], "status": []}
        value["cases"].append(copy.deepcopy(value["cases"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("boundaries[1].id" in error for error in errors))
        self.assertTrue(any("cases.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
