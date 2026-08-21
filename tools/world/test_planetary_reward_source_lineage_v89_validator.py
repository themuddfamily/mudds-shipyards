import copy
import unittest

from tools.world.test_planetary_reward_consistency_state_v88_validator import evidence as _v88_evidence
from tools.world.planetary_reward_source_lineage_v89_validator import _authority_digest, validate_source_lineage


def _replace_version(value):
    if isinstance(value, dict):
        return {key: _replace_version(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_replace_version(item) for item in value]
    if isinstance(value, str):
        return value.replace("v88", "v89")
    return value


def evidence() -> dict:
    item = _replace_version(copy.deepcopy(_v88_evidence()))
    item["schema_version"] = 89
    item["evidence_scope"] = "planetary_reward_source_lineage_v89"
    item["evidence_mode"] = "detached_reward_source_lineage_v89"
    item["authority"]["authority_scope"] = "planetary_reward_source_lineage"
    item["authority_reconciliation"]["schema_version"] = 89
    for record in item["records"]:
        record["leaf_id"] = f"{record['activity_id']}_reward_source_lineage_leaf_v89"
    item["source_lineage_digest_sha256"] = _authority_digest(item["identity"], item["authority"], item["authority_link"], item["authority_reconciliation"], item["records"])
    item.pop("consistency_state_digest_sha256", None)
    return item


class PlanetaryRewardSourceLineageV89ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_source_lineage(evidence()), [])

    def test_schema_version_is_v89(self):
        item = evidence()
        item["schema_version"] = 88
        self.assertTrue(any("schema_version must be 89" in error for error in validate_source_lineage(item)))

    def test_source_link_version_is_required(self):
        item = evidence()
        item["authority_link"]["authority_version"] = "authority_v88"
        self.assertTrue(any("authority_link.authority_version must be authority_v89" in error for error in validate_source_lineage(item)))

    def test_reconciliation_binds_source_manifest(self):
        item = evidence()
        item["authority_reconciliation"]["manifest_version"] = "v88"
        self.assertTrue(any("authority_reconciliation.manifest_version must be v89" in error for error in validate_source_lineage(item)))

    def test_digest_binds_authority(self):
        item = evidence()
        item["authority"]["reward_store_id"] = "other_store"
        self.assertTrue(any("source_lineage_digest_sha256 does not match canonical v89 payload" in error for error in validate_source_lineage(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_source_lineage(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_source_lineage(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_source_lineage(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
