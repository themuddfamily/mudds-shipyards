import copy
import unittest

try:
    from .network_damage_respawn_authority_validator import validate_rollup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_damage_respawn_authority_validator import validate_rollup


def _rollup() -> dict:
    rejection_statuses = [
        "unauthorized_source", "stale_damage_event", "stale_entity_generation",
        "recovery_not_ready", "respawn_identity_mismatch",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_damage_respawn_authority",
        "evidence_mode": "detached_contract_fixture",
        "policy_version": "network_damage_respawn_integration_v1",
        "native_claims": False,
        "uses_live_network": False,
        "simulates_health_or_physics": False,
        "audit": {
            "server_owns_damage_event_order": True,
            "server_owns_component_generation": True,
            "server_owns_recovery_gate": True,
            "server_owns_respawn_generation": True,
            "client_can_mutate_health": False,
            "client_can_mutate_recovery": False,
            "client_can_mutate_respawn": False,
            "owns_health_store": False,
            "owns_spawn_instantiation": False,
        },
        "entity": {
            "entity_id": "fighter_a", "owner_peer_id": 7, "entity_generation": 4,
            "component_generation": 1, "recovery_seconds": 1.0, "invulnerability_seconds": 0.25,
        },
        "damage": {
            "accepted": True, "status": "damage_destroyed", "server_committed": True,
            "state_after": "recovering",
            "event": {"target_entity_id": "fighter_a", "target_generation": 4, "event_sequence": 1, "damage": 100.0},
            "component_receipt": {"accepted": True, "reason": "applied", "generation": 1, "sequence": 1},
        },
        "recovery": {
            "accepted": True, "status": "recovery_ready", "state_before": "recovering",
            "state_after": "recovery_ready", "elapsed_seconds": 1.0,
        },
        "reservation": {
            "accepted": True, "status": "respawn_reserved", "target_id": "spawn_alpha",
            "respawn_token": "token_a", "state_after": "respawn_pending", "server_committed": True,
        },
        "commit": {
            "accepted": True, "status": "respawn_committed", "state_after": "active", "server_committed": True,
            "entity_generation": 5, "component_generation": 2, "target_id": "spawn_alpha", "respawn_token": "token_a",
            "component_reset": {"accepted": True, "reason": "reset", "generation": 2},
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkDamageRespawnAuthorityValidatorTest(unittest.TestCase):
    def test_accepts_server_damage_recovery_respawn_chain(self):
        self.assertEqual(validate_rollup(_rollup()), [])

    def test_rejects_damage_target_generation_mismatch(self):
        report = _rollup()
        report["damage"]["event"]["target_generation"] = 3
        self.assertTrue(any("target identity" in error for error in validate_rollup(report)))

    def test_rejects_recovery_before_configured_window(self):
        report = _rollup()
        report["recovery"]["elapsed_seconds"] = 0.5
        self.assertTrue(any("meet recovery_seconds" in error for error in validate_rollup(report)))

    def test_rejects_nonadvancing_respawn_generation(self):
        report = _rollup()
        report["commit"]["entity_generation"] = 4
        self.assertTrue(any("advance exactly once" in error for error in validate_rollup(report)))

    def test_rejects_missing_fail_closed_receipt(self):
        report = _rollup()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("respawn_identity_mismatch" in error for error in validate_rollup(report)))

    def test_rejects_client_or_live_authority_claim(self):
        report = copy.deepcopy(_rollup())
        report["audit"]["client_can_mutate_respawn"] = True
        report["uses_live_network"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("client_can_mutate_respawn" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
