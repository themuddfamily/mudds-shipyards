import copy
import unittest

from tools.settings.review.accessibility_runtime_route_provenance_v121_validator import (
    AUTHORITY,
    BINDING,
    CONTRACT_ID,
    FALLBACKS,
    ROUTES,
    SCHEMA,
    SCHEMA_VERSION,
    SOURCE_ID,
    SOURCE_SCHEMA,
    validate_runtime_route_provenance,
)


def _record() -> dict:
    return {
        "schema": SCHEMA,
        "source_schema": SOURCE_SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "source_revision": "working-tree-runtime-route-v121",
        "reviewer_required": "human accessibility and caption QA",
        "open_gate_reason": "no human route review or native render has been performed",
        "human_review_status": "not_performed",
        "native_render_status": "not_run",
        "human_review_performed": False,
        "native_render_performed": False,
        "route_verified": False,
        "runtime_claimed": False,
        "stale_payload_mutation": False,
        "routes": copy.deepcopy(ROUTES),
        "fallbacks": copy.deepcopy(FALLBACKS),
        "binding": copy.deepcopy(BINDING),
        "authority": copy.deepcopy(AUTHORITY),
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "provenance_source_of_truth": "presentation_only",
        "status": "planned",
        "evidence": None,
        **AUTHORITY,
    }


class AccessibilityRuntimeRouteProvenanceV121Tests(unittest.TestCase):
    def test_complete_record_keeps_review_and_native_gates_open(self):
        self.assertEqual(validate_runtime_route_provenance(_record()), [])

    def test_route_and_fallback_maps_are_exact(self):
        value = _record()
        value["routes"]["caption_decision"] = "settings_store"
        value["fallbacks"]["inaudible_audio"] = "silent"
        errors = validate_runtime_route_provenance(value)
        self.assertTrue(any("routes must exactly" in error for error in errors))
        self.assertTrue(any("fallbacks must exactly" in error for error in errors))

    def test_native_and_runtime_claims_must_remain_open(self):
        value = _record()
        value["native_render_status"] = "passed"
        value["runtime_claimed"] = True
        errors = validate_runtime_route_provenance(value)
        self.assertTrue(any("native_render_status must remain not_run" in error for error in errors))
        self.assertTrue(any("runtime_claimed must be false" in error for error in errors))

    def test_authority_fails_closed(self):
        value = _record()
        value["authority"]["audio_playback"] = True
        value["audio_playback"] = True
        errors = validate_runtime_route_provenance(value)
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("audio_playback must be false" in error for error in errors))

    def test_binding_and_stale_mutation_fail_closed(self):
        value = _record()
        value["binding"]["stale_policy"] = "accept_old"
        value["stale_payload_mutation"] = True
        errors = validate_runtime_route_provenance(value)
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("stale_payload_mutation must be false" in error for error in errors))

    def test_malformed_shapes_fail_without_throwing(self):
        value = _record()
        value["routes"] = []
        value["fallbacks"] = []
        value["binding"] = []
        value["authority"] = []
        value["evidence"] = [{"kind": [], "path": {}, "sha256": []}]
        errors = validate_runtime_route_provenance(value)
        self.assertTrue(any("routes must exactly" in error for error in errors))
        self.assertTrue(any("fallbacks must exactly" in error for error in errors))
        self.assertTrue(any("binding must exactly" in error for error in errors))
        self.assertTrue(any("authority must exactly" in error for error in errors))
        self.assertTrue(any("evidence[0].kind" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
