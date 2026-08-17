#!/usr/bin/env python3
"""Focused fixture tests for graphical_harness_inventory.py."""

import copy
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import graphical_harness_inventory as inventory  # noqa: E402


def entry(script="tests/capture_alpha.gd", harness_id="capture-alpha"):
    return {
        "id": harness_id,
        "script": script,
        "classification": "required",
        "output": {
            "root": "res://artifacts/alpha",
            "contract": "png_set",
        },
        "render": {
            "required": True,
            "profile": "project_forward_plus",
        },
        "review_status": "pending",
        "source_freeze": {
            "status": "pending",
            "manifest_sha256": None,
        },
        "image_inventory": {
            "status": "pending",
            "expected_png_count": 1,
            "inventory_sha256": None,
        },
        "human_review": {
            "readiness": "pending",
            "original_resolution_required": True,
            "evidence_reference": None,
        },
    }


class FixtureRepository:
    def __init__(self):
        self._temporary = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary.name)
        (self.root / "tests").mkdir()
        (self.root / "tools").mkdir()
        self.write("tests/capture_alpha.gd", "extends SceneTree\n")
        self.registry = self.root / "registry.json"

    def write(self, relative, contents):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    def register(self, entries):
        self.registry.write_text(
            json.dumps({"schema_version": 1, "harnesses": entries}),
            encoding="utf-8",
        )

    def validate(self):
        return inventory._validate_inventory(
            self.root,
            self.registry,
            mandatory_required_ids=frozenset(("capture-alpha",)),
        )

    def readiness(self):
        return inventory._evaluate_required_readiness(
            self.root,
            self.registry,
            mandatory_image_counts={"capture-alpha": 1},
        )

    def close(self):
        self._temporary.cleanup()


