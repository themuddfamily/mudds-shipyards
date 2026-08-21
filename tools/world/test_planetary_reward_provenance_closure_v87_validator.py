import copy
import unittest

from tools.world.test_planetary_reward_audit_closure_v86_validator import evidence as _v86_evidence
from tools.world.planetary_reward_provenance_closure_v87_validator import _authority_digest, validate_provenance_closure


def _replace_version(value):
    if isinstance(value, dict):
        return {key: _replace_version(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_replace_version(item) for item in value]
    if isinstance(value, str):
        return value.replace("v86", "v87")
    return value


def evidence() -> dict:
    item = _replace_version(copy.deepcopy(_v86_evidence()))
    item["schema_version"] = 87
    item["evidence_scope"] = "planetary_reward_provenance_closure_v87"
    item["evidence_mode"] = "detached_reward_provenance_closure_v87"
    item["authority"]["authority_scope"] = "planetary_reward_provenance_closure"
    item["authority_reconciliation"]["schema_version"] = 87
    for record in item["records"]:
        record["leaf_id"] = f"{record['activity_id']}_reward_provenance_closure_leaf_v87"
    item["provenance_closure_digest_sha256"] = _authority_digest(item["identity"], item["authority"], item["authority_link"], item["authority_reconciliation"], item["records"])
    item.pop("audit_closure_digest_sha256", None)
    return item


class PlanetaryRewardProvenanceClosureV87ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_provenance_closure(evidence()), [])

    def test_schema_version_is_v87(self):
        item = evidence()
        item["schema_version"] = 86
        self.assertTrue(any("schema_version must be 87" in error for error in validate_provenance_closure(item)))

    def test_provenance_link_version_is_required(self):
        item = evidence()
        item["authority_link"]["authority_version"] = "authority_v86"
        self.assertTrue(any("authority_link.authority_version must be authority_v87" in error for error in validate_provenance_closure(item)))

    def test_reconciliation_binds_provenance_manifest(self):
        item = evidence()
        item["authority_reconciliation"]["manifest_version"] = "v86"
        self.assertTrue(any("authority_reconciliation.manifest_version must be v87" in error for error in validate_provenance_closure(item)))

    def test_digest_binds_authority(self):
        item = evidence()
        item["authority"]["reward_store_id"] = "other_store"
        self.assertTrue(any("provenance_closure_digest_sha256 does not match canonical v87 payload" in error for error in validate_provenance_closure(item)))

    def test_all_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("all_evidence_refs must not contain duplicates" in error for error in validate_provenance_closure(item)))

    def test_counts_must_show_no_runtime_writes(self):
        item = evidence()
        item["counts"]["runtime_mutations"] = 1
        self.assertTrue(any("counts.runtime_mutations must be 0" in error for error in validate_provenance_closure(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_provenance_closure(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
