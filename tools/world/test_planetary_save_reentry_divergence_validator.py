import copy
import unittest

from tools.world.planetary_save_reentry_divergence_validator import validate_evidence


def snapshot(state: str, attachment: int, frame: int) -> dict:
    return {
        "state": state,
        "world_id": "ember_moon",
        "session_id": "ember_visit_01",
        "phase": "surface",
        "attachment_generation": attachment,
        "checkpoint_generation": 3,
        "physics_tick": 240,
        "frame_generation": frame,
        "payload_digest": "sha256:payload-ember-03",
        "local_streaming_position_persisted": False,
    }


def evidence() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_save_reentry_divergence",
        "evidence_mode": "detached_contract_fixture",
        "native_claims": False,
        "filesystem_write": False,
        "scene_restore": False,
        "runtime_save_authority": False,
        "source_revision": "planetary-save-contract-v1",
        "initial_snapshot": snapshot("active", 1, 4),
        "detached_snapshot": snapshot("detached", 1, 4),
        "reentered_snapshot": snapshot("active", 2, 5),
        "orbit_restore": {
            "accepted": True,
            "absolute_coordinate_preserved": True,
            "saved_frame_generation": 4,
            "restore_frame_generation": 5,
            "absolute_coordinate_digest": "sha256:absolute-orbit-01",
        },
        "surface_restore": {
            "stale_attempt_accepted": False,
            "stale_rejection_reason": "surface_checkpoint_generation_mismatch",
            "recapture_accepted": True,
            "saved_frame_generation": 4,
            "recapture_frame_generation": 5,
        },
        "divergence_guards": {
            "stale_attachment_rejected": True,
            "stale_checkpoint_rejected": True,
            "duplicate_session_rejected": True,
            "payload_digest_unchanged": True,
            "local_position_not_persisted": True,
            "generation_fenced": True,
        },
        "authority": {
            "filesystem": False,
            "scene_restore": False,
            "physics": False,
            "streaming": False,
            "gameplay": False,
            "clock": False,
            "origin_shift": False,
            "network": False,
        },
    }


class PlanetarySaveReentryDivergenceValidatorTest(unittest.TestCase):
    def test_save_reentry_fixture_is_valid(self):
        self.assertEqual(validate_evidence(evidence()), [])

    def test_detach_must_not_advance_progress(self):
        item = evidence(); item["detached_snapshot"]["physics_tick"] = 241
        self.assertTrue(any("physics progress" in error for error in validate_evidence(item)))

    def test_reentry_must_advance_attachment_once(self):
        item = evidence(); item["reentered_snapshot"]["attachment_generation"] = 3
        self.assertTrue(any("advance exactly once" in error for error in validate_evidence(item)))

    def test_orbit_restore_requires_absolute_coordinate(self):
        item = evidence(); item["orbit_restore"]["absolute_coordinate_preserved"] = False
        self.assertTrue(any("absolute_coordinate_preserved" in error for error in validate_evidence(item)))

    def test_surface_stale_checkpoint_is_rejected(self):
        item = evidence(); item["surface_restore"]["stale_attempt_accepted"] = True
        self.assertTrue(any("stale_attempt_accepted" in error for error in validate_evidence(item)))

    def test_payload_divergence_fails(self):
        item = copy.deepcopy(evidence()); item["reentered_snapshot"]["payload_digest"] = "sha256:changed"
        self.assertTrue(any("payload_digest" in error for error in validate_evidence(item)))

    def test_local_position_must_not_be_persisted(self):
        item = evidence(); item["initial_snapshot"]["local_streaming_position_persisted"] = True
        self.assertTrue(any("local_streaming_position" in error for error in validate_evidence(item)))

    def test_native_and_runtime_authority_claims_are_closed(self):
        item = evidence(); item["native_claims"] = True; item["authority"]["filesystem"] = True
        errors = validate_evidence(item)
        self.assertTrue(any("native_claims" in error for error in errors))
        self.assertTrue(any("authority.filesystem" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
