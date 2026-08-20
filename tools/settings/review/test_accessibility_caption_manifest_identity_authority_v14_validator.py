import copy
import unittest

from tools.settings.review.accessibility_caption_manifest_identity_authority_v14_validator import (
    AUTHORITY,
    IDENTITY_IDS,
    IDENTITY_RULES,
    SOURCE_SCHEMA,
    validate_manifest,
)


def _manifest() -> dict:
    entries = [{
        "id": entry_id,
        "identity": IDENTITY_RULES[entry_id]["identity"],
        "version": IDENTITY_RULES[entry_id]["version"],
        "authority": IDENTITY_RULES[entry_id]["authority"],
        "stale_policy": IDENTITY_RULES[entry_id]["stale_policy"],
        "expected_behavior": f"The {entry_id} manifest identity remains deterministic.",
    } for entry_id in IDENTITY_IDS]
    return {
        "schema": "accessibility_caption_manifest_identity_authority_v14_evidence_v1",
        "source_schema": SOURCE_SCHEMA,
        "source_revision": "working-tree-caption-identity-v14",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human v14 identity review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "digest_verified": False,
        "stale_payload_mutation": False,
        "digest_algorithm": "sha256",
        "canonicalization": "utf8_json_sorted_keys_no_whitespace_v14",
        "status": "planned",
        "digest": "0" * 64,
        "identity_policy": "unique_identity_version_authority_tuple",
        "generation_policy": "monotonic_reset_increment",
        "stale_policy": "reject_less_or_greater_generation",
        "authority": copy.deepcopy(AUTHORITY),
        "entries": entries,
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityCaptionManifestIdentityV14Tests(unittest.TestCase):
    def test_complete_manifest_keeps_native_and_human_gates_open(self):
        self.assertEqual(validate_manifest(_manifest()), [])

    def test_identity_versions_and_order_are_exact(self):
        value = _manifest()
        value["entries"].reverse()
        value["entries"][0]["version"] = 99
        errors = validate_manifest(value)
        self.assertTrue(any("entries must exactly" in error for error in errors))
        self.assertTrue(any("entries[0].version" in error for error in errors))

    def test_native_render_must_remain_not_run(self):
        value = _manifest()
        value["native_render_status"] = "planned"
        errors = validate_manifest(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))

    def test_identity_stale_and_authority_policies_fail_closed(self):
        value = _manifest()
        value["identity_policy"] = "last_writer_wins"
        value["stale_policy"] = "accept_old"
        value["authority"]["audio_authority"] = True
        value["audio_authority"] = True
        value["stale_payload_mutation"] = True
        errors = validate_manifest(value)
        self.assertTrue(any("identity_policy must" in error for error in errors))
        self.assertTrue(any("stale_policy must" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_authority must be false" in error for error in errors))

    def test_digest_and_evidence_formats_are_validated(self):
        value = _manifest()
        value["digest"] = "bad"
        value["evidence"] = [{"kind": "report", "path": "reports/identity-v14.json", "sha256": "bad"}]
        errors = validate_manifest(value)
        self.assertTrue(any("digest must be" in error for error in errors))
        self.assertTrue(any("evidence[0].sha256" in error for error in errors))

    def test_malformed_values_fail_without_throwing(self):
        value = _manifest()
        value["human_review_status"] = []
        value["native_render_status"] = {}
        value["entries"] = []
        value["authority"] = []
        errors = validate_manifest(value)
        self.assertTrue(any("human_review_status" in error for error in errors))
        self.assertTrue(any("native_render_status" in error for error in errors))
        self.assertTrue(any("exactly three ordered" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
