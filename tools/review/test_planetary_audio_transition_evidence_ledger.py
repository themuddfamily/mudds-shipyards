import unittest

from tools.review.planetary_audio_transition_evidence_ledger import validate_ledger


def ledger():
    return {
        "schema": "planetary_audio_transition_evidence_v1", "world_id": "ember_moon", "region_id": "caldera_relay", "source_revision": "b2c898e",
        "profiles": [{"id": "surface_exterior", "state": "exterior", "bus_id": "surface_bus", "loop_asset": "wind", "asset_path": "res://assets/audio/surface/wind.wav"}, {"id": "relay_interior", "state": "interior", "bus_id": "interior_bus", "loop_asset": "relay_hum", "asset_path": "res://assets/audio/interior/relay_hum.wav"}],
        "transitions": [{"state": "exterior", "trigger": "outside", "fade_policy": "hold", "review_status": "pending"}, {"state": "threshold", "trigger": "doorway_crossed", "fade_policy": "crossfade_1s", "review_status": "pending"}, {"state": "interior", "trigger": "inside", "fade_policy": "crossfade_1s", "review_status": "not_performed"}],
        "hardware_audition": {"status": "NOT_RUN", "evidence": None}, "authority_exclusions": ["audio_playback", "mix_resolution", "hardware_audition"],
    }


class PlanetaryAudioTransitionEvidenceLedgerTest(unittest.TestCase):
    def test_open_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_profiles_need_distinct_ids(self):
        item = ledger(); item["profiles"][1]["id"] = item["profiles"][0]["id"]
        self.assertTrue(any("unique" in error for error in validate_ledger(item)))

    def test_profile_asset_must_be_res_path(self):
        item = ledger(); item["profiles"][0]["asset_path"] = "wind.wav"
        self.assertTrue(any("asset_path" in error for error in validate_ledger(item)))

    def test_transition_states_are_ordered(self):
        item = ledger(); item["transitions"][1]["state"] = "interior"
        self.assertTrue(any("out of order" in error for error in validate_ledger(item)))

    def test_transition_handoff_fields_are_required(self):
        item = ledger(); item["transitions"][0]["fade_policy"] = ""
        self.assertTrue(any("fade_policy" in error for error in validate_ledger(item)))

    def test_transition_review_stays_open(self):
        item = ledger(); item["transitions"][0]["review_status"] = "approved"
        self.assertTrue(any("review_status" in error for error in validate_ledger(item)))

    def test_hardware_audition_stays_not_run(self):
        item = ledger(); item["hardware_audition"]["evidence"] = "headphones"
        self.assertTrue(any("NOT_RUN" in error for error in validate_ledger(item)))

    def test_exclusions_are_required(self):
        item = ledger(); item["authority_exclusions"] = []
        self.assertTrue(any("authority_exclusions" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
