"""Focused tests for combat/station routing evidence rollup."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import combat_station_routing_evidence_validator as validator  # noqa: E402


def route(family: str, bus: str) -> dict:
    return {"family": family, "bus": bus, "source_seam": f"scripts/audio/{family}.gd", "route_evidence": f"artifacts/audio/{family}-route.json", "presentation_only": True, "authority_exclusions": ["gameplay_damage", "gameplay_phase"]}


def rollup() -> dict:
    return {"schema": "combat_station_routing_evidence_v1", "revision": "a" * 40, "routing_owner": "audio-presentation-owner", "evidence_bundle": "artifacts/audio/routing-rollup.json", "native_audition": "OPEN", "boundary_note": "Routing evidence does not establish native balance or audibility.", "claim": "AUTOMATED_ROUTING_ONLY", "routes": [route("station_music", "Music"), route("station_machinery", "Ambience"), route("combat_cues", "SFX"), route("planetary_surface", "Ambience")]}


class CombatStationRoutingEvidenceTests(unittest.TestCase):
    def test_complete_routing_rollup(self):
        self.assertEqual(validator.validate_rollup(rollup()), [])

    def test_family_bus_mismatch_is_rejected(self):
        value = copy.deepcopy(rollup())
        value["routes"][2]["bus"] = "Music"
        errors = validator.validate_rollup(value)
        self.assertIn("routes[2].bus must be SFX for combat_cues", errors)

    def test_route_authority_and_presentation_flags_are_required(self):
        value = copy.deepcopy(rollup())
        value["routes"][0]["presentation_only"] = False
        value["routes"][0]["authority_exclusions"] = ["gameplay_damage"]
        errors = validator.validate_rollup(value)
        self.assertIn("routes[0].presentation_only must be true", errors)
        self.assertIn("routes[0].authority_exclusions must include gameplay_damage and gameplay_phase", errors)

    def test_native_audition_remains_open(self):
        value = copy.deepcopy(rollup())
        value["native_audition"] = "PASS"
        errors = validator.validate_rollup(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
