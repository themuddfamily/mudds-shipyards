import copy
import unittest

try:
    from .network_projectile_boarding_authority_validator import validate_rollup
except ImportError:  # Direct invocation from the tools/network directory.
    from network_projectile_boarding_authority_validator import validate_rollup


def _rollup() -> dict:
    rejection_statuses = [
        "spoofed_peer", "stale_ship_generation", "stale_frame_generation",
        "role_mismatch", "stale_sequence", "seat_occupied",
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "network_projectile_boarding_authority",
        "evidence_mode": "detached_contract_fixture",
        "projectile_policy": "network_projectile_damage_authority_v1",
        "boarding_policy": "network_boarding_occupancy_authority_v1",
        "native_claims": False,
        "uses_live_network": False,
        "simulates_physics": False,
        "projectile_audit": {
            "server_owns_projectile_spawn": True, "server_owns_projectile_motion": True,
            "server_owns_damage_amount": True, "server_owns_health_store": False,
            "client_can_mutate_projectiles": False,
        },
        "boarding_audit": {
            "server_owns_boarding": True, "server_owns_seat_occupancy": True,
            "server_owns_frame_binding": True, "client_can_mutate_occupancy": False,
            "one_seat_per_avatar": True, "one_avatar_per_seat": True,
            "owns_movement": False, "owns_ship_simulation": False,
        },
        "projectile_spawn": {
            "accepted": True, "status": "spawned", "server_committed": True,
            "projectile_id": "projectile_1", "source_entity_id": "fighter_a",
            "owner_peer_id": 7, "source_generation": 2, "projectile_generation": 1,
        },
        "projectile_impact": {
            "accepted": True, "status": "damage_event", "server_committed": True,
            "projectile_id": "projectile_1", "source_entity_id": "fighter_a",
            "source_generation": 2, "target_entity_id": "target_a", "target_generation": 4,
            "event_sequence": 1, "damage": 18.0,
        },
        "damage_commit": {
            "accepted": True, "status": "damage_committed", "server_committed": True,
            "projectile_removed": True, "projectile_id": "projectile_1",
            "applied_damage": 18.0, "remaining_health": 82.0,
        },
        "boarding": {
            "accepted": True, "status": "boarded", "server_committed": True,
            "source_peer_id": 99, "authority_peer_id": 99, "peer_id": 7,
            "avatar_id": "avatar_a", "ship_id": "jovian_a", "ship_generation": 4,
            "frame_id": "flight_frame", "frame_generation": 7, "seat_id": "jovian_pilot",
            "seat_generation": 3, "role": "pilot", "claim_sequence": 1,
        },
        "rejections": [
            {"status": status, "accepted": False, "server_rejected": True}
            for status in rejection_statuses
        ],
    }


class NetworkProjectileBoardingAuthorityValidatorTest(unittest.TestCase):
    def test_accepts_projectile_damage_and_boarding_chain(self):
        self.assertEqual(validate_rollup(_rollup()), [])

    def test_rejects_projectile_source_mismatch(self):
        report = _rollup()
        report["projectile_impact"]["source_generation"] = 1
        self.assertTrue(any("source identity" in error for error in validate_rollup(report)))

    def test_rejects_damage_above_server_projectile_amount(self):
        report = _rollup()
        report["damage_commit"]["applied_damage"] = 19
        self.assertTrue(any("cannot exceed" in error for error in validate_rollup(report)))

    def test_rejects_boarding_frame_or_role_boundary(self):
        report = _rollup()
        report["boarding"]["frame_generation"] = 0
        report["boarding"]["role"] = "captain"
        errors = validate_rollup(report)
        self.assertTrue(any("frame_generation" in error for error in errors))
        self.assertTrue(any("role must be supported" in error for error in errors))

    def test_rejects_missing_occupancy_fence(self):
        report = _rollup()
        report["rejections"] = report["rejections"][:-1]
        self.assertTrue(any("seat_occupied" in error for error in validate_rollup(report)))

    def test_rejects_client_or_live_authority_claim(self):
        report = copy.deepcopy(_rollup())
        report["boarding_audit"]["client_can_mutate_occupancy"] = True
        report["uses_live_network"] = True
        errors = validate_rollup(report)
        self.assertTrue(any("client_can_mutate_occupancy" in error for error in errors))
        self.assertTrue(any("uses_live_network" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