class GraphicalHarnessInventoryTests(unittest.TestCase):
    def setUp(self):
        self.fixture = FixtureRepository()

    def tearDown(self):
        self.fixture.close()

    def test_valid_fixture_is_deterministic_and_detached(self):
        registered = entry()
        self.fixture.register([registered])
        first = self.fixture.validate()
        registered["id"] = "mutated-after-write"
        second = self.fixture.validate()
        self.assertTrue(first.valid, first.errors)
        self.assertEqual(first, second)
        self.assertEqual(first.discovered, ("tests/capture_alpha.gd",))
        detached = first.to_dict()
        detached["discovered"].append("mutated")
        self.assertEqual(first.discovered, ("tests/capture_alpha.gd",))

    def test_discovery_includes_render_readback_and_excludes_png_processor(self):
        renderer = (
            "extends SceneTree\n"
            "func go():\n"
            " await RenderingServer.frame_post_draw\n"
            " get_viewport().get_texture().get_image().save_png('/tmp/frame.png')\n"
        )
        processor = "extends SceneTree\nfunc go(image):\n image.save_png('/tmp/map.png')\n"
        self.fixture.write("tools/visual_probe.gd", renderer)
        self.fixture.write("tools/generate_maps.gd", processor)
        second = entry("tools/visual_probe.gd", "visual-probe")
        second["classification"] = "historical"
        second["output"] = {"root": "/tmp/frame.png", "contract": "png"}
        second["review_status"] = "reviewed_historical"
        self.fixture.register([entry(), second])
        result = self.fixture.validate()
        self.assertTrue(result.valid, result.errors)
        self.assertEqual(
            result.discovered,
            ("tests/capture_alpha.gd", "tools/visual_probe.gd"),
        )

    def test_unregistered_and_missing_scripts_fail_closed(self):
        self.fixture.write("tests/capture_beta.gd", "extends SceneTree\n")
        missing = entry("tests/capture_missing.gd", "capture-missing")
        self.fixture.register([entry(), missing])
        result = self.fixture.validate()
        self.assertFalse(result.valid)
        self.assertIn(
            "unregistered graphical harness: tests/capture_beta.gd", result.errors
        )
        self.assertIn(
            "registered harness script is missing: tests/capture_missing.gd",
            result.errors,
        )
        self.assertIn(
            "registered script is not a discovered graphical harness: tests/capture_missing.gd",
            result.errors,
        )

    def test_duplicate_ids_scripts_and_json_keys_fail(self):
        duplicate = copy.deepcopy(entry())
        duplicate["review_status"] = "reviewed_current"
        self.fixture.register([entry(), duplicate])
        result = self.fixture.validate()
        self.assertTrue(any("duplicate harness id" in error for error in result.errors))
        self.assertTrue(any("duplicate harness script" in error for error in result.errors))
        self.fixture.registry.write_text(
            '{"schema_version":1,"schema_version":1,"harnesses":[]}',
            encoding="utf-8",
        )
        result = self.fixture.validate()
        self.assertTrue(any("duplicate JSON key" in error for error in result.errors))

    def test_unsafe_script_and_output_paths_fail(self):
        unsafe = entry("tests/../capture_alpha.gd", "unsafe-script")
        unsafe["output"]["root"] = "res://scenes/screenshots"
        self.fixture.register([unsafe])
        result = self.fixture.validate()
        self.assertTrue(any("unsafe script path" in error for error in result.errors))
        self.assertTrue(any("unsafe output root" in error for error in result.errors))

    def test_invalid_classification_review_and_render_contract_fail(self):
        malformed = entry()
        malformed["classification"] = "optional"
        malformed["review_status"] = "approved"
        malformed["render"] = {"required": False, "profile": "vulkan"}
        malformed["output"]["contract"] = "jpeg"
        self.fixture.register([malformed])
        result = self.fixture.validate()
        combined = "\n".join(result.errors)
        self.assertIn("classification must be one of", combined)
        self.assertIn("review_status must be one of", combined)
        self.assertIn("render.required must be true", combined)
        self.assertIn("render.profile must be one of", combined)
        self.assertIn("output.contract must be one of", combined)

    def test_unknown_fields_and_incompatible_status_fail(self):
        malformed = entry()
        malformed["classification"] = "deprecated"
        malformed["review_status"] = "pending"
        malformed["surprise"] = True
        self.fixture.register([malformed])
        result = self.fixture.validate()
        self.assertTrue(any("unknown field 'surprise'" in error for error in result.errors))
        self.assertTrue(any("must have review_status 'retired'" in error for error in result.errors))

    def test_mandatory_required_id_cannot_be_demoted_or_removed(self):
        demoted = entry()
        demoted["classification"] = "historical"
        demoted["review_status"] = "reviewed_historical"
        self.fixture.register([demoted])
        result = self.fixture.validate()
        self.assertIn(
            "mandatory required harness was demoted: capture-alpha", result.errors
        )
        self.fixture.register([])
        result = self.fixture.validate()
        self.assertIn(
            "mandatory required harness id is missing: capture-alpha", result.errors
        )

    def test_checked_in_mandatory_policy_rejects_demotion_missing_and_count_drift(self):
        repository = Path(__file__).resolve().parents[2]
        checked_path = repository / inventory.DEFAULT_REGISTRY
        checked = json.loads(checked_path.read_text(encoding="utf-8"))
        target_id = "capture-player-motion"
        with tempfile.TemporaryDirectory() as temporary:
            registry_path = Path(temporary) / "registry.json"
            demoted = copy.deepcopy(checked)
            demoted_row = next(
                row for row in demoted["harnesses"] if row["id"] == target_id
            )
            demoted_row["classification"] = "historical"
            demoted_row["review_status"] = "pending"
            registry_path.write_text(json.dumps(demoted), encoding="utf-8")
            result = inventory.validate_inventory(repository, registry_path)
            self.assertIn(
                f"mandatory required harness was demoted: {target_id}", result.errors
            )

            missing = copy.deepcopy(checked)
            missing["harnesses"] = [
                row for row in missing["harnesses"] if row["id"] != target_id
            ]
            registry_path.write_text(json.dumps(missing), encoding="utf-8")
            result = inventory.validate_inventory(repository, registry_path)
            self.assertIn(
                f"mandatory required harness id is missing: {target_id}", result.errors
            )

            count_drift = copy.deepcopy(checked)
            drifted_row = next(
                row for row in count_drift["harnesses"] if row["id"] == target_id
            )
            drifted_row["image_inventory"]["expected_png_count"] = 8
            registry_path.write_text(json.dumps(count_drift), encoding="utf-8")
            result = inventory.validate_inventory(repository, registry_path)
            self.assertTrue(
                any(
                    error.startswith(
                        f"mandatory required harness image count drifted: {target_id}"
                    )
                    for error in result.errors
                )
            )

    def test_all_enum_fields_reject_unhashable_types_without_crashing(self):
        mutations = (
            ("classification", lambda row, value: row.__setitem__("classification", value)),
            ("review_status", lambda row, value: row.__setitem__("review_status", value)),
            (
                "output.contract",
                lambda row, value: row["output"].__setitem__("contract", value),
            ),
            (
                "render.profile",
                lambda row, value: row["render"].__setitem__("profile", value),
            ),
            (
                "source_freeze.status",
                lambda row, value: row["source_freeze"].__setitem__("status", value),
            ),
            (
                "image_inventory.status",
                lambda row, value: row["image_inventory"].__setitem__("status", value),
            ),
            (
                "human_review.readiness",
                lambda row, value: row["human_review"].__setitem__("readiness", value),
            ),
        )
        for label, mutate in mutations:
            for invalid in ([], {}, True, 1.0):
                with self.subTest(label=label, invalid=repr(invalid)):
                    malformed = entry()
                    mutate(malformed, invalid)
                    self.fixture.register([malformed])
                    result = self.fixture.validate()
                    self.assertFalse(result.valid)
                    self.assertTrue(any(label in error for error in result.errors))

    def test_schema_and_evidence_scalar_types_are_exact(self):
        for malformed_schema in (True, 1.0, [], {}):
            with self.subTest(schema=repr(malformed_schema)):
                self.fixture.registry.write_text(
                    json.dumps(
                        {"schema_version": malformed_schema, "harnesses": [entry()]}
                    ),
                    encoding="utf-8",
                )
                result = self.fixture.validate()
                self.assertIn(
                    "registry.schema_version must be the exact integer 1",
                    result.errors,
                )
        malformed = entry()
        malformed["source_freeze"] = {
            "status": "verified",
            "manifest_sha256": True,
        }
        malformed["image_inventory"] = {
            "status": "verified",
            "expected_png_count": True,
            "inventory_sha256": 1.0,
        }
        malformed["human_review"] = {
            "readiness": "reviewed",
            "original_resolution_required": 1,
            "evidence_reference": [],
        }
        self.fixture.register([malformed])
        result = self.fixture.validate()
        combined = "\n".join(result.errors)
        self.assertIn("manifest_sha256 must be a SHA-256", combined)
        self.assertIn("expected_png_count must be null or a positive exact integer", combined)
        self.assertIn("inventory_sha256 must be a SHA-256", combined)
        self.assertIn("original_resolution_required must be a boolean", combined)
        self.assertIn("evidence_reference must be null or bounded printable text", combined)

    def test_review_readiness_requires_machine_evidence(self):
        premature = entry()
        premature["human_review"]["readiness"] = "ready"
        self.fixture.register([premature])
        result = self.fixture.validate()
        self.assertTrue(
            any("cannot be ready before source and image evidence" in error for error in result.errors)
        )

    def test_required_readiness_reports_exact_pending_stage_blockers(self):
        self.fixture.register([entry()])
        first = self.fixture.readiness()
        second = self.fixture.readiness()
        self.assertEqual(first, second)
        self.assertTrue(first.inventory_valid, first.inventory_errors)
        self.assertFalse(first.ready)
        self.assertEqual(first.blocker_count, 3)
        harness = first.harnesses[0]
        self.assertEqual(harness.harness_id, "capture-alpha")
        self.assertEqual(harness.declared_png_count, 1)
        self.assertEqual(
            tuple((blocker.stage, blocker.reason) for blocker in harness.blockers),
            (
                ("source_freeze", "status_pending"),
                ("declared_image_inventory", "status_pending"),
                ("original_resolution_human_review", "readiness_pending"),
            ),
        )
        detached = first.to_dict()
        detached["harnesses"][0]["blockers"].clear()
        self.assertEqual(first.blocker_count, 3)
        self.assertFalse(detached["render_execution"])
        self.assertFalse(detached["human_review_performed"])

    def test_required_readiness_passes_only_complete_declared_evidence(self):
        complete = entry()
        complete["source_freeze"] = {
            "status": "verified",
            "manifest_sha256": "a" * 64,
        }
        complete["image_inventory"] = {
            "status": "verified",
            "expected_png_count": 1,
            "inventory_sha256": "b" * 64,
        }
        complete["human_review"] = {
            "readiness": "reviewed",
            "original_resolution_required": True,
            "evidence_reference": "review/alpha-original-resolution",
        }
        self.fixture.register([complete])
        result = self.fixture.readiness()
        self.assertTrue(result.inventory_valid, result.inventory_errors)
        self.assertTrue(result.ready)
        self.assertEqual(result.blocker_count, 0)
        self.assertTrue(result.harnesses[0].ready)

    def test_ready_for_review_is_not_a_human_review_claim(self):
        waiting = entry()
        waiting["source_freeze"] = {
            "status": "verified",
            "manifest_sha256": "a" * 64,
        }
        waiting["image_inventory"] = {
            "status": "verified",
            "expected_png_count": 1,
            "inventory_sha256": "b" * 64,
        }
        waiting["human_review"]["readiness"] = "ready"
        self.fixture.register([waiting])
        result = self.fixture.readiness()
        self.assertTrue(result.inventory_valid, result.inventory_errors)
        self.assertFalse(result.ready)
        self.assertEqual(
            tuple(
                (blocker.stage, blocker.reason)
                for blocker in result.harnesses[0].blockers
            ),
            (
                (
                    "original_resolution_human_review",
                    "awaiting_original_resolution_human_review",
                ),
            ),
        )

    def test_missing_required_row_fails_closed_in_all_three_stages(self):
        self.fixture.register([])
        result = self.fixture.readiness()
        self.assertFalse(result.inventory_valid)
        self.assertFalse(result.ready)
        self.assertEqual(result.blocker_count, 3)
        self.assertEqual(
            tuple(blocker.reason for blocker in result.harnesses[0].blockers),
            ("harness_missing", "harness_missing", "harness_missing"),
        )

    def test_required_readiness_type_malformation_is_structured_not_exception(self):
        malformed = entry()
        malformed["source_freeze"] = []
        malformed["image_inventory"] = True
        malformed["human_review"] = "reviewed"
        self.fixture.register([malformed])
        result = self.fixture.readiness()
        self.assertFalse(result.inventory_valid)
        self.assertFalse(result.ready)
        self.assertEqual(
            tuple((blocker.stage, blocker.reason) for blocker in result.harnesses[0].blockers),
            (
                ("source_freeze", "status_invalid"),
                ("declared_image_inventory", "status_invalid"),
                (
                    "original_resolution_human_review",
                    "original_resolution_not_required",
                ),
            ),
        )

    def test_checked_in_required_report_is_exact_and_strict_pending_fails(self):
        repository = Path(__file__).resolve().parents[2]
        registry_path = repository / inventory.DEFAULT_REGISTRY
        first = inventory.evaluate_required_readiness(repository, registry_path)
        second = inventory.evaluate_required_readiness(repository, registry_path)
        self.assertEqual(first, second)
        self.assertTrue(first.inventory_valid, "\n".join(first.inventory_errors))
        self.assertFalse(first.ready)
        self.assertEqual(len(first.harnesses), 12)
        self.assertEqual(first.blocker_count, 36)
        self.assertEqual(
            tuple(harness.harness_id for harness in first.harnesses),
            tuple(sorted(inventory.MANDATORY_REQUIRED_IDS)),
        )
        for harness in first.harnesses:
            self.assertEqual(len(harness.blockers), 3)
            self.assertEqual(
                harness.declared_png_count,
                inventory.MANDATORY_REQUIRED_IMAGE_COUNTS[harness.harness_id],
            )

        report_output = io.StringIO()
        with redirect_stdout(report_output):
            report_exit = inventory.main(
                [
                    "--root",
                    str(repository),
                    "--registry",
                    str(registry_path),
                    "--required-readiness",
                    "--json",
                ]
            )
        strict_output = io.StringIO()
        with redirect_stdout(strict_output):
            strict_exit = inventory.main(
                [
                    "--root",
                    str(repository),
                    "--registry",
                    str(registry_path),
                    "--required-readiness",
                    "--strict",
                    "--json",
                ]
            )
        self.assertEqual(report_exit, 0)
        self.assertEqual(strict_exit, 1)
        self.assertEqual(report_output.getvalue(), strict_output.getvalue())
        payload = json.loads(report_output.getvalue())
        self.assertFalse(payload["ready"])
        self.assertFalse(payload["render_execution"])
        self.assertFalse(payload["human_review_performed"])

    def test_checked_in_registry_covers_live_discovery(self):
        repository = Path(__file__).resolve().parents[2]
        result = inventory.validate_inventory(
            repository, repository / inventory.DEFAULT_REGISTRY
        )
        self.assertTrue(result.valid, "\n".join(result.errors))
        self.assertEqual(len(result.discovered), len(result.registered))


if __name__ == "__main__":
    unittest.main()
