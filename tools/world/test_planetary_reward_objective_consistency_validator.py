#!/usr/bin/env python3
"""Tests for the consolidated planetary reward/objective consistency validator.

The fixture beside this file is the exact document the retired v1019 module
accepted, captured before that 901-module chain was deleted, so these tests
pin the same contract against a real artifact rather than a hand-written one.
"""

import copy
import json
import unittest
from pathlib import Path

from tools.world.planetary_reward_objective_consistency_validator import (
    SUPPORTED_VERSIONS,
    document_version,
    validate_objective_consistency,
)

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "planetary_reward_objective_consistency_v1019.json"


def evidence() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


class PlanetaryRewardObjectiveConsistencyValidatorTest(unittest.TestCase):
    def test_captured_v1019_document_is_valid(self):
        self.assertEqual(validate_objective_consistency(evidence()), [])

    def test_version_is_read_from_the_document(self):
        self.assertEqual(document_version(evidence()), 1019)
        self.assertIn(1019, SUPPORTED_VERSIONS)
        self.assertIn(119, SUPPORTED_VERSIONS)
        self.assertNotIn(118, SUPPORTED_VERSIONS)
        self.assertNotIn(1020, SUPPORTED_VERSIONS)

    def test_version_outside_the_range_is_refused(self):
        item = evidence()
        item["schema_version"] = 1020
        self.assertEqual(
            validate_objective_consistency(item),
            ["manifest.schema_version must be an integer between 119 and 1019"],
        )

    def test_pinned_version_must_match_the_document(self):
        errors = validate_objective_consistency(evidence(), schema_version=1018)
        self.assertTrue(any("schema_version must be 1018" in error for error in errors))

    def test_world_is_pinned(self):
        item = evidence()
        item["world_id"] = "mars"
        self.assertIn("manifest.world_id must be ember_moon", validate_objective_consistency(item))

    def test_digest_must_match_the_canonical_payload(self):
        item = evidence()
        item["objective_consistency_digest_sha256"] = "0" * 64
        errors = validate_objective_consistency(item)
        self.assertTrue(any("does not match canonical v1019 payload" in error for error in errors))

    def test_digest_must_be_lowercase_hex(self):
        item = evidence()
        item["objective_consistency_digest_sha256"] = "not-a-digest"
        errors = validate_objective_consistency(item)
        self.assertTrue(any("lowercase SHA-256" in error for error in errors))

    def test_record_leaf_ids_are_deterministic(self):
        item = evidence()
        item["records"][0]["leaf_id"] = "hand-written"
        errors = validate_objective_consistency(item)
        self.assertTrue(any("records[0].leaf_id must be deterministic" in error for error in errors))

    def test_authority_link_version_is_bound(self):
        item = evidence()
        item["authority_link"]["authority_version"] = "authority_v1"
        errors = validate_objective_consistency(item)
        self.assertTrue(any("authority_link.authority_version" in error for error in errors))

    def test_reconciliation_is_bound_to_the_manifest(self):
        item = evidence()
        item["authority_reconciliation"]["manifest_id"] = "other"
        errors = validate_objective_consistency(item)
        self.assertTrue(any("authority_reconciliation.manifest_id" in error for error in errors))

    def test_a_document_of_an_earlier_version_validates_on_its_own_terms(self):
        # Every retired module was this contract with the version renamed, so a
        # renamed copy of the captured document must validate at that version.
        item = json.loads(
            json.dumps(evidence()).replace("v1019", "v400").replace('"schema_version": 1019', '"schema_version": 400')
        )
        item["schema_version"] = 400
        item["authority_reconciliation"]["schema_version"] = 400
        from tools.world.planetary_reward_objective_consistency_validator import _authority_digest

        item["objective_consistency_digest_sha256"] = _authority_digest(
            400,
            item["identity"],
            item["authority"],
            item["authority_link"],
            item["authority_reconciliation"],
            item["records"],
        )
        self.assertEqual(validate_objective_consistency(item), [])

    def test_non_object_is_refused(self):
        self.assertEqual(validate_objective_consistency([]), ["manifest must be an object"])


if __name__ == "__main__":
    unittest.main()
