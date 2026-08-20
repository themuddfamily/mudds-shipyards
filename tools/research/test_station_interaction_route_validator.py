import tempfile
import unittest
from pathlib import Path

from tools.research.station_interaction_route_validator import validate_document


ROOT = Path(__file__).resolve().parents[2]
TOPOLOGY = ROOT / "docs/research/STATION_TOPOLOGY.md"


class StationInteractionRouteValidatorTests(unittest.TestCase):
    def test_repository_evidence_is_consistent_and_bounded(self):
        self.assertEqual(validate_document(TOPOLOGY), [])

    def test_connection_marker_drift_is_rejected(self):
        text = TOPOLOGY.read_text(encoding="utf-8")
        text = text.replace(
            "| `hub-aft-junction` | `ExposedDockLattice/AftModuleConnector` | `aft-junction-stack` | `approach` |",
            "| `hub-aft-junction` | `ExposedDockLattice/AftModuleConnector` | `aft-junction-stack` | `operations-room` |",
            1,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "topology.md"
            path.write_text(text, encoding="utf-8")
            errors = validate_document(path)
        self.assertTrue(any("does not use the module connection marker" in error for error in errors))

    def test_deferred_landmark_cannot_claim_live_connection(self):
        text = TOPOLOGY.read_text(encoding="utf-8")
        text = text.replace(
            "| Aft VIP access | `aft-junction-stack` | `vip-landmark` |",
            "| Aft VIP access | `aft-junction-stack` | `approach` |",
            1,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "topology.md"
            path.write_text(text, encoding="utf-8")
            errors = validate_document(path)
        self.assertTrue(any("claims a connection marker" in error for error in errors))

    def test_dead_end_without_landmark_and_stale_total_fail_closed(self):
        text = TOPOLOGY.read_text(encoding="utf-8")
        text = text.replace("| `route_marker_count` | 49 |", "| `route_marker_count` | 48 |", 1)
        text = text.replace(
            "| `observation-logistics-spur` | `connector-midpoint`, `cross-landing`, `far-return`, `logistics-pad`, `observation-pad`, `origin` | `origin` | `logistics-pad`, `observation-pad` |",
            "| `observation-logistics-spur` | `connector-midpoint`, `cross-landing`, `far-return`, `logistics-pad`, `observation-pad`, `origin` | `origin` | `logistics-pad` |",
            1,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "topology.md"
            path.write_text(text, encoding="utf-8")
            errors = validate_document(path)
        self.assertTrue(any("not marked dead-end/deferred" in error for error in errors))
        self.assertTrue(any("route_marker_count total is 48" in error for error in errors))

    def test_walkability_and_topology_boundaries_are_required(self):
        text = TOPOLOGY.read_text(encoding="utf-8")
        text = text.replace("The registry proves declared topology only.", "The registry reports the topology.", 1)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "topology.md"
            path.write_text(text, encoding="utf-8")
            errors = validate_document(path)
        self.assertTrue(any("does not prove physical reachability" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
