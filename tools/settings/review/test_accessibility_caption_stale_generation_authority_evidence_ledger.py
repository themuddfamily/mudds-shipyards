import copy
import unittest

from tools.settings.review.accessibility_caption_stale_generation_authority_evidence_ledger import (
    LIMITS,
    OWNERSHIP_IDS,
    OWNERSHIP_RULES,
    REQUIRED_CHECKS,
    validate_ledger,
)


def _ledger() -> dict:
    ownership = [{
        "id": row_id,
        "owner": OWNERSHIP_RULES[row_id]["owner"],
        "value": OWNERSHIP_RULES[row_id]["value"],
        "authority": OWNERSHIP_RULES[row_id]["authority"],
        "expected_behavior": f"The {row_id} generation-authority ownership remains deterministic.",
        "status": "planned",
        "evidence": None,
    } for row_id in OWNERSHIP_IDS]
    checks = [{
        "id": check_id,
        "expected": f"The {check_id} generation-authority check remains deterministic.",
        "source_test": "tests/caption_presentation_service_test.gd",
        "status": "planned",
        "evidence": None,
    } for check_id in REQUIRED_CHECKS]
    return {
        "schema": "accessibility_caption_stale_generation_authority_evidence_v1",
        "source_revision": "working-tree-caption-stale-generation-authority-review",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "service_source": "scripts/ui/caption_presentation_service.gd",
        "contract_source": "scripts/ui/caption_accessibility_contract.gd",
        "consumer_boundary": "caption presentation snapshot consumer",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human stale-generation authority review or native render has been performed",
        "human_review_performed": False,
        "native_render_performed": False,
        "presentation_only": True,
        "audio_authority": False,
        "audio_playback": False,
        "caption_queue_authority": False,
        "settings_authority": False,
        "gameplay_authority": False,
        "network_authority": False,
        "stale_payload_mutation": False,
        "service_id": "caption-presentation-service",
        "contract_id": "caption-accessibility-contract",
        "generation_policy": "service_owned_monotonic_reset_increment",
        "revision_policy": "service_owned_post_commit_increment",
        "stale_policy": "consumer_rejects_generation_or_revision_mismatch",
        "authority_policy": "presentation_only_contract",
        "limits": copy.deepcopy(LIMITS),
        "ownership": ownership,
        "checks": checks,
    }


class AccessibilityCaptionStaleGenerationAuthorityTests(unittest.TestCase):
    def test_complete_source_only_ledger_keeps_human_gate_open(self):
        self.assertEqual(validate_ledger(_ledger()), [])

    def test_generation_revision_stale_and_authority_policies_are_exact(self):
        value = _ledger()
        value["generation_policy"] = "consumer_owned"
        value["revision_policy"] = "wall_clock"
        value["stale_policy"] = "accept_old"
        value["authority_policy"] = "audio_owned"
        value["limits"]["generation_step_after_reset"] = 2
        errors = validate_ledger(value)
        self.assertTrue(any("generation_policy must" in error for error in errors))
        self.assertTrue(any("revision_policy must" in error for error in errors))
        self.assertTrue(any("stale_policy must" in error for error in errors))
        self.assertTrue(any("authority_policy must" in error for error in errors))
        self.assertTrue(any("limits must exactly" in error for error in errors))

    def test_ownership_rows_and_authority_fail_closed(self):
        value = _ledger()
        value["ownership"][0]["owner"] = "caption_consumer"
        value["ownership"][3]["authority"] = "gameplay"
        value["settings_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("ownership[0].owner" in error for error in errors))
        self.assertTrue(any("ownership[3].authority" in error for error in errors))
        self.assertTrue(any("settings_authority" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation" in error for error in errors))

    def test_observed_ownership_requires_valid_evidence_digest(self):
        value = _ledger()
        value["ownership"][0]["status"] = "observed"
        errors = validate_ledger(value)
        self.assertTrue(any("ownership[0].evidence must be null" in error for error in errors))
        value["ownership"][0]["evidence"] = [{"kind": "report", "path": "reports/caption-stale-authority.json", "sha256": "bad"}]
        errors = validate_ledger(value)
        self.assertTrue(any("sha256 must be a lowercase digest" in error for error in errors))

    def test_identity_and_render_claims_fail_closed(self):
        value = _ledger()
        value["service_id"] = "other-service"
        value["contract_id"] = "other-contract"
        value["native_render_status"] = "observed"
        value["native_render_performed"] = True
        errors = validate_ledger(value)
        self.assertTrue(any("service_id must identify" in error for error in errors))
        self.assertTrue(any("contract_id must identify" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("native_render_performed" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _ledger()
        value["human_review_status"] = []
        value["ownership"][1] = {"id": {}, "owner": [], "value": {}, "authority": [], "status": []}
        value["checks"].append(copy.deepcopy(value["checks"][0]))
        errors = validate_ledger(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("ownership[1].id" in error for error in errors))
        self.assertTrue(any("checks.id values must be unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
