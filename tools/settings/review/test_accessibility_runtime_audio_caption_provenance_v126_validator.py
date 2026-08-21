import copy
import unittest

from tools.settings.review.accessibility_runtime_audio_caption_provenance_v126_validator import (
    AUDIO_CAPTION_POLICY,
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_audio_caption_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-audio-caption-v126",
        "reviewer_required": "human accessibility and audio QA",
        "open_gate_reason": "no human fallback listening review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "policy_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "audio_caption_policy": copy.deepcopy(AUDIO_CAPTION_POLICY),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "audibility_observation",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeAudioCaptionProvenanceV126Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_audio_caption_provenance(_record()), [])

    def test_fallback_policy_and_binding_are_exact(self):
        value = _record()
        value["audio_caption_policy"]["inaudible_text_fallback"] = ""
        value["binding"]["stale_policy"] = "accept_old"
        errors = validate_runtime_audio_caption_provenance(value)
        self.assertTrue(any("audio_caption_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))

    def test_subtitle_modes_cannot_be_widened_without_review(self):
        value = _record()
        value["audio_caption_policy"]["subtitle_modes"].append("always_on")
        errors = validate_runtime_audio_caption_provenance(value)
        self.assertTrue(any("audio_caption_policy must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_audio_caption_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_authority_fails_closed(self):
        value = _record()
        value["authority"]["audio_playback"] = True
        value["audio_playback"] = True
        errors = validate_runtime_audio_caption_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_playback must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["audio_caption_policy"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_audio_caption_provenance(value)
        self.assertTrue(any("audio_caption_policy must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
