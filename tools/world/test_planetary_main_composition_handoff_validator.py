import copy
import unittest

from tools.world.planetary_main_composition_handoff_validator import (
    REQUIRED_HANDOFFS,
    REQUIRED_OWNER_IDS,
    validate_handoff,
)


def handoff() -> dict:
    owners = [
        {"id": "main", "path": "Main", "role": "composition_root", "instance_count": 1, "authorities": ["composition"]},
        {"id": "game_flow", "path": "Main/GameFlow", "role": "phase_coordinator", "instance_count": 1, "authorities": ["phase"]},
        {"id": "player_controller", "path": "Main/Player", "role": "embodied_movement", "instance_count": 1, "authorities": ["player_movement"]},
        {"id": "hero_ship", "path": "Main/Fleet/Arrow", "role": "craft_simulation", "instance_count": 1, "authorities": ["ship_motion"]},
        {"id": "coordinate_frame", "path": "Main/PlanetaryCoordinateFrame", "role": "coordinate_contract", "instance_count": 1, "authorities": ["coordinate_frame"]},
        {"id": "origin_owner", "path": "Main/CommonWorldOriginRebaseOwner", "role": "origin_transaction", "instance_count": 1, "authorities": ["origin_shift"]},
        {"id": "streaming_binding", "path": "Main/EmberMoonStreamingProductionBinding", "role": "streaming_observation", "instance_count": 1, "authorities": ["streaming_observation"]},
        {"id": "surface_loop_binding", "path": "Main/EmberSurfaceLoopProductionBinding", "role": "surface_loop_handoff", "instance_count": 1, "authorities": ["surface_loop"]},
        {"id": "landing_return_contract", "path": "Main/PlanetaryLandingReturnContract", "role": "landing_return_witness", "instance_count": 1, "authorities": ["landing_return"]},
    ]
    handoffs = [
        {"name": "actor_sample", "from": "game_flow", "to": "streaming_binding", "accepted": True, "sequence": 0, "same_physics_tick": True, "mutates_source_owner": False},
        {"name": "origin_receipt", "from": "origin_owner", "to": "streaming_binding", "accepted": True, "sequence": 1, "same_physics_tick": True, "mutates_source_owner": False},
        {"name": "surface_loop_start_or_advance", "from": "game_flow", "to": "surface_loop_binding", "accepted": True, "sequence": 2, "same_physics_tick": True, "mutates_source_owner": False},
        {"name": "completion_handback", "from": "surface_loop_binding", "to": "game_flow", "accepted": True, "sequence": 3, "same_physics_tick": True, "mutates_source_owner": False},
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_main_gameflow_composition_handoff",
        "evidence_mode": "detached_contract_fixture",
        "production_wiring": False,
        "native_claims": False,
        "scene_path": "res://scenes/main.tscn",
        "owners": owners,
        "authority_owners": {
            "composition": "main", "phase": "game_flow", "player_movement": "player_controller",
            "ship_motion": "hero_ship", "coordinate_frame": "coordinate_frame", "origin_shift": "origin_owner",
            "streaming_observation": "streaming_binding", "surface_loop": "surface_loop_binding",
            "landing_return": "landing_return_contract",
        },
        "handoffs": handoffs,
        "phase_path": ["orbit_approach", "descent", "surface_flight", "landed", "on_foot", "reboarded", "takeoff", "orbit_return"],
        "lifecycle": {
            "same_main_instance_on_detach_reentry": True,
            "generation_preserved_on_detach_reentry": True,
            "actor_reparented": False,
            "stale_handoff_rejected": True,
            "composition_generation": 1,
            "main_instance_id": 1001,
        },
        "negative_guards": {
            "duplicate_mover": False,
            "duplicate_origin_owner": False,
            "duplicate_streaming_coordinator": False,
            "duplicate_planetary_travel_session": False,
            "teleport_final_approach": False,
            "reparent_retained_actor": False,
            "raw_input_in_binding": False,
        },
    }


class PlanetaryMainCompositionHandoffValidatorTest(unittest.TestCase):
    def test_bounded_handoff_is_valid(self):
        report = handoff()
        self.assertEqual(validate_handoff(report), [])
        self.assertEqual(tuple(owner["id"] for owner in report["owners"]), REQUIRED_OWNER_IDS)
        self.assertEqual(tuple(item["name"] for item in report["handoffs"]), REQUIRED_HANDOFFS)

    def test_duplicate_owner_fails(self):
        report = handoff()
        report["owners"][1]["id"] = "main"
        self.assertTrue(any("unique" in error for error in validate_handoff(report)))

    def test_second_authority_owner_fails(self):
        report = handoff()
        report["authority_owners"]["origin_shift"] = "game_flow"
        self.assertTrue(any("origin_shift" in error for error in validate_handoff(report)))

    def test_handoff_order_and_sequence_are_required(self):
        report = handoff()
        report["handoffs"][2]["sequence"] = 4
        report["handoffs"][0], report["handoffs"][1] = report["handoffs"][1], report["handoffs"][0]
        errors = validate_handoff(report)
        self.assertTrue(any("required actor-to-return sequence" in error for error in errors))
        self.assertTrue(any("increase by one" in error for error in errors))

    def test_duplicate_mover_and_teleport_are_forbidden(self):
        report = handoff()
        report["negative_guards"]["duplicate_mover"] = True
        report["negative_guards"]["teleport_final_approach"] = True
        errors = validate_handoff(report)
        self.assertTrue(any("duplicate_mover" in error for error in errors))
        self.assertTrue(any("teleport_final_approach" in error for error in errors))

    def test_detach_reentry_must_preserve_main(self):
        report = handoff()
        report["lifecycle"]["same_main_instance_on_detach_reentry"] = False
        report["lifecycle"]["actor_reparented"] = True
        errors = validate_handoff(report)
        self.assertTrue(any("same_main_instance" in error for error in errors))
        self.assertTrue(any("actor_reparented" in error for error in errors))

    def test_native_and_production_claims_are_closed(self):
        report = handoff()
        report["production_wiring"] = True
        report["native_claims"] = True
        errors = validate_handoff(report)
        self.assertTrue(any("production_wiring" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))

    def test_missing_owner_and_wrong_scene_fail(self):
        report = copy.deepcopy(handoff())
        report["owners"].pop()
        report["scene_path"] = "res://scenes/world/ember_moon.tscn"
        errors = validate_handoff(report)
        self.assertTrue(any("exact Main/GameFlow composition roster" in error for error in errors))
        self.assertTrue(any("scene_path" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
