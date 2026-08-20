import copy
import unittest

from tools.world.planetary_production_integration_gate_validator import validate_gate_record


def gate_record() -> dict:
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_production_integration_gate",
        "evidence_mode": "detached_contract_fixture",
        "source_revision": "planetary-gates-v1",
        "production_wiring": False,
        "runtime_authority": False,
        "native_claims": False,
        "human_playtest_claims": False,
        "identity": {"world_id": "ember_moon", "landing_region_id": "ember_caldera", "return_target_id": "mudds_shipyards"},
        "gates": [
            {"id": "world_identity", "status": "DETACHED_EVIDENCE", "evidence_ref": "res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md", "runtime_proven": False, "native_proven": False, "authority_mutated": False},
            {"id": "main_gameflow_composition", "status": "DETACHED_EVIDENCE", "evidence_ref": "res://tools/world/planetary_main_composition_handoff_validator.py", "runtime_proven": False, "native_proven": False, "authority_mutated": False},
            {"id": "settlement_return_loop", "status": "DETACHED_EVIDENCE", "evidence_ref": "res://tools/world/planetary_route_settlement_return_validator.py", "runtime_proven": False, "native_proven": False, "authority_mutated": False},
            {"id": "objective_reward_recovery", "status": "DETACHED_EVIDENCE", "evidence_ref": "res://scripts/world/planetary_objective_reward_recovery_contract.gd", "runtime_proven": False, "native_proven": False, "authority_mutated": False},
            {"id": "save_reentry_divergence", "status": "DETACHED_EVIDENCE", "evidence_ref": "res://tools/world/planetary_save_reentry_divergence_validator.py", "runtime_proven": False, "native_proven": False, "authority_mutated": False},
            {"id": "authority_boundary", "status": "DETACHED_EVIDENCE", "evidence_ref": "res://scripts/world/planetary_production_handoff_manifest.gd", "runtime_proven": False, "native_proven": False, "authority_mutated": False},
        ],
        "authority_owners": {
            "activity": "activity_director",
            "reward": "game_flow_reward_authority",
            "recovery": "planetary_landing_return_contract",
            "origin": "common_world_origin_rebase_owner",
            "streaming": "planetary_origin_stream_contract",
            "save": "planetary_save_session_contract",
        },
        "composition_limits": {
            "main_instance_count": 1,
            "game_flow_instance_count": 1,
            "origin_owner_count": 1,
            "streaming_binding_count": 1,
            "surface_loop_binding_count": 1,
            "reward_store_count": 1,
            "active_location_count": 1,
            "travel_session_count": 0,
            "duplicate_mover": False,
            "duplicate_origin_owner": False,
            "actor_reparented": False,
            "final_approach_teleport": False,
        },
        "open_gates": [
            {"id": "runtime_main_composition", "status": "OPEN", "completion_proven": False, "reason": "Main/GameFlow production wiring remains open"},
            {"id": "packaged_native_windows", "status": "OPEN", "completion_proven": False, "reason": "native Windows package review remains open"},
            {"id": "human_playthrough", "status": "OPEN", "completion_proven": False, "reason": "human orbit-to-surface route remains open"},
            {"id": "long_session_orbit_surface", "status": "OPEN", "completion_proven": False, "reason": "repeated long-session route remains open"},
        ],
    }


class PlanetaryProductionIntegrationGateValidatorTest(unittest.TestCase):
    def test_detached_gate_record_is_valid(self):
        self.assertEqual(validate_gate_record(gate_record()), [])

    def test_gate_order_is_required(self):
        item = gate_record(); item["gates"][0], item["gates"][1] = item["gates"][1], item["gates"][0]
        self.assertTrue(any("ordered planetary integration" in error for error in validate_gate_record(item)))

    def test_missing_evidence_reference_fails(self):
        item = gate_record(); item["gates"][2]["evidence_ref"] = ""
        self.assertTrue(any("evidence_ref" in error for error in validate_gate_record(item)))

    def test_duplicate_authority_owner_fails(self):
        item = gate_record(); item["authority_owners"]["save"] = "activity_director"
        self.assertTrue(any("duplicate owners" in error for error in validate_gate_record(item)))

    def test_duplicate_composition_owner_fails(self):
        item = gate_record(); item["composition_limits"]["origin_owner_count"] = 2
        self.assertTrue(any("origin_owner_count" in error for error in validate_gate_record(item)))

    def test_production_claim_is_rejected(self):
        item = gate_record(); item["production_wiring"] = True; item["native_claims"] = True
        errors = validate_gate_record(item)
        self.assertTrue(any("production_wiring" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))

    def test_open_gate_cannot_claim_completion(self):
        item = copy.deepcopy(gate_record()); item["open_gates"][1]["completion_proven"] = True
        self.assertTrue(any("completion_proven" in error for error in validate_gate_record(item)))

    def test_runtime_authority_flag_fails_closed(self):
        item = gate_record(); item["runtime_authority"] = True
        self.assertTrue(any("runtime_authority" in error for error in validate_gate_record(item)))


if __name__ == "__main__":
    unittest.main()
