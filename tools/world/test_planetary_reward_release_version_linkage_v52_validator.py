import copy
import unittest

from tools.world.test_planetary_reward_release_version_authority_reconciliation_v51_validator import evidence as _v51_evidence
from tools.world.planetary_reward_release_version_linkage_v52_validator import _authority_digest, validate_release_version_linkage


def _replace_version(value):
    if isinstance(value, dict):
        return {key: _replace_version(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_replace_version(item) for item in value]
    if isinstance(value, str):
        return value.replace("v51", "v52")
    return value


def evidence() -> dict:
    item = _replace_version(copy.deepcopy(_v51_evidence()))
    item["schema_version"] = 52
    item["evidence_scope"] = "planetary_reward_release_version_linkage_v52"
    item["evidence_mode"] = "detached_reward_release_version_linkage_v52"
    item["authority"]["authority_scope"] = "planetary_reward_release_version_linkage"
    item["authority_reconciliation"]["schema_version"] = 52
    for record in item["records"]:
        record["leaf_id"] = record["leaf_id"].replace("reward_release_version_authority_leaf_v52", "reward_release_version_linkage_leaf_v52")
    item["release_version_linkage_digest_sha256"] = _authority_digest(item["identity"], item["authority"], item["authority_link"], item["authority_reconciliation"], item["records"])
    item.pop("release_version_authority_digest_sha256", None)
    return item


class PlanetaryRewardReleaseVersionLinkageV52ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_release_version_linkage(evidence()), [])

    def test_schema_version_is_v52(self):
        item = evidence()
        item["schema_version"] = 51
        self.assertTrue(any("schema_version must be 52" in error for error in validate_release_version_linkage(item)))

    def test_link_version_is_required(self):
        item = evidence()
        item["authority_link"]["authority_version"] = "authority_v51"
        self.assertTrue(any("authority_link.authority_version must be authority_v52" in error for error in validate_release_version_linkage(item)))

    def test_reconciliation_binds_linkage_manifest(self):
        item = evidence()
        item["authority_reconciliation"]["manifest_version"] = "v51"
        self.assertTrue(any("authority_reconciliation.manifest_version must be v52" in error for error in validate_release_version_linkage(item)))

    def test_digest_binds_authority(self):
        item = evidence()
        item["authority"]["reward_store_id"] = "other_store"
        self.assertTrue(any("release_version_linkage_digest_sha256 does not match canonical v52 payload" in error for error in validate_release_version_linkage(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_release_version_linkage(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_release_version_linkage(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_release_version_linkage(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
